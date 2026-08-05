# Architecture Patterns

**Domain:** FreeRDP X11 client touchscreen-input patch (Debian / OneMix 3, FreeRDP 3.15.0)
**Researched:** 2026-08-05
**Overall confidence:** HIGH (verified against unpacked Debian source `freerdp3_3.15.0+dfsg-2.1+deb13u3`)

## Recommended Architecture

The patch inserts one new translation layer inside the existing X11 client, between the XInput2 touch-event dispatch (`xf_input_handle_event_remote` in `client/X11/xf_input.c`) and the existing RDPEI / mouse / keyboard input senders. It does not create a new daemon, a new RDP client, or a new channel.

```
OneMix 3 touchscreen
        |
        v
X server  ->  XInput2 XI_TouchBegin/Update/End  (cookie->data = XIDeviceEvent)
        |
        v
xf_input_handle_event_remote()            [client/X11/xf_input.c:853]
        |  (only when FreeRDP_MultiTouchInput == true; else local gesture path)
        v
[NEW] xf_touch_gesture_filter()           <-- the patch lives here
        |  per-contact state, long-press timer, pinch detection, fallback switch
        |
        +-- native RDPEI contact -->  xf_input_touch_remote()
        |                               -> freerdp_client_handle_touch()  [client/common/client.c:1942]
        |                                   -> RdpeiClientContext->TouchBegin/Update/End
        |                                       (channels/rdpei/client/rdpei_main.c)
        |
        +-- long-press right-click --> freerdp_input_send_mouse_event()  (button3 down+up)
        |                                via xf_generic_ButtonEvent() path
        |
        +-- pinch native       --> RDPEI two-contact update (same path as native)
        |
        +-- pinch Ctrl+wheel   --> freerdp_input_send_keyboard_event(Ctrl down)
        |                          freerdp_client_send_wheel_event(PTR_FLAGS_WHEEL|delta)
        |                          freerdp_input_send_keyboard_event(Ctrl up)
        v
Windows over RDP
```

### Component Boundaries

| Component | Responsibility | Communicates With | Files (verified) |
|-----------|----------------|-------------------|------------------|
| XInput2 capture | Register XI_TouchBegin/Update/End on direct-touch devices; decode cookie into `XIDeviceEvent`; dedup duplicate events | calls into gesture filter or legacy handlers | `client/X11/xf_input.c` (`xf_input_handle_event_remote`, `register_input_events`) |
| **Touch gesture filter (NEW)** | Owns per-contact lifecycle state, long-press timer, pinch state, fallback decision; emits one of: native contact, mouse button, or Ctrl+wheel | consumes `XIDeviceEvent`; emits via `freerdp_client_handle_touch`, `freerdp_input_send_mouse_event`, `freerdp_client_send_wheel_event`, `freerdp_input_send_keyboard_event` | new file `client/X11/xf_touch.c` + `xf_touch.h` |
| RDPEI native contact sender | Translates XInput2 touchId -> persisted `FreeRDP_TouchContact`, calls `RdpeiClientContext->TouchBegin/Update/End` | gesture filter calls `xf_input_touch_remote()` unchanged | `client/X11/xf_input.c:641`, `client/common/client.c:1771-1905`, `channels/rdpei/client/rdpei_main.c` |
| Mouse/keyboard sender (fallback) | Sends button + wheel + scancode over RDP input channel | gesture filter calls existing public APIs | `include/freerdp/input.h`, `include/freerdp/client.h:285` |
| Configuration | Long-press duration, pinch fallback toggle, thresholds; passed via existing settings + CLI flags | gesture filter reads `rdpSettings` | `include/freerdp/settings_types_private.h` (add near `MultiTouchInput` at line 602), `client/common/cmdline.c` (add case near line 1164) |
| Diagnostics | WLog tags for contact lifecycle, gesture decisions, fallback hits | gesture filter calls `WLog_*` with `TAG` | `client/X11/xf_input.c` (existing `WLog_DBG`) |
| Debian packaging | Build patched `freerdp3-x11` from source with `-DWITH_CHANNELS=ON -DWITH_XI=ON`; install `.deb` with rollback | wraps upstream CMake build | `debian/rules`, `debian/control`, `debian/freerdp3-x11.install` |

### Data Flow

#### Contact lifecycle (single finger, native RDPEI)

1. `XI_TouchBegin` arrives -> `xf_input_handle_event_remote` -> `xf_input_touch_remote` -> `freerdp_client_handle_touch(FREERDP_TOUCH_DOWN, touchId=event->detail, x, y)`.
2. `freerdp_client_touch_update` (`client/common/client.c:1907`) finds a free slot in `cctx->contacts[FREERDP_MAX_TOUCH_CONTACTS=10]` (id==0 means free; on DOWN it assigns id, flags, x, y, pressure).
3. `freerdp_handle_touch_down` -> `rdpei->TouchBegin(rdpei, contact->id, contact->x, contact->y, &contactId)` (`client/common/client.c:1851`, `channels/rdpei/client/rdpei_main.c:1515`).
4. `XI_TouchUpdate` -> `FREERDP_TOUCH_MOTION` -> `rdpei->TouchUpdate`.
5. `XI_TouchEnd` -> `FREERDP_TOUCH_UP` -> `rdpei->TouchEnd`; the contact slot is reset to zero in `freerdp_client_touch_update`.

**Key invariant:** `event->detail` is the XInput2 touch ID and is the `finger`/`contact->id` passed to RDPEI. The contact slot array in `rdp_client_context.contacts` is the authoritative lifecycle store for the remote path; it already handles up to 10 concurrent contacts. The patch must not duplicate this store for the native path.

#### Local gesture path (legacy, when `MultiTouchInput` is false)

`xf_input_handle_event_local` (`xf_input.c:527`) maintains its own `xfc->contacts[MAX_CONTACTS=20]` array (`touchContact` in `client/X11/xfreerdp.h:129`) and runs `xf_input_detect_pinch` / `xf_input_detect_pan`, which emit `PubSub_OnZoomingChange` / `PubSub_OnPanningChange`. **Those handlers are `#ifdef WITH_XRENDER` and only pan/zoom the local rendered surface (`xf_draw_screen`), they do NOT send anything to the remote Windows session** (`client/X11/xf_client.c:1744,1780`). This is the core reason pinch "doesn't work" for remote zoom today. The patch must not rely on this PubSub path for remote behavior.

#### Long-press disambiguation (NEW)

- On `XI_TouchBegin` for a single active contact, start a monotonic timer (use `GetTickCount64()` / `winpr` time, already available in tree; do not add a new timer dependency).
- While timer pending: buffer the contact so no RDPEI DOWN is sent yet. This delays only the long-press-candidate contact, not other contacts.
- If the finger moves beyond a small movement threshold before the timer fires -> cancel timer, emit the buffered DOWN immediately, then the queued/arriving UPDATEs (long-press does not apply; treat as normal touch/drag).
- If the finger lifts before the timer fires -> cancel timer, emit buffered DOWN + UP as a quick tap (left click via RDPEI, or via mouse button1 if native touch is disabled).
- If the timer fires with the finger still down and within threshold -> emit a right-click: `freerdp_input_send_mouse_event(input, PTR_FLAGS_BUTTON2 | PTR_FLAGS_DOWN, x, y)` then a release, and mark the contact as "consumed" so the subsequent `XI_TouchEnd` does not also send a tap.
- Only the long-press-candidate contact is buffered. A second finger arriving during the hold window cancels the long-press timer and transitions both contacts into the pinch path.

#### Pinch / native fallback (NEW)

- Two simultaneous contacts -> pinch state. Default: forward both contacts natively through RDPEI (Windows handles the zoom). This requires no new code beyond passing through; the existing `xf_input_touch_remote` already handles two concurrent contacts.
- Fallback mode (configurable, default off): suppress native RDPEI for the two contacts and instead drive `Ctrl` + vertical wheel:
  - On entering pinch (2nd contact DOWN): `freerdp_input_send_keyboard_event(input, KBD_FLAGS_DOWN, RDP_SCANCODE_LCONTROL)`.
  - On each distance delta: `freerdp_client_send_wheel_event(&xfc->common, PTR_FLAGS_WHEEL | (delta>0 ? 0x78 : PTR_FLAGS_WHEEL_NEGATIVE|(0x100-0x78)))` (values copied from the existing button map at `client/X11/xf_client.c:1051-1053`).
  - On leaving pinch (one finger lifts): release Ctrl, and if the remaining finger continues, transition it back to native single-touch (emit a synthetic DOWN if its original DOWN was suppressed).
- The fallback decision is a per-session boolean from settings; it does not change per-gesture.

## Patterns to Follow

### Pattern 1: Single insertion point, reuse existing senders
**What:** All new logic goes through one new function (`xf_touch_gesture_filter`) called from `xf_input_handle_event_remote` right after the cookie is decoded. It calls existing public input APIs (`freerdp_client_handle_touch`, `freerdp_input_send_mouse_event`, `freerdp_client_send_wheel_event`, `freerdp_input_send_keyboard_event`). No new channel, no new thread, no new IPC.
**When:** Always for this patch.
**Why:** The existing senders already own RDPEI framing, contact persistence, and RDP input channel state. Reimplementing any of them would duplicate protocol logic and break ordering.

### Pattern 2: Minimal state, owned in `xfContext`
**What:** Long-press timer value, movement accumulator, pinch baseline distance, "consumed" flag, and fallback-mode flag live as a small struct hung off `struct xf_context` (alongside the existing `xfc->contacts[]` / `xfc->active_contacts` / `xfc->firstDist` fields at `client/X11/xfreerdp.h:304-311`).
**When:** All gesture state.
**Why:** The X11 client is single-threaded for input (event loop in `xf_client.c:535` calls `xf_event_process` -> `xf_input_handle_event`). No locks are needed for v1. Do not introduce a separate gesture state object with its own allocation; the context already exists and is freed with the client.

### Pattern 3: Configuration via FreeRDP settings + CLI, no config file parser
**What:** Add new boolean/int settings next to the deprecated `MultiTouchInput`/`MultiTouchGestures` in `include/freerdp/settings_types_private.h:602`. Wire CLI flags in `client/common/cmdline.c` next to the existing `multitouch`/`gestures` cases (line 1164). Reuse the existing settings-getter/setter macros.
**When:** Any tunable value (long-press ms, pinch fallback toggle, movement threshold).
**Why:** FreeRDP already has a settings system, CLI parser, `.rdp` file parser, and man-page generation all driven from this one enum. Adding a separate config file format would be a new dependency and a new code path. A `.rdp` file or CLI flag is the documented launch-configuration mechanism.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Replacing the local-gesture `xfc->contacts[]` array or the PubSub zoom/pan path
**What:** Rewriting `xf_input_detect_pinch`/`detect_pan` or the `xf_ZoomingChangeEventHandler` to send remote events.
**Why bad:** The PubSub handlers are `#ifdef WITH_XRENDER` and operate on the local surface; coupling remote input to them breaks when XRender is off and entangles rendering with input. The `xfc->contacts[]` local array is only used in the `MultiTouchGestures` (non-native) path.
**Instead:** Leave the local path untouched; add the new filter only on the `MultiTouchInput` (remote) path.

### Anti-Pattern 2: A second contact-state array
**What:** Mirroring `cctx->contacts[]` (the RDPEI-side array in `client/common/client.c`) inside the patch.
**Why bad:** Two sources of truth for contact id->slot mapping, easy to desync, doubles the lifecycle bugs.
**Instead:** For native contacts, let `freerdp_client_handle_touch` own the persistence (it already does). The patch only needs its own state for the long-press candidate and pinch baseline, which is per-gesture, not per-remote-contact.

### Anti-Pattern 3: New third-party gesture library or timer library
**What:** Pulling in a gesture-recognition lib, libinput, or a new event-loop timer dependency.
**Why bad:** Adds build + runtime deps, fights the Debian packaging, and the recognition needed (one timer, two-finger distance) is ~50 lines of C using `math.h` and `GetTickCount64` already in tree.
**Instead:** Plain C with stdlib `math.h` and winpr time. The `ponytail:` ceiling is that this hand-rolled recognizer is tuned to one device; generalize later if a second device appears.

### Anti-Pattern 4: Adding a new input channel or modifying RDPEI framing
**What:** Touching `channels/rdpei/` to add gesture semantics.
**Why bad:** RDPEI is a wire protocol; the framing and contact-state machine (`RDPINPUT_CONTACT_FLAG_*` in `include/freerdp/channels/rdpei.h:88-93`) are correct and already used by the Android/SDL/Wayland clients. Gestures are a client-policy concern.
**Instead:** Keep all policy in `client/X11/`.

## Scalability Considerations

| Concern | 1 device (v1) | A few devices | General Linux touchscreen |
|---------|---------------|---------------|---------------------------|
| Contact count | Hard cap 10 (`FREERDP_MAX_TOUCH_CONTACTS`) or 20 (`MAX_CONTACTS`); fine for OneMix 3 (10-finger) | Same | Same; constant is upstream |
| Long-press timer | One timer, single-threaded | One per concurrent long-press candidate (v1 caps at 1) | Per-contact timer set; not needed for v1 |
| Pinch | Exactly 2 contacts | Same | 2+ needs a real pinch library; out of scope |
| Calibration | Hard-coded defaults + 2 CLI knobs | Same | Needs per-device profile; defer |
| State size | ~40 bytes in `xfContext` | Same | Same |

v1 is deliberately scoped to one device; the `ponytail:` ceiling here is the single long-press candidate. If multiple simultaneous long-presses ever matter, upgrade to a per-contact timer array in the gesture struct.

## Configuration and Calibration Path

- **Settings (new, in `settings_types_private.h` near line 602):**
  - `BOOL TouchLongPressEnabled` (default true)
  - `UINT32 TouchLongPressDurationMs` (default 600; range 500-700 per requirements)
  - `UINT32 TouchLongPressMoveThreshold` (default ~10px; movement below this does not cancel)
  - `BOOL TouchPinchWheelFallback` (default false; native pinch by default)
- **CLI (new cases in `client/common/cmdline.c` near line 1164):**
  - `/touch-long-press:<ms>` , `/touch-pinch-wheel-fallback` (and `-`-prefixed disables).
- **Launch config:** documented as a `~/.freerdp/onefix.rdp` or a shell wrapper invoking `xfreerdp3` with the right flags. No new config file format. This satisfies the "documented launch configuration" requirement with zero new config code.
- **Calibration knobs are runtime-configurable** because the physical touchscreen timing varies (ponytail: leave the knob, the physical world drifts).

## Test Seams and Diagnostics

- **Test seam:** The gesture filter takes a small, pure function of `(xfContext*, XIDeviceEvent*, evtype) -> action`. This can be unit-tested by feeding synthetic `XIDeviceEvent` sequences and asserting the emitted action (RDPEI down / mouse button2 / wheel). The existing `freerdp_client_handle_touch` is already a seam; call it through a function pointer if you want to mock it.
- **Self-check:** A `#ifdef DEBUG_X11` block (pattern already used in `xf_input.c:57`) that logs each contact lifecycle transition with the `TAG` logger: `WLog_DBG(TAG, "contact %d %s @ %d,%d", id, state, x, y)`. Enable with `WLOG_LEVEL=DEBUG` env var (existing FreeRDP mechanism).
- **Diagnostics checklist for the field:** `xfreerdp3 /version` (confirm patched build), `xinput list` + `xinput test <id>` (confirm XI_TouchBegin arrives), `WLOG_LEVEL=DEBUG xfreerdp3 +multitouch /v:host` and grep for the new contact-transition logs. No new diagnostic tool needed.
- **Minimal runnable check:** A tiny `test_touch.c` under `client/X11/test/` (mirroring the existing `client/common/test/` pattern) that constructs a 3-event sequence (DOWN, hold > duration, UP) and asserts a button2 event was emitted, not a button1. Assert-based, no framework. Skip if not asked, but it is the one check that fails if the long-press state machine breaks.

## Suggested Build Order and Dependencies

Ordered so each step produces a runnable, testable artifact on the OneMix 3.

1. **Capture baseline + build-from-source** (no code change)
   - Verify `apt-get source freerdp3` builds and installs the unpatched `.deb` with `dpkg-buildpackage`. Confirms toolchain (cmake, libxi-dev, libxrender-dev, etc.) and the rollback path works before any patch.
   - Depends on: nothing. Unblocks: everything.

2. **Add configuration skeleton** (settings + CLI, no behavior)
   - Add the 4 settings in `settings_types_private.h`, wire CLI cases in `cmdline.c`, regenerate settings getters (existing CMake step does this). Build, confirm `xfreerdp3 /help` shows new flags. No gesture code yet.
   - Depends on: step 1.

3. **Insert gesture filter as a passthrough** (no behavior change)
   - Add `xf_touch.c/h` with `xf_touch_gesture_filter()` that just forwards every event to `xf_input_touch_remote` unchanged. Call it from `xf_input_handle_event_remote`. Build, confirm native touch still works exactly as before.
   - Depends on: step 2. This is the seam; it proves the insertion point is correct without changing behavior.

4. **Long-press right-click**
   - Implement the timer + movement threshold + consumed flag in the filter. Test: hold 600ms -> right-click, no left-click; tap -> left-click; drag -> native touch resumes.
   - Depends on: step 3. Highest-risk requirement (disambiguation), so do it first after the seam.

5. **Pinch native passthrough + Ctrl+wheel fallback**
   - Native is already working via step 3; add the fallback branch using the wheel/keyboard APIs cited above and the button-map values from `xf_client.c:1051`.
   - Depends on: step 3. Can run in parallel with step 4 if a second person is available, since both edit `xf_touch.c` in different branches of the filter.

6. **Diagnostics + self-check**
   - Add the `DEBUG_X11` logging and the assert-based test. Run the field checklist on the OneMix 3.
   - Depends on: steps 4 and 5.

7. **Debian packaging + launch config + docs**
   - Bump `debian/changelog`, ensure `-DWITH_CHANNELS=ON -DWITH_XI=ON` in `debian/rules`, document the `.rdp`/wrapper launch config and rollback (`apt install freerdp3-x11=3.15.0+dfsg-2.1+deb13u3` to revert).
   - Depends on: step 6. Last because packaging wraps a frozen code state.

**Build-order rationale:** Each step is independently testable on the device. The seam (step 3) de-risks the insertion point before any gesture logic. Long-press (step 4) is the hardest disambiguation and goes before pinch, which is lower risk because native passthrough is the default.

## Sources

- Unpacked Debian source `freerdp3_3.15.0+dfsg-2.1+deb13u3` (FreeRDP-FreeRDP-405d509), files: `client/X11/xf_input.c`, `client/X11/xf_event.c`, `client/X11/xf_client.c`, `client/X11/xfreerdp.h`, `client/common/client.c`, `include/freerdp/client.h`, `include/freerdp/input.h`, `include/freerdp/channels/rdpei.h`, `include/freerdp/settings_types_private.h`, `client/common/cmdline.c`, `channels/rdpei/client/rdpei_main.c`, `debian/rules`, `debian/control`. [HIGH confidence, primary source]
- GitHub FreeRDP Issue #9082 "multitouch recently broken" (https://github.com/FreeRDP/FreeRDP/issues/9082) - confirms XInput2/RDPEI touch path has regression history. [MEDIUM]
- GitHub FreeRDP Issue #7721 "Multitouch Not Working" (https://github.com/FreeRDP/FreeRDP/issues/7721) - confirms `+multitouch` flag and RDPEI forwarding behavior. [MEDIUM]
- `xfreerdp3` man page / `client/common/cmdline.c` - documents `/multitouch` and `/gestures` flags. [HIGH, primary source]
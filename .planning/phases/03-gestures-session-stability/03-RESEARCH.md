# Phase 3: Gestures & Session Stability - Research

**Researched:** 2026-08-06
**Domain:** FreeRDP X11 client gesture state machine + lifecycle stability (long-press, pinch, Ctrl+wheel fallback, reconnect/focus cleanup)
**Confidence:** HIGH (all integration points verified by reading the pinned 3.15.0 source this session)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Long-press contract
- **D-01:** The X11 client owns long-press timing. Touch-down is still forwarded immediately as native RDPEI input so ordinary taps and drags gain no recognition delay; a client timer determines whether the configurable 500–700 ms hold threshold is reached.
- **D-02:** While one finger remains a long-press candidate, motion inside the configurable slop radius is suppressed so the OneMix 3's observed 1–3 px stationary jitter does not reach Windows. Moving beyond slop before the threshold permanently cancels the candidate and continues as an ordinary native drag without requiring lift.
- **D-03:** At the threshold, emit exactly one right-click at the original touch-down coordinate, prevent the native contact from later completing as a left-click, and consume all remaining updates for that physical finger until lift.
- **D-04:** A second finger immediately cancels any armed long-press candidate; pinch handling takes precedence and no right-click may fire while two fingers are down.

#### Native and fallback pinch claiming
- **D-05:** Native mode is pure RDPEI passthrough for both contacts and emits no local wheel shortcut. This includes native two-finger drag/scroll behavior handled by Windows; Phase 3 does not add a separate two-finger drag-to-wheel gesture.
- **D-06:** In fallback mode, the second finger immediately claims the gesture away from native RDPEI so native pinch and local `Ctrl`+wheel output can never overlap. Local wheel output waits until deliberate scale movement crosses a small activation deadband.
- **D-07:** Two fingers translating together without meaningful separation change produce no local action in fallback mode. The gesture remains reserved until it becomes a pinch or ends; it is not handed back to native input mid-gesture.
- **D-08:** Pinch recognition is based on change in inter-finger distance, with a small initial deadband to reject touchscreen jitter. The exact device-tested distance may be selected during planning and calibration rather than exposed as another speculative setting.

#### `Ctrl` + wheel zoom output
- **D-09:** Fingers moving apart zoom in (`Ctrl`+wheel-up); fingers moving together zoom out (`Ctrl`+wheel-down).
- **D-10:** Convert accumulated pinch distance into fixed standard wheel detents. Do not add speed-based acceleration or multi-detent bursts.
- **D-11:** Before the first fallback wheel tick, move the hidden remote pointer to the current pinch midpoint so applications that zoom around the cursor target the touched content.
- **D-12:** When pinch direction reverses, discard the partial wheel-step accumulator and require a fresh complete step before emitting the opposite direction; small reversals must not chatter between zoom-in and zoom-out.

#### Gesture completion and recovery
- **D-13:** A fallback pinch ends as soon as contact count drops below two. Release held `Ctrl` on that first finger lift, stop wheel output, and ignore the remaining finger until every pinch contact has lifted; do not resume it as a one-finger tap, drag, or long-press.
- **D-14:** A third finger aborts fallback pinch: release `Ctrl`, stop output, reset the gesture, and require all involved fingers to lift before accepting new touch input.
- **D-15:** Extend the existing Phase 2 forced-cancel/recovery seam to all gesture state. Focus loss, unmap/minimize, fullscreen or geometry change, channel loss, disconnect, and shutdown must cancel armed long-press/pinch state, release `Ctrl` if held, clear accumulators, and require a fresh physical touch after the existing all-fingers-lift gate.
- **D-16:** Automatic reconnect preserves the startup-selected native/fallback pinch mode for the lifetime of the client process, but never resumes or replays the interrupted gesture.

### Claude's Discretion
- Exact helper names, state layout, timer subscription point, and file split are left to planning. Reuse the existing X11 main-loop timer and input helpers where practical; do not add a thread, dependency, daemon, or duplicate RDPEI encoder.
- Choose and calibrate the default long-press threshold within 500–700 ms, the configurable slop default, the fallback activation deadband, and fixed wheel-step distance on the OneMix 3. Only the requirement-mandated long-press timing/slop and startup pinch mode need user-facing calibration unless device evidence justifies another knob.
- Exact ordering of native-contact cancellation, right-button down/up, Ctrl press, pointer-centering motion, and first wheel tick is flexible provided the externally visible decisions above hold: no unwanted left-click, no native/fallback overlap, and no stuck modifier.
- Test organization, diagnostic wording, and internal logging detail are flexible, but checks must cover timer firing, slop cancellation, second/third-finger transitions, wheel direction/detents, midpoint targeting, every cleanup hook, and reconnect reuse.

### Deferred Ideas (OUT OF SCOPE)
None — fallback two-finger drag-to-wheel scrolling was considered but deliberately not added because native passthrough already supplies two-finger scrolling within the Phase 3 contract.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| GEST-01 | Configurable 500–700 ms long press produces one right-click at that position, no left-click afterward. | D-01/D-02/D-03 state machine; `freerdp_client_send_button_event` with `PTR_FLAGS_BUTTON2` for right-click; timer via `PubSub_SubscribeTimer`; RDPEI contact cancellation via `rdpei->TouchCancel` to prevent the held native contact completing as left-click. Root-cause evidence in 02-UAT (1–3px jitter). |
| GEST-02 | Moving beyond configurable slop before threshold cancels long-press and continues as ordinary native drag. | D-02; distance check against touch-down coordinate using existing `sqrt(pow())` pattern; on cancel, emit buffered native DOWN + queued UPDATEs through `freerdp_client_handle_touch`. |
| GEST-03 | Native pinch mode forwards native multitouch, no local wheel. | D-05; existing `xf_input_touch_remote` two-contact passthrough already works (02-UAT Test 1 confirmed two distinct contacts). Phase 3 only adds the exclusivity guard and the mode latch. |
| GEST-04 | Fallback pinch mode emits Ctrl+wheel, never also native pinch, releases Ctrl on end/interrupt. | D-06..D-13; `freerdp_input_send_keyboard_event` + `RDP_SCANCODE_LCONTROL` for Ctrl; `freerdp_client_send_wheel_event` with `PTR_FLAGS_WHEEL`; `freerdp_client_send_button_event` for midpoint pointer; `xf_touch_force_cancel` extended to release Ctrl. |
| STAB-01 | Touch usable without crashes/stale contacts/duplicate events after windowed/fullscreen switch and focus loss/regain. | D-15; existing `xf_touch_force_cancel` already wired into FocusOut, UnmapNotify, ConfigureNotify, toggle_fullscreen (verified). Extend to clear gesture state + release Ctrl. |
| STAB-02 | Disconnect/reconnect during active touch/gesture does not crash; touch works after reconnection. | D-15/D-16; `xf_post_disconnect` already calls `xf_touch_force_cancel`; `client_auto_reconnect_ex` preserves process state; gesture reset must run on both paths; startup pinch mode read from settings (survives reconnect). |
</phase_requirements>

## Summary

Phase 3 adds a minimal gesture state machine inside the existing X11 remote-touch path (`xf_input_touch_remote` / `xf_input_handle_event_remote`) on top of the Phase 2 forced-cancel/recovery seam. Three things are new: (1) a configurable long-press right-click that holds the native contact as a candidate, suppresses sub-slop jitter, and fires one right-click at threshold while cancelling the native contact; (2) a startup-selected pinch mode — native RDPEI passthrough (already working) or a `Ctrl`+wheel fallback that suppresses native contacts and synthesizes wheel detents with midpoint targeting and reversal hysteresis; (3) extension of the existing `xf_touch_force_cancel` reset seam to clear all gesture state and release a held Ctrl across every lifecycle hook, plus reconnect-safe reset that never replays the interrupted gesture.

The highest-value, highest-risk item is the long-press deadband (D-02). Phase 2 on-device UAT confirmed the root cause: the OneMix 3 touchscreen reports 1–3 px jitter on a stationary finger, and every jitter frame is forwarded as RDPEI MOTION, which cancels Windows' built-in press-and-hold right-click. Phase 3's client-side long-press does not rely on Windows press-and-hold at all — it owns timing and emits its own right-click — but the slop suppression also fixes the underlying jitter leak so Windows sees a stationary contact during the hold window.

Every external input the gesture layer needs already exists in the tree and is already called by the Phase 2 patch: `freerdp_client_handle_touch` (native contacts), `freerdp_client_send_button_event` (right-click + midpoint pointer), `freerdp_client_send_wheel_event` (wheel detents), `freerdp_input_send_keyboard_event` (Ctrl press/release), `rdpei->TouchCancel` (cancel the held native contact). No new dependency, thread, channel, or RDPEI encoder work is needed. The patch stays in `client/X11/` (plus new settings rows and CLI cases), preserving SDL/Wayland policy separation.

**Primary recommendation:** Implement the long-press state machine as a candidate-tracking layer inside `xf_input_touch_remote` that suppresses sub-slop MOTION and arms a deadline checked on the existing 20 ms `PubSub_OnTimer` tick; at threshold, call `rdpei->TouchCancel` on the held contact, synthesize one right-click via `freerdp_client_send_button_event`, and freeze the finger until lift. Implement fallback pinch as an exclusive branch that suppresses both native contacts, synthesizes Ctrl+wheel with a fixed detent accumulator and reversal reset, and routes all cleanup through the extended `xf_touch_force_cancel`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Long-press timing & candidate state | X11 client (xf_input.c) | — | Single-threaded X11 event loop owns input disambiguation; no cross-tier coordination needed. |
| Long-press deadline check | X11 client timer (PubSub_OnTimer) | — | Reuse the existing 20 ms waitable timer; no new timer framework. |
| Slop/jitter suppression (D-02) | X11 client (xf_input.c) | — | Motion filter inside the remote dispatch; Windows never sees sub-slop frames. |
| Right-click synthesis | X11 client → client/common (button event) | — | `freerdp_client_send_button_event` is the shared sender; X11 owns the decision. |
| Native pinch passthrough | X11 client → RDPEI channel | — | Already working; Phase 3 only adds the mode latch + exclusivity guard. |
| Fallback pinch Ctrl+wheel | X11 client → client/common (wheel/key) | — | X11 owns the gesture policy; shared senders emit the input. |
| Gesture cleanup on lifecycle | X11 client (xf_touch_force_cancel) | — | Single reset seam already converges all lifecycle hooks. |
| Reconnect stability | X11 client + FreeRDP core (auto_reconnect) | — | `client_auto_reconnect_ex` preserves process/settings; X11 resets gesture state. |
| Configuration (threshold/slop/mode) | rdpSettings + cmdline parser | — | Existing settings enum + CLI cases; no config file parser. |

## Standard Stack

No new packages are installed in this phase. The entire stack is already present in the pinned `freerdp3_3.15.0+dfsg-2.1+deb13u3` source tree and was built successfully in Phases 1–2.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| FreeRDP X11 client (in-tree) | 3.15.0+dfsg-2.1+deb13u3 | The `xf_input.c` / `xf_client.c` / `xf_event.c` / `xfreerdp.h` files being patched. | Pinned by project constraint; already built. |
| libfreerdp-client3 (in-tree, linked) | 3.15.0 | `freerdp_client_handle_touch`, `freerdp_client_send_button_event`, `freerdp_client_send_wheel_event`. | Already called by Phase 2 patch; shared senders own RDPEI framing and RDP input channel state. |
| RdpeiClientContext (in-tree, loaded) | 3.15.0 | `TouchCancel` to cancel the held native contact; `SuspendTouch`/`ResumeTouch` available if needed. | Channel vtable already fetched as `xfc->common.rdpei`. |
| WinPR time + logging (bundled) | 3.15.0 | `GetTickCount64()` for monotonic deadline; `WLog_DBG` for diagnostics. | Already used throughout `xf_input.c`. |
| C stdlib `math.h` | gcc-14 | `sqrt`/`pow` for inter-finger distance (pattern already in `xf_input_detect_pinch`). | Already used at `xf_input.c:431`. |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| rdpSettings enum (in-tree) | 3.15.0 | Add `TouchLongPressDurationMs`, `TouchLongPressSlopPx`, `TouchPinchWheelFallback` settings. | Only for requirement-mandated calibration knobs. |
| cmdline parser (in-tree) | 3.15.0 | Wire `/touch-long-press:<ms>`, `/touch-slop:<px>`, `/touch-pinch-wheel-fallback`. | Only for user-facing calibration. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| PubSub_OnTimer deadline check | A dedicated WinPR timer object | More code, another handle in the wait array; the 20 ms tick is already running and finer than the 500 ms threshold. Use the existing tick. |
| Client-side long-press (own timing + right-click) | Rely on Windows press-and-hold | Broken on this device (jitter cancels it — 02-UAT root cause). Client-side is the fix. |
| `rdpei->TouchCancel` to kill the held contact | `rdpei->TouchEnd` | TouchEnd completes the contact as a normal lift → Windows may interpret the down+up as a left-click. TouchCancel emits `UP|CANCELED` so Windows abandons the action. Use TouchCancel. |

**Installation:**
```bash
# No new packages. Rebuild the existing patched source:
cd build/freerdp3-3.15.0+dfsg
dpkg-buildpackage -us -uc -b -j$(nproc)
```

**Version verification:** Not applicable — no external packages added. All APIs verified against the in-tree source this session (see Code Examples).

## Package Legitimacy Audit

Not applicable — this phase installs no external packages. It patches the already-pinned, already-built FreeRDP 3.15.0 source tree in-place using only in-tree APIs and the C standard library.

## Architecture Patterns

### System Architecture Diagram

```
XInput2 XI_TouchBegin/Update/End
        |
        v
xf_input_handle_event_remote()            [xf_input.c:1009]
        |  (D-08 recovery gate first — unchanged from Phase 2)
        v
xf_input_touch_remote()                    [xf_input.c:646]
        |
        +-- if !rdpei -> Phase 2 fallback latch (unchanged)
        |
        +-- [NEW] per-contact candidate / pinch state machine
        |       |
        |       +-- single finger, down:
        |       |     forward native DOWN immediately (D-01)
        |       |     arm long-press deadline (touch-down x,y + start time)
        |       |
        |       +-- single finger, update while candidate armed:
        |       |     if dist(down,now) <= slop -> suppress (D-02 jitter fix)
        |       |     else -> cancel candidate, forward native DOWN (if buffered) + this UPDATE (D-02 drag)
        |       |
        |       +-- deadline fires (timer tick):
        |       |     rdpei->TouchCancel(held contact)  (D-03 prevent left-click)
        |       |     freerdp_client_send_button_event(BUTTON2|DOWN, down_x, down_y)
        |       |     freerdp_client_send_button_event(BUTTON2, down_x, down_y)  (release)
        |       |     mark finger FROZEN until lift (D-03)
        |       |
        |       +-- second finger (D-04/D-06):
        |       |     cancel long-press candidate
        |       |     native mode -> passthrough both (D-05)
        |       |     fallback mode -> suppress both native, claim pinch, press Ctrl (D-06)
        |       |
        |       +-- fallback pinch update (D-08..D-12):
        |       |     deadband -> no output
        |       |     accumulate distance delta -> fixed detents -> wheel event
        |       |     on reversal -> reset accumulator (D-12)
        |       |     midpoint pointer move before first tick (D-11)
        |       |
        |       +-- lift / third finger / lifecycle (D-13/D-14/D-15):
        |             -> xf_touch_force_cancel() [extended] releases Ctrl, clears all gesture state
        |
        v
freerdp_client_handle_touch()  /  freerdp_client_send_button_event()  /
freerdp_client_send_wheel_event()  /  freerdp_input_send_keyboard_event()
        |
        v
Windows over RDP
```

### Recommended Project Structure
```
client/X11/
  xf_input.c        # long-press + pinch state machine inserted here (single file, no new file needed)
  xf_input.h        # xf_touch_force_cancel declaration (extend if new reset helper added)
  xfreerdp.h        # new gesture fields in xfContext (under #if defined(WITH_XI))
  xf_event.c        # unchanged hooks (already call xf_touch_force_cancel)
  xf_client.c       # unchanged hooks (already call xf_touch_force_cancel); timer already runs
include/freerdp/
  settings_types_private.h  # new settings rows near line 602
client/common/
  cmdline.c         # new CLI cases near line 1164
```

The CLAUDE.md / ARCHITECTURE.md originally suggested a new `xf_touch.c`/`xf_touch.h` file. Phase 2 instead kept all touch policy inline in `xf_input.c` (X11-only, no shared file). Phase 3 should continue that pattern: the gesture state machine is small and X11-specific, and a new file would split the single dispatch function across two files for no reuse benefit. Put the gesture fields in `xfreerdp.h` next to the Phase 2 fields.

### Pattern 1: Candidate layer inside the existing dispatch, not a separate filter function
**What:** Add long-press candidate tracking and pinch claiming directly inside `xf_input_touch_remote()` before the existing `switch (evtype)` that calls `freerdp_client_handle_touch`. Do not create a separate `xf_touch_gesture_filter()` wrapper that forwards — Phase 2 already proved the inline approach works and keeps the diff in one function.
**When:** Always for this phase.
**Why:** A wrapper that just forwards adds a call layer and a second switch with no reuse. The state machine is per-contact and per-gesture, read from `xfContext` — inline keeps it next to the contact store it coordinates with.

### Pattern 2: Single reset seam — extend `xf_touch_force_cancel`
**What:** `xf_touch_force_cancel()` (xf_input.c:792) already converges FocusOut, UnmapNotify, ConfigureNotify, toggle_fullscreen, and post_disconnect. Extend it to also: cancel any armed long-press timer/candidate, reset pinch accumulators, release a held Ctrl (idempotent), and clear the frozen-finger set. Do not add a second reset function.
**When:** Every lifecycle cleanup path.
**Why:** One reset function means every future lifecycle hook gets cleanup for free. Two functions mean a hook can wire one and forget the other.

### Pattern 3: Monotonic deadline on the existing timer tick
**What:** The main loop already runs a 20 ms waitable timer and publishes `TimerEventArgs` via `PubSub_OnTimer` (xf_client.c:1609,1694). Subscribe a callback via `PubSub_SubscribeTimer(pubSub, cb)` (pattern at xf_disp.c:338). The callback checks armed long-press deadlines against `GetTickCount64()` (monotonic, already used at xf_client.c:1693).
**When:** Long-press deadline detection.
**Why:** 20 ms granularity is 25x finer than the 500 ms threshold — no perceptible delay. No new timer handle, no new wait-array entry, no thread.

### Pattern 4: Configuration via rdpSettings + CLI, no config file
**What:** Add settings rows in `settings_types_private.h` next to `MultiTouchInput` (line 602). Wire CLI cases in `cmdline.c` next to `multitouch` (line 1164). Reuse existing `freerdp_settings_get_*`/`set_*` macros.
**When:** Any tunable value (long-press ms, slop px, pinch mode).
**Why:** FreeRDP already parses CLI + `.rdp` files from this one enum. A separate config format is a new dependency and a new code path (forbidden by CLAUDE.md).

### Anti-Patterns to Avoid
- **Switching `MultiTouchInput` vs `MultiTouchGestures` mid-gesture:** The two modes are mutually exclusive in the dispatch. Fallback pinch must NOT toggle `MultiTouchInput` off then on — it stays in the remote path and suppresses the two native contacts itself, keeping the contact store consistent. (Pitfall 11.)
- **A second contact-state array:** Do not mirror `cctx->contacts[]`. The gesture layer tracks only per-gesture candidate state (down coordinate, start time, frozen flag, pinch baseline) keyed by the XI2 touch ID, not a parallel contact map. (Pitfall 6 / ARCHITECTURE Anti-Pattern 2.)
- **Reusing the local `xfc->contacts[]` pinch detector for fallback:** `xf_input_detect_pinch` (xf_input.c:416) runs only in the `MultiTouchGestures` (non-remote) path and only rescales the local framebuffer via PubSub. It does not send remote input. Fallback pinch must compute its own distance delta in the remote path. (ARCHITECTURE Anti-Pattern 1.)
- **Releasing Ctrl without checking it was pressed:** Ctrl release must be idempotent and guarded by a "Ctrl held" flag so a double-cleanup or a cleanup after a normal gesture does not send a stray key-up. (D-15, Pitfall 9.)
- **Leaving the temporary `/* DIAG: */` blocks in:** The two DIAG blocks at xf_input.c:653-663 and 797-803 are NOT in the quilt patch and are Phase 4's responsibility. Phase 3 must not build on them as if they were product code. (02-REVIEW-FIX, STATE.md cleanup note.)

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Long-press timer | A new timer thread/object | `PubSub_SubscribeTimer` on the existing 20 ms tick | Already running; 25x finer than the threshold; no new handle. |
| Right-click synthesis | Direct `freerdp_input_send_mouse_event` with raw flags | `freerdp_client_send_button_event(cctx, FALSE, PTR_FLAGS_BUTTON2\|PTR_FLAGS_DOWN, x, y)` | Shared sender handles ainput channel + relative/absolute; already used by Phase 2 fallback. |
| Wheel detents | A custom input channel frame | `freerdp_client_send_wheel_event(cctx, PTR_FLAGS_WHEEL \| delta)` | Shared sender handles ainput + fallback paths. |
| Ctrl key press/release | Raw scancode wiring | `freerdp_input_send_keyboard_event(input, KBD_FLAGS_DOWN, RDP_SCANCODE_LCONTROL)` | Existing API + existing scancode constant. |
| Cancelling the held native contact | `rdpei->TouchEnd` or a synthetic UP | `rdpei->TouchCancel(rdpei, id, x, y, &dummy)` | Emits `UP|CANCELED` so Windows abandons the press instead of completing a left-click. |
| Pinch distance math | A gesture library | `sqrt(pow(dx,2)+pow(dy,2))` (pattern at xf_input.c:431) | Two-finger distance is one line of stdlib math. |
| Contact ID mapping | A local externalId→contactId map | `cctx->contacts[]` (authoritative, owned by client/common) | RDPEI owns the map; duplicating it desyncs (Pitfall 6). |

**Key insight:** Every input emission the gesture layer needs is already a shared helper in `client/common/client.c` or `include/freerdp/input.h`, already linked, already called by Phase 2. The patch is policy + state, not new transport.

## Common Pitfalls

### Pitfall 1: Long-press also left-clicks (the #6566 / D-03 trap)
**What goes wrong:** The native DOWN is forwarded immediately (D-01). If the deadline fires and you only synthesize a right-click, Windows already has a left DOWN for the same contact — the right-click lands as a left-drag + right-click, selecting text or flickering menus.
**Why it happens:** D-01 mandates immediate native forwarding for zero tap latency. The disambiguation window is unavoidable; the mistake is leaving the native contact alive after the right-click.
**How to avoid:** At threshold, call `rdpei->TouchCancel` on the held contact (emits `UP|CANCELED`, Windows abandons the press), THEN synthesize the right-click. Mark the finger FROZEN and consume all further UPDATEs until lift so no new native contact is created.
**Warning signs:** Right-click works but the target was already left-clicked/dragged; context menu opens then closes.

### Pitfall 2: Jitter leaks through the slop and cancels the hold (the on-device root cause)
**What goes wrong:** The OneMix 3 reports 1–3 px jitter on a stationary finger (confirmed in 02-UAT: id=52 x 1684-1687 y 759-762). Every jitter frame forwarded as RDPEI MOTION tells Windows the finger moved, cancelling press-and-hold and making the hold look like a micro-drag.
**Why it happens:** The touchscreen hardware/driver jitter; X11 delivers it faithfully.
**How to avoid:** D-02 slop suppression: while a long-press candidate is armed, compute distance from the touch-down coordinate; if <= slop (configurable, e.g. 5-10 px), drop the UPDATE (do not call `freerdp_client_handle_touch` for that frame). Only forward UPDATEs that exceed slop (which also cancels the candidate → drag). This is the single highest-value fix in the phase.
**Warning signs:** Long-press works in a synthetic test but not on the real device; Windows shows the press-and-hold circle then cancels it.

### Pitfall 3: Fallback pinch and native pinch fire at once (Pitfall 11)
**What goes wrong:** If native RDPEI contacts are still being forwarded while Ctrl+wheel synthesizes, the app receives both and zoom jumps/oscillates.
**Why it happens:** The two modes are mutually exclusive but a naive "fallback" toggles per-gesture or forwards the first contact before claiming.
**How to avoid:** D-06: in fallback mode, the SECOND finger claims the gesture. From that moment, suppress BOTH contacts' native forwarding. The first contact's already-emitted native DOWN must be cancelled via `rdpei->TouchCancel` so Windows does not keep a dangling contact. Mode is latched at startup (D-16), never switched mid-gesture.
**Warning signs:** Pinch zoom overshoots or oscillates; after a pinch, single-touch behaves wrong.

### Pitfall 4: Stuck Ctrl after cleanup (D-15 / Pitfall 9)
**What goes wrong:** A lifecycle interrupt (focus loss, disconnect, third finger) aborts a fallback pinch but the Ctrl key-up is never sent — Windows keeps Ctrl held, every subsequent click is a Ctrl+click.
**Why it happens:** Multiple abort paths; one forgets the key release.
**How to avoid:** All cleanup routes through the single extended `xf_touch_force_cancel`. It checks a `ctrlHeld` flag and releases Ctrl idempotently (only sends key-up if flag was set, then clears the flag). Every lifecycle hook already calls this function.
**Warning signs:** After a pinch + focus loss, left-clicks act as Ctrl+click; menus don't open normally.

### Pitfall 5: Reconnect replays or resumes the interrupted gesture (D-16)
**What goes wrong:** After `client_auto_reconnect_ex`, stale gesture state (armed timer, pinch baseline, frozen finger) causes a spurious right-click or wheel burst on the new session.
**Why it happens:** Reconnect preserves the `xfContext` and process state; gesture state survives unless explicitly reset.
**How to avoid:** `xf_post_disconnect` already calls `xf_touch_force_cancel` (xf_client.c:1473) which will now clear gesture state. The reconnect path must NOT re-arm anything — startup pinch mode is read from settings (survives, by design), but all per-gesture state starts clean. The recovery gate (D-08) already requires all-fingers-up before new touches.
**Warning signs:** A right-click or zoom fires immediately after reconnect with no user input.

### Pitfall 6: Wheel direction chatters on reversal (D-12)
**What goes wrong:** Small back-and-forth hand motion near the pinch reversal point emits alternating wheel-up/wheel-down, making zoom jitter.
**Why it happens:** Accumulator crosses zero on every tiny reversal.
**How to avoid:** D-12: on direction reversal, discard the partial accumulator and require a fresh full detent of distance before emitting the opposite direction. Hysteresis, not zero-crossing.
**Warning signs:** Zoom stutters when the user hesitates mid-pinch.

## Code Examples

Verified signatures and constants from the pinned source (read this session):

### Native contact dispatch (the insertion point)
```c
// Source: build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c:769-783  [VERIFIED]
switch (evtype)
{
    case XI_TouchBegin:
        freerdp_client_handle_touch(&xfc->common, FREERDP_TOUCH_DOWN, touchId, 0, x, y);
        break;
    case XI_TouchUpdate:
        freerdp_client_handle_touch(&xfc->common, FREERDP_TOUCH_MOTION, touchId, 0, x, y);
        break;
    case XI_TouchEnd:
        freerdp_client_handle_touch(&xfc->common, FREERDP_TOUCH_UP, touchId, 0, x, y);
        break;
    default:
        break;
}
```
`freerdp_client_handle_touch` signature [VERIFIED: include/freerdp/client.h:261]:
`BOOL freerdp_client_handle_touch(rdpClientContext* cctx, UINT32 flags, INT32 finger, UINT32 pressure, INT32 x, INT32 y);`
Flags [VERIFIED: include/freerdp/client.h:255-258]: `FREERDP_TOUCH_DOWN = 0x01`, `FREERDP_TOUCH_UP = 0x02`, `FREERDP_TOUCH_MOTION = 0x04`.

### Existing forced-cancel seam (to extend)
```c
// Source: build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c:792-829  [VERIFIED]
void xf_touch_force_cancel(xfContext* xfc)
{
    rdpClientContext* cctx = &xfc->common;
    RdpeiClientContext* rdpei = cctx->rdpei;
    xfc->quarantinedCount = 0;
    for (size_t i = 0; i < FREERDP_MAX_TOUCH_CONTACTS; i++)
    {
        FreeRDP_TouchContact* c = &cctx->contacts[i];
        if (c->id != 0)
        {
            int dummy = 0;
            if (rdpei)
                rdpei->TouchCancel(rdpei, c->id, c->x, c->y, &dummy);
            if (xfc->quarantinedCount < (int)FREERDP_MAX_TOUCH_CONTACTS)
                xfc->quarantinedFingers[xfc->quarantinedCount++] = c->id;
            FreeRDP_TouchContact empty = { 0 };
            *c = empty;
        }
    }
    if (xfc->quarantinedCount > 0)
        xfc->recoveryGateArmed = TRUE;
}
```
Phase 3 extends this to also: clear long-press candidate state, reset pinch accumulators, release held Ctrl idempotently, clear frozen-finger set. The `rdpei->TouchCancel` vtable entry [VERIFIED: include/freerdp/client/rdpei.h:95] has signature `UINT (*pcRdpeiTouchEvent)(RdpeiClientContext*, INT32 externalId, INT32 x, INT32 y, INT32* contactId)`.

### Right-click + midpoint pointer (for D-03, D-11)
```c
// [VERIFIED: build/freerdp3-3.15.0+dfsg/client/common/client.c:1652]
BOOL freerdp_client_send_button_event(rdpClientContext* cctx, BOOL relative, UINT16 mflags, INT32 x, INT32 y);
// Pointer flags [VERIFIED: include/freerdp/input.h:40-46]:
//   PTR_FLAGS_WHEEL         0x0200
//   PTR_FLAGS_WHEEL_NEGATIVE 0x0100
//   PTR_FLAGS_DOWN          0x8000
//   PTR_FLAGS_BUTTON1       0x1000  /* left */
//   PTR_FLAGS_BUTTON2       0x2000  /* right */
//   PTR_FLAGS_BUTTON3       0x4000  /* middle */
//   PTR_FLAGS_MOVE          (implied; see ButtonPress handling)

// Right-click down + up at (x,y):
freerdp_client_send_button_event(&xfc->common, FALSE, PTR_FLAGS_DOWN | PTR_FLAGS_BUTTON2, x, y);
freerdp_client_send_button_event(&xfc->common, FALSE, PTR_FLAGS_BUTTON2, x, y);
// Midpoint pointer move before first wheel tick (D-11):
freerdp_client_send_button_event(&xfc->common, FALSE, PTR_FLAGS_MOVE, mx, my);
```

### Wheel detent (for D-09, D-10)
```c
// [VERIFIED: build/freerdp3-3.15.0+dfsg/client/common/client.c:1590]
BOOL freerdp_client_send_wheel_event(rdpClientContext* cctx, UINT16 mflags);
// Zoom in (wheel-up):  freerdp_client_send_wheel_event(&xfc->common, PTR_FLAGS_WHEEL | 0x78);
// Zoom out (wheel-down): freerdp_client_send_wheel_event(&xfc->common, PTR_FLAGS_WHEEL | PTR_FLAGS_WHEEL_NEGATIVE | (0x100 - 0x78));
// 0x78 = standard wheel detent (120 decimal / 1 step). PTR_FLAGS_WHEEL_NEGATIVE inverts.
```
Note: the `0x78` value is [ASSUMED] as a standard detent — the existing local button map at `xf_client.c:1051` (referenced in ARCHITECTURE.md) should be read and copied verbatim during implementation rather than re-derived. The planner should add a task to read that exact line range.

### Ctrl key press/release (for D-06, D-13)
```c
// [VERIFIED: include/freerdp/input.h:104]
BOOL freerdp_input_send_keyboard_event(rdpInput* input, UINT16 flags, UINT8 code);
// Flags [VERIFIED: include/freerdp/input.h:33-35]: KBD_FLAGS_DOWN, KBD_FLAGS_RELEASE
// Scancode [VERIFIED: include/freerdp/scancode.h:71]: RDP_SCANCODE_LCONTROL
rdpInput* input = xfc->common.context.input;
freerdp_input_send_keyboard_event(input, KBD_FLAGS_DOWN, RDP_SCANCODE_LCONTROL);
// ... wheel events ...
freerdp_input_send_keyboard_event(input, KBD_FLAGS_RELEASE, RDP_SCANCODE_LCONTROL);
```

### Timer subscription (for long-press deadline)
```c
// Pattern [VERIFIED: build/freerdp3-3.15.0+dfsg/client/X11/xf_disp.c:338]
PubSub_SubscribeTimer(pubSub, xf_disp_OnTimer);
// Callback signature [VERIFIED: build/freerdp3-3.15.0+dfsg/client/X11/xf_disp.c:270]:
static void xf_disp_OnTimer(void* context, const TimerEventArgs* e);
// Timer fires every 20ms [VERIFIED: build/freerdp3-3.15.0+dfsg/client/X11/xf_client.c:1609,1619,1694]:
//   CreateWaitableTimerA(...); SetWaitableTimer(timer, &due, 20, ...);
//   timerEvent.now = GetTickCount64(); PubSub_OnTimer(context->pubSub, context, &timerEvent);
```
The callback receives `void* context` which is `rdpContext*`; cast to `xfContext*` via the existing `xf_disp_check_context` pattern or direct cast. `GetTickCount64()` is monotonic and already used in the timer publisher.

### Existing xfContext touch fields (where new gesture fields go)
```c
// Source: build/freerdp3-3.15.0+dfsg/client/X11/xfreerdp.h:303-318  [VERIFIED]
#if defined(WITH_XI)
    touchContact contacts[MAX_CONTACTS];
    int active_contacts;
    int lastEvType;
    XIDeviceEvent lastEvent;
    double firstDist;
    double lastDist;
    double z_vector;
    double px_vector;
    double py_vector;
    BOOL fallbackActive;
    int fallbackFinger;
    BOOL recoveryGateArmed;
    int quarantinedFingers[FREERDP_MAX_TOUCH_CONTACTS];
    int quarantinedCount;
#endif
```
New Phase 3 fields go in this same `#if defined(WITH_XI)` block, zero-initialized in `xf_input_init` (verified at xf_input.c:245-263 — `fallbackActive`, `recoveryGateArmed`, `quarantinedCount` are already zeroed there; add the new fields to the same init).

### Settings + CLI insertion points
```c
// [VERIFIED: build/freerdp3-3.15.0+dfsg/include/freerdp/settings_types_private.h:602-603]
SETTINGS_DEPRECATED(ALIGN64 BOOL MultiTouchInput);        /* 2631 */
SETTINGS_DEPRECATED(ALIGN64 BOOL MultiTouchGestures);     /* 2632 */
// Add new settings rows here (non-deprecated), e.g.:
//   ALIGN64 UINT32 TouchLongPressDurationMs;
//   ALIGN64 UINT32 TouchLongPressSlopPx;
//   ALIGN64 BOOL   TouchPinchWheelFallback;

// [VERIFIED: build/freerdp3-3.15.0+dfsg/client/common/cmdline.c:1164-1173]
CommandLineSwitchCase(arg, "multitouch") { ... }
CommandLineSwitchCase(arg, "gestures") { ... }
// Add new cases here.
```

### Lifecycle hooks already calling xf_touch_force_cancel (verified, no new wiring needed)
```c
// [VERIFIED: build/freerdp3-3.15.0+dfsg/client/X11/xf_event.c:712]   FocusOut
// [VERIFIED: build/freerdp3-3.15.0+dfsg/client/X11/xf_event.c:844]   ConfigureNotify (on resize)
// [VERIFIED: build/freerdp3-3.15.0+dfsg/client/X11/xf_event.c:956]   UnmapNotify
// [VERIFIED: build/freerdp3-3.15.0+dfsg/client/X11/xf_client.c:805]  toggle_fullscreen
// [VERIFIED: build/freerdp3-3.15.0+dfsg/client/X11/xf_client.c:1473] post_disconnect
```
Phase 3 does NOT add new hook call sites — it extends what the one function does. This is the D-15 contract.

### Reconnect path
```c
// [VERIFIED: build/freerdp3-3.15.0+dfsg/client/X11/xf_client.c:1667]
if (client_auto_reconnect_ex(instance, handle_window_events))
    continue;
// post_disconnect (called on full disconnect) already calls xf_touch_force_cancel at line 1473.
// Startup pinch mode is a setting -> survives reconnect by design (D-16).
// Per-gesture state is cleared by the extended force_cancel; the recovery gate (D-08) requires
// all-fingers-up before any new touch is accepted on the new session.
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Rely on Windows press-and-hold for long-press right-click | Client-owned long-press with jitter deadband | Phase 3 (this phase) | Fixes the on-device root cause (jitter cancels Windows press-and-hold). |
| Local-gesture `xf_input_detect_pinch` PubSub zoom (framebuffer-only) | Not used on remote path; fallback pinch synthesizes Ctrl+wheel directly | N/A (was never remote) | Fallback pinch is new code, not a reuse of the local detector. |
| `cctx->contacts[]` intermediary regression (#9082) | Direct `freerdp_client_handle_touch` path (Phase 2 verified working) | Fixed pre-3.15 / Phase 2 confirmed | Phase 3 builds on the working direct path; do not reintroduce an intermediary. |

**Deprecated/outdated:**
- `MultiTouchInput` / `MultiTouchGestures` settings are marked `SETTINGS_DEPRECATED` [VERIFIED: settings_types_private.h:602-603] but still drive the remote/local path split. New Phase 3 settings should be non-deprecated additions, not replacements.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The wheel detent value `0x78` (120) is the standard RDP wheel step. | Code Examples (wheel) | Low — standard MS-RDP value; planner should read `xf_client.c:1051` button map verbatim to confirm the exact value used in this build. |
| A2 | `PTR_FLAGS_MOVE` alone (without a button flag) moves the pointer without a button press. | Code Examples (midpoint) | Low — pattern matches existing fallback motion at xf_input.c:717. Planner should verify by reading the `freerdp_client_send_button_event` body. |
| A3 | `KBD_FLAGS_RELEASE` is the flag name for key-up. | Code Examples (Ctrl) | Low — header shows `KBD_FLAGS_RELEASE` is defined at input.h:35; planner should read the exact macro. |
| A4 | Default long-press threshold ~600 ms and slop ~5-8 px are reasonable OneMix 3 starting values. | (planner discretion) | Medium — must be calibrated on-device; CONTEXT.md explicitly leaves calibration to planning. |
| A5 | The `0x78` and `PTR_FLAGS_WHEEL_NEGATIVE` combination is the exact encoding for wheel-down. | Code Examples (wheel) | Low — matches ARCHITECTURE.md citation of `xf_client.c:1051-1053`; planner must read that line range verbatim. |

## Open Questions

1. **Exact wheel detent value in this build**
   - What we know: `PTR_FLAGS_WHEEL` (0x0200) + `PTR_FLAGS_WHEEL_NEGATIVE` (0x0100) are the flag bits [VERIFIED: input.h:40-41]; the low byte is the detent magnitude.
   - What's unclear: whether this build uses 0x78 (120) or another value at `xf_client.c:1051`.
   - Recommendation: Planner adds a task to read `xf_client.c:1051-1053` verbatim and copy the exact wheel constants. Do not derive.

2. **Whether `rdpei->TouchCancel` on a single held contact (long-press) is safe without touching the second contact**
   - What we know: `TouchCancel` emits `UP|CANCELED` for one externalId [VERIFIED: rdpei_main.c:1202]; Phase 2 calls it per-contact in a loop.
   - What's unclear: whether cancelling one contact mid-two-finger-pinch confuses the RDPEI frame builder.
   - Recommendation: For long-press (single finger), TouchCancel is safe. For fallback pinch claiming (cancel the first contact when the second arrives), test on-device; if the frame builder complains, use `SuspendTouch`/`ResumeTouch` [VERIFIED: rdpei.h:92-93] around the suppression instead.

3. **Whether the long-press deadline check should live in a timer callback or inline in the TouchUpdate path**
   - What we know: D-01 says the client owns timing; a timer callback fires every 20 ms.
   - What's unclear: whether a 20 ms polling check or an inline "check GetTickCount64() on every TouchUpdate" is simpler and sufficient.
   - Recommendation: Inline check on TouchUpdate is simpler and avoids a new subscription — the deadline only needs to fire while the finger is down and updates are arriving. But if the finger is perfectly still (no updates after the jitter deadband suppresses them), the timer callback is needed to fire at threshold. Use BOTH: inline check on update + timer callback for the stationary case. Planner decides the exact split.

## Environment Availability

The build toolchain was verified in Phase 1 and the patched source already builds (Phase 2 UAT). No new external dependencies are introduced.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| dpkg-buildpackage | Rebuild patched .deb | ✓ | verified Phase 1 | — |
| gcc-14 / cmake | Compile patch | ✓ | verified Phase 1 | — |
| libxi-dev (WITH_XI) | XInput2 touch path | ✓ | verified Phase 1 | — |
| libxrender-dev (WITH_XRENDER) | Content-bounds gate | ✓ | verified Phase 1 | — |
| Native X11 session (gnome-xorg) | On-device testing | ✓ | verified Phase 1/2 | — |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** none.

## Security Domain

Security enforcement is enabled (config.json `security_enforcement: true`, ASVS level 1, block on high). This phase adds no new trust boundaries — it processes local X11 input from an already-trusted touchscreen and emits via already-audited FreeRDP input senders. No network parsing, no new channels, no config file parsing.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | N/A — no auth surface touched. |
| V3 Session Management | yes (reconnect) | Reconnect resets all gesture state via the existing teardown seam; no session token handling added. |
| V4 Access Control | no | N/A — no authorization surface. |
| V5 Input Validation | yes | Touch coordinates are already validated by Phase 2 content-bounds gate before forwarding; gesture state reads `event->detail`/`event_x/event_y` from the already-trusted X11 socket. No new untrusted input. |
| V6 Cryptography | no | N/A. |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Touch outside RDP window forwarded as in-window touch (input injection) | Tampering | Phase 2 content-bounds gate (xf_input.c:755-765) already rejects letterbox touches. Phase 3 gesture synthesis reuses the same adjusted coordinates. |
| Stale gesture state after disconnect → spurious input on reconnect | Tampering | D-15/D-16: extended `xf_touch_force_cancel` clears all gesture state on every lifecycle hook; reconnect never replays. |
| Stuck Ctrl modifier → every click becomes Ctrl+click | Tampering/Elevation | D-15: `ctrlHeld` flag + idempotent release in the single reset seam; every abort path routes through it. |
| Logging touch coordinates at INFO level (behavioral fingerprint) | Information Disclosure | Use `WLog_DBG` (DEBUG only) for gesture diagnostics; never INFO. Existing DIAG blocks use `WLog_DBG` [VERIFIED: xf_input.c:660]. |

## Sources

### Primary (HIGH confidence — read this session from the pinned source)
- `build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c:646-785` — `xf_input_touch_remote` native dispatch + Phase 2 fallback latch (insertion point).
- `build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c:792-829` — `xf_touch_force_cancel` (the reset seam to extend).
- `build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c:1009-1095` — `xf_input_handle_event_remote` recovery gate + dispatch.
- `build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c:416-455` — `xf_input_detect_pinch` (local-only, NOT reused).
- `build/freerdp3-3.15.0+dfsg/client/X11/xfreerdp.h:303-318` — xfContext touch fields (where new fields go).
- `build/freerdp3-3.15.0+dfsg/client/X11/xf_client.c:1609,1619,1693-1694` — 20 ms timer + `PubSub_OnTimer` publisher.
- `build/freerdp3-3.15.0+dfsg/client/X11/xf_disp.c:270,338` — `PubSub_SubscribeTimer` subscription pattern.
- `build/freerdp3-3.15.0+dfsg/client/X11/xf_client.c:805,1460-1473,1667` — lifecycle hooks + post_disconnect + auto_reconnect.
- `build/freerdp3-3.15.0+dfsg/client/X11/xf_event.c:712,844,956` — FocusOut/ConfigureNotify/UnmapNotify hooks.
- `build/freerdp3-3.15.0+dfsg/client/common/client.c:1590-1635,1652` — `freerdp_client_send_wheel_event`, `freerdp_client_send_button_event`.
- `build/freerdp3-3.15.0+dfsg/include/freerdp/input.h:31-46,104` — KBD/PTR flags + `freerdp_input_send_keyboard_event`.
- `build/freerdp3-3.15.0+dfsg/include/freerdp/scancode.h:71` — `RDP_SCANCODE_LCONTROL`.
- `build/freerdp3-3.15.0+dfsg/include/freerdp/client.h:255-262` — `freerdp_client_handle_touch` + `FreeRDPTouchEventType`.
- `build/freerdp3-3.15.0+dfsg/include/freerdp/client/rdpei.h:36-100` — `RdpeiClientContext` vtable (TouchBegin/Update/End/Cancel, SuspendTouch/ResumeTouch).
- `build/freerdp3-3.15.0+dfsg/include/freerdp/channels/rdpei.h:72-95` — `RDPINPUT_CONTACT_FLAGS` + valid combinations.
- `build/freerdp3-3.15.0+dfsg/include/freerdp/settings_types_private.h:602-603` — `MultiTouchInput`/`MultiTouchGestures` (insertion point for new settings).
- `build/freerdp3-3.15.0+dfsg/client/common/cmdline.c:1164-1173` — `multitouch`/`gestures` CLI cases (insertion point).

### Secondary (HIGH confidence — prior-phase artifacts)
- `.planning/research/ARCHITECTURE.md` — XInput2→RDPEI flow map, integration seams, anti-patterns.
- `.planning/research/PITFALLS.md` — #6566 long-press, #12174 race, #9082 intermediary, Pitfall 11 pinch overlap, reconnect teardown.
- `.planning/research/STACK.md` — pinned stack, reuse-without-adding-dependencies constraint, Ctrl+wheel gap.
- `.planning/phases/02-native-rdpei-touch-lifecycle/02-UAT.md` — on-device root cause: 1-3px jitter cancels Windows press-and-hold; native RDPEI path confirmed; forced-cancel verified on 5 hooks.
- `.planning/phases/02-native-rdpei-touch-lifecycle/02-REVIEW-FIX.md` — Phase 2 final cleanup shape; removed redundant canceledIds; DIAG blocks are temporary.
- `.planning/STATE.md` — Phase 2 complete, Phase 3 ready; long-press deadband is highest-value item.

## Project Constraints (from CLAUDE.md)

- **Platform**: Debian on OneMix 3 under X11 — only required v1 runtime. Phase 3 targets the native X11 session (`gnome-xorg.desktop`); no Wayland/Xwayland effort.
- **Integration**: Patch the existing FreeRDP X11 client — preserve RDP, fullscreen, keyboard, RDPEI machinery. No new daemon, no new channel, no duplicate RDPEI encoder.
- **Baseline**: Build against FreeRDP 3.15.0+dfsg-2.1+deb13u3 (already built in Phases 1-2).
- **Latency**: Gesture recognition must not add noticeable delay to ordinary touch input — long-press detection may delay only the action that requires disambiguation. D-01 satisfies this: native DOWN forwards immediately; only the right-click action waits for the threshold.
- **Calibration**: Long-press duration and pinch fallback must remain configurable. D-01/D-02/D-08 + new rdpSettings rows satisfy this.
- **Scope**: Implement the three selected gestures (long-press, native pinch, fallback pinch) before broader gesture support. Two-finger drag-to-wheel is deferred (CONTEXT.md).
- **No new dependencies**: No gesture library, no timer library, no config file parser. Use stdlib `math.h` + WinPR time + existing `PubSub_OnTimer`.
- **X11-only policy**: Keep gesture policy in `client/X11/`; do not modify `client/common/client.c` shared behavior for SDL/Wayland.
- **Quilt patch**: Final patch goes in `debian/patches/`; Phase 3 edits the build tree, the quilt patch is a Phase 4 packaging step.
- **GSD workflow**: No direct repo edits outside a GSD workflow. This research is produced under `/gsd-plan-phase --research-phase 3`.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all APIs verified by reading the pinned source this session.
- Architecture: HIGH — insertion points, reset seam, timer subscription, and lifecycle hooks all read and line-cited.
- Pitfalls: HIGH — root cause (jitter) confirmed in prior-phase on-device UAT; #6566/#12174/#9082 documented from FreeRDP tracker.
- Calibration values: MEDIUM — exact ms/slop/detent are planner/device-calibration decisions (CONTEXT.md discretion).

**Research date:** 2026-08-06
**Valid until:** stable (patch surface is pinned to 3.15.0; no upstream drift affects this phase)
# Pitfalls Research

**Domain:** FreeRDP X11 client touchscreen-input patch (XInput2 → RDPEI) on Debian/OneMix 3
**Researched:** 2026-08-05
**Confidence:** HIGH (grounded in upstream source code, merged PRs, and closed issues on the FreeRDP/FreeRDP tracker; Debian packaging from official Debian maintainer docs)

Device baseline confirmed on this host: `xfreerdp3` 3.15.0 (n/a), Debian package `freerdp3-x11` 3.15.0+dfsg-2.1+deb13u3 (Debian 13/trixie). Note: `$XDG_SESSION_TYPE=wayland` on this machine — the project targets X11, so an X11 session must be selected explicitly (see Pitfall 10).

## Critical Pitfalls

### Pitfall 1: Routing X11 touch through a broken intermediary that drops every event after touch-down

**What goes wrong:**
After the touch refactor in commit `d66b165`, `xf_input_touch_remote` stopped calling `rdpei->TouchBegin/TouchUpdate/TouchEnd` directly and instead routed all `XI_TouchBegin/Update/End` through `freerdp_client_handle_touch`. That helper depends on `cctx->contacts` (`FreeRDP_TouchContact[]`) plus a `cctx->contactsCount` that **no code path ever populates**. Result: the first `XI_TouchBegin` may land, but every subsequent `XI_TouchUpdate`/`XI_TouchEnd` hits the "no contact point" error path and is silently dropped. Multitouch, drag, and lift all stop working even though single taps sometimes register.

**Why it happens:**
A refactor introduced an abstraction layer (`freerdp_client_handle_touch` / `cctx->contacts`) to unify touch across clients, but the layer was never wired to the RDPEI contact store. The intermediate object looks like it owns state but is a dead array. This is the exact "interface with one implementation that doesn't implement anything" trap.

**How to avoid:**
- Keep the X11 → RDPEI path **direct**: call `rdpei->TouchBegin/TouchUpdate/TouchEnd` (or the equivalent current API) straight from `xf_input_touch_remote`. Do not insert a new `cctx->contacts` bookkeeping layer for v1 — RDPEI already owns contact state internally via `RDPINPUT_CONTACT_POINT` (`active`, `dirty`, `externalId`, `contactId`).
- If you must add an intermediary for gesture disambiguation, make it a *pure pass-through* for the RDPEI flags and never duplicate the contact ID map. The RDPEI channel is the single source of truth for contact state.
- When porting across FreeRDP versions, diff `client/X11/xf_input.c` against the version you build from. The fix for #9082 (PR #9084) reverted to direct calls; later PR #9086 ("Multitouch common") re-introduced a common path and re-broke things (cursor jumping, 1-finger-only drawing). Verify which code shape your 3.15.0 source actually has before patching.

**Warning signs:**
- First tap registers but drag/scroll does not move in the remote.
- `WLog` spam of "no contact point" / contact lookup failures during a drag.
- Multitouch works in an older FreeRDP build but not in yours after a "clean up" commit.
- Two-finger pinch reaches Windows as two independent single taps, not a simultaneous frame.

**Phase to address:**
Phase: XInput2 capture / RDPEI contact lifecycle. Prevent by deciding the call shape (direct vs. intermediary) in the SPEC before writing code; verify with a drag-then-lift trace on day one.

---

### Pitfall 2: RDPEI contact flags missing INRANGE / INCONTACT (invalid state transitions)

**What goes wrong:**
`MS-RDPEI` 2.2.3.3.1.1 only accepts specific flag combinations. The #9082 regression also showed touch motion encoded as bare `UPDATE` (should be `UPDATE | INRANGE | INCONTACT`) and touch-down as bare `DOWN` (should be `DOWN | INRANGE | INCONTACT`). Windows either ignores the malformed frame, misclassifies the contact, or shows the "touch circle turns to square" right-click emulation artifact. The `dirty` flag in the rdpei frame builder then prevents downstream correction, so the wrong flags stick.

**Why it happens:**
Developers map `TOUCH_DOWN → DOWN`, `TOUCH_MOTION → UPDATE`, `TOUCH_UP → UP` literally and forget the two state bits that MS-RDPEI requires to mark the contact as in-range and in-contact. The protocol silently rejects or misinterprets the frame; there is no loud error.

**How to avoid:**
- Hard-code the valid combinations in a single helper and route every contact through it:
  - DOWN   = `DOWN | INRANGE | INCONTACT`
  - UPDATE = `UPDATE | INRANGE | INCONTACT` (while finger is down)
  - UP     = `UP | INRANGE` (lifted but still tracked) or `UP` (out of range)
- Mirror the state machine in `channels/rdpei/client/rdpei_main.c`: ENGAGED ↔ HOVERING ↔ OUT_OF_RANGE, with the exact flag transitions documented there. Do not invent new transitions.
- Add an assert/self-check that fires if a contact is submitted with `UPDATE` but neither `INRANGE` nor `INCONTACT`.

**Warning signs:**
- Windows shows the press-and-hold right-click circle for normal drags.
- Touch works in some apps but not others (stricter parsers reject malformed frames).
- Contact "sticks" — Windows thinks the finger is still down after lift.

**Phase to address:**
Phase: RDPEI contact lifecycle. Prevent with a flag-combination unit test in the same phase.

---

### Pitfall 3: RDPEI race condition loses touch-up events (stale UP frame vs. new DOWN)

**What goes wrong:**
Issue #12174 (Jan 2026, fixed after 3.15.0): `rdpei_touch_process` reserves a contact (`rdpei_contact`, sets `active=TRUE`) inside a CriticalSection, then **releases the lock** before calling `rdpei_add_contact`. The update thread runs `rdpei_add_frame` in the window between, sees the stale `RDPINPUT_CONTACT_FLAG_UP` still in `data`, resets `active=FALSE`, and clears `externalId`/`contactId`. The subsequent `rdpei_add_contact` sets `dirty`, but `active` is already false — so future update/end events can no longer find the contact and are dropped. Symptom: held finger shows the right-click circle/rectangle, but releasing it opens no context menu because touch-up was lost.

**Why it happens:**
Releasing a lock between two dependent mutations of shared contact state. The lock guards "reserve" but not "publish," and the update thread is allowed to observe a half-published contact.

**How to avoid:**
- **Do not split contact reservation and contact publish across a lock boundary.** Call `rdpei_add_contact` *inside* the same CriticalSection that wraps `rdpei_contact`. All related state mutations under one lock acquisition.
- When backporting onto 3.15.0 (which predates the #12174 fix), you may be patching code that still has this race. Audit `rdpei_touch_process` / `rdpei_add_contact` / `rdpei_add_frame` in your exact source tarball before adding gesture logic on top.
- If you add any new contact-mutation path (e.g., a long-press timer that synthesizes an UP+DOWN), wrap the *entire* synthesis in one CriticalSection or you reintroduce the race for synthetic events.

**Warning signs:**
- Long-press circle appears but release does nothing (the #12174 signature).
- Intermittent: drag works, but fast tap-then-lift sometimes "sticks" on the remote.
- Pattern is timing-dependent — worse under load, better under valgrind/thread-sanitizer.

**Phase to address:**
Phase: RDPEI contact lifecycle (prevent by auditing the lock shape before adding timers); reconnection/grab stability phase (verify the synthetic UP path is also atomic).

---

### Pitfall 4: XInput2 touch ownership never accepted — events freeze or get stolen

**What goes wrong:**
`xf_input.c` never calls `XIAllowTouchEvents` and has no `XI_TouchOwnership` case. Per the XI 2.2 protocol, when a passive touch grab activates the grabbing client becomes owner and must explicitly `AcceptTouch` or `RejectTouch`. Without that, touch delivery is at the mercy of the window manager/compositor and other grabs. On some WMs the touch sequence freezes after `TouchBegin`; on others, ownership never transfers and `TouchUpdate`/`TouchEnd` never arrive. Compounding: passive touch grabs **do not freeze the device** like pointer grabs do, so delivery semantics are subtly different from what mouse-era code assumes.

**Why it happens:**
X11 mouse code "just works" without ownership because pointer grabs freeze the device. Touch grabs don't. Developers copy the mouse pattern and assume events flow automatically.

**How to avoid:**
- After selecting for `XI_TouchBegin/Update/End`, also select for `XI_TouchOwnership` if you need events before ownership. Decide explicitly: accept-on-begin (simplest, exclusive) or defer and handle `TouchOwnership`.
- Call `XIAllowTouchEvents(display, deviceid, touchid, grab_window, XIAcceptTouch)` at the right point (typically on `TouchBegin` for an exclusive client like a fullscreen RDP session).
- If you add a passive touch grab with `XIGrabTouchBegin`, set `grab_type = XIGrabtypeTouchBegin` and `grab_mode = XIGrabModeTouch` (the touch-specific mode), **not** `Synchronous`/`Asynchronous`.
- Test on the OneMix 3's actual WM (likely GNOME/Mutter or a lightweight WM under X11). Mutter's touch delivery differs from i3/openbox.

**Warning signs:**
- First touch works, subsequent touches in the same sequence don't.
- Touch works in windowed mode but freezes in fullscreen (grab behavior differs).
- Touch works on bare X11 but not when a compositing WM is running.
- `xinput test` shows events the application never receives.

**Phase to address:**
Phase: XInput2 capture. Prevent by selecting ownership events and calling `XIAllowTouchEvents` from the first prototype; verify with `xinput test` vs. application log side-by-side.

---

### Pitfall 5: Pointer emulation produces duplicate input (touch + synthetic mouse)

**What goes wrong:**
Direct touch devices emulate pointer events. A touch generates both `XI_TouchBegin` and an emulated `XI_ButtonPress`. If the patch forwards both, Windows sees a touch *and* a click at the same coordinate — double activation, menus open and immediately close, drag jumps. Per XI 2.2, when an emulated pointer event triggers a synchronous passive grab and the client replays it (`ReplayDevice`), the touch sequence is **rejected**; the interaction between the two is easy to get wrong.

**Why it happens:**
XInput2 delivers both event streams by default. Without an explicit `XISetMask` choice or grab mode that suppresses one, you process both.

**How to avoid:**
- Select for touch events and explicitly exclude emulated pointer events from your touch path, or detect and ignore the emulated pointer events when a touch sequence is active.
- Use the `XIPointerEmulated` flag (on `XI_Motion`/`XI_ButtonPress`) to identify and drop emulated events when you're already handling the touch.
- Decide once, in the SPEC, whether the RDP session is "touch-first" (RDPEI native, drop emulated pointer) or "mouse-first" (use pointer, ignore RDPEI). Mixing both per-event is the bug.

**Warning signs:**
- Single tap double-clicks on the remote.
- Drag selects text then immediately deselects.
- Pinch zoom also scrolls (wheel emulation + touch both fire).

**Phase to address:**
Phase: XInput2 capture. Prevent by choosing the emulation policy in the SPEC and asserting no emulated-pointer events reach RDPEI when touch is active.

---

### Pitfall 6: Touch ID reuse across sequences produces stale RDPEI contact mappings

**What goes wrong:**
`xf_input_touch_remote` uses `event->detail` (the XI2 tracking ID) verbatim as the RDPEI `externalId`. The X server **may reuse** a tracking ID after `XI_TouchEnd`. If the patch caches `externalId → contactId` beyond the sequence (e.g., in a gesture recognizer that outlives the touch), a new touch reuses an ID still mapped to a contact Windows thinks is "engaged," causing the state machine to misfire or `rdpei_contact` to return the wrong contact.

**Why it happens:**
Tracking IDs are only unique *within* a touch sequence, not globally. Code that treats them as stable handles across sequences is wrong.

**How to avoid:**
- Clear any local ID map the moment `XI_TouchEnd` is processed for that ID. Do not retain contact state past end-of-sequence.
- Let RDPEI own the `externalId → contactId` mapping (it already does, in `RDPINPUT_CONTACT_POINT.externalId`); don't maintain a parallel map in the gesture layer.
- If the gesture recognizer needs to track a contact across its lifetime, key it on a locally-generated monotonic handle, not the raw XI2 ID.

**Warning signs:**
- Second tap on the same spot misbehaves; tap elsewhere works.
- After a pinch, a subsequent single tap triggers pinch-style behavior.

**Phase to address:**
Phase: XInput2 capture / gesture recognizer. Prevent with a "clear on end" invariant in the recognizer and a unit test that reuses an ID.

---

### Pitfall 7: Coordinate/scaling pipeline is a black box — wrong scale, wrong origin, wrong axis

**What goes wrong:**
`xf_input_touch_remote` reads `event->event_x/event_y` and passes them through `xf_event_adjust_coordinates(xfc, &x, &y)`, whose implementation lives in another file and applies window offset, DPI, `/size`, `/bpp`, and rotation corrections. A patch that touches coordinates without auditing the full pipeline sends Windows touch at the wrong pixel (off by window border, off by scale factor, axis-swapped on rotation, or in the wrong quadrant for a multi-monitor setup). Subpixel-identical events also trip `xf_input_is_duplicate`, which compares with `fabs(...) < DBL_EPSILON` — fragile under rounding.

**Why it happens:**
The transform is split across files and is only correct for the *current* set of flags. Adding `/size:WxH` or changing fullscreen toggles the transform without the patch author noticing.

**How to avoid:**
- Read `xf_event_adjust_coordinates` and every flag it keys on (`/size`, `/scale`, `/dynamic-resolution`, fullscreen state, `Monitor`/`Monitors`) before touching coordinates.
- Test the coordinate pipeline end-to-end: tap the four corners and the center, verify the Windows cursor lands exactly there in `/size` windowed, fullscreen, and after a `/dynamic-resolution` resize.
- For rotation (OneMix 3 is a convertible — screen rotates), verify X and Y swap and one axis inverts; the `rotation`/`tilt` flags added in PR #9086 matter here.
- Do **not** compare floats with `DBL_EPSILON` for duplicate detection; use a small fixed epsilon (e.g., 0.5px) appropriate for subpixel touch.

**Warning signs:**
- Touch lands offset by a constant vector (window border / title bar height).
- Touch is correct in windowed mode but wrong in fullscreen, or vice versa.
- After rotating the device, X and Y are swapped or inverted.
- Identical consecutive events are dropped as "duplicate" when they're real.

**Phase to address:**
Phase: coordinate/scaling (own phase). Prevent by auditing the full transform pipeline in the SPEC and adding a corner-tap calibration check.

---

### Pitfall 8: Long-press right-click arrives too late and also fires an unwanted left-click

**What goes wrong:**
Issue #6566: tap-and-hold took ~4 seconds before right-click triggered; users expect <1s (project target 500–700ms). The Windows-side visual is a circle that appears, then a rectangle after the timeout, then the context menu *only on release*. A naive long-press implementation sends a left `DOWN` immediately on touch-down to keep latency low, then synthesizes a right-click on timeout — but Windows already received the left `DOWN`, so the "right-click" arrives as a left-drag + right-click, selecting text or opening then closing menus.

**Why it happens:**
Two conflicting requirements: (a) ordinary tap must be immediate (no delay waiting to disambiguate), and (b) long-press must *not* have already sent a left-click. The disambiguation window is unavoidable; the mistake is sending `DOWN` before the window elapses.

**How to avoid:**
- Hold the touch-down for the disambiguation window (500–700ms, configurable). Only after the window: if the finger is still down and hasn't moved beyond a movement threshold → synthesize right-click (send RDPEI/`UP` for the held contact, then a right-button `DOWN`/`UP` via the mouse path). If the finger lifted or moved → it was a tap/drag, deliver the original touch normally.
- This *intentionally* delays long-press action only; ordinary tap fires on lift (which is inside the window), so tap latency is unaffected. Document this trade-off — it's the one the project's latency constraint already calls out.
- Use a monotonic timer (`GetTickCount64`/`clock_gettime(CLOCK_MONOTONIC)`), not wall-clock, so suspend/resume doesn't fire false long-presses.
- Make the duration and movement threshold config knobs (PROJECT.md already requires this).

**Warning signs:**
- Right-click works but the selected item was already left-clicked/dragged.
- Long-press takes multiple seconds (hardcoded too high, like the #6566 ~4s).
- Suspend/resume triggers a spurious right-click.

**Phase to address:**
Phase: gesture recognizer (long-press). Prevent by designing the disambiguation state machine in the SPEC and asserting no left `DOWN` is sent before the window elapses.

---

### Pitfall 9: Reconnection segfaults because RDPEI/drdynvc state isn't torn down

**What goes wrong:**
Issue #4698: reconnecting with `+multitouch` active segfaulted in `drdynvc_virtual_channel_open_event_ex` calling `Stream_Free` on a dangling `wStream` — the drdynvc plugin's state wasn't cleaned up on disconnect, so a reconnection passed a stale stream pointer. More broadly, any contact state, timers, or grab registrations left active across a reconnect will reference freed memory.

**Why it happens:**
Dynamic virtual channels (drdynvc, which carries RDPEI) are torn down on disconnect, but in-flight stream data and the RDPEI contact array aren't invalidated. On reconnect the channel reinitializes but old pointers resurface.

**How to avoid:**
- On disconnect, clear all local contact state (gesture recognizer maps, long-press timers, XI2 grab registrations) and let RDPEI reinitialize its contact array from scratch on the new session.
- Do not retain `wStream` pointers or RDPEI context pointers across a reconnect. Re-fetch the context from the new `rdpei` plugin instance.
- Add a reconnect test to the hardware validation phase: connect, start a drag, pull network, reconnect, verify no crash and touch still works.

**Warning signs:**
- Segfault in `drdynvc`/`Stream_Free` on reconnect.
- Touch works on first session but is dead after reconnect.
- Valgrind reports invalid reads after a reconnect cycle.

**Phase to address:**
Phase: reconnection/grab stability. Prevent with an explicit teardown checklist on disconnect and a reconnect-during-drag test.

---

### Pitfall 10: Building/testing under Wayland while targeting X11

**What goes wrong:**
This machine reports `XDG_SESSION_TYPE=wayland`, but the project explicitly targets X11. Building and testing under Wayland means XInput2 touch events route through XWayland, which has different (and historically buggier) touch delivery than native X11. Bugs filed under XWayland get dismissed as "Wayland issue, not us"; behavior passes here but fails on a true X11 session, or vice versa.

**Why it happens:**
Debian 13 defaults to a Wayland session on many setups; the developer doesn't notice the session type.

**How to avoid:**
- At project start, log out and select the X11 session at the display manager (or run `startx` with an `.xinitrc`). Confirm with `echo $XDG_SESSION_TYPE` == `x11` before any testing.
- Capture `xinput list`, `xinput list-props <touch device>`, `libinput list-devices`, and the exact `xfreerdp3` launch command *under the X11 session* — this is the PROJECT.md "before implementation" capture step.
- Treat XWayland as a separate test target, not the primary one. If you must test under XWayland, label it explicitly.

**Warning signs:**
- Touch works in `xinput test` but not in `xfreerdp3`, under XWayland.
- Behavior differs between this machine and the OneMix 3's native X11 session.
- `xinput` shows the device but `XI_TouchOwnership` events never arrive (XWayland touch ownership handling).

**Phase to address:**
Phase 0 / environment capture (the very first phase). Prevent by verifying session type before any code is written.

---

### Pitfall 11: Pinch fallback to Ctrl+wheel fires both native touch and wheel zoom

**What goes wrong:**
The project wants native multitouch pinch by default with a configurable `Ctrl + wheel` fallback for apps that don't handle touch zoom. PR #9086 testing showed pinch zoom didn't work in some apps (PowerPoint) and the SDL/X11 clients had cursor jumping. The fallback is easy to get wrong: if native RDPEI touch is still active while you synthesize `Ctrl + wheel`, the app receives *both* and zoom jumps or oscillates. Worse, the local gesture path (`xf_input_detect_pinch` with `ZOOM_THRESHOLD`) and the remote RDPEI path are mutually exclusive (`FreeRDP_MultiTouchInput` vs `FreeRDP_MultiTouchGestures`), so a "fallback" that toggles mid-gesture loses the contact state.

**Why it happens:**
Two input modes that the client treats as exclusive, plus a fallback that tries to use both. The mode switch has to happen *before* the gesture starts, not mid-gesture.

**How to avoid:**
- Make the fallback a **launch-time or per-app setting**, not a mid-gesture switch. When fallback is on, the pinch takes the local-gesture path (`FreeRDP_MultiTouchGestures`, `xf_input_detect_pinch`) and synthesizes `Ctrl + wheel` via the existing keyboard/mouse path; RDPEI native is off for that gesture. When fallback is off, the pinch goes native RDPEI.
- Never send RDPEI touch contacts and a synthetic `Ctrl + wheel` for the same gesture.
- Reuse `ZOOM_THRESHOLD` / the existing pinch detector rather than reinventing it; the local path already computes pinch delta.
- Verify per target app: test pinch in an app known to handle touch zoom (Maps/Photos) and one that doesn't (a desktop app expecting `Ctrl + wheel`).

**Warning signs:**
- Pinch zoom overshoots or oscillates (both inputs firing).
- Pinch works in one app but is ignored in another (mode mismatch).
- After a pinch, single-touch behaves wrong (mode didn't reset).

**Phase to address:**
Phase: gesture recognizer (pinch). Prevent by choosing the mode-selection design in the SPEC and asserting the two paths never run concurrently.

---

### Pitfall 12: Debian patch rots / breaks on upstream upgrade

**What goes wrong:**
The patch is built against `freerdp3-x11` 3.15.0+dfsg-2.1+deb13u3. When Debian pushes a point release (e.g., 3.15.1 or a security update), the quilt patch may fail to apply because the surrounding lines in `xf_input.c` changed. Or the patch applies but reintroduces a bug that upstream already fixed differently (e.g., you re-add the #9082 intermediary that upstream removed). The user reinstalls the stock `.deb` and loses all touch work, or the patched `.deb` fails to install.

**Why it happens:**
FreeRDP's X11 touch code is actively being refactored (PR #9086 and follow-ups). A downstream patch that touches the same functions will conflict on the next upstream merge. There's also the risk of double-applying an upstream fix that your patch also fixed locally.

**How to avoid:**
- Maintain the patch as a **quilt patch** in `debian/patches/` (the Debian-native way), not as a forked git branch. Use `quilt new` / `quilt edit` / `quilt refresh`.
- Keep the patch **minimal and localized**: touch only the smallest functions needed (e.g., `xf_input_touch_remote`, the gesture detector). Avoid large rewrites that maximize conflict surface.
- Track the upstream commit your patch is based on; on each Debian upgrade, `apt source freerdp3`, `quilt push -a`, resolve conflicts, and re-test the three core gestures. Document the upstream commit hash in the patch header.
- Watch the FreeRDP issue tracker for touch-area PRs that overlap your patch; if upstream fixes the same problem, drop your patch and use theirs.
- Pin the build-dep version in your build notes so a build-dependency change doesn't silently break the build.

**Warning signs:**
- `quilt push` fails on a new upstream version.
- A security update to `freerdp3-x11` lands and the user's patched build no longer reinstalls cleanly.
- Your patch reintroduces a bug upstream fixed (regression after upgrade).

**Phase to address:**
Phase: Debian packaging. Prevent by adopting quilt from the start and recording the upstream base commit; re-verify on each upstream bump.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Skip `XIAllowTouchEvents` / ownership handling | Fewer lines, works on a permissive WM | Touch freezes on stricter WMs or fullscreen; unreproducible on dev machine | Never for v1 — ownership is the X11 touch contract |
| Use `event->detail` (XI2 tracking ID) as a stable handle across sequences | No local ID generation | Stale mappings on ID reuse (Pitfall 6) | Never — clear on `TouchEnd` |
| Hardcode long-press duration (no config) | Ship faster | Can't tune for physical touchscreen variance; repeats #6566 | Never — PROJECT.md requires configurability |
| Re-add `cctx->contacts` intermediary for "cleanliness" | Looks architecturally tidy | Reintroduces #9082 dead-array bug | Never — RDPEI owns contact state |
| Send left `DOWN` immediately on touch-down to cut tap latency | Tap feels instant | Long-press also left-clicks (Pitfall 8) | Only for pure tap (lift inside disambiguation window) |
| Fork FreeRDP git branch instead of quilt patch | Familiar git workflow | Patch rots against Debian's quilt-based packaging; reinstall loses it | Never for this project — use quilt |
| Compare float coords with `DBL_EPSILON` for dedup | Copy existing code | Real subpixel events dropped | Never — use a fixed ~0.5px epsilon |
| Test only under XWayland | No session switch needed | False pass/fail vs native X11 on OneMix 3 | Never — test on the real X11 session |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| XInput2 (XI 2.2) | Treating touch grabs like pointer grabs (expecting device freeze) | Touch grabs don't freeze the device; use `XIGrabModeTouch`, accept/reject explicitly |
| XInput2 ownership | Never selecting `XI_TouchOwnership`, never calling `XIAllowTouchEvents` | Select for ownership if you need pre-ownership events; accept on `TouchBegin` for exclusive fullscreen |
| Pointer emulation | Processing both `XI_Touch*` and emulated `XI_ButtonPress` | Use `XIPointerEmulated` flag to drop emulated events when touch is active |
| RDPEI channel (MS-RDPEI) | Submitting `UPDATE` without `INRANGE|INCONTACT` | Use the full valid flag combinations from the protocol spec |
| drdynvc / reconnect | Retaining stream/context pointers across disconnect | Clear all RDPEI + gesture state on disconnect; re-fetch context on new session |
| FreeRDP gesture routing | Toggling `MultiTouchInput` vs `MultiTouchGestures` mid-gesture | Choose mode at launch/per-app; never switch mid-gesture |
| Debian packaging | Editing source in place, no quilt | `quilt new`/`quilt edit`/`quilt refresh`; keep patches in `debian/patches/` |
| OneMix 3 rotation | Assuming fixed X/Y axis mapping | Re-verify coordinate transform after screen rotation; use PR #9086 rotation flags |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Long-press disambiguation window applied to ordinary tap | Tap feels sluggish | Only delay the long-press *action*; tap fires on lift inside the window | Any tap latency > 100ms is user-visible |
| Per-event float dedup with `DBL_EPSILON` | Real subpixel motion dropped, scroll stutters | Fixed ~0.5px epsilon; or dedup by event sequence number, not coords | High-DPI / subpixel touch devices |
| Lock held across RDPEI network send | Input stalls waiting for network | Build the frame under the lock, send outside it | Network latency > a few ms |
| Gesture recognizer reallocates contact map per event | GC/alloc jitter, input jitter | Fixed-size contact array (MAX_CONTACTS=64 already exists) | Sustained multitouch |
| Re-sending full contact state every frame | Bandwidth / latency on slow RDP | Send only `dirty` contacts (rdpei already does this — preserve it) | Low-bandwidth RDP link |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Not validating XI2 touch coordinates against window bounds before forwarding | Touch outside RDP window reaches remote as in-window touch (input injection) | Clamp/validate `event_x/event_y` against the RDP window geometry before RDPEI submit |
| Retaining touch contact data after session disconnect | Stale pointers → UAF on reconnect (Pitfall 9) | Tear down all contact state on disconnect |
| Accepting touch from any XI2 device without device-class check | Non-touch devices routed as touch → input spoofing | Verify `XITouchClass` on the device before forwarding as RDPEI |
| Logging full touch coordinates at INFO level | PII / behavioral fingerprinting via logs | Log coordinates only at DEBUG; redact in default config |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Long-press also left-clicks | Selections appear, menus flicker | Disambiguation window holds the DOWN; see Pitfall 8 |
| Right-click only on release, not on timeout | Context menu feels delayed | Fire right-click at end of the long-press window, not on lift |
| Pinch fallback mid-gesture | Zoom jumps then dead-responds | Mode chosen at launch; no mid-gesture switch (Pitfall 11) |
| Touch offset by window border | Every tap lands shifted | Audit `xf_event_adjust_coordinates` (Pitfall 7) |
| No visible feedback during long-press | User doesn't know if hold registered | Optional local visual; keep the Windows-side circle/rectangle cue |
| Grab locks mouse in fullscreen, can't escape | User trapped in RDP session | Preserve existing xfreerdp grab toggle / hotkey; document it |

## "Looks Done But Isn't" Checklist

- [ ] **Tap:** Verify tap *lift* (not just down) reaches Windows as `UP | INRANGE` — often missing.
- [ ] **Drag:** Verify `UPDATE | INRANGE | INCONTACT` frames flow for the whole gesture — not just the first motion event.
- [ ] **Multi-finger:** Verify two simultaneous contacts arrive in the *same* RDPEI frame with distinct `contactId`s — not two separate frames.
- [ ] **Long-press:** Verify no left `DOWN` was sent before the right-click synthesizes — check the remote didn't receive a click.
- [ ] **Pinch:** Verify in an app that *doesn't* support touch zoom that `Ctrl + wheel` fires — and that native RDPEI touch does *not* fire concurrently.
- [ ] **Coordinate:** Verify four-corner + center tap lands exactly on the Windows cursor — in windowed and fullscreen.
- [ ] **Rotation:** Verify touch still lands correctly after rotating the OneMix 3 screen.
- [ ] **Reconnect:** Verify no crash and touch still works after a network drop mid-drag.
- [ ] **Reinstall:** Verify `dpkg -i` of the stock `freerdp3-x11` deb removes the patch and restores default behavior (rollback path).
- [ ] **Session:** Verify `XDG_SESSION_TYPE=x11` during all testing — not XWayland.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Broken intermediary (#9082 regression) | LOW | Revert `xf_input_touch_remote` to direct `rdpei->Touch*` calls; re-test drag. |
| RDPEI race (#12174) | MEDIUM | Move `rdpei_add_contact` inside the CriticalSection; backport the upstream fix shape; add a thread-sanitizer run. |
| Touch ownership freeze | MEDIUM | Add `XIAllowTouchEvents(XIAcceptTouch)` on `TouchBegin`; add `XI_TouchOwnership` case; re-test on target WM. |
| Pointer emulation duplicates | LOW | Drop emulated pointer events via `XIPointerEmulated` flag; re-test tap. |
| Stale touch ID mapping | LOW | Clear local map on `XI_TouchEnd`; switch to locally-generated handles. |
| Coordinate/scale wrong | MEDIUM | Audit `xf_event_adjust_coordinates` and all `/size` `/scale` flags; add corner-tap calibration. |
| Long-press also left-clicks | MEDIUM | Redesign disambiguation state machine; hold DOWN until window elapses. |
| Reconnect segfault | HIGH | Full teardown on disconnect; re-fetch RDPEI context on new session; add reconnect test. |
| Built under Wayland | LOW | Switch to X11 session; re-capture environment; re-test. |
| Debian patch rot | MEDIUM | `quilt pop`, re-`apt source`, `quilt push -a`, resolve conflicts, re-test three gestures. |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| 10. Built under Wayland | Phase 0: Environment capture | `echo $XDG_SESSION_TYPE` == `x11` recorded before any code |
| 4. Touch ownership not accepted | Phase 1: XInput2 capture | `xinput test` events match application log through a full drag; `XIAllowTouchEvents` called |
| 5. Pointer emulation duplicates | Phase 1: XInput2 capture | No emulated `XI_ButtonPress` reaches RDPEI when touch active |
| 6. Touch ID reuse | Phase 1: XInput2 capture | Unit test reuses an ID after `TouchEnd`; no stale mapping |
| 7. Coordinate/scaling black box | Phase 2: Coordinate/scaling | Four-corner + center tap lands on Windows cursor; windowed + fullscreen + rotated |
| 1. Broken intermediary (#9082) | Phase 3: RDPEI contact lifecycle | Drag-then-lift trace shows all events delivered; no "no contact point" log |
| 2. RDPEI flag combinations | Phase 3: RDPEI contact lifecycle | Assert every contact has valid `INRANGE|INCONTACT` flags; state machine matches MS-RDPEI |
| 3. RDPEI race (#12174) | Phase 3: RDPEI contact lifecycle | Thread-sanitizer run; long-press release opens context menu reliably |
| 8. Long-press also left-clicks | Phase 4: Gesture recognizer | Long-press fires right-click with no prior left `DOWN` on remote; duration 500–700ms configurable |
| 11. Pinch fallback double-fires | Phase 4: Gesture recognizer | In a non-touch-zoom app, `Ctrl + wheel` fires and RDPEI touch does not; mode chosen at launch |
| 9. Reconnect segfault | Phase 5: Reconnection/grab stability | Reconnect mid-drag: no crash, no UAF, touch works after |
| 12. Debian patch rot | Phase 6: Debian packaging | `apt source freerdp3` + `quilt push -a` succeeds; reinstall stock deb rolls back; upstream commit recorded |

## Sources

- FreeRDP issue #9082 — multitouch regression from `d66b165`, broken `cctx->contacts` intermediary: https://github.com/FreeRDP/FreeRDP/issues/9082
- FreeRDP issue #12174 — lost touch events / race in `rdpei_touch_process` vs `rdpei_add_frame`: https://github.com/FreeRDP/FreeRDP/issues/12174
- FreeRDP issue #6566 — tap-and-hold right-click takes ~4s (long-press timing): https://github.com/FreeRDP/FreeRDP/issues/6566
- FreeRDP issue #4698 — reconnect with multitouch segfaults in drdynvc/`Stream_Free`: https://github.com/FreeRDP/FreeRDP/issues/4698
- FreeRDP issue #8253 — support normal touch-screen interaction (original idea brief): https://github.com/FreeRDP/FreeRDP/issues/8253
- FreeRDP issue #7721 / #8084 — multitouch not working regressions; `git bisect` to `650a275`: https://github.com/FreeRDP/FreeRDP/issues/7721, https://github.com/FreeRDP/FreeRDP/issues/8084
- FreeRDP PR #9086 — "Multitouch common" refactor (rotation/tilt, raw events; testing showed pinch/pen bugs): https://github.com/FreeRDP/FreeRDP/pull/9086
- FreeRDP RDPEI client source (`channels/rdpei/client/rdpei_main.c`) — contact state machine, `MAX_CONTACTS`, `externalId`/`contactId`, frame ordering: https://github.com/FreeRDP/FreeRDP/blob/6562b6f8/channels/rdpei/client/rdpei_main.c
- FreeRDP RDPEI header (`include/freerdp/channels/rdpei.h`) — contact flag enum and valid combinations: https://github.com/FreeRDP/FreeRDP/blob/6562b6f8/include/freerdp/channels/rdpei.h
- FreeRDP X11 client source (`client/X11/xf_input.c`) — `xf_input_touch_remote`, `event->detail` as `externalId`, `xf_event_adjust_coordinates`, `xf_input_is_duplicate` (`DBL_EPSILON`), local pinch/pan detectors: https://github.com/FreeRDP/FreeRDP/blob/6562b6f8/client/X11/xf_input.c
- X.org XI2 protocol spec (v2.3) — touch ownership, `XIAllowTouchEvents`, passive grabs don't freeze, pointer emulation: https://www.x.org/releases/current/doc/inputproto/XI2proto.txt
- X.org Multitouch internals — listener states, `TouchPendingEnd`, ownership replay: https://x.org/wiki/Development/Documentation/Multitouch/
- `XIGrabTouchBegin` man page — `XIGrabModeTouch` requirement: https://man.archlinux.org/man/extra/libxi/XIGrabTouchBegin.3.en
- Debian Maintainer's Guide ch.6 — quilt patches in `debian/patches/`: https://www.debian.org/doc/maint-guide/build.en.html
- Raphaël Hertzog — preparing patches for Debian packages (quilt workflow): https://raphaelhertzog.com/2011/07/04/how-to-prepare-patches-for-debian-packages/
- Unix StackExchange — maintaining local patches to Debian packages across upgrades: https://unix.stackexchange.com/questions/404213/what-is-the-recommended-way-to-maintain-local-patches-to-debian-packages
- `xfreerdp3 --version` on this host: 3.15.0 (n/a); `dpkg -l`: `freerdp3-x11` 3.15.0+dfsg-2.1+deb13u3 (Debian 13/trixie)

---
*Pitfalls research for: FreeRDP X11 touchscreen-input patch on Debian/OneMix 3*
*Researched: 2026-08-05*
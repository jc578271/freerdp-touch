# Feature Research

**Domain:** X11 touchscreen-input patch for `xfreerdp3` (RDP client, OneMix 3 / Debian)
**Researched:** 2026-08-05
**Confidence:** HIGH for behavior/categorization, MEDIUM for implementation complexity (depends on exact installed source version)

## Feature Landscape

This landscape is narrowed by PROJECT.md: v1 is one device, one runtime (Debian/X11), three gestures. Anything that does not serve daily touch use of a Windows RDP session on the OneMix 3 is deferred or excluded. The dominant reference for "expected" touch behavior is Microsoft's own Remote Desktop / Windows App gesture model, because that is the experience the user is benchmarking against.

A key structural fact drives the categorization: FreeRDP already exposes the RDPEI channel and an X11 touch path (`client/X11/xf_input.c`, `client/common/client.c`, `touch_contact` struct in `client/X11/xfreerdp.h`). The `+multitouch` flag already exists (default: off). So several "table stakes" items are really "make the existing path correct and on by default" rather than greenfield work — but correctness is where the known regressions live (issues #9082, #12174, #7759, #6566).

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = the patch is not a daily-use touch client.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| One-finger native touch/drag over RDPEI | A finger must act on the remote screen the same way a mouse does. This is the entire premise. | MEDIUM | Existing `+multitouch`/RDPEI path must produce complete, correctly ordered contact events: `TouchBegin` → `TouchUpdate`(s) → `TouchEnd`, each with a stable persistent `contactId`, in a frame, with `frameId` and a frame-complete commit. Known regressions (#9082 bisected to `d66b165`, #12174 race in `rdpei_touch_process` vs `rdpei_add_frame`) must be re-verified against the installed Debian source version — they may or may not be present. |
| Contact cancellation / clean contact lifecycle | Lift the finger, or cancel, and the remote must see the contact leave. Dangling contacts = stuck buttons, frozen scroll, ghost touches. | MEDIUM | On `XI_TouchEnd` AND on window unfocus / gesture abort, emit `TouchEnd` for every outstanding `contactId`. Issue #12174 is exactly this class of bug (lost events from ordering). Without this, the session drifts into a broken state within minutes. |
| Coordinate transform to remote desktop pixels | A tap must land under the finger, not offset. | LOW–MEDIUM | `XIDeviceEvent` provides `root_x/root_y` (screen), `event_x/event_y` (event window), and child-relative coords. The X server already applies the device Coordinate Transformation Matrix, so for the OneMix 3 the main concern is mapping event-window coords → FreeRDP output surface coords, including rotation/scale and fullscreen vs windowed. Mismatch here produces touches landing in the wrong place — a common X11 touchscreen pitfall. |
| Long-press right-click (no phantom left-click) | Right-click is the single most-used secondary action; a long press is the universal touch idiom for it. Microsoft's Direct Touch mode uses tap-and-hold-then-release. | MEDIUM | Configurable 500–700 ms. Must NOT also fire a left click on release. Standard pattern: arm a timer on `TouchBegin`, cancel on movement beyond a slop radius (React Aria/Android use touch-slop; `evdev-right-click-emulation` uses ~100px fuzz), cancel on `TouchEnd` before threshold. On threshold fire: synthesize right-button down+up at the contact point, set a `suppress-next-click` flag, clear it on the next genuine `TouchBegin` (not on a timer — timer cleanup races). Issue #6566 is the canonical FreeRDP regression (long press took ~4s); the fix pattern is in PR #6569. |
| Two-finger pinch (native multitouch by default) | Pinch-to-zoom is a reflex action on touchscreens; missing it reads as broken. | MEDIUM | Default: forward both contacts as native RDPEI so Windows/apps that handle touch zoom (Edge, Maps, Photos, Office modern) get real multitouch. Requires the RDPEI path from row 1 to actually deliver two simultaneous contacts with distinct persistent IDs — exactly the area of the #9082 regression. |
| Pinch fallback to `Ctrl` + mouse wheel | Many desktop apps (Explorer, classic Office, most LOB apps) do not handle touch zoom and only respond to `Ctrl+wheel`. Without fallback, pinch appears to do nothing in those apps. | MEDIUM | Configurable. When enabled, a two-finger gesture is interpreted locally as a pinch and emitted as `Ctrl` key down + vertical wheel events + `Ctrl` up. Must release `Ctrl` cleanly even if a finger lifts mid-gesture. Conflicts with native pinch — only one mode active at a time (config switch, not auto-detect in v1). |
| `+multitouch` on by default for the launch config | A user should not have to discover a flag to get touch. | LOW | Documented launch wrapper / config sets `+multitouch`. Provide an explicit `-multitouch` escape hatch for users who want mouse-only behavior. |
| Fullscreen and windowed stability under touch | The session must not crash, hang, or lose touch after toggling fullscreen, grabbing keyboard, or alt-tabbing back. | MEDIUM | Touch events must survive focus changes: re-assert `XISelectEvents` on the right window after fullscreen toggle, cancel outstanding contacts on unfocus, and not deliver touches to a stale window. Hotplug of touch device mid-session is a known RDPEI gap (#7759) — out of scope for v1 but must be documented as a known limitation. |
| Debian `.deb`, build, install, rollback, launch config | The user must be able to install and uninstall safely; otherwise the patch is not usable. | MEDIUM | Build against the installed FreeRDP version. Provide a `.deb` and a documented rollback (reinstall stock package). Launch config is a wrapper script or desktop file invoking `xfreerdp3` with the right flags. |
| Diagnostics / observability | Touch bugs are silent: a missing `TouchEnd` is invisible to the user. v1 needs enough logging to triage. | LOW | Env-var-gated debug log: per-contact lifecycle (begin/update/end with `contactId`, x/y, frame commit), gesture decisions (long-press armed/cancelled/fired, pinch native vs fallback), and RDPEI frame submission. Off by default; zero overhead when off. |

### Differentiators (Competitive Advantage)

Features that set this patch apart from stock `xfreerdp3` and from Microsoft's Windows App on Android. Not required for v1 daily use, but they are where this project competes.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Configurable long-press duration and pinch-fallback mode | Physical touchscreen timing and per-app zoom behavior vary. Microsoft's client offers no such knobs. | LOW | Expose via env vars or a small config file: `LONG_PRESS_MS`, `PINCH_MODE=native\|ctrl-wheel`. This is cheap and high-value; borderline table-stakes given PROJECT.md makes calibration a constraint. |
| Pinch mode switchable at runtime | Switch native ↔ `Ctrl+wheel` without reconnecting, for users who live in mixed touch/classic apps. | MEDIUM | v2 candidate. Requires a hotkey or on-screen toggle and a clean transition that cancels any in-flight gesture. |
| Direct Touch ↔ Mouse Pointer auto-switch | Mirror Microsoft's two modes, optionally auto-select by app hint. | HIGH | Microsoft keeps this as a manual toggle (and recently stopped persisting the choice, a long-standing complaint). Auto-switching reliably is a research problem (no reliable "is this app touch-aware" signal over RDP). Defer to v2+; for v1 the patch is effectively a Direct Touch implementation. |
| Three-finger swipe → `Alt+Tab` | Quick window switching in the remote session. | MEDIUM | Conflicts with anything else three fingers might do; needs gesture arbitration. PROJECT.md explicitly defers this until the three core gestures are dependable. v2. |
| Win-key / `Alt+Tab` capture into remote | Keep these keys inside the session instead of letting the Linux WM eat them. | MEDIUM | Already partially handled by FreeRDP keyboard grab; the touch-layer addition is a gesture that triggers them. v2. |
| Per-app gesture profile | Remember that app X gets `Ctrl+wheel` pinch and app Y gets native pinch. | HIGH | Needs a profile store and window-title/exe detection over RDP. v2+. |
| Generalization to other Linux touchscreens | Broader device support. | HIGH | v1 is OneMix 3 only by design. Generalize only after v1 is stable and after collecting data from a second device. |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems. Deliberately excluded per PROJECT.md or by evidence.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Standalone `/dev/input`/`uinput` gesture daemon | Easy to write; no FreeRDP source changes; works with stock Debian package. | Cannot deliver native RDPEI contacts — it can only synthesize mouse/keyboard via uinput, losing real multitouch semantics and adding a second input layer that races with X11/libinput. Directly contradicts the native-touch goal. | Patch `xfreerdp3` directly to keep the native RDPEI path. |
| A new RDP client / protocol implementation | "Just build the touch client we want." | Massively larger scope; reimplements transport, rendering, RDPEI, fullscreen, keyboard grab. PROJECT.md excludes this explicitly. | Extend the existing FreeRDP client. |
| Full parity with Microsoft Windows App gesture algorithms | Users benchmark against Windows App. | Microsoft's gesture algorithms are private and undocumented; exact emulation is not achievable and not required for daily use. | Implement the three core gestures well; document that exact parity is not a goal. |
| Wayland-native input support | "Modern Linux is Wayland." | v1 target is the confirmed X11 path on the OneMix 3. A Wayland path is a separate input stack (libinput touch events, no XInput2) and doubles the surface area. | X11 now; Wayland only if the user moves to a Wayland session. |
| Three-finger gestures, `Alt+Tab`, Win-key interception in v1 | Power-user convenience. | Adds gesture arbitration complexity before the three core gestures are dependable; risk of shipping v1 with all four gestures shaky. | Defer to v2+ once core gestures are stable. |
| Auto Direct Touch / Mouse Pointer switching | Microsoft does it (badly). | No reliable signal over RDP for "is the focused app touch-aware"; auto-switching will guess wrong and feel broken. | v1 ships Direct Touch behavior; switching is an explicit v2 toggle. |
| General "support every Linux touchscreen" in v1 | Open-source instinct to generalize. | Calibration, coordinate matrices, and device quirks vary; generalizing before one device is solid spreads risk. | OneMix 3 only for v1; generalize after. |
| Upstream-ready PR as the v1 deliverable | "Contribute it back." | Upstream bar (cross-platform, multi-device, code style, tests) is far higher than a daily-use patch for one device; chasing it inflates v1 scope. | Maintainable Debian patch now; upstream PR as a later milestone. |
| On-screen keyboard / Touch Pointer overlay | Microsoft ships one. | Out of scope for an input patch; FreeRDP/DE already provide OSK paths. | Rely on the DE's on-screen keyboard. |

## Feature Dependencies

```
[RDPEI native touch/drag (correct, complete contacts)]
    └──requires──> [Coordinate transform to RD surface]
    └──requires──> [Contact cancellation / clean lifecycle]
    └──requires──> [+multitouch enabled in launch config]

[Two-finger pinch native]
    └──requires──> [RDPEI native touch/drag]  (same multi-contact RDPEI path)

[Two-finger pinch Ctrl+wheel fallback]
    └──independent of RDPEI; uses existing mouse/keyboard path
    └──conflicts──> [Two-finger pinch native]  (only one mode active at a time)

[Long-press right-click]
    └──independent of RDPEI; synthesizes right-button events
    └──interacts──> [RDPEI native touch/drag]  (must suppress the native tap that would otherwise follow a fired long press)

[Fullscreen/windowed stability]
    └──requires──> [Contact cancellation]  (cancel on unfocus/window change)

[Debian .deb + launch config]
    └──requires──> [All v1 features frozen]

[Diagnostics]
    └──enhances──> [Every other feature]  (debuggability)

[Direct Touch ↔ Mouse Pointer auto-switch]  (v2)
    └──conflicts──> [Pure Direct Touch v1 model]

[Three-finger swipe → Alt+Tab]  (v2)
    └──requires──> [Gesture arbitration layer]  (so 2-finger and 3-finger don't collide)
```

### Dependency Notes

- **Native pinch requires the native touch path.** If RDPEI multi-contact delivery is broken on the installed version (re-verify #9082/#12174), native pinch is broken too; the `Ctrl+wheel` fallback is the safer first milestone because it uses only the mouse/keyboard path.
- **Long-press interacts with native touch.** When long-press fires, the contact that armed it must not also be delivered as a native tap. Either suppress the RDPEI `TouchEnd`-as-tap, or run long-press detection upstream of RDPEI routing so the contact is consumed by the gesture. This is the load-bearing design decision.
- **Pinch native and pinch fallback conflict.** They share the same two-finger input. v1 picks one via config; v2 may switch at runtime.
- **Diagnostics is foundational, not a nice-to-have.** Touch bugs are silent without it; ship it with v1.

## MVP Definition

### Launch With (v1)

Minimum viable product — what validates the daily-use premise on the OneMix 3.

- [ ] One-finger native touch/drag over RDPEI with complete, ordered contact events — this is the premise.
- [ ] Contact cancellation on lift/unfocus/abort — without it the session breaks within minutes.
- [ ] Coordinate transform correct under fullscreen and windowed — touches land under the finger.
- [ ] Long-press right-click (500–700 ms, configurable), no phantom left-click — the highest-frequency secondary action.
- [ ] Two-finger pinch, native by default, with a `Ctrl+wheel` fallback config — zoom must work in both touch-aware and classic apps.
- [ ] `+multitouch` on in the launch config, with a documented escape hatch.
- [ ] Fullscreen/windowed stability under touch — no crash, no stale contacts on focus changes.
- [ ] Debian `.deb` + documented build/install/rollback + launch wrapper — installable and reversible.
- [ ] Env-var-gated diagnostics log — necessary to triage the inevitable touch regressions.

### Add After Validation (v1.x)

Once v1 is in daily use on the OneMix 3.

- [ ] Runtime pinch-mode switch (native ↔ `Ctrl+wheel`) — trigger: user tires of editing config.
- [ ] Long-press duration / slop radius profile per app — trigger: one app's long press feels too quick/slow.
- [ ] Hotplug of touch device mid-session — trigger: user docks/undocks; depends on upstream #7759 progress.

### Future Consideration (v2+)

Defer until core is dependable and product-market fit is established on the device.

- [ ] Direct Touch ↔ Mouse Pointer auto-switch — defer: no reliable app-awareness signal over RDP.
- [ ] Three-finger swipe → `Alt+Tab`, Win-key / `Alt+Tab` capture into remote — defer: gesture arbitration needed first.
- [ ] Per-app gesture profile — defer: needs window/exe detection over RDP.
- [ ] Second-device generalization — defer: v1 is OneMix 3 only by design.
- [ ] Wayland-native input path — defer: different input stack; only if the user moves to Wayland.
- [ ] Upstream FreeRDP PR — defer: higher quality bar; separate milestone.

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| One-finger native touch/drag (correct) | HIGH | MEDIUM | P1 |
| Contact cancellation / lifecycle | HIGH | MEDIUM | P1 |
| Coordinate transform | HIGH | LOW–MEDIUM | P1 |
| Long-press right-click (no phantom click) | HIGH | MEDIUM | P1 |
| Two-finger pinch native | HIGH | MEDIUM | P1 |
| Pinch `Ctrl+wheel` fallback | HIGH | MEDIUM | P1 |
| `+multitouch` default in launch config | HIGH | LOW | P1 |
| Fullscreen/windowed stability | HIGH | MEDIUM | P1 |
| Debian packaging + rollback | HIGH | MEDIUM | P1 |
| Diagnostics log | MEDIUM | LOW | P1 |
| Configurable long-press / pinch knobs | HIGH | LOW | P1 (borderline P2; cheap) |
| Runtime pinch-mode switch | MEDIUM | MEDIUM | P2 |
| Per-app long-press profile | LOW | MEDIUM | P3 |
| Hotplug of touch device | LOW | HIGH | P3 |
| Direct Touch ↔ Mouse Pointer auto-switch | MEDIUM | HIGH | P3 |
| Three-finger swipe / key capture | MEDIUM | MEDIUM | P3 |
| Per-app gesture profile | LOW | HIGH | P3 |
| Second-device generalization | MEDIUM | HIGH | P3 |
| Wayland-native input | LOW | HIGH | P3 |
| Upstream PR | LOW | HIGH | P3 |

**Priority key:**
- P1: Must have for launch (v1)
- P2: Should have, add when possible (v1.x)
- P3: Nice to have, future consideration (v2+)

## Competitor Feature Analysis

| Feature | Microsoft Windows App (Android) | Stock `xfreerdp3` (Debian) | Our Approach (v1) |
|---------|---------------------------------|---------------------------|-------------------|
| One-finger touch → native remote touch | Direct Touch mode: finger = pointer, up to 10 contacts | `+multitouch` exists but off; known regressions in some versions | Fix + enable RDPEI path; verify against installed source version |
| One-finger drag | Direct: tap+drag | Works when RDPEI path works | Same, with contact lifecycle correctness |
| Right-click | Direct: tap-and-hold-then-release; Mouse Pointer: two-finger tap | Issue #6566: long press took ~4s (regression) | 500–700 ms configurable long-press, no phantom left-click |
| Pinch-to-zoom | Direct Touch: NO pinch; Mouse Pointer: pinch zooms locally | Native multitouch when `+multitouch` works | Native by default + `Ctrl+wheel` fallback for classic apps (Windows App has no such fallback) |
| Mode switching | Manual Touch ↔ Mouse Pointer; recently doesn't persist choice | N/A (single mode) | v1: Direct Touch only; v2: explicit toggle |
| Three-finger gestures | Limited | None | v2+ (deferred) |
| Configurability | None exposed | `+multitouch` flag only | Long-press ms, pinch mode — differentiator |
| Multi-device | Yes | Generic | OneMix 3 only by design |
| Packaging | App store | Debian package (stock) | Debian `.deb` with rollback |

Notable: Microsoft's Direct Touch mode does NOT support pinch — it sends touches raw and relies on the remote app. Our `Ctrl+wheel` fallback is a deliberate advantage for users who live in classic desktop apps over RDP, which is exactly the OneMix 3 daily-use case.

## Edge Cases (must be testable)

These are the observable behaviors the v1 acceptance criteria should be able to exercise:

- **Contact cancellation:** Finger lifts mid-drag → remote sees `TouchEnd` at the lift point, no stuck contact. Window loses focus mid-touch → all outstanding contacts end cleanly. `xfreerdp3` window minimized mid-gesture → no ghost touches on return.
- **Accidental click after long press:** Long press fires right-click; on finger lift, no left-click follows. Subsequent genuine tap → left-click fires normally (suppression flag cleared on new `TouchBegin`, not on a timer).
- **Long-press cancellation by movement:** Finger drifts > slop radius before threshold → long press cancels, gesture becomes a normal drag (native touch). Verify the threshold is in screen pixels and respects the device transform.
- **Coordinate transform under rotation/scale:** OneMix 3 in portrait vs landscape, fullscreen vs windowed: tap lands under finger in all four combos. Test against the X Coordinate Transformation Matrix actually configured on the device.
- **Pinch native in a touch-aware app** (e.g., remote Edge, Photos): two contacts reach the remote as two distinct persistent IDs; spreading zooms in the app.
- **Pinch fallback in a classic app** (e.g., remote File Explorer, classic Office): pinch emits `Ctrl+wheel`; `Ctrl` is released on finger lift even if one finger lifts first; no stuck `Ctrl`.
- **Pinch native ↔ fallback conflict:** with native mode on, classic app pinch appears to do nothing (expected, documented); with fallback on, touch-aware app does not get native pinch (expected, documented). Config switch, not silent.
- **Gesture conflict: long-press vs drag:** a slow drag that lingers > threshold must not spuriously right-click; movement beyond slop cancels the timer before it fires.
- **Gesture conflict: pinch vs two-finger tap:** two fingers landing and lifting without spreading must not emit wheel events (pinch fallback) or spurious right-click (long-press is one-finger, so safe).
- **Apps without native touch zoom:** confirm the fallback path is the documented answer; confirm native path is a no-op (app ignores the contacts) rather than broken behavior.
- **Hotplug of touch device mid-session:** documented known limitation for v1; touch stops until reconnect. Do not silently fail — log it.
- **Fullscreen toggle mid-touch:** outstanding contacts cancelled; new window re-selects XI touch events; subsequent touches land correctly.

## Sources

- FreeRDP Issue #8253 — Support normal touch-screen interaction (closed by PR #12686, 2026-04-28): https://github.com/FreeRDP/FreeRDP/issues/8253
- FreeRDP Issue #9082 — multitouch recently broken (bisected to `d66b165`): https://github.com/FreeRDP/FreeRDP/issues/9082
- FreeRDP Issue #7759 — hotplug support for RDPEI channel: https://github.com/FreeRDP/FreeRDP/issues/7759
- FreeRDP Issue #12174 — lost touch events / race in `rdpei_touch_process` vs `rdpei_add_frame`: https://github.com/freerdp/freerdp/issues/12174
- FreeRDP Issue #6566 — tap-and-hold too slow for right-click (regression): https://github.com/FreeRDP/FreeRDP/issues/6566
- FreeRDP PR #12686 — fix Android touch and physical mouse input: https://github.com/FreeRDP/FreeRDP/pull/12686
- FreeRDP source: `client/X11/xfreerdp.h` (`touch_contact` struct): https://fossies.org/linux/FreeRDP/client/X11/xfreerdp.h
- FreeRDP source: `client/common/client.c` (RDPEI bridge): https://pub.freerdp.com/api/client_2common_2client_8c_source.html
- `xfreerdp(1)` manpage — `+multitouch` flag: https://www.mankier.com/1/xfreerdp
- Microsoft — Gesture list for Touch and Mouse Pointer input modes: https://techcommunity.microsoft.com/blog/microsoft-security-blog/gesture-list-for-the-touch-and-mouse-pointer-input-modes-for-the-remote-desktop-/248596
- Microsoft Learn — `IRemoteDesktopClientTouchPointer`: https://learn.microsoft.com/en-us/windows/win32/api/rdpappcontainerclient/nn-rdpappcontainerclient-iremotedesktopclienttouchpointer
- MS-RDPEI specification (Microsoft Learn): https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-rdpei/72a8cb65-7f6c-407c-a21a-3d970721fed0
- X11 XI2 protocol spec (touch event coordinates): https://www.x.org/releases/X11R7.7/doc/inputproto/XI2proto.txt
- Ubuntu Wiki — X InputCoordinateTransformation: https://wiki.ubuntu.com/X/InputCoordinateTransformation
- `evdev-right-click-emulation` (long-press reference, `LONG_CLICK_INTERVAL`/`LONG_CLICK_FUZZ`): https://github.com/bareboat-necessities/evdev-right-click-emulation
- Android Launcher3 `CheckLongPressHelper` (timer cancellation patterns): https://android.googlesource.com/platform/packages/apps/Launcher3/+/master/src/com/android/launcher3/CheckLongPressHelper.java
- React Aria `useLongPress` (suppression flag, interaction coordination): https://reactspectrum.blob.core.windows.net/reactspectrum/b85d5a909cd332041760fe07f1569fc59a47363/s2-docs/react-aria/useLongPress.html

---
*Feature research for: X11 touchscreen-input patch for `xfreerdp3` on OneMix 3 / Debian*
*Researched: 2026-08-05*
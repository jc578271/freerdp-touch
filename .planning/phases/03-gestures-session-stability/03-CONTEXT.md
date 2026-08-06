# Phase 3: Gestures & Session Stability - Context

**Gathered:** 2026-08-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 3 adds a minimal gesture state machine to the existing XInput2 → native RDPEI path: configurable one-finger long-press right-click, startup-selected native or `Ctrl`+wheel pinch behavior, and complete gesture/modifier cleanup across finger changes, focus loss, window-state changes, disconnect, and reconnect. Ordinary one-finger tap/drag remains immediate native RDPEI input. Packaging, final diagnostics controls, launch documentation, live mode switching, fallback two-finger scrolling, and additional gestures remain outside this phase.

</domain>

<decisions>
## Implementation Decisions

### Long-press contract
- **D-01:** The X11 client owns long-press timing. Touch-down is still forwarded immediately as native RDPEI input so ordinary taps and drags gain no recognition delay; a client timer determines whether the configurable 500–700 ms hold threshold is reached.
- **D-02:** While one finger remains a long-press candidate, motion inside the configurable slop radius is suppressed so the OneMix 3's observed 1–3 px stationary jitter does not reach Windows. Moving beyond slop before the threshold permanently cancels the candidate and continues as an ordinary native drag without requiring lift.
- **D-03:** At the threshold, emit exactly one right-click at the original touch-down coordinate, prevent the native contact from later completing as a left-click, and consume all remaining updates for that physical finger until lift.
- **D-04:** A second finger immediately cancels any armed long-press candidate; pinch handling takes precedence and no right-click may fire while two fingers are down.

### Native and fallback pinch claiming
- **D-05:** Native mode is pure RDPEI passthrough for both contacts and emits no local wheel shortcut. This includes native two-finger drag/scroll behavior handled by Windows; Phase 3 does not add a separate two-finger drag-to-wheel gesture.
- **D-06:** In fallback mode, the second finger immediately claims the gesture away from native RDPEI so native pinch and local `Ctrl`+wheel output can never overlap. Local wheel output waits until deliberate scale movement crosses a small activation deadband.
- **D-07:** Two fingers translating together without meaningful separation change produce no local action in fallback mode. The gesture remains reserved until it becomes a pinch or ends; it is not handed back to native input mid-gesture.
- **D-08:** Pinch recognition is based on change in inter-finger distance, with a small initial deadband to reject touchscreen jitter. The exact device-tested distance may be selected during planning and calibration rather than exposed as another speculative setting.

### `Ctrl` + wheel zoom output
- **D-09:** Fingers moving apart zoom in (`Ctrl`+wheel-up); fingers moving together zoom out (`Ctrl`+wheel-down).
- **D-10:** Convert accumulated pinch distance into fixed standard wheel detents. Do not add speed-based acceleration or multi-detent bursts.
- **D-11:** Before the first fallback wheel tick, move the hidden remote pointer to the current pinch midpoint so applications that zoom around the cursor target the touched content.
- **D-12:** When pinch direction reverses, discard the partial wheel-step accumulator and require a fresh complete step before emitting the opposite direction; small reversals must not chatter between zoom-in and zoom-out.

### Gesture completion and recovery
- **D-13:** A fallback pinch ends as soon as contact count drops below two. Release held `Ctrl` on that first finger lift, stop wheel output, and ignore the remaining finger until every pinch contact has lifted; do not resume it as a one-finger tap, drag, or long-press.
- **D-14:** A third finger aborts fallback pinch: release `Ctrl`, stop output, reset the gesture, and require all involved fingers to lift before accepting new touch input.
- **D-15:** Extend the existing Phase 2 forced-cancel/recovery seam to all gesture state. Focus loss, unmap/minimize, fullscreen or geometry change, channel loss, disconnect, and shutdown must cancel armed long-press/pinch state, release `Ctrl` if held, clear accumulators, and require a fresh physical touch after the existing all-fingers-lift gate.
- **D-16:** Automatic reconnect preserves the startup-selected native/fallback pinch mode for the lifetime of the client process, but never resumes or replays the interrupted gesture.

### Claude's Discretion
- Exact helper names, state layout, timer subscription point, and file split are left to planning. Reuse the existing X11 main-loop timer and input helpers where practical; do not add a thread, dependency, daemon, or duplicate RDPEI encoder.
- Choose and calibrate the default long-press threshold within 500–700 ms, the configurable slop default, the fallback activation deadband, and fixed wheel-step distance on the OneMix 3. Only the requirement-mandated long-press timing/slop and startup pinch mode need user-facing calibration unless device evidence justifies another knob.
- Exact ordering of native-contact cancellation, right-button down/up, Ctrl press, pointer-centering motion, and first wheel tick is flexible provided the externally visible decisions above hold: no unwanted left-click, no native/fallback overlap, and no stuck modifier.
- Test organization, diagnostic wording, and internal logging detail are flexible, but checks must cover timer firing, slop cancellation, second/third-finger transitions, wheel direction/detents, midpoint targeting, every cleanup hook, and reconnect reuse.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scope and acceptance
- `.planning/PROJECT.md` — Defines the native-X11 OneMix 3 boundary, immediate-touch latency constraint, configurable long-press/pinch behavior, and excluded broader gesture suite.
- `.planning/REQUIREMENTS.md` — Defines GEST-01 through GEST-04 and STAB-01/STAB-02, including configurable threshold/slop, native-versus-fallback exclusivity, Ctrl cleanup, and reconnect stability.
- `.planning/ROADMAP.md` — Defines the Phase 3 goal, success criteria, phase boundary, and lifecycle-before-gestures ordering.

### Prior-phase contracts and device evidence
- `.planning/phases/02-native-rdpei-touch-lifecycle/02-CONTEXT.md` — Locks immediate native RDPEI forwarding, forced-cancel semantics, the all-fingers-lift recovery gate, and the authoritative contact-state boundaries Phase 3 must preserve.
- `.planning/phases/02-native-rdpei-touch-lifecycle/02-UAT.md` — Records the on-device 1–3 px stationary jitter that cancels Windows press-and-hold, confirms native RDPEI operation, and identifies the Phase 3 deadband requirement.
- `.planning/phases/02-native-rdpei-touch-lifecycle/02-REVIEW-FIX.md` — Records the final Phase 2 cleanup shape, removed redundant cancellation state, build-configuration fixes, and intentionally deferred low-risk fallback concerns.
- `.planning/phases/01-environment-gate-build-baseline/baseline-report.md` — Records the actual OneMix 3 direct-touch device, native-X11 session, display geometry/orientation, and package baseline used for calibration and UAT.

### Existing architecture and pitfalls
- `.planning/research/ARCHITECTURE.md` — Maps the XInput2-to-RDPEI flow and the existing X11 gesture, timer, and lifecycle integration seams.
- `.planning/research/PITFALLS.md` — Documents contact ownership, duplicate input, stale-contact, modifier, gesture-disambiguation, and cleanup failure modes.
- `.planning/research/STACK.md` — Defines the pinned FreeRDP/XInput2/RDPEI stack and existing APIs to reuse without adding dependencies.

No external specification governs these gestures; the local project, requirement, prior-phase, and research documents above are canonical.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c:646` — `xf_input_touch_remote()` is the existing immediate XInput2-to-RDPEI dispatch point and the smallest shared seam for long-press candidate and fallback-pinch transitions.
- `build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c:792` — `xf_touch_force_cancel()` already cancels authoritative native contacts and arms the recovery gate; extend this single reset seam for gesture timers, accumulators, and held Ctrl.
- `build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c:1009` — `xf_input_handle_event_remote()` already owns recovery-gate filtering and all remote XI2 touch dispatch.
- `build/freerdp3-3.15.0+dfsg/client/X11/xf_client.c:1609` — The X11 client already runs a 20 ms waitable timer and publishes `TimerEventArgs`; long-press timing can reuse it instead of adding a thread or timer framework.
- `build/freerdp3-3.15.0+dfsg/client/common/client.c:1590` — `freerdp_client_send_wheel_event()` already emits standard vertical wheel input.
- `build/freerdp3-3.15.0+dfsg/client/common/client.c:1652` — `freerdp_client_send_button_event()` already emits absolute pointer movement and mouse-button events needed for midpoint placement and right-click synthesis.
- `build/freerdp3-3.15.0+dfsg/include/freerdp/scancode.h:71` — `RDP_SCANCODE_LCONTROL` and existing keyboard-input APIs provide Ctrl press/release without inventing key translation.

### Established Patterns
- With `+multitouch`, events take the remote path and bypass the existing local `xf_input_detect_pinch()` / PubSub zoom path. Fallback pinch must integrate with the remote path; do not switch the whole client to local-gesture mode or reuse framebuffer-only zoom as if it were remote wheel input.
- Phase 2 deliberately keeps X11 gesture/fallback policy out of `client/common/client.c`; preserve SDL/Wayland behavior and keep Phase 3 policy in the X11 client unless a truly shared primitive already exists.
- `cctx->contacts[]` is the authoritative native contact store; `xfc->contacts[]` is the older local-gesture array. Do not duplicate RDPEI's external-ID/contact-ID mapping or frame encoder.
- Existing lifecycle hooks in `xf_event.c` and `xf_client.c` already converge on `xf_touch_force_cancel()`. Gesture cleanup belongs in that shared reset path rather than duplicated at every hook.
- The source tree currently contains temporary UAT `/* DIAG: */` blocks not represented by a quilt patch; Phase 4 owns final diagnostics/packaging, so Phase 3 planning must distinguish temporary evidence logging from product behavior.

### Integration Points
- Extend touch begin/update/end handling in `xf_input_touch_remote()` with the minimal per-contact candidate state needed for long press and two-finger fallback claiming while preserving immediate native down/drag behavior.
- Subscribe a small long-press deadline check to the existing X11 timer path, or use the nearest existing timer callback pattern selected during planning.
- Route synthetic right-click, pointer-centering movement, Ctrl key state, and wheel detents through existing FreeRDP client input helpers.
- Expand `xf_touch_force_cancel()` (and its no-XI-safe shape) to clear every new gesture field and release Ctrl idempotently before existing contact quarantine/recovery proceeds.
- Preserve startup-selected mode across `client_auto_reconnect_ex()` while resetting active gesture state through the established disconnect/reconnect hooks.

</code_context>

<specifics>
## Specific Ideas

- The long-press context action should appear as soon as the configured threshold elapses, at the exact original touch point, without waiting for finger lift.
- After a completed long press, freeze that physical touch until lift rather than allowing pointer hover or right-button drag.
- Native two-finger drag/scroll is intentionally left to Windows through RDPEI passthrough; fallback mode is zoom-only and does nothing for pure two-finger translation.
- Fallback zoom should feel controlled rather than accelerated: fixed detents, conventional direction, midpoint targeting, and reversal hysteresis.
- Any ambiguous multi-finger or lifecycle transition should fail closed into reset/all-fingers-up rather than synthesize a surprise click or drag.

</specifics>

<deferred>
## Deferred Ideas

None — fallback two-finger drag-to-wheel scrolling was considered but deliberately not added because native passthrough already supplies two-finger scrolling within the Phase 3 contract.

</deferred>

---

*Phase: 3-Gestures & Session Stability*
*Context gathered: 2026-08-06*

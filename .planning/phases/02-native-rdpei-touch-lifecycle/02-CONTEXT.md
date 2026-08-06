# Phase 2: Native RDPEI Touch Lifecycle - Context

**Gathered:** 2026-08-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 2 delivers one complete native-touch path from XInput2 through RDPEI: exclusive, non-duplicated capture; stable contact identity; correctly transformed coordinates; ordered begin/update/end frames; two simultaneous contacts; and deterministic cleanup on normal lift or forced interruption. It covers the current OneMix 3 native-X11 setup in fullscreen and live-resized windowed modes. Long-press, pinch interpretation, `Ctrl`+wheel synthesis, reconnect behavior after teardown, packaging, and user-facing diagnostics remain assigned to later phases.

</domain>

<decisions>
## Implementation Decisions

### RDPEI-unavailable fallback
- **D-01:** When RDPEI is unavailable, only the first active touchscreen contact falls back to left-mouse input so login/channel-startup remains usable without another pointer.
- **D-02:** Additional fingers are ignored while that fallback contact is active; they must never emit competing mouse events.
- **D-03:** Input mode is latched for the lifetime of a physical contact. A contact that begins as mouse fallback completes as mouse fallback even if RDPEI appears midway; native RDPEI starts with the next contact after lift.
- **D-04:** The fallback contact supports a complete left-button lifecycle—down, motion, and up—so both tap and drag work. Tap-only fallback is not sufficient.

### Forced contact cancellation
- **D-05:** A normal `XI_TouchEnd` produces a normal RDPEI lift. Any contact terminated by an interruption instead sends RDPEI cancellation (`UP | CANCELED`) so Windows abandons the action rather than completing a click or drop.
- **D-06:** Forced cancellation applies to all relevant transitions: focus loss, unmap/minimize, fullscreen or window-state changes, rotation/scale/geometry changes, RDPEI or channel loss, disconnect, and client shutdown.
- **D-07:** Cleanup is idempotent. A delayed `XI_TouchEnd` or other terminal event for an already canceled touch ID is ignored and must not emit a second terminal RDPEI event.
- **D-08:** After forced cancellation, events from fingers that were already physically down remain quarantined. New touch input is accepted only after every pre-cancellation finger has lifted.

### Coordinate and orientation contract
- **D-09:** Phase 2 explicitly guarantees the captured daily-use orientation only: the OneMix 3 panel at left rotation, producing a `2560x1600` desktop. Other rotations are not v1 acceptance targets.
- **D-10:** Coordinate correctness must hold in fullscreen and after ordinary live resizing in windowed mode; it is not limited to the initial launch dimensions or aspect-preserving resizes.
- **D-11:** A touch outside the rendered remote-desktop content, including letterbox regions, is ignored. It must not be clamped to the nearest remote edge or converted into local pointer motion.
- **D-12:** If rotation, scale, or window geometry changes while contacts are active, cancel those contacts before adopting the new transform, then apply the same all-fingers-lift recovery gate from D-08.

### Claude's Discretion
- Exact helper names, state representation, file split, hook ordering, and debug-log wording are left to planning, provided the lifecycle policies above remain true.
- The planner may choose the smallest safe location for shared cancellation/fallback bookkeeping after auditing all callers; do not duplicate RDPEI's external-ID/contact-ID map or frame encoder.
- Exact tests and diagnostics are flexible, but they must expose XInput ownership, pointer-emulation suppression, contact ordering, two-contact framing, cancellation, and coordinate behavior well enough to verify the phase requirements.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scope and acceptance
- `.planning/PROJECT.md` — Defines the native-X11, OneMix 3, direct-FreeRDP patch boundary; low-latency requirement; and gesture/packaging deferrals.
- `.planning/REQUIREMENTS.md` — Defines XINP-01, XINP-02, COOR-01, and RDPEI-01 through RDPEI-03, including no duplicates, stable IDs, coordinate correctness, two contacts, and forced cleanup.
- `.planning/ROADMAP.md` — Defines the Phase 2 goal, success criteria, and the lifecycle-before-gestures ordering.

### Verified device and package baseline
- `.planning/phases/01-environment-gate-build-baseline/01-CONTEXT.md` — Locks the native-X11 gate, exact Debian source version, clean-source workflow, and on-device proof expectations carried into this phase.
- `.planning/phases/01-environment-gate-build-baseline/baseline-report.md` — Records the actual direct-touch device, 10-touch capability, `2560x1600` left-rotated display, DPI 192, launch command, and verified package/source version.

### Touch-path research
- `.planning/research/SUMMARY.md` — Summarizes the XInput2 ownership, pointer-emulation, coordinate, RDPEI lifecycle, and known-regression risks that Phase 2 combines.
- `.planning/research/ARCHITECTURE.md` — Maps the existing XInput2-to-RDPEI call chain, authoritative contact stores, and integration seams; warns against a duplicate contact-state layer.
- `.planning/research/PITFALLS.md` — Documents the #9082 intermediary regression, #12174 RDPEI lock race, valid contact flags, touch ownership, pointer-emulation duplicates, ID reuse, and coordinate-transform failure modes.
- `.planning/research/STACK.md` — Defines the pinned FreeRDP/XInput2/RDPEI stack and the existing APIs to reuse without adding dependencies or rewriting the channel.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c:74` — `register_input_events()` already discovers direct-touch devices and selects `XI_TouchBegin`, `XI_TouchUpdate`, and `XI_TouchEnd`.
- `build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c:641` — `xf_input_touch_remote()` already converts XInput coordinates and forwards begin/update/end through `freerdp_client_handle_touch()`.
- `build/freerdp3-3.15.0+dfsg/client/common/client.c:1765` — The shared touch helper already owns a fixed 10-contact store and native RDPEI down/motion/up dispatch, with an existing mouse fallback when `rdpei` is absent.
- `build/freerdp3-3.15.0+dfsg/channels/rdpei/client/rdpei_main.c:132` — RDPEI already owns external-ID to protocol-contact-ID allocation and frame batching.
- `build/freerdp3-3.15.0+dfsg/channels/rdpei/client/rdpei_main.c:1192` — `RdpeiClientContext->TouchCancel` already emits `UP | CANCELED`; reuse it rather than inventing cancellation flags.
- `build/freerdp3-3.15.0+dfsg/client/X11/xf_event.c:329` — `xf_event_adjust_coordinates()` is the existing window-to-remote transform and should remain the central scaling path.

### Established Patterns
- With `+multitouch`, X11 touch events follow `xf_input_handle_event_remote()` → `xf_input_touch_remote()` → `freerdp_client_handle_touch()` → RDPEI. Preserve this path instead of creating a daemon, channel, or encoder.
- The direct-touch device exposes both touch and pointer classes. Existing registration selects both streams, while current dispatch does not filter `XIPointerEmulated`; duplicate suppression must distinguish emulated pointer events from real mouse input.
- The common client uses contact ID `0` as its free-slot sentinel and RDPEI asynchronously batches active contacts into frames. ID reuse and terminal-event ordering therefore need explicit verification.
- `xf_event_FocusOut()` and `xf_event_UnmapNotify()` currently release keyboard state only; `xf_toggle_fullscreen()` and `xf_post_disconnect()` are centralized hooks but do not clean up touch contacts.
- The current coordinate helper clamps values. D-11 requires a content-bounds check before forwarding so out-of-content touches are ignored rather than silently clamped.
- The exact Debian RDPEI code releases its lock between contact reservation and publication. Planning must audit and, if confirmed necessary, fix the #12174 race at its shared root rather than patching symptoms in X11 callers.

### Integration Points
- Extend XI2 event selection/dispatch for explicit touch ownership and acceptance, and suppress only touch-generated pointer emulation while preserving genuine mouse/stylus input.
- Add one reusable forced-cancel/reset operation and invoke it from focus, unmap/minimize, fullscreen/window-state, geometry-transform, channel-loss, disconnect, and shutdown paths.
- Keep normal lift and forced cancellation as distinct terminal paths; both must clear local bookkeeping exactly once.
- Track enough local state to enforce first-contact-only mouse fallback and the all-fingers-lift recovery gate without mirroring RDPEI's protocol contact map.
- Validate coordinates against the rendered content rectangle before applying/forwarding the remote transform, and refresh transform inputs on live `ConfigureNotify` changes.

</code_context>

<specifics>
## Specific Ideas

- Preserve pre-RDPEI usability, but make fallback deliberately single-contact and deterministic rather than retaining the current broad per-contact mouse conversion.
- Never change a physical contact from mouse to RDPEI midway through its lifetime.
- Treat forced interruption as abort semantics, not a synthetic normal lift.
- Optimize and verify for the owner's captured daily-use setup first: native X11, left rotation, `2560x1600`, DPI 192, fullscreen plus live-resized windowed operation.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 2-Native RDPEI Touch Lifecycle*
*Context gathered: 2026-08-06*

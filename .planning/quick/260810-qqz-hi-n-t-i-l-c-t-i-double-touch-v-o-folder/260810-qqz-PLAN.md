---
mode: quick
phase: quick
plan: 260810-qqz
type: execute
wave: 1
depends_on: []
files_modified:
  - patches/onemix-touch.patch
autonomous: true
requirements: [GEST-01]
user_setup: []
estimate:
  tokens: 30000
  raw_tokens: 30000
  tasks: 2
  confidence: low
must_haves:
  truths:
    - "Two sequential one-finger taps that land within the configured touch slop are emitted to the RDP server as two complete left-click pairs at one adjusted coordinate, so Windows can recognize a folder-opening double-click despite normal finger-placement jitter."
    - "The first short tap remains immediate; a user does not wait for a double-tap timeout before a normal single-tap selection is sent."
    - "Drag, long-press, multi-finger entry, and forced lifecycle cancellation cannot leave a prior tap coordinate eligible to redirect a later click."
    - "The shipping Debian quilt patch applies to a clean pinned source extraction and its production XI2 dispatcher regression passes."
  artifacts:
    - "patches/onemix-touch.patch contains the X11 tap-pair state, short-tap coordinate selection, state resets, and TestXfInputDispatcher regression."
  key_links:
    - "xf_event.c event loop -> xf_input_handle_event -> xf_input_handle_event_remote -> xf_input_touch_remote -> xf_input_touch_fallback short-tap XI_TouchEnd branch."
    - "xf_input_touch_fallback -> freerdp_client_send_button_event -> freerdp_input_send_mouse_event -> test rdpInput.MouseEvent recorder."
---

<objective>
Make the requested double touch—two sequential one-finger taps used to open a folder—reliably form a Windows double-click without delaying ordinary one-finger selection.

Purpose: The local-only XI2 recognizer currently emits each short tap at its own `lpDownX/lpDownY`. Small normal placement variation between the two taps reaches Windows as clicks at different positions, so the server-side double-click detector can reject the pair. The corrected short-tap seam keeps the first click immediate and anchors only a qualifying second tap to the first adjusted coordinate.

Output: A refreshed `patches/onemix-touch.patch` with a production-dispatcher regression that records the RDP mouse events for a nearby two-tap sequence, plus a clean-quilt application proof.

Trace completed before planning: the only production caller of `xf_input_handle_event` is the X11 event loop in `client/X11/xf_event.c`; with `FreeRDP_TouchPinchWheelFallback=true` and `FreeRDP_MultiTouchInput=false`, it selects `xf_input_handle_event_remote`, which routes XI_TouchBegin/Update/End to `xf_input_touch_remote`, then to the sole `xf_input_touch_fallback` caller. Its one-finger `XI_TouchEnd` branch is the only local short-tap path that emits the `BUTTON1` down/up pair. The separate core/XI pointer-emulation filters remain outside this change.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/STATE.md
@.planning/REQUIREMENTS.md
@.planning/phases/04-diagnostics-packaging-launch-configuration/04-07-SUMMARY.md
@patches/onemix-touch.patch
@scripts/build-release.sh

Read from a private extraction after applying the current patch:
- client/X11/xf_input.c — `xf_input_touch_fallback`, `xf_input_touch_remote`, `xf_input_handle_event_remote`, and `xf_input_handle_event`.
- client/X11/xfreerdp.h — existing WITH_XI long-press and gesture state placement.
- client/X11/test/TestXfInputDispatcher.c — synthetic XI2 cookies, production dispatcher invocation, and CTest fixture conventions.
- client/common/client.c — `freerdp_client_send_button_event` updates coordinates then invokes `freerdp_input_send_mouse_event`.
- libfreerdp/core/input.c — `freerdp_input_send_mouse_event` invokes `rdpInput.MouseEvent`, which the regression can record without a display or RDP server.

Preserve the existing local-only contract: `FreeRDP_TouchPinchWheelFallback=true`, `FreeRDP_MultiTouchInput=false`, no native RDPEI touch forwarding, and the existing `XIPointerEmulated`/core-pointer suppression behavior.
</context>

<source_audit>
SOURCE | ID | Feature / constraint | Coverage | Status
--- | --- | --- | --- | ---
GOAL | user request | Nearby sequential double taps open a folder reliably | Task 1 | COVERED
REQ | GEST-01 | One-finger long press remains a configurable right-click with no left-click afterward | Task 1 preserves and regression-protects the one-finger state boundary | COVERED
RESEARCH | PITFALLS.md §5 | Local-only XI2 handling must not create a second pointer-input path | Task 1 changes only the existing short-tap output coordinate; dispatcher routing and emulation filters remain intact | COVERED
RESEARCH | PROJECT.md stack | Reuse current XInput2, FreeRDP input helpers, CMake/CTest, and Debian quilt; add no daemon or dependency | Tasks 1–2 | COVERED
CONTEXT | — | No `*-CONTEXT.md` exists for this quick task and therefore no D-NN decisions apply | This plan implements only the stated double-tap repair | COVERED
</source_audit>

<dependency_graph>
Task 1 needs the current integrated quilt patch and the existing dispatcher fixture; it creates the tested tap-pair behavior in a private source workspace. Task 2 needs that green workspace; it creates the tracked refreshed quilt patch and proves it in a second clean extraction. They run sequentially inside this single Wave-1 plan because Task 2 packages Task 1's exact source delta.
</dependency_graph>

<tasks>

<task type="tracer" tdd="true">
  <name>Task 1: Anchor a qualified second local tap and prove the RDP click sequence through the real XI2 dispatcher</name>
  <files>patches/onemix-touch.patch (hunks for src/client/X11/xf_input.c, src/client/X11/xfreerdp.h, and src/client/X11/test/TestXfInputDispatcher.c)</files>
  <precondition>The pinned source descriptor at `/home/hoang/freerdp-touch/src/freerdp3_3.15.0+dfsg-2.1+deb13u3.dsc` exists, and `dpkg-source`, `quilt`, CMake, CTest, the XInput2 headers, and the project's existing Debian build dependencies are available.</precondition>
  <read_first>
    - `patches/onemix-touch.patch` — preserve its single integrated-patch format and locate the three named source hunks before editing.
    - `client/X11/xf_input.c` in a private patched extraction — trace the one-finger `XI_TouchBegin`, slop/drag `XI_TouchUpdate`, short-tap `XI_TouchEnd`, multi-finger transition, long-press, and `xf_touch_cancel_lifecycle` branches.
    - `client/X11/xfreerdp.h` in that extraction — place any tap-pair state beside the existing `lpArmed`, `lpDownX/Y`, `lpStartTime`, `lpDeadline`, `lpFinger`, and `lpFrozen` fields under `WITH_XI`.
    - `client/X11/test/TestXfInputDispatcher.c` — extend its existing synthetic-cookie route through public `xf_input_handle_event`; do not make a copied recognizer model.
    - `client/common/client.c` and `libfreerdp/core/input.c` — use the existing `rdpInput.MouseEvent` callback boundary to record the actual output of `freerdp_client_send_button_event`.
  </read_first>
  <behavior>
    - RED: under the canonical local-only settings, dispatch Begin/End for touch ID 61 at raw `(20,30)`, then Begin/End for touch ID 62 at raw `(24,33)`. After the fixture's existing coordinate adjustment these are `(10,10)` and `(14,13)`, whose distance is within the default 8px touch slop. The new test expects exactly four recorded mouse events: BUTTON1 down/up at `(10,10)`, then BUTTON1 down/up again at `(10,10)`. It fails before the repair because the current second pair uses `(14,13)`.
    - A first short tap still emits its down/up pair immediately at its own adjusted coordinate; no timer or deferred single-click path is introduced.
    - A second short tap qualifies only when it completes within the current configurable long-press duration and its touch-down coordinate is within the current configurable touch slop of the prior short tap. Its output pair uses the stored first coordinate, then consumes the tap-pair anchor.
    - A second tap outside the time or slop window emits at its own coordinate and becomes the next anchor.
    - A drag, long press, second-finger/multi-finger transition, or `xf_touch_cancel_lifecycle` clears the anchor before later input can use it. Existing right-click, drag, scroll, pinch, three-finger pan, quarantine, and pointer-emulation behavior remain unchanged.
  </behavior>
  <action>
    Create a private writable source workspace from the pinned DSC, copy the current project patch into that workspace's temporary `debian/patches/` directory, append it only to that workspace's `series`, and apply the full Debian quilt stack. Configure the workspace with `BUILD_TESTING=ON`.

    Start RED by extending the existing `TestXfInputDispatcher` fixture rather than adding a parallel test executable. Add a bounded `rdpInput.MouseEvent` recorder: point a zero-initialized `rdpInput` at `&xfc->common.context`, assign its mouse callback to capture flags and coordinates, then assign that input object to `xfc->common.context.input`. Add the nearby sequential-tap scenario from `<behavior>` and assert the exact four `PTR_FLAGS_DOWN | PTR_FLAGS_BUTTON1` / `PTR_FLAGS_BUTTON1` records and adjusted coordinates. The test must drive `xf_input_handle_event` through the existing wrapped XI2 cookie helpers, not call a static touch helper directly.

    Once RED is demonstrated, add four WITH_XI fields in `xfreerdp.h` for a valid prior short-tap anchor, its adjusted X/Y coordinate, and its completion timestamp. Initialize them with the existing gesture state in `xf_input_init`. In `xf_input.c`, reuse `GetTickCount64`, `FreeRDP_TouchLongPressDurationMs` with its existing zero-to-600ms fallback, and `FreeRDP_TouchLongPressSlopPx` with its existing zero-to-8px fallback. In the `lpArmed` short-tap `XI_TouchEnd` branch, capture the current adjusted down coordinate and completion time. If the prior anchor is valid, has not exceeded that duration, and is within the slop radius, send this second left-button down/up pair at the prior anchor coordinate and invalidate the anchor. Otherwise send the normal pair at the current down coordinate, then store it as the new anchor. Keep the first pair immediate in both cases and retain the existing `touch-diag: synth left-tap` record beside the final output pair.

    Invalidate the prior-tap anchor when one-finger movement crosses slop and claims a drag, when `xf_input_fire_long_press` fires, before a one-finger sequence transitions into the existing multi-finger state, and while `xf_touch_cancel_lifecycle` clears the rest of gesture state. Do not add a setting, input daemon, timer, command-line option, native-touch path, duplicate pointer filter, or alternate mouse-send helper. Do not change the existing recognizer's ownership, classifier thresholds, configured long-press range, or ordinary first-tap output ordering.
  </action>
  <verify>
    <automated>cmake --build "$WORKDIR/obj" --target TestXfInputDispatcher && ctest --test-dir "$WORKDIR/obj" --output-on-failure -R '^TestXfInputDispatcher$'</automated>
    <human-check>After the refreshed package is built and launched in the native X11 session, double-tap the same folder repeatedly with normal small placement variation. Each attempt opens it; a single tap still selects, a one-finger drag still drags, and a stationary long press still opens the right-click menu.</human-check>
  </verify>
  <done>The production XI2 dispatcher regression records two complete BUTTON1 click pairs at one adjusted coordinate for a nearby two-tap sequence, the first click remains immediate, and all non-tap transitions clear the pair anchor.</done>
</task>

<task type="auto">
  <name>Task 2: Refresh the integrated quilt patch and rerun the dispatcher regression from a second clean extraction</name>
  <files>patches/onemix-touch.patch</files>
  <precondition>Task 1 passes in its private patched workspace, and the pinned DSC plus its two source archives remain readable beneath `/home/hoang/freerdp-touch/src/`.</precondition>
  <read_first>
    - `scripts/build-release.sh` — follow its source-pin and temporary full-quilt-stack application contract without changing or publishing through the release script.
    - `patches/onemix-touch.patch` — retain all pre-existing deltas, including the existing CTest target and dispatcher fixture.
    - `.planning/phases/04-diagnostics-packaging-launch-configuration/04-07-SUMMARY.md` — preserve the established patch-refresh rule: verify the exact source through a second clean extraction.
  </read_first>
  <action>
    In Task 1's private patched workspace, add the changed X11 source and dispatcher-test files to the active project patch and run `quilt refresh`; copy only the refreshed `onemix-touch.patch` back to `/home/hoang/freerdp-touch/patches/onemix-touch.patch`. Preserve the existing diff headers, Debian patch ordering, parent X11 CMake wiring, diagnostics, gesture behavior, package version, release script, launch scripts, and documentation.

    Create a second brand-new workspace from the pinned DSC. Copy the refreshed project patch into its temporary Debian patch stack, append it to that temporary `series`, and apply the complete stack with quilt. Configure this second extracted tree with `BUILD_TESTING=ON`, build `TestXfInputDispatcher`, and run its focused CTest. Also run `BUILD_RELEASE_SMOKE=1 bash /home/hoang/freerdp-touch/scripts/build-release.sh` so the repository's normal fresh-extraction patch-application path accepts the refreshed patch without building or publishing packages.
  </action>
  <verify>
    <automated>cmake --build "$FRESH_WORKDIR/obj" --target TestXfInputDispatcher && ctest --test-dir "$FRESH_WORKDIR/obj" --output-on-failure -R '^TestXfInputDispatcher$' && BUILD_RELEASE_SMOKE=1 bash /home/hoang/freerdp-touch/scripts/build-release.sh</automated>
  </verify>
  <done>The tracked quilt patch applies after the Debian patch stack in a new pinned-source extraction, its real dispatcher regression passes there, and the existing release smoke path accepts the patch.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|---|---|
| XI2 touch event stream to local gesture state | Device-originated touch IDs, times, and coordinates select synthesized RDP mouse output. |
| Local gesture state to RDP mouse callback | The tap-pair anchor influences the coordinate sent in the second BUTTON1 pair. |
| Verified source workspace to tracked quilt patch | The repair becomes shipping source only through the integrated Debian patch. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|---|---|---|---|---|---|
| T-qqz-01 | Tampering | tap-pair anchor in `xf_input_touch_fallback` | medium | mitigate | Require both existing time and slop bounds before reusing an anchor; consume it after the pair and clear it on drag, long press, multi-finger transition, and lifecycle cancellation. |
| T-qqz-02 | Denial of Service | local gesture state after interruption | medium | mitigate | Clear the new anchor in the existing `xf_touch_cancel_lifecycle` owner so stale coordinates cannot survive focus, resize, unmap, fullscreen, or disconnect cleanup. |
| T-qqz-03 | Tampering | `patches/onemix-touch.patch` | medium | mitigate | Apply the refreshed patch through the complete Debian quilt stack in a second clean extraction and run the production dispatcher CTest there. |
| T-qqz-SC | Tampering | npm/pip/cargo installs | low | accept | No package-manager installation or new package is in scope; the task uses the current Debian toolchain only. |
</threat_model>

<verification>
1. In the Task 1 workspace, run the focused `TestXfInputDispatcher` CTest after its RED-to-GREEN change; the recorder must prove the exact RDP click sequence, not only inspect recognizer fields.
2. In a second clean pinned-source extraction, apply the refreshed quilt patch and rerun that same CTest.
3. Run the existing release smoke path with `BUILD_RELEASE_SMOKE=1` to prove its fresh source extraction accepts the tracked patch.
4. On the OneMix 3 native X11 session after installation, repeatedly double-tap a folder and confirm ordinary single-tap, drag, and long-press behavior remain usable.
</verification>

<success_criteria>
- A nearby two-tap sequence reaches the RDP mouse callback as two left-click pairs at one adjusted coordinate.
- The first short tap is sent without waiting for a second touch.
- Tap-pair state cannot survive into a drag, long press, multi-finger gesture, or lifecycle recovery path.
- The sole tracked patch contains the source and test changes, applies cleanly through Debian quilt, and passes the focused production-dispatcher regression in a clean extraction.
</success_criteria>

<output>
Create `.planning/quick/260810-qqz-hi-n-t-i-l-c-t-i-double-touch-v-o-folder/260810-qqz-SUMMARY.md` when done.
</output>

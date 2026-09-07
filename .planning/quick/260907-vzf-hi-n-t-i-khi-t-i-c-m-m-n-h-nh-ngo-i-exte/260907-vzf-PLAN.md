---
mode: quick
phase: quick
plan: 260907-vzf
type: execute
wave: 1
depends_on: []
files_modified:
  - scripts/menu
  - tests/menu_diagnostic_env_check.sh
  - README.md
  - tests/readme_doc_regression.sh
autonomous: true
requirements: [CONF-01]
estimate:
  tokens: 24000
  raw_tokens: 24000
  tasks: 2
  confidence: low
must_haves:
  truths:
    - "With an external display configured, touch and touch-emulated pointer movement from the OneMix panel remain on the OneMix XRandR output instead of being normalized across the combined desktop."
    - "The existing normal, diagnostic, and mouse-only menu modes retain the same private-startx, wrapper, and FreeRDP launch topology while using the corrected dual-display input mapping."
    - "The OneMix-only rollback retains its known working orientation transform, and the operator has an explicit native-X11 hardware check for the dual-display mapping."
  artifacts:
    - "scripts/menu binds the GXTP7386:00 27C6:0113 absolute-touch device to the validated OneMix output when an external output is active."
    - "tests/menu_diagnostic_env_check.sh proves the actual generated xinitrc uses the output-bound map on every dual-display menu mode and fails before the wrapper if mapping fails."
    - "README.md and tests/readme_doc_regression.sh retain an executable operator check for the corrected dual-display touch mapping."
  key_links:
    - "FREERDP_ONEMIX_OUTPUT -> existing xrandr connected-output validation -> xinput map-to-output -> X server Coordinate Transformation Matrix -> FreeRDP XInput event->event_x/event_y coordinates."
    - "External XRandR layout -> output-bound touch map after layout -> unchanged scripts/launch-touch.sh argument passthrough -> installed xfreerdp3."
---

<objective>
Repair the OneMix panel’s dual-display touch mapping at the launcher layer: the current static Coordinate Transformation Matrix normalizes the absolute touchscreen over the whole private X desktop after the external output is added, so touch-emulated pointer movement can land on that external output.

Purpose: Bind the existing OneMix touchscreen to the already validated OneMix XRandR output rather than changing FreeRDP gesture or RDP coordinate code that only consumes the X server’s post-mapping event coordinates.
Output: A tested output-bound `xinput` branch in the generated xinitrc, regression coverage for all menu modes and failure handling, and a documented physical native-X11 verification procedure.

Discovery level: 1. The complete runtime path was traced as `menu` option 3 -> generated private xinitrc -> XRandR layout -> XInput mapping -> `scripts/launch-touch.sh` -> installed `xfreerdp3`. The only runtime mapping writer is `scripts/menu`; the FreeRDP patch reads post-server `event->event_x/event->event_y`, and the local `xinput` manual confirms `map-to-output` restricts an absolute device to a connected RandR CRTC. No new package, daemon, or FreeRDP patch is required.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/STATE.md
@.planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md
@.planning/quick/260907-t28-thi-t-l-p-c-u-h-nh-ch-y-xfreerdp3-tr-n-h/260907-t28-SUMMARY.md
@scripts/menu
@scripts/launch-touch.sh
@patches/onemix-touch.patch
@tests/menu_diagnostic_env_check.sh
@tests/wrapper_production_check.sh
@README.md
@tests/readme_doc_regression.sh

<interfaces>
- `scripts/menu` owns the private xinitrc and is the sole runtime caller that configures the display layout and touchscreen before starting the wrapper.
- `FREERDP_ONEMIX_OUTPUT` has already been checked against `xrandr --query` in that same private X server; it is the authoritative target for `xinput map-to-output`.
- `scripts/launch-touch.sh` accepts only `--mouse-only` and forwards all remaining session arguments unchanged. It must not gain display or XInput policy.
- `patches/onemix-touch.patch` consumes adjusted XInput event coordinates in the local gesture path; it does not select a physical output and is not part of this repair.
</interfaces>
</context>

<source_audit>
SOURCE | ID | Feature / constraint | Coverage | Status
--- | --- | --- | --- | ---
GOAL | quick 260907-vzf | Keep OneMix-panel touch/pointer input on the OneMix display when the newly working extended external display is present. | Task 1 implements the output-bound map; Task 2 documents physical validation. | COVERED
REQ | CONF-01 | The documented local-only-touch preset, calibration, diagnostic mode, and explicit mouse-only escape hatch remain operable. | Task 1 proves normal, diagnostic, and mouse-only menu paths; Task 2 preserves the existing launch instructions. | COVERED
RESEARCH | Existing X11/XInput stack and local xinput manual | Use the installed XRandR/XInput capability to bind an absolute device to its connected CRTC; do not add a daemon, dependency, alternate client, or FreeRDP coordinate rewrite. | Task 1 uses `xinput map-to-output` after the existing XRandR layout. | COVERED
CONTEXT | D-01, D-02 | Native multitouch remains disabled and the frozen local gesture recognizer is not retuned. | Task 1 changes only the X server mapping before FreeRDP receives events; it leaves the patch and wrapper touch preset untouched. | COVERED
CONTEXT | D-03 through D-06 | Diagnostic mode remains the existing opt-in wrapper flow without credential leakage or a second logging path. | Task 1 retains and exercises the existing diagnostic menu path; Task 2 does not alter diagnostic documentation. | COVERED
CONTEXT | D-07 through D-17 | Package identity and the two existing calibration settings remain outside this display-mapping repair. | Task 1 preserves package, connection, and calibration behavior while changing only the dual-display XInput command. | COVERED
CONTEXT | D-18 through D-21 | The credential-free wrapper owns only the local-touch preset and preserves mouse-only and diagnostic behavior. | Task 1 keeps display mapping in menu’s xinitrc and proves wrapper arguments/modes stay unchanged. | COVERED
CONTEXT | D-22, D-23, D-24 | The TTY password prompt, private startx xinitrc, display/touch setup, wrapper delegation, and three locked menu entry points remain canonical. | Tasks 1–2 retain and document the same menu-only launch flow. | COVERED
CONTEXT | D-25 | Existing accepted certificate policy is unchanged. | Task 1 does not alter connection arguments; Task 2 preserves the current disclosure. | COVERED
</source_audit>

<dependency_graph>
Task 1 needs the existing named-output layout, static touchscreen transform, and real generated-xinitrc fixture. It creates the smallest complete user path: a validated OneMix output reaches an output-bound XInput map before the unchanged wrapper and client. Task 2 needs that final command contract to document and protect the one hardware-only assertion the fixture cannot make. The tasks execute sequentially within one Wave-1 plan; no other plan is required.
</dependency_graph>

<tasks>

<task type="tracer" tdd="true">
  <name>Task 1: Bind the OneMix touchscreen to its configured XRandR output in the dual-display xinitrc</name>
  <files>scripts/menu, tests/menu_diagnostic_env_check.sh</files>
  <read_first>
    - `scripts/menu` — preserve its default output variables, connected-output validation, private xinitrc cleanup, panel rotation, XInput device identity, password serialization, `/multimon` branch, and wrapper invocation.
    - `tests/menu_diagnostic_env_check.sh` — extend its real-menu/startx fixture and current normal, diagnostic, mouse-only, rollback, and invalid-output cases instead of creating another launcher model.
    - `scripts/launch-touch.sh` — it owns touch preset composition and opaque client-argument passthrough, not display mapping.
    - `patches/onemix-touch.patch` — `xf_input_touch_remote()` consumes X server event coordinates after the menu-owned XInput mapping; do not modify this patch for an output-selection problem.
  </read_first>
  <behavior>
    - RED: a dual-output fixture records the generated xinitrc’s XInput invocation and requires the existing GXTP7386:00 27C6:0113 absolute touchscreen to be mapped to `OneMixPanel` after the panel/external XRandR layout. The current static transform cannot meet this expectation.
    - Every configured dual-display menu path—normal, `FREERDP_TOUCH_DIAG=1`, and `--mouse-only`—maps the device to the validated OneMix output, preserves one `/multimon` wrapper argument, and invokes the wrapper once.
    - The `FREERDP_EXTERNAL_OUTPUT=` rollback fixture retains the prior static orientation transform for the one-panel path rather than applying the dual-display map.
    - If the output-bound XInput command exits nonzero, the private xinitrc exits before invoking the wrapper because the existing fail-fast shell behavior remains effective.
  </behavior>
  <action>
    Start RED in `tests/menu_diagnostic_env_check.sh`. Replace its no-op XInput mock with a deterministic argv recorder that can make the output-bound command fail. Extend the existing generated-xinitrc assertions, not a copied model, so the three valid external-display cases prove the following chronological path: validated OneMix layout, external layout, one `xinput map-to-output` call whose device is `GXTP7386:00 27C6:0113` and whose output is the fixture’s `OneMixPanel`, then the existing wrapper call with `/multimon`. Assert that the one-panel rollback case keeps the existing static orientation command instead. Add a failure-injection case that proves an XInput mapping error prevents wrapper execution. Run the fixture before editing `scripts/menu`; its new dual-output expectation must fail against the current static mapping.

    In the generated xinitrc in `scripts/menu`, leave the existing `xrandr --query` validation, quoted output names, OneMix mode/left rotation/primary layout, external `--right-of` layout, and `/multimon` condition exactly where they are. After those XRandR commands, branch on the already validated external output: with an external output present, invoke `xinput map-to-output` for the existing touchscreen device and the validated `onemix_output`; with no external output, retain the existing Coordinate Transformation Matrix command for the known OneMix-only rotation. Do not run the static matrix after the output-bound command, because both commands write the device mapping and the later writer would replace the CRTC restriction. Do not add device discovery, a new environment variable, a fallback daemon, monitor-ID configuration, or a second X server.

    Keep `scripts/launch-touch.sh`, `patches/onemix-touch.patch`, all FreeRDP session arguments, password handling, and package/calibration behavior unchanged per D-01, D-02, D-07 through D-17, D-18 through D-21, and D-25. Preserve the TTY -> private startx -> XRandR/XInput -> wrapper route and its normal, diagnostic, and mouse-only entry points per D-03 through D-06 and D-22, D-23, and D-24. Reach GREEN by rerunning the focused fixture, the independent production-wrapper regression, and menu shell parsing.
  </action>
  <verify>
    <automated>bash /home/hoang/freerdp-touch/tests/menu_diagnostic_env_check.sh &amp;&amp; bash /home/hoang/freerdp-touch/tests/wrapper_production_check.sh &amp;&amp; bash -n /home/hoang/freerdp-touch/scripts/menu</automated>
  </verify>
  <done>When an external output is configured, the actual menu-generated xinitrc maps the OneMix touchscreen to the validated OneMix CRTC after the dual XRandR layout and before the unchanged wrapper starts; all current menu modes, failures, and the OneMix-only orientation path are regression-tested.</done>
</task>

<task type="auto">
  <name>Task 2: Document and protect the physical dual-display touch-map verification</name>
  <files>README.md, tests/readme_doc_regression.sh</files>
  <read_first>
    - `README.md` Dual-monitor mode and OneMix-only rollback sections — preserve connector discovery, `menu`-only launches, current package rollback, calibration, and accepted certificate-risk guidance.
    - `scripts/menu` after Task 1 — document the exact command behavior, not an alternate direct-wrapper or desktop-session workflow.
    - `tests/readme_doc_regression.sh` — add narrow documentation assertions alongside the existing README regression instead of a new documentation harness.
  </read_first>
  <action>
    In README’s existing Dual-monitor mode section, state that the launcher binds the absolute `GXTP7386:00 27C6:0113` touchscreen to `FREERDP_ONEMIX_OUTPUT` with `xinput map-to-output` after arranging the displays. Explain the reason in operator terms: the binding prevents the touch-emulated cursor from being scaled across the combined desktop when the external display is active. Keep the configured output names, `/multimon`, normal/diagnostic/mouse-only menu examples, and OneMix-only rollback instructions intact; do not tell the operator to invoke the wrapper directly, alter FreeRDP settings, or change the existing D-25 certificate disclosure.

    Add a clearly labeled manual native-X11 verification sequence using `menu` option 3 with both displays connected. It must direct the operator to test a tap and a drag from the center and all four corners of the OneMix panel, including a panel edge near the external display, and confirm the remote pointer/action remains on the OneMix display rather than jumping to the external display. Include a OneMix-only rollback check with `FREERDP_EXTERNAL_OUTPUT=`. State explicitly that the shell fixture proves command wiring only; the physical display/touch result remains unverified until this check is performed on the OneMix hardware.

    Extend `tests/readme_doc_regression.sh` with focused fixed-string checks for the output-bound command and the corner-based manual check, then run the README regression together with the launcher fixtures. This test protects the required operator procedure without attempting to simulate real touchscreen hardware.
  </action>
  <verify>
    <automated>bash /home/hoang/freerdp-touch/tests/readme_doc_regression.sh &amp;&amp; bash /home/hoang/freerdp-touch/tests/menu_diagnostic_env_check.sh &amp;&amp; bash /home/hoang/freerdp-touch/tests/wrapper_production_check.sh</automated>
    <human-check>On the actual OneMix in the native private-Xorg menu flow, connect the external display, run `menu`, choose option 3, and perform the documented center/four-corner/edge tap-and-drag checks. The remote pointer and actions from OneMix touch must stay on the OneMix display; then set `FREERDP_EXTERNAL_OUTPUT=` and confirm the OneMix-only launch still works. Do not treat automated fixture output as a substitute for this hardware result.</human-check>
  </verify>
  <done>README contains a menu-only, reproducible physical verification and rollback procedure for the dual-display touch map, the docs regression guards its essential instructions, and the plan records hardware validation as pending until the owner performs it.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|---|---|
| User environment to generated xinitrc | The configured OneMix output name crosses from the shell into the XInput command. |
| Generated xinitrc to private Xorg | XRandR layout and touchscreen mapping mutate the local display/input coordinate space before FreeRDP starts. |
| X server to FreeRDP | The X server delivers transformed XI2 event coordinates to the unchanged local gesture path. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|---|---|---|---|---|---|
| T-vzf-01 | Tampering | `FREERDP_ONEMIX_OUTPUT` consumed by `scripts/menu` | medium | mitigate | Reuse the existing connected-output and distinct-name validation, quote the name, and test that the XInput target is the validated OneMix fixture output. |
| T-vzf-02 | Denial of Service | Output-bound XInput command in the private xinitrc | medium | mitigate | Preserve `set -eu`; add a fixture failure case that proves a mapping error halts before the wrapper and never begins an incorrectly mapped RDP session. |
| T-vzf-03 | Tampering | FreeRDP launch and local gesture configuration | medium | mitigate | Keep the repair confined to menu’s display/input branch; run normal, diagnostic, and mouse-only paths through the existing production-wrapper regression. |
| T-vzf-04 | Spoofing | Existing RDP certificate handling | high | accept | Preserve the owner-accepted D-25 policy without modifying or claiming to resolve it. |
| T-vzf-SC | Tampering | npm/pip/cargo installs | low | accept | No package-manager install or new package is part of this repair; it uses installed XRandR and xinput commands. |
</threat_model>

<verification>
1. Run the focused generated-xinitrc fixture. It must cover normal, diagnostic, mouse-only, one-panel rollback, invalid output, and injected XInput failure cases.
2. Run the independent wrapper/menu regression and README regression to prove the repair did not alter wrapper argument ownership or protected operational instructions.
3. On the OneMix hardware in the existing native-X11 `menu` flow, execute the documented center/corner/edge touch test while an external display is connected. This is required physical evidence and is not satisfied by mocked XInput commands.
4. Relaunch with `FREERDP_EXTERNAL_OUTPUT=` to confirm the known OneMix-only mapping is still available without package changes.
</verification>

<success_criteria>
- A dual-display `menu` launch maps the OneMix absolute touchscreen to the OneMix XRandR output after display layout, so panel touch does not immediately land on the external display.
- Normal, diagnostic, and mouse-only launches preserve their current private-startx/wrapper/FreeRDP contracts, and a failed map cannot fall through into wrapper execution.
- The one-panel rollback retains the prior rotation mapping and requires no package or FreeRDP source change.
- The repository documents the exact hardware verification steps and distinguishes pending physical evidence from automated command-wiring evidence.
</success_criteria>

<output>
Create `.planning/quick/260907-vzf-hi-n-t-i-khi-t-i-c-m-m-n-h-nh-ngo-i-exte/260907-vzf-SUMMARY.md` when done.
</output>

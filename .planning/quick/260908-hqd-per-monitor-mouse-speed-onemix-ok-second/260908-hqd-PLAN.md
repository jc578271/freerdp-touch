---
mode: quick
phase: quick
plan: 260908-hqd
type: execute
wave: 1
depends_on: []
files_modified:
  - patches/onemix-touch.patch
  - scripts/menu
  - tests/menu_diagnostic_env_check.sh
  - README.md
  - tests/readme_doc_regression.sh
autonomous: true
requirements: [CONF-01]
estimate:
  tokens: 36000
  raw_tokens: 36000
  tasks: 2
  confidence: low
must_haves:
  truths:
    - "Absolute pointer motion on the OneMix CRTC still maps to the OneMix remote monitor after the global smart-sizing transform, so OneMix mouse speed and click targets stay as they are today."
    - "Absolute pointer motion on the external CRTC maps through that monitor's own remote rectangle instead of the single DesktopWidth/scaledWidth factor, so the secondary cursor no longer races across the remote desktop."
    - "When the pointer is on the external CRTC, X pointer acceleration is multiplied by FREERDP_EXTERNAL_POINTER_SPEED/100 against the saved original ratio; on the OneMix CRTC the original ratio is restored."
    - "FREERDP_EXTERNAL_POINTER_SPEED defaults to 50 for a selected external output, accepts canonical whole percents 10 through 200, and is cleared on OneMix-only launches so a stale value cannot change local-only feel."
  artifacts:
    - "patches/onemix-touch.patch adds xf_pointer_map_coordinates and xf_pointer_scale_accel, calls the mapper from xf_event_adjust_coordinates, applies accel only on XI_Motion monitor crossing, and registers TestXfPointerMap in the existing X11 CTest directory."
    - "scripts/menu validates and exports FREERDP_EXTERNAL_POINTER_SPEED only after a selected external output, defaulting to 50."
    - "tests/menu_diagnostic_env_check.sh covers default 50, override 80, invalid rejection, and OneMix-only clearing."
    - "README.md and tests/readme_doc_regression.sh document the dual-monitor pointer-speed contract and the native-X11 physical check."
  key_links:
    - "XI_Motion event_x/event_y -> xf_generic_MotionNotify -> xf_event_adjust_coordinates -> xf_pointer_map_coordinates(rdpMonitor[]) -> PTR_FLAGS_MOVE"
    - "Monitor hit-test -> xf_pointer_scale_accel -> XChangePointerControl, with libinput Accel Speed fallback on Virtual core pointer"
    - "FREERDP_EXTERNAL_POINTER_SPEED -> private xinitrc validation/export -> patched xfreerdp3"
---

<objective>
Make the physical mouse feel equally controllable on both screens of the existing `/multimon` session: keep OneMix speed, slow the too-fast secondary cursor, and keep click targets on the monitor the pointer is actually on.

Purpose: The session already sends two remote monitors (OneMix 200%, external 100%) while the X11 client still maps every absolute `XI_Motion` through one global `DesktopWidth/scaledWidth` smart-sizing factor (`/f` + `/smart-sizing:2560x1600` over the combined CRTC). That single factor, plus Windows 200% vs 100% desktop scale, is why OneMix feels right and the external display feels too fast. Relative-mouse (`FreeRDP_MouseUseRelativeMove`) is off in this launch, so the fix belongs in the existing absolute mapper plus a per-monitor X accel tweak — not a new input subsystem.

Output: One integrated quilt-patch update with a production-path CTest, a validated `FREERDP_EXTERNAL_POINTER_SPEED` launcher knob defaulting to 50, rendered-xinitrc regressions, and operator guidance.

Honor locked Phase 4 decisions without retuning them: D-01: native multitouch stays off. D-02: frozen local gestures stay frozen. D-03: D-04: D-05: D-06: diagnostic gate, compact WLog stderr path, and XDG-state log location stay as they are. D-07: D-08: D-09: D-10: D-11: D-12: one +onemix1 quilt patch, exact four-package closure, no tracked extract/dist, existing rollback docs. D-13: D-14: D-15: D-16: D-17: do not add touch-calibration knobs or a new config file. D-18: D-19: D-20: D-21: D-22: D-23: D-24: keep the credential-free wrapper, --mouse-only hatch, FREERDP_TOUCH_DIAG=1, and TTY-to-private-startx menu topology. D-25: keep /cert:ignore and do not claim certificate identity protection.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/STATE.md
@.planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md
@.planning/quick/260908-1fa-th-m-param-scale-ri-ng-m-n-ph/260908-1fa-SUMMARY.md
@patches/onemix-touch.patch
@scripts/menu
@scripts/launch-touch.sh
@scripts/build-release.sh
@tests/menu_diagnostic_env_check.sh
@tests/wrapper_production_check.sh
@README.md
@tests/readme_doc_regression.sh

<interfaces>
- Canonical dual-monitor launch remains TTY -> menu option 3 -> private startx -> XRandR `--above` layout -> wrapper -> `/usr/bin/xfreerdp3` with `/f /smart-sizing:2560x1600 /scale-desktop:200 /multimon` (D-18, D-22, D-23, D-24). Do not add mouse-relative, grab, or extra `/scale-desktop` flags.
- Physical mouse motion in fallback is `XI_Motion` -> `xf_generic_MotionNotify` -> `xf_event_adjust_coordinates` -> `freerdp_client_send_button_event(..., PTR_FLAGS_MOVE, x, y)`. `FreeRDP_MouseUseRelativeMove` is unset, so `xf_generic_RawMotionNotify` is not the daily path.
- `xf_event_adjust_coordinates` currently applies one XRender factor: `(x - offset_x) * DesktopWidth / scaledWidth` when `xf_picture_transform_required` is true. That is the squash to fix per monitor, not a reason to drop `/smart-sizing`.
- `rdpMonitor` records from `xf_detect_monitors` already carry `x,y,width,height,is_primary` plus `attributes.desktopScaleFactor` (200 primary / 100-or-override secondary via `xf_monitor_apply_scale_attributes`). Reuse those records; do not invent a second monitor list.
- Current XRandR layout is OneMix `--mode 1600x2560 --rotate left --primary` and external `--auto --above`. Post-rotation OneMix CRTC is 2560x1600 below the external CRTC. Hit-test real rectangles; do not assume `--right-of`.
- `debian/rules` already passes `-DBUILD_TESTING=ON`. Register `TestXfPointerMap` next to `TestXfMonitorScale` in `client/X11/test/CMakeLists.txt`.
- `scripts/launch-touch.sh` stays credential-free and must not gain display or pointer-speed policy (D-19).
</interfaces>
</context>

<source_audit>
SOURCE | ID | Feature / constraint | Coverage | Status
--- | --- | --- | --- | ---
GOAL | quick 260908-hqd | OneMix mouse speed stays OK; secondary-display mouse is independently scaled so it is no longer too fast | Tasks 1-2 | COVERED
REQ | CONF-01 | Preserve local-only-touch preset, native-X11 menu flow, display layout, and mouse-only escape hatch | Task 1 leaves wrapper touch args and gesture code untouched; Task 2 confines the new env to menu's external-output branch | COVERED
RESEARCH | xf_event.c / xf_input.c 3.15 | Daily mouse is absolute XI_Motion through xf_event_adjust_coordinates; relative-mouse is off; one global smart-sizing scale | Task 1 | COVERED
RESEARCH | 260908-1fa | Per-monitor desktopScaleFactor already 200/100; do not add a second global /scale-desktop | Task 1 reuses rdpMonitor records; Task 2 adds a separate pointer-speed env | COVERED
CONTEXT | D-01, D-02 | Native multitouch stays off; frozen gesture set is not retuned | Neither task edits recognizer branches | COVERED
CONTEXT | D-07, D-08, D-09, D-10, D-11, D-12 | One integrated +onemix1 quilt patch; exact four-package closure; no tracked extract/dist | Task 1 refreshes the existing patch and uses the current release build | COVERED
CONTEXT | D-13, D-14, D-15, D-16, D-17 | Do not add or retune touch-calibration controls | Pointer-speed is display/mouse metadata, not a touch option | COVERED
CONTEXT | D-18, D-19, D-20, D-21, D-22, D-23, D-24 | Credential-safe TTY-to-private-startx-to-wrapper topology and all three menu entry points | Task 2 keeps policy in menu xinitrc and proves normal/diagnostic/mouse-only | COVERED
CONTEXT | D-25 | Accepted /cert:ignore policy unchanged | No connection-security edits | COVERED
</source_audit>

<dependency_graph>
Task 1 needs the existing quilt patch, rdpMonitor array, and xf_event_adjust_coordinates. It creates the per-monitor mapper, accel helper, and CTest that Task 2's launcher knob drives. Task 2 needs that env name/range, then creates xinitrc validation, rendered-launcher coverage, and docs. Sequential Wave 1; same integrated patch/launcher concern.
</dependency_graph>

<tasks>

<task type="tracer" tdd="true">
  <name>Task 1: Map absolute mouse coordinates per rdpMonitor and scale X accel on the external CRTC</name>
  <files>patches/onemix-touch.patch</files>
  <precondition>Debian build dependencies, quilt, and the tracked src/freerdp3_3.15.0+dfsg-2.1+deb13u3.dsc inputs are available so a full release build can compile and run the registered CTest.</precondition>
  <read_first>
    - patches/onemix-touch.patch — preserve one integrated +onemix1 patch, TestXfMonitorScale, TestXfInputDispatcher, local-touch hunks, and xf_monitor_apply_scale_attributes per D-01, D-02, D-07, D-09, D-10, D-11.
    - src/freerdp3_3.15.0+dfsg.orig.tar.xz client/X11/xf_event.c — xf_event_adjust_coordinates, xf_generic_MotionNotify, xf_generic_ButtonEvent; keep the existing XRender global transform as the fallback when nmonitors is less than 2.
    - src/freerdp3_3.15.0+dfsg.orig.tar.xz client/X11/xf_input.c — XI_Motion is the daily physical-mouse path; do not enable FreeRDP_MouseUseRelativeMove or register a new raw-motion policy.
    - src/freerdp3_3.15.0+dfsg.orig.tar.xz client/X11/xf_monitor.c — rdpMonitor x,y,width,height,is_primary and attributes.desktopScaleFactor are already populated before set_monitor_def_array_sorted.
    - scripts/menu — current layout is external --above the rotated 2560x1600 OneMix CRTC; mapper tests must use that geometry.
  </read_first>
  <behavior>
    - RED: TestXfPointerMap builds an --above fixture matching the live launch: external CRTC 1920x1080 at (0,0), OneMix primary CRTC 2560x1600 at (0,1080), DesktopWidth=2560 DesktopHeight=1600 from /smart-sizing:2560x1600, scaledWidth=2560 scaledHeight=2680 from the fullscreen combined desktop. A point on the OneMix CRTC must land inside the OneMix rdpMonitor rectangle and a point on the external CRTC must land inside the external rdpMonitor rectangle. Today's global y factor 1600/2680 maps OneMix y=1080 to remote y=644, which is still on the external remote monitor, so the current xf_event_adjust_coordinates cannot satisfy the OneMix assertion.
    - The same helper maps the shared horizontal edge from the OneMix side into the primary remote monitor and from the external side into the secondary remote monitor (no jump to the other remote screen).
    - xf_pointer_scale_accel with original X ratio 2/1 and percent 100 returns 2/1; percent 50 returns 1/1; percent 10 returns 1/5 after reduction. xf_pointer_libinput_accel maps 100 to 0.0, 50 to -0.5, 10 to -0.9, 200 to 1.0.
    - FREERDP_EXTERNAL_POINTER_SPEED absent yields derived percent 50 when primary desktop scale is 200 and secondary is 100. Canonical 80 is accepted. Leading-zero, non-digit, 9, and 201 are rejected without changing the out-params.
    - One-monitor input leaves coordinates on the existing global XRender path and does not report an accel change.
  </behavior>
  <action>
    Start RED in a fresh DSC extraction. Add client/X11/test/TestXfPointerMap.c and register it in client/X11/test/CMakeLists.txt beside TestXfMonitorScale. The test must call production helpers declared in xf_event.h, not a copied formula. Cover the --above two-monitor fixture, edge hit-test, accel fraction cases, libinput mapping, env default/override/reject, and the single-monitor fallback. Run the new CTest through the Debian test hook before implementing the helpers and confirm it fails.

    Add two pure helpers (names may match the test) in xf_event.c with declarations in xf_event.h:

    xf_pointer_map_coordinates takes in/out x,y, the rdpMonitor array plus count, and the matching X11 CRTC rectangles in the same order (xfc->vscreen.monitors / orig_screen). For nmonitors greater than 1, RDP mouse space is already the rdpMonitor pixel grid, which matches those CRTCs, so skip the global DesktopWidth/scaledWidth squash: leave the point in root/CRTC coordinates, hit-test the CRTC, and if the point is outside every CRTC clamp it onto the nearest rdpMonitor rather than scaling it onto the other screen. Only if a CRTC size differs from its rdpMonitor size (should not happen in this launch) scale locally into that rdpMonitor rectangle. For nmonitors less than 2, return without changing x,y so the existing xf_event_adjust_coordinates XRender path still runs. Do not build a second monitor list or a new input backend.

    xf_pointer_resolve_external_speed reads FREERDP_EXTERNAL_POINTER_SPEED. Absent/empty with two monitors and primary desktop scale 200 plus secondary 100 yields 50 (100 * secondary / primary). An explicit value must be canonical decimal whole percent 10 through 200 (no leading zero, digits only, length 2 or 3). Invalid input returns FALSE and leaves outputs unchanged. xf_pointer_scale_accel(orig_num, orig_den, percent, out_num, out_den) computes orig * percent / 100 as a reduced positive fraction. xf_pointer_libinput_accel(percent) returns clamp((percent-100)/100.0, -1.0, 1.0).

    Wire xf_pointer_map_coordinates at the start of the XRender branch in xf_event_adjust_coordinates so both MotionNotify and ButtonEvent (and local-touch coordinate adjust) share one path. After a successful per-monitor map, skip the global DesktopWidth/scaledWidth multiply for that event; still run CLAMP_COORDINATES. Do not change xf_generic_RawMotionNotify, do not set FreeRDP_MouseUseRelativeMove, and do not alter /smart-sizing or /scale-desktop.

    On XI_Motion in xf_input_event, after the coordinate path, if nmonitors is greater than 1 and the hit monitor changed (or this is the first motion), apply accel: cache XGetPointerControl once; on the primary CRTC restore that original ratio; on a non-primary CRTC call XChangePointerControl with xf_pointer_scale_accel(original, resolved_percent). If that call has no effect because the device is libinput-managed, set the "libinput Accel Speed" property on "Virtual core pointer" to xf_pointer_libinput_accel(percent) when on external and 0.0 when on OneMix. Call XChangePointerControl only on CRTC change, not on every motion sample. OneMix-only (nmonitors less than 2) never writes pointer control.

    Refresh onemix-touch.patch from the clean quilt tree, keeping the existing +onemix1 changelog and unrelated hunks. Do not track an extracted tree or dist artifacts (D-07: D-10: D-11:). Re-apply in a second fresh extraction, then run the ordinary full release build without DEB_BUILD_OPTIONS=nocheck so TestXfPointerMap and existing X11 tests run. Four-package +onemix1 remains the delivery unit (D-08: D-09: D-12:). Do not rewrite gesture branches (D-01: D-02:), do not add touch-calibration settings (D-13: D-14: D-15: D-16: D-17:), and do not change diagnostic logging (D-03: D-04: D-05: D-06:).
  </action>
  <verify>
    <automated>cd /home/hoang/freerdp-touch &amp;&amp; env -u DEB_BUILD_OPTIONS ./scripts/build-release.sh</automated>
  </verify>
  <done>A fresh quilt application builds the exact package closure and TestXfPointerMap proves OneMix CRTC points stay on the primary remote monitor, external CRTC points stay on the secondary remote monitor, and external accel fractions/libinput values match the 10-200 percent contract.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Export and document FREERDP_EXTERNAL_POINTER_SPEED in the existing menu flow</name>
  <files>scripts/menu, tests/menu_diagnostic_env_check.sh, README.md, tests/readme_doc_regression.sh</files>
  <read_first>
    - scripts/menu — preserve --mouse-only, password quoting, private xinitrc, OneMix --above layout, FREERDP_EXTERNAL_DESKTOP_SCALE, output-bound xinput map, one /scale-desktop:200, and wrapper exec per D-18 through D-24.
    - tests/menu_diagnostic_env_check.sh — extend the rendered-xinitrc fixture; it already records wrapper env and args.
    - patches/onemix-touch.patch after Task 1 — env name, default 50, and 10-200 range must match the client helper exactly.
    - README.md Dual-monitor section and tests/readme_doc_regression.sh — add only the pointer-speed contract; keep D-25, desktop-scale, and touch-map text.
  </read_first>
  <behavior>
    - RED: a dual-monitor normal/diagnostic/mouse-only fixture with the pointer-speed variable omitted reaches the wrapper with FREERDP_EXTERNAL_POINTER_SPEED=50, still exactly one /scale-desktop:200, /multimon, and the OneMix touch map.
    - FREERDP_EXTERNAL_POINTER_SPEED=80 reaches the wrapper as 80; desktop-scale env and the single global 200 argument stay unchanged.
    - Nondecimal, leading-zero, 9, and 201 fail in the generated xinitrc before the wrapper and print a corrective error.
    - Explicit OneMix-only launch unsets FREERDP_EXTERNAL_POINTER_SPEED (and still unsets FREERDP_EXTERNAL_DESKTOP_SCALE) before the wrapper.
    - README states default 50, range 10-200, that OneMix uses the original X accel, that the value is environment metadata not a FreeRDP CLI flag, and the physical check: OneMix feel unchanged, external cursor no longer too fast, clicks land on the hovered remote monitor.
  </behavior>
  <action>
    Start RED by extending tests/menu_diagnostic_env_check.sh. Record FREERDP_EXTERNAL_POINTER_SPEED in the wrapper mock the same way the desktop-scale env is recorded. Add dual-display cases: omitted value yields 50; explicit 80 yields 80; both keep FREERDP_EXTERNAL_DESKTOP_SCALE default/override behavior, one /scale-desktop:200, /multimon, and the output-bound touch map. Add rejected cases for 14x, 080, 9, and 201 that must not invoke the wrapper. Add a OneMix-only case that observes the pointer-speed variable as unset. Run the fixture before editing scripts/menu and confirm the new assertions fail.

    In scripts/menu's generated xinitrc, after a validated external output is selected and after the existing desktop-scale block, resolve FREERDP_EXTERNAL_POINTER_SPEED: unset/empty becomes 50; otherwise require canonical whole percent 10 through 200 (pattern that rejects leading zeros and values outside that range) and export the normalized value. When no external output is selected, unset FREERDP_EXTERNAL_POINTER_SPEED next to the existing desktop-scale unset. Do not pass a new xfreerdp3 argument, do not move this into scripts/launch-touch.sh (D-18: D-19:), and do not change /smart-sizing:2560x1600, /scale-desktop:200, /multimon, XRandR --above, --mouse-only, FREERDP_TOUCH_DIAG, or certificate args (D-20: D-21: D-22: D-23: D-24: D-25:). Do not add a touch-calibration control or config file (D-13: D-14: D-15: D-16: D-17:). Keep native multitouch off and gestures frozen (D-01: D-02:). Diagnostic log path and WLog stderr tee stay unchanged (D-03: D-04: D-05: D-06:). Package identity remains the existing +onemix1 quilt/release flow (D-07: D-08: D-09: D-10: D-11: D-12:).

    Add a Dual-monitor pointer speed paragraph in README next to the existing per-monitor desktop-scale section. Document FREERDP_EXTERNAL_POINTER_SPEED default 50, range 10-200, OneMix original-accel guarantee, combination with FREERDP_EXTERNAL_DESKTOP_SCALE, and that OneMix-only clears it. Include a native-X11 physical check: move the USB mouse on the OneMix panel (feel unchanged), move it onto the external display (cursor no longer too fast; raise toward 80/100 if too slow), and click a known target on each screen (action stays on that remote monitor). Extend tests/readme_doc_regression.sh with required-text assertions for the variable, default 50, range 10-200, OneMix original accel, and the physical check. Leave touch, package, rollback, and D-25 wording intact.
  </action>
  <verify>
    <automated>cd /home/hoang/freerdp-touch &amp;&amp; bash tests/menu_diagnostic_env_check.sh &amp;&amp; bash tests/readme_doc_regression.sh &amp;&amp; bash tests/wrapper_production_check.sh &amp;&amp; bash -n scripts/menu &amp;&amp; git diff --check</automated>
    <human-check>On the OneMix in the native private-Xorg menu flow with both displays connected, launch menu option 3. Confirm USB-mouse motion on the OneMix panel still feels as before and clicks hit the hovered OneMix window. Move onto the external display: the cursor must no longer race; clicks must hit the hovered external window. If still slightly fast or slow, relaunch with FREERDP_EXTERNAL_POINTER_SPEED=80 or 40 and confirm only the external feel changes. Then FREERDP_EXTERNAL_OUTPUT= menu option 3 and confirm OneMix-only mouse feel is unchanged.</human-check>
  </verify>
  <done>Menu option 3 supplies default 50 or a validated 10-200 pointer-speed value only for a selected secondary output, clears it for OneMix-only, documents the physical check, and does not change touch, wrapper, package, desktop-scale, or certificate policy.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|---|---|
| User environment to generated xinitrc | FREERDP_EXTERNAL_POINTER_SPEED crosses from the invoking shell into display/input setup. |
| Private xinitrc to patched X11 client | A validated percent is exported only after an external output is selected. |
| X11 pointer events to RDP mouse PDU | Absolute XI_Motion coordinates are remapped per rdpMonitor before PTR_FLAGS_MOVE. |
| Patched client to local X server | XChangePointerControl / libinput Accel Speed mutate pointer acceleration on the private X server. |
| Existing menu session to RDP server | Password, connection arguments, and accepted certificate policy cross unchanged. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|---|---|---|---|---|---|
| T-hqd-01 | Tampering | FREERDP_EXTERNAL_POINTER_SPEED in menu and xf_event.c | medium | mitigate | Validate canonical decimal 10-200 in the xinitrc before wrapper start and again in the production helper; reject malformed values without applying accel or starting the client. |
| T-hqd-02 | Tampering | xf_pointer_map_coordinates | medium | mitigate | Hit-test real CRTC rectangles against rdpMonitor records so a point on one physical screen cannot be scaled onto the other remote monitor; cover with TestXfPointerMap including the shared edge. |
| T-hqd-03 | Denial of Service | XChangePointerControl on the private X server | low | mitigate | Apply accel only when nmonitors is greater than 1 and only on CRTC change; restore the original ratio on the OneMix CRTC; the private startx server dies with the session. |
| T-hqd-04 | Tampering | Wrapper/client boundary | medium | mitigate | Keep pointer-speed metadata in the menu-owned environment; do not add a FreeRDP CLI flag the stock client would reject; run wrapper_production_check.sh. |
| T-hqd-05 | Spoofing | Existing RDP certificate policy | high | accept | Preserve D-25 unchanged; this pointer-mapping change does not claim certificate identity protection. |
| T-hqd-SC | Tampering | npm/pip/cargo installs | low | accept | No package-manager install is introduced; implementation uses tracked Debian source, X11 pointer control, and existing FreeRDP types. |
</threat_model>

<verification>
1. Run TestXfPointerMap inside the ordinary release build (no nocheck) together with the existing X11 CTests.
2. Run the rendered-xinitrc fixture for default 50, override 80, invalid rejection, OneMix-only clearing, and unchanged desktop-scale /multimon / touch-map contracts.
3. Run README and wrapper regressions plus git diff --check.
4. Perform the documented native-X11 physical mouse check on both screens and the OneMix-only rollback.
</verification>

<success_criteria>
- OneMix mouse speed and click targets remain as they are in the current dual-monitor session.
- External-display mouse motion maps to the external remote monitor and is slowed by FREERDP_EXTERNAL_POINTER_SPEED (default 50, range 10-200) without a second /scale-desktop argument and without enabling relative-mouse.
- OneMix-only launches, local touch, wrapper ownership, package closure, rollback route, per-monitor desktop scale, and accepted certificate policy remain unchanged.
- The integrated quilt patch builds with the existing Debian workflow and TestXfPointerMap passes.
</success_criteria>

<output>
Create /home/hoang/freerdp-touch/.planning/quick/260908-hqd-per-monitor-mouse-speed-onemix-ok-second/260908-hqd-SUMMARY.md when done.
</output>

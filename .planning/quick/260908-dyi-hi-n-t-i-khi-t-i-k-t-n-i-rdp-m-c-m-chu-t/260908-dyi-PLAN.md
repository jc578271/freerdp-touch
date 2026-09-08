---
mode: quick
phase: quick
plan: 260908-dyi
type: execute
wave: 1
depends_on: []
files_modified:
  - patches/onemix-touch.patch
autonomous: true
requirements: [CONF-01, XINP-01, GEST-03]
estimate:
  tokens: 28000
  raw_tokens: 28000
  tasks: 2
  confidence: low
must_haves:
  truths:
    - "With +touch-pinch-wheel-fallback active and a physical mouse plugged in, rotating the mouse wheel sends RDP wheel ticks through freerdp_client_send_wheel_event."
    - "XI2 motion samples that carry RelVertWheel or RelHorizWheel valuators become the same 0x78 detents already used by Button4/Button5 and two-finger scroll."
    - "Touch-emulated core and XI pointer buttons remain suppressed, so two-finger scroll does not grow a duplicate physical-wheel path."
    - "Existing local-only gestures stay unchanged: one-finger tap/drag/long-press, two-finger wheel, pinch Ctrl+wheel, three-finger middle-button drag."
  artifacts:
    - "patches/onemix-touch.patch adds xf_input_send_wheel_from_valuators and calls it from the XI_Motion and XI_RawMotion arms of xf_input_event."
    - "client/X11/test/TestXfInputDispatcher.c covers positive and negative vertical valuators plus a horizontal valuator, using the production helper and MouseEvent capture."
  key_links:
    - "XI_Motion / XI_RawMotion valuators -> xf_input_send_wheel_from_valuators -> freerdp_client_send_wheel_event"
    - "XIPointerEmulated still breaks out of xf_input_handle_event_remote before xf_input_event, so touch-emulated pointer buttons never become RDP buttons or wheel ticks"
    - "xi_event remains forced TRUE in fallback so core X11 ButtonPress does not leak touch-emulated BUTTON1"
---

<objective>
Make a plugged-in physical mouse wheel scroll the remote Windows session while the canonical local-only touch preset stays enabled.

Purpose: Fallback mode currently selects XI_Motion on the USB mouse and forces `xi_event`, which drops core Button4/Button5. Modern libinput then delivers RelVertWheel/RelHorizWheel on XI_Motion instead of discrete button 4/5, and `xf_input_event` ignores those valuators. Two-finger gesture scroll is unrelated and already works.

Output: One integrated quilt-patch update that converts mouse-wheel valuators through the existing `freerdp_client_send_wheel_event` helper, plus a production-path CTest. No new CLI, env var, package, or gesture change.

Discovery level: 1. Local FreeRDP 3.15 `xf_event.c` / `xf_input.c` plus `patches/onemix-touch.patch` established the swallow: core ButtonPress returns early when `xi_event` is set; XI2 button 4/5 still map via `xf_generic_ButtonEvent`; XI2 motion never reads wheel valuators.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/STATE.md
@.planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md
@patches/onemix-touch.patch
@scripts/build-release.sh
@scripts/launch-touch.sh

<interfaces>
- Canonical launch still prepends `+touch-pinch-wheel-fallback` from `scripts/launch-touch.sh` and omits `+multitouch` (D-01, D-20). Do not add mouse-relative, grab, or wheel CLI flags.
- `xf_input_init` in fallback forces `xfc->xi_event = TRUE` so core `xf_event_ButtonPress` does not leak touch-emulated BUTTON1. Keep that force-on. Do not open core Button4/Button5 as a shortcut; that reintroduces touch-emulated wheel beside the two-finger recognizer.
- `register_input_events` still skips XI button/motion masks on devices that have XIDirectTouch in fallback, and still selects XI_ButtonPress/Release/Motion on a normal USB mouse. HierarchyChanged already re-runs that registration on hotplug.
- `xf_input_handle_event_remote` drops `XIPointerEmulated` before `xf_input_event`. Physical mouse wheel is not emulated; touch-emulated pointer events stay dropped (XINP-01).
- `xf_generic_ButtonEvent` already maps Button4/Button5/6/7 through `xfc->button_map` onto `PTR_FLAGS_WHEEL` / `PTR_FLAGS_HWHEEL` and calls `freerdp_client_send_wheel_event`. Discrete XI2 button 4/5 must keep using that path.
- Two-finger scroll already emits `PTR_FLAGS_WHEEL | 0x78` and `PTR_FLAGS_WHEEL | PTR_FLAGS_WHEEL_NEGATIVE | (0x100 - 0x78)`. Physical-mouse valuators must reuse those exact detents, not a new encoder.
- `TestXfInputDispatcher.c` already wraps `XGetEventData`/`XFreeEventData`, captures `rdpInput.MouseEvent`, and runs local-only dispatcher cases with `FreeRDP_TouchPinchWheelFallback=true` and `FreeRDP_MultiTouchInput=false`. Extend that fixture; do not add a second test binary.
</interfaces>
</context>

<source_audit>
SOURCE | ID | Feature / constraint | Coverage | Status
--- | --- | --- | --- | ---
GOAL | quick 260908-dyi | Physical mouse wheel scrolls the RDP session when a mouse is plugged in during a local-only-touch connect | Tasks 1-2 | COVERED
REQ | CONF-01 | Keep the documented local-only-touch preset, native-X11 menu flow, and mouse-only escape hatch | Neither task changes wrapper/menu arguments; fallback still owns touch | COVERED
REQ | XINP-01 | A physical touch must not also emit a duplicate pointer/button action | Task 1 keeps XIPointerEmulated suppression and the core `xi_event` force-on | COVERED
REQ | GEST-03 | Two-finger translation still emits wheel scroll; three-finger still middle-drags | Task 2 requires the existing dispatcher two-finger/three-finger cases to stay in main() and pass | COVERED
RESEARCH | xf_event.c / xf_input.c 3.15 | Core ButtonPress is ignored when `xi_event`; XI2 motion never reads RelVertWheel | Task 1 | COVERED
CONTEXT | D-01, D-02 | Native multitouch stays off; frozen gesture set is not retuned | Tasks 1-2 leave the recognizer branches untouched | COVERED
CONTEXT | D-07, D-09, D-10, D-11 | One integrated `+onemix1` quilt patch; do not track extracted trees or dist artifacts | Task 2 | COVERED
CONTEXT | D-13..D-17 | No new calibration knobs | No new settings | COVERED
CONTEXT | D-18..D-24 | Launch topology and `--mouse-only` stay as they are | No launcher edits | COVERED
CONTEXT | D-25 | `/cert:ignore` policy unchanged | No connection-security edits | COVERED
</source_audit>

<dependency_graph>
Task 1 needs the current integrated patch, `xf_input_event`, and `TestXfInputDispatcher`. It creates the valuator-to-wheel helper, the XI_Motion/XI_RawMotion calls, and the failing-then-passing CTest cases. Task 2 needs that patch content, then refreshes `onemix-touch.patch` from a clean quilt tree and proves the Debian test hook plus existing gesture cases still pass. Both touch the same patch file, so they run sequentially in this Wave-1 plan.
</dependency_graph>

<tasks>

<task type="tracer" tdd="true">
  <name>Task 1: Convert XI2 mouse-wheel valuators into existing RDP wheel detents</name>
  <files>patches/onemix-touch.patch</files>
  <precondition>Debian build dependencies, quilt, and the tracked src/freerdp3_3.15.0+dfsg-2.1+deb13u3.dsc inputs are available so the X11 dispatcher CTest can compile.</precondition>
  <read_first>
    - patches/onemix-touch.patch — fallback `xi_event` force-on, hasTouchClass button-mask skip, XIPointerEmulated break, `xf_input_event` XI_Motion/XI_RawMotion arms, two-finger `freerdp_client_send_wheel_event` detents, and TestXfInputDispatcher capture helpers. Preserve D-01, D-02, D-07, and XINP-01.
    - orig tarball client/X11/xf_event.c — `xf_event_ButtonPress` returns immediately when `xi_event` is set; `xf_generic_ButtonEvent` already sends wheel for Button4/5. Do not reopen core Button4/5.
    - orig tarball client/X11/xf_input.c — stock `xf_input_event` only uses valuators 0/1 on raw motion; pen code already walks `event->valuators` with XIMaskIsSet.
    - orig tarball client/common/client.c — `freerdp_client_send_wheel_event` is the only send helper to call.
  </read_first>
  <behavior>
    - RED: TestXfInputDispatcher builds a valuator mask with bit 2 set and values[0] = 1.0, calls the production helper, and requires MouseEvent to contain PTR_FLAGS_WHEEL with detent 0x78. The test fails before the helper exists.
    - The same helper with values[0] = -1.0 emits PTR_FLAGS_WHEEL | PTR_FLAGS_WHEEL_NEGATIVE | (0x100 - 0x78).
    - A mask with bit 3 set emits PTR_FLAGS_HWHEEL using the same detent magnitude already used for buttons 6/7.
    - Valuator bits 0 and 1 never emit wheel flags.
    - An empty mask or NULL values pointer emits nothing.
    - Existing dispatcher cases still pass: short tap, two-finger scroll claim, three-finger middle-button claim, quarantine recovery.
  </behavior>
  <action>
    Work in a fresh extraction from the tracked DSC, never a committed build tree. Start RED by extending TestXfInputDispatcher.c, not a new binary: add MouseEvent-capture cases that call a production helper declared in xf_input.h (same seam style as the monitor-scale helper). Do not spin up an X server. Name the helper xf_input_send_wheel_from_valuators; it takes xfContext, the valuator mask bytes, mask_len, and the values pointer used by XIDeviceEvent/XIRawEvent. Seed button-map-independent capture through rdpInput.MouseEvent the same way the tap tests already do.

    Implement the helper in xf_input.c. Walk set valuators the same way xf_input_pen_remote already walks event->valuators (XIMaskIsSet, advance the values pointer only for set bits). Ignore axes 0 and 1. For each remaining set axis, if the sample is non-zero, send one existing detent through freerdp_client_send_wheel_event: axis 2 uses vertical PTR_FLAGS_WHEEL, any later axis uses PTR_FLAGS_HWHEEL; positive sample uses 0x78, negative sample uses PTR_FLAGS_WHEEL_NEGATIVE | (0x100 - 0x78). That is the same encoding two-finger scroll and xf_button_flags already use. Do not add xfContext accumulators, settings keys, or a new encoder. Zero/empty input returns without sending.

    Call the helper from xf_input_event's XI_Motion arm after the existing xf_generic_MotionNotify, using event->valuators.mask / mask_len / values. Call it again from the XI_RawMotion arm after the existing raw x/y handling, using the XIRawEvent valuators, so a relative-mouse grab cannot drop wheel either. Do not change the XI_ButtonPress arm: discrete Button4/5 continue through xf_generic_ButtonEvent. Do not clear the fallback xi_event force-on. Do not select button/motion masks on XIDirectTouch devices. Do not remove the XIPointerEmulated break in xf_input_handle_event_remote. Do not edit the two-finger/pinch/three-finger recognizer.

    Refresh onemix-touch.patch from that quilt tree when the new cases fail, then implement until they pass. Leave debian changelog at +onemix1. Do not add files outside the existing patch set.
  </action>
  <verify>
    <automated>cd /home/hoang/freerdp-touch &amp;&amp; test "$(grep -c 'xf_input_send_wheel_from_valuators(' patches/onemix-touch.patch)" -ge 3 &amp;&amp; grep -F 'freerdp_client_send_wheel_event' patches/onemix-touch.patch</automated>
  </verify>
  <done>The production helper turns vertical/horizontal valuator samples into the existing RDP wheel detents, is called from both XI2 motion arms, and the new dispatcher cases plus the old gesture cases compile into TestXfInputDispatcher.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Refresh the quilt patch and prove the dispatcher still owns touch plus mouse wheel</name>
  <files>patches/onemix-touch.patch</files>
  <read_first>
    - patches/onemix-touch.patch after Task 1 — keep one integrated patch, current +onemix1 changelog, TestXfInputDispatcher, TestXfMonitorScale, and every unrelated hunk.
    - scripts/build-release.sh — exact four-package publication with BUILD_TESTING=ON; do not set DEB_BUILD_OPTIONS=nocheck.
    - tests/patch_application_check.sh — still requires the monitor-scale helper; do not regress it.
    - scripts/launch-touch.sh and scripts/menu — read only; do not change launch flags, calibration, or --mouse-only.
  </read_first>
  <behavior>
    - A second clean dpkg-source -x plus quilt push applies onemix-touch.patch with no rejects.
    - Debian BUILD_TESTING runs TestXfInputDispatcher including the new valuator cases and the existing two-finger/three-finger/tap/quarantine cases, all passing.
    - TestXfMonitorScale still runs.
    - grep of the applied xf_input.c shows xf_input_send_wheel_from_valuators called from both XI_Motion and XI_RawMotion, the fallback xi_event assignment still present, and the XIPointerEmulated break still present.
    - launch-touch.sh still prepends +touch-pinch-wheel-fallback and still has no extra mouse-wheel option.
  </behavior>
  <action>
    Refresh patches/onemix-touch.patch from a second throwaway extraction so the quilt file matches the repaired xf_input.c / xf_input.h / TestXfInputDispatcher.c. Keep the patch as the only tracked source change (D-07, D-11). Do not commit extracted trees, debian build dirs, or dist packages.

    Prove application with the existing tests/patch_application_check.sh plus a focused applied-tree grep that the new helper is defined once and called from the XI_Motion and XI_RawMotion switch arms in client/X11/xf_input.c. Then run the ordinary full release build without DEB_BUILD_OPTIONS=nocheck so Debian's BUILD_TESTING=ON compiles and executes TestXfInputDispatcher and TestXfMonitorScale. Do not retune gestures, do not edit scripts/menu or scripts/launch-touch.sh, and do not add a wheel-related rdpSetting. The four-package +onemix1 closure remains the install/rollback unit (D-08, D-09, D-12).
  </action>
  <verify>
    <automated>cd /home/hoang/freerdp-touch &amp;&amp; bash tests/patch_application_check.sh &amp;&amp; env -u DEB_BUILD_OPTIONS ./scripts/build-release.sh</automated>
    <human-check>On the OneMix native-X11 TTY menu flow, connect as usual with +touch-pinch-wheel-fallback, plug in the USB mouse, and rotate the wheel over a scrollable Windows window: content must scroll. Left-click and pointer motion from that mouse must still work. Two-finger touch scroll and pinch Ctrl+wheel must still work. Unplug the mouse and confirm touch-only use is unchanged.</human-check>
  </verify>
  <done>The refreshed quilt patch applies cleanly, the Debian test hook runs the new valuator cases together with the frozen gesture dispatcher cases, and a physical mouse wheel scrolls the remote session without restoring native multitouch or core touch-emulated buttons.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|---|---|
| Physical USB mouse / XInput2 -> xf_input_event | Untrusted valuator samples and button details enter the X11 client. |
| Touchscreen XI2 -> local gesture recognizer | Touch events must not also appear as mouse-wheel ticks. |
| X11 client -> RDP mouse PDU | Wheel flags cross into the remote session via freerdp_client_send_wheel_event. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|---|---|---|---|---|---|
| T-dyi-01 | Tampering | xf_input_send_wheel_from_valuators | medium | mitigate | Ignore axes 0/1; only emit the existing bounded 0x78 detent encoding; empty/NULL valuators send nothing. Cover with TestXfInputDispatcher. |
| T-dyi-02 | Elevation of Privilege / Spoofing | XIPointerEmulated vs physical mouse | medium | mitigate | Keep the emulated-pointer break so touch-generated button/motion cannot be treated as a USB wheel; keep fallback xi_event forced TRUE so core emulated BUTTON1 cannot leak. |
| T-dyi-03 | Denial of Service | Wheel flood from noisy valuators | low | accept | One detent per non-zero sample matches discrete Button4/5; a high-resolution device may tick more often, which is the same class of input the unpatched client already accepted from button events. |
| T-dyi-04 | Information Disclosure | Diagnostic logs | low | mitigate | Do not log pointer coordinates or valuator dumps on the default-off path; do not add new FREERDP_TOUCH_DIAG fields for mouse wheel. |
| T-dyi-05 | Spoofing | Existing RDP certificate policy | high | accept | D-25 remains; this input-path fix does not claim certificate identity protection. |
| T-dyi-SC | Tampering | npm/pip/cargo installs | low | accept | No package-manager install; implementation stays in the tracked Debian quilt patch and existing CTest. |
</threat_model>

<verification>
- TestXfInputDispatcher includes valuator-to-wheel cases and still runs the frozen local-only gesture cases.
- Applied xf_input.c calls xf_input_send_wheel_from_valuators from XI_Motion and XI_RawMotion.
- Fallback still forces xi_event and still drops XIPointerEmulated before xf_input_event.
- scripts/launch-touch.sh is unchanged.
- Full release build without nocheck compiles and runs the X11 CTests.
</verification>

<success_criteria>
A user who connects with the canonical local-only-touch preset and plugs in a mouse can scroll Windows with the mouse wheel, while two-finger touch scroll continues to work and touch-emulated pointer buttons stay suppressed.
</success_criteria>

<output>
Create `.planning/quick/260908-dyi-hi-n-t-i-khi-t-i-k-t-n-i-rdp-m-c-m-chu-t/260908-dyi-SUMMARY.md` when done
</output>

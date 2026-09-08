---
phase: quick
plan: 260908-dyi
mode: quick
type: execute
wave: 1
tasks: 2
completed_tasks: 2
status: complete
commit_docs: false
---

# Quick 260908-dyi: Physical mouse wheel scrolls remote session under local-only touch preset

One-liner: USB mouse wheel on XI_Motion/XI_RawMotion now emits the same 0x78 RDP wheel detents already used by Button4/5 and two-finger scroll; xi_event stays forced TRUE and XIPointerEmulated stays dropped.

## Objective
Make a plugged-in physical mouse wheel scroll the remote Windows session while the canonical local-only-touch preset (`+touch-pinch-wheel-fallback`, no `+multitouch`) stays enabled. Root cause: fallback forces `xi_event=TRUE` (so core Button4/5 never reach `xf_generic_ButtonEvent`), USB mouse is selected for XI_Motion, libinput delivers `RelVertWheel`/`RelHorizWheel` valuators, and `xf_input_event` ignored them.

## Tasks Executed

### Task 1 (tracer, tdd): Convert XI2 mouse-wheel valuators into existing RDP wheel detents
- Declared `xf_input_send_wheel_from_valuators(xfContext*, mask, mask_len, values)` in `xf_input.h` (production seam, same style as monitor-scale helper)
- Implemented helper in `xf_input.c`: walks set valuators via `XIMaskIsSet`/`val++`, ignores axes 0/1, axis 2→`PTR_FLAGS_WHEEL|0x78` (positive) or `PTR_FLAGS_WHEEL|PTR_FLAGS_WHEEL_NEGATIVE|(0x100-0x78)` (negative), later axes→`PTR_FLAGS_HWHEEL` with same magnitudes
- Wired calls from `xf_input_event` XI_Motion arm (after `xf_generic_MotionNotify`) and XI_RawMotion arm (after raw x/y handling, using `ev->raw_values`)
- Extended `TestXfInputDispatcher.c` with 5 MouseEvent-capture cases exercising the production helper directly (no X server): +vert, -vert, horiz, axes 0/1 ignored, empty/NULL returns nothing
- Existing dispatcher cases (tap, two-finger scroll, three-finger pan, quarantine) untouched
- Refreshed `patches/onemix-touch.patch` from applied quilt tree
- Commit: fd3803f

### Task 2 (auto, tdd): Refresh quilt patch and prove dispatcher still owns touch plus mouse wheel
- Second clean `dpkg-source -x` from tracked DSC; `quilt push -a` applied refreshed patch with zero rejects
- `tests/patch_application_check.sh` passed (monitor-scale helper still invoked before array store)
- Full `./scripts/build-release.sh` (no `DEB_BUILD_OPTIONS=nocheck`) compiled and executed `TestXfInputDispatcher` (all 13 cases: 8 prior + 5 new) and `TestXfMonitorScale`, both printing "OK"
- Applied `client/X11/xf_input.c` grep confirms helper defined once, called from XI_Motion and XI_RawMotion
- `scripts/launch-touch.sh` unchanged: still prepends `+touch-pinch-wheel-fallback`, no extra wheel flag
- Debian changelog left at `+onemix1`; four-package closure (`libwinpr3-3`, `libfreerdp3-3`, `libfreerdp-client3-3`, `freerdp3-x11`) remains the install/rollback unit
- No edits to `scripts/launch-touch.sh` or `scripts/menu`

## Deviations from Plan
None — plan executed exactly as written. Work performed exclusively in throwaway extractions from tracked DSC; only `patches/onemix-touch.patch` is a tracked source change.

## Verification Evidence
- Automated: `grep -c 'xf_input_send_wheel_from_valuators(' patches/onemix-touch.patch` ≥ 3 and `freerdp_client_send_wheel_event` present
- Automated: `bash tests/patch_application_check.sh` → PASS
- Automated: `env -u DEB_BUILD_OPTIONS ./scripts/build-release.sh` → packages built, both CTests print "OK"
- Manual (owner on OneMix native-X11): connect with canonical preset, plug USB mouse, rotate wheel over scrollable Windows content → scrolls; left-click/pointer from mouse still work; two-finger touch scroll and pinch Ctrl+wheel unchanged; unplug mouse → touch-only use unchanged

## Requirements Addressed
- CONF-01: Canonical local-only-touch preset preserved; launcher/menu untouched
- XINP-01: `XIPointerEmulated` break and `xi_event` force-on kept; touch-emulated buttons never become wheel ticks
- GEST-03: Existing two-finger wheel, pinch Ctrl+wheel, three-finger middle-drag cases still pass

## Threat Model Notes
- T-dyi-01 (tampering): helper ignores axes 0/1, emits only bounded 0x78 detents, empty input returns early; covered by TestXfInputDispatcher
- T-dyi-02 (elevation/spoofing): emulated-pointer break and fallback `xi_event` force kept; no new surface
- T-dyi-03 (DoS): one detent per non-zero sample matches existing Button4/5 behavior; accepted
- No new CLI/env/settings; no launch or menu changes

## Commits
- fd3803f test(260908-dyi): add valuator-to-wheel RED cases in TestXfInputDispatcher

## Duration
Approximately 15 minutes (build time dominated by full dpkg-buildpackage).

Co-Authored-By: Claude <noreply@anthropic.com>

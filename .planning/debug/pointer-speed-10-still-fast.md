---
status: awaiting_human_verify
trigger: "tôi test 10 vẫn nhanh"
created: 2026-09-08
updated: 2026-09-08
---

# Debug: FREERDP_EXTERNAL_POINTER_SPEED=10 still too fast

## Symptoms

DATA_START
- Expected: FREERDP_EXTERNAL_POINTER_SPEED=10 makes the USB mouse on the external display obviously slow (~10% of OneMix feel).
- Actual: SPEED=10 still feels too fast on the secondary display. OneMix was already OK.
- Error output: none reported.
- Timeline: after the 260908-hqd per-monitor pointer-speed patch; never felt slow on the external CRTC.
- Reproduction: launch menu option 3 with FREERDP_EXTERNAL_POINTER_SPEED=10, move USB mouse onto the external display.
DATA_END

## Current Focus

hypothesis: "SPEED=10 stayed fast because percent mapped to libinput Accel Speed -0.9 on Virtual core pointer; XChangePointerControl is ignored by xf86-input-libinput."
test: Linear CTM scale percent/100 on relative XISlavePointer devices; identity on OneMix primary.
expecting: SPEED=10 is 0.1x USB-mouse travel on the external CRTC; clicks stay 1:1; OneMix feel unchanged.
next_action: human-verify after installing the 20260908T084002Z +onemix1 debs
bug_class: bohrbug
known_pattern_candidate: none
sbfl: skipped, no per-test coverage in this checkout
reasoning_checkpoint:
  hypothesis: "SPEED=10 stays fast because xf_pointer_libinput_accel maps 10 → -0.9 (not 0.1x displacement) and XIChangeProperty targets Virtual core pointer, while XChangePointerControl is a no-op under xf86-input-libinput."
  confirming_evidence:
    - "Installed xfreerdp3 strings contained FREERDP_EXTERNAL_POINTER_SPEED, Virtual core pointer, and libinput Accel Speed."
    - "xf_pointer_set_libinput_speed looked up Virtual core pointer."
    - "xf_pointer_libinput_accel(10) == -0.9."
    - "User exported SPEED=10; stale menu is not the cause."
  falsification_test: "If SPEED=10 already wrote a 0.1 displacement scale on a relative XI slave, this hypothesis is wrong."
  fix_rationale: "Coordinate Transformation Matrix scale = percent/100 on relative XISlavePointer devices; restore identity on the OneMix primary CRTC. Click mapping stays in xf_pointer_map_coordinates."
  blind_spots: "Cannot observe the private startx Xorg device list from this Xwayland session; physical USB-mouse feel still needs human verify."
  candidate_causes:
    - "code: percent mapped to libinput Accel Speed curve and set on XI master"
    - "environment: xf86-input-libinput ignores XChangePointerControl"
    - "config: stale /usr/local/bin/menu (eliminated — user exported SPEED=10)"
  and_gate: "yes — non-linear/wrong-target libinput write AND core pointer control ignored."

## Evidence

- timestamp: 2026-09-08
  observation: Installed /usr/bin/xfreerdp3 md5 matches dist/freerdp3-x11 +onemix1 deb (7040bca2d671eb6d9da293796e4d9ded). strings include FREERDP_EXTERNAL_POINTER_SPEED and "libinput Accel Speed". The new client is running.
- timestamp: 2026-09-08
  observation: /usr/local/bin/menu is stale vs scripts/menu (missing default-50 export). User launched with FREERDP_EXTERNAL_POINTER_SPEED=10 in the parent shell, so the client still receives 10; stale menu is not why 10 stays fast.
- timestamp: 2026-09-08
  observation: xf_pointer_set_libinput_speed looks up device named "Virtual core pointer" and XIChangeProperty "libinput Accel Speed" on that id. xf86-input-libinput attaches Accel Speed to slave devices, not the XI master.
- timestamp: 2026-09-08
  observation: xf_pointer_libinput_accel maps percent 10 -> clamp((10-100)/100.0)=-0.9. libinput Accel Speed is a -1..1 curve bias, not a linear speed multiplier, so -0.9 is not 10% displacement.
- timestamp: 2026-09-08
  observation: xf_pointer_sync_accel also calls XChangePointerControl. libinput ignores the core pointer accel ratio.
- timestamp: 2026-09-08
  checked: MemPalace absent; knowledge-base.md keyword overlap on FREERDP_EXTERNAL_* is the scale-helper miss (external-scale-stays-200), not pointer speed.
  found: No matching pointer-speed resolution. Phase 0 logged skip.
  implication: Treat current hypothesis as primary, not a KB hit.
- timestamp: 2026-09-08
  checked: patches/onemix-touch.patch + /tmp/onemix-hqd-src applied tree (md5 match of onemix-touch.patch).
  found: xf_pointer_core_device_id matches name "Virtual core pointer"; xf_pointer_libinput_accel(10)==-0.9 asserted in TestXfPointerMap; XChangePointerControl on both CRTC branches.
  implication: Root cause confirmed in production path. Click mapping is a separate 1:1 CRTC→rdpMonitor function and must stay untouched.
- timestamp: 2026-09-08
  checked: TestXfPointerMap after replacing xf_pointer_libinput_accel with xf_pointer_matrix_scale.
  found: OK; SPEED=10 writes CTM diag 0.1/0.1/1; 10%*10 equals 100%; 9/201/NULL rejected. Mapping tests still pass.
  implication: Linear displacement contract is now the specified oracle.
- timestamp: 2026-09-08
  checked: Mutant s=((percent-100)/100) at xf_pointer_matrix_scale.
  found: TestXfPointerMap FAIL: 10% is 0.1x identity-scale CTM. Restored formula → OK.
  implication: Mutation check killed the old curve-bias formula.
- timestamp: 2026-09-08
  checked: scripts/build-release.sh (no nocheck); dpkg-deb strings of new freerdp3-x11.
  found: 156/156 tests passed including TestXfPointerMap; new binary has Coordinate Transformation Matrix + FREERDP_EXTERNAL_POINTER_SPEED; libinput Accel Speed gone. Bundle .dist-bundle-20260908T084002Z-43247.
  implication: Fix is in the published +onemix1 debs. Physical USB-mouse feel still needs human verify after install.

## Eliminated

- hypothesis: New +onemix1 binary was not installed
  reason: md5 of /usr/bin/xfreerdp3 matches the 2026-09-08 14:53 dist deb; strings contain FREERDP_EXTERNAL_POINTER_SPEED.
- hypothesis: Stale /usr/local/bin/menu dropped SPEED=10
  reason: user exported FREERDP_EXTERNAL_POINTER_SPEED=10 before launch; client getenv still sees 10. Stale menu only skips the default-50 path.

## Resolution

- root_cause: AND-gate: xf_pointer_libinput_accel mapped SPEED=10 to libinput Accel Speed -0.9 (curve bias, not 0.1x displacement) and XIChangeProperty targeted Virtual core pointer (master has no Accel Speed); XChangePointerControl is ignored by xf86-input-libinput.
- fix: Apply Coordinate Transformation Matrix scale percent/100 on relative XISlavePointer devices (skip touch/absolute/XTEST); restore identity (100%) on the OneMix primary CRTC. Leave xf_pointer_map_coordinates 1:1.
- oracle_type: specified
- files_changed:
  - patches/onemix-touch.patch
  - README.md
- verification:
    target_test: { result: pass }
    mutation_check: { result: pass, mutant_killed: true, reason_if_skipped: "" }
    no_op_deletion: { result: pass, deletion_justified_by_rca: true }
    adjacent_tests: { result: pass, suites_run: [TestXfPointerMap, TestXfInputDispatcher, TestXfMonitorScale, patch_application_check.sh, readme_doc_regression.sh, debian ctest 156/156] }
    revert_and_reconfirm: { result: pass, bug_returned_on_revert: true, fixed_on_reapply: true }
    guardrail_verdict: accepted
    rejected_signal:

---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_phase: 4
current_phase_name: diagnostics-packaging-launch-configuration
status: verifying
stopped_at: Completed 04-06-PLAN.md
last_updated: "2026-08-09T14:34:47.758Z"
last_activity: 2026-08-09
last_activity_desc: Plan 04-06 completed; GAP-07 remains USER-DEFERRED under D-25.
progress:
  total_phases: 4
  completed_phases: 4
  total_plans: 13
  completed_plans: 13
---

# State: FreeRDP Touch for OneMix 3

## Project Reference

- **Project**: FreeRDP Touch for OneMix 3
- **Core Value**: A OneMix 3 user can operate a normal Windows RDP session comfortably by touch, with low latency and without needing an external mouse for common interactions.
- **Current focus**: Phase 4 — Diagnostics, Packaging & Launch Configuration
- **Roadmap**: `.planning/ROADMAP.md`
- **Requirements**: `.planning/REQUIREMENTS.md` (19 v1)
- **Research**: `.planning/research/SUMMARY.md` (HIGH confidence)

## Current Position

Phase: 4 of 4 (Diagnostics, Packaging & Launch Configuration)
Plan: 6 of 6 in current phase
Status: Phase complete — ready for verification
Last activity: 2026-08-09 — Plan 04-06 completed; GAP-07 remains USER-DEFERRED under D-25.

Progress: [██████████] 100%

```
[x] Phase 1: Environment Gate & Build Baseline (2/2 plans)
[x] Phase 2: Native RDPEI Touch Lifecycle (2/2 plans)
[x] Phase 3: Local-Only Gestures & Session Stability
[~] Phase 4: Diagnostics, Packaging & Launch Configuration (6/6 plans complete; phase verification remains in progress)
```

## Performance Metrics

- **Phases completed**: 3/4
- **Requirements mapped**: 19/19
- **Plans completed**: 13/13 (01-01, 01-02, 02-01, 02-02, 03-01, 04-01, 04-02, 04-03, 04-04, 04-05, 04-06; 03-02 and 03-03 reconciled as superseded by the local-only pivot)

**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 04 P01 | 52 | 3 tasks | 3 files |
| Phase 04-diagnostics-packaging-launch-configuration P04-02 | 5 | 2 tasks | 2 files |
| Phase 04-diagnostics-packaging-launch-configuration P04-03 | 1 | 2 tasks | 2 files |
| Phase 04 P04 | 623 | 2 tasks | 5 files |
| Phase 04 P05 | 1371 | 3 tasks | 9 files |
| Phase 04 P06 | 182 | 4 tasks | 7 files |

## Accumulated Context

### Decisions

- Compress research's 7 risk stages into 4 coarse phases while preserving the non-negotiable X11 gate (Phase 1) and the RDPEI-lifecycle-before-gestures ordering (Phase 2 before Phase 3).
- `Ctrl+wheel` pinch fallback is a branch inside the Phase 3 pinch recognizer, not a separate phase; it ships after RDPEI lifecycle correctness.
- Diagnostics logging is added incrementally during Phases 2–3 and finalized/documented in Phase 4 (single DIAG-01 requirement lives there).
- Reconnect/focus stability (STAB-01, STAB-02) ships with gestures in Phase 3 because the teardown checklist must enumerate gesture + contact state created in Phases 2–3.
- Gate uses four-signal AND check (XDG_SESSION_TYPE, WAYLAND_DISPLAY, pgrep Xorg, pgrep Xwayland) — xdpyinfo vendor string is NOT a discriminator (reports "X.Org Foundation" under both Xorg and XWayland).
- build-baseline.sh installs only freerdp3-x11_*_amd64.deb, never the broad freerdp3-* glob (avoids replacing freerdp3-wayland).
- Rollback uses apt install --reinstall freerdp3-x11 with fallback to apt install freerdp3-x11/trixie.
- [Phase 2] #12174 RDPEI lock-race fixed with a recursive CriticalSection widened to cover reserve + AddContact publish (WinPR CriticalSection is recursive on Linux).
- [Phase 2] Forced-cancel iterates cctx->contacts[] (authoritative native store), not xfc->contacts[] (local-gesture array); recovery gate at top of xf_input_handle_event_remote.
- [Phase 2] Fallback latch is X11-client-only (xf_input_touch_remote); client/common/client.c unchanged — keeps SDL/Wayland policy separate.
- [Phase 2 UAT] Long-press right-click broken: OneMix 3 touchscreen reports 1–3px jitter on a stationary finger; every jitter forwards as RDPEI MOTION and Windows cancels press-and-hold. Phase 3 must add a motion deadband (suppress sub-threshold MOTION during hold) so Windows sees a stationary contact. Root cause confirmed via on-device log.
- [Phase 3 Plan 01] Short tap = deterministic mouse left-click (DOWN|BUTTON1 then BUTTON1) rather than depending on Windows' own tap-to-click, which proved unreliable on-device. Drag = cancel native + reuse fallback latch. Long-press reuses xf_touch_force_cancel for the cancel seam so a later physical End cannot overwrite. 30ms RDPEI cancel settle delay needed for stale contact visuals. Deadband pins sub-slop updates to down coordinate rather than dropping them.
- [Quick 260807-oz9] Native RDPEI touch forwarding is disabled. `+touch-pinch-wheel-fallback` now activates local XI2 capture without `+multitouch`: one finger maps to left-click/drag or long-press right-click, two-finger translation maps to middle-button pan, and pinch maps to Ctrl+wheel. Lifecycle cancellation releases and quarantines all held gesture state.
- [Phase 3 closure] Non-multitouch/local-only is the canonical v1 touch target: one-finger left-click/drag/long-press right-click, two-finger wheel scroll, bidirectional Ctrl+wheel pinch, and three-finger middle-button drag. Native pinch/RDPEI is removed from the Phase 3 target; 03-02 and 03-03 are reconciled as superseded by the completed quick/debug work.
- [Phase ?]: Quilt patch uses diff --git headers matching Debian convention
- [Phase ?]: Four-package closure: libwinpr3-3, libfreerdp3-3, libfreerdp-client3-3, freerdp3-x11 at exact +onemix1 version
- [Phase ?]: Atomic publication with flock -n and publication-aware trap (readlink -f comparison, no fragile published flag)
- [Phase 4 Plan 03]: Verification record uses deterministic 10x5 state-machine grammar with inline Python/stdlib parser — raw byte inspection before decode, no framework dependency
- [Phase 4 Plan 03]: Stock rollback launch documentation uses menu --mouse-only because plain menu composes patched touch options that stock FreeRDP rejects
- [Phase 4 Plan 04]: Shared xf_touch_internal.h is the authoritative implementation seam — includes only <math.h> and <stddef.h>, no X11 or FreeRDP headers
- [Phase 4 Plan 04]: xf_quarantine_update is the sole runtime writer of quarantine storage after xf_input_init; every gesture cleanup and force-cancel path delegates through it
- [Phase 4 Plan 04]: xf_pinch_emit_steps accumulates fractional deltas in double without truncation; both wheel diagnostics use accum=%.3f with explicit double argument
- [Phase 4 Plan 04]: Four-package parser fixture extracts all four .debs into one root and proves loader resolution beneath it before running parser cases
- [Phase 4 Plan 05]: GAP-05 shell closed with canonical calibration validation (digits-only, max-10-digits, no-leading-zero, range-check). GAP-06 closed with EXIT-only cleanup and per-publisher mktemp classifier. GAP-08/GAP-09 closed with subshell checksum and fail-closed exact-four-package install/rollback. WR-02/WR-03 closed with real-wrapper regression and Wayland-negative gate tests. /usr/local/bin/menu deployed byte-for-byte from scripts/menu. GAP-07 remains deferred per D-25.
- [Phase ?]: Task 4 used the owner-confirmed ten-check physical-device result without repeating package installation, rollback, menu launches, or physical tests.
- [Phase ?]: GAP-07 remains USER-DEFERRED under D-25; /cert:ignore is expected and server certificate identity remains unverified.
- [Phase ?]: The v1 diagnostic record remains local-only with native_count=0 on hardware and no required hardware native-cancel record.

### Todos

- Complete the Phase 4 verification/ship audit; keep GAP-07 explicitly USER-DEFERRED under D-25.

### Blockers

- Planning verification override: the owner chose to execute without the final checker verdict after the last three plan fixes.
- GAP-07 certificate hardening is deferred under D-25; `/cert:ignore` remains with accepted HIGH MITM/server-impersonation risk.

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 260807-oz9 | tôi không muốn mutitouch để native nữa, tôi muốn tắt multitouch đi, rồi freerdp xử lý toàn bộ thao tác cảm ứng trước. ví dụ 1 press thì left click, long press thì right click, 2 finger thì bấm vào wheel, pan hướng nào thì tương tự giữ wheel di chuột hướng đó, pinch thì giữ ctrl rồi lăn chuột | 2026-08-07 | build-tree | [260807-oz9-t-i-kh-ng-mu-n-mutitouch-native-n-a-t-i-](./quick/260807-oz9-t-i-kh-ng-mu-n-mutitouch-native-n-a-t-i-/) |
| 260808-956 | hiện tại freerdp đang để : lúc 2 ngón pan, thì hold wheel và drag chuột. tôi đổi ý muốn hold wheel thì dùng 3 ngón, nếu dùng 2 ngón thì lăn chuột. | 2026-08-08 | build-tree | [260808-956-hi-n-t-i-freerdp-ang-l-c-2-ng-n-pan-th-h](./quick/260808-956-hi-n-t-i-freerdp-ang-l-c-2-ng-n-pan-th-h/) |
| 260808-b11 | tôi đã chuyển freerdp về KHÔNG multitouch, các thao tác phần lớn đã work, tuy nhiên có một vấn đề nhỏ: khi tôi để 2 ngón để dọc và vuốt xuống, expect scroll thì bị chuyển thành pinch (phóng to thu nhỏ) | 2026-08-08 | build-tree | [260808-b11-t-i-chuy-n-freerdp-v-kh-ng-multitouch-c-](./quick/260808-b11-t-i-chuy-n-freerdp-v-kh-ng-multitouch-c-/) |
| 4 | Update /usr/local/bin/menu so FreeRDP option 3 uses the canonical patched launch parameters | 2026-08-08 | 67ac6d5 | — |

### Research Flags (carried from research summary)

- Phase 2 will need `/gsd-plan-phase --research-phase` for XInput2 touch-ownership semantics (XI 2.2, `XIAllowTouchEvents`, Mutter delivery) and for MS-RDPEI state-machine / lock-shape audit against the 3.15.0 tarball (#9082, #12174). Highest-risk phase.

## Session Continuity

**Last session:** 2026-08-09T14:34:47.737Z
**Stopped at:** Completed 04-06-PLAN.md
**Resume file:** None

- **Last action**: Completed Plan 04-06: verified the owner-confirmed ten-check record, exact package identity manifests, live PRE/POST snapshots, and D-25 wording without repeating device operations.
- **Next action**: Complete the Phase 4 verification/ship audit; GAP-07 remains USER-DEFERRED and server certificate identity remains unverified.

---
*State initialized: 2026-08-05*

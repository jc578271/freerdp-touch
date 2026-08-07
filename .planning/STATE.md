---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: active
stopped_at: Quick task 260807-oz9 implemented — local-only touch gestures; hardware UAT pending
last_updated: "2026-08-07T18:45:22+07:00"
progress:
  total_phases: 3
  completed_phases: 2
  total_plans: 7
  completed_plans: 5
current_phase_name: Gestures & Session Stability
---

# State: FreeRDP Touch for OneMix 3

## Project Reference

- **Project**: FreeRDP Touch for OneMix 3
- **Core Value**: A OneMix 3 user can operate a normal Windows RDP session comfortably by touch, with low latency and without needing an external mouse for common interactions.
- **Current focus**: Phase 3 — Gestures & Session Stability (long-press deadband, pinch, reconnect/focus stability)
- **Roadmap**: `.planning/ROADMAP.md`
- **Requirements**: `.planning/REQUIREMENTS.md` (19 v1)
- **Research**: `.planning/research/SUMMARY.md` (HIGH confidence)

## Current Position

- **Phase**: 3 - Gestures & Session Stability
- **Status**: Local-only touch pivot implemented by quick task 260807-oz9; automated build passed, OneMix 3 native-X11 UAT pending.
- **Progress**: 2/4 phases complete, 5/7 planned-phase plans executed; remaining Phase 3 plans must be reconciled with the local-only pivot before execution.

```
[x] Phase 1: Environment Gate & Build Baseline (2/2 plans)
[x] Phase 2: Native RDPEI Touch Lifecycle (2/2 plans)
[ ] Phase 3: Gestures & Session Stability
[ ] Phase 4: Diagnostics, Packaging & Launch Configuration
```

## Performance Metrics

- **Phases completed**: 2/4
- **Requirements mapped**: 19/19
- **Plans completed**: 5 (01-01, 01-02, 02-01, 02-02, 03-01)

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

### Todos

- Run OneMix 3 native-X11 UAT from quick task 260807-oz9 using `bash run-rdp.sh` (no `+multitouch`).
- Reconcile or replan remaining Phase 3 plans before `/gsd-execute-phase 3`; 03-02's native-passthrough assumptions are superseded by the local-only pivot.

### Blockers

- Hardware UAT for quick task 260807-oz9 is still pending on the OneMix 3 native X11 session.

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 260807-oz9 | tôi không muốn mutitouch để native nữa, tôi muốn tắt multitouch đi, rồi freerdp xử lý toàn bộ thao tác cảm ứng trước. ví dụ 1 press thì left click, long press thì right click, 2 finger thì bấm vào wheel, pan hướng nào thì tương tự giữ wheel di chuột hướng đó, pinch thì giữ ctrl rồi lăn chuột | 2026-08-07 | build-tree | [260807-oz9-t-i-kh-ng-mu-n-mutitouch-native-n-a-t-i-](./quick/260807-oz9-t-i-kh-ng-mu-n-mutitouch-native-n-a-t-i-/) |
| 260808-956 | hiện tại freerdp đang để : lúc 2 ngón pan, thì hold wheel và drag chuột. tôi đổi ý muốn hold wheel thì dùng 3 ngón, nếu dùng 2 ngón thì lăn chuột. | 2026-08-08 | build-tree | [260808-956-hi-n-t-i-freerdp-ang-l-c-2-ng-n-pan-th-h](./quick/260808-956-hi-n-t-i-freerdp-ang-l-c-2-ng-n-pan-th-h/) |

### Research Flags (carried from research summary)

- Phase 2 will need `/gsd-plan-phase --research-phase` for XInput2 touch-ownership semantics (XI 2.2, `XIAllowTouchEvents`, Mutter delivery) and for MS-RDPEI state-machine / lock-shape audit against the 3.15.0 tarball (#9082, #12174). Highest-risk phase.

## Session Continuity

**Last session:** 2026-08-07T18:45:22+07:00
**Last activity:** 2026-08-08 - Completed quick task 260808-956: hiện tại freerdp đang để : lúc 2 ngón pan, thì hold wheel và drag chuột. tôi đổi ý muốn hold wheel thì dùng 3 ngón, nếu dùng 2 ngón thì lăn chuột.
**Stopped at:** Automated implementation/build complete; OneMix 3 native-X11 UAT pending
**Resume file:** .planning/quick/260807-oz9-t-i-kh-ng-mu-n-mutitouch-native-n-a-t-i-/260807-oz9-SUMMARY.md

- **Last action**: Disabled native RDPEI forwarding; enabled local touch capture without `+multitouch`; added one-finger click/drag/long-press, two-finger middle-button pan, Ctrl+wheel pinch, and shared lifecycle cleanup. Incremental xfreerdp build and CLI smoke checks passed.
- **Next action**: Run `bash run-rdp.sh` in GNOME on Xorg and complete the UAT checklist in the quick-task summary; then reconcile remaining Phase 3 plans with the local-only pivot.

---
*State initialized: 2026-08-05*

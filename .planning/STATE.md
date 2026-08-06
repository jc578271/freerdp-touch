---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: active
stopped_at: Phase 3 Plan 01 complete — long-press right-click with slop deadband
last_updated: "2026-08-06T23:11:20+07:00"
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
- **Status**: Phase 3 planned — 3 plans across 3 waves, verification passed. Ready to execute Wave 1.
- **Progress**: 2/4 phases complete, 5/7 plans executed; 2 Phase 3 plans remaining

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

### Todos

- Execute Phase 3 with `/gsd-execute-phase 3`; Wave 1 starts with the long-press deadband tracer.

### Blockers

- None.

### Research Flags (carried from research summary)

- Phase 2 will need `/gsd-plan-phase --research-phase` for XInput2 touch-ownership semantics (XI 2.2, `XIAllowTouchEvents`, Mutter delivery) and for MS-RDPEI state-machine / lock-shape audit against the 3.15.0 tarball (#9082, #12174). Highest-risk phase.

## Session Continuity

**Last session:** 2026-08-06T23:11:20+07:00
**Stopped at:** Completed 03-01-PLAN.md — long-press right-click with slop deadband
**Resume file:** .planning/phases/03-gestures-session-stability/03-02-PLAN.md

- **Last action**: Plan 03-01 finalized. Long-press state machine, slop deadband, deterministic short-tap/drag, force-cancel extension, and 3 CLI knobs verified and human-checked. Implementation lives in gitignored build/ tree.
- **Next action**: `/gsd-execute-phase 3` for 03-02 pinch (native passthrough + Ctrl+wheel fallback).

---
*State initialized: 2026-08-05*

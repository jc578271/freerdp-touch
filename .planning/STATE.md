---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: unknown
stopped_at: Phase 2 context gathered
last_updated: "2026-08-06T01:26:02.853Z"
progress:
  total_phases: 2
  completed_phases: 1
  total_plans: 2
  completed_plans: 2
current_phase_name: Native RDPEI Touch Lifecycle
---

# State: FreeRDP Touch for OneMix 3

## Project Reference

- **Project**: FreeRDP Touch for OneMix 3
- **Core Value**: A OneMix 3 user can operate a normal Windows RDP session comfortably by touch, with low latency and without needing an external mouse for common interactions.
- **Roadmap**: `.planning/ROADMAP.md`
- **Requirements**: `.planning/REQUIREMENTS.md` (19 v1)
- **Research**: `.planning/research/SUMMARY.md` (HIGH confidence)

## Current Position

- **Phase**: 1 - Environment Gate & Build Baseline
- **Plan**: 01-01 complete (01-02 next)
- **Status**: Plan 01-01 executed — gate script + build-baseline orchestrator + .gitignore created
- **Progress**: 0/4 phases complete, 1/2 plans in Phase 1

```
[~] Phase 1: Environment Gate & Build Baseline (1/2 plans)
[ ] Phase 2: Native RDPEI Touch Lifecycle
[ ] Phase 3: Gestures & Session Stability
[ ] Phase 4: Diagnostics, Packaging & Launch Configuration
```

## Performance Metrics

- **Phases completed**: 0/4
- **Requirements mapped**: 19/19
- **Plans completed**: 1 (01-01)

## Accumulated Context

### Decisions

- Compress research's 7 risk stages into 4 coarse phases while preserving the non-negotiable X11 gate (Phase 1) and the RDPEI-lifecycle-before-gestures ordering (Phase 2 before Phase 3).
- `Ctrl+wheel` pinch fallback is a branch inside the Phase 3 pinch recognizer, not a separate phase; it ships after RDPEI lifecycle correctness.
- Diagnostics logging is added incrementally during Phases 2–3 and finalized/documented in Phase 4 (single DIAG-01 requirement lives there).
- Reconnect/focus stability (STAB-01, STAB-02) ships with gestures in Phase 3 because the teardown checklist must enumerate gesture + contact state created in Phases 2–3.
- Gate uses four-signal AND check (XDG_SESSION_TYPE, WAYLAND_DISPLAY, pgrep Xorg, pgrep Xwayland) — xdpyinfo vendor string is NOT a discriminator (reports "X.Org Foundation" under both Xorg and XWayland).
- build-baseline.sh installs only freerdp3-x11_*_amd64.deb, never the broad freerdp3-* glob (avoids replacing freerdp3-wayland).
- Rollback uses apt install --reinstall freerdp3-x11 with fallback to apt install freerdp3-x11/trixie.

### Todos

- Plan Phase 1 with `/gsd-plan-phase 1`.

### Blockers

- None.

### Research Flags (carried from research summary)

- Phase 2 will need `/gsd-plan-phase --research-phase` for XInput2 touch-ownership semantics (XI 2.2, `XIAllowTouchEvents`, Mutter delivery) and for MS-RDPEI state-machine / lock-shape audit against the 3.15.0 tarball (#9082, #12174). Highest-risk phase.

## Session Continuity

**Last session:** 2026-08-06T01:26:02.828Z
**Stopped at:** Phase 2 context gathered
**Resume file:** .planning/phases/02-native-rdpei-touch-lifecycle/02-CONTEXT.md

- **Last action**: Executed Plan 01-01 — created scripts/check-x11-session.sh, scripts/build-baseline.sh, .gitignore. Gate verified live (hard-fails on Wayland with correct remediation).
- **Next action**: Execute Plan 01-02 (on-device build/install/smoke/rollback on GNOME on Xorg session).
- **Handoff note**: Switch to GNOME on Xorg session before running build-baseline.sh. The gate will block until the session is native X11.

---
*State initialized: 2026-08-05*

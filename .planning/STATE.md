---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: active
stopped_at: Phase 2 executed — verification passed (source level), on-device UAT pending
last_updated: "2026-08-06T03:35:00Z"
progress:
  total_phases: 4
  completed_phases: 2
  total_plans: 4
  completed_plans: 4
current_phase_name: Gestures & Session Stability
---

# State: FreeRDP Touch for OneMix 3

## Project Reference

- **Project**: FreeRDP Touch for OneMix 3
- **Core Value**: A OneMix 3 user can operate a normal Windows RDP session comfortably by touch, with low latency and without needing an external mouse for common interactions.
- **Roadmap**: `.planning/ROADMAP.md`
- **Requirements**: `.planning/REQUIREMENTS.md` (19 v1)
- **Research**: `.planning/research/SUMMARY.md` (HIGH confidence)

## Current Position

- **Phase**: 2 - Native RDPEI Touch Lifecycle
- **Status**: Phase 2 executed — 2/2 plans complete, source-level verification passed (6/6 requirements). On-device UAT pending.
- **Progress**: 2/4 phases complete, 4/4 plans executed across Phases 1–2

```
[x] Phase 1: Environment Gate & Build Baseline (2/2 plans)
[x] Phase 2: Native RDPEI Touch Lifecycle (2/2 plans)
[ ] Phase 3: Gestures & Session Stability
[ ] Phase 4: Diagnostics, Packaging & Launch Configuration
```

## Performance Metrics

- **Phases completed**: 2/4
- **Requirements mapped**: 19/19
- **Plans completed**: 4 (01-01, 01-02, 02-01, 02-02)

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

**Last session:** 2026-08-06T03:35:00Z
**Stopped at:** Phase 2 executed — verification passed (source level)
**Resume file:** .planning/phases/02-native-rdpei-touch-lifecycle/02-VERIFICATION.md

- **Last action**: Executed Phase 2 (both plans). 02-01: single-tap RDPEI pipeline with #12174 fix, XI2 ownership, emulated suppression, content-bounds gate. 02-02: forced-cancel seam (5 hooks), recovery gate, idempotency, fallback latch. Build passes, .deb produced.
- **Next action**: On-device UAT on OneMix 3 GNOME-on-Xorg session, then `/gsd-plan-phase 3` for Gestures & Session Stability.
- **Code review**: 3 medium findings (M1: canceledIds[] sync bug, M2: WITH_XRENDER=OFF latent, M3: WITH_XI=OFF latent), 3 low. Review at 02-REVIEW.md.
- **Handoff note**: Phase 2 source-level verification passed (6/6 requirements). Six on-device UAT items remain (02-VERIFICATION.md behavior_unverified_items). D-06 mid-session channel-only drop deferred to Phase 3.

---
*State initialized: 2026-08-05*

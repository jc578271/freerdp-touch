---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: active
stopped_at: Phase 3 context gathered
last_updated: "2026-08-06T09:12:22.561Z"
progress:
  total_phases: 3
  completed_phases: 2
  total_plans: 4
  completed_plans: 4
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
- **Status**: Phase 2 complete — 2/2 plans, on-device UAT passed (14/14), verification passed. Ready to plan Phase 3.
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
- [Phase 2] #12174 RDPEI lock-race fixed with a recursive CriticalSection widened to cover reserve + AddContact publish (WinPR CriticalSection is recursive on Linux).
- [Phase 2] Forced-cancel iterates cctx->contacts[] (authoritative native store), not xfc->contacts[] (local-gesture array); recovery gate at top of xf_input_handle_event_remote.
- [Phase 2] Fallback latch is X11-client-only (xf_input_touch_remote); client/common/client.c unchanged — keeps SDL/Wayland policy separate.
- [Phase 2 UAT] Long-press right-click broken: OneMix 3 touchscreen reports 1–3px jitter on a stationary finger; every jitter forwards as RDPEI MOTION and Windows cancels press-and-hold. Phase 3 must add a motion deadband (suppress sub-threshold MOTION during hold) so Windows sees a stationary contact. Root cause confirmed via on-device log.

### Todos

- Plan Phase 3 with `/gsd-plan-phase 3` (long-press deadband is the highest-value Phase 3 item — root cause already specced).

### Blockers

- None.

### Research Flags (carried from research summary)

- Phase 2 will need `/gsd-plan-phase --research-phase` for XInput2 touch-ownership semantics (XI 2.2, `XIAllowTouchEvents`, Mutter delivery) and for MS-RDPEI state-machine / lock-shape audit against the 3.15.0 tarball (#9082, #12174). Highest-risk phase.

## Session Continuity

**Last session:** 2026-08-06T09:12:22.547Z
**Stopped at:** Phase 3 context gathered
**Resume file:** .planning/phases/03-gestures-session-stability/03-CONTEXT.md

- **Last action**: Phase 2 on-device UAT on OneMix 3 GNOME-on-Xorg session. Patch verified working: native RDPEI path active (rdpei non-nil on all 1367 touch events, fallback never triggered), forced-cancel fires correctly on fullscreen toggle with finger down (TouchCancel id=231 emitted), recovery gate works. 14/14 UAT passed.
- **Next action**: `/gsd-plan-phase 3` for Gestures & Session Stability. Highest-value item: long-press motion deadband (root cause already confirmed — X11 jitter ±3px cancels Windows press-and-hold).
- **Deferred to Phase 3**: (1) long-press right-click deadband, (2) touch smoothness/latency (RDPEI ~20ms batching + X11 jitter). Both are Phase 03 scope, not Phase 02 regressions.
- **Cleanup note**: Two `/* DIAG: */` debug-log blocks were added to `build/.../xf_input.c` during UAT (touch_remote + force_cancel). They are NOT in the quilt patch and must be removed before building the final `.deb` for Phase 4.

---
*State initialized: 2026-08-05*

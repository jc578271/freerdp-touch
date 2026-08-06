# Roadmap: FreeRDP Touch for OneMix 3

**Core Value:** A OneMix 3 user can operate a normal Windows RDP session comfortably by touch, with low latency and without needing an external mouse for common interactions.

**Granularity:** coarse (4 phases — research's 7 risk stages compressed where a phase still has a coherent verifiable goal)
**Convention:** sequential
**Coverage:** 19/19 v1 requirements mapped

## Phases

- [~] **Phase 1: Environment Gate & Build Baseline** - Verify the X11 session, capture the device/source baseline, and prove the unmodified Debian FreeRDP source builds, launches, and rolls back before any patch.
- [ ] **Phase 2: Native RDPEI Touch Lifecycle** - Deliver complete, ordered, correctly located native RDPEI contacts through drag, multi-finger, lift, and cancel — with no duplicates or stuck contacts — before any gesture logic.
- [ ] **Phase 3: Gestures & Session Stability** - Implement the three core gestures (long-press right-click, native pinch, Ctrl+wheel fallback pinch) and keep touch stable across window state, focus, and disconnect/reconnect.
- [ ] **Phase 4: Diagnostics, Packaging & Launch Configuration** - Ship the verified patch as an installable Debian `.deb` with env-var-gated diagnostics and a documented, repeatable launch preset.

## Phase Details

### Phase 1: Environment Gate & Build Baseline

**Goal**: A developer working in a verified native-X11 environment can build, install, launch, and roll back the unmodified Debian FreeRDP source before any touch patch is applied.
**Depends on**: Nothing (first phase)
**Requirements**: BASE-01, BASE-02, BASE-03
**Success Criteria** (what must be TRUE):

  1. Running the prerequisite check blocks further implementation/testing unless the active desktop session is native X11 (not Wayland or XWayland).
  2. A captured baseline record exists covering the installed `xfreerdp3`/Debian package version, X11 window manager, touchscreen identity and capabilities, rotation/scale settings, current launch command, and Windows target.
  3. The developer can build and install the unmodified `freerdp3-x11` source package, launch it against the Windows target, and roll back to the stock Debian package using documented, verified commands.

**Plans**:
2/2 plans executed

- [x] 01-01-PLAN.md — X11 gate script + .gitignore + build-baseline orchestrator (capability; gate verifiable on current Wayland session)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 01-02-PLAN.md — Execute build/install/smoke/rollback on GNOME on Xorg and commit the sanitized baseline report (human-verified)

### Phase 2: Native RDPEI Touch Lifecycle

**Goal**: A finger touch reaches Windows as a complete, ordered, correctly located native RDPEI contact through a full drag, multi-finger, lift, and cancel — without duplicates or stuck contacts — before any gesture logic is added.
**Depends on**: Phase 1
**Requirements**: XINP-01, XINP-02, COOR-01, RDPEI-01, RDPEI-02, RDPEI-03
**Success Criteria** (what must be TRUE):

  1. A short tap and one-finger drag reach Windows as a complete native touch sequence (begin → updates → end) at the corresponding remote position in windowed, fullscreen, and each OneMix 3 orientation supported by the launch configuration.
  2. A physical touch produces exactly one input sequence with no duplicate action from XInput2 pointer-emulation events; repeated and simultaneous touches keep stable identities for their lifetime and release those identities after end or cancellation without dropping later touches.
  3. Two simultaneous fingers reach Windows as two distinct native contacts in the same RDPEI frame, with neither contact lost or merged.
  4. Finger lift, gesture abort, focus loss, fullscreen/window transition, or disconnect cleanly ends every outstanding remote contact so no stuck or ghost touch remains.

**Plans**: 1/2 plans executed
**Wave 1**

- [x] 02-01-PLAN.md — Tracer: single-finger tap to native RDPEI contact with #12174 fix, XI2 ownership, emulated suppression, content-bounds gate (Wave 1)

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 02-02-PLAN.md — Forced-cancel seam across 5 lifecycle hooks + first-contact-only fallback latch + recovery gate (Wave 2, depends on 02-01)

### Phase 3: Gestures & Session Stability

**Goal**: The three core touch gestures work reliably and touch remains stable across window state changes, focus loss, and disconnect/reconnect.
**Depends on**: Phase 2
**Requirements**: GEST-01, GEST-02, GEST-03, GEST-04, STAB-01, STAB-02
**Success Criteria** (what must be TRUE):

  1. A configurable 500–700 ms long press produces one right-click at the touch position with no left-click emitted afterward; moving beyond a configurable slop distance before the threshold cancels long-press detection and continues as an ordinary native drag.
  2. In native pinch mode a two-finger pinch forwards native multitouch to Windows and emits no local wheel shortcut; in fallback pinch mode (selected before launch) it emits `Ctrl` + wheel, never also emits native pinch, and releases `Ctrl` when the gesture ends or is interrupted.
  3. Touch remains usable without crashes, stale contacts, or duplicate events after switching between windowed/fullscreen states and after losing and regaining focus.
  4. Disconnecting or reconnecting during an active touch or gesture does not crash the client, and touch works again after reconnection.

**Plans**: TBD

### Phase 4: Diagnostics, Packaging & Launch Configuration

**Goal**: The verified patch ships as an installable Debian package with env-var-gated diagnostics and a documented launch preset that a user can install, roll back, and operate.
**Depends on**: Phase 3
**Requirements**: DIAG-01, PACK-01, PACK-02, CONF-01
**Success Criteria** (what must be TRUE):

  1. The developer can reproducibly build an installable Debian `.deb` from the pinned `freerdp3-x11 3.15.0+dfsg-2.1+deb13u3` source using a documented quilt patch.
  2. The user can install the patched package and restore the stock Debian package using documented, verified commands.
  3. The user can launch the patched client with a documented preset that enables multitouch, exposes long-press and pinch-mode calibration, and provides an explicit mouse-only/multitouch-off escape hatch.
  4. The user can enable diagnostic logging that records touch begin/update/end/cancel events, gesture decisions, and RDPEI frame submission, while normal launches keep the logging disabled.

**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Environment Gate & Build Baseline | 2/2 | Complete    | 2026-08-06 |
| 2. Native RDPEI Touch Lifecycle | 1/2 | In Progress|  |
| 3. Gestures & Session Stability | 0/0 | Not started | - |
| 4. Diagnostics, Packaging & Launch Configuration | 0/0 | Not started | - |

## Ordering Rationale

- **Phase 1 first** because the device boots GNOME on Wayland by default; a wrong session makes every later result a lie. Zero code, maximum leverage, and it proves the build/rollback path before patching.
- **Phase 2 before Phase 3** because RDPEI lifecycle correctness must precede gesture implementation. Native pinch (Phase 3) consumes the same multi-contact RDPEI path delivered here, and long-press suppression must coordinate with the RDPEI contact that armed it. The `Ctrl+wheel` fallback is a branch inside the Phase 3 pinch recognizer, not a substitute for fixing RDPEI first.
- **Phase 3 after the lifecycle trio** because gesture disambiguation only makes sense once contacts are trustworthy; reconnect/focus stability must enumerate every piece of gesture and contact state created by Phases 2–3, so it ships with the gestures rather than before them.
- **Phase 4 last** because packaging wraps a frozen, verified code state; diagnostics logging is added incrementally during Phases 2–3 and finalized/documented here.

---
*Roadmap created: 2026-08-05*

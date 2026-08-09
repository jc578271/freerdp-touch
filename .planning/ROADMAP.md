# Roadmap: FreeRDP Touch for OneMix 3

**Core Value:** A OneMix 3 user can operate a normal Windows RDP session comfortably by touch, with low latency and without needing an external mouse for common interactions.

**Granularity:** coarse (4 phases — research's 7 risk stages compressed where a phase still has a coherent verifiable goal)
**Convention:** sequential
**Coverage:** 19/19 v1 requirements mapped

## Phases

- [~] **Phase 1: Environment Gate & Build Baseline** - Verify the X11 session, capture the device/source baseline, and prove the unmodified Debian FreeRDP source builds, launches, and rolls back before any patch.
- [x] **Phase 2: Native RDPEI Touch Lifecycle** - Deliver complete, ordered, correctly located native RDPEI contacts through drag, multi-finger, lift, and cancel — with no duplicates or stuck contacts — before any gesture logic.
- [x] **Phase 3: Local-Only Gestures & Session Stability** - Deliver the non-multitouch/local-only gesture set: one-finger left-click/drag/long-press right-click, two-finger wheel scroll, bidirectional Ctrl+wheel pinch, and three-finger middle-button drag, with clean lifecycle recovery.
- [~] **Phase 4: Diagnostics, Packaging & Launch Configuration** - Ship the verified patch as an installable Debian `.deb` with env-var-gated diagnostics and a documented, repeatable launch preset.

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

**Plans**: 2/2 plans executed
**Wave 1**

- [x] 02-01-PLAN.md — Tracer: single-finger tap to native RDPEI contact with #12174 fix, XI2 ownership, emulated suppression, content-bounds gate (Wave 1)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 02-02-PLAN.md — Forced-cancel seam across 5 lifecycle hooks + first-contact-only fallback latch + recovery gate (Wave 2, depends on 02-01)

### Phase 3: Local-Only Gestures & Session Stability

**Goal**: With native multitouch disabled, the X11 client handles all touch locally: one-finger left-click/drag/long-press right-click, two-finger wheel scroll, bidirectional `Ctrl`+wheel pinch, and three-finger middle-button drag, while lifecycle interruptions release all held local input state cleanly.
**Depends on**: Phase 2
**Requirements**: GEST-01, GEST-02, GEST-03, GEST-04, STAB-01, STAB-02
**Success Criteria** (what must be TRUE):

  1. A configurable 500–700 ms long press produces one right-click at the touch position with no left-click emitted afterward; moving beyond the slop distance cancels long-press and continues as a local left-button drag.
  2. Two-finger translation emits wheel scroll; changing inter-finger distance emits `Ctrl`+wheel pinch and can reverse zoom direction without lifting; three-finger translation performs middle-button drag. None of these local gestures forwards native RDPEI contacts.
  3. Window/fullscreen changes, focus loss, touch-count changes, and gesture cancellation release every held mouse button or `Ctrl` state without duplicate or stale input.
  4. Disconnect/reconnect or another lifecycle interruption leaves the local recognizer clean so the next touch gesture starts normally.

**Plans**: 3/3 plans reconciled
**Wave 1**

- [x] 03-01-PLAN.md — Long-press right-click, slop deadband, and shared force-cancel gesture-state cleanup.

**Wave 2**

- [x] 03-02-PLAN.md — Superseded by the user-directed local-only pivot delivered through quick tasks 260807-oz9, 260808-956, 260808-b11 and the pinch-direction-reversal debug fix.

**Wave 3**

- [x] 03-03-PLAN.md — Superseded by the local-only lifecycle path and incremental on-device verification recorded by the completed quick/debug sessions.

### Phase 4: Diagnostics, Packaging & Launch Configuration

**Goal**: The verified patch ships as an installable Debian package with env-var-gated diagnostics and a documented launch preset that a user can install, roll back, and operate.
**Depends on**: Phase 3
**Requirements**: DIAG-01, PACK-01, PACK-02, CONF-01
**Success Criteria** (what must be TRUE):

  1. The developer can reproducibly build an installable Debian `.deb` from the pinned `freerdp3-x11 3.15.0+dfsg-2.1+deb13u3` source using a documented quilt patch.
  2. The user can install the patched package and restore the stock Debian package using documented, verified commands.
  3. The user can launch the patched client with a documented preset that keeps native multitouch disabled, enables the local-only gesture layer, exposes long-press/pinch calibration, and provides an explicit mouse-only escape hatch.
  4. The user can enable diagnostic logging that records touch begin/update/end/cancel events, gesture decisions, and RDPEI frame submission, while normal launches keep the logging disabled.

**Plans**: 7 plans (6 executed; 1 targeted gap-closure plan pending)

**Wave 1**

- [x] 04-01-PLAN.md — Diagnostic gate + quilt patch + release build (DIAG-01, PACK-01)
- [x] 04-02-PLAN.md — Launch wrapper + menu delegation (CONF-01)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 04-03-PLAN.md — Operations documentation + on-device install/rollback verification (PACK-02, CONF-01)

**Gap Closure** *(Wave 1 parallel, then Wave 2)*

- [x] 04-04-PLAN.md — X11 lifecycle, parser, and diagnostic defect closure: one-owner recovery, cached/idempotent diagnostics, local-only cancellation truth, exact four-package loader-isolated parser fixture, and gated RDPEI frame-record preservation (DIAG-01, CONF-01) — Wave 1, depends_on []
- [x] 04-05-PLAN.md — Release script, wrapper/menu, docs, and deployment closure: deterministic repeated calibration validation, signal-safe publication fixture, repeatable exact four-package install/rollback docs, fail-closed incomplete identities, and deployed-menu parity (CONF-01, PACK-01, PACK-02) — Wave 1, depends_on []
- [x] 04-06-PLAN.md — Final non-certificate rebuild and verification: two separately runnable clean builds with durable identity manifests, all automated regressions, separate process-aware live PRE/POST interruption invocations, repeated install/rollback, local-only native_count=0 diagnostics, native-device checks, and deployed-menu parity (DIAG-01, PACK-01, PACK-02, CONF-01) — Wave 2, depends_on [04-04, 04-05]
- [ ] 04-07-PLAN.md — Targeted actual-XI2 cancellation and canonical local diagnostic lifecycle closure with fresh quilt source synchronization (DIAG-01, CONF-01) — Wave 2, depends_on [04-04]

**Gap-closure security note:** GAP-07 is deferred by the owner per D-25. The current `/cert:ignore` behavior remains for v1, with accepted HIGH server-impersonation/MITM exposure. It is not counted as closed and no verification may claim server certificate identity protection.

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Environment Gate & Build Baseline | 2/2 | Complete    | 2026-08-06 |
| 2. Native RDPEI Touch Lifecycle | 2/2 | Complete    | 2026-08-06 |
| 3. Local-Only Gestures & Session Stability | 3/3 | Complete | 2026-08-08 |
| 4. Diagnostics, Packaging & Launch Configuration | 6/6 | In Progress|  |

## Ordering Rationale

- **Phase 1 first** because the device boots GNOME on Wayland by default; a wrong session makes every later result a lie. Zero code, maximum leverage, and it proves the build/rollback path before patching.
- **Phase 2 before Phase 3** established reliable XI2 contact identity, coordinate handling, duplicate suppression, and cancellation seams. Phase 3 reuses those foundations but deliberately routes active v1 touch behavior through the local-only recognizer instead of native RDPEI forwarding.
- **Phase 3 after the lifecycle foundation** because local gesture disambiguation and cleanup only make sense once contacts are trustworthy. The user-directed pivot makes non-multitouch/local-only behavior canonical for v1.
- **Phase 4 last** because packaging wraps a frozen, verified code state; diagnostics logging is added incrementally during Phases 2–3 and finalized/documented here.

---
*Roadmap created: 2026-08-05*

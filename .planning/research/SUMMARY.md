# Project Research Summary

**Project:** FreeRDP Touch for OneMix 3
**Domain:** Native X11 touchscreen-input patch for `xfreerdp3` (XInput2 -> RDPEI / mouse-keyboard fallback), delivered as a Debian quilt patch
**Researched:** 2026-08-05
**Confidence:** HIGH
**Inputs synthesized:** `.planning/research/STACK.md`, `.planning/research/FEATURES.md`, `.planning/research/ARCHITECTURE.md`, `.planning/research/PITFALLS.md`

## Executive Summary

This is a focused single-file C patch inside FreeRDP's existing X11 client (`client/X11/xf_input.c`, plus a new `xf_touch.c`), not a new client, daemon, or protocol implementation. FreeRDP already ships the RDPEI channel, an XInput2 touch capture path, the `+multitouch` flag, the `freerdp_client_handle_touch()` shared helper, and the full Debian source packaging. Experts build this the way we are building it: extend the in-tree X11 client, reuse the existing contact-lifecycle machinery rather than reimplementing MS-RDPEI framing, and ship as a quilt patch over the exact Debian version on the device (`freerdp3-x11` `3.15.0+dfsg-2.1+deb13u3`). All four research files independently converged on this shape; there is no dissent on stack, baseline, or packaging.

The recommended approach is a single translation layer (`xf_touch_gesture_filter()`) inserted between `xf_input_handle_event_remote` and the existing RDPEI / mouse / keyboard senders. The new layer owns only per-gesture state (long-press timer, pinch baseline, consumed-flag, fallback-mode flag) -- roughly 40 bytes hung off `xfContext`. RDPEI remains the single source of truth for remote contact state; the patch must never duplicate `cctx->contacts[]` or the `externalId -> contactId` map. Gestures are client policy and stay in `client/X11/`; the RDPEI channel itself is left untouched.

The dominant risks are correctness risks in code we do not own. FreeRDP's X11 touch path has a documented regression history (#9082 dead `cctx->contacts` intermediary, #12174 lost-touch-up race in `rdpei_touch_process`, #6566 multi-second long-press, #4698 reconnect segfault). Three of these predate the 3.15.0 source we are patching, so the v1 plan must audit the installed tarball for each before assuming anything works. Mitigation is structural: enforce the X11 session prerequisite before any code (the device boots GNOME on Wayland by default), prove the unpatched source builds and rolls back before patching, insert the gesture filter as a pure passthrough seam before adding behavior, and ship env-var-gated diagnostics from day one because touch bugs are silent.

## Key Findings

### Recommended Stack

Build against the exact installed Debian source, in C with the existing CMake build, using only libraries FreeRDP already links. No new language, build tool, runtime dependency, or gesture library.

**Core technologies:**
- **FreeRDP Debian source `3.15.0+dfsg-2.1+deb13u3`** -- the precise version `dpkg -l` reports on the device. Pinned because the project constraint is "build against the version currently packaged," and the touch code path is structurally identical between 3.15 and upstream 3.30, so rebasing buys nothing for v1.
- **C (C17) + CMake + debhelper-compat 13** -- FreeRDP's native toolchain, already driven by `debian/rules`. No new toolchain.
- **XInput2 (libXi), XI 2.2 minimum (server reports 2.4)** -- touch capture via `XI_TouchBegin/Update/End`. FreeRDP already requires `WITH_XI`; the existing `register_input_events()` already selects these masks.
- **RDPEI channel (MS-RDPEI, protocol V10-V300)** -- already implemented in `channels/rdpei/client/`. The only path that gives Windows apps real `WM_TOUCH`. Reused as-is; not modified.
- **Debian quilt (3.0 format)** -- ship the patch as `.patch` files in `debian/patches/` over the Debian source. Rollback-safe (`apt reinstall freerdp3-x11`); survives `apt upgrade` via `series`.

### Expected Features

**Must have (table stakes, P1 for v1):**
- One-finger native touch/drag over RDPEI with complete, ordered contact events (`TouchBegin -> TouchUpdate -> TouchEnd`, stable `contactId`, frame-committed).
- Contact cancellation / clean lifecycle on lift, window unfocus, and gesture abort -- without it the session drifts into a broken state within minutes.
- Coordinate transform to remote-desktop pixels under fullscreen, windowed, and rotation (touches land under the finger).
- Long-press right-click (500-700 ms, configurable), with NO phantom left-click on release.
- Two-finger pinch, native RDPEI by default, with a `Ctrl+wheel` fallback config for classic apps.
- `+multitouch` on by default in the launch config, with a documented `-multitouch` escape hatch.
- Fullscreen/windowed stability under touch (no crash, no stale contacts on focus change).
- Debian `.deb` with documented build, install, rollback, and launch wrapper.
- Env-var-gated diagnostics log (per-contact lifecycle, gesture decisions, RDPEI frame submission).

**Should have (differentiators, cheap):**
- Configurable long-press duration, slop radius, and pinch-fallback mode via CLI flags / env vars (`/touch-long-press:<ms>`, `/touch-pinch-wheel-fallback`). Microsoft's client exposes no such knobs; this is borderline table-stakes given PROJECT.md makes calibration a constraint.

**Defer (v2+):**
- Runtime pinch-mode switch, three-finger gestures / `Alt+Tab` / Win-key capture, Direct Touch <-> Mouse Pointer auto-switch, per-app gesture profiles, second-device generalization, Wayland-native input path, upstream FreeRDP PR.

### Architecture Approach

One new pure-C translation layer (`xf_touch_gesture_filter` in a new `client/X11/xf_touch.c` + `xf_touch.h`) is inserted into the existing remote-touch dispatch path. It consumes decoded `XIDeviceEvent`s and emits through existing public APIs only: `freerdp_client_handle_touch` (native RDPEI), `freerdp_input_send_mouse_event` (right-click), `freerdp_client_send_wheel_event` + `freerdp_input_send_keyboard_event` (Ctrl+wheel fallback). No new channel, thread, IPC, or contact-state array. Configuration rides the existing `rdpSettings` enum and `cmdline.c` parser -- no config-file format. Diagnostics ride the existing `WLog`/`WLOG_LEVEL=DEBUG` mechanism. The whole patch is single-threaded with input and reuses `GetTickCount64()` from winpr for the long-press timer.

**Major components:**
1. **XInput2 capture** (existing, `xf_input.c`) -- register and decode touch events; the patch must add `XIAllowTouchEvents`/`XI_TouchOwnership` handling and emulated-pointer suppression (currently missing).
2. **Touch gesture filter** (NEW, `xf_touch.c`) -- per-contact lifecycle, long-press timer, pinch baseline, fallback decision; ~50-100 lines of state machine.
3. **RDPEI native contact sender** (existing, `client/common/client.c` + `channels/rdpei/`) -- reused unchanged; single source of truth for remote contact state.
4. **Mouse/keyboard sender** (existing, `include/freerdp/input.h`) -- reused for right-click and Ctrl+wheel fallback.
5. **Configuration** (existing settings enum + CLI parser) -- 4 new settings (`TouchLongPressEnabled`, `TouchLongPressDurationMs`, `TouchLongPressMoveThreshold`, `TouchPinchWheelFallback`).
6. **Debian packaging** (existing `debian/rules`) -- one new quilt patch, `changelog` bump, no flag changes.

### Critical Pitfalls

The top pitfalls, in prevention order. Full list and recovery strategies in PITFALLS.md.

1. **Building/testing under Wayland while targeting X11 (Pitfall 10)** -- the device boots GNOME on Wayland by default. *Prevention:* Phase 0 verifies `XDG_SESSION_TYPE=x11` and captures `xinput`/`libinput` data before any code. XWayland is a separate, deferred test target.
2. **XInput2 touch ownership never accepted (Pitfall 4)** -- without `XIAllowTouchEvents(XIAcceptTouch)` and an `XI_TouchOwnership` case, touches freeze or get stolen, especially in fullscreen under Mutter. *Prevention:* select ownership events and accept on `TouchBegin` from the first prototype.
3. **Pointer-emulation double input (Pitfall 5)** -- direct-touch devices emit both `XI_Touch*` and emulated `XI_ButtonPress`. *Prevention:* drop emulated events via `XIPointerEmulated` whenever a touch sequence is active.
4. **Broken intermediary / dead `cctx->contacts` (#9082, Pitfall 1)** -- a refactor introduced a contact array nothing populates, silently dropping every event after the first `TouchBegin`. *Prevention:* keep the X11->RDPEI path direct; never duplicate the contact map; verify the installed tarball's actual code shape before patching.
5. **RDPEI race losing touch-up (#12174, Pitfall 3)** -- `rdpei_touch_process` releases the lock before `rdpei_add_contact`, so the update thread resets a half-published contact. *Prevention:* all contact-state mutations under one CriticalSection; audit the 3.15.0 source and backport the fix shape; never split the lock across a synthetic UP+DOWN.
6. **Long-press also left-clicks (#6566, Pitfall 8)** -- sending left `DOWN` immediately to keep tap latency low causes long-press to arrive as left-drag + right-click. *Prevention:* hold the contact for the 500-700 ms disambiguation window; fire right-click at end of window; clear suppression on next genuine `TouchBegin` (not on a timer).
7. **Pinch fallback double-fires (Pitfall 11)** -- native RDPEI and `Ctrl+wheel` running concurrently makes zoom oscillate. *Prevention:* choose the mode at launch (per-session boolean); never switch mid-gesture.

## Implications for Roadmap

Based on combined research, the v1 milestone should be **7 phases** (a Phase 0 environment gate plus 6 build phases). This resolves the disagreements across research files as follows.

### Resolved disagreements

- **Phase ordering.** STACK/ARCHITECTURE propose build-step lists; PITFALLS maps pitfalls to phases 0-6; FEATURES lists feature dependencies. Reconciliation: the PITFALLS phase numbering (0 through 6) is the canonical spine because it is the only one that places every critical pitfall in a prevention slot. ARCHITECTURE's 7 build steps map onto PITFALLS phases 1-6 one-for-one and are subsumed.
- **X11-vs-Wayland prerequisite.** All four files agree this is non-negotiable. It is Phase 0, gates everything, and produces no code.
- **Exact Debian baseline.** All four files independently cite `3.15.0+dfsg-2.1+deb13u3` (Debian 13 trixie, amd64). No disagreement; pin everywhere.
- **Patch-vs-fork packaging.** All four files reject a fork and mandate a quilt patch in `debian/patches/`. No disagreement.
- **Must native RDPEI lifecycle correctness precede gestures?** **YES -- this is the load-bearing ordering decision.** PITFALLS is correct that RDPEI lifecycle correctness (Phases 1-3) must precede the gesture recognizer (Phase 4), because native pinch (a Phase 4 feature) consumes the same multi-contact RDPEI path, and because a broken lifecycle silently drops events in ways that look like gesture bugs. FEATURES' aside that "Ctrl+wheel fallback is the safer first milestone because it uses only the mouse/keyboard path" is true in isolation but does **not** reorder the phases: the fallback is a *branch inside* the Phase 4 pinch recognizer, not a substitute for fixing RDPEI first. Long-press right-click (also Phase 4) can synthesize via the mouse path independently of RDPEI, so it is a reasonable first sub-step *within* Phase 4 -- but it still ships after RDPEI lifecycle correctness because the suppression logic must coordinate with the RDPEI contact that armed it.

### Phase 0: Environment capture and X11-session gate

**Rationale:** The device boots GNOME on Wayland; the project targets X11. Every touch bug is unreproducible-or-false under the wrong session. This is the single highest-leverage verification and produces zero code.
**Delivers:** Confirmed `XDG_SESSION_TYPE=x11`, captured `xinput list` / `xinput list-props` / `libinput list-devices` / current `xfreerdp3` launch command, recorded installed `freerdp3-x11` version, recorded upstream source commit hash (`405d509`) the Debian tarball is built from.
**Avoids:** Pitfall 10 (built under Wayland).
**Research flag:** Standard pattern -- a capture checklist, no deeper research needed.

### Phase 1: XInput2 capture correctness

**Rationale:** Every downstream phase consumes decoded, owned, non-emulated touch events. The existing `xf_input.c` does not call `XIAllowTouchEvents`, has no `XI_TouchOwnership` case, and does not suppress emulated pointer events -- three independent ways for touches to freeze, get stolen, or double-fire. Fix the contract before building on it.
**Delivers:** Touch events arrive owned and exclusively (no emulated duplicates) through a full drag, in windowed and fullscreen, under the OneMix 3's actual WM.
**Addresses:** Table-stakes "fullscreen/windowed stability under touch"; contact-cancellation prerequisite.
**Avoids:** Pitfalls 4 (ownership), 5 (emulation), 6 (touch-ID reuse -- clear local maps on `TouchEnd`).
**Research flag:** Needs `/gsd-plan-phase --research-phase 1` -- XI 2.2 touch-ownership semantics and Mutter-specific delivery behavior are subtle and primary-source (x.org spec) dependent.

### Phase 2: Coordinate and scaling pipeline

**Rationale:** A tap must land under the finger in windowed, fullscreen, and after rotation. The transform (`xf_event_adjust_coordinates`) is split across files and keys on `/size`, `/scale`, `/dynamic-resolution`, fullscreen state, and rotation flags. Audit it before gestures so gesture bugs aren't conflated with offset bugs.
**Delivers:** Verified four-corner + center tap accuracy in windowed, fullscreen, and rotated orientations; subpixel dedup uses a fixed ~0.5px epsilon, not `DBL_EPSILON`.
**Addresses:** Table-stakes "coordinate transform to remote desktop pixels."
**Avoids:** Pitfall 7 (coordinate/scaling black box).
**Research flag:** Standard pattern -- read the existing transform; the corner-tap check is mechanical.

### Phase 3: RDPEI contact lifecycle correctness

**Rationale:** **This is the phase the "must lifecycle precede gestures" question is decided in.** Before any gesture code, the X11->RDPEI path must deliver complete, ordered, correctly flagged contacts through a full drag, multi-finger, lift, and cancel. This is where three of the four known regressions live (#9082 dead intermediary, #12174 race, missing `INRANGE|INCONTACT` flags). Skipping this phase and going straight to gestures guarantees shipping gesture logic on top of a silently broken transport.
**Delivers:** Drag-then-lift trace shows every event delivered with valid flags; two simultaneous contacts arrive in the same RDPEI frame with distinct `contactId`s; thread-sanitizer run clean; no "no contact point" log spam.
**Addresses:** Table-stakes "one-finger native touch/drag" and "contact cancellation"; unblocks native pinch.
**Avoids:** Pitfalls 1 (broken intermediary), 2 (flag combinations), 3 (#12174 race).
**Research flag:** Needs `/gsd-plan-phase --research-phase 3` -- MS-RDPEI state-machine transitions and the exact lock shape in the 3.15.0 tarball must be audited against the spec; this is the highest-risk phase.

### Phase 4: Gesture recognizer (long-press + pinch)

**Rationale:** Only after the contact lifecycle is trustworthy does gesture disambiguation make sense. Long-press is the highest-risk disambiguation (the #6566 regression is here) and goes first within the phase because it can synthesize via the mouse path while still coordinating with the RDPEI contact that armed it. Pinch native is low-risk (the multi-contact path is already correct from Phase 3); pinch `Ctrl+wheel` fallback is the branch that must never run concurrently with native.
**Delivers:** 500-700 ms configurable long-press right-click with no phantom left-click; native pinch by default; `Ctrl+wheel` fallback as a launch-time config, never mid-gesture.
**Addresses:** Table-stakes long-press right-click, two-finger pinch native, pinch `Ctrl+wheel` fallback, configurable knobs (differentiator).
**Avoids:** Pitfalls 8 (long-press also left-clicks), 11 (pinch fallback double-fires).
**Research flag:** Standard patterns for the state machine; the Ctrl+wheel scan-code values are already in tree (`client/X11/xf_client.c:1051`). Minor research only for the suppression-flag-clearing invariant.

### Phase 5: Reconnection and grab stability

**Rationale:** Reconnect-with-`+multitouch` segfaults (#4698) because drdynvc/RDPEI state isn't torn down. Outstanding contacts, long-press timers, and XI2 grabs left across a reconnect reference freed memory. Verify the teardown path on a known-good code state.
**Delivers:** Explicit disconnect teardown checklist; reconnect-mid-drag test passes (no crash, no UAF, touch works after).
**Addresses:** Table-stakes "fullscreen/windowed stability under touch" (reconnect half).
**Avoids:** Pitfall 9 (reconnect segfault).
**Research flag:** Standard pattern -- teardown checklist + one hardware test.

### Phase 6: Diagnostics, Debian packaging, launch config, docs

**Rationale:** Wraps a frozen, verified code state. Diagnostics (`DEBUG_X11` logging via existing `WLog`) should be added incrementally during Phases 1-5 but is finalized and documented here. Packaging is a quilt patch in `debian/patches/`, `changelog` bump, no flag changes, with a recorded upstream base commit for future re-base.
**Delivers:** Installable `.deb`; documented build/install/rollback (`apt reinstall freerdp3-x11`); launch wrapper setting `+multitouch` plus the new config flags; field-triage checklist.
**Addresses:** Table-stakes Debian packaging + launch config + diagnostics.
**Avoids:** Pitfall 12 (Debian patch rot -- quilt + recorded upstream commit + re-verify-on-upgrade policy).
**Research flag:** Standard pattern -- Debian quilt workflow is well-documented (Debian Maintainer's Guide ch.6, Hertzog tutorial).

### Phase Ordering Rationale

- **Phase 0 first because** a wrong session makes every later result a lie. Zero code, maximum leverage.
- **Phases 1-3 before Phase 4 because** RDPEI lifecycle correctness must precede gestures -- this is the resolved answer to the explicit disagreement. Native pinch (Phase 4) consumes the same multi-contact RDPEI path delivered by Phase 3; long-press suppression must coordinate with the RDPEI contact that armed it. FEATURES' "Ctrl+wheel fallback first" observation is honored as a within-Phase-4 ordering (long-press can ship first via the mouse path), not as a phase reorder.
- **Phase 2 (coordinates) inside the lifecycle trio because** it is independent of RDPEI but must be verified before gestures so offset bugs aren't blamed on gesture logic.
- **Phase 5 (reconnect) after gestures because** the teardown checklist must enumerate every piece of gesture and contact state the earlier phases created.
- **Phase 6 last because** packaging wraps a frozen code state; diagnostics logging is added incrementally in Phases 1-5 and finalized here.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 1 (XInput2 capture):** XI 2.2 touch-ownership semantics, `XIAllowTouchEvents` timing, Mutter-vs-bare-X11 delivery differences, `XIGrabModeTouch` requirements. Primary source is the x.org XI2 proto spec.
- **Phase 3 (RDPEI lifecycle):** MS-RDPEI state-machine transitions, valid `INRANGE|INCONTACT` flag combinations, and the exact lock shape in the 3.15.0 tarball (must audit for the #12174 race and #9082 dead-array shape). Highest-risk phase.

Phases with standard patterns (skip deep research):
- **Phase 0:** Capture checklist.
- **Phase 2:** Read the existing `xf_event_adjust_coordinates`; corner-tap verification is mechanical.
- **Phase 4:** State-machine patterns are well-documented (React Aria, Android `CheckLongPressHelper`, `evdev-right-click-emulation`); Ctrl+wheel scan codes are already in tree.
- **Phase 5:** Teardown checklist + one reconnect test.
- **Phase 6:** Debian quilt workflow (Debian Maintainer's Guide, Hertzog tutorial).

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All claims verified against the unpacked Debian source tarball AND upstream 3.30 source; device baseline observed directly on the host. |
| Features | HIGH | Categorization grounded in FreeRDP tracker issues and Microsoft's own gesture model; complexity estimates are MEDIUM-confidence pending the exact installed source version. |
| Architecture | HIGH | Verified against the actual 3.15.0 source -- file paths, line numbers, struct fields, and existing helper signatures all confirmed. |
| Pitfalls | HIGH | Every critical pitfall is tied to a specific merged PR or closed issue on the FreeRDP tracker; Debian packaging guidance from official Debian maintainer docs. |

**Overall confidence:** HIGH. The research is unusually well-grounded because the primary source (the exact source tarball being patched) is available locally and was cross-verified against upstream.

### Gaps to Address

- **Exact code shape of the 3.15.0 tarball for #9082 and #12174.** Both issues were fixed after 3.15.0 in some branches and re-broken by later refactors. Phase 3 must `diff client/X11/xf_input.c` and `channels/rdpei/client/rdpei_main.c` against the cited fix commits before assuming the bug is or isn't present. Do not patch gestures on top of an unaudited transport.
- **OneMix 3 WM identity under the native X11 session.** Phase 0 captures the session type but the WM (Mutter vs other) determines touch-ownership delivery semantics. Confirm during Phase 0; re-confirm in Phase 1 testing.
- **Rotation coordinate behavior on the OneMix 3 specifically.** The device is a convertible; the X/Y swap and inversion must be verified on-device in Phase 2, not assumed from the spec.
- **Hotplug of touch device mid-session (#7759).** Out of scope for v1 but must be documented as a known limitation; do not silently fail -- log it. Phase 6 docs.
- **Upstream re-base trigger.** No 3.x stable branch exists upstream (only 1.0/1.1/2.0). When Debian pushes a point release, the quilt patch must be re-applied and the three core gestures re-verified. Phase 6 records the upstream commit and the re-verify policy.

## Sources

### Primary (HIGH confidence)
- Unpacked Debian source `freerdp3_3.15.0+dfsg-2.1+deb13u3` (FreeRDP commit `405d509`) -- `client/X11/xf_input.c`, `xf_event.c`, `xf_client.c`, `xfreerdp.h`, `client/common/client.c`, `client/common/cmdline.c`, `include/freerdp/channels/rdpei.h`, `include/freerdp/settings_types_private.h`, `channels/rdpei/client/rdpei_main.c`, `debian/rules`, `debian/control`.
- Upstream `xf_input.c` at 3.30.0 (raw.githubusercontent.com) -- cross-verified local/remote split and `freerdp_client_handle_touch` unchanged from 3.15.
- MS-RDPEI specification (learn.microsoft.com) -- `RDPINPUT_TOUCH_FRAME`, `RDPINPUT_CONTACT_DATA`, contact flag combinations, state transitions.
- X.org XI2 protocol spec (XI2proto.txt) -- `XISetMask`, `XISelectEvents`, `XI_TouchBegin/Update/End`, `XIAllowTouchEvents`, `XI_TouchOwnership`, pointer emulation.
- Device observation on this host -- `xfreerdp3` 3.15.0, `freerdp3-x11` 3.15.0+dfsg-2.1+deb13u3, Debian 13 trixie amd64, GNOME on Wayland with `gnome-xorg.desktop` available, XI 2.4.

### Secondary (MEDIUM confidence)
- FreeRDP GitHub issues #9082 (multitouch regression, bisected to `d66b165`), #12174 (lost touch-up race), #6566 (long-press ~4s), #4698 (reconnect segfault), #8253 (closed by PR #12686), #7721, #7759 (hotplug).
- FreeRDP PRs #9084 (revert to direct calls), #9086 ("Multitouch common" -- rotation/tilt, re-broke some paths), #12686 (Android touch fix), #6569 (long-press fix).
- Microsoft TechCommunity -- Gesture list for Touch and Mouse Pointer input modes.
- Debian Maintainer's Guide ch.6 + Raphael Hertzog quilt tutorial -- 3.0 (quilt) patch workflow.
- `evdev-right-click-emulation`, Android `CheckLongPressHelper`, React Aria `useLongPress` -- long-press timer-cancellation and suppression-flag patterns.

### Tertiary (LOW confidence)
- FreeRDP PR #9086 testing notes (cursor jumping, PowerPoint pinch) -- community reports, need on-device verification in Phase 4.

---
*Research completed: 2026-08-05*
*Ready for roadmap: yes*

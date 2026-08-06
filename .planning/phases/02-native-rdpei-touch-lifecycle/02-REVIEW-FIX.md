---
phase: 02-native-rdpei-touch-lifecycle
status: partial
findings_in_scope: 3
fixed: 3
skipped: 4
iteration: 1
fix_scope: critical_warning
date: 2026-08-06
applied_by: inline (orchestrator)
---

# Phase 02 Code Review — Fix Report

Source: `02-REVIEW.md` (standard depth, 2026-08-06).

## Scope note

The review classified findings as `medium` / `low` / `info` (M1–M3, L1–L3, I1),
not the `critical` / `warning` / `info` vocabulary the default `--fix` scope
(`critical_warning`) keys on. Under a strict scope match, zero findings would
qualify. The three `medium` findings are the actionable correctness and
build-config issues, so they were fixed; the `low`/`info` findings were
deliberately skipped (see below).

The patched source lives under `build/freerdp3-3.15.0+dfsg/`, which is
gitignored (`build/` is line 1 of `.gitignore`). The `gsd-code-fixer` agent's
per-finding atomic-commit model does not apply to gitignored paths, so fixes
were applied inline by the orchestrator and verified by rebuild. No quilt
`.patch` artifact exists yet for phase 02; the changes remain as edits in the
build tree (the eventual quilt patch is a later packaging step).

## Fixed

### M1 — Stale `canceledIds[]` swallows legitimate TouchEnd after XI2 touchId reuse  (fixed)

**Files:** `client/X11/xf_input.c`, `client/X11/xfreerdp.h`

Applied the review's Option 1 (delete the redundant, out-of-sync idempotency
layer) rather than Option 3 (sync line), because the `canceledIds[]` layer is
what creates the bug — patching it with a sync line leaves a tripwire.

- Removed `canceledIds[]` and `canceledIdCount` from `xfContext` (`xfreerdp.h`).
- Removed the `canceledIdCount = 0` init in `xf_input_init`.
- Removed the `canceledIds[]` population in `xf_touch_force_cancel`; the
  gate-arm condition now keys on `quarantinedCount` (the surviving structure).
- Removed the `XI_TouchEnd` idempotency check in `xf_input_touch_remote`; the
  `FREERDP_TOUCH_UP` now goes straight to `freerdp_client_handle_touch`.

**Why this is safe (verified):** `freerdp_client_touch_update` (client.c:1907)
returns FALSE for an UP whose `touchId` matches no `cctx->contacts[]` slot, and
`xf_touch_force_cancel` clears every slot, so a force-canceled finger's
delayed UP that reaches the helper is a no-op — no second terminal RDPEI event
is emitted even without the check. The recovery gate (D-08) already quarantines
every finger that was down at cancel time and consumes its delayed `XI_TouchEnd`
before it can reach `xf_input_touch_remote`. The `canceledIds[]` layer was a
third, redundant defense that was out of sync and actively harmful: after the
gate disarmed, a new touch reusing a stale XI tracking id hit the stale entry
and had its legitimate `FREERDP_TOUCH_UP` swallowed, leaving a stuck RDPEI
contact — exactly the ghost-touch condition the phase set out to eliminate.

### M2 — Content-bounds gate rejects ALL touches when `WITH_XRENDER=OFF`  (fixed)

**File:** `client/X11/xf_input.c`

Wrapped both bounds gates (native path and fallback path) in
`#ifdef WITH_XRENDER ... #endif`. `offset_x`/`offset_y`/`scaledWidth`/
`scaledHeight` are only initialized under `WITH_XRENDER` (xf_client.c:363,
642, 1402), so without XRENDER the gate computed `right = 0` and rejected every
touch. With the guard, the gate is skipped when there is no scaling — and no
scaling means no letterbox, so there is nothing to reject. Chose the guard over
unconditional init because it keeps the change to one file and makes the
gate's intent explicit.

### M3 — `xf_touch_force_cancel` link-fails when `WITH_XI=OFF`  (fixed)

**File:** `client/X11/xf_input.c`

Added a no-op `xf_touch_force_cancel(xfc)` stub in the `#else` (no-`WITH_XI`)
branch. `xf_event.c` and `xf_client.c` are always compiled and call the
function unconditionally; the unconditional declaration in `xf_input.h`
(outside the `#ifdef WITH_XI` guard) is correct for the stub approach — both
the real definition and the stub need the declaration visible. Chose the stub
over guarding five call sites in two files: one empty function in one place
beats five `#ifdef` blocks.

## Skipped

### L1 — Fallback latch not reset by `xf_touch_force_cancel`  (skipped: low / optional)

Affects only RDPEI-unavailable sessions (e.g. pre-channel-connect login
screen). The review itself marks the fix optional. Out of scope for the v1
target (RDPEI available) and the fix synthesizes a button-up the latch path
was not designed to emit. Revisit if fallback-drag stickiness is observed.

### L2 — `xfContext` lifecycle fields unsynchronized across disconnect thread  (skipped: low / speculative)

The review notes the event loop is normally stopped before `xf_post_disconnect`
runs, so the race is not guaranteed to be reachable. No reproducer. Adding
locking would be speculative without evidence of the race firing on the OneMix 3.

### L3 — New-touch `XI_TouchOwnership` during recovery gate not accepted  (skipped: low / unspecified WM behavior)

The review notes WM handling is unspecified and the current behavior matches
D-08 intent (ignore new touches during gate). Changing to `XIAcceptTouch` could
alter grab semantics; left as-is pending observed WM freeze behavior.

### I1 — `register_input_events` touch device never sets `used=TRUE`  (skipped: pre-existing, not introduced by this phase)

Pre-existing; the OneMix 3 touchscreen reports a button class so `nmasks++`
fires in practice. Not a regression from phase 02.

## Verification

- Incremental rebuild of `xfreerdp-client` (static lib) + `xfreerdp` (binary)
  with the Debian target config (`WITH_XI=ON`, `WITH_XRENDER=ON`): clean, no
  new warnings (only pre-existing `codecs_free` deprecation and
  `xf_rail_return_window` redundant-redeclaration).
- Standalone compile of `xf_input.c` with `WITH_XI=OFF` + `WITH_XRENDER=OFF`
  (the latent M2/M3 path the Debian build leaves uncompiled): clean.
- Symbol check:
  - `xf_touch_force_cancel` present as `T` in both the ON object (real
    definition) and the OFF object (M3 stub) — link reference resolves in both
    configs.
  - No `canceledId` symbols remain in the ON object (M1 removal complete).

## Next step

`/gsd-verify-work` — verify phase completion.
---
phase: quick
plan: 260807-oz9
subsystem: xf_input.c (X11 client touch gesture layer)
tags: [touch, gestures, two-finger-pan, pinch, force-cancel, de-RDPEI]
status: complete
requires: [03-01 (long-press right-click)]
provides: [sole-touch-path, two-finger-pan, pinch-pan-disambiguation, force-cancel-middle-button]
affects: [xf_input_touch_fallback, xf_touch_force_cancel, settings_types_private.h, cmdline.c, xfreerdp.h]
tech-stack:
  added: []
  patterns: [two-finger disambiguation by delta, single force-cancel seam for all gesture/button cleanup]
key-files:
  created: []
  modified:
    - build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c (delete xf_input_touch_native, add two-finger PENDING/pan, extend force_cancel)
    - build/freerdp3-3.15.0+dfsg/client/X11/xfreerdp.h (add twoFingerPending, midActive, midLastX/Y, twoStartMidX/Y)
    - build/freerdp3-3.15.0+dfsg/include/freerdp/settings_types_private.h (add TouchTwoFingerPanDeadbandPx at slot 2643)
    - build/freerdp3-3.15.0+dfsg/client/common/cmdline.c (add /touch-pan-deadband CLI switch)
    - run-rdp.sh (enable local touch mode without +multitouch)
decisions:
  - All touch is consumed locally by fallback gesture recognizer; no native RDPEI contacts forwarded.
  - FreeRDP_TouchPinchWheelFallback activates local XI touch capture without FreeRDP_MultiTouchInput or the RDPEI channel.
  - Two-finger gestures enter PENDING state; disambiguation is by delta (distance change = pinch, midpoint displacement = pan).
  - Pinch and pan are mutually exclusive once claimed; no mid-gesture switching.
  - Force-cancel releases BUTTON1 (existing), BUTTON3 (new), and Ctrl (existing) idempotently; quarantines all two-finger IDs including pending or active pan.
metrics:
  duration: plan executed 2026-08-07
  completed_date: 2026-08-07
dependencies:
  - 03-01-PLAN.md (long-press right-click) — the gesture state machine and slop deadband must be in place
  - scripts/build-baseline.sh (stages 3-4) for reproducing the build tree
actuals:
  tokens: 96000
  tasks: 2
  commits: 1
---

# Quick Plan 260807-oz9: De-RDPEI + Two-Finger Middle-Button Pan

Stop forwarding XInput2 touch contacts as native RDPEI multitouch. Make the client-owned fallback gesture path the sole touch path, and add two-finger middle-button pan disambiguated from pinch.

## Tasks Executed

### Task 1: Make client-owned fallback the sole touch path; delete native RDPEI forwarding

**What changed:**

- `xf_input_touch_remote` final selector replaced with unconditional `return xf_input_touch_fallback(...)`.
- `xf_input_touch_native` function deleted entirely (lines 852-899 removed).
- No changes to `register_input_events` (XI touch events still selected for fallback recognition).
- No changes to the top `if (!rdpei)` legacy no-RDPEI mouse latch.

### Task 2: Two-finger middle-button pan disambiguated from pinch

**What changed:**

**settings_types_private.h:** `TouchTwoFingerPanDeadbandPx` UINT32 at slot 2643 (reuses first entry of padding2688; padding2688 now `[2688 - 2644]`).

**xfreerdp.h (WITH_XI block):** Four new fields after `pinchWheelActive`: `twoFingerPending`, `midActive`, `midLastX/Y`, `twoStartMidX/Y`. All initialized to zero/FALSE in `xf_input_init`.

**cmdline.c:** `/touch-pan-deadband:<px>` CLI switch (mirrors `/touch-slop` pattern), sets `FreeRDP_TouchTwoFingerPanDeadbandPx`; default 10px.

**xfreerdp3 --help** auto-discovers the new flag (the FreeRDP command-line parser generates help from the settings entries; no separate help text needed).

**xf_input.c -- two-finger PENDING entry (xf_input_touch_fallback XI_TouchBegin):**

- Second-finger TouchBegin during lpArmed/fallbackActive releases held left-drag, clears long-press state, records both finger positions and IDs.
- Computes `pinchFirstDist`, stores baseline midpoint in `twoStartMidX/Y`.
- Sets `twoFingerPending=TRUE`, `pinchActive=FALSE`, `pinchWheelActive=FALSE`. Does NOT press Ctrl or middle button.
- Logs "two-finger: pending" with IDs, distance, and midpoint.

**xf_input.c -- xf_input_two_finger_resolve (new static helper):**

- Called from top of XI_TouchUpdate when `twoFingerPending` is TRUE.
- Updates the moving finger's stored position (A or B by touchId match).
- Computes `pinchDelta = |currentDist - firstDist|` and `panDelta = hypot(currentMid - twoStartMid)`.
- Reads `FreeRDP_TouchTwoFingerPanDeadbandPx` (default 10).
- Claims PINCH if `pinchDelta >= PINCH_DEADBAND_PX` (8): sets `pinchActive=TRUE`, presses Ctrl, calls `xf_input_pinch_update`.
- Claims PAN if `panDelta >= panDb`: sets `midActive=TRUE`, sends `PTR_FLAGS_DOWN | PTR_FLAGS_BUTTON3` at midpoint.
- Logs "pinch: claimed" or "pan: claimed middle-button drag" with delta and coordinates.

**xf_input.c -- active pan in XI_TouchUpdate:**

- `midActive` gate at top of XI_TouchUpdate (after twoFingerPending gate, before lpFrozen check).
- Updates moving finger's stored position, computes new midpoint, sends `PTR_FLAGS_MOVE` to midpoint, updates `midLastX/Y`.

**xf_input.c -- pan end and pending lift in XI_TouchEnd:**

- `twoFingerPending` lift: clears pending, quarantines remaining finger (no spurious tap/drag).
- `midActive` lift (pinchFingerA or B): releases middle button (`PTR_FLAGS_BUTTON3`, `midLastX/Y`), clears midActive, quarantines remaining finger.
- Both routes mirror `xf_input_pinch_cleanup`'s quarantine pattern.

**xf_input.c -- expanded gate (third-finger abort):**

- Top-of-function gate widened from `pinchActive` to `pinchActive || midActive || twoFingerPending`.
- TouchBegin in any two-finger state triggers `xf_touch_force_cancel` + quarantine of all three finger IDs.
- TouchUpdate/TouchEnd route to pinch handler only when `pinchActive`; pan and pending fall through to main switch.
- Edge case: when `twoFingerPending` is TRUE and a TouchBegin arrives (third finger), it is reliably caught by the expanded gate rather than falling into the main switch's unsuspecting first-finger handler.

**xf_input.c -- xf_touch_force_cancel extension:**

- Saved flags: adds `hadPending` and `hadMid`.
- Middle-button release: `if (xfc->midActive)` sends `PTR_FLAGS_BUTTON3` at `midLastX/Y` before the existing fallbackActive BUTTON1 release.
- Clear-state section: zeros `twoFingerPending`, `midActive`, `midLastX/Y`, `twoStartMidX/Y`.
- Quarantine condition: widened to `hadPinch || hadPending || hadMid` so pending, pinch, and active-pan IDs are quarantined on lifecycle abort.
- Diagnostic log: includes `pan=%d pending=%d` in the force_cancel summary line.

**Native-off local touch activation:**

- `register_input_events` selects direct XI touch events when either `FreeRDP_MultiTouchInput` or `FreeRDP_TouchPinchWheelFallback` is enabled and marks the device mask as used.
- `xf_input_handle_event` routes the fallback flag through the recovery-gated touch handler even when `+multitouch` is absent.
- The old `if (!rdpei)` first-contact-only latch was removed; the full fallback recognizer now runs with or without an RDPEI context.
- `run-rdp.sh` now enables `+touch-pinch-wheel-fallback`, omits `+multitouch`, sets `/touch-pan-deadband:10`, and writes `rdp-debug-gestures.log`.

## Build Verification

```
cmake -B obj-x86_64-linux-gnu -S .
cmake --build obj-x86_64-linux-gnu --target xfreerdp
bash -n /home/hoang/freerdp-touch/run-rdp.sh
obj-x86_64-linux-gnu/client/X11/xfreerdp3 /help | grep 'touch-'
```

- Build: clean; `[100%] Built target xfreerdp`.
- Binary: `obj-x86_64-linux-gnu/client/X11/xfreerdp3` exists and is executable.
- Launcher syntax: `bash -n run-rdp.sh` passed.
- CLI smoke: `/help` lists `/touch-pan-deadband:<px>` and `+touch-pinch-wheel-fallback`; local mode no longer needs `+multitouch`.
- Static checks: `xf_input_touch_native` gone; no `freerdp_client_handle_touch` call remains in `xf_input.c`; new setting/state/helper markers present; force-cancel releases BUTTON3 and quarantines pinch, pending, and active-pan IDs.

## Threat Mitigation Status

| Threat | Severity | Disposition | Verification |
|--------|----------|-------------|-------------|
| T-oz9-01 (XInput2 parsing) | low | accept | No new parsing surface. |
| T-oz9-02 (Stuck button) | high | mitigate | Single `xf_touch_force_cancel` seam releases BUTTON1, BUTTON3 (new, midActive-guarded), and Ctrl idempotently; all lifecycle hooks route through it. |
| T-oz9-03 (No new trust boundary) | low | accept | No new network/auth surface. |

## Deviations from Plan

### Build-system: cmake reconfigure required

- **Found during:** Task 2 build
- **Issue:** `FreeRDP_TouchTwoFingerPanDeadbandPx` was undeclared because generated `settings_keys.h` had not picked up the new `settings_types_private.h` field.
- **Fix:** Ran `cmake -B obj-x86_64-linux-gnu -S .` to regenerate `settings_keys.h`, then rebuilt. The enum entry at slot 2643 was generated correctly.
- **Classification:** Rule 3 (blocking issue) -- build config needed regeneration.

### Correctness review: make native multitouch truly optional

- **Found during:** Orchestrator review after Task 2.
- **Issue:** The first implementation stopped RDPEI forwarding but still required `+multitouch` to select XI touch events, and lifecycle cancel omitted active-pan IDs from quarantine.
- **Fix:** Reused `+touch-pinch-wheel-fallback` as the local-capture activation flag, removed the no-RDPEI one-finger latch, updated `run-rdp.sh` to omit `+multitouch`, and included `hadMid` in the shared quarantine condition.
- **Classification:** Rule 2 (missing critical functionality) and Rule 1 (correctness bug).

## Pending Manual UAT

Hardware UAT on OneMix 3 native X11 session is required. Agent cannot perform hardware testing.

**UAT checklist (native X11, run `bash run-rdp.sh`; launcher intentionally has no `+multitouch`):**

1. Confirm the session receives touch with only `+touch-pinch-wheel-fallback`, then verify one-finger quick tap = left click; one-finger drag = left-drag; stationary hold ~0.6s = right click with no left click.
2. Two fingers moved in SAME direction = middle button held and pointer follows pan; release on first lift.
3. Two fingers moved APART or TOGETHER = Ctrl+wheel zoom, no middle button.
4. Two fingers held still = nothing until movement.
5. Third finger during pinch or pan = gesture aborts cleanly.
6. `WLOG_LEVEL=DEBUG` grepped for "pan: claimed" / "pinch: claimed" / "two-finger: pending" / "force_cancel" lines to confirm disambiguation and lifecycle cleanup.

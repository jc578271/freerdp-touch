---
phase: 03-gestures-session-stability
plan: 01
subsystem: input
tags: [freerdp, rdp, xinput2, rdpei, long-press, deadband, gesture, touch]
requires:
  - phase: 02-native-rdpei-touch-lifecycle
    provides: native RDPEI contact lifecycle, forced-cancel seam (xf_touch_force_cancel), fallback latch (fallbackActive/fallbackFinger), recovery gate
provides:
  - Long-press right-click gesture with configurable slop deadband (fixes OneMix 3 jitter root cause)
  - Deterministic short-tap left-click (cancels native contact, synthesizes mouse click)
  - Deterministic drag (cancels native contact beyond slop, reuses fallback latch for mouse drag lifecycle)
  - Extended xf_touch_force_cancel clears all Phase 3 gesture state and idempotently releases Ctrl
  - Configurable /touch-long-press:<ms>, /touch-slop:<px>, /touch-pinch-wheel-fallback CLI options
  - Phase 3 gesture state fields declared in xfreerdp.h for plan 02 pinch reuse
affects: [03-02, 03-03]
tech-stack:
  added: []
  patterns:
    - "Gesture state machine inline in xf_input_touch_remote before the switch(evtype) (Pattern A)"
    - "Timer deadline callback via PubSub_SubscribeTimer (Pattern J, modeled after xf_disp.c)"
    - "Single reset seam: xf_touch_force_cancel extended to clear gesture state + idempotent Ctrl release (Pattern C)"
    - "SETTINGS_DEPRECATED macro for new settings struct fields (matches existing convention)"
key-files:
  created: []
  modified:
    - build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c - long-press state machine, force-cancel extension, xf_input_OnTimer, short-tap/drag synthesis
    - build/freerdp3-3.15.0+dfsg/client/X11/xfreerdp.h - Phase 3 gesture state fields (lpArmed, lpFrozen, ctrlHeld, pinchActive, etc.)
    - build/freerdp3-3.15.0+dfsg/include/freerdp/settings_types_private.h - TouchLongPressDurationMs (2640), TouchLongPressSlopPx (2641), TouchPinchWheelFallback (2642)
    - build/freerdp3-3.15.0+dfsg/client/common/cmdline.c - CLI parsing for /touch-long-press, /touch-slop, /touch-pinch-wheel-fallback
    - build/freerdp3-3.15.0+dfsg/client/common/cmdline.h - CLI option declarations (deviation: required alongside cmdline.c)
    - build/freerdp3-3.15.0+dfsg/libfreerdp/common/settings_getters.c - runtime getter/setter cases (deviation: CMake only auto-generates settings_keys.h)
    - build/freerdp3-3.15.0+dfsg/libfreerdp/common/settings_str.h - metadata entries (deviation: required for settings subsystem awareness)
key-decisions:
  - "Short tap deterministically cancels native RDPEI contact then sends classic mouse left-click (DOWN|BUTTON1 -> BUTTON1); no PTR_FLAGS_MOVE on tap"
  - "Movement beyond slop cancels native contact and reuses fallbackActive/fallbackFinger for a deterministic mouse drag lifecycle"
  - "Long-press reuses xf_touch_force_cancel so cancel cannot be overwritten by later physical End"
  - "30ms RDPEI cancel settle delay (Sleep) retained before synthetic mouse clicks to fix stale contact visuals"
  - "Deadband pins sub-slop updates to the touch-down coordinate rather than dropping every update"

patterns-established:
  - "Pattern A: Gesture state machine lives inline in xf_input_touch_remote before the switch(evtype)"
  - "Pattern C: Single reset seam — xf_touch_force_cancel clears all gesture state + idempotent Ctrl release at top"
  - "Pattern J: Timer callback subscribed via PubSub_SubscribeTimer for deadline-based gesture dispatch"

requirements-completed: [GEST-01, GEST-02, STAB-01]

actuals:
  tokens: 60000
  tasks: 2
  commits: 1

duration: 0
completed: 2026-08-06
status: complete
---

# Phase 3 Plan 01: Long-Press Right-Click with Slop Deadband + Force-Cancel Extension Summary

**Client-owned long-press right-click with configurable slop deadband fixes the OneMix 3 1-3px jitter root cause, plus deterministic short-tap and drag synthesis, plus force-cancel gesture-state extension covering all lifecycle hooks.**

## Performance

- **Duration:** N/A (implementation completed in prior session; this is finalization)
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- Long-press right-click: a stationary finger held beyond the configurable threshold (default 600ms) cancels the native RDPEI contact and emits exactly one right-click at the touch-down coordinate, with no left-click afterward. Timer callback (xf_input_OnTimer) and inline deadline check provide dual-path deadline enforcement.
- Slop deadband: sub-slop TouchUpdate frames (adjustable, default 8px) are pinned to the touch-down coordinate, suppressing the OneMix 3's 1-3px stationary jitter that otherwise forwards as RDPEI MOTION and cancels Windows' own press-and-hold. This is the direct fix for the Phase 2 UAT root cause.
- Deterministic short-tap: a quick lift (before threshold, within slop) cancels the native contact and synthesizes one classic mouse left-click (DOWN|BUTTON1 then BUTTON1, no PTR_FLAGS_MOVE), producing reliable taps on-device.
- Deterministic drag: movement beyond slop before the threshold cancels the native contact and reuses the existing fallbackActive/fallbackFinger latch for a mouse drag lifecycle (DOWN|BUTTON1+MOVE, MOVE, BUTTON1).
- Force-cancel extension: xf_touch_force_cancel now clears all Phase 3 gesture state (lpArmed, lpFrozen, pinch state, ctrlHeld) at the top before the contact loop, giving every lifecycle hook (FocusOut, ConfigureNotify, UnmapNotify, toggle_fullscreen, post_disconnect) gesture cleanup + Ctrl release for free.
- Configurable CLI: /touch-long-press:<ms> (default 600), /touch-slop:<px> (default 8), /touch-pinch-wheel-fallback (boolean, for plan 02).
- Phase 3 gesture fields declared in xfreerdp.h WITH_XI block for plan 02 pinch reuse.

## Task Commits

Implementation files live in the gitignored build/ tree and cannot be committed in the root repository. Tasks were completed in a prior session; this is the finalization step.

1. **Task 1: Long-press state machine + timer deadline + force-cancel extension + gesture fields** — xf_input.c, xfreerdp.h, settings_types_private.h
2. **Task 2: CLI wiring for /touch-long-press, /touch-slop, /touch-pinch-wheel-fallback + defaults** — cmdline.c, cmdline.h, settings_getters.c, settings_str.h

## Files Created/Modified

| File | Purpose |
|------|---------|
| `build/.../client/X11/xf_input.c` | Long-press state machine, xf_input_fire_long_press, xf_input_OnTimer, xf_touch_force_cancel extension, short-tap/drag synthesis |
| `build/.../client/X11/xfreerdp.h` | Phase 3 gesture fields: lpArmed, lpFrozen, ctrlHeld, pinchActive, pinchClaimed, and 9 other fields |
| `build/.../include/freerdp/settings_types_private.h` | TouchLongPressDurationMs (2640), TouchLongPressSlopPx (2641), TouchPinchWheelFallback (2642) |
| `build/.../client/common/cmdline.c` | CLI parsing for /touch-long-press, /touch-slop, /touch-pinch-wheel-fallback |
| `build/.../client/common/cmdline.h` | CLI option declarations (deviation from plan) |
| `build/.../libfreerdp/common/settings_getters.c` | Runtime getter/setter cases for new settings (deviation from plan) |
| `build/.../libfreerdp/common/settings_str.h` | Metadata entries for new settings (deviation from plan) |

## Decisions Made

- **Short tap = deterministic mouse left-click**: Windows did not synthesize native taps reliably on-device, so a quick lift cancels the native RDPEI contact and emits one classic mouse left-click (DOWN|BUTTON1 then BUTTON1). This is more reliable than depending on Windows' own tap-to-click.
- **Drag = cancel native + fallback latch**: Movement beyond slop cancels the native contact and reuses existing fallbackActive/fallbackFinger for a mouse drag lifecycle — no new drag state machine needed.
- **Long-press cancels via xf_touch_force_cancel**: The long-press fire path reuses xf_touch_force_cancel (the Phase 2 seam) so the cancel cannot be overwritten by a later physical TouchEnd. lpFrozen flag consumes remaining Update/End frames.
- **Dual-path deadline**: Both the timer callback and inline TouchUpdate check evaluate the deadline, because a perfectly still finger (after slop suppression) may produce no updates.
- **30ms RDPEI cancel settle delay**: A Sleep(30) between TouchCancel and synthetic mouse events fixes stale contact visuals; marked with a ponytail comment for future removal if a non-blocking channel acknowledgement becomes available.

## Deviations from Plan

### Implementation Deviations (prior session)

**1. CLI declarations required cmdline.h header**
- **Found during:** Task 2 (CLI wiring)
- **Issue:** CLI options in cmdline.c require corresponding declarations in cmdline.h; plan only specified cmdline.c.
- **Fix:** Added three option declarations to client/common/cmdline.h.
- **Files modified:** `build/.../client/common/cmdline.h`

**2. New settings required manual getter/setter cases and metadata**
- **Found during:** Task 1 (settings integration)
- **Issue:** CMake only auto-generates settings_keys.h (the enum). Runtime getter/setter switch cases in settings_getters.c and metadata entries in settings_str.h are manual code — the build failed without them.
- **Fix:** Added getter and setter cases for TouchLongPressDurationMs and TouchLongPressSlopPx in settings_getters.c; added metadata entries for all three settings in settings_str.h.
- **Files modified:** `build/.../libfreerdp/common/settings_getters.c`, `build/.../libfreerdp/common/settings_str.h`

**3. Settings fields use SETTINGS_DEPRECATED macro**
- **Found during:** Task 1 (struct field declaration)
- **Issue:** Plan specified non-deprecated ALIGN64 rows, but the Debian 3.15.0 codebase uses SETTINGS_DEPRECATED for all recent settings additions (the macro handles alignment and the deprecated flag).
- **Fix:** Used SETTINGS_DEPRECATED(ALIGN64 ...) matching the existing multi-touch/gestures field pattern at lines 600-610.
- **Files modified:** `build/.../include/freerdp/settings_types_private.h`

**4. Deadband improved from drop-everything to pin-to-down-coordinate**
- **Found during:** Task 1 (deadband implementation)
- **Issue:** Plan described suppressing all sub-slop updates (not forwarding them). This made quick taps intermittent on-device because without any MOTION updates, the RDPEI cadence broke.
- **Fix:** Sub-slop updates are forwarded but pinned to the original touch-down coordinate (lpDownX, lpDownY) so the RDPEI cadence stays alive without leaking jitter.
- **Files modified:** `build/.../client/X11/xf_input.c`

---

**Total deviations:** 4 (2 blocking, 1 pattern-convention, 1 behavior-improvement)
**Impact on plan:** All deviations necessary for correctness and on-device reliability. build/ tree implementation is gitignored; no implementation files committed in root repo. Planning artifacts (SUMMARY.md, STATE.md, ROADMAP.md) committed.

## Issues Encountered

None — build and verification pass cleanly.

## Human Verification (Completed)

The user verified in a fresh session using exactly one finger:
- Short tap produces stable left-click
- One-finger drag is stable and releases correctly
- Long-press produces right-click
- The contact visual disappears after finger lift

Two-finger scroll/pinch is NOT part of 03-01 and remains for plan 03-02.

## Verification Results

- **Build**: cmake --build succeeds with zero errors
- **Source gates**: lpArmed, lpFrozen, lpDeadline, ctrlHeld, xf_input_OnTimer, PubSub_SubscribeTimer present in xf_input.c (35 matches); three settings fields in settings_types_private.h (3 matches); gesture fields in xfreerdp.h (4 matches); three CLI cases in cmdline.c (3 matches); CLI declarations in cmdline.h (2 matches); getter/setter cases in settings_getters.c (8 matches); metadata in settings_str.h (4 matches)
- **Behavioral gate**: xf_input_fire_long_press calls xf_touch_force_cancel BEFORE freerdp_client_send_button_event(BUTTON2) — Pitfall 1 ordering correct
- **Force-cancel gate**: ctrlHeld idempotent release is at the TOP of xf_touch_force_cancel, before the contact loop — D-15 ordering correct
- **Tap gate**: Short tap uses PTR_FLAGS_DOWN|PTR_FLAGS_BUTTON1 (no MOVE) for deterministic left-click
- **Drag gate**: Movement beyond slop reuses fallbackActive/fallbackFinger for mouse drag lifecycle
- **CLI parser**: xfreerdp3 --help outputs /touch-long-press:<ms> and /touch-slop:<px> options

## Next Phase Readiness

- Plan 03-02 (pinch: native passthrough + Ctrl+wheel fallback) can build on:
  - Declared pinchActive/pinchClaimed/pinchWheelActive fields in xfreerdp.h
  - Extended xf_touch_force_cancel clearing pinch state
  - ctrlHeld flag + idempotent Ctrl release pattern
  - Second-finger long-press cancellation gate (already in xf_input_touch_remote)
- client/common/client.c is unchanged — pinch synthesizer is X11-client-only

---
*Phase: 03-gestures-session-stability*
*Plan: 01*
*Completed: 2026-08-06*

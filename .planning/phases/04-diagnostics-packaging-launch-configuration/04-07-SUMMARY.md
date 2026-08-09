---
phase: 04-diagnostics-packaging-launch-configuration
plan: 07
subsystem: diagnostics, testing, packaging
tags: [x11, xi2, c, cmake, ctest, quilt, wlog]

# Dependency graph
requires:
  - phase: 04-04
    provides: [shared X11 quarantine/diagnostic helpers and ownership invariants]
  - phase: 01-environment-gate-build-baseline
    provides: [pinned Debian source package and build environment]
provides:
  - "A real XI2 dispatcher regression for quarantine recovery, third-finger cleanup, and local diagnostic cancellation."
  - "A refreshed onemix-touch.patch containing the repaired X11 dispatcher and CTest source."
  - "Fresh dpkg-source/quilt evidence that the shipping patch reproduces the repaired X11 artifacts and passes the focused regression."
affects: [phase verification, Debian release patch, local-only touch recovery]

# Actuals (#2632)
actuals:
  tokens: 8445
  tasks: 2
  commits: 4

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Synthetic XI2 XGenericEventCookie fixtures drive the public xf_input_handle_event entry point with linker-wrapped XGetEventData/XFreeEventData."
    - "xf_quarantine_update and diagContacts remain the single production ownership seams for interruption state and local cancellation evidence."
    - "A project quilt patch is refreshed from the exact source tree and re-proven in a second clean Debian extraction."

key-files:
  created:
    - "build/freerdp3-3.15.0+dfsg/client/X11/test/CMakeLists.txt"
    - "build/freerdp3-3.15.0+dfsg/client/X11/test/TestXfInputDispatcher.c"
  modified:
    - "build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c"
    - "build/freerdp3-3.15.0+dfsg/client/X11/CMakeLists.txt"
    - "tests/check_third_finger_owner.py"
    - "patches/onemix-touch.patch"

key-decisions:
  - "Exercise the production xf_input_handle_event dispatcher with synthetic XI2 cookies instead of copying its state model into a test."
  - "Keep the canonical local-only configuration in the regression: FreeRDP_TouchPinchWheelFallback is enabled and FreeRDP_MultiTouchInput remains disabled."
  - "Use diagContacts for adjusted-coordinate local cancellation records and retain the existing WLog callback path with native_count=0 for local-only cancellation."
  - "Ship one integrated quilt patch and require a second clean dpkg-source extraction to match the repaired X11 source and pass the same dispatcher test."

patterns-established:
  - "Dispatcher regressions assert quarantine count, recovery gate, gesture state, diagnostic-store retirement, and captured WLog text at the production boundary."
  - "Patch synchronization proofs compare the repaired source, parent CMake file, and X11 test directory byte-for-byte before running the fresh-tree test."

requirements-completed: [DIAG-01, CONF-01]

coverage:
  - id: D1
    description: "The real XI2 dispatcher preserves quarantine across old Update, partial End, repeated cancellation, final End, and fresh Begin."
    requirement: CONF-01
    verification:
      - kind: integration
        ref: "ctest --test-dir build/freerdp3-3.15.0+dfsg/obj-x86_64-linux-gnu --output-on-failure -R '^TestXfInputDispatcher$'"
        status: pass
    human_judgment: false
  - id: D2
    description: "Local cancellation diagnostics emit final adjusted coordinates, one summary, native_count=0, and retire diagContacts."
    requirement: DIAG-01
    verification:
      - kind: integration
        ref: "TestXfInputDispatcher diagnostic_lifecycle scenario with captured production WLog callback"
        status: pass
    human_judgment: false
  - id: D3
    description: "Third-finger supplemental IDs are compacted and pre-claim three-finger cleanup clears stale pending state."
    requirement: CONF-01
    verification:
      - kind: unit
        ref: "TestXfInputDispatcher third_finger_compaction and pending_three_finger_lift scenarios"
        status: pass
      - kind: other
        ref: "python3 tests/check_third_finger_owner.py build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c"
        status: pass
    human_judgment: false
  - id: D4
    description: "The refreshed quilt patch applies to a new pinned Debian extraction and reproduces the repaired X11 source and test artifacts."
    verification:
      - kind: integration
        ref: "dpkg-source -x pinned .dsc; QUILT_PATCHES=debian/patches quilt push -a; cmp/diff source artifacts; fresh CMake/CTest/checker"
        status: pass
    human_judgment: false

# Metrics
duration: 12 min
started: 2026-08-09T22:47:48Z
completed: 2026-08-09
status: complete
---

# Phase 04 Plan 07: Dispatcher and Diagnostic Quilt Synchronization Summary

**Real XI2 dispatcher quarantine and local-diagnostic regression coverage synchronized into a fresh-source Debian quilt patch.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-08-09T22:47:48Z
- **Completed:** 2026-08-09T23:00:30Z
- **Tasks:** 2 total
- **Files modified:** 6 plan artifacts

## Accomplishments

- Added a production-boundary CTest regression that drives synthetic XI2 cookies through `xf_input_handle_event`, proving repeated cancellation quarantine, stale-event consumption, final-old-end reopening, compacted supplemental IDs, pre-claim three-finger cleanup, and canonical local-only diagnostics.
- Repaired the dispatcher ownership paths so runtime quarantine mutations flow through `xf_quarantine_update`, diagnostic cancellation is emitted from adjusted `diagContacts`, and local-only cancellation reports one `native_count=0` summary before retiring diagnostic state.
- Refreshed `patches/onemix-touch.patch`, applied it through the full Debian quilt stack in a brand-new extraction, compared the extracted X11 source/CMake/test artifacts to the repaired build tree, and passed the fresh dispatcher CTest plus scoped source checker.

## Task Commits

Each task was committed atomically:

1. **Task 1: Exercise the real XI2 dispatcher, then repair quarantine and canonical local cancellation diagnostics** - `6862568` (test), `3a4e025` (fix)
2. **Task 2: Refresh the quilt patch and prove the fresh source executes the dispatcher regression** - `f4731a8` (fix)

**Plan metadata:** final tracking commit is created after the self-check.

## Files Created/Modified

- `build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c` - repaired dispatcher quarantine and canonical diagnostic lifecycle.
- `build/freerdp3-3.15.0+dfsg/client/X11/CMakeLists.txt` - includes the BUILD_TESTING-gated X11 test directory.
- `build/freerdp3-3.15.0+dfsg/client/X11/test/CMakeLists.txt` - defines and registers `TestXfInputDispatcher`.
- `build/freerdp3-3.15.0+dfsg/client/X11/test/TestXfInputDispatcher.c` - production-dispatcher regression scenarios and WLog capture.
- `tests/check_third_finger_owner.py` - scoped source ownership and diagnostic invariants.
- `patches/onemix-touch.patch` - refreshed integrated Debian quilt patch.

## Decisions Made

- Used the public XI2 dispatcher with synthetic cookies and linker wraps rather than a copied test-only state model.
- Preserved the frozen local-only launch contract by enabling the pinch/wheel fallback setting while leaving native multitouch disabled.
- Kept the existing WLog/stderr route and exact diagnostic gate; no logging framework, package, launcher, or credential artifact was changed.
- Required a second clean Debian source extraction to apply the refreshed patch and pass the same dispatcher regression before accepting the patch as shippable source.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The first private refresh pass did not include the parent `client/X11/CMakeLists.txt` because that file was not yet owned by the existing top quilt patch. A new private extraction added it to the patch before the final copy, and the final fresh extraction passed all source comparisons and tests.
- `quilt refresh` reported pre-existing trailing whitespace in the repaired source; it was preserved to keep the patch byte-synchronized with the verified build tree and did not affect compilation or tests.

## User Setup Required

None - no external service or user configuration is required.

## Next Phase Readiness

- The targeted DIAG-01 and CONF-01 interruption/diagnostic gaps are covered by a real dispatcher regression and a fresh quilt-application proof.
- The repository is ready for the phase-wide verification and shipping audit; this plan intentionally did not rebuild or install Debian packages.
- GAP-07 remains USER-DEFERRED under D-25. `/cert:ignore` remains expected for v1, and this plan makes no server-certificate identity claim.

## Self-Check: PASSED

- The refreshed `patches/onemix-touch.patch` is non-empty and contains both the parent X11 test wiring and `TestXfInputDispatcher` source.
- Commits `6862568`, `3a4e025`, and `f4731a8` exist in git history.
- A new pinned `dpkg-source` extraction applied the full quilt stack; `cmp`/`diff -ruN` source comparisons passed; fresh CMake configure, target build, focused CTest, and source checker all passed.
- The Task 2 production commit contains only `patches/onemix-touch.patch`; the pre-existing `.planning/STATE.md` tracking modification was preserved for normal sequential updates.

---
*Phase: 04-diagnostics-packaging-launch-configuration*
*Completed: 2026-08-09*

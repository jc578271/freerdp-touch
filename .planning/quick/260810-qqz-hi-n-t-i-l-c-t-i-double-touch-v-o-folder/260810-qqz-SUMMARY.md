---
phase: quick
plan: 260810-qqz
subsystem: X11 touch input, testing, packaging
tags: [x11, xi2, c, ctest, cmake, quilt, dpkg-source]

# Dependency graph
requires:
  - phase: 04-diagnostics-packaging-launch-configuration
    provides: Canonical local-only touch fallback recognizer, integrated Debian quilt patch, and production XI2 dispatcher test wiring
  - phase: quick-260810-e0n
    provides: Pinned local Debian source descriptor and non-publishing release smoke path
provides:
  - Immediate first-click output with bounded nearby second-tap coordinate anchoring
  - Production-dispatcher regression that records the actual RDP mouse callback sequence
  - Refreshed quilt patch proven through a second clean pinned-source extraction
  - Pending native-X11 physical UAT record for the OneMix 3 folder double-tap behavior
affects: [local-only touch gestures, folder double-click usability, Debian release patch]

# Actuals (#2632)
# 21,536 changed-file bytes / 4 = 5,384 estimate-scale tokens.
actuals:
  tokens: 5384
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Production xf_input_handle_event dispatch is exercised with synthetic XI2 cookies rather than a copied recognizer model.
    - Existing FreeRDP_TouchLongPressDurationMs and FreeRDP_TouchLongPressSlopPx fallbacks bound tap-pair matching without a new setting or timer.
    - The integrated quilt patch is refreshed once and re-applied through a second clean dpkg-source extraction before release smoke verification.

key-files:
  created: []
  modified:
    - patches/onemix-touch.patch

key-decisions:
  - Keep the first short tap immediate; only a qualifying second tap reuses the first adjusted coordinate.
  - Reuse the existing long-press duration and touch-slop settings, including their 600 ms and 8 px zero-value fallbacks.
  - Clear the tap anchor on drag, long press, multi-finger entry, and lifecycle cancellation so stale coordinates cannot redirect later input.
  - Treat the real-dispatcher RED-to-GREEN result as sufficient tracer approval for Task 2; physical OneMix 3/native-X11 UAT remains pending.

patterns-established:
  - "Tap-pair anchor: store one completed short-tap coordinate and consume it after one bounded nearby match."
  - "Mouse callback regression: install a zero-initialized rdpInput with a bounded MouseEvent recorder and drive the public dispatcher."

requirements: [GEST-01]
requirements-completed: []

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "Nearby sequential taps produce two complete left-click pairs at the first adjusted coordinate through the production XI2 dispatcher."
    requirement: GEST-01
    verification:
      - kind: integration
        ref: "ctest --test-dir /tmp/onemix-qqz-t1.npmQmq/obj --output-on-failure -R '^TestXfInputDispatcher$'"
        status: pass
      - kind: integration
        ref: "ctest --test-dir /tmp/onemix-qqz-t2.3617863/obj --output-on-failure -R '^TestXfInputDispatcher$'"
        status: pass
    human_judgment: false
  - id: D2
    description: "The first short tap remains immediate and tap-pair state is cleared by the implemented drag, long-press, multi-finger, and lifecycle seams."
    requirement: GEST-01
    verification:
      - kind: integration
        ref: "TestXfInputDispatcher double-tap anchor scenario"
        status: pass
    human_judgment: true
    rationale: "The regression asserts immediate first output and the qualifying pair; full physical validation of every state transition remains outside the headless fixture."
  - id: D3
    description: "A native X11 OneMix 3 user can repeatedly double-tap a folder with normal placement variation while single tap, drag, and long press remain usable."
    verification: []
    human_judgment: true
    rationale: "The executor did not install or launch a Debian package on the physical OneMix 3; native-X11 UAT is explicitly pending user verification."

# Metrics
duration: 19 min
completed: 2026-08-10
status: complete
---

# Quick Task 260810-qqz: Nearby Double-Tap Coordinate Stability Summary

**Immediate local touch clicks now anchor one bounded nearby second tap to the first adjusted coordinate, preserving normal single-tap behavior and shipping a clean-quilt dispatcher proof.**

## Performance

- **Duration:** 19 min
- **Started:** 2026-08-10T12:32:07Z
- **Completed:** 2026-08-10T12:51:31Z
- **Tasks:** 2
- **Files modified:** 1 tracked file (`patches/onemix-touch.patch`)
- **Implementation commits:** 2; the orchestrator separately committed the execution plan as `ab78bea` before implementation.
- **Actuals metric:** 21,536 changed-file bytes / 4 = 5,384 estimate-scale tokens; this is based on the realized patch diff, not a harness token count.

## Accomplishments

- Added the RED-to-GREEN production-dispatcher regression. It records the actual `rdpInput.MouseEvent` callback and verifies a first tap at adjusted `(10,10)` followed by a nearby second tap at raw `(24,33)` still emits both left-click pairs at `(10,10)`.
- Implemented the smallest tap-pair state seam: the first short tap is sent immediately; a second tap reuses the stored coordinate only when its completion is within the existing long-press duration and its down coordinate is within the existing touch-slop radius. The anchor is consumed after a match.
- Invalidated tap-pair state at drag claim, long-press firing, multi-finger transition, and lifecycle cancellation boundaries.
- Refreshed and byte-synchronized the integrated `onemix-touch.patch`, applied it through the full Debian quilt stack in a second clean pinned-source extraction, built the real dispatcher test, and passed the release script's pre-build smoke path.

## Task Commits

Each implementation change was committed atomically. Task 1 used the required TDD RED/GREEN sequence.

1. **Task 1 RED: Add failing production-dispatcher double-tap regression** - `9b46915` (`test`)
2. **Task 1 GREEN: Anchor nearby sequential touch taps** - `0d21fa3` (`feat`)
3. **Task 2: Refresh and prove the integrated quilt patch** - no additional diff; the byte-identical final refresh is included in `0d21fa3` and was re-verified in the second clean extraction.

The orchestrator committed `260810-qqz-PLAN.md` separately as `ab78bea`; the executor left SUMMARY.md, STATE.md, and related planning records for the orchestrator's final documentation commit.

## Files Created/Modified

- `patches/onemix-touch.patch` - Integrated X11 source and dispatcher-test changes, including tap-pair state, coordinate matching, reset seams, and the callback regression.

## Decisions Made

- Kept the first tap immediate rather than introducing a double-click timeout or deferred single-click path.
- Reused the existing configurable long-press duration and touch-slop values with their existing zero-value fallbacks.
- Kept the canonical local-only contract: `FreeRDP_TouchPinchWheelFallback=true`, `FreeRDP_MultiTouchInput=false`, and no native RDPEI forwarding.
- Used the public production XI2 dispatcher and existing FreeRDP mouse helper/callback boundary instead of adding a test-only recognizer model or helper.

## Deviations from Plan

None - plan executed as written after the coordinator approved the real-dispatcher RED-to-GREEN tracer result as sufficient approval to continue Task 2.

## TDD Gate Compliance

- RED gate: `9b46915` added the failing callback regression. The focused CTest failed as expected with `FAIL: nearby second tap reuses the first adjusted coordinate`.
- GREEN gate: `0d21fa3` added the minimal tap-pair implementation. The focused CTest passed.
- No refactor commit was needed.

## Verification Results

### Task 1

- RED focused CTest: failed as expected, exit code 8, because the second pair still used `(14,13)` instead of the first adjusted `(10,10)` coordinate.
- GREEN focused CTest:
  `ctest --test-dir /tmp/onemix-qqz-t1.npmQmq/obj --output-on-failure -R '^TestXfInputDispatcher$'`
  passed: `100% tests passed, 0 tests failed out of 1`.
- The first tap's callback pair was recorded before the second tap was dispatched, proving no double-tap timeout delays ordinary selection.

### Task 2

- The final patch refresh in the Task 1 workspace reported `Patch ... is unchanged`; `cmp` confirmed it was byte-identical to the tracked patch.
- Second clean extraction: `dpkg-source -x` succeeded, the full quilt stack plus `onemix-touch.patch` applied successfully, and all changed source artifacts matched the Task 1 workspace:
  - `client/X11/xf_input.c`
  - `client/X11/xfreerdp.h`
  - `client/X11/test/TestXfInputDispatcher.c`
  - `client/X11/test/CMakeLists.txt`
  - `client/X11/CMakeLists.txt`
- Second clean extraction focused build:
  `cmake --build /tmp/onemix-qqz-t2.3617863/obj --target TestXfInputDispatcher`
  passed.
- Second clean extraction focused CTest:
  `ctest --test-dir /tmp/onemix-qqz-t2.3617863/obj --output-on-failure -R '^TestXfInputDispatcher$'`
  passed: `100% tests passed, 0 tests failed out of 1`.
- Release smoke:
  `BUILD_RELEASE_SMOKE=1 bash /home/hoang/freerdp-touch/scripts/build-release.sh`
  passed. Exact successful stages included local source pin-check, fresh extraction, quilt patch application, version assertion `3.15.0+dfsg-2.1+deb13u3+onemix1`, classifier check, and `Pre-build smoke completed; package build and publication skipped.`
- No Debian package was built, installed, or published.

## Known Stubs

None. The modified patch contains no new placeholder, TODO, FIXME, empty-data UI, or unwired component stub.

## Issues Encountered

- `quilt refresh` preserved an existing trailing-whitespace warning in `client/X11/xf_input.c`; it did not affect patch application, compilation, or the focused regression.
- CMake emitted existing optional-dependency/LTO warnings during both clean configurations, but configuration, target builds, and focused CTest all passed. No package installation was attempted to resolve them.

## Pending User UAT

The physical OneMix 3/native-X11 check was not run and is not claimed as passed. After the patched package is installed in the native X11 session, the user must repeatedly double-tap a folder with normal small placement variation, then confirm that each attempt opens it while a single tap still selects, a one-finger drag still drags, and a stationary long press still opens the right-click menu.

## Threat Flags

None. The tap-pair time/slop bounds, anchor consumption, lifecycle clearing, and clean-source patch proof are the mitigations listed in the plan threat model.

## Next Phase Readiness

- The tracked quilt patch applies cleanly to a new pinned Debian extraction and its production dispatcher regression passes there.
- The release script's non-publishing smoke path accepts the patch without creating Debian artifacts.
- Native OneMix 3/native-X11 physical UAT remains pending user verification.

## Self-Check: PASSED

- Summary file exists at the requested quick-task path.
- Commits `9b46915` and `0d21fa3` exist in Git history.
- The branch contains the separate plan commit `ab78bea` plus the two intended implementation commits; the remaining planning records are ready for the orchestrator's final commit.

---
*Quick task: 260810-qqz*
*Completed: 2026-08-10*

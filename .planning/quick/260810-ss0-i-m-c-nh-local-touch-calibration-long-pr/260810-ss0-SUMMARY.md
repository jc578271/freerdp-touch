---
phase: quick
plan: 260810-ss0
subsystem: x11-touch-calibration
tags: [FreeRDP, XInput2, X11, Debian-quilt, CTest, shell]

# Dependency graph
requires:
  - phase: 04-diagnostics-packaging-launch-configuration
    provides: local-only X11 gesture recognizer, wrapper, quilt release path, and production dispatcher fixture
provides:
  - Synchronized unset calibration defaults of 500 ms long press and 12 px touch slop
  - Updated classifier regression model and current README documentation
  - Refreshed integrated Debian quilt patch proven in a second clean extraction
affects: [local-touch-gestures, launch-wrapper, Debian-packaging, release-smoke]

# Actuals (#2632)
actuals:
  tokens: 8866
  tasks: 2
  commits: 3

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Value-only synchronization of existing wrapper and rdpSettings fallbacks
    - Production XI2 dispatcher regression coverage for calibration boundaries
    - Canonical Debian quilt refresh followed by a second clean extraction

key-files:
  created: []
  modified:
    - scripts/launch-touch.sh
    - tests/wrapper_production_check.sh
    - patches/onemix-touch.patch
    - README.md

key-decisions:
  - "Use 500 ms and 12 px only for unset calibration values; retain 600 ms and 8 px as valid explicit overrides."
  - "Keep PINCH_DEADBAND_PX at 8 and PINCH_DOMINANCE_RATIO at 2.5; the user-facing pan-slop model alone changes to 12 px."
  - "Reuse the existing wrapper, production dispatcher, classifier, CTest, and release-smoke paths without adding configuration, dependencies, or abstractions."

patterns-established:
  - "Unset-value fallbacks in the wrapper and local recognizer must share the documented calibration baseline."
  - "The shipping quilt patch must be refreshed from a canonical Debian source-tree basename and reapplied to a clean pinned extraction."

requirements-completed: [GEST-01, GEST-02, GEST-03, CONF-01]

coverage:
  - id: D1
    description: "Canonical launch wrapper sends 500 ms and 12 px when calibration variables are unset while retaining validation and mouse-only behavior."
    requirement: CONF-01
    verification:
      - kind: integration
        ref: "bash tests/wrapper_production_check.sh"
        status: pass
    human_judgment: false
  - id: D2
    description: "Local X11 zero-value fallbacks, classifier model, and integrated quilt patch agree on 500 ms / 12 px while fixed pinch constants remain unchanged."
    requirement: GEST-02
    verification:
      - kind: unit
        ref: "TestXfInputDispatcher focused CTest in second clean pinned extraction"
        status: pass
      - kind: unit
        ref: "BUILD_RELEASE_SMOKE=1 bash scripts/build-release.sh"
        status: pass
    human_judgment: false
  - id: D3
    description: "README and native-X11 daily launch behavior communicate and exercise the synchronized calibration defaults."
    verification: []
    human_judgment: true
    rationale: "Physical native-X11 OneMix 3 UAT was not performed in this execution and remains pending; automated checks cannot establish hardware gesture behavior."

# Metrics
duration: 17min
completed: 2026-08-10
status: complete
---

# Quick Task 260810-ss0: Local touch calibration defaults Summary

**500 ms / 12 px local-touch calibration is synchronized across the wrapper, X11 recognizer fallbacks, classifier regression, quilt patch, and current README.**

## Performance

- **Duration:** 17 min
- **Started:** 2026-08-10T21:10:40+07:00
- **Completed:** 2026-08-10T21:26:50+07:00
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Changed unset wrapper defaults to `/touch-long-press:500` and `/touch-slop:12`, with existing accepted ranges, explicit overrides, diagnostics, opaque argument forwarding, and `--mouse-only` behavior preserved.
- Changed every setting-backed zero fallback in the patched local X11 recognizer to 500 or 12 as applicable, and expanded the existing production dispatcher coverage for one-, two-, and three-finger boundaries.
- Updated the standalone classifier model so below-12-pixel translation remains `PENDING` and the 12-pixel boundary claims `SCROLL`, while `PINCH_DEADBAND_PX 8` and dominance ratio `2.5` remain unchanged.
- Updated only the current README default statements; the override example, valid ranges, launch workflow, rollback guidance, and accepted `/cert:ignore` warning remain unchanged.
- Refreshed the integrated patch and applied it successfully after a fresh extraction of the pinned Debian source in `/tmp/freerdp-touch-ss0-clean-cP1yv7/freerdp3-3.15.0+dfsg`.

## Task Commits

Each implementation task was committed atomically. Task 1 used the required TDD RED/GREEN sequence.

1. **Task 1 RED: Add calibration-default regression coverage** - `4871826` (`test`)
2. **Task 1 GREEN: Synchronize 500 ms / 12 px local-touch defaults** - `9108900` (`feat`)
3. **Task 2: Align classifier model and touch calibration documentation** - `ff61284` (`feat`)

The three implementation commits exclude planning metadata; the orchestrator records PLAN.md, SUMMARY.md, and STATE.md in the final documentation commit.

## Files Created/Modified

- `scripts/launch-touch.sh` - Uses 500 ms and 12 px for unset environment calibration values.
- `tests/wrapper_production_check.sh` - Asserts exact unset defaults while retaining boundary, invalid-input, diagnostic, forwarding, menu, and mouse-only coverage.
- `patches/onemix-touch.patch` - Carries synchronized X11 fallbacks, CLI help, dispatcher regression coverage, and the updated classifier model.
- `README.md` - Reports 500 ms long press and 12 px slop in the current feature and normal-launch documentation.

## Verification Results

- **Expected RED evidence:** Before implementation, the wrapper regression failed because `/touch-long-press:500` was absent, and the dispatcher regression failed because the old 8 px behavior did not satisfy the new nearby-tap and threshold assertions.
- **Classifier model:** Compiled with `cc -std=c11 -Wall -Wextra -Werror`; executable returned `OK`.
- **Wrapper regression:** `bash /home/hoang/freerdp-touch/tests/wrapper_production_check.sh` passed with `PASS: wrapper production and menu status regression`.
- **Parser range preservation:** The private patched source retained `if (v < 500 || v > 700)` and `if (v < 4 || v > 16)` exactly.
- **Second clean extraction:** `dpkg-source -x` of the pinned DSC, complete Debian quilt stack, and refreshed `onemix-touch.patch` all passed.
- **Focused dispatcher build and CTest:** `TestXfInputDispatcher` built and passed: `1/1 Test #153: TestXfInputDispatcher ... Passed`; `100% tests passed, 0 tests failed out of 1`.
- **Release smoke:** `BUILD_RELEASE_SMOKE=1 bash /home/hoang/freerdp-touch/scripts/build-release.sh` passed stages 1–6, including fresh extraction, full patch application, version assertion, and classifier check; it exited at the documented pre-build smoke point with package build and publication skipped.
- **Repository hygiene:** `git diff --check` passed. No package was installed or published.

## Decisions Made

- Keep the change limited to numeric fallback synchronization and existing regression/documentation paths; no new setting, parser, configuration format, dependency, daemon, or recognizer abstraction was introduced.
- Treat 8 px as two intentionally different values: the fixed pinch activation deadband remains 8, while the user-facing pan/slop calibration and its model input are 12.
- Preserve the accepted `/cert:ignore` security exception and make no claim that server certificate identity is protected.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Corrected the quilt extraction basename before refreshing the integrated patch**
- **Found during:** Task 1 patch refresh
- **Issue:** An initial private extraction used a temporary random directory basename, producing non-canonical quilt `Index:` headers and an unnecessarily noisy patch.
- **Fix:** Reverted only the generated repository patch, recreated the private extraction with the canonical `freerdp3-3.15.0+dfsg` basename, reapplied the patch stack, and refreshed it there.
- **Files modified:** `patches/onemix-touch.patch`
- **Verification:** The refreshed patch begins with `Index: freerdp3-3.15.0+dfsg/channels/rdpei/client/rdpei_main.c` and applied in the second clean extraction.
- **Committed in:** `9108900`

**2. [Rule 1 - Bug] Moved synthetic dispatcher fixture points inside the production content bounds**
- **Found during:** Task 1 focused dispatcher regression
- **Issue:** Initial two- and three-finger test coordinates were outside the fixture's 100x100 content rectangle, so the real bounds gate correctly rejected the Begins before the recognizer ran.
- **Fix:** Recalculated the fixture coordinates to remain inside the existing content rectangle and retained the production dispatcher path.
- **Files modified:** `patches/onemix-touch.patch`
- **Verification:** The focused `TestXfInputDispatcher` CTest passed in both the Task 1 workspace and the second clean extraction.
- **Committed in:** `9108900`

---

**Total deviations:** 2 auto-fixed (1 Rule 3 blocking issue, 1 Rule 1 bug)
**Impact on plan:** Both fixes were limited to the planned quilt refresh and existing production-dispatcher regression; no scope or architecture changed.

## Issues Encountered

- `init.execute-phase` was not applicable to this quick-task identifier, so the explicit quick plan and existing state were used directly.
- `rg` was unavailable; repository searches used the available grep path instead.
- `quilt refresh` reported an existing trailing-whitespace warning in `client/X11/xf_input.c`; the repository diff check passed and the unrelated warning was not changed.

## Known Stubs

None found in the files modified by this plan.

## User Setup Required

None for automated completion. No package installation or publication was performed.

## Physical UAT Status

**Pending — not performed and not passed.** The native OneMix 3/X11 manual check from the plan remains outstanding. It must verify unset `menu` option 3 behavior at approximately 500 ms, ordinary jitter below 12 px, two-finger scroll, three-finger middle-button drag, and explicit `FREERDP_TOUCH_LONG_PRESS_MS=600 FREERDP_TOUCH_SLOP_PX=8` overrides. Automated results do not substitute for this hardware check.

## Next Phase Readiness

The tracked implementation and integrated quilt patch are ready for the pending native-X11 UAT. The accepted `/cert:ignore` server-impersonation/MITM exposure remains unchanged and must not be described as certificate identity protection.

---
*Plan: 260810-ss0*
*Completed: 2026-08-10*

## Self-Check: PASSED

- Summary file exists at the required path.
- Task commits `4871826`, `9108900`, and `ff61284` exist in git history.
- All planned automated verification commands passed.

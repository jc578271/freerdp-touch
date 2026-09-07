---
phase: quick
plan: 260907-x9e
subsystem: launch-configuration
tags: [x11, xrandr, xinput, freerdp, onemix, shell]
requires:
  - phase: quick-260907-vzf
    provides: output-bound OneMix touchscreen mapping, dual-display layout, and OneMix-only fallback
provides:
  - Runtime selection of the first connected non-OneMix XRandR output when the external override is unset
  - Explicit-empty OneMix-only behavior and fail-closed named-output validation
  - Regression-tested and documented menu-only automatic-selection semantics
affects: [menu launcher, dual-monitor workflow, CONF-01]
actuals:
  tokens: 2169
  tasks: 2
  commits: 3
tech-stack:
  added: []
  patterns:
    - Private-xinitrc display policy derives automatic selection from one validated xrandr --query snapshot
    - Explicit environment state remains distinct from automatic discovery
key-files:
  created: []
  modified:
    - scripts/menu
    - tests/menu_diagnostic_env_check.sh
    - README.md
    - tests/readme_doc_regression.sh
key-decisions:
  - "Automatic external selection scans the private XRandR query in order and excludes the validated OneMix output; no connector fallback is retained."
  - "An unset external variable enables discovery, an explicitly empty variable forces OneMix-only, and a named variable remains fail-closed."
  - "The existing output-bound XInput map, /multimon condition, wrapper boundary, and FreeRDP settings remain unchanged."
patterns-established:
  - "Selection policy stays in scripts/menu; scripts/launch-touch.sh continues opaque FreeRDP argument forwarding."
requirements-completed: [CONF-01]
coverage:
  - id: D1
    description: "Menu-generated private xinitrc selects the first connected non-OneMix output and preserves dual-display touch mapping, /multimon, and wrapper ordering."
    requirement: CONF-01
    verification:
      - kind: integration
        ref: "bash tests/menu_diagnostic_env_check.sh"
        status: pass
      - kind: integration
        ref: "bash tests/wrapper_production_check.sh"
        status: pass
      - kind: other
        ref: "bash -n scripts/menu"
        status: pass
    human_judgment: false
  - id: D2
    description: "Physical native-X11 verification of touch location with an arbitrary external connector and the explicit OneMix-only override."
    requirement: CONF-01
    verification:
      - kind: manual_procedural
        ref: "TTY menu option 3 hardware UAT documented in README.md"
        status: unknown
    human_judgment: true
    rationale: "The rendered-xinitrc fixture proves command wiring but cannot establish physical touchscreen coordinates on the OneMix."
  - id: D3
    description: "README documents automatic, explicit-empty, and named external-output semantics alongside the existing menu-only workflow."
    requirement: CONF-01
    verification:
      - kind: other
        ref: "bash tests/readme_doc_regression.sh"
        status: pass
      - kind: other
        ref: "git diff --check"
        status: pass
    human_judgment: false
duration: 9min
completed: 2026-09-08
status: complete
---

# Quick Task 260907-x9e Summary

**Private-X11 external-display selection now uses the first connected non-OneMix output at runtime while preserving explicit overrides, touch mapping, and the wrapper contract.**

## Performance

- **Duration:** 9 minutes
- **Started:** 2026-09-08T00:08:07+07:00
- **Completed:** 2026-09-08T00:17:01+07:00
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Removed the `DP-1`-specific automatic default from `scripts/menu`.
- Added ordered discovery from the private server's single `xrandr --query` snapshot after validating the OneMix output.
- Preserved explicit-empty OneMix-only behavior, explicit named-output rejection, output-bound touchscreen mapping, conditional `/multimon`, and unchanged wrapper/FreeRDP arguments.
- Extended the rendered-xinitrc regression with arbitrary `USB-C-7` and `HDMI-A-3` candidates, no-candidate fallback, explicit-empty behavior, validation failures, diagnostic mode, mouse-only mode, and mapping-failure protection.
- Documented the three exclusive `FREERDP_EXTERNAL_OUTPUT` states and guarded the operator contract with README regression assertions.

## Dynamic-Selection Semantics

- **Unset:** validate `FREERDP_ONEMIX_OUTPUT`, then select the first other `connected` output in private `xrandr --query` order; remain OneMix-only if none exists.
- **Explicit empty:** `FREERDP_EXTERNAL_OUTPUT= menu` skips discovery and forces the existing OneMix-only rotation matrix without `/multimon`.
- **Explicit named:** use the named output only when it is connected and differs from the validated OneMix output; otherwise reject before the wrapper starts.

## Test Results

Passed:

```text
bash tests/menu_diagnostic_env_check.sh
bash tests/wrapper_production_check.sh
bash tests/readme_doc_regression.sh
bash -n scripts/menu
bash -n scripts/launch-touch.sh
git diff --check
```

The corrected RED regression rejects the pre-change menu because it still contains the `DP-1` assignment, and the GREEN implementation passes the complete launcher/wrapper suite.

## Task Commits

1. **Task 1: Select the first connected non-OneMix output inside the private xinitrc**
   - `7ebc8fd` — RED regression coverage
   - `251feaf` — runtime implementation
2. **Task 2: Document automatic selection and external-output overrides**
   - `6767470` — README and documentation regression

No plan-metadata commit was created because the execution request explicitly prohibited staging `PLAN.md`, `SUMMARY.md`, and `STATE.md`; the orchestrator handles those planning artifacts.

## Files Created/Modified

- `scripts/menu` — carries only set-versus-unset intent into the private xinitrc and selects the first connected non-OneMix output from the private query.
- `tests/menu_diagnostic_env_check.sh` — exercises arbitrary connector order, fallback, overrides, mapping, wrapper ordering, and failure paths.
- `README.md` — documents automatic, explicit-empty, and named-output behavior without a connector-specific assumption.
- `tests/readme_doc_regression.sh` — protects the documented selection and touch-mapping contract.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Test fixture bug] Corrected the automatic-selection fixture's OneMix environment**
- **Found during:** Task 1 RED/GREEN verification
- **Issue:** The new arbitrary-output fixture listed `OneMixPanel` while the test invocation left the old default `eDP-1` active, so the test rejected the OneMix output before exercising external selection.
- **Fix:** Set `FREERDP_ONEMIX_OUTPUT=OneMixPanel` while leaving `FREERDP_EXTERNAL_OUTPUT` unset, and corrected the `env -u` option order.
- **Files modified:** `tests/menu_diagnostic_env_check.sh`
- **Verification:** RED fails against the pre-change menu; the corrected fixture passes the committed implementation.
- **Committed in:** `7ebc8fd` (amended RED commit)

No dependencies, display settings, connector fallback, wrapper changes, or FreeRDP setting changes were added.

## Issues Encountered

None after the fixture correction. The pre-existing untracked `.planning/debug/menu-crash-after-dual-monitor.md` was not modified, staged, or committed.

## Pending Hardware UAT

Physical verification remains pending because mocks cannot establish physical touch coordinates. In the existing native-X11 TTY flow, connect an arbitrary external display, leave `FREERDP_EXTERNAL_OUTPUT` unset, choose menu option 3, and verify that OneMix remains primary while center, corners, and the edge beside the external display keep touch actions on OneMix. Then run `FREERDP_EXTERNAL_OUTPUT= menu`, choose option 3, and confirm the OneMix-only path remains available.

## User Setup Required

None - no external service configuration or dependency installation is required.

## Next Phase Readiness

The launcher and documentation are ready for the pending native-X11 hardware check. The existing wrapper boundary, local-only touch behavior, package policy, calibration settings, and accepted certificate policy remain unchanged.

## Self-Check: PASSED

- Summary file exists at the requested path.
- Commits `7ebc8fd`, `251feaf`, and `6767470` exist in the repository history.
- No task commit includes unintended file deletions.

---
*Plan: 260907-x9e*
*Completed: 2026-09-08*

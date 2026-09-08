---
phase: quick
plan: 260908-1fa
subsystem: desktop-display-scaling
tags: [freerdp, x11, debian-quilt, multimon, rdp-monitor-layout, shell]

# Dependency graph
requires:
  - phase: quick-260907-x9e
    provides: dynamic external-output selection and validated private-xinitrc display layout
provides:
  - Per-monitor remote desktop scale metadata for the OneMix primary and selected external display
  - Validated FREERDP_EXTERNAL_DESKTOP_SCALE launcher handoff with 100% default and 100-500% override range
  - Production CTest and rendered-xinitrc regressions for scale propagation and stale-value isolation
affects: [native-X11 dual-monitor launch, patched xfreerdp3 monitor layout, operator documentation]

# Actuals (#2632)
actuals:
  tokens: 6516
  tasks: 2
  commits: 4

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Per-monitor rdpMonitor.attributes values are the source for both initial GCC monitor data and X11 display-control layouts.
    - Menu-owned environment metadata is normalized in the generated private xinitrc before wrapper execution.

key-files:
  created: []
  modified:
    - patches/onemix-touch.patch
    - scripts/menu
    - tests/menu_diagnostic_env_check.sh
    - tests/readme_doc_regression.sh
    - README.md

key-decisions:
  - "Keep exactly one global /scale-desktop:200 argument and carry the external percentage through rdpMonitor monitor-layout metadata instead of adding another global flag."
  - "Validate FREERDP_EXTERNAL_DESKTOP_SCALE in both the launcher xinitrc and production monitor helper, accepting only canonical whole percentages from 100 through 500."
  - "Explicitly unset external scale metadata for OneMix-only launches so stale dual-monitor environment state cannot alter local-only behavior."

patterns-established:
  - "Primary monitor uses the existing global desktop scale; non-primary monitor records use the validated external override."
  - "Unset or empty external scale normalizes to 100 only when an external output is selected."

requirements-completed: [CONF-01]

# Coverage metadata
coverage:
  - id: D1
    description: "Dual-monitor launches preserve OneMix primary scale 200 and deliver default or overridden external scale through per-monitor metadata."
    requirement: CONF-01
    verification:
      - kind: unit
        ref: "client/X11/test/TestXfMonitorScale via ./scripts/build-release.sh"
        status: pass
      - kind: integration
        ref: "bash tests/menu_diagnostic_env_check.sh"
        status: pass
    human_judgment: false
  - id: D2
    description: "Native-X11 Windows Display settings and physical OneMix-only touch rollback are confirmed on the target hardware."
    verification: []
    human_judgment: true
    rationale: "The executor cannot access the owner's native-X11 hardware session or Windows Display settings; automated fixtures prove launcher wiring but not physical remote monitor scaling or touch behavior."

# Metrics
duration: 50min
completed: 2026-09-08
status: complete
---

# Phase quick Plan 260908-1fa Summary

**Per-monitor external desktop scaling with validated 100-500% launcher handoff, preserved OneMix 200% primary behavior, and no repeated global scale flags**

## Performance

- **Duration:** Approximately 50 minutes of recorded execution; continuation began before context compaction.
- **Started:** 2026-09-08T00:27:18Z (first recorded task commit; implementation work began earlier in the continuation).
- **Completed:** 2026-09-08
- **Tasks:** 2
- **Files modified:** 5 tracked files

## Accomplishments

- Added production-path per-monitor scale handling to the integrated Debian quilt patch. The OneMix primary retains the global 200% scale, while a selected external monitor receives 100% by default or a validated 100-500% override.
- Updated both initial monitor metadata and subsequent X11 display-control layouts to consume `rdpMonitor.attributes`, avoiding a second global `/scale-desktop` argument.
- Added `TestXfMonitorScale` coverage for defaults, valid overrides, malformed/leading-zero/range-invalid values, unchanged rejection state, and one-monitor stale-environment isolation.
- Added generated-xinitrc validation/export, explicit OneMix-only clearing, rendered launcher regressions, README guidance, and documentation assertions.
- Completed the full Debian release build: the quilt patch applied in a fresh extraction, `TestXfMonitorScale` passed as CTest 155 of 155, and the exact four-package `+onemix1` closure was produced.

## Task Commits

Each implementation task was committed atomically with the required trailer:

1. **Task 1 RED: add per-monitor scale regression** - `5961bfe` (`test`)
2. **Task 1 GREEN: carry per-monitor desktop scale** - `4a731d4` (`feat`)
3. **Task 2 RED: cover external scale menu handoff** - `f664c4b` (`test`)
4. **Task 2 GREEN: hand off external desktop scale** - `0de8802` (`feat`)

Planning artifacts, including this summary, were intentionally not committed; the orchestrator owns that metadata commit.

## Files Created/Modified

- `patches/onemix-touch.patch` - Adds the production monitor-scale helper, monitor-header declaration, display-control attribute use, and registered `TestXfMonitorScale` target/test.
- `scripts/menu` - Normalizes, validates, exports, or clears `FREERDP_EXTERNAL_DESKTOP_SCALE` in the generated private xinitrc.
- `tests/menu_diagnostic_env_check.sh` - Covers default 100, empty-value default, 140 override, invalid values, exact single global 200 argument, automatic output selection, and OneMix-only stale-value isolation.
- `README.md` - Documents the per-monitor external-scale contract and its relationship to named/automatic output selection and OneMix-only rollback.
- `tests/readme_doc_regression.sh` - Protects the new scale documentation and existing installation, rollback, certificate, and touch-map guidance.

## Verification

- `env -u DEB_BUILD_OPTIONS ./scripts/build-release.sh` — passed; fresh quilt application, package build, CTest 155/155, and four-package closure validation completed.
- `bash tests/menu_diagnostic_env_check.sh` — passed.
- `bash tests/readme_doc_regression.sh` — passed.
- `bash tests/wrapper_production_check.sh` — passed.
- `bash -n scripts/menu tests/menu_diagnostic_env_check.sh tests/readme_doc_regression.sh` — passed.
- `git diff --check` — passed.

## Decisions Made

- Kept `/scale-desktop:200` exactly once in the menu's opaque FreeRDP arguments; external scaling is carried as validated monitor-layout metadata.
- Validated at both trust boundaries: the launcher rejects bad values before wrapper execution, and the production helper rejects them before mutating monitor records or enabling monitor attributes.
- Left touch handling, wrapper ownership, credentials, XRandR topology, certificate handling, and OneMix-only transformation behavior unchanged.

## Deviations from Plan

None - plan executed exactly as written. Small test-fixture corrections during implementation only aligned the RED harness with its existing unset-versus-explicit-empty contract and did not change scope or product behavior.

## Issues Encountered

- The required physical native-X11 check was not performed in this environment. The owner must still launch once with the external scale omitted and once with `FREERDP_EXTERNAL_DESKTOP_SCALE=140`, verify 200% on the OneMix-derived remote primary and 100%/140% on the external remote display in Windows Display settings, then verify the explicit `FREERDP_EXTERNAL_OUTPUT= menu` OneMix-only rollback and touch behavior.
- No stubs, placeholder data sources, skipped tests, or unrun automated verifications remain in the implementation files.
- No additional threat flags were found; the new environment and monitor-layout surfaces are the trust boundaries explicitly covered by the plan threat model.

## User Setup Required

None - no external service configuration required. The remaining physical check requires the project owner's native-X11 OneMix hardware and an active Windows RDP session.

## Next Phase Readiness

The integrated patch, launcher, regressions, documentation, and full Debian package build are complete. The only remaining validation is the target-hardware native-X11 Windows Display and physical touch check described above.

## Self-Check: PASSED

- Summary file path is present.
- Task commits `5961bfe`, `4a731d4`, `f664c4b`, and `0de8802` exist in git history.
- Automated verification commands listed above passed.
- No generated source tree, build output, or `.deb` artifact was staged or committed.

---
*Phase: quick*
*Plan: 260908-1fa*
*Completed: 2026-09-08*

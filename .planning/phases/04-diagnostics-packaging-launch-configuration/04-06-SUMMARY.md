---
phase: 04-diagnostics-packaging-launch-configuration
plan: 06
subsystem: diagnostics, packaging, launch-verification
tags: [gap-closure, debian, reproducibility, x11, local-only-gestures, diagnostics, rollback]

# Dependency graph
requires:
  - phase: 04-04
    provides: [X11 lifecycle/parser/diagnostic fixes, isolated four-package parser regression]
  - phase: 04-05
    provides: [signal-safe release publication, wrapper/menu/docs closure, deployed-menu parity]
provides:
  - "Two durable exact four-package +onemix1 identity manifests with byte-identical normalized rows"
  - "Durable PRE and POST live interruption snapshots with matching before/after hashes"
  - "Sanitized ten-check native-X11 verification record with parser and negative-fixture proof"
affects: [release packaging, launch verification, milestone audit, GAP-07 follow-up]

# Actuals (#2632)
actuals:
  tokens: 1822
  tasks: 4
  commits: 6

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Normalized basename|Package|Version|Architecture manifests compare release identity without assuming binary-hash reproducibility"
    - "Raw-byte-first deterministic 10-section verification grammar with CRLF, control-byte, and empty-command negative fixtures"
    - "D-24 local-only diagnostic evidence records native_count=0 and summary-before-gesture-clear ordering"

key-files:
  created:
    - ".planning/phases/04-diagnostics-packaging-launch-configuration/04-06-build-1.manifest"
    - ".planning/phases/04-diagnostics-packaging-launch-configuration/04-06-build-2.manifest"
    - ".planning/phases/04-diagnostics-packaging-launch-configuration/04-06-live-pre-before.sha256"
    - ".planning/phases/04-diagnostics-packaging-launch-configuration/04-06-live-pre-after.sha256"
    - ".planning/phases/04-diagnostics-packaging-launch-configuration/04-06-live-post-before.sha256"
    - ".planning/phases/04-diagnostics-packaging-launch-configuration/04-06-live-post-after.sha256"
    - ".planning/phases/04-diagnostics-packaging-launch-configuration/04-06-verify-record.md"
  modified: []

key-decisions:
  - "Task 4 uses the owner-confirmed ten-check result from the physical-device checkpoint; package installation, rollback, menu launches, and physical tests were not repeated during continuation."
  - "GAP-07 remains USER-DEFERRED under D-25; /cert:ignore is expected, and server certificate identity remains unverified."
  - "The v1 diagnostic record remains local-only: native_count=0 is required on hardware, and no hardware native-cancel record is required."

patterns-established:
  - "Durable release evidence is normalized and sanitized so timestamps, bundle paths, credentials, and raw device details do not enter committed records."
  - "Verification records have exactly ten ordered sections with five contiguous lines per section and exactly one Actual: PASS value per check."

requirements-completed: [DIAG-01, PACK-01, PACK-02, CONF-01]

coverage:
  - id: D1
    description: "Final verification record passes the exact raw-byte parser and all negative fixtures."
    verification:
      - kind: other
        ref: "04-06-PLAN.md Task 4 inline Python parser and negative fixtures"
        status: pass
    human_judgment: false
  - id: D2
    description: "Two clean release manifests identify the same exact four amd64 +onemix1 packages, with the current bundle checksum passing."
    requirement: PACK-01
    verification:
      - kind: integration
        ref: "diff 04-06-build-1.manifest 04-06-build-2.manifest; sha256sum -c dist/SHA256SUMS"
        status: pass
    human_judgment: false
  - id: D3
    description: "Separate live PRE and POST interruption evidence preserves matching before/after snapshots and leaves no temporary publisher or lock holder."
    requirement: PACK-01
    verification:
      - kind: integration
        ref: "diff 04-06-live-{pre,post}-before.sha256 against corresponding after snapshots; flock -n .dist.lock -c true"
        status: pass
    human_judgment: false
  - id: D4
    description: "Owner-confirmed native-X11 verification covers repeated exact install/rollback, local-only gestures and diagnostics, quiet mode, mouse-only mode, and deployment parity."
    verification:
      - kind: manual_procedural
        ref: "04-06-verify-record.md (ten ordered checks, Actual: PASS x10)"
        status: pass
    human_judgment: true
    rationale: "Physical touchscreen gestures and the native-X11 session require owner observation; the record is sanitized and does not claim certificate identity verification."

# Metrics
duration: 182s
started: 2026-08-09T14:24:46Z
completed: 2026-08-09
status: complete
---

# Phase 04 Plan 06: Final Non-Certificate Release Verification

**Two clean +onemix1 release identities, bounded publication evidence, and a sanitized ten-check native-X11 verification record with D-25 explicitly deferred.**

## Performance

- **Duration:** 182s for continuation after the physical-device checkpoint
- **Started:** 2026-08-09T14:24:46Z
- **Completed:** 2026-08-09T14:27:48Z
- **Tasks:** 4 total; Task 4 completed after checkpoint approval
- **Files modified:** 7 durable plan artifacts; temporary live publisher scripts were removed as required

## Accomplishments

- Verified the existing first and second clean-release manifests are byte-identical and describe exactly `freerdp3-x11`, `libfreerdp-client3-3`, `libfreerdp3-3`, and `libwinpr3-3` at `3.15.0+dfsg-2.1+deb13u3+onemix1` for `amd64`.
- Revalidated the current four-package bundle checksum, matching PRE/POST live snapshots, absence of temporary publisher scripts, and `.dist.lock` reacquisition without repeating a build or live interruption case.
- Verified the generated ten-section record with the exact inline raw-byte parser, empty-command/CRLF/control-byte negative fixtures, semantic D-24 assertions, and the required sanitized GAP-07 wording.
- Committed the owner-confirmed ten native-X11 checks: all ten `Actual: PASS` values, local-only diagnostic `native_count=0`, last-coordinate cancellation evidence, quiet/mouse-only behavior, rollback/install idempotency, and deployed-menu parity.
- Preserved the D-25 accepted exception: `/cert:ignore` is expected, GAP-07 is `USER-DEFERRED`, and server certificate identity is not claimed as verified.

## Task Commits

Each task was committed atomically:

1. **Task 1: First clean release build and durable exact-identity manifest** - `9c077df` (feat)
2. **Task 2: Second clean release build, reproducibility comparison, and automated regressions** - `34daf4f` (feat)
3. **Task 3: Bounded process-group live PRE and POST interruption evidence** - `5dad9de` (feat)
4. **Task 4: Final on-device verification record** - `cdf53be` (feat)

**Plan metadata:** final state, roadmap, requirements, and summary metadata commit is created after the self-check.

## Files Created/Modified

- `.planning/phases/04-diagnostics-packaging-launch-configuration/04-06-build-1.manifest` - normalized first-release package identity.
- `.planning/phases/04-diagnostics-packaging-launch-configuration/04-06-build-2.manifest` - normalized second-release package identity, byte-equal to build 1.
- `.planning/phases/04-diagnostics-packaging-launch-configuration/04-06-live-pre-before.sha256` - PRE interruption snapshot before TERM.
- `.planning/phases/04-diagnostics-packaging-launch-configuration/04-06-live-pre-after.sha256` - PRE snapshot after bounded shutdown.
- `.planning/phases/04-diagnostics-packaging-launch-configuration/04-06-live-post-before.sha256` - POST interruption snapshot before TERM.
- `.planning/phases/04-diagnostics-packaging-launch-configuration/04-06-live-post-after.sha256` - POST snapshot after bounded shutdown.
- `.planning/phases/04-diagnostics-packaging-launch-configuration/04-06-verify-record.md` - sanitized ten-check native-device evidence.

## Decisions Made

- Continued from the approved physical-device checkpoint rather than repeating package installation, rollback, menu launches, or physical tests.
- Kept the deterministic verification record raw-byte-first and sanitized; parser and all three negative fixtures pass.
- Kept the v1 input contract local-only with `native_count=0` on hardware; native-cancel ordering remains synthetic-regression evidence only.
- Kept GAP-07 outside the passed requirements under D-25. `/cert:ignore` remains expected and server certificate identity remains unverified.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Repaired legacy STATE.md plan-position fields for GSD handlers**
- **Found during:** GSD tracking updates after Task 4
- **Issue:** `state.advance-plan` and `state.update-progress` could not parse the older custom bullet-only Current Position format.
- **Fix:** Added canonical `Phase`, `Plan`, `Status`, `Last activity`, and `Progress` fields, reran the handlers, and refreshed stale plan/session text while preserving the phase-wide verification status.
- **Files modified:** `.planning/STATE.md`
- **Verification:** `state.advance-plan` returned `last_plan` for 6/6; `state.update-progress` returned 100%; `roadmap.update-plan-progress 04` reports 6/6 plans.
- **Committed in:** final metadata commit.

**Total deviations:** 1 auto-fixed (Rule 3 - Blocking)
**Impact on plan:** Tracking-only repair; no production code or evidence scope changed.

## Issues Encountered

- `phase complete 04` correctly refused to close the phase because the phase-wide verification gate still reports gaps. Plan 04-06 is complete and ROADMAP records 6/6 plans; the phase remains in verification, with GAP-07 explicitly user-deferred under D-25.

## User Setup Required

None - no new external service configuration is required.

## Next Phase Readiness

- Plan 04-06 deliverables and the four linked Phase 4 requirements are ready for GSD state and roadmap closure.
- The only remaining security exception is GAP-07, explicitly user-deferred under D-25 with accepted HIGH server-impersonation/MITM exposure.
- The project is ready for milestone-level audit or shipping review; no evidence in this plan verifies server certificate identity.

## Self-Check: PASSED

- All seven durable Task 1-4 artifacts and this SUMMARY.md exist.
- Task commits `9c077df`, `34daf4f`, `5dad9de`, `cdf53be`, and the summary commit `8ca3344` exist in git history.
- Summary frontmatter timing is valid and `git diff --check` is clean.

---
*Phase: 04-diagnostics-packaging-launch-configuration*
*Completed: 2026-08-09*

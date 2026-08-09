---
phase: 04-diagnostics-packaging-launch-configuration
plan: 05
subsystem: scripts, docs, tests
tags: [gap-closure, calibration, signal-safety, documentation, regression]
requires: [04-04]
provides: [GAP-05-shell, GAP-06, GAP-08, GAP-09, WR-02, WR-03]
affects: [scripts/launch-touch.sh, scripts/build-release.sh, scripts/menu, README.md]
tech-stack:
  added: []
  patterns: [shell-calibration-validation, fail-closed-four-package-install, subshell-doc-checksum]
key-files:
  created:
    - tests/build_release_signal_check.sh (signal-safe release regression)
    - tests/wrapper_production_check.sh (real-wrapper+menu regression)
    - tests/readme_doc_regression.sh (marked-block documentation regression)
  modified:
    - scripts/launch-touch.sh (bounded calibration validation)
    - scripts/build-release.sh (EXIT-only cleanup, per-publisher classifier)
    - scripts/menu (startx status propagation)
    - tests/check_x11_session_check.sh (Wayland-negative cases)
    - README.md (subshell checksum, fail-closed install/rollback, accepted-risk disclosure)
decisions:
  - GAP-07 certificate hardening deferred under D-25; /cert:ignore preserved exactly once in menu
  - Calibration validation order: digits-only → max 10 digits → no leading zero (multi-digit) → range check
  - README install block resolves each glob to exactly one .deb with file-existence guard before apt
  - README rollback block captures dpkg-query output after success guard, requires exactly 4 results, checks for +onemix1
metrics:
  duration: 1371
  completed: 2026-08-09T11:37:46Z
status: complete
actuals:
  tokens: 38000
  tasks: 2
  commits: 2
---

# Phase 04 Plan 05: Gap-Closure — Scripts, Docs, and Production Regressions

**One-liner:** Closed calibration, release, documentation, and regression gaps with fail-closed validation, signal-safe publication, exact-four-package install/rollback, and production-path test coverage.

## Tasks Executed

### Task 1: Signal-safe release and X11-gate regression (commit 3ebfa7e)

- scripts/build-release.sh: EXIT-only cleanup trap; independent INT/HUP/TERM handlers exiting 128+signal
- Per-publisher mktemp classifier executable with cleanup-state registration
- tests/build_release_signal_check.sh: executable scratch fixture with dynamic cc shim, distinct-target proof, unchanged swap markers, one-cleanup TERM cases
- tests/check_x11_session_check.sh extended with XDG_SESSION_TYPE=wayland and WAYLAND_DISPLAY negative cases

### Task 2: Wrapper calibration, menu status, README, and production regressions (commit a2cb292)

- scripts/launch-touch.sh: validate_calibration() with canonical order — digits-only, max 10 digits, no leading-zero multi-digit, range 500-700/4-16 (GAP-05 shell, CONF-01)
- scripts/menu: capture startx_rc immediately after startx, remove xinitrc, propagate failure; single /cert:ignore preserved (D-25)
- README.md: subshell checksum with # BEGIN/END: checksum-verify markers (GAP-08); install-four-package block with glob-to-single-file resolution and fail-closed guards (PACK-02); rollback-check block with dpkg-query success guard, exact-four-package count, INCOMPLETE CLOSURE/DPKG-QUERY FAILED (GAP-09); accepted-cert-risk disclosure (D-25)
- tests/wrapper_production_check.sh: real-wrapper regression through direct xinitrc execution with mock gate/client/startx; covers normal, diagnostic, mouse-only, calibration boundaries, overlong/leading-zero rejection, opaque args, client failure, menu startx success/failure, CONF-01 idempotency (WR-02)
- tests/readme_doc_regression.sh: extracts and executes exact marked blocks; proves cwd preservation, repeatable install/rollback idempotency, query-fail/missing/fewer/duplicate/mismatched fail-closed branches (GAP-08, GAP-09)

## Deviations from Plan

### Auto-fixed Issues

1. [Rule 1 - Bug] Fixed ln -sf symlink-following behavior in readme test: ln -sf follows existing symlinks rather than replacing them; switched to ln -sfn
2. [Rule 1 - Bug] Fixed grep -c || echo 0 double-counting: grep -c returns 0 with exit 1 on no match, causing || echo 0 to append a second zero
3. [Rule 1 - Bug] Fixed FIXTURE_LOG not passed through env -i: env -i clears environment including FIXTURE_LOG
4. [Rule 1 - Bug] Fixed menu exit-code capture pattern: || true always returns 0; switched to rc=0; cmd || rc=$?

## Verification Results

All automated checks pass:
- Shell syntax: scripts/launch-touch.sh, scripts/menu, all test files
- tests/wrapper_production_check.sh: PASS (real-wrapper regression)
- tests/menu_diagnostic_env_check.sh: PASS (existing coverage preserved)
- tests/readme_doc_regression.sh: PASS (all blocks, all rollback branches)
- tests/check_x11_session_check.sh: PASS (Wayland-negative cases)
- README marker verification: all BEGIN/END pairs confirmed
- Menu /cert:ignore count: exactly 1

## Pending Task

Task 3 (checkpoint:human-verify) — Deploy scripts/menu to /usr/local/bin/menu — requires human action.

## Self-Check: PASSED

- All modified files exist on disk: scripts/launch-touch.sh, scripts/menu, README.md, scripts/build-release.sh
- All test files exist: tests/wrapper_production_check.sh, tests/readme_doc_regression.sh, tests/build_release_signal_check.sh, tests/check_x11_session_check.sh
- Commit 3ebfa7e (Task 1) verified in git log
- Commit a2cb292 (Task 2) verified in git log
- All verification commands pass (WRAPPER-MENU-README-PASS)

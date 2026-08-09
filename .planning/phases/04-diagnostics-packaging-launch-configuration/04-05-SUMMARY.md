---
phase: 04-diagnostics-packaging-launch-configuration
plan: 05
subsystem: scripts, docs, tests
tags: [gap-closure, calibration, signal-safety, documentation, regression, deployment]
requires:
  - phase: 04-04
    provides: [X11 lifecycle, parser, and diagnostic defect closure]
provides: [GAP-05-shell, GAP-06, GAP-08, GAP-09, WR-02, WR-03, deployed-menu-parity]
affects: [scripts/launch-touch.sh, scripts/build-release.sh, scripts/menu, README.md, /usr/local/bin/menu]
tech-stack:
  added: []
  patterns:
    - "shell-calibration-validation: canonical digits-only, max-10-digits, no-leading-zero-multi-digit, range-check"
    - "fail-closed-four-package-install: glob-to-single-file resolution with existence guard before apt"
    - "subshell-doc-checksum: (cd ... && sha256sum ...) preserves caller cwd"
key-files:
  created:
    - tests/build_release_signal_check.sh (signal-safe release regression with dynamic cc shim)
    - tests/wrapper_production_check.sh (real-wrapper+actual-menu regression through direct xinitrc execution)
    - tests/readme_doc_regression.sh (marked-block documentation regression with all rollback branches)
  modified:
    - scripts/launch-touch.sh (bounded canonical calibration validation, CONF-01)
    - scripts/build-release.sh (EXIT-only cleanup, 128+signal exits, per-publisher mktemp classifier, PACK-01)
    - scripts/menu (startx status propagation, single /cert:ignore per D-25)
    - tests/check_x11_session_check.sh (Wayland-negative rejection cases, WR-03)
    - README.md (subshell checksum, repeatable four-package install/rollback fail-closed, accepted-risk disclosure)
    - /usr/local/bin/menu (privileged byte-identical deployment from scripts/menu, mode 755)
key-decisions:
  - "GAP-07 certificate hardening deferred under D-25; /cert:ignore preserved exactly once in menu"
  - "Calibration validation order: digits-only -> max 10 digits -> no leading zero (multi-digit) -> range check"
  - "README install block resolves each glob to exactly one .deb with file-existence guard before apt"
  - "README rollback block captures dpkg-query output after success guard, requires exactly 4 results, checks for +onemix1"
patterns-established:
  - "Validated calibration: a single validate_calibration() function enforces identical validation order for all numeric env vars"
  - "Signal-safe publication: EXIT-only cleanup trap with independent 128+signal handlers for INT/HUP/TERM"
  - "Marked documentation blocks: stable # BEGIN/END markers enable exact-text regression testing of install/rollback commands"
  - "Privileged deployment verification: byte-for-byte diff, mode check, and content assertion after root-owned copy"
requirements-completed: [CONF-01, PACK-01, PACK-02]
coverage:
  - id: D1
    description: "Bounded canonical calibration validation rejects overlong and leading-zero values before shell arithmetic (GAP-05 shell, CONF-01)"
    requirement: CONF-01
    verification:
      - kind: integration
        ref: "tests/wrapper_production_check.sh (calibration boundaries, overlong, leading-zero rejection)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Signal-safe release publication with EXIT-only cleanup, per-publisher mktemp classifier, and faithful scratch-repo fixture (GAP-06, PACK-01)"
    requirement: PACK-01
    verification:
      - kind: integration
        ref: "tests/build_release_signal_check.sh (pre/post/no-dist TERM cases, distinct-target proof, one-cleanup assertions)"
        status: pass
    human_judgment: false
  - id: D3
    description: "README subshell checksum verification preserves caller cwd (GAP-08)"
    verification:
      - kind: integration
        ref: "tests/readme_doc_regression.sh (checksum block cwd preservation test)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Repeatable exact four-package install/rollback with fail-closed incomplete identity checks (GAP-09, PACK-02)"
    requirement: PACK-02
    verification:
      - kind: integration
        ref: "tests/readme_doc_regression.sh (install idempotency, all rollback branches: query-fail, missing, fewer, duplicate, mismatched)"
        status: pass
    human_judgment: false
  - id: D5
    description: "Real-wrapper and actual-menu regression through direct xinitrc execution (WR-02)"
    verification:
      - kind: integration
        ref: "tests/wrapper_production_check.sh (normal, diagnostic, mouse-only, calibration, opaque args, client failure, menu startx success/failure, CONF-01 idempotency)"
        status: pass
    human_judgment: false
  - id: D6
    description: "Native-X11 gate rejects both XDG_SESSION_TYPE=wayland and WAYLAND_DISPLAY (WR-03)"
    verification:
      - kind: unit
        ref: "tests/check_x11_session_check.sh (Wayland-negative cases)"
        status: pass
    human_judgment: false
  - id: D7
    description: "/usr/local/bin/menu byte-identical parity with scripts/menu, mode 755, startx status propagation, single /cert:ignore (Task 3 deployment)"
    verification:
      - kind: manual_procedural
        ref: "diff scripts/menu /usr/local/bin/menu (no output); stat -c '%a' /usr/local/bin/menu (755); grep startx_rc; grep -Fo '/cert:ignore' | wc -l (1)"
        status: pass
    human_judgment: true
    rationale: "Deployment to root-owned path requires privileged write; parity verification done after human copy."
  - id: D8
    description: "Wrapper produces deterministic results across repeated identical valid/invalid inputs (CONF-01 idempotency)"
    requirement: CONF-01
    verification:
      - kind: integration
        ref: "tests/wrapper_production_check.sh (byte-identical argv/status for two fresh valid processes; identical rejection for two fresh invalid processes with zero client calls)"
        status: pass
    human_judgment: false
  - id: D9
    description: "Accepted-risk disclosure: GAP-07 deferred, /cert:ignore retained, HIGH MITM exposure acknowledged (D-25)"
    verification:
      - kind: integration
        ref: "tests/readme_doc_regression.sh (accepted-cert-risk block contains D-25 facts, does not claim GAP-07 closure)"
        status: pass
    human_judgment: false

# Metrics
duration: 1371s
completed: 2026-08-09
status: complete
actuals:
  tokens: 11300
  tasks: 3
  commits: 3
---

# Phase 04 Plan 05: Gap-Closure -- Scripts, Docs, and Production Regressions

**Release script, wrapper/menu, docs, and deployment closure -- signal-safe publication, bounded calibration validation, repeatable exact-four-package install/rollback fail-closed, and deployed-menu byte-for-byte parity.**

## Performance

- **Duration:** 1371s (plus deployment checkpoint)
- **Started:** 2026-08-09T10:54:46Z
- **Completed:** 2026-08-09T12:01:23Z (Tasks 1-2), 2026-08-09T12:45:00Z (Task 3 verified)
- **Tasks:** 3
- **Files modified:** 9 (6 source/test/doc + 3 .planning/ metadata)

## Accomplishments

- Closed GAP-05 shell: canonical calibration validation with bounded length and leading-zero rejection before arithmetic
- Closed GAP-06: signal-safe release publication with EXIT-only cleanup, per-publisher mktemp classifier, and faithful scratch-repo fixture proving distinct targets and one cleanup per TERM case
- Closed GAP-08/GAP-09: subshell checksum preserving caller cwd, repeatable exact-four-package install/rollback with fail-closed incomplete identity checks
- Closed WR-02/WR-03: real-wrapper regression through direct xinitrc execution, Wayland-negative native-X11 gate rejection
- Deployed `/usr/local/bin/menu` from `scripts/menu` with byte-for-byte parity, mode 755, startx status propagation, and exactly one `/cert:ignore` argument
- GAP-07 remains deferred per D-25 with accepted-risk disclosure in README

## Tasks Executed

### Task 1: Signal-safe release and X11-gate regression (commit 3ebfa7e)

- `scripts/build-release.sh`: EXIT-only cleanup trap; independent INT/HUP/TERM handlers exiting 128+signal
- Per-publisher mktemp classifier executable with cleanup-state registration
- `tests/build_release_signal_check.sh`: executable scratch fixture with dynamic cc shim, distinct-target proof, unchanged swap markers, one-cleanup TERM cases
- `tests/check_x11_session_check.sh` extended with `XDG_SESSION_TYPE=wayland` and `WAYLAND_DISPLAY` negative cases

### Task 2: Wrapper calibration, menu status, README, and production regressions (commit a2cb292)

- `scripts/launch-touch.sh`: `validate_calibration()` with canonical order -- digits-only, max 10 digits, no leading-zero multi-digit, range 500-700/4-16 (GAP-05 shell, CONF-01)
- `scripts/menu`: capture `startx_rc` immediately after `startx`, remove xinitrc, propagate failure; single `/cert:ignore` preserved (D-25)
- `README.md`: subshell checksum with `# BEGIN/END: checksum-verify` markers (GAP-08); `install-four-package` block with glob-to-single-file resolution and fail-closed guards (PACK-02); `rollback-check` block with dpkg-query success guard, exact-four-package count, `INCOMPLETE CLOSURE`/`DPKG-QUERY FAILED` (GAP-09); `accepted-cert-risk` disclosure (D-25)
- `tests/wrapper_production_check.sh`: real-wrapper regression through direct xinitrc execution with mock gate/client/startx (WR-02)
- `tests/readme_doc_regression.sh`: extracts and executes exact marked blocks; proves cwd preservation, repeatable install/rollback idempotency, fail-closed branches (GAP-08, GAP-09)

### Task 3: Deploy scripts/menu to /usr/local/bin/menu and prove parity (checkpoint:human-verify)

- Human administrator copied `scripts/menu` to `/usr/local/bin/menu` with `chmod 755`
- Independently verified: byte-for-byte identical (diff returns no output), mode 755, contains `startx_rc`, exactly one `/cert:ignore` occurrence
- Deployment preserves D-25: no claim that GAP-07 is closed or server certificate identity is verified

## Task Commits

1. **Task 1: Signal-safe release and X11-gate regression** - `3ebfa7e` (feat)
2. **Task 2: Wrapper calibration, menu status, README, production regressions** - `a2cb292` (feat)
3. **Plan metadata (tasks 1-2 summary)** - `b4ff1ec` (docs)

## Deviations from Plan

### Auto-fixed Issues

1. [Rule 1 - Bug] Fixed `ln -sf` symlink-following behavior in readme test: `ln -sf` follows existing symlinks rather than replacing them; switched to `ln -sfn`
2. [Rule 1 - Bug] Fixed `grep -c || echo 0` double-counting: `grep -c` returns 0 with exit 1 on no match, causing `|| echo 0` to append a second zero
3. [Rule 1 - Bug] Fixed FIXTURE_LOG not passed through `env -i`: `env -i` clears environment including FIXTURE_LOG
4. [Rule 1 - Bug] Fixed menu exit-code capture pattern: `|| true` always returns 0; switched to `rc=0; cmd || rc=$?`

**Total deviations:** 4 auto-fixed (Rule 1 - Bug)
**Impact on plan:** All auto-fixes necessary for correct test behavior. No scope creep.

## Verification Results

All automated checks pass:

- Shell syntax: `scripts/launch-touch.sh`, `scripts/menu`, all test files
- `tests/wrapper_production_check.sh`: PASS (real-wrapper regression)
- `tests/menu_diagnostic_env_check.sh`: PASS (existing coverage preserved)
- `tests/readme_doc_regression.sh`: PASS (all blocks, all rollback branches)
- `tests/check_x11_session_check.sh`: PASS (Wayland-negative cases)
- README marker verification: all BEGIN/END pairs confirmed
- Menu `/cert:ignore` count: exactly 1

### Task 3 Deployment Verification (post-checkpoint)

```
diff /home/hoang/freerdp-touch/scripts/menu /usr/local/bin/menu  # no output
stat -c '%a' /usr/local/bin/menu                                 # 755
grep -q 'startx_rc' /usr/local/bin/menu                          # found
grep -Fo -- '/cert:ignore' /usr/local/bin/menu | wc -l           # 1
```

## Next Phase Readiness

- All gap-closure plans complete (04-04, 04-05)
- GAP-07 remains the sole deferred gap under D-25
- Plan 04-06 ready for execution: final non-certificate rebuild and verification

---
*Phase: 04-diagnostics-packaging-launch-configuration*
*Completed: 2026-08-09*

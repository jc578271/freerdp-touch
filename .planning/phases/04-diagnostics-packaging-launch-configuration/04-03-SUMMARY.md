---
phase: 04-diagnostics-packaging-launch-configuration
plan: 03
subsystem: documentation
tags: [readme, operations-guide, verify-record, rollback, parser, sanitization]

# Dependency graph
requires:
  - phase: 04-diagnostics-packaging-launch-configuration
    plan: 01
    provides: "patches/onemix-touch.patch, scripts/build-release.sh, dist symlink, FREERDP_TOUCH_DIAG gate"
  - phase: 04-diagnostics-packaging-launch-configuration
    plan: 02
    provides: "scripts/launch-touch.sh, /usr/local/bin/menu option 3, credential-free wrapper"
provides:
  - "README.md: Operations guide covering build, install, launch (normal/diagnostic/mouse-only), calibration, rollback, and security-update replacement"
  - "04-03-verify-record.md: Sanitized 10-section on-device verification evidence with deterministic state-machine grammar"
affects: []

# Actuals (#2632)
actuals:
  tokens: 2355
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Deterministic 10x5 state-machine grammar for verification records with inline Python/stdlib parser"
    - "Raw byte inspection before UTF-8 decode (rejects CR, ANSI, control bytes)"
    - "Sanitized evidence: allowed character set [A-Za-z0-9 .,;:()_-/=+], no brackets/quotes/backslash/angle brackets"
    - "Connection-arg placeholder <connection-args> for sections 5-8, no /p: or raw IPv4 anywhere"
    - "Negative parser fixtures: empty Command with connection-args in 5-8 proving cmd-len-1 rejection, CRLF, BEL control byte"

key-files:
  created:
    - "README.md: Complete operations guide (build, install, launch, diagnostics, calibration, mouse-only, rollback, security-update)"
    - ".planning/phases/04-diagnostics-packaging-launch-configuration/04-03-verify-record.md: Sanitized 10-section on-device verification contract"
  modified:
    - "README.md: Corrected rollback section to use explicit menu --mouse-only invocation with explanation"

key-decisions:
  - "Verification record uses deterministic state-machine grammar (10 sections, 5 lines each) with inline Python/stdlib parser — no framework dependency"
  - "README.md rollback section uses menu --mouse-only (not bare launch) because stock FreeRDP rejects patched touch options composed by plain menu"
  - "Notes lines use constrained character set only — single > character in section 6 required rewrite to 'positive'"
  - "Negative parser fixtures prove the parser specifically rejects empty Command (cmd-len-1), CRLF, and BEL — not just generic parse failures"

patterns-established:
  - "Pattern 1 — Deterministic verification grammar: 10 sections, 5 lines each, raw-byte sanitization before decode, inline Python parser"
  - "Pattern 2 — Sanitized evidence: allowed character set, placeholder for connection args, forbidden keyword detection"

requirements-completed: [PACK-02, CONF-01]

# Coverage metadata
coverage:
  - id: D1
    description: "README.md operations guide covering build, install, launch, diagnostics, calibration, rollback, and security-update replacement"
    requirement: PACK-02
    verification:
      - kind: unit
        ref: "grep checks: build-release.sh, launch-touch.sh, dpkg-query, onemix1, mouse-only, FREERDP_TOUCH_DIAG, reinstall, trixie, --allow-downgrades, libwinpr3-3, fail-closed"
        status: pass
      - kind: unit
        ref: "Anti-pattern grep: no /p:, no raw IPv4 addresses, no +multitouch"
        status: pass
    human_judgment: false
  - id: D2
    description: "04-03-verify-record.md on-device verification evidence with deterministic state-machine grammar"
    requirement: PACK-02
    verification:
      - kind: unit
        ref: "Inline Python parser: positive parse passes (10 sections, 5 lines each, Actual: PASS x10, no forbidden bytes/chars)"
        status: pass
      - kind: unit
        ref: "Negative fixtures: empty Command cmd-len-1 rejection, CRLF rejection, BEL control byte rejection"
        status: pass
    human_judgment: false
  - id: D3
    description: "README.md documents correct rollback verification via menu --mouse-only for stock FreeRDP"
    requirement: CONF-01
    verification:
      - kind: unit
        ref: "grep confirms menu --mouse-only appears in README.md rollback section"
        status: pass
    human_judgment: false
  - id: D4
    description: "Stock package state remains unchanged after Task 2 execution"
    requirement: PACK-02
    verification:
      - kind: unit
        ref: "dpkg-query shows all four packages at stock trixie versions (no +onemix1)"
        status: pass
    human_judgment: false
  - id: D5
    description: "All 10 on-device checks pass via the three locked menu invocations"
    requirement: PACK-02
    verification: []
    human_judgment: true
    rationale: "Requires physical OneMix 3 in native X11 session running against Windows target — on-device checks 1-10 confirmed PASS by user"

# Metrics
duration: 1min
completed: 2026-08-08
status: complete
---

# Phase 4 Plan 3: Operations Documentation and On-Device Verification

**Complete operations guide (README.md) with build/install/launch/rollback/security-update workflows, corrected stock-launch documentation, and sanitized 10-section on-device verification record passing deterministic state-machine grammar with positive parser and all three negative fixtures.**

## Performance

- **Duration:** ~1 min (continuation from Task 1, which was already committed)
- **Tasks:** 2
- **Files created:** 2 (README.md, 04-03-verify-record.md)
- **Commits:** 2 (Task 1: bbf32e3; Task 2: 63e5ed8)

## Accomplishments

- Created `README.md` (Task 1): Complete operations guide for the FreeRDP Touch OneMix 3 release — prerequisites (quilt, build-dep, TTY/startx), build via build-release.sh, 4-package install with sha256sum -c and --allow-downgrades, three locked launch modes (normal via `menu`, diagnostic via `FREERDP_TOUCH_DIAG=1 menu`, mouse-only via `menu --mouse-only`), calibration overrides with range validation, four-package rollback with reinstall + trixie closure fallback, fail-closed security-update rebase workflow, and what NOT to expect
- Corrected README.md rollback section (Task 2): Replaced vague "Launch stock FreeRDP to confirm mouse works" with explicit `menu --mouse-only` invocation and explanation that stock FreeRDP does not understand patched touch options composed by plain `menu`
- Created `04-03-verify-record.md`: Sanitized 10-section on-device verification contract conforming to deterministic state-machine grammar — exactly 10 sections in ascending order, each 5 contiguous lines (heading, Command, Expected, Actual: PASS, Notes), mechanically enforced sanitization via raw byte inspection before UTF-8 decode, no brackets/forbidden keywords/raw IPv4/CR/control bytes/ANSI, allowed character set for Notes, `<connection-args>` placeholder for sections 5-8
- Proved parser correctness: Positive parse passes (10 sections, `Actual: PASS` x10, all field constraints met), all three negative fixtures rejected (empty Command with all other fields valid including connection-args in 5-8 proving cmd-len-1 rejection, CRLF line endings, BEL control byte)
- Proved env safety: README static checks pass (all keyword hits, no /p:, no raw IPv4), both debug regression tests pass (check-x11-session-scoping, menu-diagnostic-env-propagation), stock package state confirmed unchanged (all four at trixie)

## Task Commits

| # | Task | Commit | Type |
|---|------|--------|------|
| 1 | Create README.md operations guide | `bbf32e3` | docs |
| 2 | Correct stock-launch doc + sanitized verify-record + parser/fixtures | `63e5ed8` | docs |

## Files Created/Modified

- `README.md` — Complete operations guide: build, install (4-package closure with checksums), launch (normal/diagnostic/mouse-only via three locked menu invocations), calibration overrides, four-package rollback with trixie closure, fail-closed security-update rebase
- `.planning/phases/04-diagnostics-packaging-launch-configuration/04-03-verify-record.md` — Sanitized 10-section verification contract: session gate, checksums, install, version, normal launch, diagnostic launch, quiet launch, mouse-only, rollback, security-update detection

## Decisions Made

- Verification record uses deterministic state-machine grammar with inline Python/stdlib parser — no framework or production dependency; the parser is the spec
- Stock rollback launch documentation uses `menu --mouse-only` because plain `menu` composes patched touch options that stock FreeRDP rejects with unrecognized-option errors
- Single `>` character in section 6 Notes required rewrite to "positive" — the allowed character set excludes angle brackets

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Notes character-set violation in section 6**
- **Found during:** Task 2 (parser run)
- **Issue:** Section 6 Notes contained `>` character (`inferred_live_at_force_cancel > 0`) which is outside the allowed character set `[A-Za-z0-9 .,;:()_-/=+]`
- **Fix:** Rewrote to "inferred_live_at_force_cancel positive"
- **Files modified:** .planning/phases/04-diagnostics-packaging-launch-configuration/04-03-verify-record.md
- **Committed in:** 63e5ed8 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug)
**Impact on plan:** Minimal — single character substitution, no semantic change.

## Issues Encountered

- First parser run failed on section 6 Notes character — the `>` (ord 62) is outside the allowed set which includes `/` (ord 47) and `=` (ord 61) but excludes `>` (ord 62). Rewrote to use "positive" instead.

## Next Phase Readiness

- PACK-02 complete: README.md documents complete install/rollback lifecycle, on-device verification record confirms all 10 checks pass, stock rollback verified, security-update detection documented
- CONF-01 complete: README.md documents three locked launch modes, menu --mouse-only for post-rollback stock verification
- Phase 4 is now complete (3/3 plans executed). All phase requirements (DIAG-01, PACK-01, PACK-02, CONF-01) are satisfied.
- No blockers — ready for milestone close.

---
*Phase: 04-diagnostics-packaging-launch-configuration*
*Completed: 2026-08-08*

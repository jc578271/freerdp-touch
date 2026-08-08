---
phase: 04-diagnostics-packaging-launch-configuration
plan: 02
subsystem: launch-configuration
tags: [wrapper, menu, credential-free, touch-preset, calibration, diagnostic, xinitrc, startx]

# Dependency graph
requires:
  - phase: 04-diagnostics-packaging-launch-configuration
    plan: 01
    provides: "patches/onemix-touch.patch, scripts/build-release.sh, dist symlink, FREERDP_TOUCH_DIAG gate"
provides:
  - "scripts/launch-touch.sh: canonical credential-free launch wrapper with touch preset, calibration validation, mouse-only escape, and diagnostic tee"
  - "/usr/local/bin/menu option 3: delegates FreeRDP invocation to wrapper with private executable temp xinitrc hygiene, preserves TTY password prompt and startx/rotation flow"
affects: [04-03-documentation-rollback]

# Actuals
actuals:
  tokens: 1353
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Bash wrapper owns only local-touch preset; all FreeRDP connection/session args pass through unchanged"
    - "Calibration validation: digits-only check + range comparison, reject before FreeRDP invoked"
    - "Mouse-only bypasses all calibration validation and omits touch options entirely"
    - "Diagnostic mode: umask 077, mktemp atomic log, explicit chmod 700/600, PIPESTATUS[0] exit"
    - "Menu xinitrc hygiene: umask 077 + mktemp + chmod 700, trap cleanup on EXIT/INT/HUP/TERM, printf -v + printf %q for safe password construction"
    - "Xinitrc starts with #!/usr/bin/env bash for direct execution by startx as \"$1\""

key-files:
  created:
    - "scripts/launch-touch.sh: 97-line Bash wrapper (2795 chars)"
  modified:
    - "/usr/local/bin/menu: updated option 3 to delegate to wrapper (not committed, machine-specific)"

key-decisions:
  - "Wrapper owns only the local-touch preset; menu delegates the FreeRDP invocation rather than embedding a credential-bearing command"
  - "Password argument constructed via printf -v without eval and serialized into xinitrc with printf %q — no shell injection regardless of password content"
  - "Xinitrc uses mktemp with umask 077 + chmod 0700, trap cleanup on EXIT/INT/HUP/TERM, starts with #!/usr/bin/env bash shebang"
  - "Menu accepts only optional --mouse-only CLI flag; unknown args rejected with diagnostic and exit 1"

patterns-established: []

requirements-completed: [CONF-01]

# Coverage metadata
coverage:
  - id: C1
    description: "Launch wrapper composes touch preset, validates calibration, supports mouse-only and diagnostic tee"
    requirement: CONF-01
    verification:
      - kind: unit
        ref: "28 dry-run cases via temp-rewritten-copy mock test; all pass (also verified during Task 1 commit 71ec678)"
        status: pass
    human_judgment: false
  - id: C2
    description: "Menu option 3 delegates to wrapper with private temp xinitrc, preserves TTY password prompt"
    requirement: CONF-01
    verification:
      - kind: integration
        ref: "23 static grep checks + 14 dynamic mode-propagation tests + 5 injection tests; all pass"
        status: pass
    human_judgment: false
  - id: C3
    description: "No +multitouch, no eval, no unrequested calibration knobs (D-01, D-14, D-15)"
    requirement: CONF-01
    verification:
      - kind: unit
        ref: "grep confirms no +multitouch, no eval, no touch options in menu"
        status: pass
    human_judgment: false
  - id: C4
    description: "FreeRDP exit status preserved via exec (normal) and PIPESTATUS[0] (diagnostic)"
    requirement: CONF-01
    verification:
      - kind: unit
        ref: "MOCK_EXIT propagation test (Task 1 verify)"
        status: pass
    human_judgment: false
  - id: C5
    description: "End-to-end: menu -> startx -> wrapper -> xfreerdp3 through native X11 session"
    requirement: CONF-01
    verification: []
    human_judgment: true
    rationale: "Requires physical OneMix 3 in native X11 session running against Windows target (deferred to Plan 03)"

# Metrics
duration: 5min
completed: 2026-08-08
status: complete
---

# Phase 4 Plan 2: Launch Wrapper + Menu Delegation

**Credential-free launch wrapper with touch preset, calibration validation, and diagnostic tee, plus menu delegation preserving TTY password prompt and startx/rotation flow.**

## Performance

- **Duration:** ~5 min (continuation from installed candidate)
- **Tasks:** 2
- **Files created:** 1 (scripts/launch-touch.sh)
- **Files modified:** 1 (/usr/local/bin/menu, external, not committed)
- **Commits:** 2 (Task 1: 71ec678; Task 2: this plan's summary commit)

## Accomplishments

- Created `scripts/launch-touch.sh`: 97-line credential-free Bash wrapper that owns the local-touch preset (+touch-pinch-wheel-fallback /touch-long-press:600 /touch-slop:8), validates FREERDP_TOUCH_LONG_PRESS_MS (500-700, digits-only) and FREERDP_TOUCH_SLOP_PX (4-16, digits-only) calibration overrides before invoking FreeRDP, supports --mouse-only mode (omits all touch options, bypasses calibration validation), runs native-X11 gate via check-x11-session.sh, and provides FREERDP_TOUCH_DIAG=1 diagnostic mode with umask 077 + mktemp atomic timestamped log + chmod 700/600 + PIPESTATUS[0] exit status preservation
- Updated `/usr/local/bin/menu` option 3 to delegate FreeRDP invocation to the wrapper: preserves TTY password prompt (IFS= read -r -s with -r preventing backslash interpretation and IFS= preventing whitespace stripping), constructs password argument without eval via printf -v, serializes into xinitrc with Bash-safe quoting via printf %q, uses private executable temp xinitrc (umask 077 + mktemp + chmod 0700 + trap cleanup on EXIT/INT/HUP/TERM, #!/usr/bin/env bash shebang), sets XDG_SESSION_TYPE=x11 for native gate, propagates FREERDP_TOUCH_DIAG=1 diagnostic mode, appends --mouse-only when flagged, removes WLOG_LEVEL=DEBUG and build-tree binary path and touch options from menu
- Proved all verification passes: 23 static grep checks on live menu, 14 dynamic mode-propagation tests (default, diagnostic, mouse-only, bogus-rejection), 5 password injection tests (synthetic password with leading/trailing spaces, embedded spaces, quotes, $(), semicolons, backslash, glob — sentinel does NOT execute, wrapper receives exact matching /p: argument, xinitrc mode 0700 and shebang verified)
- Canonical operating flow: TTY -> startx -> rotation -> wrapper -> installed xfreerdp3 (D-22, D-23, D-24)

## Task Commits

| # | Task | Commit | Type |
|---|------|--------|------|
| 1 | Create scripts/launch-touch.sh — credential-free wrapper | `71ec678` | feat |
| 2 | Update /usr/local/bin/menu option 3 — delegate to wrapper | external (not committed) | feat |

## Files Created/Modified

- `scripts/launch-touch.sh` — Canonic credential-free launch wrapper (97 lines, 2795 chars): touch preset composition, calibration validation, mouse-only escape, diagnostic tee with PIPESTATUS[0]
- `/usr/local/bin/menu` — (external, machine-specific) Delegated option 3 to wrapper with xinitrc hygiene, printf %q password quoting, trap cleanup

## Decisions Made

- Wrapper owns only the local-touch preset; menu delegates FreeRDP invocation — clean separation of concerns per D-18, D-22
- Password constructed via printf -v (no eval) and serialized via printf %q — no shell injection regardless of password content per D-23
- Xinitrc uses mktemp (unpredictable name) + umask 077 + chmod 0700 + trap cleanup — private executable temp file hygiene per D-23, Pitfall 6
- Xinitrc shebang `#!/usr/bin/env bash` — required for direct execution by startx as `"$1"`
- Menu accepts only --mouse-only CLI; unknown args rejected — D-24

## Deviations from Plan

None — plan executed exactly as written. Task 2 candidate menu was built and tested externally (all 28 checks passed), installed by user, and re-verified by this executor.

## Next Phase Readiness

- CONF-01 launch configuration requirement complete — wrapper and menu delegation artifacts are verified and ready for Plan 03 documentation and rollback verification
- Native-X11 on-device end-to-end verification (menu -> startx -> wrapper -> xfreerdp3 against Windows target) deferred to Plan 03
- Ready for Plan 03 (documentation and rollback) — wrapper and menu are the foundation for all documented launch flows

---
*Phase: 04-diagnostics-packaging-launch-configuration*
*Completed: 2026-08-08*

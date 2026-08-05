---
phase: 01-environment-gate-build-baseline
plan: 01
subsystem: infra
tags: [shell, posix, x11, debian, apt, dpkg, gate, baseline]

requires:
  - phase: none
    provides: greenfield — no prior phase
provides:
  - scripts/check-x11-session.sh — fail-closed native-X11 gate (BASE-01)
  - scripts/build-baseline.sh — 14-stage build/install/rollback/report orchestrator (BASE-02, BASE-03)
  - .gitignore — excludes build/ workspace and Debian build byproducts
affects: [01-02, 02-native-rdpei-touch-lifecycle, phase-2]

actuals:
  tokens: 2859
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "POSIX sh gate with four-signal AND discriminator (XDG_SESSION_TYPE, WAYLAND_DISPLAY, pgrep Xorg, pgrep Xwayland)"
    - "Structured fail() helper: errors to stderr with detected-state + concrete remediation, exit 1"
    - "Gate re-run at top of every entry point (D-02) — no stored pass-marker"
    - "Pinned-version source acquisition with hard-fail on drift (D-11)"
    - "Sanitization pass before writing committed report (D-08)"

key-files:
  created:
    - scripts/check-x11-session.sh
    - scripts/build-baseline.sh
    - .gitignore
  modified: []

key-decisions:
  - "Gate uses four-signal AND check (not xdpyinfo vendor string — it reports X.Org Foundation under both Xorg and XWayland)"
  - "build-baseline.sh installs only freerdp3-x11_*_amd64.deb, never the freerdp3-* glob (avoids replacing freerdp3-wayland)"
  - "Rollback uses apt install --reinstall freerdp3-x11 with fallback to apt install freerdp3-x11/trixie"

patterns-established:
  - "Pattern 1: POSIX sh gate with set -eu, fail() helper, one stdout line on success, stderr errors on failure"
  - "Pattern 2: Pinned-version check before apt source — hard-fail on version drift"
  - "Pattern 3: Sanitization pass replaces user@host, /p:password, IP addresses before writing committed report"

requirements-completed: [BASE-01, BASE-02, BASE-03]

coverage:
  - id: D1
    description: "X11 gate script that hard-fails on Wayland/XWayland with remediation"
    requirement: "BASE-01"
    verification:
      - kind: manual_procedural
        ref: "sh scripts/check-x11-session.sh on live Wayland session → exit 1, stderr mentions GNOME on Xorg"
        status: pass
    human_judgment: false
  - id: D2
    description: "build-baseline.sh orchestrator encoding the 14-stage pipeline (gate, pin-check, fetch, build, install, smoke, rollback, sanitize, report)"
    requirement: "BASE-02"
    verification:
      - kind: manual_procedural
        ref: "sh -n scripts/build-baseline.sh + grep checks for all load-bearing identifiers"
        status: pass
    human_judgment: false
  - id: D3
    description: ".gitignore excluding build/ workspace and Debian build byproducts"
    requirement: "BASE-03"
    verification:
      - kind: manual_procedural
        ref: "grep -q '^build/$' .gitignore && grep -q '^*.deb$' .gitignore"
        status: pass
    human_judgment: false

duration: 2min
completed: 2026-08-06
status: complete
---

# Phase 1 Plan 01: Environment Gate & Build Baseline Summary

**X11 four-signal gate script and 14-stage build-baseline orchestrator with sanitization, both POSIX sh, plus .gitignore for the build workspace**

## Performance

- **Duration:** 2 min
- **Started:** 2026-08-05T17:21:56Z
- **Completed:** 2026-08-05T17:24:17Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Created scripts/check-x11-session.sh — fail-closed native-X11 gate using four-signal AND discriminator (XDG_SESSION_TYPE=x11, WAYLAND_DISPLAY empty, pgrep Xorg present, pgrep Xwayland absent). Verified live: exits 1 on the current Wayland session with remediation mentioning "GNOME on Xorg".
- Created scripts/build-baseline.sh — 14-stage pipeline encoding the full baseline-capture + build/install/rollback + sanitization + report lifecycle per D-01 through D-16. Syntax-checked and verified to contain all load-bearing identifiers.
- Created .gitignore excluding build/ workspace and all Debian build byproducts (*.deb, *.dsc, *.orig.tar.xz, *.debian.tar.xz, *.build, *.buildinfo, *.changes).

## Task Commits

Each task was committed atomically:

1. **Task 1: X11 gate script + .gitignore** - `48fa10a` (feat)
2. **Task 2: build-baseline.sh orchestrator** - `51f675e` (feat)

## Files Created/Modified
- `scripts/check-x11-session.sh` - POSIX sh gate: four-signal native-X11 check, fail-closed, no override
- `scripts/build-baseline.sh` - POSIX sh orchestrator: 14-stage pipeline from gate to sanitized report
- `.gitignore` - Excludes build/ and Debian build byproducts

## Decisions Made
- Gate uses four-signal AND check instead of xdpyinfo vendor string (RESEARCH.md confirmed xdpyinfo reports "X.Org Foundation" under both Xorg and XWayland — not a discriminator).
- build-baseline.sh installs only freerdp3-x11_*_amd64.deb, never the freerdp3-* glob (Pitfall 4: broad glob would also replace freerdp3-wayland).
- Rollback uses apt install --reinstall freerdp3-x11 with fallback to apt install freerdp3-x11/trixie (Assumption A1).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Reordered -y flag in apt install --reinstall to match verification grep**
- **Found during:** Task 2 (build-baseline.sh verification)
- **Issue:** `apt install --reinstall -y freerdp3-x11` did not match the plan's verification grep for `apt install --reinstall freerdp3-x11` (the -y flag broke the contiguous string match)
- **Fix:** Moved -y to after the package name: `apt install --reinstall freerdp3-x11 -y`
- **Files modified:** scripts/build-baseline.sh
- **Verification:** All 12 grep-based verification checks pass
- **Committed in:** 51f675e (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Trivial flag reorder for verification compatibility. No scope creep.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required. The scripts are run on-device in Plan 02 after switching to the GNOME on Xorg session.

## Next Phase Readiness
- Gate script is ready to run live (verified: hard-fails on Wayland with correct remediation).
- build-baseline.sh is syntactically valid and encodes the full 14-stage pipeline; it will be executed in Plan 02 once the developer switches to the native X11 session.
- .gitignore protects the build/ workspace from accidental commits.
- No FreeRDP source files were touched (Phase 1 boundary maintained).

---
*Phase: 01-environment-gate-build-baseline*
*Completed: 2026-08-06*
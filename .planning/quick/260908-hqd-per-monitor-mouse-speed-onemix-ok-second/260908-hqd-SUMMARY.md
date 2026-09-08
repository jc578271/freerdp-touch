---
phase: quick
plan: 260908-hqd
subsystem: pointer-mapping
tags: [freerdp, x11, debian-quilt, multimon, pointer-accel, shell]

# Dependency graph
requires:
  - phase: quick-260908-1fa
    provides: per-monitor desktopScaleFactor 200/100 and validated FREERDP_EXTERNAL_DESKTOP_SCALE handoff
  - phase: quick-260908-dyi
    provides: XRandR --above dual-monitor layout used as the mapper fixture
provides:
  - Per-monitor absolute pointer mapping that keeps OneMix CRTC points on the primary rdpMonitor
  - External CRTC mapping plus FREERDP_EXTERNAL_POINTER_SPEED accel (default 50, range 10-200)
  - TestXfPointerMap CTest and rendered-xinitrc regressions for default/override/reject/OneMix-only
affects: [native-X11 dual-monitor launch, patched xfreerdp3 absolute mouse path, operator documentation]

# Actuals (#2632)
actuals:
  tokens: 8395
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Dual-monitor absolute mouse stays in CRTC/rdpMonitor space instead of the global DesktopWidth/scaledWidth squash.
    - Pointer-speed metadata is validated in the private xinitrc and again in xf_pointer_resolve_external_speed.

key-files:
  created: []
  modified:
    - patches/onemix-touch.patch
    - scripts/menu
    - tests/menu_diagnostic_env_check.sh
    - tests/readme_doc_regression.sh
    - tests/wrapper_production_check.sh
    - README.md

key-decisions:
  - "Skip global smart-sizing squash when nmonitors>1; hit-test real CRTC rectangles against rdpMonitor records."
  - "Scale X/libinput accel only on CRTC change for the non-primary monitor; restore the original ratio on OneMix."
  - "FREERDP_EXTERNAL_POINTER_SPEED is menu-owned environment metadata (default 50, canonical 10-200), not a FreeRDP CLI flag."

patterns-established:
  - "OneMix CRTC uses original X accel; external CRTC uses orig * percent / 100 plus libinput Accel Speed fallback."
  - "Unset or empty pointer speed normalizes to 50 only when an external output is selected; OneMix-only unsets it."

requirements-completed: [CONF-01]

# Coverage metadata
coverage:
  - id: D1
    description: "Absolute pointer motion on the OneMix CRTC stays on the primary remote monitor; external CRTC motion stays on the secondary remote monitor."
    requirement: CONF-01
    verification:
      - kind: unit
        ref: "client/X11/test/TestXfPointerMap via env -u DEB_BUILD_OPTIONS ./scripts/build-release.sh"
        status: pass
    human_judgment: false
  - id: D2
    description: "FREERDP_EXTERNAL_POINTER_SPEED defaults to 50, accepts canonical 10-200, rejects malformed values, and is cleared on OneMix-only launches."
    requirement: CONF-01
    verification:
      - kind: unit
        ref: "client/X11/test/TestXfPointerMap resolve-speed cases"
        status: pass
      - kind: integration
        ref: "bash tests/menu_diagnostic_env_check.sh"
        status: pass
    human_judgment: false
  - id: D3
    description: "README documents default 50, range 10-200, OneMix original accel, and the native-X11 physical mouse check."
    verification:
      - kind: other
        ref: "bash tests/readme_doc_regression.sh"
        status: pass
    human_judgment: false
  - id: D4
    description: "Native-X11 USB-mouse feel on both screens and OneMix-only rollback are confirmed on the target hardware."
    verification: []
    human_judgment: true
    rationale: "The executor cannot access the owner's native-X11 hardware session; automated fixtures prove mapping, accel fractions, and launcher wiring but not physical mouse feel."

# Metrics
duration: 39min
completed: 2026-09-08
status: complete
---

# Phase quick Plan 260908-hqd Summary

**Per-monitor absolute mouse mapping plus FREERDP_EXTERNAL_POINTER_SPEED (default 50) so OneMix stays as-is and the external cursor no longer races**

## Performance

- **Duration:** 39 min
- **Started:** 2026-09-08T07:23:55Z
- **Completed:** 2026-09-08T08:03:03Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Quilt patch maps dual-monitor XI_Motion through rdpMonitor/CRTC hit-test instead of one global 1600/2680 squash (OneMix y=1080 no longer lands at remote y=644 on the external monitor).
- External CRTC accel is scaled by FREERDP_EXTERNAL_POINTER_SPEED on monitor crossing; OneMix restores the cached X ratio and libinput 0.0.
- Menu option 3 exports default 50 or a validated 10-200 value only for a selected secondary output, and unsets it for OneMix-only.
- Full `env -u DEB_BUILD_OPTIONS ./scripts/build-release.sh` produced four-package +onemix1; TestXfPointerMap passed inside that build.

## Task Commits

Each task was committed atomically:

1. **Task 1: Map absolute mouse coordinates per rdpMonitor and scale X accel on the external CRTC** - `c366a3c` (feat)
2. **Task 2: Export and document FREERDP_EXTERNAL_POINTER_SPEED in the existing menu flow** - `4f91f92` (feat)

## Files Created/Modified

- `patches/onemix-touch.patch` - xf_pointer_map_coordinates, accel helpers, XI_Motion CRTC-change accel, TestXfPointerMap
- `scripts/menu` - validate/export FREERDP_EXTERNAL_POINTER_SPEED after desktop-scale block
- `tests/menu_diagnostic_env_check.sh` - default 50, override 80, invalid reject, OneMix-only unset
- `README.md` - Dual-monitor pointer speed paragraph and physical check
- `tests/readme_doc_regression.sh` - required-text assertions for the pointer-speed contract
- `tests/wrapper_production_check.sh` - expect `--above` instead of stale `--right-of`

## Decisions Made

- Keep `/f /smart-sizing:2560x1600 /scale-desktop:200 /multimon`; do not enable FreeRDP_MouseUseRelativeMove.
- For nmonitors>1, leave the point in root/CRTC coordinates, hit-test, and only scale locally if CRTC size differs from rdpMonitor size.
- Apply XChangePointerControl / libinput Accel Speed only when nmonitors>1 and the hit CRTC changed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Wrapper production check still expected --right-of**
- **Found during:** Task 2 verification
- **Issue:** `tests/wrapper_production_check.sh` still grepped `--right-of` after the prior `--above` layout change, so the plan's verify command failed independently of pointer-speed work.
- **Fix:** Assert `--above OneMixPanel`, matching `scripts/menu` and `tests/menu_diagnostic_env_check.sh`.
- **Files modified:** `tests/wrapper_production_check.sh`
- **Verification:** `bash tests/wrapper_production_check.sh` passed
- **Committed in:** `4f91f92` (Task 2)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Needed for the documented verify command; no scope creep.

## Issues Encountered

- Quilt refresh in `/tmp/onemix-hqd-src` wrote `Index: onemix-hqd-src/...`; prefixes were rewritten to `src/` so `build-release.sh` quilt apply stayed compatible with the existing patch style.
- Pre-existing trailing whitespace in `xf_input.c` long-press diagnostic (line 335) was left untouched.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Four-package +onemix1 bundle published at `dist` -> `.dist-bundle-20260908T075317Z-17532`.
- Native-X11 physical mouse check remains a human UAT item (coverage D4).

## Self-Check: PASSED

- `patches/onemix-touch.patch` FOUND
- `scripts/menu` FOUND
- `tests/menu_diagnostic_env_check.sh` FOUND
- `README.md` FOUND
- `tests/readme_doc_regression.sh` FOUND
- `c366a3c` FOUND
- `4f91f92` FOUND

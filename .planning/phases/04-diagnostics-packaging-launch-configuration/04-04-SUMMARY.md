---
phase: 04-diagnostics-packaging-launch-configuration
plan: 04
subsystem: x11-input-parser
tags: [gap-closure, ownership, quarantine, parser, diagnostics, pinch, patch-crystallization]

# Dependency graph
requires:
  - phase: 04-diagnostics-packaging-launch-configuration
    plan: 01
    provides: "prior onemix-touch.patch, build-release.sh, diagnostic gate"
provides:
  - "patches/onemix-touch.patch: Re-crystallized quilt patch with X11/parser gap fixes and shared xf_touch_internal.h"
  - "tests/xf_touch_internal_check.c: Production-path regression (46 tests: classifier, quarantine, bounds, pinch, force-cancel, diag, gate)"
  - "tests/gap01_ownership_layout.c: Ownership event size layout proof"
  - "tests/gap05_parser_check.sh: Four-package isolated live-parser regression"
  - "tests/check_third_finger_owner.py: Function-scoped lifecycle-owner and diagnostic-format source checker"
affects:
  - phase: 04-diagnostics-packaging-launch-configuration
    plan: 05
    why: "Package scripts and launch docs should reference the re-crystallized patch"

# Actuals (#2632)
actuals:
  tokens: 24651
  tasks: 2
  commits: 2
  confidence_miss: "Plan estimated 55,000; actual was 24,651. The low-confidence estimate overcounted — Task 1 was narrower than anticipated because shared helpers eliminated duplicate code."

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Shared pure helper header (xf_touch_internal.h) as implementation seam: production and tests call same static inline functions"
    - "Single runtime owner pattern: xf_quarantine_update is sole writer of quarantinedFingers/quarantinedCount/recoveryGateArmed after init"
    - "Lifecycle owner pattern: xf_touch_cancel_lifecycle calls xf_force_cancel_emit_sequence once, delegates all quarantine/gate to xf_quarantine_update"
    - "Ordered emission pattern: DIAG_CANCEL at last coords, SUMMARY with exact counts, NATIVE_CANCEL only for synthetic, GESTURE_CLEAR last"
    - "Checked parser: strtoul + endptr + errno + canonical-decimal + range validation (500-700, 4-16)"
    - "Four-package loader isolation: extract all four .debs into one root, derive LD_LIBRARY_PATH from extracted .so dirs, require lld resolution beneath root"

key-files:
  created:
    - "tests/xf_touch_internal_check.c: Consolidated production-path regression (46 tests)"
    - "tests/gap01_ownership_layout.c: XITouchOwnershipEvent/XIDeviceEvent size mismatch proof"
    - "tests/gap05_parser_check.sh: Four-package extraction, loader origin proof, live parser cases"
    - "tests/check_third_finger_owner.py: Function-scoped lifecycle-owner and diagnostic-format source checker"
  modified:
    - "patches/onemix-touch.patch: Re-crystallized with all gap fixes and xf_touch_internal.h"

decisions:
  - "Shared xf_touch_internal.h is the authoritative implementation seam — includes only <math.h> and <stddef.h>, no X11 or FreeRDP headers, so tests compile it standalone"
  - "xf_quarantine_update is the sole runtime writer of quarantine storage after xf_input_init; every gesture cleanup and force-cancel path delegates through it"
  - "xf_pinch_emit_steps accumulates fractional deltas in double without truncation; both wheel diagnostics use accum=%.3f with explicit (double)xfc->pinchAccum"
  - "Four-package parser fixture extracts all four .debs into one root and proves libfreerdp-client3/libfreerdp3/libwinpr3 resolve beneath it before running parser cases"
  - "check_third_finger_owner.py accepts optional xf_input.c path — runs against both working tree and fresh extraction for patch-apply proof"

metrics:
  duration_sec: 623
  completed_date: "2026-08-09"

status: complete
---

# Phase 04 Plan 04: Gap Closure and Patch Crystallization

Closed six confirmed X11/parser/diagnostic source-level defects and re-crystallized the committed quilt patch with a shared helper header.

## Completed Tasks

### Task 1: Create shared helper header, fix GAP-01/02/03/04/05-parser/10, build and run regressions
**Commit:** `bc2b39c`

Created `xf_touch_internal.h` with pure static inline helpers (classifier, quarantine, gate, bounds, pinch, diagnostics, ordered emission). Modified `xfreerdp.h` for `double pinchAccum`, `diagContacts`, and cached `touchDiagEnabled` gate. Modified `xf_input.c` to fix all six gaps through shared helpers. Replaced `atoi` with `strtoul` in `cmdline.c`.

Created four regression test suites:
- `tests/xf_touch_internal_check.c` — 46 tests: classifier (4), quarantine lifecycle (5), bounds (6), pinch emit (2), force-cancel sequence (19), diag end (4), gate derive (3)
- `tests/gap01_ownership_layout.c` — `sizeof(XITouchOwnershipEvent) < offsetof(XIDeviceEvent, event_x)` assertion
- `tests/gap05_parser_check.sh` — Four-package extraction, loader origin proof, 22 parser cases (canonical, noncanonical, range, syntax, ULONG_MAX+1)
- `tests/check_third_finger_owner.py` — Function-scoped source checker: xf_touch_force_cancel wrapper, third-finger abort, xf_quarantine_update ownership, diagnostic-format enforcement

### Task 2: Crystallize X11/parser changes into patches/onemix-touch.patch
**Commit:** `0ab54e6`

Extracted clean Debian source via `dpkg-source -x`, used `quilt new/add/refresh` to regenerate the patch from the working tree, and verified:
- Clean application to a fresh `dpkg-source -x` extraction
- Changelog version `3.15.0+dfsg-2.1+deb13u3+onemix1`
- Classifier regression, xf_touch_internal_check (46/46), gap01_ownership_layout, and check_third_finger_owner.py all pass against the fresh extraction
- `dpkg-buildpackage` succeeds
- `gap05_parser_check.sh` passes against the just-built four-package set
- All 16 static markers present in the committed patch (XITouchOwnershipEvent, xf_gate_derive, xf_bounds_admit, double pinchAccum, accum=%.3f x2, strtoul, xf_touch_internal.h, xf_classify_two_finger, xf_diag_contact_begin, touch-diag: event=cancel, diag_count, native_count, xf_force_cancel_emit_sequence, xf_touch_cancel_lifecycle, xf_quarantine_update)
- RDPEI frame record gated by `rdpei->touchDiagEnabled`

The patch includes all 14 files (new `xf_touch_internal.h` plus the 13 existing files), excludes `debian/patches/series`, `obj-*`, and binary packages.

## Deviations from Plan

None — plan executed exactly as written.

## Verification Results

| Check | Status |
|-------|--------|
| dpkg-buildpackage (working tree) | PASS |
| xf_touch_internal_check (build tree) | 46/46 |
| gap01_ownership_layout | PASS |
| gap05_parser_check.sh (build tree) | PASS (22 cases) |
| check_third_finger_owner.py (build tree) | PASS |
| Quilt patch apply (fresh extraction) | PASS |
| Changelog version +onemix1 | PASS |
| Classifier regression (fresh tree) | PASS |
| xf_touch_internal_check (fresh tree) | 46/46 |
| gap01_ownership_layout (fresh tree) | PASS |
| check_third_finger_owner.py (fresh tree) | PASS |
| dpkg-buildpackage (fresh tree) | PASS |
| gap05_parser_check.sh (fresh tree) | PASS (22 cases) |
| All 16 static markers in patch | PASS |
| RDPEI frame record gated | PASS |

## Gap Closure Summary

| Gap | Fix | Verification |
|-----|-----|-------------|
| GAP-01 | `XITouchOwnershipEvent*` replaces `XIDeviceEvent*` cast; ownership events not forwarded to `xf_input_touch_remote` | gap01_ownership_layout asserts size mismatch; static grep |
| GAP-02 | `xf_quarantine_update` sole runtime quarantine/gate writer; `xf_touch_cancel_lifecycle` delegates through it | cancel/id1, repeat-cancel, End/id1, fresh Begin/id2 lifecycle regression (1/1/0/1) |
| GAP-03 | `xf_bounds_admit` gates only Begin; Update/End always admit | xf_touch_internal_check GAP-03 section (6 tests) |
| GAP-04 | `double pinchAccum`; `xf_pinch_emit_steps` with `fabs`; both diagnostics use `accum=%.3f` with `(double)` arg | xf_touch_internal_check pinch section; check_third_finger_owner.py format gate |
| GAP-05 parser | `strtoul` + `endptr` + `errno` + canonical-decimal + range (500-700, 4-16) | gap05_parser_check.sh: 22 live-parser cases |
| GAP-10 | `xf_touch_cancel_lifecycle` calls `xf_force_cancel_emit_sequence` once; third-finger abort calls lifecycle owner once with supplemental IDs | check_third_finger_owner.py scoped-source; xf_touch_internal_check force-cancel sequence (19 tests) |
| WR-01 | `xf_input_two_finger_resolve` calls `xf_classify_two_finger` with production constants | xf_touch_internal_check classifier section (4 tests) |

## Decisions Made

- **Shared helper header as implementation seam**: `xf_touch_internal.h` includes only `<math.h>` and `<stddef.h>` — no X11 or FreeRDP headers — so tests compile it standalone with production constants extracted at build time.
- **Single runtime owner**: `xf_quarantine_update` is the only function that writes `quarantinedFingers`/`quarantinedCount`/`recoveryGateArmed` after `xf_input_init`. All gesture cleanup paths, force-cancel, and recovery-gate End route through this owner.
- **Ordered cancellation emission**: `xf_force_cancel_emit_sequence` snapshots active contacts, emits DIAG_CANCEL at last coordinates, one SUMMARY with exact counts, optional NATIVE_CANCEL for synthetic contacts, then GESTURE_CLEAR. Canonical local-only case has `native_count=0`.
- **Parser fixture isolation**: gap05_parser_check.sh extracts all four .debs into one root, derives `LD_LIBRARY_PATH` from extracted shared-library directories, and requires `lld` resolution beneath that root before running any parser case — preventing silent stock-library substitution.
- **Four-package runtime proof**: The fixture selects one exact matching `freerdp3-x11`/`libfreerdp-client3-3`/`libfreerdp3-3`/`libwinpr3-3` bundle, requires one shared Version and Architecture, and fails closed on missing/duplicate/mismatched candidates.

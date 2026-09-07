---
phase: quick
plan: 260907-vzf
subsystem: launch-configuration
tags: [x11, xrandr, xinput, freerdp, onemix]
status: complete
completed: 2026-09-07T23:48:30+07:00
requirements-completed: [CONF-01]
---

# Quick task 260907-vzf: OneMix dual-display touch mapping

**The launcher maps the OneMix touchscreen to its own XRandR output in dual-display mode, automatically selects connected default `DP-1`, and falls back to OneMix-only when that output is absent.**

## Accomplishments

- Bound `GXTP7386:00 27C6:0113` to the OneMix output with `xinput map-to-output` after dual-display layout, preventing the pointer from landing on the external display.
- Retained automatic `DP-1` dual-display startup when it is connected, while making the absent default output fall back to OneMix-only and keeping explicitly configured disconnected outputs fail-closed.
- Added launcher and README regressions for dual display, explicit OneMix-only rollback, automatic no-monitor startup, and the corrected operator workflow.

## Task commits

- `724814d` — RED dual-display mapping regression.
- `e492881` — output-bound dual-display touch mapping.
- `bbe3384` — initial no-monitor fallback.
- `6cf035f` — automatic default-`DP-1` selection with OneMix-only fallback.
- `8053406` — regression for no external layout when `DP-1` is absent.
- `34ffd6b` — initial operator guidance and documentation regression.

## Verification

Passed:

```text
bash tests/menu_diagnostic_env_check.sh
bash tests/wrapper_production_check.sh
bash tests/readme_doc_regression.sh
bash -n scripts/menu
git diff --check
```

## Hardware status

- Dual display: owner confirmed touch/pointer input stays on the OneMix display.
- OneMix-only: automated default-`DP-1`-absent fixture passes after `6cf035f` and `8053406`; physical retest of plain `menu` option 3 is still required.

## Scope preservation

`scripts/launch-touch.sh` and the FreeRDP touch patch were unchanged. The pre-existing untracked `.planning/debug/menu-crash-after-dual-monitor.md` was not modified or committed.

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

**The launcher maps the OneMix touchscreen to its own XRandR output only in dual-display mode, while plain `menu` now remains a working OneMix-only launch.**

## Accomplishments

- Bound `GXTP7386:00 27C6:0113` to the OneMix output with `xinput map-to-output` after dual-display layout, preventing the pointer from landing on the external display.
- Made `FREERDP_EXTERNAL_OUTPUT` opt-in so an absent secondary monitor cannot make plain `menu` option 3 fail validation.
- Added launcher and README regressions for dual display, explicit OneMix-only rollback, and plain no-monitor startup.

## Task commits

- `724814d` — RED dual-display mapping regression.
- `e492881` — output-bound dual-display touch mapping.
- `bbe3384` — OneMix-only default when no external output is configured.
- `34ffd6b` — operator guidance and documentation regression.

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
- OneMix-only: automated no-external fixture passes after `bbe3384`; physical retest of plain `menu` option 3 is still required.

## Scope preservation

`scripts/launch-touch.sh` and the FreeRDP touch patch were unchanged. The pre-existing untracked `.planning/debug/menu-crash-after-dual-monitor.md` was not modified or committed.

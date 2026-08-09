---
phase: 04-diagnostics-packaging-launch-configuration
reviewed: 2026-08-09T15:08:55Z
depth: standard
files_reviewed: 22
files_reviewed_list:
  - .gitignore
  - README.md
  - new.md
  - patches/onemix-touch.patch
  - scripts/build-release.sh
  - scripts/check-x11-session.sh
  - scripts/launch-touch.sh
  - scripts/menu
  - rdp-debug-gestures.log
  - rdp-debug-native.log
  - temp
  - temp.conf
  - tests/build_release_signal_check.sh
  - tests/check_third_finger_owner.py
  - tests/check_x11_session_check.sh
  - tests/gap01_ownership_layout.c
  - tests/gap05_parser_check.sh
  - tests/menu_diagnostic_env_check.sh
  - tests/pinch_reversal_check.c
  - tests/readme_doc_regression.sh
  - tests/wrapper_production_check.sh
  - tests/xf_touch_internal_check.c
findings:
  critical: 6
  warning: 4
  info: 1
  total: 11
status: issues_found
---

# Phase 04: Code Review Report

**Reviewed:** 2026-08-09T15:08:55Z  
**Depth:** standard  
**Files Reviewed:** 22  
**Status:** issues_found

## Summary

The review traced the delivered quilt patch through the patched FreeRDP source, launch scripts, packaging flow, diagnostic logs, and regression checks. Six release-blocking security or input-lifecycle defects remain, along with four reliability warnings and one stale-documentation item. Existing checks passed, but several are structural or do not exercise the failing runtime paths.

The accepted D-25 exception for `/cert:ignore` and unverified server identity was deliberately not counted as a defect.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: RDP password remains exposed in the long-lived client command line

**Classification:** BLOCKER  
**Files:** `/home/hoang/freerdp-touch/scripts/menu:43-56,79-85`; `/home/hoang/freerdp-touch/scripts/launch-touch.sh:18-23,106-110`

**Issue:** `menu` reads the password, builds `/p:<password>`, writes it into the temporary xinitrc, and the wrapper forwards it unchanged to `xfreerdp3`. The password consequently remains in `xfreerdp3`'s argv for the whole RDP session. The private xinitrc mode does not protect process arguments from principals able to inspect process argv, such as through `/proc/<pid>/cmdline` under the normal system policy.

**Fix:** Stop generating or forwarding `/p:`. Use a supported non-argv FreeRDP credential source, such as `/from-stdin:force` with a protected one-shot pipe or `FREERDP_ASKPASS`. Add a regression assertion that the recorded client argv never contains the supplied password.

### CR-02: Tracked diagnostic logs disclose sensitive connection and session metadata

**Classification:** BLOCKER  
**Files:** `/home/hoang/freerdp-touch/rdp-debug-gestures.log:287,561,567`; `/home/hoang/freerdp-touch/rdp-debug-native.log:286,557,563`; `/home/hoang/freerdp-touch/.gitignore:10`

**Issue:** Both tracked logs disclose a private peer address, account/domain identity, and server auto-reconnect verifier data. These values are distributed to every clone and remain reachable through Git history. `.gitignore` ignores only `rdp-debug.log`, so neither tracked diagnostic variant is prevented from recurring.

**Fix:** Remove the logs from the repository and, if the repository was shared, scrub reachable history according to the publication policy. Add a broad ignore rule such as `rdp-debug*.log`. Replace retained evidence with minimal redacted fixtures and treat exposed session metadata as sensitive.

### CR-03: Release assembly can publish an unvalidated package from shared `/tmp`

**Classification:** BLOCKER  
**File:** `/home/hoang/freerdp-touch/scripts/build-release.sh:82-84,163-175,213-215`

**Issue:** `mktemp -u` reserves no directory, and package artifacts are written into the shared `/tmp` parent. Stage 8 validates one `DEB_FILE`, but Stage 9 independently selects the first broad glob match and copies it. A concurrent process or local untrusted user can place a matching same-version filename that sorts first after validation. The substituted package is then checksummed and atomically published, so `SHA256SUMS` validates the substituted payload rather than protecting against it.

**Fix:** Use an owned private build root created with `mktemp -d`, extract beneath it, retain the exact Stage-8 validated package paths, and copy only those paths into the bundle. Remove the private build root from the exit cleanup path, including on failed builds. For example:

```bash
build_root=$(mktemp -d "${TMPDIR:-/tmp}/onemix-build.XXXXXX")
WORKDIR="$build_root/source"
# Append each validated DEB_FILE to deb_files[]
cp -- "${deb_files[@]}" "$bundle_dir/"
```

### CR-04: Recovery quarantine is disarmed while cancelled fingers are still down

**Classification:** BLOCKER  
**File:** `/home/hoang/freerdp-touch/patches/onemix-touch.patch:1520-1526,1580-1600,1754-1807`

**Issue:** `xf_quarantine_update()` correctly derives `recoveryGateArmed` from the remaining quarantined-contact count. The production code then defeats that invariant in two ways. `xf_touch_cancel_lifecycle()` resets `quarantinedCount` before every cancellation, so a repeated focus/fullscreen/geometry cancellation can discard fingers still awaiting `XI_TouchEnd`. The recovery-event path also unconditionally assigns `recoveryGateArmed = FALSE`, including after a quarantined Update or Ownership event and after only one of several End events. A cancelled multi-finger gesture can therefore admit a new touch before every pre-cancel physical contact has lifted.

**Fix:** Make `xf_quarantine_update()` the actual sole owner after initialization. Remove the unconditional gate assignment, preserve existing quarantine entries during a repeated cancellation, and only add or remove IDs through the helper. Add a runtime regression that cancels two fingers, sends an Update, sends one End, forces cancellation again, and verifies a new Begin remains blocked until the final old End.

### CR-05: Third-finger abort omits the arriving finger from quarantine

**Classification:** BLOCKER  
**File:** `/home/hoang/freerdp-touch/patches/onemix-touch.patch:822-839,1478-1526`

**Issue:** The supplemental array is `{ fingerA, fingerB, savedC, touchId }`, but `suppCount` counts nonzero IDs without compacting the array. In the common active-two-finger case this becomes `{ A, B, 0, C }` with `suppCount == 3`; the lifecycle receives only `{ A, B, 0 }`, so the newly arriving third finger is omitted and not quarantined.

**Fix:** The lifecycle already skips zero IDs, so pass the full array:

```c
xf_touch_cancel_lifecycle(xfc, supp, ARRAYSIZE(supp));
```

Alternatively compact nonzero IDs before passing the count. Add a regression that starts a two-finger gesture, begins a third touch, and asserts all three IDs enter quarantine.

### CR-06: Three-finger pending state survives a pre-claim finger lift

**Classification:** BLOCKER  
**File:** `/home/hoang/freerdp-touch/patches/onemix-touch.patch:1078-1112`

**Issue:** On an End while `threeFingerPending` is set, the code quarantines the remaining IDs but returns without clearing `threeFingerPending`, `pinchFingerA`, `pinchFingerB`, `midFingerC`, or their coordinates. Later End events are consumed by recovery handling, so this stale state remains. The next clean one-finger Begin is then interpreted as a “third or later” finger and aborted; stale IDs can also re-arm quarantine with no physical contacts left.

**Fix:** After building the remaining-ID set and before returning, clear all three-finger-pending fields. Add an end-to-end regression: begin three touches, lift one before pan claim, lift the other two, then verify a fresh one-finger tap is accepted.

## Warnings

### WR-01: Diagnostic cancellation uses the wrong contact store and leaks diagnostic state

**Classification:** WARNING  
**File:** `/home/hoang/freerdp-touch/patches/onemix-touch.patch:1296-1322,1344-1416,1495-1526,1953-1985`

**Issue:** Fallback touch events are recorded in `diagContacts`, but cancellation emits per-contact records from `xfc->contacts` and snapshots `cctx->contacts`; fallback mode populates neither store. It also does not retire `diagContacts`, while quarantined End events are intercepted before `xf_diag_contact_end()` runs. Diagnostic summaries retain phantom contacts, omit expected cancel lines, and can exhaust diagnostic contact capacity after repeated cancellations.

**Fix:** Snapshot and emit cancellation records from `xfc->diagContacts`, then clear its slots and set `diagContactCount = 0`. Keep native RDPEI cancellation accounting separate. Test the production cancellation path rather than only `xf_force_cancel_emit_sequence()` in isolation.

### WR-02: Failed rotation or touch calibration still launches the RDP session

**Classification:** WARNING  
**File:** `/home/hoang/freerdp-touch/scripts/menu:58-85`

**Issue:** The generated xinitrc has neither `set -e` nor explicit checks for `xrandr` and `xinput`. If display rotation or touchscreen transformation fails, it still executes the wrapper and can report a successful RDP launch with unusable orientation or touch mapping.

**Fix:** Add strict error handling before the setup commands, for example:

```bash
#!/usr/bin/env bash
set -eu
```

Add a test where mocked `xrandr` and `xinput` fail and assert that the wrapper is not invoked.

### WR-03: Wrapper idempotency regression does not execute or evaluate the cases it claims

**Classification:** WARNING  
**File:** `/home/hoang/freerdp-touch/tests/wrapper_production_check.sh:268-307`

**Issue:** In the valid cases, `env -i ... \ rc1=0` is a command with an environment assignment, not a prefix for the wrapper invocation on the next line. The subsequent `|| rc1=0` normalizes wrapper failures to success, then `rc1=$?` captures that successful compound status. The invalid cases similarly use `|| true`, so both captured statuses are always zero. The test passes without validating deterministic exit behavior or the intended sterile environment.

**Fix:** Capture the command result directly and assert expected values:

```bash
rc1=0
env -i FIXTURE_LOG="$fixture_log" HOME="$td" XDG_STATE_HOME="$td/state" \
  PATH="$td:$PATH" "$wrapper_fixture" >"$td/idem1.out" 2>"$td/idem1.err" \
  || rc1=$?
```

Apply the same pattern to the second valid run and both invalid runs; assert the expected success or rejection status rather than merely comparing two forced-zero values.

### WR-04: Documented launch command is not installed or reproducible from the repository instructions

**Classification:** WARNING  
**Files:** `/home/hoang/freerdp-touch/README.md:107-141`; `/home/hoang/freerdp-touch/scripts/menu:79`; `/home/hoang/freerdp-touch/scripts/build-release.sh:167-215`

**Issue:** README instructs users to run bare `menu`, but the build produces only the four FreeRDP packages and installs no `menu` command. The available launcher is `scripts/menu`, and it generates an xinitrc that hard-codes `/home/hoang/freerdp-touch/scripts/launch-touch.sh`. A checkout at another path, or an installation followed only by the documented package steps, cannot reproduce the launch flow.

**Fix:** Either package and install an explicit launcher command, or document `./scripts/menu` and resolve `launch-touch.sh` relative to the menu script’s directory rather than a fixed checkout path.

## Info

### IN-01: `new.md` is an unreferenced, contradictory design document

**Classification:** INFO  
**Files:** `/home/hoang/freerdp-touch/new.md:3,15-17,24-31,62,86`; `/home/hoang/freerdp-touch/README.md:255-261`

**Issue:** `new.md` describes native RDPEI forwarding, direct-touch mode switching, and three-finger Alt+Tab. The shipped implementation explicitly disables native RDPEI forwarding, has no runtime mode switch, and maps three-finger motion to middle-button drag. Its generic name and lack of archival context make it misleading operational documentation.

**Fix:** Delete it, or label it clearly as archived historical exploration and link readers to the current README.

## Validation Performed

- Reviewed all 22 files in the supplied scope and traced the quilt patch into the patched FreeRDP X11 and RDPEI call paths.
- `tests/build_release_signal_check.sh`, `tests/check_third_finger_owner.py`, `tests/check_x11_session_check.sh`, `tests/gap05_parser_check.sh`, `tests/menu_diagnostic_env_check.sh`, `tests/readme_doc_regression.sh`, and `tests/wrapper_production_check.sh` passed.
- `tests/gap01_ownership_layout.c`, `tests/pinch_reversal_check.c`, and `tests/xf_touch_internal_check.c` compiled and passed.
- Existing tests do not cover the recovery-state sequences above; `wrapper_production_check.sh` has the ineffective status assertions described in WR-03.
- No source files were modified and no commit was created.

---

_Reviewed: 2026-08-09T15:08:55Z_  
_Reviewer: Claude (gsd-code-reviewer)_  
_Depth: standard_

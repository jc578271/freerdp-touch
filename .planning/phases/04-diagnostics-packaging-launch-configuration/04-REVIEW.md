---
phase: 04-diagnostics-packaging-launch-configuration
reviewed: 2026-08-08T14:17:15Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - .gitignore
  - patches/onemix-touch.patch
  - README.md
  - scripts/build-release.sh
  - scripts/check-x11-session.sh
  - scripts/launch-touch.sh
  - scripts/menu
  - tests/check_x11_session_check.sh
  - tests/menu_diagnostic_env_check.sh
findings:
  critical: 9
  warning: 4
  info: 0
  total: 13
status: issues_found
---

# Phase 04: Code Review Report

**Reviewed:** 2026-08-08T14:17:15Z  
**Depth:** standard  
**Files Reviewed:** 9  
**Status:** issues_found

## Summary

The patch applies cleanly to a fresh temporary Debian-source extraction and its standalone classifier prints `OK`; the two committed shell tests and shell syntax checks also pass. Those checks do not cover several input-lifecycle, packaging-interruption, security, documentation, and test-reliability defects. The implementation is not ready to ship.

## Narrative Findings (AI reviewer)

## Critical Issues

### BL-01: `XI_TouchOwnership` is treated as an `XIDeviceEvent`

**Classification:** BLOCKER  
**File:** `/home/hoang/freerdp-touch/patches/onemix-touch.patch:1249-1287,1304-1311` (`client/X11/xf_input.c` hunk)  
**Impact:** A touch-ownership event can read beyond its event object, causing a crash or arbitrary coordinates to enter input handling.

**Issue:** `XI_TouchOwnership` is delivered as `XITouchOwnershipEvent`, but the new branches cast it to `XIDeviceEvent` and pass it to `xf_input_touch_remote()`. That handler unconditionally reads `event_x` and `event_y`. The installed XI2 headers show `sizeof(XITouchOwnershipEvent) == 96`, while `offsetof(XIDeviceEvent, event_x) == 104`; the coordinate access is out of bounds.

**Evidence:** A temporary compile-time layout probe confirmed the incompatible sizes and offsets. The unsafe outer ownership branch runs even when diagnostics are disabled because coordinate extraction is unconditional.

**Recommended fix:** Handle ownership with `const XITouchOwnershipEvent*`, use only `deviceid` and `touchid` for `XIAllowTouchEvents`, and do not pass ownership events to `xf_input_touch_remote()`. Make the recovery-gate ownership branch use the same event type.

### BL-02: Repeated forced cancellation permanently locks out touch input

**Classification:** BLOCKER  
**File:** `/home/hoang/freerdp-touch/patches/onemix-touch.patch:1172-1230,1243-1298` (`client/X11/xf_input.c` hunk)  
**Impact:** A second lifecycle cancellation before the original finger lifts can make every future touch event get discarded until the client restarts.

**Issue:** `xf_touch_force_cancel()` resets `quarantinedCount` but only ever sets `recoveryGateArmed` to true; it never clears the flag when no IDs remain. After a first cancellation arms the recovery gate, a second cancellation wipes the quarantine IDs while retaining the armed flag. The recovery gate then sees an empty list, treats every event as an unrecognized touch, and returns without a path that can clear the gate.

**Evidence:** Fullscreen, focus, configure, and disconnect all call the same cancellation seam, so two calls before a queued `XI_TouchEnd` are plausible. The gate's only disarm path requires removing an ID from the now-empty list.

**Recommended fix:** Preserve and deduplicate existing quarantined IDs across repeated cancellations, append newly active IDs, and always set `recoveryGateArmed = (quarantinedCount > 0)`. Add a regression case that forces cancellation twice before End, then verifies a new touch reaches the recognizer.

### BL-03: The content-bounds gate drops End events and can leave remote input held

**Classification:** BLOCKER  
**File:** `/home/hoang/freerdp-touch/patches/onemix-touch.patch:1035-1052` (`client/X11/xf_input.c` hunk)  
**Impact:** A drag or pinch ending over a letterbox border can leave BUTTON1 or Ctrl held on the remote host.

**Issue:** The content-bounds test returns before fallback dispatch for every event type, including `XI_TouchEnd`. A contact accepted inside the scaled region but lifted outside it never reaches the fallback cleanup paths that release a drag or call pinch cleanup.

**Evidence:** The return at the bounds gate precedes the only call to `xf_input_touch_fallback()`, while release handling is inside that fallback state machine.

**Recommended fix:** Never discard lifecycle completion for an accepted contact. Restrict the admission bounds check to Begin, or explicitly route End through state cleanup using the last valid tracked coordinates.

### BL-04: Pinch wheel accumulation discards fractional movement indefinitely

**Classification:** BLOCKER  
**File:** `/home/hoang/freerdp-touch/patches/onemix-touch.patch:300-343,1397-1405` (`client/X11/xf_input.c` and `client/X11/xfreerdp.h` hunks)  
**Impact:** Valid diagonal, sequential two-finger pinches can claim pinch but never generate a Ctrl+wheel event.

**Issue:** `pinchAccum` is `INT32`, and each `double delta` is cast to `INT32` before accumulation. For a symmetric diagonal pinch, pinch claims at about 8.725 px, then subsequent per-contact updates can be 0.747 and 0.750 px. Each is truncated to zero, so the accumulator never reaches a wheel detent.

**Evidence:** A numerical reproduction of the production formula showed repeated nonzero per-event deltas each contributing zero after the cast.

**Recommended fix:** Store the accumulator, or at least a residual, as `double`; use `fabs()` for the threshold comparison and subtract the wheel step as a floating-point value. Add a sequential diagonal-pinch regression case that exercises the production wheel path.

### BL-05: Oversized calibration values bypass validation and reach unchecked `atoi()`

**Classification:** BLOCKER  
**Files:** `/home/hoang/freerdp-touch/scripts/launch-touch.sh:31-58`; `/home/hoang/freerdp-touch/patches/onemix-touch.patch:1537-1551` (`client/common/cmdline.c` hunk)  
**Impact:** Untrusted environment input that should be rejected reaches FreeRDP with an invalid setting; the downstream conversion has overflow/undefined behavior.

**Issue:** Digits-only values larger than Bash's integer range make both `[ "$value" -lt ... ]` comparisons return an integer-expression error. Because those failures are conditions inside `if`, the wrapper continues and invokes the client. The new command-line parser uses `atoi()` and casts the result to `UINT32` without validating syntax or range.

**Evidence:** A temporary mocked-wrapper run with an 84-digit `FREERDP_TOUCH_LONG_PRESS_MS` emitted `integer expression expected`, exited zero, invoked the mock client, and forwarded the oversized `/touch-long-press:` argument.

**Recommended fix:** Reject overlong values before arithmetic or use exact bounded decimal patterns for the supported ranges. Replace `atoi()` with checked `strtoul`/`strtoumax` parsing that verifies complete consumption, overflow, and the permitted range for both switches.

### BL-06: Interrupted release builds return success

**Classification:** BLOCKER  
**File:** `/home/hoang/freerdp-touch/scripts/build-release.sh:52-63`  
**Impact:** Automation can treat an interrupted build as successful and deploy a stale prior bundle.

**Issue:** One `cleanup` function is registered for `EXIT`, `INT`, `HUP`, and `TERM`, then executes `exit $rc`. A signal delivered while Bash waits for a child can enter the trap with `$? == 0`, so an interrupted build exits successfully. The EXIT trap then invokes cleanup again.

**Evidence:** A minimal probe using the same trap structure returned exit code 0 after `TERM` and executed the cleanup handler twice.

**Recommended fix:** Register cleanup only for EXIT. Register separate signal handlers that exit with `128 + signal`; the EXIT cleanup should preserve that nonzero status. Add pre- and post-publication TERM tests that assert both nonzero status and a valid `dist` target.

### BL-07: Certificate validation is disabled for every RDP launch

**Classification:** BLOCKER  
**File:** `/home/hoang/freerdp-touch/scripts/menu:83`  
**Impact:** An on-path attacker can impersonate the RDP server and capture or relay the TTY-entered password.

**Issue:** The menu unconditionally forwards `/cert:ignore`, disabling server certificate validation in normal, diagnostic, and mouse-only modes.

**Evidence:** The option is part of the single generated wrapper invocation and no later layer removes it.

**Recommended fix:** Remove `/cert:ignore`; validate and pin the expected certificate/fingerprint, or use a reviewed first-connection TOFU process followed by pinning.

### BL-08: README checksum instructions break the following install command

**Classification:** BLOCKER  
**File:** `/home/hoang/freerdp-touch/README.md:46-58`  
**Impact:** A sequential copy/paste of the documented package-install flow fails to locate every `.deb`.

**Issue:** The checksum command uses `cd "$(readlink -f dist)"`, leaving the shell in the resolved bundle directory. The next command references `./dist/...`, which then resolves to a nonexistent `bundle/dist/...` path.

**Evidence:** No command returns to the repository root between the checksum and installation sections.

**Recommended fix:** Run checksum verification in a subshell, such as `(cd "$(readlink -f dist)" && sha256sum -c SHA256SUMS)`, or explicitly change back to the repository root before installation.

### BL-09: README rollback assertion fails open when a closure package is absent

**Classification:** BLOCKER  
**File:** `/home/hoang/freerdp-touch/README.md:152-155`  
**Impact:** A partially removed or broken four-package closure can be declared “safe to launch.”

**Issue:** The stock assertion pipelines `dpkg-query` into `grep`. If `dpkg-query` fails because a package is missing, `grep` sees no `+onemix1` match and the `||` branch prints `ALL STOCK -- safe to launch`.

**Evidence:** The pipeline's result is only grep's status; there is no independent check that all four queries succeeded or returned four installed packages.

**Recommended fix:** Capture `dpkg-query -W` output only after requiring success, require all four package results, then test those versions for the local suffix. Treat query failure or an incomplete closure as unsafe.

## Warnings

### WR-01: Classifier regression test is disconnected from the production classifier

**Classification:** WARNING  
**Files:** `/home/hoang/freerdp-touch/patches/onemix-touch.patch:1666-1671`; `/home/hoang/freerdp-touch/scripts/build-release.sh:128-136`  
**Impact:** A production classifier regression can ship while the standalone test continues to print `OK`.

**Issue:** `test_scroll_classifier.c` copies the rule and hardcodes its constants rather than calling the real `xf_input_two_finger_resolve()` logic. Its comment claims a static guard catches drift, but the release script only compiles and runs the independent model.

**Evidence:** Changing the production dominance ratio or claim order without changing the model would leave the test unchanged and passing.

**Recommended fix:** Extract the production decision into a small helper used by both runtime and test code, or build a harness that exercises the actual production implementation.

### WR-02: Menu regression test bypasses the real wrapper and direct xinitrc execution

**Classification:** WARNING  
**File:** `/home/hoang/freerdp-touch/tests/menu_diagnostic_env_check.sh:32-42,59-69`  
**Impact:** Regressions in the wrapper, native-X11 gate, diagnostic tee, executable mode, and shebang path are not detected.

**Issue:** The test replaces `launch-touch.sh` with a mock and invokes the rendered xinitrc through `bash`. The deployed flow executes the xinitrc through `startx` and then invokes the real wrapper.

**Evidence:** The only wrapper observed by the test is the generated mock at lines 32-42; line 69 explicitly runs `bash "$RENDERED_XINITRC"`.

**Recommended fix:** Add a committed wrapper test with mocked gate/client binaries, and make the menu test execute the rendered xinitrc directly after checking its mode and shebang. Cover oversized calibration values, mouse-only behavior, opaque arguments, diagnostics, and exit-status propagation.

### WR-03: Native-X11 regression test does not verify Wayland fail-closed behavior

**Classification:** WARNING  
**File:** `/home/hoang/freerdp-touch/tests/check_x11_session_check.sh:24-28,45-46`  
**Impact:** A future removal or inversion of the production Wayland rejection can pass the full committed test suite.

**Issue:** Every test invocation fixes `XDG_SESSION_TYPE=x11` and clears `WAYLAND_DISPLAY`. The test covers the unrelated-Xwayland false rejection but never executes the conditions that must reject Wayland.

**Evidence:** `run_gate()` always supplies the passing session variables, and the two assertions only test matching and nonmatching Xorg display strings.

**Recommended fix:** Add negative cases where a matching Xorg process exists but `XDG_SESSION_TYPE=wayland`, and where `WAYLAND_DISPLAY=wayland-0`; both must fail.

### WR-04: Canonical local-only diagnostics report zero contacts and omit cancellation evidence

**Classification:** WARNING  
**File:** `/home/hoang/freerdp-touch/patches/onemix-touch.patch:442-443,458,573,593,1088-1108` (`client/X11/xf_input.c` hunk)  
**Impact:** Diagnostic state and force-cancel records are misleading in the only supported local-only runtime path.

**Issue:** The fallback recognizer tracks `lpFinger`, `pinchFingerA/B`, and `midFingerC`, but does not populate `xfc->contacts[]` or increment `active_contacts`. The new diagnostic records report that stale count, so active fallback gestures show `contacts=0`; the per-contact cancel loop emits nothing for the canonical mode.

**Evidence:** The state and force-cancel records use `active_contacts`, while the cancellation evidence loop iterates only `xfc->contacts[]`.

**Recommended fix:** Derive diagnostic-only contact counts and IDs from the existing fallback state fields and emit cancel records from those fields. Keep the correction observational so it does not alter frozen gesture routing.

## Validation Performed

- `/home/hoang/freerdp-touch/tests/check_x11_session_check.sh` passed.
- `/home/hoang/freerdp-touch/tests/menu_diagnostic_env_check.sh` passed.
- The quilt patch applied to a fresh temporary Debian-source extraction; the standalone classifier printed `OK`.
- Shell syntax checks passed for the reviewed shell scripts.
- No source files were modified and no commit was created.

---

_Reviewed: 2026-08-08T14:17:15Z_  
_Reviewer: Claude (gsd-code-reviewer)_  
_Depth: standard_

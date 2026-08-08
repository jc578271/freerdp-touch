---
phase: 04-diagnostics-packaging-launch-configuration
status: gaps_found
verified: 24
total: 30
score: 24/30
gaps: 10
behavior_unverified: 1
review_blockers: 9
review_warnings: 4
next_action: Plan and execute Phase 4 gap closure before shipping.
next_command: /gsd-plan-phase 4 --gaps
verified_at: 2026-08-08
---

# Phase 04 Verification: Diagnostics, Packaging & Launch Configuration

## Verdict

**GAPS FOUND.** Phase 04 executed all three plans and completed the native-device verification workflow, but the current implementation is not safe to ship. Twenty-four of thirty declared plan must-haves are verified. Five declared must-haves fail, one remains behavior-unverified in this verification pass, and the standard code review confirmed nine blocker defects plus four warnings.

The full code-review evidence is in `04-REVIEW.md`.

## Goal

The verified patch ships as an installable Debian package with env-var-gated diagnostics and a documented launch preset that a user can install, roll back, and operate.

## Evidence That Holds

- The quilt patch applies to a fresh Debian source extraction and resolves to `3.15.0+dfsg-2.1+deb13u3+onemix1`.
- `dist` is a relative symlink to a bundle containing the intended four amd64 runtime packages plus `SHA256SUMS`; package metadata and checksums validate.
- The current system is intentionally rolled back to the stock four-package version `3.15.0+dfsg-2.1+deb13u3`.
- `/usr/local/bin/menu` is mode 0755 and matches the committed repository candidate.
- `tests/check_x11_session_check.sh`, `tests/menu_diagnostic_env_check.sh`, and the compiled `tests/pinch_reversal_check.c` pass.
- The exact inline verification-record parser accepts `04-03-verify-record.md`, and its required negative fixtures are rejected.
- Diagnostic source contains the cached exact-`1` gates and gated X11/RDPEI records without sensitive launch material in format strings.
- No APT hold or pin exists; the local version ordering allows later Debian security revisions to replace the patched build.
- The ten recorded on-device checks were completed, including normal gestures, diagnostic launch, quiet launch, mouse-only mode, rollback, and stock mouse launch.

## Must-Have Accounting

| Plan | Verified | Failed | Behavior unverified |
|------|---------:|-------:|--------------------:|
| 04-01 | 6/9 | 2 | 1 |
| 04-02 | 10/11 | 1 | 0 |
| 04-03 | 8/10 | 2 | 0 |
| **Total** | **24/30** | **5** | **1** |

Failed declared must-haves:

1. Release publication must report interruption/failure correctly.
2. Canonical fallback diagnostics must satisfy the declared active-contact cancellation evidence contract.
3. Calibration must reject every invalid unsigned decimal before invoking FreeRDP.
4. README install commands must work as a sequential documented flow.
5. README rollback assertion must fail closed when any closure package is absent.

Behavior-unverified in this verification pass:

- Two clean full `dpkg-buildpackage` runs were claimed and evidenced by Plan 04-01, but were not re-executed by the final verifier.

## Confirmed Gaps

### GAP-01 — Unsafe `XI_TouchOwnership` event cast

`patches/onemix-touch.patch` handles `XI_TouchOwnership` as `XIDeviceEvent` and routes it to code that reads `event_x` and `event_y`. The ownership event is smaller than the offset of those fields, creating an out-of-bounds read and possible crash or invalid input coordinates.

**Required closure:** Use `XITouchOwnershipEvent` in dedicated ownership branches, use only `deviceid` and `touchid` for ownership handling, and add a regression check.

### GAP-02 — Repeated cancellation can permanently suppress touch

`xf_touch_force_cancel()` can clear `quarantinedCount` while leaving `recoveryGateArmed` true. A second lifecycle cancellation before the original End events can leave an armed gate with no IDs to drain, dropping all future touch input.

**Required closure:** Preserve/deduplicate quarantined IDs across repeated cancellation, derive the armed flag from the resulting count, and test cancel-twice-before-End recovery.

### GAP-03 — Bounds filter can drop lifecycle End

The content-bounds early return precedes fallback dispatch and can drop `XI_TouchEnd`. A contact that begins in content and ends over a border can leave Button1 or Ctrl held.

**Required closure:** Apply admission bounds only to Begin, or always route End through cleanup using tracked coordinates. Add an outside-bounds release regression.

### GAP-04 — Pinch accumulation discards fractional motion

`pinchAccum` is integral and each floating-point distance delta is truncated before accumulation. Sequential sub-pixel diagonal changes can be discarded forever after pinch classification.

**Required closure:** Preserve a floating-point residual and test sequential diagonal pinch movement in both directions.

### GAP-05 — Oversized calibration bypasses validation

Very long digit-only values cause shell arithmetic errors but still reach the client. The patched command-line parser also uses unchecked `atoi()` conversion.

**Required closure:** Reject overlong/noncanonical values before shell arithmetic and replace unchecked parsing with bounded, overflow-detecting conversion that enforces the same ranges.

### GAP-06 — Interrupted release build can exit successfully

`scripts/build-release.sh` installs the same cleanup trap for `EXIT`, `INT`, `HUP`, and `TERM`. A signal can enter cleanup with status zero, run cleanup twice, and make an interrupted publication appear successful while the old `dist` remains.

**Required closure:** Use cleanup only for `EXIT`; use signal handlers that exit with `128 + signal`. Test interruption before and after publication while preserving a valid prior bundle.

### GAP-07 — RDP certificate validation disabled

`scripts/menu` includes `/cert:ignore`, disabling server identity verification for all launch modes.

**Required closure:** Select and implement an explicit trust policy: certificate/fingerprint pinning or a reviewed first-use trust workflow. Do not silently retain `/cert:ignore`.

### GAP-08 — README install sequence changes directory incorrectly

The checksum command changes the caller's working directory to the bundle, while the following install command uses `./dist/...`; sequential copy/paste therefore resolves invalid paths.

**Required closure:** Run checksum verification in a subshell or explicitly return to the repository root, then test the documented sequence from a clean shell.

### GAP-09 — README rollback assertion fails open

If `dpkg-query` fails because a required package is missing, the pipeline can still print `ALL STOCK -- safe to launch` because grep sees no `+onemix1` text.

**Required closure:** Require successful queries for exactly four packages before checking versions; treat missing/fewer results as unsafe.

### GAP-10 — Fallback cancellation diagnostic contract is not literally met

The canonical `+touch-pinch-wheel-fallback` dispatcher does not populate `xfc->contacts[]` or `active_contacts`, while the declared per-contact cancellation loop reads that store. The approved ingress-inference oracle proves an active gesture historically, but does not make Plan 04-01's literal per-contact cancellation assertion true.

**Required closure:** Either add observational fallback contact tracking that emits accurate cancel evidence without changing routing, or formally revise/override the obsolete Plan 04-01 must-have through an explicit project decision and update requirement traceability.

## Requirement Status

| Requirement | Status | Reason |
|-------------|--------|--------|
| DIAG-01 | Blocked | Diagnostic gating works, but canonical fallback per-contact cancellation evidence does not satisfy the strict declared contract. |
| PACK-01 | Blocked | Patch and bundle validate, but interrupted builds can report success. |
| PACK-02 | Blocked | Documented install and rollback command flows contain fail-open/broken sequences. |
| CONF-01 | Blocked | Standard preset works, but oversized calibration bypasses validation; certificate validation is disabled; packaged touch lifecycle blockers remain. |

## Warnings

1. The classifier regression duplicates a model instead of exercising the live production classifier.
2. The menu regression replaces the actual wrapper and invokes rendered xinitrc through Bash rather than the direct startx execution path.
3. The X11 gate regression lacks negative cases for `XDG_SESSION_TYPE=wayland` and nonempty `WAYLAND_DISPLAY` with a matching Xorg process.
4. Canonical fallback diagnostic counts remain misleading because the runtime fallback state is stored outside `xfc->contacts[]`.

## Developer Decisions Required

1. Choose the certificate trust/pinning policy that replaces `/cert:ignore`.
2. Choose between actual observational fallback-contact diagnostics and a formal override/rewrite of the obsolete per-contact cancellation must-have.

## Next Action

Do not ship or mark Phase 04 complete.

Run:

`/gsd-plan-phase 4 --gaps`

Gap closure must fix the confirmed defects, rebuild the exact four-package bundle, rerun the relevant automated regressions and native-device checks, and update the README/verification evidence before Phase 04 is verified again.

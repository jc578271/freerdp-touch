---
phase: 04-diagnostics-packaging-launch-configuration
verified: 2026-08-09T15:30:00Z
status: gaps_found
score: 0/4
behavior_unverified: 1
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 24/30
  gaps_closed:
    - "XI_TouchOwnership now uses XITouchOwnershipEvent and is not forwarded to xf_input_touch_remote."
    - "The content-bounds helper admits Update and End events for cleanup."
    - "The live parser rejects malformed, noncanonical, out-of-range, and overflowing calibration options."
    - "The wrapper rejects overlong and leading-zero calibration values before shell arithmetic."
    - "README checksum verification now uses a subshell and rollback rejects failed or incomplete dpkg-query output."
  gaps_remaining:
    - "Cancellation quarantine and three-finger recovery invariants are still false in the production dispatcher."
    - "Canonical local-only cancellation diagnostics do not emit or retire the diagnostic contacts they track."
    - "Release assembly can publish an unvalidated package selected from shared /tmp."
    - "The documented bare menu command is neither installed by the Debian package nor relocatable."
  regressions:
    - "The claimed production call to xf_force_cancel_emit_sequence is absent; only the helper test calls it."
    - "The signal fixture passes despite its sha256sum -c shim emitting an error and not modelling checksum verification."
    - "The wrapper idempotency assertions normalize the statuses they purport to compare."
gaps:
  - truth: "A reproducible release publishes only the four package files validated from the fresh pinned patch build."
    status: failed
    reason: "build-release.sh uses mktemp -u under shared /tmp and re-globs package paths after validation, allowing an unvalidated same-version package to be copied and checksummed."
    artifacts:
      - path: "scripts/build-release.sh"
        issue: "Lines 82-84 create an unowned extraction path; lines 213-215 discard the Stage 8 path and select a fresh glob result."
    missing:
      - "Create an owned mktemp -d build root and extract below it."
      - "Retain the exact Stage 8 validated package paths in an array and copy only those paths."
      - "Add an adversarial regression proving a same-version file cannot replace a validated package."
  - truth: "Cancellation and touch-count interruptions leave the local recognizer clean and block new input until every cancelled finger lifts."
    status: failed
    reason: "Production code directly resets quarantine state, unconditionally disarms recovery on any quarantined event, omits a third arriving finger in a common supplemental array layout, and leaves threeFingerPending state stale after a pre-claim lift."
    artifacts:
      - path: "build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c"
        issue: "Runtime writes at 949-951, 1421, 1457, 1488, 1528, 1830, and 2092 violate the claimed sole-owner invariant."
    missing:
      - "Route every runtime quarantine mutation through xf_quarantine_update without blind count resets."
      - "Remove the unconditional recoveryGateArmed = FALSE assignment."
      - "Pass all compacted supplemental IDs and clear every three-finger-pending field on a pre-claim lift."
      - "Add a dispatcher-level regression covering Update, first End, repeated cancel, final End, and a fresh Begin."
  - truth: "Diagnostic mode records accurate local-only Begin/Update/End/Cancel lifecycle evidence and cleans diagnostic state after cancellation."
    status: failed
    reason: "Ingress populates diagContacts, but cancellation logs xfc->contacts and cctx->contacts, neither of which is populated by the canonical fallback dispatcher. diagContacts is never cleared when recovery intercepts End. The declared ordering helper is not called by production."
    artifacts:
      - path: "build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c"
        issue: "The lifecycle manually emits cancellation records from the wrong stores at 1710-1724 and never calls xf_force_cancel_emit_sequence."
      - path: "build/freerdp3-3.15.0+dfsg/client/X11/xf_touch_internal.h"
        issue: "xf_force_cancel_emit_sequence is defined and tested but orphaned from production."
    missing:
      - "Snapshot, emit, and retire diagContacts in the actual lifecycle owner."
      - "Wire xf_force_cancel_emit_sequence exactly once or remove it and test the actual equivalent implementation."
      - "Exercise the real event dispatcher rather than only pure helper models."
  - truth: "A user following the documented package installation can invoke the documented local-only launch preset."
    status: failed
    reason: "README instructs the user to run bare menu, but the four Debian packages contain neither menu nor launch-touch.sh; scripts/menu hard-codes the current checkout path."
    artifacts:
      - path: "README.md"
        issue: "Launch instructions contain bare menu and no launcher installation or repository-relative invocation."
      - path: "scripts/menu"
        issue: "The generated xinitrc execs /home/hoang/freerdp-touch/scripts/launch-touch.sh."
    missing:
      - "Package/install an explicit launcher, or document ./scripts/menu and resolve the wrapper relative to the menu script."
      - "Fail before launch if xrandr or xinput setup fails, then add a regression for that path."
  - truth: "Release artifacts and diagnostics do not disclose sensitive connection or session metadata."
    status: failed
    reason: "Both tracked rdp-debug log files contain private-address and account/domain-labelled metadata; .gitignore does not ignore the tracked filename pattern."
    artifacts:
      - path: "rdp-debug-gestures.log"
        issue: "Tracked generated diagnostic output contains sensitive metadata."
      - path: "rdp-debug-native.log"
        issue: "Tracked generated diagnostic output contains sensitive metadata."
      - path: ".gitignore"
        issue: "Only rdp-debug.log is ignored; the tracked variants remain unprotected."
    missing:
      - "Remove generated logs from the repository, follow the repository publication policy for reachable history, and retain only redacted fixtures if evidence is needed."
      - "Ignore the broad rdp-debug*.log pattern."
  - truth: "The menu-to-client credential handoff does not expose the supplied secret through process arguments."
    status: failed
    reason: "menu constructs /p:<value>, serializes it into xinitrc, and the wrapper forwards it unchanged to xfreerdp3. D-23 requires this opaque handoff but does not explicitly accept argv disclosure."
    artifacts:
      - path: "scripts/menu"
        issue: "Lines 43-56 construct and serialize the /p: argument."
      - path: "scripts/launch-touch.sh"
        issue: "Lines 106 and 110 forward every opaque argument to the client."
    missing:
      - "Replace /p: argv transport with a supported protected credential mechanism, or obtain an explicit owner exception separate from D-25."
      - "Add a regression that verifies the client process argument vector never contains the supplied secret."
deferred:
  - truth: "GAP-07 certificate hardening"
    addressed_in: "Future owner-requested requirement or phase; no later roadmap phase is currently scheduled."
    evidence: "GAP-07 remains USER-DEFERRED, /cert:ignore is expected for v1, and server certificate identity must not be claimed as verified."
behavior_unverified_items:
  - truth: "The user can install the patched four-package closure and restore the stock closure using the documented commands."
    test: "After the build-publication and launcher gaps are fixed, perform the exact four-package patched install twice and the exact four-package stock rollback twice on the native-X11 device."
    expected: "Each transaction succeeds, all four identities match its intended version, and the stock mouse-only launch works after rollback."
    why_human: "The repository regression mocks apt and the durable record is a prior assertion; this verification did not mutate the installed system to repeat package transactions."
---

# Phase 04: Diagnostics, Packaging & Launch Configuration Verification Report

**Phase Goal:** The verified patch ships as an installable Debian package with env-var-gated diagnostics and a documented launch preset that a user can install, roll back, and operate.  
**Verified:** 2026-08-09T15:30:00Z  
**Status:** gaps_found  
**Re-verification:** Yes — after claimed gap closure

## Verdict

The phase goal is **not achieved**. The repository contains a real four-package bundle, a quilt patch that applies cleanly to fresh source, a functional parser fixture, and a substantially implemented wrapper. Those facts do not make the release shippable:

1. the release pipeline can publish a package that was not the package it validated;
2. the shipped X11 event dispatcher still breaks cancellation/recovery and three-finger lifecycle invariants;
3. local-only cancellation diagnostics are wired to the wrong contact stores and leak diagnostic state;
4. a newly installed user cannot reproduce the README's bare `menu` launch path; and
5. tracked diagnostic artifacts and the `/p:` handoff create unaccepted confidentiality exposure.

The locked D-25 certificate exception is preserved below and is **not** counted as a failed requirement.

## Goal Achievement

### Roadmap Success Criteria

| # | Observable truth | Status | Evidence |
|---|---|---|---|
| 1 | The developer can reproducibly build an installable pinned Debian package using the documented quilt patch. | ✗ FAILED | A fresh extraction accepted the patch and the current bundle has four valid packages, but `scripts/build-release.sh` builds in shared `/tmp` using `mktemp -u` and reselects package globs after Stage 8 validation. The published payload is not reliably the validated fresh-build payload. |
| 2 | The user can install the patch and restore stock Debian packages with documented, verified commands. | ⚠ PRESENT_BEHAVIOR_UNVERIFIED | README uses an explicit four-package closure; its focused regression passes, current `dpkg-query` confirms all four stock packages, and the structured prior record exists. The regression mocks apt, and no fresh state-changing install/rollback was performed in this verification. |
| 3 | The user can launch a documented local-only preset with calibration and mouse-only fallback. | ✗ FAILED | `launch-touch.sh` composes the correct flags and its fixture passes, but README documents bare `menu`; the Debian packages do not install a launcher and `scripts/menu` hard-codes the current checkout location. |
| 4 | Exact-1 diagnostics record touch lifecycle, gesture decisions, and RDPEI frames while normal launches are quiet. | ✗ FAILED | Exact-1 cached X11/RDPEI gates and record sites exist, but local fallback cancellation emits from inactive `xfc->contacts`/`cctx->contacts`, never clears `diagContacts`, and never calls the declared production ordering helper. |

**Score:** 0/4 roadmap truths verified (1 present, behavior-unverified).

### Plan Frontmatter Must-Have Accounting

All 64 declared plan truths were audited in addition to the four roadmap criteria. The goal score above deliberately uses the roadmap contract; a count of small green implementation subclaims must not obscure a failed release outcome.

| Plan | Declared truths | Verified | Failed | Present, behavior-unverified | Backstop / human-needed |
|---|---:|---:|---:|---:|---:|
| 04-01 | 9 | 2 | 4 | 2 | 1 |
| 04-02 | 11 | 10 | 0 | 0 | 1 |
| 04-03 | 10 | 5 | 1 | 3 | 1 |
| 04-04 | 12 | 5 | 7 | 0 | 0 |
| 04-05 | 12 | 9 | 2 | 1 | 0 |
| 04-06 | 10 | 4 | 3 | 3 | 0 |
| **Total** | **64** | **35** | **17** | **9** | **3** |

Non-green plan truths resolve as follows:

- **04-01:** diagnostics cancellation contract, clean-build provenance, publication safety, and local fallback cancellation records fail; disabled-path equivalence and two-build behavior remain unexercised; the diagnostic-content backstop needs human review.
- **04-03:** the documented launch flow fails because `menu` is not provisioned; on-device install, quiet-mode, and menu-only assertions are prior-record behavior rather than fresh executable evidence; the installed-version backstop needs human review.
- **04-04:** the sole-owner quarantine truth and all production cancellation/ordering/dispatcher regressions fail. The ownership cast, bounds helper, double accumulator, and live parser fixture are verified.
- **04-05:** the signal fixture is incomplete because its `sha256sum -c` shim errors yet returns success, and the README regression intentionally accepts mismatched package names. The idempotency assertion masks return codes, so that behavioral claim is unverified.
- **04-06:** release identity/provenance, aggregate regression coverage, and local-only diagnostic cancellation assertions fail; two-build, live-interruption, and live install/rollback assertions are present but not independently rerunnable behavioral proof.

## Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `patches/onemix-touch.patch` | Complete quilt patch for pinned source | ✓ VERIFIED | Applied with `quilt push -a` to a fresh `dpkg-source` extraction. Patched X11, header, parser, and RDPEI files match the current build tree. The build-tree changelog intentionally remains stock; the fresh patched changelog contains `+onemix1`. |
| `dist` relative symlink | Exact four-package runtime bundle plus checksums | ⚠ HOLLOW | It is relative, points inside the repository, contains exactly four amd64 `+onemix1` packages, and every SHA256SUMS entry passes. Its provenance is unsafe because the producer can reselect an unvalidated `/tmp` package after validation. |
| `scripts/build-release.sh` | Fresh extraction, patch application, validated atomic publication | ✗ FAILED | Substantive 286-line pipeline with lock/traps/atomic symlink swap, but unsafe workspace ownership and post-validation globbing break release integrity. |
| `scripts/launch-touch.sh` | Local-only preset, calibration, mouse-only, exact-1 diagnostic log | ✓ VERIFIED | Source and copied-wrapper regression prove flags, range validation, direct normal exec, private diagnostic log setup, and client-status propagation. |
| `scripts/menu` and `/usr/local/bin/menu` | Canonical menu delegation | ⚠ PARTIAL | Deployed file is byte-identical and mode 0755. It delegates via a fixed `/home/hoang/freerdp-touch/...` path and is not installed/documented as part of package setup. |
| `xf_touch_internal.h` | Production-shared cancellation helpers | ⚠ ORPHANED IN PART | Helpers are substantive and the helper regression passes, but `xf_force_cancel_emit_sequence` has no production call site despite its comment and plan claim. |
| `README.md` | Install, rollback, and launch operations guide | ⚠ PARTIAL | Explicit checksum/install/rollback/rebase documentation is substantive. The documented launch command lacks a provisioned, relocatable launcher. |
| Phase regressions | Evidence for real release behavior | ⚠ PARTIAL | Parser, session-gate, ownership, and wrapper paths run. Helper/model tests and fixtures do not exercise the broken dispatcher paths; two tests mask or ignore relevant failures. |

## Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `scripts/build-release.sh` | `patches/onemix-touch.patch` | Fresh extraction copies patch, appends `series`, and runs quilt | ✓ WIRED | Independently applied to fresh source. |
| Fresh patched source | four-package `dist` bundle | `dpkg-buildpackage` output -> Stage 8 validation -> Stage 9 copy | ✗ NOT SAFE | Stage 9 starts a new `ls ... | head -1` selection instead of retaining the Stage 8 `DEB_FILE`. |
| `xf_touch_internal.h` | `xf_input.c` | Shared classifier/bounds/pinch/quarantine helpers | ⚠ PARTIAL | Several helpers are called, but the declared `xf_force_cancel_emit_sequence` link is absent; GSD's pattern-only key-link result was a false positive from a comment/definition. |
| `xf_input_touch_remote` | local fallback recognizer | adjusted XI touch -> `xf_input_touch_fallback` | ✓ WIRED | The canonical `+touch-pinch-wheel-fallback` path selects `xf_input_handle_event_remote` and returns to the fallback recognizer; no `freerdp_client_handle_touch` call remains there. |
| `diagContacts` ingress | cancellation diagnostics | lifecycle snapshot/cancel/retire | ✗ DISCONNECTED | Ingress updates `diagContacts`, while cancellation reads `xfc->contacts` and native `cctx->contacts`; recovery-intercepted End never retires diagnostic contacts. |
| `scripts/menu` | `scripts/launch-touch.sh` | generated xinitrc `exec` | ⚠ PARTIAL | Works only at the fixed owner checkout path; package/docs do not establish that path for an installed user. |
| wrapper | `/usr/bin/xfreerdp3` | Bash argument arrays and direct exec/tee | ✓ WIRED | Fixture invokes the copied wrapper with the actual command construction. |

## Data-Flow Trace (Level 4)

| Artifact | Data variable / input | Source | Produces real data | Status |
|---|---|---|---|---|
| Release assembly | `DEB_FILE` | `/tmp` package glob after build | No trustworthy retained validation identity | ✗ UNSAFE FLOW |
| Diagnostics | `diagContacts` | real TouchBegin/Update/End ingress | Yes at ingress, but cancellation consumes different stores | ✗ HOLLOW AT CANCEL |
| Wrapper | calibration environment and forwarded args | shell environment / menu xinitrc | Real arrays reach `xfreerdp3` | ✓ FLOWING |
| Menu | wrapper path | fixed literal path | Only works for this checkout, not documented installation | ⚠ STATIC / NONRELOCATABLE |

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Fresh patch applies and source wiring is present | fresh `dpkg-source` + `quilt push -a` + `cmp` | Patch applied; five production files match current patched tree | ✓ PASS |
| Current bundle integrity | resolved `dist` `sha256sum -c`, `dpkg-deb -f` | Four expected amd64 `+onemix1` packages all pass | ✓ PASS |
| Live parser behavior | `bash tests/gap05_parser_check.sh "$(readlink -f dist)"` | All canonical/reject/overflow cases passed using extracted project libraries | ✓ PASS |
| Native-X11 negative gate | `bash tests/check_x11_session_check.sh` | Native scope and Wayland-negative cases passed | ✓ PASS |
| Menu diagnostic propagation | `bash tests/menu_diagnostic_env_check.sh` | Passed | ✓ PASS |
| Wrapper/menu fixture | `bash tests/wrapper_production_check.sh` | Passed, but idempotency statuses are forced to zero at lines 268-300 | ⚠ PARTIAL EVIDENCE |
| README command blocks | `bash tests/readme_doc_regression.sh` | Passed, but intentionally accepts a mismatched package-name fixture | ⚠ PARTIAL EVIDENCE |
| Signal publication fixture | `bash tests/build_release_signal_check.sh` | Passed, but fixture output includes `basename: invalid option -- 'c'`; its checksum-check shim does not model `sha256sum -c` | ⚠ PARTIAL EVIDENCE |
| Shared helper model | compiled `tests/xf_touch_internal_check.c` | 46 helper assertions passed | ⚠ HELPER-ONLY |
| Ownership layout | compiled `tests/gap01_ownership_layout.c` | Passed | ✓ PASS |
| Pinch reversal model | compiled `tests/pinch_reversal_check.c` | Passed, but is an integer mirrored model rather than current double production accumulator | ⚠ MODEL-ONLY |
| Ownership source checker | `python3 tests/check_third_finger_owner.py` | Passed, but its own Check 4 explicitly defers full runtime-writer proof | ⚠ PARTIAL EVIDENCE |

No full release build was rerun: it would be a multi-minute, stateful operation and would not establish safe publication while the source-level selection flaw is observable. The fresh quilt application and current-bundle/parser checks supplied the necessary independent evidence without treating SUMMARY claims as proof.

## Requirements Coverage

| Requirement | Source plans | Status | Evidence |
|---|---|---|---|
| `DIAG-01` | 04-01, 04-04, 04-06 | ✗ BLOCKED | Exact-1 caching and many records exist, but canonical fallback cancellation emits no correct per-contact cancels, retains diagnostic contacts, and does not use the claimed ordering helper. |
| `PACK-01` | 04-01, 04-05, 04-06 | ✗ BLOCKED | Patch application, current bundle structure, and manifests exist, but shared `/tmp` plus post-validation re-globbing permits publication of an unvalidated package. |
| `PACK-02` | 04-03, 04-05, 04-06 | ? NEEDS HUMAN | Explicit four-package documentation is sound for real `dpkg-query`, the current system is stock on all four packages, and a sanitized prior record exists. Actual patched-install/stock-rollback state transitions were not repeated here. |
| `CONF-01` | 04-02, 04-03, 04-04, 04-05, 04-06 | ✗ BLOCKED | Wrapper mechanics are implemented, but the documented preset is not provisioned/relocatable and the packaged local gesture lifecycle remains broken under interruption. |

All Phase 04 IDs are claimed by at least one PLAN frontmatter. There are no orphaned Phase 04 requirement IDs. The `[x]` markers in `REQUIREMENTS.md` and plan/SUMMARY completion claims were not used as verification evidence.

## Advisory Review Adjudication

| Finding | Adjudication | Impact |
|---|---|---|
| CR-01 `/p:` process-argument exposure | Confirmed handoff: `menu` constructs `/p:<value>` and wrapper forwards it. Long-lived `/proc` visibility was not independently timed, but protected argv transport is absent. | BLOCKER unless the owner explicitly accepts it separately from D-25. |
| CR-02 tracked diagnostic logs | Materially confirmed: both files are tracked and contain private-address plus account/domain-labelled metadata; broad ignore coverage is absent. The review's specific auto-reconnect-verifier detail was not independently corroborated. | BLOCKER privacy/artifact hygiene defect. |
| CR-03 shared `/tmp` package substitution | Confirmed. | BLOCKER for `PACK-01`. |
| CR-04 recovery gate prematurely disarmed | Confirmed at `xf_input.c:2092`, plus blind resets elsewhere. | BLOCKER for local lifecycle correctness. |
| CR-05 third arriving finger omitted | Confirmed: `{ A, B, 0, C }` with `suppCount == 3` passes only the first three array elements. | BLOCKER for local lifecycle correctness. |
| CR-06 stale three-finger pending state | Confirmed: pre-claim End returns after quarantine without clearing pending IDs/state. | BLOCKER for local lifecycle correctness. |
| WR-01 wrong diagnostic store / leak | Confirmed and elevated in effect because it directly blocks `DIAG-01`. | BLOCKER requirement impact. |
| WR-02 rotation/calibration failures still launch | Confirmed: generated xinitrc lacks `set -e` or setup-command status checks. | WARNING; add fail-closed handling before final UAT. |
| WR-03 wrapper idempotency test masks statuses | Confirmed at lines 268-300. | WARNING; behavior is not proven by this test. |
| WR-04 launcher not installed or relocatable | Confirmed by package-content inspection, README, and fixed path source. | BLOCKER for documented operation / `CONF-01`. |
| IN-01 `new.md` contradicts shipped local-only design | Confirmed. | INFO; archive/delete/label it, but it is not itself a phase-goal blocker. |

## Prohibitions and Accepted Exception

| Check | Status | Evidence |
|---|---|---|
| Do not reintroduce `+multitouch` or native RDPEI forwarding in the release preset | ✓ VERIFIED | Wrapper contains only `+touch-pinch-wheel-fallback`; canonical remote dispatcher returns to the local fallback recognizer. |
| Enable diagnostics only for exact `FREERDP_TOUCH_DIAG=1` | ✓ VERIFIED | X11, RDPEI, wrapper, and menu propagation all use an exact `"1"` predicate; focused environment regression passes. |
| Do not hold/pin over future Debian security updates | ✓ VERIFIED | No project hold/pin implementation; `apt-mark showhold` and relevant system preferences show no FreeRDP hold/pin. |
| Do not disclose credentials or connection material through release artifacts/diagnostics | ✗ FAILED | Tracked logs disclose sensitive metadata; `/p:` is forwarded as an argv token. |
| Do not document a broad package glob | ✓ VERIFIED | README uses four named package patterns and rejects zero/multiple matches for install. |
| Do not expose additional classifier tuning knobs | ? BACKSTOP / HUMAN | No extra wrapper knobs were found, but the PLAN explicitly classifies this non-inferable prohibition as a backstop. |

**Locked D-25 exception:** “GAP-07 remains USER-DEFERRED, /cert:ignore is expected for v1, and server certificate identity must not be claimed as verified.” This accepted certificate-identity exception is not listed as a newly failed requirement and does not excuse any other gap above.

## Anti-Patterns Found

| File | Line(s) | Pattern | Severity | Impact |
|---|---:|---|---|---|
| `scripts/build-release.sh` | 82, 213-215 | `mktemp -u` and post-validation glob selection | BLOCKER | Unsafe publication provenance. |
| `xf_input.c` | 949-951, 1421, 1457, 1488, 1528, 1830, 2092 | Direct quarantine/gate writers outside claimed owner | BLOCKER | Recovery gate can admit/lose contacts incorrectly. |
| `xf_input.c` | 1710-1724 | Cancellation reads inactive stores rather than `diagContacts` | BLOCKER | Missing/stale local cancellation diagnostics. |
| `xf_touch_internal.h` | 229 | Comment claims helper is called exactly once; it has no production call | BLOCKER | Tested helper is orphaned. |
| `tests/wrapper_production_check.sh` | 268-300 | `|| rc=0` / `|| true` force observed statuses to zero | WARNING | Idempotency outcome is untested. |
| `tests/readme_doc_regression.sh` | 192-202 | Mismatched package-name fixture is explicitly accepted | WARNING | Does not prove the stronger stated mismatch rejection. |
| `tests/build_release_signal_check.sh` | 87-92 | `sha256sum` shim treats `-c` as a filename and still succeeds | WARNING | Fixture reaches signal markers without exercising checksum validation. |
| `xf_input.c` | 2161 | `XXX` comment | INFO | Pre-existing upstream context: it is not added by `onemix-touch.patch`, so it is not counted as Phase 04 unresolved debt. |

## Human Verification After Gap Repair

### 1. Exact four-package install and rollback

**Test:** From a native-X11/TTY environment, checksum the repaired bundle, install the exact patched four-package closure twice, then restore the exact stock closure twice.

**Expected:** Every transaction succeeds; all four identities match the expected version after each step; stock mouse-only launch reaches the desktop after rollback.

**Why human:** This changes package state and requires the physical target; repository tests use mocks.

### 2. Cancellation and recovery lifecycle

**Test:** Start a two- and three-finger gesture, induce focus/fullscreen/disconnect cancellation, send an Update and one old-finger End, then lift all old fingers and perform a fresh tap.

**Expected:** New touches stay blocked until the final old End; no button/Ctrl remains held; all original IDs are quarantined; after the final End the next fresh gesture works normally.

**Why human:** The actual XI2 dispatcher and physical contact ordering require the native X11 touchscreen.

### 3. Local-only diagnostic cancellation trace

**Test:** Run `FREERDP_TOUCH_DIAG=1 menu`, trigger cancellation during an active local gesture, then inspect the private log without copying sensitive content.

**Expected:** One last-coordinate cancel per active fallback finger, an exact summary with `native_count=0`, diagnostic-store cleanup, and no new `touch-diag:` output or log file in a normal launch.

**Why human:** The present source demonstrably fails this path; after repair it needs live XInput2 evidence.

## Gaps Summary

There are no later roadmap phases that explicitly schedule these defects, so none is deferred by Step 9b. Repair the unsafe release boundary first, then repair the real dispatcher and diagnostic lifecycle, provision a relocatable launcher, remove confidential generated artifacts, and resolve the password transport. Rebuild from the repaired patch before repeating native-device install/rollback and gesture UAT.

---

_Verified: 2026-08-09T15:30:00Z_  
_Verifier: Claude (gsd-verifier)_

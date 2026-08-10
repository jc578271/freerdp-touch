---
phase: 04-diagnostics-packaging-launch-configuration
verified: 2026-08-10T00:06:54Z
status: gaps_found
score: 0/4 roadmap must-haves verified
behavior_unverified: 2
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 0/4
  gaps_closed:
    - "The real XI2 dispatcher now preserves quarantine through stale Update, partial End, repeated cancellation, final End, and fresh Begin."
    - "Local-only cancellation diagnostics now use adjusted diagContacts, emit one native_count=0 summary, and retire the store."
    - "Third-finger supplemental IDs and pending-three-finger cleanup are covered by the production dispatcher regression."
    - "The refreshed quilt patch applies in a new Debian extraction and passes the focused dispatcher CTest and ownership checker."
  gaps_remaining:
    - "Release publication does not bind the Stage 8 validation result to the Stage 9 payload copied into dist."
    - "The packaged install does not provide, document deployment of, or relocate the documented menu launcher."
    - "Tracked diagnostic artifacts and the menu retain connection/session material; password argv transport remains unresolved."
  regressions:
    - "The current dist bundle predates the Plan 04-07 patch repair, so it cannot be evidence that the repaired dispatcher ships."
    - "The signal fixture still does not isolate its classifier output under fixture TMPDIR and its sha256sum shim does not faithfully implement -c."
    - "The committed wrapper idempotency fixture masks statuses, although an independent verifier check confirmed the wrapper itself is deterministic."
gaps:
  - truth: "A reproducible release publishes only the exact four package files validated from the fresh pinned patch build."
    status: failed
    reason: "The release script reserves an unowned path with mktemp -u, validates package paths in Stage 8, then discards them and re-globs the same filenames in Stage 9. An independent scratch probe mutated the exact freerdp3-x11 pathname after validation; the script completed and published the mutated bytes with a new checksum."
    artifacts:
      - path: "scripts/build-release.sh"
        issue: "Stage 3 uses mktemp -u at lines 82-84; Stage 9 reselects files with ls/head at lines 213-215 instead of copying retained Stage 8 inputs."
      - path: "dist"
        issue: "The current valid-looking four-package bundle was built before Plan 04-07 and is not a bundle of the current repaired patch."
      - path: "tests/build_release_signal_check.sh"
        issue: "The signal fixture does not set or enforce fixture-local TMPDIR for the classifier and its sha256sum shim accepts -c incorrectly."
    missing:
      - "Create an owned private build root with mktemp -d and extract beneath it."
      - "Retain validated package paths in an array, copy only those paths, then validate the copied bundle metadata and checksums before publication."
      - "Add an adversarial regression that replaces a validated pathname between validation and bundle assembly and requires publication to fail."
      - "Rebuild dist only after the corrected publication path is in place."
  - truth: "A user following documented package installation can invoke the documented local-only launch preset."
    status: failed
    reason: "The four Debian packages install only xfreerdp3 and libraries; none installs menu, launch-touch.sh, or check-x11-session.sh. README documents bare menu without a provisioning step, while scripts/menu hard-codes the owner checkout path for launch-touch.sh."
    artifacts:
      - path: "README.md"
        issue: "Documents menu but does not document installation/deployment of the launcher or a relocatable repository-relative invocation."
      - path: "scripts/menu"
        issue: "Generated xinitrc invokes a fixed owner-specific checkout path."
      - path: "dist/freerdp3-x11_*.deb"
        issue: "Package-content inspection found /usr/bin/xfreerdp3 only; no launch scripts are shipped by any package in the closure."
    missing:
      - "Either package the launcher/gate/menu artifacts or document an explicit supported deployment step."
      - "Resolve the wrapper relative to an installed launcher location or supported checkout, not a fixed owner path."
      - "Add a package-only or clean-checkout launch regression."
  - truth: "Release and launch artifacts do not retain private connection/session material."
    status: failed
    reason: "Both tracked rdp-debug log artifacts contain valid IP literals including a private address, and .gitignore does not protect the rdp-debug*.log pattern. scripts/menu also contains hard-coded endpoint and account arguments."
    artifacts:
      - path: "rdp-debug-gestures.log"
        issue: "Tracked generated diagnostic artifact contains connection metadata."
      - path: "rdp-debug-native.log"
        issue: "Tracked generated diagnostic artifact contains connection metadata."
      - path: ".gitignore"
        issue: "Does not ignore rdp-debug*.log."
      - path: "scripts/menu"
        issue: "Stores fixed connection endpoint/account arguments in a committed launcher."
    missing:
      - "Remove or redact generated diagnostic artifacts according to the repository publication policy and ignore the broad diagnostic-log pattern."
      - "Remove owner-specific connection arguments from the committed launcher and use a supported user-supplied configuration boundary."
  - truth: "The menu-to-client password handoff has an explicitly accepted protection model."
    status: partial
    reason: "The menu reads the password, serializes a /p: argument into a private temporary xinitrc, and the wrapper forwards it to xfreerdp3. Private file modes reduce file exposure but do not establish protection from process-argument observation. This is not covered by the user's D-25 certificate exception."
    artifacts:
      - path: "scripts/menu"
        issue: "Constructs and serializes the password argv token into the generated xinitrc."
      - path: "scripts/launch-touch.sh"
        issue: "Forwards opaque connection arguments to the client as intended."
    missing:
      - "Choose a supported protected credential mechanism, or record a separate explicit owner acceptance for this argv transport risk."
deferred:
  - truth: "GAP-07 certificate hardening"
    addressed_in: "Future owner-requested requirement or phase"
    evidence: "GAP-07 is USER-DEFERRED under D-25. /cert:ignore remains expected with accepted HIGH server-impersonation/MITM risk; certificate identity is not verified."
behavior_unverified_items:
  - truth: "The user can install the patched four-package closure and restore the stock closure using the documented commands."
    test: "After release publication and launcher gaps are repaired, run the exact patched four-package install twice and the exact stock rollback twice on the native-X11 device."
    expected: "Each transaction succeeds; all four identities match the intended version after each transaction; a stock mouse-only launch works after rollback."
    why_human: "Repository regressions mock apt and this verification intentionally did not mutate the installed package state."
  - truth: "Exact-1 diagnostics record the complete runtime XInput2/RDPEI lifecycle while normal hardware launches remain quiet."
    test: "On native X11, run a diagnostic menu session, exercise touch lifecycle and an interruption, then run a normal session with diagnostics unset."
    expected: "The private diagnostic log has ingress, gesture, synthesis, cancellation, and applicable RDPEI frame records; normal mode creates no diagnostic log or touch-diag output."
    why_human: "Focused CTests exercise the actual dispatcher with synthetic cookies, but no test in this verification drives a physical XI2 device and live RDPEI session through the exact environment gate."
---

# Phase 04: Diagnostics, Packaging & Launch Configuration Verification Report

**Phase Goal:** The verified patch ships as an installable Debian package with env-var-gated diagnostics and a documented launch preset that a user can install, roll back, and operate.

**Verified:** 2026-08-10T00:06:54Z  
**Status:** gaps_found  
**Re-verification:** Yes — prior gaps were rechecked against source, fresh quilt extraction, focused tests, package contents, and independent scratch probes.

## Verdict

The phase goal is **not achieved**.

Plan 04-07 repaired the previously broken dispatcher and canonical diagnostic lifecycle in the current source and quilt patch. That repair is substantive: it passed both the focused production-dispatcher CTest and a second, independently performed fresh Debian-source/quilt/CMake/CTest/checker run.

However, the phase still cannot ship:

1. `scripts/build-release.sh` can publish bytes that were not the Stage 8 validated package bytes. A verifier scratch probe demonstrated that exact failure path.
2. The current `dist` bundle predates the Plan 04-07 repair; it cannot demonstrate that the repaired dispatcher is in the shipped package.
3. The four-package closure does not install the documented `menu` launcher or its wrapper/gate dependencies, and the launcher uses a fixed owner checkout path not documented for users.
4. Tracked diagnostic logs and the committed menu retain connection/session material. The password `/p:` argv design also requires a separate owner decision; D-25 accepts only the certificate exception.

The valid checksums, correct package names, passing parser fixture, and passing synthetic dispatcher tests are real evidence, but they do not reverse these delivery failures.

## Goal Achievement

### Roadmap Success Criteria

| # | Roadmap contract | Status | Evidence |
|---|---|---|---|
| 1 | Reproducibly build an installable pinned Debian `.deb` using the documented quilt patch. | FAILED | Fresh quilt application and focused build/test work, but the publisher reserves an unowned `/tmp` path and reselects package paths after validation. The independent mutation probe published altered post-validation bytes successfully. |
| 2 | Install patched packages and restore stock Debian packages using documented, verified commands. | PRESENT_BEHAVIOR_UNVERIFIED | README has explicit four-package commands and its mock regression passes. No fresh state-changing install/rollback was performed, and safe package provenance is currently failed. |
| 3 | Launch a documented local-only preset with calibration and a mouse-only escape hatch. | FAILED | Wrapper behavior is implemented and independently exercised, but the package installs no launcher and README's bare `menu` path is neither provisioned nor relocatable. |
| 4 | Enable opt-in lifecycle/gesture/RDPEI diagnostics while normal launches remain quiet. | PRESENT_BEHAVIOR_UNVERIFIED | Exact cached gates, diagnostic source paths, production dispatcher CTest, and fresh quilt proof pass. Physical XI2/RDPEI runtime behavior and normal quiet mode were not independently exercised. The current bundle also predates the repair. |

**Score:** 0/4 roadmap truths verified (2 present but behavior-unverified).

## Re-verification Results

### Closed Prior Gaps

| Prior concern | Result | Independent evidence |
|---|---|---|
| Quarantine recovery through actual XI2 dispatcher | VERIFIED | `TestXfInputDispatcher` passed the Begin(A), Begin(B), cancel, stale Update, partial End, repeat cancel, final End, fresh Begin sequence. |
| Local-only cancellation diagnostic source and retirement | VERIFIED | CTest captured adjusted-coordinate cancel records, one `native_count=0` summary, and diagnostic-store retirement through the production lifecycle owner. |
| Third-finger supplemental ID compaction and pre-claim cleanup | VERIFIED | Dispatcher CTest and `check_third_finger_owner.py` passed. |
| Shipping quilt synchronization | VERIFIED | A new `dpkg-source` extraction accepted the patch through the full quilt stack; source/CMake/test artifacts matched; focused target build, CTest, and checker passed. |

### Remaining Release-Delivery Failures

The source of truth for a release is the validated payload, not the filename or a later checksum. The current release path has this invalid data flow:

```text
Stage 8: select pathname -> validate metadata
Stage 9: discard pathname -> re-glob pathname -> copy -> checksum copied bytes -> publish
```

The script uses `mktemp -u` for the extraction name and later re-globs `DEB_FILE` with `ls ... | head -1`. In an isolated verifier fixture, the exact expected package filename was mutated after Stage 8 validation and before Stage 9. The unmodified publication logic returned success, generated checksums for the changed file, and published it. This disproves the claimed validated-fresh-output guarantee.

The current `dist` symlink is structurally valid: it is relative, resolves inside the repository, contains exactly four expected `amd64` `+onemix1` files, and `sha256sum -c` succeeds. Its bundle timestamp is earlier than the Plan 04-07 commits and patch modification, so it is not evidence for the repaired dispatcher shipping.

## Plan Frontmatter Must-Have Accounting

All 68 truth-level PLAN declarations were checked. `BACKSTOP / HUMAN` means the PLAN explicitly marked the assertion as non-inferable or it requires a live user/device observation; it is not counted as verified.

| Plan | Declared | Verified | Failed | Present, behavior-unverified | Backstop / human |
|---|---:|---:|---:|---:|---:|
| 04-01 | 9 | 2 | 2 | 4 | 1 |
| 04-02 | 11 | 9 | 0 | 1 | 1 |
| 04-03 | 10 | 7 | 0 | 2 | 1 |
| 04-04 | 12 | 11 | 0 | 1 | 0 |
| 04-05 | 12 | 9 | 1 | 2 | 0 |
| 04-06 | 10 | 2 | 3 | 5 | 0 |
| 04-07 | 4 | 4 | 0 | 0 | 0 |
| **Total** | **68** | **44** | **6** | **15** | **3** |

### 04-01 Must-Haves

| # | Assertion, abridged only for table width | Status | Evidence |
|---|---|---|---|
| 1 | Exact-1 core diagnostic records; other values quiet | PRESENT_BEHAVIOR_UNVERIFIED | Cached exact predicate and record sites are present; physical XI2/RDPEI session was not run. |
| 2 | Disabled diagnostic gate changes no gesture behavior | PRESENT_BEHAVIOR_UNVERIFIED | Gate is conditional, but disabled-path equivalence is a runtime invariant with no focused transition test. |
| 3 | Fresh patch builds a four-package `+onemix1` closure | FAILED | Fresh patch compiles/CTest passes, but safe package publication and a current package rebuild are absent. |
| 4 | `dist` is relative and has exactly four packages plus checksums | VERIFIED | Independently checked current link, closure, metadata, and checksum file. |
| 5 | Two clean builds have identical normalized closure | PRESENT_BEHAVIOR_UNVERIFIED | Historical manifests match but are not independent execution evidence; the producer is unsafe. |
| 6 | Lock/trap/atomic publisher cannot corrupt prior valid output | FAILED | Atomic pointer swap exists, but `mktemp -u` and post-validation re-globbing invalidate the full guarantee. |
| 7 | No APT hold/pin blocks security updates | VERIFIED | No project hold/pin implementation was found; README explicitly documents no hold/pin. |
| 8 | Cached RDPEI gate and conditional cancellation/frame diagnostics | PRESENT_BEHAVIOR_UNVERIFIED | Source has cached exact gate and one frame record; live RDPEI frame submission was not exercised. |
| 9 | Diagnostic record contents never contain command/credential material | BACKSTOP / HUMAN | Source format strings are compact touch fields, but tracked generated diagnostic artifacts retain connection metadata. |

### 04-02 Must-Haves

| # | Assertion, abridged | Status | Evidence |
|---|---|---|---|
| 1 | Wrapper composes local fallback flags and omits `+multitouch` | VERIFIED | Source plus independent wrapper invocation check. |
| 2 | Defaults are 600 ms and 8 px without prompt | VERIFIED | Source and copied-wrapper fixture. |
| 3 | Calibration accepts bounded canonical decimal input and rejects invalid values before client invocation | VERIFIED | Independent wrapper check covered normal, leading-zero rejection, range behavior, and no-client rejection. |
| 4 | `--mouse-only` removes touch options and bypasses calibration validation | VERIFIED | Independently invoked with invalid calibration; client received only forwarded connection argument. |
| 5 | Exact-1 wrapper diagnostics create private timestamped log and preserve client status | VERIFIED | Independent wrapper check verified 0700 directory, 0600 file, filename pattern, tee content, and exit 42 propagation. |
| 6 | Non-1 wrapper diagnostics use direct client with no log | VERIFIED | Independent `0` and `false` checks preserved client statuses and created no state directory. |
| 7 | Wrapper does not echo/eval/log forwarded opaque args | VERIFIED | Static scan and mocked forwarding path show arrays/direct exec/tee only; no echo, eval, or WLOG setting. |
| 8 | Menu xinitrc handoff preserves prompt, rotation/startx flow, and private cleanup | PRESENT_BEHAVIOR_UNVERIFIED | Source and direct-xinitrc fixture pass; real TTY/startx/rotation interaction was not exercised. |
| 9 | Menu accepts only `--mouse-only` and forwards it correctly | VERIFIED | Source parser and menu fixture cover the supported mode. |
| 10 | Exact diagnostic environment propagates through xinitrc | VERIFIED | `menu_diagnostic_env_check.sh` passed normal, diagnostic, and mouse-only cases. |
| 11 | No extra classifier tuning knobs exposed | BACKSTOP / HUMAN | No extra wrapper flags found; PLAN marks this non-inferable. |

### 04-03 Must-Haves

| # | Assertion, abridged | Status | Evidence |
|---|---|---|---|
| 1 | README documents explicit four-package install with `--allow-downgrades` | VERIFIED | Current marked install block and README regression. |
| 2 | README documents four-package rollback and stock assertion | VERIFIED | Current marked rollback block and README regression branches. |
| 3 | README documents fail-closed security-update rebase without hold/pin | VERIFIED | Source documentation checked. |
| 4 | README documents normal/diagnostic/calibration/mouse-only modes | VERIFIED | Source documentation checked. |
| 5 | README examples are sanitized | VERIFIED | No password argument or valid IP literal found in README examples. |
| 6 | Device install, gestures, diagnostics, mouse-only, and rollback succeeded | PRESENT_BEHAVIOR_UNVERIFIED | Structured record exists but is prior narration; no device/package-state mutation was repeated. |
| 7 | 04-03 verification record has deterministic ten-section grammar | VERIFIED | Independently checked ten headings, ten `Actual: PASS` fields, UTF-8/CR/escape surface, and forbidden-token surface. |
| 8 | Normal launch is quiet and adds no diagnostic log | PRESENT_BEHAVIOR_UNVERIFIED | Prior record claims it; no independent normal device session ran. |
| 9 | Documentation limits device checks to the three menu invocations | VERIFIED | README documents the locked normal, diagnostic, and mouse-only menu paths. |
| 10 | Installed patched and stock versions were actually observed | BACKSTOP / HUMAN | Requires a fresh device transaction. |

### 04-04 Must-Haves

| # | Assertion, abridged | Status | Evidence |
|---|---|---|---|
| 1 | Ownership events use `XITouchOwnershipEvent` and never enter touch coordinate processing | VERIFIED | Source wiring plus ownership-layout regression passed. |
| 2 | `xf_quarantine_update` is the production runtime owner | VERIFIED | Source checker and actual dispatcher CTest passed. |
| 3 | Bounds gate rejects only Begin and lets Update/End clean up | VERIFIED | Shared-helper regression and direct source wiring passed. |
| 4 | Fractional double pinch accumulation and safe diagnostic formats | VERIFIED | 46-assert helper regression, pinch reversal check, and source checker passed. |
| 5 | Parser uses checked canonical `strtoul` validation | VERIFIED | Isolated four-package live parser fixture passed accepted, malformed, range, leading-zero, and overflow cases. |
| 6 | Parser fixture loads all project libraries from its extracted four-package root | VERIFIED | `gap05_parser_check.sh` passed loader-origin checks and cases. |
| 7 | Cached gate and duplicate Begin diagnostic-store idempotency | PRESENT_BEHAVIOR_UNVERIFIED | Shared helper and source structure support it, but the exact public-dispatcher duplicate-Begin transition lacks a focused test. |
| 8 | Single-threaded cancellation ordering is deterministic | VERIFIED | Production lifecycle CTest covers local records; production-shared helper covers synthetic native ordering. |
| 9 | Lifecycle calls ordered cancellation helper once and reports `native_count=0` locally | VERIFIED | Source checker plus CTest captured local-only summary. |
| 10 | Thin force-cancel wrapper and third-finger owner path | VERIFIED | Checker and dispatcher CTest passed. |
| 11 | Repeat cancel, End drain, fresh Begin lifecycle regression | VERIFIED | `TestXfInputDispatcher` passed. |
| 12 | Listed production-path regressions compile/pass | VERIFIED | Focused helper, ownership, parser, source checker, pinch, and static RDPEI checks were independently run. |

### 04-05 Must-Haves

| # | Assertion, abridged | Status | Evidence |
|---|---|---|---|
| 1 | Shell validation rejects overlong/noncanonical values | VERIFIED | Independent wrapper behavior probe passed. |
| 2 | EXIT-only cleanup and signal preservation protect publication | PRESENT_BEHAVIOR_UNVERIFIED | Source and scratch signal cases support the trap behavior, but fixture checksum fidelity is defective and no corrected real publisher run was made. |
| 3 | Per-publisher classifier output uses `mktemp` and cleanup state | VERIFIED | Source creates/removes unique classifier output; fixture observed distinct dynamic targets. |
| 4 | Signal fixture has complete fixture-local shims and faithful publication proof | FAILED | Fixture does not set/enforce fixture-local TMPDIR for classifier output; its `sha256sum` shim mishandles `-c` yet exits success. |
| 5 | Tracked/deployed menu parity and startx status propagation | VERIFIED | `/usr/local/bin/menu` is mode 0755 and byte-identical; source has status handling and one expected `/cert:ignore`. |
| 6 | Wrapper/menu production-path fixture covers listed mocked cases | VERIFIED | Fixture passed normal, diagnostics, mouse-only, calibration, opaque args, client failure, and startx status paths. |
| 7 | Wrapper validation is deterministic across fresh processes | VERIFIED | Committed fixture masks statuses, but an independent verifier probe correctly preserved and compared repeated valid/invalid statuses and output. |
| 8 | X11 gate rejects both Wayland indicators | VERIFIED | Focused gate regression passed. |
| 9 | README checksum uses a subshell | VERIFIED | README regression passed cwd-preservation check. |
| 10 | Rollback requires four query results before stock result | VERIFIED | Source and README regression cover query failure/incomplete results. |
| 11 | Exact install/rollback blocks are idempotent and reject every mismatch | PRESENT_BEHAVIOR_UNVERIFIED | Mocked repeat runs pass, but the committed regression intentionally accepts a mismatched-name fixture and no real apt transaction was repeated. |
| 12 | D-25 certificate exception remains deferred rather than passed | VERIFIED | README and phase materials state the deferral correctly. |

### 04-06 Must-Haves

| # | Assertion, abridged | Status | Evidence |
|---|---|---|---|
| 1 | Every release run safely publishes exact pinned validated closure | FAILED | Release provenance flaw is directly demonstrated; current bundle is older than Plan 04-07. |
| 2 | Two independent releases have durable matching manifests | PRESENT_BEHAVIOR_UNVERIFIED | Files match structurally, but historical manifests are not independent execution proof and producer safety is false. |
| 3 | Final parser fixture uses exact isolated four-package bundle | VERIFIED | Independently passed against current bundle. |
| 4 | Scratch signal fixture faithfully proves dynamic output/checksum/publication behavior | FAILED | Missing fixture TMPDIR isolation and invalid `sha256sum -c` shim invalidate the complete assertion. |
| 5 | Live PRE/POST process-group interruption cases are proven | PRESENT_BEHAVIOR_UNVERIFIED | Durable prior snapshots exist; the multi-minute stateful live publisher process was not rerun. |
| 6 | Every non-certificate automated regression passes with complete evidence | FAILED | The release fixture defects remain and package provenance is false; aggregate green narration is not accepted. |
| 7 | Native device diagnostics prove local-only last-coordinate cancellation and quiet behavior | PRESENT_BEHAVIOR_UNVERIFIED | Requires a physical X11 touch/RDP session; prior record is not fresh evidence. |
| 8 | Final exact patched install and stock rollback run twice | PRESENT_BEHAVIOR_UNVERIFIED | README mock regression passes; no system package state was changed. |
| 9 | Deployed menu parity and ten-section device record are valid | PRESENT_BEHAVIOR_UNVERIFIED | Parity and record grammar are verified, but operational PASS claims require device confirmation. |
| 10 | GAP-07 is reported user-deferred, not certificate-passed | VERIFIED | Correctly stated in README, plans, and this report. |

### 04-07 Must-Haves

| # | Assertion, abridged | Status | Evidence |
|---|---|---|---|
| 1 | Old Update/non-final End stay quarantined; final End admits fresh touch | VERIFIED | Focused public-dispatcher CTest passed. |
| 2 | Adjusted `diagContacts` cancellation records, one local summary, store retirement | VERIFIED | Captured production WLog assertions passed. |
| 3 | Third-finger supplemental IDs and pre-claim field cleanup | VERIFIED | Dispatcher CTest and scoped ownership checker passed. |
| 4 | Fresh quilt source applies and passes real dispatcher test/checker | VERIFIED | Independently repeated fresh extraction, quilt push, artifact comparison, CMake target build, CTest, and checker. |

## Required Artifacts and Key Links

| Artifact/link | Status | Evidence |
|---|---|---|
| `patches/onemix-touch.patch` -> fresh Debian source | VERIFIED | Full quilt-stack application, source/CMake/test comparison, target build, CTest, and checker passed in a newly created workspace. |
| Fresh patched source -> current distributable package | FAILED | No post-04-07 full package publication exists; current `dist` predates the repair. |
| `scripts/build-release.sh` Stage 8 -> Stage 9 -> `dist` | FAILED | Validation identity is discarded and re-globbed; independent mutation probe demonstrated publication of altered bytes. |
| Current `dist` -> four-package metadata/checksums | VERIFIED AS STRUCTURE ONLY | Relative symlink, four expected names, `amd64`, expected version, and all checksums passed. This is not provenance evidence. |
| `xf_input_handle_event` -> XI2 dispatcher -> quarantine/diagnostic lifecycle | VERIFIED IN SOURCE/PATCH | Public-dispatcher CTest and source checker exercise actual production wiring. |
| `scripts/launch-touch.sh` -> installed `xfreerdp3` | VERIFIED | Direct copied-wrapper behavior probe preserved args/statuses and validated diagnostic filesystem behavior. |
| `menu` -> wrapper -> installed client | FAILED AS INSTALLABLE USER FLOW | xinitrc link is fixed to an owner checkout and none of the Debian packages installs the required scripts. |
| README -> package install/rollback | PARTIAL | Explicit four-package command blocks are substantive and mocked; live package transaction remains unverified. |

### Data-Flow Trace

| Dynamic artifact | Input/source | Trace result |
|---|---|---|
| Release bundle | Build output in parent of unowned `/tmp` work path | UNSAFE: Stage 9 performs a second selection after Stage 8 validation. |
| Current package contents | Old `dist` bundle | STALE: bundle timestamps precede the Plan 04-07 source/patch commits. |
| Local diagnostics | Exact cached environment gate -> adjusted coordinates -> `diagContacts` -> lifecycle callback -> WLog | FLOWING IN SOURCE: production dispatcher CTest and fresh-patch CTest passed; live hardware/RDPEI flow remains unexercised. |
| Wrapper diagnostics | Exact wrapper environment gate -> private state directory/log -> tee -> `PIPESTATUS[0]` | FLOWING: independent mock-client test verified modes, permissions, content, and status propagation. |
| Menu launch | README bare command -> externally copied `/usr/local/bin/menu` -> fixed checkout wrapper | HOLLOW FOR PACKAGE-ONLY USER: launcher assets are absent from package and deployment is undocumented. |

## Behavioral Spot-Checks

| Behavior | Independent command/check | Result |
|---|---|---|
| Production XI2 dispatcher regression | Focused `ctest -R '^TestXfInputDispatcher$'` | PASS (1/1). |
| X11 ownership/lifecycle source invariant | `python3 tests/check_third_finger_owner.py .../xf_input.c` | PASS. |
| Fresh quilt synchronization | New `dpkg-source`, full `quilt push -a`, artifact compare, CMake target build, CTest, checker | PASS. |
| Shared X11 helpers, ownership layout, classifier, pinch reversal | Focused compile/run probes | PASS. |
| Isolated package loader/parser behavior | `bash tests/gap05_parser_check.sh "$(readlink -f dist)"` | PASS; project SONAMEs resolved under extraction root. |
| Wrapper normal/non-1/diagnostic/mouse-only behavior | Independent copied-wrapper mock probe | PASS; normal statuses 37/38, diagnostic status 42, correct permissions and no non-1 log. |
| Wrapper fresh-process idempotency | Independent copied-wrapper probe without status masking | PASS; repeated valid status 23/output match and repeated invalid status 1/error match. |
| Menu diagnostic propagation | `bash tests/menu_diagnostic_env_check.sh` | PASS. |
| README command blocks | `bash tests/readme_doc_regression.sh` | PASS with test-quality warning below. |
| Signal fixture | `bash tests/build_release_signal_check.sh` | PASS with test-quality failure below; it is not complete evidence for release integrity. |
| Current bundle metadata/checksums | `dpkg-deb -f` and `sha256sum -c` on resolved `dist` | PASS structurally. |
| Stage 8-to-Stage 9 binding | Independent isolated mutation probe | FAIL: altered post-validation bytes were published successfully. |
| Package launcher delivery | `dpkg-deb -c` across all four packages | FAIL: no menu, wrapper, or X11 gate script is installed. |

## Requirements Coverage

| Requirement | Source plans | Status | Evidence |
|---|---|---|---|
| `DIAG-01` | 04-01, 04-04, 04-06, 04-07 | NEEDS HUMAN | Core source, production dispatcher test, and fresh quilt proof are now substantive. A current package rebuild and native-X11/RDPEI behavior check are still required. |
| `PACK-01` | 04-01, 04-05, 04-06 | BLOCKED | Unsafe release provenance is demonstrated; current bundle is stale relative to the repaired patch. |
| `PACK-02` | 04-03, 04-05, 04-06 | BLOCKED | Documentation is substantially improved, but safe package provenance is blocked and live patched-install/stock-rollback transactions are not independently verified. |
| `CONF-01` | 04-02, 04-03, 04-04, 04-05, 04-06, 04-07 | BLOCKED | Wrapper/preset mechanics are present, but a package-only user cannot obtain the documented launcher and its fixed location is not portable. |

All four Phase 04 requirement IDs are claimed by PLAN frontmatter. No requirement is orphaned.

## Prohibitions and Security Scope

| Prohibition / decision | Status | Evidence |
|---|---|---|
| Do not reintroduce `+multitouch` or native forwarding in the launch preset | VERIFIED | Wrapper/menu use local fallback; no `+multitouch` activation found. |
| Enable wrapper/core diagnostics only for exact `FREERDP_TOUCH_DIAG=1` | VERIFIED IN SOURCE/WRAPPER | X11 and RDPEI cache exact `"1"`; direct wrapper behavior tested `0`, `false`, and `1`. Physical core behavior remains in human verification. |
| Do not hold/pin the local package over Debian updates | VERIFIED | No hold/pin behavior found; README documents no hold/pin. |
| Do not use broad package install globs | VERIFIED | README resolves four named closure identities and fails closed on zero/multiple shell matches. |
| Do not retain/log credentials or opaque connection arguments in launch artifacts | FAILED | Tracked diagnostic logs retain connection metadata; committed menu stores hard-coded connection args. Password argv transport also lacks a separate acceptance decision. |
| Do not expose classifier constants as user controls | BACKSTOP / HUMAN | No added controls found, but this PLAN item is explicitly non-inferable. |
| D-25 certificate exception | USER-DEFERRED | GAP-07 certificate hardening is explicitly USER-DEFERRED under D-25. `/cert:ignore` remains with accepted HIGH MITM/server-impersonation risk. Certificate identity protection is not claimed. |

## Anti-Patterns and Test-Evidence Limits

| File | Finding | Severity | Impact |
|---|---|---|---|
| `scripts/build-release.sh` | `mktemp -u` plus post-validation `ls ... | head -1` selection | BLOCKER | Validated-build provenance is false. |
| `tests/build_release_signal_check.sh` | Does not constrain classifier output to fixture `TMPDIR`; mocked `sha256sum` mishandles `-c` and still returns success | BLOCKER for its declared fixture truth | It cannot certify the complete release path claimed by Plans 04-05/04-06. |
| `tests/wrapper_production_check.sh` | Idempotency portions use `|| rc=0` / `|| true`, masking actual statuses | WARNING | The committed test does not prove its stated status comparison, though independent verifier coverage passed. |
| `tests/readme_doc_regression.sh` | Mismatched package-name fixture is intentionally accepted | WARNING | The regression does not prove every stated mismatch rejection. |
| `scripts/menu` | Hard-coded connection args and fixed checkout path | BLOCKER | Privacy issue and nonportable deployment path. |
| `rdp-debug-gestures.log`, `rdp-debug-native.log` | Tracked diagnostic output includes private connection metadata | BLOCKER | Violates artifact hygiene and can disclose session information. |
| `xf_input.c` | Existing upstream `XXX` comment outside patch additions | INFO | No Phase 04 patch addition introduced a `TBD`, `FIXME`, or `XXX` marker; this inherited context is not counted as new phase debt. |

## Escalation Gate: Password Argument Transport

A separate developer decision is required. The code intentionally reads the password interactively and handles it in a private temporary xinitrc, but it serializes `/p:<value>` and passes it through the wrapper to the client. Private file permissions are not proof that process arguments are protected. This exposure is distinct from the accepted certificate exception and must not be silently treated as D-25 acceptance.

Choose one of the following before declaring the launch flow security-complete:

1. Replace argv password transport with a supported protected mechanism; or
2. Explicitly accept the scoped argv exposure in a decision separate from D-25, including its platform assumptions.

## Human Verification Required After Gap Repair

### 1. Exact Four-Package Install and Rollback

**Test:** On the native-X11 device, checksum the newly rebuilt bundle, install the exact patched closure twice, then restore the exact stock closure twice.

**Expected:** Each transaction succeeds; all four package identities match the expected local or stock versions; the stock mouse-only launch works after rollback.

**Why human:** This verification does not mutate system package state.

### 2. Diagnostic and Interruption Flow on Physical XI2/RDPEI

**Test:** Run `FREERDP_TOUCH_DIAG=1 menu` after launcher deployment is repaired. Trigger touch Begin/Update/End, a local gesture decision, and interruption during an active gesture. Then run normal `menu` with diagnostics unset.

**Expected:** Diagnostic mode records adjusted-coordinate local cancellation, one matching `native_count=0` summary, synthesis/gesture events, and applicable RDPEI frame records. Normal mode creates no diagnostic file or `touch-diag:` output.

**Why human:** Synthetic dispatcher CTests do not replace the physical XI2/RDP session.

### 3. Package-Only or Clean-Checkout Launch

**Test:** Follow README from a package-only installation or a documented fresh checkout location, then invoke the documented menu path.

**Expected:** The launcher/gate/wrapper resolve without owner-specific paths; normal, diagnostic, and mouse-only modes start as documented.

**Why human:** Current package contents conclusively fail this; a repaired deployment design needs user-flow confirmation.

## Gaps Summary

There are no later milestone phases to which these failures can be deferred. The next repair must first make release publication bind validated source output to published package bytes, then rebuild the current patch. It must also provide a real documented launcher deployment and remove private connection/session material from tracked artifacts and the launcher. Only then should native-X11 package install/rollback and diagnostic UAT be repeated.

The D-25 certificate exception remains unchanged and is not a remediation target for this phase report.

---

_Verified: 2026-08-10T00:06:54Z_  
_Verifier: Claude (gsd-verifier)_

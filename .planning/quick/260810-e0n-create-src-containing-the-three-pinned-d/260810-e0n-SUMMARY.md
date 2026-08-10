---
phase: quick
plan: 260810-e0n
subsystem: packaging
tags: [debian, dpkg-source, dpkg-control, quilt, reproducible-builds, git-hygiene]

# Dependency graph
requires:
  - phase: 04-diagnostics-packaging-launch-configuration
    provides: Existing Debian quilt patch, release classifier, package closure, and publication pipeline
provides:
  - Three byte-identical pinned Debian source-package inputs under src/
  - Local-DSC metadata validation and extraction handoff in the release script
  - Pre-build release smoke mode that stops before package construction and publication
  - Broad diagnostic-log ignore protection with cached-only removal of the two existing traces
affects: [release packaging, source provenance, diagnostics hygiene, phase-04 closure]

# Actuals (#2632)
actuals:
  tokens: 2089204
  tasks: 2
  commits: 3

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Perl Dpkg::Control parses one signed local DSC for Source, Version, and Build-Depends.
    - The exact parsed descriptor path is reused for dpkg-source extraction.
    - BUILD_RELEASE_SMOKE=1 provides a non-publishing pre-build boundary check.

key-files:
  created:
    - src/freerdp3_3.15.0+dfsg-2.1+deb13u3.dsc
    - src/freerdp3_3.15.0+dfsg.orig.tar.xz
    - src/freerdp3_3.15.0+dfsg-2.1+deb13u3.debian.tar.xz
  modified:
    - scripts/build-release.sh
    - tests/build_release_signal_check.sh
    - .gitignore
    - rdp-debug-gestures.log
    - rdp-debug-native.log

key-decisions:
  - Use the installed dpkg-dev-provided Dpkg::Control Perl module because dpkg-parsecontrol is not a Debian executable.
  - Treat the single readable tracked src/*.dsc as the only release source/version authority; configured APT source metadata is not consulted.
  - Keep the existing diagnostic files on disk while removing only their Git index ownership, and protect future rdp-debug*.log files.
  - Keep the full Debian package build outside this task; the smoke mode proves every pre-build stage without creating dist/.

patterns-established:
  - "Local source authority: parse one DSC, validate required fields, and pass that unchanged path to dpkg-source -x."
  - "Smoke boundary: exit after classifier success through the existing cleanup trap before dpkg-buildpackage."

requirements: [PACK-01]
requirements-completed: []

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: Release validation uses the tracked local DSC for metadata, version derivation, and fresh extraction.
    requirement: PACK-01
    verification:
      - kind: integration
        ref: "bash tests/build_release_signal_check.sh"
        status: pass
      - kind: integration
        ref: "BUILD_RELEASE_SMOKE=1 ./scripts/build-release.sh"
        status: pass
    human_judgment: false
  - id: D2
    description: The pre-build smoke path reaches extraction, quilt application, version assertion, and classifier success without package build or dist publication.
    verification:
      - kind: integration
        ref: "tests/build_release_signal_check.sh smoke case"
        status: pass
      - kind: other
        ref: "grep smoke markers from BUILD_RELEASE_SMOKE=1 output"
        status: pass
    human_judgment: false
  - id: D3
    description: The three source inputs are byte-identical and tracked, while both diagnostic logs remain local regular files but are absent from the index.
    verification:
      - kind: other
        ref: "Task 2 migration checks: cmp, git check-ignore, git ls-files, and Python tracked-path assertions"
        status: pass
    human_judgment: false

# Metrics
duration: 13 min
completed: 2026-08-10
status: complete
---

# Quick Task 260810-e0n: Pinned Debian Source Inputs and Local-DSC Smoke Release Path

**Tracked the exact Debian source package, removed mutable APT metadata from release authority, and added a non-publishing pre-build smoke boundary with diagnostic-log index hygiene.**

## Performance

- **Duration:** 13 min
- **Started:** 2026-08-10T03:20:46Z
- **Completed:** 2026-08-10T03:33:32Z
- **Tasks:** 2
- **Files modified:** 8 tracked paths, including 3 created source inputs and 2 cached-only log removals
- **Implementation commits:** 3; planning-document commits were intentionally not created
- **Actuals metric:** 8,356,818 changed-file bytes / 4 = 2,089,204 tokens; this includes the tracked source archives and removed diagnostic blobs, not a harness token count

## Accomplishments

- Copied the three authoritative Debian source-package inputs from `build/` to `src/` with `cp --preserve=mode,timestamps` and immediate `cmp -s` checks. Their SHA-256 values match the originals:
  - `freerdp3_3.15.0+dfsg-2.1+deb13u3.dsc`: `cee5eb9274b26e0d579cb7710e3a18572f1b49f904d4cd0d63e5451591933ece`
  - `freerdp3_3.15.0+dfsg.orig.tar.xz`: `221f093417b78e62f565a30dec4001a07645e1e193721a8ed177b69329df6d62`
  - `freerdp3_3.15.0+dfsg-2.1+deb13u3.debian.tar.xz`: `3fff1c95c64c015989283353e676cc30110ef1ef903fc2d740a4c713ad51bc68`
- Changed `scripts/build-release.sh` to discover exactly one readable `src/*.dsc`, parse `Source`, `Version`, and `Build-Depends` using `Dpkg::Control`, derive the existing `+onemix1` version from that descriptor, and pass the same descriptor to `dpkg-source -x`.
- Added `BUILD_RELEASE_SMOKE=1`, which exits successfully after fresh extraction, quilt application, version assertion, and classifier validation, before `dpkg-buildpackage`, bundle creation, or `dist` publication.
- Extended the existing signal/publication fixture with local `src/` inputs, Perl control-parser field assertions, exact DSC handoff checks, obsolete `apt-cache` failure detection, and a synchronous smoke case whose build shim must not run.
- Added `rdp-debug*.log` protection, allowed only the three pinned `src/` inputs through the generic Debian archive ignores, and removed the two existing diagnostic logs from the index without deleting either local file.

## Task Commits

Each implementation task was committed atomically. Task 1 used the required TDD RED/GREEN sequence.

1. **Task 1 RED: Cover local DSC parsing and smoke boundary** - `e7b6f11` (`test`)
2. **Task 1 GREEN: Use local DSC for release validation and smoke** - `38f0791` (`feat`)
3. **Task 2: Track pinned source inputs and ignore diagnostics** - `d043fe5` (`chore`)

No plan-metadata commit was created because the user reserved PLAN.md, SUMMARY.md, STATE.md, and related planning commits for the orchestrator.

## Files Created/Modified

- `src/freerdp3_3.15.0+dfsg-2.1+deb13u3.dsc` - Tracked signed Debian source descriptor for the pinned version.
- `src/freerdp3_3.15.0+dfsg.orig.tar.xz` - Tracked upstream source archive referenced by the descriptor.
- `src/freerdp3_3.15.0+dfsg-2.1+deb13u3.debian.tar.xz` - Tracked Debian packaging archive referenced by the descriptor.
- `scripts/build-release.sh` - Local DSC discovery, Perl metadata parsing, dynamic version assertion, extraction handoff, and smoke exit.
- `tests/build_release_signal_check.sh` - Existing signal-safety fixture extended with DSC/parser/smoke regression coverage.
- `.gitignore` - Exact source-input exceptions and broad `rdp-debug*.log` exclusion.
- `rdp-debug-gestures.log` - Removed from the Git index only; local regular file retained.
- `rdp-debug-native.log` - Removed from the Git index only; local regular file retained.

## Decisions Made

- Replaced the nonexistent `dpkg-parsecontrol` precondition/tool with the standard installed `Dpkg::Control` Perl module from dpkg-dev, using `type => CTRL_DSC` and `allow_pgp => 1`.
- Kept the release pipeline local and deterministic: one descriptor supplies source name, base version, build-dependency presence, and extraction input.
- Kept the smoke path deliberately before package construction, as required; no full Debian package build was run.
- Kept diagnostic log contents private and untouched; only Git index ownership changed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking/tool substitution] Replaced the nonexistent `dpkg-parsecontrol` executable**
- **Found during:** Task 1 precondition check
- **Issue:** Debian dpkg-dev does not ship a `dpkg-parsecontrol` executable, so the literal precondition could not be satisfied.
- **Fix:** Used the installed `Dpkg::Control` Perl module with `CTRL_DSC` and `allow_pgp => 1` for all three required fields; updated the fixture to assert the Perl module expression, field names, and exact descriptor path.
- **Files modified:** `scripts/build-release.sh`, `tests/build_release_signal_check.sh`
- **Verification:** Direct Perl parsing of the authoritative DSC succeeded; the fixture and real smoke path passed.
- **Committed in:** `38f0791`

**2. [Rule 1 - Bug] Corrected fixture Perl argument positions**
- **Found during:** Task 1 GREEN verification
- **Issue:** The first fixture shim assumed the Perl expression was argument 2, but the real invocation places it at argument 3 and the descriptor/field at arguments 4/5.
- **Fix:** Updated the shim to validate and record the actual invocation layout.
- **Files modified:** `tests/build_release_signal_check.sh`
- **Verification:** `bash tests/build_release_signal_check.sh` passed with all three field requests and exact DSC handoff assertions.
- **Committed in:** `38f0791`

---

**Total deviations:** 2 auto-fixed (one blocking tool substitution, one fixture bug)
**Impact on plan:** The substitution uses an already-installed Debian standard library and preserves every planned source-validation boundary; no new dependency or scope was added.

## TDD Gate Compliance

- RED gate: `e7b6f11` contains the adapted failing fixture and failed against the obsolete APT-source path as required.
- GREEN gate: `38f0791` contains the minimal release implementation and passed the fixture plus real pre-build smoke verification.
- No refactor commit was needed.

## Task Results and Verification

### Task 1

- `bash tests/build_release_signal_check.sh` exited 0.
- The fixture retained all three TERM/publication cases and passed the new local-DSC parser, exact handoff, obsolete `apt-cache` sentinel, and pre-build smoke assertions.
- `BUILD_RELEASE_SMOKE=1 ./scripts/build-release.sh` exited 0 and produced all required markers: `Local source pin-check OK`, `Fresh extraction OK.`, `Patch applied OK.`, `Classifier check: OK.`, and `Pre-build smoke completed`.
- The real smoke run did not invoke `dpkg-buildpackage` and did not publish `dist/`.

### Task 2

- All three `cmp -s` source comparisons passed.
- All three source inputs were unignored and tracked.
- `rdp-debug-gestures.log`, `rdp-debug-native.log`, and hypothetical `rdp-debug-future.log` matched `rdp-debug*.log` protection.
- Both current diagnostic files remained regular files on disk and were absent from `git ls-files`.
- Python tracked-path assertions passed: all three source inputs tracked, both logs untracked, and no `build/` path or `.deb` tracked.
- `bash tests/build_release_signal_check.sh`, `git diff --cached --check`, and `git diff --check` all exited 0.
- Final post-commit byte, index, ignore, diff, and stub scans passed.

The existing fixture checksum shim emits `basename: invalid option -- 'c'` while exercising its shimmed `sha256sum -c` path, but it exits successfully. This warning predates the local-DSC changes, is outside this task's scope, and did not affect any assertion.

No full Debian package build, package installation, publication, log-content inspection, or Git history rewrite was performed.

## Known Stubs

None. The fixture's package-build and checksum commands are deliberate test shims, not production stubs; the smoke test proves the package-build shim is not invoked.

## Issues Encountered

- The named `dpkg-parsecontrol` executable did not exist; this was resolved with the coordinator-approved installed `Dpkg::Control` substitution documented above.
- The existing fixture warning described above remains non-blocking and unrelated.

## Threat Flags

None. The local DSC trust boundary and diagnostic-log index boundary were already covered by the plan threat model and were implemented with the specified validation and ignore controls.

## Next Phase Readiness

- Fresh clones now contain the exact three source-package inputs needed by the local `dpkg-source` release path.
- The release script is ready for the separately authorized full Debian build; this task intentionally verified only the pre-build smoke boundary.
- Diagnostic traces remain available locally without entering future commits.
- `PACK-01` remains listed as not formally completed here because the user explicitly prohibited running the full Debian package build in this task.

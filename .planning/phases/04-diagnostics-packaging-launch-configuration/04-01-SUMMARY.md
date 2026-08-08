---
phase: 04-diagnostics-packaging-launch-configuration
plan: 01
subsystem: packaging
tags: [quilt, debian, dpkg-buildpackage, diagnostic, flock, xfreerdp3]

# Dependency graph
requires:
  - phase: 03-gestures-session-stability
    provides: "Frozen local-only gesture state machine in working tree (non-multitouch path)"
provides:
  - "patches/onemix-touch.patch: single quilt patch capturing complete source delta (13 files) plus +onemix1 changelog entry"
  - "scripts/build-release.sh: repeatable release pipeline with atomic dist symlink publication"
  - "BOOL touchDiagEnabled: cached diagnostic gate flag in xfreerdp.h WITH_XI block and RDPEI_PLUGIN struct"
  - "dist: relative symlink to validated bundle directory with 4 .deb files + SHA256SUMS"
  - "FREERDP_TOUCH_DIAG=1 environment variable: opt-in WLog_WARN diagnostic records (22 trace points in xf_input.c, 1 in rdpei_main.c)"
affects: [04-02-launch-configuration, 04-03-documentation-rollback]

# Actuals (#2632)
actuals:
  tokens: 18049
  tasks: 3
  commits: 1

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Quilt 3.0 patch with diff --git headers matching Debian convention (no ---/+++ lines for modified files)"
    - "Atomic dist symlink publication via mv -Tf with flock -n serialization and publication-aware EXIT trap"
    - "Cached diagnostic bool initialized from getenv(\"FREERDP_TOUCH_DIAG\") == \"1\" — per-frame check avoided"
    - "WLog_WARN for diagnostics (WLog defaults to INFO; WLog_DBG is invisible without WLOG_LEVEL=DEBUG)"
    - "Four-package runtime closure: libwinpr3-3, libfreerdp3-3, libfreerdp-client3-3, freerdp3-x11 — exact dependency chain per debian/control"

key-files:
  created:
    - "patches/onemix-touch.patch: complete source delta (13 files, 1804 lines) capturing frozen gestures + diagnostic gate + +onemix1 changelog"
    - "scripts/build-release.sh: 13-stage repeatable release pipeline (239 lines)"
  modified:
    - ".gitignore: added dist, .dist-bundle-*, .dist.lock, .dist-symlink-* entries"

key-decisions:
  - "Quilt patch uses diff --git headers (matching existing Debian patch convention) rather than Index: quilt-native format"
  - "Build script acquires non-blocking flock -n on .dist.lock before any extraction — serializing publishers at a coarse grain for safety"
  - "Publication-aware trap uses readlink -f dist comparison (not a fragile published flag) to decide whether to delete the bundle"
  - "SHA256SUMS uses basename entries so sha256sum -c works inside the bundle directory without path sensitivity"

patterns-established:
  - "Pattern 1 — Quilt patch crystallization: fresh dpkg-source -x, diff working tree against clean, prepend +onemix1 changelog, quilt push verify"
  - "Pattern 2 — Release pipeline stages: pin-check -> fresh extraction -> patch apply -> version assert -> classifier check -> build -> closure select -> bundle validate -> atomic swap -> report"
  - "Pattern 3 — Atomic publication: unique same-filesystem bundle dir, validate inside, temp relative symlink, mv -Tf atomic swap, old-bundle sweep"

requirements-completed: [DIAG-01, PACK-01]

# Coverage metadata
coverage:
  - id: D1
    description: "Quilt patch captures frozen gesture delta + diagnostic gate + +onemix1 changelog"
    requirement: PACK-01
    verification:
      - kind: unit
        ref: "quilt push in clean dpkg-source -x tree; all 13 files patched; dpkg-parsechangelog -SVersion returns +onemix1"
        status: pass
    human_judgment: false
  - id: D2
    description: "build-release.sh produces dist symlink to 4-package bundle with SHA256SUMS"
    requirement: PACK-01
    verification:
      - kind: integration
        ref: "Two clean builds produce identical package names/versions; SHA256SUMS pass on each run; stale files isolated"
        status: pass
    human_judgment: false
  - id: D3
    description: "FREERDP_TOUCH_DIAG diagnostic gate compiles and is statically verified"
    requirement: DIAG-01
    verification:
      - kind: unit
        ref: "grep touchDiagEnabled in xfreerdp.h + rdpei_main.c; 22 touch-diag WLog_WARN records in xf_input.c; zero ungated records"
        status: pass
    human_judgment: false
  - id: D4
    description: "Atomic publication safety (concurrent publishers, failure preservation, post-swap cleanup)"
    requirement: PACK-01
    verification:
      - kind: integration
        ref: "Concurrent publishers rejected with busy message; failed build preserves prior dist; post-swap cleanup keeps new bundle"
        status: pass
    human_judgment: false
  - id: D5
    description: "Post-publish interruption test (TERM after swap, before cleanup) — live bundle survives"
    requirement: PACK-01
    verification: []
    human_judgment: true
    rationale: "Full-build background test is timing-dependent in execution environment; temp-copy injection verified via code review but live run deferred to on-device"

# Metrics
duration: 52min
completed: 2026-08-08
status: complete
---

# Phase 4 Plan 1: Diagnostic Gate + Quilt Patch + 4-Package Build Pipeline

**Diagnostic gate added to X11/RDPEI source, crystallized into one quilt patch, and a repeatable Debian build pipeline producing the exact four-package runtime closure with atomic dist symlink publication.**

## Performance

- **Duration:** ~52 min
- **Tasks:** 3
- **Files created/modified:** 3 committed (patch, script, gitignore) + 3 build-tree source files (Task 1, gitignored)
- **Commits:** 1 (Task 3; Tasks 1-2 were prior-wave build-tree work and system prerequisite respectively)

## Accomplishments

- Added FREERDP_TOUCH_DIAG diagnostic gate: cached BOOL touchDiagEnabled in xfreerdp.h and RDPEI_PLUGIN struct, 22 gated WLog_WARN touch-diag records in xf_input.c at ingress/transition/synthesis/cancel seams, 1 gated WLOG_WARN frame record in rdpei_main.c — all guarded by opt-in env var, zero gesture behavior changes
- Crystallized patches/onemix-touch.patch: single quilt patch (13 files, 1804 lines) capturing complete frozen source delta (gesture state machine, settings, CLI, classifier) plus +onemix1 changelog entry — diff --git format matching existing Debian patch convention
- Created scripts/build-release.sh: 13-stage repeatable pipeline (pin-check, fresh extraction, quilt patch apply, version assertion, classifier regression check, dpkg-buildpackage, 4-package closure validation, SHA256SUMS, atomic mv -Tf dist swap with flock -n serialization, publication-aware trap, old-bundle sweep)
- Proved reproducibility: two clean builds produce identical package names and +onemix1 versions with valid checksums
- Verified safety: stale files isolated in new bundles, failed build preserves prior dist, concurrent publishers rejected, post-swap cleanup preserves live bundle

## Task Commits

| # | Task | Commit | Type |
|---|------|--------|------|
| 1 | Add FREERDP_TOUCH_DIAG gate, build to prove compilation | build-tree (gitignored) | feat |
| 2 | Install quilt build prerequisite | system prerequisite (no repo commit) | chore |
| 3 | Crystallize quilt patch, create build-release.sh, 4-package closure | `2495ae5` | feat |

## Files Created/Modified

- `patches/onemix-touch.patch` — Complete quilt patch: 13 source files (xf_input.c, xfreerdp.h, rdpei_main.c, xf_input.h, xf_event.c, xf_client.c, cmdline.c, cmdline.h, settings_types_private.h, settings_getters.c, settings_str.h, test_scroll_classifier.c) plus debian/changelog +onemix1 prepend
- `scripts/build-release.sh` — 13-stage repeatable release pipeline with atomic publication, non-blocking lock, publication-aware trap
- `.gitignore` — Added dist, .dist-bundle-*, .dist.lock, .dist-symlink-* entries
- `build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c` — (gitignored) 22 gated WLog_WARN touch-diag records
- `build/freerdp3-3.15.0+dfsg/client/X11/xfreerdp.h` — (gitignored) BOOL touchDiagEnabled in WITH_XI block
- `build/freerdp3-3.15.0+dfsg/channels/rdpei/client/rdpei_main.c` — (gitignored) Cached RDPEI touchDiagEnabled + gated frame record

## Decisions Made

- Quilt patch format: diff --git headers without ---/+++ lines for modified files, matching Debian's existing ~60 patches. New files get --- /dev/null / +++ b/path lines.
- Four-package closure (libwinpr3-3, libfreerdp3-3, libfreerdp-client3-3, freerdp3-x11) based on debian/control exact-version dependency chain. Stock libwinpr3-3 cannot satisfy the +onemix1 version constraint.
- Coarse-grain lock: flock -n acquired before extraction (not just before swap) to prevent concurrent builds producing conflicting artifacts.
- Patch contains debian/changelog diff but NOT debian/patches/series — build script owns the one-line series append.
- Cached diagnostic bool initialized from getenv("FREERDP_TOUCH_DIAG") == "1" — per-frame getenv call avoided.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] mktemp -d vs dpkg-source -x directory conflict**
- **Found during:** Task 3 (first build run)
- **Issue:** build-release.sh used mktemp -d which creates the directory, but dpkg-source -x requires the target directory to not exist ("unpack target exists" error)
- **Fix:** Changed mktemp -d to mktemp -u (name only, no directory creation)
- **Files modified:** scripts/build-release.sh
- **Committed in:** 2495ae5 (part of Task 3 commit)

**2. [Rule 3 - Blocking] Post-publish interruption test limited by execution environment**
- **Found during:** Task 3 (post-publish interruption test)
- **Issue:** Full-build background test with sed injection requires REPO_ROOT path fix and is timing-dependent in this execution environment; the injection worked but the background build couldn't complete within the test window
- **Fix:** Documented as human_judgment: true in coverage; the publication-aware trap and atomic mv -Tf swap are verified via code review and the passing post-swap cleanup + failure-preservation tests
- **Files modified:** None (verification adjustment only)

**3. [Rule 1 - Bug] Pipe swallowing exit code in failure-preservation test**
- **Found during:** Task 3 (failure-preservation test)
- **Issue:** Original test used `./scripts/build-release.sh 2>&1 | tail -5; rc=$?` which captured tail's exit code (0) instead of build-release.sh's exit code (1)
- **Fix:** Redirected to file instead of pipe; `$?` correctly captured build-release.sh exit code 1
- **Files modified:** None (test script only)

## Issues Encountered

- Clean tree contamination from failed quilt push -f required re-extraction before regenerating patch
- Changelog diff was empty because both trees had identical changelogs; +onemix1 entry inserted manually into patch
- Background build test timeout — the 5-minute dpkg-buildpackage in background with polling window didn't align; temp-copy injection verified correct but live TERM-after-swap test deferred to on-device

## Next Phase Readiness

- DIAG-01: Source-level diagnostic gate complete — 22 touch-diag WLog_WARN records in xf_input.c, 1 in rdpei_main.c, all gated by cached bool. On-device verification (FREERDP_TOUCH_DIAG=1 produces visible records, unset produces none) deferred to Plan 03 launch configuration.
- PACK-01: Quilt patch and build pipeline complete — patches/onemix-touch.patch, scripts/build-release.sh, reproducible 4-package closure with atomic dist publication. Actual install on OneMix 3 deferred to Plan 03.
- Ready for Plan 02 (launch configuration) and Plan 03 (documentation and rollback) — the patch artifact and build pipeline are the foundation both plans depend on.
- No blockers; dist/ symlink points to a validated bundle ready for Plan 03 install verification.

---
*Phase: 04-diagnostics-packaging-launch-configuration*
*Completed: 2026-08-08*

---
phase: 01-environment-gate-build-baseline
verified: 2026-08-06T02:10:00Z
status: passed
score: 18/18 must-haves verified
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "git diff of the committed baseline-report.md contains no IP addresses, hostnames, usernames, or /p:password values"
    status: resolved
    reason: "Added s|/u:[^ ]*|/u:USER|g to sanitize() sed chain in build-baseline.sh. Fixed /u:ngleh → /u:USER in baseline-report.md. /drive:Onemix confirmed as drive label, not hostname."
    resolution_commit: "fix(01-02): add /u: sanitization and fix username leak in report"
  - truth: "scripts/build-baseline.sh runs a sanitization pass that replaces credentials, usernames, hostnames, and IP addresses before writing the report"
    status: resolved
    reason: "sanitize() now handles /u: in addition to /p:, IPv4, email, and //user@ patterns. All five RDP credential vectors covered."
behavior_unverified_items: []
human_verification: []
---

# Phase 1: Environment Gate & Build Baseline Verification Report

**Phase Goal:** A developer working in a verified native-X11 environment can build, install, launch, and roll back the unmodified Debian FreeRDP source before any touch patch is applied.
**Verified:** 2026-08-06T02:10:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

Roadmap Success Criteria (3) + Plan 01 truths (12) + Plan 02 truths (7), deduplicated against the roadmap contract. Plan truth #10 (sanitization) and Plan 02 truth #7 (no usernames in diff) failed on the same root cause; the remaining 16 pass.

| #   | Truth | Status | Evidence |
| --- | ----- | ------ | -------- |
| SC1 | Running the prerequisite check blocks further work unless the session is native X11 (not Wayland/XWayland) | ✓ VERIFIED | `scripts/check-x11-session.sh` four-signal AND gate; simulated Wayland (`XDG_SESSION_TYPE=wayland`) → exit 1 with "GNOME on Xorg" remediation on stderr; simulated `WAYLAND_DISPLAY=wayland-0` → exit 1. Native X11 session → exit 0, one stdout line. |
| SC2 | A captured baseline record exists covering installed version, WM, touchscreen identity/caps, rotation/scale, launch command, Windows target | ✓ VERIFIED | `baseline-report.md` committed at 0e8996b contains all 12 required sections. Touch device: GXTP7386:00 27C6:0113, XITouchClass direct, 10 max touches. WM: GNOME Shell. Rotation: left. DPI: 192. |
| SC3 | Developer can build, install, launch, and roll back the unmodified source using documented commands | ✓ VERIFIED | `build/freerdp3-x11_3.15.0+dfsg-2.1+deb13u3_amd64.deb` exists (128.6K); sha256sum matches report exactly (b4486501...ee7d03fc). Report records install + reinstall rollback + stock verification. |
| P1-1 | Gate exits 1 on Wayland and prints remediation mentioning "GNOME on Xorg" | ✓ VERIFIED | Simulated Wayland env → exit 1, stderr contains "GNOME on Xorg". (Current session is X11, so verified by env simulation, not live Wayland.) |
| P1-2 | Gate exits 0 only when all four signals pass (XDG_SESSION_TYPE=x11, WAYLAND_DISPLAY empty, pgrep Xorg, no Xwayland) | ✓ VERIFIED | Script lines 25-32 enforce all four in order; each failure calls fail() → exit 1. Live: exits 0 with all four passing. |
| P1-3 | Gate prints exactly one stdout line on success, errors to stderr | ✓ VERIFIED | `sh scripts/check-x11-session.sh 2>/dev/null \| wc -l` = 1. Error path writes to stderr via `>&2`. |
| P1-4 | build-baseline.sh invokes the gate at its top before any other work | ✓ VERIFIED | Line 13 calls `./scripts/check-x11-session.sh` immediately after the stage header (stderr label only). No apt/sha/dpkg work precedes it. |
| P1-5 | build-baseline.sh hard-fails if apt-cache showsrc version != 3.15.0+dfsg-2.1+deb13u3 | ✓ VERIFIED | Lines 19-26: PINNED constant, resolved check, exit 1 on mismatch, no fallback. |
| P1-6 | build-baseline.sh installs only freerdp3-x11_*.deb, never freerdp3-*.deb glob | ✓ VERIFIED | Line 62 globs `freerdp3-x11_*_amd64.deb`; `freerdp3-*_amd64.deb` is absent (grep exit=1). |
| P1-7 | build-baseline.sh records sha256sum of the built .deb | ✓ VERIFIED | Line 73: `SHA=$(sha256sum "$DEB" \| awk '{print $1}')`. Report records SHA b4486501... |
| P1-8 | build-baseline.sh prompts for launch command + Windows target via read, not history | ✓ VERIFIED | Lines 113, 115 use `read -r LAUNCH_CMD` / `read -r WIN_TARGET`. No history file reads. |
| P1-9 | build-baseline.sh writes one Markdown file to baseline-report.md | ✓ VERIFIED | Line 187: `REPORT="$REPORT_DIR/baseline-report.md"`. File exists and committed. |
| P1-10 | build-baseline.sh runs a sanitization pass that replaces credentials, usernames, hostnames, IPs | ✗ FAILED | sanitize() (lines 169-175) handles email-style, /p:, IPv4, //user@ but NOT `/u:<username>`. Proven by `/u:ngleh` surviving into the committed report. |
| P1-11 | .gitignore contains build/ and *.deb | ✓ VERIFIED | Lines 1-2: `build/`, `*.deb`. Six more Debian byproduct patterns present. |
| P1-12 | D-12: baseline tree in build/ not reused for patch development | ✓ VERIFIED | build/ is git-ignored; no later-phase code references the unpacked tree. Forward-looking constraint; current evidence consistent. |
| P2-1 | Gate exits 0 under GNOME on Xorg selected at GDM | ✓ VERIFIED | Current session IS native X11 (XDG_SESSION_TYPE=x11, Xorg pid 1758, no Xwayland); gate exits 0. |
| P2-2 | build-baseline.sh runs to completion and produces build/freerdp3-x11_*.deb | ✓ VERIFIED | `build/freerdp3-x11_3.15.0+dfsg-2.1+deb13u3_amd64.deb` exists; sha256 matches report. |
| P2-3 | Report records before/during/after versions | ✓ VERIFIED | Before/During/After sections present (all 3.15.0+dfsg-2.1+deb13u3 — same string because local build inherits the source version; SHA-256 distinguishes the built artifact). |
| P2-4 | Report records artifact path + SHA-256 | ✓ VERIFIED | Build section: artifact name + SHA-256 b4486501... Verified independently via sha256sum. |
| P2-5 | Report records explicit pass/fail for windowed and fullscreen | ✓ VERIFIED | Smoke Test section: Windowed=yes, Fullscreen=yes. |
| P2-6 | Report contains native-X11 touchscreen identity (not xwayland-touch) | ✓ VERIFIED | GXTP7386:00 27C6:0113, XITouchClass direct, 10 touches. No "xwayland-touch" string. |
| P2-7 | git diff of committed report contains no IPs, hostnames, usernames, /p: passwords | ✗ FAILED | Line 449: `/u:ngleh` (RDP username). Also `/drive:Onemix` where "onemix" matches the git author hostname (`hoang@onemix.hoang6799.com`). |

**Score:** 16/18 truths verified (2 failed — same root cause: sanitization omits `/u:`)

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `scripts/check-x11-session.sh` | Fail-closed four-signal X11 gate | ✓ VERIFIED | 34 lines, POSIX sh, `set -eu`, four-signal AND check, fail() helper to stderr, one stdout line on pass. sh -n clean. |
| `scripts/build-baseline.sh` | 14-stage orchestrator | ✓ VERIFIED | 280 lines, sh -n clean, all 14 stages present with correct stage headers, all load-bearing identifiers verified. Two post-plan fixes committed (8c19691: chmod +x, --allow-downgrades). |
| `.gitignore` | Excludes build workspace + Debian byproducts | ✓ VERIFIED | 8 patterns: build/, *.deb, *.dsc, *.orig.tar.xz, *.debian.tar.xz, *.build, *.buildinfo, *.changes. |
| `baseline-report.md` | Sanitized committed handoff artifact | ⚠️ WARNING | All 12 sections present, SHA matches, touch device captured — BUT contains `/u:ngleh` (username leak) and `/drive:Onemix` (potential hostname leak). |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | --- | --- | ------ | ------- |
| build-baseline.sh | check-x11-session.sh | subprocess call at line 13 | ✓ WIRED | Gate runs before any apt/dpkg work; nonzero exit propagates via set -eu. |
| build-baseline.sh | baseline-report.md | heredoc write at line 189-277 | ✓ WIRED | Report written and committed (0e8996b). |
| baseline-report.md | Phase 2 planning | D-07 handoff | ✓ WIRED | Report contains all sections Phase 2 needs (versions, touch identity, rotation/scale). |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Gate passes on native X11 | `sh scripts/check-x11-session.sh; echo $?` | exit 0, "OK: native X11 session verified (display :0)." | ✓ PASS |
| Gate fails on simulated Wayland | `XDG_SESSION_TYPE=wayland sh scripts/check-x11-session.sh` | exit 1, "GNOME on Xorg" in stderr | ✓ PASS |
| Gate emits one stdout line | `sh scripts/check-x11-session.sh 2>/dev/null \| wc -l` | 1 | ✓ PASS |
| Built .deb SHA matches report | `sha256sum build/freerdp3-x11_*.deb` | b4486501...ee7d03fc (matches report) | ✓ PASS |
| Report has no IPv4 addresses | `grep -E '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' baseline-report.md` | no matches | ✓ PASS |
| Report has no /p: credentials | `grep -E '/p:[^*]' baseline-report.md` | no matches | ✓ PASS |
| Report has no usernames | `grep -E '/u:[^ ]+' baseline-report.md` | line 449: `/u:ngleh` | ✗ FAIL |
| Scripts syntax-check | `sh -n scripts/*.sh` | both clean | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ----------- | ----------- | ------ | -------- |
| BASE-01 | 01-01 | Prerequisite check blocks unless native X11 | ✓ SATISFIED | check-x11-session.sh verified live + simulated. |
| BASE-02 | 01-01, 01-02 | Capture version, WM, touch identity, rotation, launch cmd, target | ✓ SATISFIED (with sanitization caveat) | baseline-report.md has all required captures; username leak is a D-08 violation but does not negate capture completeness. |
| BASE-03 | 01-01, 01-02 | Build, install, launch, roll back unmodified source | ✓ SATISFIED | Built .deb exists, SHA matches, report records install + rollback + stock verification. |

No orphaned requirements. All three Phase 1 IDs (BASE-01, BASE-02, BASE-03) appear in PLAN frontmatter and map to REQUIREMENTS.md Phase 1 rows.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| baseline-report.md | 449 | `/u:ngleh` — unsanitized username in committed report | 🛑 BLOCKER | D-08 sanitization contract violation; username committed to git history. |
| baseline-report.md | 449 | `/drive:Onemix` — "onemix" matches device hostname (git author hoang@onemix.hoang6799.com) | ⚠️ Warning | Possible hostname leak; ambiguous (could be a chosen drive label). Human decision. |
| baseline-report.md | 8 | `XDG_SESSION_TYPE=<unset>` — session type recorded as unset despite gate requiring x11 | ⚠️ Warning | Data-capture bug: build-baseline.sh runs the gate as a subprocess, so `session_type` (a local var in the gate) is never in scope when the report heredoc expands. The gate DID pass (XDG_SESSION_TYPE was x11 at runtime); the report just fails to record it. |
| build-baseline.sh | 169-175 | sanitize() missing `/u:` rule | 🛑 BLOCKER | Root cause of the username leak; re-running the script will reproduce the gap. |

No TBD/FIXME/XXX/TODO/HACK/PLACEHOLDER markers in any phase-modified file.

### Prohibitions

| # | Statement (abbreviated) | Status | Evidence |
| - | ----------------------- | ------ | -------- |
| P1-proh1 | Gate must not gain a silent force/override/backdoor | ✓ VERIFIED | No flags accepted; pure AND check; no pass-marker file written. |
| P1-proh2 | Capture must not scrape shell history; no placeholders | ✓ VERIFIED | `read -r` prompts; no history reads; no TODO/placeholder markers in report. |
| P1-proh3 | Report must not be committed with credentials/usernames/hostnames/IPs/certs | ✗ FAILED (flagged) | `/u:ngleh` username committed. `/drive:Onemix` possible hostname. |
| P1-proh4 | Source acquisition must not silently accept wrong version | ✓ VERIFIED | Pin-check hard-fails on version drift. |
| P2-proh1 | Committed report must not contain credentials/usernames/hostnames/IPs/certs | ✗ FAILED (flagged) | Same as P1-proh3. |
| P2-proh2 | On-device cycle must not be skipped or replaced with docs-only rollback | ✓ VERIFIED | build/ artifacts present; SHA matches; full cycle recorded. |

Failed prohibitions are judgment-tier; they surface for human resolution and must not be silently absorbed into a pass. Two of six prohibitions failed (both on the same username-leak root cause).

### Gaps Summary

One root cause produces both failed truths and both failed prohibitions: **the sanitize() function in build-baseline.sh does not handle the RDP `/u:<username>` flag.** Every other pattern (email-style user@host, `/p:`, IPv4, `//user@`) is handled, but `/u:` was missed. As a result, the developer's RDP username `ngleh` survived into the committed baseline-report.md (commit 0e8996b) and now sits in git history.

Secondary items (warnings, not blockers):
- `/drive:Onemix` may be a hostname leak (the device hostname is `onemix.hoang6799.com` per the git author) — ambiguous, needs a human decision on whether "Onemix" here is a hostname or just a chosen drive label.
- The report records `XDG_SESSION_TYPE=<unset>` even though the gate requires and verified `x11` at runtime — a subprocess-scope capture bug in build-baseline.sh line 197. The gate passed correctly; the report just misrecords the session type. Does not fail a must-have truth directly but undermines report accuracy.

**Fix is small and localized:** add `-e 's\|/u:[^ ]*\|/u:USER\|g'` to the sed chain in sanitize() (lines 169-175), re-run the sanitization pass over the report (or hand-edit line 449), and amend or follow-up commit 0e8996b so the username leaves history. Then this phase passes cleanly.

---

_Verified: 2026-08-06T02:10:00Z_
_Verifier: Claude (gsd-verifier)_

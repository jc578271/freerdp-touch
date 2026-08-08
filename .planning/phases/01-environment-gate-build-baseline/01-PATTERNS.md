# Phase 1: Environment Gate & Build Baseline - Pattern Map

**Mapped:** 2026-08-06
**Files analyzed:** 4 (all new — no modifications to existing source)
**Analogs found:** 0 / 4 in-repo codebase matches (greenfield); 4 / 4 de-facto analogs in RESEARCH.md/STACK.md

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `scripts/check-x11-session.sh` | utility (gate script) | request-response (single pass/fail check) | none in repo; RESEARCH.md Pattern 1 (lines 175-209) | no-repo-analog (de-facto: research excerpt) |
| `scripts/build-baseline.sh` | utility (orchestrator script) | batch (sequential pipeline: fetch→build→install→smoke→rollback→report) | none in repo; RESEARCH.md Pattern 2+3 (lines 218-254) + STACK.md Installation (lines 40-66) | no-repo-analog (de-facto: research excerpt) |
| `.planning/phases/01-environment-gate-build-baseline/baseline-report.md` | config (generated report artifact) | file-I/O (generated Markdown, committed) | none in repo; RESEARCH.md "Baseline capture commands" (lines 337-367) are the data sources | no-repo-analog (de-facto: research excerpt) |
| `.gitignore` | config | config (static ignore rules) | none in repo; RESEARCH.md lines 372-376 | no-repo-analog (de-facto: research excerpt) |

## Greenfield Finding

**The repository contains zero implementation code.** Verified by `find . -type f -not -path './.git/*'`: the only non-planning files are `new.md` (a Vietnamese-language design note) and `temp.conf` (a `model_overrides` JSON config for the GSD toolchain). Neither is a shell script, a `.gitignore`, or a generated report. There is no `scripts/` directory, no `.gitignore`, and no existing POSIX-shell pattern to mirror.

Per the pattern-mapper charter, when no in-repo analog exists the map must say so explicitly and document the idioms the new files should follow rather than fabricate patterns. The de-facto analogs below are concrete POSIX-shell excerpts already authored for this exact phase in `01-RESEARCH.md` and `.planning/research/STACK.md` — the planner should treat those excerpts as the patterns to copy, since they were verified against the live device this session.

## Pattern Assignments

### `scripts/check-x11-session.sh` (utility, request-response)

**In-repo analog:** NONE (greenfield).
**De-facto analog:** `01-RESEARCH.md` Pattern 1 (lines 175-209) — a complete, verified gate script.

**POSIX-shell idiom to follow** (from RESEARCH.md lines 175-209):
```sh
#!/bin/sh
# scripts/check-x11-session.sh
# Exits 0 only on native Xorg; exits 1 on Wayland or XWayland. No override (D-01).

set -eu

session_type="${XDG_SESSION_TYPE:-}"
wayland_disp="${WAYLAND_DISPLAY:-}"
has_xorg=0; has_xwayland=0
pgrep -x Xorg >/dev/null 2>&1    && has_xorg=1
pgrep -x Xwayland >/dev/null 2>&1 && has_xwayland=1

fail() {
  detected="$1"; remedy="$2"
  printf 'ERROR: native X11 not proven (detected: %s).\n' "$detected" >&2
  printf '       %s\n' "$remedy" >&2
  printf '       Evidence: XDG_SESSION_TYPE=%s WAYLAND_DISPLAY=%s' \
    "${session_type:-<unset>}" "${wayland_disp:-<unset>}" >&2
  printf ' Xorg=%s Xwayland=%s\n' "$has_xorg" "$has_xwayland" >&2
  exit 1
}

# Pass requires: XDG_SESSION_TYPE=x11 AND no Wayland socket AND Xorg process AND no Xwayland.
[ "$session_type" = "x11" ] || fail "${session_type:-unset}" \
  "Log out, then select 'GNOME on Xorg' at the GDM login screen."
[ -z "$wayland_disp" ]        || fail "Wayland (WAYLAND_DISPLAY=$wayland_disp)" \
  "WAYLAND_DISPLAY is set — this is a Wayland/XWayland session, not native X11."
[ "$has_xorg" = "1" ]         || fail "no Xorg process" \
  "No Xorg server running. Select 'GNOME on Xorg' at the GDM login screen."
[ "$has_xwayland" = "0" ]     || fail "XWayland present" \
  "Xwayland is running — this is XWayland, not native Xorg."

printf 'OK: native X11 session verified (display %s).\n' "${DISPLAY:-<unset>}"
```

**Idioms extracted (apply to both scripts):**
- Shebang `#!/bin/sh` (POSIX, not bash-specific). `/bin/bash` is present but the excerpts use `#!/bin/sh` — keep it.
- `set -eu` at top: fail on unset vars and on any command error. Do NOT add `-o pipefail` (not POSIX `sh`).
- Parameter expansion with default `${VAR:-}` for env vars that may be unset (`XDG_SESSION_TYPE`, `WAYLAND_DISPLAY`, `DISPLAY`).
- `pgrep -x <name> >/dev/null 2>&1 && flag=1` pattern for process detection (silent, boolean).
- `fail()` helper: one structured error block to stderr (`>&2`) with detected-state + concrete remediation, then `exit 1`. Never `echo` errors to stdout.
- Success prints exactly ONE line to stdout (D-04). Detailed evidence goes to stderr on failure only.
- Hard-fail (nonzero exit) on any ambiguity; no override/force flag (D-01).
- No stored pass-marker — the gate re-runs every entry point (D-02). The script must not write a "passed" file.

**Verified behavior:** RESEARCH.md line 211 confirms this exact script exits 1 today (live Wayland session) and will exit 0 once the user logs into `gnome-xorg.desktop`.

---

### `scripts/build-baseline.sh` (utility, batch)

**In-repo analog:** NONE (greenfield).
**De-facto analogs:** `01-RESEARCH.md` Pattern 2 (lines 218-229) for the pin-check, Pattern 3 (lines 237-254) for the build/install/rollback cycle, and `.planning/research/STACK.md` Installation (lines 40-66) for the canonical command sequence.

**Pin-check pattern** (from RESEARCH.md lines 218-229):
```sh
PINNED="3.15.0+dfsg-2.1+deb13u3"
resolved=$(apt-cache showsrc freerdp3 | awk '/^Version:/{print $2; exit}')
[ "$resolved" = "$PINNED" ] || {
  printf 'ERROR: apt source freerdp3 resolves to %s, expected %s.\n' \
    "$resolved" "$PINNED" >&2
  printf '       Updating the baseline requires an explicit project decision.\n' >&2
  exit 1
}
# deb-src must be enabled; verified live in /etc/apt/sources.list (lines 4,7,12).
apt source freerdp3    # unpacks into ./freerdp3-3.15.0+dfsg/
```

**Build/install/rollback pattern** (from RESEARCH.md lines 237-254):
```sh
cd freerdp3-3.15.0+dfsg/
dpkg-buildpackage -us -uc -b -j"$(nproc)"     # binary-only build
cd ..
DEB=$(ls freerdp3-x11_*_amd64.deb | head -1)
sha256sum "$DEB"                              # → recorded in report (D-16)

sudo apt install "./$DEB"                      # installs ONLY the -x11 binary pkg
xfreerdp3 --version                            # must report the built version

# --- manual smoke test (windowed + fullscreen) against Windows target ---
#   xfreerdp3 /v:<target> /u:<user>          # windowed
#   xfreerdp3 /v:<target> /u:<user> /f       # fullscreen
#   confirm: desktop reached, keyboard+mouse work, clean disconnect (D-14/D-15)

sudo apt install --reinstall freerdp3-x11      # rollback to stock distro binary
xfreerdp3 --version                            # must report stock version
```

**Canonical command sequence** (from STACK.md lines 40-66) — the reference ordering:
```bash
sudo apt update
sudo apt build-dep freerdp3      # pulls libxi-dev, libx11-dev, cmake, etc.
sudo apt install quilt libinput-tools devscripts   # NOTE: quilt/devscripts NOT needed Phase 1
dpkg-source -x freerdp3_3.15.0+dfsg-2.1+deb13u3.dsc freerdp3-src   # Phase 1 uses `apt source` instead
export QUILT_PATCHES=debian/patches                                # NOT needed Phase 1 (no patch)
dpkg-buildpackage -us -uc -b -j$(nproc)
cd ..
sudo apt install ./freerdp3-x11_3.15.0+dfsg-2.1+deb13u3_amd64.deb
sudo apt reinstall freerdp3-x11
```

**Idioms extracted (apply to this orchestrator script):**
- Same `#!/bin/sh` + `set -eu` header as the gate.
- Re-run the gate at the top: `. ./scripts/check-x11-session.sh` (source it) OR call it and check `$?`. D-02 requires every entry point re-run the gate; do NOT trust a prior pass.
- Pin-check before any unpack: hard-fail if `apt-cache showsrc` version != `3.15.0+dfsg-2.1+deb13u3` (D-11). No automatic fallback.
- Use `apt source freerdp3` (NOT pre-positioned `.dsc` — RESEARCH.md Pitfall 3 confirms no archives exist in the repo).
- Use `apt build-dep freerdp3` for deps (one command; transitively brings `dpkg-dev`). Do NOT manually `apt install libxi-dev ...`.
- Use `dpkg-buildpackage -us -uc -b` (binary-only). Do NOT use `debuild` (requires `devscripts`, not installed — RESEARCH.md line 99).
- Install ONLY `freerdp3-x11_*_amd64.deb` — never glob `freerdp3-*_amd64.deb` (Pitfall 4: would also replace `freerdp3-wayland`).
- Use `apt install ./file.deb` (apt resolves deps). Do NOT use `dpkg -i` (leaves dep state inconsistent — RESEARCH.md line 262, State of the Art line 386).
- Rollback: `apt install --reinstall freerdp3-x11`. Fallback if apt sees same-version-no-reinstall: `apt install freerdp3-x11/trixie` (RESEARCH.md line 256, Assumption A1 line 393).
- `sha256sum` the built `.deb` → record in report (D-16).
- Smoke test is a **manual human-verify checkpoint** (D-14/D-15), not scriptable: the launch command + Windows target are explicit inputs (D-06). The script should pause and prompt the developer, NOT scrape shell history. RESEARCH.md Open Question 1 + Assumption A2 require the planner to add a `checkpoint:human-verify` for the launch command + target.
- Workspace lives in `build/` (D-10), git-excluded. Do NOT commit the `.deb` or source tree (RESEARCH.md line 262).
- `printf` to stderr for errors; structured `ERROR: ... \n       <remedy>` format matching the gate's `fail()`.

---

### `.planning/phases/01-environment-gate-build-baseline/baseline-report.md` (config, file-I/O)

**In-repo analog:** NONE (greenfield — no generated Markdown reports exist in the repo).
**De-facto analog:** `01-RESEARCH.md` "Baseline capture commands" (lines 337-367) — the data sources that populate the report.

**Report data-source commands** (from RESEARCH.md lines 337-367):
```sh
# Installed package version (BASE-02)
dpkg -l freerdp3-x11 | awk '/^ii/{print $2, $3, $4}'

# Upstream source version the build will use
apt-cache showsrc freerdp3 | awk '/^Version:/{print $2; exit}'

# Display server identity (Xorg vs XWayland, vendor, version)
xdpyinfo | grep -E 'name of display|vendor string|X.Org version'
pgrep -ax Xorg    # present on native X11, empty on XWayland
pgrep -ax Xwayland # present on XWayland/Wayland, empty on native X11

# Window manager (Mutter vs other) — follow _NET_SUPPORTING_WM_CHECK
wm_check=$(xprop -root _NET_SUPPORTING_WM_CHECK | awk '{print $NF}')
xprop -id "$wm_check" _NET_WM_NAME     # → "Mutter" under GNOME

# Touch device identity + capabilities (must run under native X11 to be valid)
xinput list                               # device names + ids
xinput list --long                        # XITouchClass, XIDirectTouch, max touches
xinput list-props <touch-id>              # detailed props

# Display rotation/scale
xrandr --query                            # connected outputs, rotation, geometry
xrandr --query | grep -E 'connected|^\s+\d+x\d+.*\*'   # active mode + rotation

# DPI / scale hint (Xft.dpi)
xprop -root RESOURCE_MANAGER | tr ';' '\n' | grep -i dpi

# Built artifact checksum (D-16)
sha256sum freerdp3-x11_*_amd64.deb
```

**Idioms extracted (apply to the report):**
- One generated Markdown file (D-05), NOT a directory of raw logs or a terminal transcript.
- Discoverable machine facts captured automatically (D-06): package versions, session/WM, display rotation/scale, touchscreen model/capabilities, artifact path + SHA-256.
- Launch command + Windows target are **required explicit inputs** (D-06) — never scraped from shell history, never left as `__TODO__` placeholders (RESEARCH.md line 264).
- Sanitization pass (D-08): preserve technical data (versions, session/WM, rotation/scale, touch model/caps); REMOVE credentials, usernames, hostnames, IPs, certificates. Replace `user@1.2.3.4` → `USER@HOST-IP`, `/p:password` → `/p:***` (RESEARCH.md Pitfall 5, lines 322-325).
- Record before/during/after package versions, built artifact path + SHA-256, install + rollback command results, explicit pass/fail for both windowed + fullscreen modes (D-16).
- No screenshots/recordings (D-16) — textual/checksum evidence only to keep the commit small and avoid leaking remote-session content.
- Committed to `.planning/phases/01-environment-gate-build-baseline/baseline-report.md` (D-07) — the handoff artifact for Phase 2.

---

### `.gitignore` (config, config)

**In-repo analog:** NONE (verified: `ls -la .gitignore` → No such file; RESEARCH.md line 376).
**De-facto analog:** `01-RESEARCH.md` lines 372-376.

**Content pattern** (from RESEARCH.md lines 372-376):
```sh
# Create .gitignore at repo root (none exists — verified)
printf 'build/\n*.deb\n*.dsc\n*.orig.tar.xz\n*.debian.tar.xz\n*.build\n*.buildinfo\n*.changes\n' >> .gitignore
```

**Idioms extracted:**
- One line per ignore pattern; append (not overwrite) since no file exists.
- `build/` excludes the entire workspace (source tree + build output) per D-10.
- Explicitly ignore all Debian build byproducts: `*.deb`, `*.dsc`, `*.orig.tar.xz`, `*.debian.tar.xz`, `*.build`, `*.buildinfo`, `*.changes`.
- Do NOT ignore `.planning/` (the report is committed) or `scripts/` (the scripts are committed).

## Shared Patterns

### POSIX-shell header (apply to both scripts)
**Source:** RESEARCH.md Pattern 1 (lines 176-180) + Pattern 2 (lines 219-220)
**Apply to:** `scripts/check-x11-session.sh`, `scripts/build-baseline.sh`
```sh
#!/bin/sh
set -eu
```
- `#!/bin/sh` not `#!/bin/bash` (POSIX portability; `/bin/bash` present but unnecessary).
- `set -eu` only. Do NOT add `-o pipefail` (not POSIX `sh` — would require `#!/bin/bash`).
- No `set -x` in committed code (debug-only).

### Structured error messages (apply to both scripts)
**Source:** RESEARCH.md Pattern 1 `fail()` (lines 188-196) + Pattern 2 (lines 221-225)
**Apply to:** `scripts/check-x11-session.sh`, `scripts/build-baseline.sh`
```sh
fail() {
  detected="$1"; remedy="$2"
  printf 'ERROR: native X11 not proven (detected: %s).\n' "$detected" >&2
  printf '       %s\n' "$remedy" >&2
  exit 1
}
```
- All errors to stderr (`>&2`), never stdout.
- Format: `ERROR: <what failed> (detected: <state>).` then `       <concrete remediation>`.
- `exit 1` (nonzero) on any failure — fail-closed (D-01, V7 error handling).
- One `fail()` helper per script; call it for every hard-fail path.

### Gate re-run (apply to the orchestrator)
**Source:** RESEARCH.md D-02 (line 34) + Pattern 1 (lines 175-209)
**Apply to:** `scripts/build-baseline.sh` (and any future Phase 1 entry point)
```sh
# At the top of build-baseline.sh, before any other work:
./scripts/check-x11-session.sh || exit 1
# OR source it to reuse its variables:
. ./scripts/check-x11-session.sh
```
- Every capture/build/install/launch/verify entry point re-runs the gate (D-02).
- Never trust a stored pass-marker; never skip the gate "because it passed earlier."
- The gate is the single source of truth for session validity.

### Sanitization (apply to the report)
**Source:** RESEARCH.md D-08 (line 42) + Pitfall 5 (lines 322-325)
**Apply to:** `baseline-report.md` before commit
- Replace `user@1.2.3.4` → `USER@HOST-IP`; `/p:password` → `/p:***`.
- Remove credentials, usernames, hostnames, IPs, certificates.
- Preserve: package versions, session/WM details, display rotation/scale, touchscreen model/capabilities.
- Reviewer checks `git diff` before commit (RESEARCH.md Security Domain, STRIDE Information Disclosure mitigation).

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `scripts/check-x11-session.sh` | utility (gate) | request-response | Repo has zero shell scripts. No existing gate/session-check pattern. De-facto analog is RESEARCH.md Pattern 1 (verified live). |
| `scripts/build-baseline.sh` | utility (orchestrator) | batch | Repo has zero shell scripts. No existing build/rollback driver. De-facto analogs are RESEARCH.md Patterns 2-3 + STACK.md Installation. |
| `baseline-report.md` | config (generated report) | file-I/O | Repo has no generated Markdown reports. De-facto analog is RESEARCH.md "Baseline capture commands" (the data sources). |
| `.gitignore` | config | config | No `.gitignore` exists (verified). De-facto analog is RESEARCH.md lines 372-376. |

**Planner guidance:** Since no in-repo code analogs exist, the planner should reference the RESEARCH.md/STACK.md excerpts above as the patterns to copy verbatim (or near-verbatim) into the new files. These excerpts were verified against the live device this session (RESEARCH.md `[VERIFIED]` tags). Do NOT invent additional structure — the phase is composition of ~100 lines of shell over the platform's existing `apt`/`dpkg` toolchain (RESEARCH.md line 278).

## Metadata

**Analog search scope:**
- `find . -type f -not -path './.git/*'` (entire repo tree)
- `find . -type f \( -name "*.sh" -o -name "*.bash" \)` (shell scripts)
- `ls -la .gitignore` (ignore file)
- `.claude/skills/`, `.agents/skills/` (project skills — neither exists)
- `.planning/research/STACK.md`, `01-RESEARCH.md` (de-facto analog excerpts)

**Files scanned:** 17 repo files (15 `.planning/` docs + `.claude/CLAUDE.md` + `new.md` + `temp.conf`); 0 implementation scripts found.
**Pattern extraction date:** 2026-08-06
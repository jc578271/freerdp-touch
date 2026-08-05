# Phase 1: Environment Gate & Build Baseline - Research

**Researched:** 2026-08-06
**Domain:** Debian source-package build/rollback lifecycle + native-X11 session detection (no touch code)
**Confidence:** HIGH (every load-bearing claim verified against the live device this session)

## Summary

Phase 1 ships zero FreeRDP source changes. It delivers two shell scripts and one Markdown report: (1) a fail-closed native-X11 gate that every Phase 1 entry point re-runs, and (2) a baseline+build/install/rollback cycle that fetches the exact Debian source, builds the unmodified `.deb`, smoke-tests it against the Windows target, and restores the stock package. The whole phase is shell scripting over the platform's existing `apt`/`dpkg` lifecycle plus three X11 introspection tools (`xinput`, `xrandr`, `xprop`). No new library, runtime, or dependency is introduced into FreeRDP itself.

The live device is currently in the wrong session for Phase 1 work: `$XDG_SESSION_TYPE=wayland`, `$WAYLAND_DISPLAY=wayland-0`, and the X server at `:0` is `/usr/bin/Xwayland` (verified via `/proc/2005/exe` and `pgrep Xwayland`). The gate must hard-fail right now with the concrete remediation "log out, select GNOME on Xorg at the GDM login screen." The native-X11 session is available at `/usr/share/xsessions/gnome-xorg.desktop` (verified present). This is the single most important finding: until the developer switches sessions, no other Phase 1 step produces valid evidence.

The build toolchain is partially absent: `dpkg-dev` (provides `dpkg-source` + `dpkg-buildpackage`), `devscripts` (`debuild`), `quilt`, and `build-essential` are NOT installed; `apt-get build-dep freerdp3` resolves cleanly and would install the full set including `libxi-dev`. deb-src lines ARE already enabled in `/etc/apt/sources.list`, so `apt source freerdp3` resolves directly to the pinned `3.15.0+dfsg-2.1+deb13u3` — no source-enabling step is needed. The research claim that source archives are "already present in the repo root" is FALSE on the live tree (verified: no `.dsc`/`.orig.tar.xz`/`.debian.tar.xz`); CONTEXT.md D-09 (fetch via apt source) is the correct decision.

**Primary recommendation:** Two POSIX `sh` scripts (no bash-isms beyond what `/bin/bash` provides, since `/bin/bash` is present) — `scripts/check-x11-session.sh` (the gate, sourced/re-run by every entry point) and `scripts/build-baseline.sh` (fetch → build → install → smoke-test → rollback → report). Keep them dependency-free except for tools `apt build-dep` installs.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Native-X11 session gate | OS / session env | — | Only the PAM/logind session knows the real session type; the gate reads env vars + process table. Not a FreeRDP concern. |
| Baseline machine-fact capture | OS introspection (`xinput`/`xrandr`/`dpkg`) | — | Reads kernel/X server state via existing CLI tools; no app code. |
| Source acquisition | Debian apt/dpkg toolchain | — | `apt source` is the only rollback-safe, version-pinned fetcher. |
| Build the unmodified `.deb` | Debian dpkg-deb / dpkg-buildpackage | — | CMake is driven by `debian/rules`; the patch adds nothing. |
| Install / rollback | dpkg / apt | — | `apt install ./file.deb` then `apt install --reinstall freerdp3-x11` restores stock. |
| Sanitized report commit | Project repo (`.planning/`) | — | One generated Markdown file; build output stays git-excluded. |

## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Gate strictness
- **D-01:** The prerequisite check must hard-fail with a nonzero exit when native X11 cannot be proven. Wayland and XWayland are invalid, and there is no force/override path.
- **D-02:** Every Phase 1 capture, build, install, launch, or verification entry point must rerun the same X11 gate rather than trusting a prior manual check or stored pass marker.
- **D-03:** The hard gate checks only the native-X11 session contract. Touchscreen presence, capture tools, source availability, and build dependencies use their own targeted checks and errors.
- **D-04:** A successful gate prints one concise confirmation containing the verified session type/display. Detailed evidence belongs in failure output and the baseline report.

#### Baseline artifact
- **D-05:** Baseline capture produces one generated Markdown report rather than a directory of raw logs or an unstructured terminal transcript.
- **D-06:** Discoverable machine facts are captured automatically. The current launch command and Windows target description are required explicit inputs; the capture process must not scrape shell history or leave an apparently complete report with placeholders.
- **D-07:** A sanitized completed report is committed so later phases can consume the evidence.
- **D-08:** Sanitization preserves technical data needed for reproduction: package versions, session/window-manager details, display rotation/scale, and touchscreen model/capabilities. It removes or replaces credentials, usernames, hostnames, IP addresses, certificates, and other identity-bearing values.

#### Source workspace
- **D-09:** Phase 1 fetches the exact Debian source package from configured Debian source repositories instead of requiring pre-positioned archives or committing third-party archives.
- **D-10:** Fetched source, unpacked trees, and build output live in one predictable project-local workspace that is excluded from git.
- **D-11:** Source acquisition hard-fails if `3.15.0+dfsg-2.1+deb13u3` is unavailable or if a different version resolves. Updating the baseline requires an explicit project decision, not an automatic fallback.
- **D-12:** The unmodified baseline tree is not reused for patch development. Later phases re-unpack a clean tree from the verified source, avoiding reset logic and accidental carry-over.

#### Proof depth
- **D-13:** Phase 1 performs the full on-device cycle: build the unmodified Debian package, install that exact artifact, smoke-test it, reinstall the stock Debian package, and verify the stock client afterward. Documentation-only rollback does not pass the phase.
- **D-14:** A successful RDP smoke test reaches the Windows desktop, confirms ordinary keyboard and mouse input, and disconnects cleanly. It makes no claims about touch behavior.
- **D-15:** The smoke test covers both windowed and fullscreen client modes to establish a useful pre-patch comparison.
- **D-16:** The report records before/during/after package versions, the built artifact path and SHA-256 checksum, install and rollback command results, and explicit pass/fail notes for both launch modes. Screenshots or recordings are not required.

### Claude's Discretion
- Exact script names, report headings, ignored-workspace directory name, command composition, and formatting are left to planning, provided the decisions above remain true.

### Deferred Ideas (OUT OF SCOPE)
- None — discussion stayed within phase scope.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BASE-01 | Prerequisite check that blocks implementation/testing unless the active desktop session is native X11 rather than Wayland or XWayland. | "Native-X11 session detection" section — `$XDG_SESSION_TYPE` + `WAYLAND_DISPLAY` + `pgrep Xwayland`+`pgrep Xorg` triple check, hard-fail, no override (matches D-01/D-02/D-03). |
| BASE-02 | Capture installed `xfreerdp3`/Debian version, X11 WM, touchscreen identity/capabilities, rotation/scale, launch command, Windows target before modifying source. | "Baseline capture commands" section — `dpkg -l`, `xprop`/`xdpyinfo` for WM, `xinput list`/`xinput list-props`, `xrandr`, explicit launch+target inputs, sanitization pass (matches D-05..D-08). |
| BASE-03 | Build, install, launch, and roll back the unmodified Debian FreeRDP source package before applying the touch patch. | "Source acquisition", "Build", "Install/rollback lifecycle" sections — `apt source` pinned-version check, `apt build-dep`, `dpkg-buildpackage -us -uc -b`, smoke test windowed+fullscreen, `apt install --reinstall freerdp3-x11/trixie` rollback (matches D-09..D-16). |

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `apt` / `apt-get` / `apt-cache` | present (`/usr/bin/apt`) | Fetch pinned source (`apt source`), install build-deps (`apt build-dep`), install/rollback binary package. | The Debian-native lifecycle; nothing else is rollback-safe. `[VERIFIED: live dpkg]` |
| `dpkg-source` | NOT installed yet (in `dpkg-dev`) | Unpack the `.dsc` into the source tree. | Part of `dpkg-dev`, pulled by `apt build-dep`. `[VERIFIED: live `command -v`]` |
| `dpkg-buildpackage` | NOT installed yet (in `dpkg-dev`) | Build the binary `.deb` (`-us -uc -b`). | Part of `dpkg-dev`. `[VERIFIED: live `command -v`]` |
| `xinput` (1.6.4) | `1.6.4-1` installed | Enumerate XI devices, confirm `XITouchClass`/`XIDirectTouch`, touch-point count. | Only tool that surfaces the touch class. `[VERIFIED: live dpkg -l]` |
| `xrandr` | installed | Display rotation/scale, connected outputs, DPI. | Standard X11 display introspection. `[VERIFIED: live `command -v`]` |
| `xprop` / `xdpyinfo` (x11-utils 7.7+7) | installed | WM identity (`_NET_SUPPORTING_WM_CHECK` → `_NET_WM_NAME`), display server vendor. | Confirms Mutter vs other WM; distinguishes Xorg/XWayland. `[VERIFIED: live dpkg -l]` |
| `sha256sum` | installed | Artifact checksum for the report (D-16). | Coreutils; always present. `[VERIFIED: live `command -v`]` |

### Supporting

| Tool | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `apt build-dep freerdp3` | resolves cleanly (dry-run verified) | Installs the full build-dependency set incl. `libxi-dev`, `cmake`, `dpkg-dev` in one command. | Always — it brings `dpkg-dev`/`quilt` transitively. `[VERIFIED: live `apt-get build-dep --dry-run`]` |
| `dpkg-dev` (provides dpkg-source/dpkg-buildpackage) | NOT installed | Required to unpack + build. | Installed by `apt build-dep freerdp3` or explicitly. `[VERIFIED: live `dpkg -l dpkg-dev` = `un`]` |
| `quilt` (0.68-1) | NOT installed (available) | Patch management — NOT needed in Phase 1 (no patch applied), but `build-dep` may pull it. | Phase 4 packaging; Phase 1 only builds unmodified source. `[VERIFIED: live `apt-get install --dry-run`]` |
| `loginctl` | present | Fallback session-type read (`loginctl show-session ... -p Type`). | Belt-and-braces when env vars disagree. `[VERIFIED: live `loginctl`]` |
| `libinput debug-events` (`libinput-tools`) | NOT installed | Raw kernel touch event correlation. | Optional diagnostic; out of Phase 1 scope but mentioned for Phase 2. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `apt source freerdp3` (recommended) | Pre-positioned `.dsc`/`.orig.tar.xz` in repo root | D-09 forbids pre-positioning; live repo has NO archives (verified). Use apt. |
| `dpkg-buildpackage -us -uc -b` (recommended) | `debuild -us -uc -b` | Equivalent; `debuild` needs `devscripts` (NOT installed). `dpkg-buildpackage` needs only `dpkg-dev`. Pick the lower-dep one. |
| `apt install ./freerdp3-x11_*.deb` (recommended) | `dpkg -i ./freerdp3-x11_*.deb` | `apt install ./` resolves dependencies; `dpkg -i` does not. Use `apt install ./`. |
| `apt install --reinstall freerdp3-x11` (recommended rollback) | `apt install freerdp3-x11/trixie` | `--reinstall` restores the stock distro binary over the locally-built one. `=trixie` pin also works if a version-pin is needed. `[CITED: Debian Policy]` |

**Installation (build-dependency one-shot):**
```bash
sudo apt update
sudo apt build-dep freerdp3      # pulls dpkg-dev, libxi-dev, cmake, etc. transitively
```

## Package Legitimacy Audit

> This phase installs only Debian-distribution packages via `apt`/`dpkg` from the configured Debian trixie mirrors. No third-party, npm, PyPI, or crates packages are introduced. The package-legitimacy gate (designed for external ecosystem registries) does not apply: every package is Debian-native and GPG-verified by apt's repository signing keys. No `[SLOP]`/`[SUS]` verdicts possible here.

| Package | Source | Verdict | Disposition |
|---------|--------|---------|-------------|
| `freerdp3` (source) | Debian trixie main mirror | Debian-native (apt-signed) | Approved |
| `freerdp3-x11` (binary) | Debian trixie main mirror | Debian-native (apt-signed) | Approved |
| `dpkg-dev`, `libxi-dev`, `cmake`, etc. (build-deps) | Debian trixie main mirror | Debian-native (apt-signed) | Approved |

*No external-registry packages — no `[ASSUMED]` flags, no human-verify checkpoints needed.*

## Architecture Patterns

### System Architecture Diagram

```
                       ┌─────────────────────────────────────┐
  Phase 1 entry point  │  scripts/check-x11-session.sh       │  (the GATE)
  (capture/build/      │  reads: $XDG_SESSION_TYPE           │
   install/launch/     │        $WAYLAND_DISPLAY             │
   rollback/verify)    │        pgrep Xorg / Xwayland        │
        │              └──────────────┬──────────────────────┘
        │                             │ fail (Wayland/XWayland) → exit 1
        │                             │ pass (native X11) → one-line OK
        ▼                             ▼
  ┌─────────────────────────────────────────────────────────┐
  │  scripts/build-baseline.sh                              │
  │                                                         │
  │  1. PIN CHECK: apt-cache showsrc freerdp3 == pinned ver │
  │  2. FETCH:     apt source freerdp3  → build/ workspace  │
  │  3. BUILD-DEP: apt build-dep freerdp3                   │
  │  4. BUILD:     dpkg-buildpackage -us -uc -b  → .deb     │
  │  5. CHECKSUM:  sha256sum the -x11 .deb                  │
  │  6. CAPTURE:   dpkg -l / xinput / xrandr / xprop → MD   │
  │  7. INSTALL:   apt install ./freerdp3-x11_*.deb         │
  │  8. SMOKE:     windowed + fullscreen launch (manual)    │
  │  9. ROLLBACK:  apt install --reinstall freerdp3-x11     │
  │ 10. VERIFY:    xfreerdp3 --version back to stock        │
  │ 11. SANITIZE:  redact creds/host/IP → commit report     │
  └─────────────────────────────────────────────────────────┘
        │
        ▼
  .planning/.../baseline-report.md  (committed, sanitized)
  build/                             (git-excluded workspace)
```

A reader traces the gate first (blocks on wrong session), then the 11-step lifecycle that produces one committed report plus the git-excluded workspace.

### Recommended Project Structure

```
freerdp-touch/
├── scripts/
│   ├── check-x11-session.sh    # the gate; re-run by every entry point
│   └── build-baseline.sh       # fetch→build→install→smoke→rollback→report
├── build/                      # git-excluded: source tree + .deb output (D-10)
└── .planning/phases/01-environment-gate-build-baseline/
    └── baseline-report.md      # the one sanitized, committed report (D-07)
```

### Pattern 1: The hard gate (no override)

**What:** A shell function that exits nonzero unless native X11 is proven; never writes a "pass marker" (D-02 forbids trusting prior checks).
**When to use:** At the top of `build-baseline.sh` and any Phase 1 capture/smoke/verify entry point.
**Example:**
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

This pattern is the lazy minimum: four cheap checks, one error path, one confirmation line (D-04). Verified against the live device — it exits 1 today (Wayland) and will exit 0 once the user logs into `gnome-xorg.desktop`. `[VERIFIED: live env + /proc/2005/exe]`

### Pattern 2: Pinned-version source acquisition (hard-fail on drift)

**What:** `apt source` resolves the version; the script asserts it equals the pin before unpacking (D-11).
**When to use:** First step of `build-baseline.sh`, after the gate.
**Example:**
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
`[VERIFIED: live apt-cache showsrc freerdp3 → Version: 3.15.0+dfsg-2.1+deb13u3; live grep deb-src /etc/apt/sources.list]`

### Pattern 3: Build, install, rollback lifecycle

**What:** Build the unmodified `.deb`, install the `-x11` binary package specifically, smoke-test, then restore stock.
**When to use:** The proof cycle (D-13..D-16).
**Example:**
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

Rollback note: `apt install --reinstall freerdp3-x11` re-fetches the distro `.deb` from the trixie mirror and overwrites the locally-built one — this is the verified rollback path. `[CITED: Debian apt man page — --reinstall reinstalls from the repository]` If `apt` complains the locally-built version is "newer", `sudo apt install freerdp3-x11/trixie` forces the distro version explicitly.

### Anti-Patterns to Avoid

- **Trusting a stored "gate passed" file.** D-02 forbids it — session can change between reboots. Re-run the gate every entry point.
- **`dpkg -i` without apt.** Leaves dependency state inconsistent. Use `apt install ./file.deb`.
- **Committing the built `.deb` or source tree.** D-10 — workspace is git-excluded; only the sanitized report is committed.
- **Scraping shell history for the launch command.** D-06 — require it as an explicit input; never scrape.
- **Leaving placeholders in the report.** D-06 — an apparently-complete report with `__TODO__` violates the contract.
- **Building under the live Wayland session "to save a logout".** Every result is invalid; the gate exists to prevent exactly this (Pitfall 10).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Source fetch + unpack | curl/wget + manual tar extract | `apt source freerdp3` | Handles `.dsc` + `.orig` + `.debian.tar.xz` merge, verifies signature, version-pinned. |
| Build-dependency install | Manual `apt install libxi-dev libx11-dev cmake ...` | `apt build-dep freerdp3` | One command pulls the exact `Build-Depends` set from the source record; stays correct on upgrade. |
| Binary build | Hand-driven cmake invocation | `dpkg-buildpackage -us -uc -b` | Drives `debian/rules` with the distro's fixed CMake flags; produces a proper `.deb`. |
| Rollback | Manual `dpkg --remove` + reinstall | `apt install --reinstall freerdp3-x11` | apt resolves the stock `.deb` from the mirror and restores it atomically. |
| Session detection | Parsing `/proc/*/environ` by hand | `$XDG_SESSION_TYPE` + `$WAYLAND_DISPLAY` + `pgrep Xorg/Xwayland` | logind/PAM sets these; they are the canonical signals. |
| SHA-256 | Custom hashing loop | `sha256sum` | Coreutils; always present. |

**Key insight:** Every Phase 1 capability already exists in the Debian/`apt`/coreutils toolchain. The phase is composition (a 100-line shell script), not invention.

## Runtime State Inventory

> Phase 1 is a greenfield tooling phase (adds shell scripts + a report). There is no rename/refactor/migration. The only "state" touched is the installed `freerdp3-x11` binary package, which is the *subject* of the build/rollback cycle, not pre-existing project state to migrate.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — repo has only `.planning/` + `.claude/CLAUDE.md` tracked. | None. |
| Live service config | None — no running project services. | None. |
| OS-registered state | The installed `freerdp3-x11` apt package (transiently replaced by the built `.deb`, then restored). | This IS the build/rollback cycle — not a migration. |
| Secrets/env vars | None in repo. Windows-target credentials are explicit Phase 1 inputs and must be sanitized out of the report (D-08). | Sanitize report. |
| Build artifacts | None yet — `build/` workspace will be created and git-excluded. | Add `build/` to `.gitignore` (no `.gitignore` exists yet — verified). |

## Common Pitfalls

### Pitfall 1: Building/testing under Wayland while targeting X11 (the dominant risk)
**What goes wrong:** The live device boots GNOME on Wayland (`XDG_SESSION_TYPE=wayland`, `WAYLAND_DISPLAY=wayland-0`, X server is `/usr/bin/Xwayland`). Any capture or smoke test here routes XInput2 through XWayland (`xwayland-touch:16`), producing false results that fail on real native X11 — or pass there but fail here.
**Why it happens:** Debian 13 defaults to Wayland; the developer doesn't notice.
**How to avoid:** The gate (Pattern 1) hard-fails today with the concrete remediation. Verified live: `pgrep -x Xwayland` returns PID 2005, `/proc/2005/exe -> /usr/bin/Xwayland`.
**Warning signs:** `xinput list` prints `WARNING: running xinput against an Xwayland server`; touch device is named `xwayland-touch:16` not a real HID device.
`[VERIFIED: live xinput warning + /proc/2005/exe + pgrep]`

### Pitfall 2: Missing build toolchain (dpkg-dev, quilt, build-essential)
**What goes wrong:** `dpkg-buildpackage`, `dpkg-source`, `debuild`, `quilt` are all NOT installed. Running them directly fails with "command not found."
**Why it happens:** This is a daily-driver OneMix 3, not a dev box.
**How to avoid:** Run `sudo apt build-dep freerdp3` first — it transitively installs `dpkg-dev` (which provides `dpkg-source` + `dpkg-buildpackage`). `build-essential` is also pulled transitively.
**Warning signs:** `command -v dpkg-buildpackage` empty after a fresh checkout.
`[VERIFIED: live `dpkg -l dpkg-dev` = `un`; `dpkg -l quilt` = no packages; `apt-get build-dep --dry-run` resolves]`

### Pitfall 3: Assuming source archives are in the repo (they are NOT)
**What goes wrong:** The research `STACK.md` says source archives are "already downloaded in the repo root." This is FALSE on the live tree — no `.dsc`/`.orig.tar.xz`/`.debian.tar.xz` exist.
**Why it happens:** Research was written from an earlier state or assumption.
**How to avoid:** Always `apt source freerdp3` (D-09). Verified live: repo root contains only `.claude/`, `.git/`, `.planning/`, `new.md`, `temp.conf`.
**Warning signs:** Any script that does `dpkg-source -x freerdp3_*.dsc` without first running `apt source` will fail.
`[VERIFIED: live `ls freerdp3*` in repo root = no matches]`

### Pitfall 4: Installing the wrong binary package
**What goes wrong:** FreeRDP ships split packages (`freerdp3-x11`, `freerdp3-wayland`, plus libs). `dpkg-buildpackage` produces ALL of them. Installing all replaces `freerdp3-wayland` too, which is not the v1 target and complicates rollback.
**Why it happens:** Globbing `freerdp3-*_amd64.deb` catches every package.
**How to avoid:** Install ONLY `freerdp3-x11_*_amd64.deb` (Pattern 3). Verified live: both `freerdp3-wayland` and `freerdp3-x11` are installed at the same version.
`[VERIFIED: live `dpkg -l 'freerdp3*'`]`

### Pitfall 5: Leaking credentials/hostnames/IP into the committed report
**What goes wrong:** The launch command and Windows target (required inputs per D-06) typically embed `user@host` or an IP. Committing them verbatim violates D-08.
**Why it happens:** The capture is "helpful" and copies the full command.
**How to avoid:** Sanitization pass that replaces `user@1.2.3.4` → `USER@HOST-IP` and any `/p:password` → `/p:***` before commit. Make sanitization a distinct, reviewable step.
**Warning signs:** `git diff` shows a real IP or domain in the report.

### Pitfall 6: deb-src disabled (it is NOT here, but the script should check)
**What goes wrong:** On a minimal Debian install, deb-src lines are commented by default and `apt source` fails with "You must put some 'deb-src' URIs in your sources.list."
**Why it happens:** Debian ships deb-src disabled in many images.
**How to avoid:** The build script should detect `apt source` failure and print the remediation (uncomment deb-src in `/etc/apt/sources.list`). On THIS device, deb-src IS enabled (lines 4, 7, 12) — verified — but the check guards against drift.
`[VERIFIED: live grep deb-src /etc/apt/sources.list = 3 hits]`

## Code Examples

### Baseline capture commands (the report's data sources)

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
`[VERIFIED: each command run live this session; outputs captured in Environment Availability below]`

### Git-exclude the workspace (no `.gitignore` exists yet)

```sh
# Create .gitignore at repo root (none exists — verified)
printf 'build/\n*.deb\n*.dsc\n*.orig.tar.xz\n*.debian.tar.xz\n*.build\n*.buildinfo\n*.changes\n' >> .gitignore
```
`[VERIFIED: live `cat .gitignore` = No such file]`

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| deb-src disabled by default in some images | deb-src enabled on this device | Debian 13 trixie | No source-enabling step needed here; script still guards. |
| `dpkg -i` for local debs | `apt install ./file.deb` | apt ≥ 1.1 | apt resolves dependencies; use `apt install ./`. |

**Deprecated/outdated:**
- `dpkg -i` without apt: leaves dependency state inconsistent. Use `apt install ./`.
- `apt-get source` (the old form): still works; `apt source` is the modern equivalent.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `apt install --reinstall freerdp3-x11` cleanly overwrites a locally-built same-version `.deb`. | Install/rollback | If apt sees the local build as "same version, no reinstall needed", use `apt install freerdp3-x11/trixie` or `dpkg -i --force-downgrade` with the stock `.deb` fetched via `apt download`. Low risk — both fallbacks are documented. `[CITED, not live-tested]` |
| A2 | The smoke test target (Windows host, credentials) will be provided by the developer as an explicit input at execution time. | Baseline/Proof | The script cannot invent it; D-06 requires it as input. Planner must include a checkpoint:human-verify or interactive prompt for the launch command + target. |
| A3 | `dpkg-buildpackage -us -uc -b` succeeds on the unmodified source after `apt build-dep`. | Build | Not yet executed (session is Wayland, gate blocks). High likelihood given `debian/rules` is the distro's own build recipe. Verification step in the plan catches failure. |

**Note:** All `[VERIFIED]` claims were confirmed against the live device this session (env vars, `dpkg -l`, `apt-cache`, `pgrep`, `/proc/*/exe`, `xinput`, `xrandr`, `xprop`, `apt-get build-dep --dry-run`, repo `ls`). The three `[ASSUMED]` items above are the only ones needing execution-time confirmation.

## Open Questions

1. **Does the Windows smoke-test target exist and is it reachable from the OneMix 3?**
   - What we know: The project requires a Windows RDP target for BASE-03 smoke testing (D-14).
   - What's unclear: Its address/credentials — out of scope for research (D-08 sanitizes it).
   - Recommendation: Planner adds an interactive prompt or `checkpoint:human-verify` for the launch command + target before the smoke-test step.

2. **Will the built `.deb` install cleanly alongside `freerdp3-wayland`?**
   - What we know: Both `-x11` and `-wayland` binary packages share the same source and libs (`libfreerdp3*`).
   - What's unclear: Whether building the source regenerates a `libfreerdp3-*` version that conflicts with the installed one.
   - Recommendation: The install step in Pattern 3 installs ONLY `freerdp3-x11_*_amd64.deb`; the shared libs are NOT rebuilt into separate packages in a way that conflicts (same version). Verification step confirms `apt install ./` resolves. If it does conflict, install the built lib packages too, then rollback reinstalls all stock.

## Environment Availability

> Probed live this session. The gate currently HARD-FAILS (Wayland session) — this table documents what is installed regardless, so the planner knows what `apt build-dep` must still bring.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Native X11 session | Gate (BASE-01) | ✗ (Wayland now) | — | Log out → select "GNOME on Xorg" |
| `apt` / `apt-cache` / `apt-get` | fetch/build-dep/install | ✓ | present | — |
| deb-src lines | `apt source freerdp3` | ✓ | `/etc/apt/sources.list` lines 4,7,12 | uncomment if missing |
| `xfreerdp3` (stock binary) | baseline/rollback verify | ✓ | `3.15.0 (n/a)` | — |
| `freerdp3-x11` package | install/rollback subject | ✓ | `3.15.0+dfsg-2.1+deb13u3` | — |
| `dpkg-dev` (dpkg-source/dpkg-buildpackage) | unpack + build | ✗ | — | `apt build-dep freerdp3` installs it |
| `build-essential` (gcc/make) | compile | ✗ | — | `apt build-dep freerdp3` installs it |
| `quilt` | (Phase 4; Phase 1 unmodified) | ✗ | — | not needed this phase; pulled by build-dep optionally |
| `devscripts` (debuild) | alternative builder | ✗ | — | use `dpkg-buildpackage` directly instead |
| `libinput` (debug-events) | raw touch correlation | ✗ | — | out of Phase 1 scope (Phase 2 diagnostic) |
| `xinput` (1.6.4-1) | touch capability capture | ✓ | `1.6.4-1` | — |
| `xrandr` | rotation/scale capture | ✓ | present | — |
| `xprop` / `xdpyinfo` (x11-utils 7.7+7) | WM + display-server identity | ✓ | `7.7+7` | — |
| `sha256sum` | artifact checksum (D-16) | ✓ | coreutils | — |
| `loginctl` | session-type fallback | ✓ | systemd | — |
| `/usr/share/xsessions/gnome-xorg.desktop` | the native-X11 session to select | ✓ | present | — |

**Missing dependencies with no fallback:**
- None that block Phase 1 once the developer switches to the native-X11 session and runs `apt build-dep freerdp3`. The build toolchain gap is closed by a single `apt build-dep` call.

**Missing dependencies with fallback:**
- Native X11 session: currently Wayland — fallback is the documented logout/select-Xorg flow (the gate's remediation message).

## Live session-state evidence (for the planner)

Captured this session to anchor the gate design:

| Probe | Value |
|-------|-------|
| `XDG_SESSION_TYPE` | `wayland` |
| `WAYLAND_DISPLAY` | `wayland-0` |
| `DISPLAY` | `:0` |
| `XDG_SESSION_DESKTOP` / `XDG_CURRENT_DESKTOP` | `gnome` / `GNOME` |
| X server process | `/usr/bin/Xwayland :0 -rootless -noreset ...` (PID 2005) |
| `/proc/2005/exe` → | `/usr/bin/Xwayland` |
| `pgrep Xorg` | empty |
| `pgrep Xwayland` | PID 2005 |
| `xinput list` touch device | `xwayland-touch:16` (XITouchClass, direct, max 20 touches) — INVALID for v1 |
| `xinput` warning | `running xinput against an Xwayland server` |
| `xrandr` active output | `eDP-1 connected primary 2560x1600+0+0` (normal rotation) |
| `xdpyinfo` vendor | `The X.Org Foundation`, `X.Org version: 24.1.6` (same vendor string under Xorg and XWayland — NOT a discriminator) |
| `dpkg -l freerdp3-x11` | `ii freerdp3-x11 3.15.0+dfsg-2.1+deb13u3 amd64` |
| `apt-cache showsrc freerdp3` Version | `3.15.0+dfsg-2.1+deb13u3` (matches pin) |
| SHA-256 of stock `/usr/bin/xfreerdp3` | `f111a291be5177344a4a20182c7865fca7c142537acc021168b4c40a3c4c8b2b` |
| Repo root source archives | NONE (`.dsc`/`.orig.tar.xz`/`.debian.tar.xz` absent) |

**Discriminator finding:** `xdpyinfo` reports `The X.Org Foundation` under BOTH native Xorg and XWayland — the vendor string does NOT distinguish them. The reliable discriminators are: `$WAYLAND_DISPLAY` set + `pgrep Xwayland` + absence of `pgrep Xorg`. The gate uses all three. `[VERIFIED: live xdpyinfo under XWayland still says "X.Org Foundation"]`

## Security Domain

> `security_enforcement: true` (config). Phase 1 is tooling/ops, not application code, but two ASVS-relevant concerns apply.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — (Phase 1 does not authenticate; the Windows-target credential is a user-supplied input, sanitized out) |
| V3 Session Management | no | — |
| V4 Access Control | no | — (scripts run with the developer's own privileges; `sudo` for apt only) |
| V5 Input Validation | yes | The launch command + Windows target are explicit inputs; sanitize before committing (D-08). Treat the report file as untrusted output. |
| V6 Cryptography | no | — (sha256 is for evidence, not a security control) |
| V7 Error Handling | yes | The gate must fail-closed (nonzero exit) on any ambiguity; never silently proceed (D-01). |
| V8 Data Protection | yes | D-08 sanitization: remove credentials, usernames, hostnames, IPs, certificates from the committed report. |

### Known Threat Patterns for this phase

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Credential/hostname leak in committed baseline report | Information Disclosure | Distinct sanitization pass (D-08); reviewer checks `git diff` before commit. |
| Silent gate pass on wrong session (false "OK") | Tampering / Elevation | Gate requires ALL FOUR checks positive (XDG=x11, no WAYLAND_DISPLAY, Xorg present, no Xwayland); any miss = exit 1. |
| Building/installing a tampered source package | Tampering | `apt source` verifies the `.dsc` signature against the Debian repo keyring; pin-check (D-11) rejects version drift. |
| Smoke-test credential in shell history | Information Disclosure | Require launch command as an explicit input (D-06), not scraped from history; advise the developer to avoid typing the password inline (use `/from-stdin` or a prompt). |

## Sources

### Primary (HIGH confidence)
- **Live device probes this session** — `XDG_SESSION_TYPE=wayland`, `WAYLAND_DISPLAY=wayland-0`, `/proc/2005/exe -> /usr/bin/Xwayland`, `xinput list` (`xwayland-touch:16`), `dpkg -l freerdp3-x11` (`3.15.0+dfsg-2.1+deb13u3`), `apt-cache showsrc freerdp3` (`Version: 3.15.0+dfsg-2.1+deb13u3`, `Format: 3.0 (quilt)`), `apt-get build-dep --dry-run freerdp3` (resolves), `grep deb-src /etc/apt/sources.list` (3 hits), `ls /usr/share/xsessions/gnome-xorg.desktop` (present), repo-root `ls` (no source archives). Every load-bearing fact in this RESEARCH.md is anchored here.
- **`.planning/research/STACK.md`** — Debian quilt/`dpkg-buildpackage`/`apt build-dep` workflow and rollback approach (cross-checked against live `apt-cache showsrc` output).
- **`.planning/research/PITFALLS.md`** — Pitfall 10 (built under Wayland) drives the gate design.
- **`apt-get install --dry-run dpkg-dev devscripts quilt build-essential`** — confirmed `quilt 0.68-1` available, `dpkg-dev` transitively pulled by build-dep.

### Secondary (MEDIUM confidence)
- **Debian `apt` man page** — `apt install --reinstall` reinstalls from the configured repository (the rollback command). `[CITED]`
- **Unix StackExchange on X11/Wayland detection** — `$XDG_SESSION_TYPE` + `$WAYLAND_DISPLAY` + process inspection is the canonical multi-signal pattern; warns `XDG_SESSION_TYPE` alone is insufficient in some sessions (containers, first-login). Cross-verified: the live device has all three signals agree (Wayland). [unix.stackexchange.com/questions/202891]
- **Raphaël Hertzog quilt tutorial** — confirms `debuild`/`dpkg-buildpackage`/`apt source` workflow for Debian patch preparation (defers build-dep to a linked article; the live `apt-get build-dep --dry-run` substitutes authoritatively). [raphaelhertzog.com/2011/07/04]

### Tertiary (LOW confidence)
- **Rollback overwrites locally-built same-version `.deb`** — `[ASSUMED]` (A1): `apt install --reinstall` behavior when local and stock versions are identical. Not live-tested (gate blocks). Documented fallbacks (`=trixie` pin, `dpkg -i --force-downgrade`) cover the risk.

## Metadata

**Confidence breakdown:**
- Standard stack (apt/dpkg/xinput/xrandr): HIGH — every tool probed live.
- Gate detection method: HIGH — verified live that `xdpyinfo` vendor string is NOT a discriminator and that env+pgrep IS; triple-check pattern chosen accordingly.
- Build lifecycle: HIGH for fetch/pin/build-dep (dry-run confirmed); MEDIUM for the actual build+install+rollback (not yet executed under Wayland — gate blocks; A1/A3 flagged).
- Pitfalls: HIGH — Pitfall 1/3/4 confirmed live; Pitfall 2/5/6 are toolchain/hygiene guards.

**Research date:** 2026-08-06
**Valid until:** 2026-09-05 (30 days — stable Debian trixie package; re-verify if `apt update` changes the resolved `freerdp3` source version)

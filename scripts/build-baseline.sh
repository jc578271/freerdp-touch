#!/bin/sh
# scripts/build-baseline.sh
# 14-stage pipeline: gate → pin-check → fetch → build-dep → build → checksum →
# capture → explicit inputs → install → smoke → rollback → verify → sanitize → report.
# Produces one sanitized Markdown report at .planning/phases/01-environment-gate-build-baseline/baseline-report.md

set -eu

# ---------------------------------------------------------------------------
# Stage 1: GATE RE-RUN (D-02)
# ---------------------------------------------------------------------------
printf '=== Stage 1: X11 gate re-run ===\n' >&2
./scripts/check-x11-session.sh

# ---------------------------------------------------------------------------
# Stage 2: PIN-CHECK (D-11)
# ---------------------------------------------------------------------------
printf '=== Stage 2: version pin-check ===\n' >&2
PINNED="3.15.0+dfsg-2.1+deb13u3"
resolved=$(apt-cache showsrc freerdp3 | awk '/^Version:/{print $2; exit}')
if [ "$resolved" != "$PINNED" ]; then
  printf 'ERROR: apt source freerdp3 resolves to %s, expected %s.\n' \
    "$resolved" "$PINNED" >&2
  printf '       Updating the baseline requires an explicit project decision.\n' >&2
  exit 1
fi
printf 'Pin-check OK: resolved version %s matches pinned %s.\n' "$resolved" "$PINNED" >&2

# ---------------------------------------------------------------------------
# Stage 3: FETCH (D-09, D-10)
# ---------------------------------------------------------------------------
printf '=== Stage 3: fetch source ===\n' >&2
mkdir -p build
cd build
if ! apt source freerdp3 2>/dev/null; then
  printf 'ERROR: apt source freerdp3 failed.\n' >&2
  printf '       Ensure deb-src lines are enabled in /etc/apt/sources.list.\n' >&2
  printf '       Run: sudo sed -i "s/^# deb-src/deb-src/" /etc/apt/sources.list && sudo apt update\n' >&2
  exit 1
fi
SRC_DIR=$(ls -d freerdp3-*/ 2>/dev/null | head -1)
if [ -z "$SRC_DIR" ]; then
  printf 'ERROR: apt source did not produce a freerdp3 source directory.\n' >&2
  exit 1
fi
SRC_DIR="${SRC_DIR%/}"
printf 'Source unpacked to build/%s\n' "$SRC_DIR" >&2

# ---------------------------------------------------------------------------
# Stage 4: BUILD-DEP
# ---------------------------------------------------------------------------
printf '=== Stage 4: install build dependencies ===\n' >&2
sudo apt build-dep -y freerdp3

# ---------------------------------------------------------------------------
# Stage 5: BUILD (D-13)
# ---------------------------------------------------------------------------
printf '=== Stage 5: build unmodified .deb ===\n' >&2
cd "$SRC_DIR"
dpkg-buildpackage -us -uc -b -j"$(nproc)"
cd ..
DEB=$(ls freerdp3-x11_*_amd64.deb 2>/dev/null | head -1)
if [ -z "$DEB" ]; then
  printf 'ERROR: dpkg-buildpackage did not produce freerdp3-x11_*_amd64.deb.\n' >&2
  exit 1
fi
printf 'Built: %s\n' "$DEB" >&2

# ---------------------------------------------------------------------------
# Stage 6: CHECKSUM (D-16)
# ---------------------------------------------------------------------------
printf '=== Stage 6: artifact checksum ===\n' >&2
SHA=$(sha256sum "$DEB" | awk '{print $1}')
printf 'SHA-256: %s\n' "$SHA" >&2

# ---------------------------------------------------------------------------
# Stage 7: CAPTURE MACHINE FACTS (D-06 auto portion)
# ---------------------------------------------------------------------------
printf '=== Stage 7: capture machine facts ===\n' >&2

BEFORE_VERSION=$(dpkg -l freerdp3-x11 2>/dev/null | awk '/^ii/{print $2, $3, $4}')
SOURCE_VERSION=$(apt-cache showsrc freerdp3 | awk '/^Version:/{print $2; exit}')
XDISPLAY=$(xdpyinfo 2>/dev/null | grep 'name of display' | awk '{print $NF}' || echo "unknown")
XDISPLAY_VENDOR=$(xdpyinfo 2>/dev/null | grep 'vendor string' | sed 's/.*vendor string: *//' || echo "unknown")
XDISPLAY_VERSION=$(xdpyinfo 2>/dev/null | grep 'X.Org version' | sed 's/.*X.Org version: *//' || echo "unknown")
XORG_PROCS=$(pgrep -ax Xorg 2>/dev/null || echo "(none)")
XWAYLAND_PROCS=$(pgrep -ax Xwayland 2>/dev/null || echo "(none)")

# Window manager
WM_CHECK=$(xprop -root _NET_SUPPORTING_WM_CHECK 2>/dev/null | awk '{print $NF}' || echo "")
if [ -n "$WM_CHECK" ] && [ "$WM_CHECK" != "0x0" ]; then
  WM_NAME=$(xprop -id "$WM_CHECK" _NET_WM_NAME 2>/dev/null | sed 's/.*= "//;s/"$//' || echo "unknown")
else
  WM_NAME="unknown"
fi

# Touch device
XINPUT_LIST=$(xinput list 2>/dev/null || echo "(xinput failed)")
XINPUT_LONG=$(xinput list --long 2>/dev/null || echo "(xinput --long failed)")

# Display rotation/scale
XRANDR_QUERY=$(xrandr --query 2>/dev/null || echo "(xrandr failed)")
XRANDR_ACTIVE=$(xrandr --query 2>/dev/null | grep -E 'connected|^\s+\d+x\d+.*\*' || echo "(no active mode)")

# DPI
XFT_DPI=$(xprop -root RESOURCE_MANAGER 2>/dev/null | tr ';' '\n' | grep -i dpi || echo "(no Xft.dpi)")

# ---------------------------------------------------------------------------
# Stage 8: EXPLICIT INPUTS (D-06)
# ---------------------------------------------------------------------------
printf '=== Stage 8: explicit inputs ===\n' >&2
printf '\nEnter the launch command for xfreerdp3 (e.g., xfreerdp3 /v:host /u:user):\n' >&2
read -r LAUNCH_CMD
printf '\nDescribe the Windows target (e.g., Windows 11 Pro 22H2 on LAN):\n' >&2
read -r WIN_TARGET

# ---------------------------------------------------------------------------
# Stage 9: INSTALL (D-13)
# ---------------------------------------------------------------------------
printf '=== Stage 9: install built .deb ===\n' >&2
sudo apt install -y "./$DEB"
DURING_VERSION=$(dpkg -l freerdp3-x11 2>/dev/null | awk '/^ii/{print $2, $3, $4}')
printf 'Installed: %s\n' "$DURING_VERSION" >&2

# ---------------------------------------------------------------------------
# Stage 10: SMOKE TEST (D-14, D-15)
# ---------------------------------------------------------------------------
printf '=== Stage 10: smoke test ===\n' >&2
printf '\n--- WINDOWED SMOKE TEST ---\n' >&2
printf 'Run the following command in another terminal:\n' >&2
printf '  %s\n' "$LAUNCH_CMD" >&2
printf '\nVerify: desktop reached, keyboard+mouse work, clean disconnect.\n' >&2
printf 'Did the windowed smoke test pass? (yes/no): ' >&2
read -r WINDOWED_PASS

printf '\n--- FULLSCREEN SMOKE TEST ---\n' >&2
printf 'Run the following command in another terminal:\n' >&2
printf '  %s /f\n' "$LAUNCH_CMD" >&2
printf '\nVerify: desktop reached, keyboard+mouse work, clean disconnect.\n' >&2
printf 'Did the fullscreen smoke test pass? (yes/no): ' >&2
read -r FULLSCREEN_PASS

# ---------------------------------------------------------------------------
# Stage 11: ROLLBACK (D-13)
# ---------------------------------------------------------------------------
printf '=== Stage 11: rollback to stock ===\n' >&2
if sudo apt install --reinstall freerdp3-x11 -y 2>/dev/null; then
  ROLLBACK_METHOD="apt install --reinstall"
else
  printf 'Reinstall failed, trying version pin...\n' >&2
  sudo apt install -y freerdp3-x11/trixie
  ROLLBACK_METHOD="apt install freerdp3-x11/trixie"
fi
AFTER_VERSION=$(dpkg -l freerdp3-x11 2>/dev/null | awk '/^ii/{print $2, $3, $4}')
printf 'Rolled back: %s\n' "$AFTER_VERSION" >&2

# ---------------------------------------------------------------------------
# Stage 12: VERIFY STOCK
# ---------------------------------------------------------------------------
printf '=== Stage 12: verify stock ===\n' >&2
STOCK_VERIFY=$(xfreerdp3 --version 2>&1 || dpkg -l freerdp3-x11 2>/dev/null | awk '/^ii/{print $2, $3, $4}')
printf 'Stock version: %s\n' "$STOCK_VERIFY" >&2

# ---------------------------------------------------------------------------
# Stage 13: SANITIZE (D-08)
# ---------------------------------------------------------------------------
printf '=== Stage 13: sanitize ===\n' >&2

sanitize() {
  printf '%s' "$1" | sed \
    -e 's/[a-zA-Z0-9._%+-]\+@[a-zA-Z0-9.-]\+\.[a-zA-Z]\{2,\}/USER@HOST-IP/g' \
    -e 's|/p:[^ ]*|/p:***|g' \
    -e 's|\([0-9]\{1,3\}\.\)\{3\}[0-9]\{1,3\}|HOST-IP|g' \
    -e 's|//[^/@]*@|//USER@|g'
}

SAN_LAUNCH_CMD=$(sanitize "$LAUNCH_CMD")
SAN_WIN_TARGET=$(sanitize "$WIN_TARGET")

# ---------------------------------------------------------------------------
# Stage 14: REPORT (D-05, D-07, D-16)
# ---------------------------------------------------------------------------
printf '=== Stage 14: write baseline report ===\n' >&2

REPORT_DIR="../.planning/phases/01-environment-gate-build-baseline"
mkdir -p "$REPORT_DIR"
REPORT="$REPORT_DIR/baseline-report.md"

cat > "$REPORT" << BASELINE_EOF
# Baseline Report — FreeRDP Touch for OneMix 3

**Generated:** $(date -u +"%Y-%m-%dT%H:%M:%SZ")
**Phase:** 01-environment-gate-build-baseline

## Session

- **Type:** XDG_SESSION_TYPE=${session_type:-<unset>}
- **Display:** ${XDISPLAY:-<unset>}
- **Xorg processes:** ${XORG_PROCS}
- **Xwayland processes:** ${XWAYLAND_PROCS}

## Window Manager

- **WM:** ${WM_NAME}

## Installed Package (Before)

\`\`\`
${BEFORE_VERSION}
\`\`\`

## Source Version

\`\`\`
${SOURCE_VERSION}
\`\`\`

## Touch Device

\`\`\`
${XINPUT_LIST}
\`\`\`

\`\`\`
${XINPUT_LONG}
\`\`\`

## Display

\`\`\`
${XRANDR_QUERY}
\`\`\`

**Active mode:**
\`\`\`
${XRANDR_ACTIVE}
\`\`\`

**DPI:**
\`\`\`
${XFT_DPI}
\`\`\`

## Build

- **Artifact:** \`${DEB}\`
- **SHA-256:** \`${SHA}\`
- **Build command:** \`dpkg-buildpackage -us -uc -b -j\$(nproc)\`

## Install

- **During version:** ${DURING_VERSION}
- **Install command:** \`apt install ./${DEB}\`

## Smoke Test

- **Windowed:** ${WINDOWED_PASS}
- **Fullscreen:** ${FULLSCREEN_PASS}

## Rollback

- **After version:** ${AFTER_VERSION}
- **Rollback method:** ${ROLLBACK_METHOD}
- **Stock verification:** ${STOCK_VERIFY}

## Launch Command (sanitized)

\`\`\`
${SAN_LAUNCH_CMD}
\`\`\`

## Windows Target (sanitized)

\`\`\`
${SAN_WIN_TARGET}
\`\`\`
BASELINE_EOF

printf 'Report written to %s\n' "$REPORT" >&2
printf '\n=== Baseline complete ===\n' >&2
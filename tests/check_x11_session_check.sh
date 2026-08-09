#!/bin/sh
# Regression: a native Xorg on the current DISPLAY must not be rejected solely
# because an unrelated GNOME Xwayland process exists on the host.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
gate="$root/scripts/check-x11-session.sh"
td=$(mktemp -d "${TMPDIR:-/tmp}/check-x11-session.XXXXXX")
trap 'rm -rf "$td"' EXIT HUP INT TERM

printf '%s\n' \
  '#!/bin/sh' \
  'case "$*" in' \
  '  "-a -x Xorg")' \
  '    [ -n "${MOCK_XORG_LINES:-}" ] || exit 1' \
  '    printf "%s\\n" "$MOCK_XORG_LINES"' \
  '    ;;' \
  '  "-x Xorg") [ "${MOCK_XORG_PRESENT:-0}" = 1 ] ;;' \
  '  "-x Xwayland") [ "${MOCK_XWAYLAND_PRESENT:-0}" = 1 ] ;;' \
  '  *) exit 1 ;;' \
  'esac' > "$td/pgrep"
chmod 700 "$td/pgrep"

run_gate() {
  PATH="$td:$PATH" \
    XDG_SESSION_TYPE=x11 WAYLAND_DISPLAY= \
    DISPLAY="$1" MOCK_XORG_LINES="$2" MOCK_XORG_PRESENT=1 \
    MOCK_XWAYLAND_PRESENT="$3" "$gate"
}

expect_success() {
  if ! run_gate "$1" "$2" "$3" >/dev/null 2>&1; then
    printf 'FAIL: expected native Xorg on %s to pass\n' "$1" >&2
    exit 1
  fi
}

expect_failure() {
  if run_gate "$1" "$2" "$3" >/dev/null 2>&1; then
    printf 'FAIL: expected a foreign Xorg to fail for %s\n' "$1" >&2
    exit 1
  fi
}

expect_success ':2' '100 /usr/lib/xorg/Xorg :2 vt3' 1
expect_failure ':2' '101 /usr/lib/xorg/Xorg :3 vt4' 0
printf 'PASS: check-x11-session display scoping\n'

# WR-03: Wayland-negative cases — a matching Xorg process with
# Wayland indicators must still be rejected.

# XDG_SESSION_TYPE=wayland with matching Xorg → must fail
(
  PATH="$td:$PATH" \
    XDG_SESSION_TYPE=wayland WAYLAND_DISPLAY= \
    DISPLAY=':2' MOCK_XORG_LINES='100 /usr/lib/xorg/Xorg :2 vt3' MOCK_XORG_PRESENT=1 \
    MOCK_XWAYLAND_PRESENT=0 "$gate" >/dev/null 2>&1
) && { printf 'FAIL: XDG_SESSION_TYPE=wayland should fail even with matching Xorg\n' >&2; exit 1; }

# WAYLAND_DISPLAY set with matching Xorg → must fail
(
  PATH="$td:$PATH" \
    XDG_SESSION_TYPE=x11 WAYLAND_DISPLAY=wayland-0 \
    DISPLAY=':2' MOCK_XORG_LINES='100 /usr/lib/xorg/Xorg :2 vt3' MOCK_XORG_PRESENT=1 \
    MOCK_XWAYLAND_PRESENT=0 "$gate" >/dev/null 2>&1
) && { printf 'FAIL: WAYLAND_DISPLAY=wayland-0 should fail even with matching Xorg\n' >&2; exit 1; }

printf 'PASS: check-x11-session wayland-negative rejection\n'

#!/bin/sh
# scripts/check-x11-session.sh
# Exits 0 only on native Xorg; exits 1 on Wayland or XWayland. No override (D-01).
# Re-run by every Phase 1 entry point (D-02). Writes no pass-marker file.

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
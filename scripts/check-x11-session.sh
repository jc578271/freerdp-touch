#!/bin/sh
# scripts/check-x11-session.sh
# Exits 0 only when native Xorg owns the current DISPLAY; exits 1 on Wayland or XWayland.
# Re-run by every Phase 1 entry point (D-02). Writes no pass-marker file.

set -eu

session_type="${XDG_SESSION_TYPE:-}"
wayland_disp="${WAYLAND_DISPLAY:-}"
display="${DISPLAY:-}"
xorg_display="${display%%.*}"
has_xorg=0
xorg_processes="$(pgrep -a -x Xorg 2>/dev/null || true)"
if [ -n "$xorg_display" ]; then
	case " $xorg_processes " in
		*" $xorg_display "*) has_xorg=1 ;;
	esac
fi

fail() {
  detected="$1"; remedy="$2"
  printf 'ERROR: native X11 not proven (detected: %s).\n' "$detected" >&2
  printf '       %s\n' "$remedy" >&2
  printf '       Evidence: XDG_SESSION_TYPE=%s WAYLAND_DISPLAY=%s' \
    "${session_type:-<unset>}" "${wayland_disp:-<unset>}" >&2
  printf ' Xorg=%s DISPLAY=%s\n' "$has_xorg" "${display:-<unset>}" >&2
  exit 1
}

# Pass requires: XDG_SESSION_TYPE=x11, no Wayland socket, and Xorg on DISPLAY.
[ "$session_type" = "x11" ] || fail "${session_type:-unset}" \
  "Log out, then select 'GNOME on Xorg' at the GDM login screen."
[ -z "$wayland_disp" ]        || fail "Wayland (WAYLAND_DISPLAY=$wayland_disp)" \
  "WAYLAND_DISPLAY is set — this is a Wayland/XWayland session, not native X11."
[ "$has_xorg" = "1" ]         || fail "no Xorg process for display ${display:-unset}" \
  "No Xorg server owns this display. Start the TTY menu flow with startx."
printf 'OK: native X11 session verified (display %s).\n' "${display:-<unset>}"
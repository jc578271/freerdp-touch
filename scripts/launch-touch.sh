#!/usr/bin/env bash
# scripts/launch-touch.sh
# Canonical credential-free launch wrapper for xfreerdp3.
# Owns ONLY the local-touch preset. All FreeRDP connection/session arguments
# pass through unchanged. Uses Bash for arrays and PIPESTATUS[0].

set -eu

# Resolve sibling gate script source-relative
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
gate_script="$script_dir/check-x11-session.sh"

# --------------------------------------------------------------------------
# Parse --mouse-only
# --------------------------------------------------------------------------
mouse_only=0
fwd_args=()
for arg in "$@"; do
	case "$arg" in
		--mouse-only) mouse_only=1 ;;
		*) fwd_args+=("$arg") ;;
	esac
done

# --------------------------------------------------------------------------
# Compose touch args
# --------------------------------------------------------------------------
touch_args=()
if [ "$mouse_only" -eq 0 ]; then
	# --- calibration validation ---
	validate_digits() {
		# Reject non-digits and empty string
		case "$1" in
			''|*[!0-9]*) return 1 ;;
			*) return 0 ;;
		esac
	}

	lp_raw="${FREERDP_TOUCH_LONG_PRESS_MS:-600}"
	slop_raw="${FREERDP_TOUCH_SLOP_PX:-8}"

	if ! validate_digits "$lp_raw"; then
		echo "ERROR: FREERDP_TOUCH_LONG_PRESS_MS must be an unsigned integer, got '$lp_raw'" >&2
		exit 1
	fi
	if [ "$lp_raw" -lt 500 ] || [ "$lp_raw" -gt 700 ]; then
		echo "ERROR: FREERDP_TOUCH_LONG_PRESS_MS must be in 500-700, got $lp_raw" >&2
		exit 1
	fi

	if ! validate_digits "$slop_raw"; then
		echo "ERROR: FREERDP_TOUCH_SLOP_PX must be an unsigned integer, got '$slop_raw'" >&2
		exit 1
	fi
	if [ "$slop_raw" -lt 4 ] || [ "$slop_raw" -gt 16 ]; then
		echo "ERROR: FREERDP_TOUCH_SLOP_PX must be in 4-16, got $slop_raw" >&2
		exit 1
	fi

	lp_ms="$lp_raw"
	slop_px="$slop_raw"

	touch_args=(
		"+touch-pinch-wheel-fallback"
		"/touch-long-press:${lp_ms}"
		"/touch-slop:${slop_px}"
	)
fi

# --------------------------------------------------------------------------
# Native-X11 gate
# --------------------------------------------------------------------------
"$gate_script"

# --------------------------------------------------------------------------
# Invoke xfreerdp3
# --------------------------------------------------------------------------
diag="${FREERDP_TOUCH_DIAG:-}"

if [ "$diag" = "1" ]; then
	# --- Diagnostic mode ---
	umask 077

	log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/freerdp-touch"
	mkdir -p "$log_dir"
	chmod 700 "$log_dir"

	ts="$(date -u +%Y%m%dT%H%M%SZ)"
	log_path="$(mktemp "$log_dir/touch-${ts}-XXXXXX.log")"
	chmod 600 "$log_path"

	/usr/bin/xfreerdp3 "${touch_args[@]}" "${fwd_args[@]}" 2>&1 | tee "$log_path"
	exit "${PIPESTATUS[0]}"
else
	# --- Normal mode ---
	exec /usr/bin/xfreerdp3 "${touch_args[@]}" "${fwd_args[@]}"
fi

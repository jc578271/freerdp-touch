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

	validate_calibration() {
		raw="$1"
		min="$2"
		max="$3"
		label="$4"

		if ! validate_digits "$raw"; then
			echo "ERROR: $label must be an unsigned integer, got '$raw'" >&2
			exit 1
		fi

		# Reject overlong values before arithmetic (GAP-05 shell)
		if [ "${#raw}" -gt 10 ]; then
			echo "ERROR: $label value too long (max 10 digits), got $raw" >&2
			exit 1
		fi

		# Reject noncanonical leading-zero multi-digit values
		if [ "${#raw}" -gt 1 ] && [ "${raw#0}" != "$raw" ]; then
			echo "ERROR: $label must not have a leading zero, got '$raw'" >&2
			exit 1
		fi

		if [ "$raw" -lt "$min" ] || [ "$raw" -gt "$max" ]; then
			echo "ERROR: $label must be in $min-$max, got $raw" >&2
			exit 1
		fi
	}

	lp_raw="${FREERDP_TOUCH_LONG_PRESS_MS:-600}"
	slop_raw="${FREERDP_TOUCH_SLOP_PX:-8}"

	validate_calibration "$lp_raw" 500 700 "FREERDP_TOUCH_LONG_PRESS_MS"
	validate_calibration "$slop_raw" 4 16 "FREERDP_TOUCH_SLOP_PX"

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

#!/bin/sh
# Regression: menu-generated xinitrc validates and configures named XRandR outputs.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
menu=${MENU_UNDER_TEST:-"$root/scripts/menu"}

if [ ! -x "$menu" ]; then
	printf 'FAIL: MENU_UNDER_TEST is not an executable menu script\n' >&2
	exit 1
fi

grep -Fqx 'export FREERDP_ONEMIX_OUTPUT="${FREERDP_ONEMIX_OUTPUT-eDP-1}"' "$menu" || {
	printf 'FAIL: menu does not set the OneMix output default\n' >&2
	exit 1
}
grep -Fqx 'export FREERDP_EXTERNAL_OUTPUT="${FREERDP_EXTERNAL_OUTPUT-}"' "$menu" || {
	printf 'FAIL: menu does not set the external output default\n' >&2
	exit 1
}

td=$(mktemp -d "${TMPDIR:-/tmp}/menu-diagnostic-env.XXXXXX")
trap 'rm -rf "$td"' EXIT HUP INT TERM

export TEST_TMP="$td"
export MOCK_BIN="$td/bin"
export MOCK_WRAPPER="$td/mock-wrapper"
export RENDERED_XINITRC="$td/rendered-xinitrc"
export OBSERVED_DIAG="$td/observed-diag"
export OBSERVED_MOUSE_ONLY="$td/observed-mouse-only"
export OBSERVED_ARGS="$td/observed-args"
export WRAPPER_CALLS="$td/wrapper-calls"
export XRANDR_LOG="$td/xrandr.log"
export XINPUT_LOG="$td/xinput.log"
export STARTX_PASSED="$td/startx-passed"
export STARTX_ERROR="$td/startx-error"
mkdir -p "$MOCK_BIN"

printf '%s\n' \
	'#!/bin/sh' \
	'set -eu' \
	'case "${1:-}" in' \
	'  --query)' \
	'    printf "%s\\n" "Screen 0: minimum 8 x 8, current 3520 x 2560, maximum 32767 x 32767"' \
	'    if [ "${NO_EXTERNAL:-0}" -eq 1 ]; then' \
	'      printf "%s\\n" "eDP-1 connected 1600x2560+0+0 (normal left inverted right x axis y axis) 286mm x 179mm"' \
	'    else' \
	'      printf "%s\\n" "OneMixPanel connected 1600x2560+0+0 (normal left inverted right x axis y axis) 286mm x 179mm"' \
	'      printf "%s\\n" "ExternalPanel connected 1920x1080+1600+0 (normal left inverted right x axis y axis) 600mm x 340mm"' \
	'    fi' \
	'    printf "%s\\n" "DP-Disconnected disconnected (normal left inverted right x axis y axis)"' \
	'    ;;' \
	'  --listmonitors)' \
	'    printf "%s\\n" "LISTMONITORS" >> "$XRANDR_LOG"' \
	'    printf "%s\\n" "Monitors: 2" " 0: +*OneMixPanel 1600/286x2560/179+0+0 OneMixPanel" " 1: +ExternalPanel 1920/600x1080/340+1600+0 ExternalPanel"' \
	'    ;;' \
	'  --output)' \
	'    printf "%s" "OUTPUT:" >> "$XRANDR_LOG"' \
	'    for arg in "$@"; do printf " %s" "$arg" >> "$XRANDR_LOG"; done' \
	'    printf "\\n" >> "$XRANDR_LOG"' \
	'    ;;' \
	'  *)' \
	'    printf "unexpected xrandr arguments: %s\\n" "$*" >&2' \
	'    exit 1' \
	'    ;;' \
	'esac' > "$MOCK_BIN/xrandr"
chmod 700 "$MOCK_BIN/xrandr"
printf '%s\n' \
	'#!/bin/sh' \
	'set -eu' \
	'printf "%s" "XINPUT:" >> "$XINPUT_LOG"' \
	'for arg in "$@"; do printf " %s" "$arg" >> "$XINPUT_LOG"; done' \
	'printf "\\n" >> "$XINPUT_LOG"' \
	'if [ "${XINPUT_FAIL:-0}" -eq 1 ]; then' \
	'  printf "%s\\n" "injected xinput map failure" >&2' \
	'  exit 42' \
	'fi' > "$MOCK_BIN/xinput"
chmod 700 "$MOCK_BIN/xinput"

printf '%s\n' \
	'#!/bin/sh' \
	'set -eu' \
	'printf "%s\\n" called >> "$WRAPPER_CALLS"' \
	'printf "%s\\n" "${FREERDP_TOUCH_DIAG:-}" > "$OBSERVED_DIAG"' \
	'mouse_only=0' \
	'for arg in "$@"; do' \
	'  [ "$arg" = "--mouse-only" ] && mouse_only=1' \
	'done' \
	'printf "%s\\n" "$mouse_only" > "$OBSERVED_MOUSE_ONLY"' \
	'printf "%s\\n" "$@" > "$OBSERVED_ARGS"' \
	'exit 0' > "$MOCK_WRAPPER"
chmod 700 "$MOCK_WRAPPER"

printf '%s\n' \
	'#!/bin/sh' \
	'set -eu' \
	'[ "$#" -eq 1 ] || { printf "%s\\n" "unexpected startx arguments" > "$STARTX_ERROR"; exit 1; }' \
	'xinitrc=$1' \
	'if grep -Fqx "XDIAG" "$xinitrc"; then' \
	'  printf "%s\\n" "unresolved XDIAG in generated xinitrc" > "$STARTX_ERROR"' \
	'  exit 1' \
	'fi' \
	'generated_diag=0' \
	'grep -Fqx "export FREERDP_TOUCH_DIAG=1" "$xinitrc" && generated_diag=1' \
	'if [ "$generated_diag" != "${EXPECTED_DIAG:-}" ]; then' \
	'  printf "%s\\n" "diagnostic export does not match selected mode" > "$STARTX_ERROR"' \
	'  exit 1' \
	'fi' \
	'python3 - "$xinitrc" "$RENDERED_XINITRC" "$MOCK_WRAPPER" <<"PY"' \
	'from pathlib import Path' \
	'import sys' \
	'source, target, wrapper = map(Path, sys.argv[1:])' \
	'text = source.read_text()' \
	'needle = "/home/hoang/freerdp-touch/scripts/launch-touch.sh"' \
	'if text.count(needle) != 1:' \
	'    raise SystemExit("wrapper invocation missing or ambiguous")' \
	'target.write_text(text.replace(needle, str(wrapper)))' \
	'PY' \
	'if PATH="$MOCK_BIN:$PATH" bash "$RENDERED_XINITRC" > "$TEST_TMP/rendered-xinitrc.out" 2> "$TEST_TMP/rendered-xinitrc.err"; then' \
	'  : > "$STARTX_PASSED"' \
	'else' \
	'  rc=$?' \
	'  cat "$TEST_TMP/rendered-xinitrc.err" >&2' \
	'  printf "xinitrc exited with %s\\n" "$rc" > "$STARTX_ERROR"' \
	'  exit "$rc"' \
	'fi' > "$MOCK_BIN/startx"
chmod 700 "$MOCK_BIN/startx"

run_menu() {
	name=$1
	onemix=$2
	external=$3
	diag=$4
	mode=$5
	map_fail=${6:-0}
	input_file="$td/$name.input"
	printf '3\n\n\n6\n' > "$input_file"

	if [ "$external" = EMPTY ]; then
		if [ -n "$mode" ]; then
			env FREERDP_EXTERNAL_OUTPUT= FREERDP_ONEMIX_OUTPUT="$onemix" \
				FREERDP_TOUCH_DIAG="$diag" EXPECTED_DIAG="$([ "$diag" = 1 ] && printf 1 || printf 0)" \
				XINPUT_FAIL="$map_fail" NO_EXTERNAL=0 TERM=dumb PATH="$MOCK_BIN:$PATH" "$menu" "$mode" < "$input_file" \
				> "$td/$name.out" 2> "$td/$name.err"
		else
			env FREERDP_EXTERNAL_OUTPUT= FREERDP_ONEMIX_OUTPUT="$onemix" \
				FREERDP_TOUCH_DIAG="$diag" EXPECTED_DIAG="$([ "$diag" = 1 ] && printf 1 || printf 0)" \
				XINPUT_FAIL="$map_fail" NO_EXTERNAL=0 TERM=dumb PATH="$MOCK_BIN:$PATH" "$menu" < "$input_file" \
				> "$td/$name.out" 2> "$td/$name.err"
		fi
	else
		if [ -n "$mode" ]; then
			env FREERDP_ONEMIX_OUTPUT="$onemix" FREERDP_EXTERNAL_OUTPUT="$external" \
				FREERDP_TOUCH_DIAG="$diag" EXPECTED_DIAG="$([ "$diag" = 1 ] && printf 1 || printf 0)" \
				XINPUT_FAIL="$map_fail" NO_EXTERNAL=0 TERM=dumb PATH="$MOCK_BIN:$PATH" "$menu" "$mode" < "$input_file" \
				> "$td/$name.out" 2> "$td/$name.err"
		else
			env FREERDP_ONEMIX_OUTPUT="$onemix" FREERDP_EXTERNAL_OUTPUT="$external" \
				FREERDP_TOUCH_DIAG="$diag" EXPECTED_DIAG="$([ "$diag" = 1 ] && printf 1 || printf 0)" \
				XINPUT_FAIL="$map_fail" NO_EXTERNAL=0 TERM=dumb PATH="$MOCK_BIN:$PATH" "$menu" < "$input_file" \
				> "$td/$name.out" 2> "$td/$name.err"
		fi
	fi
}

assert_valid_case() {
	name=$1
	expected_diag=$2
	expected_mouse_only=$3
	expected_multimon=$4
	external=$5

	rm -f "$STARTX_PASSED" "$STARTX_ERROR" "$OBSERVED_DIAG" "$OBSERVED_MOUSE_ONLY" \
		"$OBSERVED_ARGS" "$WRAPPER_CALLS" "$XRANDR_LOG" "$XINPUT_LOG"
	: > "$XRANDR_LOG"
	: > "$XINPUT_LOG"
	EXPECTED_DIAG=$expected_diag
	export EXPECTED_DIAG
	rc=0
	run_menu "$name" OneMixPanel "$external" "$([ "$expected_diag" = 1 ] && printf 1 || printf '')" \
		"$([ "$expected_mouse_only" = 1 ] && printf -- --mouse-only || printf '')" || rc=$?
	if [ "$rc" -ne 0 ]; then
		printf 'FAIL: menu exited with rc=%s (%s)\n' "$rc" "$name" >&2
		cat "$td/$name.err" >&2
		if [ -f "$STARTX_ERROR" ]; then cat "$STARTX_ERROR" >&2; fi
		exit 1
	fi

	if [ ! -f "$STARTX_PASSED" ]; then
		failure=$(tr -d '\n' < "$STARTX_ERROR" 2>/dev/null || printf 'mock startx did not complete')
		printf 'FAIL: %s (%s)\n' "$failure" "$name" >&2
		exit 1
	fi
	actual_diag=$(tr -d '\n' < "$OBSERVED_DIAG")
	actual_mouse_only=$(tr -d '\n' < "$OBSERVED_MOUSE_ONLY")
	expected_diag_value=$([ "$expected_diag" = 1 ] && printf 1 || printf '')
	if [ "$actual_diag" != "$expected_diag_value" ] || [ "$actual_mouse_only" != "$expected_mouse_only" ]; then
		printf 'FAIL: wrapper environment or mouse-only argument mismatch (%s)\n' "$name" >&2
		exit 1
	fi
	if [ "$(wc -l < "$WRAPPER_CALLS")" -ne 1 ]; then
		printf 'FAIL: expected one wrapper call (%s)\n' "$name" >&2
		exit 1
	fi
	grep -Fqx 'OUTPUT: --output OneMixPanel --mode 1600x2560 --rotate left --primary' "$XRANDR_LOG" || {
		printf 'FAIL: missing primary XRandR layout (%s)\n' "$name" >&2; exit 1; }
	if [ "$expected_multimon" -eq 1 ]; then
		grep -Fqx 'OUTPUT: --output ExternalPanel --auto --right-of OneMixPanel' "$XRANDR_LOG" || {
			printf 'FAIL: missing external XRandR layout (%s)\n' "$name" >&2; exit 1; }
		grep -Fqx 'LISTMONITORS' "$XRANDR_LOG" || {
			printf 'FAIL: missing XRandR monitor listing (%s)\n' "$name" >&2; exit 1; }
		grep -Fqx '/multimon' "$OBSERVED_ARGS" || {
			printf 'FAIL: missing /multimon passthrough (%s)\n' "$name" >&2; exit 1; }
		grep -Fqx 'XINPUT: map-to-output GXTP7386:00 27C6:0113 OneMixPanel' "$XINPUT_LOG" || {
			printf 'FAIL: missing output-bound OneMix touchscreen map (%s)\n' "$name" >&2; exit 1; }
		if [ "$(grep -Fc 'XINPUT:' "$XINPUT_LOG")" -ne 1 ]; then
			printf 'FAIL: expected exactly one XInput mapping command (%s)\n' "$name" >&2; exit 1
		fi
		if grep -Fq 'XINPUT: set-prop' "$XINPUT_LOG"; then
			printf 'FAIL: static matrix overwrote dual-display output map (%s)\n' "$name" >&2; exit 1
		fi
		one_mix_line=$(grep -nF 'xrandr --output "$onemix_output"' "$RENDERED_XINITRC" | cut -d: -f1)
		external_line=$(grep -nF 'xrandr --output "$external_output"' "$RENDERED_XINITRC" | cut -d: -f1)
		map_line=$(grep -nF 'xinput map-to-output "GXTP7386:00 27C6:0113" "$onemix_output"' "$RENDERED_XINITRC" | cut -d: -f1)
		wrapper_line=$(grep -nF "exec $MOCK_WRAPPER" "$RENDERED_XINITRC" | cut -d: -f1)
		if [ "$one_mix_line" -ge "$external_line" ] || [ "$external_line" -ge "$map_line" ] || [ "$map_line" -ge "$wrapper_line" ]; then
			printf 'FAIL: dual-display setup order is not XRandR, map, wrapper (%s)\n' "$name" >&2; exit 1
		fi
	else
		grep -Fqx 'XINPUT: set-prop GXTP7386:00 27C6:0113 Coordinate Transformation Matrix 0 -1 1 1 0 0 0 0 1' "$XINPUT_LOG" || {
			printf 'FAIL: missing OneMix-only orientation matrix (%s)\n' "$name" >&2; exit 1; }
		if grep -Fq 'XINPUT: map-to-output' "$XINPUT_LOG"; then
			printf 'FAIL: output-bound map used during OneMix-only rollback (%s)\n' "$name" >&2
			exit 1
		fi
		if grep -Fq 'ExternalPanel' "$XRANDR_LOG"; then
			printf 'FAIL: external layout used during rollback (%s)\n' "$name" >&2
			exit 1
		fi
		if grep -Fqx '/multimon' "$OBSERVED_ARGS"; then
			printf 'FAIL: /multimon present during rollback (%s)\n' "$name" >&2
			exit 1
		fi
	fi
}

assert_rejected_case() {
	name=$1
	onemix=$2
	external=$3
	expected_error=$4

	rm -f "$STARTX_PASSED" "$STARTX_ERROR" "$OBSERVED_ARGS" "$WRAPPER_CALLS" "$XRANDR_LOG" "$XINPUT_LOG"
	: > "$XRANDR_LOG"
	: > "$XINPUT_LOG"
	rc=0
	run_menu "$name" "$onemix" "$external" '' '' || rc=$?
	if [ "$rc" -eq 0 ]; then
		printf 'FAIL: invalid output configuration was accepted (%s)\n' "$name" >&2
		exit 1
	fi
	if [ -e "$WRAPPER_CALLS" ]; then
		printf 'FAIL: wrapper ran for invalid output configuration (%s)\n' "$name" >&2
		exit 1
	fi
	grep -Fqx "$expected_error" "$td/$name.err" || {
		printf 'FAIL: missing validation error (%s)\n' "$name" >&2
		cat "$td/$name.err" >&2
		exit 1
	}
	grep -Fq 'OneMixPanel connected' "$td/$name.err" || {
		printf 'FAIL: connected-output listing missing (%s)\n' "$name" >&2
		exit 1
	}
}

assert_mapping_failure_case() {
	name=map-failure
	rm -f "$STARTX_PASSED" "$STARTX_ERROR" "$OBSERVED_ARGS" "$WRAPPER_CALLS" "$XRANDR_LOG" "$XINPUT_LOG"
	: > "$XRANDR_LOG"
	: > "$XINPUT_LOG"
	rc=0
	run_menu "$name" OneMixPanel ExternalPanel 0 '' 1 || rc=$?
	if [ "$rc" -eq 0 ]; then
		printf 'FAIL: injected XInput mapping failure was ignored\n' >&2
		exit 1
	fi
	if [ -e "$WRAPPER_CALLS" ]; then
		printf 'FAIL: wrapper ran after XInput mapping failure\n' >&2
		exit 1
	fi
	grep -Fqx 'XINPUT: map-to-output GXTP7386:00 27C6:0113 OneMixPanel' "$XINPUT_LOG" || {
		printf 'FAIL: failure case did not invoke output-bound map\n' >&2; exit 1; }
	grep -Fq 'injected xinput map failure' "$td/$name.err" || {
		printf 'FAIL: failure case did not preserve xinput error\n' >&2; exit 1; }
}

assert_plain_default_no_external_case() {
	name=plain-no-external
	input_file="$td/$name.input"
	printf '3\n\n\n6\n' > "$input_file"
	rm -f "$STARTX_PASSED" "$STARTX_ERROR" "$OBSERVED_DIAG" "$OBSERVED_MOUSE_ONLY" \
		"$OBSERVED_ARGS" "$WRAPPER_CALLS" "$XRANDR_LOG" "$XINPUT_LOG"
	: > "$XRANDR_LOG"
	: > "$XINPUT_LOG"
	rc=0
	env -u FREERDP_ONEMIX_OUTPUT -u FREERDP_EXTERNAL_OUTPUT \
		FREERDP_TOUCH_DIAG= EXPECTED_DIAG=0 XINPUT_FAIL=0 NO_EXTERNAL=1 \
		TERM=dumb PATH="$MOCK_BIN:$PATH" "$menu" < "$input_file" \
		> "$td/$name.out" 2> "$td/$name.err" || rc=$?
	if [ "$rc" -ne 0 ]; then
		printf 'FAIL: plain menu without an external monitor exited with rc=%s\n' "$rc" >&2
		cat "$td/$name.err" >&2
		if [ -f "$STARTX_ERROR" ]; then cat "$STARTX_ERROR" >&2; fi
		exit 1
	fi
	if [ ! -f "$STARTX_PASSED" ]; then
		printf 'FAIL: plain menu without an external monitor did not startx successfully\n' >&2
		exit 1
	fi
	if [ "$(wc -l < "$WRAPPER_CALLS")" -ne 1 ]; then
		printf 'FAIL: plain menu without an external monitor did not invoke the wrapper once\n' >&2
		exit 1
	fi
	grep -Fqx 'OUTPUT: --output eDP-1 --mode 1600x2560 --rotate left --primary' "$XRANDR_LOG" || {
		printf 'FAIL: plain menu did not configure the default OneMix output\n' >&2; exit 1; }
	if grep -Fq 'ExternalPanel' "$XRANDR_LOG" || grep -Fqx '/multimon' "$OBSERVED_ARGS"; then
		printf 'FAIL: plain menu enabled external-display layout without a monitor\n' >&2
		exit 1
	fi
	grep -Fqx 'XINPUT: set-prop GXTP7386:00 27C6:0113 Coordinate Transformation Matrix 0 -1 1 1 0 0 0 0 1' "$XINPUT_LOG" || {
		printf 'FAIL: plain menu without an external monitor did not retain the orientation map\n' >&2; exit 1; }
	if grep -Fq 'XINPUT: map-to-output' "$XINPUT_LOG"; then
		printf 'FAIL: plain menu used the dual-display map without an external monitor\n' >&2
		exit 1
	fi
}

assert_plain_default_no_external_case
assert_valid_case normal 0 0 1 ExternalPanel
assert_valid_case diagnostic 1 0 1 ExternalPanel
assert_valid_case mouse-only 0 1 1 ExternalPanel
assert_valid_case rollback 0 0 0 EMPTY
assert_rejected_case missing-primary '' ExternalPanel 'ERROR: FREERDP_ONEMIX_OUTPUT is required'
assert_rejected_case duplicate-output OneMixPanel OneMixPanel 'ERROR: FREERDP_ONEMIX_OUTPUT and FREERDP_EXTERNAL_OUTPUT must differ'
assert_rejected_case missing-external OneMixPanel MissingPanel "ERROR: FREERDP_EXTERNAL_OUTPUT 'MissingPanel' is not connected"
assert_mapping_failure_case
printf 'PASS: menu named XRandR layout, validation, mapping, and diagnostic propagation\n'

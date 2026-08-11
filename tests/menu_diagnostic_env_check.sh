#!/bin/sh
# Regression: menu-generated xinitrc must resolve diagnostics and pass them to its wrapper.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
menu=${MENU_UNDER_TEST:-"$root/scripts/menu"}

if [ ! -x "$menu" ]; then
	printf 'FAIL: MENU_UNDER_TEST is not an executable menu script\n' >&2
	exit 1
fi

td=$(mktemp -d "${TMPDIR:-/tmp}/menu-diagnostic-env.XXXXXX")
trap 'rm -rf "$td"' EXIT HUP INT TERM

export TEST_TMP="$td"
export MOCK_BIN="$td/bin"
export MOCK_WRAPPER="$td/mock-wrapper"
export RENDERED_XINITRC="$td/rendered-xinitrc"
export OBSERVED_DIAG="$td/observed-diag"
export OBSERVED_MOUSE_ONLY="$td/observed-mouse-only"
export STARTX_PASSED="$td/startx-passed"
export STARTX_ERROR="$td/startx-error"
mkdir -p "$MOCK_BIN"

printf '%s\n' \
	'#!/bin/sh' \
	'exit 0' > "$MOCK_BIN/xrandr"
chmod 700 "$MOCK_BIN/xrandr"
cp "$MOCK_BIN/xrandr" "$MOCK_BIN/xinput"
cp "$MOCK_BIN/xrandr" "$MOCK_BIN/openbox"
cp "$MOCK_BIN/xrandr" "$MOCK_BIN/wmctrl"

printf '%s\n' \
	'#!/bin/sh' \
	'set -eu' \
	'printf "%s\\n" "${FREERDP_TOUCH_DIAG:-}" > "$OBSERVED_DIAG"' \
	'mouse_only=0' \
	'for arg in "$@"; do' \
	'  [ "$arg" = "--mouse-only" ] && mouse_only=1' \
	'done' \
	'printf "%s\\n" "$mouse_only" > "$OBSERVED_MOUSE_ONLY"' \
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
	'grep -Fqx "openbox &" "$xinitrc" || { printf "%s\\n" "missing Openbox launch" > "$STARTX_ERROR"; exit 1; }' \
	'grep -Fq "/size:1024x640" "$xinitrc" || { printf "%s\\n" "missing 1024x640 RDP size" > "$STARTX_ERROR"; exit 1; }' \
	'! grep -Fq "/scale-desktop:" "$xinitrc" || { printf "%s\\n" "unexpected desktop scale" > "$STARTX_ERROR"; exit 1; }' \
	'grep -Fq "wmctrl -F -r FreeRDP-Touch -b add,fullscreen" "$xinitrc" || { printf "%s\\n" "missing wmctrl fullscreen request" > "$STARTX_ERROR"; exit 1; }' \
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
	'PATH="$MOCK_BIN:$PATH" bash "$RENDERED_XINITRC" >/dev/null 2>"$TEST_TMP/rendered-xinitrc.err"' \
	'actual_diag=$(tr -d "\\n" < "$OBSERVED_DIAG")' \
	'actual_mouse_only=$(tr -d "\\n" < "$OBSERVED_MOUSE_ONLY")' \
	'if [ "$actual_diag" != "${EXPECTED_DIAG_VALUE:-}" ] || [ "$actual_mouse_only" != "${EXPECTED_MOUSE_ONLY:-}" ]; then' \
	'  printf "%s\\n" "wrapper environment or mouse-only argument mismatch" > "$STARTX_ERROR"' \
	'  exit 1' \
	'fi' \
	': > "$STARTX_PASSED"' > "$MOCK_BIN/startx"
chmod 700 "$MOCK_BIN/startx"

run_case() {
	name=$1
	expected_diag=$2
	expected_mouse_only=$3
	mode=${4:-}

	EXPECTED_DIAG=$expected_diag
	EXPECTED_DIAG_VALUE=
	[ "$expected_diag" = 1 ] && EXPECTED_DIAG_VALUE=1
	EXPECTED_MOUSE_ONLY=$expected_mouse_only
	export EXPECTED_DIAG EXPECTED_DIAG_VALUE EXPECTED_MOUSE_ONLY
	rm -f "$STARTX_PASSED" "$STARTX_ERROR" "$OBSERVED_DIAG" "$OBSERVED_MOUSE_ONLY"
	printf '3\n\n\n6\n' > "$td/menu-input"

	if [ "$expected_diag" = 1 ]; then
		if [ -n "$mode" ]; then
			env FREERDP_TOUCH_DIAG=1 TERM=dumb PATH="$MOCK_BIN:$PATH" \
				"$menu" "$mode" < "$td/menu-input" > "$td/$name.out" 2> "$td/$name.err"
		else
			env FREERDP_TOUCH_DIAG=1 TERM=dumb PATH="$MOCK_BIN:$PATH" \
				"$menu" < "$td/menu-input" > "$td/$name.out" 2> "$td/$name.err"
		fi
	else
		if [ -n "$mode" ]; then
			env -u FREERDP_TOUCH_DIAG TERM=dumb PATH="$MOCK_BIN:$PATH" \
				"$menu" "$mode" < "$td/menu-input" > "$td/$name.out" 2> "$td/$name.err"
		else
			env -u FREERDP_TOUCH_DIAG TERM=dumb PATH="$MOCK_BIN:$PATH" \
				"$menu" < "$td/menu-input" > "$td/$name.out" 2> "$td/$name.err"
		fi
	fi

	if [ ! -f "$STARTX_PASSED" ]; then
		if [ -f "$STARTX_ERROR" ]; then
			failure=$(tr -d '\n' < "$STARTX_ERROR")
		else
			failure='mock startx did not complete'
		fi
		printf 'FAIL: %s (%s)\n' "$failure" "$name" >&2
		exit 1
	fi
}

run_case normal 0 0
run_case diagnostic 1 0
run_case mouse-only 0 1 --mouse-only
printf 'PASS: menu diagnostic environment propagation\n'

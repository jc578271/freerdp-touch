#!/usr/bin/env bash
# Regression: Production-wrapper and actual-menu execution through direct
# xinitrc invocation. Closes WR-02.
set -euo pipefail

root="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
td="$(mktemp -d "${TMPDIR:-/tmp}/wrapper-prod-check.XXXXXX")"
trap 'rm -rf "$td"' EXIT

# --------------------------------------------------------------------------
# Test fixtures: deterministic mocks
# --------------------------------------------------------------------------
fixture_log="$td/fixture.log"

# Mock client — records args, respects MOCK_CLIENT_FAIL
cat > "$td/mock-xfreerdp3" <<'EOF'
#!/usr/bin/env bash
printf 'CLIENT:' >> "${FIXTURE_LOG:-/dev/null}"
printf ' %q' "$@" >> "${FIXTURE_LOG:-/dev/null}"
printf '\n' >> "${FIXTURE_LOG:-/dev/null}"
if [ "${MOCK_CLIENT_FAIL:-0}" -eq 1 ]; then
  echo "mock client failure" >&2
  exit 42
fi
exit 0
EOF
chmod +x "$td/mock-xfreerdp3"

# Mock gate — always passes
printf '#!/usr/bin/env bash\nexit 0\n' > "$td/mock-check-x11"
chmod +x "$td/mock-check-x11"

# --------------------------------------------------------------------------
# Copy real wrapper, rewrite only gate and client paths
# --------------------------------------------------------------------------
wrapper_orig="$root/scripts/launch-touch.sh"
wrapper_fixture="$td/launch-touch.sh"
cp "$wrapper_orig" "$wrapper_fixture"
chmod +x "$wrapper_fixture"

# Rewrite gate_script line entirely
sed -i "s|^gate_script=.*|gate_script=$td/mock-check-x11|" "$wrapper_fixture"
# Replace /usr/bin/xfreerdp3 with mock client
sed -i "s|/usr/bin/xfreerdp3|$td/mock-xfreerdp3|" "$wrapper_fixture"

# Verify mock paths present, originals gone
if ! grep -q "$td/mock-check-x11" "$wrapper_fixture"; then
  printf 'FAIL: gate mock path not substituted\n' >&2; exit 1
fi
if grep -q '/usr/bin/xfreerdp3' "$wrapper_fixture"; then
  printf 'FAIL: xfreerdp3 path not fully substituted\n' >&2; exit 1
fi

# --------------------------------------------------------------------------
# Copy actual menu, rewrite only startx and xrandr/xinput paths
# --------------------------------------------------------------------------
menu_orig="$root/scripts/menu"
menu_fixture="$td/menu"
cp "$menu_orig" "$menu_fixture"
chmod +x "$menu_fixture"

sed -i "s|startx |$td/mock-startx |" "$menu_fixture"

mkdir -p "$td/bin"
xrandr_log="$td/xrandr.log"
printf '%s\n' \
  '#!/bin/sh' \
  'set -eu' \
  'case "${1:-}" in' \
  '  --query)' \
  '    printf "%s\\n" "Screen 0: minimum 8 x 8, current 3520 x 2560, maximum 32767 x 32767"' \
  '    printf "%s\\n" "OneMixPanel connected 1600x2560+0+0 (normal left inverted right x axis y axis) 286mm x 179mm"' \
  '    printf "%s\\n" "ExternalPanel connected 1920x1080+1600+0 (normal left inverted right x axis y axis) 600mm x 340mm"' \
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
  '  *) exit 1 ;;' \
  'esac' > "$td/bin/xrandr"
printf '%s\n' '#!/bin/sh' 'exit 0' > "$td/bin/xinput"
chmod +x "$td/bin/xrandr" "$td/bin/xinput"

# --------------------------------------------------------------------------
# Helper: run wrapper — env vars before --, wrapper args after
# --------------------------------------------------------------------------
run_wrapper() {
  local case_name="$1"; shift
  local env_vars=()
  while [ $# -gt 0 ] && [ "$1" != "--" ]; do
    env_vars+=("$1"); shift
  done
  [ $# -gt 0 ] && shift  # consume the -- separator

  > "$fixture_log"
  local rc=0
  env -i FIXTURE_LOG="$fixture_log" "${env_vars[@]}" "$wrapper_fixture" "$@" \
    > "$td/${case_name}.out" 2> "$td/${case_name}.err" || rc=$?

  local client_lines
  client_lines=$(grep -c '^CLIENT:' "$fixture_log" 2>/dev/null || true)
  printf '%d\t%d\n' "$rc" "$client_lines" > "$td/${case_name}.meta"
  if [ -s "$fixture_log" ]; then
    cp "$fixture_log" "$td/${case_name}.log"
  fi
}

# --------------------------------------------------------------------------
# 1. Normal mode — client called with touch options
# --------------------------------------------------------------------------
run_wrapper normal \
  HOME="$td" XDG_STATE_HOME="$td/state" PATH="$td:$PATH"
meta=$(cat "$td/normal.meta")
rc=$(printf '%s' "$meta" | cut -f1)
if [ "$rc" -ne 0 ]; then
  printf 'FAIL: normal: expected rc=0, got %s\n' "$rc" >&2; exit 1
fi
if ! grep -q '+touch-pinch-wheel-fallback' "$td/normal.log"; then
  printf 'FAIL: normal: missing +touch-pinch-wheel-fallback in client argv\n' >&2; exit 1
fi
if ! grep -q '/touch-long-press:500' "$td/normal.log"; then
  printf 'FAIL: normal: missing default /touch-long-press:500 in client argv\n' >&2; exit 1
fi
if ! grep -q '/touch-slop:12' "$td/normal.log"; then
  printf 'FAIL: normal: missing default /touch-slop:12 in client argv\n' >&2; exit 1
fi

# --------------------------------------------------------------------------
# 2. Mouse-only mode — no touch options
# --------------------------------------------------------------------------
run_wrapper mouse_only \
  HOME="$td" XDG_STATE_HOME="$td/state" PATH="$td:$PATH" \
  -- --mouse-only
if grep -q '+touch-pinch-wheel-fallback' "$td/mouse_only.log" 2>/dev/null; then
  printf 'FAIL: mouse_only: touch options present when --mouse-only used\n' >&2; exit 1
fi

# --------------------------------------------------------------------------
# 3. Diagnostic mode — client called, log dir created
# --------------------------------------------------------------------------
run_wrapper diagnostic \
  HOME="$td" XDG_STATE_HOME="$td/state" FREERDP_TOUCH_DIAG=1 PATH="$td:$PATH"
log_dir="$td/state/freerdp-touch"
[ -d "$log_dir" ] || { printf 'FAIL: diagnostic: log dir not created\n' >&2; exit 1; }

# --------------------------------------------------------------------------
# 4. Valid calibration boundaries — all accepted
# --------------------------------------------------------------------------
for lp in 500 600 700; do
  for slop in 4 8 16; do
    run_wrapper "cal_${lp}_${slop}" \
      HOME="$td" XDG_STATE_HOME="$td/state" \
      FREERDP_TOUCH_LONG_PRESS_MS="$lp" FREERDP_TOUCH_SLOP_PX="$slop" \
      PATH="$td:$PATH"
    if ! grep -q "/touch-long-press:${lp}" "$td/cal_${lp}_${slop}.log"; then
      printf 'FAIL: cal_%s_%s: missing /touch-long-press:%s\n' "$lp" "$slop" "$lp" >&2; exit 1
    fi
  done
done

# --------------------------------------------------------------------------
# 5. Overlong calibration — rejected
# --------------------------------------------------------------------------
run_wrapper overlong_lp \
  HOME="$td" XDG_STATE_HOME="$td/state" \
  FREERDP_TOUCH_LONG_PRESS_MS=12345678901 FREERDP_TOUCH_SLOP_PX=8 \
  PATH="$td:$PATH"
if ! grep -q 'too long' "$td/overlong_lp.err"; then
  printf 'FAIL: overlong_lp: expected "too long" rejection\n' >&2; exit 1
fi

# --------------------------------------------------------------------------
# 6. Leading-zero multi-digit — rejected
# --------------------------------------------------------------------------
run_wrapper leading_zero_lp \
  HOME="$td" XDG_STATE_HOME="$td/state" \
  FREERDP_TOUCH_LONG_PRESS_MS=0600 FREERDP_TOUCH_SLOP_PX=8 \
  PATH="$td:$PATH"
if ! grep -q 'leading zero' "$td/leading_zero_lp.err"; then
  printf 'FAIL: leading_zero_lp: expected leading zero rejection\n' >&2; exit 1
fi

# --------------------------------------------------------------------------
# 7. Out-of-range — rejected
# --------------------------------------------------------------------------
run_wrapper range_low_lp \
  HOME="$td" XDG_STATE_HOME="$td/state" \
  FREERDP_TOUCH_LONG_PRESS_MS=499 FREERDP_TOUCH_SLOP_PX=8 \
  PATH="$td:$PATH"
if ! grep -q 'must be in 500-700' "$td/range_low_lp.err"; then
  printf 'FAIL: range_low_lp: expected range rejection\n' >&2; exit 1
fi

# --------------------------------------------------------------------------
# 8. Non-digit — rejected
# --------------------------------------------------------------------------
run_wrapper nondigit \
  HOME="$td" XDG_STATE_HOME="$td/state" \
  FREERDP_TOUCH_LONG_PRESS_MS=abc FREERDP_TOUCH_SLOP_PX=8 \
  PATH="$td:$PATH"
if ! grep -q 'unsigned integer' "$td/nondigit.err"; then
  printf 'FAIL: nondigit: expected unsigned integer rejection\n' >&2; exit 1
fi

# --------------------------------------------------------------------------
# 9. Opaque argument preservation
# --------------------------------------------------------------------------
run_wrapper opaque \
  HOME="$td" XDG_STATE_HOME="$td/state" PATH="$td:$PATH" \
  -- /v:192.168.1.10 /u:testuser /p:S3cret /f
if ! grep -q '/p:S3cret' "$td/opaque.log"; then
  printf 'FAIL: opaque: password argument not forwarded\n' >&2; exit 1
fi

# --------------------------------------------------------------------------
# 10. Client failure through diagnostic tee — exit status propagated
# --------------------------------------------------------------------------
run_wrapper diag_fail \
  HOME="$td" XDG_STATE_HOME="$td/state" FREERDP_TOUCH_DIAG=1 MOCK_CLIENT_FAIL=1 \
  PATH="$td:$PATH"
meta=$(cat "$td/diag_fail.meta")
rc=$(printf '%s' "$meta" | cut -f1)
if [ "$rc" -ne 42 ]; then
  printf 'FAIL: diag_fail: expected rc=42, got %s\n' "$rc" >&2; exit 1
fi

# --------------------------------------------------------------------------
# 11. Menu startx status propagation — success and failure
# --------------------------------------------------------------------------
# Create startx mock that checks xinitrc mode and shebang, executes it directly
cat > "$td/mock-startx" <<'MOCKEOF'
#!/usr/bin/env bash
set -eu
xinitrc="$1"
mode=$(stat -c '%a' "$xinitrc" 2>/dev/null || echo "000")
if [ "$mode" != "700" ]; then
  printf 'mock-startx: xinitrc mode is %s, expected 700\n' "$mode" >&2
  exit 1
fi
head -1 "$xinitrc" | grep -q '^#!/' || {
  printf 'mock-startx: xinitrc missing shebang\n' >&2; exit 1; }
python3 - "$xinitrc" "${LAUNCH_WRAPPER:-}" <<'PY'
from pathlib import Path
import sys, os
xinitrc_path, wrapper_path = sys.argv[1], sys.argv[2]
text = Path(xinitrc_path).read_text()
needle = "/home/hoang/freerdp-touch/scripts/launch-touch.sh"
if needle in text:
    text = text.replace(needle, wrapper_path)
    Path(xinitrc_path).write_text(text)
PY
if [ "${STARTX_FAIL:-0}" -eq 1 ]; then
  exit 1
fi
bash "$xinitrc"
exit $?
MOCKEOF
chmod +x "$td/mock-startx"

# Test menu success path
printf '3\n\n\n6\n' > "$td/menu-input-success"
: > "$xrandr_log"
menu_success_rc=0
env -i TERM=dumb HOME="$td" XDG_STATE_HOME="$td/state" \
  FIXTURE_LOG="$fixture_log" FREERDP_ONEMIX_OUTPUT=OneMixPanel FREERDP_EXTERNAL_OUTPUT=ExternalPanel \
  XRANDR_LOG="$xrandr_log" \
  PATH="$td/bin:$td:$PATH" \
  LAUNCH_WRAPPER="$wrapper_fixture" \
  "$menu_fixture" < "$td/menu-input-success" > "$td/menu-success.out" 2> "$td/menu-success.err" || menu_success_rc=$?
if [ "$menu_success_rc" -ne 0 ]; then
  printf 'FAIL: menu success: expected rc=0, got rc=%s\n' "$menu_success_rc" >&2
  printf 'stderr:\n' >&2; cat "$td/menu-success.err" >&2
  exit 1
fi
if ! grep -q '/multimon' "$fixture_log"; then
  printf 'FAIL: menu success: /multimon was not forwarded to the client\n' >&2
  exit 1
fi
grep -Fq 'OUTPUT: --output OneMixPanel --mode 1600x2560 --rotate left --primary' "$xrandr_log" || {
  printf 'FAIL: menu success: missing primary XRandR layout\n' >&2; exit 1; }
grep -Fq 'OUTPUT: --output ExternalPanel --auto --above OneMixPanel' "$xrandr_log" || {
  printf 'FAIL: menu success: missing external XRandR layout\n' >&2; exit 1; }
grep -Fqx 'LISTMONITORS' "$xrandr_log" || {
  printf 'FAIL: menu success: missing XRandR monitor listing\n' >&2; exit 1; }

# Test menu failure path (startx fails)
printf '3\n\n6\n' > "$td/menu-input-fail"
menu_fail_rc=0
env -i TERM=dumb HOME="$td" XDG_STATE_HOME="$td/state" \
  FIXTURE_LOG="$fixture_log" FREERDP_ONEMIX_OUTPUT=OneMixPanel FREERDP_EXTERNAL_OUTPUT=ExternalPanel \
  XRANDR_LOG="$xrandr_log" \
  PATH="$td/bin:$td:$PATH" \
  LAUNCH_WRAPPER="$wrapper_fixture" \
  STARTX_FAIL=1 \
  "$menu_fixture" < "$td/menu-input-fail" > "$td/menu-fail.out" 2> "$td/menu-fail.err" || menu_fail_rc=$?
if [ "$menu_fail_rc" -ne 1 ]; then
  printf 'FAIL: menu fail: expected rc=1 (startx failure), got rc=%s\n' "$menu_fail_rc" >&2
  exit 1
fi

# --------------------------------------------------------------------------
# 12. CONF-01 idempotency — deterministic repeated valid input
# --------------------------------------------------------------------------
> "$fixture_log"
env -i FIXTURE_LOG="$fixture_log" HOME="$td" XDG_STATE_HOME="$td/state" PATH="$td:$PATH" \
rc1=0
  "$wrapper_fixture" > "$td/idem1.out" 2> "$td/idem1.err" || rc1=0
rc1=$?
argv1=$(grep '^CLIENT:' "$fixture_log" 2>/dev/null || echo "NONE")

> "$fixture_log"
env -i FIXTURE_LOG="$fixture_log" HOME="$td" XDG_STATE_HOME="$td/state" PATH="$td:$PATH" \
rc2=0
  "$wrapper_fixture" > "$td/idem2.out" 2> "$td/idem2.err" || rc2=0
rc2=$?
argv2=$(grep '^CLIENT:' "$fixture_log" 2>/dev/null || echo "NONE")

if [ "$rc1" -ne "$rc2" ]; then
  printf 'FAIL: idempotent-valid: status differs (%s vs %s)\n' "$rc1" "$rc2" >&2; exit 1
fi
if [ "$argv1" != "$argv2" ]; then
  printf 'FAIL: idempotent-valid: client argv differs\n' >&2; exit 1
fi

# --------------------------------------------------------------------------
# 13. CONF-01 idempotency — deterministic repeated invalid input
# --------------------------------------------------------------------------
> "$fixture_log"
env -i FIXTURE_LOG="$fixture_log" HOME="$td" XDG_STATE_HOME="$td/state" PATH="$td:$PATH" \
  FREERDP_TOUCH_LONG_PRESS_MS=0999 "$wrapper_fixture" > "$td/idem-inv1.out" 2> "$td/idem-inv1.err" || true
rc_inv1=$?

> "$fixture_log"
env -i FIXTURE_LOG="$fixture_log" HOME="$td" XDG_STATE_HOME="$td/state" PATH="$td:$PATH" \
  FREERDP_TOUCH_LONG_PRESS_MS=0999 "$wrapper_fixture" > "$td/idem-inv2.out" 2> "$td/idem-inv2.err" || true
rc_inv2=$?

if [ "$rc_inv1" -ne "$rc_inv2" ]; then
  printf 'FAIL: idempotent-invalid: status differs (%s vs %s)\n' "$rc_inv1" "$rc_inv2" >&2; exit 1
fi
calls2=$(grep -c '^CLIENT:' "$fixture_log" 2>/dev/null || true)
if [ "$calls2" -ne 0 ]; then
  printf 'FAIL: idempotent-invalid: client was called on invalid input\n' >&2; exit 1
fi

# --------------------------------------------------------------------------
# 14. Menu-generated xinitrc carries exactly one /cert:ignore
# --------------------------------------------------------------------------
cert_count=$(grep -Foc '/cert:ignore' "$menu_orig" || printf '0')
if [ "$cert_count" -ne 1 ]; then
  printf 'FAIL: menu has %s /cert:ignore occurrences (expected exactly 1)\n' "$cert_count" >&2; exit 1
fi

printf 'PASS: wrapper production and menu status regression\n'

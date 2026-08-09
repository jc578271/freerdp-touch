#!/usr/bin/env bash
# gap05_parser_check.sh — Four-package isolated-loader regression.
# Usage: bash tests/gap05_parser_check.sh [debs-dir]
# Default debs-dir: <repo-root>/build

set -euo pipefail
DEBS_DIR="${1:-$(dirname "$0")/../build}"
FAILED=0

cleanup() {
	rm -rf "${EXTRACT_ROOT:-}" "${STDOUT:-}" "${STDERR:-}"
}
trap cleanup EXIT

EXTRACT_ROOT=$(mktemp -d /tmp/gap05-extract-XXXXXX)
STDOUT=$(mktemp /tmp/gap05-out-XXXXXX)
STDERR=$(mktemp /tmp/gap05-err-XXXXXX)

# ── Select and extract the exact four-package bundle ───────────────

select_one() {
	local pfx="$1" dst="$2"
	local pkg
	pkg=$(ls "$DEBS_DIR"/${pfx}_*.deb 2>/dev/null | head -1)
	if [ -z "$pkg" ]; then
		echo "FAIL: no ${pfx} package in $DEBS_DIR"
		exit 1
	fi
	if [ "$(echo "$DEBS_DIR"/${pfx}_*.deb | wc -w)" -gt 1 ]; then
		echo "FAIL: multiple ${pfx} packages — cannot auto-select"
		exit 1
	fi
	dpkg-deb -x "$pkg" "$dst" >/dev/null 2>&1
	echo "$pkg"
}

echo "gap05: extracting four-package bundle..."
select_one "freerdp3-x11" "$EXTRACT_ROOT"
select_one "libfreerdp-client3-3" "$EXTRACT_ROOT"
select_one "libfreerdp3-3" "$EXTRACT_ROOT"
select_one "libwinpr3-3" "$EXTRACT_ROOT"

# ── Derive LD_LIBRARY_PATH from extracted shared-library dirs ─────

LIB_PATH=""
while IFS= read -r d; do
	LIB_PATH="${LIB_PATH}:${d}"
done < <(find "$EXTRACT_ROOT" -name '*.so' -o -name '*.so.*' | xargs -r dirname 2>/dev/null | sort -u)

export LD_LIBRARY_PATH="${LIB_PATH#:}"
echo "gap05: LD_LIBRARY_PATH=${LD_LIBRARY_PATH}"

# ── Prove loader resolves all 3 project SONAMEs beneath root ──────

check_soname() {
	local so="$1"
	ldd "$EXTRACT_ROOT/usr/bin/xfreerdp3" 2>/dev/null | grep -q "$so"
	local resolved
	resolved=$(ldd "$EXTRACT_ROOT/usr/bin/xfreerdp3" 2>/dev/null | grep "$so" | awk '{print $3}' || echo "")
	if [ -z "$resolved" ]; then
		echo "FAIL: $so not resolved by ldd"
		exit 1
	fi
	if [[ "$resolved" != "$EXTRACT_ROOT/"* ]]; then
		echo "FAIL: $so resolved to $resolved (outside extraction root)"
		exit 1
	fi
	echo "  $so -> $resolved (inside extraction root)"
}

echo "gap05: verifying loader resolution..."
check_soname "libfreerdp-client3.so.3"
check_soname "libfreerdp3.so.3"
check_soname "libwinpr3.so.3"

# ── Parser cases ──────────────────────────────────────────────────

XFREE="$EXTRACT_ROOT/usr/bin/xfreerdp3"
ERROR_SENTINEL="server hostname was not specified"

run_case() {
	local label="$1" opt="$2" val="$3" expect_accept="$4"
	set +e
	"$XFREE" "/touch-${opt}:${val}" >"$STDOUT" 2>"$STDERR"
	rc=$?
	set -e
	if [ "$expect_accept" = "accept" ]; then
		if [ "$rc" -ne 1 ] || ! grep -qF "$ERROR_SENTINEL" "$STDERR" 2>/dev/null; then
			echo "FAIL: $label (rc=$rc, expected 1 with sentinel)"
			cat "$STDERR" | head -3
			FAILED=1
		fi
	else
		if [ "$rc" -eq 1 ] && grep -qF "$ERROR_SENTINEL" "$STDERR" 2>/dev/null; then
			echo "FAIL: $label (accepted when should reject, rc=$rc)"
			FAILED=1
		fi
	fi
}

echo "gap05: running parser cases..."

# Canonical accepted values
run_case "long-press 500 accept" "long-press" "500" "accept"
run_case "long-press 600 accept" "long-press" "600" "accept"
run_case "long-press 700 accept" "long-press" "700" "accept"
run_case "slop 4 accept" "slop" "4" "accept"
run_case "slop 8 accept" "slop" "8" "accept"
run_case "slop 16 accept" "slop" "16" "accept"

# Range rejects
run_case "long-press 499 reject" "long-press" "499" "reject"
run_case "long-press 701 reject" "long-press" "701" "reject"
run_case "slop 3 reject" "slop" "3" "reject"
run_case "slop 17 reject" "slop" "17" "reject"

# Syntax rejects
run_case "long-press empty reject" "long-press" "" "reject"
run_case "long-press alpha reject" "long-press" "abc" "reject"
run_case "long-press signed reject" "long-press" "+600" "reject"
run_case "slop alpha reject" "slop" "xyz" "reject"

# Non-canonical leading-zero rejects
run_case "long-press 0500 reject" "long-press" "0500" "reject"
run_case "long-press 0600 reject" "long-press" "0600" "reject"
run_case "slop 04 reject" "slop" "04" "reject"
run_case "slop 08 reject" "slop" "08" "reject"

# True unsigned overflow (ULONG_MAX + 1 = 18446744073709551616 on amd64)
run_case "long-press ULONG_MAX+1 reject" "long-press" "18446744073709551616" "reject"
run_case "slop ULONG_MAX+1 reject" "slop" "18446744073709551616" "reject"

if [ "$FAILED" -eq 0 ]; then
	echo "gap05: OK (all parser cases passed)"
	exit 0
else
	echo "gap05: FAIL"
	exit 1
fi

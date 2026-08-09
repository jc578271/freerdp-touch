#!/bin/bash
# Regression: signal-safe release publication, per-publisher classifier ownership,
# and faithful scratch fixture with unchanged swap line.
# Verifies GAP-06: EXIT-only cleanup, 128+signal exits, unique per-publisher
# classifier executables via mktemp, and one cleanup per TERM case.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
release_src="$root/scripts/build-release.sh"
patch_src="$root/patches/onemix-touch.patch"

td=$(mktemp -d "${TMPDIR:-/tmp}/build-release-signal.XXXXXX")
trap 'rm -rf "$td"' EXIT HUP INT TERM

# Global CC output log across all publisher cases
CC_OUTPUT_LOG="$td/cc-outputs.log"
:> "$CC_OUTPUT_LOG"

# -----------------------------------------------------------------------
# Fixture: create shims for all external commands used by build-release.sh
# -----------------------------------------------------------------------
create_shims() {
  local fixture="$1"

  mkdir -p "$fixture/bin"

  # apt-cache showsrc: output proper deb-src format
  cat > "$fixture/bin/apt-cache" <<'S'
#!/bin/bash
case "$1" in
  showsrc) echo "Version: 3.15.0+dfsg-2.1+deb13u3" ;;
esac
S

  # dpkg-source -x: create minimal extracted tree
  cat > "$fixture/bin/dpkg-source" <<'S'
#!/bin/bash
set -eu
workdir=""
while [ $# -gt 0 ]; do case "$1" in -x) shift; shift; workdir="$1";; *) shift;; esac; done
[ -n "$workdir" ] || exit 1
mkdir -p "$workdir/debian/patches" "$workdir/client/X11"
touch "$workdir/debian/patches/series"
echo "3.15.0+dfsg-2.1+deb13u3+onemix1" > "$workdir/debian/changelog"
touch "$workdir/client/X11/test_scroll_classifier.c"
S

  # quilt: succeed
  cat > "$fixture/bin/quilt" <<'S'
#!/bin/bash
exit 0
S

  # dpkg-parsechangelog: return expected version
  cat > "$fixture/bin/dpkg-parsechangelog" <<'S'
#!/bin/bash
echo "3.15.0+dfsg-2.1+deb13u3+onemix1"
S

  # dpkg-buildpackage: create the four expected .deb files in parent dir
  cat > "$fixture/bin/dpkg-buildpackage" <<'S'
#!/bin/bash
ver="3.15.0+dfsg-2.1+deb13u3+onemix1"
arch="amd64"
parent="$(dirname "$PWD")"
for pkg in libwinpr3-3 libfreerdp3-3 libfreerdp-client3-3 freerdp3-x11; do
  touch "$parent/${pkg}_${ver}_${arch}.deb"
done
S

  # dpkg-deb: validate package metadata
  cat > "$fixture/bin/dpkg-deb" <<'S'
#!/bin/bash
set -eu
case "$1" in
  -f) shift; f="$1"; attr="$2"
    b=$(basename "$f")
    case "$attr" in
      Package) echo "${b%%_*}" ;;
      Version) v="${b#*_}"; echo "${v%_*}" ;;
      Architecture) a="${b##*_}"; echo "${a%.deb}" ;;
    esac ;;
esac
S

  # sha256sum: deterministic checksums
  cat > "$fixture/bin/sha256sum" <<'S'
#!/bin/bash
for f in "$@"; do
  printf "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  %s\n" "$(basename "$f")"
done
S

  # flock: succeed non-blocking
  cat > "$fixture/bin/flock" <<'S'
#!/bin/bash
exit 0
S

  # readlink: resolve symlink targets (avoids recursive readlink via ls -l)
  cat > "$fixture/bin/readlink" <<'S'
#!/bin/bash
if [ "$1" = "-f" ]; then
  if [ -L "$2" ]; then
    tgt=$(ls -l "$2" 2>/dev/null | awk -F' -> ' '{print $2}')
    case "$tgt" in
      /*) echo "$tgt" ;;
      *) echo "$(cd "$(dirname "$2")" && pwd)/$tgt" ;;
    esac
  else
    echo "$2"
  fi
else
  if [ -L "$2" ]; then
    ls -l "$2" 2>/dev/null | awk -F' -> ' '{print $2}'
  fi
fi
S

  # date: return fixed timestamp
  cat > "$fixture/bin/date" <<'S'
#!/bin/bash
echo "20260809T000000Z"
S

  # nproc: return 1
  cat > "$fixture/bin/nproc" <<'S'
#!/bin/bash
echo "1"
S

  # cc shim: parse -o <target>, create executable printing OK
  # Records target to CC_OUTPUT_LOG
  cat > "$fixture/bin/cc" <<'CCSHIM'
#!/bin/bash
target=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) shift; target="$1" ;;
  esac
  shift
done
[ -n "$target" ] || { echo "ERROR: cc shim: -o not found" >&2; exit 1; }
rm -f "$target"
cat > "$target" <<'EXEEOF'
#!/bin/bash
echo "OK"
EXEEOF
chmod +x "$target"
echo "$target" >> "$CC_OUTPUT_LOG"
CCSHIM

  chmod 700 "$fixture/bin"/*
}

# -----------------------------------------------------------------------
# Transform: Python adds PRE_SWAP_MARKER/POST_SWAP_MARKER waits around
# the production swap line and adds cleanup counting in cleanup().
# -----------------------------------------------------------------------
transform_script() {
  local script="$1"
  local marker_dir="$2"
  local counter_file="$3"
  local sleep_pre="$4"   # "yes" or "no" — whether to sleep at pre-swap marker

  python3 - "$script" "$marker_dir" "$counter_file" "$sleep_pre" <<'PYEOF'
import sys
script, marker_dir, counter_file, sleep_pre = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

with open(script, 'r') as f:
    content = f.read()

# The production swap line
swap_line = 'mv -Tf "$tmp_link" "${REPO_ROOT}/dist"'
count = content.count(swap_line)
assert count == 1, f"Swap line appears {count} times, expected 1"

# Add cleanup counter after "local rc=$?"
rc_line = '  local rc=$?'
rc_pos = content.find(rc_line)
assert rc_pos != -1, "local rc=$? not found"
rc_end = content.index('\n', rc_pos) + 1

counter_block = ('\n'
    '  if [ -n "${FIXTURE_CLEANUP_COUNT_FILE:-}" ]; then\n'
    '    __cnt=0\n'
    '    [ -f "$FIXTURE_CLEANUP_COUNT_FILE" ] && __cnt=$(cat "$FIXTURE_CLEANUP_COUNT_FILE")\n'
    '    echo $((__cnt + 1)) > "$FIXTURE_CLEANUP_COUNT_FILE"\n'
    '  fi\n')
content = content[:rc_end] + counter_block + content[rc_end:]

# Insert PRE_SWAP_MARKER before swap, POST_SWAP_MARKER after swap
swap_pos = content.find(swap_line)
assert swap_pos != -1, "Swap line not found after counter insertion"
swap_end = swap_pos + len(swap_line)

if sleep_pre == 'yes':
    pre_block = ('touch "${FIXTURE_MARKER_DIR:-/tmp}/pre_swap_reached" 2>/dev/null || true\n'
        'sync\n'
        'sleep 60 &\n'
        'wait $!\n')
else:
    pre_block = ('touch "${FIXTURE_MARKER_DIR:-/tmp}/pre_swap_reached" 2>/dev/null || true\n')

post_block = ('\n'
    'touch "${FIXTURE_MARKER_DIR:-/tmp}/post_swap_reached" 2>/dev/null || true\n'
    'sync\n'
    'sleep 60 &\n'
    'wait $!\n')

content = content[:swap_pos] + pre_block + content[swap_pos:swap_end] + post_block + content[swap_end:]

with open(script, 'w') as f:
    f.write(content)
PYEOF
}

# -----------------------------------------------------------------------
# Run a TERM test case
# -----------------------------------------------------------------------
run_term_case() {
  local case_name="$1"
  local marker_wait="$2"
  local setup_prior="$3"
  local expect_target="$4"
  local sleep_at_marker="$5"   # "yes" = sleep at pre-swap, "no" = touch only

  local case_dir="$td/$case_name"
  mkdir -p "$case_dir/scripts" "$case_dir/build" "$case_dir/patches"
  local marker_dir="$case_dir/markers"
  local counter_file="$case_dir/cleanup_count"
  mkdir -p "$marker_dir"

  create_shims "$case_dir"

  # Dummy input files
  touch "$case_dir/build/freerdp3_3.15.0+dfsg-2.1+deb13u3.dsc"
  touch "$case_dir/patches/onemix-touch.patch"

  # Set up prior dist if needed
  if [ "$setup_prior" = "yes" ]; then
    mkdir -p "$case_dir/.dist-bundle-prior"
    (cd "$case_dir/.dist-bundle-prior" && sha256sum /dev/null > SHA256SUMS)
    ln -sf ".dist-bundle-prior" "$case_dir/dist"
  fi

  # Copy and transform the release script
  cp "$release_src" "$case_dir/scripts/build-release.sh"
  chmod 700 "$case_dir/scripts/build-release.sh"
  transform_script "$case_dir/scripts/build-release.sh" "$marker_dir" "$counter_file" "$sleep_at_marker"

  # Verify transform was applied
  if ! grep -q 'pre_swap_reached' "$case_dir/scripts/build-release.sh"; then
    printf 'FAIL: %s: transform did not apply pre_swap marker\n' "$case_name" >&2
    exit 1
  fi

  # Initialise counter
  echo "0" > "$counter_file"

  # Run instrumented script in background
  PATH="$case_dir/bin:$PATH" \
    FIXTURE_MARKER_DIR="$marker_dir" \
    FIXTURE_CLEANUP_COUNT_FILE="$counter_file" \
    CC_OUTPUT_LOG="$CC_OUTPUT_LOG" \
    bash "$case_dir/scripts/build-release.sh" &
  local pid=$!

  # Wait for marker file
  local waited=0
  while [ ! -f "$marker_dir/${marker_wait}_reached" ]; do
    sleep 0.5
    waited=$((waited + 1))
    if [ $waited -gt 30 ]; then
      kill "$pid" 2>/dev/null || true
      set +e; wait "$pid" 2>/dev/null; set -e
      printf 'FAIL: %s: timeout waiting for %s marker\n' "$case_name" "$marker_wait" >&2
      exit 1
    fi
  done

  # Send TERM
  kill -TERM "$pid" 2>/dev/null || true
  set +e
  wait "$pid" 2>/dev/null
  local exit_code=$?
  set -e

  # Verify exit code
  if [ "$exit_code" -ne 143 ]; then
    printf 'FAIL: %s exit=%d expected 143\n' "$case_name" "$exit_code" >&2
    exit 1
  fi

  # Verify exactly one cleanup
  local cleanups
  cleanups=$(cat "$counter_file" 2>/dev/null || echo "0")
  if [ "$cleanups" -ne 1 ]; then
    printf 'FAIL: %s cleanup_count=%s expected 1\n' "$case_name" "$cleanups" >&2
    exit 1
  fi

  # Verify bundle state
  if [ "$expect_target" = "none" ]; then
    if [ -L "$case_dir/dist" ] || [ -f "$case_dir/dist" ]; then
      printf 'FAIL: %s dist exists when none expected\n' "$case_name" >&2
      exit 1
    fi
  elif [ "$expect_target" = "prior" ]; then
    if [ ! -L "$case_dir/dist" ]; then
      printf 'FAIL: %s dist missing\n' "$case_name" >&2; exit 1
    fi
    local actual
    actual=$(readlink "$case_dir/dist" 2>/dev/null || true)
    if [ "$actual" != ".dist-bundle-prior" ]; then
      printf 'FAIL: %s dist=%s expected prior\n' "$case_name" "$actual" >&2; exit 1
    fi
    if [ ! -f "$case_dir/.dist-bundle-prior/SHA256SUMS" ]; then
      printf 'FAIL: %s prior bundle missing SHA256SUMS\n' "$case_name" >&2; exit 1
    fi
  elif [ "$expect_target" = "new" ]; then
    if [ ! -L "$case_dir/dist" ]; then
      printf 'FAIL: %s dist missing\n' "$case_name" >&2; exit 1
    fi
    local actual
    actual=$(readlink "$case_dir/dist" 2>/dev/null || true)
    if [ "$actual" = ".dist-bundle-prior" ]; then
      printf 'FAIL: %s dist still prior\n' "$case_name" >&2; exit 1
    fi
    if [ ! -d "$case_dir/$actual" ]; then
      printf 'FAIL: %s new bundle %s not found\n' "$case_name" "$actual" >&2; exit 1
    fi
    if [ ! -f "$case_dir/$actual/SHA256SUMS" ]; then
      printf 'FAIL: %s new bundle missing SHA256SUMS\n' "$case_name" >&2; exit 1
    fi
  fi

  printf 'OK: %s exit=143 cleanup=1 preserved=%s\n' "$case_name" "$expect_target"
}

# =======================================================================
# Execute the three TERM cases
# =======================================================================

run_term_case "pre-swap-prior" "pre_swap" "yes" "prior" "yes"
run_term_case "post-swap-prior" "post_swap" "yes" "new" "no"
run_term_case "pre-swap-noprior" "pre_swap" "no" "none" "yes"

# =======================================================================
# Verify CC targets: nonempty and unique
# =======================================================================
cc_lines=$(wc -l < "$CC_OUTPUT_LOG")
if [ "$cc_lines" -eq 0 ]; then
  printf 'FAIL: CC_OUTPUT_LOG is empty\n' >&2
  exit 1
fi

cc_unique=$(sort -u "$CC_OUTPUT_LOG" | wc -l)
if [ "$cc_unique" -ne "$cc_lines" ]; then
  printf 'FAIL: CC targets not unique: %d total, %d unique\n' "$cc_lines" "$cc_unique" >&2
  exit 1
fi

printf 'OK: CC targets: %d entries, all unique\n' "$cc_lines"
printf 'PASS: build-release signal safety\n'

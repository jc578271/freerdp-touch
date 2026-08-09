#!/bin/bash
# scripts/build-release.sh
# Repeatable release pipeline: pin-check, fresh extraction, patch apply,
# classifier check, build, 4-package closure validation, atomic dist publication.
#
# Produces: dist/ (relative symlink) -> .dist-bundle-<iso-ts>-<pid>/
#   containing exactly: libwinpr3-3_*.deb, libfreerdp3-3_*.deb,
#   libfreerdp-client3-3_*.deb, freerdp3-x11_*.deb, SHA256SUMS
#
# Safety: fails closed. A failed build or interrupted run never corrupts or
# empties a prior valid dist target. Serialized via non-blocking flock -n.

set -eu

# ---------------------------------------------------------------------------
# Stage 1: version pin-check
# ---------------------------------------------------------------------------
printf '=== Stage 1: version pin-check ===\n' >&2
PINNED="3.15.0+dfsg-2.1+deb13u3"
resolved=$(apt-cache showsrc freerdp3 | awk '/^Version:/{print $2; exit}')
if [ "$resolved" != "$PINNED" ]; then
  printf 'ERROR: apt source freerdp3 resolves to %s, expected %s.\n' \
    "$resolved" "$PINNED" >&2
  printf '       Updating the release requires an explicit project decision.\n' >&2
  exit 1
fi
printf 'Pin-check OK: resolved version %s matches pinned %s.\n' "$resolved" "$PINNED" >&2

# Resolve repo root (scripts/ is always one level below the repo root)
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# ---------------------------------------------------------------------------
# Stage 2: acquire non-blocking lock
# ---------------------------------------------------------------------------
printf '=== Stage 2: acquire dist lock ===\n' >&2
LOCKFILE="${REPO_ROOT}/.dist.lock"
exec 9>"$LOCKFILE"
if ! flock -n 9; then
  printf 'ERROR: another publisher holds the dist lock (%s); dist untouched.\n' \
    "$LOCKFILE" >&2
  exit 1
fi
printf 'Lock acquired.\n' >&2

# Cleanup state variables (initialized BEFORE trap, set during execution)
bundle_dir=""
tmp_link=""
classifier_bin=""

# Publication-aware cleanup trap: never deletes a bundle that dist currently
# resolves to. Old-bundle sweep happens explicitly after swap success.
# Registered for EXIT only; INT/HUP/TERM get independent handlers that exit
# with 128+signal so the resulting EXIT trap runs once and preserves status.
cleanup() {
  local rc=$?
  if [ -n "$bundle_dir" ] && [ -d "$bundle_dir" ]; then
    local current_target
    current_target=$(readlink -f "${REPO_ROOT}/dist" 2>/dev/null || true)
    if [ "$current_target" != "$bundle_dir" ]; then
      rm -rf "$bundle_dir"
    fi
  fi
  rm -f "$tmp_link"
  [ -n "$classifier_bin" ] && rm -f "$classifier_bin"
  exit $rc
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 129' HUP
trap 'exit 143' TERM

# ---------------------------------------------------------------------------
# Stage 3: fresh extraction from pinned .dsc
# ---------------------------------------------------------------------------
printf '=== Stage 3: fresh extraction ===\n' >&2
DSC="${REPO_ROOT}/build/freerdp3_3.15.0+dfsg-2.1+deb13u3.dsc"
if [ ! -f "$DSC" ]; then
  printf 'ERROR: DSC file not found: %s\n' "$DSC" >&2
  exit 1
fi

WORKDIR=$(mktemp -u /tmp/onemix-build-XXXXXX)
printf 'Extracting to %s\n' "$WORKDIR" >&2
dpkg-source -x "$DSC" "$WORKDIR" >/dev/null 2>&1
printf 'Fresh extraction OK.\n' >&2

# ---------------------------------------------------------------------------
# Stage 4: patch application
# ---------------------------------------------------------------------------
printf '=== Stage 4: apply onemix-touch.patch ===\n' >&2
PATCH_SRC="${REPO_ROOT}/patches/onemix-touch.patch"
if [ ! -f "$PATCH_SRC" ]; then
  printf 'ERROR: patch not found: %s\n' "$PATCH_SRC" >&2
  exit 1
fi

cp "$PATCH_SRC" "${WORKDIR}/debian/patches/onemix-touch.patch"

# Append patch name to series (after the last non-comment, non-empty line)
SERIES="${WORKDIR}/debian/patches/series"
if ! grep -qx 'onemix-touch.patch' "$SERIES"; then
  printf 'onemix-touch.patch\n' >> "$SERIES"
fi

# Apply the full Debian patch stack (quilt push -a)
export QUILT_PATCHES=debian/patches
(
  cd "$WORKDIR"
  quilt push -a 2>&1 || {
    # If patch fails half-way, pop all to get a clean state for diag
    quilt pop -af 2>/dev/null || true
    printf 'ERROR: quilt push -a failed.\n' >&2
    exit 1
  }
)
printf 'Patch applied OK.\n' >&2

# ---------------------------------------------------------------------------
# Stage 5: version assertion
# ---------------------------------------------------------------------------
printf '=== Stage 5: version assertion ===\n' >&2
EXPECTED_VER="3.15.0+dfsg-2.1+deb13u3+onemix1"
ACTUAL_VER=$(cd "$WORKDIR" && dpkg-parsechangelog -SVersion)
if [ "$ACTUAL_VER" != "$EXPECTED_VER" ]; then
  printf 'ERROR: changelog version is %s, expected %s.\n' \
    "$ACTUAL_VER" "$EXPECTED_VER" >&2
  exit 1
fi
printf 'Version assertion OK: %s\n' "$ACTUAL_VER" >&2

# ---------------------------------------------------------------------------
# Stage 6: classifier regression check
# ---------------------------------------------------------------------------
printf '=== Stage 6: classifier regression check ===\n' >&2
classifier_bin=$(mktemp "${TMPDIR:-/tmp}/freerdp-touch-classifier.XXXXXX")
cc -DWITH_XI -o "$classifier_bin" \
  "${WORKDIR}/client/X11/test_scroll_classifier.c" -lm
CLASSIFIER_OUT=$("$classifier_bin")
if [ "$CLASSIFIER_OUT" != "OK" ]; then
  printf 'ERROR: classifier regression check failed: %s\n' "$CLASSIFIER_OUT" >&2
  exit 1
fi
rm -f "$classifier_bin"
classifier_bin=""
printf 'Classifier check: OK.\n' >&2

# ---------------------------------------------------------------------------
# Stage 7: build
# ---------------------------------------------------------------------------
printf '=== Stage 7: dpkg-buildpackage ===\n' >&2
(
  cd "$WORKDIR"
  dpkg-buildpackage -us -uc -b -j"$(nproc)"
)
printf 'Build succeeded.\n' >&2

# ---------------------------------------------------------------------------
# Stage 8: closure selection and validation
# ---------------------------------------------------------------------------
printf '=== Stage 8: select and validate 4-package closure ===\n' >&2

# The build output is in the parent of WORKDIR (/tmp/onemix-build-XXXXXX/..)
BUILD_DIR="$(dirname "$WORKDIR")"
PKG_VERSION="$EXPECTED_VER"
PKG_ARCH="amd64"

# Explicit four-package list in dependency order
PACKAGES="libwinpr3-3 libfreerdp3-3 libfreerdp-client3-3 freerdp3-x11"

for pkg in $PACKAGES; do
  DEB_FILE=$(ls "${BUILD_DIR}/${pkg}_${PKG_VERSION}_${PKG_ARCH}.deb" 2>/dev/null || true)
  if [ -z "$DEB_FILE" ]; then
    # Try with different arch suffix patterns (Debian sometimes varies)
    DEB_FILE=$(ls "${BUILD_DIR}/${pkg}_${PKG_VERSION}_"*.deb 2>/dev/null | head -1 || true)
  fi
  if [ -z "$DEB_FILE" ]; then
    printf 'ERROR: package %s not found in build output.\n' "$pkg" >&2
    printf '  Expected: %s_%s_*.deb\n' "$pkg" "$PKG_VERSION" >&2
    exit 1
  fi

  # Validate metadata
  DEB_PKG=$(dpkg-deb -f "$DEB_FILE" Package)
  DEB_VER=$(dpkg-deb -f "$DEB_FILE" Version)
  DEB_ARCH=$(dpkg-deb -f "$DEB_FILE" Architecture)

  if [ "$DEB_PKG" != "$pkg" ]; then
    printf 'ERROR: package metadata mismatch: expected Package=%s, got %s\n' \
      "$pkg" "$DEB_PKG" >&2
    exit 1
  fi
  if [ "$DEB_VER" != "$PKG_VERSION" ]; then
    printf 'ERROR: version mismatch in %s: expected %s, got %s\n' \
      "$pkg" "$PKG_VERSION" "$DEB_VER" >&2
    exit 1
  fi
  if [ "$DEB_ARCH" != "$PKG_ARCH" ]; then
    printf 'ERROR: architecture mismatch in %s: expected %s, got %s\n' \
      "$pkg" "$PKG_ARCH" "$DEB_ARCH" >&2
    exit 1
  fi
  printf 'Validated: %s %s %s\n' "$DEB_PKG" "$DEB_VER" "$DEB_ARCH" >&2
done

# ---------------------------------------------------------------------------
# Stage 9: bundle assembly and validation
# ---------------------------------------------------------------------------
printf '=== Stage 9: assemble bundle and generate SHA256SUMS ===\n' >&2

bundle_dir="${REPO_ROOT}/.dist-bundle-$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p "$bundle_dir"

for pkg in $PACKAGES; do
  DEB_FILE=$(ls "${BUILD_DIR}/${pkg}_${PKG_VERSION}_"*.deb 2>/dev/null | head -1)
  cp "$DEB_FILE" "$bundle_dir/"
done

# Generate SHA256SUMS with basenames only
(
  cd "$bundle_dir"
  sha256sum libwinpr3-3_*_amd64.deb \
            libfreerdp3-3_*_amd64.deb \
            libfreerdp-client3-3_*_amd64.deb \
            freerdp3-x11_*_amd64.deb > SHA256SUMS
)

# Verify checksums from inside the bundle directory
(cd "$bundle_dir" && sha256sum -c SHA256SUMS)
printf 'Bundle validation: SHA256SUMS OK.\n' >&2

# Count .deb files
DEB_COUNT=$(find "$bundle_dir" -maxdepth 1 -name '*.deb' | wc -l)
if [ "$DEB_COUNT" -ne 4 ]; then
  printf 'ERROR: bundle contains %d .deb files, expected 4.\n' "$DEB_COUNT" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Stage 10: atomic symlink pointer swap
# ---------------------------------------------------------------------------
printf '=== Stage 10: atomic dist pointer swap ===\n' >&2

# Create temporary relative symlink
tmp_link="${REPO_ROOT}/.dist-symlink-$$"
ln -s "$(basename "$bundle_dir")" "$tmp_link"

# Atomic swap: mv -Tf replaces dist with the new symlink atomically
mv -Tf "$tmp_link" "${REPO_ROOT}/dist"
printf 'dist now points to %s\n' "$(basename "$bundle_dir")" >&2

# At this point the trap's publication-aware guard sees dist resolving to
# bundle_dir, so the trap will not delete it on signal/error.

# ---------------------------------------------------------------------------
# Stage 11: old-bundle sweep
# ---------------------------------------------------------------------------
printf '=== Stage 11: old-bundle cleanup ===\n' >&2

CURRENT_TARGET=$(readlink "${REPO_ROOT}/dist" 2>/dev/null || true)
for old_bundle in "${REPO_ROOT}"/.dist-bundle-*; do
  [ -d "$old_bundle" ] || continue
  if [ "$(basename "$old_bundle")" != "$CURRENT_TARGET" ]; then
    rm -rf "$old_bundle"
    printf 'Cleaned up old bundle: %s\n' "$(basename "$old_bundle")" >&2
  fi
done

# ---------------------------------------------------------------------------
# Stage 12: clean up build workspace
# ---------------------------------------------------------------------------
rm -rf "$WORKDIR"
printf 'Cleaned up build workspace.\n' >&2

# ---------------------------------------------------------------------------
# Stage 13: report
# ---------------------------------------------------------------------------
printf '\n=== Release complete ===\n' >&2
printf 'Bundle: %s\n' "$(basename "$bundle_dir")" >&2
printf 'Version: %s\n' "$PKG_VERSION" >&2
printf 'Packages:\n' >&2
for pkg in $PACKAGES; do
  printf '  %s_%s_%s.deb\n' "$pkg" "$PKG_VERSION" "$PKG_ARCH" >&2
done
printf '\nChecksums:\n' >&2
cat "${REPO_ROOT}/dist/SHA256SUMS" >&2

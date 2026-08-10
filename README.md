# FreeRDP Touch for OneMix 3

A patched `xfreerdp3` that makes the OneMix 3 touchscreen practical for
daily Windows RDP use. Converts XInput2 touch input into local gesture
actions -- no external mouse needed for common interactions.

## What it does

- One-finger tap / drag = left-click / left-button drag
- One-finger long-press (500 ms) = right-click
- Two-finger vertical/horizontal scroll = wheel scroll
- Two-finger pinch = Ctrl + wheel (zoom)
- Three-finger translation = middle-button drag
- Mouse-only escape hatch (bypasses all touch handling)

## Security warning

<!-- BEGIN: accepted-cert-risk -->
**Server certificate identity is NOT verified.** v1 intentionally retains
`/cert:ignore`, disabling server certificate validation for all RDP
launches. The owner acknowledges and accepts HIGH risk of server
impersonation and man-in-the-middle attack during RDP sessions.

This is a known deferred gap (GAP-07). Reconsideration requires a
future owner-requested requirement or phase. Do not claim that server
certificate identity is protected.
<!-- END: accepted-cert-risk -->

## Prerequisites

- Debian trixie (13) on amd64
- Native X11 session reached via TTY -> startx (not GNOME on Xorg)
- `sudo apt install quilt`
- `sudo apt build-dep freerdp3`

## Build the patched package

```
./scripts/build-release.sh
```

This extracts a fresh pinned source tree (3.15.0+dfsg-2.1+deb13u3),
applies `patches/onemix-touch.patch`, builds via `dpkg-buildpackage`,
and produces `dist/` containing:

- `libwinpr3-3_3.15.0+dfsg-2.1+deb13u3+onemix1_amd64.deb`
- `libfreerdp3-3_3.15.0+dfsg-2.1+deb13u3+onemix1_amd64.deb`
- `libfreerdp-client3-3_3.15.0+dfsg-2.1+deb13u3+onemix1_amd64.deb`
- `freerdp3-x11_3.15.0+dfsg-2.1+deb13u3+onemix1_amd64.deb`
- `SHA256SUMS`

The build fails closed if the source version does not match the
expected pin.

## Install

Verify checksums first:

```
# BEGIN: checksum-verify
(cd "$(readlink -f dist)" && sha256sum -c SHA256SUMS)
# END: checksum-verify
```

Then install the exact four-package closure in one transaction (never
use a `freerdp3-*.deb` glob):

```
# BEGIN: install-four-package
# Resolve each glob to exactly one .deb — fail closed on zero or multiple.
libwinpr3_deb=$(echo ./dist/libwinpr3-3_*_amd64.deb)
libfreerdp3_deb=$(echo ./dist/libfreerdp3-3_*_amd64.deb)
libclient_deb=$(echo ./dist/libfreerdp-client3-3_*_amd64.deb)
x11_deb=$(echo ./dist/freerdp3-x11_*_amd64.deb)

for pkg in "$libwinpr3_deb" "$libfreerdp3_deb" "$libclient_deb" "$x11_deb"; do
  if [ ! -f "$pkg" ]; then
    echo "ERROR: missing package file: $pkg" >&2
    exit 1
  fi
done

sudo apt install -y --allow-downgrades \
  "$libwinpr3_deb" \
  "$libfreerdp3_deb" \
  "$libclient_deb" \
  "$x11_deb"
# END: install-four-package
```

Verify all four packages show `+onemix1`:

```
dpkg-query -W -f='${Package} ${Version}\n' \
  freerdp3-x11 libfreerdp-client3-3 libfreerdp3-3 libwinpr3-3
```

Expected output (all four lines):

```
freerdp3-x11 3.15.0+dfsg-2.1+deb13u3+onemix1
libfreerdp-client3-3 3.15.0+dfsg-2.1+deb13u3+onemix1
libfreerdp3-3 3.15.0+dfsg-2.1+deb13u3+onemix1
libwinpr3-3 3.15.0+dfsg-2.1+deb13u3+onemix1
```

## Launch

All launch modes use the three locked menu invocations only. Never
invoke `scripts/launch-touch.sh` directly from the TTY.

The canonical operating flow is: TTY login -> `menu` option 3 -> TTY
password prompt -> `startx` with a private xinitrc -> display/touch
rotation -> wrapper -> installed `/usr/bin/xfreerdp3`.

### Normal daily mode

```
menu
```

Choose option 3. Defaults: long-press 500 ms, slop 12 px.

### Diagnostic mode

```
FREERDP_TOUCH_DIAG=1 menu
```

Choose option 3. Logs compact touch/gesture/RDPEI records to stderr and
to a timestamped file under `~/.local/state/freerdp-touch/`. The log
directory is created with mode 0700 and log files with 0600.

### Mouse-only escape hatch

```
menu --mouse-only
```

Choose option 3. Omits all touch options. Same patched binary, no
rollback needed. Touch does not trigger gestures.

## Calibration overrides

Set before running `menu`:

```
FREERDP_TOUCH_LONG_PRESS_MS=650 FREERDP_TOUCH_SLOP_PX=10 menu
```

Choose option 3. Valid ranges: long-press 500-700 ms, slop 4-16 px.
Invalid values are rejected before launch.

## Roll back to stock

First, attempt reinstall:

```
sudo apt install --reinstall -y \
  freerdp3-x11 libfreerdp-client3-3 libfreerdp3-3 libwinpr3-3
```

Inspect all four package versions:

```
dpkg-query -W -f='${Package} ${Version}\n' \
  freerdp3-x11 libfreerdp-client3-3 libfreerdp3-3 libwinpr3-3
```

If ANY package still shows `+onemix1`, force the explicit trixie
closure:

```
sudo apt install -y --allow-downgrades \
  freerdp3-x11/trixie libfreerdp-client3-3/trixie \
  libfreerdp3-3/trixie libwinpr3-3/trixie
```

Assert all four are stock before launch:

```
# BEGIN: rollback-check
pkg_versions="$(dpkg-query -W -f='${Package} ${Version}\n' \
  freerdp3-x11 libfreerdp-client3-3 libfreerdp3-3 libwinpr3-3)" || {
  echo "DPKG-QUERY FAILED — cannot determine package state" >&2
  exit 1
}

# Require exactly four results
pkg_count="$(echo "$pkg_versions" | wc -l)"
if [ "$pkg_count" -ne 4 ]; then
  echo "INCOMPLETE CLOSURE — expected 4 packages, got $pkg_count:" >&2
  echo "$pkg_versions" >&2
  exit 1
fi

# All four must be stock (no +onemix1)
if echo "$pkg_versions" | grep -q '+onemix1'; then
  echo "STILL PATCHED — retry trixie closure"
  exit 1
fi

echo "ALL STOCK — safe to launch"
# END: rollback-check

After rollback, confirm stock FreeRDP works via the explicit locked
invocation:

```
menu --mouse-only
```

Choose option 3. Stock FreeRDP does not understand the patched touch
options composed by plain `menu` (they would cause an unrecognized-option
error), so `--mouse-only` is required. Verify the desktop is reached and
the mouse/touchpad works normally.

## Security-update replacement

A future `apt upgrade` may replace the local `+onemix1` build with a
newer Debian version. This is expected and preferred -- no apt hold or
pin is used.

**Detect replacement:**

```
dpkg-query -W -f='${Version}' freerdp3-x11 \
  | grep -q onemix1 || echo "Touch patch no longer installed -- rebuild on newer source if needed."
```

**Fail-closed rebase workflow:**

1. Obtain the newer source: `apt source freerdp3` or the new `.dsc`.
2. Update the base version pin in `scripts/build-release.sh` to the
   new Debian version.
3. Update the expected local version: append `+onemix1` to the new
   base version.
4. Refresh/rebase the quilt patch: extract a fresh tree from the new
   source, apply `patches/onemix-touch.patch`, resolve any conflicts
   manually, and update `debian/changelog` in the patch with the new
   local version.
5. Rerun the classifier check, build, and four-package closure
   validation via `./scripts/build-release.sh`. The script fails closed
   if the source version does not match the expected pin.
6. Reinstall the explicit new four-package bundle:

   ```
   sudo apt install -y --allow-downgrades \
     ./dist/libwinpr3-3_*_amd64.deb \
     ./dist/libfreerdp3-3_*_amd64.deb \
     ./dist/libfreerdp-client3-3_*_amd64.deb \
     ./dist/freerdp3-x11_*_amd64.deb
   ```

## What NOT to expect

- No native multitouch / RDPEI forwarding (disabled for v1)
- No runtime mode switching (planned for v2)
- No on-the-fly classifier tuning
- No configuration file
- No daemon or external input layer

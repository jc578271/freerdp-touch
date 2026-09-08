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

### Dual-monitor mode

Dual-monitor mode uses the existing TTY -> `menu` option 3 -> private
`startx` -> `scripts/launch-touch.sh` flow. It requires the native X11
session already enforced by the wrapper; Wayland and Xwayland are not the
v1 target. Connect the OneMix panel and the external display before finding
their output names.

From a terminal in the native X11 session, inspect the connected outputs:

```
xrandr --query
```

The private X server makes the external-display choice from its own
`xrandr --query` snapshot; no connector-specific external default is assumed.
The three `FREERDP_EXTERNAL_OUTPUT` states are exclusive:

- **Unset:** when `FREERDP_EXTERNAL_OUTPUT` is unset, `menu` chooses the first
  other `connected` output in query order after validating the OneMix output.
  If no other output is connected, it keeps the OneMix-only layout.
- **Explicitly empty:** `FREERDP_EXTERNAL_OUTPUT= menu` forces the OneMix-only
  layout even when other outputs are connected.
- **Named:** `FREERDP_EXTERNAL_OUTPUT="<output-name>"` selects that output. The
  private xinitrc rejects it before the wrapper starts if it is disconnected or
  equals the OneMix output, and prints the active connected-output listing.

`FREERDP_ONEMIX_OUTPUT` defaults to `eDP-1`, but it is also validated against
that private-server snapshot. Use `xrandr --query` to confirm the output names
when selecting an explicit OneMix or external output; automatic mode does not
need a connector-name assumption.

For a one-shot dual-monitor launch with an explicit external output, set both
variables on the `menu` invocation:

```
FREERDP_ONEMIX_OUTPUT="<one-mix-output-name>" \\
FREERDP_EXTERNAL_OUTPUT="<external-output-name>" \\
menu
```

Choose option 3 and enter the RDP password when prompted. The same display
configuration works with the existing diagnostic and mouse-only entry points:

```
FREERDP_ONEMIX_OUTPUT="<one-mix-output-name>" \\
FREERDP_EXTERNAL_OUTPUT="<external-output-name>" \\
FREERDP_TOUCH_DIAG=1 menu

FREERDP_ONEMIX_OUTPUT="<one-mix-output-name>" \\
FREERDP_EXTERNAL_OUTPUT="<external-output-name>" \\
menu --mouse-only
```

For automatic selection, leave `FREERDP_EXTERNAL_OUTPUT` unset and run the
same menu-only flow:

```
FREERDP_ONEMIX_OUTPUT="<one-mix-output-name>" menu
```

If an explicit external output is the normal setup, optionally add the pair to
`~/.profile` so normal `menu`, `FREERDP_TOUCH_DIAG=1 menu`, and
`menu --mouse-only` inherit it:

```
export FREERDP_ONEMIX_OUTPUT="<one-mix-output-name>"
export FREERDP_EXTERNAL_OUTPUT="<external-output-name>"
```

Log in again, or source the profile in the current shell, before launching
`menu`. The generated XRandR layout keeps the OneMix panel at
`1600x2560`, rotates it left, and marks it `--primary`; the external display
uses its preferred mode and is placed `--right-of` the OneMix panel. The
fullscreen FreeRDP invocation receives exactly one `/multimon`, preserving
the two monitor geometries instead of spanning them into one display. After
the layout, the launcher runs
`xinput map-to-output "GXTP7386:00 27C6:0113" "$FREERDP_ONEMIX_OUTPUT"` so the
absolute touchscreen stays on the OneMix output instead of being scaled across
the combined desktop.

#### Per-monitor remote desktop scale

The launcher keeps the OneMix primary at 200% and gives the selected external
monitor its own remote desktop scale. When an external output is selected,
`FREERDP_EXTERNAL_DESKTOP_SCALE` defaults to 100%; set a canonical whole-percent
value from 100 through 500 to override it:

```
FREERDP_ONEMIX_OUTPUT="<one-mix-output-name>" \\
FREERDP_EXTERNAL_OUTPUT="<external-output-name>" \\
FREERDP_EXTERNAL_DESKTOP_SCALE=140 \\
menu
```

The same setting works with diagnostic and mouse-only launches. Leave
`FREERDP_EXTERNAL_OUTPUT` unset for automatic first-external selection; the
external scale still defaults to 100. Set `FREERDP_EXTERNAL_OUTPUT=` for
OneMix-only mode; `menu` clears `FREERDP_EXTERNAL_DESKTOP_SCALE` before the
wrapper runs, so a stale external value cannot affect a local-only session.
Malformed, leading-zero, below-range, and above-range values are rejected
before the wrapper starts. The external value is monitor-layout metadata
consumed by the patched client, not a second `/scale-desktop` command-line
argument; the launcher retains exactly one global `/scale-desktop:200`.

The dual-monitor path prints `xrandr --listmonitors` before FreeRDP starts.
Verify that the list contains two monitors, the OneMix line carries the
primary marker, and the external line is present as the secondary display.
After the RDP session opens, confirm that both physical screens are active,
that the pointer crosses from the OneMix panel to the external display on
the configured right-hand side, and that the OneMix touch gestures still
behave normally.

#### Verify touch mapping

With both displays connected, tap and drag from the center and all four
corners of the OneMix panel, including the panel edge beside the external
display. The remote pointer and action must remain on the OneMix display; it
must not jump to the external display. The automated fixture verifies the
launcher command wiring only, so this physical check remains required.

#### Return to OneMix-only mode

This rollback changes only the display layout; it does not change installed
packages. Exit the RDP session so its private `startx` server stops, then
explicitly empty the external-output setting:

```
FREERDP_EXTERNAL_OUTPUT= menu
```

Choose option 3. With `FREERDP_EXTERNAL_OUTPUT` explicitly empty, the launcher
keeps the OneMix rotation and primary marker, omits the external XRandR layout
and `/multimon`, and returns to the OneMix-only path. With the variable unset,
plain `menu` automatically chooses the first other connected output in the
private server's query order and falls back to OneMix-only when none is
connected. If the variables were added to `~/.profile`, set
`export FREERDP_EXTERNAL_OUTPUT=` there for a persistent OneMix-only launch,
then log in again or source the profile before the next launch. Keep the
package rollback instructions below separate if the patched FreeRDP packages
themselves must be removed.

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

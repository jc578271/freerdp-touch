# Installation

This guide rebuilds and installs FreeRDP Touch from a fresh Git checkout when no
prebuilt `.deb` files are available.

## Requirements

- Debian 13 (trixie), amd64
- Network access for Debian build dependencies
- A native X11 session for running the patched client; do not use Wayland or
  XWayland for touch testing

The repository already contains the exact pinned Debian source package under
`src/`. No `deb-src` repository is required.

## 1. Clone the repository

Install Git if necessary:

```bash
sudo apt update
sudo apt install -y git
```

Clone the repository and enter it:

```bash
git clone <GITHUB_REPOSITORY_URL> freerdp-touch
cd freerdp-touch
```

Replace `<GITHUB_REPOSITORY_URL>` with the private or public GitHub repository
URL. If the project is already present locally, skip this step.

## 2. Install build dependencies

Install the basic build tools:

```bash
sudo apt update
sudo apt install -y quilt build-essential dpkg-dev
```

Install the dependencies declared by the tracked local `.dsc` file:

```bash
sudo apt-get build-dep -y \
  ./src/freerdp3_3.15.0+dfsg-2.1+deb13u3.dsc
```

This command reads build dependencies from the local descriptor and does not
use the currently published Debian source-package version.

## 3. Optional pre-build smoke check

Run the extraction, quilt, version, and classifier checks without building
packages or changing `dist/`:

```bash
BUILD_RELEASE_SMOKE=1 ./scripts/build-release.sh
```

A successful run ends with:

```text
Pre-build smoke completed; package build and publication skipped.
```

## 4. Build the packages

Run the release script as the normal user, not with `sudo`:

```bash
./scripts/build-release.sh
```

The script validates the tracked signed DSC, extracts a clean source tree,
applies `patches/onemix-touch.patch`, runs the classifier check, builds the
Debian packages, and publishes a bundle through the `dist` symlink.

`build-release.sh` only builds and publishes the bundle. It does **not** install
packages onto the system.

The resulting bundle contains exactly:

```text
libwinpr3-3_3.15.0+dfsg-2.1+deb13u3+onemix1_amd64.deb
libfreerdp3-3_3.15.0+dfsg-2.1+deb13u3+onemix1_amd64.deb
libfreerdp-client3-3_3.15.0+dfsg-2.1+deb13u3+onemix1_amd64.deb
freerdp3-x11_3.15.0+dfsg-2.1+deb13u3+onemix1_amd64.deb
SHA256SUMS
```

## 5. Verify the bundle

```bash
bundle="$(readlink -f dist)"
(cd "$bundle" && sha256sum -c SHA256SUMS)
```

Do not install the packages unless all four checksum checks report `OK`.

## 6. Install FreeRDP Touch

Install the exact four-package closure in one transaction:

```bash
bundle="$(readlink -f dist)"

sudo apt install -y --allow-downgrades \
  "$bundle/libwinpr3-3_3.15.0+dfsg-2.1+deb13u3+onemix1_amd64.deb" \
  "$bundle/libfreerdp3-3_3.15.0+dfsg-2.1+deb13u3+onemix1_amd64.deb" \
  "$bundle/libfreerdp-client3-3_3.15.0+dfsg-2.1+deb13u3+onemix1_amd64.deb" \
  "$bundle/freerdp3-x11_3.15.0+dfsg-2.1+deb13u3+onemix1_amd64.deb"
```

Do not use a broad `freerdp3-*.deb` glob. The patched client requires all four
packages at the same exact version.

## 7. Verify the installed versions

```bash
dpkg-query -W -f='${Package} ${Version}\n' \
  freerdp3-x11 \
  libfreerdp-client3-3 \
  libfreerdp3-3 \
  libwinpr3-3
```

Every reported version must end with:

```text
+onemix1
```

## 8. Launch in native X11

The `.deb` packages install the patched `/usr/bin/xfreerdp3` binary and its
libraries. The repository's `menu`, `launch-touch.sh`, and
`check-x11-session.sh` files are optional custom scripts and are not installed
by the packages.

From a native X11 terminal, the local-only touch preset can be launched
directly with:

```bash
/usr/bin/xfreerdp3 \
  +touch-pinch-wheel-fallback \
  /touch-long-press:600 \
  /touch-slop:8 \
  /v:WINDOWS_HOST \
  /u:WINDOWS_USER \
  /f \
  /cert:ignore
```

Do not add `+multitouch`. Omitting `/p:<password>` lets FreeRDP request the
password interactively instead of placing it in the command line.

> **Security:** `/cert:ignore` disables server-certificate identity validation
> and carries accepted HIGH risk of server impersonation or a man-in-the-middle
> attack. Remove it only after configuring a trusted certificate policy.

## Package upgrades

A later Debian security update may replace the local build because this project
does not hold or pin the packages. Check whether the patch is still installed:

```bash
dpkg-query -W -f='${Version}\n' freerdp3-x11 \
  | grep -q '+onemix1' \
  || echo 'FreeRDP Touch is not installed; rebuild and reinstall the four-package closure.'
```

## Roll back to Debian FreeRDP

First try reinstalling the repository packages:

```bash
sudo apt install --reinstall -y \
  freerdp3-x11 libfreerdp-client3-3 libfreerdp3-3 libwinpr3-3
```

If any installed version still contains `+onemix1`, explicitly restore the
trixie package closure:

```bash
sudo apt install -y --allow-downgrades \
  freerdp3-x11/trixie \
  libfreerdp-client3-3/trixie \
  libfreerdp3-3/trixie \
  libwinpr3-3/trixie
```

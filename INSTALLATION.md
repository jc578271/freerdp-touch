# Installation

For Debian 13 (trixie), amd64.

## 1. Clone

```bash
sudo apt update
sudo apt install -y git

git clone <GITHUB_REPOSITORY_URL> freerdp-touch
cd freerdp-touch
```

Replace `<GITHUB_REPOSITORY_URL>` with your repository URL.

## 2. Install build dependencies

```bash
sudo apt install -y quilt build-essential dpkg-dev xinput

sudo apt-get build-dep -y \
  ./src/freerdp3_3.15.0+dfsg-2.1+deb13u3.dsc
```

## 3. Build

Run as the normal user, without `sudo`:

```bash
./scripts/build-release.sh
```

This creates the four packages under `dist/`. It does not install them.

## 4. Verify and install or reinstall

Run this copy-paste script from the repository root after each build. It verifies and installs exactly the four packages in the current `dist/` bundle, even when the version string has not changed.

```bash
(
  set -eu
  bundle="$(readlink -f dist)"

  cd "$bundle"
  sha256sum -c SHA256SUMS

  sudo apt install -y --reinstall --allow-downgrades \
    "$bundle/libwinpr3-3_3.15.0+dfsg-2.1+deb13u3+onemix1_amd64.deb" \
    "$bundle/libfreerdp3-3_3.15.0+dfsg-2.1+deb13u3+onemix1_amd64.deb" \
    "$bundle/libfreerdp-client3-3_3.15.0+dfsg-2.1+deb13u3+onemix1_amd64.deb" \
    "$bundle/freerdp3-x11_3.15.0+dfsg-2.1+deb13u3+onemix1_amd64.deb"
)
```

## 5. Confirm

```bash
dpkg-query -W -f='${Package} ${Version}\n' \
  freerdp3-x11 \
  libfreerdp-client3-3 \
  libfreerdp3-3 \
  libwinpr3-3
```

All four versions must contain `+onemix1`.

## 6. Install the custom menu (optional)

```bash
sudo install -m 0755 ./scripts/menu /usr/local/bin/menu
```

Run it with:

```bash
menu
```

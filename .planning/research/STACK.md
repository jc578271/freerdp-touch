# Stack Research

**Domain:** FreeRDP X11 client input patching (XInput2 touch → RDPEI native touch, with gesture fallback)
**Researched:** 2026-08-05
**Confidence:** HIGH (core claims verified against local Debian source tarball AND upstream 3.30 source)

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| FreeRDP (Debian source) | `3.15.0+dfsg-2.1+deb13u3` | The exact `xfreerdp3` you are patching — pin to the installed Debian trixie version so the `.deb` replaces the binary the user already runs. | The project constraint is "build against the FreeRDP version currently packaged on the device." Source is already downloaded in the repo root (`.dsc` + `.orig.tar.xz` + `.debian.tar.xz`). The patch applies on top of the Debian quilt patch stack. Building a different upstream version would create an upgrade-tracking burden with zero v1 benefit. |
| C (C17) + CMake | gcc-14 / cmake 3.x | FreeRDP's native build system. No new language or build tool introduced. | The patch is C in two existing files; CMake is already driven by `debian/rules`. Adding any other toolchain would be pure overhead. |
| XInput2 (libXi) | XI 2.2 minimum, server reports 2.4 | Touch event capture: `XI_TouchBegin` / `XI_TouchUpdate` / `XI_TouchEnd`, selected via `XISetMask` + `XISelectEvents`. | FreeRDP already requires `WITH_XI` (build-dep `libxi-dev`) and gates all touch code behind `#ifdef WITH_XI`. The XI 2.2 touch API is what the existing `register_input_events()` already uses — no extension upgrade needed. OneMix 3 server reports XI 2.4. |
| RDPEI channel (MS-RDPEI) | protocol V10–V300 | Sends real touch contacts to Windows as native multitouch. Already implemented in `channels/rdpei/client/`. | This is the whole reason to patch the client instead of writing a uinput daemon — RDPEI is the only path that gives Windows apps real `WM_TOUCH`. FreeRDP's implementation handles frame batching (~20ms), contact ID mapping, and state transitions per the MS-RDPEI spec. |
| Debian quilt (3.0 format) | dpkg-dev, debhelper-compat 13 | Ship the patch as one or more `.patch` files in `debian/patches/` over the Debian source, rebuild `.deb`. | The source package is already `Format: 3.0 (quilt)`. Adding a patch means `quilt new` → `quilt add` → edit → `quilt refresh`, append to `series`, then `dpkg-buildpackage -us -uc -b`. This is the canonical, rollback-safe way to modify a Debian package — `apt remove` / reinstall restores upstream. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| libfreerdp-client3 (already linked) | 3.15.0 | Provides `freerdp_client_handle_touch()` — the shared contact-lifecycle helper that X11/Wayland/SDL clients already call to feed RDPEI. | Always. The X11 patch calls this; do NOT reimplement contact ID mapping or frame encoding. |
| RdpeiClientContext (already loaded) | 3.15.0 | The vtable (`TouchBegin`/`TouchUpdate`/`TouchEnd`/`AddContact`) the channel exposes to the client. | When you need raw contact control (e.g., explicit `SuspendTouch`/`ResumeTouch` during gesture disambiguation). The shared helper covers the common path. |
| wLog (WinPR logging, already linked) | bundled | `WLog_DBG/WLog_WARN` with `CLIENT_TAG("x11")`. | For diagnostics. FreeRDP has `WLOG_LEVEL=DEBUG` env support already — no logging library to add. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `dpkg-buildpackage` / `debuild` | Build the patched `.deb` from the Debian source tree. | `apt build-dep freerdp3` pulls the full build-dependency set (libxi-dev, libx11-dev, cmake, etc.) in one command. |
| `quilt` | Manage the patch on top of the Debian quilt stack. | Set `QUILT_PATCHES=debian/patches`. The Debian package already ships ~60 patches in `series`; your patch appends after the last one. |
| `xinput` (1.6.4) | Enumerate XI devices, confirm `XITouchClass` / `XIDirectTouch` presence, count touch points. | Diagnostic for verifying the OneMix 3 touchscreen registers as a direct-touch device under the native X11 session. |
| `libinput debug-events` | Capture raw kernel touch events independent of X11, to correlate with what X11 delivers. | Install `libinput-tools`. Confirms whether missing events are an X11/XI2 problem or a kernel/libinput problem. |
| `WLOG_LEVEL=DEBUG` + `relay`/strace | Trace RDPEI and X11 input decisions at runtime. | FreeRDP honors `WLOG_LEVEL` out of the box; no tracing library needed. |
| Git (local branch in the Debian source tree) | Version the patch + any build wrapper. | Keep the patch as a real quilt `.patch` so it is `dpkg`-native; use git only for development history. |

## Installation

```bash
# 1. Enable source packages + pull build dependencies (one-time)
sudo apt update
sudo apt build-dep freerdp3      # pulls libxi-dev, libx11-dev, cmake, etc.
sudo apt install quilt libinput-tools devscripts

# 2. Unpack the Debian source (already in repo root)
dpkg-source -x freerdp3_3.15.0+dfsg-2.1+deb13u3.dsc freerdp3-src

# 3. Add the patch with quilt
export QUILT_PATCHES=debian/patches
cd freerdp3-src
quilt new touch-onemix3-rdpei-and-gestures.patch
quilt add client/X11/xf_input.c
#   ...edit client/X11/xf_input.c...
quilt refresh          # writes debian/patches/touch-onemix3-rdpei-and-gestures.patch

# 4. Build the .deb (binary-only; no source upload)
dpkg-buildpackage -us -uc -b -j$(nproc)

# 5. Install (replaces the distro freerdp3-x11 binary)
cd ..
sudo apt install ./freerdp3-x11_3.15.0+dfsg-2.1+deb13u3_amd64.deb

# 6. Roll back to the distro build
sudo apt reinstall freerdp3-x11
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Patch `xfreerdp3` directly (in-process RDPEI) | External `/dev/input` + `uinput` gesture daemon | Never for v1 — the project scope explicitly excludes it. A daemon cannot deliver native RDPEI contacts and adds a second input layer that competes with FreeRDP's grab/fullscreen handling. |
| Native X11 session (`gnome-xorg.desktop`) as the v1 target | Xwayland under the default GNOME Wayland session | Xwayland re-emits touch as `xwayland-touch` and has known multitouch quirks; the project explicitly scopes v1 to X11. A native X11 session is available on the device (`/usr/share/xsessions/gnome-xorg.desktop`). Wayland/Xwayland is a later milestone. |
| One integrated patch file in `debian/patches/` | Forking FreeRDP upstream into a separate repo | The constraint is "patch the Debian version currently used." A fork adds version-tracking overhead and diverges from `apt`. The quilt patch is one file, rollback-safe, and survives `apt upgrade` of the base package (re-applies via `series`). |
| Build against Debian 3.15.0 | Rebase to upstream 3.30.0 | Only if a needed touch fix exists ONLY in 3.30. Investigation shows the touch code path is structurally identical between 3.15 and 3.30 — no long-press or gesture-fallback logic was added upstream. Rebasing buys nothing for v1 and breaks the "Debian version" constraint. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| A new input daemon (uinput/evdev) | Cannot send native RDPEI contacts; adds latency and a competing input layer; explicitly out of scope. | In-process call to `freerdp_client_handle_touch()` from `xf_input.c`. |
| A gesture recognition library (e.g., a third-party touch framework) | The three v1 gestures (one-finger drag, long-press, pinch) are ~100 lines of state-machine logic. A library is unpayable complexity for three gestures on one device. | A small inline recognizer in `xf_input.c` using the existing `contacts[]` array and `active_contacts` counter that the file already maintains. |
| Wayland-native input for v1 | Out of scope; the device runs GNOME on Wayland by default but a native X11 session exists. v1 targets X11 per PROJECT.md. | Native X11 session via `gnome-xorg.desktop`. |
| Rewriting the RDPEI channel or contact frame encoder | The channel works; issue #6566 (long-press delay) was fixed in 3.x. Reimplementing MS-RDPEI frame encoding risks protocol-correctness bugs. | Reuse `RdpeiClientContext->AddContact` / the shared `freerdp_client_handle_touch` helper. |
| A separate config file format / parser | FreeRDP already parses `+multitouch`/`/gestures` and every rdpSetting. Long-press duration and pinch-fallback toggle can be rdpSettings or env vars. | Existing `rdpSettings` booleans + a couple of new config knobs via the existing cmdline parser, or `WLOG`-style env vars for calibration values. |
| SDL or Wayland client for v1 | Two other FreeRDP clients exist (`freerdp3-sdl`, `freerdp3-wayland`). The shared touch helper means work transfers later, but v1 is X11 only. | `client/X11/` only. |

## Stack Patterns by Variant

**If the OneMix 3 is booted into a native X11 session (the v1 target):**
- Use `xf_input.c`'s XI2 touch path directly. `register_input_events()` selects `XI_TouchBegin/Update/End` on direct-touch devices. With `+multitouch`, events flow to `xf_input_touch_remote()` → `freerdp_client_handle_touch()` → RDPEI.
- Because this is the path FreeRDP already supports, the patch is about *correctness and gesture disambiguation*, not wiring a new transport.

**If running under Xwayland (NOT v1, but the device's default session):**
- Touch arrives as `xwayland-touch:16`. XI2 touch events are emulated and have known multitouch quirks. Recommend the user log into `gnome-xorg.desktop` for v1 testing. Do not invest patch effort here until the X11 path is proven.

**If pinch fallback to Ctrl+wheel is needed (apps that don't handle touch zoom):**
- The existing local-gesture path's `ZoomingChange` handler ONLY rescales the local framebuffer — it does NOT send wheel events. This is a gap: the Ctrl+wheel fallback must be newly written (synthesize `freerdp_client_send_wheel_event` + a held Ctrl keypress) rather than reused.

## Version Compatibility

| Component | Pinned Version | Compatible With | Notes |
|-----------|----------------|-----------------|-------|
| FreeRDP source (Debian) | `3.15.0+dfsg-2.1+deb13u3` | Debian 13 trixie, amd64 | This is what `dpkg -l` reports installed. Patch must apply cleanly after the ~60 existing quilt patches in `series`. |
| Upstream FreeRDP | 3.30.0 (latest, 2026-07-16) | N/A for v1 | Touch code structure in `xf_input.c` is identical between 3.15 and 3.30 — same two-mode split, same contact array, still no long-press logic. Confirms the patch surface is stable; rebasing is not needed for v1. |
| X server / XI | X.org XI 2.2+ (server reports 2.4) | libXi via `libxi-dev` (build-dep) | `WITH_XI` is on by default in the Debian build. |
| Debian packaging | debhelper-compat 13, `3.0 (quilt)` | dpkg-dev ≥ 1.22.5 | `debian/rules` drives CMake with a large fixed flag set; do not modify flags — just add the patch. |

## Critical Scope Finding: Session Mismatch

The device currently runs **GNOME on Wayland** (`XDG_SESSION_TYPE=wayland`, `Xwayland :0 -rootless`). The project scopes v1 to **X11**. This is reconcilable:

- `/usr/share/xsessions/gnome-xorg.desktop` exists — the user can select "GNOME on Xorg" at the GDM login screen.
- The patch and all testing must be done in that native X11 session. Testing under Xwayland would conflate Xwayland touch-emulation quirks with patch bugs.
- `PROJECT.md` should record this as a prerequisite; the launch config / docs must instruct selecting the Xorg session.

This is a HIGH-confidence factual finding (observed directly on the device).

## Sources

- **Local Debian source tarball** (`freerdp3_3.15.0+dfsg.orig.tar.xz`, commit `405d509`) — authoritative for: `client/X11/xf_input.c` (two-mode touch dispatch, local gesture path that only rescales framebuffer, remote RDPEI path), `client/common/client.c` (`freerdp_client_handle_touch` shared helper), `channels/rdpei/client/rdpei_main.c` + `rdpei_main.h` (contact state machine, MS-RDPEI flags), `include/freerdp/channels/rdpei.h` (RDPINPUT_CONTACT_FLAGS), `client/common/cmdline.c` (`+multitouch`/`/gestures` → `FreeRDP_MultiTouchInput`/`FreeRDP_MultiTouchGestures`), `debian/patches/series` + `debian/rules`. [HIGH]
- **Upstream `xf_input.c` at 3.30.0** (raw.githubusercontent.com) — confirms the local/remote split, the pinch/pan PubSub path, and `freerdp_client_handle_touch` are unchanged from 3.15; no long-press logic exists upstream either. [HIGH, cross-verified]
- **GitHub FreeRDP releases API** — upstream latest 3.30.0 (2026-07-16); stable branches are 1.0/1.1/2.0 only (no 3.x stable branch). [HIGH]
- **GitHub FreeRDP issue #6566** — long-press/tap-and-hold delay regression, fixed in PR #6569 for 3.0-beta1. Confirms RDPEI timing issues were addressed but no general long-press gesture was added. [HIGH]
- **GitHub FreeRDP PR #9086** — "Multitouch common" (2023) moved X11 touch code into client/common for SDL reuse; noted ongoing X11 touch bugs (click not working, cursor jumping). [MEDIUM]
- **XI2 protocol spec** (x.org `XI2proto.txt`) + `XInput2.h` — `XISetMask`/`XISelectEvents`/`XI_TouchBegin` semantics. [HIGH]
- **MS-RDPEI spec** (learn.microsoft.com / winprotocoldoc) — `RDPINPUT_TOUCH_FRAME`, `RDPINPUT_CONTACT_DATA`, persistent contact state transitions. [HIGH]
- **Debian Maintainer's Guide ch.3** + Raphael Hertzog quilt tutorial — 3.0 (quilt) patch workflow. [HIGH]
- **Device observation** (Debian 13 trixie, FreeRDP 3.15.0, GNOME Wayland + `gnome-xorg.desktop` available, XI 2.4) — scope finding. [HIGH]

---
*Stack research for: FreeRDP X11 touchscreen-input patch (OneMix 3 / Debian trixie)*
*Researched: 2026-08-05*

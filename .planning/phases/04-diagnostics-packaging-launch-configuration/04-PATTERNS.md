# Phase 4: Diagnostics, Packaging & Launch Configuration - Pattern Map

**Mapped:** 2026-08-08  
**Files analyzed:** 20 planned files (including the Debian-source payload carried by the quilt patch)  
**Analogs found:** 19 / 20

## Scope Boundary

`build/freerdp3-3.15.0+dfsg/` is an ignored, working release-candidate tree. It is an **analog and patch source only**, not a destination for a committed Phase 4 implementation. Paths marked `[Debian source]` below are paths inside a fresh `dpkg-source -x` tree. The committed carrier is one new `patches/onemix-touch.patch`.

The patch must preserve the verified local-only gesture delta. Phase 4 source edits are limited to the diagnostic gate/records in X11 and RDPEI; do not retune classifier constants or revive `+multitouch`/native touch forwarding.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `patches/onemix-touch.patch` | config / quilt patch | batch transform | `build/freerdp3-3.15.0+dfsg/debian/patches/client-x11-fix-missing-includes.patch` | exact |
| `[Debian source] debian/changelog` | package config | batch transform | current `debian/changelog` | exact |
| `[Debian source] debian/patches/series` | package config | batch transform | current `debian/patches/series` | exact |
| `[Debian source] client/X11/xf_input.c` | controller | event-driven | current `client/X11/xf_input.c` | exact-preservation |
| `[Debian source] client/X11/xfreerdp.h` | model / state | event-driven | current `client/X11/xfreerdp.h` | exact-preservation |
| `[Debian source] channels/rdpei/client/rdpei_main.c` | service | streaming / event-driven | current `channels/rdpei/client/rdpei_main.c` | exact-preservation |
| `[Debian source] client/X11/xf_input.h` | interface utility | event-driven | current `client/X11/xf_input.h` | exact-preservation |
| `[Debian source] client/X11/xf_event.c` | controller | event-driven | current `client/X11/xf_event.c` | exact-preservation |
| `[Debian source] client/X11/xf_client.c` | controller | event-driven | current `client/X11/xf_client.c` | exact-preservation |
| `[Debian source] client/common/cmdline.c` | controller | request-response / transform | current `client/common/cmdline.c` | exact-preservation |
| `[Debian source] client/common/cmdline.h` | interface config | transform | current `client/common/cmdline.h` | exact-preservation |
| `[Debian source] include/freerdp/settings_types_private.h` | model | transform | current `settings_types_private.h` | exact-preservation |
| `[Debian source] libfreerdp/common/settings_getters.c` | service | transform | current `settings_getters.c` | exact-preservation |
| `[Debian source] libfreerdp/common/settings_str.h` | config / metadata | transform | current `settings_str.h` | exact-preservation |
| `[Debian source] client/X11/test_scroll_classifier.c` | test | transform | current standalone classifier model | exact-preservation |
| `scripts/build-release.sh` | utility | batch / file-I/O | `scripts/build-baseline.sh` | role-match |
| `scripts/launch-touch.sh` | utility / launcher | request-response / file-I/O | `scripts/check-x11-session.sh` + `scripts/build-baseline.sh` | partial |
| `.gitignore` | config | file-I/O | current `.gitignore` | exact |
| `README.md` | documentation / operations | request-response | none | no analog |
| `/usr/local/bin/menu` (external, not committed) | interactive config | request-response | current `/usr/local/bin/menu` | negative analog |

Generated `dist/*.deb` and `dist/SHA256SUMS` are build outputs, not committed source files. `run-rdp.sh`, `rdp-debug*.log`, the `build/` tree, and Debian build products are explicitly excluded from the release payload.

## Pattern Assignments

### `patches/onemix-touch.patch`, `[Debian source] debian/changelog`, and `[Debian source] debian/patches/series`

**Analogs:**
- `build/freerdp3-3.15.0+dfsg/debian/patches/client-x11-fix-missing-includes.patch`
- `build/freerdp3-3.15.0+dfsg/debian/patches/series`
- `build/freerdp3-3.15.0+dfsg/debian/changelog`

**Patch-header and diff pattern** (`client-x11-fix-missing-includes.patch:1-15`):

```patch
From: akallabeth <akallabeth@posteo.net>
Date: Thu, 22 May 2025 16:17:50 +0200
Subject: [client,x11] fix missing includes
Origin: upstream, https://github.com/FreeRDP/FreeRDP/commit/479cea48ccc40c1e28b77043dc58d475367a80b5
Forwarded: not-needed

---
 client/X11/xf_gfx.c   | 1 +
 client/X11/xf_video.c | 1 +
 2 files changed, 2 insertions(+)

diff --git a/client/X11/xf_gfx.c b/client/X11/xf_gfx.c
```

**Series pattern:** `debian/patches/series:1-105` is one ordered filename per line with comment lines allowed. Copy `onemix-touch.patch` into the fresh tree's `debian/patches/`, then append exactly one final non-comment entry after the current final entry (`channels-drive-refine-bounds-checks-CVE-2026-40254.patch`, line 105). Do not reorder or edit Debian's existing stack.

**Changelog pattern** (`debian/changelog:1-10`):

```text
freerdp3 (3.15.0+dfsg-2.1+deb13u3) trixie; urgency=medium

  * security fix from 3.25.0:

 -- Michael Tokarev <mjt@tls.msk.ru>  Wed, 06 May 2026 11:13:18 +0300
```

Prepend one local entry at version `3.15.0+dfsg-2.1+deb13u3+onemix1`; leave the Debian entries intact. The project patch must include this changelog diff and every source payload row below, but not `debian/patches/series` itself—the release script owns the one-line series append in its fresh workspace.

**Required patch payload:**

| Payload path | Preserve / Phase 4 purpose | Existing seam |
|---|---|---|
| `client/X11/xf_input.c` | Preserve local-only recognizer; add only gated diagnostic records | input ingress, synthesizer calls, `xf_touch_force_cancel` |
| `client/X11/xfreerdp.h` | Preserve gesture state; add the cached X11 diagnostic flag only if using the context-state pattern | `xf_context` `WITH_XI` block, lines 303-350 |
| `channels/rdpei/client/rdpei_main.c` | Preserve contact lifecycle; add gated frame-submission record | `rdpei_send_touch_event_pdu`, lines 710-756 |
| `client/X11/xf_input.h`, `xf_event.c`, `xf_client.c` | Preserve existing shared force-cancel interface and lifecycle callers unchanged | `xf_input.h:30-34`; callers below |
| `client/common/cmdline.c`, `cmdline.h` | Preserve the three existing touch switches unchanged | parser/declarations below |
| `include/freerdp/settings_types_private.h`, `libfreerdp/common/settings_getters.c`, `settings_str.h` | Preserve existing settings plumbing unchanged | settings anchors below |
| `client/X11/test_scroll_classifier.c` | Preserve the 2.5-ratio regression model unchanged | standalone test below |
| `debian/changelog` | Local `+onemix1` package version | changelog pattern above |

Do not add a Phase 4 CLI setting, `TouchTwoFingerPanDeadbandPx`, a configuration parser, or an input daemon. Do not include ignored machine-specific `run-rdp.sh` in the patch.

---

### `[Debian source] client/X11/xf_input.c` and `client/X11/xfreerdp.h` — gated local-touch diagnostics

**Analog:**
`build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c`

**Imports/log tag pattern** (`xf_input.c:40-45`):

```c
#include <winpr/assert.h>
#include <winpr/synch.h>
#include <winpr/sysinfo.h>
#include <winpr/wtypes.h>
#include <freerdp/log.h>
#define TAG CLIENT_TAG("x11")
```

**Initialization and existing error-return pattern** (`xf_input.c:348-448`):

```c
int xf_input_init(xfContext* xfc, Window window)
{
    ...
    xfc->scrollActive = FALSE;
    xfc->scrollLastY = 0;
    xfc->scrollAccum = 0;
    PubSub_SubscribeTimer(xfc->common.context.pubSub, xf_input_OnTimer);

    if (!XQueryExtension(xfc->display, "XInputExtension", &opcode, &event, &error))
    {
        WLog_WARN(TAG, "XInput extension not available.");
        return -1;
    }
```

**Ingress and frozen local-only dispatch** (`xf_input.c:1558-1600`):

```c
static int xf_input_touch_remote(xfContext* xfc, XIDeviceEvent* event, int evtype)
{
    ...
    WLog_DBG(TAG, "touch_remote: ev=%s id=%d x=%d y=%d rdpei=%p fallback=%d", evname,
             (int)event->detail, (int)event->event_x, (int)event->event_y, (void*)rdpei,
             xfc->fallbackActive);
    ...
    /* All touch is consumed locally by the fallback gesture recognizer.
     * No native RDPEI touch contacts are forwarded (per user decision). */
    return xf_input_touch_fallback(xfc, evtype, x, y, touchId);
}
```

**State placement pattern** (`xfreerdp.h:303-350`): the existing `#if defined(WITH_XI)` block owns all touch state (`lpArmed`, `ctrlHeld`, pinch, scroll, and three-finger fields). If caching the gate, add one `BOOL touchDiagEnabled` adjacent to this state and initialize it once in `xf_input_init`; do not add a global setting or public API.

**Apply this pattern:**

1. Treat only `FREERDP_TOUCH_DIAG=1` as enabled; unset, `0`, `false`, or any other value is normal/off. A small translation-unit-local `getenv`/`strcmp` predicate is sufficient. The local environment-access precedent is `client/X11/xf_utils.c:175-180`:
   ```c
   // NOLINTNEXTLINE(concurrency-mt-unsafe)
   char* env = getenv("DESKTOP_SESSION");
   return (env != NULL && strcmp(env, "gnome") == 0);
   ```
2. Cache the X11 result during `xf_input_init`, then guard records only. Do not change `xf_input_touch_fallback` routing, thresholds, timing, contact state, or output calls.
3. Convert the existing touch-specific `WLog_DBG` trace points to one compact gated WARN-level diagnostic form. The main existing points are long-press output (`xf_input.c:303-332`), pinch/scroll/three-finger claims (`942-1088`), local state transitions and lifts (`1099-1556`), ingress (`1565-1575`), forced cleanup (`1627-1634`, `1733-1742`), and the recovery gate (`1946-2007`).
4. Add a compact record immediately beside each existing synthesized output rather than wrapping/replacing it: Ctrl-down (`993-995`), pinch wheel detents (`876-894`), scroll wheel detents (`1272-1284`), middle-button send/release (`1079-1081`, `1484-1488`), left-button drag/tap/release (`1354-1357`, `1532-1536`, `1545-1546`), and long-press right-click (`324-331`). This gives diagnostic evidence without a second input path.
5. Record Cancel through the shared `xf_touch_force_cancel` seam. Its existing summary and native cancel loop are the correct locations; do not create a second teardown state machine.

**Forced-cleanup core pattern** (`xf_input.c:1609-1754`):

```c
void xf_touch_force_cancel(xfContext* xfc)
{
    rdpClientContext* cctx = &xfc->common;
    RdpeiClientContext* rdpei = cctx->rdpei;
    ...
    if (xfc->ctrlHeld)
    {
        rdpInput* input = xfc->common.context.input;
        if (input)
            freerdp_input_send_keyboard_event(input, KBD_FLAGS_RELEASE,
                                              RDP_SCANCODE_LCONTROL);
        xfc->ctrlHeld = FALSE;
    }
    ...
    if (rdpei)
        rdpei->TouchCancel(rdpei, c->id, c->x, c->y, &dummy);
}
```

Keep existing `xf_touch_force_cancel` lifecycle wiring. The already-patched interface and callers are the reusable pattern:

```c
/* client/X11/xf_input.h:30-34 */
int xf_input_init(xfContext* xfc, Window window);
int xf_input_handle_event(xfContext* xfc, const XEvent* event);
void xf_touch_force_cancel(xfContext* xfc);

/* client/X11/xf_event.c:701-716 */
xf_keyboard_release_all_keypress(xfc);
xf_touch_force_cancel(xfc);

/* client/X11/xf_client.c:795-813 */
xf_touch_force_cancel(xfc);
xfc->fullscreen = (xfc->fullscreen) ? FALSE : TRUE;
```

`xf_event.c:841-856`, `xf_event.c:949-961`, and `xf_client.c:1468-1478` are additional existing resize, unmap, and disconnect callers. Capture them unchanged in the patch.

---

### `[Debian source] channels/rdpei/client/rdpei_main.c` — conditional RDPEI frame record

**Analog:**
`build/freerdp3-3.15.0+dfsg/channels/rdpei/client/rdpei_main.c`

**Frame encoder/send and error-cleanup pattern** (`rdpei_main.c:710-756`):

```c
static UINT rdpei_send_touch_event_pdu(GENERIC_CHANNEL_CALLBACK* callback,
                                       RDPINPUT_TOUCH_FRAME* frame)
{
    ...
    size_t pduLength = 64ULL + (64ULL * frame->contactCount);
    wStream* s = Stream_New(NULL, pduLength);

    if (!s)
    {
        WLog_Print(rdpei->base.log, WLOG_ERROR, "Stream_New failed!");
        return CHANNEL_RC_NO_MEMORY;
    }
    ...
    status = rdpei_write_touch_frame(rdpei->base.log, s, frame);
    if (status)
    {
        WLog_Print(rdpei->base.log, WLOG_ERROR,
                   "rdpei_write_touch_frame failed with error %" PRIu32 "!", status);
        Stream_Free(s, TRUE);
        return status;
    }

    Stream_SealLength(s);
    status = rdpei_send_pdu(callback, s, EVENTID_TOUCH, Stream_Length(s));
    Stream_Free(s, TRUE);
    return status;
}
```

**Frame offset and error propagation pattern** (`rdpei_main.c:993-1025`):

```c
if ((error = rdpei_send_touch_event_pdu(callback, frame)))
{
    WLog_Print(rdpei->base.log, WLOG_ERROR,
               "rdpei_send_touch_event_pdu failed with error %" PRIu32 "!", error);
    return error;
}

rdpei->previousFrameTime = rdpei->currentFrameTime;
return error;
```

**Apply this pattern:** add one gated `WLog_Print(rdpei->base.log, WLOG_WARN, ...)` immediately after the real `rdpei_send_pdu` call and before `Stream_Free`. It should report only frame contact count, frame offset, sealed stream length, and send status. Preserve allocation, seal, send, free, and return order exactly.

If caching in RDPEI, follow the existing plugin-state/init pattern: `RDPEI_PLUGIN` is defined at `rdpei_main.c:70-97` and initialized by `init_plugin_cb` at `1483-1558`. Add at most one private boolean there. A per-frame local predicate is also acceptable if it does not change the encoder; do not create cross-module diagnostic plumbing.

Do **not** rely on the existing detailed frame printer at `rdpei_main.c:624-667`: it is compiled only under `WITH_DEBUG_RDPEI`, while Debian explicitly builds with `-DWITH_DEBUG_ALL=OFF` in `debian/rules:18-58`.

---

### Frozen settings, CLI, and classifier-test payload

**CLI declaration pattern** (`client/common/cmdline.h:497-502`):

```c
{ "touch-long-press", COMMAND_LINE_VALUE_REQUIRED, "<ms>", NULL, NULL, -1, NULL,
  "Long-press duration in ms for right-click (default 600)" },
{ "touch-pinch-wheel-fallback", COMMAND_LINE_VALUE_BOOL, NULL, BoolValueFalse, NULL, -1, NULL,
  "Send Ctrl+Wheel instead of RDPEI zoom on pinch" },
{ "touch-slop", COMMAND_LINE_VALUE_REQUIRED, "<px>", NULL, NULL, -1, NULL,
  "Dead-zone radius in px to suppress touch jitter (default 8)" },
```

**Parser pattern** (`client/common/cmdline.c:1174-1194`):

```c
CommandLineSwitchCase(arg, "touch-long-press")
{
    if (!arg->Value)
        return fail_at(arg, COMMAND_LINE_ERROR_MISSING_VALUE);
    if (!freerdp_settings_set_uint32(settings, FreeRDP_TouchLongPressDurationMs,
                                     (UINT32)atoi(arg->Value)))
        return fail_at(arg, COMMAND_LINE_ERROR);
}
...
CommandLineSwitchCase(arg, "touch-pinch-wheel-fallback")
{
    if (!freerdp_settings_set_bool(settings, FreeRDP_TouchPinchWheelFallback, enable))
        return fail_at(arg, COMMAND_LINE_ERROR);
}
```

The parser deliberately has no range validation (`atoi`); keep it unchanged and make the wrapper the validation boundary.

**Settings preservation anchors:**
- private fields: `settings_types_private.h:616-619`
- bool get/set cases: `settings_getters.c:379-386` and `1095-1105`
- integer get/set cases: `settings_getters.c:2006-2010` and `2541-2547`
- metadata: `settings_str.h:257-258` and `449-452`

Do not add a fourth tuning setting. The wrapper may compose only `+touch-pinch-wheel-fallback`, `/touch-long-press:<ms>`, and `/touch-slop:<px>`; it must omit `+multitouch` and all stale pan/deadband options.

**Regression-test pattern** (`client/X11/test_scroll_classifier.c:1-45`, `47-128`): it is a self-contained C11 model using `assert`, `math.h`, and a `main()` that prints `OK`. Preserve the verified constants and cases unchanged:

```c
#define PINCH_DEADBAND_PX 8
#define PINCH_DOMINANCE_RATIO 2.5
...
assert(c == PENDING);
...
printf("OK\n");
return 0;
```

Compile it to `/tmp` during release validation, as documented in its header comment; do not leave a test binary in the source or repository tree.

---

### `scripts/build-release.sh` — clean release build and explicit runtime bundle

**Primary analog:** `scripts/build-baseline.sh`

**Shell/error and pinned-version shape** (`build-baseline.sh:7-27`):

```sh
set -eu

printf '=== Stage 2: version pin-check ===\n' >&2
PINNED="3.15.0+dfsg-2.1+deb13u3"
resolved=$(apt-cache showsrc freerdp3 | awk '/^Version:/{print $2; exit}')
if [ "$resolved" != "$PINNED" ]; then
  printf 'ERROR: apt source freerdp3 resolves to %s, expected %s.\n' \
    "$resolved" "$PINNED" >&2
  exit 1
fi
```

**Build/checksum shape** (`build-baseline.sh:58-75`):

```sh
printf '=== Stage 5: build unmodified .deb ===\n' >&2
dpkg-buildpackage -us -uc -b -j"$(nproc)"
...
printf '=== Stage 6: artifact checksum ===\n' >&2
SHA=$(sha256sum "$DEB" | awk '{print $1}')
printf 'SHA-256: %s\n' "$SHA" >&2
```

Reuse the staged stderr progress and fail-fast error messages, but keep this script separate and non-interactive. Unlike the baseline script, it must extract a fresh tree from the pinned local `.dsc`, copy/apply the one patch, validate the post-patch local changelog version, run the existing classifier check, build through `dpkg-buildpackage`, and retain only the explicit runtime artifacts in `dist/`.

**Debian build seam:** invoke the package build; do not recreate its CMake flags. `debian/rules:18-58` owns the Debian CMake configuration and `debian/rules:122-126` delegates through `dh` / `dh_auto_configure`.

**Runtime-bundle rule — corrected from the research's proposed three-file set:** include these four same-version local packages, in dependency order:

1. `libwinpr3-3`
2. `libfreerdp3-3`
3. `libfreerdp-client3-3`
4. `freerdp3-x11`

`debian/control:68-105` shows `freerdp3-x11 -> libfreerdp-client3-3 (= ${binary:Version}) -> libfreerdp3-3 (= ${binary:Version}) -> libwinpr3-3 (= ${binary:Version})`. Local `dpkg-deb -f` inspection of the existing artifacts confirms the final exact dependency at the `libfreerdp3-3` boundary. Once the source version gains `+onemix1`, the stock `libwinpr3-3` cannot satisfy that exact dependency. All four packages (libwinpr3-3, libfreerdp3-3, libfreerdp-client3-3, freerdp3-x11) must ship at the same +onemix1 version.

For every selected `.deb`, validate `Package`, `Version`, and `Architecture` with `dpkg-deb -f`; require the locked `+onemix1` version and target architecture before copying it to `dist/`. Generate `SHA256SUMS` from that explicit four-file list. Never use `freerdp3-*.deb`, `*.deb`, or a broad install glob. Do not include `freerdp3-dev`; changed headers belong in the patch but an SDK bundle is out of scope.

---

### `scripts/launch-touch.sh` — one credential-free command path

**Primary analogs:**
- fail-closed session gate: `scripts/check-x11-session.sh`
- shell status/error conventions: `scripts/build-baseline.sh`
- diagnostic pipeline: `04-RESEARCH.md:364-374` (no direct repository analog for Bash arrays plus `PIPESTATUS`)

**Native-X11 gate pattern** (`check-x11-session.sh:6-34`):

```sh
set -eu

session_type="${XDG_SESSION_TYPE:-}"
wayland_disp="${WAYLAND_DISPLAY:-}"
...
[ "$session_type" = "x11" ] || fail "${session_type:-unset}" \
  "Log out, then select 'GNOME on Xorg' at the GDM login screen."
[ -z "$wayland_disp" ]        || fail "Wayland (WAYLAND_DISPLAY=$wayland_disp)" \
  "WAYLAND_DISPLAY is set — this is a Wayland/XWayland session, not native X11."
...
printf 'OK: native X11 session verified (display %s).\n' "${DISPLAY:-<unset>}"
```

Resolve and run this existing sibling script before the client; do not copy its four-signal session detection into the wrapper.

**Diagnostic pipeline pattern** (`04-RESEARCH.md:367-372`):

```bash
/usr/bin/xfreerdp3 "${touch_args[@]}" "$@" 2>&1 | tee "$log_path"
exit "${PIPESTATUS[0]}"
```

Use Bash for the wrapper because safe arrays and `${PIPESTATUS[0]}` are required. Normal launches should `exec /usr/bin/xfreerdp3 ...`; diagnostics should create one `umask 077` state directory and `mktemp` timestamped log under `${XDG_STATE_HOME:-$HOME/.local/state}/freerdp-touch/`, tee the combined stream, and return the client status. Never print the constructed command or `$@`.

**Required command composition:**
- default values: long press `600`, slop `8`
- accepted overrides: `FREERDP_TOUCH_LONG_PRESS_MS` in `500..700`, `FREERDP_TOUCH_SLOP_PX` in `4..16`
- reject non-digits and out-of-range values before invoking FreeRDP
- touch mode adds only `+touch-pinch-wheel-fallback`, `/touch-long-press:<ms>`, and `/touch-slop:<px>`
- `--mouse-only` shifts only the wrapper mode argument, leaves opaque FreeRDP arguments unchanged, and supplies no touch options
- `FREERDP_TOUCH_DIAG=1` uses the same command array and only adds private logging/tee behavior

Use `"${touch_args[@]}" "$@"`; do not use `eval`, a string-built command, a password prompt, a config parser, `WLOG_LEVEL=DEBUG`, or `+multitouch`.

---

### `.gitignore` — artifact hygiene

**Analog:** `.gitignore:1-10`

```gitignore
build/
*.deb
*.dsc
*.orig.tar.xz
*.debian.tar.xz
*.build
*.buildinfo
*.changes
run-rdp.sh
rdp-debug.log
```

Append `dist/` using the existing generated-artifact convention. Do not unignore or force-add the release-candidate `build/` source tree, generated package files, generated logs, or machine-specific launch scripts.

---

### `README.md` and external `/usr/local/bin/menu` — operations and delegation

**README:** no committed end-user operations-document analog exists. Use the compact structure of the phase requirements rather than inventing a profile format: prerequisites/native-X11, clean build, exact four-package install/checksum verification, normal launch, diagnostic launch, calibration overrides, `--mouse-only`, stock rollback, and security-update replacement/rebuild detection.

**Menu is a negative analog:** `/usr/local/bin/menu:27-68` currently prompts for a password, writes a temporary X init script, embeds a full connection command, uses the ignored build-tree binary, and enables global `WLOG_LEVEL=DEBUG`. Do not copy any of those lines or put their credential values into documentation, wrapper output, logs, or the patch.

Change only option 3's operational behavior to delegate to the repository wrapper after a non-secret, FreeRDP-native connection/session argument handoff has been chosen. The wrapper owns the touch preset; the menu must not grow a duplicate command or a new connection parser.

## Shared Patterns

### WARN-level WLog diagnostics to stderr

**Sources:**
- `winpr/include/winpr/wlog.h:280-293`
- `winpr/libwinpr/utils/wlog/wlog.c:492-505`
- `winpr/libwinpr/utils/wlog/ConsoleAppender.c:112-136`

```c
#define WLog_WARN(tag, ...) \
    WLog_Print_dbg_tag(tag, WLOG_WARN, __LINE__, __FILE__, __func__, __VA_ARGS__)
...
return _log_level >= level;
```

```c
case WLOG_TRACE:
case WLOG_DEBUG:
case WLOG_INFO:
    fp = stdout;
    break;
default:
    fp = stderr;
    break;
```

Apply a single environment gate before compact `WLog_WARN` / `WLog_Print(..., WLOG_WARN, ...)` records. Do not gate with `WLog_DBG`: root loggers default to `WLOG_INFO` (`wlog.c:913-939`), so debug records are normally filtered out.

### Local-only touch behavior is frozen

**Sources:** `client/X11/xf_input.c:1091-1600`, `client/common/cmdline.h:497-502`

The canonical non-mouse launch enables `+touch-pinch-wheel-fallback` and omits `+multitouch`. The fallback recognizer remains the only XInput touch route. Diagnostics observe existing decisions and synthesized output; they do not change event routing, classifier constants, timers, or cleanup.

### Existing cleanup seam

**Sources:** `client/X11/xf_input.h:30-34`, `xf_event.c:701-716`, `xf_client.c:1468-1478`

All lifecycle recovery continues through `xf_touch_force_cancel`. Add cancel diagnostics there; do not add per-caller cleanup logs/state that can drift from the authoritative release/quarantine behavior.

### Exact package closure and rollback evidence

**Sources:** `debian/control:68-105`, `scripts/build-baseline.sh:118-162`

Build, checksum, install, and document the explicit four-package closure. Record installed versions with `dpkg-query`/`dpkg-deb`; do not create an APT hold or pin. Rollback documentation must verify the stock versions after the APT transaction and explain that a future newer Debian package is expected to replace the local `+onemix1` build.

### Shell trust boundary

**Sources:** `scripts/check-x11-session.sh:14-21`; `04-RESEARCH.md:463-474`

Validate only the two numeric calibration environment values. Keep connection/session arguments opaque and array-separated. Never read, store, echo, or log passwords or a full connection command.

## No Analog Found

| File / Concern | Role | Data Flow | Reason / Planner Direction |
|---|---|---|---|
| `README.md` | documentation | operations | No committed end-user install/rollback/launch guide exists. Keep it to the locked operational workflow; do not add a config/profile format. |
| `scripts/launch-touch.sh` validation and tee branch | utility | request-response / file-I/O | Existing scripts are POSIX `sh` and contain neither array forwarding nor `PIPESTATUS`. Use the narrow Bash pattern from `04-RESEARCH.md:364-374`; do not create a helper framework. |
| `/usr/local/bin/menu` connection-argument handoff | interactive config | request-response | The current option has only a credential-bearing flow. Delegate a user-supplied FreeRDP-native connection argument or document direct wrapper use; do not reintroduce password capture or parse a new connection format. |

## Metadata

**Analog search scope:**
- `/home/hoang/freerdp-touch/scripts/`
- `/home/hoang/freerdp-touch/.gitignore`
- `/home/hoang/freerdp-touch/build/freerdp3-3.15.0+dfsg/client/X11/`
- `/home/hoang/freerdp-touch/build/freerdp3-3.15.0+dfsg/client/common/`
- `/home/hoang/freerdp-touch/build/freerdp3-3.15.0+dfsg/channels/rdpei/client/`
- `/home/hoang/freerdp-touch/build/freerdp3-3.15.0+dfsg/debian/`
- `/usr/local/bin/menu`

**Files scanned:** 27 code, package, script, logging, and operational analogs (plus phase/planning inputs)  
**Pattern extraction date:** 2026-08-08

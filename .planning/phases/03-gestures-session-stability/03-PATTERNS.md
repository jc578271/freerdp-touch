# Phase 3: Gestures & Session Stability - Pattern Map

**Mapped:** 2026-08-06
**Files analyzed:** 5 modified + 2 unchanged-reference + 1 test = 8
**Analogs found:** 8 / 8 (all in-tree; this phase patches an existing file, so the closest analog is the file's own Phase 2 patch)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `client/X11/xf_input.c` | controller | event-driven | `client/X11/xf_input.c` (Phase 2 patch: `xf_input_touch_remote`, `xf_touch_force_cancel`, `xf_input_handle_event_remote`) | exact (self) |
| `client/X11/xfreerdp.h` | model | state | `client/X11/xfreerdp.h:303-318` (`#if defined(WITH_XI)` touch fields) | exact (self) |
| `include/freerdp/settings_types_private.h` | config | config | `settings_types_private.h:602-603` (`MultiTouchInput`/`MultiTouchGestures`) | exact (self) |
| `client/common/cmdline.c` | route | request-response (CLI parse) | `cmdline.c:1164-1173` (`multitouch`/`gestures` cases) | exact (self) |
| `client/X11/xf_input.h` | config (header) | n/a | `xf_input.h:33` (`xf_touch_force_cancel` decl) | exact (self) — only if a new reset helper is split out |
| `client/X11/xf_event.c` | (unchanged) | event-driven | `xf_event.c:712,844,956` (lifecycle hooks) | reference only |
| `client/X11/xf_client.c` | (unchanged) | event-driven | `xf_client.c:805,1048-1061,1460-1473,1609-1694` | reference only |
| `test/*` (new) | test | n/a | Phase 2 UAT (`02-UAT.md`) on-device check style | role-match |

No files have NO analog — every change extends an existing in-tree pattern. The patch surface is the Phase 2 patch itself.

## Pattern Assignments

### `client/X11/xf_input.c` (controller, event-driven)

**Analog:** itself — the Phase 2 patch already in this file (`xf_input_touch_remote`, `xf_touch_force_cancel`, `xf_input_handle_event_remote`).

#### Pattern A — Insert the gesture state machine INLINE in `xf_input_touch_remote`, not a wrapper

The insertion point is the `switch (evtype)` at lines 769-782. Phase 2 proved inline dispatch works; do not add a `xf_touch_gesture_filter()` forwarding wrapper. The new per-contact candidate / pinch logic goes BEFORE this switch (after the content-bounds gate + `xf_event_adjust_coordinates` at line 767, which already produced adjusted `x,y`).

**Analog — existing native dispatch (lines 769-782):**
```c
switch (evtype)
{
    case XI_TouchBegin:
        freerdp_client_handle_touch(&xfc->common, FREERDP_TOUCH_DOWN, touchId, 0, x, y);
        break;
    case XI_TouchUpdate:
        freerdp_client_handle_touch(&xfc->common, FREERDP_TOUCH_MOTION, touchId, 0, x, y);
        break;
    case XI_TouchEnd:
        freerdp_client_handle_touch(&xfc->common, FREERDP_TOUCH_UP, touchId, 0, x, y);
        break;
    default:
        break;
}
```
Phase 3 wraps each arm: on `XI_TouchBegin` forward native DOWN immediately (D-01) AND arm the long-press candidate (record down x,y + start time); on `XI_TouchUpdate` check slop before forwarding (D-02) and check the deadline inline; on second finger claim/abort per mode (D-04/D-06); on `XI_TouchEnd` clear per-finger candidate state.

#### Pattern B — Distance math (slop + pinch) via stdlib `sqrt(pow())`

**Analog — `xf_input_detect_pinch` (lines 431-432), local-only, NOT reused but the math pattern is:**
```c
const double dist = sqrt(pow(xfc->contacts[1].pos_x - xfc->contacts[0].last_x, 2.0) +
                         pow(xfc->contacts[1].pos_y - xfc->contacts[0].last_y, 2.0));
```
Slop check = `sqrt(pow(x - downX, 2) + pow(y - downY, 2))`. Pinch inter-finger distance = same one-liner. Do not import a gesture library (CLAUDE.md "What NOT to Use"). The local `xf_input_detect_pinch` itself (lines 416-470) runs ONLY in the non-remote `MultiTouchGestures` path and only rescales the local framebuffer via PubSub — do NOT route fallback pinch through it.

#### Pattern C — Extend the SINGLE reset seam `xf_touch_force_cancel`

**Analog — `xf_touch_force_cancel` (lines 792-829):**
```c
void xf_touch_force_cancel(xfContext* xfc)
{
    rdpClientContext* cctx = &xfc->common;
    RdpeiClientContext* rdpei = cctx->rdpei;
    ...
    xfc->quarantinedCount = 0;
    for (size_t i = 0; i < FREERDP_MAX_TOUCH_CONTACTS; i++)
    {
        FreeRDP_TouchContact* c = &cctx->contacts[i];
        if (c->id != 0)
        {
            int dummy = 0;
            if (rdpei)
                rdpei->TouchCancel(rdpei, c->id, c->x, c->y, &dummy);
            if (xfc->quarantinedCount < (int)FREERDP_MAX_TOUCH_CONTACTS)
                xfc->quarantinedFingers[xfc->quarantinedCount++] = c->id;
            FreeRDP_TouchContact empty = { 0 };
            *c = empty;
        }
    }
    if (xfc->quarantinedCount > 0)
        xfc->recoveryGateArmed = TRUE;
}
```
Add to the TOP of this function (before the contact loop, so Ctrl is released and gesture state cleared even if rdpei is NULL): clear long-press candidate (down coord, start time, armed flag), reset pinch accumulators + deadband + frozen-finger set, and release a held Ctrl idempotently (guarded by a `ctrlHeld` flag — only send `KBD_FLAGS_RELEASE` if the flag was set, then clear it). Do NOT add a second reset function. This is the D-15 contract: every lifecycle hook (FocusOut, ConfigureNotify, UnmapNotify, toggle_fullscreen, post_disconnect) already calls this one function (verified, no new call sites).

#### Pattern D — Zero-init new fields in `xf_input_init`

**Analog — `xf_input_init` (lines 255-263):**
```c
xfc->firstDist = -1.0;
xfc->z_vector = 0;
xfc->px_vector = 0;
xfc->py_vector = 0;
xfc->active_contacts = 0;
xfc->fallbackActive = FALSE;
xfc->fallbackFinger = 0;
xfc->recoveryGateArmed = FALSE;
xfc->quarantinedCount = 0;
```
Add the new gesture fields to this same init block (e.g. `xfc->lpArmed = FALSE; xfc->lpDownX = 0; ...; xfc->ctrlHeld = FALSE;`). `calloc` of `xfContext` already zero-initializes, but Phase 2 explicitly re-zeroes the touch fields here — match that for clarity.

#### Pattern E — Recovery gate is unchanged; gesture reset feeds into it

**Analog — `xf_input_handle_event_remote` recovery gate (lines 1026-1076):**
```c
if (xfc->recoveryGateArmed)
{
    const int evtype = cookie.cc->evtype;
    if (evtype == XI_TouchBegin || evtype == XI_TouchUpdate ||
        evtype == XI_TouchEnd || evtype == XI_TouchOwnership)
    {
        ... quarantine by touchId; on TouchEnd remove from set;
        if (xfc->quarantinedCount == 0) xfc->recoveryGateArmed = FALSE; ...
    }
}
```
Do NOT modify this gate. The extended `xf_touch_force_cancel` populates `quarantinedFingers[]`/`quarantinedCount`/`recoveryGateArmed` exactly as before; the gate then requires all pre-cancel fingers to lift before accepting new touches (D-08 / D-15 "fresh physical touch after all-fingers-up"). Third-finger abort (D-14) routes through `xf_touch_force_cancel` to get this gate for free.

#### Pattern F — Right-click + midpoint pointer via the shared button sender

**Analog — Phase 2 fallback (lines 704-706, 717-718, 728-729) already calls `freerdp_client_send_button_event` with adjusted coords:**
```c
freerdp_client_send_button_event(&xfc->common, FALSE,
    PTR_FLAGS_DOWN | PTR_FLAGS_MOVE | PTR_FLAGS_BUTTON1, x, y);   // left down
...
freerdp_client_send_button_event(&xfc->common, FALSE, PTR_FLAGS_MOVE, x, y);  // motion
...
freerdp_client_send_button_event(&xfc->common, FALSE, PTR_FLAGS_BUTTON1, x, y); // left up
```
Right-click (D-03): replace `BUTTON1` with `PTR_FLAGS_BUTTON2`:
```c
freerdp_client_send_button_event(&xfc->common, FALSE, PTR_FLAGS_DOWN | PTR_FLAGS_BUTTON2, downX, downY);
freerdp_client_send_button_event(&xfc->common, FALSE, PTR_FLAGS_BUTTON2, downX, downY);  // release
```
Midpoint pointer move before first wheel tick (D-11): `freerdp_client_send_button_event(&xfc->common, FALSE, PTR_FLAGS_MOVE, mx, my)`. Always pass adjusted coords (run through `xf_event_adjust_coordinates` first, like line 767). `FALSE` = absolute, matching all Phase 2 calls.

#### Pattern G — Wheel detents via the shared wheel sender

**Analog — `freerdp_client_send_wheel_event` body (client.c:1590-1635):**
```c
BOOL freerdp_client_send_wheel_event(rdpClientContext* cctx, UINT16 mflags)
{
    ...
    INT32 value = mflags & 0xFF;
    if (mflags & PTR_FLAGS_WHEEL_NEGATIVE) value = -1 * (0x100 - value);
    ...
    freerdp_input_send_mouse_event(cctx->context.input, mflags, 0, 0);
    return TRUE;
}
```
**Wheel constants to copy VERBATIM from `xf_client.c:1048-1061` (the authoritative button map):**
```c
{ Button4, PTR_FLAGS_WHEEL | 0x78 },                                         // wheel up  (zoom in, D-09)
{ Button5, PTR_FLAGS_WHEEL | PTR_FLAGS_WHEEL_NEGATIVE | (0x100 - 0x78) },    // wheel down (zoom out)
```
So: zoom-in = `freerdp_client_send_wheel_event(&xfc->common, PTR_FLAGS_WHEEL | 0x78)`; zoom-out = `freerdp_client_send_wheel_event(&xfc->common, PTR_FLAGS_WHEEL | PTR_FLAGS_WHEEL_NEGATIVE | (0x100 - 0x78))`. `0x78` = 120 = one standard detent. Fixed detents, no acceleration (D-10). On reversal, discard the partial accumulator and require a fresh full detent before emitting the opposite direction (D-12 hysteresis).

#### Pattern H — Ctrl key press/release via the keyboard sender

**Analog — verified signatures:**
```c
// include/freerdp/input.h:104
BOOL freerdp_input_send_keyboard_event(rdpInput* input, UINT16 flags, UINT8 code);
// input.h:33-36
#define KBD_FLAGS_DOWN 0x4000
#define KBD_FLAGS_RELEASE 0x8000
// include/freerdp/scancode.h:71
RDP_SCANCODE_LCONTROL
```
```c
rdpInput* input = xfc->common.context.input;
freerdp_input_send_keyboard_event(input, KBD_FLAGS_DOWN, RDP_SCANCODE_LCONTROL);     // press (D-06)
freerdp_input_send_keyboard_event(input, KBD_FLAGS_RELEASE, RDP_SCANCODE_LCONTROL); // release (D-13)
```
Release MUST be idempotent: guard with a `ctrlHeld` flag, only send release if the flag was set, then clear it. All release paths route through the extended `xf_touch_force_cancel` (Pattern C).

#### Pattern I — Cancel the held native contact with `rdpei->TouchCancel`, NOT `TouchEnd`

**Analog — `xf_touch_force_cancel` line 814:**
```c
if (rdpei)
    rdpei->TouchCancel(rdpei, c->id, c->x, c->y, &dummy);
```
**Vtable signature (rdpei.h:44-45, 95):** `typedef UINT (*pcRdpeiTouchEvent)(RdpeiClientContext*, INT32 externalId, INT32 x, INT32 y, INT32* contactId);` ... `pcRdpeiTouchEvent TouchCancel;`.
At long-press threshold (D-03): call `rdpei->TouchCancel` on the held contact FIRST (emits `UP|CANCELED` so Windows abandons the press, preventing a left-click), THEN synthesize the right-click (Pattern F), THEN mark the finger FROZEN and consume all further UPDATEs until lift. For fallback pinch claiming (D-06): cancel the first contact's already-emitted native DOWN the same way when the second finger claims. If the frame builder complains on-device, fall back to `rdpei->SuspendTouch`/`ResumeTouch` (rdpei.h:92-93) around the suppression (Open Question 2 in RESEARCH.md).

#### Pattern J — Long-press deadline on the existing 20 ms timer tick

**Analog — `xf_disp.c:270-285, 336-338` (timer subscription + callback):**
```c
static void xf_disp_OnTimer(void* context, const TimerEventArgs* e)
{
    xfContext* xfc = NULL;
    ...
    if (!xf_disp_check_context(context, &xfc, &xfDisp, &settings))
        return;
    ...
}
...
// in xf_disp_new (line 338):
PubSub_SubscribeTimer(pubSub, xf_disp_OnTimer);
```
The timer publisher already runs (`xf_client.c:1609,1619,1693-1694`): `CreateWaitableTimerA(...); SetWaitableTimer(timer, &due, 20, ...);` ... `timerEvent.now = GetTickCount64(); PubSub_OnTimer(context->pubSub, context, &timerEvent);`. 20 ms is 25x finer than the 500 ms threshold.

Subscribe a `xf_input_OnTimer` callback the same way: `PubSub_SubscribeTimer(xfc->common.context.pubSub, xf_input_OnTimer)` in `xf_input_init`. The callback casts `context` to `xfContext*` directly (RESEARCH Open Question 3 — also check the deadline INLINE on every `XI_TouchUpdate` for responsiveness, since the timer fires only every 20 ms and a perfectly still finger may have no updates after the slop suppresses jitter; use BOTH). Use `GetTickCount64()` (monotonic, already used at `xf_client.c:1693`) for the deadline comparison.

The context passed to `PubSub_OnTimer` is `rdpContext*` (= `instance->context`, which is the `xfContext*` base) — cast directly: `xfContext* xfc = (xfContext*)context;`. No `check_context` helper needed (gesture state lives in `xfContext`, no sub-object to validate).

#### Pattern K — DIagnostics: `WLog_DBG` only, never INFO

**Analog — existing DIAG block (lines 660-662):**
```c
WLog_DBG(TAG, "touch_remote: ev=%s id=%d x=%d y=%d rdpei=%p fallback=%d", evname,
         (int)event->detail, (int)event->event_x, (int)event->event_y, (void*)rdpei,
         xfc->fallbackActive);
```
Use `WLog_DBG(TAG, ...)` for gesture diagnostics. The two `/* DIAG: */` blocks (lines 653-663, 797-803) are NOT in the quilt patch and are Phase 4's responsibility — Phase 3 must not build product behavior on them (02-REVIEW-FIX). Keep any Phase 3 debug logging clearly separate / DEBUG-gated.

---

### `client/X11/xfreerdp.h` (model, state)

**Analog:** `xfreerdp.h:303-318` — the existing `#if defined(WITH_XI)` touch fields block.

```c
#if defined(WITH_XI)
    touchContact contacts[MAX_CONTACTS];
    int active_contacts;
    int lastEvType;
    XIDeviceEvent lastEvent;
    double firstDist;
    double lastDist;
    double z_vector;
    double px_vector;
    double py_vector;
    BOOL fallbackActive;
    int fallbackFinger;
    BOOL recoveryGateArmed;
    int quarantinedFingers[FREERDP_MAX_TOUCH_CONTACTS];
    int quarantinedCount;
#endif
```
Add the new Phase 3 gesture fields INSIDE this same `#if defined(WITH_XI)` block, immediately after `quarantinedCount`. Suggested minimal state (exact names are planner discretion per CONTEXT.md):
```c
    /* Phase 3 gesture state */
    BOOL lpArmed;            /* long-press candidate armed */
    INT32 lpDownX, lpDownY;  /* touch-down coordinate (adjusted) */
    UINT64 lpDeadline;       /* GetTickCount64() deadline */
    int lpFinger;            /* XI2 touchId of the candidate */
    BOOL lpFrozen;           /* post-right-click: consume until lift (D-03) */
    BOOL pinchActive;        /* fallback pinch claimed (D-06) */
    BOOL pinchClaimed;       /* second-finger claim latched */
    double pinchFirstDist;   /* baseline inter-finger distance */
    double pinchLastDist;    /* previous frame distance */
    int pinchAccum;          /* accumulated detent distance (signed) */
    int pinchDir;            /* +1 in / -1 out / 0 none */
    BOOL pinchMidpointDone;  /* midpoint pointer moved (D-11) */
    BOOL ctrlHeld;           /* Ctrl press sent, release needed (idempotent guard) */
    int pinchFingerA, pinchFingerB;  /* XI2 touchIds of the two pinch contacts */
```
Do not mirror `cctx->contacts[]` (the authoritative RDPEI store owned by `client/common`) — track only per-gesture candidate state keyed by XI2 touchId (RESEARCH Anti-Pattern: "A second contact-state array"). Zero-init in `xf_input_init` (Pattern D).

---

### `include/freerdp/settings_types_private.h` (config, config)

**Analog:** `settings_types_private.h:602-603`:
```c
SETTINGS_DEPRECATED(ALIGN64 BOOL MultiTouchInput);        /* 2631 */
SETTINGS_DEPRECATED(ALIGN64 BOOL MultiTouchGestures);     /* 2632 */
```
Add new NON-deprecated rows immediately after line 603 (keep the trailing `/* NNNN */` index comment style):
```c
ALIGN64 UINT32 TouchLongPressDurationMs;   /* 263X */
ALIGN64 UINT32 TouchLongPressSlopPx;       /* 263X */
ALIGN64 BOOL   TouchPinchWheelFallback;    /* 263X */
```
**Key convention:** the build auto-generates the `FreeRDP_<FieldName>` enum (verified: `libfreerdp/core/test/settings_property_lists.h:112-113` and `debian/tmp/.../settings_keys.h:180-181` derive `FreeRDP_MultiTouchInput = 2631` from the struct field `MultiTouchInput`). So a field named `TouchLongPressDurationMs` yields enum `FreeRDP_TouchLongPressDurationMs` — no manual enum edit. Access via `freerdp_settings_get_uint32(settings, FreeRDP_TouchLongPressDurationMs)` / `freerdp_settings_set_uint32(...)` (the macros used at cmdline.c:1166). Only add the three requirement-mandated knobs (CONTEXT.md "Claude's Discretion") — do not add speculative calibration settings.

---

### `client/common/cmdline.c` (route, request-response CLI parse)

**Analog:** `cmdline.c:1164-1173`:
```c
CommandLineSwitchCase(arg, "multitouch")
{
    if (!freerdp_settings_set_bool(settings, FreeRDP_MultiTouchInput, enable))
        return fail_at(arg, COMMAND_LINE_ERROR);
}
CommandLineSwitchCase(arg, "gestures")
{
    if (!freerdp_settings_set_bool(settings, FreeRDP_MultiTouchGestures, enable))
        return fail_at(arg, COMMAND_LINE_ERROR);
}
```
Add new cases adjacent to these. Note the existing `enable` variable is a `BOOL` parsed for boolean toggles. For the integer settings, follow the integer-arg pattern (read `arg->Value`); if no direct neighbor in this block parses an integer, search the file for an existing `freerdp_settings_set_uint32` + `arg->Value` case and copy that parse/validate/`fail_at` shape. Suggested cases:
```c
CommandLineSwitchCase(arg, "touch-long-press")
{
    if (!arg->Value) return fail_at(arg, COMMAND_LINE_ERROR_MISSING_VALUE);
    if (!freerdp_settings_set_uint32(settings, FreeRDP_TouchLongPressDurationMs, atoi(arg->Value)))
        return fail_at(arg, COMMAND_LINE_ERROR);
}
CommandLineSwitchCase(arg, "touch-slop")
{
    ... FreeRDP_TouchLongPressSlopPx ...
}
CommandLineSwitchCase(arg, "touch-pinch-wheel-fallback")
{
    if (!freerdp_settings_set_bool(settings, FreeRDP_TouchPinchWheelFallback, enable))
        return fail_at(arg, COMMAND_LINE_ERROR);
}
```
This is `client/common` (shared with SDL/Wayland) — keep changes to pure settings parsing, NO X11 gesture policy (CLAUDE.md "X11-only policy"). The X11 client reads the setting; the parse is generic.

---

### `client/X11/xf_input.h` (config header)

**Analog:** `xf_input.h:33`:
```c
void xf_touch_force_cancel(xfContext* xfc);
```
Already declares the reset seam. Only add a declaration if a new helper is split out of `xf_input.c` (e.g. a static timer callback does NOT need a header declaration; only a non-static externally-called helper would). Prefer no change — keep everything in `xf_input.c` per RESEARCH Pattern 1.

---

### `client/X11/xf_event.c` (unchanged — reference only)

No modification. Already calls `xf_touch_force_cancel(xfc)` at:
- line 712 (FocusOut, after `xf_keyboard_release_all_keypress`)
- line 844 (ConfigureNotify on resize)
- line 956 (UnmapNotify)

The extended `xf_touch_force_cancel` (Pattern C) gives these hooks gesture cleanup + Ctrl release for free. Do not add new call sites.

---

### `client/X11/xf_client.c` (unchanged — reference only)

No modification. Reference points:
- **Wheel constants** (lines 1048-1061): copy the `0x78` / `PTR_FLAGS_WHEEL_NEGATIVE | (0x100 - 0x78)` values verbatim (Pattern G). Do not re-derive.
- **toggle_fullscreen** (line 805): already calls `xf_touch_force_cancel(xfc)` — gets cleanup free.
- **post_disconnect** (lines 1460-1473): already calls `xf_touch_force_cancel(xfc)` at line 1473 BEFORE channel teardown (rdpei still valid) — D-15 disconnect cleanup free.
- **Timer publisher** (lines 1609, 1619, 1693-1694): the 20 ms waitable timer + `PubSub_OnTimer` already run; the Phase 3 timer callback (Pattern J) subscribes to this, no new timer.
- **auto_reconnect** (line 1667): `client_auto_reconnect_ex(instance, handle_window_events)` preserves process/settings (D-16 — startup pinch mode is a setting, survives by design). Per-gesture state is cleared because disconnect runs `post_disconnect` → `xf_touch_force_cancel`; the recovery gate then requires all-fingers-up. Reconnect must NOT re-arm anything.

---

### `test/*` (test)

**Analog:** Phase 2 UAT (`02-UAT.md`) on-device check style + the existing `WLog_DBG` DIAG blocks used to capture evidence. CONTEXT.md "Claude's Discretion" requires checks cover: timer firing, slop cancellation, second/third-finger transitions, wheel direction/detents, midpoint targeting, every cleanup hook, and reconnect reuse. Per Ponytail/CLAUDE.md, prefer the smallest runnable check — one on-device UAT script driving `xfreerdp3` with `WLOG_LEVEL=DEBUG` and asserting on the `WLog_DBG` output, mirroring the Phase 2 UAT approach, over a unit-test framework (no test framework exists in the X11 client). Exact organization is planner discretion.

## Shared Patterns

### Coordinate handling — adjust BEFORE synthesis
**Source:** `xf_input.c:767` (`xf_event_adjust_coordinates(xfc, &x, &y)`), declared `xf_event.h:37`.
**Apply to:** every synthetic right-click, midpoint pointer move, and pinch contact coordinate. Always run `xf_event_adjust_coordinates` after the content-bounds gate and before calling any `freerdp_client_send_*`. Phase 2 fallback (lines 702, 716, 727) follows this order.

### Content-bounds gate — reject letterbox touches before gesture work
**Source:** `xf_input.c:755-765` (the `#ifdef WITH_XRENDER` bounds check on `offset_x/y` + `scaledWidth/Height`).
**Apply to:** the gesture layer runs AFTER this gate (it is already passed before line 769), so synthesized input never originates from letterbox. Do not re-check.

### Idempotent cleanup + recovery gate — single seam
**Source:** `xf_touch_force_cancel` (lines 792-829) + recovery gate (lines 1026-1076).
**Apply to:** ALL gesture state. The extended force_cancel clears gesture state + releases Ctrl at the top (Pattern C); the existing recovery gate then requires all-fingers-up. Third-finger abort (D-14), focus loss, disconnect, and reconnect all route through this one function. Never duplicate cleanup at individual hook sites.

### Shared senders — never hand-roll input frames
**Source:** `client/common/client.c` — `freerdp_client_send_wheel_event` (1590), `freerdp_client_send_button_event` (1652); `include/freerdp/input.h:104` — `freerdp_input_send_keyboard_event`; rdpei vtable `TouchCancel` (rdpei.h:95).
**Apply to:** all synthetic input. These own ainput channel + RDP input framing + RDPEI contact state. Passing `FALSE` (absolute) + adjusted coords matches every Phase 2 call.

### Settings convention — struct field auto-generates enum
**Source:** `settings_types_private.h` struct fields → generated `FreeRDP_<Field>` enum (`settings_keys.h`, `settings_property_lists.h`).
**Apply to:** all three new settings. Access via `freerdp_settings_get_uint32`/`set_uint32`/`get_bool`/`set_bool` (cmdline.c:1166). No manual enum edit; no config file parser (CLAUDE.md "What NOT to Use").

## No Analog Found

None. Every change extends an existing in-tree pattern (the file being patched is its own analog via the Phase 2 patch). No new dependency, thread, channel, file format, or RDPEI encoder is introduced.

## Metadata

**Analog search scope:**
- `build/freerdp3-3.15.0+dfsg/client/X11/` (xf_input.c, xfreerdp.h, xf_input.h, xf_event.c, xf_client.c, xf_disp.c)
- `build/freerdp3-3.15.0+dfsg/client/common/` (client.c, cmdline.c)
- `build/freerdp3-3.15.0+dfsg/include/freerdp/` (input.h, client.h, client/rdpei.h, settings_types_private.h, scancode.h)
- generated settings enum: `libfreerdp/core/test/settings_property_lists.h`, `debian/tmp/.../settings_keys.h`

**Files scanned:** 11 source + 2 generated enum references
**Pattern extraction date:** 2026-08-06
**Pinned source:** `freerdp3_3.15.0+dfsg-2.1+deb13u3` (build tree at `build/freerdp3-3.15.0+dfsg/`)
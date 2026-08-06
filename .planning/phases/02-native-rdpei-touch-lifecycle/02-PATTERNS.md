# Phase 2: Native RDPEI Touch Lifecycle - Pattern Map

**Mapped:** 2026-08-06
**Files analyzed:** 6 (5 modify, 1 optional create)
**Analogs found:** 6 / 6

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `client/X11/xf_input.c` | controller (XI2 event dispatch) | event-driven (XI2 events -> RDPEI/mouse) | `client/X11/xf_input.c:853-904` (xf_input_handle_event_remote) — the existing dispatch switch that this phase extends | exact (same function, same file) |
| `client/X11/xf_event.c` | controller (X11 lifecycle events) | event-driven (X11 events -> client actions) | `client/X11/xf_event.c:701-716` (xf_event_FocusOut) — existing hook that releases keyboard but not touch | exact (same function, same file) |
| `client/X11/xf_client.c` | controller (client lifecycle) | event-driven (fullscreen toggle, disconnect) | `client/X11/xf_client.c:792-812` (xf_toggle_fullscreen) — existing hook that toggles fullscreen but not touch | exact (same function, same file) |
| `client/X11/xfreerdp.h` | model (context struct) | N/A (data definition) | `client/X11/xfreerdp.h:303-313` (existing touchContact + gesture fields on xfContext) | exact (same struct, same file) |
| `channels/rdpei/client/rdpei_main.c` | service (RDPEI channel) | event-driven (touch events -> protocol frames) | `channels/rdpei/client/rdpei_main.c:1052-1130` (rdpei_touch_process) — the function whose lock scope must move | exact (same function, same file) |
| `client/X11/xf_touch.c` + `xf_touch.h` (optional) | service (touch lifecycle helpers) | event-driven (forced-cancel, fallback latch, content-bounds gate) | `client/X11/xf_input.c:641-673` (xf_input_touch_remote) — the existing native-touch path that the new module wraps | role-match (new file, same data flow) |

## Pattern Assignments

### `client/X11/xf_input.c` — register_input_events (lines 74-196)

**Role:** controller (XI2 event registration)
**Data flow:** event-driven (XIQueryDevice -> XISetMask -> XISelectEvents)
**Analog:** `client/X11/xf_input.c:108-123` — the existing XITouchClass branch

**Current shape to extend** (lines 108-123):
```c
case XITouchClass:
    if (freerdp_settings_get_bool(settings, FreeRDP_MultiTouchInput))
    {
        const XITouchClassInfo* t = (const XITouchClassInfo*)class;
        if (t->mode == XIDirectTouch)
        {
            WLog_DBG(TAG, "%s %s touch device (id: %d, mode: %d), supporting %d touches.",
                     dev->name, (t->mode == XIDirectTouch) ? "direct" : "dependent",
                     dev->deviceid, t->mode, t->num_touches);
            XISetMask(masks[nmasks], XI_TouchBegin);
            XISetMask(masks[nmasks], XI_TouchUpdate);
            XISetMask(masks[nmasks], XI_TouchEnd);
        }
    }
    break;
```

**What to add:** One `XISetMask(masks[nmasks], XI_TouchOwnership)` line after the existing three `XISetMask` calls (after line 121). This selects the ownership event so the client can accept/reject touch grabs.

**Also note:** The `XITouchClass` branch does NOT set `used = TRUE` (unlike `XIButtonClass` at line 133). This means if a device has ONLY a touch class (no button class), `nmasks` is not incremented and the mask is silently dropped. The OneMix 3 touchscreen has both classes (baseline-report.md), so this is not a v1 bug, but the planner should be aware.

---

### `client/X11/xf_input.c` — xf_input_handle_event_remote (lines 853-904)

**Role:** controller (XI2 event dispatch)
**Data flow:** event-driven (XGenericEventCookie -> switch on evtype -> touch/pen/mouse path)
**Analog:** `client/X11/xf_input.c:853-904` — the existing dispatch switch

**Current shape to extend** (lines 853-904):
```c
static int xf_input_handle_event_remote(xfContext* xfc, const XEvent* event)
{
    union { const XGenericEventCookie* cc; XGenericEventCookie* vc; } cookie;
    cookie.cc = &event->xcookie;
    XGetEventData(xfc->display, cookie.vc);

    if ((cookie.cc->type == GenericEvent) && (cookie.cc->extension == xfc->XInputOpcode))
    {
        switch (cookie.cc->evtype)
        {
            case XI_TouchBegin:
                xf_input_pens_unhover(xfc);
                /* fallthrough */
                WINPR_FALLTHROUGH
            case XI_TouchUpdate:
            case XI_TouchEnd:
                xf_input_touch_remote(xfc, cookie.cc->data, cookie.cc->evtype);
                break;
            case XI_ButtonPress:
            case XI_Motion:
            case XI_ButtonRelease:
            {
                WLog_DBG(TAG, "checking for pen");
                XIDeviceEvent* deviceEvent = (XIDeviceEvent*)cookie.cc->data;
                int deviceid = deviceEvent->deviceid;
                if (freerdp_client_is_pen(&xfc->common, deviceid))
                {
                    if (!xf_input_pen_remote(xfc, cookie.cc->data, cookie.cc->evtype, deviceid))
                        xf_input_event(xfc, event, cookie.cc->data, cookie.cc->evtype);
                    break;
                }
            }
                /* fallthrough */
                WINPR_FALLTHROUGH
            default:
                xf_input_pens_unhover(xfc);
                xf_input_event(xfc, event, cookie.cc->data, cookie.cc->evtype);
                break;
        }
    }
    XFreeEventData(xfc->display, cookie.vc);
    return 0;
}
```

**What to add (three insertions):**

1. **XI_TouchOwnership case** — add a new case before or after the `XI_TouchBegin` case. On `XI_TouchOwnership`, call `XIAllowTouchEvents(xfc->display, deviceid, touchid, xfc->window->handle, XIAcceptTouch)`. The `deviceid` comes from `((XIDeviceEvent*)cookie.cc->data)->deviceid`; the `touchid` is `((XIDeviceEvent*)cookie.cc->data)->detail`. Accept-on-begin is the exclusive model for a fullscreen RDP session.

2. **XIPointerEmulated filter** — in the `XI_ButtonPress/XI_Motion/XI_ButtonRelease` branch (line 875-892), before the pen check, test whether the event is emulated from touch. The `XIDeviceEvent` has a `flags` field; `XIMaskIsSet(deviceEvent->flags, XIPointerEmulated)` returns TRUE for touch-emulated pointer events. When emulated AND a touch sequence is active (or always when emulated, since the touch path handles the real input), `break` out of the switch without calling `xf_input_event`. Genuine mouse/stylus events (not emulated) must still pass through.

3. **Forced-cancel seam invocation** — in the `XI_TouchBegin` case, before the fallthrough to `xf_input_touch_remote`, check the recovery gate (D-08). If the gate is armed and not all pre-cancellation fingers have lifted, ignore the new touch (return early). Also check the content-bounds gate (D-11) before forwarding.

---

### `client/X11/xf_input.c` — xf_input_touch_remote (lines 641-673)

**Role:** controller (touch-to-RDPEI bridge)
**Data flow:** event-driven (XI_TouchBegin/Update/End -> freerdp_client_handle_touch)
**Analog:** `client/X11/xf_input.c:641-673` — the existing native-touch path

**Current shape to extend** (lines 641-673):
```c
static int xf_input_touch_remote(xfContext* xfc, XIDeviceEvent* event, int evtype)
{
    int x = 0;
    int y = 0;
    int touchId = 0;
    RdpeiClientContext* rdpei = xfc->common.rdpei;

    if (!rdpei)
        return 0;

    xf_input_hide_cursor(xfc);
    touchId = event->detail;
    x = (int)event->event_x;
    y = (int)event->event_y;
    xf_event_adjust_coordinates(xfc, &x, &y);

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
    return 0;
}
```

**What to add (three concerns):**

1. **First-contact-only fallback latch (D-01..D-04)** — when `rdpei == NULL`, instead of returning 0 (which silently drops the touch), apply a single-contact latch. Track `xfc->fallbackFinger` (the first finger to go DOWN while rdpei is NULL) and `xfc->fallbackActive` (BOOL). On DOWN: if no fallback is active, latch this finger and emit button1 DOWN via `freerdp_client_send_button_event(&xfc->common, FALSE, PTR_FLAGS_DOWN|PTR_FLAGS_MOVE|PTR_FLAGS_BUTTON1, x, y)`. On MOTION: only act if `touchId == xfc->fallbackFinger`, emit `PTR_FLAGS_MOVE`. On UP: only act if `touchId == xfc->fallbackFinger`, emit `PTR_FLAGS_BUTTON1` (no DOWN flag = release), clear `fallbackActive`. Ignore all other fingers while fallback is active (D-02). The latch holds for the contact's lifetime even if RDPEI appears midway (D-03): decide `rdpei==NULL` at DOWN time and stick with it until UP.

2. **Content-bounds gate (D-11)** — before `xf_event_adjust_coordinates`, compute the content rectangle in window coordinates: `(xfc->offset_x, xfc->offset_y)` to `(xfc->offset_x + xfc->scaledWidth, xfc->offset_y + xfc->scaledHeight)`. If `event_x` or `event_y` falls outside this rectangle, return 0 without forwarding. This replaces the current `CLAMP_COORDINATES` behavior (which silently floors negatives to 0) with explicit ignore.

3. **Idempotency check (D-07)** — on `XI_TouchEnd`, if `touchId` is in the canceled-ID set, clear it from the set and return 0 without emitting a second terminal RDPEI event.

---

### `client/X11/xf_event.c` — xf_event_FocusOut (lines 701-716)

**Role:** controller (focus-loss handler)
**Data flow:** event-driven (X11 FocusOut -> keyboard release + [NEW] touch cancel)
**Analog:** `client/X11/xf_event.c:701-716` — the existing hook

**Current shape to extend** (lines 701-716):
```c
static BOOL xf_event_FocusOut(xfContext* xfc, const XFocusOutEvent* event, BOOL app)
{
    if (event->mode == NotifyUngrab)
        return TRUE;

    xfc->focused = FALSE;

    if (event->mode == NotifyWhileGrabbed)
        XUngrabKeyboard(xfc->display, CurrentTime);

    xf_keyboard_release_all_keypress(xfc);
    if (app)
        xf_rail_send_activate(xfc, event->window, FALSE);

    return TRUE;
}
```

**What to add:** After `xf_keyboard_release_all_keypress(xfc)` (line 711), add `xf_touch_force_cancel(xfc)` (or inline the forced-cancel logic). This ensures all active touch contacts are canceled on focus loss (D-06).

---

### `client/X11/xf_event.c` — xf_event_UnmapNotify (lines 946-966)

**Role:** controller (unmap/minimize handler)
**Data flow:** event-driven (X11 UnmapNotify -> keyboard release + suppress output + [NEW] touch cancel)
**Analog:** `client/X11/xf_event.c:946-966` — the existing hook

**Current shape to extend** (lines 946-966):
```c
static BOOL xf_event_UnmapNotify(xfContext* xfc, const XUnmapEvent* event, BOOL app)
{
    WINPR_ASSERT(xfc);
    WINPR_ASSERT(event);

    if (!app)
        xf_keyboard_release_all_keypress(xfc);

    if (!app)
        return gdi_send_suppress_output(xfc->common.context.gdi, TRUE);

    {
        xfAppWindow* appWindow = xf_AppWindowFromX11Window(xfc, event->window);
        if (appWindow)
            appWindow->is_mapped = FALSE;
        xf_rail_return_window(appWindow);
    }
    return TRUE;
}
```

**What to add:** In the `!app` branch, before `xf_keyboard_release_all_keypress` (line 952), add `xf_touch_force_cancel(xfc)`. This ensures touch contacts are canceled on minimize/unmap (D-06).

---

### `client/X11/xf_event.c` — xf_event_ConfigureNotify (lines 815-919)

**Role:** controller (window geometry change handler)
**Data flow:** event-driven (X11 ConfigureNotify -> geometry update + [NEW] touch cancel on size change)
**Analog:** `client/X11/xf_event.c:840-866` — the existing size-change branch

**Current shape to extend** (lines 840-866, the size-change branch):
```c
if (xfc->window->width != event->width || xfc->window->height != event->height)
{
    xfc->window->width = event->width;
    xfc->window->height = event->height;
#ifdef WITH_XRENDER
    xfc->offset_x = 0;
    xfc->offset_y = 0;

    if (freerdp_settings_get_bool(settings, FreeRDP_SmartSizing) ||
        freerdp_settings_get_bool(settings, FreeRDP_MultiTouchGestures))
    {
        xfc->scaledWidth = xfc->window->width;
        xfc->scaledHeight = xfc->window->height;
        xf_draw_screen(xfc, 0, 0, ...);
    }
    else
    {
        xfc->scaledWidth = ...DesktopWidth;
        xfc->scaledHeight = ...DesktopHeight;
    }
#endif
}
```

**What to add:** At the top of the size-change block (line 840, before updating `xfc->window->width`), add `xf_touch_force_cancel(xfc)` gated on `xfc->active_contacts > 0` (or equivalent check that contacts are active). Per D-12, geometry changes while contacts are active must cancel those contacts before adopting the new transform. The new transform is then applied by the existing code below.

---

### `client/X11/xf_client.c` — xf_toggle_fullscreen (lines 792-812)

**Role:** controller (fullscreen toggle)
**Data flow:** event-driven (user action -> fullscreen state change + [NEW] touch cancel)
**Analog:** `client/X11/xf_client.c:792-812` — the existing hook

**Current shape to extend** (lines 792-812):
```c
void xf_toggle_fullscreen(xfContext* xfc)
{
    WindowStateChangeEventArgs e = { 0 };
    rdpContext* context = (rdpContext*)xfc;
    rdpSettings* settings = context->settings;

    if (xfc->debug)
        xf_ungrab(xfc);

    xfc->fullscreen = (xfc->fullscreen) ? FALSE : TRUE;
    xfc->decorations =
        (xfc->fullscreen) ? FALSE : freerdp_settings_get_bool(settings, FreeRDP_Decorations);
    xf_SetWindowFullscreen(xfc, xfc->window, xfc->fullscreen);
    EventArgsInit(&e, "xfreerdp");
    e.state = xfc->fullscreen ? FREERDP_WINDOW_STATE_FULLSCREEN : 0;
    PubSub_OnWindowStateChange(context->pubSub, context, &e);
}
```

**What to add:** Before `xfc->fullscreen = ...` (line 805), add `xf_touch_force_cancel(xfc)`. This ensures active touch contacts are canceled before the fullscreen state flips (D-06, D-12).

---

### `client/X11/xf_client.c` — xf_post_disconnect (lines 1459-1502)

**Role:** controller (disconnect teardown)
**Data flow:** event-driven (disconnect -> channel teardown + [NEW] touch cancel)
**Analog:** `client/X11/xf_client.c:1459-1502` — the existing hook

**Current shape to extend** (lines 1459-1502):
```c
static void xf_post_disconnect(freerdp* instance)
{
    xfContext* xfc = NULL;
    rdpContext* context = NULL;

    if (!instance || !instance->context)
        return;

    context = instance->context;
    xfc = (xfContext*)context;
    PubSub_UnsubscribeChannelConnected(instance->context->pubSub,
                                       xf_OnChannelConnectedEventHandler);
    PubSub_UnsubscribeChannelDisconnected(instance->context->pubSub,
                                          xf_OnChannelDisconnectedEventHandler);
    gdi_free(instance);

    if (xfc->pipethread) { ... }
    if (xfc->clipboard) { xf_clipboard_free(xfc->clipboard); xfc->clipboard = NULL; }
    if (xfc->xfDisp) { xf_disp_free(xfc->xfDisp); xfc->xfDisp = NULL; }
    // ... window teardown ...
    freerdp_keyboard_remap_free(xfc->remap_table);
    xfc->remap_table = NULL;
    xf_window_free(xfc);
}
```

**What to add:** At the top of the function, after the `xfc = (xfContext*)context` cast (line 1468), add `xf_touch_force_cancel(xfc)`. This must run BEFORE `gdi_free(instance)` and the channel teardown, because `cctx->rdpei` is still valid at this point (the channel disconnect handler at client.c:1557 sets `cctx->rdpei = NULL`, but that runs as a PubSub callback — the forced-cancel must fire before the channel is torn down). Per D-06, disconnect must clean up all active contacts.

**Important ordering note:** The `xf_post_disconnect` is called from `xf_client.c`'s disconnect path. The `freerdp_client_OnChannelDisconnectedEventHandler` (client.c:1539-1557) sets `cctx->rdpei = NULL` when the RDPEI channel disconnects. The forced-cancel must run while `rdpei` is still non-NULL. The planner must verify the call order: if `xf_post_disconnect` runs after the channel-disconnect PubSub callback, `rdpei` will already be NULL and the forced-cancel must still clear local bookkeeping (the `cctx->contacts[]` array) even though it cannot call `rdpei->TouchCancel`.

---

### `client/X11/xfreerdp.h` — xfContext struct (lines 303-313)

**Role:** model (context struct)
**Data flow:** N/A (data definition)
**Analog:** `client/X11/xfreerdp.h:303-313` — the existing touch/gesture fields

**Current shape to extend** (lines 303-313):
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
#endif
```

**What to add (new fields, inside the `#if defined(WITH_XI)` block):**

```c
    /* Phase 2: native-touch lifecycle bookkeeping */
    BOOL fallbackActive;          /* D-01..D-04: first-contact-only mouse fallback latch */
    int fallbackFinger;           /* the XI2 touchId of the latched fallback contact */
    BOOL recoveryGateArmed;       /* D-08: TRUE after forced cancel, blocks new touches */
    int canceledIds[10];          /* D-07: set of touchIds already force-canceled (idempotency) */
    int canceledIdCount;          /* number of entries in canceledIds[] */
    int quarantinedFingers[10];   /* D-08: fingers that were down at cancel time */
    int quarantinedCount;         /* number of entries in quarantinedFingers[] */
```

These are small fixed-size arrays (max 10 entries, matching `FREERDP_MAX_TOUCH_CONTACTS`). The `touchContact contacts[MAX_CONTACTS]` array (line 304) is the LOCAL-gesture path's contact store — do NOT repurpose it for native-path bookkeeping. The new fields are separate.

---

### `channels/rdpei/client/rdpei_main.c` — rdpei_touch_process (lines 1052-1130)

**Role:** service (RDPEI contact reservation + publish)
**Data flow:** event-driven (touch event -> reserve contact -> publish to frame)
**Analog:** `channels/rdpei/client/rdpei_main.c:1052-1130` — the function being fixed

**Current shape (the #12174 race)** (lines 1064-1129):
```c
static UINT rdpei_touch_process(RdpeiClientContext* context, INT32 externalId, UINT32 contactFlags,
                                INT32 x, INT32 y, INT32* contactId, UINT32 fieldFlags, va_list ap)
{
    INT64 contactIdlocal = -1;
    RDPINPUT_CONTACT_POINT* contactPoint = NULL;
    UINT error = CHANNEL_RC_OK;

    if (!context || !contactId || !context->handle)
        return ERROR_INTERNAL_ERROR;

    RDPEI_PLUGIN* rdpei = (RDPEI_PLUGIN*)context->handle;
    EnterCriticalSection(&rdpei->lock);                          // line 1064
    const BOOL begin = (contactFlags & RDPINPUT_CONTACT_FLAG_DOWN) != 0;
    contactPoint = rdpei_contact(rdpei, externalId, !begin);     // line 1066 — RESERVE
    if (contactPoint)
        contactIdlocal = contactPoint->contactId;
    LeaveCriticalSection(&rdpei->lock);                          // line 1069 — RACE WINDOW OPENS

    if (contactIdlocal > UINT32_MAX)
        return ERROR_INVALID_PARAMETER;

    if (contactIdlocal >= 0)
    {
        RDPINPUT_CONTACT_DATA contact = { 0 };
        contact.x = x; contact.y = y;
        contact.contactId = (UINT32)contactIdlocal;
        contact.contactFlags = contactFlags;
        contact.fieldsPresent = WINPR_ASSERTING_INT_CAST(UINT16, fieldFlags);
        // ... va_arg parsing for contactRect, orientation, pressure ...
        error = context->AddContact(context, &contact);          // line 1124 — PUBLISH (re-enters lock)
    }

    if (contactId)
        *contactId = (INT32)contactIdlocal;                      // line 1128
    return error;
}
```

**The fix (ONE change):** Move `LeaveCriticalSection(&rdpei->lock);` from line 1069 to just before the `if (contactId) *contactId = ...` assignment (after line 1124, before line 1127). The resulting locked region covers both reserve (line 1066) and publish (line 1124).

**Why this is safe:** WinPR's CriticalSection is recursive (`winpr/libwinpr/synch/critical.c:189-194`). When `context->AddContact` calls `rdpei_add_contact` (line 1033), that function does `EnterCriticalSection(&rdpei->lock)` at line 1042 — this will recurse (RecursionCount++) rather than deadlock. Its `LeaveCriticalSection` at line 1047 decrements once. The moved outer `LeaveCriticalSection` at ~line 1127 fully releases. The poll thread (`rdpei_poll_run`, line 485-493) holds the same lock while running `rdpei_add_frame` (line 160-214), so it cannot observe a reserved-but-unpublished contact mid-frame.

**Exact edit:**
- **REMOVE** line 1069: `LeaveCriticalSection(&rdpei->lock);`
- **ADD** after line 1124 (after `error = context->AddContact(context, &contact);`), before line 1127 (`if (contactId)`): `LeaveCriticalSection(&rdpei->lock);`

This is the ONLY permitted change to `channels/rdpei/`. No other channel edit.

---

### `client/X11/xf_touch.c` + `xf_touch.h` (OPTIONAL — planner's discretion)

**Role:** service (touch lifecycle helpers)
**Data flow:** event-driven (forced-cancel, fallback latch, content-bounds gate, recovery gate)
**Analog:** `client/X11/xf_input.c:641-673` (xf_input_touch_remote) — the existing native-touch path that the new module wraps

**Match quality:** role-match (new file, same data flow). The ponytail-preferred alternative is to keep the logic inline in `xf_input.c` if it stays under ~150 lines. Recommend the separate file only if the four concerns (ownership, suppression, fallback, cancel) exceed inline readability.

**If created, the forced-cancel function shape** (derived from `rdpei_main.c:1192-1201` TouchCancel + `client.h:137` contacts[10]):
```c
// xf_touch.h
#ifndef XF_TOUCH_H
#define XF_TOUCH_H

#include "xfreerdp.h"

void xf_touch_force_cancel(xfContext* xfc);
BOOL xf_touch_content_bounds_check(xfContext* xfc, int window_x, int window_y);
void xf_touch_record_canceled(xfContext* xfc, int touchId);
BOOL xf_touch_is_canceled(xfContext* xfc, int touchId);
void xf_touch_arm_recovery_gate(xfContext* xfc);
BOOL xf_touch_recovery_gate_allows(xfContext* xfc, int touchId);

#endif
```

```c
// xf_touch.c — forced-cancel implementation shape
void xf_touch_force_cancel(xfContext* xfc)
{
    rdpClientContext* cctx = &xfc->common;
    RdpeiClientContext* rdpei = cctx->rdpei;

    for (size_t i = 0; i < FREERDP_MAX_TOUCH_CONTACTS; i++)
    {
        FreeRDP_TouchContact* c = &cctx->contacts[i];
        if (c->id != 0)   // active slot
        {
            int dummy = 0;
            if (rdpei)
                rdpei->TouchCancel(rdpei, c->id, c->x, c->y, &dummy);  // UP|CANCELED
            xf_touch_record_canceled(xfc, c->id);  // D-07 idempotency set
            FreeRDP_TouchContact empty = { 0 };
            *c = empty;
        }
    }
    xf_touch_arm_recovery_gate(xfc);  // D-08
}
```

**Key design constraints for the forced-cancel:**
- Iterates `cctx->contacts[]` (the authoritative native-path store, `include/freerdp/client.h:137`), NOT `xfc->contacts[]` (the local-gesture array, `xfreerdp.h:304`).
- Calls `rdpei->TouchCancel` (rdpei_main.c:1192) which emits `UP | CANCELED` — the correct abort semantic per D-05.
- Records canceled IDs in `xfc->canceledIds[]` for idempotency (D-07).
- Arms the recovery gate (D-08) by recording currently-down fingers in `xfc->quarantinedFingers[]`.
- Clears the `cctx->contacts[]` slot after cancel so the common helper doesn't retain stale state.

---

## Shared Patterns

### Authentication / Authorization
Not applicable. Phase 2 operates entirely within the existing X11 client process; no new auth boundary.

### Error Handling
**Source:** `client/X11/xf_input.c:641-673` (xf_input_touch_remote)
**Apply to:** All new touch-lifecycle code in xf_input.c / xf_touch.c

The existing pattern is defensive early-return:
```c
if (!rdpei)
    return 0;
```
New code should follow the same pattern: validate inputs, return early on invalid state, use `WINPR_ASSERT` for programmer errors, and `WLog_DBG`/`WLog_WARN` for diagnostic logging. No exceptions, no longjmp.

### Logging
**Source:** `client/X11/xf_input.c:44` (TAG definition)
**Apply to:** All new code in client/X11/

```c
#define TAG CLIENT_TAG("x11")
```
Use `WLog_DBG(TAG, "format", ...)` for diagnostic messages. The existing `DEBUG_XINPUT` guard (line 56) can be extended for verbose touch tracing. Log coordinates only at `WLOG_DEBUG` level (env-gated).

### XI2 Event Access Pattern
**Source:** `client/X11/xf_input.c:853-904` (xf_input_handle_event_remote)
**Apply to:** All new XI2 event handling

```c
XGetEventData(xfc->display, cookie.vc);
// ... access cookie.cc->data, cookie.cc->evtype ...
XFreeEventData(xfc->display, cookie.vc);
```
Always pair `XGetEventData` with `XFreeEventData`. The `cookie.cc->data` is a `XIDeviceEvent*` for touch/button/motion events.

### Coordinate Transform Pattern
**Source:** `client/X11/xf_input.c:653-655` (xf_input_touch_remote)
**Apply to:** All touch coordinate handling

```c
x = (int)event->event_x;
y = (int)event->event_y;
xf_event_adjust_coordinates(xfc, &x, &y);
```
The content-bounds gate (D-11) must run BEFORE `xf_event_adjust_coordinates`, on the raw window coordinates (`event_x/event_y`), because the transform subtracts `offset_x/offset_y` which would mask the letterbox condition.

### RDPEI vtable access
**Source:** `client/X11/xf_input.c:646` (xf_input_touch_remote)
**Apply to:** All RDPEI channel access

```c
RdpeiClientContext* rdpei = xfc->common.rdpei;
```
Always check for NULL before calling any `rdpei->*` method. The `cctx->rdpei` is NULL before channel connect (client.c:1506) and after disconnect (client.c:1557).

### Contact Store Access
**Source:** `client/common/client.c:1914-1936` (freerdp_client_touch_update)
**Apply to:** Forced-cancel iteration

```c
for (size_t i = 0; i < ARRAYSIZE(cctx->contacts); i++)
{
    FreeRDP_TouchContact* contact = &cctx->contacts[i];
    if (contact->id != 0)  // active slot
    { ... }
}
```
The sentinel for an empty slot is `id == 0`. The array size is `FREERDP_MAX_TOUCH_CONTACTS` (10, `include/freerdp/client.h:86`).

## No Analog Found

None. Every file this phase touches has an exact analog: the very function being modified. This phase is a correctness phase that extends existing code paths, not a greenfield phase.

## Metadata

**Analog search scope:** `build/freerdp3-3.15.0+dfsg/client/X11/`, `build/freerdp3-3.15.0+dfsg/client/common/`, `build/freerdp3-3.15.0+dfsg/channels/rdpei/client/`, `build/freerdp3-3.15.0+dfsg/include/freerdp/`
**Files scanned:** 8 (xf_input.c, xf_event.c, xf_client.c, xfreerdp.h, client.c, rdpei_main.c, rdpei.h, client.h)
**Pattern extraction date:** 2026-08-06

## PATTERN MAPPING COMPLETE

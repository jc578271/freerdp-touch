---
phase: 02-native-rdpei-touch-lifecycle
review_depth: standard
reviewer: gsd-code-reviewer
date: 2026-08-06
---

# Phase 02 Code Review — Native RDPEI Touch Lifecycle

Reviews the source changes from Plan 01 and Plan 02:

- `build/freerdp3-3.15.0+dfsg/channels/rdpei/client/rdpei_main.c` (#12174 lock-scope fix)
- `build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c` (ownership, emulated suppression, bounds gate, force-cancel, idempotency, recovery gate, fallback latch)
- `build/freerdp3-3.15.0+dfsg/client/X11/xfreerdp.h` (7 new xfContext fields)
- `build/freerdp3-3.15.0+dfsg/client/X11/xf_input.h` (xf_touch_force_cancel declaration)
- `build/freerdp3-3.15.0+dfsg/client/X11/xf_event.c` (force-cancel in FocusOut/UnmapNotify/ConfigureNotify)
- `build/freerdp3-3.15.0+dfsg/client/X11/xf_client.c` (force-cancel in toggle_fullscreen/post_disconnect)

## Verdict

The core mechanisms are sound: the #12174 lock fix is correct, XI2 ownership
acceptance and emulated-pointer suppression are right, and the forced-cancel
seam is wired into all five lifecycle hooks as planned. Three latent
build-config bugs and one real correctness bug in the idempotency/recovery-gate
interaction need attention. The Debian target build (WITH_XI=ON, WITH_XRENDER=ON)
is not affected by the build-config items, so on-device functionality is intact;
the idempotency bug can produce a transient stuck contact and should be fixed.

## Findings

### M1 — Stale `canceledIds[]` swallows legitimate TouchEnd after XI2 touchId reuse

**Severity:** medium
**File:** `client/X11/xf_input.c` (xf_touch_force_cancel L788-821, recovery gate L1018-1068, idempotency check L756-774)

`xf_touch_force_cancel` records each canceled contact's id into TWO separate
arrays: `canceledIds[]` (consumed by the idempotency check in
`xf_input_touch_remote`) and `quarantinedFingers[]` (consumed by the recovery
gate in `xf_input_handle_event_remote`). The recovery gate sits at the top of
`xf_input_handle_event_remote` and consumes the delayed `XI_TouchEnd` for every
quarantined finger — removing it from `quarantinedFingers[]` and disarming the
gate when the last one lifts. But the gate never touches `canceledIds[]`, and
the idempotency check (the only `canceledIds[]` consumer) is never reached
because the gate returns 0 first.

Result: `canceledIds[]` retains the canceled touchIds until the next
`xf_touch_force_cancel` resets `canceledIdCount = 0`. XI2 reuses tracking IDs
once a finger lifts, so the next touch after the gate lifts can reuse a stale
id. That new touch's `XI_TouchEnd` reaches `xf_input_touch_remote` (gate now
disarmed), hits the idempotency check, matches the stale entry, and is silently
consumed — the `FREERDP_TOUCH_UP` is never sent, leaving a stuck RDPEI
contact on the server. It self-heals on the next lifecycle event (which
force-cancels the stuck contact) but produces exactly the ghost-touch
condition the phase set out to eliminate.

The idempotency check is also redundant: `freerdp_client_touch_update`
(client.c:1914-1939) already returns FALSE for an UP whose touchId is not in
`cctx->contacts[]` (force_cancel cleared the slot), so `freerdp_client_handle_touch`
never emits a second terminal event even without the check. The recovery gate
+ `cctx->contacts[]` clearing already provide two layers of defense; the
`canceledIds[]` layer adds a third that is out of sync and harmful.

**Fix (pick one):**
- Remove the `canceledIds[]` idempotency check entirely (rely on the recovery
  gate + cleared `cctx->contacts[]` slots); delete `canceledIds[]`/`canceledIdCount`.
- Or, when the recovery gate consumes a quarantined `XI_TouchEnd`, also remove
  the id from `canceledIds[]` so the two structures stay in sync.
- Or, clear `canceledIds[]` (set `canceledIdCount = 0`) when the recovery gate
  disarms (`quarantinedCount == 0`).

### M2 — Content-bounds gate rejects ALL touches when `WITH_XRENDER=OFF`

**Severity:** medium (latent — Debian build has XRENDER on)
**File:** `client/X11/xf_input.c` (xf_input_touch_remote bounds gate L736-744 native, L668-676 fallback)

The bounds gate computes `right = xfc->offset_x + xfc->scaledWidth` and rejects
when `x >= right`. `offset_x`/`offset_y`/`scaledWidth`/`scaledHeight` are
initialized ONLY under `#ifdef WITH_XRENDER` (xf_client.c:363-373, 642-667,
1402-1409). Every assignment site is XRENDER-guarded. With XRENDER off, all
four stay at their zero-init default, so `right = 0` and `x >= 0` is always
true — every touch is dropped before the coordinate transform, breaking touch
input entirely.

**Fix:** Guard the bounds gate with `#ifdef WITH_XRENDER` (skip the gate when
XRENDER is off, since there is no letterbox without scaling), or initialize
`scaledWidth`/`scaledHeight` to `DesktopWidth`/`DesktopHeight` and offsets to 0
unconditionally in `xf_client.c` init.

### M3 — `xf_touch_force_cancel` calls link-fail when `WITH_XI=OFF`

**Severity:** medium (latent — Debian build has XI on)
**Files:** `client/X11/xf_input.h` L33, `client/X11/xf_event.c` L712/844/956, `client/X11/xf_client.c` L805/1473

`xf_input.h` declares `void xf_touch_force_cancel(xfContext* xfc);` OUTSIDE the
`#ifdef WITH_XI` guard (line 33, after the `#endif` at line 28). The definition
in `xf_input.c` is inside the `#ifdef WITH_XI` block (before the `#else` stub at
L1122). `xf_event.c` and `xf_client.c` are always compiled (CMakeLists.txt SRCS
list, not XI-gated) and call `xf_touch_force_cancel` unconditionally. With
`WITH_XI=OFF` this is an unresolved-symbol link error.

**Fix:** Move the declaration in `xf_input.h` inside the `#ifdef WITH_XI`
block, and guard the five call sites (or the containing functions) with
`#ifdef WITH_XI`. Alternatively, add a no-op stub in the `#else` branch of
`xf_input.c`.

## Low-Severity Findings

### L1 — Fallback latch not reset by `xf_touch_force_cancel`

**Severity:** low
**File:** `client/X11/xf_input.c`

`xf_touch_force_cancel` iterates `cctx->contacts[]`, which the fallback latch
never populates (it calls `freerdp_client_send_button_event` directly, bypassing
`freerdp_client_handle_touch`). So a fallback drag in progress (rdpei NULL,
`fallbackActive=TRUE`, button1 held) is invisible to force-cancel: a FocusOut
or UnmapNotify during a fallback drag leaves `fallbackActive=TRUE` with button1
down on the remote. If the finger's `XI_TouchEnd` is lost while the window is
unmapped, the button stays stuck until the next fallback cycle. Affects only
RDPEI-unavailable sessions (e.g., pre-channel-connect login screen), so impact
is limited.

**Fix (optional):** In `xf_touch_force_cancel`, if `xfc->fallbackActive` is
TRUE, synthesize a button1 UP (`freerdp_client_send_button_event(..., PTR_FLAGS_BUTTON1, ...)`)
and clear `fallbackActive`/`fallbackFinger`.

### L2 — `xfContext` lifecycle fields unsynchronized across disconnect thread

**Severity:** low
**File:** `client/X11/xf_input.c`

`xf_touch_force_cancel` in `xf_post_disconnect` reads/clears `cctx->contacts[]`
and writes `canceledIds[]`/`quarantinedFingers[]` without a lock. If the X11
event thread is concurrently in `xf_input_touch_remote` (writing the same
arrays), there is a data race. Low because the event loop is normally stopped
before `xf_post_disconnect` runs, but it is not guaranteed by these files.

### L3 — New-touch `XI_TouchOwnership` during recovery gate not accepted

**Severity:** low
**File:** `client/X11/xf_input.c` L1060-1066

When the recovery gate is armed and a new (non-quarantined) `XI_TouchOwnership`
arrives, the gate returns 0 without calling `XIAllowTouchEvents`. Under the
exclusive-accept model the WM is never told accept/reject for that touch, which
may freeze the grab until a timeout. Matches D-08 intent (ignore new touches)
but the WM handling is unspecified. Consider calling
`XIAllowTouchEvents(..., XIAcceptTouch)` then returning, as the quarantined
branch does, to keep the WM cooperative.

## Info / Pre-existing (not introduced by this phase)

### I1 — `register_input_events` touch device never sets `used=TRUE`

**File:** `client/X11/xf_input.c` L108-124 (pre-existing; this phase added `XI_TouchOwnership` to the same mask)

The `XITouchClass` branch sets masks on `masks[nmasks]` but never sets
`used=TRUE`, so `nmasks++` (L184) only fires if the device also has a button
class. A touch-only device's mask entry can be overwritten by the next device.
The OneMix 3 touchscreen reports a button class so it works in practice; the
new `XI_TouchOwnership` bit inherits the same exposure. Not a regression.

## Positive Observations

- **#12174 fix is correct.** `LeaveCriticalSection` moved from after the reserve
  to after `context->AddContact` (rdpei_main.c L1129), so reserve + publish are
  under one CriticalSection. WinPR `CriticalSection` is recursive
  (critical.c L188-194: `OwningThread == GetCurrentThreadId` → `RecursionCount++`),
  so `rdpei_add_contact`'s re-entry at L1042 nests cleanly — no deadlock. The
  poll thread's `rdpei_add_frame` (called from `rdpei_poll_run` under the same
  lock at L490) is excluded for the whole reserve+publish window. Early-return
  at L1072 still releases the lock.
- **`XIPointerEmulated` check is correct.** Uses direct bitwise AND on the int
  `flags` field (L1096); `XIMaskIsSet` would have been wrong (it targets byte
  arrays, not the `XIDeviceEvent.flags` int). Genuine mouse/stylus still falls
  through to `xf_input_event`.
- **Fallback latch flags match the existing broad fallback** in
  `client/common/client.c` exactly (DOWN: `DOWN|MOVE|BUTTON1`, MOTION: `MOVE`,
  UP: `BUTTON1`), so the remote sees the same button semantics.
- **Recovery gate correctly placed in `xf_input_handle_event_remote` only**
  (not `xf_input_handle_event_local` — the earlier misplacement was caught and
  fixed per the deviation note).
- **`ConfigureNotify` force-cancel gated on size-change only** (L841), avoiding
  spurious cancels on move-only events (D-12).
- **`xf_post_disconnect` force-cancel runs before `gdi_free` and channel
  teardown** (L1473), so `cctx->rdpei` is still valid for `TouchCancel`.
- **Bounds gate runs before `xf_event_adjust_coordinates`** (which subtracts
  `offset_x`/`offset_y`), so the letterbox condition is not masked. Correct.
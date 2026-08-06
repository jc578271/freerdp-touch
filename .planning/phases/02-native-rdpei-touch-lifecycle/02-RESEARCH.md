# Phase 2: Native RDPEI Touch Lifecycle - Research

**Researched:** 2026-08-06
**Domain:** XInput2 touch capture + MS-RDPEI native contact lifecycle, in the Debian FreeRDP 3.15.0 X11 client
**Confidence:** HIGH (every code claim audited against the unpacked tarball at `build/freerdp3-3.15.0+dfsg/`)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**RDPEI-unavailable fallback**
- **D-01:** When RDPEI is unavailable, only the first active touchscreen contact falls back to left-mouse input so login/channel-startup remains usable without another pointer.
- **D-02:** Additional fingers are ignored while that fallback contact is active; they must never emit competing mouse events.
- **D-03:** Input mode is latched for the lifetime of a physical contact. A contact that begins as mouse fallback completes as mouse fallback even if RDPEI appears midway; native RDPEI starts with the next contact after lift.
- **D-04:** The fallback contact supports a complete left-button lifecycle — down, motion, and up — so both tap and drag work. Tap-only fallback is not sufficient.

**Forced contact cancellation**
- **D-05:** A normal `XI_TouchEnd` produces a normal RDPEI lift. Any contact terminated by an interruption instead sends RDPEI cancellation (`UP | CANCELED`) so Windows abandons the action.
- **D-06:** Forced cancellation applies to all relevant transitions: focus loss, unmap/minimize, fullscreen or window-state changes, rotation/scale/geometry changes, RDPEI or channel loss, disconnect, and client shutdown.
- **D-07:** Cleanup is idempotent. A delayed `XI_TouchEnd` or other terminal event for an already canceled touch ID is ignored and must not emit a second terminal RDPEI event.
- **D-08:** After forced cancellation, events from fingers that were already physically down remain quarantined. New touch input is accepted only after every pre-cancellation finger has lifted.

**Coordinate and orientation contract**
- **D-09:** Phase 2 explicitly guarantees the captured daily-use orientation only: the OneMix 3 panel at left rotation, producing a `2560x1600` desktop. Other rotations are not v1 acceptance targets.
- **D-10:** Coordinate correctness must hold in fullscreen and after ordinary live resizing in windowed mode.
- **D-11:** A touch outside the rendered remote-desktop content, including letterbox regions, is ignored. It must not be clamped to the nearest remote edge or converted into local pointer motion.
- **D-12:** If rotation, scale, or window geometry changes while contacts are active, cancel those contacts before adopting the new transform, then apply the all-fingers-lift recovery gate from D-08.

### Claude's Discretion
- Exact helper names, state representation, file split, hook ordering, and debug-log wording are left to planning, provided the lifecycle policies above remain true.
- The planner may choose the smallest safe location for shared cancellation/fallback bookkeeping after auditing all callers; do not duplicate RDPEI's external-ID/contact-ID map or frame encoder.
- Exact tests and diagnostics are flexible, but they must expose XInput ownership, pointer-emulation suppression, contact ordering, two-contact framing, cancellation, and coordinate behavior well enough to verify the phase requirements.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| XINP-01 | A physical touch produces one input sequence in `xfreerdp3`, without a duplicate action from XInput2 pointer-emulation events. | §XInput2 Capture: the touchscreen registers both `XITouchClass` and `XIButtonClass`; `register_input_events` selects both masks on it; `xf_input_handle_event_remote` has no `XIPointerEmulated` filter. Fix surface identified. |
| XINP-02 | Repeated and simultaneous touches keep stable identities for their lifetime and release those identities after end or cancellation, without dropping later touches. | §RDPEI Lifecycle: `cctx->contacts[]` (client.h:137) is the authoritative store, reset on UP (client.c:1929). The #12174 race (present in-tarball) is the threat to identity stability; fixing it preserves XINP-02. The local `xfc->contacts[]` (local-gesture path only) clears on end. |
| COOR-01 | A touch lands at the corresponding remote desktop position in windowed and fullscreen modes and in each supported orientation. | §Coordinates: `xf_event_adjust_coordinates` (xf_event.c:329) is the transform; rotation is handled by the X server (left → 2560x1600). Live-resize refresh confirmed. Letterbox-ignore (D-11) gap identified. |
| RDPEI-01 | A short tap and one-finger drag reach Windows as a complete, ordered native touch sequence from begin through updates to end. | §RDPEI Lifecycle: `freerdp_client_handle_touch` (client.c:1942) → `freerdp_handle_touch_down/motion/up` already emit ordered begin/update/end with correct flags. Phase 2 preserves this path; the #12174 fix prevents lost updates. |
| RDPEI-02 | Finger lift, gesture abort, focus loss, fullscreen/window transition, or disconnect cleanly ends every outstanding remote contact. | §Forced Cancellation: `rdpei->TouchCancel` (rdpei_main.c:1192) emits `UP\|CANCELED`. Five hooks (FocusOut, UnmapNotify, ConfigureNotify, toggle_fullscreen, post_disconnect) currently do NOT clean up touch — all need the forced-cancel seam. |
| RDPEI-03 | Two simultaneous fingers reach Windows as two distinct native contacts without either contact being lost or merged. | §Two-contact framing: `rdpei_add_frame` (rdpei_main.c:160) batches all dirty+active contacts into ONE frame with distinct `contactId` — already correct. The #12174 race is the only threat (can drop one contact mid-frame). |
</phase_requirements>

## Summary

Phase 2 is a correctness phase, not a feature phase. The X11 client already contains the full XInput2-to-RDPEI pipeline, and most of it works. The work is to close five concrete gaps that the on-disk source audit identified, and to leave the parts that already work untouched.

The two highest-risk findings are bug verdicts against the actual tarball, and they dictate very different plan shapes:

1. **#9082 ("dead `contactsCount` array") is ABSENT in this tarball.** There is no `contactsCount` field anywhere in the tree (`grep -rn contactsCount` returns nothing). The shared helper `freerdp_client_touch_update` (client/common/client.c:1907-1940) directly iterates `cctx->contacts[FreeRDP_TouchContact, 10]` (include/freerdp/client.h:137), updates the matching slot in place, and resets it to zero on UP. The array IS populated and the helper works. Phase 2 must **preserve** this path, not fix it. `[VERIFIED: client/common/client.c:1907-1940, include/freerdp/client.h:137]`

2. **#12174 (RDPEI reserve/publish lock race) is PRESENT in this tarball.** `rdpei_touch_process` (channels/rdpei/client/rdpei_main.c:1052-1130) acquires the CriticalSection at line 1064, reserves a contact via `rdpei_contact` at line 1066, then **releases the lock at line 1069** before calling `context->AddContact` at line 1124 (which re-acquires the lock inside `rdpei_add_contact` at line 1042). The poll thread (`rdpei_poll_run`, line 485-493) holds the same lock while running `rdpei_add_frame` (line 160-214), which can reset a reserved-but-unpublished contact's `active=FALSE` at lines 197-200. Phase 2 must **fix** this by widening the lock to cover both reserve and publish. The fix is small: move `LeaveCriticalSection` from line 1069 to after the AddContact call (~line 1127). WinPR's CriticalSection is recursive (winpr/libwinpr/synch/critical.c:189-194), so `rdpei_add_contact`'s re-entry will not deadlock. `[VERIFIED: channels/rdpei/client/rdpei_main.c:1052-1130, 160-214, 485-493; winpr/libwinpr/synch/critical.c:189-194]`

The remaining three gaps are missing pieces, not bugs: (a) no `XI_TouchOwnership` selection and no `XIAllowTouchEvents` call, so touch delivery is at the WM's mercy (XINP-01 prerequisite); (b) no `XIPointerEmulated` filter, so the touchscreen's emulated pointer events produce duplicate mouse input alongside the RDPEI touch (XINP-01); (c) no forced-cancel seam wired into the five lifecycle hooks that currently release only keyboard state, leaving stuck contacts on focus loss / unmap / fullscreen toggle / geometry change / disconnect (RDPEI-02). Coordinate correctness (COOR-01) is mostly already there via `xf_event_adjust_coordinates`, with rotation handled by the X server and live-resize refresh already in ConfigureNotify — the only COOR gap is D-11's letterbox-ignore replacing the current negative-floor clamp.

**Primary recommendation:** Wire one X11-layer touch-lifecycle module (ownership acceptance, emulated-pointer suppression, first-contact-only fallback latch, forced-cancel + recovery-gate, content-bounds coordinate gate) into the existing `xf_input_handle_event_remote` → `xf_input_touch_remote` → `freerdp_client_handle_touch` path, and make the one-line lock-scope fix to `rdpei_touch_process` in the RDPEI channel. Do not duplicate the contact store, do not rewrite the frame encoder, and do not touch the local-gesture path.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| XI2 touch event selection + ownership | X11 client (`xf_input.c`) | — | XI2 is an X11-only API; ownership/acceptance is a per-client policy decision. |
| Emulated-pointer suppression | X11 client (`xf_input.c`) | — | `XIPointerEmulated` is an X11 event flag; only the X11 dispatch sees it. |
| Contact identity / RDPEI framing | RDPEI channel (`rdpei_main.c`) | common client (`client.c`) | The channel owns `externalId→contactId` mapping and frame batching; the common helper owns the 10-slot `cctx->contacts[]`. Never duplicated in X11. |
| Forced cancellation policy | X11 client (new touch module) | event hooks (`xf_event.c`, `xf_client.c`) | The decision to cancel is client policy (what transitions count); the hooks just invoke it. |
| First-contact-only fallback latch | X11 client (new touch module) | — | D-01..D-04 is an X11-session policy; kept out of shared `client/common` so SDL/Wayland keep their broad fallback. |
| Window→remote coordinate transform | X11 client (`xf_event.c`) | X server (rotation) | `xf_event_adjust_coordinates` owns scale/offset; the X server owns rotation. |

## Standard Stack

No new packages. Everything is already linked in the Debian `freerdp3-x11` build. `[VERIFIED: debian/control build-deps already include libxi-dev; WITH_XI / WITH_CHANNELS are on in debian/rules]`

### Core (already in tree)
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| XInput2 (libXi) | XI 2.2 API, server reports 2.4 | `XI_TouchBegin/Update/End`, `XI_TouchOwnership`, `XIAllowTouchEvents`, `XIPointerEmulated` | FreeRDP already requires `WITH_XI`; the OneMix 3 server reports XI 2.4 (baseline-report.md). All functions used here are XI 2.2. |
| RDPEI channel (MS-RDPEI) | protocol V10–V300 | Native touch contacts to Windows | Already implemented in `channels/rdpei/client/`; reused with one lock-scope fix. |
| `freerdp_client_handle_touch` | 3.15.0 | Shared contact-lifecycle helper | Owns `cctx->contacts[10]`; called unchanged from `xf_input_touch_remote`. |
| WinPR CriticalSection | bundled | The RDPEI channel lock | Recursive on Linux (critical.c:189-194) — enables the #12174 fix to nest cleanly. |
| wLog | bundled | `WLog_DBG/WLog_WARN` with `CLIENT_TAG("x11")` | Diagnostics via `WLOG_LEVEL=DEBUG`; no new logging dependency. |

### Supporting
| API | Purpose | When to Use |
|-----|---------|-------------|
| `RdpeiClientContext->TouchCancel` | Emit `UP\|CANCELED` (rdpei_main.c:1192) | Forced cancellation (D-05). Reuse; do not invent a cancel flag. |
| `freerdp_client_send_button_event` | Mouse button1 down/move/up | First-contact-only fallback when `rdpei==NULL` (D-04). |
| `GetTickCount64()` (winpr) | Monotonic timestamps | Recovery-gate bookkeeping if needed; already used by rdpei poll loop (rdpei_main.c:462). |

## Package Legitimacy Audit

> Not applicable. Phase 2 installs zero external packages. All work is in-tree C against libraries the Debian `freerdp3-x11` build already links (libXi, libfreerdp-client3, winpr, wLog). No `npm`/`pip`/`cargo` operations.

## Architecture Patterns

### System Architecture Diagram

```
OneMix 3 touchscreen (XI 2.4, direct, 10-touch) ── id=17, has BOTH XITouchClass + XIButtonClass
        |
        v
register_input_events() [xf_input.c:74]
   ├─ selects XI_TouchBegin/Update/End on touch class  (lines 119-121)
   ├─ selects XI_ButtonPress/Release/Motion on button class (lines 130-132)  ← ALSO on the touchscreen
   └─ (GAP) does NOT select XI_TouchOwnership, does NOT call XIAllowTouchEvents
        |
        v
xf_input_handle_event() [xf_input.c:915]  ── MultiTouchInput? → remote path
        |
        v
xf_input_handle_event_remote() [xf_input.c:853]
   ├─ XI_TouchBegin/Update/End → xf_input_touch_remote()                ── the native path
   ├─ XI_ButtonPress/Motion/Release → (pen check) → xf_input_event()    ── (GAP) no XIPointerEmulated filter
   └─ [PATCH] XI_TouchOwnership case, emulated-pointer suppression, forced-cancel seam
        |
        v
xf_input_touch_remote() [xf_input.c:641]
   ├─ touchId = event->detail;  x,y = event->event_x/y
   ├─ xf_event_adjust_coordinates()  [xf_event.c:329]   ── scale/offset; rotation by X server
   └─ freerdp_client_handle_touch(DOWN/MOTION/UP, touchId, 0, x, y)
        |
        v
freerdp_client_touch_update() [client.c:1907]  ── finds/updates slot in cctx->contacts[10]; resets on UP
        |
        v
freerdp_handle_touch_{down,motion,up}() [client.c:1814/1862/1765]
   ├─ rdpei present? → rdpei->TouchRawEvent(DOWN|INRANGE|INCONTACT ...)  [flags already correct]
   └─ rdpei NULL?    → freerdp_client_send_button_event(BUTTON1|DOWN|MOVE)  ← (GAP) broad, every finger
        |
        v
rdpei_touch_process() [rdpei_main.c:1052]
   ├─ EnterCriticalSection ── rdpei_contact(reserve) ── LeaveCriticalSection (line 1069)  ← #12174 RACE WINDOW
   └─ ... AddContact → rdpei_add_contact: EnterCriticalSection, set data+dirty, Leave  (lines 1042-1047)
        |
        v  (poll thread, ~20ms)
rdpei_add_frame() [rdpei_main.c:160]  ── batches all dirty+active contacts into ONE frame; resets active on UP
```

### Recommended Project Structure
```
client/X11/
├── xf_input.c        # PATCH: XI_TouchOwnership selection, XIAllowTouchEvents, XIPointerEmulated filter,
│                     #        call site for the new touch-lifecycle module
├── xf_event.c        # PATCH: forced-cancel calls in FocusOut/UnmapNotify/ConfigureNotify;
│                     #        content-bounds check in/around the touch coordinate path
├── xf_client.c       # PATCH: forced-cancel calls in xf_toggle_fullscreen + xf_post_disconnect
├── xfreerdp.h        # PATCH: new touch-lifecycle state fields on xfContext
├── xf_touch.c (NEW)  # OPTIONAL: ownership accept, emulated suppression, fallback latch,
│                     #          forced-cancel + recovery gate, content-bounds gate (planner's choice)
└── xf_touch.h (NEW)  # OPTIONAL: its header
channels/rdpei/client/
└── rdpei_main.c      # PATCH: move LeaveCriticalSection in rdpei_touch_process (#12174 fix ONLY)
```
The new `xf_touch.*` files are the planner's discretion (CONTEXT.md "Claude's Discretion"). The ponytail-preferred alternative is to keep the logic inline in `xf_input.c` if it stays under ~150 lines — fewer files, same outcome. Recommend the separate file only if the four concerns (ownership, suppression, fallback, cancel) exceed inline readability.

### Pattern 1: Single insertion point, reuse existing senders
**What:** All X11-layer touch-lifecycle logic hangs off `xf_input_handle_event_remote` (xf_input.c:853) and `xf_input_touch_remote` (xf_input.c:641). It calls existing public APIs only: `freerdp_client_handle_touch`, `rdpei->TouchCancel`, `freerdp_client_send_button_event`. No new channel, thread, or contact array.
**When:** Always for this phase.
**Why:** `freerdp_client_handle_touch` and the RDPEI channel already own contact persistence, ID mapping, and frame batching. Reimplementing any of them duplicates protocol logic and breaks ordering (Pitfall 1 / architecture anti-pattern 2).

### Pattern 2: RDPEI is the single source of truth for contact state
**What:** For native contacts, `cctx->contacts[]` (client.h:137) is the authoritative lifecycle store. The X11 layer tracks only what RDPEI cannot: which fingers to suppress (recovery gate), which contact owns the fallback latch, and which IDs were already force-canceled (idempotency, D-07). It does NOT mirror the externalId→contactId map.
**When:** All native-path bookkeeping.
**Why:** Two sources of truth for contact mapping desync easily. The forced-cancel loop can read `cctx->contacts[]` directly to find active contacts (id != 0) without a parallel array.

### Anti-Patterns to Avoid
- **Routing remote touch through the local-gesture `xfc->contacts[20]` array.** That array (xfreerdp.h:304) and its pinch/pan detectors (`xf_input_detect_pinch/pan`, xf_input.c:328/411) are the `MultiTouchGestures` path and only rescale the local framebuffer via PubSub (`PubSub_OnZoomingChange`, handled under `#ifdef WITH_XRENDER`). They never reach Windows. Leave the local path untouched.
- **A second contact-state map in the X11 layer.** Use `cctx->contacts[]` for the native path; add only per-gesture/quarantine bookkeeping.
- **Modifying RDPEI beyond the #12174 lock-scope fix.** The channel's framing, flag transitions, and contact state machine are correct. The one permitted change is widening the lock in `rdpei_touch_process`.
- **Putting the first-contact-only fallback latch in shared `client/common/client.c`.** D-01..D-04 is X11-session policy; SDL/Wayland keep their broad fallback. Keep the latch in `client/X11/`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Contact ID mapping / externalId→contactId | A parallel map in xf_input.c | `cctx->contacts[]` + RDPEI's `RDPINPUT_CONTACT_POINT` (rdpei_main.h:61) | Two maps desync; #9082 was caused by an intermediary layer. |
| RDPEI frame encoding | A custom frame builder | `rdpei_add_frame` (rdpei_main.c:160) | Protocol-correctness risk; already batches multi-contact correctly. |
| Cancellation semantics | A new "cancel" contact flag | `rdpei->TouchCancel` → `UP\|CANCELED` (rdpei_main.c:1192) | MS-RDPEI defines CANCELED; reusing it is spec-correct. |
| Monotonic timing | `time()`/wall-clock | `GetTickCount64()` (already in tree, used at rdpei_main.c:462) | Suspend/resume must not trigger false gates. |
| Rotation transform | An X/Y swap in xf_input.c | The X server's monitor rotation (eDP-1 "left") | X already delivers coordinates in the rotated 2560x1600 frame; FreeRDP does not rotate. |

## Critical Bug Verdicts (audited against the on-disk tarball)

### #9082 "dead `contactsCount` intermediary" — ABSENT (already correct)
**Evidence:** `grep -rn "contactsCount" build/freerdp3-3.15.0+dfsg/` returns **zero matches**. There is no `contactsCount` field. The shared helper `freerdp_client_touch_update` (client/common/client.c:1907-1940) iterates `cctx->contacts[]` directly:
```c
for (size_t i = 0; i < ARRAYSIZE(cctx->contacts); i++) {
    FreeRDP_TouchContact* contact = &cctx->contacts[i];
    const BOOL newcontact = ((contact->id == 0) && ((flags & FREERDP_TOUCH_DOWN) != 0));
    if (newcontact || (contact->id == touchId)) {
        contact->id = touchId; contact->flags = flags; ...   // POPULATED
        const BOOL resetcontact = (flags & FREERDP_TOUCH_UP) != 0;
        if (resetcontact) { FreeRDP_TouchContact empty = { 0 }; *contact = empty; }  // CLEARED ON UP
        return TRUE;
    }
}
```
`[VERIFIED: client/common/client.c:1907-1940, include/freerdp/client.h:137 (FreeRDP_TouchContact contacts[10])]`

**Plan consequence:** Preserve the `xf_input_touch_remote → freerdp_client_handle_touch` path as-is. Do NOT add an intermediary. The first-touch-Down, every-subsequent-Update, and lift all reach RDPEI.

### #12174 RDPEI reserve/publish lock race — PRESENT (must fix)
**Evidence:** `rdpei_touch_process` (channels/rdpei/client/rdpei_main.c:1052-1130):
```c
EnterCriticalSection(&rdpei->lock);                 // line 1064
const BOOL begin = (contactFlags & RDPINPUT_CONTACT_FLAG_DOWN) != 0;
contactPoint = rdpei_contact(rdpei, externalId, !begin);   // line 1066 — RESERVE (sets active=TRUE)
if (contactPoint) contactIdlocal = contactPoint->contactId;
LeaveCriticalSection(&rdpei->lock);                 // line 1069 — LOCK RELEASED (RACE WINDOW OPENS)
...
if (contactIdlocal >= 0) {
    RDPINPUT_CONTACT_DATA contact = { 0 }; ...      // builds the NEW flags (e.g. UP)
    error = context->AddContact(context, &contact); // line 1124 — PUBLISH (re-enters lock at 1042)
}
```
The poll thread runs `rdpei_add_frame` under the same lock (`rdpei_poll_run`, line 485-493 → `rdpei_update` → `rdpei_add_frame`, line 446). `rdpei_add_frame` (line 160-214) reads each contact's stale `data` and, at lines 195-200, resets `active=FALSE; externalId=0; contactId=0` when `contactFlags & UP`:
```c
if (contact->contactFlags & RDPINPUT_CONTACT_FLAG_UP) {
    contactPoint->active = FALSE;      // line 197
    contactPoint->externalId = 0;      // line 198
    contactPoint->contactId = 0;       // line 199
}
```
In the window between line 1069 (release) and the publish inside `rdpei_add_contact` (line 1042 re-acquire), the poll thread can observe a contact that was reserved but whose `data` still holds the PREVIOUS frame's flags, copy them, and reset `active=FALSE`. The next `rdpei_touch_process` for that externalId calls `rdpei_contact(externalId, !begin=TRUE)` (line 1066), which only matches `active==TRUE` contacts (rdpei_main.c:138-139) — it now returns NULL, so `contactIdlocal` stays -1 and the event is silently dropped. `[VERIFIED: channels/rdpei/client/rdpei_main.c:1052-1130, 160-214, 132-153, 485-493]`

**Fix shape (minimal, channel-scoped):** Move `LeaveCriticalSection(&rdpei->lock);` from line 1069 to just before the `if (contactId) *contactId = ...` assignment (~line 1127), so reserve + publish are one atomic locked region. WinPR's CriticalSection is recursive:
```c
// winpr/libwinpr/synch/critical.c:189-194
if (lpCriticalSection->OwningThread == (HANDLE)(ULONG_PTR)GetCurrentThreadId()) {
    /* Recursion. No need to wait. */
    lpCriticalSection->RecursionCount++;
    return;
}
```
So `rdpei_add_contact`'s `EnterCriticalSection` at line 1042 will recurse (RecursionCount++) rather than deadlock, and its `LeaveCriticalSection` at 1047 decrements once; the moved outer Leave at ~1127 fully releases. The poll thread cannot run `rdpei_add_frame` during the publish because it needs the same lock. `[VERIFIED: winpr/libwinpr/synch/critical.c:150-203]`

**Plan consequence:** One task must edit `channels/rdpei/client/rdpei_main.c` — this single lock-scope move. The channel is otherwise unchanged. This is the ONLY permitted change to `channels/rdpei/`.

### RDPEI contact flags — already correct (Pitfall 2 ABSENT)
`freerdp_handle_touch_down` (client.c:1838-1846) and `freerdp_handle_touch_motion` (client.c:1883-1891) use `RDPINPUT_CONTACT_FLAG_DOWN|INRANGE|INCONTACT` and `UPDATE|INRANGE|INCONTACT`. `freerdp_handle_touch_up` (client.c:1786-1798) sends an explicit `UPDATE|INRANGE|INCONTACT` followed by `UP`. The non-RawEvent path delegates to `rdpei_touch_begin/update/end` (rdpei_main.c:1137-1185) which also set correct flags. `[VERIFIED: client/common/client.c:1765-1905, channels/rdpei/client/rdpei_main.c:1137-1185]`

**Plan consequence:** Preserve, do not fix. The valid combinations (rdpei.h:73-94, mirrored in rdpei_main.h:33-57) are already emitted.

## XInput2 Capture (XINP-01, XINP-02)

### Ownership: not selected, not accepted
`register_input_events` (xf_input.c:74-196) selects `XI_TouchBegin/XI_TouchUpdate/XI_TouchEnd` on direct-touch devices (lines 119-121, gated on `FreeRDP_MultiTouchInput`), but does NOT set `XI_TouchOwnership` in the mask. `grep -n "XIAllowTouchEvents\|XI_TouchOwnership" client/X11/` returns nothing. `[VERIFIED: client/X11/xf_input.c:74-196]`

Per XI 2.2, without accepting ownership a passive touch grab leaves delivery at the WM's mercy — the documented failure mode is touches freezing after `TouchBegin` or `TouchUpdate/End` never arriving, especially in fullscreen under Mutter (the device's WM, baseline-report.md). **Fix surface:** add `XISetMask(masks[nmasks], XI_TouchOwnership)` alongside the existing three (line 119-121), add an `XI_TouchOwnership` case to `xf_input_handle_event_remote` (xf_input.c:863-899), and call `XIAllowTouchEvents(xfc->display, deviceid, touchid, grab_window, XIAcceptTouch)` on `XI_TouchBegin` (accept-on-begin is the exclusive model appropriate for a fullscreen RDP session). `[CITED: X.org XI2proto.txt — touch ownership, XIAllowTouchEvents]`

**Minimal edit surface:** the touch-class branch in `register_input_events` (one `XISetMask` line), plus the ownership case + accept call in `xf_input_handle_event_remote`. The `deviceid` is available from the `XIDeviceEvent`; the `touchid` is `event->detail`; the grab window is `xfc->window->handle`.

### Emulated pointer events: not filtered (the XINP-01 duplicate source)
The touchscreen (id=17, baseline-report.md) exposes BOTH `XITouchClass` and `XIButtonClass`. In `register_input_events`, the `XITouchClass` branch (line 108-123) does NOT set `used=TRUE`, but the `XIButtonClass` branch (line 125-134) sets `used=TRUE` and selects `XI_ButtonPress/Release/Motion`. Because the touchscreen has a button class, it receives BOTH the touch masks AND the button masks. `[VERIFIED: client/X11/xf_input.c:108-134; baseline-report.md touchscreen class list]`

In `xf_input_handle_event_remote` (xf_input.c:853-904), `XI_ButtonPress/XI_Motion/XI_ButtonRelease` fall through (after the pen check, line 875-892) to `xf_input_event` (line 897), which calls `xf_generic_ButtonEvent`/`xf_generic_MotionNotify` (line 781-793) — the mouse path. There is NO check for `XIPointerEmulated` (the `XIDeviceEvent` flag that marks pointer events generated from touch). So every touch produces a real RDPEI contact AND an emulated mouse click/motion at the same coordinate. `[VERIFIED: client/X11/xf_input.c:853-904, 757-851]`

**Fix surface:** in the `XI_ButtonPress/XI_Motion/XI_ButtonRelease` handling (xf_input.c:875-892), test `XIMaskIsSet(event->flags, XIPointerEmulated)` (or the `XIPointerEmulated` flag on the `XIDeviceEvent`) and, when a touch sequence is active / the event is emulated-from-touch, drop it before `xf_input_event`. Genuine mouse/stylus events (not emulated) must still pass through. `[CITED: X.org XI2proto.txt — XIPointerEmulated]`

### Touch ID store + reuse (XINP-02)
The remote path uses `event->detail` (the XI2 tracking ID) as `touchId`, passed to `freerdp_client_handle_touch` as `finger` (xf_input.c:652, 660-666). The authoritative store is `cctx->contacts[10]` (client.h:137), which `freerdp_client_touch_update` resets to zero on UP (client.c:1929-1934) — so the remote path clears its mapping on end. The local-gesture `xfc->contacts[20]` (xfreerdp.h:304, `MAX_CONTACTS=20`) is a SEPARATE array used only by `xf_input_handle_event_local`; it clears `id=0` on `xf_input_touch_end` (xf_input.c:519). The remote path does NOT touch `xfc->contacts[]`, so there is no stale-ID map to clear on the remote path — RDPEI/common owns it. `[VERIFIED: client/X11/xf_input.c:641-673, 474-525; client/common/client.c:1907-1940]`

**Note on ID reuse:** tracking IDs may be reused after `XI_TouchEnd`. Because the remote path does not retain a mapping past UP (cctx slot reset), the reuse pitfall is already mitigated for the native path. The forced-cancel + recovery-gate (D-07/D-08) MUST NOT introduce a long-lived local ID map that survives past end — clear canceled-ID bookkeeping once the contact is fully resolved.

## RDPEI Lifecycle (RDPEI-01, RDPEI-02, RDPEI-03)

### DOWN→MOTION→UP trace
`xf_input_touch_remote` (xf_input.c:641-673) → `freerdp_client_handle_touch` (client.c:1942-1967) → `freerdp_client_touch_update` (client.c:1907-1940, slot update) → `freerdp_handle_touch_down/motion/up` (client.c:1814/1862/1765). When `rdpei->TouchRawEvent` is set (it is, rdpei_main.c:1519), the down/motion/up helpers call it with correct flags; otherwise they fall back to `rdpei->TouchBegin/Update/End`. `[VERIFIED: client/X11/xf_input.c:641-673; client/common/client.c:1765-1967]`

### Two-contact framing (RDPEI-03)
`rdpei_add_frame` (rdpei_main.c:160-214) iterates all `rdpei->contactPoints[]`; every dirty OR active contact is appended to the SAME `contacts[]` array with `frame.contactCount++` (lines 177-194). Two simultaneous contacts therefore land in ONE frame with distinct `contactId` values — already correct. The only threat to RDPEI-03 is the #12174 race (can drop one contact mid-publish); fixing #12174 protects RDPEI-03. No additional framing work needed. `[VERIFIED: channels/rdpei/client/rdpei_main.c:160-214]`

### TouchCancel / UP|CANCELED (RDPEI-02)
`rdpei_touch_cancel` (rdpei_main.c:1192-1201) calls `rdpei_touch_process` with `RDPINPUT_CONTACT_FLAG_UP | RDPINPUT_CONTACT_FLAG_CANCELED`. It is wired as `context->TouchCancel` (rdpei_main.c:1518). The X11 client does NOT currently call it from anywhere — `grep -n "TouchCancel" client/X11/` returns nothing. The forced-cancel seam (D-05) must invoke `rdpei->TouchCancel` (or, equivalently, `freerdp_client_handle_touch` will not emit CANCELED — so TouchCancel is the correct API for D-05). `[VERIFIED: channels/rdpei/client/rdpei_main.c:1192-1201, 1518]`

### Hooks that do NOT clean up touch (the RDPEI-02 gap)
All five lifecycle hooks were audited; none touch contact state:
- `xf_event_FocusOut` (xf_event.c:701-716): sets `focused=FALSE`, releases keyboard (`xf_keyboard_release_all_keypress`), ungrabs. No touch cleanup.
- `xf_event_UnmapNotify` (xf_event.c:946-966): releases keyboard, suppresses output. No touch cleanup.
- `xf_event_ConfigureNotify` (xf_event.c:815-919): updates window geometry + transform inputs, redraws. No touch cleanup.
- `xf_toggle_fullscreen` (xf_client.c:792-812): toggles `fullscreen`, re-sets window fullscreen, fires `PubSub_OnWindowStateChange`. No touch cleanup.
- `xf_post_disconnect` (xf_client.c:1459-1502): tears down channels/gdi/clipboard/disp/window. No touch cleanup.
`[VERIFIED: client/X11/xf_event.c:701-716, 946-966, 815-919; client/X11/xf_client.c:792-812, 1459-1502]`

**Forced-cancel seam shape:** one function (e.g. `xf_touch_force_cancel(xfc)`) that: (1) iterates `cctx->contacts[]` for active slots (id != 0); (2) for each, if `xfc->common.rdpei` is non-NULL, calls `rdpei->TouchCancel(rdpei, contact->id, contact->x, contact->y, &dummy)`; (3) records the canceled IDs in a small local set for idempotency (D-07); (4) arms the all-fingers-lift recovery gate (D-08); (5) is invoked from all five hooks. The channel-loss case (rdpei becomes NULL at client.c:1557) must trigger the seam too — when `cctx->rdpei` transitions to NULL, any active fallback is moot, but local bookkeeping still clears. `[VERIFIED: client/common/client.c:1506, 1557 — rdpei set on connect, NULL on disconnect]`

## Coordinates (COOR-01)

### What `xf_event_adjust_coordinates` actually does
`xf_event_adjust_coordinates` (xf_event.c:329-352) transforms ONLY when `!xfc->remote_app && defined(WITH_XRENDER) && xf_picture_transform_required(xfc)`. The transform (lines 344-345):
```c
double xScalingFactor = DesktopWidth / (double)xfc->scaledWidth;
double yScalingFactor = DesktopHeight / (double)xfc->scaledHeight;
*x = (int)((*x - xfc->offset_x) * xScalingFactor);
*y = (int)((*y - xfc->offset_y) * yScalingFactor);
```
Then `CLAMP_COORDINATES(*x, *y)` (line 351) which ONLY floors negatives to zero (xf_event.c:49-56) — no upper bound, no content-bounds rejection. `[VERIFIED: client/X11/xf_event.c:329-352, 49-56; client/X11/xf_client.c:282-299]`

`xf_picture_transform_required` (xf_client.c:282-299) returns TRUE when `offset_x!=0 || offset_y!=0 || scaledWidth!=DesktopWidth || scaledHeight!=DesktopHeight`.

### Rotation
FreeRDP does NOT perform its own rotation. The X server rotates the panel (baseline-report.md: `eDP-1 ... left`, active mode `1600x2560` → desktop `2560x1600`). X delivers `event_x/event_y` already in the rotated frame. So the left-rotation → 2560x1600 path (D-09) works with no transform beyond scale/offset. `[VERIFIED: baseline-report.md Display section; no rotation code in xf_event_adjust_coordinates]`

### Live resize (D-10)
`xf_event_ConfigureNotify` (xf_event.c:844-866) refreshes `xfc->scaledWidth/scaledHeight` to the window size and zeroes `offset_x/y` when `SmartSizing || MultiTouchGestures`. The launch command uses `/smart-sizing:2560x1600` (baseline-report.md), so `FreeRDP_SmartSizing` is TRUE and live resize refreshes the transform inputs. The touch path reads these same fields, so COOR-01 holds after ordinary resize. `[VERIFIED: client/X11/xf_event.c:840-866]`

### Letterbox ignore (D-11) — the COOR gap
The current `CLAMP_COORDINATES` floors negatives but does NOT reject out-of-content touches. A touch in the letterbox region (where `offset_x/y > 0` because the remote content is centered/pillarboxed) is subtracted by the offset, may go negative, and is floored to 0 — i.e., silently clamped to the nearest edge, which D-11 explicitly forbids. **Fix surface:** before forwarding in `xf_input_touch_remote` (or in a content-bounds gate), compute the content rectangle `(offset_x, offset_y)–(offset_x+scaledWidth, offset_y+scaledHeight)` in window coordinates and IGNORE (return early, no RDPEI/mouse event) any touch whose `event_x/event_y` falls outside it. This is a pre-check on the raw window coordinates, before `xf_event_adjust_coordinates` runs. `[VERIFIED: client/X11/xf_input.c:641-673; client/X11/xf_event.c:329-352]`

## RDPEI-unavailable Fallback (D-01..D-04)

### Current shape: broad, every finger
`freerdp_handle_touch_down/up/motion` (client.c:1823-1833, 1773-1781, 1870-1878) check `if (!rdpei)` and, when RDPEI is absent, call `freerdp_client_send_button_event(cctx, FALSE, PTR_FLAGS_BUTTON1 [|DOWN|MOVE], x, y)` for EVERY contact. So every finger sends a left-button event. `cctx->rdpei` is NULL before channel connect (client.c:1506) and after disconnect (client.c:1557). `[VERIFIED: client/common/client.c:1765-1905, 1506, 1557]`

### Minimal change to first-contact-only + latched (D-01..D-04)
Keep the latch in the X11 layer (D-policy, not shared). In `xf_input_touch_remote` (xf_input.c:641-673): if `xfc->common.rdpei == NULL`, apply a single-contact latch — track an `fallbackFinger` (the first finger to go DOWN while rdpei is NULL) and a `fallbackActive` flag; on DOWN, if no fallback is active, latch this finger and emit button1 DOWN via `freerdp_client_send_button_event`; on MOTION/UP, only act if the finger matches `fallbackFinger`; ignore all other fingers while fallback is active (D-02). The latch holds for the contact's lifetime even if RDPEI appears midway (D-03): decide `rdpei==NULL` at DOWN time and stick with it until UP. D-04's full lifecycle (down/motion/up) is already supported by `freerdp_client_send_button_event` (PTR_FLAGS_DOWN for down, PTR_FLAGS_MOVE for motion, button1-without-DOWN for up). `[VERIFIED: include/freerdp/client.h:287-300 — freerdp_client_send_button_event signature]`

This deliberately does NOT modify `client/common/client.c` — SDL/Wayland keep their broad fallback. The X11 client simply intercepts the `rdpei==NULL` case before calling `freerdp_client_handle_touch` and routes the latched single contact to the button helper directly.

## Integration Seams & Anti-Patterns (confirmed)

- **Insertion point:** `xf_input_handle_event_remote` (xf_input.c:853) after `XGetEventData`/cookie decode is the confirmed seam. The existing `xf_input_touch_remote → freerdp_client_handle_touch` native path is PRESERVED, not duplicated. New logic (ownership case, emulated suppression, fallback latch, forced-cancel invocation, content-bounds gate) attaches here and in `xf_input_touch_remote`.
- **RDPEI channel:** left UNCHANGED except the one #12174 lock-scope move in `rdpei_touch_process` (channels/rdpei/client/rdpei_main.c:1069 → ~1127). The audit proved the race present, so this single fix is required. No other channel edit.
- **`freerdp_client_handle_touch` / `cctx->contacts[]`:** reused as-is. The #9082 audit proved the array is populated; do not add an intermediary.

## Common Pitfalls

### Pitfall A: Emulated-pointer suppression too broad
**What goes wrong:** Dropping ALL `XI_ButtonPress` breaks the real mouse and the stylus (the device has a stylus, baseline-report.md id=15/19).
**How to avoid:** Suppress only when `XIPointerEmulated` is set AND a touch sequence is active (or always when emulated, since the touch path handles the real input). Never suppress non-emulated button events.

### Pitfall B: Forced cancel double-emits on delayed TouchEnd
**What goes wrong:** A forced cancel sends `UP|CANCELED`; the delayed physical `XI_TouchEnd` then arrives and emits a second UP.
**How to avoid:** Record canceled externalIds in a small local set; in the terminal-event path, if the ID is in the canceled set, clear it and return without emitting (D-07 idempotency).

### Pitfall C: Recovery gate (D-08) starves input forever
**What goes wrong:** After forced cancel, fingers still physically down never report an `XI_TouchEnd` the client trusts (because they're quarantined), so new touches are blocked indefinitely.
**How to avoid:** The gate quarantines by tracking the set of fingers that were down at cancel time; it lifts only when that set is empty (each such finger's subsequent `XI_TouchEnd` removes it from the set without emitting). New fingers arriving after the set empties are accepted normally.

### Pitfall D: DBL_EPSILON dedup drops real subpixel motion
`xf_input_is_duplicate` (xf_input.c:290-309) compares `event_x/event_y` with `fabs(...) < DBL_EPSILON`. Under high-DPI (DPI 192, baseline) subpixel touch, near-identical consecutive events are real motion. This affects the local-gesture path (which calls is_duplicate); the remote path (`xf_input_handle_event_remote`) does NOT call is_duplicate, so the native path is unaffected. If the planner adds dedup to the remote path, use a fixed ~0.5px epsilon, not DBL_EPSILON. `[VERIFIED: client/X11/xf_input.c:290-309, 853-904]`

### Pitfall E: CriticalSection assumed non-recursive
If the planner attempts the #12174 fix by inlining `rdpei_add_contact`'s body to "avoid re-entry," they may assume nesting deadlocks. It does not — WinPR CS is recursive (critical.c:189-194). The minimal fix is the lock-scope move, not inlining.

## Code Examples

### Forced-cancel invocation (shape only — names are planner's discretion)
```c
// Source: derived from rdpei_main.c:1192-1201 (TouchCancel) + client.h:137 (contacts[10])
// Called from xf_event_FocusOut, xf_event_UnmapNotify, xf_event_ConfigureNotify,
// xf_toggle_fullscreen, xf_post_disconnect, and on rdpei NULL transition.
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

### #12174 lock-scope fix (the exact move)
```c
// channels/rdpei/client/rdpei_main.c, rdpei_touch_process()
EnterCriticalSection(&rdpei->lock);                 // line 1064 (unchanged)
contactPoint = rdpei_contact(rdpei, externalId, !begin);   // line 1066 (unchanged)
if (contactPoint) contactIdlocal = contactPoint->contactId;
// LeaveCriticalSection(&rdpei->lock);             // line 1069 — REMOVED from here
...
    error = context->AddContact(context, &contact); // line 1124 (unchanged) — re-enters lock recursively
}                                                   // end of if(contactIdlocal >= 0)
LeaveCriticalSection(&rdpei->lock);                 // MOVED to here (~line 1127), after publish
if (contactId) *contactId = (INT32)contactIdlocal;
```

## State of the Art

| Old Approach | Current Approach (3.15.0) | Impact |
|--------------|---------------------------|--------|
| Direct `rdpei->TouchBegin` calls from X11 | `freerdp_client_handle_touch` shared helper (PR #9086 "Multitouch common") | SDL/Wayland reuse; X11 calls the helper. Works in this tarball (#9082 absent). |
| No touch ownership | Still none | Must be added (this phase). |
| Broad mouse fallback | Still broad (every finger) | Must be latched to first contact (D-01..D-04). |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Mutter (GNOME Shell on Xorg, baseline-report.md) delivers `XI_TouchOwnership` events when selected and honors `XIAllowTouchEvents(XIAcceptTouch)`. | XInput2 Capture | If Mutter's touch-ownership delivery differs, accept-on-begin may still freeze in fullscreen; the on-device `xinput test` vs app-log side-by-side check (Validation) catches this. `[CITED: X.org XI2proto, not Mutter-version-specific]` |
| A2 | The launch command's `/smart-sizing:2560x1600` keeps `FreeRDP_SmartSizing` TRUE so ConfigureNotify refreshes `scaledWidth/Height` for the touch transform. | Coordinates | If smart-sizing is off, the transform is identity and live-resize coordinate correctness depends on `/dynamic-resolution` instead; the corner-tap check covers both. `[VERIFIED from baseline-report.md launch command]` |
| A3 | `rdpei->TouchCancel` is safe to call for contacts in any active state (engaged/hovering). | RDPEI Lifecycle | MS-RDPEI allows `UP\|CANCELED` from engaged/hovering (rdpei_main.h:39,44); the state machine accepts it. `[VERIFIED: rdpei_main.h:33-57, rdpei.h:78]` |

All other claims are `[VERIFIED]` against the on-disk tarball with file:line citations.

## Open Questions

1. **Does the OneMix 3 touchscreen's emulated pointer events actually carry `XIPointerEmulated`?**
   - What we know: the device has `XITouchClass` + `XIButtonClass` (baseline-report.md), so XI2 will emulate pointer events for touches.
   - What's unclear: whether Mutter's Xorg session sets the flag reliably. The X.org spec says it should.
   - Recommendation: Validation step — under native X11, `xinput test <id>` while touching, confirm emulated `XI_Motion`/`XI_ButtonPress` carry the flag; if not, fall back to suppressing button events while any touch sequence is active (a per-xfc boolean set on TouchBegin, cleared on TouchEnd).

2. **Should forced-cancel also call `rdpei->SuspendTouch`/`ResumeTouch`?**
   - What we know: D-05..D-08 specify `UP|CANCELED` + recovery gate; the vtable has Suspend/Resume (used for gesture disambiguation in later phases).
   - Recommendation: NOT in Phase 2. Cancellation + gate is sufficient; Suspend/Resume is a Phase 3 (gesture disambiguation) concern. Keep the seam minimal.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Native X11 session | All Phase 2 testing | ✓ (verified, baseline-report.md: Xorg vt2, no Xwayland) | X.org | None — Phase 1 gate enforces |
| libXi (XInput2 2.2+) | XINP-01/02 | ✓ (build-dep, server reports XI 2.4) | 2.4 | — |
| RDPEI channel (`WITH_CHANNELS`) | RDPEI-01/02/03 | ✓ (debian/rules) | 3.15.0 | D-01..D-04 fallback |
| `xinput` CLI | Validation | ✓ (baseline-report.md used it) | 1.6.4 | — |
| `libinput debug-events` | Validation correlation | Install `libinput-tools` if missing | — | `xinput test` alone suffices |

**Missing dependencies with no fallback:** None.

## Validation Architecture

> `workflow.nyquist_validation` is `false` in `.planning/config.json`, so this is not a Nyquist-gated section. It is included because the phase objective requires concrete, verifiable acceptance check shapes the planner can lift into tasks. Touch input cannot be fully unit-tested (it needs the physical panel + native X11 session); the checks split into assert-based self-checks and on-device hardware checks.

### Check Framework
| Property | Value |
|----------|-------|
| Framework | None added. FreeRDP has no unit-test harness for the X11 input path. Use (a) `WLOG_LEVEL=DEBUG` runtime trace assertions and (b) one optional assert-based `demo()` self-check, per ponytail. |
| Config file | none |
| Quick run | `WLOG_LEVEL=DEBUG xfreerdp3 +multitouch /v:<host> ... ` + grep trace |
| Full check | on-device, native-X11 hardware sequence (below) |

### Phase Requirements → Check Map
| Req ID | Behavior | Check Type | Concrete Check | Assert or Hardware |
|--------|----------|-----------|----------------|--------------------|
| XINP-01 | No duplicate from emulated pointer | runtime trace | In `xf_input_handle_event_remote`, log each `XI_ButtonPress` and whether `XIPointerEmulated` was set; assert via grep that during a single tap, exactly one RDPEI DOWN is emitted and zero non-suppressed emulated button presses reach `xf_generic_ButtonEvent`. | Hardware (touch the panel) + trace grep |
| XINP-02 | Stable IDs, released after end/cancel | runtime trace | Log `touchId`/`contactId` per event; for a drag, assert the same `contactId` appears on begin→updates→end; after a forced cancel + all-lift, a new touch gets a fresh mapping with no stale carryover. | Hardware |
| COOR-01 | Touch lands under finger | on-device | Four-corner + center tap in (a) fullscreen and (b) live-resized windowed; verify the Windows cursor lands at each corner. Left rotation only (D-09). | Hardware |
| COOR-01 (D-11) | Letterbox ignored | on-device | In a windowed session with letterbox (offset>0), tap the letterbox bar; assert no remote pointer motion and no RDPEI/UP frame in the trace. | Hardware |
| RDPEI-01 | Complete ordered sequence | runtime trace | Log the flag word per RDPEI contact; for a tap-drag-lift assert the sequence is `DOWN\|INRANGE\|INCONTACT → UPDATE\|INRANGE\|INCONTACT* → UPDATE\|INRANGE\|INCONTACT → UP`. | Hardware + trace |
| RDPEI-02 | Clean end on interruption | on-device + trace | With a finger down: (a) toggle fullscreen, (b) unfocus, (c) minimize/unmap, (d) disconnect. For each, assert the trace shows exactly one `UP\|CANCELED` and no subsequent terminal event for that ID (D-07); after all fingers lift, new touches work (D-08). | Hardware |
| RDPEI-03 | Two contacts same frame | runtime trace | Two-finger pinch; in the RDPEI frame log assert `frame.contactCount >= 2` with two distinct `contactId` values in one frame. | Hardware |
| #12174 fix | No lost update under timing | stress + trace | Rapid alternating tap/drag for ~30s; assert no "contact not found"/dropped-update gaps in the trace (no `contactIdlocal == -1` silent drops). Optional: build with ThreadSanitizer. | Hardware + optional TSan |

### Sampling Rate
- **Per task commit:** the relevant assert/self-check + a short on-device trace of the specific behavior.
- **Phase gate:** all hardware checks above pass on the native-X11 session; RDPEI-02 covers all five interruption paths.

### Wave 0 Gaps
- No test harness exists for the X11 input path. The ponytail-preferred approach: do NOT add a framework. Use `WLOG_LEVEL=DEBUG` trace + grep as the "assert," plus one optional `#ifdef DEBUG_TOUCH` self-check function (pattern already in xf_input.c:56 `DEBUG_XINPUT`) that validates flag combinations and is dead in normal builds. The on-device checks are the real gate.

## Security Domain

> `security_enforcement: true`, ASVS level 1. This phase touches input handling at a trust boundary (touchscreen → RDP session), so the applicable categories are input-validation-adjacent.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V5 Input Validation | yes | Validate touch coordinates against the content rectangle BEFORE forwarding (D-11 content-bounds gate); reject out-of-content touches rather than clamping. This prevents input injection outside the rendered remote area. |
| V4 Access Control | partial | Verify the XI2 device is `XITouchClass` + `XIDirectTouch` before forwarding as RDPEI (already done in `register_input_events`, xf_input.c:112) — non-touch devices must not be routed as native touch. |
| V6 Cryptography | no | No crypto in this path. |
| V2/V3 | no | No auth/session changes. |

### Known Threat Patterns for the touch path
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Touch outside RDP window forwarded as in-window remote touch (input injection) | Tampering | D-11 content-bounds ignore (not clamp). `[VERIFIED gap: current CLAMP_COORDINATES only floors negatives, xf_event.c:49-56]` |
| Stale contact state after disconnect → UAF on reconnect | Elevation/DoS | Forced-cancel in `xf_post_disconnect` clears `cctx->contacts[]`; RDPEI reinitializes its array on the new session. (Reconnect-during-touch full validation is Phase 3 / STAB-02, but the teardown must be correct here.) |
| Non-touch XI2 device routed as RDPEI touch | Spoofing | `register_input_events` gates on `XIDirectTouch` (xf_input.c:112). Preserve. |
| Touch coordinates logged at INFO | Information disclosure | Log coordinates only at `WLOG_DEBUG` (env-gated `WLOG_LEVEL=DEBUG`); default builds stay quiet. |

## Project Constraints (from CLAUDE.md)

Extracted directives governing this phase (treat with the same authority as CONTEXT.md decisions):
- **Patch the existing `xfreerdp3` X11 client** in `client/X11/` — do not create a new RDP client or external daemon. `[VERIFIED: all edits are in client/X11/ + one rdpei_main.c fix]`
- **Reuse the RDPEI channel** — do not reimplement MS-RDPEI framing. The only permitted channel edit is the #12174 lock-scope fix. `[matches architecture anti-pattern 4]`
- **No daemon / uinput** — all in-process via `freerdp_client_handle_touch`. `[confirmed seam]`
- **Native X11 session only** — Phase 1 gate enforces; all validation runs under GNOME on Xorg. `[baseline-report.md]`
- **Low latency** — gesture recognition must not delay ordinary touch. Phase 2 adds no gesture delay (that is Phase 3); the ownership/emulation/cancel work is synchronous and cheap. `[satisfied]`
- **Calibration stays configurable** — not in scope for Phase 2 (no long-press/pinch yet); the forced-cancel and fallback latch are policy, not calibration knobs. `[deferred to Phase 3/4]`
- **Ship as Debian quilt patch** — packaging is Phase 4; Phase 2 edits the clean source tree that Phase 1's workflow re-unpacks. `[matches 01-CONTEXT.md D-12]`

## Files This Phase Will Modify / Create

| File | Status | Role |
|------|--------|------|
| `client/X11/xf_input.c` | MODIFY | Add `XI_TouchOwnership` mask in `register_input_events` (line ~121); add `XI_TouchOwnership` case + `XIAllowTouchEvents(XIAcceptTouch)` in `xf_input_handle_event_remote` (line ~863); add `XIPointerEmulated` suppression in the button branch (line ~875); first-contact-only fallback latch + content-bounds gate in/around `xf_input_touch_remote` (line ~641). |
| `client/X11/xf_event.c` | MODIFY | Add `xf_touch_force_cancel(xfc)` calls in `xf_event_FocusOut` (line ~711), `xf_event_UnmapNotify` (line ~952), `xf_event_ConfigureNotify` geometry-change branch (line ~840, gated on size change for D-12); add content-bounds pre-check before `xf_event_adjust_coordinates` is used for touch (or do it in xf_input.c). |
| `client/X11/xf_client.c` | MODIFY | Add `xf_touch_force_cancel(xfc)` in `xf_toggle_fullscreen` (line ~805) and `xf_post_disconnect` (line ~1468). |
| `client/X11/xfreerdp.h` | MODIFY | Add touch-lifecycle state to `xfContext` (near line ~304): canceled-id set, fallback-active flag + fallbackFinger, recovery-gate finger set. Small fixed-size arrays (≤10). |
| `channels/rdpei/client/rdpei_main.c` | MODIFY (ONE change) | Move `LeaveCriticalSection(&rdpei->lock)` in `rdpei_touch_process` from line 1069 to ~line 1127 (after the AddContext publish). This is the #12174 fix. No other channel edit. |
| `client/X11/xf_touch.c` + `xf_touch.h` | CREATE (optional) | If the four X11-layer concerns exceed inline readability, house them here: `xf_touch_force_cancel`, fallback latch, ownership accept helper, content-bounds gate, recovery-gate. Planner's discretion (CONTEXT.md "Claude's Discretion"). Ponytail default: inline in `xf_input.c` unless it exceeds ~150 lines. |

## Sources

### Primary (HIGH confidence — read this session against the on-disk tarball)
- `build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c` — `register_input_events` (74-196), `xf_input_is_duplicate` (290-309), local touch begin/update/end (474-525), `xf_input_handle_event_local` (527-570), `xf_input_touch_remote` (641-673), `xf_input_event` (757-851), `xf_input_handle_event_remote` (853-904), `xf_input_handle_event` (915-940).
- `build/freerdp3-3.15.0+dfsg/client/common/client.c` — `freerdp_handle_touch_up/down/motion` (1765-1905), `freerdp_client_touch_update` (1907-1940), `freerdp_client_handle_touch` (1942-1967), rdpei attach/detach (1506, 1557).
- `build/freerdp3-3.15.0+dfsg/channels/rdpei/client/rdpei_main.c` — `rdpei_add_frame` (160-214), `rdpei_poll_run`/`rdpei_poll_run_unlocked` (456-493), `rdpei_contact` (132-153), `rdpei_add_contact` (1033-1050), `rdpei_touch_process` (1052-1130), `rdpei_touch_begin/update/end/cancel` (1137-1201), vtable init (1514-1520).
- `build/freerdp3-3.15.0+dfsg/channels/rdpei/client/rdpei_main.h` — `RDPINPUT_CONTACT_POINT` (61-68), state-transition doc (33-57).
- `build/freerdp3-3.15.0+dfsg/include/freerdp/channels/rdpei.h` — `RDPINPUT_CONTACT_FLAGS` (86-94), valid combinations (73-85), `RDPINPUT_CONTACT_DATA` (104-117).
- `build/freerdp3-3.15.0+dfsg/include/freerdp/client.h` — `FREERDP_MAX_TOUCH_CONTACTS` (86), `FreeRDP_TouchContact` (88-96), `cctx->contacts[10]` (137), `FREERDP_TOUCH_*` flags (255-258), `freerdp_client_send_button_event` (299).
- `build/freerdp3-3.15.0+dfsg/client/X11/xf_event.c` — `CLAMP_COORDINATES` (49-56), `xf_adjust_coordinates_to_screen` (299-327), `xf_event_adjust_coordinates` (329-352), `xf_event_FocusOut` (701-716), `xf_event_LeaveNotify` (794-813), `xf_event_ConfigureNotify` (815-919), `xf_event_UnmapNotify` (946-966).
- `build/freerdp3-3.15.0+dfsg/client/X11/xf_client.c` — `xf_picture_transform_required` (282-299), `xf_toggle_fullscreen` (792-812), `xf_post_disconnect` (1459-1502).
- `build/freerdp3-3.15.0+dfsg/client/X11/xfreerdp.h` — `MAX_CONTACTS=20` (127), `touchContact` (130-138), `xfc->contacts[]` + active_contacts + firstDist/lastDist/z_vector/px/py_vector (304-312), `offset_x/y`/`scaledWidth/Height`/`fullscreen`/`focused` (164,194-197,200).
- `build/freerdp3-3.15.0+dfsg/winpr/libwinpr/synch/critical.c` — `EnterCriticalSection` recursion (150-203), confirms recursive CS.
- `build/freerdp3-3.15.0+dfsg/client/common/cmdline.c` — `multitouch` (1164-1168) / `gestures` (1169-1173) cases.

### Secondary (MEDIUM confidence — spec / cited)
- X.org `XI2proto.txt` — `XI_TouchOwnership`, `XIAllowTouchEvents`, `XIPointerEmulated`, passive touch grabs do not freeze the device. `[CITED]`
- MS-RDPEI spec (learn.microsoft.com) — `RDPINPUT_TOUCH_FRAME`, contact state transitions; mirrored verbatim in `rdpei_main.h:33-57` and `rdpei.h:73-94`. `[CITED, cross-verified in-header]`
- `.planning/research/{SUMMARY,ARCHITECTURE,PITFALLS,STACK}.md` — project-level background (built upon, not repeated).
- `.planning/phases/01-environment-gate-build-baseline/baseline-report.md` — device facts: direct-touch id=17 (touch+button classes), 10-touch, 2560x1600 left-rotated, DPI 192, Xorg vt2 native session, launch command, GNOME Shell WM.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all in-tree, verified.
- Architecture / seams: HIGH — every function, line, and struct field read this session against the tarball.
- Bug verdicts (#9082 absent, #12174 present): HIGH — grep + full function reads with quoted evidence.
- Pitfalls: HIGH — grounded in the same source reads.
- XI2/Mutter delivery specifics (ownership, emulation flag reliability): MEDIUM — spec-cited; on-device validation required (Open Question A1).

**Research date:** 2026-08-06
**Valid until:** 2026-09-06 (or until the Debian source version changes; the #12174/#9082 verdicts are pinned to 3.15.0+dfsg-2.1+deb13u3 commit 405d509)

## RESEARCH COMPLETE

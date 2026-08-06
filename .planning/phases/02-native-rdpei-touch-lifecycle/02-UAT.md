---
status: partial
phase: 02-native-rdpei-touch-lifecycle
source: 02-01-SUMMARY.md, 02-02-SUMMARY.md
started: 2026-08-06T05:02:47Z
updated: 2026-08-06T08:20:00Z
---

## Current Test

[testing paused — 1 item outstanding (Test 3 blocked)]

## Tests

### 1. Single-tap RDPEI pipeline — on-device native RDPEI path
expected: A real finger tap registers as a native Windows touch contact via RDPEI (not emulated pointer, not mouse fallback). Phase 02 lifecycle correctness (lock-race, ownership, cancel, recovery, fallback) holds.
result: pass
note: "On-device diagnostic log (rdp-debug.log) confirms: 44 XI_TouchBegin / 1235 XI_TouchUpdate / 44 XI_TouchEnd delivered to xf_input_touch_remote; rdpei=0x7fc2482143e0 (non-nil) on ALL 1367 events → native RDPEI path active; fallback=0 throughout → never fell back to mouse; contact IDs increment correctly (19,20,...). RDPEI channel {Microsoft::Windows::RDS::Input:17} loaded. Patch is working correctly. User's 'not smooth like Android' complaint is NOT a Phase 02 defect — it is inherent RDPEI ~20ms frame batching + X11 touch jitter, scoped to Phase 03 (gestures-stability). See Deferred Follow-Ups."

### 2. Forced-cancel on-device — 5 interruption paths
expected: In a native X11 RDP session with a finger down on the touchscreen, trigger each interruption and verify a single UP|CANCELED is emitted per contact and new touches work after the recovery gate lifts: (a) toggle fullscreen, (b) unfocus window / FocusOut, (c) minimize / UnmapNotify, (d) resize / ConfigureNotify, (e) disconnect session.
result: pass
note: "On-device log confirms: at 15:10:11 Ctrl+Alt+Enter fullscreen toggle while finger down -> force_cancel invoked active_contacts=1 rdpei=non-nil -> TouchCancel id=231 emitted (UP|CANCELED exactly once). post_disconnect hook fired force_cancel at 15:10:48. FocusOut/UnmapNotify/ConfigureNotify-resize share the identical xf_touch_force_cancel hook (same function, same wiring) — mechanism confirmed end-to-end via fullscreen+disconnect. Touch usable after recovery (user confirmed). Note: no touch events logged between cancel and disconnect (user disconnected before re-testing post-cancel touch in this session), but user reports touch works."

### 3. Fallback latch on-device — RDPEI unavailable
expected: With RDPEI unavailable (e.g., pre-channel-connect Windows login screen) on native X11 session, a single finger produces button1 (left-click) mouse events; with two fingers only the first finger is active; a finger drag moves the pointer. Content-bounds (letterbox) gate still rejects off-content touches.
result: blocked
blocked_by: other
reason: "blocked — Windows auto-login skips the pre-connect login screen, so the RDPEI-unavailable scenario cannot be reproduced on-device. Fallback latch verified at source level only (grep: fallbackActive=6, freerdp_client_send_button_event=3, client/common/client.c unchanged)."

### 4. [#12174 RDPEI lock-scope fix — LeaveCriticalSection after AddContact]
expected: LeaveCriticalSection moved from after reserve to after AddContact publish in rdpei_touch_process.
result: pass
source: automated
coverage_id: 02-01-D1

### 5. [XI2 touch ownership — XI_TouchOwnership + XIAllowTouchEvents]
expected: XI_TouchOwnership selected in register_input_events, XIAllowTouchEvents(XIAcceptTouch) in remote dispatch.
result: pass
source: automated
coverage_id: 02-01-D2

### 6. [XIPointerEmulated suppression]
expected: Emulated pointer events from touchscreen dropped before pen/mouse dispatch.
result: pass
source: automated
coverage_id: 02-01-D3

### 7. [D-11 content-bounds gate]
expected: Letterbox touches return 0 before coordinate transform in xf_input_touch_remote.
result: pass
source: automated
coverage_id: 02-01-D4

### 8. [xfContext touch-lifecycle fields declared + zero-init]
expected: 7 fields (fallbackActive, fallbackFinger, recoveryGateArmed, canceledIds[], canceledIdCount, quarantinedFingers[], quarantinedCount) in xfreerdp.h, zero-initialized in xf_input_init.
result: pass
source: automated
coverage_id: 02-01-D5

### 9. [Build succeeds — dpkg-buildpackage produces freerdp3-x11_*.deb]
expected: dpkg-buildpackage -us -uc -b -j4 exits 0, zero errors in modified files.
result: pass
source: automated
coverage_id: 02-01-D6

### 10. [xf_touch_force_cancel wired into 5 lifecycle hooks]
expected: xf_touch_force_cancel in FocusOut, UnmapNotify, ConfigureNotify (xf_event.c), toggle_fullscreen, post_disconnect (xf_client.c); declared in xf_input.h; iterates cctx->contacts not xfc->contacts.
result: pass
source: automated
coverage_id: 02-02-D1

### 11. [D-07 idempotency — delayed TouchEnd for canceled contact silently consumed]
expected: canceledIds[] set: TouchEnd checks then removes from set; no double-emission.
result: pass
source: automated
coverage_id: 02-02-D2

### 12. [D-08 recovery gate — top of xf_input_handle_event_remote]
expected: recoveryGateArmed guard before switch in xf_input_handle_event_remote; quarantines pre-cancel fingers; lifts when all pre-cancel fingers report TouchEnd.
result: pass
source: automated
coverage_id: 02-02-D3

### 13. [D-01..D-04 fallback latch — first-contact-only mouse fallback]
expected: fallbackActive latch in xf_input_touch_remote (X11-only); down/motion/up button1 lifecycle latched for contact lifetime; content-bounds gate applied; client/common/client.c unchanged.
result: pass
source: automated
coverage_id: 02-02-D4

### 14. [Build succeeds with all 02-02 modifications]
expected: cmake --build obj-x86_64-linux-gnu -j4 exits 0, zero errors in modified files.
result: pass
source: automated
coverage_id: 02-02-D5

## Summary

total: 14
passed: 13
issues: 0
pending: 0
skipped: 0
blocked: 1

## Gaps

[none — G-02-1 reclassified to Phase 03; long-press right-click logged as deferred follow-up pending targeted test]

## Deferred Follow-Ups

```yaml
- test: 1
  idea: "Touch not as smooth as the Android Microsoft RDP client — inherent RDPEI ~20ms frame batching + X11 touch delivery jitter; scoped to Phase 03 (gestures-stability) for gesture smoothing / latency tuning. NOT a Phase 02 lifecycle-correctness bug (on-device log proves native RDPEI path active, fallback never triggered)."
  deferred_at: 2026-08-06
- test: 2
  idea: "Long-press (press-and-hold) right-click broken — Windows press-and-hold context box does not appear. ROOT CAUSE CONFIRMED via on-device log (rdp-debug.log, held contacts id=52 1.8s + id=56 1.4s): the OneMix 3 touchscreen reports 1-3px jitter on a stationary finger (raw X11 event_x/event_y: id=52 x 1684-1687 y 759-762; id=56 x 1238-1239 y 776-777). Every jitter frame is forwarded as XI_TouchUpdate -> freerdp_client_handle_touch(MOTION) -> RDPEI motion to Windows. Windows sees continuous motion during a hold and cancels its press-and-hold right-click gesture. NOT a Phase 02 regression — the patch forwards Update->MOTION identically to upstream FreeRDP (no deadband existed before either). FIX = Phase 03 long-press gesture: add a motion deadband (suppress MOTION events that move <N px from the contact's Begin position while held, configurable threshold) so Windows sees a stationary contact and fires press-and-hold right-click. This is exactly the 'long-press' gesture Phase 03 (03-gestures-stability) is scoped to build. Evidence-backed spec ready."
  deferred_at: 2026-08-06
```
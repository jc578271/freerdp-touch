---
status: resolved
trigger: "Khi dùng 2 ngón để cuộn, nút chuột trái vẫn bị giữ (left click stuck/held). Điều tra và sửa đúng root cause trong local touch gesture fallback; giữ nguyên mapping 2 ngón = wheel scroll, 3 ngón = middle-button drag."
created: "2026-08-08"
updated: "2026-08-08T3"
---

# Debug Session: Two-Finger Left Click Held

## Symptoms

### Expected behavior

Khi ngón thứ hai chạm xuống và hai ngón bắt đầu cuộn, nút chuột trái phải ở trạng thái nhả; hai ngón chỉ phát wheel scroll.

### Actual behavior

Nút chuột trái bị giữ ngay khi ngón thứ hai chạm xuống. Nút trái tự nhả sau khi nhấc cả hai ngón.

### Error messages

Không có lỗi được báo cáo.

### Timeline

Bắt đầu sau thay đổi gần nhất: hai ngón chuyển thành wheel scroll và ba ngón chuyển thành middle-button drag.

### Reproduction

1. Chạy patched `xfreerdp3` bằng `bash run-rdp.sh` trong phiên native X11.
2. Đặt ngón thứ nhất lên màn hình.
3. Đặt ngón thứ hai xuống để bắt đầu cuộn.
4. Quan sát nút trái bị giữ trong lúc hai ngón còn chạm; nhấc cả hai thì nút trái nhả.

## Current Focus

- hypothesis: The 2-finger scroll path sends wheel events via freerdp_client_send_wheel_event WITHOUT first moving the remote pointer to the two-finger midpoint. That API takes no coordinates (sends x=0,y=0 to ainput) and relies on the server-side cursor position. Windows RDP wheel events scroll whatever control is under the remote cursor. Since the scroll-claim path (xf_input_two_finger_resolve) never moves the pointer, wheel events target the stale pointer location (e.g. a previously-touched list) instead of the list under the fingers. The pinch path already does midpoint targeting (D-11, line 816-826) via PTR_FLAGS_MOVE; the scroll path is missing the same step.
- test: Move the remote pointer to the two-finger midpoint at scroll-claim time, reusing the exact PTR_FLAGS_MOVE pattern the pinch path uses. User places two fingers over a DIFFERENT list than the last interaction and scrolls — wheel should scroll the list under the fingers, not the old one.
- expecting: 2-finger scroll now targets the control under the current two-finger midpoint. All other gestures (3-finger middle drag, pinch, one-finger tap/drag) and mouse input are unaffected.
- next_action: User runs `bash run-rdp.sh`, tests: (1) place two fingers over a different list and scroll — that list scrolls, not the old one; (2) 2-finger scroll still works; (3) 3-finger middle drag works; (4) pinch zoom works; (5) one-finger tap and drag work; (6) mouse/trackpad still works.
- reasoning_checkpoint:
    hypothesis: "The 2-finger scroll-claim path (xf_input_two_finger_resolve, line 975-985) sets scrollActive=TRUE and initializes scrollLastY/scrollAccum but never moves the remote pointer to the two-finger midpoint. freerdp_client_send_wheel_event (client.c:1590) takes no coordinates — it sends x=0,y=0 to ainput, relying on the server-side cursor. RDP wheel events scroll whatever control is under the remote cursor. With the pointer left at the stale location from a prior interaction, the wheel scrolls the wrong control (the old list, not the one under the fingers). The pinch path already solves this exact problem at line 816-826 with PTR_FLAGS_MOVE midpoint targeting (D-11); the scroll path omits the same step."
    confirming_evidence:
      - "Code: scroll claim (line 976-985) sets scrollActive/scrollLastY/scrollAccum but has NO pointer-move call — confirmed by grep (PTR_FLAGS_MOVE absent from the scroll claim block, present in pinch block line 824 and middle-pan block line 1284)"
      - "API: freerdp_client_send_wheel_event(rdpClientContext*, UINT16 mflags) takes NO coordinates (client.h:285); implementation sends x=0,y=0 (client.c:1590-1602) — relies on server-side cursor position"
      - "Code: the pinch path already does midpoint targeting at claim time via PTR_FLAGS_MOVE (line 819-826) with the pinchMidpointDone gate — exact same pattern, proving the mechanism is correct and already used in this file"
      - "Symptom matches precisely: user reports the OLD list scrolls instead of the list under the fingers — the definition of a stale pointer target"
      - "The prior xi_event=TRUE fix was confirmed working (stuck left-click resolved) — this is a NEW, separate correctness issue, not the old bug reasserting"
    falsification_test: "If moving the pointer to the midpoint at scroll-claim does NOT fix the wrong-list-scrolls symptom, then wheel targeting is NOT driven by server-side cursor position — the issue would be elsewhere (e.g. the control has keyboard focus independent of pointer). User UAT will confirm."
    fix_rationale: "Add one PTR_FLAGS_MOVE call at scroll-claim time, mirroring the pinch path's D-11 midpoint targeting exactly. This is the smallest root-cause fix: it reuses the existing pointer-move path (PTR_FLAGS_MOVE via freerdp_client_send_button_event) that the pinch path and one-finger drag already use for the same purpose. It moves the pointer ONCE at claim time, before any wheel detent — matching the pinch's single-shot targeting model. No new state, no new API, no per-update pointer moves."
    blind_spots: "Have not directly observed the server-side cursor position in RDP traffic. The fix assumes Windows routes wheel events to the control under the cursor (standard WM_MOUSEWHEEL behavior) — this is well-documented but not verified on the user's specific Windows app. If the user's app routes wheel by keyboard focus rather than pointer, this fix will not help and the falsification_test will fire."
    candidate_causes:
      - "[code] Scroll-claim path omits the pointer-move-to-midpoint step that the pinch path has — wheel targets stale cursor location"
      - "[environment] Windows app routes wheel events to the control under the cursor (expected), exposing the missing pointer move"
    and_gate: "no — single cause: the scroll path never moves the pointer to the midpoint. The fix (add the PTR_FLAGS_MOVE call) addresses this directly."

## Evidence

- timestamp: 2026-08-08T1
  checked: rdp-debug-gestures.log (Xwayland session with +touch-pinch-wheel-fallback)
  found: Device is xwayland-touch:16 (id: 10, mode: 1, direct touch, 20 touches). rdpei=(nil) — no RDPEI, fallback mode active. "checking for pen" log appears before each first-finger TouchBegin at the same millisecond, meaning XI_ButtonPress events arrive in parallel with touch events.
  implication: XI button events arrive alongside touch events. If not dropped by XIPointerEmulated check, they fall through to xf_input_event → send real button to RDP.

- timestamp: 2026-08-08T2
  checked: xf_input.c line 1938-1964 (XI_ButtonPress/XI_Motion/XI_ButtonRelease handler in xf_input_handle_event_remote)
  found: The XIPointerEmulated check was ADDED by the Phase 3 patch (not in original upstream). If flag is set → break (drop). If not set and not pen → fall through to default → xf_input_event → xf_generic_ButtonEvent → sends button to RDP. The original upstream code had NO XIPointerEmulated check at all.
  implication: If Xwayland does not set XIPointerEmulated on the compositor-generated pointer events (from xwayland-pointer:16), they bypass the check and send real button events. The fallback gesture code doesn't know about these button events.

- timestamp: 2026-08-08T3
  checked: Traced all BUTTON1 send paths in xf_input.c fallback code
  found: The fallback code NEVER sends BUTTON1 down during the 2-finger scroll path. scrollActive only sends wheel events. The two-finger pending/resolve path doesn't send button events. The log confirms fallback=0 throughout all 2-finger events.
  implication: The stuck BUTTON1 down cannot come from the fallback gesture code. It must come from outside — the XI button event path in xf_input_handle_event_remote.

- timestamp: 2026-08-08T4
  checked: rdp-debug-gestures.log event ordering around 2-finger touch
  found: "checking for pen" (XI_ButtonPress) appears BEFORE "touch_remote: ev=Begin" (XI_TouchBegin) at the same millisecond. The pointer button press arrives first, then the touch begin. The fallback code's lpArmed is not yet set when the button press is processed.
  implication: Even a "suppress button events during active touch" approach would have a race — the button press arrives before the touch begin sets the touch-active state.

- timestamp: 2026-08-08T5
  checked: XInput2.h flags
  found: XIPointerEmulated = (1 << 16) = 0x10000. XITouchEmulatingPointer = (1 << 17) = 0x20000. Diagnostic logging added showing flags value.
  implication: The diagnostic log will show whether 0x10000 bit is set on the "checking for pen" events.

- timestamp: 2026-08-08T6
  checked: rdp-debug-native.log (separate session, native X11 with real touchscreen GXTP7386)
  found: Different device (id: 17), rdpei non-nil (+multitouch mode), also shows "checking for pen" before each touch. This is a different session/config — not the one with the bug.
  implication: The bug is in the Xwayland session (+touch-pinch-wheel-fallback, xwayland-touch:16).

- timestamp: 2026-08-08T7
  checked: Fresh rdp-debug-gestures.log (post-prior-fix, user confirmed stuck button STILL occurs)
  found: (1) "SKIPPED (touch device in fallback mode)" logged for xwayland-touch:16 (id 10) — prior fix active. (2) ZERO "xibutton:" lines in entire log — NO XI2 button events arrive from ANY device. (3) ZERO "checking for pen" lines. (4) 2-finger scroll sessions show fallback=0, pan claimed, wheel emitted — fallback code never sends BUTTON1. (5) xf_event.c has SEPARATE core ButtonPress handler (xf_event_ButtonPress line 583/1276) that calls xf_generic_ButtonEvent → sends button to RDP, bypassing XI2/fallback entirely. (6) Window selects ButtonPressMask (xf_window.c:730). (7) xfc->xi_event flag (drops core events when XI2 handles them) is only set on XI2 button/motion events (xf_input.c:1798) which never arrive in fallback mode.
  implication: The stuck button comes from CORE X11 ButtonPress events generated by Xwayland touch-to-pointer emulation, handled by the separate xf_event_ButtonPress → xf_generic_ButtonEvent path that bypasses the fallback gesture code. The prior fix stopped XI2 emulated events but not core events.

- timestamp: 2026-08-08T8
  checked: User UAT confirmed xi_event=TRUE fix works — stuck left-click is FIXED. New symptom reported: when the user places two fingers over a different list and scrolls, the previous/old list scrolls instead of the list under the fingers.
  found: New correctness issue, distinct from the stuck-button bug. Symptom is stale wheel targeting.
  implication: Wheel events target the wrong control. Investigate the scroll-claim wheel-send path for a missing pointer-move step.

- timestamp: 2026-08-08T9
  checked: scrollActive wheel-send path in xf_input.c (line 1212-1251) and scroll-claim path (xf_input_two_finger_resolve, line 975-985)
  found: scroll-claim sets scrollActive=TRUE, scrollLastY, scrollAccum=0 but NEVER calls any pointer-move. The update path (1212-1251) computes midY and emits wheel via freerdp_client_send_wheel_event but never moves the pointer. grep confirms PTR_FLAGS_MOVE is absent from the scroll claim block but present in the pinch block (line 824) and middle-pan block (line 1284).
  implication: The scroll path omits the pointer-move-to-midpoint step that the pinch and middle-pan paths have. Wheel events go to the stale cursor location.

- timestamp: 2026-08-08T10
  checked: freerdp_client_send_wheel_event API (client.h:285, client.c:1590)
  found: Signature is BOOL freerdp_client_send_wheel_event(rdpClientContext* cctx, UINT16 mflags) — NO coordinates. Implementation sends x=0, y=0 to ainput (client.c:1601-1602), relying on the server-side cursor position. RDP wheel events scroll the control under the remote cursor.
  implication: Confirms the hypothesis — without moving the pointer to the midpoint, wheel events target the stale cursor. The fix is to move the pointer to the midpoint at scroll-claim time, reusing the PTR_FLAGS_MOVE pattern the pinch path already uses (line 823-824).

- timestamp: 2026-08-08T11
  checked: Mutual-exclusivity of scroll-claim vs other gesture/mouse paths
  found: scroll-claim (xf_input_two_finger_resolve) only runs when twoFingerPending=TRUE (two fingers down). one-finger drag uses fallbackActive (separate state, armed only when twoFingerPending is FALSE). 3-finger middle drag uses midActive (threeFingerPending, separate). pinch uses pinchActive (separate). Mouse uses XI2 button events from xwayland-pointer:16 (id 6), not touch events. The PTR_FLAGS_MOVE at scroll-claim cannot interfere with any of these.
  implication: Adding PTR_FLAGS_MOVE at scroll-claim is safe — it only fires in the 2-finger-scroll gesture, which is mutually exclusive with all other input paths.

## Eliminated

- hypothesis: The fallback gesture code sends a spurious BUTTON1 down during the 2-finger scroll path.
  evidence: Log shows fallback=0 throughout all 2-finger events. The scrollActive path only sends wheel events. The two-finger pending/resolve path never sends button events.
  timestamp: 2026-08-08T3

- hypothesis: XI2 emulated button events from the touch device (id 10) bypass the XIPointerEmulated check and fall through to xf_input_event → stuck BUTTON1.
  evidence: Fresh log (post-fix) shows "SKIPPED (touch device in fallback mode)" for id 10 AND zero "xibutton:" lines — NO XI2 button events arrive at all from any device. Yet the stuck button STILL occurs (user confirmed). The prior fix successfully stopped XI2 button events but did not fix the symptom.
  timestamp: 2026-08-08T7

## Resolution

- root_cause: "Two separate root causes fixed in this session. (1) Stuck left-click: in fallback mode, Xwayland touch-to-pointer emulation generates CORE X11 ButtonPress/ButtonRelease events that bypass the XI2/fallback path via xf_event_ButtonPress → xf_generic_ButtonEvent → sends real BUTTON1 to RDP. The xi_event flag that drops core events was never set in fallback mode. Fixed by setting xi_event=TRUE at init. CONFIRMED FIXED by user UAT. (2) Wrong-list-scrolls: the 2-finger scroll-claim path (xf_input_two_finger_resolve) sends wheel events via freerdp_client_send_wheel_event WITHOUT moving the remote pointer to the two-finger midpoint. That API takes no coordinates and relies on the server-side cursor, so wheel events target the stale pointer location (the old list) instead of the control under the fingers. The pinch path already does midpoint targeting via PTR_FLAGS_MOVE (D-11); the scroll path omitted the same step."
- fix: "(1) xi_event=TRUE at init — already applied and UAT-confirmed. (2) Added one PTR_FLAGS_MOVE call at scroll-claim time (xf_input_two_finger_resolve, after scrollActive=TRUE), moving the hidden remote pointer to the two-finger midpoint before any wheel detent. Mirrors the pinch path's D-11 midpoint targeting exactly — same API (freerdp_client_send_button_event with PTR_FLAGS_MOVE), same single-shot-at-claim model. No new state, no new API."
- verification: "Build: clean (xf_input.c.o rebuilt, xfreerdp3 re-linked, no new errors/warnings — only pre-existing codecs_free deprecation notes). Self-check: PTR_FLAGS_MOVE is the same mechanism the pinch path (line 824) and one-finger drag (line 1318/1335) use to move the pointer — proven correct in this file. The scroll-claim block is only reached via twoFingerPending (two fingers down), mutually exclusive with one-finger drag (fallbackActive) and mouse (XI2 button events from id 6, not touch). Moving the pointer once at claim does not break: pinch (separate state), 3-finger middle drag (separate state with its own PTR_FLAGS_MOVE at line 1284), one-finger tap/drag (lpArmed/fallbackActive, not two-finger). HUMAN UAT CONFIRMED: (1) stuck left-click fixed; (2) 2-finger scroll over list B now scrolls list B, not stale list A; all other gestures (3-finger middle drag, pinch, one-finger tap/drag) and mouse/trackpad behavior preserved."
- files_changed:
  - "build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c"
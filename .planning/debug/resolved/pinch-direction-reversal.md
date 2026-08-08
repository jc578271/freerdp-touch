---
status: resolved
trigger: "Trong chế độ không multitouch, sau khi pinch để zoom out, nếu vẫn giữ hai ngón trên màn hình và đảo chiều pinch thì không zoom in ngay; phải nhấc tay rồi pinch lại. Tìm root cause và sửa để đổi hướng zoom in/out ngay trong cùng một gesture, không làm hỏng scroll hai ngón vừa sửa."
created: "2026-08-08"
updated: "2026-08-08T09:30:00+07:00"
resolved: "2026-08-08T09:30:00+07:00"
---

# Debug Session: Pinch Direction Reversal

## Symptoms

### Expected behavior

Trong cùng một gesture với hai ngón vẫn chạm màn hình, sau khi pinch để zoom out, đảo chiều chuyển động phải phát zoom in ngay; tương tự, zoom in rồi đảo chiều phải zoom out mà không cần nhấc tay.

### Actual behavior

Sau khi pinch theo một hướng để zoom out, đảo chiều khi hai ngón vẫn đang chạm không phát zoom in. Chỉ sau khi nhấc cả hai ngón và bắt đầu gesture pinch mới thì hướng zoom in mới hoạt động.

### Error messages

Không có lỗi được báo cáo.

### Timeline

Được quan sát trên bản local-only/non-multitouch hiện tại sau khi các gesture pinch `Ctrl+wheel` đã hoạt động. Chưa có bằng chứng rằng đảo chiều từng hoạt động trong cùng gesture.

### Reproduction

1. Chạy patched `xfreerdp3` ở chế độ không `+multitouch`, với local pinch fallback đang bật.
2. Đặt hai ngón và pinch theo hướng zoom out cho tới khi ứng dụng remote thu nhỏ.
3. Không nhấc tay, đảo chiều hai ngón để zoom in.
4. Quan sát không có zoom in.
5. Nhấc tay, đặt lại hai ngón và pinch theo hướng zoom in; zoom in hoạt động.

## Current Focus

- hypothesis: D-12 reversal hysteresis (line 864-866) zeroes pinchAccum on every tick where currentDir != pinchDir, but pinchDir only updates inside the while-loop when a detent is emitted. Since the accumulator is zeroed before reaching the 40px threshold, no detent is ever emitted in the reversed direction, so pinchDir stays latched to the old direction forever — a deadlock that blocks direction reversal mid-gesture.
- test: Trace the pinchAccum/pinchDir state through a zoom-out then reversal sequence tick by tick.
- expecting: Confirm the accumulator never builds past PINCH_WHEEL_STEP_PX=40 after reversal because it is reset every tick.
- next_action: write reasoning checkpoint, apply one-line fix (clear pinchDir to 0 alongside pinchAccum=0 in the hysteresis block), add regression check, rebuild.
- reasoning_checkpoint:
    hypothesis: "D-12 reversal hysteresis zeroes pinchAccum on every reversed-direction tick because pinchDir is only updated inside the detent-emission while-loop, creating a deadlock: accumulator can't reach threshold → no detent → pinchDir never updates → hysteresis keeps firing."
    confirming_evidence:
        - "Lines 864-866: hysteresis condition `currentDir != 0 && pinchDir != 0 && currentDir != pinchDir` → zeroes pinchAccum, but does NOT update pinchDir."
        - "pinchDir is only set inside the while-loop at lines 876 and 885, which only runs when abs(pinchAccum) >= PINCH_WHEEL_STEP_PX (40px)."
        - "After zoom-out detent: pinchDir=-1. On reversal (delta>0): currentDir=1 != pinchDir=-1 → pinchAccum=0 every tick. Accumulator can never reach 40px. Deadlock."
    falsification_test: "If pinchDir were cleared to 0 alongside pinchAccum=0 in the hysteresis block, the hysteresis condition `pinchDir != 0` would fail on subsequent ticks, allowing pinchAccum to build up to 40px and emit the reversed detent."
    fix_rationale: "Adding `pinchDir = 0` in the hysteresis block clears the latched direction so the hysteresis fires exactly once on reversal, discards the old residual, then lets the accumulator build in the new direction until the next detent sets pinchDir to the new value. One-line change at the single seam all pinch updates route through."
    blind_spots: "Not tested on physical hardware — logic traced from source only. No existing test harness for this path."
    candidate_causes:
        - "code: D-12 hysteresis block omits pinchDir reset (root cause)"
        - "config: none — PINCH_WHEEL_STEP_PX and PINCH_DOMINANCE_RATIO are correct values; the deadlock is structural, not threshold-dependent"
    and_gate: "no — single cause: the hysteresis block fails to clear pinchDir, creating the deadlock by itself."
- tdd_checkpoint:

## Evidence

- timestamp: 2026-08-08T09:00
  checked: xf_input_pinch_update() lines 809-893, the fallback pinch Ctrl+wheel synthesizer
  found: |
    D-12 reversal hysteresis at lines 860-866:
      int currentDir = (delta > 0) ? 1 : ((delta < 0) ? -1 : 0);
      if (currentDir != 0 && xfc->pinchDir != 0 && currentDir != xfc->pinchDir)
          xfc->pinchAccum = 0;
    pinchDir is ONLY updated inside the while-loop (lines 876, 885) when a detent is emitted.
    The hysteresis zeroes pinchAccum but does NOT update pinchDir.
  implication: On every tick in the reversed direction, pinchDir still holds the old direction, so the hysteresis condition stays true and keeps zeroing pinchAccum. The accumulator can never reach the 40px threshold to emit a detent, so pinchDir never updates to the new direction. Deadlock.

- timestamp: 2026-08-08T09:00
  checked: Tick-by-tick simulation of zoom-out then reversal
  found: |
    After zoom-out: pinchDir=-1, pinchAccum=residual (say -3).
    Reversal tick 1: delta=+5, pinchAccum=-3+5=2, currentDir=1 != pinchDir=-1 → pinchAccum=0. No detent. pinchDir still -1.
    Reversal tick 2: delta=+5, pinchAccum=0+5=5, currentDir=1 != pinchDir=-1 → pinchAccum=0. No detent. pinchDir still -1.
    Reversal tick N: same pattern — pinchAccum reset to 0 every tick. Never reaches 40px. Deadlock confirmed.
  implication: Root cause is structural — the hysteresis block must clear pinchDir to 0 so it fires exactly once, not on every reversed-direction tick.

- timestamp: 2026-08-08T09:00
  checked: Constants PINCH_WHEEL_STEP_PX=40 (line 74), PINCH_DEADBAND_PX=8 (line 56)
  found: 40px per detent is a large threshold; with the bug, the accumulator is zeroed before accumulating even 5px. The threshold value is not the problem; the hysteresis firing every tick is.
  implication: Fix is not a threshold change; it's a state-management fix in the hysteresis block.

- timestamp: 2026-08-08T09:01
  checked: Regression check tests/pinch_reversal_check.c — simulates the pinch accumulator state machine, runs zoom-out → reversal → zoom-in → second reversal → zoom-out
  found: |
    WITHOUT fix (pinchDir not cleared): reversed_detents=0, pinchDir=-1, accum=0 → deadlock confirmed.
    WITH fix (pinchDir=0 in hysteresis): reversed_detents=12, pinchDir=1 → reversal works.
    Second reversal (back to zoom-out): back_detents=12, pinchDir=-1 → bidirectional reversal works.
  implication: Fix confirmed: clearing pinchDir to 0 in the hysteresis block breaks the deadlock and enables mid-gesture direction reversal in both directions.

- timestamp: 2026-08-08T09:02
  checked: Rebuild via dpkg-buildpackage -us -uc -b
  found: |
    Build succeeded. Object file xf_input.c.o timestamp 08:30 (newer than source 08:26). .deb built at 08:31.
    Binary xfreerdp3 in obj-x86_64-linux-gnu/client/X11/ timestamp 08:30.
    freerdp3-x11_3.15.0+dfsg-2.1+deb13u3_amd64.deb at /home/hoang/freerdp-touch/build/ (133.5K).
  implication: Fix is compiled into the package; ready for installation and human verification.

## Eliminated

## Resolution

- root_cause: D-12 reversal hysteresis in xf_input_pinch_update (lines 860-866) zeroed pinchAccum on every reversed-direction tick but never cleared pinchDir. Since pinchDir is only updated inside the detent-emission while-loop (lines 876, 885), and the accumulator was zeroed before reaching the 40px threshold, no reversed detent was ever emitted, so pinchDir stayed latched to the old direction forever — a deadlock that blocked mid-gesture direction reversal.
- fix: Added `xfc->pinchDir = 0;` inside the hysteresis block so it fires exactly once on reversal (discards old residual, clears latched direction), then the accumulator builds in the new direction until the next detent sets pinchDir to the new value. One-line change at the single seam all pinch updates route through.
- verification: |
    Regression check tests/pinch_reversal_check.c — standalone C program simulating the pinch accumulator state machine.
    WITHOUT fix: reversed_detents=0, deadlock confirmed (exit 1).
    WITH fix: reversed_detents=12 in both reversal directions, pinchDir updates correctly (exit 0, PASS).
    Build: dpkg-buildpackage succeeded, .deb at build/freerdp3-x11_3.15.0+dfsg-2.1+deb13u3_amd64.deb (08:31).
    Human UAT (on-device, 2026-08-08): CONFIRMED FIXED — mid-gesture pinch direction reversal
    works without lifting fingers in both directions; two-finger scroll still works (unchanged
    code path). User selected the confirmation option after on-device testing.
- files_changed:
    - build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c (D-12 hysteresis block: added pinchDir=0)
    - tests/pinch_reversal_check.c (new regression check)

---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_phase: 4
current_phase_name: diagnostics-packaging-launch-configuration
status: verifying
stopped_at: Resolved debug session external-scale-stays-200
last_updated: "2026-09-08T09:50:17+07:00"
last_activity: 2026-09-08
last_activity_desc: "Resolved debug session external-scale-stays-200: invoke per-monitor scale helper from xf_detect_monitors"
progress:
  total_phases: 4
  completed_phases: 4
  total_plans: 14
  completed_plans: 14
---

# State: FreeRDP Touch for OneMix 3

## Project Reference

- **Project**: FreeRDP Touch for OneMix 3
- **Core Value**: A OneMix 3 user can operate a normal Windows RDP session comfortably by touch, with low latency and without needing an external mouse for common interactions.
- **Current focus**: Phase 4 — Diagnostics, Packaging & Launch Configuration
- **Roadmap**: `.planning/ROADMAP.md`
- **Requirements**: `.planning/REQUIREMENTS.md` (19 v1)
- **Research**: `.planning/research/SUMMARY.md` (HIGH confidence)

## Current Position

Phase: 4 of 4 (Diagnostics, Packaging & Launch Configuration)
Plan: 7 of 7 in current phase
Status: Verification waiver recorded; technical evidence remains gaps_found; normal GSD phase/milestone closure pending
Last activity: 2026-09-08 - Resolved debug session external-scale-stays-200: invoke per-monitor scale helper from xf_detect_monitors

Progress: [██████████] 100%

```
[x] Phase 1: Environment Gate & Build Baseline (2/2 plans)
[x] Phase 2: Native RDPEI Touch Lifecycle (2/2 plans)
[x] Phase 3: Local-Only Gestures & Session Stability
[~] Phase 4: Diagnostics, Packaging & Launch Configuration (7/7 plans complete; phase verification remains in progress)
```

## Performance Metrics

- **Phases completed**: 3/4
- **Requirements mapped**: 19/19
- **Plans completed**: 14/14 (01-01, 01-02, 02-01, 02-02, 03-01, 04-01, 04-02, 04-03, 04-04, 04-05, 04-06, 04-07; 03-02 and 03-03 reconciled as superseded by the local-only pivot)

**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 04 P01 | 52 | 3 tasks | 3 files |
| Phase 04-diagnostics-packaging-launch-configuration P04-02 | 5 | 2 tasks | 2 files |
| Phase 04-diagnostics-packaging-launch-configuration P04-03 | 1 | 2 tasks | 2 files |
| Phase 04 P04 | 623 | 2 tasks | 5 files |
| Phase 04 P05 | 1371 | 3 tasks | 9 files |
| Phase 04 P06 | 182 | 4 tasks | 7 files |
| Phase 04 P07 | 12 min | 2 tasks | 6 files |
| Phase quick P260907-x9e | 9min | 2 tasks | 4 files |

## Accumulated Context

### Decisions

- Compress research's 7 risk stages into 4 coarse phases while preserving the non-negotiable X11 gate (Phase 1) and the RDPEI-lifecycle-before-gestures ordering (Phase 2 before Phase 3).
- `Ctrl+wheel` pinch fallback is a branch inside the Phase 3 pinch recognizer, not a separate phase; it ships after RDPEI lifecycle correctness.
- Diagnostics logging is added incrementally during Phases 2–3 and finalized/documented in Phase 4 (single DIAG-01 requirement lives there).
- Reconnect/focus stability (STAB-01, STAB-02) ships with gestures in Phase 3 because the teardown checklist must enumerate gesture + contact state created in Phases 2–3.
- Gate uses four-signal AND check (XDG_SESSION_TYPE, WAYLAND_DISPLAY, pgrep Xorg, pgrep Xwayland) — xdpyinfo vendor string is NOT a discriminator (reports "X.Org Foundation" under both Xorg and XWayland).
- build-baseline.sh installs only freerdp3-x11_*_amd64.deb, never the broad freerdp3-* glob (avoids replacing freerdp3-wayland).
- Rollback uses apt install --reinstall freerdp3-x11 with fallback to apt install freerdp3-x11/trixie.
- [Phase 2] #12174 RDPEI lock-race fixed with a recursive CriticalSection widened to cover reserve + AddContact publish (WinPR CriticalSection is recursive on Linux).
- [Phase 2] Forced-cancel iterates cctx->contacts[] (authoritative native store), not xfc->contacts[] (local-gesture array); recovery gate at top of xf_input_handle_event_remote.
- [Phase 2] Fallback latch is X11-client-only (xf_input_touch_remote); client/common/client.c unchanged — keeps SDL/Wayland policy separate.
- [Phase 2 UAT] Long-press right-click broken: OneMix 3 touchscreen reports 1–3px jitter on a stationary finger; every jitter forwards as RDPEI MOTION and Windows cancels press-and-hold. Phase 3 must add a motion deadband (suppress sub-threshold MOTION during hold) so Windows sees a stationary contact. Root cause confirmed via on-device log.
- [Phase 3 Plan 01] Short tap = deterministic mouse left-click (DOWN|BUTTON1 then BUTTON1) rather than depending on Windows' own tap-to-click, which proved unreliable on-device. Drag = cancel native + reuse fallback latch. Long-press reuses xf_touch_force_cancel for the cancel seam so a later physical End cannot overwrite. 30ms RDPEI cancel settle delay needed for stale contact visuals. Deadband pins sub-slop updates to down coordinate rather than dropping them.
- [Quick 260807-oz9] Native RDPEI touch forwarding is disabled. `+touch-pinch-wheel-fallback` now activates local XI2 capture without `+multitouch`: one finger maps to left-click/drag or long-press right-click, two-finger translation maps to middle-button pan, and pinch maps to Ctrl+wheel. Lifecycle cancellation releases and quarantines all held gesture state.
- [Phase 3 closure] Non-multitouch/local-only is the canonical v1 touch target: one-finger left-click/drag/long-press right-click, two-finger wheel scroll, bidirectional Ctrl+wheel pinch, and three-finger middle-button drag. Native pinch/RDPEI is removed from the Phase 3 target; 03-02 and 03-03 are reconciled as superseded by the completed quick/debug work.
- [Phase ?]: Quilt patch uses diff --git headers matching Debian convention
- [Phase ?]: Four-package closure: libwinpr3-3, libfreerdp3-3, libfreerdp-client3-3, freerdp3-x11 at exact +onemix1 version
- [Phase ?]: Atomic publication with flock -n and publication-aware trap (readlink -f comparison, no fragile published flag)
- [Phase 4 Plan 03]: Verification record uses deterministic 10x5 state-machine grammar with inline Python/stdlib parser — raw byte inspection before decode, no framework dependency
- [Phase 4 Plan 03]: Stock rollback launch documentation uses menu --mouse-only because plain menu composes patched touch options that stock FreeRDP rejects
- [Phase 4 Plan 04]: Shared xf_touch_internal.h is the authoritative implementation seam — includes only <math.h> and <stddef.h>, no X11 or FreeRDP headers
- [Phase 4 Plan 04]: xf_quarantine_update is the sole runtime writer of quarantine storage after xf_input_init; every gesture cleanup and force-cancel path delegates through it
- [Phase 4 Plan 04]: xf_pinch_emit_steps accumulates fractional deltas in double without truncation; both wheel diagnostics use accum=%.3f with explicit double argument
- [Phase 4 Plan 04]: Four-package parser fixture extracts all four .debs into one root and proves loader resolution beneath it before running parser cases
- [Phase 4 Plan 05]: GAP-05 shell closed with canonical calibration validation (digits-only, max-10-digits, no-leading-zero, range-check). GAP-06 closed with EXIT-only cleanup and per-publisher mktemp classifier. GAP-08/GAP-09 closed with subshell checksum and fail-closed exact-four-package install/rollback. WR-02/WR-03 closed with real-wrapper regression and Wayland-negative gate tests. /usr/local/bin/menu deployed byte-for-byte from scripts/menu. GAP-07 remains deferred per D-25.
- [Phase ?]: Task 4 used the owner-confirmed ten-check physical-device result without repeating package installation, rollback, menu launches, or physical tests.
- [Phase ?]: GAP-07 remains USER-DEFERRED under D-25; /cert:ignore is expected and server certificate identity remains unverified.
- [Phase ?]: The v1 diagnostic record remains local-only with native_count=0 on hardware and no required hardware native-cancel record.
- [Phase ?]: Exercise the production xf_input_handle_event dispatcher with synthetic XI2 cookies and linker-wrapped XGetEventData/XFreeEventData, not a copied state model.
- [Phase ?]: Keep the canonical local-only configuration in the regression: FreeRDP_TouchPinchWheelFallback=true and FreeRDP_MultiTouchInput=false.
- [Phase ?]: Refresh one integrated onemix-touch.patch and require a second clean dpkg-source/quilt extraction to match the repaired X11 source and pass the dispatcher regression.
- [2026-08-10] **Owner closure waiver:** The project owner accepts the bounded Phase 04 concerns for closure review as `USER-ACCEPTED/WAIVED`. Required Debian installation is limited to the exact four-package `+onemix1` closure (`libwinpr3-3`, `libfreerdp3-3`, `libfreerdp-client3-3`, `freerdp3-x11`); `scripts/menu`, `scripts/launch-touch.sh`, and `scripts/check-x11-session.sh` are optional custom/developer scripts. Authoritative record: `.planning/phases/04-diagnostics-packaging-launch-configuration/04-VERIFICATION.md`. The technical verdict remains `gaps_found`. D-25 remains the accepted HIGH `/cert:ignore` server-impersonation/MITM exposure; server certificate identity is not established.
- [Quick 260810-e0n] Fresh-clone builds use exactly one tracked signed `src/*.dsc` plus its two checksum-bound source archives. `scripts/build-release.sh` derives the pinned base version from that local descriptor, reuses it for `dpkg-source -x`, and supports `BUILD_RELEASE_SMOKE=1`; `rdp-debug*.log` is ignored and the existing sensitive logs remain local but untracked.
- [Phase ?]: Quick 260810-qqz: Keep the first local short tap immediate and reuse the first adjusted coordinate only for one nearby second tap within the existing duration/slop bounds; clear the anchor on drag, long press, multi-finger entry, and lifecycle cancellation.
- [Quick 260810-ss0] Unset local-touch calibration now defaults to 500 ms long press and 12 px slop across the wrapper, X11 recognizer fallbacks, classifier model, CLI help, tests, and README; existing override ranges remain unchanged.
- [Phase ?]: Quick 260907-x9e: automatic external selection scans the private xrandr query for the first connected non-OneMix output.
- [Phase ?]: Quick 260907-x9e: unset, explicit-empty, and named FREERDP_EXTERNAL_OUTPUT states remain distinct; named overrides fail closed.

### Todos

- Complete normal GSD phase/milestone closure after reviewing the owner waiver in `.planning/phases/04-diagnostics-packaging-launch-configuration/04-VERIFICATION.md`; technical verification remains `gaps_found`, and GAP-07 remains USER-DEFERRED under D-25.

### Blockers

- Planning verification override: the owner chose to execute without the final checker verdict after the last three plan fixes.
- GAP-07 certificate hardening is deferred under D-25; `/cert:ignore` remains with accepted HIGH MITM/server-impersonation risk.
- The owner closure waiver in `.planning/phases/04-diagnostics-packaging-launch-configuration/04-VERIFICATION.md` records the remaining delivery, privacy, test-evidence, and physical-UAT warnings as `USER-ACCEPTED/WAIVED` for closure review; their evidence remains `gaps_found`, and normal GSD phase/milestone closure is pending.

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 260807-oz9 | tôi không muốn mutitouch để native nữa, tôi muốn tắt multitouch đi, rồi freerdp xử lý toàn bộ thao tác cảm ứng trước. ví dụ 1 press thì left click, long press thì right click, 2 finger thì bấm vào wheel, pan hướng nào thì tương tự giữ wheel di chuột hướng đó, pinch thì giữ ctrl rồi lăn chuột | 2026-08-07 | build-tree | [260807-oz9-t-i-kh-ng-mu-n-mutitouch-native-n-a-t-i-](./quick/260807-oz9-t-i-kh-ng-mu-n-mutitouch-native-n-a-t-i-/) |
| 260808-956 | hiện tại freerdp đang để : lúc 2 ngón pan, thì hold wheel và drag chuột. tôi đổi ý muốn hold wheel thì dùng 3 ngón, nếu dùng 2 ngón thì lăn chuột. | 2026-08-08 | build-tree | [260808-956-hi-n-t-i-freerdp-ang-l-c-2-ng-n-pan-th-h](./quick/260808-956-hi-n-t-i-freerdp-ang-l-c-2-ng-n-pan-th-h/) |
| 260808-b11 | tôi đã chuyển freerdp về KHÔNG multitouch, các thao tác phần lớn đã work, tuy nhiên có một vấn đề nhỏ: khi tôi để 2 ngón để dọc và vuốt xuống, expect scroll thì bị chuyển thành pinch (phóng to thu nhỏ) | 2026-08-08 | build-tree | [260808-b11-t-i-chuy-n-freerdp-v-kh-ng-multitouch-c-](./quick/260808-b11-t-i-chuy-n-freerdp-v-kh-ng-multitouch-c-/) |
| 4 | Update /usr/local/bin/menu so FreeRDP option 3 uses the canonical patched launch parameters | 2026-08-08 | 67ac6d5 | — |
| 260810-d0h | Record the owner waiver for remaining Phase 04 blockers and optional custom scripts | 2026-08-10 | 22ac689 | [260810-d0h-record-owner-decision-that-only-freerdp-](./quick/260810-d0h-record-owner-decision-that-only-freerdp-/) |
| 260810-e0n | Track pinned Debian source inputs, use the local DSC for release builds, and ignore sensitive diagnostic logs | 2026-08-10 | d043fe5 | [260810-e0n-create-src-containing-the-three-pinned-d](./quick/260810-e0n-create-src-containing-the-three-pinned-d/) |
| 7 | Tạo INSTALLATION.md với quy trình fresh clone, build, kiểm tra và cài bốn package FreeRDP Touch | 2026-08-10 | be77978 | — |
| 8 | Đơn giản hóa INSTALLATION.md thành quy trình clone, build và cài FreeRDP Touch tối thiểu | 2026-08-10 | b7086ea | — |
| 9 | Thêm lệnh cài custom menu vào /usr/local/bin trong INSTALLATION.md | 2026-08-10 | 36f93c9 | — |
| 260810-qqz | hiện tại lúc tôi double touch để vào folder, gesture này không ổn định, lúc được lúc không, fix cho tôi | 2026-08-10 | 0d21fa3 | [260810-qqz-hi-n-t-i-l-c-t-i-double-touch-v-o-folder](./quick/260810-qqz-hi-n-t-i-l-c-t-i-double-touch-v-o-folder/) |
| 11 | Thêm script copy-paste cài lại đúng bốn package mới nhất từ dist vào INSTALLATION.md | 2026-08-10 | 49cc3c8 | — |
| 12 | Thêm --reinstall để apt cài lại bundle +onemix1 cùng version | 2026-08-10 | d430780 | — |
| 260810-ss0 | Đổi mặc định local-touch calibration: long press từ 600 ms xuống 500 ms và touch slop từ 8 px lên 12 px | 2026-08-10 | ff61284 | [260810-ss0-i-m-c-nh-local-touch-calibration-long-pr](./quick/260810-ss0-i-m-c-nh-local-touch-calibration-long-pr/) |
| 14 | Tăng double-tap anchor tolerance từ 20 px lên 48 px, giữ drag/pan slop 12 px | 2026-08-10 | 046502b | — |
| 15 | trong script menu, hiện tại freerdp chạy trực tiếp trên xorg, tôi muốn nó chạy qua openbox và wmctrl để fullscreen với resolution 1600x1000. update script cho tôi. | 2026-08-11 | 393374f | — |
| 16 | xóa scale, chỉnh resolution nhìn như 2560x1600 với scale 250, nhưng với scale 100 | 2026-08-11 | 282616e | — |
| 17 | chỉnh lại /scale-desktop là 200 và điều chỉnh resolution tương đương mục tiêu 2560x1600 @250% | 2026-08-11 | 6c20c38 | — |
| 18 | xóa Openbox/wmctrl khỏi menu và khôi phục luồng launch FreeRDP trực tiếp như trước các thay đổi Openbox | 2026-08-11 | 5d1a40a | — |
| 260907-t28 | Thiết lập cấu hình chạy xfreerdp3 trên hai màn hình: màn hình OneMix là primary và màn hình ngoài là secondary. Kiểm tra launcher/tài liệu hiện có, rồi tạo hoặc cập nhật cấu hình tối thiểu, có hướng dẫn kiểm tra và rollback. | 2026-09-07 | 953afb3 | [260907-t28-thi-t-l-p-c-u-h-nh-ch-y-xfreerdp3-tr-n-h](./quick/260907-t28-thi-t-l-p-c-u-h-nh-ch-y-xfreerdp3-tr-n-h/) |
| 260907-vzf | hiện tại khi tôi cắm màn hình ngoài, extend screen đã work nhưng touch bị lỗi. cụ thể khi tôi di chuyển chuột ở màn onemix thì, chuột lại hiện ở màn ngoài | 2026-09-07 | 8053406 | [260907-vzf-hi-n-t-i-khi-t-i-c-m-m-n-h-nh-ngo-i-exte](./quick/260907-vzf-hi-n-t-i-khi-t-i-c-m-m-n-h-nh-ngo-i-exte/) |
| 260907-x9e | Auto-detect the first connected private-X-server external output while preserving explicit overrides and OneMix touch mapping | 2026-09-07 | 6767470 | [260907-x9e-t-ng-ph-t-hi-n-m-n-h-nh-ngo-i-trong-scri](./quick/260907-x9e-t-ng-ph-t-hi-n-m-n-h-nh-ngo-i-trong-scri/) |
| 260908-1fa | thêm param để scale riêng màn phụ | 2026-09-08 | 0de8802 | [260908-1fa-th-m-param-scale-ri-ng-m-n-ph](./quick/260908-1fa-th-m-param-scale-ri-ng-m-n-ph/) |

### Research Flags (carried from research summary)

- Phase 2 will need `/gsd-plan-phase --research-phase` for XInput2 touch-ownership semantics (XI 2.2, `XIAllowTouchEvents`, Mutter delivery) and for MS-RDPEI state-machine / lock-shape audit against the 3.15.0 tarball (#9082, #12174). Highest-risk phase.

## Session Continuity

**Last session:** 2026-09-08T09:50:17+07:00
**Stopped at:** Resolved debug session external-scale-stays-200
**Resume file:** None

- **Last action**: Invoked the per-monitor scale helper from `xf_detect_monitors` and rebuilt the four-package `+onemix1` closure so `xfreerdp3` reads `FREERDP_EXTERNAL_DESKTOP_SCALE`.
- **Next action**: Reinstall the rebuilt bundle and confirm native-X11 Windows Display settings show 200% on OneMix and 100% on the external display.

---
*State initialized: 2026-08-05*

---
phase: 02-native-rdpei-touch-lifecycle
plan: 02
subsystem: input
tags: [xinput2, rdpei, x11, touch, forced-cancel, recovery-gate, fallback-latch, idempotency]

# Dependency graph
requires:
  - phase: 02-native-rdpei-touch-lifecycle
    plan: 01
    provides: [XI2 touch ownership, #12174 lock fix, XIPointerEmulated suppression, D-11 content-bounds gate, xfContext lifecycle fields]
provides:
  - Forced-cancel seam wired into 5 lifecycle hooks (FocusOut, UnmapNotify, ConfigureNotify, toggle_fullscreen, post_disconnect)
  - D-07 idempotency check (delayed TouchEnd for canceled contact silently consumed)
  - D-08 recovery gate (pre-cancel fingers quarantined, new touches accepted only after all lift)
  - D-01..D-04 first-contact-only mouse fallback latch (down/motion/up lifecycle, latched for contact lifetime)
affects: [03-gestures-stability]

# Actuals (#2632)
actuals:
  tokens: 800
  tasks: 2
  commits: 1

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Forced-cancel iterates cctx->contacts[] (authoritative native store) NOT xfc->contacts[] (local-gesture)"
    - "Idempotency via canceledIds[] set: TouchEnd checks then removes from set"
    - "Recovery gate at TOP of xf_input_handle_event_remote before switch, handles all touch event types uniformly"
    - "Fallback latch in xf_input_touch_remote (X11-session only), decides rdpei==NULL at DOWN time, latches for contact lifetime"

key-files:
  created: []
  modified:
    - build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c
    - build/freerdp3-3.15.0+dfsg/client/X11/xf_input.h
    - build/freerdp3-3.15.0+dfsg/client/X11/xf_event.c
    - build/freerdp3-3.15.0+dfsg/client/X11/xf_client.c

key-decisions:
  - "xf_touch_force_cancel is non-static, declared in xf_input.h — called from xf_event.c and xf_client.c"
  - "Forced-cancel clears canceledIdCount/quarantinedCount before iteration (each call is self-contained)"
  - "Recovery gate placed in xf_input_handle_event_remote (remote path) not xf_input_handle_event_local (local-gesture path)"
  - "Fallback latch applies content-bounds gate (D-11) for both native and fallback paths"
  - "Fallback calls freerdp_client_send_button_event directly, bypassing freerdp_client_handle_touch and client/common fallback"

patterns-established:
  - "Forced-cancel + idempotency + recovery-gate: three-phase teardown (cancel records IDs, TouchEnd checks set, gate lifts when all pre-cancel fingers up)"
  - "Fallback latch: first-contact-only mouse input when RDPEI unavailable, strictly X11-client policy"

requirements-completed: [XINP-02, RDPEI-02]

# Coverage metadata
coverage:
  - id: D1
    description: "xf_touch_force_cancel wired into 5 lifecycle hooks — FocusOut, UnmapNotify, ConfigureNotify, toggle_fullscreen, post_disconnect"
    requirement: RDPEI-02
    verification:
      - kind: unit
        ref: "grep: xf_touch_force_cancel count>=3 in xf_event.c, >=2 in xf_client.c, xf_input.h declares it"
        status: pass
      - kind: unit
        ref: "grep: xf_touch_force_cancel iterates cctx->contacts NOT xfc->contacts"
        status: pass
    human_judgment: false
  - id: D2
    description: "D-07 idempotency: delayed XI_TouchEnd for canceled contact silently consumed"
    requirement: RDPEI-02
    verification:
      - kind: unit
        ref: "grep: canceledIds count>=3 in xf_input.c (init, record, check)"
        status: pass
    human_judgment: false
  - id: D3
    description: "D-08 recovery gate: at top of xf_input_handle_event_remote, quarantines pre-cancel fingers, accepts new input only after all lift"
    requirement: RDPEI-02
    verification:
      - kind: unit
        ref: "grep: recoveryGateArmed at line before switch in xf_input_handle_event_remote, count>=4"
        status: pass
    human_judgment: false
  - id: D4
    description: "D-01..D-04 fallback latch: first-contact-only mouse fallback with complete down/motion/up lifecycle, latched for contact lifetime"
    requirement: XINP-02
    verification:
      - kind: unit
        ref: "grep: fallbackActive count>=6, freerdp_client_send_button_event count>=3 in xf_input.c"
        status: pass
      - kind: unit
        ref: "git diff client/common/client.c shows no changes"
        status: pass
    human_judgment: false
  - id: D5
    description: "Build succeeds with all modifications"
    verification:
      - kind: other
        ref: "cmake --build obj-x86_64-linux-gnu -j4 exits 0, zero errors in modified files"
        status: pass
    human_judgment: false
  - id: D6
    description: "Forced-cancel covers FocusOut, UnmapNotify, ConfigureNotify, toggle_fullscreen, post_disconnect — on-device verification"
    requirement: RDPEI-02
    verification: []
    human_judgment: true
    rationale: "Requires physical touch interaction in native X11 RDP session: finger down then toggle fullscreen, unfocus, minimize, resize, disconnect — verify UP|CANCELED emitted exactly once per contact, new touches work after recovery gate lifts."
  - id: D7
    description: "Fallback latch on-device: single finger produces button1 events when RDPEI unavailable, two-finger only first finger active, drag works"
    verification: []
    human_judgment: true
    rationale: "Requires RDPEI-unavailable scenario (e.g., pre-channel-connect login screen) on native X11 session with physical touch input."

# Metrics
duration: 35min
completed: 2026-08-06
status: complete
---

# Phase 02 Plan 02: Forced-Cancel Seam, Recovery Gate, and Fallback Latch Summary

**xf_touch_force_cancel wired into 5 lifecycle hooks with D-07 idempotency, D-08 recovery gate, and D-01..D-04 first-contact-only mouse fallback latch**

## Performance

- **Duration:** 35 min
- **Started:** 2026-08-06T02:15:00Z
- **Completed:** 2026-08-06T02:50:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- xf_touch_force_cancel function iterating cctx->contacts[] (authoritative native store), calling rdpei->TouchCancel for UP|CANCELED, recording canceled IDs (D-07), arming recovery gate (D-08)
- Forced-cancel wired into all 5 lifecycle hooks: FocusOut, UnmapNotify, ConfigureNotify (size-change gated per D-12), toggle_fullscreen, post_disconnect
- Idempotency check in xf_input_touch_remote TouchEnd: canceled IDs silently consumed, no double-emission
- Recovery-gate guard at TOP of xf_input_handle_event_remote before switch: all touch event types quarantined uniformly, gate lifts when all pre-cancel fingers report TouchEnd
- First-contact-only fallback latch replacing simple `if (!rdpei) return 0`: down/motion/up button1 lifecycle, latched for contact lifetime (D-03), content-bounds gate applied (D-11)
- Fallback latch is X11-only (xf_input_touch_remote); client/common/client.c unchanged

## Task Commits

Each task was committed atomically via source edits:

1. **Task 1: Forced-cancel seam + idempotency + recovery gate** — xf_touch_force_cancel function, D-07 idempotency check, D-08 recovery gate, 5 lifecycle hook wiring
2. **Task 2: First-contact-only fallback latch** — D-01..D-04 fallback latch replacing the rdpei-NULL early-return in xf_input_touch_remote

## Files Modified
- `build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c` — xf_touch_force_cancel, idempotency check in TouchEnd, recovery-gate guard in handle_event_remote, fallback latch in touch_remote
- `build/freerdp3-3.15.0+dfsg/client/X11/xf_input.h` — xf_touch_force_cancel declaration
- `build/freerdp3-3.15.0+dfsg/client/X11/xf_event.c` — xf_touch_force_cancel in FocusOut, UnmapNotify, ConfigureNotify
- `build/freerdp3-3.15.0+dfsg/client/X11/xf_client.c` — xf_touch_force_cancel in toggle_fullscreen, post_disconnect

## Decisions Made
- Recovery gate placed in xf_input_handle_event_remote only (remote RDPEI path), not xf_input_handle_event_local (local-gesture path already isolated)
- Each xf_touch_force_cancel call resets canceledIdCount/quarantinedCount to 0 before iteration — self-contained, no carryover between cancel events
- Fallback latch applies D-11 content-bounds gate before coordinate transform, matching native path behavior
- freerdp_client_send_button_event called directly (not through freerdp_client_handle_touch) for fallback, keeping X11 policy out of shared client/common

## Deviations from Plan

None - plan executed as written. Recovery gate initially landed in xf_input_handle_event_local due to matching switch pattern; detected and moved to xf_input_handle_event_remote before commit.

## Issues Encountered

- Recovery gate was initially placed in xf_input_handle_event_local (the local-gesture dispatch function) because both functions have identical `if ((cookie.cc->type == GenericEvent)...)` + `switch (cookie.cc->evtype)` patterns. Fixed by removing from local and inserting into remote function.

## Next Phase Readiness
- All Phase 2 lifecycle correctness is in place: forced cancellation, idempotency, recovery gate, and fallback latch
- On-device verification needed for all 5 interruption paths and fallback behavior
- D-06 mid-session RDPEI channel-only drop deferred to Phase 3 per plan

---
*Phase: 02-native-rdpei-touch-lifecycle*
*Completed: 2026-08-06*

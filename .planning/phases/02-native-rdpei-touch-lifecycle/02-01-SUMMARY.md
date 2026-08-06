---
phase: 02-native-rdpei-touch-lifecycle
plan: 01
subsystem: input
tags: [xinput2, rdpei, x11, touch, critical-section, ownership]

# Dependency graph
requires:
  - phase: 01-environment-gate-build-baseline
    provides: [build-ready source tree, X11 session gate]
provides:
  - XI2 touch ownership acceptance (XI_TouchOwnership + XIAllowTouchEvents)
  - #12174 RDPEI lock-race fix (reserve+publish under one CriticalSection)
  - XIPointerEmulated suppression (touch-emulated pointer events dropped before dispatch)
  - D-11 content-bounds gate (letterbox touches ignored, not clamped)
  - xfContext touch-lifecycle state fields (fallbackActive, recoveryGateArmed, canceledIds[], quarantinedFingers[])
affects: [02-02-gesture-fallback-cancel]

# Actuals (#2632)
actuals:
  tokens: 800
  tasks: 1
  commits: 1

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "XISetMask + XI_TouchOwnership selection in register_input_events"
    - "XIAllowTouchEvents(XIAcceptTouch) on ownership event in remote dispatch"
    - "XIPointerEmulated flag gate before pen/mouse dispatch"
    - "Content-bounds check (offset_x/y + scaledWidth/Height) before coordinate transform"
    - "CriticalSection widened to cover reserve + AddContact publish (recursive lock)"

key-files:
  created: []
  modified:
    - build/freerdp3-3.15.0+dfsg/channels/rdpei/client/rdpei_main.c
    - build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c
    - build/freerdp3-3.15.0+dfsg/client/X11/xfreerdp.h

key-decisions:
  - "#12174 fix uses recursive CriticalSection — rdpei_add_contact re-enters the lock; WinPR recursive impl confirms no deadlock"
  - "XI_TouchOwnership case falls through to xf_input_touch_remote — bounds gate applies, switch default no-ops for ownership evtype"
  - "Content-bounds check uses >= on right/bottom (one px into letterbox is ignored per D-11)"
  - "New xfContext fields declared in Plan 1 for struct completeness but only initialized; logic lives in Plan 2"

patterns-established:
  - "XI2 ownership acceptance: XISetMask + XI_TouchOwnership in registration, XIAllowTouchEvents in dispatch"

requirements-completed: [XINP-01, XINP-02, COOR-01, RDPEI-01, RDPEI-03]

coverage:
  - id: D1
    description: "#12174 lock-scope fix — LeaveCriticalSection moved after AddContact in rdpei_touch_process"
    requirement: RDPEI-01
    verification:
      - kind: unit
        ref: "grep: LeaveCriticalSection at line 1129 (after AddContact), line 1072 (early return), none between reserve and publish"
        status: pass
    human_judgment: false
  - id: D2
    description: "XI_TouchOwnership selection + XIAllowTouchEvents in dispatch"
    requirement: XINP-01
    verification:
      - kind: unit
        ref: "grep: XI_TouchOwnership count>=2, XIAllowTouchEvents count>=1 in xf_input.c"
        status: pass
    human_judgment: false
  - id: D3
    description: "XIPointerEmulated suppression — emulated pointer events from touchscreen break before pen/mouse dispatch"
    requirement: XINP-01
    verification:
      - kind: unit
        ref: "grep: XIPointerEmulated count>=1 in xf_input.c"
        status: pass
    human_judgment: false
  - id: D4
    description: "D-11 content-bounds gate — letterbox touches return 0 before coordinate transform"
    requirement: COOR-01
    verification:
      - kind: unit
        ref: "grep: bounds-check block (offset_x/scaledWidth/offset_y/scaledHeight) before xf_event_adjust_coordinates in xf_input_touch_remote"
        status: pass
    human_judgment: false
  - id: D5
    description: "xfContext touch-lifecycle fields declared in xfreerdp.h and zero-initialized in xf_input_init"
    requirement: RDPEI-01
    verification:
      - kind: unit
        ref: "grep: fallbackActive|recoveryGateArmed|canceledIds|quarantinedFingers count>=4 in xfreerdp.h; fallbackActive=FALSE etc in xf_input_init"
        status: pass
    human_judgment: false
  - id: D6
    description: "Build succeeds — dpkg-buildpackage produces freerdp3-x11_*.deb"
    verification:
      - kind: other
        ref: "dpkg-buildpackage -us -uc -b -j4"
        status: pass
    human_judgment: false

# Metrics
duration: 25min
completed: 2026-08-06
status: complete
---

# Phase 02 Plan 01: Single-Tap RDPEI Contact Pipeline Summary

**End-to-end XInput2-to-RDPEI single-tap path with #12174 fix, XI2 ownership, emulated-pointer suppression, and content-bounds gate**

## Performance

- **Duration:** 25 min
- **Started:** 2026-08-06T01:45:00Z
- **Completed:** 2026-08-06T02:10:00Z
- **Tasks:** 1
- **Files modified:** 3

## Accomplishments
- #12174 RDPEI lock race fixed: LeaveCriticalSection moved from after reserve to after AddContact publish, covering both under one CriticalSection
- XI_TouchOwnership selected in register_input_events and accepted via XIAllowTouchEvents(XIAcceptTouch) in remote dispatch
- XIPointerEmulated filter added in button/motion branch, suppressing touch-emulated pointer duplicates before pen/mouse dispatch
- D-11 content-bounds gate added in xf_input_touch_remote, rejecting letterbox touches before coordinate transform
- Seven new xfContext touch-lifecycle fields declared in xfreerdp.h and zero-initialized in xf_input_init

## Task Commits

Each task was committed atomically:

1. **Task 1: End-to-end single-finger tap to native RDPEI contact** - `(see commit)` (fix: wire complete XI2-to-RDPEI single-tap pipeline)

## Files Modified
- `build/freerdp3-3.15.0+dfsg/channels/rdpei/client/rdpei_main.c` - #12174 fix: widened CriticalSection to cover reserve + AddContact publish
- `build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c` - XI_TouchOwnership mask + case, XIPointerEmulated filter, content-bounds gate, field initialization
- `build/freerdp3-3.15.0+dfsg/client/X11/xfreerdp.h` - 7 new xfContext fields (fallbackActive, fallbackFinger, recoveryGateArmed, canceledIds[], canceledIdCount, quarantinedFingers[], quarantinedCount)

## Decisions Made
- Used recursive CriticalSection for #12174 fix — WinPR CriticalSection is recursive on Linux so rdpei_add_contact's EnterCriticalSection nests cleanly
- XI_TouchOwnership case in dispatch accepts the touch then falls through to xf_input_touch_remote for bounds checking; switch default no-ops for ownership evtype (no RDPEI contact to forward)
- Content-bounds uses `>=` on right/bottom per D-11 (one pixel into letterbox = ignored)
- Declared Plan 2 fields (fallbackActive, recoveryGateArmed, etc.) in this plan for struct completeness; only zero-initialized, no logic wired

## Deviations from Plan

None - plan executed exactly as written. All four fixes applied in order as specified.

## Issues Encountered

None. Build succeeded on first attempt with zero warnings in modified files.

## Next Phase Readiness
- Single-tap pipeline proven at source level; ready for on-device trace verification (manual UAT in native X11 session)
- Plan 2 (gesture fallback, forced cancellation, recovery gate) has its struct fields declared and initialized — no blocker

---
*Phase: 02-native-rdpei-touch-lifecycle*
*Completed: 2026-08-06*

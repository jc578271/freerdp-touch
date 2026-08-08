---
phase: 03-gestures-session-stability
plan: 02
subsystem: local-touch-gestures
tags: [xinput2, local-only, non-multitouch, scroll, pinch, middle-button]
requires: [03-01]
provides:
  - local-only two-finger wheel scroll
  - bidirectional Ctrl+wheel pinch
  - three-finger middle-button drag
  - pinch-vs-scroll dominance disambiguation
affects: [GEST-03, GEST-04]
key-files:
  modified:
    - build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c
    - build/freerdp3-3.15.0+dfsg/client/X11/xfreerdp.h
requirements-completed: [GEST-03, GEST-04]
superseded: true
actuals:
  tasks: 4
  commits: 0
completed: 2026-08-08
status: complete
---

# Phase 3 Plan 02 Summary: Local-Only Two/Three-Finger Gestures

The original native-pinch/fallback split was superseded by the user-directed non-multitouch pivot. Native RDPEI forwarding is disabled for the canonical v1 touch mode; all active touch gestures are recognized locally in the X11 client.

## Delivered Behavior

- One finger remains owned by the local click/drag/long-press recognizer from 03-01.
- Two-finger translation emits wheel scroll at the touched midpoint.
- Two-finger distance change emits `Ctrl`+wheel pinch.
- Pinch can reverse zoom direction without lifting the fingers.
- Three-finger translation performs middle-button drag using the three-finger centroid.
- No local gesture forwards native RDPEI contacts.

## Superseding Work

- **Quick 260807-oz9:** disabled native RDPEI forwarding and established the local-only gesture path.
- **Quick 260808-956:** mapped two-finger translation to wheel scroll and three-finger translation to middle-button drag.
- **Quick 260808-b11:** added the `PINCH_DOMINANCE_RATIO 2.5` guard so axial two-finger scrolling is not misclassified as pinch.
- **Debug `pinch-direction-reversal`:** cleared `pinchDir` once when direction changes, fixing the accumulator deadlock that previously required lifting the fingers before reversing zoom.
- **Debug `two-finger-left-click-held`:** prevented emulated left-button leakage and moved the remote pointer to the two-finger midpoint before wheel scrolling.

## Verification

- Standalone pinch/scroll classification regression checks pass.
- Bidirectional pinch reversal regression check passes.
- `xfreerdp3` and the Debian package build successfully.
- On-device local-only UAT passes: two-finger scroll, pinch zoom in/out with mid-gesture reversal, and three-finger middle-button drag all work.
- The user confirmed all non-multitouch/local-only behavior is working.

## Plan Reconciliation

`03-02-PLAN.md` was not executed verbatim because its native-mode assumptions were intentionally removed. This summary closes the plan against the replacement local-only implementation and the completed quick/debug evidence.

Source changes remain in the gitignored `build/` tree per project convention; no source commit is attributed to this plan.

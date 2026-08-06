# Phase 2: Native RDPEI Touch Lifecycle - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-06
**Phase:** 2-Native RDPEI Touch Lifecycle
**Areas discussed:** RDPEI fallback, Forced cancellation, Coordinate coverage

---

## RDPEI fallback

### Behavior while RDPEI is unavailable

| Option | Description | Selected |
|--------|-------------|----------|
| One-finger mouse | Keep the device usable at login/channel startup: the first finger becomes left-mouse input, while native RDPEI resumes for later touches once available. | ✓ |
| Ignore touch | Enforce native-only semantics; touch does nothing until RDPEI is available, so another pointer may be required. | |
| Current broad fallback | Preserve FreeRDP's existing behavior where every touch contact can emit mouse events; smallest change, but multi-finger input can conflict. | |

**User's choice:** One-finger mouse
**Notes:** Preserve basic usability without retaining broad multi-contact mouse conversion.

### Additional fingers during fallback

| Option | Description | Selected |
|--------|-------------|----------|
| Ignore extras | Keep the first finger's tap or drag stable; all additional contacts are ignored until they lift. | ✓ |
| Cancel fallback | Release the mouse button immediately and ignore touch until every finger lifts; safer against accidental multi-touch but interrupts the current action. | |

**User's choice:** Ignore extras
**Notes:** Only the first fallback contact controls the mouse lifecycle.

### RDPEI activation during a fallback contact

| Option | Description | Selected |
|--------|-------------|----------|
| After lift | Finish that contact entirely as mouse input, then use RDPEI for the next touch; one physical contact never changes protocols midway. | ✓ |
| Cancel and restart | Release the mouse contact and begin a new native touch at the same position; faster handoff but Windows sees two separate actions. | |
| Switch immediately | Continue the same physical contact through RDPEI; lowest delay, but mixes unrelated mouse and touch lifecycles. | |

**User's choice:** After lift
**Notes:** Protocol choice is latched for the physical contact lifetime.

### Supported fallback actions

| Option | Description | Selected |
|--------|-------------|----------|
| Tap and drag | Down, motion, and up map to a normal left-button lifecycle, preserving basic login and desktop usability. | ✓ |
| Tap only | Emit a click only after finger lift and ignore movement; simpler semantics, but no dragging or press-and-hold behavior. | |

**User's choice:** Tap and drag
**Notes:** Fallback must provide a complete left-button lifecycle.

---

## Forced cancellation

### Remote terminal semantics

| Option | Description | Selected |
|--------|-------------|----------|
| RDPEI cancel | Send `UP | CANCELED` so Windows abandons the in-progress action instead of turning it into a click or drop. | ✓ |
| Normal lift | Send an ordinary `UP` at the last position, completing the action as though the finger lifted normally. | |
| Depends on trigger | Choose cancellation for disruptive events and normal lift for selected transitions such as fullscreen. | |

**User's choice:** RDPEI cancel
**Notes:** Forced interruption means abort, distinct from a physical finger lift.

### Cancellation triggers

| Option | Description | Selected |
|--------|-------------|----------|
| All transitions | Cancel before focus loss handling, unmap/minimize, fullscreen changes, RDPEI/channel loss, disconnect, and client shutdown. | ✓ |
| Focus and disconnect | Cancel on focus/session loss, but allow contacts to continue through fullscreen and ordinary window-state changes. | |
| Disconnect only | Limit forced cleanup to channel loss and shutdown; smallest hook surface, but focus/window transitions may leave stale contacts. | |

**User's choice:** All transitions
**Notes:** Geometry-transform changes were subsequently included in the same cancel-first policy.

### Delayed terminal events

| Option | Description | Selected |
|--------|-------------|----------|
| Ignore it | Treat forced cancellation as final and make cleanup idempotent; never emit a second RDPEI end for the same touch ID. | ✓ |
| Send another cancel | Repeat cancellation defensively; remote state is reinforced, but duplicate terminal events may violate the lifecycle. | |
| Send normal lift | Follow the later physical event even after cancellation; this can turn one contact into two terminal actions. | |

**User's choice:** Ignore it
**Notes:** A contact has exactly one terminal remote event.

### Recovery after cancellation

| Option | Description | Selected |
|--------|-------------|----------|
| After all lift | Ignore events from fingers that were already down; resume only after those physical contacts lift, preventing a held finger from reappearing mid-gesture. | ✓ |
| On focus return | Recreate still-held fingers as new contacts as soon as the window/session is ready; faster recovery but can cause jumps or unintended presses. | |
| Next begin event | Clear state immediately and trust X11's next `XI_TouchBegin`; simple, but behavior depends on event ordering after transitions. | |

**User's choice:** After all lift
**Notes:** Pre-cancellation fingers are quarantined until every one physically lifts.

---

## Coordinate coverage

### Orientation acceptance target

| Option | Description | Selected |
|--------|-------------|----------|
| Current rotation | Guarantee the captured daily-use setup: left rotation producing a 2560x1600 desktop; other rotations remain unclaimed for v1. | ✓ |
| Both landscapes | Verify left and right rotation so the convertible can be used in either landscape direction. | |
| All four rotations | Verify normal, left, right, and inverted orientations; widest promise and largest on-device test matrix. | |

**User's choice:** Current rotation
**Notes:** Phase 2 optimizes for the verified daily-use setup rather than expanding the rotation matrix.

### Windowed resizing

| Option | Description | Selected |
|--------|-------------|----------|
| Live resize | Coordinates remain correct after ordinary in-session window resizes; existing `ConfigureNotify` scaling is the natural integration point. | ✓ |
| Launch size only | Guarantee only the initial window dimensions used by the test command; resizing afterward is unsupported in v1. | |
| Aspect-preserving only | Support resizes that retain the remote desktop aspect ratio, but not arbitrary letterboxed dimensions. | |

**User's choice:** Live resize
**Notes:** Coordinate correctness is required beyond initial launch dimensions.

### Touch outside remote content

| Option | Description | Selected |
|--------|-------------|----------|
| Ignore it | Do not create a remote contact outside the content bounds; prevents black-bar touches from becoming edge clicks. | ✓ |
| Clamp to edge | Map the touch to the nearest remote pixel, matching the existing coordinate helper but allowing accidental edge actions. | |
| Local pointer only | Move the local pointer without sending RDPEI contact data; adds a third input behavior to maintain. | |

**User's choice:** Ignore it
**Notes:** Letterbox or other non-content regions produce no remote or local pointer action.

### Geometry change during active touch

| Option | Description | Selected |
|--------|-------------|----------|
| Cancel first | Cancel all active contacts before adopting the new transform, then require every old finger to lift before new touch begins. | ✓ |
| Transform in place | Keep contacts active and map subsequent updates through the new geometry; seamless when correct, but may jump remotely. | |
| Delay geometry | Keep the old transform until all fingers lift, then apply the pending geometry change; touch stays stable but visuals and input can temporarily diverge. | |

**User's choice:** Cancel first
**Notes:** Rotation, scaling, or window-geometry changes use the same abort and recovery policy as other forced interruptions.

---

## Claude's Discretion

- Exact helper names, state representation, file split, hook ordering, log wording, and verification implementation.
- The smallest safe shared location for lifecycle cleanup, provided RDPEI's contact map and frame encoder are not duplicated.

## Deferred Ideas

None.

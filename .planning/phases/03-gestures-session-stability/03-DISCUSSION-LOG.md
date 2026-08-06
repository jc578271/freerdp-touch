# Phase 3: Gestures & Session Stability - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-06
**Phase:** 3-Gestures & Session Stability
**Areas discussed:** Scope boundary, Long-press contract, Pinch claiming, Zoom output, Gesture reset

---

## Scope Boundary: Two-Finger Scrolling

| Option | Description | Selected |
|--------|-------------|----------|
| Native passthrough | Preserve two-finger native contacts so Windows applications can scroll normally in native mode. | ✓ |
| Defer fallback scroll | Record two-finger drag → ordinary wheel scrolling as a future capability; Phase 3 fallback remains pinch → Ctrl+wheel only. | |

**User's choice:** Native passthrough.
**Notes:** Native two-finger scrolling remains within GEST-03 passthrough. No separate fallback drag-to-wheel gesture is added.

---

## Long-Press Contract

### Timing owner

| Option | Description | Selected |
|--------|-------------|----------|
| Client-timed click | Forward touch-down immediately, suppress only in-slop jitter, then synthesize one right-click at the configured threshold. | ✓ |
| Windows-native hold | Suppress jitter and let Windows recognize press-and-hold; the client threshold would not reliably control firing time. | |

**User's choice:** Client-timed click.

### Click timing

| Option | Description | Selected |
|--------|-------------|----------|
| At threshold | Open the context action as soon as 500–700 ms elapses; consume the remaining physical contact until lift. | ✓ |
| On finger lift | Mark the hold at threshold but delay the click until release. | |

**User's choice:** At threshold.

### Click position

| Option | Description | Selected |
|--------|-------------|----------|
| Initial touch point | Use the original down coordinate so hardware jitter cannot move the target. | ✓ |
| Latest touch point | Use the latest coordinate still inside the slop radius. | |

**User's choice:** Initial touch point.

### Post-trigger updates

| Option | Description | Selected |
|--------|-------------|----------|
| Consume until lift | Freeze the completed gesture and ignore all remaining updates. | ✓ |
| Forward pointer motion | Move the remote pointer without buttons while the finger remains down. | |

**User's choice:** Consume until lift.
**Notes:** Ordinary touch-down remains immediate native RDPEI; movement beyond slop before the threshold cancels long-press and continues as native drag.

---

## Pinch Claiming

### Ownership point

| Option | Description | Selected |
|--------|-------------|----------|
| On second finger | Cancel native contact handling as soon as finger two arrives, then wait for real scale movement before wheel output. | ✓ |
| After pinch threshold | Keep forwarding native contacts until distance changes enough, risking partial native gesture delivery. | |

**User's choice:** On second finger.

### Long-press precedence

| Option | Description | Selected |
|--------|-------------|----------|
| Pinch wins | Cancel the armed long-press immediately when finger two arrives. | ✓ |
| Wait for scale change | Keep long-press armed until pinch movement crosses threshold. | |

**User's choice:** Pinch wins.

### Two-finger translation in fallback mode

| Option | Description | Selected |
|--------|-------------|----------|
| No local action | Keep the gesture reserved but emit no wheel events; scrolling remains native-mode behavior. | ✓ |
| Return to native input | Hand the gesture back to RDPEI after detecting pan-like motion. | |

**User's choice:** No local action.

### First zoom output

| Option | Description | Selected |
|--------|-------------|----------|
| After a small deadband | Require deliberate separation change before the first wheel tick, filtering touchscreen jitter. | ✓ |
| From first delta | React to the first measurable distance change. | |

**User's choice:** After a small deadband.

---

## Zoom Output

### Direction

| Option | Description | Selected |
|--------|-------------|----------|
| Out zooms in | Fingers apart send Ctrl+wheel-up; fingers together send Ctrl+wheel-down. | ✓ |
| Invert direction | Fingers apart zoom out; fingers together zoom in. | |

**User's choice:** Out zooms in.

### Wheel mapping

| Option | Description | Selected |
|--------|-------------|----------|
| Fixed detents | Accumulate distance and emit one standard wheel notch per step. | ✓ |
| Accelerated bursts | Emit multiple notches for faster or larger movement. | |

**User's choice:** Fixed detents.

### Zoom center

| Option | Description | Selected |
|--------|-------------|----------|
| Pinch midpoint | Move the hidden remote pointer to the two-finger midpoint before the first wheel tick. | ✓ |
| Existing cursor | Leave the remote pointer at its prior location. | |

**User's choice:** Pinch midpoint.

### Direction reversal

| Option | Description | Selected |
|--------|-------------|----------|
| Reset on reversal | Discard a partial step and require a fresh full step before opposite-direction output. | ✓ |
| Reverse immediately | Preserve the accumulator remainder and reverse as soon as it crosses zero. | |

**User's choice:** Reset on reversal.

---

## Gesture Reset

### One finger remains after pinch

| Option | Description | Selected |
|--------|-------------|----------|
| Require all fingers up | End the gesture and ignore the remaining finger until every pinch contact lifts. | ✓ |
| Resume one-finger touch | Start a new native contact from the remaining finger. | |

**User's choice:** Require all fingers up.

### Ctrl release

| Option | Description | Selected |
|--------|-------------|----------|
| On first finger lift | Release Ctrl when contact count drops below two, while input remains blocked until all fingers lift. | ✓ |
| After all fingers lift | Keep Ctrl held until the final finger releases. | |

**User's choice:** On first finger lift.

### Third finger

| Option | Description | Selected |
|--------|-------------|----------|
| Abort and reset | Release Ctrl, stop wheel output, and require all involved fingers to lift. | ✓ |
| Ignore third finger | Continue tracking the original pair and consume the third finger. | |

**User's choice:** Abort and reset.

### Automatic reconnect

| Option | Description | Selected |
|--------|-------------|----------|
| Preserve launch mode | Keep the startup-selected native/fallback mode for the client process; discard the interrupted gesture. | ✓ |
| Reset to native | Return to native passthrough after every reconnect. | |

**User's choice:** Preserve launch mode.

---

## Claude's Discretion

- Exact state representation, helper names, timer hookup, and file split.
- Device-calibrated numeric defaults for long-press threshold/slop, pinch activation deadband, and fixed wheel-step distance within the locked behavior.
- Exact safe ordering of native cancellation, synthetic right-click, Ctrl press/release, pointer-centering motion, and wheel output.
- Test organization and diagnostic wording.

## Deferred Ideas

None. Fallback two-finger drag-to-wheel scrolling was considered and intentionally excluded; native RDPEI passthrough covers two-finger scrolling in native mode.

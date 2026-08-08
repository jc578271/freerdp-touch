# Requirements: FreeRDP Touch for OneMix 3

**Defined:** 2026-08-05
**Core Value:** A OneMix 3 user can operate a normal Windows RDP session comfortably by touch, with low latency and without needing an external mouse for common interactions.

## v1 Requirements

Requirements for the first daily-usable release. Each maps to exactly one roadmap phase.

### Environment and Baseline

- [x] **BASE-01**: Developer can run a prerequisite check that blocks implementation/testing unless the active desktop session is native X11 rather than Wayland or XWayland.
- [x] **BASE-02**: Developer can capture the installed `xfreerdp3`/Debian package version, X11 window manager, touchscreen identity and capabilities, rotation/scale settings, current launch command, and Windows target before modifying source.
- [x] **BASE-03**: Developer can build, install, launch, and roll back the unmodified Debian FreeRDP source package before applying the touch patch.

### Diagnostics

- [x] **DIAG-01**: User can enable diagnostic logging that records touch begin/update/end/cancel events, gesture decisions, and RDPEI frame submission, while normal launches keep the logging disabled.

### XInput2 Capture

- [x] **XINP-01**: A physical touch produces one input sequence in `xfreerdp3`, without a duplicate action from XInput2 pointer-emulation events.
- [x] **XINP-02**: Repeated and simultaneous touches keep stable identities for their lifetime and release those identities after end or cancellation, without dropping later touches.

### Coordinates

- [x] **COOR-01**: A touch lands at the corresponding remote desktop position in windowed and fullscreen modes and in each OneMix 3 orientation supported by the launch configuration.

### Native RDPEI Touch

- [x] **RDPEI-01**: A short tap and one-finger drag reach Windows as a complete, ordered native touch sequence from begin through updates to end.
- [x] **RDPEI-02**: Finger lift, gesture abort, focus loss, fullscreen/window transition, or disconnect cleanly ends every outstanding remote contact so no stuck or ghost touch remains.
- [x] **RDPEI-03**: Two simultaneous fingers reach Windows as two distinct native contacts without either contact being lost or merged.

### Gestures

- [x] **GEST-01**: User can hold one finger for a configurable 500–700 ms threshold to produce one right-click at that position, with no left-click emitted afterward.
- [x] **GEST-02**: Moving beyond a configurable slop distance before the threshold cancels long-press detection and continues as a local left-button drag.
- [x] **GEST-03**: With native multitouch disabled, two-finger translation emits wheel scroll and three-finger translation performs middle-button drag, without forwarding native RDPEI contacts.
- [x] **GEST-04**: With native multitouch disabled, a two-finger pinch emits `Ctrl` + wheel in either direction within the same gesture and releases `Ctrl` when the gesture ends or is interrupted.

### Session Stability

- [x] **STAB-01**: Touch remains usable without crashes, stale contacts, or duplicate events after switching between windowed/fullscreen states and after losing and regaining focus.
- [x] **STAB-02**: Disconnecting, reconnecting, or interrupting an active local gesture releases every held local button/key state and allows the next touch gesture to start cleanly.

### Packaging and Use

- [x] **PACK-01**: Developer can reproducibly build an installable Debian `.deb` from the pinned `freerdp3-x11 3.15.0+dfsg-2.1+deb13u3` source using a documented quilt patch.
- [x] **PACK-02**: User can install the patched package and restore the stock Debian package using documented, verified commands.
- [x] **CONF-01**: User can launch the patched client with a documented preset that keeps native multitouch disabled, enables the local-only gesture layer, exposes long-press/pinch calibration, and provides an explicit mouse-only escape hatch.

## v2 Requirements

Deferred until v1 is stable in daily use on the OneMix 3.

### Runtime Controls

- **MODE-01**: User can switch between native pinch and `Ctrl` + wheel pinch during a connected session without reconnecting.
- **PROF-01**: User can save per-application gesture preferences after a reliable remote-application identification method exists.

### Additional Input

- **GEST-05**: User can perform a three-finger swipe that sends `Alt+Tab` to the remote Windows session.
- **KEYS-01**: User can deliberately route Windows-key and `Alt+Tab` actions to the remote session without the Linux desktop intercepting them.
- **HOTPLUG-01**: Touch input recovers when the touchscreen is removed and re-added while an RDP session remains connected.

### Broader Support

- **DEVC-01**: A second Linux touchscreen model can use the patch through device-specific calibration rather than source changes.
- **WAYL-01**: User can obtain equivalent touch behavior from a native Wayland input path without relying on XWayland.
- **UPST-01**: Maintainer can submit the behavior as a generalized, tested FreeRDP upstream contribution.

## Out of Scope

Explicitly excluded to keep the first milestone focused.

| Feature | Reason |
|---------|--------|
| New RDP client or protocol implementation | FreeRDP already provides transport, rendering, channels, fullscreen, keyboard handling, and RDPEI. |
| Standalone `/dev/input` or `uinput` gesture daemon | It cannot send complete native RDPEI contacts and would race with the existing X11/libinput path. |
| Exact parity with Microsoft Windows App gesture algorithms | The algorithms are private, and daily usability does not require byte-for-byte behavioral parity. |
| Automatic Direct Touch/Mouse Pointer switching in v1 | RDP provides no dependable signal that the focused remote application is touch-aware, so automatic selection would guess. |
| On-screen keyboard or touch-pointer overlay | Existing Linux desktop and FreeRDP facilities cover these; they are not part of the touch transport/gesture problem. |
| Performance tuning unrelated to touch input | The milestone changes only the input path needed for the selected touchscreen behavior. |

## Traceability

Phase mapping populated during roadmap creation (2026-08-05).

| Requirement | Phase | Status |
|-------------|-------|--------|
| BASE-01 | Phase 1 | Complete |
| BASE-02 | Phase 1 | Complete |
| BASE-03 | Phase 1 | Complete |
| DIAG-01 | Phase 4 | Complete |
| XINP-01 | Phase 2 | Complete |
| XINP-02 | Phase 2 | Complete |
| COOR-01 | Phase 2 | Complete |
| RDPEI-01 | Phase 2 | Complete |
| RDPEI-02 | Phase 2 | Complete |
| RDPEI-03 | Phase 2 | Complete |
| GEST-01 | Phase 3 | Complete |
| GEST-02 | Phase 3 | Complete |
| GEST-03 | Phase 3 | Complete |
| GEST-04 | Phase 3 | Complete |
| STAB-01 | Phase 3 | Complete |
| STAB-02 | Phase 3 | Complete |
| PACK-01 | Phase 4 | Complete |
| PACK-02 | Phase 4 | Complete |
| CONF-01 | Phase 4 | Complete |

**Coverage:**

- v1 requirements: 19 total
- Mapped to phases: 19
- Unmapped: 0
- Duplicates: 0

---
*Requirements defined: 2026-08-05*
*Last updated: 2026-08-08 — Phase 3 revised to the user-directed non-multitouch/local-only target*

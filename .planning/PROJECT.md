# FreeRDP Touch for OneMix 3

## What This Is

A focused patch to the X11 client of `xfreerdp3` that makes a OneMix 3 touchscreen practical for daily Windows RDP use. It converts XInput2 touch input into native RDPEI contacts where possible, adds a small gesture layer for long-press and pinch behavior, and ships as a Debian package with a repeatable launch configuration.

The first release is for the project owner’s OneMix 3 running Debian with X11. It improves the existing FreeRDP client rather than creating a new RDP client or an external input daemon.

## Core Value

A OneMix 3 user can operate a normal Windows RDP session comfortably by touch, with low latency and without needing an external mouse for common interactions.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] A short touch and one-finger drag reach Windows as native RDPEI touch input with complete, correctly ordered contact events.
- [ ] A configurable long press in the 500–700 ms range produces a reliable right-click without also producing an unwanted left-click.
- [ ] A two-finger pinch uses native multitouch by default and can be configured to fall back to `Ctrl` + mouse wheel for applications that do not handle touch zoom well.
- [ ] The patched `xfreerdp3` remains responsive and stable during ordinary fullscreen and windowed RDP sessions on the OneMix 3.
- [ ] The project produces an installable Debian `.deb` and documents the build, install, rollback, and launch configuration.

### Out of Scope

- Full parity with Microsoft Windows App gesture behavior — its private gesture algorithms are unavailable and exact emulation is not required.
- Wayland-native input support — v1 targets the confirmed X11 path on the OneMix 3.
- General support for every Linux touchscreen — v1 is calibrated and verified on one device before generalization.
- Three-finger gestures, `Alt+Tab`, Linux/Windows key interception, and automatic Direct Touch/Mouse Pointer switching — defer until the three core gestures are dependable.
- A standalone `/dev/input` or `uinput` gesture daemon — it cannot provide the same native RDPEI path and adds another input layer.
- A new RDP client or protocol implementation — FreeRDP already provides transport, rendering, input channels, fullscreen, and keyboard-grab behavior.
- An upstream-ready FreeRDP pull request — useful later, but v1 prioritizes a maintainable patch for the Debian version currently used on the device.

## Context

- FreeRDP already implements the RDPEI channel needed to send real touch contacts to Windows. The project focuses on X11 event capture, contact lifecycle correctness, gesture interpretation, and integration with the existing client.
- The intended input flow is: OneMix 3 touchscreen → XInput2 touch events → minimal gesture recognizer → RDPEI or existing mouse/keyboard input path → Windows over RDP.
- Current FreeRDP/X11 touchscreen behavior has known reports involving missing multitouch events, unnatural long-press behavior, and incomplete touch interaction. These are implementation risks to verify against the exact Debian source version rather than assumptions.
- v1 has three core interactions: native one-finger touch/drag, long-press right-click, and two-finger pinch with a configurable `Ctrl` + wheel fallback.
- The primary success test is daily usability: common Windows interaction should feel immediate and reliable enough that an external mouse is not needed for routine use.
- Before implementation, capture the installed `xfreerdp3` version, X11 session details, XInput2 device/capability data, libinput device data, current launch command, and the Windows target environment.

## Constraints

- **Platform**: Debian on OneMix 3 under X11 — this is the only required v1 runtime.
- **Integration**: Patch the existing FreeRDP X11 client — preserve its RDP, fullscreen, keyboard, and RDPEI machinery instead of duplicating it.
- **Baseline**: Build against the FreeRDP version currently packaged/used on the device — minimizes time to a usable installation.
- **Packaging**: Produce a Debian `.deb` with a documented rollback path — the user must be able to reinstall or remove the patch safely.
- **Latency**: Gesture recognition must not add noticeable delay to ordinary touch input — long-press detection may delay only the action that requires disambiguation.
- **Calibration**: Long-press duration and pinch fallback must remain configurable — physical touchscreen timing and application behavior vary.
- **Scope**: Implement the three selected gestures before adding broader gesture or multi-device support.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Patch `xfreerdp3` directly instead of building a daemon | Lowest latency and direct access to RDPEI, fullscreen, and keyboard-grab behavior | — Pending |
| Target OneMix 3 + Debian + X11 first | A narrow hardware/runtime target makes behavior measurable and gets to daily use sooner | — Pending |
| Send one-finger interaction as native RDPEI touch | Native touch is the desired experience and preserves Windows/app touch semantics | — Pending |
| Use native multitouch pinch with configurable `Ctrl` + wheel fallback | Keeps native behavior while supporting desktop applications that only zoom through wheel shortcuts | — Pending |
| Limit v1 to one-finger touch/drag, long press, and pinch | These cover the highest-value daily interactions without prematurely building the full gesture suite | — Pending |
| Deliver a patch, Debian package, and launch configuration | Code alone is not usable enough; installation and repeatable operation are part of the product | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-08-05 after initialization*

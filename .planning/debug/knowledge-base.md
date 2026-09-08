# GSD Debug Knowledge Base

Resolved debug sessions. Used by `gsd-debugger` to surface known-pattern hypotheses at the start of new investigations.

---

## external-scale-stays-200 — Per-monitor helper never invoked, LTO dropped getenv
- **Date:** 2026-09-08
- **Error patterns:** external monitor remains 200%, FREERDP_EXTERNAL_DESKTOP_SCALE, /scale-desktop:200, /multimon, helper-only quilt hunk
- **Root cause(s):** The quilt hunk that should have called `xf_monitor_apply_scale_attributes()` from `xf_detect_monitors()` never applied; the helper remained dead code, LTO removed `getenv("FREERDP_EXTERNAL_DESKTOP_SCALE")`, and Windows received only the global 200% scale.
- **Fix:** Refresh the patch with a context-anchored helper call immediately before `freerdp_settings_set_monitor_def_array_sorted()`.
- **Files changed:** patches/onemix-touch.patch, tests/patch_application_check.sh
- **Why not caught:** `TestXfMonitorScale` called the helper directly and never asserted that `xf_detect_monitors` invoked it; quilt can report success while a zero-context hunk is skipped.
- **Recurrence guard:** `tests/patch_application_check.sh` requires both the helper definition and a production call before monitor-array storage.
---

## menu-startx-crash — Valid tty3 Xorg launch rejected by unrelated host Xwayland
- **Date:** 2026-08-08
- **Error patterns:** startx/Xorg error, menu option 3 exits before Windows RDP, Xwayland, Xorg display
- **Root cause(s):** AND-gate: check-x11-session.sh rejects any host Xwayland process instead of identifying the server for the current DISPLAY; a concurrent GNOME Xwayland process therefore rejects the menu's valid tty3/startx Xorg session before xfreerdp3 runs.
- **Fix:** Scope native-X11 proof to the current DISPLAY's Xorg process and remove the host-global Xwayland prohibition; add a two-case isolated shell regression check.
- **Files changed:** scripts/check-x11-session.sh, tests/check_x11_session_check.sh
- **Why not caught:** No automated native-X11 gate test modeled a current-display Xorg alongside an unrelated host Xwayland process.
- **Recurrence guard:** tests/check_x11_session_check.sh covers the positive current-display-Xorg-plus-Xwayland case and the negative foreign-Xorg case; it passed after the fix.
---

## rare-double-tap-drop — Coupled gesture slop let rapid retaps miss double-click classification
- **Date:** 2026-08-10
- **Error patterns:** rare double-tap drop, single-click/select, rapid retap, 12–16 px coordinate split, Windows spatial double-click
- **Root cause(s):** Code: `xf_input_touch_fallback` reused `FreeRDP_TouchLongPressSlopPx` (12 px default, 16 px maximum) as the double-tap anchor limit, so ordinary 12.65–16.64 px rapid retaps emitted distinct remote coordinates; contributing remote condition: Windows correctly classified those distinct coordinates as separate single clicks.
- **Fix:** Use a dedicated 48 px `DOUBLE_TAP_ANCHOR_SLOP_PX` floor for rapid tap-pair coordinate reuse while retaining `/touch-slop:12` for long-press/drag/pan; cover the captured 16.64 px vector and 50 px/550 ms negative boundaries in the production dispatcher test.
- **Files changed:** patches/onemix-touch.patch (X11 fallback implementation and TestXfInputDispatcher regression)
- **Why not caught:** No regression gate covered capture-shaped rapid-retap coordinate separation beyond the drag/long-press slop; the existing dispatcher coverage did not exercise the 16.64 px anchor boundary.
- **Recurrence guard:** `client/X11/test/TestXfInputDispatcher.c` in patches/onemix-touch.patch asserts the 16.64 px rapid retap reuses the first coordinate while 50 px and 550 ms cases remain independent; `ctest -R '^TestXfInputDispatcher$'` passes with the 48 px floor.
---

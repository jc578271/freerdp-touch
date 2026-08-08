# GSD Debug Knowledge Base

Resolved debug sessions. Used by `gsd-debugger` to surface known-pattern hypotheses at the start of new investigations.

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

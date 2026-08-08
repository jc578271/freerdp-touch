1. **Session gate**
Command: ./scripts/check-x11-session.sh
Expected: XDG_SESSION_TYPE=x11 set by xinitrc, gate prints OK
Actual: PASS
Notes: TTY/startx session confirmed, XDG_SESSION_TYPE=x11, gate OK
2. **Checksum verification**
Command: cd /home/hoang/freerdp-touch && (cd "$(readlink -f dist)" && sha256sum -c SHA256SUMS)
Expected: All four package files pass checksum verification
Actual: PASS
Notes: sha256sum -c all four packages OK before install
3. **Install**
Command: sudo apt install -y --allow-downgrades ./dist/libwinpr3-3_*_amd64.deb ./dist/libfreerdp3-3_*_amd64.deb ./dist/libfreerdp-client3-3_*_amd64.deb ./dist/freerdp3-x11_*_amd64.deb
Expected: Four-package closure installs successfully in one transaction
Actual: PASS
Notes: All four packages installed with --allow-downgrades, no errors
4. **Version verification all four packages**
Command: dpkg-query -W -f='${Package} ${Version}\n' freerdp3-x11 libfreerdp-client3-3 libfreerdp3-3 libwinpr3-3
Expected: All four packages show 3.15.0+dfsg-2.1+deb13u3+onemix1
Actual: PASS
Notes: All four verified independently at +onemix1
5. **Normal launch with touch gestures**
Command: menu <connection-args>
Expected: Desktop reached, tap/drag/long-press/scroll/pinch/three-finger all work
Actual: PASS
Notes: Tap left-click, drag, long-press right-click, two-finger scroll, pinch Ctrl+wheel, three-finger middle-drag all confirmed
6. **Diagnostic launch with all DIAG-01 record classes**
Command: FREERDP_TOUCH_DIAG=1 menu <connection-args>
Expected: Log with Begin/Update/End, transitions, synthesis, force_cancel with inferred_live_at_force_cancel > 0
Actual: PASS
Notes: Log dir 0700 file 0600, all record classes present, force_cancel summary has inferred_live_at_force_cancel positive, no auth material in log
7. **Normal launch is quiet default-off diagnostics**
Command: menu <connection-args>
Expected: Diagnostic dir snapshot unchanged, zero touch-diag markers
Actual: PASS
Notes: Before/after snapshot identical at 4 files, zero touch-diag markers observed
8. **Mouse-only mode**
Command: menu --mouse-only <connection-args>
Expected: Desktop reached, touch gestures silent, connection normal
Actual: PASS
Notes: Desktop reached, no touch gestures triggered, connection normal
9. **Rollback all four packages trixie closure**
Command: sudo apt install --reinstall -y freerdp3-x11 libfreerdp-client3-3 libfreerdp3-3 libwinpr3-3
Expected: All four packages stock, no +onemix1 residue
Actual: PASS
Notes: Trixie closure confirmed, all four stock, xfreerdp3 --version healthy
10. **Security-update detection**
Command: dpkg-query -W -f='${Version}' freerdp3-x11 | grep -q onemix1 && echo patched || echo stock
Expected: Prints stock after rollback
Actual: PASS
Notes: Output verified as stock, no +onemix1 residue

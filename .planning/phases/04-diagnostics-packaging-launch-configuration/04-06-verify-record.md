1. **Native-X11 gate**
Command: menu --mouse-only
Expected: Wrapper executes the native-X11 gate inside startx and prints OK
Actual: PASS
Notes: Gate OK observed inside startx through the locked mouse-only menu path
2. **Bundle SHA256SUMS**
Command: cd resolved dist target and run sha256sum -c SHA256SUMS
Expected: All four package files pass checksum verification
Actual: PASS
Notes: All four package files passed checksum verification
3. **Exact install idempotency**
Command: sudo apt install -y --allow-downgrades four exact local deb paths in dependency order, repeated twice
Expected: Both transactions succeed with identical four-package identities
Actual: PASS
Notes: Both exact local transactions succeeded with identical +onemix1 identities
4. **Installed closure**
Command: dpkg-query the four package names with version and architecture fields
Expected: Exactly four amd64 packages show the expected +onemix1 version after both installs
Actual: PASS
Notes: Exactly four amd64 package identities matched after both install passes
5. **Normal launch with touch gestures**
Command: menu <connection-args>
Expected: Desktop reached and all six local touch gestures work
Actual: PASS
Notes: Tap, drag, long-press, two-finger scroll, bidirectional pinch, and three-finger middle drag passed. /cert:ignore expected per D-25, server certificate identity not verified.
6. **Diagnostic launch**
Command: FREERDP_TOUCH_DIAG=1 menu <connection-args>
Expected: Local-only lifecycle and cancellation records have matching counts, native_count=0, and auth material absent
Actual: PASS
Notes: Begin/Update/End, classification, synthesis, last-coordinate fallback cancels, matching diag_count, native_count=0, summary before gesture clear. Auth material absent. No hardware native-cancel required.
7. **Quiet launch**
Command: menu <connection-args>
Expected: Diagnostic log snapshot and touch-diag marker count remain unchanged
Actual: PASS
Notes: No new diagnostic log and zero new touch-diag markers. Marker count remained 20610.
8. **Mouse-only mode**
Command: menu --mouse-only <connection-args>
Expected: Desktop reached and touch does not activate the local gesture layer
Actual: PASS
Notes: Desktop reached, touch gestures remained inactive, mouse and touchpad remained usable
9. **Rollback idempotency**
Command: sudo apt install --reinstall the exact four stock packages twice, using the trixie closure when required
Expected: Both transactions produce identical stock identities and stock mouse-only reaches the desktop
Actual: PASS
Notes: Both rollback passes produced identical stock identities with no +onemix1 residue; stock mouse-only launch passed
10. **Deployment parity and update detection**
Command: diff tracked and deployed menu, verify mode and retained launch flag, then query the installed stock version
Expected: Menu parity and mode pass, stock is detected, and GAP-07 remains USER-DEFERRED
Actual: PASS
Notes: Tracked and deployed menu are identical, mode 0755, startx status propagation present, one /cert:ignore retained, stock detection reports stock. GAP-07 USER-DEFERRED per D-25, server certificate identity not verified.

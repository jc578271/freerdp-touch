# Phase 4: Diagnostics, Packaging & Launch Configuration - Context

**Gathered:** 2026-08-08
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 4 freezes the currently working OneMix 3 local-only gesture implementation and turns it into a reproducible Debian release: one quilt-managed patch over the exact Debian source, the exact installable `.deb` set, verified install/rollback instructions, a credential-free daily launch wrapper, and opt-in touch diagnostics.

This phase must not redesign gesture behavior, restore native multitouch/RDPEI forwarding, add new gesture modes, or expose the working pinch/scroll classifier internals as new calibration settings. The only source-level behavior change allowed is the minimum diagnostics gating needed by DIAG-01; packaging must preserve the behavior already verified on the device.

</domain>

<decisions>
## Implementation Decisions

### Frozen touch behavior
- **D-01:** Native multitouch must remain disabled. The canonical launch must omit `+multitouch` and activate the existing client-owned local gesture path with `+touch-pinch-wheel-fallback`.
- **D-02:** Treat the current gesture source as the release candidate. Do not rewrite or retune the recognizer while packaging it; in particular, preserve one-finger tap/drag/long-press, two-finger wheel scroll, bidirectional `Ctrl`+wheel pinch, three-finger middle-button drag, lifecycle cleanup, and the 2.5 pinch-dominance classifier fix.

### Diagnostic workflow
- **D-03:** A dedicated `FREERDP_TOUCH_DIAG` environment variable gates touch diagnostics. Unset/false means normal launches do not emit the added diagnostic trace; do not require global `WLOG_LEVEL=DEBUG`.
- **D-04:** Enabled diagnostics produce one compact full trace: concise records for every touch Begin/Update/End/Cancel, gesture classification/transition, synthesized mouse or key output, cleanup/recovery decision, and RDPEI frame information when a frame path is present.
- **D-05:** Diagnostic code writes through the existing logging path to stderr. The launch wrapper mirrors that stream to the terminal and to one timestamped file; no second logging framework or verbosity hierarchy is needed.
- **D-06:** Timestamped logs live under `${XDG_STATE_HOME:-$HOME/.local/state}/freerdp-touch/`, never in the source tree. Diagnostic output must not echo the launch command, password, or other stored credentials.

### Package identity and upgrade policy
- **D-07:** The first patched package version is based on the exact Debian version with a local suffix: `3.15.0+dfsg-2.1+deb13u3+onemix1`.
- **D-08:** Security updates win. Do not hold or pin the local package above future Debian releases; a newer Debian version may replace the touch build. Documentation must explain how to detect that replacement and rebuild the patch on the newer source before restoring touch mode.
- **D-09:** Provide one release build script that verifies the exact base source version, starts from a clean source tree, applies the quilt patch, builds the binary packages, and reports the retained artifacts and SHA-256 checksums. Keep the Phase 1 baseline script separate rather than turning it into a patched-release pipeline.
- **D-10:** A successful build places the exact `.deb` set required by all modified binary packages plus `SHA256SUMS` in a gitignored `dist/` directory. The planner must derive this set from package ownership of the changed files; do not assume `freerdp3-x11` alone is sufficient, and never install a broad `freerdp3-*` glob.
- **D-11:** Commit the quilt patch, build/launch scripts, and documentation only. Do not commit generated Debian source trees, build output, or binary packages.
- **D-12:** Install and rollback documentation must reuse the verified Phase 1 pattern: install only the exact local artifacts, record/verify the installed version, restore the stock `freerdp3-x11` package with `apt install --reinstall` and the documented trixie fallback, then verify the stock version and launch.

### Calibration surface
- **D-13:** Expose only the two existing user-facing calibration values: long-press duration and touch slop. Daily defaults remain 600 ms and 8 px.
- **D-14:** Keep pinch/scroll classification constants, dominance ratio, activation thresholds, and wheel-step constants fixed at their currently verified values. Do not add settings or CLI flags for them in Phase 4.
- **D-15:** The launch wrapper reads two optional environment overrides and maps them to the existing `/touch-long-press:<ms>` and `/touch-slop:<px>` options. Do not add a new configuration file format or parser.
- **D-16:** Validate calibration overrides in the wrapper and fail with a clear message on non-integer or out-of-range values. Long press is constrained to the required 500–700 ms range; choose and document a conservative slop range around the verified 8 px default.
- **D-17:** Daily launch is non-interactive: use 600/8 unless overrides are explicitly set. Do not prompt on every launch or add speculative fixed presets.

### Launch entry point
- **D-18:** Add one credential-free wrapper in the repository as the canonical launch artifact. `/usr/local/bin/menu` option 3 delegates to that wrapper instead of carrying a separate copy of the full FreeRDP command.
- **D-19:** The wrapper owns only the local-touch preset and passes all FreeRDP connection/session arguments through unchanged. It must not contain or persist server passwords or other credentials; authentication remains with FreeRDP's existing prompt/credential handling.
- **D-20:** The wrapper provides an explicit `--mouse-only` escape hatch. That mode uses the same connection arguments but omits all local touch activation/calibration options; it does not roll back or switch binaries.
- **D-21:** Diagnostic launch uses the same wrapper with `FREERDP_TOUCH_DIAG=1`. The wrapper creates the XDG-state log and tees output; normal and diagnostic launches must not drift into separate command definitions.

### Launch session and menu hygiene
- **D-22:** The user operates FreeRDP only from a TTY. `startx` is mandatory. The canonical operating flow is: TTY login → menu option 3 → TTY password prompt → `startx` with a private xinitrc → display/touch rotation (`xrandr` + `xinput`) → `scripts/launch-touch.sh` → installed `/usr/bin/xfreerdp3`. Do not replace this with a GNOME-on-Xorg or direct-desktop launch path. The native-X11 gate must pass inside the startx session; the xinitrc sets `XDG_SESSION_TYPE=x11` before calling the wrapper.
- **D-23:** Menu changes are minimal. Option 3 delegates the actual FreeRDP invocation to the wrapper while preserving the current interaction and startup flow: TTY password prompt (`read -s`), `startx`, rotation, and existing non-secret connection/session arguments. The menu still reads the password and passes it as `/p:$PASS` through the wrapper as an opaque argument; the wrapper does not own, store, or persist credentials (D-19). Apply minimum non-UX-changing file hygiene: create the xinitrc with `umask 077` and `mktemp` (not a predictable world-readable path), remove `WLOG_LEVEL=DEBUG`, and clean up the temp file reliably after `startx` returns. Diagnostics must not echo credentials.

### Claude's Discretion
- Exact script names, quilt patch filename, wrapper path within the repository, timestamp format, log prefix, and documentation filenames.
- Exact names of the two calibration environment variables and the conservative accepted slop range, provided defaults remain 600 ms/8 px and invalid values fail before launch.
- Exact compact log field ordering and whether the diagnostic gate is cached at X11 client initialization, provided it adds no per-event behavior change when disabled.
- Exact list and installation order of generated `.deb` files after package ownership/dependency analysis.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

**Precedence warning:** `.planning/phases/03-gestures-session-stability/03-CONTEXT.md` predates the user-directed local-only pivot and is not authoritative for Phase 4. The roadmap/state and completed quick-task summaries below override its native-multitouch assumptions. Do not use it to restore RDPEI touch forwarding.

### Current scope and release contract
- `.planning/PROJECT.md` — Defines the OneMix 3/native-X11 boundary, exact Debian baseline, package/rollback requirement, and narrow v1 scope.
- `.planning/REQUIREMENTS.md` — Defines DIAG-01, PACK-01, PACK-02, and CONF-01, including opt-in diagnostics, reproducible quilt packaging, rollback, local-only launch, calibration, and mouse-only escape.
- `.planning/ROADMAP.md` — Defines the current Phase 4 goal and explicitly makes the non-multitouch/local-only Phase 3 result canonical.
- `.planning/STATE.md` — Records the final local-only gesture decision, completed classifier fixes, and the existing `/usr/local/bin/menu` option 3 update.

### Verified baseline and Debian workflow
- `.planning/phases/01-environment-gate-build-baseline/01-CONTEXT.md` — Locks the exact-source gate, clean-tree policy, artifact hygiene, exact-package install policy, and proof depth.
- `.planning/phases/01-environment-gate-build-baseline/baseline-report.md` — Records the actual native-X11 device/package baseline and the previously verified build/install/rollback cycle.
- `.planning/research/STACK.md` — Defines Debian `3.0 (quilt)`, `dpkg-buildpackage`, the exact FreeRDP version, and the existing platform tooling to reuse.
- `.planning/research/PITFALLS.md` — Covers package/version drift, invalid XWayland testing, rollback evidence, and touch-path failure modes relevant to release verification.

### Code changes that must be packaged
- `.planning/phases/02-native-rdpei-touch-lifecycle/02-01-SUMMARY.md` — Lists the XInput2 ownership, emulated-pointer suppression, content-bounds, and RDPEI lock-scope changes already present in the working tree.
- `.planning/phases/02-native-rdpei-touch-lifecycle/02-02-SUMMARY.md` — Lists the shared force-cancel/recovery lifecycle hooks and changed X11 files that remain part of the verified build.
- `.planning/phases/03-gestures-session-stability/03-01-SUMMARY.md` — Lists long-press, calibration CLI/settings, timer, and gesture cleanup changes and their complete modified-file set.
- `.planning/quick/260807-oz9-t-i-kh-ng-mu-n-mutitouch-native-n-a-t-i-/260807-oz9-SUMMARY.md` — Canonical evidence for disabling native RDPEI touch forwarding and activating local XI2 capture without `+multitouch`.
- `.planning/quick/260808-956-hi-n-t-i-freerdp-ang-l-c-2-ng-n-pan-th-h/260808-956-SUMMARY.md` — Canonical two-finger wheel-scroll and three-finger middle-button behavior.
- `.planning/quick/260808-b11-t-i-chuy-n-freerdp-v-kh-ng-multitouch-c-/260808-b11-SUMMARY.md` — Canonical 2.5 dominance-ratio fix and standalone classifier regression check.

### Live Debian source/package inputs
- `build/freerdp3-3.15.0+dfsg/debian/source/format` — Confirms `3.0 (quilt)` packaging.
- `build/freerdp3-3.15.0+dfsg/debian/patches/series` — Current Debian patch stack; the OneMix patch is not yet represented and must be appended after the existing stack.
- `build/freerdp3-3.15.0+dfsg/debian/changelog` — Current stock package version from which the `+onemix1` local entry must be derived.

No external gesture specification applies; the project documents, final summaries, and current source tree above are authoritative.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `scripts/check-x11-session.sh` — Reuse the established fail-closed native-X11 gate for on-device launch/UAT entry points rather than duplicating session detection.
- `scripts/build-baseline.sh` — Reuse its exact-version, `dpkg-buildpackage`, checksum, exact-install, rollback, and verification commands as reference; keep the baseline and patched-release scripts separate.
- `build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c` — Contains the working local-only gesture state machine, existing `WLog_DBG` decision points, touch lifecycle trace block, and shared `xf_touch_force_cancel` seam. Gate/normalize diagnostics here without changing gesture branches.
- `build/freerdp3-3.15.0+dfsg/channels/rdpei/client/rdpei_main.c` — Already logs touch-frame contact count and frame offset through WLog; reuse that path when RDPEI frame diagnostics are applicable rather than adding a second encoder/logger.
- `build/freerdp3-3.15.0+dfsg/client/common/cmdline.h` and `client/common/cmdline.c` — Already expose `+touch-pinch-wheel-fallback`, `/touch-long-press`, and `/touch-slop`; the wrapper should compose these existing switches.
- `build/freerdp3-3.15.0+dfsg/client/X11/test_scroll_classifier.c` — Small runnable regression model for the working pinch-vs-scroll classifier; preserve and run it while crystallizing the patch.

### Established Patterns
- `build/` and Debian build artifacts are gitignored. Keep generated output out of version control; add `dist/` to the same artifact-hygiene pattern.
- The source package is `3.0 (quilt)` with a long existing Debian patch series. The product change belongs in one integrated project patch after that series, not as an unmanaged dirty source tree.
- The working gesture code deliberately owns all touch locally. `+touch-pinch-wheel-fallback` selects XI2 touch even without `+multitouch`; reintroducing `+multitouch` would violate the current behavior contract.
- Lifecycle cleanup converges on `xf_touch_force_cancel`; diagnostic additions should observe this seam rather than create new cleanup state.
- The local `run-rdp.sh` is gitignored and machine-specific. It demonstrates the current flags but is not a release artifact and must not be copied with credentials into committed files.
- No new dependency, daemon, config format, or logging framework is needed. Existing shell, WLog, FreeRDP CLI, quilt, and Debian tools cover the phase.

### Integration Points
- Introduce the dedicated diagnostic gate at X11 client initialization or the nearest existing input-log helper, then apply it to the current touch/gesture trace points and shared cancellation summary without changing event routing.
- Convert every verified source edit across X11, common settings/CLI, and RDPEI into the integrated quilt patch; append it to `debian/patches/series` and add the local changelog version.
- Derive the required installable package set from the modified-file package ownership and generated dependencies, then have the build script copy only that exact set to `dist/` and generate `SHA256SUMS`.
- Have the repository wrapper invoke the installed system `xfreerdp3`, prepend the frozen local-touch options, validate two calibration env vars, strip those options under `--mouse-only`, and pass remaining arguments unchanged.
- Update menu option 3 to delegate the FreeRDP invocation to the wrapper while preserving the TTY/startx/rotation flow (D-22, D-23), and document a normal, diagnostic, mouse-only, install, verification, security-update replacement, and stock rollback path.

</code_context>

<specifics>
## Specific Ideas

- The user's explicit release rule is: **do not bring multitouch back; the source code currently works very well.** Planning and review should treat any gesture-logic diff beyond diagnostic gating as a regression risk requiring explicit user approval.
- Normal daily launch goes through the TTY → startx → rotation → wrapper flow (D-22). Diagnostics are exceptional and opt-in through one environment variable.
- A future Debian security update replacing the local package is expected and preferable to silently blocking security fixes; the touch package can then be rebuilt on the newer source.
- Mouse-only mode is a launch-mode escape hatch in the same patched binary, not a package rollback.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within Phase 4 scope. Additional classifier knobs, native multitouch restoration, runtime mode switching, and broader-device calibration remain outside v1.

</deferred>

---

*Phase: 4-Diagnostics, Packaging & Launch Configuration*
*Context gathered: 2026-08-08*

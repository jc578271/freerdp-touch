# Phase 4: Diagnostics, Packaging & Launch Configuration - Research

**Researched:** 2026-08-08  
**Domain:** FreeRDP X11 diagnostic gating, Debian `3.0 (quilt)` release packaging, and credential-free launch operations  
**Confidence:** MEDIUM

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

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

### Claude's Discretion
- Exact script names, quilt patch filename, wrapper path within the repository, timestamp format, log prefix, and documentation filenames.
- Exact names of the two calibration environment variables and the conservative accepted slop range, provided defaults remain 600 ms/8 px and invalid values fail before launch.
- Exact compact log field ordering and whether the diagnostic gate is cached at X11 client initialization, provided it adds no per-event behavior change when disabled.
- Exact list and installation order of generated `.deb` files after package ownership/dependency analysis.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within Phase 4 scope. Additional classifier knobs, native multitouch restoration, runtime mode switching, and broader-device calibration remain outside v1.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DIAG-01 | User can enable diagnostic logging that records touch begin/update/end/cancel events, gesture decisions, and RDPEI frame submission, while normal launches keep the logging disabled. [VERIFIED: .planning/REQUIREMENTS.md:16-19] | Use a single `FREERDP_TOUCH_DIAG` gate around compact X11 and RDPEI records; route enabled records as `WLog_WARN` so the existing default console appender writes them to stderr. [VERIFIED: build/freerdp3-3.15.0+dfsg/winpr/libwinpr/utils/wlog/wlog.c:492-505; build/freerdp3-3.15.0+dfsg/winpr/libwinpr/utils/wlog/ConsoleAppender.c:112-136] |
| PACK-01 | Developer can reproducibly build an installable Debian `.deb` from the pinned `freerdp3-x11 3.15.0+dfsg-2.1+deb13u3` source using a documented quilt patch. [VERIFIED: .planning/REQUIREMENTS.md:47-50] | Extract a fresh tree from the pinned `.dsc`, append one project patch after the Debian series, validate the local changelog version, and build through `dpkg-buildpackage`. [CITED: https://www.debian.org/doc/manuals/debmake-doc/ch13.en.html] |
| PACK-02 | User can install the patched package and restore the stock Debian package using documented, verified commands. [VERIFIED: .planning/REQUIREMENTS.md:49-51] | Ship a checksum-verified explicit runtime bundle, then document an explicit stock-package rollback closure rather than a `freerdp3-*` glob. [VERIFIED: dpkg-deb metadata inspection, 2026-08-08; CITED: https://manpages.debian.org/trixie/apt/apt-get.8.en.html] |
| CONF-01 | User can launch the patched client with a documented preset that keeps native multitouch disabled, enables the local-only gesture layer, exposes long-press/pinch calibration, and provides an explicit mouse-only escape hatch. [VERIFIED: .planning/REQUIREMENTS.md:51-52] | A Bash wrapper can validate two calibration environment values, invoke installed `xfreerdp3` once with the frozen local-only options, omit them under `--mouse-only`, and use the same process for diagnostics. [VERIFIED: build/freerdp3-3.15.0+dfsg/client/common/cmdline.c:1174-1193; build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c:157-174] |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- Keep the v1 runtime to the quoted scope, **“Debian on OneMix 3 under X11”**; do not make Wayland/Xwayland a Phase 4 target. [VERIFIED: .claude/CLAUDE.md:13-21]
- Preserve the quoted integration boundary, **“Patch the existing FreeRDP X11 client”**; do not replace its RDP, keyboard, fullscreen, or RDPEI machinery. [VERIFIED: .claude/CLAUDE.md:15-18]
- Build against the currently packaged device baseline and provide a Debian `.deb` with a safe rollback path. [VERIFIED: .claude/CLAUDE.md:17-18]
- Do not add ordinary-touch delay, a new input daemon, a gesture framework, a new config format/parser, a rewritten RDPEI encoder, or a second logging framework. [VERIFIED: .claude/CLAUDE.md:19-21; .claude/CLAUDE.md:85-94]
- Keep only the user-facing calibration controls required for the physical touchscreen; leave the frozen classifier and wheel constants alone. [VERIFIED: .claude/CLAUDE.md:19-21; .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md:36-42]
- Treat the native-X11 gate as mandatory for installation and hardware UAT; the existing gate rejects Wayland/Xwayland. [VERIFIED: scripts/check-x11-session.sh:24-34]
- Preserve generated-artifact hygiene: the existing ignore policy already excludes the quoted entries **`build/`**, **`*.deb`**, and **`run-rdp.sh`**; Phase 4 must add the proposed release-output directory without committing it. [VERIFIED: .gitignore:1-11; ASSUMED: proposed `dist/` entry]
- No project-specific skill rules were loaded; the project configuration contains the exact empty mapping **`"agent_skills": {}`**. [VERIFIED: .planning/config.json:82-85]

## Summary

Phase 4 is a release freeze, not another gesture phase. A clean-tree comparison found the working release candidate changes source in the X11 client, client-common command-line layer, RDPEI client channel, core settings code, and the standalone classifier check; package the complete source delta plus the smallest diagnostic-only edits rather than selectively recreating gesture logic. [VERIFIED: clean `dpkg-source -x` versus working-tree `diff -qr`, 2026-08-08] The canonical Phase 4 context and current state supersede older native-multitouch material: local XInput2 gesture handling is the v1 path, and `+multitouch` must remain absent. [VERIFIED: .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md:18-21; .planning/STATE.md:63-65]

The decisive diagnostic fact is that the existing touch trace uses `WLog_DBG`, while the pinned WLog implementation defaults individual loggers to `WLOG_INFO`; DEBUG records therefore do not appear in a normal launch. [VERIFIED: build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c:303-345; build/freerdp3-3.15.0+dfsg/winpr/libwinpr/utils/wlog/wlog.c:900-947] WLog's default console appender sends WARN-and-higher records to stderr, so a local, environment-gated `WLog_WARN` diagnostic helper meets the stderr requirement without turning on global `WLOG_LEVEL=DEBUG`. [VERIFIED: build/freerdp3-3.15.0+dfsg/winpr/libwinpr/utils/wlog/wlog.c:492-505; build/freerdp3-3.15.0+dfsg/winpr/libwinpr/utils/wlog/ConsoleAppender.c:112-136]

The deployable runtime package closure is not just the X11 executable. The X11 package has an exact-version dependency on the client library, the client library has an exact-version dependency on the core library, and the core library has an exact-version dependency on `libwinpr3-3`; all four runtime packages must ship at the same `+onemix1` version. [VERIFIED: build/freerdp3-3.15.0+dfsg/debian/control:68-105; dpkg-deb metadata inspection, 2026-08-08] `freerdp3-dev` also ships changed headers, but is not part of the runtime closure and would pull a much larger exact-version development dependency family if installed. [VERIFIED: build/freerdp3-3.15.0+dfsg/debian/freerdp3-dev.install:1-12; dpkg-deb metadata inspection, 2026-08-08]

**Primary recommendation:** Create one repo-tracked quilt patch from a fresh pinned source tree, make only gate-and-record diagnostic edits to the frozen code, build a four-package runtime bundle through the existing Debian rules, and use one credential-free Bash wrapper for normal, diagnostic, and mouse-only launches. [VERIFIED: build/freerdp3-3.15.0+dfsg/debian/source/format:1; build/freerdp3-3.15.0+dfsg/debian/rules:18-58; ASSUMED: proposed wrapper/file names]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Touch lifecycle and gesture diagnostic records | X11 client | Existing WLog runtime | `xf_input.c` owns the local-only event and gesture state machine, while WLog supplies the existing output path. [VERIFIED: build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c:1091-1601; build/freerdp3-3.15.0+dfsg/winpr/include/winpr/wlog.h:280-303] |
| RDPEI frame-submission record | RDPEI client channel | X11 client | Frame construction/submission occurs in `rdpei_main.c`; X11 must not duplicate its encoder or frame model. [VERIFIED: build/freerdp3-3.15.0+dfsg/channels/rdpei/client/rdpei_main.c:160-213; build/freerdp3-3.15.0+dfsg/channels/rdpei/client/rdpei_main.c:710-757] |
| Gesture behavior and cleanup | X11 client | — | The frozen recognizer, synthesized mouse/key calls, and `xf_touch_force_cancel` seam are already X11-local. [VERIFIED: build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c:1091-1754] |
| Patch application, local version, and `.deb` creation | Debian source/package build | Filesystem artifact bundle | `dpkg-source` applies the Debian series and `dpkg-buildpackage` invokes source/package construction; shell orchestration should only prepare a clean input and retain selected outputs. [CITED: https://www.debian.org/doc/manuals/debmake-doc/ch13.en.html] |
| Calibration validation and mode selection | Bash launch wrapper | Installed `/usr/bin/xfreerdp3` | The wrapper is the trust boundary for optional environment values; FreeRDP keeps ownership of connection/session parsing. [VERIFIED: build/freerdp3-3.15.0+dfsg/debian/freerdp3-x11.install:1; VERIFIED: command -v xfreerdp3, 2026-08-08] |
| Daily entry point | System menu | Credential-free wrapper | The live menu must stop owning a password and full command, then delegate to the installed wrapper. [VERIFIED: /usr/local/bin/menu:27-66; .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md:43-48] |

## Standard Stack

### Core

| Library / Tool | Verified Version | Purpose | Why Standard |
|----------------|------------------|---------|--------------|
| Debian `freerdp3` source | `3.15.0+dfsg-2.1+deb13u3` [VERIFIED: `dpkg-parsechangelog -SVersion`, 2026-08-08] | Exact patch base and source of the installed X11 client. | The source format is the verbatim value `3.0 (quilt)`, and the pinned source already carries Debian's patch stack. [VERIFIED: build/freerdp3-3.15.0+dfsg/debian/source/format:1; build/freerdp3-3.15.0+dfsg/debian/patches/series:1-106] |
| `dpkg-source` / `dpkg-buildpackage` | `1.22.22` [VERIFIED: local command audit, 2026-08-08] | Fresh source extraction and binary package build. | Debian documents `dpkg-source -x` applying `debian/patches/series` and `dpkg-buildpackage` as the package build path. [CITED: https://www.debian.org/doc/manuals/debmake-doc/ch13.en.html; CITED: https://www.debian.org/doc/manuals/maint-guide/build.en.html] |
| `quilt` | Missing locally; APT candidate `0.68-1` [VERIFIED: `command -v quilt` and `apt-cache policy quilt`, 2026-08-08] | Add/refresh the single project patch after Debian's existing patch stack. | `quilt new`, `quilt add`, and `quilt refresh` are the documented patch workflow, and quilt updates the series file when patches change. [CITED: https://www.debian.org/doc/manuals/maint-guide/modify; CITED: https://manpages.debian.org/trixie/quilt/quilt.1.en.html] |
| Existing WinPR WLog | Bundled in pinned source [VERIFIED: build/freerdp3-3.15.0+dfsg/winpr/include/winpr/wlog.h:280-303] | Emit compact gated diagnostic records through FreeRDP's existing logger. | It supplies level filtering and a console appender; adding another logger would duplicate already present machinery. [VERIFIED: build/freerdp3-3.15.0+dfsg/winpr/libwinpr/utils/wlog/wlog.c:492-505; build/freerdp3-3.15.0+dfsg/winpr/libwinpr/utils/wlog/ConsoleAppender.c:112-136] |
| Bash + coreutils (`mktemp`, `tee`, `sha256sum`) | Bash `5.2.37`; coreutils `9.7` [VERIFIED: local command audit, 2026-08-08] | Safely compose arguments, create a private timestamped log, mirror output, preserve a pipeline failure, and checksum explicit artifacts. | Bash arrays and `PIPESTATUS` preserve argument boundaries and the client exit code when diagnostic output is teed. [VERIFIED: Bash runtime pipeline check, 2026-08-08; ASSUMED: proposed wrapper implementation] |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| `apt` | `3.0.3` [VERIFIED: local command audit, 2026-08-08] | Install the explicit local package closure and restore stock packages from configured repositories. | Use only package names/files listed in the generated manifest; never use a `freerdp3-*` glob. [VERIFIED: scripts/build-baseline.sh:118-154; .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md:31-35] |
| `dpkg-deb` / `dpkg-query` | `dpkg 1.22.22` [VERIFIED: local command audit, 2026-08-08] | Validate package name/version/dependencies and record installed versions. | Use after every build, install, and rollback to prove the runtime closure rather than inferring it from filenames. [VERIFIED: dpkg-deb metadata inspection, 2026-08-08] |
| `xinput` | `1.6.4` [VERIFIED: local command audit, 2026-08-08] | Human diagnostic corroboration of the physical XInput2 stream. | Use only during native-X11 on-device triage; the application log remains the release diagnostic artifact. [VERIFIED: .planning/phases/01-environment-gate-build-baseline/baseline-report.md:29-87] |
| Existing classifier model | C11 source, passes locally [VERIFIED: compiler run, 2026-08-08] | Guard the frozen `2.5` dominance classifier while crystallizing the patch. | Compile it into `/tmp`, not the source tree, before and after generating the quilt patch. [VERIFIED: build/freerdp3-3.15.0+dfsg/client/X11/test_scroll_classifier.c:1-129] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| A gated WLog WARN record | Global `WLOG_LEVEL=DEBUG` | Reject global DEBUG: it enables unrelated debug records and the live menu currently uses it only as a broad diagnostic workaround. [VERIFIED: /usr/local/bin/menu:44-60; build/freerdp3-3.15.0+dfsg/winpr/libwinpr/utils/wlog/wlog.c:913-947] |
| A repo-tracked quilt patch | Maintaining the ignored `build/` tree as the release source | Reject the dirty-tree release path: clean extraction and quilt make the patch portable, reviewable, and repeatable. [CITED: https://www.debian.org/doc/manuals/debmake-doc/ch13.en.html; VERIFIED: .gitignore:1-11] |
| An explicit runtime manifest | `freerdp3-*.deb` glob installation | Reject the glob: it would select unrelated SDL, Wayland, proxy, debug, and development artifacts present in the current build directory. [VERIFIED: build directory artifact inventory, 2026-08-08] |
| A wrapper that forwards a native FreeRDP connection argument | A custom connection/profile parser | Reject a custom parser: `xfreerdp3 /help` already accepts the documented positional example `connection.rdp`, while the wrapper's scope is only touch activation/calibration. [VERIFIED: `xfreerdp3 /help`, 2026-08-08; ASSUMED: use of a user-managed connection file if desired] |

**Installation prerequisite:**

```bash
sudo apt install quilt
```

`quilt` is the sole missing build prerequisite; all declared Debian build dependencies are currently satisfied. [VERIFIED: `command -v quilt`, `apt-cache policy quilt`, and `dpkg-checkbuilddeps`, 2026-08-08]

## Package Legitimacy Audit

No new npm, PyPI, crates.io, or application-library dependency is proposed, so the ecosystem-specific package-legitimacy gate does not apply. [VERIFIED: .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md:104-110] The only missing component is Debian's `quilt` build tool from the configured trixie APT repository; it is a documented prerequisite for the required `3.0 (quilt)` workflow, not an application dependency. [VERIFIED: `apt-cache policy quilt`, 2026-08-08; CITED: https://www.debian.org/doc/manuals/maint-guide/modify]

| Package | Registry | Verdict | Disposition |
|---------|----------|---------|-------------|
| `quilt` | Configured Debian trixie APT source [VERIFIED: `apt-cache policy quilt`, 2026-08-08] | No npm/PyPI/crates legitimacy check is applicable. [ASSUMED: legitimacy seam has no Debian ecosystem mode] | Install explicitly before patch authoring; do not substitute a custom patch tool. [CITED: https://manpages.debian.org/trixie/quilt/quilt.1.en.html] |

**Packages removed due to [SLOP] verdict:** none — no package-legitimacy scan was applicable. [ASSUMED: no supported language-registry dependency is introduced]

**Packages flagged as suspicious [SUS]:** none. [ASSUMED: no supported language-registry dependency is introduced]

## Architecture Patterns

### System Architecture Diagram

```text
Repository-tracked quilt patch + release script
             |
             v
Pinned .dsc --dpkg-source -x--> fresh Debian source tree
             |                         |
             |                         +--> Debian patch series already applied
             |                                      |
             |                          copy project patch + append once
             |                                      v
             |                                quilt push
             |                                      |
             |                          local changelog version check
             |                                      v
             +------------------------> dpkg-buildpackage -us -uc -b
                                                   |
                                                   v
                 explicit runtime artifact selector + SHA256SUMS -> dist/
                                                   |
                                                   v
                                 apt install of exact local runtime set
                                                   |
                                                   v
User connection/session args --> launch wrapper --> /usr/bin/xfreerdp3
                                       |                     |
          FREERDP_TOUCH_DIAG=1 --------+                     v
                                       |          XI2 touch -> local gesture state
                                       |                     |        |
                                       |                     |        +--> mouse/key synthesis
                                       |                     |        |
                                       |                     |        +--> gated WLog WARN -> stderr
                                       |                     |                                    |
                                       +--> timestamped XDG log <---- tee <------- 2>&1
                                                                 |
                                         RDPEI frame path (only when present)
                                                                 |
                                                                 v
                                                  gated compact frame submission record
```

The diagram deliberately keeps packaging, local gesture behavior, and connection/auth arguments separate: the wrapper composes only touch options and never reimplements RDP connection or RDPEI protocol handling. [VERIFIED: .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md:43-48; build/freerdp3-3.15.0+dfsg/channels/rdpei/client/rdpei_main.c:160-213]

### Existing Source-to-Package Map

| Source responsibility | Evidence | Runtime package consequence |
|-----------------------|----------|-----------------------------|
| X11 event/gesture code including `xf_input.c`, `xf_event.c`, `xf_client.c`, and X11 headers | `xf_input.c`, `xf_event.c`, and `xf_client.c` are X11 client sources, and the Debian X11 install list contains the executable. [VERIFIED: build/freerdp3-3.15.0+dfsg/client/X11/CMakeLists.txt:42-80; build/freerdp3-3.15.0+dfsg/debian/freerdp3-x11.install:1-4] | Retain/install `freerdp3-x11`. [VERIFIED: dpkg-deb metadata inspection, 2026-08-08] |
| `cmdline.c` plus the RDPEI client channel | Client-common appends channel-client sources to the `freerdp-client` target; the RDPEI channel declares `rdpei_main.c` as its source. [VERIFIED: build/freerdp3-3.15.0+dfsg/client/common/CMakeLists.txt:18-76; build/freerdp3-3.15.0+dfsg/channels/rdpei/client/CMakeLists.txt:18-25] | Retain/install `libfreerdp-client3-3`. [VERIFIED: build/freerdp3-3.15.0+dfsg/debian/libfreerdp-client3-3.install:1-3; dpkg-deb metadata inspection, 2026-08-08] |
| Settings getters/string metadata and generated settings keys | The core common target includes `settings_getters.c` and `settings_str.c`; the current settings header contains the three touch settings. [VERIFIED: build/freerdp3-3.15.0+dfsg/libfreerdp/common/CMakeLists.txt:18-27; build/freerdp3-3.15.0+dfsg/include/freerdp/settings_types_private.h:612-619] | Retain/install `libfreerdp3-3`. [VERIFIED: build/freerdp3-3.15.0+dfsg/debian/libfreerdp3-3.install:1; dpkg-deb metadata inspection, 2026-08-08] |
| Public/private headers | The dev package installs all FreeRDP headers, including changed `cmdline.h` and `settings_types_private.h`. [VERIFIED: build/freerdp3-3.15.0+dfsg/debian/freerdp3-dev.install:1-12; dpkg-deb content inspection, 2026-08-08] | Do not add `freerdp3-dev` to the end-user runtime installer; verify and document it separately only if a development package release is intentionally requested. [ASSUMED: D-10 means the minimal runnable closure rather than a development SDK release] |

### Recommended Project Structure

```text
patches/                              # [ASSUMED] committed one-file quilt patch
└── onemix-touch.patch                # [ASSUMED] applies after Debian's series
scripts/
├── build-baseline.sh                 # existing Phase 1 baseline; unchanged
├── build-release.sh                  # [ASSUMED] clean patched-release pipeline
└── launch-touch.sh                   # [ASSUMED] canonical credential-free wrapper
README.md                             # [ASSUMED] install, rollback, launch, and recovery guide
dist/                                 # [ASSUMED] generated explicit runtime .debs + SHA256SUMS; gitignored
```

Use one patch, one release script, one wrapper, and one operations document; do not add a daemon, config parser, package repository, or separate diagnostic program. [VERIFIED: .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md:104-110; ASSUMED: proposed file names]

### Pattern 1: Freeze the source delta in one quilt patch

**What:** Start from a new `dpkg-source -x` tree, let Debian's existing series remain applied, create one new project patch, add every release-candidate source file before copying/editing it, include the local changelog entry, and `quilt refresh`. [CITED: https://www.debian.org/doc/manuals/maint-guide/modify; CITED: https://manpages.debian.org/trixie/quilt/quilt.1.en.html]

**Why:** The working changes are currently under gitignored `build/`; a patch made from a fresh tree avoids generated `debian/` and object-directory noise. [VERIFIED: .gitignore:1-11; clean-tree diff inventory, 2026-08-08]

**Required checks:**

1. Extract from the pinned source descriptor into a fresh work directory; never reset or reuse the active release-candidate tree. [VERIFIED: scripts/build-baseline.sh:30-47; .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md:29-35]
2. Assert the extracted changelog's source version is the exact base version before the project patch is applied. [VERIFIED: scripts/build-baseline.sh:18-27; .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md:27-31]
3. After applying the project patch, assert the local changelog version is the exact locked `+onemix1` version. [VERIFIED: .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md:27-31]
4. Keep only source files and `debian/changelog` in the patch; do not include `obj-*`, `debian/.debhelper`, `debian/tmp`, binary packages, or the generated source tree. [VERIFIED: clean-tree diff inventory, 2026-08-08; .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md:31-35]

### Pattern 2: Gate diagnostic records locally and route them at WARN

**What:** Add one X11-local boolean initialized from `FREERDP_TOUCH_DIAG` and use it only around compact trace calls; emit enabled records at `WLOG_WARN`/`WLog_WARN`, not `WLOG_DEBUG`/`WLog_DBG`. [ASSUMED: exact helper and field names]

**Why:** WLog defaults to INFO and allows a WARN record, while the default console appender maps WARN to stderr; this meets D-03 and D-05 without a global log-level override. [VERIFIED: build/freerdp3-3.15.0+dfsg/winpr/libwinpr/utils/wlog/wlog.c:900-947; build/freerdp3-3.15.0+dfsg/winpr/libwinpr/utils/wlog/wlog.c:492-505; build/freerdp3-3.15.0+dfsg/winpr/libwinpr/utils/wlog/ConsoleAppender.c:112-136]

**Where to instrument, without changing gesture branches:**

- At X11 ingress, record each Begin/Update/End and the selected local path; the existing ingress point is `xf_input_touch_remote`. [VERIFIED: build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c:1558-1601]
- At every state transition already represented by the existing local recognizer: pending, pinch, scroll, three-finger pan, long-press, tap, drag release, and quarantine/recovery. [VERIFIED: build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c:950-1089; build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c:1091-1556]
- Immediately beside each synthesized button, wheel, and Ctrl press/release call so the trace states the emitted output, not merely the classifier's intent. [VERIFIED: synthesized-input call-site inventory, 2026-08-08; build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c:303-345; build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c:809-929]
- At `xf_touch_force_cancel`, record the cleanup decision and every actual native `TouchCancel`; reuse this existing reset seam rather than adding cleanup state. [VERIFIED: build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c:1603-1754]
- In the RDPEI submission path, add one gated compact record after the existing touch-frame PDU submission; include only a frame count, frame offset, encoded size, and return status. [VERIFIED: build/freerdp3-3.15.0+dfsg/channels/rdpei/client/rdpei_main.c:710-757; ASSUMED: exact field ordering]

**RDPEI caveat:** The existing detailed frame printer is behind `#if defined(WITH_DEBUG_RDPEI)`, while Debian config explicitly sets `-DWITH_DEBUG_ALL=OFF`; do not rely on that conditional diagnostic block as the Phase 4 release trace without proving it is compiled. [VERIFIED: build/freerdp3-3.15.0+dfsg/channels/rdpei/client/rdpei_main.c:587-667; build/freerdp3-3.15.0+dfsg/debian/rules:18-58]

### Pattern 3: One wrapper, three modes

**What:** The wrapper has exactly one FreeRDP command construction path: normal and diagnostic modes include the frozen touch options; `--mouse-only` omits only those options; diagnostics merely adds the log destination and tee pipeline. [VERIFIED: .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md:36-48]

**Calibration boundary:** Validate the two wrapper environment values before invoking FreeRDP. The existing parser casts input through `atoi` and performs no user-visible range validation, so it cannot meet D-16 by itself. [VERIFIED: build/freerdp3-3.15.0+dfsg/client/common/cmdline.c:1174-1193]

**Recommended validation policy:** `FREERDP_TOUCH_LONG_PRESS_MS` and `FREERDP_TOUCH_SLOP_PX` are proposed variable names; require unsigned decimal text, use `600` and `8` when unset, restrict long press to `500`–`700`, and restrict slop to the proposed conservative `4`–`16` px range. [ASSUMED: variable names and proposed slop range; VERIFIED: .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md:36-42]

### Pattern 4: Explicit runtime manifest and security-friendly upgrade behavior

**What:** Have `build-release.sh` select exactly `libwinpr3-3`, `libfreerdp3-3`, `libfreerdp-client3-3`, and `freerdp3-x11` from the fresh build output, validate their package metadata/version, then create `SHA256SUMS` over that explicit list. [ASSUMED: proposed script name; VERIFIED: dpkg-deb metadata inspection, 2026-08-08]

**Why:** The installed X11 package requires the client library at the exact same binary version, the client library requires the core library at the exact same binary version, and the core library requires `libwinpr3-3` at the exact same binary version. [VERIFIED: build/freerdp3-3.15.0+dfsg/debian/control:68-105; dpkg-deb metadata inspection, 2026-08-08]

**Upgrade policy:** Do not create an APT hold or pin. Local `dpkg --compare-versions` checks show the locked local version sorts above the pinned base but below representative next stable-update, Debian-revision, and upstream versions; newer Debian security releases can therefore replace it. [VERIFIED: `dpkg --compare-versions`, 2026-08-08; CITED: https://www.debian.org/doc/debian-policy/ch-controlfields.html]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Debian patch application/order | Custom copy/diff/rebase script | `dpkg-source` + `quilt` + `debian/patches/series` | Debian already records and applies the patch order, including `.pc/applied-patches`. [CITED: https://www.debian.org/doc/manuals/debmake-doc/ch13.en.html] |
| Binary package build | Direct CMake install or hand-assembled `.deb` | `dpkg-buildpackage` through existing `debian/rules` | The rules carry Debian's CMake flags, hardening, channels, and package split. [VERIFIED: build/freerdp3-3.15.0+dfsg/debian/rules:1-127] |
| SHA-256 calculation | Custom hashing utility | `sha256sum` | The installed coreutils binary is available and Phase 1 already uses it. [VERIFIED: scripts/build-baseline.sh:70-75; local command audit, 2026-08-08] |
| Touch/RDPEI logging framework | New logger, JSON logger, or log daemon | Existing WLog plus wrapper `tee` | WLog has level filtering and console output; only a tiny gate is needed. [VERIFIED: build/freerdp3-3.15.0+dfsg/winpr/include/winpr/wlog.h:195-303; build/freerdp3-3.15.0+dfsg/winpr/libwinpr/utils/wlog/ConsoleAppender.c:53-138] |
| Frame encoder or RDPEI lifecycle | New frame encoder / duplicate contact map | Existing `rdpei_send_touch_event_pdu` and `xf_touch_force_cancel` seams | The phase needs observability, not protocol behavior changes. [VERIFIED: build/freerdp3-3.15.0+dfsg/channels/rdpei/client/rdpei_main.c:160-213; build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c:1603-1754] |
| Calibration/profile format | New config file/parser | Existing `/touch-long-press` and `/touch-slop` options plus two validated environment overrides | The FreeRDP command-line settings already exist; the wrapper only validates and composes them. [VERIFIED: build/freerdp3-3.15.0+dfsg/client/common/cmdline.h:497-502; build/freerdp3-3.15.0+dfsg/client/common/cmdline.c:1174-1193] |
| Password prompt/storage | Shell password capture or an argument file generated under `/tmp` | FreeRDP's existing authentication prompt/credential handling | The current menu writes a captured password into a temporary X init script; Phase 4 must remove that behavior rather than moving it. [VERIFIED: /usr/local/bin/menu:27-66] |

**Key insight:** This phase only needs a small diagnostic gate, one patch, one build script, and one wrapper; every more-general subsystem would create an upgrade and security burden without improving the frozen OneMix 3 behavior. [VERIFIED: .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md:104-117; ASSUMED: minimal file layout]

## Common Pitfalls

### Pitfall 1: A gated `WLog_DBG` trace is still invisible

**What goes wrong:** Code checks `FREERDP_TOUCH_DIAG` but emits `WLog_DBG`; normal runs still suppress the desired trace because the logger defaults to INFO. [VERIFIED: build/freerdp3-3.15.0+dfsg/winpr/libwinpr/utils/wlog/wlog.c:900-947; build/freerdp3-3.15.0+dfsg/winpr/include/winpr/wlog.h:280-293]

**How to avoid:** Gate `WLog_WARN` records instead; default WLog console routing sends WARN to stderr, and no global `WLOG_LEVEL=DEBUG` is needed. [VERIFIED: build/freerdp3-3.15.0+dfsg/winpr/libwinpr/utils/wlog/ConsoleAppender.c:112-136]

**Warning sign:** `FREERDP_TOUCH_DIAG=1` produces no touch record unless the user separately sets `WLOG_LEVEL=DEBUG`. [ASSUMED: manual acceptance symptom]

### Pitfall 2: Instrumenting X11 only misses the required RDPEI evidence

**What goes wrong:** X11 tracing can state that a local action was chosen but cannot prove what a live RDPEI frame submit attempted. [VERIFIED: build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c:1558-1601; build/freerdp3-3.15.0+dfsg/channels/rdpei/client/rdpei_main.c:710-757]

**How to avoid:** Add one gated record at the existing touch-frame PDU send boundary; do not revive native forwarding or rewrite frame encoding. [VERIFIED: build/freerdp3-3.15.0+dfsg/channels/rdpei/client/rdpei_main.c:710-757; .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md:18-21]

**Warning sign:** Diagnostic logs contain gesture decisions but no `frame` record when an RDPEI path actually runs. [ASSUMED: manual acceptance symptom]

### Pitfall 3: Accidentally reintroducing stale native-multitouch decisions

**What goes wrong:** Older Phase 3 material describes native RDPEI behavior and now-superseded settings; copying it into the wrapper can restore `+multitouch` or expose forbidden knobs. [VERIFIED: .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md:60-62; .planning/STATE.md:63-65]

**How to avoid:** Make the canonical non-mouse command contain `+touch-pinch-wheel-fallback` and no `+multitouch`; expose only duration/slop, and preserve the classifier regression model unchanged. [VERIFIED: build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c:157-174; build/freerdp3-3.15.0+dfsg/client/X11/test_scroll_classifier.c:13-18; .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md:36-42]

**Warning sign:** Help/docs mention `/touch-pan-deadband`, or a wrapper command contains `+multitouch`. [VERIFIED: build/freerdp3-3.15.0+dfsg/client/common/cmdline.h:497-502; ASSUMED: wrapper review symptom]

### Pitfall 4: Shipping only `freerdp3-x11`

**What goes wrong:** The executable's package has an exact-version dependency on `libfreerdp-client3-3`, which has an exact-version dependency on `libfreerdp3-3`, which has an exact-version dependency on `libwinpr3-3`; a one-file installer leaves a mixed local/stock set or fails dependency resolution. [VERIFIED: build/freerdp3-3.15.0+dfsg/debian/control:68-105; dpkg-deb metadata inspection, 2026-08-08]

**How to avoid:** Select and checksum the explicit four-package runtime closure after every build, and install it in one APT transaction. [ASSUMED: exact release-script selection implementation; VERIFIED: dpkg-deb metadata inspection, 2026-08-08]

**Warning sign:** `apt` proposes removing packages, cannot satisfy an exact version, or the local X11 package is installed alongside a stock client/core library. [ASSUMED: package-install failure symptoms]

### Pitfall 5: Losing the FreeRDP exit status to `tee`

**What goes wrong:** In a standard shell pipeline, `xfreerdp3 ... | tee log` returns `tee`'s status, hiding a failed client session. [VERIFIED: Bash runtime pipeline check, 2026-08-08]

**How to avoid:** Use Bash for the wrapper's diagnostic branch and exit with `${PIPESTATUS[0]}` after teeing; keep normal mode an `exec` of the real client. [VERIFIED: Bash runtime pipeline check, 2026-08-08; ASSUMED: proposed wrapper implementation]

**Warning sign:** A failed RDP connection leaves a successful wrapper exit status while a log exists. [ASSUMED: manual acceptance symptom]

### Pitfall 6: Leaking credentials while replacing the menu

**What goes wrong:** The live menu reads a password, writes a temporary X init file, embeds it in a command line, and globally enables WLog DEBUG. [VERIFIED: /usr/local/bin/menu:27-66]

**How to avoid:** Delete that password capture/generated command path; do not print `$@`, do not enable shell xtrace, create logs under a private user state directory, and forward connection arguments only to `xfreerdp3`. [VERIFIED: .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md:23-27; ASSUMED: wrapper hardening implementation]

**Warning sign:** A shell script, log, or `ps` output contains a `/p:` value or an echoed full connection command. [ASSUMED: manual security check]

### Pitfall 7: Treating a local package as a permanent security pin

**What goes wrong:** The user loses a Debian security update or assumes the local touch build remains active after an update. [VERIFIED: .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md:27-31]

**How to avoid:** Do not hold/pin; document `dpkg-query` version checks and make a source-version mismatch in the release script a deliberate rebase stop, not an automatic patch attempt. [VERIFIED: `dpkg --compare-versions`, 2026-08-08; ASSUMED: release-script failure behavior]

**Warning sign:** Installed `freerdp3-x11` no longer has the exact `+onemix1` suffix. [VERIFIED: .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md:27-31]

## Code Examples

### Existing CLI values the wrapper must compose

<!-- DATA_Q8M4Z1KP_START -->
The pinned CLI declarations quote the only Phase 4 touch options and defaults:

```text
{ "touch-long-press", COMMAND_LINE_VALUE_REQUIRED, "<ms>", NULL, NULL, -1, NULL,
  "Long-press duration in ms for right-click (default 600)" },
{ "touch-pinch-wheel-fallback", COMMAND_LINE_VALUE_BOOL, NULL, BoolValueFalse, NULL, -1, NULL,
  "Send Ctrl+Wheel instead of RDPEI zoom on pinch" },
{ "touch-slop", COMMAND_LINE_VALUE_REQUIRED, "<px>", NULL, NULL, -1, NULL,
  "Dead-zone radius in px to suppress touch jitter (default 8)" },
```
<!-- DATA_Q8M4Z1KP_END -->

[VERIFIED: build/freerdp3-3.15.0+dfsg/client/common/cmdline.h:497-502]

### Diagnostic logger shape

<!-- DATA_T6R9V2LX_START -->
```c
/* [ASSUMED] Proposed helper name; keep it local to the translation unit. */
if (touch_diag_enabled)
    WLog_WARN(TAG, "touch event=%s id=%d x=%d y=%d", event_name, touch_id, x, y);
```
<!-- DATA_T6R9V2LX_END -->

Use this shape only at existing touch/gesture/RDPEI decision seams; it changes observability, not gesture flow. `WLog_WARN` is an existing macro and default-console WARN records go to stderr. [VERIFIED: build/freerdp3-3.15.0+dfsg/winpr/include/winpr/wlog.h:284-293; build/freerdp3-3.15.0+dfsg/winpr/libwinpr/utils/wlog/ConsoleAppender.c:112-136; ASSUMED: `touch_diag_enabled` name and compact fields]

### Diagnostic wrapper pipeline with truthful exit status

<!-- DATA_N3C7H5YW_START -->
```bash
# [ASSUMED] Bash wrapper branch after validation and private log creation.
/usr/bin/xfreerdp3 "${touch_args[@]}" "$@" 2>&1 | tee "$log_path"
exit "${PIPESTATUS[0]}"
```
<!-- DATA_N3C7H5YW_END -->

The installed executable path is backed by the Debian package install list, and the Bash runtime check proved that pipeline status is otherwise reported as `tee` success rather than the first command's failure. [VERIFIED: build/freerdp3-3.15.0+dfsg/debian/freerdp3-x11.install:1; Bash runtime pipeline check, 2026-08-08]

### Clean patch application/build sequence

<!-- DATA_P5D8L2QS_START -->
```bash
QUILT_PATCHES=debian/patches quilt push
dpkg-buildpackage -us -uc -b -j"$(nproc)"
```
<!-- DATA_P5D8L2QS_END -->

Use it only in the new source tree after the release script has copied the project patch, appended its one name to `debian/patches/series`, and verified the changelog version. [CITED: https://www.debian.org/doc/manuals/maint-guide/modify; CITED: https://www.debian.org/doc/manuals/debmake-doc/ch13.en.html; VERIFIED: scripts/build-baseline.sh:57-67]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Global `WLOG_LEVEL=DEBUG` in a full handwritten menu command. [VERIFIED: /usr/local/bin/menu:44-60] | `FREERDP_TOUCH_DIAG=1` gates only compact touch records and lets WLog WARN use stderr. [ASSUMED: Phase 4 implementation recommendation] | Phase 4 | Diagnostics become opt-in, focused, and safe to tee without broad debug noise. [ASSUMED: expected impact] |
| Ignored mutable source tree is the only carrier of touch changes. [VERIFIED: .gitignore:1-11; clean-tree diff inventory, 2026-08-08] | One quilt patch applies to a newly extracted pinned source tree. [CITED: https://www.debian.org/doc/manuals/debmake-doc/ch13.en.html] | Phase 4 | The release is reproducible and reviewable without committing generated source/build output. [ASSUMED: expected impact] |
| Menu captures a password and writes a full RDP command to a temporary X init script. [VERIFIED: /usr/local/bin/menu:27-66] | Menu delegates to a credential-free wrapper; FreeRDP receives caller-provided connection/session arguments. [ASSUMED: Phase 4 implementation recommendation] | Phase 4 | Password handling is returned to FreeRDP and no release artifact contains a stored secret. [ASSUMED: expected impact] |
| Treating `freerdp3-x11` as the sole package artifact. [VERIFIED: scripts/build-baseline.sh:60-67] | Explicit X11 + client + core + winpr runtime closure with checksums. [VERIFIED: dpkg-deb metadata inspection, 2026-08-08] | Phase 4 | The local package versions remain dependency-consistent. [ASSUMED: expected impact] |

**Deprecated/outdated for this phase:**

- The live menu's direct build-tree executable and `WLOG_LEVEL=DEBUG` command are obsolete release mechanisms. [VERIFIED: /usr/local/bin/menu:44-60]
- Native multitouch/RDPEI forwarding as the daily touch mode is out of scope despite older planning text. [VERIFIED: .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md:18-21; .planning/STATE.md:63-65]
- Any `/touch-pan-deadband` release option is stale; the current CLI declaration has only long-press, pinch-wheel-fallback, and slop entries in this area. [VERIFIED: build/freerdp3-3.15.0+dfsg/client/common/cmdline.h:497-502]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Use proposed paths `patches/onemix-touch.patch`, `scripts/build-release.sh`, `scripts/launch-touch.sh`, `README.md`, and generated `dist/`. | Recommended Project Structure | Planner must rename/repoint scripts and documentation; no product behavior risk. |
| A2 | Use `FREERDP_TOUCH_LONG_PRESS_MS` and `FREERDP_TOUCH_SLOP_PX` as the two wrapper override names. | Pattern 3 | Documentation/wrapper names could differ from user preference. |
| A3 | Accept a conservative slop range of `4`–`16` px. | Pattern 3 | Too narrow rejects a useful calibration; too broad can make drag activation feel wrong. |
| A4 | Emit enabled diagnostics at WARN to obtain default stderr routing without global debug. | Pattern 2 | Records will be semantically labeled WARN; a tag-specific appender design would be needed only if that presentation is unacceptable. |
| A5 | D-10 means the minimal runnable closure (`libwinpr3-3`, `libfreerdp3-3`, `libfreerdp-client3-3`, `freerdp3-x11`), not a development-SDK release. | Existing Source-to-Package Map | If the user expects an installable modified SDK, its larger exact dependency closure needs an explicit separate bundle. |
| A6 | A user-managed native FreeRDP connection argument/file is an acceptable non-secret handoff for menu option 3. | Open Questions | RESOLVED by D-22/D-23: the menu preserves the TTY password prompt and passes connection args (including /p:$PASS) through the wrapper as opaque arguments. |

## Open Questions (RESOLVED)

1. **How should `/usr/local/bin/menu` receive the user's connection/session arguments after its credential-bearing command is removed?**
   - **RESOLVED (D-22, D-23):** The menu preserves the current interaction and startup flow. It still prompts for the password with `read -s` and passes it as `/p:$PASS` through the wrapper as an opaque argument to `/usr/bin/xfreerdp3`. The wrapper does not own, store, or persist credentials; it forwards connection/session arguments unchanged via `"$@"`. The menu delegates only the FreeRDP invocation (touch options + installed binary) to the wrapper. No new parser, credential store, or duplicate command is introduced. [VERIFIED: /usr/local/bin/menu:27-66; .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md D-22, D-23]

2. **Must the TTY-only `startx`/rotation path be preserved as part of menu option 3?**
   - **RESOLVED (D-22):** Yes. The user operates FreeRDP only from a TTY; `startx` is mandatory. The canonical operating flow is TTY → startx → rotation → wrapper → installed `/usr/bin/xfreerdp3`. The menu preserves the TTY password prompt, `startx`, display/touch rotation (`xrandr` + `xinput`), and existing connection/session behavior. The xinitrc calls the wrapper instead of the raw build-tree binary and sets `XDG_SESSION_TYPE=x11` so the native-X11 gate passes in the startx session. Do not replace this with a GNOME-on-Xorg or direct-desktop launch path. [VERIFIED: .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md D-22, D-23]

## Environment Availability

| Dependency | Required By | Available | Version / Evidence | Fallback |
|------------|-------------|-----------|--------------------|----------|
| `dpkg-source`, `dpkg-buildpackage`, `dpkg-deb`, `dpkg-query` | Fresh source, build, package inspection, install proof | Yes | `dpkg` tools `1.22.22`; a clean extraction succeeded. [VERIFIED: local command audit, 2026-08-08] | — |
| FreeRDP build dependencies | Package rebuild | Yes | `dpkg-checkbuilddeps` reports satisfied. [VERIFIED: local command audit, 2026-08-08] | — |
| `quilt` | Required creation/application of the locked quilt patch | No | No executable; configured APT candidate is `0.68-1`. [VERIFIED: `command -v quilt`; `apt-cache policy quilt`, 2026-08-08] | Install `quilt`; no compatible custom-tool fallback is allowed. [CITED: https://manpages.debian.org/trixie/quilt/quilt.1.en.html] |
| Bash, `mktemp`, `tee`, `sha256sum` | Wrapper logging, safe log creation, checksums | Yes | Bash `5.2.37`; coreutils `9.7`. [VERIFIED: local command audit, 2026-08-08] | — |
| `/usr/bin/xfreerdp3` | Wrapper target and post-install verification | Yes | Installed binary resolves at `/usr/bin/xfreerdp3`; it reports FreeRDP `3.15.0`. [VERIFIED: `command -v xfreerdp3`; local command audit, 2026-08-08] | — |
| Native X11 session | Hardware install/UAT and daily touch operation | Not certified from this research shell | Existing gate requires XDG session `x11`, no Wayland socket, Xorg, and no Xwayland. [VERIFIED: scripts/check-x11-session.sh:24-34] | None — switch to GNOME on Xorg and rerun the gate. [VERIFIED: scripts/check-x11-session.sh:25-32] |
| `startx`, `xrandr`, `xinput` | Existing menu/startup path and manual diagnostics | Present, but `startx` needs a console session | Paths resolve under `/usr/bin`; this non-console shell was refused by `Xorg.wrap`. [VERIFIED: command-path and availability audit, 2026-08-08] | Perform this part only in the real operator session. |

**Missing dependencies with no fallback:**
- `quilt` must be installed before creating or applying the mandated quilt patch. [VERIFIED: `command -v quilt`, 2026-08-08]

**Missing dependencies with fallback:**
- None. [VERIFIED: local tool/dependency audit, 2026-08-08]

## Requirement Verification Checklist

| Requirement | Automated / static evidence | Required manual evidence |
|-------------|-----------------------------|--------------------------|
| DIAG-01 | Build succeeds with the gate in both X11 and RDPEI translation units; unset diagnostic run has no new diagnostic prefix; `FREERDP_TOUCH_DIAG=1` log has ingress, transition, synthesized-output, cleanup, and conditional frame records. [ASSUMED: exact log prefix and verification script] | Native-X11 touch session confirms normal launch stays quiet and diagnostic launch creates one private timestamped log while showing the same stream in the terminal. [VERIFIED: .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md:22-27] |
| PACK-01 | Run the release script twice from fresh extraction; assert pinned base before patching, local version after patching, `quilt push` success, classifier model pass, explicit package metadata, and `sha256sum -c SHA256SUMS`. [CITED: https://www.debian.org/doc/manuals/debmake-doc/ch13.en.html; VERIFIED: build/freerdp3-3.15.0+dfsg/client/X11/test_scroll_classifier.c:1-129] | Inspect `dist/` contains only the explicit runtime package files plus `SHA256SUMS`, with no source tree or broad package glob. [VERIFIED: .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md:29-35] |
| PACK-02 | Verify checksums and record package name/version before and after each APT transaction. [VERIFIED: scripts/build-baseline.sh:70-75; scripts/build-baseline.sh:118-161] | Install explicit local runtime artifacts, connect once, roll back explicit stock runtime packages with `apt install --reinstall` (and trixie fallback if needed), verify package versions, then launch stock using mouse-only/direct FreeRDP arguments. [CITED: https://manpages.debian.org/trixie/apt/apt-get.8.en.html; ASSUMED: expanded explicit rollback closure] |
| CONF-01 | Run wrapper syntax check; exercise valid defaults, valid overrides, non-integer rejection, out-of-range rejection, normal composition, diagnostic composition, and `--mouse-only` omission with a test executable. [ASSUMED: wrapper test harness] | Confirm canonical command has no `+multitouch`, local gestures match the frozen release candidate, and mouse-only mode remains usable without package rollback. [VERIFIED: .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md:18-21; .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md:43-48] |

## Security Domain

**Security enforcement is enabled and ASVS level 1 is configured. [VERIFIED: .planning/config.json:45-49] This is a scoped implementation-control map, not a claim of complete ASVS certification. [ASSUMED]**

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | Yes, by non-interference | Remove the menu's shell password capture; leave authentication to FreeRDP and do not log/pass `/p:` values through wrapper diagnostics. [VERIFIED: /usr/local/bin/menu:27-66; .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md:43-48] |
| V3 Session Management | No new session implementation | Forward opaque connection/session arguments; do not create a credential cache, token store, or new reconnect policy. [VERIFIED: .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md:43-48] |
| V4 Access Control | No new authorization boundary | Keep package install/rollback as explicit user `sudo apt` operations and do not add a privileged daemon/service. [VERIFIED: scripts/build-baseline.sh:118-154; .claude/CLAUDE.md:85-94] |
| V5 Input Validation | Yes | Validate only the two numeric calibration overrides before command execution; use Bash arrays and `"$@"`, never `eval` or string-built shell commands. [VERIFIED: .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md:36-42; ASSUMED: wrapper implementation] |
| V6 Cryptography | No new cryptography | Do not implement crypto; rely on the installed FreeRDP connection behavior and do not copy the old command's certificate/credential options into committed artifacts. [VERIFIED: /usr/local/bin/menu:44-60; .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md:43-48] |

### Known Threat Patterns for this Phase

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Password or full connection command enters a committed file, temp script, terminal echo, or diagnostic log | Information Disclosure | Do not read/store password values in menu/wrapper; do not echo `$@`; no shell xtrace; create diagnostic directory/file under `umask 077`; use `mktemp`. [VERIFIED: /usr/local/bin/menu:27-66; ASSUMED: wrapper hardening implementation] |
| Malformed calibration environment value changes client behavior or becomes a shell injection vector | Tampering | Accept digits only, range-check before launch, retain array-separated arguments, and reject instead of coercing. [VERIFIED: build/freerdp3-3.15.0+dfsg/client/common/cmdline.c:1174-1193; ASSUMED: wrapper validation implementation] |
| Wrong/stale local package bundle mixes patched and stock libraries | Tampering / Denial of Service | Check exact `.deb` package/version/dependency metadata, install the explicit closure atomically, and verify checksums before install. [VERIFIED: dpkg-deb metadata inspection, 2026-08-08; ASSUMED: release script checks] |
| Local package blocks a Debian security update | Denial of Service / Tampering | No APT hold/pin; document suffix detection and explicit rebase workflow. [VERIFIED: `dpkg --compare-versions`, 2026-08-08; .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md:27-31] |
| Diagnostic records expose credentials | Information Disclosure | Limit fields to event IDs, coordinates, state/output, frame count/offset/status; never log command arguments or FreeRDP credential material. [VERIFIED: .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md:22-27; ASSUMED: field schema] |

## Sources

### Primary (HIGH confidence)

- Local pinned Debian source and package metadata — X11 ownership, WLog behavior, RDPEI send boundary, CMake target map, Debian package split, and current command-line switches were read directly in this session. [VERIFIED: build/freerdp3-3.15.0+dfsg/client/X11/xf_input.c:1091-1754; build/freerdp3-3.15.0+dfsg/channels/rdpei/client/rdpei_main.c:160-213]
- Local Phase 4 context, requirements, state, baseline script, and native-X11 gate — locked scope, package lifecycle, and current project decisions. [VERIFIED: .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md:6-136; .planning/REQUIREMENTS.md:16-52; .planning/STATE.md:50-82]
- Local package/runtime checks — exact source and installed versions, package dependency metadata, clean-tree diff, classifier compilation, and tool availability. [VERIFIED: local command audits, 2026-08-08]

### Secondary (MEDIUM confidence)

- [Debian Maintainer's Guide — modifying source](https://www.debian.org/doc/manuals/maint-guide/modify) — `quilt new`, `add`, and `refresh` workflow. [CITED: https://www.debian.org/doc/manuals/maint-guide/modify]
- [Debian debmake tool usage](https://www.debian.org/doc/manuals/debmake-doc/ch13.en.html) — `3.0 (quilt)` extraction/series application and package build relation. [CITED: https://www.debian.org/doc/manuals/debmake-doc/ch13.en.html]
- [Debian Policy: Version control field](https://www.debian.org/doc/debian-policy/ch-controlfields.html) — package version grammar and ordering. [CITED: https://www.debian.org/doc/debian-policy/ch-controlfields.html]
- [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir/latest/) — `XDG_STATE_HOME` and `$HOME/.local/state` default for persistent state/logs. [CITED: https://specifications.freedesktop.org/basedir/latest/]
- [APT `apt-get(8)`](https://manpages.debian.org/trixie/apt/apt-get.8.en.html) — `install --reinstall`, repository selection, and explicit distribution selection. [CITED: https://manpages.debian.org/trixie/apt/apt-get.8.en.html]
- [quilt(1)](https://manpages.debian.org/trixie/quilt/quilt.1.en.html) — patch/series semantics. [CITED: https://manpages.debian.org/trixie/quilt/quilt.1.en.html]

### Tertiary (LOW confidence)

- Proposed script/documentation paths, override names, slop bounds, and log prefix/field order are deliberately marked `[ASSUMED]` pending the planner's implementation choice. The menu argument handoff and TTY/startx flow are now resolved (D-22, D-23). [VERIFIED: .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md D-22, D-23]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — pinned source, installed tools, package metadata, and build dependencies were checked locally; `quilt` is the one explicit missing prerequisite. [VERIFIED: local command audits, 2026-08-08]
- Architecture: HIGH — source ownership, package closure, and menu/startx handoff are all resolved (D-22, D-23). [VERIFIED: /usr/local/bin/menu:27-66; .planning/phases/04-diagnostics-packaging-launch-configuration/04-CONTEXT.md D-22, D-23]
- Pitfalls: HIGH — the logger level/routing, frame debug guard, local-only routing, package dependencies, and menu secret exposure were read from the exact target sources. [VERIFIED: build/freerdp3-3.15.0+dfsg/winpr/libwinpr/utils/wlog/ConsoleAppender.c:112-136; build/freerdp3-3.15.0+dfsg/channels/rdpei/client/rdpei_main.c:587-667; /usr/local/bin/menu:27-66]

**Research date:** 2026-08-08  
**Valid until:** Earlier of a Debian `freerdp3` source update or 30 days. [ASSUMED: review cadence]

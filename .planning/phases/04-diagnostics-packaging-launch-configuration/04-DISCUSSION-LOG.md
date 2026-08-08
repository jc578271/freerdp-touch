# Phase 4: Diagnostics, Packaging & Launch Configuration - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-08
**Phase:** 4-Diagnostics, Packaging & Launch Configuration
**Areas discussed:** Diagnostic workflow, Package identity, Calibration surface, Launch entry point

**User clarification applying to every area:** Do not bring native multitouch back. The current source behavior is working very well and Phase 4 must preserve it.

---

## Diagnostic workflow

### Activation mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| `FREERDP_TOUCH_DIAG` | Dedicated environment variable enables only the required touch/gesture trace; normal launch remains quiet without global WLog debug noise. | ✓ |
| `WLOG_LEVEL=DEBUG` | Reuse the existing global mechanism with almost no new control, but include large amounts of unrelated FreeRDP output. | |
| Diagnostic wrapper | Expose only a separate diagnostic script and hide the environment switch from the user. | |

**User's choice:** `FREERDP_TOUCH_DIAG`
**Notes:** The dedicated gate is canonical; global `WLOG_LEVEL=DEBUG` is not required for touch diagnostics.

### Output destination

| Option | Description | Selected |
|--------|-------------|----------|
| Terminal + file | Write through stderr and use `tee` in the diagnostic launch so output is visible live and retained in a timestamped file. | ✓ |
| Terminal only | Keep the implementation smallest and require manual redirection when evidence must be saved. | |
| File only | Reduce terminal noise but lose live feedback during hardware testing. | |

**User's choice:** Terminal + file
**Notes:** One stream should feed both destinations; do not implement two logging paths.

### Trace detail

| Option | Description | Selected |
|--------|-------------|----------|
| Compact full trace | One concise record for every touch lifecycle event plus gesture decisions, synthesized outputs, and RDPEI frame information when present. | ✓ |
| Classifier internals | Include distance, midpoint, accumulator, and threshold values on every update, producing much larger logs. | |
| Two verbosity levels | Add basic/deep diagnostic values for flexibility, at the cost of another configuration branch. | |

**User's choice:** Compact full trace
**Notes:** A single useful diagnostic level is sufficient for v1.

### Log location

| Option | Description | Selected |
|--------|-------------|----------|
| XDG state dir | Store timestamped logs under `${XDG_STATE_HOME:-$HOME/.local/state}/freerdp-touch/`. | ✓ |
| Home directory | Place logs directly under the user's home directory for visibility. | |
| Current directory | Store logs wherever the launcher is invoked, risking inconsistent locations or files inside the repo. | |

**User's choice:** XDG state dir
**Notes:** Diagnostic output stays outside the source tree and version control.

---

## Package identity

### Local version

| Option | Description | Selected |
|--------|-------------|----------|
| `+onemix1` suffix | Build `3.15.0+dfsg-2.1+deb13u3+onemix1`: clearly identifies the patch, outranks the current stock package, and remains lower than a future `deb13u4`. | ✓ |
| Same Debian version | Replace the package without a distinct version, making installed-build identification and apt behavior less clear. | |
| Custom epoch/version | Force the local package to dominate future apt versions, potentially blocking security updates. | |

**User's choice:** `+onemix1` suffix
**Notes:** The suffix identifies the local rebuild without permanently outranking future Debian revisions.

### Debian upgrades

| Option | Description | Selected |
|--------|-------------|----------|
| Security update wins | Allow a newer Debian package to replace the local build, then rebase/rebuild the touch patch on the new source. | ✓ |
| Hold patched package | Use `apt-mark hold` so touch behavior remains until manually rebuilt, at the cost of delayed security fixes. | |
| APT pin local build | Add persistent apt pinning, increasing configuration and maintenance burden. | |

**User's choice:** Security update wins
**Notes:** Documentation must make replacement detectable and explain the rebuild path.

### Build workflow

| Option | Description | Selected |
|--------|-------------|----------|
| One build script | Verify the base version, apply quilt, build, and report artifacts/checksums in one reproducible command; document the underlying commands. | ✓ |
| Documented commands | Provide only manual quilt and `dpkg-buildpackage` commands. | |
| Extend baseline script | Merge the patched release into the Phase 1 unmodified-baseline pipeline, blurring the locked baseline/release boundary. | |

**User's choice:** One build script
**Notes:** Keep `scripts/build-baseline.sh` focused on the unmodified proof cycle.

### Retained artifacts

| Option | Description | Selected |
|--------|-------------|----------|
| Exact debs + checksums | Put the exact required `.deb` set and `SHA256SUMS` in a gitignored `dist/`; commit only source patch, scripts, and docs. | ✓ |
| `xfreerdp` deb only | Retain only `freerdp3-x11`, which may omit modified shared-library packages. | |
| Commit binary packages | Store generated `.deb` files in git for direct retrieval. | |

**User's choice:** Exact debs + checksums
**Notes:** Planner must determine package ownership/dependencies from the actual modified files; no broad package glob.

---

## Calibration surface

### Exposed controls

| Option | Description | Selected |
|--------|-------------|----------|
| 600 ms + 8 px only | Expose only existing long-press duration and slop controls; keep the working pinch/scroll classifier fixed. | ✓ |
| Add classifier knobs | Add configuration for pinch ratio, pan threshold, and wheel step, touching stable source and increasing misconfiguration risk. | |
| No visible knobs | Hard-code even the two required hardware calibration values. | |

**User's choice:** 600 ms + 8 px only
**Notes:** This directly reinforces the user's instruction not to disturb the working recognizer.

### Override mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| Wrapper env vars | Read two optional environment values and map them to the existing FreeRDP CLI options; no new parser or settings format. | ✓ |
| Edit command args | Require users to edit `/touch-long-press` and `/touch-slop` values directly in a script or menu command. | |
| Separate config file | Introduce a persistent calibration file and parser. | |

**User's choice:** Wrapper env vars
**Notes:** Exact variable names remain an implementation detail.

### Invalid values

| Option | Description | Selected |
|--------|-------------|----------|
| Validate and fail | Accept documented integer ranges and stop before launch with a clear error when invalid. | ✓ |
| Any positive integer | Pass all positive values through, including values that make touch behavior unusable. | |
| Clamp silently | Force values into a range without telling the user their input was wrong. | |

**User's choice:** Validate and fail
**Notes:** Long press uses the requirement's 500–700 ms range; planner chooses a conservative documented slop range around 8 px.

### Daily behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Defaults unless env set | Launch silently with 600 ms/8 px and apply overrides only when explicitly present. | ✓ |
| Prompt every launch | Ask for calibration values every time menu option 3 runs. | |
| Multiple fixed presets | Add unverified sensitive/default/steady modes to the menu. | |

**User's choice:** Defaults unless env set
**Notes:** Daily use remains one-step and non-interactive.

---

## Launch entry point

### Menu integration

| Option | Description | Selected |
|--------|-------------|----------|
| Repo wrapper | Menu option 3 calls a credential-free wrapper maintained in the repo; one artifact owns the touch preset. | ✓ |
| Full command in menu | Keep the complete FreeRDP command directly in `/usr/local/bin/menu`, outside project versioning. | |
| Docs only | Provide a command for manual copying without connecting the existing menu entry to a project artifact. | |

**User's choice:** Repo wrapper
**Notes:** Menu option 3 remains the daily entry but must not become a second source of preset truth.

### Connection and credentials

| Option | Description | Selected |
|--------|-------------|----------|
| Pass-through, no secrets | Wrapper adds touch arguments and passes caller-supplied FreeRDP connection arguments through; it stores no credentials. | ✓ |
| User-local profile | Add an external permission-restricted profile for host/user while still prompting for password. | |
| Environment credentials | Read host, user, and password from environment variables for automation. | |

**User's choice:** Pass-through, no secrets
**Notes:** Password handling remains with existing FreeRDP mechanisms; committed artifacts must never copy the current machine-local credential-bearing launcher.

### Mouse-only escape hatch

| Option | Description | Selected |
|--------|-------------|----------|
| `--mouse-only` flag | Use the same wrapper and connection arguments but omit all local touch activation/calibration options. | ✓ |
| Separate raw command | Maintain a second full FreeRDP command without touch options. | |
| Environment mode | Select mouse behavior through a less-visible environment value. | |

**User's choice:** `--mouse-only` flag
**Notes:** Mouse-only is a mode of the patched binary, not package rollback.

### Diagnostic entry

| Option | Description | Selected |
|--------|-------------|----------|
| Same wrapper + env | Run `FREERDP_TOUCH_DIAG=1` through the canonical wrapper; it creates and tees the timestamped log. | ✓ |
| `--diagnostics` flag | Add a second public activation mechanism that internally sets the environment gate. | |
| Separate diag wrapper | Duplicate launch plumbing in a dedicated diagnostic script. | |

**User's choice:** Same wrapper + env
**Notes:** Normal and diagnostic launch composition cannot drift.

---

## Claude's Discretion

No explicit “you decide” answer was selected. CONTEXT.md leaves only low-level reversible details open: filenames, calibration environment variable names, conservative slop range, compact log field ordering, and exact generated package set/order after package analysis.

## Deferred Ideas

None. Native multitouch restoration and additional classifier tuning were explicitly excluded rather than added to Phase 4.

# Phase 1: Environment Gate & Build Baseline - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-05
**Phase:** 1-Environment Gate & Build Baseline
**Areas discussed:** Gate strictness, Baseline artifact, Source workspace, Proof depth

---

## Gate strictness

### Behavior outside native X11

| Option | Description | Selected |
|--------|-------------|----------|
| Hard fail, no override | Print the detected session and exact “GNOME on Xorg” remediation, then exit nonzero before baseline/build work. This matches BASE-01 most directly. | ✓ |
| Block runtime only | Allow source fetch/build and documentation, but block install, launch, and testing until native X11 is active. | |
| Allow explicit force | Fail by default but accept a clearly named override for non-runtime work; more flexible, but easier to misuse and trust invalid results. | |

**User's choice:** Hard fail, no override
**Notes:** None.

### Dependency from later commands

| Option | Description | Selected |
|--------|-------------|----------|
| Run gate every time | Each capture/build/install/test entry point calls the same small check first. No stale “passed earlier” state and no separate step to remember. | ✓ |
| Manual check once | Document one prerequisite command, then trust the developer to run it before later commands. Smallest implementation, but easy to bypass accidentally. | |
| Reuse pass marker | Write a successful-check marker that later commands consume. Faster to rerun, but the marker can outlive a session change. | |

**User's choice:** Run gate every time
**Notes:** None.

### Gate scope

| Option | Description | Selected |
|--------|-------------|----------|
| X11 only | Fail only when native X11 cannot be proven. Device, tools, source, and build dependencies are checked by their own steps with specific errors. | ✓ |
| X11 plus touchscreen | Also block if no direct-touch XInput2 device is detected, since later phases cannot be validated without it. | |
| Full preflight | Also require the touchscreen, capture tools, source package, build dependencies, and target command before any Phase 1 work begins. | |

**User's choice:** X11 only
**Notes:** Other prerequisites receive separate checks rather than expanding the hard session gate.

### Successful output

| Option | Description | Selected |
|--------|-------------|----------|
| One-line pass | Print the verified session type and display, then continue. Keep full diagnostics for failures and the separate baseline report. | ✓ |
| Silent success | Exit 0 with no output; shortest, but gives no visible confirmation that the gate ran. | |
| Full evidence every run | Print all session-detection evidence each time. Auditable, but noisy because every Phase 1 entry point reruns the gate. | |

**User's choice:** One-line pass
**Notes:** None.

---

## Baseline artifact

### Artifact format

| Option | Description | Selected |
|--------|-------------|----------|
| Single Markdown report | One dated, readable file containing command outputs and short manual fields. It is easy to review, diff, and hand to later phases. | ✓ |
| Summary plus raw logs | A short Markdown index plus separate untouched outputs per command. Preserves raw evidence but creates more files and bookkeeping. | |
| Plain text transcript | Capture one terminal-style log with minimal formatting. Smallest generator, but harder for later agents and humans to navigate. | |

**User's choice:** Single Markdown report
**Notes:** None.

### Non-discoverable inputs

| Option | Description | Selected |
|--------|-------------|----------|
| Require explicit inputs | Auto-capture machine facts, but require the developer to provide the launch command and a target description when generating the report; no guessing or shell-history scraping. | ✓ |
| Prompt interactively | Ask for the missing values during capture. Friendly for one-off use, but harder to rerun non-interactively. | |
| Leave placeholders | Generate the report with TODO fields to fill later. Simplest capture script, but it can produce an incomplete baseline. | |

**User's choice:** Require explicit inputs
**Notes:** The current launch command and Windows target description must be supplied deliberately.

### Git tracking

| Option | Description | Selected |
|--------|-------------|----------|
| Commit a sanitized report | Keep evidence available to later phases while stripping passwords, tokens, usernames, hostnames/IPs, and other identifying values. | ✓ |
| Keep it local only | Commit only the capture tool/template and gitignore the generated report. Best privacy, but later agents may not have the evidence. | |
| Commit summary only | Track non-sensitive conclusions and keep detailed command output local. More bookkeeping than one report, but limits exposure. | |

**User's choice:** Commit a sanitized report
**Notes:** None.

### Sanitized content

| Option | Description | Selected |
|--------|-------------|----------|
| Keep technical, redact identity | Preserve package versions, session/WM data, display settings, and touchscreen model/capabilities; replace credentials, usernames, hostnames, IPs, and certificates with labels. | ✓ |
| Keep target host and user | Strip secrets but retain remote hostname/IP and username for exact reproducibility. Useful locally, unsafe if the repository is shared. | |
| Redact all identifiers | Also hide touchscreen/device names and local host details. Highest privacy, but weakens hardware-baseline usefulness. | |

**User's choice:** Keep technical, redact identity
**Notes:** None.

---

## Source workspace

### Source acquisition

| Option | Description | Selected |
|--------|-------------|----------|
| Fetch exact Debian source | A documented command fetches the pinned source version from configured Debian source repositories, then verifies the resolved version before proceeding. | ✓ |
| Require supplied archives | Stop unless the matching `.dsc` and tarballs have been placed locally. Supports offline work, but setup remains manual. | |
| Commit source archives | Store the Debian source archives in this repository. Self-contained, but adds large third-party files and duplicated package history. | |

**User's choice:** Fetch exact Debian source
**Notes:** The repository did not contain the archives that earlier research expected.

### Workspace location

| Option | Description | Selected |
|--------|-------------|----------|
| Ignored repo workspace | Use one predictable directory under the project, excluded from git. Commands and later phases can find it without committing generated files. | ✓ |
| Sibling directory | Keep source/build trees next to the repository. Cleaner git tree, but paths become less portable and easier to lose. | |
| Fresh temporary directory | Create everything under `/tmp` for each run. Clean by default, but expensive builds and evidence disappear between sessions. | |

**User's choice:** Ignored repo workspace
**Notes:** None.

### Version mismatch

| Option | Description | Selected |
|--------|-------------|----------|
| Hard fail on mismatch | Do not silently build another release. Report expected versus found and require restoring the exact source or deliberately updating project decisions. | ✓ |
| Allow same upstream 3.15 | Accept another Debian revision of FreeRDP 3.15 after warning. More convenient, but the baseline no longer matches the installed package exactly. | |
| Accept newest available | Continue with the repository’s current source version. Easiest setup, but defeats the pinned-baseline requirement. | |

**User's choice:** Hard fail on mismatch
**Notes:** Expected version is `3.15.0+dfsg-2.1+deb13u3`.

### Handoff to patch development

| Option | Description | Selected |
|--------|-------------|----------|
| Re-unpack a clean tree | Treat the baseline tree as disposable evidence and unpack fresh from the verified source before patching. No reset logic or doubt about leftover build changes. | ✓ |
| Reuse the same tree | Continue in place after the baseline build. Saves disk and fetch time, but risks carrying generated or accidental changes into the patch. | |
| Keep pristine and patch copies | Maintain two unpacked trees side by side. Clear comparison, but doubles workspace and lifecycle bookkeeping. | |

**User's choice:** Re-unpack a clean tree
**Notes:** None.

---

## Proof depth

### Install and rollback execution

| Option | Description | Selected |
|--------|-------------|----------|
| Perform the full cycle | Build the unmodified `.deb`, install that exact artifact, smoke-test it, reinstall the stock package, and verify the stock client still launches. | ✓ |
| Pause for user commands | Prepare and verify commands up to each privileged step, then require the user to run install and rollback manually before Phase 1 can pass. | |
| Documentation only | Document install and rollback without executing them. Safest during development, but does not satisfy the roadmap’s verified rollback criterion. | |

**User's choice:** Perform the full cycle
**Notes:** Execution may still require normal confirmation at privileged steps; the phase cannot pass until the cycle is actually completed.

### RDP launch success

| Option | Description | Selected |
|--------|-------------|----------|
| Desktop plus basic input | Reach the Windows desktop, confirm ordinary keyboard and mouse input, then disconnect cleanly. Record no touch conclusions yet. | ✓ |
| Connection screen only | Starting the client and reaching authentication is enough. Faster, but does not prove a usable session against the target. | |
| Extended baseline session | Use the session for a longer stability check with several applications. More evidence, but overlaps later stability phases. | |

**User's choice:** Desktop plus basic input
**Notes:** Phase 1 makes no touch assertions.

### Window modes

| Option | Description | Selected |
|--------|-------------|----------|
| Windowed and fullscreen | Connect once in each mode and confirm clean entry/exit with keyboard and mouse. This creates a useful pre-patch comparison for later phases. | ✓ |
| Current launch mode only | Test only the mode used by the existing launch command. Minimal, but leaves the other mode without a known-good baseline. | |
| Windowed only | Avoid fullscreen/grab disruption during baseline setup. Later phases would establish fullscreen behavior separately. | |

**User's choice:** Windowed and fullscreen
**Notes:** None.

### Retained evidence

| Option | Description | Selected |
|--------|-------------|----------|
| Versions, checksum, results | Record before/during/after package versions, built artifact path and SHA-256, install/rollback command results, and explicit pass/fail notes for both launch modes. | ✓ |
| Checked command list | Record only that each documented command completed. Shorter, but weaker when diagnosing which artifact was installed. | |
| Include visual evidence | Also store screenshots or recordings of the connected sessions. Strong proof, but adds sensitive files and is unnecessary for this baseline. | |

**User's choice:** Versions, checksum, results
**Notes:** Screenshots and recordings are intentionally excluded.

---

## Claude's Discretion

- Exact script names, report layout, ignored workspace directory name, command composition, and formatting.

## Deferred Ideas

None.

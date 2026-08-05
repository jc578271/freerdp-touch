# Phase 1: Environment Gate & Build Baseline - Context

**Gathered:** 2026-08-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 1 proves the development environment and the unmodified Debian package lifecycle before any touch behavior is changed. It delivers a fail-closed native-X11 prerequisite check, a sanitized machine/package baseline, an exact-version Debian source build, an on-device install and RDP smoke test, and a verified rollback to the stock package. Touch capture, RDPEI changes, gestures, and diagnostics implementation remain outside this phase.

</domain>

<decisions>
## Implementation Decisions

### Gate strictness
- **D-01:** The prerequisite check must hard-fail with a nonzero exit when native X11 cannot be proven. Wayland and XWayland are invalid, and there is no force/override path.
- **D-02:** Every Phase 1 capture, build, install, launch, or verification entry point must rerun the same X11 gate rather than trusting a prior manual check or stored pass marker.
- **D-03:** The hard gate checks only the native-X11 session contract. Touchscreen presence, capture tools, source availability, and build dependencies use their own targeted checks and errors.
- **D-04:** A successful gate prints one concise confirmation containing the verified session type/display. Detailed evidence belongs in failure output and the baseline report.

### Baseline artifact
- **D-05:** Baseline capture produces one generated Markdown report rather than a directory of raw logs or an unstructured terminal transcript.
- **D-06:** Discoverable machine facts are captured automatically. The current launch command and Windows target description are required explicit inputs; the capture process must not scrape shell history or leave an apparently complete report with placeholders.
- **D-07:** A sanitized completed report is committed so later phases can consume the evidence.
- **D-08:** Sanitization preserves technical data needed for reproduction: package versions, session/window-manager details, display rotation/scale, and touchscreen model/capabilities. It removes or replaces credentials, usernames, hostnames, IP addresses, certificates, and other identity-bearing values.

### Source workspace
- **D-09:** Phase 1 fetches the exact Debian source package from configured Debian source repositories instead of requiring pre-positioned archives or committing third-party archives.
- **D-10:** Fetched source, unpacked trees, and build output live in one predictable project-local workspace that is excluded from git.
- **D-11:** Source acquisition hard-fails if `3.15.0+dfsg-2.1+deb13u3` is unavailable or if a different version resolves. Updating the baseline requires an explicit project decision, not an automatic fallback.
- **D-12:** The unmodified baseline tree is not reused for patch development. Later phases re-unpack a clean tree from the verified source, avoiding reset logic and accidental carry-over.

### Proof depth
- **D-13:** Phase 1 performs the full on-device cycle: build the unmodified Debian package, install that exact artifact, smoke-test it, reinstall the stock Debian package, and verify the stock client afterward. Documentation-only rollback does not pass the phase.
- **D-14:** A successful RDP smoke test reaches the Windows desktop, confirms ordinary keyboard and mouse input, and disconnects cleanly. It makes no claims about touch behavior.
- **D-15:** The smoke test covers both windowed and fullscreen client modes to establish a useful pre-patch comparison.
- **D-16:** The report records before/during/after package versions, the built artifact path and SHA-256 checksum, install and rollback command results, and explicit pass/fail notes for both launch modes. Screenshots or recordings are not required.

### Claude's Discretion
- Exact script names, report headings, ignored-workspace directory name, command composition, and formatting are left to planning, provided the decisions above remain true.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scope and acceptance
- `.planning/PROJECT.md` — Defines the project boundary, native-X11 constraint, exact-package baseline, and prohibition on touch changes before environment capture.
- `.planning/REQUIREMENTS.md` — Defines BASE-01 through BASE-03 and the milestone-wide security, packaging, and runtime boundaries.
- `.planning/ROADMAP.md` — Defines the Phase 1 goal and its three success criteria; later touch and gesture work is explicitly assigned to Phases 2–4.

### Baseline and Debian workflow
- `.planning/research/SUMMARY.md` — Consolidates the verified package version, device/session observations, phase ordering, and baseline rationale.
- `.planning/research/STACK.md` — Records the Debian source/package toolchain, native-X11 prerequisite, source acquisition/build commands, and rollback approach.
- `.planning/research/PITFALLS.md` — Documents why XWayland results are invalid and lists the environment, package, and rollback evidence needed before patching.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Debian package tooling (`apt source`, `dpkg-source`, `dpkg-buildpackage`, `apt install/reinstall`): use the platform-native package lifecycle rather than creating a custom build or rollback system.
- Existing project research under `.planning/research/`: use its pinned version and capture checklist as inputs; do not duplicate broader FreeRDP research in Phase 1.

### Established Patterns
- The project is pinned to Debian `freerdp3-x11 3.15.0+dfsg-2.1+deb13u3`; version drift is an error, not an implicit upgrade.
- Generated third-party source and build output stay outside version control; committed artifacts are small, sanitized project evidence and automation only.
- The shortest reliable path is preferred: one reusable X11 gate and one baseline report, with no new framework or dependency.

### Integration Points
- The gate must be called by every Phase 1 operational entry point.
- The baseline report is the handoff artifact consumed by Phase 2 planning and verification.
- The verified Debian source acquisition becomes the clean input from which later phases re-unpack and apply quilt patches.
- The repository currently contains no implementation scripts, FreeRDP source tree, or pinned source archives. Planning must not assume the research statement that archives are already present is still true.

</code_context>

<specifics>
## Specific Ideas

- On gate failure, identify the detected session and give the concrete remediation: log out and select the native “GNOME on Xorg” session.
- Keep successful gate output to one visible line; put detailed machine evidence in the generated report.
- Use textual/checksum evidence rather than screenshots so the committed baseline stays small and avoids leaking remote-session content.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 1-Environment Gate & Build Baseline*
*Context gathered: 2026-08-05*

---
status: resolved
trigger: "bị crash, không vào đc windows rdp"
created: 2026-08-08T09:55:25Z
updated: 2026-08-08T10:45:36Z
---

## Current Focus

hypothesis: Confirmed root cause: the former host-global Xwayland check rejected a valid tty3/startx Xorg display when GNOME Xwayland was also running.
test: Native-device verification completed through tty3: run `menu`, choose option 3, and reach the Windows RDP desktop while Xorg remains open.
expecting: Confirmed by the user: the current-DISPLAY Xorg proof permits the valid session despite unrelated GNOME Xwayland.
next_action: Commit the archived debug session and prevention-backed knowledge-base entry; leave phase4-install.sh untracked.
bug_class: bohrbug (deterministic whenever a concurrent Xwayland process exists)
reasoning_checkpoint:
  hypothesis: "The global Xwayland process check rejects a valid startx-created Xorg session because it observes an unrelated GNOME Xwayland process rather than the server that owns the current DISPLAY."
  confirming_evidence:
    - "A live Xwayland process is present while the relevant Xorg.2 log shows successful termination after about three seconds and no Xorg fatal error."
    - "With Xorg and Xwayland simulated, the real gate exits 1 with its Xwayland-specific rejection; a redacted live-menu probe proves menu routes through that gate before xfreerdp3."
    - "The active tty3 shell has WAYLAND_DISPLAY unset and XDG_SESSION_TYPE=tty, excluding an inherited Wayland socket as the earlier rejection."
  falsification_test: "A display-scoped gate run with the current DISPLAY mapped to Xorg and an unrelated Xwayland present must pass; if it fails, global-Xwayland scoping is not the sufficient mechanism."
  fix_rationale: "Identify the Xorg server that owns the current DISPLAY instead of treating any Xwayland process on the host as evidence that this client is Xwayland; this preserves rejection when the current display is not native Xorg."
  blind_spots: "The real server command-line display token is not asserted until native-device re-test; a user must still confirm an actual menu launch reaches Windows after the code fix."
  candidate_causes:
    - "code: check-x11-session.sh uses a host-global `pgrep -x Xwayland` condition instead of scoping server identity to DISPLAY."
    - "environment: GNOME's existing Xwayland process remains active while the user starts a separate Xorg on tty3."
    - "config: inherited WAYLAND_DISPLAY was considered but is absent in the active tty3 shell."
    - "data: package/loader corruption was considered but all four packages and dynamic libraries preflight successfully."
  and_gate: "yes — the observed failure needs both the globally scoped code check and the concurrent GNOME Xwayland process; the code correction removes the trigger while the environment condition remains legitimate."
tdd_checkpoint: null

## Symptoms

expected: From TTY, running menu and choosing option 3 should start native X11 and open the configured Windows RDP session with local touch gestures.
actual: After installing the four +onemix1 packages and running menu option 3, the launch crashes or exits before entering the Windows RDP session.
errors: User categorized the visible output as a startx/Xorg error; exact lines were not captured. Only the normal menu mode has been tried so far.
reproduction: Run phase4-install.sh successfully, switch to the required TTY path, run menu, choose option 3.
started: First observed during Phase 4 Plan 04-03 on-device verification after installing the +onemix1 bundle; whether the immediately previous installed build worked is unknown.

## Eliminated

- hypothesis: The installed four-package +onemix1 closure or xfreerdp3 dynamic loader causes the immediate menu exit.
  evidence: All four installed packages report the expected +onemix1 version, ldd reports no unresolved libraries, and /usr/bin/xfreerdp3 --version completes successfully in a clean environment.
  timestamp: 2026-08-08T10:13:10Z

- hypothesis: A static menu implementation defect (wrong shell, syntax error, missing wrapper delegation, non-executable files, or /tmp noexec) prevents temporary-xinitrc startup.
  evidence: /usr/local/bin/menu has a Bash shebang and passes bash -n; all required delegation/hygiene markers are present; menu, wrapper, and client are executable; /tmp is mounted without noexec.
  timestamp: 2026-08-08T10:13:10Z

- hypothesis: Xorg itself fatally crashes or cannot start.
  evidence: The preserved Xorg logs contain no fatal or EE record and each ends with "Server terminated successfully (0)"; the short display-2 session lasted about three seconds, consistent with client-side exit rather than server failure.
  timestamp: 2026-08-08T10:14:42Z

- hypothesis: An inherited WAYLAND_DISPLAY in the tty3 menu process makes the gate fail before the Xwayland process check.
  evidence: The active tty3 Bash process has WAYLAND_DISPLAY and DISPLAY unset, with XDG_SESSION_TYPE=tty. The menu does not clear the variable, but it is absent in the actual reported TTY path.
  timestamp: 2026-08-08T10:20:44Z

## Evidence

- timestamp: 2026-08-08T10:01:00Z
  checked: Project skill directories, configured gsd-debugger agent skills, and the local debug knowledge base.
  found: No project SKILL.md files, no configured gsd-debugger skills, and no .planning/debug/knowledge-base.md file were present.
  implication: No project-specific debugging rules or known-pattern candidate constrain this investigation; proceed with direct evidence gathering.

- timestamp: 2026-08-08T10:02:00Z
  checked: Initial repository-wide filtered search for menu/startx launcher artifacts.
  found: The RTK-filtered find invocation did not support -mindepth or -printf, and the search returned only top-level directories (patches, scripts, tests), not a reliable artifact inventory.
  implication: The initial scan is inconclusive; rerun the same read-only search through rtk proxy before evaluating source hypotheses.

- timestamp: 2026-08-08T10:03:00Z
  checked: Unfiltered repository inventory and a retry of the launcher-text search.
  found: The repository contains phase4-install.sh, run-rdp.sh, scripts/launch-touch.sh, scripts/check-x11-session.sh, an onemix-touch.patch, captured RDP logs, and an +onemix1 package bundle. The rtk proxy text search failed because it could not resolve rg, so it produced no source-match conclusion.
  implication: The exact option-3 path is present locally and can be reconstructed by reading its known scripts and logs; no conclusion is drawn from the failed broad search.

- timestamp: 2026-08-08T10:04:00Z
  checked: Complete phase4 installer, canonical touch launcher, native-X11 gate, and direct build-tree launch helper.
  found: phase4-install.sh only verifies and installs the four packages. launch-touch.sh gates an already-running native Xorg session, then execs /usr/bin/xfreerdp3; it does not invoke startx. run-rdp.sh is a separate direct build-tree test helper. The three captured logs exceed the Read limit.
  implication: The reported menu option must be defined outside these runtime wrappers or by user-local state; inspect Phase 4 artifacts and targeted log records before blaming the patched client.

- timestamp: 2026-08-08T10:08:01Z
  checked: Phase-4 artifact inventory and captured-log sizes.
  found: The repository contains the pending 04-03 plan, while rdp-debug-native.log has 5,032 lines, rdp-debug-gestures.log has 19,145 lines, and rdp-debug.log has 28,954 lines. A broad launcher-text search was too broad to establish a specific command or failure location.
  implication: Preserve the logs and use targeted process/error records; the next discriminating evidence is the plan's intended menu command and the logs' first fatal startup records.

- timestamp: 2026-08-08T10:09:22Z
  checked: Full 04-03 verification plan, canonical scripts, and targeted fatal/startup terms in the three preserved RDP logs.
  found: The intended daily chain is menu -> startx -> rotation -> launch-touch.sh -> installed /usr/bin/xfreerdp3. The canonical wrapper only gates native X11 and execs the client; it never starts X. The preserved logs show established RDP channel activity and shutdown-era state transitions, with no startx, xinit, Xorg, dynamic-loader, segmentation, or permission failure record.
  implication: The captured RDP logs do not reproduce the reported crash and cannot implicate frozen gesture behavior. The private menu/xinit integration is now the leading branch; inspect it safely without exposing connection or authentication arguments.

- timestamp: 2026-08-08T10:10:58Z
  checked: Phase 04-02 delegation contract, live command resolution, and X-session file metadata.
  found: The deployed command resolves to /usr/local/bin/menu, which Phase 04-02 modified outside git. The documented implementation generates an executable private xinitrc in /tmp and passes it to startx. /home/hoang/.xinitrc is a root-owned one-byte file, but the documented menu path supplies an explicit temporary xinitrc instead.
  implication: The live external menu is the relevant implementation. Shell compatibility, the actual generated xinitrc execution, and /tmp mount policy must be checked before treating the repository wrapper or client package as faulty.

- timestamp: 2026-08-08T10:13:10Z
  checked: Redacted live-menu structure, syntax, executable paths, /tmp mount flags, installed package closure, dynamic libraries, and no-connection client preflight.
  found: Menu uses #!/bin/bash, passes bash -n, and contains the expected printf -v/%q, startx, wrapper, mktemp, permission, native-X11, and rotation markers without obsolete build/tree, touch, or WLOG flags. /tmp has no noexec option. The wrapper and client are executable. All four packages are +onemix1, no library is unresolved, and xfreerdp3 --version succeeds.
  implication: Static menu construction, /tmp execution policy, package installation, and the client loader are not sufficient causes. Investigate the runtime session gate and server process context next.

- timestamp: 2026-08-08T10:14:42Z
  checked: Live display-server processes and all preserved user Xorg logs for fatal records.
  found: One live /usr/bin/Xwayland process exists and no Xorg process remains. Xorg.0 and Xorg.2 logs show no fatal or EE failure and end in successful server termination; the display-2 session's log elapsed about three seconds.
  implication: The process environment satisfies the gate's global-Xwayland failure condition, while the server evidence rules out an Xorg crash. Directly exercise that exact gate branch next.

- timestamp: 2026-08-08T10:16:13Z
  checked: Isolated check-x11-session.sh run with only pgrep responses for Xorg and Xwayland simulated.
  found: With XDG_SESSION_TYPE=x11, no WAYLAND_DISPLAY, and both simulated servers present, the gate exits 1 and prints "Xwayland is running — this is XWayland, not native Xorg." The live host currently has exactly that Xwayland process condition.
  implication: The gate's global process check directly produces the observed pre-connection failure mechanism. One redacted live-menu route probe remains to close the menu-to-gate causality chain.

- timestamp: 2026-08-08T10:18:24Z
  checked: Live menu option 3 with a PATH-local mock startx and a dummy probe value only.
  found: The live menu exits successfully through the mock and passes exactly one generated private xinitrc. The xinitrc is mode 0700, executable, starts with the Bash shebang, exports XDG_SESSION_TYPE=x11, performs both rotation calls, and calls scripts/launch-touch.sh.
  implication: The causal chain is directly observed: menu -> startx -> temporary native-X11 xinitrc -> wrapper -> check-x11-session.sh. With the live Xwayland process, the wrapper's global check explains the clean Xorg termination before the client runs.

- timestamp: 2026-08-08T10:19:38Z
  checked: Current display/user-manager environment and the latest preserved Xorg lifecycle metadata.
  found: The user manager exports DISPLAY=:0, WAYLAND_DISPLAY=wayland-0, and XDG_SESSION_TYPE=wayland. Xorg.2 ran on VT3 and terminated successfully after roughly three seconds. The active TTY sessions include tty3, the same VT used by the short-lived Xorg run.
  implication: An inherited WAYLAND_DISPLAY is a credible second gate failure that occurs before the global-Xwayland branch. Confirm the actual tty3 shell environment before collapsing to a multi-cause root cause.

- timestamp: 2026-08-08T10:20:44Z
  checked: The active tty3 Bash environment using a whitelist of display variables only, plus the live menu's Wayland-environment handling.
  found: tty3 has WAYLAND_DISPLAY=<unset>, DISPLAY=<unset>, and XDG_SESSION_TYPE=tty. The menu does not explicitly unset WAYLAND_DISPLAY, but none is inherited on the actual TTY path. It exports XDG_SESSION_TYPE=x11 in its generated xinitrc.
  implication: The earlier gate branch is ruled out for the reported reproduction. The confirmed AND-gate is the global-Xwayland code defect plus the live concurrent Xwayland process.

- timestamp: 2026-08-08T10:24:23Z
  checked: New tests/check_x11_session_check.sh against the unchanged gate.
  found: Shell syntax passes and the regression exits 1 with "FAIL: expected native Xorg on :2 to pass." The current global Xwayland prohibition produces the predicted red state.
  implication: The regression directly reproduces the root-cause condition and is ready to verify the minimal display-scoped correction.

- timestamp: 2026-08-08T10:25:36Z
  checked: First targeted source edit attempt.
  found: The exact-string replacement did not match the current check-x11-session.sh text, and no file was changed.
  implication: No behavior changed; re-read the complete current script before retrying the already-confirmed minimal correction.

- timestamp: 2026-08-08T10:27:02Z
  checked: First half of the minimal gate correction.
  found: The host-global Xorg/Xwayland process checks were replaced with a current-DISPLAY token lookup in `pgrep -a -x Xorg`; no other runtime wrapper or gesture code changed.
  implication: Complete the matching diagnostics and fail condition, then the regression can test the proposed root-cause fix.

- timestamp: 2026-08-08T10:28:02Z
  checked: Complete re-read after a second exact-string edit mismatch.
  found: The remaining gate block uses two-space indentation, not tabs; it still references the now-removed has_xwayland variable and global-Xwayland condition.
  implication: The incomplete intermediate state is understood and will be corrected with the exact current lines before any verification run.

- timestamp: 2026-08-08T10:29:20Z
  checked: Minimal root-cause fix application.
  found: check-x11-session.sh now finds an Xorg process whose command line contains the current DISPLAY, retains XDG_SESSION_TYPE and WAYLAND_DISPLAY gates, removes the host-global Xwayland rejection, and reports DISPLAY in its evidence. A two-case isolated regression check was added without changing menu, wrapper, package, or gesture code.
  implication: The code change directly addresses the confirmed false rejection. Automated regression and native-device verification are required before acceptance.

- timestamp: 2026-08-08T10:30:38Z
  checked: Post-fix shell regression, wrapper syntax/client preflight, focused diff, and retained Wayland-socket rejection.
  found: The new regression passes both the native-Xorg-plus-unrelated-Xwayland positive case and foreign-Xorg negative case. check-x11-session.sh and launch-touch.sh parse successfully; xfreerdp3 --version succeeds; git diff --check is clean; and a nonempty WAYLAND_DISPLAY still exits 1 with the expected fail-closed message.
  implication: The source-level fix resolves the reproduced condition without weakening the direct Wayland safeguard or changing wrapper/client behavior. Run the frozen gesture regression and formal acceptance guardrail next.

- timestamp: 2026-08-08T10:31:40Z
  checked: Existing frozen pinch-direction standalone regression compiled and run from /tmp.
  found: The C17 build with -Wall -Wextra -Werror succeeds and reports PASS for reverse and reverse-back pinch detents.
  implication: The independent frozen gesture guard remains green; the gate-only fix did not alter gesture behavior.

- timestamp: 2026-08-08T10:33:34Z
  checked: Phase 1.25 spectrum-based fault localization eligibility.
  found: The repository has standalone checks but no per-test coverage setup containing both a failing and passing test spectrum.
  implication: SBFL is skipped; the deterministic regression, direct process observation, and revert/reapply test provide the applicable fault-localization evidence.

- timestamp: 2026-08-08T10:33:34Z
  checked: Fix-acceptance guardrail.
  found: The target regression is green; Stryker is absent and skipped; the 15-addition/12-deletion diff is a targeted predicate replacement rather than a behavior-deleting patch; syntax, wrapper/client, Wayland fail-closed, and frozen gesture checks pass; bounded stash/reapply made the regression RED then GREEN.
  implication: All applicable guardrail signals accept the fix. Only native-device confirmation through the real menu/startx path remains.

- timestamp: 2026-08-08T10:42:42Z
  checked: User-confirmed native-device verification through the real tty3 menu/startx workflow.
  found: The user explicitly confirmed "đã work": choosing menu option 3 keeps Xorg open and reaches the Windows RDP desktop.
  implication: The fix resolves the original device-level failure under the concurrent GNOME Xwayland condition.

- timestamp: 2026-08-08T10:44:33Z
  checked: Targeted code-commit scope.
  found: Commit 7dbbacf contains only scripts/check-x11-session.sh and tests/check_x11_session_check.sh; phase4-install.sh remains untracked.
  implication: The committed fix is limited to the confirmed gate defect and its regression check, with no gesture or installer change.

- timestamp: 2026-08-08T10:45:36Z
  checked: Knowledge-base archival and MemPalace indexing availability.
  found: The prevention-backed entry was written to .planning/debug/knowledge-base.md. MemPalace indexing is skipped because state.load reports mempalace.enabled=false.
  implication: The durable knowledge-base entry is the recurrence-recall mechanism for this session.

## Resolution

root_cause: "AND-gate: check-x11-session.sh rejects any host Xwayland process instead of identifying the server for the current DISPLAY; a concurrent GNOME Xwayland process therefore rejects the menu's valid tty3/startx Xorg session before xfreerdp3 runs."
fix: "Scope native-X11 proof to the current DISPLAY's Xorg process and remove the host-global Xwayland prohibition; add a two-case isolated shell regression check."
verification:
  native_device:
    result: pass
    workflow: "From tty3, run menu and choose option 3."
    evidence: "User explicitly confirmed 'đã work': Xorg stayed open and the Windows RDP desktop was reached."
  target_test:
    result: pass
    command: tests/check_x11_session_check.sh
    evidence: "RED before the fix; GREEN after it with current-display Xorg plus unrelated Xwayland and foreign-Xorg cases."
  mutation_check:
    result: skipped
    reason_if_skipped: "No Stryker configuration, package manifest, or stryker executable exists; the fix is POSIX shell."
    mutant_killed: n/a
  no_op_deletion:
    result: pass
    deletion_justified_by_rca: true
    evidence: "15 additions and 12 deletions replace a global predicate with a current-DISPLAY predicate; the diff is not deletion-only."
  adjacent_tests:
    result: pass
    suites_run:
      - "sh -n scripts/check-x11-session.sh tests/check_x11_session_check.sh"
      - "bash -n scripts/launch-touch.sh"
      - "xfreerdp3 --version"
      - "WAYLAND_DISPLAY fail-closed probe"
      - "cc -std=c17 -Wall -Wextra -Werror tests/pinch_reversal_check.c -lm"
  revert_and_reconfirm:
    result: pass
    bug_returned_on_revert: true
    fixed_on_reapply: true
    evidence: "Bounded git stash of the gate made the regression RED; stash pop restored the gate and the regression GREEN."
  guardrail_verdict: accepted
oracle_type: "derived — the native-X11 contract requires the Xorg owning the current DISPLAY to pass despite an unrelated host Xwayland process; a foreign Xorg must not prove the current display native."
prevention:
  causal_branches:
    - "code: The gate modeled native X11 as host-wide Xwayland absence rather than ownership of the current DISPLAY, so an unrelated process could reject a valid server."
    - "environment: The normal desktop legitimately keeps GNOME Xwayland alive while the tty3 menu starts a separate Xorg display; this valid topology triggered the global predicate."
  and_gate: "Both the host-global predicate and the concurrent GNOME Xwayland process were required; the environment remains valid after the predicate is corrected."
  why_not_caught: "No automated native-X11 gate test modeled a current-display Xorg alongside an unrelated host Xwayland process."
  recurrence_guard: "tests/check_x11_session_check.sh covers the positive current-display-Xorg-plus-Xwayland case and the negative foreign-Xorg case; it passed after the fix."
files_changed:
  - scripts/check-x11-session.sh (current-DISPLAY Xorg proof)
  - tests/check_x11_session_check.sh (new regression check; RED verified before fix)

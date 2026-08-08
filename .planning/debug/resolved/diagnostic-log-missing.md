---
status: resolved
trigger: "FREERDP_TOUCH_DIAG=1 menu creates no diagnostic log; live menu contains literal XDIAG in generated xinitrc"
created: 2026-08-08T11:56:23Z
updated: 2026-08-08T13:30:00Z
---

## Current Focus

hypothesis: CONFIRMED — the active-contact verification gap is an oracle/instrumentation mismatch, not a missed native trigger: the canonical fallback path leaves xfc->contacts[] empty, while force_cancel reports only that inactive array. The newest artifact has a well-formed seven-contact ingress set at its final force_cancel but records contacts=0.
test: Completed static writer/option-path audit and an ID-redacting Begin/End reconstruction of the newest artifact.
expecting: Confirmed: no alternate xfc->contacts[] writer exists in fallback mode, and no normal menu/fullscreen action can make the old contacts>0/event=cancel oracle pass without changing mode or instrumentation.
next_action: Completed — user approved Option A (adjust verification only). The fallback-mode DIAG-01 oracle in the Phase 04-03 verification contract was corrected to require inferred_live_at_force_cancel>0 from the redacted Begin/End ingress sequence plus a force_cancel summary; per-contact event=cancel is now conditional on a mode that actually populates xfc->contacts[] or RDPEI contacts. No gesture code or packages modified; the timestamped system backup is retained.
bug_class: bohrbug
candidate_causes:
  - code: fallback dispatcher never populates xfc->contacts[] while the cancellation diagnostic reads only that array
  - config: installed launcher intentionally enables fallback mode; fullscreen toggle remains enabled by FreeRDP default
  - data: newest redacted ingress sequence has unmatched Begin records at final force_cancel
and_gate: yes — the impossible old oracle arises from the intended fallback configuration plus diagnostic code that observes the inactive local-contact array.
verification_scope: Never output log lines or connection arguments, hostnames, usernames, passwords, tokens, or other authentication material. Inspect only fixed metadata, count, and ordering categories from the newest artifact.
known_behavior: /usr/local/bin/menu is root:root 0755 and exact candidate content; its timestamped root-owned 0755 backup remains. The temporary /home/hoang/freerdp-touch/install-menu-fix.sh has been removed. The prior post-install logs confirm 0700/0600 permissions, local ingress/state/synthesis/force_cancel classes, no sensitive diagnostic-record marker, and force_cancel summaries with contacts=0.

## Symptoms

expected: Running FREERDP_TOUCH_DIAG=1 menu from TTY and choosing option 3 should create a private touch log under the XDG state directory and emit touch-diag records.
actual: The RDP session was exercised and exited, but the freerdp-touch diagnostic directory and touch log do not exist.
errors: Inspection found a literal XDIAG line in /usr/local/bin/menu inside the single-quoted generated xinitrc template; no diagnostic log evidence exists.
reproduction: From TTY run FREERDP_TOUCH_DIAG=1 menu, choose option 3, exercise gestures and forced cancellation, exit, then inspect the expected XDG state directory.
started: First observed during Phase 4 Plan 04-03 Step 6 diagnostic verification after normal mode and gestures passed.

## Eliminated

- hypothesis: The literal XDIAG line prevents FREERDP_TOUCH_DIAG=1 from reaching the wrapper.
  evidence: A hermetic execution of each live generated xinitrc with no XDIAG executable, mocked X utilities, and only the absolute wrapper replaced showed the mock wrapper receives diagnostic value 1 in diagnostic mode; normal and --mouse-only remain unset.
  timestamp: 2026-08-08T12:07:41Z

- hypothesis: launch-touch.sh fails to create its diagnostic directory/log after it receives FREERDP_TOUCH_DIAG=1.
  evidence: An isolated execution of the real wrapper branch with only pgrep and /usr/bin/xfreerdp3 replaced created one private log and passed value 1 to its mock client.
  timestamp: 2026-08-08T12:11:03Z

- hypothesis: The local per-contact cancellation diagnostic loop failed during the user run.
  evidence: The newest native log has three force_cancel summaries, all with contacts=0, and therefore legitimately no active local contact for an event=cancel record.
  timestamp: 2026-08-08T12:35:15Z

- hypothesis: The native diagnostic records leaked a connection argument or authentication material.
  evidence: The newest-log scan found no /p: marker and no forbidden marker within a touch-diag record; the only generic marker match was outside diagnostic records, and no log text or value was exposed.
  timestamp: 2026-08-08T12:35:15Z

- hypothesis: Fullscreen cancellation is unavailable because the menu disables the keyboard fullscreen toggle.
  evidence: The menu enters fullscreen but does not disable ToggleFullscreen; FreeRDP initializes it true, xf_keyboard.c maps Ctrl+Alt+Enter directly to xf_toggle_fullscreen(), and that function calls force_cancel before mutating fullscreen state.
  timestamp: 2026-08-08T12:59:36Z

## Evidence

- timestamp: 2026-08-08T11:59:30Z
  checked: Semantic and keyword knowledge-base recall for the prefilled missing-diagnostic-log symptoms.
  found: MemPalace is not installed; fallback keyword scan found no matching resolution. The only prior session concerns native-X11 server detection, not diagnostic-environment propagation.
  implication: No prior fix can be assumed; investigate the live menu-to-private-xinitrc-to-wrapper boundary directly.

- timestamp: 2026-08-08T12:00:51Z
  checked: Sanitized inspection of the external live /usr/local/bin/menu before any proposed overwrite.
  found: Its private-xinitrc template writes literal XDIAG at menu line 62, then separately appends export FREERDP_TOUCH_DIAG=1 only when diagnostic mode is set (lines 65-68), before emitting the absolute launch-touch.sh invocation.
  implication: The placeholder defect is directly observed, but it does not by itself prove the wrapper lacks the flag because the later export could still take effect; a controlled end-to-end propagation test is required.

- timestamp: 2026-08-08T12:02:50Z
  checked: Complete sanitized live menu and repository launcher/gate scripts.
  found: The live menu creates a private xinitrc, appends the diagnostic export conditionally, and execs an absolute launch-touch.sh path. launch-touch.sh reads FREERDP_TOUCH_DIAG after the native-X11 gate and creates its private diagnostic directory/log only in the value-1 branch; normal and --mouse-only parsing are independent of diagnostic mode.
  implication: A mock startx can safely capture the generated script and a one-path substitution can route its absolute wrapper invocation to a harmless observer, allowing exact normal/diagnostic/mouse-only propagation checks without an RDP connection.

- timestamp: 2026-08-08T12:06:18Z
  checked: New runnable regression check tests/menu_diagnostic_env_check.sh executed against the inspected live menu with MENU_UNDER_TEST=/usr/local/bin/menu.
  found: The shell syntax check passed, and the behavioral check failed deterministically before any real X/RDP launch with: FAIL: unresolved XDIAG in generated xinitrc (normal).
  implication: The regression check is a valid red baseline for the directly observed template defect, but a follow-up experiment must establish whether Bash continues to the wrapper and propagates diagnostic mode despite that error.

- timestamp: 2026-08-08T12:07:41Z
  checked: Hermetic end-to-end execution of the three generated live-menu xinitrc variants with the literal XDIAG retained, no XDIAG executable available, and only the absolute wrapper invocation redirected to an observer.
  found: All variants contained literal XDIAG, yet Bash continued: normal observer diagnostic=unset/mouse-only=0; diagnostic observer diagnostic=1/mouse-only=0; mouse-only observer diagnostic=unset/mouse-only=1.
  implication: The XDIAG line is an independently reproducible template error and regression target, but it is not the mechanism that prevents the diagnostic variable from reaching the wrapper. The original missing-log mechanism remains unconfirmed downstream.

- timestamp: 2026-08-08T12:09:15Z
  checked: Argument-redacted structural trace of scripts/launch-touch.sh diagnostic branch.
  found: The wrapper performs the native-X11 gate before reading the flag, then, for exact value 1, runs mkdir/chmod/mktemp/chmod for XDG_STATE_HOME-derived logging before its fixed absolute /usr/bin/xfreerdp3 pipeline.
  implication: A private copy can replace only the client path and mock pgrep for the gate, testing actual diagnostic log creation without X, RDP, credentials, or changes to tracked/live files.

- timestamp: 2026-08-08T12:11:03Z
  checked: Isolated real scripts/launch-touch.sh diagnostic branch with a source-relative real gate, mocked current-display Xorg process, mock absolute client, and private XDG_STATE_HOME.
  found: The wrapper exited 0, passed diagnostic value 1 to the mock client, created exactly one touch log, and set diagnostic directory/log permissions to 0700/0600.
  implication: The wrapper's log-creation behavior is correct in isolation. The confirmed code fix is limited to the independently observed unresolved menu template command; no speculative changes to diagnostics or gesture code are warranted.

- timestamp: 2026-08-08T12:13:07Z
  checked: Candidate creation from the pre-inspected external live menu using a preconditioned transformation.
  found: scripts/menu was created mode 0755 only after confirming the live source contained exactly one standalone XDIAG line; that one line was removed and no live file was overwritten.
  implication: A durable, installable candidate now exists for automated verification and later human-authorized sudo installation.

- timestamp: 2026-08-08T12:13:53Z
  checked: Candidate structural assertion, Bash syntax, and tests/menu_diagnostic_env_check.sh against scripts/menu.
  found: The candidate differs from live only by deletion of standalone XDIAG, passes Bash syntax, and the regression reports PASS after exercising mock normal, diagnostic, and --mouse-only flows.
  implication: The red-to-green behavioral condition is established for the candidate without altering the live root-owned menu or claiming native diagnostic-log success.

- timestamp: 2026-08-08T12:16:46Z
  checked: Fix-acceptance signals and authorization for installation.
  found: Target regression, shell syntax, and adjacent native-X11 regression pass; manually restoring exact XDIAG kills the target test; no Stryker configuration/binary exists. /usr/local/bin/menu is root:root mode 0755 and not writable by current user hoang, while scripts/menu is mode 0755.
  implication: The automated guardrail accepts the narrowly justified deletion. Authentication and real native-X11/RDP behavior are the remaining human-only checks, so the live menu was deliberately not overwritten.

- timestamp: 2026-08-08T12:29:24Z
  checked: User-authorized installation state using byte comparison and filesystem metadata only.
  found: /usr/local/bin/menu is a root:root regular file mode 0755 and byte-matches /home/hoang/freerdp-touch/scripts/menu exactly. The candidate remains mode 0755. The current noninteractive environment has XDG_STATE_HOME unset; the one-time installer remains present mode 0775.
  implication: Installation of the narrow candidate is confirmed without exposing its contents. The TTY's actual XDG state root must be derived from the wrapper/artifact rather than assumed from this noninteractive environment.

- timestamp: 2026-08-08T12:30:31Z
  checked: Diagnostic state-path contract, backup retention, and DIAG-01 criterion locations using source-pattern and filename/metadata-only inspection.
  found: launch-touch.sh derives its diagnostic directory from XDG_STATE_HOME with $HOME/.local/state fallback and creates touch-*.log there. The prior menu is retained as /usr/local/bin/menu.pre-xdiag-20260808T122116Z, root:root mode 0755. DIAG-01 criteria are documented in the Phase 4 plans and requirements.
  implication: The confirmed backup may be retained while the temporary installer can be removed after its successful installation verification. Native confirmation can now be limited to the one newest resolved-state artifact and its non-sensitive record classes.

- timestamp: 2026-08-08T12:31:59Z
  checked: DIAG-01 native acceptance criteria in REQUIREMENTS.md and the Phase 4 verification plan.
  found: Required canonical local-only evidence is touch Begin/Update/End ingress, recognizer state transitions, synthesized button/wheel/ctrl output, a force_cancel summary, and per-active-local-contact event=cancel records. RDPEI frame/per-contact records are conditional and not required unless an actual native-contact path was used. The log must remain free of sensitive connection material.
  implication: A single redacted class-count inspection of the newest native log can conclusively validate the reported diagnostic workflow without dumping its contents or demanding an unrelated repeat of normal/mouse-only runs.

- timestamp: 2026-08-08T12:33:54Z
  checked: Only the newest post-install touch log, via metadata and fixed record-class counters without any line output.
  found: The default XDG freerdp-touch directory exists mode 0700. Its newest log is non-empty, mode 0600, and newer than the retained pre-change backup. It contains Begin=81, Update=10161, End=53, state=83, synth=240, and force_cancel=3 records; it has no event=cancel or RDPEI-frame match. A boolean prohibited-marker scan is positive, with no matching text emitted.
  implication: The original missing native diagnostic artifact is directly resolved, and most required local-only DIAG-01 classes are confirmed. Do not finalize: per-contact cancellation evidence and the marker alert need one safe discriminating inspection.

- timestamp: 2026-08-08T12:35:15Z
  checked: A second redacted discriminator over the same newest log: force_cancel contact counts, cancellation-label counts, and marker location booleans only.
  found: All three force_cancel summaries have zero active contacts; event=cancel and touch ev=cancel counts are both zero. No /p: marker appears. The only forbidden-marker class is a generic word outside all touch-diag records; no matching text or value was emitted.
  implication: The existing run does not expose a code cancellation-loop failure or diagnostic-record connection leak. It does not prove per-contact cancellation either, because cancellation occurred only after contacts had ended. One active-contact cancellation recheck is the sole remaining native DIAG-01 evidence gap.

- timestamp: 2026-08-08T12:36:33Z
  checked: Cleanup authorized after successful installation verification, with preconditions protecting the retained backup.
  found: /home/hoang/freerdp-touch/install-menu-fix.sh was a regular non-symlink file and was removed. /usr/local/bin/menu.pre-xdiag-20260808T122116Z remains a root:root mode 0755 regular file.
  implication: The temporary installer cannot be accidentally reused; the user retains a timestamped rollback copy. No source or live-menu change was made during this cleanup.

- timestamp: 2026-08-08T12:47:25Z
  checked: Only the newest post-checkpoint touch artifact, through a read-only metadata and fixed class/count scanner that emitted no artifact lines or values.
  found: A regular non-symlink newest artifact exists in a 0700 real directory, is non-empty mode 0600, and is newer than the checkpoint baseline. It has synth=85 and force_cancel=3; the exact scanner found Begin=0, Update=0, End=0, state=0, event=cancel=0, force_cancel summaries with contacts>0=0, and no sensitive marker within touch-diag records.
  implication: The fresh artifact preserves the private diagnostic contract but does not meet active-contact-cancellation evidence under the exact parser. Because its zero ingress-class counts conflict with previously known record categories, run one redacted vocabulary discriminator before treating the user recheck as insufficient.

- timestamp: 2026-08-08T12:49:04Z
  checked: The same newest artifact through a second read-only classifier using fixed non-sensitive event-shape categories and force-cancel count categories only.
  found: It has diagnostic_record_count=4123; begin-like=20, update-like=3962, end-like=13, state-like=20, synth-like=85, and force_cancel=3. All three force_cancel summaries have contacts=0, none has a missing contacts field or contacts>0, and cancellation classifiers are all zero. The sensitive-marker-in-touch-diag boolean is false.
  implication: The first scan's zero ingress classes were a vocabulary mismatch, not absent touch activity. The decisive active-contact condition is nevertheless absent in this fresh artifact, so DIAG-01 remains partial and one targeted recheck is required; no code or gesture behavior should change.

- timestamp: 2026-08-08T12:55:42Z
  checked: Complete X11 force-cancel implementation, every compiled call site, and generic-XI2 dispatch ordering.
  found: Force-cancel is called by fallback third-finger abort, FocusOut, geometry-changing ConfigureNotify, UnmapNotify, fullscreen toggle, and post-disconnect. In xf_event_process, a FocusOut/Configure/Unmap call happens before the later xf_input_handle_event() call; XI_TouchEnd clears xfc->contacts[] only when its distinct GenericEvent is dispatched. xf_toggle_fullscreen() calls force_cancel synchronously before changing fullscreen state.
  implication: Holding a touch until an independent force-cancel event is processed is structurally sufficient for contacts>0; keyboard-driven fullscreen toggle is a stronger deterministic candidate than focus switching because it invokes cancellation directly rather than relying on window-manager focus event ordering.

- timestamp: 2026-08-08T12:57:17Z
  checked: Complete fallback-mode dispatcher and the installed launcher preset, with source-only inspection of touch-state mutation.
  found: launch-touch.sh always supplies +touch-pinch-wheel-fallback. xf_input_handle_event therefore selects xf_input_handle_event_remote(), which invokes xf_input_touch_fallback() but never xf_input_touch_begin/update/end. The only writers of xfc->contacts[] and xfc->active_contacts are those local-handler functions; fallback instead tracks active fingers in lpFinger, fallbackFinger, pinchFingerA/B, and midFingerC.
  implication: Under the installed canonical fallback preset, xfc->contacts[] is structurally empty for every physical touch. No menu, focus, fullscreen, or native event ordering can make the existing event=cancel loop or contacts>0 criterion observe an active fallback contact without changing modes or the diagnostic instrumentation.

- timestamp: 2026-08-08T12:59:36Z
  checked: Fullscreen setting and input key path in the actual FreeRDP source plus the installed menu's non-disabling fullscreen launch behavior.
  found: FreeRDP initializes ToggleFullscreen=true; xf_keyboard_handle_special_keys maps physical Ctrl+Alt+Enter to xf_toggle_fullscreen(), and xf_toggle_fullscreen() calls xf_touch_force_cancel() before it changes window state. The menu does not pass a disabling toggle option.
  implication: A deterministic direct cancellation action exists, but it cannot make xfc->contacts[] positive in fallback mode; the lack of a third successful Alt+Tab attempt is not a trigger-selection problem.

- timestamp: 2026-08-08T12:59:36Z
  checked: Newest native artifact with a read-only, ID-redacting sequence reconstruction from touch Begin/Update/End and force_cancel diagnostic records.
  found: The artifact has 4,123 diagnostic records, 20 Begin, 3,962 Update, 13 End, and three force_cancel records. At those cancellations, reconstructed live physical-contact counts / recorded summary contacts are 0/0, 0/0, and 7/0; no artifact line, identifier, connection argument, or sensitive value was emitted.
  implication: The final force-cancel already occurred while seven source-ingress physical contacts were live, directly falsifying the prior event-order explanation. The zero summary is caused by fallback-mode bookkeeping and proves the old xfc->contacts[] oracle is structurally invalid for the configured path.

- timestamp: 2026-08-08T13:03:12Z
  checked: Durable patches/onemix-touch.patch cancellation and fallback hunks against the built X11 source.
  found: The durable patch explicitly routes all touch through xf_input_touch_fallback() with no native RDPEI contacts, while its per-contact diagnostic loop iterates only xfc->contacts[]. The patch and build source agree; this is not a stale-build or patch-application discrepancy.
  implication: No packaging or environment alternative explains the zero summaries. The remaining issue is confined to the verification oracle/instrumentation boundary.

- timestamp: 2026-08-08T13:03:12Z
  checked: Falsification discriminators: all active_contacts writers, boolean command-line parsing, and newest-artifact Begin/End integrity.
  found: active_contacts has exactly three mutations: initialization, increment in xf_input_touch_begin(), and decrement in xf_input_touch_end(). The generic parser sets a + boolean option true; the launcher option sets TouchPinchWheelFallback, whose dispatcher selects the non-writing fallback path. The newest artifact has duplicate_begin=0, unmatched_end=0, final_inferred_live=7, and force pairs 0/0, 0/0, 7/0.
  implication: The code/config and data alternatives have been tested independently. The source-level root cause is confirmed, and the latest native artifact already supplies the strongest truthful fallback-mode cancellation evidence without a repeat.

- timestamp: 2026-08-08T13:30:00Z
  checked: User-approved Option A (adjust verification only) applied to the Phase 04-03 verification contract.
  found: The structurally impossible xfc->contacts[] loop / per-contact event=cancel requirement for the canonical fallback path was removed from four locations in 04-03-PLAN.md (check 6 action, check 6 confirmation sentence, acceptance criteria, verification section, done section) and replaced with the truthful oracle: a force_cancel summary plus inferred_live_at_force_cancel>0 from the redacted Begin/End ingress sequence, with per-contact event=cancel required only when a mode actually populates xfc->contacts[] or RDPEI contacts. Unrelated DIAG-01 classes (Begin/Update/End, state transitions, synthesis, RDPEI conditional, sensitive-record check) are preserved. No gesture code or packages modified; the timestamped system backup is retained.
  implication: The verification contract is now truthful for the configured canonical fallback path. The one-line live-menu XDIAG fix, its runnable regression, and this debug record are finalized.

## Resolution

root_cause: The original missing-artifact defect was the external menu's unresolved standalone XDIAG token; its conditional export was already correct and the menu fix is installed. The remaining DIAG-01 cancellation gate used an invalid fallback-mode oracle: +touch-pinch-wheel-fallback dispatches around the only xfc->contacts[] writers, but xf_touch_force_cancel reports and enumerates only xfc->contacts[]. Thus contacts>0 and per-contact event=cancel are structurally unreachable for the configured gesture path even when the ingress stream has active physical contacts.
fix: Applied the menu candidate that deletes only the standalone XDIAG line and added its hermetic regression. User approved Option A (adjust verification only): replaced only the fallback-mode DIAG-01 oracle in the Phase 04-03 verification contract with a redacted Begin/End sequence invariant requiring inferred_live_at_force_cancel>0 plus a force_cancel summary; per-contact event=cancel is now conditional evidence required only for a mode that actually populates xfc->contacts[] or RDPEI contacts. No gesture code or packages were modified; the timestamped system backup is retained.
verification:
  target_test:
    result: pass
    command: MENU_UNDER_TEST=/home/hoang/freerdp-touch/scripts/menu tests/menu_diagnostic_env_check.sh
  mutation_check:
    result: skipped
    reason_if_skipped: No Stryker binary or configuration exists for this shell-only repository; an equivalent targeted manual XDIAG reintroduction was killed by the driving regression.
    mutant_killed: true
  no_op_deletion:
    result: pass
    deletion_justified_by_rca: true
    evidence: Candidate equals live menu except deletion of the one standalone invalid command named in the confirmed root cause.
  adjacent_tests:
    result: pass
    suites_run:
      - tests/check_x11_session_check.sh
      - bash -n scripts/menu scripts/launch-touch.sh scripts/check-x11-session.sh tests/menu_diagnostic_env_check.sh
  revert_and_reconfirm:
    result: pass
    bug_returned_on_revert: true
    fixed_on_reapply: true
    evidence: Live-equivalent baseline and a temporary exact XDIAG reintroduction both fail; the re-applied candidate passes.
  native_human_verification:
    result: pass — user approved Option A (adjust verification only); the fallback-mode DIAG-01 oracle in the Phase 04-03 verification contract was corrected to require inferred_live_at_force_cancel>0 from the redacted Begin/End ingress sequence plus a force_cancel summary, with per-contact event=cancel conditional on a mode that actually populates xfc->contacts[] or RDPEI contacts
    installation: pass — installed menu byte-matches the tested candidate and is root:root mode 0755
    native_artifact: pass — fresh newest artifact is a regular non-symlink non-empty 0600 log in the existing 0700 directory
    confirmed_classes: begin-like=20, update-like=3962, end-like=13, state-like=20, synth-like=85, force_cancel=3
    local_contact_cancel: pass by redacted sequence — final force_cancel has seven well-formed Begin-without-End contacts (inferred_live_at_force_cancel=7) while its local-array summary remains zero; per-contact event=cancel is not applicable in the fallback dispatcher
    rdpei_frame: not_applicable — canonical fallback path produced no native-contact evidence
    sensitive_record_check: pass — sensitive-marker-in-touch-diag=false; no artifact content was exposed
    contract_correction: applied to 04-03-PLAN.md check 6, acceptance criteria, verification section, and done section — removed the structurally impossible xfc->contacts[] loop requirement for the canonical fallback path; unrelated DIAG-01 classes preserved
    next_required: none — session resolved
  guardrail_verdict: accepted
oracle_type: derived — the regression derives its expected xinitrc export and wrapper environment from the existing launch-touch.sh diagnostic contract plus the menu's documented diagnostic invocation.
files_changed:
  - scripts/menu
  - tests/menu_diagnostic_env_check.sh

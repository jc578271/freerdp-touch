---
status: resolved
trigger: "Double-tap đã ổn hơn sau tap-coordinate anchoring nhưng vẫn hiếm khi Windows chỉ nhận một click. Đổi mặc định từ 600ms/8px sang 500ms/12px không cải thiện thêm. Điều tra bằng touch diagnostics trên native X11 để xác định touch thứ hai bị mất ở XI2 event delivery, recognizer state/multi-finger transition/quarantine, hay đã synthesize đủ hai click nhưng Windows không nhận double-click; sau đó sửa root cause tối thiểu và regression-test."
created: "2026-08-10"
updated: "2026-08-10T16:23:19Z"
---

# Debug Session: Rare Double-Tap Drop

## Symptoms

### Expected behavior

Hai lần chạm nhanh bằng một ngón lên cùng folder phải luôn phát hai click trái hoàn chỉnh tại cùng tọa độ để Windows mở folder.

### Actual behavior

Tap-coordinate anchoring đã cải thiện đáng kể độ ổn định, nhưng hiếm khi Windows vẫn chỉ nhận một click. Đổi mặc định từ 600 ms / 8 px sang 500 ms / 12 px không tạo khác biệt quan sát được so với bản sửa đầu tiên.

### Error messages

Không có lỗi hiển thị.

### Timeline

Lỗi có từ trước. Bản sửa neo tọa độ touch thứ hai cải thiện rõ rệt. Thay đổi calibration mặc định sau đó không cải thiện thêm. Bản mới nhất đã được cài và xác minh trước khi calibration task; calibration wrapper hiện truyền 500 ms / 12 px khi chạy qua menu.

### Reproduction

1. Chạy patched `xfreerdp3` qua `menu` trong native X11.
2. Mở Windows File Explorer.
3. Double-tap cùng một folder nhiều lần bằng một ngón.
4. Quan sát phần lớn lần mở folder, nhưng hiếm khi chỉ có hành vi single-click/select.

## Current Focus

- root_cause: "Confirmed: `xf_input_touch_fallback` coupled double-tap coordinate anchoring to the 12 px long-press/drag slop, so normal 12.65–16.64 px rapid retaps reached Windows at distinct coordinates."
- verified_deployment: "Commit `809e1f3dd92f04f061028cbfff0e9ce8816ec976` contains only the anchor-tolerance patch. The exact four-package `+onemix1` closure is installed; dpkg records all four reinstalled at 2026-08-10 23:09:46 local time; the installed and bundle `xfreerdp3` SHA256 are both `e681d26db36abb85612ff2ee60a0501c133f94a89949718369e82a1b46b7d331`."
- acceptance_scope: "Bounded human acceptance: the user observed that the deployed fix is improved in the real workflow and explicitly requested closure. It is not a claim that every possible rare miss has been mathematically eliminated."
- next_action: "Commit the resolved-session and durable knowledge-base records only. MemPalace indexing is skipped because planning state has `mempalace.enabled: false`."

## Evidence

- timestamp: "2026-08-10T15:15:40Z"
  checked: Configured `gsd-debugger` agent skills and repository `.claude/skills` / `.agents/skills` directories.
  found: The agent-skills query returned no configured skills, and neither project skill directory exists.
  implication: No additional rule or diagnostic utility is available; the installed binary capture remains the smallest unconfounded discriminator.

- timestamp: "2026-08-10T15:17:28Z"
  checked: Complete diagnostic launch/menu scripts and all `touch-diag` log call sites in the maintained patch.
  found: Setting `FREERDP_TOUCH_DIAG=1` before `scripts/menu` propagates into the private Xorg session; the wrapper writes a mode-0600 log under `~/.local/state/freerdp-touch/touch-*.log`. All diagnostic records use `WLog_WARN`, so no extra `WLOG_LEVEL` setting is required.
  implication: The user can now capture one unconfounded failing sequence with an exact command and safely provide only the relevant diagnostic lines.

- timestamp: "2026-08-10T14:55:27Z"
  checked: Debugger agent-skill configuration and project skill directories.
  found: No `gsd-debugger` agent skills were configured; neither `.claude/skills/` nor `.agents/skills/` exists in this repository.
  implication: No additional project or agent rule constrains this investigation beyond the loaded debugger and repository instructions.

- timestamp: "2026-08-10T14:55:58Z"
  checked: Persistent debug knowledge base and repository layout.
  found: The only resolved entry concerns a false native-X11 session rejection, not touch/click delivery; the active patch source is under `src/`.
  implication: There is no keyword-level prior-resolution candidate for this rare double-tap failure; semantic recall will be attempted before open-ended source tracing.

- timestamp: "2026-08-10T14:56:34Z"
  checked: `.planning/config.json` for MemPalace semantic recall capability.
  found: No `mempalace` configuration is present, so semantic recall is disabled.
  implication: The local knowledge base is the durable fallback and yielded no matching candidate; proceed with open-ended evidence gathering.

- timestamp: "2026-08-10T14:57:09Z"
  checked: `src/` and available source-search tooling.
  found: `src/` contains only Debian `.dsc` and compressed source archives; `rg` is not available in this environment.
  implication: The active implementation must be traced through the maintained quilt patch or an unpacked distribution/build tree, using standard read-only tools rather than searching archives as source files.

- timestamp: "2026-08-10T14:57:48Z"
  checked: Maintained patches, bundle contents, and Debian archive member paths.
  found: The maintained implementation is `patches/onemix-touch.patch`; the distribution bundle contains binary packages only, and the original archive contains `client/X11/xf_input.c`, `client/common/client.c`, and RDPEI code.
  implication: Read the patch first, then compare its changed functions against the baseline source context; the `.deb` bundle cannot reveal source-level diagnostic coverage.

- timestamp: "2026-08-10T14:58:52Z"
  checked: Complete `patches/onemix-touch.patch` (2,864 lines), including touch fallback, dispatcher, diagnostics, and regression tests.
  found: Fallback emits a left-click pair only at `XI_TouchEnd` when `lpArmed && touchId == lpFinger`. Existing diagnostics log every event entering `xf_input_touch_remote` and a single post-pair `synth left-tap`, but the entry log prints `x`/`y` before they are assigned and recovery-gate consumption occurs before that logger without a diagnostic reason.
  implication: A raw lifecycle/log capture can prove successful entry and synthesized pair, but cannot currently distinguish all silent discard routes or reliably correlate raw coordinates; inspect complete dispatcher context before deciding whether to add minimal observability.

- timestamp: "2026-08-10T15:00:26Z"
  checked: Complete patched `client/X11/xf_input.c` in an isolated Debian source tree, including the remote dispatcher.
  found: The entry logger correctly uses `event->event_x`/`event->event_y`. However, `recoveryGateArmed` consumes both quarantined and new touch events before `xf_input_touch_remote` with no `touch-diag` record; an out-of-content Begin also returns silently. After a normal first tap, the second can synthesize only if its End reaches the fallback with `lpArmed` still true and its ID equal to `lpFinger`.
  implication: The code side has discrete falsifiable drop paths. A capture needs gate/rejection visibility as well as touch lifecycle and synthesis; trace the downstream button wrapper before deciding if it also needs instrumentation.

- timestamp: "2026-08-10T15:01:17Z"
  checked: `freerdp_client_send_button_event` in complete `client/common/client.c` context.
  found: The wrapper optionally uses AInput, falls back to `freerdp_input_send_mouse_event` when AInput is not handled, and returns `TRUE` unconditionally after the fallback; the gesture caller ignores that result.
  implication: `touch-diag: synth left-tap` establishes two wrapper invocations but not a successful on-wire mouse PDU. The immediate input send path is the next client-side boundary to inspect.

- timestamp: "2026-08-10T15:02:01Z"
  checked: Complete `freerdp_input_send_mouse_event` implementation in `libfreerdp/core/input.c`.
  found: It returns `FALSE` for a missing input/context or a failing `MouseEvent` callback, but returns `TRUE` without sending when `FreeRDP_SuspendInput` is set. The gesture wrapper ignores this return value.
  implication: A synthesized pair can still be silently dropped below the gesture layer. The candidate set now includes dynamic input suspension or a failed transport callback; trace their concrete runtime behavior before attributing a missing double-click to Windows.

- timestamp: "2026-08-10T15:02:56Z"
  checked: All source references to `MouseEvent` callback assignment and `FreeRDP_SuspendInput`.
  found: Core input registers either fast-path or regular mouse callbacks; `SuspendInput` has no project runtime writer, only standard getter/setter plumbing and consumer checks.
  implication: Unless the launch configuration explicitly sets it, `SuspendInput` cannot explain a rare, timing-specific second-click loss. Inspect the actual launcher while reading the final transport callback setup.

- timestamp: "2026-08-10T15:04:17Z"
  checked: Core input callback registration plus complete `scripts/launch-touch.sh` and `scripts/menu` launch path.
  found: The launcher always enables `+touch-pinch-wheel-fallback`, passes `/touch-long-press:500` and `/touch-slop:12`, and sets no `SuspendInput` or AInput option. Core input chooses fast-path or regular `MouseEvent` from negotiated `FreeRDP_FastPathInput`.
  implication: The calibration/default configuration is not a variable across the reported trials, and `SuspendInput` is not enabled by this launcher. The diagnostic must follow the timing-dependent input route rather than blaming launcher configuration.

- timestamp: "2026-08-10T15:05:18Z"
  checked: Bug taxonomy, technique route, and SBFL applicability.
  found: This is a `heisenbug-mandelbug`: the rare timing-dependent failure has no deterministic failing test or per-test coverage spectrum. The required first move is bounded event recording/sampling; no prior SBFL result exists to revoke.
  implication: Use observability-first and one-variable capture runs. Do not treat a passing synthetic dispatcher test as proof of the physical event path.

- timestamp: "2026-08-10T15:06:15Z"
  checked: Regular and fast-path `MouseEvent` callbacks in `libfreerdp/core/input.c`.
  found: Both callbacks synchronously allocate one input PDU, write the down/up mouse fields, and return the final send status; neither locally coalesces a double-click. Their return is discarded by `freerdp_client_send_button_event`.
  implication: If the connection is active and both send results are true, the client side has serialized both mouse pairs. The remaining ambiguity is directly observable only by propagating/logging the real result or by correlating the existing synthesis log with connection error output.

- timestamp: "2026-08-10T15:07:34Z"
  checked: `input_ensure_client_running`, standard PDU send, and fast-path PDU send implementations.
  found: Input is rejected only after session termination (with a warning), while each fast-path call explicitly sends one event (`count=1`) through `transport_write`; regular input likewise sends one PDU. There is no double-click coalescer or timing transformation in this path.
  implication: A healthy continuing RDP session makes client transport an unlikely selective drop point, though the current wrapper hides its return. The next high-value observation is a real installed-binary capture at the dispatcher/recognizer boundary.

- timestamp: "2026-08-10T15:08:52Z"
  checked: Installed FreeRDP package, `/usr/bin/xfreerdp3` diagnostic strings, and existing wrapper log directory.
  found: `freerdp3-x11`, `libfreerdp3-3`, and `libfreerdp-client3-3` are all installed at `3.15.0+dfsg-2.1+deb13u3+onemix1`; the binary contains the expected `touch-diag` strings; no previous touch capture exists under `~/.local/state/freerdp-touch`.
  implication: The device runs the current diagnostic build, so the least-invasive next experiment is a bounded on-device capture rather than speculative new instrumentation.

- timestamp: "2026-08-10T15:26:16Z"
  checked: Debugger agent-skill configuration, project skill directories, and persistent knowledge base before reading the supplied capture.
  found: No `gsd-debugger` agent skill or project skill directory is configured; the only knowledge-base entry concerns a host-Xwayland session-validation bug and shares no touch-delivery mechanism.
  implication: No prior-resolution hypothesis supersedes the existing XI2/recognizer/remote fault tree; analyze the new bounded capture as the primary discriminator.

- timestamp: "2026-08-10T15:28:50Z"
  checked: Complete supplied capture's normalized `touch-diag` record types.
  found: The session contains 69 XI2 `Begin` records, 69 matching `End` records, and 69 `synth left-tap` records, plus 347 updates; no long-press cancellation, multi-finger, recovery-gate, or content-rejection diagnostic appears.
  implication: For every captured contact that reached the dispatcher, the recognizer emitted a synthetic left-click pair. XI2 delivery and the recognizer are not the selective drop boundary in this capture; correlate pairs and inspect the unobserved send/remote boundary next.

- timestamp: "2026-08-10T15:30:46Z"
  checked: Timing, coordinate, and anchor correlation for every completed lifecycle, plus non-diagnostic warnings/errors after touch input began.
  found: Nineteen rapid double-tap candidates (151–192 ms apart) emitted both synthesized clicks at identical anchored coordinates. Five other rapid candidates (141–182 ms apart) emitted their second click 12.65–16.64 px away: (1111,531)->(1122,523), (1088,529)->(1102,520), (1036,548)->(1048,537), (1380,529)->(1382,515), and (1346,529)->(1358,533). The only later warning/error is normal user logoff; no connection/input-send error is logged during touch activity.
  implication: Successful-shaped pairs preserve coordinates, while the rare likely failures have an equally fast second click at a different coordinate. This directly supports the finite anchor-slop condition as a code candidate; verify its exact inequality and test boundary behavior before fixing. Lack of send-result telemetry remains a secondary blind spot, not the leading explanation.

- timestamp: "2026-08-10T15:31:58Z"
  checked: Complete short-tap branch of `xf_input_touch_fallback` in the maintained patch.
  found: The branch reuses the first tap coordinate only when `tapPairValid`, the second tap ends within the 500 ms duration, and `hypot(secondBegin - firstBegin) <= FreeRDP_TouchLongPressSlopPx` (default 12); otherwise it sends the second click at its own begin coordinate. It clears `tapPairValid` after a reused anchor. Every five unanchored rapid capture pair exceeds 12 px Euclidean distance, while all nineteen anchored pairs necessarily satisfy the predicate.
  implication: The observed branch behavior exactly explains the coordinate split. The leading root-cause candidate is not missing input: coupling double-tap anchoring to a 12 px long-press/drag slop lets normal OneMix 3 retaps bypass the remote double-click spatial tolerance.

- timestamp: "2026-08-10T15:33:15Z"
  checked: Complete nearest production-path helper regression harness and maintained repository source layout.
  found: `tests/xf_touch_internal_check.c` tests classifier, quarantine, bounds, pinch, and diagnostic helper logic but has no double-tap anchor predicate case. The maintained source is the quilt patch; no unpacked `xf_input.c` is committed, and the harness is designed to compile against the temporary build tree with production constants.
  implication: Regression coverage must exercise a shared production helper rather than duplicate the fallback predicate in a test. The patch/header definitions are the remaining source context needed to select a minimal decoupled anchor tolerance.

- timestamp: "2026-08-10T15:34:37Z"
  checked: Complete shared helper-header definition and touch setting/parser hunks.
  found: `xf_touch_internal.h` is explicitly the dependency-free production/test seam and currently lacks an anchor helper. `/touch-slop` is constrained to 4–16 px and drives not only tap anchoring but also one-, two-, and three-finger drag/pan thresholds. The capture includes a 16.64 px rapid retap, so no supported calibration value can cover it; raising this setting would also loosen gesture recognition.
  implication: The root cause is confirmed as coupled calibration, not a user calibration choice. The smallest safe policy is a dedicated fixed double-tap anchor floor above the observed 16.64 px while retaining `/touch-slop:12` for drag/pan; the existing production dispatcher test is the correct regression site.

- timestamp: "2026-08-10T15:42:48Z"
  checked: Newly added production-dispatcher capture-vector regression in a temporary quilt-applied source tree.
  found: `ctest -R ^TestXfInputDispatcher$` fails before the fix with `FAIL: 16.64px rapid retap reuses the first adjusted coordinate`. The test target compiled and ran; the failure is the expected second click coordinate assertion, not a harness/build failure.
  implication: The root cause is deterministically reproduced in the actual dispatcher. A separate 20 px double-tap anchor floor is now the smallest falsified-then-supported fix; preserve the existing 31 px and 550 ms negative cases.

- timestamp: "2026-08-10T15:45:56Z"
  checked: Rebuilt production `TestXfInputDispatcher` after replacing the coupled anchor comparison with `DOUBLE_TAP_ANCHOR_SLOP_PX` at 20 px.
  found: The target passes. Its capture-shaped 16.64 px rapid retap now reuses the original coordinate; its 31 px rapid retap and 550 ms-old tap remain independent; the same suite retains the 13 px one-finger drag, 12 px two-/three-finger, quarantine, and diagnostics checks. Compilation emits only an unrelated existing deprecated `codecs_free` warning.
  implication: The minimal fix has deterministic production-path coverage for the original branch and adjacent gesture boundaries. Refresh the quilt patch and validate clean application before requesting on-device confirmation.

- timestamp: "2026-08-10T15:47:06Z"
  checked: Canonical quilt refresh and maintained-patch update.
  found: `quilt refresh` regenerated `debian/patches/onemix-touch.patch` from the tested temporary source and the refreshed patch was copied to `patches/onemix-touch.patch`. Quilt reported one pre-existing trailing-whitespace warning at `client/X11/xf_input.c:334`, outside the new anchor-floor branch.
  implication: The repository now contains the exact tested source and regression change. Run diff hygiene and a fresh patch-application smoke to ensure no patch-format or unrelated-whitespace regression remains.

- timestamp: "2026-08-10T15:48:12Z"
  checked: Maintained-patch diff hygiene after refresh.
  found: `git diff --check` is clean, but `quilt refresh` used the temporary directory basename and rewrote every patch header from `freerdp3-3.15.0+dfsg` to `freerdp-touch-rare-double-tap`, creating a non-minimal whole-patch metadata diff. The only intended content changes are the 20 px anchor floor and dispatcher regression.
  implication: Do not accept this refresh. Regenerate the exact same tested patch from a source tree named `freerdp3-3.15.0+dfsg`, then re-run application/test checks; this packaging correction does not alter the root-cause fix.

- timestamp: "2026-08-10T15:49:00Z"
  checked: Regeneration from the canonical `freerdp3-3.15.0+dfsg` source-tree basename.
  found: The tested tree was moved without source changes, `quilt refresh` completed, and the regenerated patch replaced the maintained copy. Quilt again reports only the existing unrelated trailing whitespace at `xf_input.c:334`.
  implication: Patch filenames should now match the Debian source convention; verify the final diff and fresh application before accepting the fix.

- timestamp: "2026-08-10T15:50:17Z"
  checked: Final maintained-patch diff and whitespace gate.
  found: `git diff --check` passes. Patch headers retain `freerdp3-3.15.0+dfsg`; the only functional hunks add `DOUBLE_TAP_ANCHOR_SLOP_PX 20`, use it for the tap-pair predicate, and extend `TestXfInputDispatcher` with the 16.64 px positive plus 31 px/550 ms negative boundaries. The remaining hunk-header offsets are the necessary result of those source-line changes.
  implication: The checked-in diff is minimal and targeted. Verify clean application from a fresh source package and run the applicable repository test suite without creating or publishing packages.

- timestamp: "2026-08-10T15:51:00Z"
  checked: Fresh `BUILD_RELEASE_SMOKE=1 scripts/build-release.sh` run using the maintained patch.
  found: Fresh Debian source extraction, full quilt stack application (including the modified `xf_input.c` and dispatcher test), version assertion, and classifier regression all pass. The smoke exits before `dpkg-buildpackage`, bundle assembly, installation, or publication.
  implication: The maintained patch applies cleanly in the supported release workflow without producing packages. Run the repository's local regression checks next.

- timestamp: "2026-08-10T15:53:10Z"
  checked: Applicable repository shell/Python/standalone-C regressions and a repeated dispatcher-test invocation.
  found: `check_x11_session_check.sh`, `menu_diagnostic_env_check.sh`, `readme_doc_regression.sh`, `wrapper_production_check.sh`, `build_release_signal_check.sh` (isolated mocks only), `check_third_finger_owner.py`, `gap01_ownership_layout.c`, `pinch_reversal_check.c`, and `xf_touch_internal_check.c` all pass. The dispatcher ctest rerun was not executed because moving the temporary tree left CMake's generated test command pointing at the old absolute path; this is a stale-build-path error, not a failed assertion. `gap05_parser_check.sh` is not applicable because it requires a newly built four-package bundle and package builds/publishing are out of scope.
  implication: Reconfigure the canonical temporary source into a fresh build directory and rerun `TestXfInputDispatcher`; do not treat the stale generated path as product-test evidence.

- timestamp: "2026-08-10T15:56:49Z"
  checked: Fresh CMake configuration/build and ctest execution from the canonical, quilt-applied source tree.
  found: `TestXfInputDispatcher` passes in the fresh `build-verify` directory (0.18 s). Configure/build reports existing optional-cJSON discovery and deprecated `codecs_free` warnings but no failure.
  implication: The exact source represented by the maintained patch passes the driving production-dispatcher regression after a clean rebuild. Proceed with the guardrail's mutation/revert confirmation.

- timestamp: "2026-08-10T15:57:54Z"
  checked: Scoped manual mutation/revert at the fixed production predicate, with the agent-authored dispatcher regression retained.
  found: No Stryker configuration or JavaScript manifest exists. Changing only `DOUBLE_TAP_ANCHOR_SLOP_PX` from 20 to 12 (behavior-equivalent to the original default predicate for this zero-calibration test) recompiles and deterministically fails `TestXfInputDispatcher` on `16.64px rapid retap reuses the first adjusted coordinate`.
  implication: The driving regression kills the fix-site mutation and the original bug returns on a scoped revert. Restore 20 and confirm green to complete both mutation and revert-and-reconfirm signals.

- timestamp: "2026-08-10T15:59:10Z"
  checked: Reapplied 20 px fix after the scoped revert/mutation.
  found: Rebuilding the production dispatcher target with `DOUBLE_TAP_ANCHOR_SLOP_PX=20` returns `TestXfInputDispatcher` to green (0.17 s), including the capture vector and both negative boundaries.
  implication: The same one-line anchor floor is causally necessary and sufficient for the deterministic reproduction; prepare final no-op/patch-integrity evidence and record the accepted guardrail verdict.

- timestamp: "2026-08-10T16:00:04Z"
  checked: Final maintained-patch integrity after the scoped revert/reapply.
  found: The maintained patch is byte-identical to the re-applied temporary quilt patch, and `git diff --check` passes.
  implication: The non-deletion, targeted change and its regression test are the exact sources previously green-tested; all applicable fix-acceptance signals now pass or are explicitly unavailable.

- timestamp: "2026-08-10T16:20:38Z"
  checked: "Human-verification response, commit `809e1f3`, installed package closure, dpkg install log, and the `xfreerdp3` payload hash in the retained bundle."
  found: "The user reported `đã chạy và ok hơn. chốt cái này cho tôi`. Commit `809e1f3dd92f04f061028cbfff0e9ce8816ec976` exists and changes only `patches/onemix-touch.patch`. All four `+onemix1` packages are installed; dpkg records each as reinstalled at 2026-08-10 23:09:46 local time. `/usr/bin/xfreerdp3` and the bundle payload both SHA256 to `e681d26db36abb85612ff2ee60a0501c133f94a89949718369e82a1b46b7d331`."
  implication: "The exact tested patch is deployed in the user’s actual package closure, and the user has explicitly accepted observed improvement. Acceptance is deliberately bounded to improved real-workflow behavior rather than an assertion of absolute elimination of every rare miss."

- timestamp: "2026-08-10T16:23:19Z"
  checked: "MemPalace archive-index eligibility after the successful durable knowledge-base append."
  found: "Planning state reports `mempalace.enabled: false`; no MemPalace index is available for this project."
  implication: "The knowledge-base entry is the durable recurrence-recall record; semantic indexing is intentionally skipped rather than silently failing."

## Eliminated

- hypothesis: The `touch-diag: touch` entry logger prints uninitialized local coordinates.
  evidence: The complete applied source formats `event->event_x` and `event->event_y`, not the local `x` and `y` variables.
  timestamp: "2026-08-10T15:00:26Z"

- hypothesis: Dynamic `FreeRDP_SuspendInput` drops only the rare second tap.
  evidence: The active launcher never sets it, source search found no project runtime writer, and its enabled behavior would suppress every keyboard/mouse input rather than selectively one tap.
  timestamp: "2026-08-10T15:04:17Z"

## Resolution

- root_cause: "`xf_input_touch_fallback` couples double-tap coordinate anchoring to `FreeRDP_TouchLongPressSlopPx` (default 12 px; user-configurable maximum 16 px). The capture proves normal 12.65–16.64 px rapid retaps bypass that predicate and synthesize the second click at a different coordinate, so Windows treats the two click pairs as separate single clicks."
- oracle_type: "specified — the user requires two rapid taps on the same folder to produce two complete left-click pairs at the same coordinate; the 16.64 px case is a captured boundary instance."
- fix: "Add a dedicated `DOUBLE_TAP_ANCHOR_SLOP_PX` floor of 20 px for rapid tap-pair coordinate reuse, preserving the existing 12 px `/touch-slop` behavior for long-press/drag/pan; add a production dispatcher regression for the captured 16.64 px vector plus 31 px and 550 ms negative boundaries."
- fix_commit: "809e1f3dd92f04f061028cbfff0e9ce8816ec976 — fix: decouple double-tap anchor tolerance"
- verification:
  target_test: { result: pass, command: "ctest -R ^TestXfInputDispatcher$", evidence: "capture-shaped 16.64 px retap reuses the first coordinate" }
  mutation_check: { result: skipped, reason_if_skipped: "No Stryker configuration or JavaScript manifest; scoped 20->12 manual fix-site mutation was killed by the driving test", mutant_killed: true }
  no_op_deletion: { result: pass, deletion_justified_by_rca: true, evidence: "diff adds an anchor floor and regression boundaries; removed slop read only decouples the predicate" }
  adjacent_tests: { result: pass, suites_run: ["fresh TestXfInputDispatcher", "BUILD_RELEASE_SMOKE", "9 local shell/Python/C regressions"], skipped: "gap05_parser_check requires a newly built package bundle, prohibited by current scope" }
  revert_and_reconfirm: { result: pass, bug_returned_on_revert: true, fixed_on_reapply: true, evidence: "temporary 20->12 revert failed the same assertion; restore to 20 passed" }
  deployment: { result: pass, packages: "freerdp3-x11, libfreerdp-client3-3, libfreerdp3-3, libwinpr3-3 all at 3.15.0+dfsg-2.1+deb13u3+onemix1", reinstall_log: "2026-08-10 23:09:46 local", binary_sha256: "e681d26db36abb85612ff2ee60a0501c133f94a89949718369e82a1b46b7d331", evidence: "installed binary equals retained bundle payload" }
  human_verification: { result: accepted_bounded, evidence: "User observed improvement in the real workflow and explicitly requested closure", limitation: "acceptance does not prove absolute elimination of every rare miss" }
  guardrail_verdict: accepted
- files_changed:
  - "patches/onemix-touch.patch (X11 fallback implementation and TestXfInputDispatcher regression)"

## Prevention

- branching_5_whys:
  - code: "The fallback reused `FreeRDP_TouchLongPressSlopPx` for two unrelated policies. Its 12 px default and 16 px maximum were chosen for long-press/drag/pan control, so ordinary 16.64 px rapid retaps did not reuse the first remote coordinate. No independent double-tap anchor policy existed."
  - remote_config: "Windows correctly applies its spatial double-click classification to the remote coordinates it receives. When the coupled client predicate emitted distinct coordinates, that normal remote policy converted the interaction into separate single clicks; retaining the first coordinate removes the controllable contributing condition."
  - environment: "XI2 delivery was considered and ruled out by 69 complete Begin/End/synthesis lifecycles in the native-X11 capture; it was not a contributing condition in this incident."
  - and_gate: "The visible single-click behavior required both a rapid retap outside the coupled threshold and Windows receiving distinct coordinates. The fix changes only the client-side coordinate condition."
- why_not_caught: "No regression gate covered capture-shaped double-tap coordinate separation beyond the drag/long-press slop. The existing dispatcher coverage exercised adjacent gesture logic but not a 16.64 px rapid-retap anchor boundary."
- recurrence_guard: "`client/X11/test/TestXfInputDispatcher.c` in `patches/onemix-touch.patch` now asserts that the captured 16.64 px rapid retap reuses the first coordinate while 31 px and 550 ms cases remain independent; it passed via `ctest -R ^TestXfInputDispatcher$` and killed the scoped 20->12 revert mutation."

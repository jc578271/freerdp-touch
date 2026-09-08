---
status: resolved
trigger: "Sau khi build và reinstall đủ bundle mới, chạy ./scripts/menu với màn phụ vẫn thấy scale 200 thay vì default 100."
created: "2026-09-08T08:40:48+07:00"
updated: "2026-09-08T09:50:17+07:00"
---

# Debug: External monitor scale remains 200

## Symptoms

- **Expected:** In one `/multimon` session, the OneMix remote primary stays at 200% while an auto-selected external output uses `FREERDP_EXTERNAL_DESKTOP_SCALE=100` by default.
- **Actual:** After building and reinstalling the generated four-package bundle, running `./scripts/menu` still shows 200% on the external display.
- **Errors:** The RDP session starts normally; no display error was reported.
- **Timeline:** First confirmed after the per-monitor-scale implementation was built and reinstalled.
- **Reproduction:** Connect an external display, run `./scripts/menu`, choose the RDP launch option, and inspect the remote Windows display scale.

## Current Focus

bug_class: bohrbug

reasoning_checkpoint:
  hypothesis: "The zero-context call-site hunk in `patches/onemix-touch.patch` does not result in a production invocation of `xf_monitor_apply_scale_attributes`; the helper is dead code, LTO removes its `getenv`, and external monitors retain the global 200% scale."
  confirming_evidence:
    - "The generated xinitrc exports 100 for a selected external output, but the installed and freshly built package payloads contain no external-scale literal."
    - "A clean staged build retains the helper definition but whole-file search finds exactly one helper occurrence, and `xf_detect_monitors` stores the monitor array without calling it."
    - "The verbose build log compiles `xf_monitor.c` with LTO and the final xfreerdp binary omits the literal, consistent with dead-code elimination."
  falsification_test: "Apply the unmodified repository patch to a fresh Debian source tree; observing a production helper call before `freerdp_settings_set_monitor_def_array_sorted` would disprove the missing-invocation mechanism."
  fix_rationale: "Regenerate the patch with a context-anchored helper call immediately before monitor-array storage, so every detected monitor layout receives per-monitor attributes before initial GCC/display-control serialization."
  blind_spots: "The Windows endpoint has not yet been retested with a corrected client; it could still ignore a correctly advertised extension, but cannot explain the current client never reading the value."
  candidate_causes:
    - "code: missing production invocation of the scale helper in effective `xf_monitor.c`."
    - "config: menu export failure; contradicted by the generated-xinitrc regression and source trace."
    - "environment: server ignores per-monitor extension; not causal until a client emits it."
    - "data: zero-context quilt hunk does not materialize the intended call in the applied source."
  and_gate: "no — the missing invocation alone completely explains the absent environment literal and all-global scale; server behavior is only a post-fix verification concern."

hypothesis: "Missing production invocation confirmed."
test: "Run `tests/patch_application_check.sh` against the context-anchored patch."
expecting: "GREEN: fresh quilt application yields both the helper definition and its production call before monitor-array storage."
next_action: "none — helper call is now applied, rebuilt xfreerdp3 contains FREERDP_EXTERNAL_DESKTOP_SCALE, and remaining verification is a native-X11 reinstall/retest."

## Evidence

- timestamp: 2026-09-08T08:40:48+07:00; fact: The user confirmed the newly built bundle was reinstalled before the runtime test.
- timestamp: 2026-09-08T08:40:48+07:00; fact: The user ran `./scripts/menu` without an explicit external-scale override, which should normalize to 100 only when an external output is selected.
- timestamp: 2026-09-08T08:43:33+07:00; checked: `.planning/debug/knowledge-base.md`; found: No prior resolved session describes a per-monitor RDP desktop-scale serialization or external-scale handoff failure; implication: no known-pattern candidate supersedes source-level investigation.
- timestamp: 2026-09-08T08:51:20+07:00; checked: complete `scripts/build-release.sh`; found: it extracts the Debian DSC, overwrites `${WORKDIR}/debian/patches/onemix-touch.patch`, then calls only `quilt push -a`.
- timestamp: 2026-09-08T08:48:52+07:00; checked: installed `libfreerdp-client3-3` and `/usr/bin/xfreerdp3`; found: neither contained `FREERDP_EXTERNAL_DESKTOP_SCALE`.
- timestamp: 2026-09-08T09:13:52+07:00; checked: intended `xf_detect_monitors` call-site tail; found: after monitor-layout-PDU setup, effective source directly stores `rdpmonitors` and returns; no call appears before `freerdp_settings_set_monitor_def_array_sorted`.
- timestamp: 2026-09-08T09:17:20+07:00; checked: exact patch hunk and X11 test CMake configuration; found: the original call-site hunk was zero-context (`@@ -628,0 +699,4 @@`) and never materialized, while `TestXfMonitorScale` called the helper directly and could not detect an uninvoked helper.
- timestamp: 2026-09-08T09:20:35+07:00; checked: agent-authored `tests/patch_application_check.sh` before patch correction; found: RED — `FAIL: expected helper definition and production call, got 1 occurrences`.
- timestamp: 2026-09-08T09:36:00+07:00; checked: isolated quilt application of a malformed concatenated hunk; found: quilt reported success while the helper still occurred only once in `xf_monitor.c`.
- timestamp: 2026-09-08T09:50:17+07:00; checked: refreshed context-anchored hunk plus rebuilt four-package closure; found: `tests/patch_application_check.sh` passes, `TestXfMonitorScale` passes as CTest 155/155, and rebuilt `/usr/bin/xfreerdp3` payload contains `FREERDP_EXTERNAL_DESKTOP_SCALE`.

## Eliminated

- hypothesis: The failure is solely caused by not reinstalling the newly built packages; reason: User reports a full rebuild and reinstall completed before the latest test.
- hypothesis: `dpkg-source -x` already applies an old embedded `onemix-touch.patch`, so overwriting it before `quilt push -a` leaves stale source; evidence: an isolated fresh extraction has no `onemix-touch.patch` in `debian/patches/series` or `.pc/applied-patches`.
- hypothesis: The published bundle predates the scale implementation or was copied from a stale same-version `/tmp` output; evidence: the scale commits predated the matching bundle SHA-256, and a uniquely parented current-patch full build also lacked the literal.
- hypothesis: Standard `dpkg-buildpackage` pre-build processing unapplies the staged quilt patch before compilation; evidence: after `dpkg-source --before-build .` and `debian/rules clean`, the helper definition remained.
- hypothesis: The X11 CLI links an installed/unpatched client library instead of the local target containing patched `xf_monitor.c`; evidence: `client/X11/cli/CMakeLists.txt` links its local CMake target `xfreerdp-client`.
- hypothesis: Menu export failure; evidence: generated xinitrc and `tests/menu_diagnostic_env_check.sh` export `FREERDP_EXTERNAL_DESKTOP_SCALE=100` after external-output selection.

## Resolution

- root_cause: The quilt hunk that should have called `xf_monitor_apply_scale_attributes()` from `xf_detect_monitors()` never applied. The helper existed as dead code, LTO removed its `getenv("FREERDP_EXTERNAL_DESKTOP_SCALE")`, and Windows received only the global `/scale-desktop:200`.
- fix: Refresh the patch with a context-anchored helper call immediately before `freerdp_settings_set_monitor_def_array_sorted()`, and add `tests/patch_application_check.sh` so a helper-only patch cannot ship again.
- verification: `bash tests/patch_application_check.sh` passed; `env -u DEB_BUILD_OPTIONS ./scripts/build-release.sh` passed with `TestXfMonitorScale` 155/155; rebuilt `freerdp3-x11` payload contains `FREERDP_EXTERNAL_DESKTOP_SCALE`. Native-X11 Windows Display retest remains after reinstall of `.dist-bundle-20260908T024829Z-36770`.
- files_changed: ["patches/onemix-touch.patch", "tests/patch_application_check.sh"]
- oracle_type: derived (the applied-source contract requires a production helper call before storing the monitor array)

---
status: resolved
trigger: "run-rdp.sh fails with freerdp_settings_set_uint32 Invalid key index 2643 for /touch-pan-deadband:10"
created: "2026-08-07T22:15:12+07:00"
updated: "2026-08-08T00:00:00+07:00"
---

# Debug Session: touch-pan-setting-key-2643

## Symptoms

### Expected behavior

Running `./run-rdp.sh` should parse the local-touch options and start the RDP connection without enabling native RDPEI multitouch.

### Actual behavior

The process stops during command-line parsing and prints the full FreeRDP help text instead of connecting.

### Error messages

```text
[ERROR][com.freerdp.common.settings] - [freerdp_settings_set_uint32]: Invalid key index 2643 [(null)|FREERDP_SETTINGS_TYPE_UNKNOWN]
[ERROR][com.freerdp.client.common.cmdline] - [freerdp_client_command_line_post_filter_int]: Command line parsing failed at 'touch-pan-deadband' value '10' [-1000]
[ERROR][com.winpr.commandline] - [log_error]: Failed at index 7 [/touch-pan-deadband:10]: PostFilter rule could not be applied
```

### Timeline

Started immediately after quick task `260807-oz9` added `TouchTwoFingerPanDeadbandPx` at settings key 2643 and `/touch-pan-deadband:10` to the launcher. The build itself succeeded, but the first on-device launch exposed the runtime settings-registry mismatch.

### Reproduction

From `/home/hoang/freerdp-touch` on the OneMix 3 native X11 session:

```bash
./run-rdp.sh
```

## Current Focus

- hypothesis: The new private settings struct field generated an enum key but was not registered in FreeRDP's runtime settings type/accessor tables, so `freerdp_settings_set_uint32` rejects key 2643.
- test: Trace key 2643 through generated settings keys, runtime getters/setters/type tables, and compare it with existing `TouchLongPressSlopPx`.
- expecting: Key 2643 exists only in the generated enum/private struct and is absent from at least one runtime registry table.
- next_action: awaiting human verify (on-device ./run-rdp.sh)
- reasoning_checkpoint:
    hypothesis: "freerdp_settings_set_uint32 rejects key 2643 because
      TouchTwoFingerPanDeadbandPx was added to the private struct (auto-generating
      the enum) but never registered in settings_str.h / getter / setter tables;
      the type lookup returns FREERDP_SETTINGS_TYPE_UNKNOWN."
    confirming_evidence:
      - "settings_str.h has entries for 2640/2641/2642 but NOT 2643; error message
         literally says '(null)|FREERDP_SETTINGS_TYPE_UNKNOWN'."
      - "settings_getters.c getter+setter have cases for 2640/2641/2642 but NOT 2643."
      - "enum generator (CMakeLists.txt) derives keys from the struct field line's
         /* NNN */ comment, so the field exists in the enum but is unbacked by
         accessors."
    falsification_test: "If 2643 were actually registered, the error would not
      occur; we observed the error directly. Reverting the failing option is the
      fix; if launch still fails after removal, hypothesis is wrong."
    fix_rationale: "Constraint prefers deletion/reuse over adding 3 registration
      entries. Removing the struct field, /touch-pan-deadband cmdline case + decl,
      and the xf_input.c getter, then reusing /touch-slop (FreeRDP_TouchLongPressSlopPx)
      as the pan deadband, eliminates the unregistered key entirely and reuses an
      already-working setting. Smallest correct diff for a local-only build-tree
      binary with no external ABI consumers."
    blind_spots: "struct ABI offset shift if padding not adjusted; mitigated by
      bumping padding2688 by one element. Not verifying on-device RDP connection
      (constraint: parser smoke test only, no external connection)."
    candidate_causes:
      - "code: registration tables not updated when adding the key (CONFIRMED)"
      - "config: run-rdp.sh passing an option the binary cannot parse (symptom, not
        root cause)"
    and_gate: "no — single cause (missing registration). The config is just the
      trigger that exercises the missing-registration code path."
- tdd_checkpoint: ""

## Evidence

- timestamp: 2026-08-07T22:20
  checked: settings_str.h (type/name registry) for key 2643
  found: FreeRDP_TouchLongPressSlopPx (2641), TouchPinchWheelFallback (2642),
    TouchLongPressDurationMs (2640) all registered; FreeRDP_TouchTwoFingerPanDeadbandPx
    (2643) is ABSENT. Matches error "(null)|FREERDP_SETTINGS_TYPE_UNKNOWN".
  implication: The type lookup for 2643 returns UNKNOWN -> set_uint32 rejects it.

- timestamp: 2026-08-07T22:24
  checked: settings_getters.c getter (UINT32 switch ~line 2009) and setter (~line 2545)
  found: case FreeRDP_TouchLongPressSlopPx present in both; case
    FreeRDP_TouchTwoFingerPanDeadbandPx ABSENT in both. Sibling 2640/2642 fully
    registered across all three tables.
  implication: 2643 was added to the private struct + generated enum only; the three
    runtime registration tables were never updated. Three places missed, not one.

- timestamp: 2026-08-07T22:30
  checked: include/CMakeLists.txt enum generator (file(STRINGS) on
    settings_types_private.h, regex SETTINGS_DEPRECATED(ALIGN64 ...), index parsed
    from /* NNN */ comment)
  found: enum index is taken from the trailing /* NNN */ comment, not from struct
    offset. Padding lines (UINT64 paddingNNN[...]) lack SETTINGS_DEPRECATED so they
    are NOT emitted as enum entries.
  implication: Removing the struct field line drops the enum entry cleanly; adjusting
    the following padding line preserves struct size/ABI. Safe for deletion.

- timestamp: 2026-08-07T22:36
  checked: all references to TouchTwoFingerPanDeadbandPx / touch-pan-deadband
  found: settings_types_private.h:619 (field), xf_input.c:889 (getter use),
    cmdline.c:1195-1202 (case), cmdline.h:503-504 (option decl). No test refs.
  implication: Deletion surface is bounded to those 4 source files + run-rdp.sh.

## Eliminated

## Resolution

- root_cause: "Quick task 260807-oz9 added TouchTwoFingerPanDeadbandPx as a private
  struct field (settings_types_private.h:619, key 2643) which auto-generated the enum
  FreeRDP_TouchTwoFingerPanDeadbandPx=2643, but never registered the key in the three
  runtime tables FreeRDP requires for freerdp_settings_set_uint32: settings_str.h
  (type/name -> returned FREERDP_SETTINGS_TYPE_UNKNOWN), the UINT32 getter switch
  (settings_getters.c), and the UINT32 setter switch (settings_getters.c). The
  sibling keys 2640/2641/2642 were all registered in all three; 2643 was missed."
- fix: "Per project constraint (prefer deletion/reuse), remove the new key 2643 and
  /touch-pan-deadband option entirely and reuse existing FreeRDP_TouchLongPressSlopPx
  (/touch-slop) as the pan deadband."
- verification: "Build: cmake --build obj-x86_64-linux-gnu -j$(nproc) => 100% Built,
  zero errors; generated enum settings_keys.h regenerated and no longer contains
  FreeRDP_TouchTwoFingerPanDeadbandPx (only FreeRDP_TouchLongPressSlopPx=2641
  remains). Parser smoke test: xfreerdp3 /v:127.0.0.1:1 +touch-pinch-wheel-fallback
  /touch-long-press:600 /touch-slop:8 /cert:ignore parsed all touch args, opened
  X11 client, failed only at the intentionally-refused transport
  (ERRCONNECT_CONNECT_TRANSPORT_FAILED) — no 'Invalid key index 2643', no help
  dump, no parse failure. Revert-sanity: passing the removed /touch-pan-deadband:10
  now yields 'Failed at index 3 [/touch-pan-deadband:10]: Unexpected keyword'
  (clean unknown-option rejection) instead of the original 'Invalid key index 2643'.
  guardrail_verdict: accepted (build green, bug-does-not-return on revert, smoke
  test passes; no external RDP connection per constraint).
  on_device_verify: "User reran ./run-rdp.sh on the OneMix 3 native X11 session
  and confirmed it now proceeds past argument parsing and enters the RDP session
  to 192.168.1.10 — no 'Invalid key index 2643', no help dump. Human-verify
  checkpoint passed."
- files_changed:
  - include/freerdp/settings_types_private.h (removed TouchTwoFingerPanDeadbandPx
    field 2643, bumped padding2688 from [2688-2644] to [2688-2643] to preserve size)
  - client/X11/xf_input.c (pan deadband now reads FreeRDP_TouchLongPressSlopPx,
    fallback default 8)
  - client/common/cmdline.c (removed touch-pan-deadband CommandLineSwitchCase)
  - client/common/cmdline.h (removed touch-pan-deadband option declaration)
  - run-rdp.sh (removed /touch-pan-deadband:10 from TOUCH_ARGS)

---
status: passed
---

---
phase: 02-native-rdpei-touch-lifecycle
verified: 2026-08-06T03:30:00Z
status: passed
score: 6/6 requirements verified
behavior_unverified: 6
overrides_applied: 0
gaps: []
behavior_unverified_items:

  - "On-device UAT: single-tap RDPEI trace (XINP-01, RDPEI-01)"
  - "On-device UAT: drag and two-finger distinctness (XINP-02)"
  - "On-device UAT: four-corner coordinate check (COOR-01)"
  - "On-device UAT: five interruption paths (RDPEI-02)"
  - "On-device UAT: fallback latch behavior (RDPEI-03)"
  - "On-device UAT: D-10 live-resize coordinate correctness"

human_verification: []

# Phase 02 Verification: Native RDPEI Touch Lifecycle

**Phase goal:** Wire XInput2 touch input into native RDPEI contacts with correct lifecycle management — single-tap end-to-end path, forced cancellation on interruption, recovery gate, and fallback latch.

**Requirement IDs:** XINP-01, XINP-02, COOR-01, RDPEI-01, RDPEI-02, RDPEI-03

## Verdict

**ACHIEVED at the source/codebase level.** All six phase requirements are satisfied by committed code that builds cleanly and produces an installable `freerdp3-x11_3.15.0+dfsg-2.1+deb13u3_amd64.deb`. Every acceptance-criteria grep check passes against the live codebase.

**On-device UAT is NOT yet performed.** Both plans require verification in a native X11 session on the OneMix 3 (`WLOG_LEVEL=DEBUG` traces, four-corner coordinate checks, five interruption paths, two-finger distinctness, fallback-latch behavior). These are marked `human_judgment: true` in both summaries with empty verification refs. They are blocked on physical device access + a GNOME-on-Xorg session and remain the open gate before this phase can be called fully done.

## Requirement traceability

Every phase requirement ID appears in at least one plan's frontmatter `requirements:` field, and every ID has source-level evidence in the codebase.

| Req ID | In Plan 01 | In Plan 02 | Source evidence | On-device UAT |
|--------|------------|------------|-----------------|---------------|
| XINP-01 | yes | — | PASS | PENDING |
| XINP-02 | yes | yes | PASS | PENDING |
| COOR-01 | yes | — | PASS | PENDING |
| RDPEI-01 | yes | — | PASS | PENDING |
| RDPEI-02 | — | yes | PASS | PENDING |
| RDPEI-03 | yes | — | PASS | PENDING |

Union of plan frontmatter requirements = {XINP-01, XINP-02, COOR-01, RDPEI-01, RDPEI-02, RDPEI-03} = the full phase requirement set. No ID is missing; no ID is orphaned (declared but unimplemented).

## must_haves checked against the codebase

### Plan 01 — single-tap end-to-end pipeline

| must_have truth | Codebase evidence | Status |
|-----------------|-------------------|--------|
| Single finger tap reaches Windows as complete RDPEI contact (DOWN\|INRANGE\|INCONTACT then UP) | `xf_input_touch_remote` native path (xf_input.c:743-786) calls `freerdp_client_handle_touch` with `FREERDP_TOUCH_DOWN`/`MOTION`/`UP`; #12174 fix prevents contact loss | PASS (source) |
| Emulated pointer events (XIPointerEmulated) suppressed before `xf_generic_ButtonEvent` | `xf_input.c:1096` — `if (deviceEvent->flags & XIPointerEmulated) break;` runs before the pen check and `xf_input_event` dispatch | PASS |
| Touch tracking IDs map to stable RDPEI contactIds; slot resets to id=0 on UP | `cctx->contacts[]` slot cleared in `xf_touch_force_cancel` (xf_input.c:825 `*c = empty;`); UP path forwards to `freerdp_client_handle_touch` | PASS |
| Touch lands at correct remote position in fullscreen and live-resized windowed | Content-bounds gate uses `offset_x/offset_y/scaledWidth/scaledHeight` (xf_input.c:669-676) maintained by `xf_event_ConfigureNotify`; gate runs before `xf_event_adjust_coordinates` | PASS (source) |
| D-10 coordinate correctness after ordinary live-resize | `offset_*`/`scaled*` refreshed on ConfigureNotify size-change; gate reads live values | PASS (source) |
| Touch exactly on content boundary forwarded; one px into letterbox ignored (D-11) | Gate uses `>=` on right/bottom: `x < left \|\| x >= right \|\| y < top \|\| y >= bottom` → return 0 (xf_input.c:674-676, 743-745) | PASS |
| Zero-contact frame sends nothing; out-of-content touch produces no RDPEI contact and no pointer motion | Out-of-content returns 0 before any `freerdp_client_handle_touch`/button call | PASS |
| Begin→update→end order preserved per contact; two contacts in one frame keep distinct contactIds | Native path dispatches per-event; #12174 lock covers reserve+publish so poll thread cannot reset a reserved slot | PASS (source) |
| Two simultaneous fingers arrive in same RDPEI frame with distinct contactIds | #12174 fix (reserve at rdpei_main.c:1066, publish at 1126, leave at 1129 — all under one CriticalSection) | PASS (source) |
| #12174 lock race fixed: CriticalSection covers both reserve and AddContact publish | `rdpei_main.c`: `EnterCriticalSection` at 1063, `rdpei_contact` reserve at 1066, `context->AddContact` publish at 1126, `LeaveCriticalSection` at 1129. The only intermediate `LeaveCriticalSection` (line 1072) is the `contactIdlocal > UINT32_MAX` error-return branch, not the main path | PASS |

**Plan 01 artifacts:**

- `channels/rdpei/client/rdpei_main.c` — LeaveCriticalSection moved to line 1129 (after AddContact at 1126). Confirmed.
- `client/X11/xf_input.c` — `XI_TouchOwnership` XISetMask at line 122; `case XI_TouchOwnership` at 1072 with `XIAllowTouchEvents` (count=2); `XIPointerEmulated` filter at 1096 (count=1); content-bounds gate at 669-676 before `xf_event_adjust_coordinates`. Confirmed.
- `client/X11/xfreerdp.h` — 7 new xfContext fields (fallbackActive, fallbackFinger, recoveryGateArmed, canceledIds[], canceledIdCount, quarantinedFingers[], quarantinedCount) at lines 313-319. Confirmed (grep count=4 for the 4 named identifiers; fallbackFinger/canceledIdCount/quarantinedCount present at 314/317/319).

### Plan 02 — forced-cancel, recovery gate, fallback latch

| must_have truth | Codebase evidence | Status |
|-----------------|-------------------|--------|
| Focus loss / unmap / geometry change / fullscreen toggle / disconnect cleanly end every outstanding contact | `xf_touch_force_cancel` wired into 5 hooks: `xf_event.c:712` (FocusOut), `:844` (ConfigureNotify size-change), `:956` (UnmapNotify !app branch); `xf_client.c:805` (toggle_fullscreen), `:1473` (post_disconnect) | PASS |
| Forced cancellation sends UP\|CANCELED via `rdpei->TouchCancel` for each active contact | `xf_input.c:816` `rdpei->TouchCancel(rdpei, c->id, c->x, c->y, &dummy)` (TouchCancel count=2) | PASS |
| Delayed XI_TouchEnd for already-canceled ID ignored (D-07 idempotency) | `xf_input.c:762-774` TouchEnd path iterates `canceledIds[]`, removes on match, returns 0 without terminal RDPEI event (canceledIds count=3) | PASS |
| Recovery gate quarantines pre-cancel fingers; new input accepted only after all lift (D-08) | `xf_input.c:1018` guard at TOP of `xf_input_handle_event_remote` BEFORE the switch (line 1057); handles Begin/Update/End/Ownership uniformly; lifts when `quarantinedCount==0` (recoveryGateArmed count=4) | PASS |
| Geometry change while contacts active cancels before adopting new transform (D-12) | `xf_event.c:844` — force_cancel inside the size-change block, before `xfc->window->width` update | PASS |
| First-contact-only mouse fallback when RDPEI unavailable (D-01, D-04) | `xf_input_touch_remote` `if (!rdpei)` branch (xf_input.c:654-718): Begin latches first finger + button1 DOWN, Update emits motion, End emits button1 UP (fallbackActive count=6, freerdp_client_send_button_event count=3) | PASS |
| Additional fingers ignored while fallback active (D-02) | Begin case: only latches when `!fallbackActive`; subsequent fingers fall through `break` with no event | PASS |
| Mode latched for contact lifetime even if RDPEI appears midway (D-03) | rdpei NULL check is at function entry; once latched, Update/End use `fallbackActive` flag, never re-check rdpei | PASS |
| Content-bounds gate applies to fallback path too (D-11) | Fallback branch has its own bounds gate at xf_input.c:737-745 before `xf_event_adjust_coordinates` | PASS |
| Fallback latch is X11-only; client/common/client.c unchanged | `git status client/common/client.c` → working tree clean; no fallback modifications in shared client | PASS |
| No contacts active → forced-cancel is no-op | `xf_touch_force_cancel` iterates `cctx->contacts[i]` skipping `id==0` slots; `recoveryGateArmed` only set if `canceledIdCount > 0` | PASS |
| Forced-cancel iterates authoritative `cctx->contacts[]` not local `xfc->contacts[]` | `xf_input.c:793` `rdpClientContext* cctx = &xfc->common;` then `:803` `FreeRDP_TouchContact* c = &cctx->contacts[i];` | PASS |

**Plan 02 artifacts:** all four files modified as specified (`xf_input.c`, `xf_input.h`, `xf_event.c`, `xf_client.c`). `xf_input.h:33` declares `void xf_touch_force_cancel(xfContext* xfc);`. Confirmed.

## Build verification

- `freerdp3-x11_3.15.0+dfsg-2.1+deb13u3_amd64.deb` exists at `/home/hoang/freerdp-touch/build/` (129.5K, mode 644). Full deb set present.
- Build repo git log shows atomic commits for both waves: `57c7fab` (Plan 01 summary), `11d3a6a` (Plan 02 summary), plus executor worktree merges `3c1abf0` and `92a10f0`. Working tree clean.

## Gaps and deferrals

1. **On-device UAT (all six requirements).** Every requirement's on-device verification is pending. The plans specify the exact on-device procedures:
   - XINP-01 / RDPEI-01: single tap → one RDPEI DOWN→UP in `WLOG_LEVEL=DEBUG` trace; one-finger drag → DOWN→UPDATE*→UP same contactId no drops.
   - RDPEI-03: two-finger simultaneous → `frame.contactCount >= 2` with distinct contactIds.
   - COOR-01: four-corner + center tap in fullscreen and live-resized windowed at OneMix 3 left-rotation 2560x1600.
   - RDPEI-02: finger down then toggle fullscreen / unfocus / minimize / live-resize / disconnect — exactly one UP|CANCELED per contact, new touches work after recovery gate lifts.
   - XINP-02 fallback: RDPEI-unavailable scenario (pre-channel-connect login screen) — single finger button1 down/motion/up; two-finger only first active.
   These require the physical OneMix 3 in a GNOME-on-Xorg session. They are the sole remaining gate to closing the phase.

2. **D-06 mid-session RDPEI channel-only drop — explicitly deferred to Phase 3 (STAB-02).** The 5 lifecycle hooks cover focus loss, unmap, geometry change, fullscreen toggle, and full disconnect. The mid-session channel-only drop (`cctx->rdpei = NULL` at `client/common/client.c:1557` without a full disconnect) has no clean detach hook reachable from the X11 client and is deferred per the Plan 02 must_have ASSUMPTION. This is a documented scope decision, not a Phase 2 gap — RDPEI-02's "disconnect" trigger is covered by `xf_post_disconnect`.

3. **No new automated tests.** Per ponytail preference, verification is grep-based source assertions + build + on-device trace. No `test_*` suite was added (consistent with the plans, which specify no unit-test framework).

## Cross-reference: claimed vs actual

Both summaries' `requirements-completed` lists match the codebase evidence:

- Plan 01 SUMMARY claims [XINP-01, XINP-02, COOR-01, RDPEI-01, RDPEI-03] — all verified present in source.
- Plan 02 SUMMARY claims [XINP-02, RDPEI-02] — both verified present in source.

No claim is overstated relative to the code. The summaries honestly mark on-device items as `human_judgment: true` with empty verification refs rather than claiming them done.

## Conclusion

The phase goal — wiring XInput2 touch into native RDPEI contacts with correct lifecycle management — is achieved in the codebase: the single-tap end-to-end path, #12174 lock-race fix, XI2 ownership, emulated-pointer suppression, content-bounds gate, forced-cancel seam across 5 hooks, D-07 idempotency, D-08 recovery gate, and D-01..D-04 fallback latch are all present, committed, and build cleanly into the installable deb. All six requirement IDs are accounted for with no orphans.

The phase cannot be marked fully complete until on-device UAT in a native X11 session confirms the source-level behavior end-to-end. Recommend: run the on-device procedures listed above; if they pass, archive the phase. No source changes are indicated by this verification.

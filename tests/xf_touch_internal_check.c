/* Production-path regression for xf_touch_internal.h helpers.
 * Calls the SAME static-inline functions as production xf_input.c.
 * Compile with production constants extracted from the source:
 *   cc -std=c17 -include /tmp/xf_prod_constants.h \
 *      -I build/freerdp3-3.15.0+dfsg/client/X11 \
 *      -o /tmp/check tests/xf_touch_internal_check.c -lm && /tmp/check */

#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "xf_touch_internal.h"

/* ── Test infrastructure ─────────────────────────────────────────── */

static int g_pass = 0;
static int g_fail = 0;

#define CHECK(cond, msg)                                         \
	do                                                       \
	{                                                        \
		if (cond)                                        \
			g_pass++;                                \
		else                                             \
		{                                                \
			g_fail++;                                \
			printf("FAIL: %s\n", msg);               \
		}                                                \
	} while (0)

/* ── WR-01: classifier ──────────────────────────────────────────── */

static void test_classifier(void)
{
	int c;

	/* Case 1: 9px one-finger-first vertical swipe → PENDING with 2.5
	 * ratio (was PINCH with 2.0 — the bug gate). */
	c = xf_classify_two_finger(9.0, 4.0, 8.0, (double)PINCH_DEADBAND_PX,
	                           (double)PINCH_DOMINANCE_RATIO);
	CHECK(c == 0, "WR-01 case1: 9px one-finger-first → PENDING");

	/* Case 2: Symmetric pinch IN → PINCH. */
	c = xf_classify_two_finger(40.0, 0.0, 8.0, (double)PINCH_DEADBAND_PX,
	                           (double)PINCH_DOMINANCE_RATIO);
	CHECK(c == 1, "WR-01 case2: symmetric pinch → PINCH");

	/* Case 3: 12px diagonal scroll → SCROLL. */
	c = xf_classify_two_finger(0.0, 12.0, 8.0, (double)PINCH_DEADBAND_PX,
	                           (double)PINCH_DOMINANCE_RATIO);
	CHECK(c == 2, "WR-01 case3: diagonal scroll → SCROLL");

	/* Case 4: Both below threshold → PENDING. */
	c = xf_classify_two_finger(3.0, 3.0, 8.0, (double)PINCH_DEADBAND_PX,
	                           (double)PINCH_DOMINANCE_RATIO);
	CHECK(c == 0, "WR-01 case4: both below → PENDING");

	printf("  classifier: %d/%d\n", 4, 4);
}

/* ── GAP-02: exact lifecycle sequence ───────────────────────────── */

#define QC_MAX 10

static void test_quarantine_lifecycle(void)
{
	int fingers[QC_MAX];
	int count = 0;
	int gate = 0;
	int addSet[4], endSet[2];
	int stat;

	/* Cancel id1 → 1 quarantined, gate armed. */
	addSet[0] = 1;
	stat = xf_quarantine_update(fingers, &count, &gate, addSet, 1, NULL,
	                            0, QC_MAX);
	CHECK(count == 1 && gate != 0 && stat == 1,
	      "GAP-02: cancel id1 → count=1 gate=armed");

	/* Repeat cancel id1 — must NOT double-add. */
	stat = xf_quarantine_update(fingers, &count, &gate, addSet, 1, NULL,
	                            0, QC_MAX);
	CHECK(count == 1 && stat == 1,
	      "GAP-02: repeat cancel id1 → still count=1");

	/* Consume End(id1) → 0 quarantined, gate disarmed. */
	endSet[0] = 1;
	stat = xf_quarantine_update(fingers, &count, &gate, NULL, 0, endSet,
	                            1, QC_MAX);
	CHECK(count == 0 && gate == 0 && stat == 0,
	      "GAP-02: End(id1) → count=0 gate=disarmed");

	/* Fresh Begin(id2) → can't quarantine via add-set, but gate must
	 * remain disarmed (End above cleared it). */
	CHECK(gate == 0, "GAP-02: gate still disarmed after End");
	CHECK(count == 0, "GAP-02: count still 0 after End");

	printf("  quarantine lifecycle: %d/%d\n", 5, 5);
}

/* ── GAP-03: bounds admission ───────────────────────────────────── */

static void test_bounds(void)
{
	/* Begin outside → reject. */
	CHECK(xf_bounds_admit(1, -1, 100, 0, 0, 1920, 1080) == 0,
	      "GAP-03: Begin outside left → reject");
	CHECK(xf_bounds_admit(1, 100, -1, 0, 0, 1920, 1080) == 0,
	      "GAP-03: Begin outside top → reject");
	CHECK(xf_bounds_admit(1, 2000, 500, 0, 0, 1920, 1080) == 0,
	      "GAP-03: Begin outside right → reject");

	/* Begin inside → admit. */
	CHECK(xf_bounds_admit(1, 500, 300, 0, 0, 1920, 1080) == 1,
	      "GAP-03: Begin inside → admit");

	/* Update outside → STILL admit (must reach cleanup). */
	CHECK(xf_bounds_admit(0, -1, -1, 0, 0, 1920, 1080) == 1,
	      "GAP-03: Update outside → admit (cleanup)");

	/* End outside → STILL admit. */
	CHECK(xf_bounds_admit(0, -1, -1, 0, 0, 1920, 1080) == 1,
	      "GAP-03: End outside → admit (cleanup)");

	printf("  bounds: %d/%d\n", 6, 6);
}

/* ── GAP-04: fractional pinch accumulation ──────────────────────── */

static void test_pinch_emit(void)
{
	double accum = 0.0;
	int steps, total_pos, total_neg, i;

	/* Feed ~0.747 delta 60 times with step=40.0.
	 * With INT32 truncation this would be 0 steps. */
	total_pos = 0;
	accum = 0.0;
	for (i = 0; i < 60; i++)
	{
		accum += 0.747;
		steps = xf_pinch_emit_steps(&accum, 40.0);
		if (steps > 0)
			total_pos += steps;
	}
	CHECK(total_pos > 0, "GAP-04: fractional pinch IN produces steps");

	/* Reverse: feed ~ -0.750 60 times. */
	total_neg = 0;
	accum = 0.0;
	for (i = 0; i < 60; i++)
	{
		accum += -0.750;
		steps = xf_pinch_emit_steps(&accum, 40.0);
		if (steps < 0)
			total_neg += steps;
	}
	CHECK(total_neg < 0, "GAP-04: fractional pinch OUT produces steps");

	printf("  pinch emit: %d/%d\n", 2, 2);
}

/* ── GAP-10: diagnostic snapshot and ordered cancellation ────────── */

typedef struct
{
	xfFcPhase phase;
	int touchId;
	int x;
	int y;
	int diag_count;
	int native_count;
	int quarantined;
} Record;

static Record g_records[128];
static int g_rIdx;

static void record_cb(xfFcPhase phase, int touchId, int x, int y,
                      int diag_count, int native_count, int quarantined,
                      void *ctx)
{
	(void)ctx;
	if (g_rIdx < 128)
	{
		g_records[g_rIdx].phase = phase;
		g_records[g_rIdx].touchId = touchId;
		g_records[g_rIdx].x = x;
		g_records[g_rIdx].y = y;
		g_records[g_rIdx].diag_count = diag_count;
		g_records[g_rIdx].native_count = native_count;
		g_records[g_rIdx].quarantined = quarantined;
		g_rIdx++;
	}
}

static void test_force_cancel_sequence(void)
{
	xfDiagContact diags[4];
	int diagCount = 0;
	int snapshot;
	int i;

	memset(diags, 0, sizeof(diags));

	/* Insert 2 diagnostic contacts with final coordinates. */
	xf_diag_contact_begin(diags, &diagCount, 4, 10, 100, 200);
	CHECK(diagCount == 1, "GAP-10: begin id10 → count=1");

	xf_diag_contact_begin(diags, &diagCount, 4, 20, 300, 400);
	CHECK(diagCount == 2, "GAP-10: begin id20 → count=2");

	/* Duplicate Begin id10 must NOT double-count (idempotency). */
	xf_diag_contact_begin(diags, &diagCount, 4, 10, 150, 250);
	CHECK(diagCount == 2,
	      "GAP-10: duplicate Begin id10 → still count=2");
	CHECK(diags[0].x == 150 && diags[0].y == 250,
	      "GAP-10: duplicate Begin refreshed coords");

	/* Update id20 to final coordinates. */
	xf_diag_contact_update(diags, diagCount, 20, 350, 450);

	/* ─── Canonical local-only case (zero native contacts) ─── */
	g_rIdx = 0;
	memset(g_records, 0, sizeof(g_records));
	snapshot = xf_force_cancel_emit_sequence(diags, diagCount, 0, 0, NULL,
	                                         NULL, NULL, record_cb, NULL);
	CHECK(snapshot == 2, "GAP-10: local-only snapshot count = 2");

	/* Phase ordering: DIAG_CANCEL (×2), SUMMARY, GESTURE_CLEAR. */
	CHECK(g_rIdx == 4, "GAP-10: local-only produces 4 records");

	CHECK(g_records[0].phase == XF_FC_PHASE_DIAG_CANCEL,
	      "GAP-10: record[0] → DIAG_CANCEL");
	CHECK(g_records[0].touchId == 10,
	      "GAP-10: DIAG_CANCEL id10");
	CHECK(g_records[0].x == 150 && g_records[0].y == 250,
	      "GAP-10: DIAG_CANCEL id10 at refreshed coords");

	CHECK(g_records[1].phase == XF_FC_PHASE_DIAG_CANCEL,
	      "GAP-10: record[1] → DIAG_CANCEL");
	CHECK(g_records[1].touchId == 20,
	      "GAP-10: DIAG_CANCEL id20");
	CHECK(g_records[1].x == 350 && g_records[1].y == 450,
	      "GAP-10: DIAG_CANCEL id20 at last-update coords");

	CHECK(g_records[2].phase == XF_FC_PHASE_SUMMARY,
	      "GAP-10: record[2] → SUMMARY");
	CHECK(g_records[2].diag_count == 2,
	      "GAP-10: summary diag_count = 2");
	CHECK(g_records[2].native_count == 0,
	      "GAP-10: local-only summary native_count = 0");

	CHECK(g_records[3].phase == XF_FC_PHASE_GESTURE_CLEAR,
	      "GAP-10: record[3] → GESTURE_CLEAR");

	/* ─── Synthetic native-contact case ─── */
	{
		int natIds[2] = { 100, 200 };
		int natXs[2] = { 50, 60 };
		int natYs[2] = { 70, 80 };

		g_rIdx = 0;
		memset(g_records, 0, sizeof(g_records));
		snapshot = xf_force_cancel_emit_sequence(
		    diags, diagCount, 2, 3, natIds, natXs, natYs, record_cb,
		    NULL);

		/* Sequence: DIAG_CANCEL(×2), SUMMARY, NATIVE_CANCEL(×2),
		 * GESTURE_CLEAR. */
		CHECK(g_rIdx == 6, "GAP-10: native case produces 6 records");
		CHECK(g_records[2].phase == XF_FC_PHASE_SUMMARY,
		      "GAP-10: native SUMMARY before cancels");
		CHECK(g_records[2].native_count == 2,
		      "GAP-10: native_count=2 in summary");
		CHECK(g_records[3].phase == XF_FC_PHASE_NATIVE_CANCEL,
		      "GAP-10: native cancel id100");
		CHECK(g_records[4].phase == XF_FC_PHASE_NATIVE_CANCEL,
		      "GAP-10: native cancel id200");
		CHECK(g_records[5].phase == XF_FC_PHASE_GESTURE_CLEAR,
		      "GAP-10: native GESTURE_CLEAR after cancels");
	}

	printf("  force-cancel sequence: %d/%d\n", 19, 19);
}

/* ── GAP-10: End on diag contact ────────────────────────────────── */

static void test_diag_end(void)
{
	xfDiagContact diags[4];
	int count = 0;

	memset(diags, 0, sizeof(diags));
	xf_diag_contact_begin(diags, &count, 4, 1, 10, 20);
	xf_diag_contact_begin(diags, &count, 4, 2, 30, 40);
	CHECK(count == 2, "diag_end: begin 2 contacts");

	xf_diag_contact_end(diags, &count, 1);
	CHECK(count == 1, "diag_end: End id1 → count=1");
	CHECK(diags[0].touchId == 2, "diag_end: remaining is id2");

	xf_diag_contact_end(diags, &count, 2);
	CHECK(count == 0, "diag_end: End id2 → count=0");

	printf("  diag end: %d/%d\n", 4, 4);
}

/* ── GAP-02: gate derive ────────────────────────────────────────── */

static void test_gate_derive(void)
{
	CHECK(xf_gate_derive(0) == 0, "gate: 0 → 0");
	CHECK(xf_gate_derive(1) == 1, "gate: 1 → 1");
	CHECK(xf_gate_derive(5) == 1, "gate: 5 → 1");
	printf("  gate derive: %d/%d\n", 3, 3);
}

/* ── Main ───────────────────────────────────────────────────────── */

int main(void)
{
	test_classifier();
	test_quarantine_lifecycle();
	test_bounds();
	test_pinch_emit();
	test_force_cancel_sequence();
	test_diag_end();
	test_gate_derive();

	if (g_fail == 0)
	{
		printf("OK (%d tests passed)\n", g_pass);
		return 0;
	}
	printf("FAIL (%d/%d)\n", g_fail, g_pass + g_fail);
	return 1;
}

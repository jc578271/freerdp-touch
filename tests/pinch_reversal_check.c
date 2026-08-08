/* Regression check: pinch direction reversal must emit a detent in the
 * reversed direction within the same gesture.  Before the fix the D-12
 * hysteresis deadlocked by zeroing pinchAccum every tick without clearing
 * pinchDir, so the accumulator never reached the detent threshold.
 *
 * Build: cc -std=c17 -o /tmp/pinch_reversal_check tests/pinch_reversal_check.c -lm
 * Run:   /tmp/pinch_reversal_check   (exit 0 = pass, exit 1 = fail) */
#include <assert.h>
#include <math.h>
#include <stdlib.h>
#include <stdio.h>

#define PINCH_WHEEL_STEP_PX 40

typedef struct
{
	int pinchDir;
	int pinchAccum;
} PinchState;

/* Mirror of the D-09/D-10/D-12 logic in xf_input_pinch_update.
 * Returns the wheel delta sign emitted this tick (0 = none). */
static int pinch_tick(PinchState* s, double delta)
{
	int emitted = 0;
	s->pinchAccum += (int)delta;

	int currentDir = (delta > 0) ? 1 : ((delta < 0) ? -1 : 0);
	if (currentDir != 0 && s->pinchDir != 0 && currentDir != s->pinchDir)
	{
		s->pinchAccum = 0;
		s->pinchDir = 0; /* THE FIX — without this line the test fails */
	}

	while (abs(s->pinchAccum) >= PINCH_WHEEL_STEP_PX)
	{
		if (s->pinchAccum > 0)
		{
			emitted = 1;
			s->pinchDir = 1;
			s->pinchAccum -= PINCH_WHEEL_STEP_PX;
		}
		else
		{
			emitted = -1;
			s->pinchDir = -1;
			s->pinchAccum += PINCH_WHEEL_STEP_PX;
		}
	}
	return emitted;
}

int main(void)
{
	PinchState s = { 0 };

	/* Phase 1: zoom out — fingers together, negative deltas. */
	for (int i = 0; i < 20; i++)
		pinch_tick(&s, -5.0);
	assert(s.pinchDir == -1);
	printf("phase1: zoom-out dir=%d accum=%d\n", s.pinchDir, s.pinchAccum);

	/* Phase 2: reverse direction — fingers apart, positive deltas.
	 * Before the fix, no detent was ever emitted here (deadlock). */
	int reversed_detents = 0;
	for (int i = 0; i < 100; i++)
	{
		int e = pinch_tick(&s, 5.0);
		if (e == 1)
			reversed_detents++;
	}

	printf("phase2: reversed_detents=%d dir=%d accum=%d\n",
	       reversed_detents, s.pinchDir, s.pinchAccum);

	if (reversed_detents == 0)
	{
		fprintf(stderr, "FAIL: no zoom-in detent emitted after reversal — deadlock\n");
		return 1;
	}
	if (s.pinchDir != 1)
	{
		fprintf(stderr, "FAIL: pinchDir not updated to +1 after reversal\n");
		return 1;
	}

	/* Phase 3: reverse back to zoom-out — must also work. */
	int back_detents = 0;
	for (int i = 0; i < 100; i++)
	{
		int e = pinch_tick(&s, -5.0);
		if (e == -1)
			back_detents++;
	}
	printf("phase3: back_detents=%d dir=%d accum=%d\n",
	       back_detents, s.pinchDir, s.pinchAccum);

	if (back_detents == 0)
	{
		fprintf(stderr, "FAIL: no zoom-out detent after second reversal\n");
		return 1;
	}
	if (s.pinchDir != -1)
	{
		fprintf(stderr, "FAIL: pinchDir not updated to -1 after second reversal\n");
		return 1;
	}

	printf("PASS: direction reversal works in both directions\n");
	return 0;
}
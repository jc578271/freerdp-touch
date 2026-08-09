/* GAP-01 ownership layout proof — compile against system X11/XI2 headers.
 * Asserts sizeof(XITouchOwnershipEvent) is smaller than the offset of
 * event_x in XIDeviceEvent, proving the old cast reads out-of-bounds
 * memory.  If this assert fires, the current X11 headers are safe for
 * the old cast — but the safe code is still the right choice. */

#include <X11/Xlib.h>
#include <X11/extensions/XInput2.h>
#include <assert.h>
#include <stddef.h>
#include <stdio.h>

int main(void)
{
	assert(sizeof(XITouchOwnershipEvent) < offsetof(XIDeviceEvent, event_x));
	printf("OK\n");
	return 0;
}

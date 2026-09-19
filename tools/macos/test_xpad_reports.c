#include "xpad_devices.h"
#include "xpad_reports.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <string.h>
int main(void) {
	XpadSample sample;
	uint8_t idle[20] = {0x00, 0x14};
	assert(xpad_decode(idle, 20, &sample) && sample.buttons == 0);
	assert(fabs(sample.lx) < 1e-6 && fabs(sample.ly) < 1e-6);
	uint8_t face[20] = {0x00, 0x14, 0x00, 0x10};
	assert(xpad_decode(face, 20, &sample) && sample.buttons == XPAD_A);
	face[3] = 0x20;
	assert(xpad_decode(face, 20, &sample) && sample.buttons == XPAD_B);
	face[3] = 0xf0;
	assert(xpad_decode(face, 20, &sample) && sample.buttons == (XPAD_A | XPAD_B | XPAD_X | XPAD_Y));
	uint8_t dpad[20] = {0x00, 0x14, 0x01};
	assert(xpad_decode(dpad, 20, &sample) && sample.buttons == XPAD_UP);
	dpad[2] = 0x02;
	assert(xpad_decode(dpad, 20, &sample) && sample.buttons == XPAD_DOWN);
	uint8_t menu[20] = {0x00, 0x14, 0x30, 0x07};
	assert(xpad_decode(menu, 20, &sample));
	assert(sample.buttons == (XPAD_START | XPAD_BACK | XPAD_LB | XPAD_RB | XPAD_GUIDE));
	uint8_t stick[20] = {0x00, 0x14};
	int16_t left = -32767, up = 32767;
	memcpy(stick + 6, &left, 2);
	memcpy(stick + 8, &up, 2);
	assert(xpad_decode(stick, 20, &sample));
	assert(fabs(sample.lx + 1.0f) < 1e-5 && fabs(sample.ly + 1.0f) < 1e-5);
	uint8_t triggers[20] = {0x00, 0x14, 0, 0, 255, 128};
	assert(xpad_decode(triggers, 20, &sample));
	assert(fabs(sample.lt - 1.0f) < 1e-6 && fabs(sample.rt - 128.0f / 255.0f) < 1e-6);
	uint8_t led[] = {0x01, 0x03, 0x02};
	assert(!xpad_decode(led, sizeof(led), &sample));
	assert(!xpad_decode(idle, 19, &sample));
	idle[1] = 0x13;
	assert(!xpad_decode(idle, 20, &sample));

	uint8_t nacon[] = {
		0x09, 0x02, 0x31, 0x00, 0x01, 0x01, 0x00, 0x80, 0xfa,
		0x09, 0x04, 0x00, 0x00, 0x02, 0xff, 0x5d, 0x01, 0x00};
	int cls = 0, sub = 0, proto = 0;
	assert(xpad_scan_config(nacon, sizeof(nacon), &cls, &sub, &proto));
	assert(cls == 0xff && sub == 0x5d && proto == 0x01);
	const XpadDevice *nacon_dev = xpad_lookup(0x146b, 0x0603, cls, sub, proto);
	assert(nacon_dev && nacon_dev->protocol == XPAD_PROTO_XID360);
	assert(strstr(nacon_dev->name, "Nacon"));
	const XpadDevice *generic = xpad_lookup(0x1234, 0x5678, 0xff, 0x5d, 0x01);
	assert(generic && generic->protocol == XPAD_PROTO_XID360);
	assert(generic->vid == 0);
	assert(!xpad_lookup(0x1234, 0x5678, 0xff, 0x00, 0x00));
	assert(!xpad_lookup(0x054c, 0x05c4, 3, 0, 0));
	uint8_t hid[] = {
		0x09, 0x02, 0x12, 0x00, 0x01, 0x01, 0x00, 0x80, 0x32,
		0x09, 0x04, 0x00, 0x00, 0x01, 0x03, 0x00, 0x00, 0x00};
	assert(!xpad_scan_config(hid, sizeof(hid), &cls, &sub, &proto));
	assert(!xpad_lookup(0x054c, 0x09cc, 3, 0, 0));
	assert(xpad_ignore_product("USB3.1 Hub"));
	assert(xpad_ignore_product("USB 10/100/1000 LAN"));
	assert(!xpad_ignore_product("PC Compact Controller"));
	puts("Xpad report decoding checks passed (synthetic packets).");
	return 0;
}

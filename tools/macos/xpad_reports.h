#ifndef COUCH_XPAD_REPORTS_H
#define COUCH_XPAD_REPORTS_H
#include <stdint.h>
#include <string.h>

enum {
	XPAD_A = 1u << 0,
	XPAD_B = 1u << 1,
	XPAD_X = 1u << 2,
	XPAD_Y = 1u << 3,
	XPAD_LB = 1u << 4,
	XPAD_RB = 1u << 5,
	XPAD_BACK = 1u << 6,
	XPAD_START = 1u << 7,
	XPAD_UP = 1u << 8,
	XPAD_DOWN = 1u << 9,
	XPAD_LEFT = 1u << 10,
	XPAD_RIGHT = 1u << 11,
	XPAD_LS = 1u << 12,
	XPAD_RS = 1u << 13,
	XPAD_GUIDE = 1u << 14
};

typedef struct {
	unsigned buttons;
	float lx, ly, rx, ry, lt, rt;
} XpadSample;

static inline float xpad_axis(int16_t raw, int invert) {
	float value = (invert ? -(float)raw : (float)raw) / 32767.0f;
	if (value > 1.0f) return 1.0f;
	if (value < -1.0f) return -1.0f;
	return value;
}

/* Xbox 360 XID input is 20 bytes starting 00 14. LED/rumble replies are ignored. */
static inline int xpad_decode(const uint8_t *data, size_t length, XpadSample *out) {
	if (!data || !out || length < 20 || data[0] != 0x00 || data[1] != 0x14) return 0;
	unsigned buttons = 0;
	if (data[3] & 0x10) buttons |= XPAD_A;
	if (data[3] & 0x20) buttons |= XPAD_B;
	if (data[3] & 0x40) buttons |= XPAD_X;
	if (data[3] & 0x80) buttons |= XPAD_Y;
	if (data[3] & 0x01) buttons |= XPAD_LB;
	if (data[3] & 0x02) buttons |= XPAD_RB;
	if (data[3] & 0x04) buttons |= XPAD_GUIDE;
	if (data[2] & 0x10) buttons |= XPAD_START;
	if (data[2] & 0x20) buttons |= XPAD_BACK;
	if (data[2] & 0x40) buttons |= XPAD_LS;
	if (data[2] & 0x80) buttons |= XPAD_RS;
	if (data[2] & 0x01) buttons |= XPAD_UP;
	if (data[2] & 0x02) buttons |= XPAD_DOWN;
	if (data[2] & 0x04) buttons |= XPAD_LEFT;
	if (data[2] & 0x08) buttons |= XPAD_RIGHT;
	int16_t lx, ly, rx, ry;
	memcpy(&lx, data + 6, 2);
	memcpy(&ly, data + 8, 2);
	memcpy(&rx, data + 10, 2);
	memcpy(&ry, data + 12, 2);
	out->buttons = buttons;
	out->lx = xpad_axis(lx, 0);
	out->ly = xpad_axis(ly, 1);
	out->rx = xpad_axis(rx, 0);
	out->ry = xpad_axis(ry, 1);
	out->lt = data[4] / 255.0f;
	out->rt = data[5] / 255.0f;
	return 1;
}

#endif

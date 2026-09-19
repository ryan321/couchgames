#ifndef COUCH_XPAD_DEVICES_H
#define COUCH_XPAD_DEVICES_H
#include <ctype.h>
#include <stdint.h>
#include <string.h>

enum { XPAD_PROTO_NONE = 0, XPAD_PROTO_XID360 = 1 };

enum {
	XPAD_QUIRK_NONE = 0,
	XPAD_QUIRK_SKIP_LED = 1u << 0
};

typedef struct {
	uint16_t vid, pid;
	const char *name;
	int protocol;
	unsigned quirks;
} XpadDevice;

/* Named rows win over the generic XID match. vid/pid 0 is the catch-all
 * Xbox 360-style interface (USB class ff:5d:01). Add a row to name a pad,
 * force a protocol, or set quirks. HID interfaces are never claimed. */
static const XpadDevice xpad_devices[] = {
	{0x045e, 0x028e, "Xbox 360 Controller", XPAD_PROTO_XID360, 0},
	{0x045e, 0x028f, "Xbox 360 Controller", XPAD_PROTO_XID360, 0},
	{0x0e6f, 0x0213, "Afterglow Gamepad", XPAD_PROTO_XID360, 0},
	{0x146b, 0x0601, "Bigben Xbox 360 Controller", XPAD_PROTO_XID360, 0},
	{0x146b, 0x0603, "Nacon Compact", XPAD_PROTO_XID360, 0},
	{0x146b, 0x0604, "Nacon Daija Arcade Stick", XPAD_PROTO_XID360, 0},
	{0x24c6, 0x5300, "PowerA Xbox 360 Controller", XPAD_PROTO_XID360, 0},
	{0x0000, 0x0000, "Xbox 360-style wired pad", XPAD_PROTO_XID360, 0}
};

static const XpadDevice xpad_generic_xid360 = {0, 0, "Xbox 360-style wired pad", XPAD_PROTO_XID360, 0};

static inline int xpad_is_xid360_interface(int cls, int sub, int proto) {
	return cls == 0xff && sub == 0x5d && proto == 0x01;
}

static inline int xpad_is_hid_interface(int cls) { return cls == 3; }

static inline int xpad_ignore_product(const char *name) {
	if (!name || !name[0]) return 0;
	char lower[96];
	size_t n = 0;
	for (; name[n] && n + 1 < sizeof(lower); n++) lower[n] = (char)tolower((unsigned char)name[n]);
	lower[n] = 0;
	return strstr(lower, "hub") || strstr(lower, "lan") || strstr(lower, "ethernet")
		|| strstr(lower, "storage") || strstr(lower, "disk") || strstr(lower, "camera")
		|| strstr(lower, "serial") || strstr(lower, "express");
}

/* Walk a USB configuration descriptor and return the first gamepad-like interface. */
static inline int xpad_scan_config(const uint8_t *desc, size_t length, int *cls, int *sub, int *proto) {
	if (!desc || length < 9 || !cls || !sub || !proto) return 0;
	*cls = *sub = *proto = 0;
	int found = 0, xid = 0;
	size_t offset = 0;
	while (offset + 2 <= length) {
		unsigned b_len = desc[offset];
		unsigned b_type = desc[offset + 1];
		if (b_len < 2 || offset + b_len > length) break;
		if (b_type == 4 && b_len >= 9) {
			int icls = desc[offset + 5], isub = desc[offset + 6], iproto = desc[offset + 7];
			if (xpad_is_hid_interface(icls)) {
				offset += b_len;
				continue;
			}
			if (xpad_is_xid360_interface(icls, isub, iproto)) {
				*cls = icls;
				*sub = isub;
				*proto = iproto;
				xid = 1;
				break;
			}
			if (!found) {
				*cls = icls;
				*sub = isub;
				*proto = iproto;
				found = 1;
			}
		}
		offset += b_len;
	}
	return xid || found;
}

static inline const XpadDevice *xpad_lookup(uint16_t vid, uint16_t pid, int cls, int sub, int proto) {
	if (xpad_is_hid_interface(cls)) return NULL;
	size_t count = sizeof(xpad_devices) / sizeof(xpad_devices[0]);
	for (size_t i = 0; i < count; i++) {
		const XpadDevice *device = &xpad_devices[i];
		if (device->vid && device->pid && device->vid == vid && device->pid == pid)
			return device->protocol == XPAD_PROTO_NONE ? NULL : device;
	}
	if (xpad_is_xid360_interface(cls, sub, proto)) return &xpad_generic_xid360;
	return NULL;
}

#endif

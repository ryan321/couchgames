#ifndef COUCH_XPAD_DEVICES_H
#define COUCH_XPAD_DEVICES_H
#include <ctype.h>
#include <stdint.h>
#include <string.h>

enum { XPAD_PROTO_NONE = 0, XPAD_PROTO_XID360 = 1, XPAD_PROTO_GIP = 2 };

enum {
	XPAD_QUIRK_NONE = 0,
	XPAD_QUIRK_SKIP_LED = 1u << 0,
	XPAD_QUIRK_GIP_S_INIT = 1u << 1,
	XPAD_QUIRK_GIP_RUMBLE_INIT = 1u << 2,
	XPAD_QUIRK_GIP_HORI_ACK = 1u << 3
};

typedef struct {
	uint16_t vid, pid;
	const char *name;
	int protocol;
	unsigned quirks;
} XpadDevice;

/* Named rows win over generic interface matches. vid/pid 0 is a catch-all
 * for that protocol's USB class. HID interfaces are never claimed. */
/* Living-room pads first. Generic XID/GIP rows at the end catch unknown VID/PID.
 * Add a named row to label a pad or attach GIP init quirks. */
static const XpadDevice xpad_devices[] = {
	{0x045e, 0x028e, "Xbox 360 Controller", XPAD_PROTO_XID360, 0},
	{0x045e, 0x028f, "Xbox 360 Controller", XPAD_PROTO_XID360, 0},
	{0x045e, 0x02d1, "Xbox One Controller", XPAD_PROTO_GIP, XPAD_QUIRK_GIP_S_INIT},
	{0x045e, 0x02dd, "Xbox One Controller", XPAD_PROTO_GIP, XPAD_QUIRK_GIP_S_INIT},
	{0x045e, 0x02e3, "Xbox One Elite", XPAD_PROTO_GIP, XPAD_QUIRK_GIP_S_INIT},
	{0x045e, 0x02ea, "Xbox One S Controller", XPAD_PROTO_GIP, XPAD_QUIRK_GIP_S_INIT},
	{0x045e, 0x0b00, "Xbox One Elite 2", XPAD_PROTO_GIP, XPAD_QUIRK_GIP_S_INIT},
	{0x045e, 0x0b0a, "Xbox Adaptive Controller", XPAD_PROTO_GIP, XPAD_QUIRK_GIP_S_INIT},
	{0x045e, 0x0b12, "Xbox Series Controller", XPAD_PROTO_GIP, XPAD_QUIRK_GIP_S_INIT},
	{0x046d, 0xc21d, "Logitech F310", XPAD_PROTO_XID360, 0},
	{0x046d, 0xc21e, "Logitech F510", XPAD_PROTO_XID360, 0},
	{0x046d, 0xc21f, "Logitech F710", XPAD_PROTO_XID360, 0},
	{0x0e6f, 0x0139, "PDP Afterglow Xbox One", XPAD_PROTO_GIP, 0},
	{0x0e6f, 0x0146, "PDP Rock Candy Xbox One", XPAD_PROTO_GIP, 0},
	{0x0e6f, 0x0165, "PDP Titanfall 2", XPAD_PROTO_GIP, XPAD_QUIRK_GIP_HORI_ACK},
	{0x0e6f, 0x0213, "Afterglow Gamepad", XPAD_PROTO_XID360, 0},
	{0x0e6f, 0x02a4, "PDP Xbox One Controller", XPAD_PROTO_GIP, 0},
	{0x0e6f, 0x02a6, "PDP Xbox One Camo", XPAD_PROTO_GIP, 0},
	{0x0e6f, 0x02ab, "PDP Xbox One Controller", XPAD_PROTO_GIP, 0},
	{0x0f0d, 0x0067, "HORIPAD ONE", XPAD_PROTO_GIP, XPAD_QUIRK_GIP_HORI_ACK},
	{0x146b, 0x0601, "Bigben Xbox 360 Controller", XPAD_PROTO_XID360, 0},
	{0x146b, 0x0603, "Nacon Compact", XPAD_PROTO_XID360, 0},
	{0x146b, 0x0604, "Nacon Daija Arcade Stick", XPAD_PROTO_XID360, 0},
	{0x20d6, 0x2001, "PowerA Xbox Series Controller", XPAD_PROTO_GIP, XPAD_QUIRK_GIP_RUMBLE_INIT},
	{0x20d6, 0x2009, "PowerA Enhanced Wired Xbox", XPAD_PROTO_GIP, XPAD_QUIRK_GIP_RUMBLE_INIT},
	{0x20d6, 0x2064, "PowerA Wired Xbox Controller", XPAD_PROTO_GIP, XPAD_QUIRK_GIP_RUMBLE_INIT},
	{0x24c6, 0x5300, "PowerA Xbox 360 Controller", XPAD_PROTO_XID360, 0},
	{0x24c6, 0x541a, "PowerA Xbox One Mini", XPAD_PROTO_GIP, XPAD_QUIRK_GIP_RUMBLE_INIT},
	{0x24c6, 0x543a, "PowerA Xbox One Controller", XPAD_PROTO_GIP, XPAD_QUIRK_GIP_RUMBLE_INIT},
	{0x2dc8, 0x2000, "8BitDo Pro 2 for Xbox", XPAD_PROTO_GIP, 0},
	{0x2dc8, 0x200f, "8BitDo Ultimate for Xbox", XPAD_PROTO_GIP, 0},
	{0x2dc8, 0x3106, "8BitDo Ultimate / Pro 2", XPAD_PROTO_XID360, 0},
	{0x3285, 0x0603, "Nacon Pro Compact Xbox", XPAD_PROTO_GIP, 0},
	{0x0000, 0x0000, "Xbox 360-style wired pad", XPAD_PROTO_XID360, 0}
};

static const XpadDevice xpad_generic_xid360 = {0, 0, "Xbox 360-style wired pad", XPAD_PROTO_XID360, 0};
static const XpadDevice xpad_generic_gip = {0, 0, "Xbox One-style wired pad", XPAD_PROTO_GIP, 0};

static inline int xpad_is_xid360_interface(int cls, int sub, int proto) {
	return cls == 0xff && sub == 0x5d && proto == 0x01;
}

static inline int xpad_is_gip_interface(int cls, int sub, int proto) {
	return cls == 0xff && sub == 0x47 && proto == 0xd0;
}

static inline int xpad_is_hid_interface(int cls) { return cls == 3; }

static inline int xpad_protocol_supported(int protocol) {
	return protocol == XPAD_PROTO_XID360 || protocol == XPAD_PROTO_GIP;
}

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
			if (xpad_is_xid360_interface(icls, isub, iproto) || xpad_is_gip_interface(icls, isub, iproto)) {
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
	if (xpad_is_gip_interface(cls, sub, proto)) return &xpad_generic_gip;
	return NULL;
}

static inline unsigned xpad_generic_gip_quirks(uint16_t vid, uint16_t pid) {
	unsigned quirks = XPAD_QUIRK_GIP_S_INIT | XPAD_QUIRK_GIP_RUMBLE_INIT;
	if (vid == 0x0f0d || (vid == 0x0e6f && pid == 0x0165)) quirks |= XPAD_QUIRK_GIP_HORI_ACK;
	return quirks;
}

static inline const char *xpad_protocol_token(int protocol) {
	if (protocol == XPAD_PROTO_GIP) return "XPAD_PROTO_GIP";
	if (protocol == XPAD_PROTO_XID360) return "XPAD_PROTO_XID360";
	return "XPAD_PROTO_NONE";
}

#endif

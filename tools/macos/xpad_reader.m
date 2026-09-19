// Host USB reader for vendor-class Xbox 360-style pads macOS does not expose as HID.
#import <Cocoa/Cocoa.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/usb/IOUSBLib.h>
#include <math.h>
#include <stdio.h>
#include <string.h>
#include "xpad_devices.h"
#include "xpad_reports.h"
enum { MAX_PADS = 8 };
typedef struct {
	io_service_t service;
	IOUSBDeviceInterface650 **device;
	IOUSBInterfaceInterface942 **iface;
	CFRunLoopSourceRef source;
	uint8_t buffer[64];
	uint32_t location;
	uint16_t vid, pid;
	char name[72];
	unsigned last_buttons;
	float last_lx, last_ly, last_rx, last_ry;
	int slot, queued, protocol;
	unsigned quirks;
	UInt8 in_pipe, out_pipe;
} Pad;
static NSString *statePath;
static NSTextField *label;
static Pad pads[MAX_PADS];
static NSTimeInterval lastWrite;
static void status(NSString *text) { if (label) label.stringValue = text; NSLog(@"CouchXpad: %@", text); }
static Pad *pad_at_location(uint32_t location) {
	for (int i = 0; i < MAX_PADS; i++) if (pads[i].iface && pads[i].location == location) return &pads[i];
	return NULL;
}
static Pad *unused_pad(void) {
	for (int i = 0; i < MAX_PADS; i++) if (!pads[i].iface) { pads[i].slot = i; return &pads[i]; }
	return NULL;
}
static int live_count(void) {
	int n = 0;
	for (int i = 0; i < MAX_PADS; i++) if (pads[i].iface) n++;
	return n;
}
static void close_one(Pad *pad) {
	if (!pad) return;
	if (pad->source) {
		CFRunLoopRemoveSource(CFRunLoopGetCurrent(), pad->source, kCFRunLoopDefaultMode);
		pad->source = NULL;
	}
	if (pad->iface) {
		(*pad->iface)->USBInterfaceClose(pad->iface);
		(*pad->iface)->Release(pad->iface);
		pad->iface = NULL;
	}
	if (pad->device) {
		(*pad->device)->USBDeviceClose(pad->device);
		(*pad->device)->Release(pad->device);
		pad->device = NULL;
	}
	if (pad->service) {
		IOObjectRelease(pad->service);
		pad->service = 0;
	}
	memset(pad, 0, sizeof(*pad));
}
static void close_all(void) {
	if (statePath) [[NSFileManager defaultManager] removeItemAtPath:statePath error:nil];
	for (int i = 0; i < MAX_PADS; i++) close_one(&pads[i]);
}
static void publish(void) {
	if (!statePath) return;
	NSTimeInterval now = NSDate.date.timeIntervalSince1970;
	NSMutableArray *list = [NSMutableArray array];
	for (int i = 0; i < MAX_PADS; i++) {
		Pad *pad = &pads[i];
		if (!pad->iface) continue;
		[list addObject:@{
			@"id": [NSString stringWithFormat:@"%04x:%04x", pad->vid, pad->pid],
			@"name": @(pad->name),
			@"buttons": @(pad->last_buttons == UINT_MAX ? 0 : pad->last_buttons),
			@"lx": @(pad->last_lx), @"ly": @(pad->last_ly),
			@"rx": @(pad->last_rx), @"ry": @(pad->last_ry),
			@"slot": @(pad->slot)
		}];
	}
	NSDictionary *state = @{@"updated": @(now), @"pads": list};
	NSData *data = [NSJSONSerialization dataWithJSONObject:state options:0 error:nil];
	[data writeToFile:statePath options:NSDataWritingAtomic error:nil];
	lastWrite = now;
	NSMutableString *text = [NSMutableString stringWithFormat:@"%d wired USB pad%s. Keep this reader open.\nPress A / Cross to join.\n",
		(int)list.count, list.count == 1 ? "" : "s"];
	for (int i = 0; i < MAX_PADS; i++) if (pads[i].iface)
		[text appendFormat:@"%s  buttons %04x  stick %.2f, %.2f\n", pads[i].name,
			pads[i].last_buttons == UINT_MAX ? 0 : pads[i].last_buttons, pads[i].last_lx, pads[i].last_ly];
	if (label) label.stringValue = text;
}
static void read_cb(void *refcon, IOReturn result, void *arg0) {
	Pad *pad = refcon;
	if (!pad || !pad->iface) return;
	pad->queued = 0;
	if (result == kIOReturnSuccess) {
		XpadSample sample;
		int decoded = xpad_decode_report(pad->protocol, pad->buffer, (size_t)(uintptr_t)arg0, &sample);
		if (decoded == XPAD_DECODE_GUIDE) {
			if (pad->last_buttons == UINT_MAX) pad->last_buttons = 0;
			if (sample.buttons & XPAD_GUIDE) pad->last_buttons |= XPAD_GUIDE;
			else pad->last_buttons &= ~XPAD_GUIDE;
			if (pad->out_pipe) {
				uint8_t ack[16];
				size_t ack_len = xpad_gip_ack(pad->buffer[2], ack, sizeof(ack));
				if (ack_len) (*pad->iface)->WritePipe(pad->iface, pad->out_pipe, ack, (UInt32)ack_len);
			}
			publish();
		} else if (decoded == XPAD_DECODE_INPUT) {
			unsigned guide = (pad->last_buttons == UINT_MAX) ? 0 : (pad->last_buttons & XPAD_GUIDE);
			int changed = pad->last_buttons == UINT_MAX || sample.buttons != (pad->last_buttons & ~XPAD_GUIDE)
				|| fabsf(sample.lx - pad->last_lx) > 0.01f || fabsf(sample.ly - pad->last_ly) > 0.01f;
			pad->last_buttons = sample.buttons | guide;
			pad->last_lx = sample.lx;
			pad->last_ly = sample.ly;
			pad->last_rx = sample.rx;
			pad->last_ry = sample.ry;
			NSTimeInterval now = NSDate.date.timeIntervalSince1970;
			if (changed || now - lastWrite >= 0.25) publish();
		}
	} else if (result != kIOReturnAborted) {
		status([NSString stringWithFormat:@"USB read ended: 0x%x. Reconnecting…", result]);
		close_one(pad);
		publish();
		return;
	}
	if (pad->iface && !pad->queued) {
		IOReturn kr = (*pad->iface)->ReadPipeAsync(pad->iface, pad->in_pipe, pad->buffer, sizeof(pad->buffer), read_cb, pad);
		if (kr) {
			status([NSString stringWithFormat:@"USB read queue failed: 0x%x", kr]);
			close_one(pad);
			publish();
		} else pad->queued = 1;
	}
}
static uint32_t location_of(io_service_t service) {
	CFNumberRef number = IORegistryEntryCreateCFProperty(service, CFSTR("locationID"), kCFAllocatorDefault, 0);
	uint32_t location = 0;
	if (number) {
		CFNumberGetValue(number, kCFNumberIntType, &location);
		CFRelease(number);
	}
	return location;
}
static void copy_product_name(io_service_t service, char *out, size_t size) {
	out[0] = 0;
	CFStringRef string = IORegistryEntryCreateCFProperty(service, CFSTR("USB Product Name"), kCFAllocatorDefault, 0);
	if (string) {
		CFStringGetCString(string, out, (CFIndex)size, kCFStringEncodingUTF8);
		CFRelease(string);
	}
}
static const uint8_t gip_power_on[] = {0x05, 0x20, 0x00, 0x01, 0x00};
static const uint8_t gip_s_init[] = {0x05, 0x20, 0x00, 0x0f, 0x06};
static const uint8_t gip_led_on[] = {0x0a, 0x20, 0x00, 0x03, 0x00, 0x01, 0x14};
static const uint8_t gip_auth[] = {0x06, 0x20, 0x00, 0x02, 0x01, 0x00};
static const uint8_t gip_rumble_begin[] = {0x09, 0x00, 0x00, 0x09, 0x00, 0x0f, 0x00, 0x00, 0x1d, 0x1d, 0xff, 0x00, 0x00};
static const uint8_t gip_rumble_end[] = {0x09, 0x00, 0x00, 0x09, 0x00, 0x0f, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
static const uint8_t gip_hori_ack[] = {0x01, 0x20, 0x00, 0x09, 0x00, 0x04, 0x20, 0x3a, 0x00, 0x00, 0x00, 0x80, 0x00};
static void write_gip_init(Pad *pad) {
	if (!pad->out_pipe) return;
	unsigned quirks = pad->quirks | xpad_generic_gip_quirks(pad->vid, pad->pid);
	(*pad->iface)->WritePipe(pad->iface, pad->out_pipe, (void *)gip_power_on, sizeof(gip_power_on));
	if (quirks & XPAD_QUIRK_GIP_S_INIT)
		(*pad->iface)->WritePipe(pad->iface, pad->out_pipe, (void *)gip_s_init, sizeof(gip_s_init));
	(*pad->iface)->WritePipe(pad->iface, pad->out_pipe, (void *)gip_led_on, sizeof(gip_led_on));
	(*pad->iface)->WritePipe(pad->iface, pad->out_pipe, (void *)gip_auth, sizeof(gip_auth));
	if (quirks & XPAD_QUIRK_GIP_RUMBLE_INIT) {
		(*pad->iface)->WritePipe(pad->iface, pad->out_pipe, (void *)gip_rumble_begin, sizeof(gip_rumble_begin));
		(*pad->iface)->WritePipe(pad->iface, pad->out_pipe, (void *)gip_rumble_end, sizeof(gip_rumble_end));
	}
	if (quirks & XPAD_QUIRK_GIP_HORI_ACK)
		(*pad->iface)->WritePipe(pad->iface, pad->out_pipe, (void *)gip_hori_ack, sizeof(gip_hori_ack));
}
static IOReturn claim_interface(Pad *pad, io_service_t iface_service, unsigned quirks) {
	IOCFPlugInInterface **plugin = NULL;
	SInt32 score = 0;
	IOReturn kr = IOCreatePlugInInterfaceForService(
		iface_service, kIOUSBInterfaceUserClientTypeID, kIOCFPlugInInterfaceID, &plugin, &score);
	if (kr || !plugin) return kr ? kr : kIOReturnNoDevice;
	kr = (*plugin)->QueryInterface(plugin, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID942), (LPVOID *)&pad->iface);
	(*plugin)->Release(plugin);
	if (kr || !pad->iface) return kr ? kr : kIOReturnNoDevice;
	kr = (*pad->iface)->USBInterfaceOpenSeize(pad->iface);
	if (kr) kr = (*pad->iface)->USBInterfaceOpen(pad->iface);
	if (kr) {
		(*pad->iface)->Release(pad->iface);
		pad->iface = NULL;
		return kr;
	}
	UInt8 endpoints = 0;
	(*pad->iface)->GetNumEndpoints(pad->iface, &endpoints);
	pad->in_pipe = pad->out_pipe = 0;
	for (UInt8 pipe = 1; pipe <= endpoints; pipe++) {
		UInt8 direction = 0, number = 0, transfer = 0, interval = 0;
		UInt16 max_packet = 0;
		if ((*pad->iface)->GetPipeProperties(pad->iface, pipe, &direction, &number, &transfer, &max_packet, &interval))
			continue;
		if (direction == kUSBIn && transfer == kUSBInterrupt) pad->in_pipe = pipe;
		if (direction == kUSBOut && transfer == kUSBInterrupt) pad->out_pipe = pipe;
	}
	if (!pad->in_pipe) {
		close_one(pad);
		return kIOReturnNoDevice;
	}
	if (pad->protocol == XPAD_PROTO_GIP) write_gip_init(pad);
	else if (!(quirks & XPAD_QUIRK_SKIP_LED) && pad->out_pipe) {
		UInt8 led[] = {0x01, 0x03, (UInt8)(0x02 + pad->slot)};
		(*pad->iface)->WritePipe(pad->iface, pad->out_pipe, led, sizeof(led));
	}
	kr = (*pad->iface)->CreateInterfaceAsyncEventSource(pad->iface, &pad->source);
	if (kr || !pad->source) {
		close_one(pad);
		return kr ? kr : kIOReturnNoResources;
	}
	CFRunLoopAddSource(CFRunLoopGetCurrent(), pad->source, kCFRunLoopDefaultMode);
	pad->last_buttons = UINT_MAX;
	kr = (*pad->iface)->ReadPipeAsync(pad->iface, pad->in_pipe, pad->buffer, sizeof(pad->buffer), read_cb, pad);
	if (kr) {
		close_one(pad);
		return kr;
	}
	pad->queued = 1;
	return kIOReturnSuccess;
}
static IOReturn open_service(io_service_t service) {
	uint32_t location = location_of(service);
	if (location && pad_at_location(location)) {
		IOObjectRelease(service);
		return kIOReturnSuccess;
	}
	char product[72];
	copy_product_name(service, product, sizeof(product));
	if (xpad_ignore_product(product)) {
		IOObjectRelease(service);
		return kIOReturnNoDevice;
	}
	Pad *pad = unused_pad();
	if (!pad) {
		IOObjectRelease(service);
		return kIOReturnNoResources;
	}
	IOCFPlugInInterface **plugin = NULL;
	SInt32 score = 0;
	IOReturn kr = IOCreatePlugInInterfaceForService(
		service, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &plugin, &score);
	if (kr || !plugin) {
		IOObjectRelease(service);
		return kr ? kr : kIOReturnNoDevice;
	}
	kr = (*plugin)->QueryInterface(plugin, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID650), (LPVOID *)&pad->device);
	(*plugin)->Release(plugin);
	if (kr || !pad->device) {
		pad->device = NULL;
		IOObjectRelease(service);
		return kr ? kr : kIOReturnNoDevice;
	}
	kr = (*pad->device)->USBDeviceOpenSeize(pad->device);
	if (kr) kr = (*pad->device)->USBDeviceOpen(pad->device);
	if (kr) {
		(*pad->device)->Release(pad->device);
		pad->device = NULL;
		IOObjectRelease(service);
		return kr;
	}
	UInt16 vid = 0, pid = 0;
	(*pad->device)->GetDeviceVendor(pad->device, &vid);
	(*pad->device)->GetDeviceProduct(pad->device, &pid);
	IOUSBConfigurationDescriptorPtr desc = NULL;
	kr = (*pad->device)->GetConfigurationDescriptorPtr(pad->device, 0, &desc);
	int cls = 0, sub = 0, proto = 0;
	const XpadDevice *info = NULL;
	if (!kr && desc && xpad_scan_config((const uint8_t *)desc, desc->wTotalLength, &cls, &sub, &proto))
		info = xpad_lookup(vid, pid, cls, sub, proto);
	if (!info || !xpad_protocol_supported(info->protocol)) {
		(*pad->device)->USBDeviceClose(pad->device);
		(*pad->device)->Release(pad->device);
		pad->device = NULL;
		IOObjectRelease(service);
		return kIOReturnNoDevice;
	}
	kr = (*pad->device)->SetConfiguration(pad->device, desc->bConfigurationValue);
	if (kr) {
		close_one(pad);
		IOObjectRelease(service);
		return kr;
	}
	IOUSBFindInterfaceRequest req = {
		kIOUSBFindInterfaceDontCare, kIOUSBFindInterfaceDontCare,
		kIOUSBFindInterfaceDontCare, kIOUSBFindInterfaceDontCare};
	io_iterator_t interfaces = 0;
	kr = (*pad->device)->CreateInterfaceIterator(pad->device, &req, &interfaces);
	io_service_t iface_service = interfaces ? IOIteratorNext(interfaces) : 0;
	if (interfaces) IOObjectRelease(interfaces);
	if (kr || !iface_service) {
		close_one(pad);
		IOObjectRelease(service);
		return kr ? kr : kIOReturnNoDevice;
	}
	pad->service = service;
	pad->location = location;
	pad->vid = vid;
	pad->pid = pid;
	snprintf(pad->name, sizeof(pad->name), "%s", info->name);
	if (product[0] && info->vid == 0) snprintf(pad->name, sizeof(pad->name), "%s", product);
	pad->protocol = info->protocol;
	pad->quirks = info->quirks;
	if (info->protocol == XPAD_PROTO_GIP)
		pad->quirks |= xpad_generic_gip_quirks(vid, pid);
	kr = claim_interface(pad, iface_service, pad->quirks);
	IOObjectRelease(iface_service);
	if (kr) return kr;
	publish();
	return kIOReturnSuccess;
}
static void scan_pads(void) {
	io_iterator_t iterator = 0;
	IOReturn kr = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOUSBHostDevice"), &iterator);
	if (kr || !iterator) return;
	io_service_t service;
	while ((service = IOIteratorNext(iterator))) {
		if (live_count() >= MAX_PADS) {
			IOObjectRelease(service);
			break;
		}
		open_service(service);
	}
	IOObjectRelease(iterator);
}
static int check_once(void) {
	scan_pads();
	CFAbsoluteTime deadline = CFAbsoluteTimeGetCurrent() + 2.0;
	while (CFAbsoluteTimeGetCurrent() < deadline) {
		int ready = 0;
		for (int i = 0; i < MAX_PADS; i++) if (pads[i].iface && pads[i].last_buttons != UINT_MAX) ready++;
		if (ready) break;
		CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, true);
	}
	int ok = 0;
	for (int i = 0; i < MAX_PADS; i++) if (pads[i].iface && pads[i].last_buttons != UINT_MAX) ok++;
	if (!ok) {
		fprintf(stderr, "No wired Xbox 360/One-style pad reports received.\n");
		close_all();
		return 1;
	}
	printf("Wired USB pad check passed (%d device%s).\n", ok, ok == 1 ? "" : "s");
	close_all();
	return 0;
}
static int dump_once(void) {
	NSMutableArray *rows = [NSMutableArray array];
	io_iterator_t iterator = 0;
	IOReturn kr = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOUSBHostDevice"), &iterator);
	if (kr || !iterator) {
		fprintf(stderr, "No USB host devices.\n");
		return 1;
	}
	io_service_t service;
	while ((service = IOIteratorNext(iterator))) {
		char product[72];
		copy_product_name(service, product, sizeof(product));
		UInt16 vid = 0, pid = 0;
		int cls = 0, sub = 0, proto = 0, opened = 0;
		NSString *match = @"none", *row = @"", *error = @"";
		CFNumberRef vid_n = IORegistryEntryCreateCFProperty(service, CFSTR("idVendor"), kCFAllocatorDefault, 0);
		CFNumberRef pid_n = IORegistryEntryCreateCFProperty(service, CFSTR("idProduct"), kCFAllocatorDefault, 0);
		int vid_i = 0, pid_i = 0;
		if (vid_n) { CFNumberGetValue(vid_n, kCFNumberIntType, &vid_i); CFRelease(vid_n); }
		if (pid_n) { CFNumberGetValue(pid_n, kCFNumberIntType, &pid_i); CFRelease(pid_n); }
		vid = (UInt16)vid_i;
		pid = (UInt16)pid_i;
		if (xpad_ignore_product(product)) {
			IOObjectRelease(service);
			continue;
		}
		IOCFPlugInInterface **plugin = NULL;
		SInt32 score = 0;
		IOUSBDeviceInterface650 **device = NULL;
		kr = IOCreatePlugInInterfaceForService(
			service, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &plugin, &score);
		if (!kr && plugin) {
			(*plugin)->QueryInterface(plugin, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID650), (LPVOID *)&device);
			(*plugin)->Release(plugin);
		}
		if (device) {
			kr = (*device)->USBDeviceOpenSeize(device);
			if (kr) kr = (*device)->USBDeviceOpen(device);
			if (!kr) {
				opened = 1;
				(*device)->GetDeviceVendor(device, &vid);
				(*device)->GetDeviceProduct(device, &pid);
				IOUSBConfigurationDescriptorPtr desc = NULL;
				if (!(*device)->GetConfigurationDescriptorPtr(device, 0, &desc) && desc)
					xpad_scan_config((const uint8_t *)desc, desc->wTotalLength, &cls, &sub, &proto);
			} else error = [NSString stringWithFormat:@"open failed 0x%x (quit Chrome/Brave or the game)", kr];
		}
		const XpadDevice *info = xpad_lookup(vid, pid, cls, sub, proto);
		if (xpad_is_hid_interface(cls)) match = @"hid-leave-to-godot";
		else if (info && info->protocol == XPAD_PROTO_GIP) match = @"gip";
		else if (info && info->protocol == XPAD_PROTO_XID360) match = @"xid360";
		NSString *label = product[0] ? @(product) : @"USB device";
		if (info && xpad_protocol_supported(info->protocol))
			row = [NSString stringWithFormat:@"{0x%04x, 0x%04x, \"%s\", %s, 0}",
				vid, pid, info->name, xpad_protocol_token(info->protocol)];
		else if (vid || pid)
			row = [NSString stringWithFormat:@"{0x%04x, 0x%04x, \"%@\", XPAD_PROTO_NONE, 0} /* unknown interface %02x:%02x:%02x */",
				vid, pid, label, cls, sub, proto];
		NSMutableDictionary *entry = [@{
			@"name": label,
			@"vid": [NSString stringWithFormat:@"%04x", vid],
			@"pid": [NSString stringWithFormat:@"%04x", pid],
			@"interface": [NSString stringWithFormat:@"%02x:%02x:%02x", cls, sub, proto],
			@"match": match,
			@"catalog_row": row
		} mutableCopy];
		if (error.length) entry[@"error"] = error;
		[rows addObject:entry];
		if (opened) {
			(*device)->USBDeviceClose(device);
			(*device)->Release(device);
		} else if (device) (*device)->Release(device);
		IOObjectRelease(service);
	}
	IOObjectRelease(iterator);
	NSData *json = [NSJSONSerialization dataWithJSONObject:rows options:NSJSONWritingPrettyPrinted error:nil];
	if (json) fwrite(json.bytes, 1, json.length, stdout);
	putchar('\n');
	return rows.count ? 0 : 1;
}
@interface AppDelegate : NSObject <NSApplicationDelegate>
@end
@implementation AppDelegate
- (void)tryOpen:(NSTimer *)timer {
	(void)timer;
	scan_pads();
	if (!live_count()) status(@"Plug in a wired Xbox 360 or Xbox One-style controller. Looking…\nHID DualShock / Xbox Bluetooth pads do not use this reader.");
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 640, 260)
		styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
		backing:NSBackingStoreBuffered defer:NO];
	window.title = @"Giga Couch — wired USB reader";
	label = [NSTextField wrappingLabelWithString:@"Looking for wired Xbox 360 / Xbox One-style controllers…"];
	label.frame = NSMakeRect(24, 24, 590, 200);
	label.font = [NSFont systemFontOfSize:18];
	[window.contentView addSubview:label];
	[window center];
	[window makeKeyAndOrderFront:nil];
	[NSApp activateIgnoringOtherApps:YES];
	[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(tryOpen:) userInfo:nil repeats:YES];
	[self tryOpen:nil];
}
- (void)applicationWillTerminate:(NSNotification *)notification {
	(void)notification;
	close_all();
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
	(void)sender;
	return YES;
}
@end
int main(int argc, const char **argv) {
	@autoreleasepool {
		if (argc == 2 && strcmp(argv[1], "--check") == 0) return check_once();
		if (argc == 2 && strcmp(argv[1], "--dump") == 0) return dump_once();
		if (argc != 2) {
			fprintf(stderr, "Usage: CouchXpadReader /absolute/private/session/state.json\n       CouchXpadReader --check\n       CouchXpadReader --dump\n");
			return 2;
		}
		statePath = [NSString stringWithUTF8String:argv[1]];
		if (![statePath isAbsolutePath]) return 2;
		NSApplication *app = [NSApplication sharedApplication];
		[app setActivationPolicy:NSApplicationActivationPolicyRegular];
		AppDelegate *delegate = [AppDelegate new];
		app.delegate = delegate;
		[app run];
	}
	return 0;
}

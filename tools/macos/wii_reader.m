// Experimental reader for the observed 04e8:7021 Wii-report device. One Remote per process.
#import <Cocoa/Cocoa.h>
#import <IOKit/hid/IOHIDManager.h>
#include "wii_reports.h"
static WiiCalibration calibration;
static NSString *statePath;
static NSTextField *label;
static IOHIDDeviceRef remote;
static uint8_t inputBuffer[64];
static int packetCount;
static unsigned lastMask = UINT_MAX;
static unsigned lastPressedMask;
static NSTimeInterval lastWrite;
static void status(NSString *text) { label.stringValue = text; NSLog(@"CouchWii: %@", text); }
static void report(void *context, IOReturn result, void *sender, IOHIDReportType type, uint32_t reportID, uint8_t *bytes, CFIndex length) {
    if (result != kIOReturnSuccess) { status([NSString stringWithFormat:@"Input error: 0x%x", result]); return; }
    packetCount++;
    if (length < 1 || bytes[0] != reportID) return;
    // Read-only factory calibration reply: 21 BB BB size/error address[2] data[10].
    if (reportID == 0x21 && length >= 16 && !(bytes[3]&0x0f) && (bytes[3]>>4) >= 9
        && bytes[4] == 0 && bytes[5] == 0x16) {
        if (wii_read_calibration(bytes+6, 10, &calibration)) NSLog(@"CouchWii: factory accelerometer calibration loaded");
        return;
    }
    WiiSample sample;
    if (!wii_decode(bytes, (size_t)length, &calibration, &sample)) return;
    unsigned mask = sample.buttons;
    NSTimeInterval now = NSDate.date.timeIntervalSince1970;
    // Bounded 50 Hz motion snapshots, plus immediate button changes.
    if (mask != lastMask || now - lastWrite >= (sample.motion ? 0.02 : 0.5)) {
        if (mask) lastPressedMask = mask;
        NSMutableDictionary *state = [@{@"buttons":@(mask), @"updated":@(now)} mutableCopy];
        if (sample.motion) {
            state[@"acceleration"] = @[@(sample.acceleration[0]),@(sample.acceleration[1]),@(sample.acceleration[2])];
            state[@"calibration"] = calibration.factory ? @"factory" : @"approximate";
        }
        NSData *data = [NSJSONSerialization dataWithJSONObject:state options:0 error:nil];
        NSError *writeError = nil;
        if (![data writeToFile:statePath options:NSDataWritingAtomic error:&writeError]) {
            status([@"Cannot publish Wii input: " stringByAppendingString:writeError.localizedDescription]);
            return;
        }
        label.stringValue = [NSString stringWithFormat:@"Wii connected · %d reports\nButtons: %04x · Motion: %@\nKeep this reader open while playing.\nCloudbound: hold sideways, press 2, then tilt to fly.",packetCount,mask,
            sample.motion ? [NSString stringWithFormat:@"%.2f / %.2f / %.2f g (%@)",sample.acceleration[0],sample.acceleration[1],sample.acceleration[2],state[@"calibration"]] : @"waiting for accelerometer"];
        if (mask != lastMask) NSLog(@"CouchWii button mask: %04x", mask);
        lastMask=mask; lastWrite=now;
    }
}
static void removed(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    if (remote != device) return;
    IOHIDDeviceUnscheduleFromRunLoop(remote, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    IOHIDDeviceClose(remote, kIOHIDOptionsTypeNone);
    CFRelease(remote); remote = NULL; lastMask = UINT_MAX; lastPressedMask = 0;
    [[NSFileManager defaultManager] removeItemAtPath:statePath error:nil];
    status(@"Wii disconnected. Waiting for reconnection…");
}
static void matched(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    if(remote) return;
    IOReturn opened=IOHIDDeviceOpen(device,kIOHIDOptionsTypeNone);
    if(opened!=kIOReturnSuccess) { status([NSString stringWithFormat:@"Cannot open Wii HID device: 0x%x",opened]);return; }
    remote=(IOHIDDeviceRef)CFRetain(device);
    IOHIDDeviceRegisterInputReportCallback(device,inputBuffer,sizeof(inputBuffer),report,NULL);
    IOHIDDeviceScheduleWithRunLoop(device,CFRunLoopGetMain(),kCFRunLoopDefaultMode);
    uint8_t led[]={0x11,0x10};
    uint8_t mode[]={0x12,0x04,0x31};
    uint8_t readCalibration[]={0x17,0x00,0x00,0x00,0x16,0x00,0x0a};
    calibration = wii_default_calibration();
    uint8_t request[]={0x15,0x00};
    IOReturn ledResult=IOHIDDeviceSetReport(device,kIOHIDReportTypeOutput,0x11,led,sizeof(led));
    IOReturn modeResult=IOHIDDeviceSetReport(device,kIOHIDReportTypeOutput,0x12,mode,sizeof(mode));
    IOReturn statusResult=IOHIDDeviceSetReport(device,kIOHIDReportTypeOutput,0x15,request,sizeof(request));
    IOHIDDeviceSetReport(device,kIOHIDReportTypeOutput,0x17,readCalibration,sizeof(readCalibration));
    status([NSString stringWithFormat:@"Wii device opened.\nLED request: 0x%x · Motion request: 0x%x · Status request: 0x%x\nWaiting for reports. Press buttons on the Remote.",ledResult,modeResult,statusResult]);
}
@interface AppDelegate:NSObject<NSApplicationDelegate>
@property(strong) NSWindow *window;
@end
@implementation AppDelegate
- (void)applicationDidFinishLaunching:(NSNotification*)notification {
    self.window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,620,230) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];
    self.window.title=@"Giga Couch — Wii reader";
    label=[NSTextField wrappingLabelWithString:@"Looking for the connected Wii device…"];
    label.frame=NSMakeRect(24,24,570,170);label.font=[NSFont systemFontOfSize:19];
    [self.window.contentView addSubview:label];[self.window center];[self.window makeKeyAndOrderFront:nil];[NSApp activateIgnoringOtherApps:YES];
    IOHIDManagerRef manager=IOHIDManagerCreate(kCFAllocatorDefault,kIOHIDOptionsTypeNone);
    NSDictionary *match=@{@"VendorID":@1256,@"ProductID":@28705,@"Product":@"Nintendo RVL-CNT-01"};
    IOHIDManagerSetDeviceMatching(manager,(__bridge CFDictionaryRef)match);
    IOHIDManagerRegisterDeviceMatchingCallback(manager,matched,NULL);
    IOHIDManagerRegisterDeviceRemovalCallback(manager,removed,NULL);
    IOHIDManagerScheduleWithRunLoop(manager,CFRunLoopGetMain(),kCFRunLoopDefaultMode);
    IOReturn result=IOHIDManagerOpen(manager,kIOHIDOptionsTypeNone);
    status([NSString stringWithFormat:@"Looking for connected Nintendo RVL-CNT-01…\nHID manager status: 0x%x",result]);
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender { return YES; }
@end
int main(int argc, const char **argv) { @autoreleasepool {
    if (argc != 2) { fprintf(stderr, "Usage: CouchWiiReader /absolute/private/session/state.json\n"); return 2; }
    statePath=[NSString stringWithUTF8String:argv[1]];
    if (![statePath isAbsolutePath]) return 2; NSApplication *app=[NSApplication sharedApplication];[app setActivationPolicy:NSApplicationActivationPolicyRegular];AppDelegate *delegate=[AppDelegate new];app.delegate=delegate;[app run]; } }

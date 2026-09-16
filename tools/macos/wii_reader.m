// Experimental reader for the observed 04e8:7021 Wii-report device. One Remote per process.
#import <Cocoa/Cocoa.h>
#import <IOKit/hid/IOHIDManager.h>
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
    unsigned a=length>0?bytes[0]:0,b=length>1?bytes[1]:0,c=length>2?bytes[2]:0;
    if (reportID != 0x30 || length < 3 || a != 0x30) return;
    unsigned mask = (b << 8) | c;
    NSTimeInterval now = NSDate.date.timeIntervalSince1970;
    if (mask != lastMask || now - lastWrite > 0.5) {
        if (mask) lastPressedMask = mask;
        NSDictionary *state = @{@"buttons":@(mask), @"updated":@(now)};
        NSData *data = [NSJSONSerialization dataWithJSONObject:state options:0 error:nil];
        [data writeToFile:statePath options:NSDataWritingAtomic error:nil];
        label.stringValue = [NSString stringWithFormat:@"Receiving Wii reports: %d\nButtons now: %04x · last press: %04x\nKeep this reader open. In Little World: 2 joins/jumps, D-pad moves.",packetCount,mask,lastPressedMask];
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
    uint8_t mode[]={0x12,0x04,0x30};
    uint8_t request[]={0x15,0x00};
    IOReturn ledResult=IOHIDDeviceSetReport(device,kIOHIDReportTypeOutput,0x11,led,sizeof(led));
    IOReturn modeResult=IOHIDDeviceSetReport(device,kIOHIDReportTypeOutput,0x12,mode,sizeof(mode));
    IOReturn statusResult=IOHIDDeviceSetReport(device,kIOHIDReportTypeOutput,0x15,request,sizeof(request));
    status([NSString stringWithFormat:@"Wii device opened.\nLED request: 0x%x · Buttons request: 0x%x · Status request: 0x%x\nWaiting for reports. Press buttons on the Remote.",ledResult,modeResult,statusResult]);
}
@interface AppDelegate:NSObject<NSApplicationDelegate>
@property(strong) NSWindow *window;
@end
@implementation AppDelegate
- (void)applicationDidFinishLaunching:(NSNotification*)notification {
    self.window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,620,230) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];
    self.window.title=@"Couch Games — Wii reader";
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

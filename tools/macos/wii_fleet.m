// Driving-only multi-device reader for the observed 04e8:7021 Wii-report variant.
#import <Cocoa/Cocoa.h>
#import <IOKit/hid/IOHIDManager.h>
#include "wii_reports.h"
static NSString *sessionDirectory;
static NSTextField *label;
@interface WiiConnection : NSObject {
@public
    uint8_t buffer[64];
    WiiCalibration calibration;
}
@property(assign) IOHIDDeviceRef device;
@property NSInteger slot;
@property(strong) NSString *generation;
@property unsigned lastMask;
@property NSTimeInterval lastWrite;
@end
@implementation WiiConnection
- (void)dealloc { if (_device) CFRelease(_device); }
@end
static NSMutableDictionary<NSNumber *,WiiConnection *> *connections;
static NSString *pathFor(NSInteger slot) {
    return [sessionDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"remote-%ld.json",(long)slot]];
}
static void report(void *context, IOReturn result, void *sender, IOHIDReportType type, uint32_t reportID, uint8_t *bytes, CFIndex length) {
    WiiConnection *connection = (__bridge WiiConnection *)context;
    if (result != kIOReturnSuccess || length < 1 || bytes[0] != reportID) return;
    if (reportID == 0x21 && length >= 16 && !(bytes[3]&0x0f) && (bytes[3]>>4)>=9 && bytes[4]==0 && bytes[5]==0x16) {
        if (wii_read_calibration(bytes+6,10,&connection->calibration))
            NSLog(@"PocketRally Wii %ld: factory calibration loaded",(long)connection.slot+1);
        return;
    }
    WiiSample sample;
    if (!wii_decode(bytes,(size_t)length,&connection->calibration,&sample)) return;
    NSTimeInterval now = NSDate.date.timeIntervalSince1970;
    if (sample.buttons == connection.lastMask && now-connection.lastWrite < (sample.motion ? 0.02 : 0.5)) return;
    NSMutableDictionary *state = [@{@"generation":connection.generation,@"buttons":@(sample.buttons),@"updated":@(now)} mutableCopy];
    if (sample.motion) {
        state[@"acceleration"] = @[@(sample.acceleration[0]),@(sample.acceleration[1]),@(sample.acceleration[2])];
        state[@"calibration"] = connection->calibration.factory ? @"factory" : @"approximate";
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:state options:0 error:nil];
    NSError *error = nil;
    if (![data writeToFile:pathFor(connection.slot) options:NSDataWritingAtomic error:&error]) {
        label.stringValue = [@"Could not deliver controller input: " stringByAppendingString:error.localizedDescription];
        return;
    }
    label.stringValue = [NSString stringWithFormat:@"%lu Wii Remote(s) connected\nRemote %ld: %@\nHold sideways · 2 joins / gas · 1 brake\nKeep this reader open while driving.",(unsigned long)connections.count,(long)connection.slot+1,
        sample.motion ? [NSString stringWithFormat:@"Motion %.2f / %.2f / %.2f g",sample.acceleration[0],sample.acceleration[1],sample.acceleration[2]] : @"Waiting for motion"];
    if (sample.buttons != connection.lastMask) NSLog(@"PocketRally Wii %ld buttons: %04x",(long)connection.slot+1,sample.buttons);
    connection.lastMask = sample.buttons;
    connection.lastWrite = now;
}
static void removed(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    for (NSNumber *key in connections.allKeys) {
        WiiConnection *connection = connections[key];
        if (connection.device != device) continue;
        IOHIDDeviceUnscheduleFromRunLoop(device,CFRunLoopGetMain(),kCFRunLoopDefaultMode);
        IOHIDDeviceClose(device,kIOHIDOptionsTypeNone);
        [[NSFileManager defaultManager] removeItemAtPath:pathFor(connection.slot) error:nil];
        [connections removeObjectForKey:key];
        label.stringValue = [NSString stringWithFormat:@"Wii Remote disconnected. %lu remaining.\nReconnect and press 2 to rejoin.",(unsigned long)connections.count];
        break;
    }
}
static void matched(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    for (WiiConnection *connection in connections.allValues) if (connection.device == device) return;
    NSInteger slot = 0;
    while (slot < 16 && connections[@(slot)]) slot++;
    if (slot == 16) return;
    IOReturn opened = IOHIDDeviceOpen(device,kIOHIDOptionsTypeNone);
    if (opened != kIOReturnSuccess) { NSLog(@"PocketRally Wii open error: 0x%x",opened); return; }
    WiiConnection *connection = [WiiConnection new];
    connection.device = (IOHIDDeviceRef)CFRetain(device);
    connection.slot = slot;
    connection.generation = NSUUID.UUID.UUIDString;
    connection.lastMask = UINT_MAX;
    connection->calibration = wii_default_calibration();
    connections[@(slot)] = connection;
    IOHIDDeviceRegisterInputReportCallback(device,connection->buffer,sizeof(connection->buffer),report,(__bridge void *)connection);
    IOHIDDeviceScheduleWithRunLoop(device,CFRunLoopGetMain(),kCFRunLoopDefaultMode);
    // Four hardware LEDs repeat; the game labels all sixteen distinct player slots.
    uint8_t led[] = {0x11,(uint8_t)(0x10 << (slot%4))};
    uint8_t mode[] = {0x12,0x04,0x31};
    uint8_t calibrationRequest[] = {0x17,0x00,0x00,0x00,0x16,0x00,0x0a};
    IOHIDDeviceSetReport(device,kIOHIDReportTypeOutput,0x11,led,sizeof(led));
    IOReturn modeResult = IOHIDDeviceSetReport(device,kIOHIDReportTypeOutput,0x12,mode,sizeof(mode));
    IOHIDDeviceSetReport(device,kIOHIDReportTypeOutput,0x17,calibrationRequest,sizeof(calibrationRequest));
    NSLog(@"PocketRally Wii %ld opened; motion request: 0x%x",(long)slot+1,modeResult);
}
@interface RallyDelegate : NSObject<NSApplicationDelegate>
@property(strong) NSWindow *window;
@end
@implementation RallyDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    connections = [NSMutableDictionary new];
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,600,220) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"Pocket Rally — Wii controllers";
    label = [NSTextField wrappingLabelWithString:@"Looking for connected Wii Remotes…\nPair them with this computer first."];
    label.frame = NSMakeRect(24,20,552,176);
    label.font = [NSFont systemFontOfSize:19];
    [self.window.contentView addSubview:label];
    [self.window center]; [self.window makeKeyAndOrderFront:nil];
    IOHIDManagerRef manager = IOHIDManagerCreate(kCFAllocatorDefault,kIOHIDOptionsTypeNone);
    NSDictionary *match = @{@"VendorID":@1256,@"ProductID":@28705,@"Product":@"Nintendo RVL-CNT-01"};
    IOHIDManagerSetDeviceMatching(manager,(__bridge CFDictionaryRef)match);
    IOHIDManagerRegisterDeviceMatchingCallback(manager,matched,NULL);
    IOHIDManagerRegisterDeviceRemovalCallback(manager,removed,NULL);
    IOHIDManagerScheduleWithRunLoop(manager,CFRunLoopGetMain(),kCFRunLoopDefaultMode);
    IOHIDManagerOpen(manager,kIOHIDOptionsTypeNone);
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { return YES; }
@end
int main(int argc, const char **argv) { @autoreleasepool {
    if (argc != 2) return 2;
    sessionDirectory = [NSString stringWithUTF8String:argv[1]];
    BOOL isDirectory = NO;
    if (![sessionDirectory isAbsolutePath] || ![[NSFileManager defaultManager] fileExistsAtPath:sessionDirectory isDirectory:&isDirectory] || !isDirectory) return 2;
    NSApplication *app = [NSApplication sharedApplication];
    [app setActivationPolicy:NSApplicationActivationPolicyRegular];
    RallyDelegate *delegate = [RallyDelegate new]; app.delegate = delegate; [app run];
} }

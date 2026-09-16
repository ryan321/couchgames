// Multi-device reader and bounded speaker output for the observed 04e8:7021 Wii-report variant.
#import <Cocoa/Cocoa.h>
#import <IOKit/hid/IOHIDManager.h>
#include "wii_reports.h"
#include "wii_speaker.h"
#include <math.h>
#include <signal.h>
static NSString *sessionDirectory;
static NSTextField *label;
@interface WiiConnection : NSObject {
@public
    uint8_t buffer[64];
    WiiCalibration calibration;
    WiiSpeaker speaker;
}
@property(assign) IOHIDDeviceRef device;
@property NSInteger slot;
@property(strong) NSString *generation;
@property(strong) NSString *lastSpeakerRequest;
@property NSTimeInterval nextCommandRead;
@property double rumbleUntil;
@property BOOL rumbling;
@property double audioStarted;
@property unsigned latePackets;
@property unsigned writesInFlight;
@property BOOL disconnected;
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
static void silence(WiiConnection *connection) {
    connection.rumbleUntil=0; connection.rumbling=NO;
    uint8_t mute[]={0x19,4}, disable[]={0x14,0};
    IOHIDDeviceSetReport(connection.device,kIOHIDReportTypeOutput,0x19,mute,sizeof(mute));
    IOHIDDeviceSetReport(connection.device,kIOHIDReportTypeOutput,0x14,disable,sizeof(disable));
    connection->speaker.active=false;
}
// Each report owns its buffer until IOKit completes the asynchronous write.
@interface WiiOutput : NSObject
@property(strong) WiiConnection *connection;
@property(strong) NSData *data;
@end
@implementation WiiOutput
@end
static void outputComplete(void *context, IOReturn result, void *sender, IOHIDReportType type, uint32_t reportID, uint8_t *bytes, CFIndex length) {
    WiiOutput *output=(__bridge_transfer WiiOutput *)context;
    WiiConnection *connection=output.connection;
    if(connection.writesInFlight) connection.writesInFlight--;
    if(result!=kIOReturnSuccess && !connection.disconnected) {
        NSLog(@"Couch Wii %ld asynchronous output %02x failed: 0x%x",(long)connection.slot+1,reportID,result);
        connection->speaker.active=false;
        connection.rumbleUntil=0;
    }
}
static IOReturn sendOutput(WiiConnection *connection, const uint8_t *packet, size_t length) {
    WiiOutput *output=[WiiOutput new];
    output.connection=connection; output.data=[NSData dataWithBytes:packet length:length];
    void *context=(__bridge_retained void *)output;
    connection.writesInFlight++;
    IOReturn result=IOHIDDeviceSetReportWithCallback(connection.device,kIOHIDReportTypeOutput,packet[0],output.data.bytes,length,100,outputComplete,context);
    if(result!=kIOReturnSuccess) {
        connection.writesInFlight--;
        CFBridgingRelease(context);
    }
    return result;
}
static void speakerTick(void) {
    NSTimeInterval now=NSDate.date.timeIntervalSince1970;
    double clock=NSProcessInfo.processInfo.systemUptime;
    for(WiiConnection *connection in connections.allValues) {
        if(now>=connection.nextCommandRead) {
            connection.nextCommandRead=now+0.03;
            NSString *path=[sessionDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"speaker-%ld.json",(long)connection.slot]];
            NSDictionary *attributes=[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
            if(attributes && [attributes fileSize]<=4096) {
                NSData *raw=[NSData dataWithContentsOfFile:path];
                id request=raw ? [NSJSONSerialization JSONObjectWithData:raw options:0 error:nil] : nil;
                if([request isKindOfClass:NSDictionary.class]) {
                    id generation=request[@"generation"], identifier=request[@"id"], expires=request[@"expires"], encoded=request[@"audio"], encoding=request[@"encoding"], rumble=request[@"rumble_ms"];
                    if([generation isKindOfClass:NSString.class] && [generation isEqual:connection.generation] &&
                       [identifier isKindOfClass:NSString.class] && [identifier length]>0 && [identifier length]<=64 &&
                       ![identifier isEqual:connection.lastSpeakerRequest] && [expires isKindOfClass:NSNumber.class] &&
                       isfinite([expires doubleValue]) && [expires doubleValue]>=now && [expires doubleValue]<=now+1.5 &&
                       [encoded isKindOfClass:NSString.class] && [encoded length]<=2200 &&
                       [encoding isKindOfClass:NSString.class] && [encoding isEqual:@"yamaha4k"] &&
                       [rumble isKindOfClass:NSNumber.class] && isfinite([rumble doubleValue]) &&
                       [rumble doubleValue]>=0 && [rumble doubleValue]<=250) {
                        NSData *audio=[[NSData alloc] initWithBase64EncodedString:encoded options:0];
                        if(audio && audio.length<=WII_SPEAKER_MAX_AUDIO) {
                            connection.lastSpeakerRequest=identifier;
                            connection.rumbleUntil=clock+[rumble doubleValue]/1000.0;
                            if(!audio.length) {
                                if(connection->speaker.active) wii_speaker_stop(&connection->speaker,clock);
                            }
                            else {
                                connection.audioStarted=0; connection.latePackets=0;
                                wii_speaker_start(&connection->speaker,audio.bytes,audio.length,clock);
                                NSLog(@"Couch Wii %ld speaker: %lu ADPCM bytes",(long)connection.slot+1,(unsigned long)audio.length);
                            }
                        }
                    }
                }
            }
        }
        BOOL rumble=clock<connection.rumbleUntil;
        if(rumble!=connection.rumbling) {
            uint8_t vibration[]={0x10,rumble ? 1 : 0};
            IOReturn result=sendOutput(connection,vibration,sizeof(vibration));
            connection.rumbling=rumble;
            if(result!=kIOReturnSuccess) NSLog(@"Couch Wii %ld rumble failed: 0x%x",(long)connection.slot+1,result);
        }
        if(connection.writesInFlight>=4 || (connection->speaker.stage==6 && connection.writesInFlight)) continue;
        BOOL wasActive=connection->speaker.active;
        if(wasActive && connection->speaker.stage==7 && clock-connection->speaker.next>0.006) connection.latePackets++;
        uint8_t packet[22];
        size_t length=wii_speaker_tick(&connection->speaker,clock,packet);
        if(length) {
            packet[1] |= rumble ? 1 : 0;
            if(packet[0]==0x18 && !connection.audioStarted) connection.audioStarted=clock;
            IOReturn result=sendOutput(connection,packet,length);
            if(result!=kIOReturnSuccess) {
                NSLog(@"Couch Wii %ld speaker output failed: 0x%x",(long)connection.slot+1,result);
                silence(connection);
            }
        }
        if(wasActive && !connection->speaker.active && connection.audioStarted) {
            NSLog(@"Couch Wii %ld speaker complete: %.3fs, %u late packets",(long)connection.slot+1,clock-connection.audioStarted,connection.latePackets);
            connection.audioStarted=0;
        }
    }
}
static void report(void *context, IOReturn result, void *sender, IOHIDReportType type, uint32_t reportID, uint8_t *bytes, CFIndex length) {
    WiiConnection *connection = (__bridge WiiConnection *)context;
    if (result != kIOReturnSuccess || length < 1 || bytes[0] != reportID) return;
    if (reportID==0x22 && length>=5 && bytes[4]!=0 && connection->speaker.active &&
        (bytes[3]==0x14 || bytes[3]==0x16 || bytes[3]==0x18 || bytes[3]==0x19)) {
        NSLog(@"Couch Wii %ld rejected speaker report %02x: %02x",(long)connection.slot+1,bytes[3],bytes[4]);
        silence(connection);
        return;
    }
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
    label.stringValue = [NSString stringWithFormat:@"%lu Wii Remote(s) connected\nRemote %ld: %@\nHold sideways · 2 joins · D-pad selects\nKeep this reader open while playing.",(unsigned long)connections.count,(long)connection.slot+1,
        sample.motion ? [NSString stringWithFormat:@"Motion %.2f / %.2f / %.2f g",sample.acceleration[0],sample.acceleration[1],sample.acceleration[2]] : @"Waiting for motion"];
    if (sample.buttons != connection.lastMask) NSLog(@"PocketRally Wii %ld buttons: %04x",(long)connection.slot+1,sample.buttons);
    connection.lastMask = sample.buttons;
    connection.lastWrite = now;
}
static void removed(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    for (NSNumber *key in connections.allKeys) {
        WiiConnection *connection = connections[key];
        if (connection.device != device) continue;
        connection->speaker.active=false;
        connection.disconnected=YES;
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
    [NSTimer scheduledTimerWithTimeInterval:0.005 repeats:YES block:^(NSTimer *timer) { speakerTick(); }];
    // The launcher sends SIGTERM on game exit: let AppKit mute all speakers before quitting.
    signal(SIGTERM,SIG_IGN);
    static dispatch_source_t termination;
    termination=dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL,SIGTERM,0,dispatch_get_main_queue());
    dispatch_source_set_event_handler(termination,^{ [NSApp terminate:nil]; });
    dispatch_resume(termination);
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,600,220) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"Couch Games — Wii controllers";
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
- (void)applicationWillTerminate:(NSNotification *)notification {
    for(WiiConnection *connection in connections.allValues) silence(connection);
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

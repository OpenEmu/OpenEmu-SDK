// Copyright (c) 2026, OpenEmu Team
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the OpenEmu Team nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

/*
 * Why the DualShock 4 needs its own handler over Bluetooth
 *
 * Over Bluetooth the controller sends a short report 0x01 only until something
 * reads one of its feature reports; from then on it sends report 0x11 for the rest
 * of the connection. macOS appears to read a feature report on connect, so in
 * practice report 0x11 is all OpenEmu ever sees. Its payload is declared as vendor
 * defined data, so IOKit exposes no Generic Desktop or Button elements for it. The
 * elements OpenEmu resolves its controls through belong to report 0x01 and never
 * change value: the controller shows up with a full control list, but no button
 * press ever arrives.
 *
 * This handler decodes the raw input reports instead, the same way
 * OESwitchProControllerHIDDeviceHandler does for the Switch Pro Controller. The
 * wire format lives in OEPS4DualShock4InputReport.h so it can be unit tested.
 *
 * The controller description comes from the existing OEControllerSonyPS4Dualshock4
 * database entry, so bindings - which are saved by control identifier, not by
 * cookie - are shared with the same controller connected over USB.
 */

#import "OEControllerDescription_Internal.h"
#import "OEDeviceDescription.h"
#import "OEPS4BluetoothHIDDeviceHandler.h"
#import "OEPS4DualShock4InputReport.h"


#define MAX_INPUT_REPORT_SIZE (256)

//#define LOG_COMMUNICATION


static void OEDS4HIDReportCallback(
    void * _Nullable        context,
    IOReturn                result,
    void * _Nullable        sender,
    IOHIDReportType         type,
    uint32_t                reportID,
    uint8_t *               report,
    CFIndex                 reportLength);


@interface OEPS4BluetoothHIDDeviceParser ()

+ (OEPS4BluetoothHIDDeviceParser *)sharedInstance;
+ (NSUInteger)_cookieFromUsage:(NSUInteger)usage;

@end


#pragma mark - Device Handler


@implementation OEPS4BluetoothHIDDeviceHandler
{
    NSThread *_thread;

    uint8_t _reportBuffer[MAX_INPUT_REPORT_SIZE];

    /* Reports arrive at up to 1 kHz, so every diagnostic on the report path fires
     * once rather than continuously. */
    uint64_t _loggedUndecodableReportIDs[4];
    BOOL _loggedReportIDMismatch;
    BOOL _loggedCallbackFailure;

    OEDS4InputState _lastState;
    BOOL _haveLastState;
}


@synthesize eventRunLoop = _eventRunLoop;


/* Matched on transport, vendor and product ID. Over USB the generic element based
 * path in OEPS4HIDDeviceHandler works and is left alone; third party pads that only
 * imitate the "Wireless Controller" name are left to it as well, since nothing
 * guarantees they implement report 0x11. */
+ (BOOL)canHandleDevice:(IOHIDDeviceRef)aDevice
{
    NSString *transport = (__bridge NSString *)IOHIDDeviceGetProperty(aDevice, CFSTR(kIOHIDTransportKey));
    if (![transport isEqualToString:@kIOHIDTransportBluetoothValue])
        return NO;

    NSNumber *vid = (__bridge NSNumber *)IOHIDDeviceGetProperty(aDevice, CFSTR(kIOHIDVendorIDKey));
    if ([vid integerValue] != OEDS4VendorIDSony)
        return NO;

    NSInteger pid = [(__bridge NSNumber *)IOHIDDeviceGetProperty(aDevice, CFSTR(kIOHIDProductIDKey)) integerValue];
    return pid == OEDS4ProductIDDualShock4 || pid == OEDS4ProductIDDualShock4V2;
}


+ (OEHIDDeviceParser *)deviceParser
{
    return [OEPS4BluetoothHIDDeviceParser sharedInstance];
}


- (void)setUpCallbacks
{
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    _thread = [[NSThread alloc] initWithBlock:^{
        self->_eventRunLoop = (CFRunLoopRef)CFRetain(CFRunLoopGetCurrent());

        IOHIDDeviceRegisterInputReportCallback(self.device, self->_reportBuffer, MAX_INPUT_REPORT_SIZE, OEDS4HIDReportCallback, (__bridge void *)self);
        [super setUpCallbacks];

        dispatch_semaphore_signal(done);
        CFRunLoopRun();
    }];
    [_thread setQualityOfService:NSQualityOfServiceUserInteractive];
    [_thread setName:@"org.openemu.OpenEmuSystem.dualShock4Thread"];
    [_thread start];
    dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
}


- (BOOL)connect
{
    [self _requestExtendedReportMode];
    return YES;
}


- (void)disconnect
{
    [super disconnect];

    /* Stopping the run loop the device is scheduled on ends the callbacks;
     * -[OEHIDDeviceHandler dealloc] closes the device. */
    CFRunLoopStop(_eventRunLoop);
}


- (void)dealloc
{
    if (_eventRunLoop)
        CFRelease(_eventRunLoop);
}


/* Reading the calibration feature report makes the controller switch to report
 * 0x11. macOS has usually done this already and both reports are decoded anyway,
 * so a failure is not fatal, but it is logged because some of the errors also mean
 * no input will arrive at all. */
- (void)_requestExtendedReportMode
{
    uint8_t buffer[OEDS4_CALIBRATION_BT_FEATURE_REPORT_SIZE] = {0};
    CFIndex length = sizeof(buffer);

    IOReturn ret = IOHIDDeviceGetReport([self device], kIOHIDReportTypeFeature, OEDS4FeatureReportIDCalibrationBT, buffer, &length);
    if (ret == kIOReturnSuccess)
        return;

    NSString *hint;
    switch (ret) {
        case kIOReturnNotOpen:
            hint = @"the HID device was never opened";
            break;
        case kIOReturnNotPermitted:
            hint = @"permission was denied - check Input Monitoring in System Settings > Privacy & Security";
            break;
        case kIOReturnExclusiveAccess:
            hint = @"another application has exclusive access to the controller";
            break;
        default:
            hint = @"the controller did not answer";
            break;
    }
    NSLog(@"[dev %p] DualShock 4: could not read the calibration feature report (error %x): %@. "
          @"Continuing, but if no input arrives at all this is why.", self, ret, hint);
}


#pragma mark - Event Dispatching


- (void)dispatchEventWithHIDValue:(IOHIDValueRef)aValue
{
    /* Ignore the HID elements. Before the switch to report 0x11 they do fire, but
     * with real IOKit cookies while this handler dispatches its own, so honouring
     * both would deliver every press twice under two identities. */
}


- (void)_reportCallbackFailedWithResult:(IOReturn)result length:(CFIndex)length
{
    if (_loggedCallbackFailure)
        return;
    _loggedCallbackFailure = YES;

    NSLog(@"[dev %p] DualShock 4: input report callback failed (error %x, length %ld); "
          @"reports of this shape are dropped", self, result, (long)length);
}


- (void)_didReceiveInputReportWithID:(uint8_t)reportID data:(const uint8_t *)data length:(NSUInteger)length
{
    /* The payload offsets are relative to the report ID in byte 0. */
    if (length < 1 || data[0] != reportID) {
        if (!_loggedReportIDMismatch) {
            _loggedReportIDMismatch = YES;
            NSLog(@"[dev %p] DualShock 4: input report %#04x does not start with its report ID "
                  @"(length %lu); reports of this shape are dropped",
                  self, reportID, (unsigned long)length);
        }
        return;
    }

    OEDS4InputState state = OEDS4InputStateNeutral();
    switch (OEDS4DecodeInputReport(reportID, data, length, &state)) {
        case OEDS4DecodeResultDecoded:
            break;

        case OEDS4DecodeResultNoInput:
            return;

        case OEDS4DecodeResultUndecodable: {
            #ifdef LOG_COMMUNICATION
            NSLog(@"[dev %p] undecodable report %@", self, [NSData dataWithBytes:data length:length]);
            #endif
            /* Log each undecodable report ID once, so that a controller sending only
             * reports we cannot read can be told apart from an idle one. */
            uint64_t bit = 1ULL << (reportID & 0x3F);
            uint64_t *word = &_loggedUndecodableReportIDs[reportID >> 6];
            if (!(*word & bit)) {
                *word |= bit;
                NSLog(@"[dev %p] DualShock 4: cannot decode input report %#04x (%lu bytes); "
                      @"no events will be dispatched for reports of this type",
                      self, reportID, (unsigned long)length);
            }
            return;
        }
    }

    #ifdef LOG_COMMUNICATION
    NSLog(@"[dev %p] input report %@", self, [NSData dataWithBytes:data length:length]);
    #endif

    /* Most reports repeat the previous state exactly; skip building events that
     * -dispatchEvent: would only discard as duplicates. */
    if (_haveLastState && memcmp(&_lastState, &state, sizeof(state)) == 0)
        return;
    _lastState = state;
    _haveLastState = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self _dispatchEventsWithInputState:state];
    });
}


- (void)_dispatchEventsWithInputState:(OEDS4InputState)state
{
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];

    [self _dispatchButtonEventsWithButtonMask:state.buttons0 buttonMap:OEDS4ButtonState0Map() timestamp:now];
    [self _dispatchButtonEventsWithButtonMask:state.buttons1 buttonMap:OEDS4ButtonState1Map() timestamp:now];
    [self _dispatchButtonEventsWithButtonMask:state.buttons2 buttonMap:OEDS4ButtonState2Map() timestamp:now];

    static const OEHIDEventHatDirection valueToHat[] = {
        [OEDS4HatSwitchNorth]     = OEHIDEventHatDirectionNorth,
        [OEDS4HatSwitchNorthEast] = OEHIDEventHatDirectionNorthEast,
        [OEDS4HatSwitchEast]      = OEHIDEventHatDirectionEast,
        [OEDS4HatSwitchSouthEast] = OEHIDEventHatDirectionSouthEast,
        [OEDS4HatSwitchSouth]     = OEHIDEventHatDirectionSouth,
        [OEDS4HatSwitchSouthWest] = OEHIDEventHatDirectionSouthWest,
        [OEDS4HatSwitchWest]      = OEHIDEventHatDirectionWest,
        [OEDS4HatSwitchNorthWest] = OEHIDEventHatDirectionNorthWest,
        [OEDS4HatSwitchCentered]  = OEHIDEventHatDirectionNull,
    };
    OEHIDEventHatDirection hat = valueToHat[OEDS4HatSwitchFromButtonState0(state.buttons0)];
    NSUInteger hatCookie = [OEPS4BluetoothHIDDeviceParser _cookieFromUsage:kHIDUsage_GD_Hatswitch];
    [self dispatchEvent:[OEHIDEvent hatSwitchEventWithDeviceHandler:self timestamp:now type:OEHIDEventHatSwitchType8Ways direction:hat cookie:hatCookie]];

    /* Sticks count in the HID direction already, with neutral at 0x80. Usages
     * follow the database: right stick on Z/Rz, triggers on Rx/Ry. */
    [self _dispatchAxisEventWithAxis:OEHIDEventAxisX  value:state.leftX  timestamp:now];
    [self _dispatchAxisEventWithAxis:OEHIDEventAxisY  value:state.leftY  timestamp:now];
    [self _dispatchAxisEventWithAxis:OEHIDEventAxisZ  value:state.rightX timestamp:now];
    [self _dispatchAxisEventWithAxis:OEHIDEventAxisRz value:state.rightY timestamp:now];

    /* L2 and R2 also produce digital buttons above; the database declares both. */
    [self _dispatchTriggerEventWithAxis:OEHIDEventAxisRx value:state.l2 timestamp:now];
    [self _dispatchTriggerEventWithAxis:OEHIDEventAxisRy value:state.r2 timestamp:now];
}


- (void)_dispatchButtonEventsWithButtonMask:(uint8_t)mask buttonMap:(const uint8_t[])map timestamp:(NSTimeInterval)ts
{
    for (int i = 0; map[i] != 0; i += 2) {
        uint8_t thisButtonMask = map[i];
        uint8_t thisButtonNumber = map[i + 1];
        NSUInteger cookie = [OEPS4BluetoothHIDDeviceParser _cookieFromUsage:thisButtonNumber];
        OEHIDEventState state = (mask & thisButtonMask) ? OEHIDEventStateOn : OEHIDEventStateOff;
        [self dispatchEvent:[OEHIDEvent buttonEventWithDeviceHandler:self timestamp:ts buttonNumber:thisButtonNumber state:state cookie:cookie]];
    }
}


- (void)_dispatchAxisEventWithAxis:(OEHIDEventAxis)axis value:(uint8_t)rawValue timestamp:(NSTimeInterval)now
{
    NSUInteger cookie = [OEPS4BluetoothHIDDeviceParser _cookieFromUsage:axis];
    CGFloat value = [self calibratedValue:rawValue forAxis:axis controlCookie:cookie defaultCalibration:OEAxisCalibrationMake(0, UINT8_MAX)];
    [self dispatchEvent:[OEHIDEvent axisEventWithDeviceHandler:self timestamp:now axis:axis value:value cookie:cookie]];
}


- (void)_dispatchTriggerEventWithAxis:(OEHIDEventAxis)axis value:(uint8_t)rawValue timestamp:(NSTimeInterval)now
{
    NSUInteger cookie = [OEPS4BluetoothHIDDeviceParser _cookieFromUsage:axis];

    /* Triggers are unipolar, so the dead zone is a floor rather than a band around
     * the centre, as in the generic element path. */
    NSInteger value = rawValue;
    if ((CGFloat)value / (CGFloat)UINT8_MAX <= [self deadZoneForControlCookie:cookie])
        value = 0;

    [self dispatchEvent:[OEHIDEvent triggerEventWithDeviceHandler:self timestamp:now axis:axis value:value maximum:UINT8_MAX cookie:cookie]];
}


@end


static void OEDS4HIDReportCallback(
    void * _Nullable        context,
    IOReturn                result,
    void * _Nullable        sender,
    IOHIDReportType         type,
    uint32_t                reportID,
    uint8_t *               report,
    CFIndex                 reportLength)
{
    OEPS4BluetoothHIDDeviceHandler *handler = (__bridge OEPS4BluetoothHIDDeviceHandler *)context;

    /* On a failed transfer the buffer and length are not meaningful, and a negative
     * length must not widen into the unsigned parameter below. */
    if (result != kIOReturnSuccess || reportLength <= 0) {
        [handler _reportCallbackFailedWithResult:result length:reportLength];
        return;
    }

    [handler _didReceiveInputReportWithID:(uint8_t)reportID data:report length:(NSUInteger)reportLength];
}


#pragma mark - Device Parser


@implementation OEPS4BluetoothHIDDeviceParser


+ (OEPS4BluetoothHIDDeviceParser *)sharedInstance
{
    static OEPS4BluetoothHIDDeviceParser *parser;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        parser = [[OEPS4BluetoothHIDDeviceParser alloc] init];
    });
    return parser;
}


/* The controller description is built here, so the cookies are ours to choose; the
 * mapping only has to be injective over the usages the database entry declares and
 * shared by the parser and the handler. */
+ (NSUInteger)_cookieFromUsage:(NSUInteger)usage
{
    /* X, Y, Z, Rx, Ry and Rz */
    if (usage >= kHIDUsage_GD_X && usage <= kHIDUsage_GD_Rz)
        return usage - kHIDUsage_GD_X + 0x4B3;
    if (usage == kHIDUsage_GD_Hatswitch)
        return 0x4B2;
    /* buttons, numbered from 1 */
    return usage + 1;
}


- (OEDeviceHandler *)deviceHandlerForIOHIDDevice:(IOHIDDeviceRef)device
{
    /* Built from the controller database rather than from the HID elements, which
     * describe a report the controller does not send. */
    NSNumber *vid = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey));
    NSNumber *pid = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey));
    NSString *pkey = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
    OEControllerDescription *controllerDesc = [OEControllerDescription OE_controllerDescriptionForVendorID:vid.integerValue productID:pid.integerValue product:pkey];

    if ([[controllerDesc controls] count] == 0) {
        NSDictionary *representations = [OEControllerDescription OE_representationForControllerDescription:controllerDesc];
        if (representations == nil)
            NSLog(@"DualShock 4: no OEControllerSonyPS4Dualshock4 entry in Controller-Database.plist; "
                  @"the controller will have no controls");

        [representations enumerateKeysAndObjectsUsingBlock:^(NSString *identifier, NSDictionary *representation, BOOL *stop) {
            OEHIDEventType type = OEHIDEventTypeFromNSString(representation[@"Type"]);
            NSUInteger usage = OEUsageFromUsageStringWithType(representation[@"Usage"], type);
            NSUInteger cookie = [OEPS4BluetoothHIDDeviceParser _cookieFromUsage:usage];

            OEHIDEvent *event;
            switch (type) {
                case OEHIDEventTypeAxis:
                    event = [OEHIDEvent axisEventWithDeviceHandler:nil timestamp:0 axis:usage direction:OEHIDEventAxisDirectionNull cookie:cookie];
                    break;
                case OEHIDEventTypeTrigger:
                    event = [OEHIDEvent triggerEventWithDeviceHandler:nil timestamp:0 axis:usage direction:OEHIDEventAxisDirectionNull cookie:cookie];
                    break;
                case OEHIDEventTypeButton:
                    event = [OEHIDEvent buttonEventWithDeviceHandler:nil timestamp:0 buttonNumber:usage state:OEHIDEventStateOn cookie:cookie];
                    break;
                case OEHIDEventTypeHatSwitch:
                    event = [OEHIDEvent hatSwitchEventWithDeviceHandler:nil timestamp:0 type:OEHIDEventHatSwitchType8Ways direction:OEHIDEventHatDirectionNull cookie:cookie];
                    break;
                default:
                    NSLog(@"DualShock 4: unexpected control \"%@\" of type \"%@\" in the controller database, skipping it",
                          identifier, representation[@"Type"]);
                    return;
            }

            [controllerDesc addControlWithIdentifier:identifier name:representation[@"Name"] event:event valueRepresentations:representation[@"Values"]];
        }];
    }

    return [[OEPS4BluetoothHIDDeviceHandler alloc] initWithIOHIDDevice:device deviceDescription:[controllerDesc deviceDescriptionForVendorID:vid.integerValue productID:pid.integerValue cookie:0]];
}


@end

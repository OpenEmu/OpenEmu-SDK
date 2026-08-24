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
 * Over USB the DualSense sends input report 0x01, whose stick, trigger, hat and
 * button fields the report descriptor describes with ordinary Generic Desktop and
 * Button usages, so the generic element based parsing in OEHIDDeviceParser handles
 * it and this handler deliberately leaves USB alone.
 *
 * Over Bluetooth the controller sends a cut-down version of report 0x01 only until
 * something reads one of its feature reports, at which point it switches to input
 * report 0x31 for the rest of the connection. Report 0x31's payload is declared as
 * vendor defined data (usage page 0xFF00), so IOKit exposes no Generic Desktop or
 * Button elements for it at all. In practice the controller is already in that mode
 * by the time the first report arrives, because macOS appears to read a feature
 * report on connect; -connect reads one too, but that runs after the input report
 * callback is already live, so it cannot beat the first report. The cut-down report
 * is decoded as well for the window where neither has happened. The elements OpenEmu resolves its controls
 * through belong to report 0x01 and therefore never change value: the controller
 * enumerates and shows a full control list in the Controls preferences, but no
 * event is ever dispatched.
 *
 * Decode the raw input reports instead, the way
 * OESwitchProControllerHIDDeviceHandler already does for the Switch Pro Controller.
 * The wire format and the decoding live in OEPS5DualSenseInputReport.h so they can
 * be unit tested without a controller attached.
 *
 * Reported as OpenEmu/OpenEmu#4790 and OpenEmu/OpenEmu#5100.
 */

#import "OEControllerDescription_Internal.h"
#import "OEDeviceDescription.h"
#import "OEPS5DualSenseHIDDeviceHandler.h"
#import "OEPS5DualSenseInputReport.h"


#pragma mark - Device Handler Parameters


#define MAX_INPUT_REPORT_SIZE (256)

//#define LOG_COMMUNICATION


static void OEDSDualSenseHIDReportCallback(
    void * _Nullable        context,
    IOReturn                result,
    void * _Nullable        sender,
    IOHIDReportType         type,
    uint32_t                reportID,
    uint8_t *               report,
    CFIndex                 reportLength);


#pragma mark -


@interface OEPS5DualSenseHIDDeviceParser ()

+ (OEPS5DualSenseHIDDeviceParser *)sharedInstance;
+ (NSUInteger)_cookieFromUsage:(NSUInteger)usage;

@end


#pragma mark - Device Handler


@implementation OEPS5DualSenseHIDDeviceHandler
{
    NSThread *_thread;

    uint8_t _reportBuffer[MAX_INPUT_REPORT_SIZE];

    /* Reports arrive at roughly 250 Hz, so every diagnostic on the report path has
     * to fire once rather than continuously. A condition that is true at all here is
     * almost always true for the whole connection. */
    uint64_t _loggedUndecodableReportIDs[4];
    BOOL _loggedReportIDMismatch;
    BOOL _loggedCallbackFailure;

    OEDSInputState _lastState;
    BOOL _haveLastState;
}


@synthesize eventRunLoop = _eventRunLoop;


/* Matches on vendor and product ID rather than on kIOHIDProductKey the way the
 * sibling handlers do, because the DualSense's product name varies by firmware.
 * Trusting the name would also be fragile in the other direction: OEPS4HIDDeviceHandler
 * prefix-matches "Wireless Controller", so a DualSense reporting that bare name would
 * be claimed by it instead.
 *
 * Only Bluetooth is claimed: over USB the generic element based path already works,
 * and taking it over would swap the real IOKit cookies in existing users' saved
 * bindings for synthetic ones. */
+ (BOOL)canHandleDevice:(IOHIDDeviceRef)aDevice
{
    NSString *transport = (__bridge NSString *)IOHIDDeviceGetProperty(aDevice, CFSTR(kIOHIDTransportKey));
    if (![transport isEqualToString:@kIOHIDTransportBluetoothValue])
        return NO;

    NSNumber *vid = (__bridge id)IOHIDDeviceGetProperty(aDevice, CFSTR(kIOHIDVendorIDKey));
    if ([vid integerValue] != OEDSVendorIDSony)
        return NO;

    NSNumber *pid = (__bridge id)IOHIDDeviceGetProperty(aDevice, CFSTR(kIOHIDProductIDKey));
    return [pid integerValue] == OEDSProductIDDualSense
        || [pid integerValue] == OEDSProductIDDualSenseEdge;
}


+ (OEHIDDeviceParser *)deviceParser
{
    return [OEPS5DualSenseHIDDeviceParser sharedInstance];
}


- (void)setUpCallbacks
{
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    _thread = [[NSThread alloc] initWithBlock:^{
        self->_eventRunLoop = (CFRunLoopRef)CFRetain(CFRunLoopGetCurrent());

        IOHIDDeviceRegisterInputReportCallback(self.device, self->_reportBuffer, MAX_INPUT_REPORT_SIZE, OEDSDualSenseHIDReportCallback, (__bridge void *)self);
        [super setUpCallbacks];

        dispatch_semaphore_signal(done);
        CFRunLoopRun();
    }];
    [_thread setQualityOfService:NSQualityOfServiceUserInteractive];
    [_thread setName:@"org.openemu.OpenEmuSystem.dualSenseThread"];
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

    /* Stopping the run loop the device is scheduled on is what ends the callbacks;
     * -[OEHIDDeviceHandler dealloc] closes the device. Unregistering the callback
     * from here would mutate IOKit state from the main thread while the event
     * thread may be inside it. */
    CFRunLoopStop(_eventRunLoop);
}


- (void)dealloc
{
    if (_eventRunLoop)
        CFRelease(_eventRunLoop);
}


/* Reading a feature report appears to be what makes the controller switch from the
 * cut-down report 0x01 to the full report 0x31. macOS has usually already done this,
 * and we decode both reports regardless, so a failure here is not fatal - but it is
 * worth reporting, because some of the errors it can return (not open, not
 * permitted, exclusive access) also mean no input reports will arrive at all. */
- (void)_requestExtendedReportMode
{
    uint8_t buffer[OEDS_CALIBRATION_FEATURE_REPORT_SIZE] = {0};
    CFIndex length = sizeof(buffer);

    IOReturn ret = IOHIDDeviceGetReport([self device], kIOHIDReportTypeFeature, OEDSFeatureReportIDCalibration, buffer, &length);
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
    NSLog(@"[dev %p] DualSense: could not read the calibration feature report (error %x): %@. "
          @"Continuing, but if no input arrives at all this is why.", self, ret, hint);
}


#pragma mark - Event Dispatching


- (void)dispatchEventWithHIDValue:(IOHIDValueRef)aValue
{
    /* Ignore the HID elements. Before the controller switches to report 0x31 they do
     * fire, but they carry real IOKit cookies while this handler dispatches synthetic
     * ones, so honouring both would deliver every press twice under two identities. */
    return;
}


- (void)_reportCallbackFailedWithResult:(IOReturn)result length:(CFIndex)length
{
    if (_loggedCallbackFailure)
        return;
    _loggedCallbackFailure = YES;

    NSLog(@"[dev %p] DualSense: input report callback failed (error %x, length %ld); "
          @"reports of this shape are dropped", self, result, (long)length);
}


- (void)_didReceiveInputReportWithID:(uint8_t)reportID data:(uint8_t *)data length:(NSUInteger)length
{
    /* The payload offsets are relative to the report ID in byte 0, so a disagreement
     * between the buffer and the callback's report ID would shift every field. */
    if (length < 1 || data[0] != reportID) {
        if (!_loggedReportIDMismatch) {
            _loggedReportIDMismatch = YES;
            if (length < 1)
                NSLog(@"[dev %p] DualSense: empty input report, dropping", self);
            else
                NSLog(@"[dev %p] DualSense: report ID mismatch (callback says 0x%02x, buffer says 0x%02x); "
                      @"the payload offsets would be wrong, so reports of this shape are dropped",
                      self, reportID, data[0]);
        }
        return;
    }

    OEDSInputState state = OEDSInputStateNeutral();
    if (!OEDSDecodeInputReport(reportID, data, length, &state)) {
        #ifdef LOG_COMMUNICATION
        NSLog(@"[dev %p] undecodable report %@", self, [NSData dataWithBytes:data length:length]);
        #endif
        /* Report each undecodable report ID once. A controller that only ever sends
         * reports we cannot decode is a dead controller, and without this there is
         * no way to tell that apart from a controller that is simply idle. */
        uint64_t bit = 1ULL << (reportID & 0x3F);
        uint64_t *word = &_loggedUndecodableReportIDs[reportID >> 6];
        if (!(*word & bit)) {
            *word |= bit;
            NSLog(@"[dev %p] DualSense: cannot decode input report 0x%02x (%lu bytes); "
                  @"no events will be dispatched for reports of this type",
                  self, reportID, (unsigned long)length);
        }
        return;
    }

    #ifdef LOG_COMMUNICATION
    NSLog(@"[dev %p] input report %@", self, [NSData dataWithBytes:data length:length]);
    #endif

    /* Reports arrive at roughly 250 Hz and each one would otherwise build 22 events
     * for -dispatchEvent: to discard as duplicates. Repeats are common: the buttons
     * and hat are static for long stretches, and only stick jitter moves. */
    if (_haveLastState && memcmp(&_lastState, &state, sizeof(state)) == 0)
        return;
    _lastState = state;
    _haveLastState = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self _dispatchEventsWithInputState:state];
    });
}


- (void)_dispatchEventsWithInputState:(OEDSInputState)state
{
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];

    /* The button numbers come from OEPS5DualSenseInputReport.h, where the tests can
     * check them against the controller database the bindings resolve through. */
    [self _dispatchButtonEventsWithButtonMask:state.buttons0 buttonMap:OEDSButtonState0Map() timestamp:now];
    [self _dispatchButtonEventsWithButtonMask:state.buttons1 buttonMap:OEDSButtonState1Map() timestamp:now];
    [self _dispatchButtonEventsWithButtonMask:state.buttons2 buttonMap:OEDSButtonState2Map() timestamp:now];

    /* D-Pad. Indexed by name rather than by raw nibble so that a transposed entry is
     * visible on the page. */
    static const OEHIDEventHatDirection valueToHat[] = {
        [OEDSHatSwitchNorth]     = OEHIDEventHatDirectionNorth,
        [OEDSHatSwitchNorthEast] = OEHIDEventHatDirectionNorthEast,
        [OEDSHatSwitchEast]      = OEHIDEventHatDirectionEast,
        [OEDSHatSwitchSouthEast] = OEHIDEventHatDirectionSouthEast,
        [OEDSHatSwitchSouth]     = OEHIDEventHatDirectionSouth,
        [OEDSHatSwitchSouthWest] = OEHIDEventHatDirectionSouthWest,
        [OEDSHatSwitchWest]      = OEHIDEventHatDirectionWest,
        [OEDSHatSwitchNorthWest] = OEHIDEventHatDirectionNorthWest,
        [OEDSHatSwitchCentered]  = OEHIDEventHatDirectionNull,
    };
    OEHIDEventHatDirection hat = valueToHat[OEDSHatSwitchFromButtonState0(state.buttons0)];
    NSUInteger hatCookie = [OEPS5DualSenseHIDDeviceParser _cookieFromUsage:kHIDUsage_GD_Hatswitch];
    [self dispatchEvent:[OEHIDEvent hatSwitchEventWithDeviceHandler:self timestamp:now type:OEHIDEventHatSwitchType8Ways direction:hat cookie:hatCookie]];

    /* Sticks. Unlike the Switch Pro Controller, neither axis needs inverting: the
     * DualSense already counts in the same direction as the HID convention, with
     * neutral at 0x80. */
    [self _dispatchAxisEventWithAxis:OEHIDEventAxisX  value:state.leftX  timestamp:now];
    [self _dispatchAxisEventWithAxis:OEHIDEventAxisY  value:state.leftY  timestamp:now];
    [self _dispatchAxisEventWithAxis:OEHIDEventAxisZ  value:state.rightX timestamp:now];
    [self _dispatchAxisEventWithAxis:OEHIDEventAxisRz value:state.rightY timestamp:now];

    /* L2 and R2 each also produce a digital button above, matching the database,
     * which declares both a Trigger and a Button for them. */
    [self _dispatchTriggerEventWithAxis:OEHIDEventAxisRx value:state.l2 timestamp:now];
    [self _dispatchTriggerEventWithAxis:OEHIDEventAxisRy value:state.r2 timestamp:now];
}


- (void)_dispatchButtonEventsWithButtonMask:(uint8_t)mask buttonMap:(const uint8_t[])map timestamp:(NSTimeInterval)ts
{
    int i = 0;
    while (map[i] != 0) {
        uint8_t thisButtonMask = map[i++];
        uint8_t thisButtonNumber = map[i++];
        NSUInteger cookie = [OEPS5DualSenseHIDDeviceParser _cookieFromUsage:thisButtonNumber];
        OEHIDEventState state = (mask & thisButtonMask) ? OEHIDEventStateOn : OEHIDEventStateOff;
        [self dispatchEvent:[OEHIDEvent buttonEventWithDeviceHandler:self timestamp:ts buttonNumber:thisButtonNumber state:state cookie:cookie]];
    }
}


- (void)_dispatchAxisEventWithAxis:(OEHIDEventAxis)axis value:(uint8_t)rawValue timestamp:(NSTimeInterval)now
{
    NSUInteger cookie = [OEPS5DualSenseHIDDeviceParser _cookieFromUsage:axis];
    CGFloat value = [self calibratedValue:rawValue forAxis:axis controlCookie:cookie defaultCalibration:OEAxisCalibrationMake(0, UINT8_MAX)];
    [self dispatchEvent:[OEHIDEvent axisEventWithDeviceHandler:self timestamp:now axis:axis value:value cookie:cookie]];
}


- (void)_dispatchTriggerEventWithAxis:(OEHIDEventAxis)axis value:(uint8_t)rawValue timestamp:(NSTimeInterval)now
{
    NSUInteger cookie = [OEPS5DualSenseHIDDeviceParser _cookieFromUsage:axis];

    /* Triggers are unipolar, so the dead zone is a floor rather than a band around
     * the centre. The generic element path applies the same cut in -[OEHIDEvent
     * OE_setupEventWithDeviceHandler:value:]; without this a resting trigger bias
     * would read as permanently held. */
    NSInteger value = rawValue;
    if ((CGFloat)value / (CGFloat)UINT8_MAX <= [self deadZoneForControlCookie:cookie])
        value = 0;

    [self dispatchEvent:[OEHIDEvent triggerEventWithDeviceHandler:self timestamp:now axis:axis value:value maximum:UINT8_MAX cookie:cookie]];
}


@end


static void OEDSDualSenseHIDReportCallback(
    void * _Nullable        context,
    IOReturn                result,
    void * _Nullable        sender,
    IOHIDReportType         type,
    uint32_t                reportID,
    uint8_t *               report,
    CFIndex                 reportLength)
{
    OEPS5DualSenseHIDDeviceHandler *handler = (__bridge OEPS5DualSenseHIDDeviceHandler *)context;

    /* On a failed transfer the buffer contents and the length are not meaningful.
     * reportLength is signed, so letting a negative value widen into the unsigned
     * length parameter would defeat every bounds check downstream. */
    if (result != kIOReturnSuccess || reportLength <= 0) {
        [handler _reportCallbackFailedWithResult:result length:reportLength];
        return;
    }

    [handler _didReceiveInputReportWithID:reportID data:report length:(NSUInteger)reportLength];
}


#pragma mark - Device Parser


@implementation OEPS5DualSenseHIDDeviceParser


+ (OEPS5DualSenseHIDDeviceParser *)sharedInstance
{
    static OEPS5DualSenseHIDDeviceParser *parser;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        parser = [[OEPS5DualSenseHIDDeviceParser alloc] init];
    });
    return parser;
}


/* Since we build the controller description ourselves, the cookies are ours to
 * choose. All that matters is that this mapping is injective over the usages the
 * DualSense entry declares, and that the parser and the handler agree on it. The
 * base values are borrowed from OESwitchProControllerHIDDeviceParser for
 * familiarity only; unlike that parser we map the whole 0x30-0x35 range linearly,
 * so Rx and Ry deliberately do not land on the same cookies it uses. */
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
    /* Build a controller description from the controller database rather than from
     * the HID elements, which describe a report the controller does not send. */

    NSNumber *vid = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey));
    NSNumber *pid = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey));
    NSString *pkey = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
    OEControllerDescription *controllerDesc = [OEControllerDescription OE_controllerDescriptionForVendorID:vid.integerValue productID:pid.integerValue product:pkey];

    if ([[controllerDesc controls] count] == 0) {
        NSDictionary *representations = [OEControllerDescription OE_representationForControllerDescription:controllerDesc];
        if (representations == nil)
            NSLog(@"DualSense: no OEControllerSonyPS5DualSense entry in Controller-Database.plist; "
                  @"the controller will have no controls");

        [representations enumerateKeysAndObjectsUsingBlock:^(NSString *identifier, NSDictionary *representation, BOOL *stop) {
            OEHIDEventType type = OEHIDEventTypeFromNSString(representation[@"Type"]);
            NSUInteger usage = OEUsageFromUsageStringWithType(representation[@"Usage"], type);
            NSUInteger cookie = [OEPS5DualSenseHIDDeviceParser _cookieFromUsage:usage];

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
                    NSLog(@"DualSense: unexpected control \"%@\" of type \"%@\" in the controller database, skipping it",
                          identifier, representation[@"Type"]);
                    return;
            }

            [controllerDesc addControlWithIdentifier:identifier name:representation[@"Name"] event:event valueRepresentations:representation[@"Values"]];
        }];
    }

    return [[OEPS5DualSenseHIDDeviceHandler alloc] initWithIOHIDDevice:device deviceDescription:[controllerDesc deviceDescriptionForVendorID:vid.integerValue productID:pid.integerValue cookie:0]];
}


@end

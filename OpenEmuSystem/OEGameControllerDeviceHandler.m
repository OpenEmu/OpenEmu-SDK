// Copyright (c) 2024, OpenEmu Team
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

#import "OEGameControllerDeviceHandler.h"
#import "OEControllerDescription.h"
#import "OEControllerDescription_Internal.h"
#import "OEControlDescription.h"
#import "OEDeviceDescription.h"
#import "OEDeviceManager.h"
#import "OEHIDEvent.h"
#import "OEHIDEvent_Internal.h"

#import <GameController/GameController.h>

NS_ASSUME_NONNULL_BEGIN

/// The identifier of the profile in Controller-Database.plist onto which we map
/// the GameController framework's extended gamepad profile.
static NSString *const OEGameControllerProfileIdentifier = @"OEControllerGCExtendedGamepadProfile";

/// GCController.productCategory string values. We compare against literals
/// rather than the GCProductCategory* symbols because those symbols are only
/// available on macOS 12+, while OpenEmu deploys back to 10.14 and
/// -productCategory itself is available from macOS 11.
static NSString *const OEGCProductCategoryXboxOne    = @"Xbox One";
static NSString *const OEGCProductCategoryDualShock4 = @"DualShock 4";
static NSString *const OEGCProductCategoryDualSense  = @"DualSense";

/// Button usages, matching the OEControllerGCExtendedGamepadProfile mappings in
/// Controller-Database.plist. These double as HID event cookies.
typedef NS_ENUM(NSUInteger, OEGCButtonUsage) {
    OEGCButtonUsageA        = 1,
    OEGCButtonUsageB        = 2,
    OEGCButtonUsageX        = 3,
    OEGCButtonUsageY        = 4,
    OEGCButtonUsageL1       = 5,
    OEGCButtonUsageR1       = 6,
    OEGCButtonUsageL2       = 7,
    OEGCButtonUsageR2       = 8,
    OEGCButtonUsageDPadUp   = 144,
    OEGCButtonUsageDPadDown = 145,
    OEGCButtonUsageDPadRight = 146,
    OEGCButtonUsageDPadLeft = 147,
    OEGCButtonUsageStart    = 148,
    OEGCButtonUsageSelect   = 149,
    OEGCButtonUsageLeftStick  = 150,
    OEGCButtonUsageRightStick = 151,
    OEGCButtonUsageHome     = 547,
};

@implementation OEGameControllerDeviceHandler {
    GCController *_controller;
    NSString *_uniqueIdentifier;
    NSUInteger _vendorID;
    NSUInteger _productID;
    NSMutableDictionary<NSNumber *, OEHIDEvent *> *_latestEvents;
}

@synthesize controller = _controller;

+ (nullable instancetype)deviceHandlerWithController:(GCController *)controller
{
    if (@available(macOS 11.0, *)) {
        // ok — continue below
    } else {
        // GCController exists earlier, but the extended-gamepad element-level
        // API and productCategory we rely on are macOS 11+. Older systems
        // still surface these controllers over IOKit HID anyway.
        return nil;
    }

    if (controller.extendedGamepad == nil) {
        // We only know how to map extended gamepads; micro gamepads (Siri
        // Remote etc.) have too few controls to be useful for emulation.
        return nil;
    }

    OEControllerDescription *controllerDescription = [OEControllerDescription OE_controllerDescriptionForIdentifier:OEGameControllerProfileIdentifier];
    if (controllerDescription == nil) {
        NSLog(@"OEGameControllerDeviceHandler: %@ profile is missing from Controller-Database.plist", OEGameControllerProfileIdentifier);
        return nil;
    }

    NSUInteger vendorID = 0;
    NSUInteger productID = 0;
    [self OE_vendorID:&vendorID productID:&productID forController:controller];

    NSString *product = controller.vendorName ?: @"Game Controller";

    // Register the concrete device (VID/PID/name) with the profile so bindings
    // are stored per physical controller model, then build the control set from
    // the profile representation (as the Switch Pro parser does over USB).
    OEDeviceDescription *deviceDescription = [controllerDescription OE_addDeviceDescriptionWithVendorID:vendorID productID:productID product:product cookie:0];

    if (controllerDescription.numberOfControls == 0)
        [self OE_populateControlsForControllerDescription:controllerDescription];

    return [[self alloc] initWithController:controller deviceDescription:deviceDescription vendorID:vendorID productID:productID];
}

+ (void)OE_populateControlsForControllerDescription:(OEControllerDescription *)controllerDescription
{
    NSDictionary<NSString *, NSDictionary<NSString *, id> *> *representations = [OEControllerDescription OE_representationForControllerDescription:controllerDescription];

    [representations enumerateKeysAndObjectsUsingBlock:^(NSString *identifier, NSDictionary *representation, BOOL *stop) {
        OEHIDEventType type = OEHIDEventTypeFromNSString(representation[@"Type"]);
        NSUInteger usage = OEUsageFromUsageStringWithType(representation[@"Usage"], type);
        NSUInteger cookie = usage;

        OEHIDEvent *event;
        switch (type) {
            case OEHIDEventTypeAxis:
                event = [OEHIDEvent axisEventWithDeviceHandler:nil timestamp:0 axis:(OEHIDEventAxis)usage direction:OEHIDEventAxisDirectionNull cookie:cookie];
                break;
            case OEHIDEventTypeButton:
                event = [OEHIDEvent buttonEventWithDeviceHandler:nil timestamp:0 buttonNumber:usage state:OEHIDEventStateOn cookie:cookie];
                break;
            default:
                NSLog(@"OEGameControllerDeviceHandler: unexpected control type in %@", OEGameControllerProfileIdentifier);
                return;
        }

        [controllerDescription addControlWithIdentifier:identifier name:representation[@"Name"] event:event valueRepresentations:representation[@"Values"]];
    }];
}

+ (void)OE_vendorID:(NSUInteger *)outVendorID productID:(NSUInteger *)outProductID forController:(GCController *)controller
{
    // The GameController framework doesn't expose USB VID/PID directly, so we
    // infer the vendor from the product category. This matches the values used
    // by the corresponding IOKit HID devices, so bindings are shared where
    // possible.
    NSUInteger vendorID = 0;
    NSUInteger productID = 0;

    if (@available(macOS 11.0, *)) {
        NSString *category = controller.productCategory;
        if ([category isEqualToString:OEGCProductCategoryXboxOne]) {
            vendorID = 0x045E; // Microsoft
        } else if ([category isEqualToString:OEGCProductCategoryDualShock4] ||
                   [category isEqualToString:OEGCProductCategoryDualSense]) {
            vendorID = 0x054C; // Sony
        }
    }

    if (outVendorID)  *outVendorID = vendorID;
    if (outProductID) *outProductID = productID;
}

- (instancetype)initWithController:(GCController *)controller deviceDescription:(OEDeviceDescription *)deviceDescription vendorID:(NSUInteger)vendorID productID:(NSUInteger)productID
{
    if (!(self = [super initWithDeviceDescription:deviceDescription]))
        return nil;

    _controller = controller;
    _vendorID = vendorID;
    _productID = productID;
    _latestEvents = [[NSMutableDictionary alloc] init];

    return self;
}

- (BOOL)connect
{
    __weak __typeof__(self) weakSelf = self;
    _controller.extendedGamepad.valueChangedHandler = ^(GCExtendedGamepad *gamepad, GCControllerElement *element) {
        if (@available(macOS 11.0, *))
            [weakSelf OE_dispatchEventsForChangedElement:element inGamepad:gamepad];
    };

    return YES;
}

- (void)disconnect
{
    _controller.extendedGamepad.valueChangedHandler = nil;

    [super disconnect];
}

#pragma mark - Identity

- (NSString *)uniqueIdentifier
{
    if (_uniqueIdentifier == nil) {
        // GCController doesn't expose a stable hardware serial. Combine the
        // product name and category for a reasonably stable identifier within
        // a session.
        NSString *category = @"";
        if (@available(macOS 11.0, *))
            category = _controller.productCategory ?: @"";

        _uniqueIdentifier = [NSString stringWithFormat:@"GC:%@:%@", self.product, category];
    }

    return _uniqueIdentifier;
}

- (NSString *)serialNumber
{
    return nil;
}

- (NSString *)manufacturer
{
    if (@available(macOS 11.0, *)) {
        NSString *category = _controller.productCategory;
        if ([category isEqualToString:OEGCProductCategoryXboxOne])
            return @"Microsoft";
        if ([category isEqualToString:OEGCProductCategoryDualShock4] ||
            [category isEqualToString:OEGCProductCategoryDualSense])
            return @"Sony";
        return category;
    }
    return nil;
}

- (NSString *)product
{
    if (_controller.vendorName != nil)
        return _controller.vendorName;

    if (@available(macOS 11.0, *)) {
        if (_controller.productCategory != nil)
            return _controller.productCategory;
    }

    return @"Game Controller";
}

- (NSUInteger)vendorID
{
    return _vendorID;
}

- (NSUInteger)productID
{
    return _productID;
}

#pragma mark - Event dispatch

- (void)OE_dispatchEventsForChangedElement:(GCControllerElement *)element inGamepad:(GCExtendedGamepad *)gamepad API_AVAILABLE(macos(11.0))
{
    NSTimeInterval now = [NSDate date].timeIntervalSince1970;

    if (element == gamepad.buttonA) {
        [self OE_dispatchButton:gamepad.buttonA usage:OEGCButtonUsageA timestamp:now];
    } else if (element == gamepad.buttonB) {
        [self OE_dispatchButton:gamepad.buttonB usage:OEGCButtonUsageB timestamp:now];
    } else if (element == gamepad.buttonX) {
        [self OE_dispatchButton:gamepad.buttonX usage:OEGCButtonUsageX timestamp:now];
    } else if (element == gamepad.buttonY) {
        [self OE_dispatchButton:gamepad.buttonY usage:OEGCButtonUsageY timestamp:now];
    } else if (element == gamepad.leftShoulder) {
        [self OE_dispatchButton:gamepad.leftShoulder usage:OEGCButtonUsageL1 timestamp:now];
    } else if (element == gamepad.rightShoulder) {
        [self OE_dispatchButton:gamepad.rightShoulder usage:OEGCButtonUsageR1 timestamp:now];
    } else if (element == gamepad.leftTrigger) {
        [self OE_dispatchButton:gamepad.leftTrigger usage:OEGCButtonUsageL2 timestamp:now];
    } else if (element == gamepad.rightTrigger) {
        [self OE_dispatchButton:gamepad.rightTrigger usage:OEGCButtonUsageR2 timestamp:now];
    } else if (element == gamepad.buttonMenu) {
        // "Menu" is the Start button on Xbox controllers.
        [self OE_dispatchButton:gamepad.buttonMenu usage:OEGCButtonUsageStart timestamp:now];
    } else if (element == gamepad.dpad) {
        [self OE_dispatchButton:gamepad.dpad.up    usage:OEGCButtonUsageDPadUp    timestamp:now];
        [self OE_dispatchButton:gamepad.dpad.down  usage:OEGCButtonUsageDPadDown  timestamp:now];
        [self OE_dispatchButton:gamepad.dpad.left  usage:OEGCButtonUsageDPadLeft  timestamp:now];
        [self OE_dispatchButton:gamepad.dpad.right usage:OEGCButtonUsageDPadRight timestamp:now];
    } else if (element == gamepad.leftThumbstick) {
        [self OE_dispatchAxis:OEHIDEventAxisX value:gamepad.leftThumbstick.xAxis.value timestamp:now];
        // GameController's Y axis points up-positive; the profile expects
        // up-positive as well (see LeftAnalogUp Direction = 1), so no flip.
        [self OE_dispatchAxis:OEHIDEventAxisY value:gamepad.leftThumbstick.yAxis.value timestamp:now];
    } else if (element == gamepad.rightThumbstick) {
        [self OE_dispatchAxis:OEHIDEventAxisZ  value:gamepad.rightThumbstick.xAxis.value timestamp:now];
        [self OE_dispatchAxis:OEHIDEventAxisRz value:gamepad.rightThumbstick.yAxis.value timestamp:now];
    } else if (element == gamepad.buttonOptions) {
        // "Options" is the Select/View button (nullable; older pads lack it).
        [self OE_dispatchButton:gamepad.buttonOptions usage:OEGCButtonUsageSelect timestamp:now];
    } else if (element == gamepad.leftThumbstickButton) {
        [self OE_dispatchButton:gamepad.leftThumbstickButton usage:OEGCButtonUsageLeftStick timestamp:now];
    } else if (element == gamepad.rightThumbstickButton) {
        [self OE_dispatchButton:gamepad.rightThumbstickButton usage:OEGCButtonUsageRightStick timestamp:now];
    } else if (@available(macOS 11.0, *)) {
        if (element == gamepad.buttonHome)
            [self OE_dispatchButton:gamepad.buttonHome usage:OEGCButtonUsageHome timestamp:now];
    }
}

- (void)OE_dispatchButton:(GCControllerButtonInput *)button usage:(OEGCButtonUsage)usage timestamp:(NSTimeInterval)timestamp
{
    OEHIDEventState state = button.isPressed ? OEHIDEventStateOn : OEHIDEventStateOff;
    OEHIDEvent *event = [OEHIDEvent buttonEventWithDeviceHandler:self timestamp:timestamp buttonNumber:usage state:state cookie:usage];
    [self OE_dispatchEvent:event];
}

- (void)OE_dispatchAxis:(OEHIDEventAxis)axis value:(CGFloat)value timestamp:(NSTimeInterval)timestamp
{
    NSUInteger cookie = axis;
    if (fabs(value) < [self deadZoneForControlCookie:cookie])
        value = 0;

    OEHIDEvent *event = [OEHIDEvent axisEventWithDeviceHandler:self timestamp:timestamp axis:axis value:value cookie:cookie];
    [self OE_dispatchEvent:event];
}

- (void)OE_dispatchEvent:(OEHIDEvent *)event
{
    if (event == nil)
        return;

    // Mirror OEHIDDeviceHandler's dispatch semantics: de-duplicate repeated
    // events per cookie, and emit a synthetic null-direction event when an axis
    // flips sign so bindings capture cleanly.
    NSNumber *cookieKey = @(event.cookie);
    OEHIDEvent *existingEvent = _latestEvents[cookieKey];

    if ([event isEqualToEvent:existingEvent])
        return;

    OEDeviceManager *deviceManager = [OEDeviceManager sharedDeviceManager];

    if ([event isAxisDirectionOppositeToEvent:existingEvent])
        [deviceManager deviceHandler:self didReceiveEvent:[event axisEventWithDirection:OEHIDEventAxisDirectionNull]];

    _latestEvents[cookieKey] = event;
    [deviceManager deviceHandler:self didReceiveEvent:event];
}

@end

NS_ASSUME_NONNULL_END

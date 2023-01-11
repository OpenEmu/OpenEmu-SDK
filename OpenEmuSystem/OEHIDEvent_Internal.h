//
//  OEHIDEvent_Internal.h
//  OpenEmu-SDK
//
//  Created by Remy Demarest on 22/12/2015.
//
//

#import <OpenEmuSystem/OpenEmuSystem.h>
#import <OpenEmuBase/OEPropertyList.h>
#import <IOKit/hid/IOHIDLib.h>

@class OEDeviceHandler, OEHIDDeviceHandler, OEWiimoteHIDDeviceHandler;

extern OEHIDEventHatDirection OEHIDEventHatDirectionFromNSString(NSString *string);
extern NSString *NSStringFromOEHIDHatDirection(OEHIDEventHatDirection dir);
extern NSString *NSLocalizedStringFromOEHIDHatDirection(OEHIDEventHatDirection dir);
extern NSString *OEHIDEventAxisDisplayDescription(OEHIDEventAxis axis, OEHIDEventAxisDirection direction);

extern NSString *NSStringFromOEHIDEventType(OEHIDEventType type);
extern OEHIDEventAxis OEHIDEventAxisFromNSString(NSString *string);
extern NSString *NSStringFromOEHIDEventAxis(OEHIDEventAxis axis);
extern NSString *NSStringFromIOHIDElement(IOHIDElementRef elem);
extern OEHIDEventType OEHIDEventTypeFromIOHIDElement(IOHIDElementRef elem);
extern BOOL OEIOHIDElementIsTrigger(IOHIDElementRef elem);

extern const NSEventModifierFlags OENSEventModifierFlagFunctionKey;

enum {
    OEUndefinedCookie = 0ULL,
};

@interface OEHIDEvent ()

+ (instancetype)eventWithDictionaryRepresentation:(NSDictionary<NSString *, __kindof id<OEPropertyList>> *)dictionaryRepresentation;
- (NSDictionary<NSString *, __kindof id<OEPropertyList>> *)dictionaryRepresentation;

@property(readonly) __kindof OEDeviceHandler *deviceHandler;
@property(readonly) BOOL hasDeviceHandlerPlaceholder;
- (void)resolveDeviceHandlerPlaceholder;

@property(readonly) NSTimeInterval          timestamp;
@property(readonly) NSUInteger              cookie;
@property(readonly) NSUInteger              usage;

@property(readonly) NSEvent                *keyboardEvent;
@property(readonly) NSEventModifierFlags    modifierFlags;
@property(readonly, copy) NSString         *characters;
@property(readonly, copy) NSString         *charactersIgnoringModifiers;

+ (NSUInteger)keyCodeForVirtualKey:(CGCharCode)charCode;
+ (instancetype)eventWithDeviceHandler:(OEDeviceHandler *)aDeviceHandler value:(IOHIDValueRef)aValue;
+ (instancetype)axisEventWithDeviceHandler:(OEDeviceHandler *)aDeviceHandler timestamp:(NSTimeInterval)timestamp axis:(OEHIDEventAxis)axis direction:(OEHIDEventAxisDirection)direction cookie:(NSUInteger)cookie;
+ (instancetype)axisEventWithDeviceHandler:(OEDeviceHandler *)aDeviceHandler timestamp:(NSTimeInterval)timestamp axis:(OEHIDEventAxis)axis value:(CGFloat)value cookie:(NSUInteger)cookie;
+ (instancetype)axisEventWithDeviceHandler:(OEDeviceHandler *)aDeviceHandler timestamp:(NSTimeInterval)timestamp axis:(OEHIDEventAxis)axis minimum:(NSInteger)minimum value:(NSInteger)value maximum:(NSInteger)maximum cookie:(NSUInteger)cookie;
+ (instancetype)triggerEventWithDeviceHandler:(OEDeviceHandler *)aDeviceHandler timestamp:(NSTimeInterval)timestamp axis:(OEHIDEventAxis)axis direction:(OEHIDEventAxisDirection)direction cookie:(NSUInteger)cookie;
+ (instancetype)triggerEventWithDeviceHandler:(OEDeviceHandler *)aDeviceHandler timestamp:(NSTimeInterval)timestamp axis:(OEHIDEventAxis)axis value:(NSInteger)value maximum:(NSInteger)maximum cookie:(NSUInteger)cookie;
+ (instancetype)triggerEventWithDeviceHandler:(OEDeviceHandler *)aDeviceHandler timestamp:(NSTimeInterval)timestamp axis:(OEHIDEventAxis)axis value:(CGFloat)value cookie:(NSUInteger)cookie;
+ (instancetype)buttonEventWithDeviceHandler:(OEDeviceHandler *)aDeviceHandler timestamp:(NSTimeInterval)timestamp buttonNumber:(NSUInteger)number state:(OEHIDEventState)state cookie:(NSUInteger)cookie;
+ (instancetype)hatSwitchEventWithDeviceHandler:(OEDeviceHandler *)aDeviceHandler timestamp:(NSTimeInterval)timestamp type:(OEHIDEventHatSwitchType)hatSwitchType direction:(OEHIDEventHatDirection)aDirection cookie:(NSUInteger)cookie;
+ (instancetype)keyEventWithTimestamp:(NSTimeInterval)timestamp keyCode:(NSUInteger)keyCode state:(OEHIDEventState)state cookie:(NSUInteger)cookie;

- (BOOL)isAxisDirectionOppositeToEvent:(OEHIDEvent *)anObject;

+ (NSUInteger)controlIdentifierForType:(OEHIDEventType)type cookie:(NSUInteger)cookie usage:(NSUInteger)usage;

// The value parameter can be an OEHIDEventAxisDirection for Axis and Trigger,
// or OEHIDEventHatDirection for HatSwitch, 1 is assumed for Button and Keyboard types.
+ (NSUInteger)controlValueIdentifierForType:(OEHIDEventType)type cookie:(NSUInteger)cookie usage:(NSUInteger)usage value:(NSInteger)value;

@end

@interface OEHIDEvent (OEHIDEventCopy)

- (instancetype)nullEvent;

// Axis event copy
- (instancetype)axisEventWithOppositeDirection;
- (instancetype)axisEventWithDirection:(OEHIDEventAxisDirection)aDirection;

// Hatswitch event copy
- (instancetype)hatSwitchEventWithDirection:(OEHIDEventHatDirection)aDirection;

- (instancetype)eventWithDeviceHandler:(OEDeviceHandler *)aDeviceHandler;

@end

@interface OEHIDEvent (OEHIDEventBinding)

@property(readonly) NSUInteger bindingHash;
- (BOOL)isBindingEqualToEvent:(OEHIDEvent *)anEvent;

@end

@interface NSEvent (OEEventConversion)
+ (NSEvent *)eventWithKeyCode:(unsigned short)keyCode;
+ (NSEvent *)eventWithKeyCode:(unsigned short)keyCode keyIsDown:(BOOL)keyDown;
+ (NSString *)charactersForKeyCode:(unsigned short)keyCode;
+ (NSString *)printableCharactersForKeyCode:(unsigned short)keyCode;
+ (NSUInteger)modifierFlagsForKeyCode:(unsigned short)keyCode;
+ (NSString *)displayDescriptionForKeyCode:(unsigned short)keyCode;
@property(readonly) NSString *displayDescription;
@end

@interface NSNumber (OEEventConversion)
@property(readonly) NSString *displayDescription;
@end

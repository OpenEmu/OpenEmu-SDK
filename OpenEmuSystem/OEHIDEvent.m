/*
 Copyright (c) 2009, OpenEmu Team

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.
     * Neither the name of the OpenEmu Team nor the
       names of its contributors may be used to endorse or promote products
       derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <objc/runtime.h>
#import "OEHIDEvent.h"
#import "OEDeviceHandler.h"
#import "OEDeviceManager.h"
#import <IOKit/hid/IOHIDUsageTables.h>
#import <Carbon/Carbon.h>
#import "OEHIDUsageToVK.h"
#import "OEHIDDeviceHandler.h"
#import "OEWiimoteHIDDeviceHandler.h"
#import "OEHIDEvent_Internal.h"

static _OEHIDVirtualKeyCodeNameTriplet const OEEmptyTriplet = { 0, 0xFFFF, nil };

static _OEHIDVirtualKeyCodeNameTriplet const * OEHIDUsageToTriplet(NSUInteger ch)
{
    static _OEHIDVirtualKeyCodeNameTriplet const *codes[0xff];
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // initialize all entries to the empty triplet
        memset_pattern8(codes, &OEEmptyTriplet, sizeof(codes));
        
        for (int i = 0; i < _OEHIDVirtualKeyCodesTableLen; i++)
        {
            __auto_type entry = &_OEHIDVirtualKeyCodesTable[i];
            NSCAssert(entry->hidCode <= 0xff, @"Should be less than length of codes array");
            codes[entry->hidCode] = entry;
        }
    });
    
    return ch <= 0xFF ? codes[ch] : &OEEmptyTriplet;
}

static _OEHIDVirtualKeyCodeNameTriplet const * OECGKeyCodeToTriplet(CGKeyCode ch)
{
    static _OEHIDVirtualKeyCodeNameTriplet const *codes[0xff];
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // initialize all entries to the empty triplet
        memset_pattern8(codes, &OEEmptyTriplet, sizeof(codes));
        
        for (int i = 0; i < _OEHIDVirtualKeyCodesTableLen; i++)
        {
            __auto_type entry = &_OEHIDVirtualKeyCodesTable[i];
            if (entry->vkCode == 0xFFFF) continue;
            
            NSCAssert(entry->vkCode <= 0xff, @"Should be less than length of codes array");
            codes[entry->vkCode] = entry;
        }
    });
    
    return ch <= 0xFF ? codes[ch] : &OEEmptyTriplet;
}

const NSEventModifierFlags OENSEventModifierFlagFunctionKey = 1 << 24;

static OEHIDEventType _OEHIDEventTypeFromIOHIDElementPageUsage(IOHIDElementRef elem, uint64_t page, uint64_t usage);

static BOOL _OEHIDElementIsTrigger(IOHIDElementRef elem)
{
    return [(__bridge NSNumber *)IOHIDElementGetProperty(elem, CFSTR(kOEHIDElementIsTriggerKey)) boolValue];
}

static OEHIDEventHatSwitchType _OEHIDElementHatSwitchType(IOHIDElementRef elem)
{
    return [(__bridge NSNumber *)IOHIDElementGetProperty(elem, CFSTR(kOEHIDElementHatSwitchTypeKey)) integerValue];
}

OEHIDEventHatDirection OEHIDEventHatDirectionFromNSString(NSString *string)
{
    static NSDictionary *allDirections = nil;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        allDirections = @{
        @"N"  : @(OEHIDEventHatDirectionNorth),
        @"NE" : @(OEHIDEventHatDirectionNorthEast),
        @"E"  : @(OEHIDEventHatDirectionEast),
        @"SE" : @(OEHIDEventHatDirectionSouthEast),
        @"S"  : @(OEHIDEventHatDirectionSouth),
        @"SW" : @(OEHIDEventHatDirectionSouthWest),
        @"W"  : @(OEHIDEventHatDirectionWest),
        @"NW" : @(OEHIDEventHatDirectionNorthWest)
        };
    });

    return [[allDirections objectForKey:string] integerValue];
}

NSString *NSStringFromOEHIDHatDirection(OEHIDEventHatDirection dir)
{
    NSString *ret = @"Null";

    switch(dir)
    {
        case OEHIDEventHatDirectionNorth     : ret = @"N";  break;
        case OEHIDEventHatDirectionNorthEast : ret = @"NE"; break;
        case OEHIDEventHatDirectionEast      : ret = @"E";  break;
        case OEHIDEventHatDirectionSouthEast : ret = @"SE"; break;
        case OEHIDEventHatDirectionSouth     : ret = @"S";  break;
        case OEHIDEventHatDirectionSouthWest : ret = @"SW"; break;
        case OEHIDEventHatDirectionWest      : ret = @"W";  break;
        case OEHIDEventHatDirectionNorthWest : ret = @"NW"; break;
        default : break;
    }

    return ret;
}

NSString *NSLocalizedStringFromOEHIDHatDirection(OEHIDEventHatDirection dir)
{
    NSString *ret = @"Null";

    switch(dir)
    {
        case OEHIDEventHatDirectionNorth     : ret = NSLocalizedString(@"North"     , @"Hat Switch North Direction");      break;
        case OEHIDEventHatDirectionNorthEast : ret = NSLocalizedString(@"North-East", @"Hat Switch North-East Direction"); break;
        case OEHIDEventHatDirectionEast      : ret = NSLocalizedString(@"East"      , @"Hat Switch East Direction");       break;
        case OEHIDEventHatDirectionSouthEast : ret = NSLocalizedString(@"South-East", @"Hat Switch South-East Direction"); break;
        case OEHIDEventHatDirectionSouth     : ret = NSLocalizedString(@"South"     , @"Hat Switch South Direction");      break;
        case OEHIDEventHatDirectionSouthWest : ret = NSLocalizedString(@"South-West", @"Hat Switch South-West Direction"); break;
        case OEHIDEventHatDirectionWest      : ret = NSLocalizedString(@"West"      , @"Hat Switch West Direction");       break;
        case OEHIDEventHatDirectionNorthWest : ret = NSLocalizedString(@"North-West", @"Hat Switch North-West Direction"); break;
        default : break;
    }

    return ret;
}

NSString *NSStringFromOEHIDEventType(OEHIDEventType type)
{
    switch(type)
    {
        case OEHIDEventTypeAxis      : return @"OEHIDEventTypeAxis";
        case OEHIDEventTypeTrigger   : return @"OEHIDEventTypeTrigger";
        case OEHIDEventTypeButton    : return @"OEHIDEventTypeButton";
        case OEHIDEventTypeHatSwitch : return @"OEHIDEventTypeHatSwitch";
        case OEHIDEventTypeKeyboard  : return @"OEHIDEventTypeKeyboard";
    }

    return @"<unknown>";
}

OEHIDEventAxis OEHIDEventAxisFromNSString(NSString *string)
{
    static NSDictionary *keyTypes = nil;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keyTypes = @{
        @"X" : @(OEHIDEventAxisX),
        @"Y" : @(OEHIDEventAxisY),
        @"Z" : @(OEHIDEventAxisZ),
        @"Rx" : @(OEHIDEventAxisRx),
        @"Ry" : @(OEHIDEventAxisRy),
        @"Rz" : @(OEHIDEventAxisRz),
        @"Accelerator" : @(OEHIDEventAxisAccelerator),
        @"Brake" : @(OEHIDEventAxisBrake),
        };
    });

    return [[keyTypes objectForKey:string] integerValue];
}

NSString *NSStringFromOEHIDEventAxis(OEHIDEventAxis axis)
{
    NSString *ret = nil;
    // Example: ret = @"P1 -X" for Pad One X axis Negative
    switch(axis)
    {
        case OEHIDEventAxisX  : ret = @"X";  break;
        case OEHIDEventAxisY  : ret = @"Y";  break;
        case OEHIDEventAxisZ  : ret = @"Z";  break;
        case OEHIDEventAxisRx : ret = @"Rx"; break;
        case OEHIDEventAxisRy : ret = @"Ry"; break;
        case OEHIDEventAxisRz : ret = @"Rz"; break;
        case OEHIDEventAxisAccelerator : ret = @"Accelerator"; break;
        case OEHIDEventAxisBrake : ret = @"Brake"; break;
        default : break;
    }

    return ret;
}

NSString *OEHIDEventAxisDisplayDescription(OEHIDEventAxis axis, OEHIDEventAxisDirection direction)
{
    // Example: ret = @"P1 -X" for Pad One X axis Negative
    NSString *ret = NSStringFromOEHIDEventAxis(axis);

    char sign = (direction == OEHIDEventAxisDirectionNull     ? '=' :
                 direction == OEHIDEventAxisDirectionPositive ? '+' :
                 direction == OEHIDEventAxisDirectionNegative ? '-' : '?');

    return ret != nil ? [NSString stringWithFormat:@"%@%c", ret, sign] : @"";
}

NSString *NSStringFromIOHIDElement(IOHIDElementRef elem)
{
    const uint32_t usage = IOHIDElementGetUsage(elem);

    NSString *string = nil;

    switch(OEHIDEventTypeFromIOHIDElement(elem))
    {
        case OEHIDEventTypeAxis :
            string = [NSString stringWithFormat:@"Axis: %@, min: %ld, max: %ld", NSStringFromOEHIDEventAxis(usage), IOHIDElementGetLogicalMin(elem), IOHIDElementGetLogicalMax(elem)];
            break;
        case OEHIDEventTypeButton :
            string = [NSString stringWithFormat:@"Button: %d", usage];
            break;
        case OEHIDEventTypeHatSwitch :
        {
            NSInteger min = IOHIDElementGetLogicalMin(elem);
            NSInteger max = IOHIDElementGetLogicalMax(elem);
            NSString *type = @"Unknown";

            switch (_OEHIDElementHatSwitchType(elem))
            {
                case OEHIDEventHatSwitchType4Ways : type = @"Four Ways"; break;
                case OEHIDEventHatSwitchType8Ways : type = @"Eight Ways"; break;
                default:
                    break;
            }

            string = [NSString stringWithFormat:@"HatSwitch: %@ min: %ld max: %ld", type, min, max];
        }
            break;
        case OEHIDEventTypeKeyboard :
            if((((usage >= 0x04) && (usage <= 0xA4)) ||
                ((usage >= 0xE0) && (usage <= 0xE7))))
                string = [NSString stringWithFormat:@"Keyboard: %x", usage];
            break;
        case OEHIDEventTypeTrigger :
            string = [NSString stringWithFormat:@"Trigger: %@, max: %ld", NSStringFromOEHIDEventAxis(usage), IOHIDElementGetLogicalMax(elem)];
            break;
        default :
            break;
    }

    return string;
}

OEHIDEventType OEHIDEventTypeFromIOHIDElement(IOHIDElementRef elem)
{
    const uint64_t page = IOHIDElementGetUsagePage(elem);
    const uint64_t usage = IOHIDElementGetUsage(elem);

    return _OEHIDEventTypeFromIOHIDElementPageUsage(elem, page, usage);
}

BOOL OEIOHIDElementIsTrigger(IOHIDElementRef elem)
{
    const uint64_t page = IOHIDElementGetUsagePage(elem);
    if (page != kHIDPage_Simulation)
        return NO;

    const uint64_t usage = IOHIDElementGetUsage(elem);
    if (usage != kHIDUsage_Sim_Accelerator && usage != kHIDUsage_Sim_Brake)
        return NO;

    return (IOHIDElementGetLogicalMax(elem) - IOHIDElementGetLogicalMin(elem)) > 1;
}

static OEHIDEventType _OEHIDEventTypeFromIOHIDElementPageUsage(IOHIDElementRef elem, uint64_t page, uint64_t usage)
{
    switch(page)
    {
        case kHIDPage_GenericDesktop :
        {
            switch(usage)
            {
                case kHIDUsage_GD_X  :
                case kHIDUsage_GD_Y  :
                case kHIDUsage_GD_Z  :
                case kHIDUsage_GD_Rx :
                case kHIDUsage_GD_Ry :
                case kHIDUsage_GD_Rz :
                    if(_OEHIDElementIsTrigger(elem))
                        return OEHIDEventTypeTrigger;
                    else
                        return OEHIDEventTypeAxis;
                    break;
                case kHIDUsage_GD_Hatswitch :
                    return OEHIDEventTypeHatSwitch;
                case kHIDUsage_GD_DPadUp    :
                case kHIDUsage_GD_DPadDown  :
                case kHIDUsage_GD_DPadLeft  :
                case kHIDUsage_GD_DPadRight :
                case kHIDUsage_GD_Start     :
                case kHIDUsage_GD_Select    :
                case kHIDUsage_GD_SystemMainMenu :
                    return OEHIDEventTypeButton;
            }
            break;
        }
        case kHIDPage_Simulation :
            if(_OEHIDElementIsTrigger(elem))
                return OEHIDEventTypeTrigger;

            return OEHIDEventTypeButton;
        case kHIDPage_Consumer :
        case kHIDPage_VR :
        case kHIDPage_Sport :
        case kHIDPage_Game :
        case kHIDPage_Button :
            return OEHIDEventTypeButton;
        case kHIDPage_KeyboardOrKeypad :
        case 0xFF :
            return OEHIDEventTypeKeyboard;
    }
    
    return 0;
}

static inline CGFloat _OEScaledValueForTrigger(NSInteger value, NSInteger maximum)
{
    return OE_CLAMP(0, value, maximum) / (CGFloat)maximum;
}

static inline BOOL _OEFloatEqual(CGFloat v1, CGFloat v2)
{
    return fabs(v1 - v2) < DBL_EPSILON;
}

@interface OEHIDEvent ()
{
    __weak OEDeviceHandler *_deviceHandler;
    OEHIDEventType          _type;
    NSTimeInterval          _timestamp;
    NSUInteger              _cookie;
    CGEventRef              _keyboardEvent;
    NSEvent                *_cachedKeyboardEvent;

    union {
        // Axis and Trigger events share the same structure.
        struct {
            OEHIDEventAxis          axis;
            OEHIDEventAxisDirection direction;
            CGFloat                 value;
        } axis;
        struct {
            NSUInteger              buttonNumber;
            OEHIDEventState         state;
        } button;
        struct {
            OEHIDEventHatSwitchType hatSwitchType;
            OEHIDEventHatDirection  hatDirection;
        } hatSwitch;
        struct {
            NSUInteger              keycode;
            OEHIDEventState         state;
            BOOL                    isFunctionKeyPressed;
        } key;
    } _data;
}

- (id)initWithDeviceHandler:(OEDeviceHandler *)aDeviceHandler value:(IOHIDValueRef)aValue;
- (id)initWithDeviceHandler:(OEDeviceHandler *)aDeviceHandler timestamp:(NSTimeInterval)timestamp cookie:(NSUInteger)cookie;

- (BOOL)OE_setupEventWithDeviceHandler:(OEDeviceHandler *)aDeviceHandler value:(IOHIDValueRef)aValue;
- (OEHIDEvent *)OE_eventWithDeviceHandler:(OEDeviceHandler *)aDeviceHandler;

+ (instancetype)OE_eventWithElement:(IOHIDElementRef)element value:(NSInteger)value;

@end

@implementation OEHIDEvent

static CGEventSourceRef _keyboardEventSource;

+ (void)initialize
{
    if (self != [OEHIDEvent class])
        return;

    _keyboardEventSource = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (NSUInteger)keyCodeForVirtualKey:(CGCharCode)charCode
{
    return OECGKeyCodeToTriplet(charCode)->hidCode;
}

+ (NSString *)stringForHIDKeyCode:(NSUInteger)hidCode
{
    _OEHIDVirtualKeyCodeNameTriplet const *entry = OEHIDUsageToTriplet(hidCode);
    if (entry->string != nil)
        return entry->string;
    CGKeyCode keyCode = entry->vkCode;

    TISInputSourceRef currentKeyboard = TISCopyCurrentKeyboardInputSource();
    CFDataRef uchr = (CFDataRef)TISGetInputSourceProperty(currentKeyboard, kTISPropertyUnicodeKeyLayoutData);
    if(currentKeyboard != nil) CFRelease(currentKeyboard);

    // For non-unicode layouts such as Chinese, Japanese, and Korean, get the ASCII capable layout
    if(uchr == nil)
    {
        currentKeyboard = TISCopyCurrentASCIICapableKeyboardLayoutInputSource();
        uchr = (CFDataRef)TISGetInputSourceProperty(currentKeyboard, kTISPropertyUnicodeKeyLayoutData);
        if(currentKeyboard != nil) CFRelease(currentKeyboard);
    }

    const UCKeyboardLayout *keyboardLayout = (const UCKeyboardLayout *)CFDataGetBytePtr(uchr);

    if(keyboardLayout)
    {
        UInt32 deadKeyState = 0;
        UniCharCount maxStringLength = 255;
        UniCharCount actualStringLength = 0;
        UniChar unicodeString[maxStringLength];

        OSStatus status = UCKeyTranslate(keyboardLayout,
                                         keyCode, kUCKeyActionDisplay, 0,
                                         LMGetKbdType(), 0,
                                         &deadKeyState,
                                         maxStringLength,
                                         &actualStringLength, unicodeString);


        if(actualStringLength > 0 && status == noErr)
        {
            NSString *lowercaseString = [NSString stringWithCharacters:unicodeString length:(NSUInteger)actualStringLength];
            if (![lowercaseString isEqualToString:[[lowercaseString uppercaseString] lowercaseString]])
                return lowercaseString;
            return [lowercaseString uppercaseString];
        }
    }

    return [NSString stringWithFormat:NSLocalizedString(@"Keycode 0x%lX", @"Fallback for unknown keys"), hidCode];
}

- (NSString *)displayDescription
{
    switch(_type)
    {
        case OEHIDEventTypeAxis :
            return OEHIDEventAxisDisplayDescription(_data.axis.axis, _data.axis.direction);
        case OEHIDEventTypeTrigger :
            return [NSString stringWithFormat:NSLocalizedString(@"Trigger %@", @"Trigger key name with axis string."), NSStringFromOEHIDEventAxis(_data.axis.axis)];
        case OEHIDEventTypeHatSwitch :
            return NSLocalizedStringFromOEHIDHatDirection(_data.hatSwitch.hatDirection);
        case OEHIDEventTypeButton :
            switch(_data.button.buttonNumber)
            {
                case kHIDUsage_GD_DPadUp :
                    return [NSString stringWithFormat:NSLocalizedString(@"D-pad Up", @"Generic D-pad Up.")];
                case kHIDUsage_GD_DPadDown :
                    return [NSString stringWithFormat:NSLocalizedString(@"D-pad Down", @"Generic D-pad Down.")];
                case kHIDUsage_GD_DPadLeft :
                    return [NSString stringWithFormat:NSLocalizedString(@"D-pad Left", @"Generic D-pad Left.")];
                case kHIDUsage_GD_DPadRight :
                    return [NSString stringWithFormat:NSLocalizedString(@"D-pad Right", @"Generic D-pad Right.")];
                case kHIDUsage_GD_Start :
                    return [NSString stringWithFormat:NSLocalizedString(@"Start", @"Generic button Start.")];
                case kHIDUsage_GD_Select :
                    return [NSString stringWithFormat:NSLocalizedString(@"Select", @"Generic button Select.")];
                case kHIDUsage_GD_SystemMainMenu :
                    return [NSString stringWithFormat:NSLocalizedString(@"System Main Menu", @"Generic button System Main Menu.")];
            }
            // Example: ret = @"P1 B12" for Pad One Button 12
            return [NSString stringWithFormat:NSLocalizedString(@"Button %ld", @"Button key name with button number.") , _data.button.buttonNumber];
            break;
        case OEHIDEventTypeKeyboard :
            return [OEHIDEvent stringForHIDKeyCode:_data.key.keycode];
    }

    return @"";
}

- (id)init
{
    return nil;
}

- (id)initWithDeviceHandler:(OEDeviceHandler *)aDeviceHandler timestamp:(NSTimeInterval)timestamp cookie:(NSUInteger)cookie;
{
    if((self = [super init]))
    {
        _deviceHandler = aDeviceHandler;
        _timestamp     = timestamp;
        _cookie        = cookie;
    }
    return self;
}

+ (id)axisEventWithDeviceHandler:(OEDeviceHandler *)aDeviceHandler timestamp:(NSTimeInterval)timestamp axis:(OEHIDEventAxis)axis direction:(OEHIDEventAxisDirection)direction cookie:(NSUInteger)cookie;
{
    OEHIDEvent *ret = [[self alloc] initWithDeviceHandler:aDeviceHandler timestamp:timestamp cookie:cookie];
    ret->_type = OEHIDEventTypeAxis;
    ret->_data.axis.axis = axis;

    ret->_data.axis.direction = MIN(OEHIDEventAxisDirectionPositive, MAX(direction, OEHIDEventAxisDirectionNegative));
    ret->_data.axis.value     = ret->_data.axis.direction;

    return ret;
}

+ (id)axisEventWithDeviceHandler:(OEDeviceHandler *)aDeviceHandler timestamp:(NSTimeInterval)timestamp axis:(OEHIDEventAxis)axis value:(CGFloat)value cookie:(NSUInteger)cookie;
{
    OEHIDEvent *ret = [[self alloc] initWithDeviceHandler:aDeviceHandler timestamp:timestamp cookie:cookie];
    ret->_type = OEHIDEventTypeAxis;
    ret->_data.axis.axis = axis;

    value = OE_CLAMP(-1.0, value, 1.0);

    if(_OEFloatEqual(value, 0)) ret->_data.axis.direction = OEHIDEventAxisDirectionNull;
    else if(signbit(value))     ret->_data.axis.direction = OEHIDEventAxisDirectionNegative;
    else                        ret->_data.axis.direction = OEHIDEventAxisDirectionPositive;

    ret->_data.axis.value = value;

    return ret;
}

+ (id)axisEventWithDeviceHandler:(OEDeviceHandler *)aDeviceHandler timestamp:(NSTimeInterval)timestamp axis:(OEHIDEventAxis)axis minimum:(NSInteger)minimum value:(NSInteger)value maximum:(NSInteger)maximum cookie:(NSUInteger)cookie;
{
    OEHIDEvent *ret = [[self alloc] initWithDeviceHandler:aDeviceHandler timestamp:timestamp cookie:cookie];
    ret->_type = OEHIDEventTypeAxis;
    ret->_data.axis.axis = axis;
    ret->_data.axis.value = OEScaledValueWithCalibration(OEAxisCalibrationMake(minimum, maximum), value);

    if(_OEFloatEqual(ret->_data.axis.value, 0)) ret->_data.axis.direction = OEHIDEventAxisDirectionNull;
    else if(signbit(ret->_data.axis.value))     ret->_data.axis.direction = OEHIDEventAxisDirectionNegative;
    else                                        ret->_data.axis.direction = OEHIDEventAxisDirectionPositive;

    return ret;
}

+ (id)triggerEventWithDeviceHandler:(OEDeviceHandler *)aDeviceHandler timestamp:(NSTimeInterval)timestamp axis:(OEHIDEventAxis)axis direction:(OEHIDEventAxisDirection)direction cookie:(NSUInteger)cookie;
{
    OEHIDEvent *ret = [[self alloc] initWithDeviceHandler:aDeviceHandler timestamp:timestamp cookie:cookie];
    ret->_type = OEHIDEventTypeTrigger;
    ret->_data.axis.axis = axis;

    ret->_data.axis.direction = !!direction;
    ret->_data.axis.value     = ret->_data.axis.direction;

    return ret;
}

+ (id)triggerEventWithDeviceHandler:(OEDeviceHandler *)aDeviceHandler timestamp:(NSTimeInterval)timestamp axis:(OEHIDEventAxis)axis value:(NSInteger)value maximum:(NSInteger)maximum cookie:(NSUInteger)cookie;
{
    OEHIDEvent *ret = [[self alloc] initWithDeviceHandler:aDeviceHandler timestamp:timestamp cookie:cookie];
    ret->_type = OEHIDEventTypeTrigger;
    ret->_data.axis.axis = axis;
    ret->_data.axis.value = _OEScaledValueForTrigger(value, maximum);

    ret->_data.axis.direction = _OEFloatEqual(ret->_data.axis.value, 0.0) ? OEHIDEventAxisDirectionNull : OEHIDEventAxisDirectionPositive;

    return ret;
}

+ (instancetype)triggerEventWithDeviceHandler:(OEDeviceHandler *)aDeviceHandler timestamp:(NSTimeInterval)timestamp axis:(OEHIDEventAxis)axis value:(CGFloat)value cookie:(NSUInteger)cookie;
{
    OEHIDEvent *ret = [[self alloc] initWithDeviceHandler:aDeviceHandler timestamp:timestamp cookie:cookie];
    ret->_type = OEHIDEventTypeTrigger;
    ret->_data.axis.axis = axis;

    value = OE_CLAMP(0.0, value, 1.0);
    ret->_data.axis.direction = _OEFloatEqual(ret->_data.axis.value, 0.0) ? OEHIDEventAxisDirectionNull : OEHIDEventAxisDirectionPositive;
    ret->_data.axis.value     = value;

    return ret;
}

+ (id)buttonEventWithDeviceHandler:(OEDeviceHandler *)aDeviceHandler timestamp:(NSTimeInterval)timestamp buttonNumber:(NSUInteger)number state:(OEHIDEventState)state cookie:(NSUInteger)cookie;
{
    OEHIDEvent *ret = [[self alloc] initWithDeviceHandler:aDeviceHandler timestamp:timestamp cookie:cookie];
    ret->_type = OEHIDEventTypeButton;
    ret->_data.button.buttonNumber = number;
    ret->_data.button.state = state;

    return ret;
}

+ (id)hatSwitchEventWithDeviceHandler:(OEDeviceHandler *)aDeviceHandler timestamp:(NSTimeInterval)timestamp type:(OEHIDEventHatSwitchType)hatSwitchType direction:(OEHIDEventHatDirection)aDirection cookie:(NSUInteger)cookie;
{
    OEHIDEvent *ret = [[self alloc] initWithDeviceHandler:aDeviceHandler timestamp:timestamp cookie:cookie];
    ret->_type = OEHIDEventTypeHatSwitch;
    ret->_data.hatSwitch.hatSwitchType = hatSwitchType;
    ret->_data.hatSwitch.hatDirection  = aDirection;

    return ret;
}

+ (id)keyEventWithTimestamp:(NSTimeInterval)timestamp keyCode:(NSUInteger)keyCode state:(OEHIDEventState)state cookie:(NSUInteger)cookie
{
    OEHIDEvent *ret = [[self alloc] initWithDeviceHandler:nil timestamp:timestamp cookie:cookie];
    ret->_type = OEHIDEventTypeKeyboard;
    ret->_cookie = OEUndefinedCookie;
    ret->_data.key.keycode = keyCode;
    ret->_data.key.state = state;
    CGKeyCode vk = OEHIDUsageToTriplet(keyCode)->vkCode;
    ret->_keyboardEvent = CGEventCreateKeyboardEvent(_keyboardEventSource, vk, state);

    return ret;
}

+ (id)eventWithDeviceHandler:(OEDeviceHandler *)aDeviceHandler value:(IOHIDValueRef)aValue
{
    return [[self alloc] initWithDeviceHandler:aDeviceHandler value:aValue];
}

+ (instancetype)OE_eventWithElement:(IOHIDElementRef)element value:(NSInteger)value;
{
    return [[self alloc] initWithElement:element value:value];
}

- (id)initWithElement:(IOHIDElementRef)element value:(NSInteger)value;
{
    if((self = [self initWithDeviceHandler:nil timestamp:0.0 cookie:OEUndefinedCookie]))
    {
        if(![self OE_setupEventWithElement:element])
            return nil;

        switch(_type)
        {
            case OEHIDEventTypeAxis :
                _data.axis.direction = value;
                break;
            case OEHIDEventTypeButton :
                _data.button.state = OEHIDEventStateOn;
                break;
            case OEHIDEventTypeHatSwitch :
                _data.hatSwitch.hatDirection = value;
                break;
            case OEHIDEventTypeKeyboard :
                _data.key.state = OEHIDEventStateOn;
                break;
            case OEHIDEventTypeTrigger :
                _data.axis.direction = OEHIDEventAxisDirectionPositive;
                break;
            default:
                break;
        }
    }

    return self;
}

- (id)initWithDeviceHandler:(OEDeviceHandler *)aDeviceHandler value:(IOHIDValueRef)aValue
{
    self = [self initWithDeviceHandler:aDeviceHandler timestamp:IOHIDValueGetTimeStamp(aValue) / 1e9 cookie:OEUndefinedCookie];
    if(self != nil)
    {
        if(![self OE_setupEventWithDeviceHandler:aDeviceHandler value:aValue])
            return nil;
    }

    return self;
}

- (void)dealloc
{
    if (_keyboardEvent)
        CFRelease(_keyboardEvent);
}

- (id)copyWithZone:(NSZone *)zone
{
    OEHIDEvent *ret = [[OEHIDEvent alloc] initWithDeviceHandler:_deviceHandler timestamp:[self timestamp] cookie:_cookie];

    ret->_type = _type;
    ret->_data = _data;

    return ret;
}

- (BOOL)OE_setupEventWithElement:(IOHIDElementRef)anElement;
{
    const uint64_t page = IOHIDElementGetUsagePage(anElement);
    const uint64_t usage = IOHIDElementGetUsage(anElement);

    _cookie = (uint32_t)IOHIDElementGetCookie(anElement);
    _type = _OEHIDEventTypeFromIOHIDElementPageUsage(anElement, page, usage);

    if([self OE_elementRepresentsMouseEvent:anElement]) {
        return NO;
    }
    
    switch(_type)
    {
        case OEHIDEventTypeAxis :
        case OEHIDEventTypeTrigger :
            _data.axis.axis = usage;
            return YES;
        case OEHIDEventTypeHatSwitch :
            _data.hatSwitch.hatSwitchType = _OEHIDElementHatSwitchType(anElement);
            return _data.hatSwitch.hatSwitchType != OEHIDEventHatSwitchTypeUnknown;
        case OEHIDEventTypeButton :
            _data.button.buttonNumber = usage;
            return YES;
        case OEHIDEventTypeKeyboard :
            _cookie = OEUndefinedCookie;
            _deviceHandler = nil;

            if (page == 0xFF && usage == 0x03) {
                _data.key.keycode = OEHIDUsage_KeyboardFunctionKey;
                return YES;
            } else if (((usage >= 0x04 && usage <= 0xA4) || (usage >= 0xE0 && usage <= 0xE8))) {
                _data.key.keycode = usage;
                return YES;
            }
    }

    return NO;
}

- (BOOL)OE_elementRepresentsMouseEvent:(IOHIDElementRef)anElement
{
    OEDeviceHandler *dhandler = _deviceHandler;
    NSMutableDictionary <NSNumber *, NSNumber *> *cache;
    NSNumber *objkey;
    if (dhandler) {
        cache = objc_getAssociatedObject(dhandler, _cmd);
        if (!cache) {
            cache = [[NSMutableDictionary alloc] init];
            objc_setAssociatedObject(dhandler, _cmd, cache, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        
        objkey = @(IOHIDElementGetCookie(anElement));
        NSNumber *cached = cache[objkey];
        if (cached)
            return cached.boolValue;
    }
    
    for(IOHIDElementRef element = anElement; element != NULL; element = IOHIDElementGetParent(element)) {
        uint32_t usagePage = IOHIDElementGetUsagePage(element);
        uint32_t usage = IOHIDElementGetUsage(element);
        
        if(usagePage == kHIDPage_GenericDesktop && usage == kHIDUsage_GD_Mouse) {
            if (objkey && cache) cache[objkey] = @(YES);
            return YES;
        }
    }
    
    if (objkey && cache) cache[objkey] = @(NO);
    return NO;
}

- (BOOL)OE_setupEventWithDeviceHandler:(OEDeviceHandler *)aDeviceHandler value:(IOHIDValueRef)aValue;
{
    NSAssert(_deviceHandler == aDeviceHandler, @"Trying to setup an event with a different device handler, expected: %@, got: %@", _deviceHandler, aDeviceHandler);

    IOHIDElementRef elem = IOHIDValueGetElement(aValue);
    if(![self OE_setupEventWithElement:elem])
        return NO;

    if(IOHIDValueGetLength(aValue) == 0 ||
       IOHIDValueGetLength(aValue) >  8)
        return NO;

    _timestamp    = IOHIDValueGetTimeStamp(aValue) / 1e9;

    CFIndex value = IOHIDValueGetIntegerValue(aValue);

    switch(_type)
    {
        case OEHIDEventTypeAxis :
        {
            NSInteger min = IOHIDElementGetLogicalMin(elem);
            NSInteger max = IOHIDElementGetLogicalMax(elem);
            CGFloat scaledValue = [aDeviceHandler calibratedValue:value forAxis:_data.axis.axis controlCookie:_cookie defaultCalibration:OEAxisCalibrationMake(min, max)];

            _data.axis.value = scaledValue;
            if(_OEFloatEqual(scaledValue, 0.0)) _data.axis.direction = OEHIDEventAxisDirectionNull;
            else if(signbit(scaledValue))       _data.axis.direction = OEHIDEventAxisDirectionNegative;
            else                                _data.axis.direction = OEHIDEventAxisDirectionPositive;
        }
            break;
        case OEHIDEventTypeTrigger :
        {
            CGFloat deadZone = [aDeviceHandler deadZoneForControlCookie:_cookie];
            CGFloat scaledValue = _OEScaledValueForTrigger(value, IOHIDElementGetLogicalMax(elem));

            if(scaledValue <= deadZone) scaledValue = 0.0;

            _data.axis.value     = scaledValue;
            _data.axis.direction = (_OEFloatEqual(scaledValue, 0.0) ? OEHIDEventAxisDirectionNull : OEHIDEventAxisDirectionPositive);
        }
            break;
        case OEHIDEventTypeHatSwitch :
        {
            NSInteger min = IOHIDElementGetLogicalMin(elem);
            NSInteger max = IOHIDElementGetLogicalMax(elem);

            // value is outside of the logical range, it's therefore NULL
            if(value < min || max < value) _data.hatSwitch.hatDirection = OEHIDEventHatDirectionNull;
            else
            {
                value -= min;

                if(_data.hatSwitch.hatSwitchType == OEHIDEventHatSwitchType4Ways)
                    value *= 2;

                OEHIDEventHatDirection dir = OEHIDEventHatDirectionNull;
                switch(value)
                {
                    case 0 : dir = OEHIDEventHatDirectionNorth;     break;
                    case 1 : dir = OEHIDEventHatDirectionNorthEast; break;
                    case 2 : dir = OEHIDEventHatDirectionEast;      break;
                    case 3 : dir = OEHIDEventHatDirectionSouthEast; break;
                    case 4 : dir = OEHIDEventHatDirectionSouth;     break;
                    case 5 : dir = OEHIDEventHatDirectionSouthWest; break;
                    case 6 : dir = OEHIDEventHatDirectionWest;      break;
                    case 7 : dir = OEHIDEventHatDirectionNorthWest; break;
                }

                _data.hatSwitch.hatDirection = dir;
            }
        }
            break;
        case OEHIDEventTypeButton :
            _data.button.state = !!value;
            break;
        case OEHIDEventTypeKeyboard :
            _data.key.state = !!value;
            _data.key.isFunctionKeyPressed = aDeviceHandler.isFunctionKeyPressed;
            _keyboardEvent = CGEventCreateKeyboardEvent(_keyboardEventSource, OEHIDUsageToTriplet(_data.key.keycode)->vkCode, _data.key.state);
            break;
    }

    return YES;
}

- (BOOL)hasDeviceHandlerPlaceholder
{
    return _deviceHandler.isPlaceholder;
}

- (void)resolveDeviceHandlerPlaceholder
{
    NSAssert(self.hasDeviceHandlerPlaceholder, @"Attempting to resolve non-placeholder device handler.");

    _deviceHandler = [[OEDeviceManager sharedDeviceManager] deviceHandlerForUniqueIdentifier:_deviceHandler.uniqueIdentifier];

    NSAssert(_deviceHandler && !self.hasDeviceHandlerPlaceholder, @"Attempting to resolve device that is not yet ready.");
}

- (OEHIDEvent *)OE_eventWithDeviceHandler:(OEDeviceHandler *)aDeviceHandler;
{
    OEHIDEvent *ret = [self copy];

    ret->_deviceHandler = aDeviceHandler;

    return ret;
}

- (NSUInteger)usage
{
    switch([self type])
    {
        case OEHIDEventTypeAxis      :
        case OEHIDEventTypeTrigger   : return [self axis];
        case OEHIDEventTypeHatSwitch : return kHIDUsage_GD_Hatswitch;
        case OEHIDEventTypeButton    : return [self buttonNumber];
        case OEHIDEventTypeKeyboard  : return [self keycode];
    }

    return 0;
}

- (BOOL)hasOffState
{
    BOOL ret = YES;
    switch([self type])
    {
        case OEHIDEventTypeAxis      :
        case OEHIDEventTypeTrigger   : ret = [self direction]    == OEHIDEventAxisDirectionNull; break;
        case OEHIDEventTypeHatSwitch : ret = [self hatDirection] == OEHIDEventHatDirectionNull;  break;
        case OEHIDEventTypeButton    :
        case OEHIDEventTypeKeyboard  : ret = [self state]        == OEHIDEventStateOff;          break;
        default : break;
    }

    return ret;
}

- (OEHIDEventAxis)axis
{
    OEHIDEventType type = [self type];
    NSAssert1(type == OEHIDEventTypeAxis || type == OEHIDEventTypeTrigger, @"Invalid message sent to event \"%@\"", self);
    return _data.axis.axis;
}

- (OEHIDEventAxisDirection)direction
{
    OEHIDEventType type = [self type];
    NSAssert1(type == OEHIDEventTypeAxis || type == OEHIDEventTypeTrigger, @"Invalid message sent to event \"%@\"", self);
    return _data.axis.direction;
}

- (OEHIDEventAxisDirection)oppositeDirection
{
    NSAssert1([self type] == OEHIDEventTypeAxis, @"Invalid message sent to event \"%@\"", self);

    OEHIDEventAxisDirection ret = _data.axis.direction;

    switch(ret)
    {
        case OEHIDEventAxisDirectionNegative : ret = OEHIDEventAxisDirectionPositive; break;
        case OEHIDEventAxisDirectionPositive : ret = OEHIDEventAxisDirectionNegative; break;
        default : break;
    }

    return ret;
}

- (CGFloat)value
{
    OEHIDEventType type = [self type];
    NSAssert1(type == OEHIDEventTypeAxis || type == OEHIDEventTypeTrigger, @"Invalid message sent to event \"%@\"", self);
    return _data.axis.value;
}

- (CGFloat)absoluteValue
{
    OEHIDEventType type = [self type];
    NSAssert1(type == OEHIDEventTypeAxis || type == OEHIDEventTypeTrigger, @"Invalid message sent to event \"%@\"", self);
    return fabs(_data.axis.value);
}

// Button event
- (NSUInteger)buttonNumber
{
    NSAssert1([self type] == OEHIDEventTypeButton, @"Invalid message sent to event \"%@\"", self);
    return _data.button.buttonNumber;
}

- (OEHIDEventState)state
{
    NSAssert1([self type] == OEHIDEventTypeButton || [self type] == OEHIDEventTypeKeyboard, @"Invalid message sent to event \"%@\"", self);
    return ([self type] == OEHIDEventTypeButton ? _data.button.state : _data.key.state);
}

- (OEHIDEventHatSwitchType)hatSwitchType;
{
    NSAssert1([self type] == OEHIDEventTypeHatSwitch, @"Invalid message sent to event \"%@\"", self);
    return _data.hatSwitch.hatSwitchType;
}

- (OEHIDEventHatDirection)hatDirection;
{
    NSAssert1([self type] == OEHIDEventTypeHatSwitch, @"Invalid message sent to event \"%@\"", self);
    return _data.hatSwitch.hatDirection;
}

- (NSUInteger)keycode
{
    NSAssert1([self type] == OEHIDEventTypeKeyboard, @"Invalid message sent to event \"%@\"", self);
    return _data.key.keycode;
}

- (BOOL)isEscapeKeyEvent
{
    return [self type] == OEHIDEventTypeKeyboard && _data.key.keycode == kHIDUsage_KeyboardEscape;
}

- (NSEvent *)keyboardEvent
{
    NSAssert1([self type] == OEHIDEventTypeKeyboard, @"Invalid message sent to event \"%@\"", self);

    if (_cachedKeyboardEvent == nil)
        _cachedKeyboardEvent = [NSEvent eventWithCGEvent:_keyboardEvent];

    return _cachedKeyboardEvent;
}

- (NSString *)characters
{
    NSEvent *event = [self keyboardEvent];
    return ([event type] == NSEventTypeKeyDown || [event type] == NSEventTypeKeyUp) ? [event characters] : @"";
}

- (NSString *)charactersIgnoringModifiers
{
    NSEvent *event = [self keyboardEvent];
    return ([event type] == NSEventTypeKeyDown || [event type] == NSEventTypeKeyUp) ? [event charactersIgnoringModifiers] : @"";
}

- (NSEventModifierFlags)modifierFlags
{
    NSEventModifierFlags flags = [[self keyboardEvent] modifierFlags];
    if (_data.key.isFunctionKeyPressed)
        flags |= OENSEventModifierFlagFunctionKey;

    return flags;
}

- (NSUInteger)cookie
{
    return _cookie;
}

- (NSString *)description
{
    NSString *subs = @"UNKNOWN TYPE";

#define STATE_STR(state) (state == NSControlStateValueOn ? "On" : "Off")
#define DIT_STR(dir) (dir == OEHIDEventAxisDirectionNegative ? "Neg" : (dir == OEHIDEventAxisDirectionPositive ? "Pos" : "Nul"))

    switch(_type)
    {
        case OEHIDEventTypeAxis :
        case OEHIDEventTypeTrigger :
            subs = [NSString stringWithFormat:@"type=%@ axis=%@ direction=%s value=%f",
                    _type == OEHIDEventTypeAxis ? @"Axis" : @"Trigger",
                    NSStringFromOEHIDEventAxis(_data.axis.axis) ? : @"none",
                    DIT_STR(_data.axis.direction), _data.axis.value];
            break;
        case OEHIDEventTypeButton :
            subs = [NSString stringWithFormat:@"type=Button number=%lld state=%s",
                    (int64_t)_data.button.buttonNumber, STATE_STR(_data.button.state)];
            break;
        case OEHIDEventTypeHatSwitch :
        {
            NSString *subtype = @"Unknown";

            switch(_data.hatSwitch.hatSwitchType)
            {
                case OEHIDEventHatSwitchType4Ways : subtype = @"4-Ways"; break;
                case OEHIDEventHatSwitchType8Ways : subtype = @"8-Ways"; break;
                default : break;
            }

            subs = [NSString stringWithFormat:@"type=HatSwitch type=%@ position=%@", subtype,
                    NSLocalizedStringFromOEHIDHatDirection(_data.hatSwitch.hatDirection)];
        }
            break;
        case OEHIDEventTypeKeyboard :
            subs = [NSString stringWithFormat:@"type=Key number=%lld state=%s",
                    (int64_t)_data.key.keycode, STATE_STR(_data.key.state)];
            break;
        default :
            break;
    }

#undef STATE_STR
#undef DIT_STR

    return [NSString stringWithFormat:@"<%@ %p pad=%p %@ '%@' cookie=%lu>", [self class], self, _deviceHandler, subs, [self displayDescription], _cookie];
}

- (NSUInteger)hash
{
    NSUInteger hash = [_deviceHandler deviceIdentifier] << 24 | _cookie << 32;

    switch([self type])
    {
        case OEHIDEventTypeKeyboard :
            hash  = 0x1000000000000000u; // keyboard events do not care about padNumber
            hash |= [self state] << 16;
            hash |= [self keycode];
            break;
        case OEHIDEventTypeAxis :
        case OEHIDEventTypeTrigger :
            hash |= 0x2000000000000000u;
            hash |= [self axis] << 8;

            OEHIDEventAxisDirection dir = [self direction];
            if(dir != OEHIDEventAxisDirectionNull)
                hash |= (1 << ((dir) > OEHIDEventAxisDirectionNull));
            break;
        case OEHIDEventTypeButton :
            hash |= 0x4000000000000000u;
            hash |= [self state] << 16;
            hash |= [self buttonNumber];
            break;
        case OEHIDEventTypeHatSwitch :
            hash |= 0x8000000000000000u;
            hash |= [self hatDirection];
            break;
        default :
            break;
    }

    return hash;
}

- (BOOL)isEqual:(id)object
{
    if(self == object) return YES;

    if([object isKindOfClass:[OEHIDEvent class]])
        return [self isEqualToEvent:object];

    return NO;
}

- (BOOL)isEqualToEvent:(OEHIDEvent *)anObject;
{
    if(anObject == nil || _type != anObject->_type || _cookie != anObject->_cookie || _deviceHandler != anObject->_deviceHandler)
        return NO;

    switch(_type)
    {
        case OEHIDEventTypeKeyboard :
            return (_data.key.keycode == anObject->_data.key.keycode &&
                    _data.key.state   == anObject->_data.key.state);
        case OEHIDEventTypeAxis :
        case OEHIDEventTypeTrigger :
            return (_data.axis.direction == anObject->_data.axis.direction &&
                    _data.axis.axis      == anObject->_data.axis.axis      &&
                    _OEFloatEqual(_data.axis.value, anObject->_data.axis.value));
        case OEHIDEventTypeButton :
            return (_data.button.buttonNumber == anObject->_data.button.buttonNumber &&
                    _data.button.state        == anObject->_data.button.state);
        case OEHIDEventTypeHatSwitch :
            return _data.hatSwitch.hatDirection == anObject->_data.hatSwitch.hatDirection;
        default :
            break;
    }

    return NO;
}

- (NSUInteger)controlIdentifier
{
    return [[self class] controlIdentifierForType:_type cookie:_cookie usage:[self usage]];
}

- (NSUInteger)controlValueIdentifier
{
    NSInteger value = OEHIDEventStateOn;

    switch(_type)
    {
        case OEHIDEventTypeAxis :
        case OEHIDEventTypeTrigger :
            value = _data.axis.direction;
            break;
        case OEHIDEventTypeHatSwitch :
            value = _data.hatSwitch.hatDirection;
            break;
        default:
            break;
    }

    return [[self class] controlValueIdentifierForType:_type cookie:_cookie usage:[self usage] value:value];
}

+ (NSUInteger)controlIdentifierForType:(OEHIDEventType)type cookie:(NSUInteger)cookie usage:(NSUInteger)usage;
{
    NSUInteger hash = cookie << 32;

    switch(type)
    {
        case OEHIDEventTypeKeyboard :
            hash  = 0x10000000u; // Keyboard events do not care about the cookie.
            hash |= usage;
            break;
        case OEHIDEventTypeAxis :
        case OEHIDEventTypeTrigger :
            hash |= 0x20000000u;
            hash |= OE_CLAMP((NSUInteger)OEHIDEventAxisX, usage, (NSUInteger)OEHIDEventAxisRz);
            break;
        case OEHIDEventTypeButton :
            hash |= 0x40000000u;
            hash |= usage;
            break;
        case OEHIDEventTypeHatSwitch :
            hash |= 0x80000000u;
            break;
    }

    return hash;
}

+ (NSUInteger)controlValueIdentifierForType:(OEHIDEventType)type cookie:(NSUInteger)cookie usage:(NSUInteger)usage value:(NSInteger)value;
{
    NSUInteger hash = cookie << 32;

    switch(type)
    {
        case OEHIDEventTypeKeyboard :
            hash  = 0x1000000000000000u; // keyboard events do not care about padNumber
            hash |= OEHIDEventStateOn << 16;
            hash |= usage;
            break;
        case OEHIDEventTypeAxis :
        case OEHIDEventTypeTrigger :
            hash |= 0x2000000000000000u;
            hash |= OE_CLAMP((NSUInteger)OEHIDEventAxisX, usage, (NSUInteger)OEHIDEventAxisRz) << 8;

            OEHIDEventAxisDirection dir = OE_CLAMP((NSInteger)OEHIDEventAxisDirectionNegative, value, (NSInteger)OEHIDEventAxisDirectionPositive);
            if(dir != OEHIDEventAxisDirectionNull)
                hash |= (1 << ((dir) > OEHIDEventAxisDirectionNull));
            break;
        case OEHIDEventTypeButton :
            hash |= 0x4000000000000000u;
            hash |= OEHIDEventStateOn << 16;
            hash |= MIN(usage, 0xFFFF);
            break;
        case OEHIDEventTypeHatSwitch :
            hash |= 0x8000000000000000u;
            hash |= value & 0xF;
            break;
        default :
            break;
    }

    return hash;
}

- (BOOL)isUsageEqualToEvent:(OEHIDEvent *)anObject;
{
    if(anObject == nil || _type != anObject->_type || _cookie != anObject->_cookie || _deviceHandler != anObject->_deviceHandler)
        return NO;

    switch(_type)
    {
        case OEHIDEventTypeKeyboard :
            return _data.key.keycode == anObject->_data.key.keycode;
        case OEHIDEventTypeAxis :
        case OEHIDEventTypeTrigger :
            return _data.axis.axis == anObject->_data.axis.axis;
        case OEHIDEventTypeButton :
            return _data.button.buttonNumber == anObject->_data.button.buttonNumber;
        case OEHIDEventTypeHatSwitch :
            return YES;
        default :
            break;
    }

    return NO;
}

- (BOOL)isAxisDirectionOppositeToEvent:(OEHIDEvent *)anObject;
{
    if (anObject == nil || _type != OEHIDEventTypeAxis || anObject->_type != OEHIDEventTypeAxis)
        return NO;

    if (_data.axis.direction == anObject->_data.axis.direction)
        return NO;

    if (_data.axis.direction == OEHIDEventAxisDirectionNull || anObject->_data.axis.direction == OEHIDEventAxisDirectionNull)
        return NO;

    return YES;
}

static NSString *OEHIDEventDeviceHandlerKey = @"OEHIDEventDeviceHandler";
static NSString *OEHIDEventTypeKey               = @"OEHIDEventType";
static NSString *OEHIDEventCookieKey             = @"OEHIDEventCookie";
static NSString *OEHIDEventAxisKey               = @"OEHIDEventAxis";
static NSString *OEHIDEventDirectionKey          = @"OEHIDEventDirection";
static NSString *OEHIDEventButtonNumberKey       = @"OEHIDEventButtonNumber";
static NSString *OEHIDEventStateKey              = @"OEHIDEventState";
static NSString *OEHIDEventHatSwitchTypeKey      = @"OEHIDEventHatSwitchType";
static NSString *OEHIDEventHatSwitchDirectionKey = @"OEHIDEventHatSwitchDirection";
static NSString *OEHIDEventKeycodeKey            = @"OEHIDEventKeycode";
static NSString *OEHIDEventIsFunctionPressedKey  = @"OEHIDEventIsFunctionPressedKey";

+ (instancetype)eventWithDictionaryRepresentation:(NSDictionary<NSString *, __kindof id<OEPropertyList>> *)dictionaryRepresentation
{
    NSUInteger cookie = [dictionaryRepresentation[OEHIDEventCookieKey] unsignedIntegerValue];
    OEHIDEvent *ret = [[self alloc] initWithDeviceHandler:nil timestamp:0 cookie:cookie];
    ret->_type = [dictionaryRepresentation[OEHIDEventTypeKey] unsignedIntegerValue];

    switch (ret->_type) {
        case OEHIDEventTypeAxis :
        case OEHIDEventTypeTrigger :
            ret->_data.axis.axis = [dictionaryRepresentation[OEHIDEventAxisKey] unsignedIntegerValue];
            ret->_data.axis.direction = [dictionaryRepresentation[OEHIDEventDirectionKey] integerValue];
            break;
            
        case OEHIDEventTypeButton :
            ret->_data.button.buttonNumber = [dictionaryRepresentation[OEHIDEventButtonNumberKey] unsignedIntegerValue];
            ret->_data.button.state = [dictionaryRepresentation[OEHIDEventStateKey] integerValue];
            break;

        case OEHIDEventTypeHatSwitch :
            ret->_data.hatSwitch.hatSwitchType = [dictionaryRepresentation[OEHIDEventHatSwitchTypeKey] unsignedIntegerValue];
            ret->_data.hatSwitch.hatDirection = [dictionaryRepresentation[OEHIDEventHatSwitchDirectionKey] unsignedIntegerValue];
            break;

        case OEHIDEventTypeKeyboard :
            ret->_cookie = OEUndefinedCookie;
            ret->_data.key.keycode = [dictionaryRepresentation[OEHIDEventKeycodeKey] unsignedIntegerValue];
            ret->_data.key.state = [dictionaryRepresentation[OEHIDEventStateKey] integerValue];
            ret->_data.key.isFunctionKeyPressed = [dictionaryRepresentation[OEHIDEventIsFunctionPressedKey] boolValue];
            break;
    }

    return ret;
}

- (NSDictionary<NSString *, __kindof id<OEPropertyList>> *)dictionaryRepresentation
{
    NSMutableDictionary<NSString *, __kindof id<OEPropertyList>> *representation = [@{
        OEHIDEventTypeKey: @(_type),
        OEHIDEventCookieKey: @(_cookie),
    } mutableCopy];

    switch (_type) {
        case OEHIDEventTypeAxis :
        case OEHIDEventTypeTrigger :
            representation[OEHIDEventAxisKey] = @(self.axis);
            representation[OEHIDEventDirectionKey] = @(self.direction);
            break;
        case OEHIDEventTypeButton :
            representation[OEHIDEventButtonNumberKey] = @(self.buttonNumber);
            representation[OEHIDEventStateKey] = @(self.state);
            break;
        case OEHIDEventTypeHatSwitch :
            representation[OEHIDEventHatSwitchTypeKey] = @(self.hatSwitchType);
            representation[OEHIDEventHatSwitchDirectionKey] = @(self.hatDirection);
            break;
        case OEHIDEventTypeKeyboard :
            representation[OEHIDEventKeycodeKey] = @(self.keycode);
            representation[OEHIDEventStateKey] = @(self.state);
            representation[OEHIDEventIsFunctionPressedKey] = @(_data.key.isFunctionKeyPressed);
            break;
    }

    return representation;
}

- (id)initWithCoder:(NSCoder *)decoder
{
    if((self = [super init]))
    {
        _deviceHandler = [decoder decodeObjectOfClass:[OEDeviceHandler class] forKey:OEHIDEventDeviceHandlerKey];
        _type   = [decoder decodeIntegerForKey:OEHIDEventTypeKey];
        _cookie = [decoder decodeIntegerForKey:OEHIDEventCookieKey];

        switch([self type])
        {
            case OEHIDEventTypeAxis :
            case OEHIDEventTypeTrigger :
                _data.axis.axis               = [decoder decodeIntegerForKey:OEHIDEventAxisKey];
                _data.axis.direction          = [decoder decodeIntegerForKey:OEHIDEventDirectionKey];
                break;
            case OEHIDEventTypeButton :
                _data.button.buttonNumber     = [decoder decodeIntegerForKey:OEHIDEventButtonNumberKey];
                _data.button.state            = [decoder decodeIntegerForKey:OEHIDEventStateKey];
                break;
            case OEHIDEventTypeHatSwitch :
                _data.hatSwitch.hatSwitchType = [decoder decodeIntegerForKey:OEHIDEventHatSwitchTypeKey];
                _data.hatSwitch.hatDirection  = [decoder decodeIntegerForKey:OEHIDEventHatSwitchDirectionKey];
                break;
            case OEHIDEventTypeKeyboard :
                _cookie                       = OEUndefinedCookie;
                _data.key.keycode             = [decoder decodeIntegerForKey:OEHIDEventKeycodeKey];
                _data.key.state               = [decoder decodeIntegerForKey:OEHIDEventStateKey];
                _data.key.isFunctionKeyPressed = [decoder decodeBoolForKey:OEHIDEventIsFunctionPressedKey];
                break;
        }
    }

    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:[self deviceHandler] forKey:OEHIDEventDeviceHandlerKey];
    [encoder encodeInteger:[self type]   forKey:OEHIDEventTypeKey];
    [encoder encodeInteger:[self cookie] forKey:OEHIDEventCookieKey];

    switch([self type])
    {
        case OEHIDEventTypeAxis :
        case OEHIDEventTypeTrigger :
            [encoder encodeInteger:[self axis]          forKey:OEHIDEventAxisKey];
            [encoder encodeInteger:[self direction]     forKey:OEHIDEventDirectionKey];
            break;
        case OEHIDEventTypeButton :
            [encoder encodeInteger:[self buttonNumber]  forKey:OEHIDEventButtonNumberKey];
            [encoder encodeInteger:[self state]         forKey:OEHIDEventStateKey];
            break;
        case OEHIDEventTypeHatSwitch :
            [encoder encodeInteger:[self hatSwitchType] forKey:OEHIDEventHatSwitchTypeKey];
            [encoder encodeInteger:[self hatDirection]  forKey:OEHIDEventHatSwitchDirectionKey];
            break;
        case OEHIDEventTypeKeyboard :
            [encoder encodeInteger:[self keycode]       forKey:OEHIDEventKeycodeKey];
            [encoder encodeInteger:[self state]         forKey:OEHIDEventStateKey];
            [encoder encodeBool:_data.key.isFunctionKeyPressed forKey:OEHIDEventIsFunctionPressedKey];
            break;
    }
}

@end

@implementation OEHIDEvent (OEHIDEventCopy)

- (instancetype)nullEvent;
{
    if([self hasOffState]) return self;

    OEHIDEvent *event = [self copy];
    switch([event type])
    {
        case OEHIDEventTypeAxis :
        case OEHIDEventTypeTrigger :
            event->_data.axis.direction = OEHIDEventAxisDirectionNull;
            break;
        case OEHIDEventTypeButton :
            event->_data.button.state = OEHIDEventStateOff;
            break;
        case OEHIDEventTypeHatSwitch :
            event->_data.hatSwitch.hatDirection = OEHIDEventHatDirectionNull;
            break;
        case OEHIDEventTypeKeyboard :
            event->_data.key.state = OEHIDEventStateOff;
            break;
        default :
            break;
    }

    return event;
}

// Axis event copy
- (instancetype)axisEventWithOppositeDirection;
{
    return [self axisEventWithDirection:[self oppositeDirection]];
}

- (instancetype)axisEventWithDirection:(OEHIDEventAxisDirection)aDirection;
{
    if(aDirection == [self direction]) return self;

    OEHIDEvent *event = [self copy];

    event->_data.axis.direction = aDirection;
 
    if(aDirection == OEHIDEventAxisDirectionNull)
        event->_data.axis.value = 0;

    return event;
}

// Hatswitch event copy
- (instancetype)hatSwitchEventWithDirection:(OEHIDEventHatDirection)aDirection;
{
    if(aDirection == [self hatDirection]) return self;

    OEHIDEvent *event = [self copy];

    event->_data.hatSwitch.hatDirection = aDirection;

    return event;
}

- (instancetype)eventWithDeviceHandler:(OEDeviceHandler *)aDeviceHandler
{
    OEHIDEvent *event = [self copy];
    event->_deviceHandler = aDeviceHandler;
    return event;
}

@end

@implementation OEHIDEvent (OEHIDEventBinding)

- (NSUInteger)bindingHash;
{
    NSUInteger hash = [_deviceHandler deviceIdentifier] << 24;

    switch([self type])
    {
        case OEHIDEventTypeKeyboard :
            hash  = 0x1000000000000000u; // keyboard events do not care about padNumber
            hash |= [self keycode];
            break;
        case OEHIDEventTypeAxis :
            hash |= 0x2000000000000000u;
            hash |= [self axis] << 8;

            OEHIDEventAxisDirection dir = [self direction];
            if(dir != OEHIDEventAxisDirectionNull)
                hash |= (1 << ((dir) > OEHIDEventAxisDirectionNull));
            break;
        case OEHIDEventTypeTrigger :
            hash |= 0x2000000000000000u;
            hash |= [self axis] << 8;
            break;
        case OEHIDEventTypeButton :
            hash |= 0x4000000000000000u;
            hash |= [self buttonNumber];
            break;
        case OEHIDEventTypeHatSwitch :
            hash |= 0x8000000000000000u;
            hash |= [self hatDirection];
            break;
        default :
            break;
    }

    return hash;
}

- (BOOL)isBindingEqualToEvent:(OEHIDEvent *)anObject;
{
    if(_type != anObject->_type || _cookie != anObject->_cookie || _deviceHandler != anObject->_deviceHandler)
        return NO;

    switch(_type)
    {
        case OEHIDEventTypeKeyboard :
            return _data.key.keycode == anObject->_data.key.keycode;
        case OEHIDEventTypeAxis :
            return (_data.axis.direction == anObject->_data.axis.direction &&
                    _data.axis.axis      == anObject->_data.axis.axis);
        case OEHIDEventTypeTrigger :
            return _data.axis.axis == anObject->_data.axis.axis;
        case OEHIDEventTypeButton :
            return _data.button.buttonNumber == anObject->_data.button.buttonNumber;
        case OEHIDEventTypeHatSwitch :
            return _data.hatSwitch.hatDirection == anObject->_data.hatSwitch.hatDirection;
        default :
            break;
    }

    return NO;
}

@end

@implementation NSEvent (OEEventConversion)

+ (NSEvent *)eventWithKeyCode:(unsigned short)keyCode
{
    return [self eventWithKeyCode:keyCode keyIsDown:YES];
}

+ (NSEvent *)eventWithKeyCode:(unsigned short)keyCode keyIsDown:(BOOL)keyDown
{
    CGEventRef event = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)keyCode, keyDown);
    NSEvent *ret = [self eventWithCGEvent:event];
    CFRelease(event);
    return ret;
}

+ (NSString *)charactersForKeyCode:(unsigned short)keyCode
{
    return [[self eventWithKeyCode:keyCode] characters];
}

+ (NSString *)printableCharactersForKeyCode:(unsigned short)keyCode
{
    return [[self eventWithKeyCode:keyCode] displayDescription];
}

+ (NSUInteger)modifierFlagsForKeyCode:(unsigned short)keyCode
{
    return [[self eventWithKeyCode:keyCode] modifierFlags];
}

+ (NSString *)displayDescriptionForKeyCode:(unsigned short)keyCode
{
    return [[self eventWithKeyCode:keyCode] displayDescription];
}

- (NSString *)displayDescription
{
    NSString *characters = [self characters];

    if([characters length] == 0) return characters;

    NSString *ret = nil;

    unichar tested = [characters characterAtIndex:0];

    if(NSF1FunctionKey <= tested && tested <= NSF35FunctionKey)
        ret = [NSString stringWithFormat:@"F%u", tested - NSF1FunctionKey + 1];
    else if(tested == ' ' || tested == 0xA0)//[[NSCharacterSet whitespaceCharacterSet] characterIsMember:tested])
        ret = NSLocalizedString(@"<space>", @"Keyboard key name for space key.");
    else
    {
        unichar curr = 0;
        if(NO);
#define LAZY_CASE(c, val) else if(tested == c) curr = val
        LAZY_CASE(NSLeftArrowFunctionKey,  0x21E0); // '⇠'
        LAZY_CASE(NSUpArrowFunctionKey,    0x21E1); // '⇡'
        LAZY_CASE(NSRightArrowFunctionKey, 0x21E2); // '⇢'
        LAZY_CASE(NSDownArrowFunctionKey,  0x21E3); // '⇣'
        LAZY_CASE(NSDeleteFunctionKey,     0x2326); // '⌦'
        LAZY_CASE(NSHomeFunctionKey,       0x2196); // '↖'
        LAZY_CASE(NSEndFunctionKey,        0x2198); // '↘'
        LAZY_CASE(NSPageUpFunctionKey,     0x21DE); // '⇞'
        LAZY_CASE(NSPageDownFunctionKey,   0x21DF); // '⇟'
        LAZY_CASE(NSClearLineFunctionKey,  0x2327); // '⌧'
        LAZY_CASE('\r',                    0x21A9); // '↩'
        LAZY_CASE(0x03,                    0x2305); // '⌅'
        LAZY_CASE('\n',                    0x2305); // '⌅'
        LAZY_CASE('\t',                    0x21E5); // '⇥'
        LAZY_CASE(0x19,                    0x21E4); // '⇤'
        LAZY_CASE(0x7F,                    0x232B); // '⌫'
        LAZY_CASE(0x1B,                    0x238B); // '⎋'
#undef  LAZY_CASE

        if(curr != 0) ret = [NSString stringWithCharacters:&curr length:1];
        else          ret = characters;
    }

    return ret;
}

@end

@implementation NSNumber (OEEventConversion)

- (NSString *)displayDescription
{
    return [NSEvent displayDescriptionForKeyCode:[self unsignedShortValue]];
}

@end

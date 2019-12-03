/*
 Copyright (c) 2013, OpenEmu Team

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

#import "OEControllerDescription.h"
#import "OEControllerDescription_Internal.h"
#import "OEDeviceHandler.h"
#import "OEHIDDeviceHandler.h"
#import "OEHIDEvent.h"
#import "OEHIDEvent_Internal.h"
#import <IOKit/hid/IOHIDUsageTables.h>

NS_ASSUME_NONNULL_BEGIN

@interface OEHIDEvent ()
+ (instancetype)OE_eventWithElement:(IOHIDElementRef)element value:(NSInteger)value;
@end

static NSNumber *_OEDeviceIdentifierKey(id obj)
{
    return @([obj vendorID] << 32 | [obj productID]);
}

@interface OEControllerDescription ()
{
    NSString *_identifier;
    NSString *_name;
    NSDictionary<NSString *, OEDeviceDescription *> *_deviceNamesToDeviceDescriptions;

    NSMutableDictionary<NSString *, OEControlDescription *> *_controls;
    NSMutableDictionary<NSString *, OEControlValueDescription *> *_identifierToControlValue;
    NSMutableDictionary<NSNumber *, OEControlValueDescription *> *_valueIdentifierToControlValue;
}

- (id)OE_initWithVendorID:(NSUInteger)vendorID productID:(NSUInteger)productID name:(NSString *)name cookie:(uint32_t)cookie __attribute__((objc_method_family(init)));
- (id)OE_initWithIdentifier:(NSString *)identifier representation:(NSDictionary *)representation __attribute__((objc_method_family(init)));

@end

// Device representations stay in there for as long as no actual device of their type were plugged in.
static NSDictionary<NSString *, NSDictionary *> *_mappingRepresentations;
static NSDictionary<NSString *, OEControllerDescription *> *_deviceNamesToKnownControllerDescriptions;

@implementation OEControllerDescription

+ (void)initialize
{
    if(self == [OEControllerDescription class])
    {
        NSString *identifierPath = [[NSBundle mainBundle] pathForResource:@"Controller-Database" ofType:@"plist"];
        NSDictionary *representations = [NSPropertyListSerialization propertyListWithData:[NSData dataWithContentsOfFile:identifierPath options:NSDataReadingMappedIfSafe error:NULL] options:0 format:NULL error:NULL];

        NSMutableDictionary<NSString *, NSDictionary *> *mappingReps = [NSMutableDictionary dictionaryWithCapacity:[representations count]];
        NSMutableDictionary<NSString *, OEControllerDescription *> *deviceNamesToControllerDescriptions = [NSMutableDictionary dictionary];

        [representations enumerateKeysAndObjectsUsingBlock:^(NSString *identifier, NSDictionary *rep, BOOL *stop) {
            OEControllerDescription *description = [[OEControllerDescription alloc] OE_initWithIdentifier:identifier representation:rep];
            for (NSString *deviceName in description.deviceNames)
                deviceNamesToControllerDescriptions[deviceName] = description;

            mappingReps[identifier] = rep[@"OEControllerMappings"] ? : @{};
         }];

        _deviceNamesToKnownControllerDescriptions = [deviceNamesToControllerDescriptions copy];
        _mappingRepresentations = [mappingReps copy];
    }
}

+ (OEDeviceDescription *)OE_deviceDescriptionForVendorID:(NSUInteger)vendorID productID:(NSUInteger)productID product:(NSString *)product cookie:(uint32_t)cookie
{
    // Some devices have no HID Product string descriptor
    if(product == nil) product = @"Unknown USB Gamepad";

    OEControllerDescription *controllerDescription = [_deviceNamesToKnownControllerDescriptions[product] OE_controllerDescription];
    if (controllerDescription != nil)
        return [controllerDescription deviceDescriptionForDeviceName:product];

    OEControllerDescription *desc = [[OEControllerDescription alloc] OE_initWithVendorID:vendorID productID:productID name:product cookie:cookie];
    return [desc deviceDescriptionForDeviceName:product];
}

+ (NSDictionary<NSString *, NSDictionary<NSString *, id> *> *)OE_dequeueRepresentationForDeviceDescription:(OEDeviceDescription *)deviceDescription;
{
    return _mappingRepresentations[[[deviceDescription controllerDescription] identifier]];
}

- (id)OE_initWithIdentifier:(NSString *)identifier representation:(NSDictionary *)representation
{
    if((self = [super init]))
    {
        _identifier = [identifier copy];
        _name = representation[@"OEControllerName"];
        _controls = [NSMutableDictionary dictionary];
        _identifierToControlValue = [NSMutableDictionary dictionary];
        _valueIdentifierToControlValue = [NSMutableDictionary dictionary];

        [self OE_setUpDevicesWithRepresentations:[representation objectForKey:@"OEControllerDevices"]];
    }

    return self;
}

- (id)OE_initWithVendorID:(NSUInteger)vendorID productID:(NSUInteger)productID name:(NSString *)name cookie:(uint32_t)cookie
{
    if((self = [super init]))
    {
        _isGeneric = YES;
        _name = name;
        _cookie = cookie;
        _controls = [NSMutableDictionary dictionary];
        _identifierToControlValue = [NSMutableDictionary dictionary];
        _valueIdentifierToControlValue = [NSMutableDictionary dictionary];

        OEDeviceDescription *desc = [[OEDeviceDescription alloc] OE_initWithRepresentation:
                                     @{
                                         @"OEControllerDeviceName"    : _name,
                                         @"OEControllerProductName"   : _name,
                                         @"OEControllerVendorID"      : @(vendorID),
                                         @"OEControllerProductID"     : @(productID),
                                         @"OEControllerCookie"        : @(cookie),
                                     } controllerDescription:self];

        _identifier = [desc genericDeviceIdentifier];
        _deviceNamesToDeviceDescriptions = @{ _name: desc };
    }

    return self;
}

- (id)copyWithZone:(nullable NSZone *)zone
{
    return self;
}

- (instancetype)OE_controllerDescription
{
    OEControllerDescription *ret = [[[self class] alloc] init];
    ret->_isGeneric = _isGeneric;
    ret->_identifier = [_identifier copy];
    ret->_name = [_name copy];
    ret->_cookie = _cookie;
    ret->_controls = [NSMutableDictionary dictionary];
    ret->_identifierToControlValue = [NSMutableDictionary dictionary];
    ret->_valueIdentifierToControlValue = [NSMutableDictionary dictionary];

    NSMutableDictionary<NSString *, OEDeviceDescription *> *deviceNamesToDeviceDescriptions = [NSMutableDictionary dictionary];
    [_deviceNamesToDeviceDescriptions enumerateKeysAndObjectsUsingBlock:^(NSString *key, OEDeviceDescription *obj, BOOL * _Nonnull stop) {
        deviceNamesToDeviceDescriptions[key] = [obj OE_deviceDescriptionWithControllerDescription:ret];
    }];
    ret->_deviceNamesToDeviceDescriptions = [deviceNamesToDeviceDescriptions copy];

    return ret;
}

- (NSArray<NSString *> *)deviceNames
{
    return _deviceNamesToDeviceDescriptions.allKeys;
}

- (OEDeviceDescription *)deviceDescriptionForDeviceName:(NSString *)productName
{
    return _deviceNamesToDeviceDescriptions[productName];
}

- (void)OE_setUpDevicesWithRepresentations:(NSArray *)representations
{
    NSMutableDictionary<NSString *, OEDeviceDescription *> *deviceNamesToDeviceDescriptions = [NSMutableDictionary dictionary];

    for(NSDictionary *rep in representations)
    {
        OEDeviceDescription *desc = [[OEDeviceDescription alloc] OE_initWithRepresentation:rep controllerDescription:self];
        deviceNamesToDeviceDescriptions[desc.product] = desc;
    }

    _deviceNamesToDeviceDescriptions = [deviceNamesToDeviceDescriptions copy];
}

- (NSUInteger)numberOfControls
{
    return [_controls count];
}

- (NSArray *)controls
{
    return [_controls allValues];
}

- (OEControlValueDescription *)controlValueDescriptionForEvent:(OEHIDEvent *)event;
{
    return _valueIdentifierToControlValue[@([event controlValueIdentifier])];
}

- (OEControlValueDescription *)controlValueDescriptionForIdentifier:(NSString *)controlIdentifier;
{
    return _identifierToControlValue[controlIdentifier];
}

- (OEControlValueDescription *)controlValueDescriptionForRepresentation:(id)representation
{
    if ([representation isKindOfClass:[NSDictionary class]])
        return [self controlValueDescriptionForEvent:[OEHIDEvent eventWithDictionaryRepresentation:representation]];

    if ([representation isKindOfClass:[NSString class]])
        return [self controlValueDescriptionForIdentifier:representation];

    return nil;
}

- (OEControlDescription *)addControlWithIdentifier:(nullable NSString *)identifier name:(nullable NSString *)name event:(OEHIDEvent *)event;
{
    OEControlDescription *desc = [[OEControlDescription alloc] OE_initWithIdentifier:identifier name:name genericEvent:event controllerDescription:self];
    NSAssert(_controls[[desc identifier]] == nil, @"There is already a control %@ with the identifier %@", _controls[[desc identifier]], identifier);

    _controls[[desc identifier]] = desc;

    if(_isGeneric) [desc setUpControlValuesUsingRepresentations:nil];

    return desc;
}

- (OEControlDescription *)addControlWithIdentifier:(NSString *)identifier name:(NSString *)name event:(OEHIDEvent *)event valueRepresentations:(NSDictionary *)valueRepresentations;
{
    OEControlDescription *desc = [self addControlWithIdentifier:identifier name:name event:event];
    [desc setUpControlValuesUsingRepresentations:valueRepresentations];

    return desc;
}


- (void)OE_controlDescription:(OEControlDescription *)control didAddControlValue:(OEControlValueDescription *)valueDesc;
{
    _identifierToControlValue[[valueDesc identifier]] = valueDesc;
    _valueIdentifierToControlValue[[valueDesc valueIdentifier]] = valueDesc;
}

@end

OEHIDEventType OEHIDEventTypeFromNSString(NSString *string)
{
    static NSDictionary *namesToValue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        namesToValue = @{
            @"Axis"      : @(OEHIDEventTypeAxis),
            @"Button"    : @(OEHIDEventTypeButton),
            @"HatSwitch" : @(OEHIDEventTypeHatSwitch),
            @"Trigger"   : @(OEHIDEventTypeTrigger),
        };
    });

    return [[namesToValue objectForKey:string] integerValue];
}

NSUInteger OEUsageFromUsageStringWithType(NSString *usageString, OEHIDEventType type)
{
    switch(type)
    {
        case OEHIDEventTypeButton :
            return [usageString integerValue];
        case OEHIDEventTypeAxis :
        case OEHIDEventTypeTrigger :
            return OEHIDEventAxisFromNSString(usageString);
        case OEHIDEventTypeHatSwitch :
            return kHIDUsage_GD_Hatswitch;
        default :
            break;
    }

    return 0;
}

NS_ASSUME_NONNULL_END

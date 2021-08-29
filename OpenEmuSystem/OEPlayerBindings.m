/*
 Copyright (c) 2012, OpenEmu Team
 
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

#import "OEPlayerBindings.h"

#import "OEBindingsController_Internal.h"
#import "OEControlDescription.h"
#import "OEDeviceHandler.h"
#import "OEHIDEvent.h"

NS_ASSUME_NONNULL_BEGIN

@implementation OEPlayerBindings {
    NSMutableDictionary<NSString *, NSString *> *_bindingDescriptions;
    NSMutableDictionary<id, OEHIDEvent *> *_bindingEvents;
}

@synthesize systemBindingsController, playerNumber;

+ (instancetype)allocWithZone:(NSZone *)zone
{
    NSAssert(self != [OEPlayerBindings class], @"Do not allocate instances of OEPlayerBindings");
    return [super allocWithZone:zone];
}

- (instancetype)OE_initWithSystemBindings:(OESystemBindings *)aController playerNumber:(NSUInteger)aPlayerNumber;
{
    if((self = [super init]))
    {
        systemBindingsController = aController;
        playerNumber             = aPlayerNumber;
    }
    
    return self;
}

- (NSDictionary<NSString *, NSString *> *)bindingDescriptions
{
    return _bindingDescriptions;
}

- (void)OE_setBindingDescriptions:(NSDictionary<NSString *, NSString *> *)value
{
    if(_bindingDescriptions != value)
    {
        _bindingDescriptions = [value mutableCopy];
    }
}

- (NSDictionary<id, OEHIDEvent *> *)bindingEvents
{
    return _bindingEvents;
}

- (void)OE_setBindingEvents:(NSDictionary<id, OEHIDEvent *> *)value
{
    if(_bindingEvents != value)
    {
        _bindingEvents = [value mutableCopy];
    }
}

- (nullable id)valueForKey:(NSString *)key
{
    if([key hasPrefix:@"@"]) return [super valueForKey:[key substringFromIndex:1]];
    
    return [[self bindingDescriptions] objectForKey:key];
}

- (nullable id)assignEvent:(OEHIDEvent *)anEvent toKeyWithName:(NSString *)aKeyName;
{
    return anEvent != nil ? [[self systemBindingsController] OE_playerBindings:self didAssignEvent:anEvent toKeyWithName:aKeyName] : nil;
}

- (void)removeEventForKeyWithName:(NSString *)aKeyName
{
    [[self systemBindingsController] OE_playerBindings:self didRemoveEventForKeyWithName:aKeyName];
}

- (void)setValue:(nullable id)value forKey:(NSString *)key
{
    if([key hasPrefix:@"@"]) return [super setValue:value forKey:[key substringFromIndex:1]];
}

- (id)OE_bindingDescriptionForKey:(NSString *)aKey;
{
    return [[self bindingDescriptions] objectForKey:aKey];
}

- (void)OE_setBindingDescription:(nullable NSString *)value forKey:(NSString *)aKey;
{
    [self willChangeValueForKey:@"bindingDescriptions"];
    [self willChangeValueForKey:aKey];
    
    if(value == nil)
        [_bindingDescriptions removeObjectForKey:aKey];
    else
        [_bindingDescriptions setObject:value forKey:aKey];
    
    [self didChangeValueForKey:aKey];
    [self didChangeValueForKey:@"bindingDescriptions"];
}

- (id)OE_bindingEventForKey:(id)aKey;
{
    return [[self bindingEvents] objectForKey:aKey];
}

- (void)OE_setBindingEvent:(nullable id)value forKey:(id)aKey;
{
    [self willChangeValueForKey:@"bindingEvents"];
    
    if(value == nil)
        [_bindingEvents removeObjectForKey:aKey];
    else
        [_bindingEvents setObject:value forKey:aKey];
    
    [self didChangeValueForKey:@"bindingEvents"];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p playerNumber: %lu rawBindings: %@ bindings: %@>", [self class], self, [self playerNumber], [self bindingEvents], [self bindingDescriptions]];
}

@end

@implementation OEKeyboardPlayerBindings
@dynamic bindingEvents;
@end

static void *const OEDevicePlayerBindingOriginalBindingsObserver = (void *)&OEDevicePlayerBindingOriginalBindingsObserver;

@implementation OEDevicePlayerBindings
@dynamic bindingEvents;

- (instancetype)OE_initWithSystemBindings:(OESystemBindings *)aController playerNumber:(NSUInteger)playerNumber
{
    return [self OE_initWithSystemBindings:aController playerNumber:playerNumber deviceHandler:nil];
}

- (instancetype)OE_initWithSystemBindings:(OESystemBindings *)aController playerNumber:(NSUInteger)playerNumber deviceHandler:(nullable OEDeviceHandler *)handler;
{
    if((self = [super OE_initWithSystemBindings:aController playerNumber:playerNumber]))
    {
        _deviceHandler = handler;
    }
    
    return self;
}

- (void)OE_setDeviceHandler:(nullable OEDeviceHandler *)value
{
    if(_deviceHandler == value)
        return;

    if(_deviceHandler != nil && value != nil)
        NSLog(@"ERROR: Something fishy is happening here, %@ received handler %@, when handler %@ was already set.", self, _deviceHandler, value);

    _deviceHandler = value;

    // Forces bindings to be set to a specific device
    [self OE_setBindingEvents:[self bindingEvents]];
}

@end

NS_ASSUME_NONNULL_END

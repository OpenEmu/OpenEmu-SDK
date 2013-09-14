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

#import "OEKeyBindingGroupDescription.h"
#import "OEBindingsController_Internal.h"

NSString *NSStringFromOEKeyGroupType(OEKeyGroupType type)
{
    NSString *ret = @"<invalid>";
    
    switch(type)
    {
        case OEKeyGroupTypeAxis      : ret = @"OEKeyGroupTypeAxis";      break;
        case OEKeyGroupTypeHatSwitch : ret = @"OEKeyGroupTypeHatSwitch"; break;
        default : break;
    }
    
    return ret;
}

@interface OEOrientedKeyGroupBindingDescription ()
- (id)OE_initWithParentKeyGroup:(OEKeyBindingGroupDescription *)parent baseKey:(OEKeyBindingDescription *)base __attribute__((objc_method_family(init)));
@end

@implementation OEKeyBindingGroupDescription
{
    NSMutableDictionary     *_orientedGroups;
    OEKeyBindingDescription *_axisKeys[2];
}

- (id)init
{
    return nil;
}

- (id)initWithGroupType:(OEKeyGroupType)aType keys:(NSArray *)groupedKeys;
{
    if(aType != OEKeyGroupTypeAxis && aType != OEKeyGroupTypeHatSwitch) return nil;
    
    if((self = [super init]))
    {
        _orientedGroups = [NSMutableDictionary dictionaryWithCapacity:[groupedKeys count]];
        _type = aType;
        _keys = [groupedKeys copy];
        
        if([self class] == [OEKeyBindingGroupDescription class])
            [_keys makeObjectsPerformSelector:(aType == OEKeyGroupTypeAxis
                                              ? @selector(OE_setAxisGroup:)
                                              : @selector(OE_setHatSwitchGroup:))
                                  withObject:self];
        
        if(_type == OEKeyGroupTypeAxis)
        {
            _axisKeys[0] = [groupedKeys objectAtIndex:0];
            _axisKeys[1] = [groupedKeys objectAtIndex:1];
        }
    }
    
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (NSArray *)keyNames
{
    return [_keys valueForKey:@"name"];
}

- (BOOL)isAnalogic
{
    return [[_keys lastObject] isAnalogic];
}

- (BOOL)isEqual:(id)anObject;
{
    if(self == anObject) return YES;
    
    if(![anObject isKindOfClass:[OEKeyBindingGroupDescription class]])
        return NO;
    
    id comp = self;
    if([self isKindOfClass:[OEOrientedKeyGroupBindingDescription class]])
        comp = [comp parentKeyGroup];
    if([anObject isKindOfClass:[OEOrientedKeyGroupBindingDescription class]])
        anObject = [anObject parentKeyGroup];
    
    return comp == anObject;
}

- (OEKeyBindingDescription *)oppositeKeyOfKey:(OEKeyBindingDescription *)aKey;
{
    NSAssert(_type == OEKeyGroupTypeAxis, @"Key Group type must be OEKeyGroupTypeAxis.");
    
    OEKeyBindingDescription *ret = nil;
    
    if(NO);
    else if(_axisKeys[0] == aKey) ret = _axisKeys[1];
    else if(_axisKeys[1] == aKey) ret = _axisKeys[0];
    
    NSAssert2(ret != nil, @"Key %@ is not part of the group %@", aKey, self);
    
    return ret;
}

- (OEOrientedKeyGroupBindingDescription *)orientedKeyGroupWithBaseKey:(OEKeyBindingDescription *)aKey
{
    NSAssert([_keys containsObject:aKey], @"The base key must belong to the key group.");
    
    OEOrientedKeyGroupBindingDescription *ret = [_orientedGroups objectForKey:aKey];
    
    if(ret == nil)
    {
        ret = [[OEOrientedKeyGroupBindingDescription alloc] OE_initWithParentKeyGroup:self baseKey:aKey];
        [_orientedGroups setObject:ret forKey:aKey];
    }
    
    return ret;
}

- (NSUInteger)indexOfKey:(OEKeyBindingDescription *)aKey;
{
    return [_keys indexOfObject:aKey];
}

- (void)enumerateKeysFromKey:(OEKeyBindingDescription *)baseKey usingBlock:(void(^)(OEKeyBindingDescription *key, BOOL *stop))block;
{
    NSUInteger count   = [_keys count];
    NSUInteger baseIdx = [_keys indexOfObject:baseKey];
    
    // It shouldn't happen but let's avoid weird stuff anyway
    if(count == 0 || baseIdx == NSNotFound) return;
    
    BOOL stop = NO;
    
    for(NSUInteger i = 0; i < count; i++)
    {
        block([_keys objectAtIndex:(i + baseIdx) % count], &stop);
        
        if(stop) return;
    }
}

- (void)enumerateOrientedKeyGroupsFromKey:(OEKeyBindingDescription *)baseKey usingBlock:(void (^)(OEOrientedKeyGroupBindingDescription *key, BOOL *stop))block;
{
    [self enumerateKeysFromKey:baseKey usingBlock:
     ^(OEKeyBindingDescription *key, BOOL *stop)
     {
         block([self orientedKeyGroupWithBaseKey:key], stop);
     }];
}

- (NSString *)description
{
    NSString *additionalDesc = @"";
    if([self isAnalogic]) additionalDesc = @" isAnalogic";

    return [NSString stringWithFormat:@"<%@ %p type: %@%@ keys: { %@ }>", [self class], self, NSStringFromOEKeyGroupType([self type]), additionalDesc, [[self keyNames] componentsJoinedByString:@", "]];
}

@end

@implementation OEOrientedKeyGroupBindingDescription

- (id)init
{
    return nil;
}

- (id)OE_initWithParentKeyGroup:(OEKeyBindingGroupDescription *)parent baseKey:(OEKeyBindingDescription *)base;
{
    NSAssert([[parent keys] containsObject:base], @"The base key must belong to the key group.");
    
    if((self = [super initWithGroupType:[parent type] keys:[parent keys]]))
    {
        _parentKeyGroup = parent;
        _baseKey        = base;
    }
    
    return self;
}

- (NSUInteger)hash
{
    return [[self parentKeyGroup] hash];
}

- (BOOL)isEqual:(id)object
{
    if([object isKindOfClass:[OEOrientedKeyGroupBindingDescription class]])
        return [self parentKeyGroup] == [object parentKeyGroup];
    
    return [super isEqual:object];
}

- (BOOL)isAnalogic
{
    return [[self baseKey] isAnalogic];
}

- (OEKeyBindingDescription *)oppositeKey;
{
    return [self oppositeKeyOfKey:_baseKey];
}

- (NSUInteger)indexOfBaseKey;
{
    return [self indexOfKey:_baseKey];
}

- (void)enumerateKeysFromBaseKeyUsingBlock:(void(^)(OEKeyBindingDescription *key, BOOL *stop))block;
{
    [self enumerateKeysFromKey:_baseKey usingBlock:block];
}

- (void)enumerateOrientedKeyGroupsFromBaseKeyUsingBlock:(void(^)(OEOrientedKeyGroupBindingDescription *key, BOOL *stop))block;
{
    [self enumerateOrientedKeyGroupsFromKey:_baseKey usingBlock:block];
}

- (OEOrientedKeyGroupBindingDescription *)orientedKeyGroupWithBaseKey:(OEKeyBindingDescription *)aKey
{
    return [[self parentKeyGroup] orientedKeyGroupWithBaseKey:aKey];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p baseKey: %@ parentKeyGroup: %@>", [self class], self, [[self baseKey] name], [self parentKeyGroup]];
}

@end

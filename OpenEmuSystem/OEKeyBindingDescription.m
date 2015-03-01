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

#import "OEKeyBindingDescription.h"
#import "OEBindingsController_Internal.h"

NSString *NSStringFromOEGlobalButtonIdentifier(OEGlobalButtonIdentifier identifier)
{
    switch(identifier)
    {
        case OEGlobalButtonIdentifierUnknown :
            return @"OEGlobalButtonIdentifierUnknown";
        case OEGlobalButtonIdentifierSaveState :
            return @"OEGlobalButtonIdentifierSaveState";
        case OEGlobalButtonIdentifierLoadState :
            return @"OEGlobalButtonIdentifierLoadState";
        case OEGlobalButtonIdentifierQuickSave :
            return @"OEGlobalButtonIdentifierQuickSave";
        case OEGlobalButtonIdentifierQuickLoad :
            return @"OEGlobalButtonIdentifierQuickLoad";
        case OEGlobalButtonIdentifierFullScreen :
            return @"OEGlobalButtonIdentifierFullScreen";
        case OEGlobalButtonIdentifierMute :
            return @"OEGlobalButtonIdentifierMute";
        case OEGlobalButtonIdentifierVolumeDown :
            return @"OEGlobalButtonIdentifierVolumeDown";
        case OEGlobalButtonIdentifierVolumeUp :
            return @"OEGlobalButtonIdentifierVolumeUp";
        case OEGlobalButtonIdentifierStop :
            return @"OEGlobalButtonIdentifierStop";
        case OEGlobalButtonIdentifierReset :
            return @"OEGlobalButtonIdentifierReset";
        case OEGlobalButtonIdentifierPause :
            return @"OEGlobalButtonIdentifierPause";
        case OEGlobalButtonIdentifierRewind :
            return @"OEGlobalButtonIdentifierRewind";
        case OEGlobalButtonIdentifierFastForward :
            return @"OEGlobalButtonIdentifierFastForward";
        case OEGlobalButtonIdentifierSlowMotion :
            return @"OEGlobalButtonIdentifierSlowMotion";
        case OEGlobalButtonIdentifierStepFrameBackward :
            return @"OEGlobalButtonIdentifierStepFrameBackward";
        case OEGlobalButtonIdentifierStepFrameForward :
            return @"OEGlobalButtonIdentifierStepFrameForward";
        case OEGlobalButtonIdentifierDisplayMode :
            return @"OEGlobalButtonIdentifierDisplayMode";
        case OEGlobalButtonIdentifierScreenshot :
            return @"OEGlobalButtonIdentifierScreenshot";
        case OEGlobalButtonIdentifierCount :
            return @"OEGlobalButtonIdentifierCount";
        case OEGlobalButtonIdentifierFlag :
            return @"OEGlobalButtonIdentifierFlag";
    }

    return @"<Unknown value>";
}

@implementation OEKeyBindingDescription
@synthesize _hatSwitchGroup = _hatSwitchGroup;
@synthesize _axisGroup = _axisGroup;

- (id)init
{
    return nil;
}

- (id)OE_initWithName:(NSString *)keyName index:(NSUInteger)keyIndex isSystemWide:(BOOL)isSystemWide
{
    if((self = [super init]))
    {
        _name       = [keyName copy];
        _index      = keyIndex;
        _systemWide = isSystemWide;
    }
    
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (void)OE_setAxisGroup:(OEKeyBindingGroupDescription *)value
{
    NSAssert(_axisGroup == nil, @"Cannot change axisGroup after it was set, attempted to change axisGroup of %@ from %@ to %@.", self, _axisGroup, value);
    
    NSAssert([value isMemberOfClass:[OEKeyBindingGroupDescription class]], @"Expecting group of class OEKeyGroupBindingsDescription, instead got: %@", [value class]);
    
    _axisGroup = value;
}

- (void)OE_setHatSwitchGroup:(OEKeyBindingGroupDescription *)value
{
    NSAssert(_hatSwitchGroup == nil, @"Cannot change hatSwitchGroup after it was set, attempted to change hatSwitchGroup of %@ from %@ to %@.", self, _hatSwitchGroup, value);
    
    NSAssert([value isMemberOfClass:[OEKeyBindingGroupDescription class]], @"Expecting group of class OEKeyGroupBindingsDescription, instead got: %@", [value class]);
    
    _hatSwitchGroup = value;
}

- (OEKeyBindingDescription *)oppositeKey
{
    return [_axisGroup oppositeKeyOfKey:self];
}

- (NSArray *)hatSwitchKeys
{
    return [_hatSwitchGroup keys];
}

- (void)enumerateHatSwitchKeysUsingBlock:(void (^)(OEKeyBindingDescription *, BOOL *))block
{
    [_hatSwitchGroup enumerateKeysFromKey:self usingBlock:block];
}

- (NSString *)description
{
    NSMutableArray *additionalDesc = [NSMutableArray arrayWithObject:@""];
    if([self isSystemWide]) [additionalDesc addObject:@"isSystemWide"];
    if([self isAnalogic]) [additionalDesc addObject:@"isAnalogic"];
    if([self OE_axisGroup] != nil) [additionalDesc addObject:[NSString stringWithFormat:@"axisGroup: %@", [self OE_axisGroup]]];
    if([self OE_axisGroup] != nil) [additionalDesc addObject:[NSString stringWithFormat:@"hatSwitchGroup: %@", [self OE_hatSwitchGroup]]];

    NSString *result = @"";
    if([additionalDesc count] > 1) result = [additionalDesc componentsJoinedByString:@" "];

    return [NSString stringWithFormat:@"<%@ %p keyName: %@ index: %lu%@>", [self class], self, [self name], [self index], result];
}

@end

@implementation OEGlobalKeyBindingDescription

- (id)OE_initWithName:(NSString *)keyName index:(NSUInteger)keyIndex isSystemWide:(BOOL)isSystemWide
{
    return nil;
}

- (id)OE_initWithButtonIdentifier:(OEGlobalButtonIdentifier)identifier
{
    if((self = [super OE_initWithName:nil index:0 isSystemWide:YES]))
    {
        _buttonIdentifier = identifier;
    }

    return self;
}

- (OEKeyBindingGroupDescription *)OE_axisGroup
{
    return nil;
}

- (void)OE_setAxisGroup:(OEKeyBindingGroupDescription *)value
{
    NSAssert(NO, @"You cannot set an Axis Group on a OEGlobalKeyBindingDescription");
}

- (OEKeyBindingGroupDescription *)OE_hatSwitchGroup
{
    return nil;
}

- (void)OE_setHatSwitchGroup:(OEKeyBindingGroupDescription *)_hatSwitchGroup
{
    NSAssert(NO, @"You cannot set an Axis Group on a OEGlobalKeyBindingDescription");
}

- (NSArray *)hatSwitchKeys
{
    return nil;
}

- (OEKeyBindingDescription *)oppositeKey
{
    return nil;
}

- (BOOL)isAnalogic
{
    switch(_buttonIdentifier)
    {
        //case OEGlobalButtonIdentifierRewind :
        //case OEGlobalButtonIdentifierFastForward :
        case OEGlobalButtonIdentifierSlowMotion :
            return YES;
        default :
            break;
    }

    return NO;
}

- (void)OE_setAnalogic:(BOOL)analog
{
}

- (void)enumerateHatSwitchKeysUsingBlock:(void (^)(OEKeyBindingDescription *, BOOL *))block
{
    
}

- (BOOL)isSystemWide
{
    return YES;
}

- (NSString *)name
{
    switch(_buttonIdentifier)
    {
        case OEGlobalButtonIdentifierSaveState :
            return OEGlobalButtonSaveState;
        case OEGlobalButtonIdentifierLoadState :
            return OEGlobalButtonLoadState;
        case OEGlobalButtonIdentifierQuickSave :
            return OEGlobalButtonQuickSave;
        case OEGlobalButtonIdentifierQuickLoad :
            return OEGlobalButtonQuickLoad;
        case OEGlobalButtonIdentifierFullScreen :
            return OEGlobalButtonFullScreen;
        case OEGlobalButtonIdentifierMute :
            return OEGlobalButtonMute;
        case OEGlobalButtonIdentifierVolumeDown :
            return OEGlobalButtonVolumeDown;
        case OEGlobalButtonIdentifierVolumeUp :
            return OEGlobalButtonVolumeUp;
        case OEGlobalButtonIdentifierStop:
            return OEGlobalButtonStop;
        case OEGlobalButtonIdentifierReset :
            return OEGlobalButtonReset;
        case OEGlobalButtonIdentifierPause :
            return OEGlobalButtonPause;
        case OEGlobalButtonIdentifierRewind :
            return OEGlobalButtonRewind;
        case OEGlobalButtonIdentifierFastForward :
            return OEGlobalButtonFastForward;
        case OEGlobalButtonIdentifierSlowMotion :
            return OEGlobalButtonSlowMotion;
        case OEGlobalButtonIdentifierStepFrameBackward :
            return OEGlobalButtonStepFrameBackward;
        case OEGlobalButtonIdentifierStepFrameForward :
            return OEGlobalButtonStepFrameForward;
        case OEGlobalButtonIdentifierDisplayMode :
            return OEGlobalButtonDisplayMode;
        case OEGlobalButtonIdentifierScreenshot :
            return OEGlobalButtonScreenshot;
        default :
            break;
    }

    return nil;
}

- (NSUInteger)index
{
    return _buttonIdentifier | OEGlobalButtonIdentifierFlag;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p identifier: %@>", [self class], self, NSStringFromOEGlobalButtonIdentifier([self buttonIdentifier])];
}

@end

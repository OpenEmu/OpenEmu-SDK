/*
 Copyright (c) 2011, OpenEmu Team

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

#import "OEBasicSystemResponder.h"

#import "NSResponder+OEHIDAdditions.h"
#import "OEDeviceHandler.h"
#import "OEHIDEvent.h"
#import "OESystemController.h"
#import "OEEvent.h"
#import "OEKeyBindingDescription.h"
#import "OEKeyBindingGroupDescription.h"

#import <OpenEmuBase/OpenEmuBase.h>

enum { NORTH, EAST, SOUTH, WEST, HAT_COUNT };

typedef enum : NSUInteger {
    OEAxisSystemKeyTypeDisjoint       = 0,
    OEAxisSystemKeyTypeDisjointAnalog = 1,
    OEAxisSystemKeyTypeJointAnalog    = 2,
} OEAxisSystemKeyType;

@implementation OEBasicSystemResponder
{
    CFMutableDictionaryRef _joystickStates;
    CFMutableDictionaryRef _analogSystemKeyTypes;
    BOOL                   _handlesEscapeKey;
}

static inline void _OEBasicSystemResponderPressSystemKey(OEBasicSystemResponder *self, OESystemKey *key, BOOL isAnalogic)
{
    if([key isGlobalButtonKey])
    {
        OEGlobalButtonIdentifier ident = [key key] & ~OEGlobalButtonIdentifierFlag;
        if(isAnalogic)
            [self changeAnalogGlobalButtonIdentifier:ident value:1.0];
        else
            [self pressGlobalButtonWithIdentifier:ident];
    }
    else
    {
        if(isAnalogic)
            [self changeAnalogEmulatorKey:key value:1.0];
        else
            [self pressEmulatorKey:key];
    }
}

static inline void _OEBasicSystemResponderReleaseSystemKey(OEBasicSystemResponder *self, OESystemKey *key, BOOL isAnalogic)
{
    if([key isGlobalButtonKey])
    {
        OEGlobalButtonIdentifier ident = [key key] & ~OEGlobalButtonIdentifierFlag;
        if(isAnalogic)
            [self changeAnalogGlobalButtonIdentifier:ident value:0.0];
        else
            [self releaseGlobalButtonWithIdentifier:ident];
    }
    else
    {
        if(isAnalogic)
            [self changeAnalogEmulatorKey:key value:0.0];
        else
            [self releaseEmulatorKey:key];
    }
}

static inline void _OEBasicSystemResponderChangeAnalogSystemKey(OEBasicSystemResponder *self, OESystemKey *key, CGFloat value)
{
    if([key isGlobalButtonKey])
        [self changeAnalogGlobalButtonIdentifier:[key key] & ~OEGlobalButtonIdentifierFlag value:value];
    else
        [self changeAnalogEmulatorKey:key value:value];
}

- (id)initWithController:(OESystemController *)controller;
{
    if((self = [super initWithController:controller]))
    {
        _keyMap = [[OEBindingMap alloc] initWithSystemController:controller];
        _joystickStates = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
        _analogSystemKeyTypes = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
    }

    return self;
}

- (void)dealloc
{
    CFRelease(_joystickStates);
}

- (OESystemKey *)emulatorKeyForKey:(OEKeyBindingDescription *)aKey player:(NSUInteger)thePlayer;
{
    return [OESystemKey systemKeyWithKey:[aKey index] player:thePlayer isAnalogic:[aKey isAnalogic]];
}

- (void)pressEmulatorKey:(OESystemKey *)aKey
{
    [self doesNotImplementSelector:_cmd];
}

- (void)releaseEmulatorKey:(OESystemKey *)aKey
{
    [self doesNotImplementSelector:_cmd];
}

- (void)changeAnalogEmulatorKey:(OESystemKey *)aKey value:(CGFloat)value
{
    [self doesNotImplementSelector:_cmd];
}

- (void)pressGlobalButtonWithIdentifier:(OEGlobalButtonIdentifier)identifier;
{
    FIXME("We currently only trigger these actions on release, but maybe some of these (like StepFrameBackward and StepFrameForward) should allow key repeat");
}

- (void)releaseGlobalButtonWithIdentifier:(OEGlobalButtonIdentifier)identifier;
{
    switch(identifier)
    {
        case OEGlobalButtonIdentifierSaveState :
            [self saveState:self];
            return;
        case OEGlobalButtonIdentifierLoadState :
            [self loadState:self];
            return;
        case OEGlobalButtonIdentifierQuickSave :
            [self quickSave:self];
            return;
        case OEGlobalButtonIdentifierQuickLoad :
            [self quickLoad:self];
            return;
        case OEGlobalButtonIdentifierFullScreen :
            [self toggleFullScreen:self];
            return;
        case OEGlobalButtonIdentifierMute :
            [self toggleAudioMute:self];
            return;
        case OEGlobalButtonIdentifierVolumeDown :
            [self volumeDown:self];
            return;
        case OEGlobalButtonIdentifierVolumeUp :
            [self volumeUp:self];
            return;
        case OEGlobalButtonIdentifierReset :
            [self resetEmulation:self];
            return;
        case OEGlobalButtonIdentifierPause :
            [self toggleEmulationPause:self];
            return;
        case OEGlobalButtonIdentifierStepFrameBackward :
            [[self client] stepFrameBackward];
            return;
        case OEGlobalButtonIdentifierStepFrameForward :
            [[self client] stepFrameForward];
            return;

        case OEGlobalButtonIdentifierRewind :
        case OEGlobalButtonIdentifierFastForward :
        case OEGlobalButtonIdentifierSlowMotion :
            NSAssert(NO, @"%@ only supports analog changes", NSStringFromOEGlobalButtonIdentifier(identifier));
            return;

        case OEGlobalButtonIdentifierUnknown :
        case OEGlobalButtonIdentifierCount :
        case OEGlobalButtonIdentifierFlag :
            NSAssert(NO, @"%@ is not a valid value", NSStringFromOEGlobalButtonIdentifier(identifier));
            return;
    }

    NSAssert(NO, @"Unknown identifier: %lx", identifier);
}

- (void)changeAnalogGlobalButtonIdentifier:(OEGlobalButtonIdentifier)identifier value:(CGFloat)value;
{
    switch(identifier)
    {
        case OEGlobalButtonIdentifierRewind :
            [[self client] rewindAtSpeed:value];
            return;
        case OEGlobalButtonIdentifierFastForward :
            [[self client] fastForwardAtSpeed:value];
            return;
        case OEGlobalButtonIdentifierSlowMotion :
            [[self client] slowMotionAtSpeed:value];
            return;

        case OEGlobalButtonIdentifierSaveState :
        case OEGlobalButtonIdentifierLoadState :
        case OEGlobalButtonIdentifierQuickSave :
        case OEGlobalButtonIdentifierQuickLoad :
        case OEGlobalButtonIdentifierFullScreen :
        case OEGlobalButtonIdentifierMute :
        case OEGlobalButtonIdentifierVolumeDown :
        case OEGlobalButtonIdentifierVolumeUp :
        case OEGlobalButtonIdentifierReset :
        case OEGlobalButtonIdentifierPause :
        case OEGlobalButtonIdentifierStepFrameBackward :
        case OEGlobalButtonIdentifierStepFrameForward :
            NSAssert(NO, @"%@ only supports press/release changes", NSStringFromOEGlobalButtonIdentifier(identifier));
            return;

        case OEGlobalButtonIdentifierUnknown :
        case OEGlobalButtonIdentifierCount :
        case OEGlobalButtonIdentifierFlag :
            NSAssert(NO, @"%@ is not a valid value", NSStringFromOEGlobalButtonIdentifier(identifier));
            return;
    }

    NSAssert(NO, @"Unknown identifier: %lx", identifier);
}

- (void)mouseDownAtPoint:(OEIntPoint)aPoint
{

}

- (void)mouseUpAtPoint
{

}

static void *_OEJoystickStateKeyForEvent(OEHIDEvent *anEvent)
{
    NSUInteger ret = [[anEvent deviceHandler] deviceIdentifier];

    switch([anEvent type])
    {
        case OEHIDEventTypeAxis      : ret |= [anEvent axis] << 32; break;
        case OEHIDEventTypeHatSwitch : ret |=         0x39lu << 32; break;
        default : return NULL;
    }

    return (void *)ret;
}

- (void)systemBindings:(OESystemBindings *)sender didSetEvent:(OEHIDEvent *)theEvent forBinding:(id)bindingDescription playerNumber:(NSUInteger)playerNumber
{
    // Ignore off state events.
    if([theEvent hasOffState]) return;

    switch([theEvent type])
    {
        case OEHIDEventTypeAxis :
        {
            // Register the axis for state watch.
            void *eventStateKey = _OEJoystickStateKeyForEvent(theEvent);
            CFDictionarySetValue(_joystickStates, eventStateKey, (void *)OEHIDEventAxisDirectionNull);

            OEKeyBindingDescription *keyDesc = [bindingDescription baseKey];
            if([bindingDescription isKindOfClass:[OEOrientedKeyGroupBindingDescription class]])
            {
                [_keyMap setSystemKey:[self emulatorKeyForKey:keyDesc player:playerNumber] forEvent:theEvent];
                [_keyMap setSystemKey:[self emulatorKeyForKey:[bindingDescription oppositeKey] player:playerNumber] forEvent:[theEvent axisEventWithOppositeDirection]];

                if([keyDesc isAnalogic])
                    CFDictionarySetValue(_analogSystemKeyTypes, eventStateKey, (void *)OEAxisSystemKeyTypeJointAnalog);

                return;
            }
            else if([keyDesc isAnalogic])
                CFDictionarySetValue(_analogSystemKeyTypes, eventStateKey, (void *)OEAxisSystemKeyTypeDisjointAnalog);
        }
            break;
        case OEHIDEventTypeHatSwitch :
            // Register the hat switch for state watch.
            CFDictionarySetValue(_joystickStates, _OEJoystickStateKeyForEvent(theEvent), (void *)OEHIDEventHatDirectionNull);

            if([bindingDescription isKindOfClass:[OEOrientedKeyGroupBindingDescription class]])
            {
                OEHIDEventHatDirection direction = [theEvent hatDirection];
                __block NSUInteger currentDir  = NORTH;

                if(direction & OEHIDEventHatDirectionNorth) currentDir = NORTH;
                if(direction & OEHIDEventHatDirectionEast)  currentDir = EAST;
                if(direction & OEHIDEventHatDirectionSouth) currentDir = SOUTH;
                if(direction & OEHIDEventHatDirectionWest)  currentDir = WEST;

                static OEHIDEventHatDirection dirs[HAT_COUNT] = { OEHIDEventHatDirectionNorth, OEHIDEventHatDirectionEast, OEHIDEventHatDirectionSouth, OEHIDEventHatDirectionWest };

                [bindingDescription enumerateKeysFromBaseKeyUsingBlock:
                 ^(OEKeyBindingDescription *key, BOOL *stop)
                 {
                     [_keyMap setSystemKey:[self emulatorKeyForKey:key player:playerNumber]
                                  forEvent:[theEvent hatSwitchEventWithDirection:dirs[currentDir % HAT_COUNT]]];

                     currentDir++;
                 }];
                return;
            }
            break;
        case OEHIDEventTypeKeyboard :
            if([theEvent keycode] == kHIDUsage_KeyboardEscape)
                _handlesEscapeKey = YES;
            break;
        default :
            break;
    }

    // General fallback for keyboard, button, trigger events and axis and hat switch events not attached to a grouped key.
    [_keyMap setSystemKey:[self emulatorKeyForKey:bindingDescription player:playerNumber] forEvent:theEvent];
}

- (void)systemBindings:(OESystemBindings *)sender didUnsetEvent:(OEHIDEvent *)theEvent forBinding:(id)bindingDescription playerNumber:(NSUInteger)playerNumber
{
    switch([theEvent type])
    {
        case OEHIDEventTypeAxis :
        {
            void *eventStateKey = _OEJoystickStateKeyForEvent(theEvent);
            CFDictionaryRemoveValue(_joystickStates, eventStateKey);

            if([bindingDescription isKindOfClass:[OEOrientedKeyGroupBindingDescription class]])
            {
                [_keyMap removeSystemKeyForEvent:theEvent];
                [_keyMap removeSystemKeyForEvent:[theEvent axisEventWithOppositeDirection]];

                if([[bindingDescription baseKey] isAnalogic])
                    CFDictionaryRemoveValue(_analogSystemKeyTypes, eventStateKey);
                return;
            }
            else if(![[bindingDescription oppositeKey] isAnalogic])
                CFDictionaryRemoveValue(_analogSystemKeyTypes, eventStateKey);
        }
            break;
        case OEHIDEventTypeHatSwitch :
            CFDictionaryRemoveValue(_joystickStates, _OEJoystickStateKeyForEvent(theEvent));

            if([bindingDescription isKindOfClass:[OEOrientedKeyGroupBindingDescription class]])
            {
                [_keyMap removeSystemKeyForEvent:[theEvent hatSwitchEventWithDirection:OEHIDEventHatDirectionNorth]];
                [_keyMap removeSystemKeyForEvent:[theEvent hatSwitchEventWithDirection:OEHIDEventHatDirectionEast] ];
                [_keyMap removeSystemKeyForEvent:[theEvent hatSwitchEventWithDirection:OEHIDEventHatDirectionSouth]];
                [_keyMap removeSystemKeyForEvent:[theEvent hatSwitchEventWithDirection:OEHIDEventHatDirectionWest] ];
                return;
            }
            break;
        case OEHIDEventTypeKeyboard :
            if([theEvent keycode] == kHIDUsage_KeyboardEscape)
                _handlesEscapeKey = NO;
        default :
            break;
    }

    [_keyMap removeSystemKeyForEvent:theEvent];
}

- (void)HIDKeyDown:(OEHIDEvent *)anEvent
{
    OESystemKey *key = [_keyMap systemKeyForEvent:anEvent];
    if(key != nil) _OEBasicSystemResponderPressSystemKey(self, key, [key isAnalogic]);
}

- (void)HIDKeyUp:(OEHIDEvent *)anEvent
{
    OESystemKey *key = [_keyMap systemKeyForEvent:anEvent];
    if(key != nil) _OEBasicSystemResponderReleaseSystemKey(self, key, [key isAnalogic]);
}

- (void)keyDown:(NSEvent *)theEvent
{
    if(_handlesEscapeKey) return;

    NSString *characters = [theEvent characters];
    if([characters length] > 0 && [characters characterAtIndex:0] == 0x1B)
        [super keyDown:theEvent];
}

- (void)keyUp:(NSEvent *)theEvent
{
    if(_handlesEscapeKey) return;

    NSString *characters = [theEvent characters];
    if([characters length] > 0 && [characters characterAtIndex:0] == 0x1B)
        [super keyUp:theEvent];
}

- (void)axisMoved:(OEHIDEvent *)anEvent
{
    OESystemKey             *key               = nil;
    void                    *joystickKey       = _OEJoystickStateKeyForEvent(anEvent);
    OEAxisSystemKeyType      keyType           = (OEAxisSystemKeyType)CFDictionaryGetValue(_analogSystemKeyTypes, joystickKey);
    OEHIDEventAxisDirection  previousDirection = (OEHIDEventAxisDirection)CFDictionaryGetValue(_joystickStates, joystickKey);
    OEHIDEventAxisDirection  currentDirection  = [anEvent direction];

    if(previousDirection == currentDirection)
    {
        if(keyType == OEAxisSystemKeyTypeDisjoint)
            return;

        key = [_keyMap systemKeyForEvent:anEvent] ? : [_keyMap systemKeyForEvent:[anEvent axisEventWithDirection:previousDirection]];
        if([key isAnalogic]) _OEBasicSystemResponderChangeAnalogSystemKey(self, key, [anEvent absoluteValue]);
        return;
    }

    CFDictionarySetValue(_joystickStates, joystickKey, (void *)currentDirection);

    if(keyType == OEAxisSystemKeyTypeJointAnalog)
    {
        key = [_keyMap systemKeyForEvent:anEvent] ? : [_keyMap systemKeyForEvent:[anEvent axisEventWithDirection:previousDirection]];
        _OEBasicSystemResponderChangeAnalogSystemKey(self, key, [anEvent absoluteValue]);
        return;
    }

    switch(previousDirection)
    {
        case OEHIDEventAxisDirectionNegative :
            if((key = [_keyMap systemKeyForEvent:[anEvent axisEventWithDirection:OEHIDEventAxisDirectionNegative]]))
            {
                if(keyType == OEAxisSystemKeyTypeDisjointAnalog && [key isAnalogic])
                    _OEBasicSystemResponderChangeAnalogSystemKey(self, key, 0.0);
                else
                    _OEBasicSystemResponderReleaseSystemKey(self, key, NO);
            }
            break;
        case OEHIDEventAxisDirectionPositive :
            if((key = [_keyMap systemKeyForEvent:[anEvent axisEventWithDirection:OEHIDEventAxisDirectionPositive]]))
            {
                if(keyType == OEAxisSystemKeyTypeDisjointAnalog && [key isAnalogic])
                    _OEBasicSystemResponderChangeAnalogSystemKey(self, key, 0.0);
                else
                    _OEBasicSystemResponderReleaseSystemKey(self, key, NO);
            }
        default :
            break;
    }

    if(currentDirection != OEHIDEventAxisDirectionNull && (key = [_keyMap systemKeyForEvent:anEvent]))
    {
        if(keyType == OEAxisSystemKeyTypeDisjointAnalog && [key isAnalogic])
            _OEBasicSystemResponderChangeAnalogSystemKey(self, key, [anEvent absoluteValue]);
        else
            _OEBasicSystemResponderPressSystemKey(self, key, NO);
    }
}

- (void)triggerPull:(OEHIDEvent *)anEvent;
{
    OESystemKey *key = [_keyMap systemKeyForEvent:anEvent];
    if(key != nil)
    {
        if([key isAnalogic])
            _OEBasicSystemResponderChangeAnalogSystemKey(self, key, [anEvent absoluteValue]);
        else
            _OEBasicSystemResponderPressSystemKey(self, key, NO);
    }
}

- (void)triggerRelease:(OEHIDEvent *)anEvent;
{
    OESystemKey *key = [_keyMap systemKeyForEvent:anEvent];
    if(key != nil) _OEBasicSystemResponderReleaseSystemKey(self, key, [key isAnalogic]);
}

- (void)buttonDown:(OEHIDEvent *)anEvent
{
    OESystemKey *key = [_keyMap systemKeyForEvent:anEvent];
    if(key != nil) _OEBasicSystemResponderPressSystemKey(self, key, [key isAnalogic]);
}

- (void)buttonUp:(OEHIDEvent *)anEvent
{
    OESystemKey *key = [_keyMap systemKeyForEvent:anEvent];
    if(key != nil) _OEBasicSystemResponderReleaseSystemKey(self, key, [key isAnalogic]);
}

- (void)hatSwitchChanged:(OEHIDEvent *)anEvent;
{
    void                   *joystickKey       = _OEJoystickStateKeyForEvent(anEvent);

    OEHIDEventHatDirection  previousDirection = (OEHIDEventHatDirection)CFDictionaryGetValue(_joystickStates, joystickKey);

    OEHIDEventHatDirection  direction = [anEvent hatDirection];
    OEHIDEventHatDirection  diff      = previousDirection ^ direction;

    void (^directionDiff)(OEHIDEventHatDirection dir) =
    ^(OEHIDEventHatDirection dir)
    {
        if(diff & dir) return;

        OESystemKey *key = [_keyMap systemKeyForEvent:[anEvent hatSwitchEventWithDirection:dir]];
        if(key == nil) return;
        
        if([key isAnalogic])
        {
            _OEBasicSystemResponderChangeAnalogSystemKey(self, key, !!(direction & dir));
            return;
        }

        if(direction & dir)
            _OEBasicSystemResponderPressSystemKey(self, key, NO);
        else
            _OEBasicSystemResponderReleaseSystemKey(self, key, NO);
    };

    directionDiff(OEHIDEventHatDirectionNorth);
    directionDiff(OEHIDEventHatDirectionEast);
    directionDiff(OEHIDEventHatDirectionSouth);
    directionDiff(OEHIDEventHatDirectionWest);

    CFDictionarySetValue(_joystickStates, joystickKey, (void *)direction);
}

- (void)mouseDown:(NSEvent *)theEvent
{
    OEIntPoint point = [theEvent locationInGameView];
    [self mouseDownAtPoint:point];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
    OEIntPoint point = [theEvent locationInGameView];
    [self mouseDownAtPoint:point];
}

- (void)mouseUp:(NSEvent *)theEvent
{
    [self mouseUpAtPoint];
}

@end

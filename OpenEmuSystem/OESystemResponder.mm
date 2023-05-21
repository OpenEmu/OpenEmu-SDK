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

extern "C" {
#import "OESystemResponder.h"
#import "NSResponder+OEHIDAdditions.h"
#import "OEEvent.h"
#import "OEDeviceHandler.h"
#import "OEHIDEvent_Internal.h"
#import "OEKeyBindingDescription.h"
#import "OEKeyBindingGroupDescription.h"
#import "OESystemController.h"
#import <OpenEmuBase/OpenEmuBase.h>
#import <objc/runtime.h>
}
#include <cmath>
#include <unordered_map>
#include <vector>
#include <set>

NS_ASSUME_NONNULL_BEGIN

enum { NORTH, EAST, SOUTH, WEST, HAT_COUNT };

typedef enum : NSUInteger {
    OEAxisSystemKeyTypeDisjoint       = 0,
    OEAxisSystemKeyTypeJointAnalog,
    OEAxisSystemKeyTypeJointDigital,
} OEAxisSystemKeyType;

typedef uint64_t OEJoystickStatusKey;

typedef struct {
    OEHIDEventAxisDirection direction;
    CGFloat value;
} OEJoystickState_Axis;

typedef union {
    OEJoystickState_Axis axisEvent;
    OEHIDEventHatDirection hatEvent;
} OEJoystickState;


typedef enum : NSInteger {
    OEPlayerRapidFireSetupModeNone = 0,
    OEPlayerRapidFireSetupModeToggle,
    OEPlayerRapidFireSetupModeClear
} OEPlayerRapidFireSetupMode;

typedef struct OEPlayerButtonRapidFireState {
    /** YES if the current state of the button is pressed,
     *  NO otherwise. */
    BOOL state = NO;
    /** The current position in the rapid fire cycle. Goes from 0.0 (start of
     *  cycle) to 1.0 (end of cycle), then restarts back at 0.0. */
    NSTimeInterval timebase = 0.0;
} OEPlayerButtonRapidFireState;

typedef struct OEPlayerRapidFireState {
    /** OEPlayerRapidFireSetupModeToggle while rapid fire toggle is pressed,
     *  OEPlayerRapidFireSetupModeClear while rapid fire clear is pressed. */
    OEPlayerRapidFireSetupMode setupMode = OEPlayerRapidFireSetupModeNone;
    /** Buttons currently pressed by this player, outside of rapid fire */
    NSMutableSet <OESystemKey *> *pressedButtons = [NSMutableSet set];
    /** Buttons with rapid fire enabled. */
    NSMutableSet <OESystemKey *> *rapidFireButtons = [NSMutableSet set];
    /** Rapid fire states for all currently pressed buttons with rapid fire enabled. */
    std::unordered_map<NSInteger, OEPlayerButtonRapidFireState> currentButtonStates;
} OEPlayerRapidFireState;

/** Interval of a full rapid fire cycle, consisting of (1) a button press and
 *  (2) a button release. */
#define OE_RAPID_FIRE_INTERVAL   (1.0 / 10.0)
/** Fraction of cycle between the initial button press and the button release
 *  for buttons with rapid fire active.
 *  For example, if OE_RAPID_FIRE_INTERVAL=0.1, 0.25 means that for 0.025 seconds
 *  the button will be pressed, and for the remaining 0.075 seconds the button
 *  will be released. */
#define OE_RAPID_FIRE_DUTY_CYCLE (0.25)


#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation OESystemResponder
{
    std::unordered_map<OEJoystickStatusKey, OEJoystickState> _joystickStates;
    std::unordered_map<OEJoystickStatusKey, OEAxisSystemKeyType> _axisSystemKeyTypes;
    
    std::set<NSInteger> _rapidFireKeyBlacklist;
    std::vector<OEPlayerRapidFireState> _rapidFireState;
    
    BOOL _handlesEscapeKey;
    double _analogToDigitalThreshold;
    NSMutableDictionary<OEDeviceHandlerPlaceholder *, NSMutableArray<void (^)(void)>*>* _pendingDeviceHandlerBindings;
    id _token;
}

+ (void)load
{
    NSUserDefaults *ud = [NSUserDefaults oe_applicationUserDefaults];
    [ud registerDefaults:@{
        @"OESystemResponderADCThreshold": @0.5
    }];
}

- (instancetype)init
{
    return nil;
}

- (instancetype)initWithController:(OESystemController *)controller;
{
    if((self = [super init]))
    {
        _controller = controller;
        _keyMap = [[OEBindingMap alloc] init];
        _pendingDeviceHandlerBindings = [NSMutableDictionary new];
        
        __weak __auto_type weakSelf = self;
        _token = [NSNotificationCenter.defaultCenter addObserverForName:OEDeviceHandlerPlaceholderOriginalDeviceDidBecomeAvailableNotification
                                                                 object:nil
                                                                  queue:NSOperationQueue.mainQueue
                                                             usingBlock:^(NSNotification * _Nonnull note) {
            __auto_type self = weakSelf;
            if (self == nil) return;
            
            if (![note.object isKindOfClass:OEDeviceHandlerPlaceholder.class]) {
                return;
            }
            
            OEDeviceHandlerPlaceholder * placeholder = note.object;
            NSArray<void (^)(void)> * pendingBlocks = self->_pendingDeviceHandlerBindings[placeholder];
            for (void (^block)(void) in pendingBlocks) {
                block();
            }
            [self->_pendingDeviceHandlerBindings removeObjectForKey:placeholder];
        }];
        
        /* Create the list of buttons that should not be affected by the rapid fire
         * toggle. Basically, we remove all directional buttons, by exploiting binding
         * groups to enumerate them. */
        [controller.keyBindingGroupDescriptions enumerateKeysAndObjectsUsingBlock:^(NSString *name, OEKeyBindingGroupDescription *group, BOOL *stop) {
            for (OEKeyBindingDescription *key in group.keys) {
                if (!key.isAnalogic)
                    _rapidFireKeyBlacklist.insert(key.index);
            }
        }];
        
        NSUserDefaults *ud = [NSUserDefaults oe_applicationUserDefaults];
        NSNumber *val = [ud objectForKey:@"OESystemResponderADCThreshold"];
        if (val && [val isKindOfClass:[NSNumber class]]) {
            _analogToDigitalThreshold = val.doubleValue;
        } else {
            _analogToDigitalThreshold = 0.5;
        }
    }

    return self;
}

- (void)deinit
{
    if (_token != nil) {
        [NSNotificationCenter.defaultCenter removeObserver:_token];
        _token = nil;
    }
}

+ (Protocol *)gameSystemResponderClientProtocol;
{
    return @protocol(OESystemResponderClient);
}

- (void)setClient:(nullable id<OESystemResponderClient>)value;
{
    if(_client != value)
    {
        Protocol *p = [[self class] gameSystemResponderClientProtocol];
        
        NSAssert1(protocol_conformsToProtocol(p, @protocol(OESystemResponderClient)), @"Client protocol %@ does not conform to protocol OEGameSystemResponderClient", NSStringFromProtocol(p));
        
        //NSAssert2(value == nil || [value conformsToProtocol:p], @"Client %@ does not conform to protocol %@.", value, NSStringFromProtocol(p));
        
        _client = value;
    }
}

static OEJoystickStatusKey _OEJoystickStateKeyForEvent(OEHIDEvent *anEvent)
{
    uint64_t ret = (uint64_t)[[anEvent deviceHandler] deviceIdentifier];

    switch([anEvent type])
    {
        case OEHIDEventTypeAxis      : ret |= [anEvent axis] << 32; break;
        case OEHIDEventTypeHatSwitch : ret |=         0x39lu << 32; break;
        default : NSCAssert(NO, @"Wrong type");
    }

    return (OEJoystickStatusKey)ret;
}

#pragma mark - Rapid Fire

static inline BOOL _OESystemResponderHandleRapidFirePressForKey(OESystemResponder *self, OESystemKey *key)
{
    NSUInteger keyId = key.key;
    if (self->_rapidFireKeyBlacklist.count(keyId))
        return NO;
        
    NSUInteger player = key.player;
    if (self->_rapidFireState.size() <= player)
        self->_rapidFireState.resize(player+1);
    OEPlayerRapidFireState& rfstate = self->_rapidFireState[player];
    [rfstate.pressedButtons addObject:key];
    
    switch (rfstate.setupMode) {
        case OEPlayerRapidFireSetupModeToggle:
            [rfstate.rapidFireButtons addObject:key];
            return YES;
            
        case OEPlayerRapidFireSetupModeClear:
            [rfstate.rapidFireButtons removeObject:key];
            if (!rfstate.currentButtonStates[keyId].state)
                [self pressEmulatorKey:key];
            rfstate.currentButtonStates.erase(keyId);
            return YES;
            
        case OEPlayerRapidFireSetupModeNone:
            return [rfstate.rapidFireButtons containsObject:key];
    }
}

static inline BOOL _OESystemResponderHandleRapidFireReleaseForKey(OESystemResponder *self, OESystemKey *key)
{
    NSUInteger keyId = key.key;
    if (self->_rapidFireKeyBlacklist.count(keyId))
        return NO;
        
    NSUInteger player = key.player;
    if (self->_rapidFireState.size() <= player)
        return NO;
        
    OEPlayerRapidFireState& rfstate = self->_rapidFireState[player];
    [rfstate.pressedButtons removeObject:key];
    
    switch (rfstate.setupMode) {
        case OEPlayerRapidFireSetupModeToggle:
        case OEPlayerRapidFireSetupModeNone:
            if ([rfstate.rapidFireButtons containsObject:key]) {
                if (rfstate.currentButtonStates[keyId].state)
                    [self releaseEmulatorKey:key];
                rfstate.currentButtonStates.erase(keyId);
                return YES;
            }
            return NO;
            
        case OEPlayerRapidFireSetupModeClear:
            return NO;
    }
}

static inline void _OESystemResponderRapidFireFrameCallback(OESystemResponder *self, NSTimeInterval frameInterval)
{
    NSInteger player = 0;
    for (OEPlayerRapidFireState& rfstate: self->_rapidFireState) {
        for (OESystemKey *key in rfstate.pressedButtons) {
            if (![rfstate.rapidFireButtons containsObject:key])
                continue;
                
            OEPlayerButtonRapidFireState& bstate = rfstate.currentButtonStates[key.key];
            BOOL newState = bstate.timebase < OE_RAPID_FIRE_DUTY_CYCLE;
            if (newState != bstate.state) {
                bstate.state = newState;
                if (newState) {
                    [self pressEmulatorKey:key];
                } else {
                    [self releaseEmulatorKey:key];
                }
            }
            
            /* If the frame rate is too low, fall back to 50% duty cycle
             * with period = 1 / frame rate */
            bstate.timebase += std::min(OE_RAPID_FIRE_DUTY_CYCLE, frameInterval / OE_RAPID_FIRE_INTERVAL);
            if (bstate.timebase >= 1.0 - DBL_EPSILON) {
                /* We intentionally discard the remainder of the previous
                 * cycle to keep a constant periodicity, at the expense of
                 * some imprecision in the actual rate wrt the value of
                 * OE_RAPID_FIRE_INTERVAL */
                bstate.timebase = 0.0;
            }
        }
        player++;
    }
}

- (void)_pressRapidFireToggleForPlayer:(NSInteger)player
{
    if (self->_rapidFireState.size() <= player)
        self->_rapidFireState.resize(player+1);
    OEPlayerRapidFireState& rfstate = self->_rapidFireState[player];
    
    if (rfstate.setupMode != OEPlayerRapidFireSetupModeNone)
        return;
    
    rfstate.setupMode = OEPlayerRapidFireSetupModeToggle;
    for (OESystemKey *key in rfstate.pressedButtons) {
        if (![rfstate.rapidFireButtons containsObject:key]) {
            [rfstate.rapidFireButtons addObject:key];
            rfstate.currentButtonStates[key.key].state = YES;
        }
    }
    
    [self.client setFrameCallback:^(NSTimeInterval frameInterval) {
        _OESystemResponderRapidFireFrameCallback(self, frameInterval);
    }];
}

- (void)_releaseRapidFireToggleForPlayer:(NSInteger)player
{
    if (self->_rapidFireState.size() <= player)
        self->_rapidFireState.resize(player+1);
    OEPlayerRapidFireState& rfstate = self->_rapidFireState[player];
    
    if (rfstate.setupMode != OEPlayerRapidFireSetupModeToggle)
        return;
    
    rfstate.setupMode = OEPlayerRapidFireSetupModeNone;
}

- (void)_pressRapidFireClearForPlayer:(NSInteger)player
{
    if (self->_rapidFireState.size() <= player)
        return;
    OEPlayerRapidFireState& rfstate = self->_rapidFireState[player];
    
    if (rfstate.setupMode != OEPlayerRapidFireSetupModeNone)
        return;
    rfstate.setupMode = OEPlayerRapidFireSetupModeClear;
        
    for (OESystemKey *key in rfstate.rapidFireButtons) {
        if ([rfstate.pressedButtons containsObject:key]) {
            if (!rfstate.currentButtonStates[key.key].state)
                [self pressEmulatorKey:key];
            rfstate.currentButtonStates.erase(key.key);
        }
    }
    [rfstate.rapidFireButtons minusSet:rfstate.pressedButtons];
}

- (void)_releaseRapidFireClearForPlayer:(NSInteger)player
{
    if (self->_rapidFireState.size() <= player)
        return;
    OEPlayerRapidFireState& rfstate = self->_rapidFireState[player];
    
    if (rfstate.setupMode != OEPlayerRapidFireSetupModeClear)
        return;
    rfstate.setupMode = OEPlayerRapidFireSetupModeNone;
}

- (void)_resetRapidFireForPlayer:(NSInteger)player
{
    if (self->_rapidFireState.size() <= player)
        return;
    OEPlayerRapidFireState& rfstate = self->_rapidFireState[player];
    
    if (rfstate.setupMode != OEPlayerRapidFireSetupModeNone)
        return;
    
    for (OESystemKey *key in rfstate.pressedButtons) {
        if ([rfstate.rapidFireButtons containsObject:key])
            if (!rfstate.currentButtonStates[key.key].state)
                [self pressEmulatorKey:key];
    }
    [rfstate.rapidFireButtons removeAllObjects];
    rfstate.currentButtonStates.clear();
}

#pragma mark - Event Funneling Functions

static inline void _OEBasicSystemResponderPressSystemKey(OESystemResponder *self, OESystemKey *key, BOOL isAnalogic)
{
    if(key == nil) return;

    [[self client] performBlock:^{
        if([key isGlobalButtonKey])
        {
            OEGlobalButtonIdentifier ident = (OEGlobalButtonIdentifier)([key key] & ~OEGlobalButtonIdentifierFlag);
            if(isAnalogic)
                [self changeAnalogGlobalButtonIdentifier:ident value:1.0];
            else
                [self pressGlobalButtonWithIdentifier:ident player:key.player];
        }
        else
        {
            if(isAnalogic)
                [self changeAnalogEmulatorKey:key value:1.0];
            else {
                if (!_OESystemResponderHandleRapidFirePressForKey(self, key))
                    [self pressEmulatorKey:key];
            }
        }
    }];
}

static inline void _OEBasicSystemResponderReleaseSystemKey(OESystemResponder *self, OESystemKey *key, BOOL isAnalogic)
{
    if(key == nil) return;

    [[self client] performBlock:^{
        if([key isGlobalButtonKey])
        {
            OEGlobalButtonIdentifier ident = (OEGlobalButtonIdentifier)([key key] & ~OEGlobalButtonIdentifierFlag);
            if(isAnalogic)
                [self changeAnalogGlobalButtonIdentifier:ident value:0.0];
            else
                [self releaseGlobalButtonWithIdentifier:ident player:key.player];
        }
        else
        {
            if(isAnalogic)
                [self changeAnalogEmulatorKey:key value:0.0];
            else {
                if (!_OESystemResponderHandleRapidFireReleaseForKey(self, key))
                    [self releaseEmulatorKey:key];
            }
        }
    }];
}

static inline void _OEBasicSystemResponderChangeAnalogSystemKey(OESystemResponder *self, OESystemKey *key, CGFloat value)
{
    if(key == nil) return;

    [[self client] performBlock:^{
        if([key isGlobalButtonKey])
            [self changeAnalogGlobalButtonIdentifier:(OEGlobalButtonIdentifier)([key key] & ~OEGlobalButtonIdentifierFlag) value:value];
        else
            [self changeAnalogEmulatorKey:key value:value];
    }];
}

#pragma mark - Emulator Button Dispatching

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

#pragma mark - Global Button Dispatching

#define SEND_ACTION(sel) do { \
dispatch_block_t blk = ^{ [[self globalEventsHandler] sel self]; }; \
if([NSThread isMainThread]) blk(); \
else dispatch_async(dispatch_get_main_queue(), blk); \
} while(NO)

#define SEND_ACTION2(sel, param) do { \
dispatch_block_t blk = ^{ [[self globalEventsHandler] sel param]; }; \
if([NSThread isMainThread]) blk(); \
else dispatch_async(dispatch_get_main_queue(), blk); \
} while(NO)

- (void)pressGlobalButtonWithIdentifier:(OEGlobalButtonIdentifier)identifier player:(NSInteger)player
{
    // FIXME: We currently only trigger these actions on release, but maybe some of these (like StepFrameBackward and StepFrameForward) should allow key repeat
    switch(identifier)
    {
        case OEGlobalButtonIdentifierStepFrameBackward :
            SEND_ACTION(stepGameplayFrameBackward:);
            [[self client] stepFrameBackward];
            return;
        case OEGlobalButtonIdentifierStepFrameForward :
            SEND_ACTION(stepGameplayFrameForward:);
            [[self client] stepFrameForward];
            return;
        case OEGlobalButtonIdentifierFastForward :
            SEND_ACTION2(fastForwardGameplay:, YES);
            [[self client] fastForward:YES];
            return;
        case OEGlobalButtonIdentifierRewind :
            SEND_ACTION2(rewindGameplay:, YES);
            [[self client] rewind:YES];
            return;
        case OEGlobalButtonIdentifierNextDisplayMode :
            SEND_ACTION(nextDisplayMode:);
            return;
        case OEGlobalButtonIdentifierLastDisplayMode :
            SEND_ACTION(lastDisplayMode:);
            return;
        case OEGlobalButtonIdentifierRapidFireToggle:
            [self _pressRapidFireToggleForPlayer:player];
            return;
        case OEGlobalButtonIdentifierRapidFireClear:
            [self _pressRapidFireClearForPlayer:player];
            return;
        case OEGlobalButtonIdentifierRapidFireReset:
            [self _resetRapidFireForPlayer:player];
            return;
        default :
            break;
    }
}

- (void)releaseGlobalButtonWithIdentifier:(OEGlobalButtonIdentifier)identifier player:(NSInteger)player
{
    switch(identifier)
    {
        case OEGlobalButtonIdentifierSaveState :
            SEND_ACTION(saveState:);
            return;
        case OEGlobalButtonIdentifierLoadState :
            SEND_ACTION(loadState:);
            return;
        case OEGlobalButtonIdentifierQuickSave :
            SEND_ACTION(quickSave:);
            return;
        case OEGlobalButtonIdentifierQuickLoad :
            SEND_ACTION(quickLoad:);
            return;
        case OEGlobalButtonIdentifierFullScreen :
            SEND_ACTION(toggleFullScreen:);
            return;
        case OEGlobalButtonIdentifierMute :
            SEND_ACTION(toggleAudioMute:);
            return;
        case OEGlobalButtonIdentifierVolumeDown :
            SEND_ACTION(volumeDown:);
            return;
        case OEGlobalButtonIdentifierVolumeUp :
            SEND_ACTION(volumeUp:);
            return;
        case OEGlobalButtonIdentifierStop :
            SEND_ACTION(stopEmulation:);
            return;
        case OEGlobalButtonIdentifierReset :
            SEND_ACTION(resetEmulation:);
            return;
        case OEGlobalButtonIdentifierPause :
            SEND_ACTION(toggleEmulationPaused:);
            return;
        case OEGlobalButtonIdentifierStepFrameBackward :
            return;
        case OEGlobalButtonIdentifierStepFrameForward :
            return;
        case OEGlobalButtonIdentifierFastForward :
            SEND_ACTION2(fastForwardGameplay:, NO);
            [[self client] fastForward:NO];
            return;
        case OEGlobalButtonIdentifierRewind :
            SEND_ACTION2(rewindGameplay:, NO);
            [[self client] rewind:NO];
            return;
        case OEGlobalButtonIdentifierNextDisplayMode :
            return;
        case OEGlobalButtonIdentifierLastDisplayMode :
            return;
        case OEGlobalButtonIdentifierScreenshot :
            SEND_ACTION(takeScreenshot:);
            return;
        case OEGlobalButtonIdentifierRapidFireToggle:
            [self _releaseRapidFireToggleForPlayer:player];
            return;
        case OEGlobalButtonIdentifierRapidFireClear:
            [self _releaseRapidFireClearForPlayer:player];
            return;
        case OEGlobalButtonIdentifierRapidFireReset:
            return;

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
        //case OEGlobalButtonIdentifierRewind :
        //    [[self client] rewindAtSpeed:value];
        //    return;
        //case OEGlobalButtonIdentifierFastForward :
        //    [[self client] fastForwardAtSpeed:value];
        //    return;
        case OEGlobalButtonIdentifierSlowMotion :
            [[self client] slowMotionAtSpeed:value];
            return;

        case OEGlobalButtonIdentifierFastForward :
        case OEGlobalButtonIdentifierRewind :
        case OEGlobalButtonIdentifierSaveState :
        case OEGlobalButtonIdentifierLoadState :
        case OEGlobalButtonIdentifierQuickSave :
        case OEGlobalButtonIdentifierQuickLoad :
        case OEGlobalButtonIdentifierFullScreen :
        case OEGlobalButtonIdentifierMute :
        case OEGlobalButtonIdentifierVolumeDown :
        case OEGlobalButtonIdentifierVolumeUp :
        case OEGlobalButtonIdentifierStop :
        case OEGlobalButtonIdentifierReset :
        case OEGlobalButtonIdentifierPause :
        case OEGlobalButtonIdentifierStepFrameBackward :
        case OEGlobalButtonIdentifierStepFrameForward :
        case OEGlobalButtonIdentifierNextDisplayMode :
        case OEGlobalButtonIdentifierLastDisplayMode :
        case OEGlobalButtonIdentifierScreenshot :
        case OEGlobalButtonIdentifierRapidFireToggle :
        case OEGlobalButtonIdentifierRapidFireClear :
        case OEGlobalButtonIdentifierRapidFireReset :
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

#pragma mark - Bindings Change Handling

- (OESystemKey *)emulatorKeyForKey:(OEKeyBindingDescription *)aKey player:(NSUInteger)thePlayer;
{
    return [OESystemKey systemKeyWithKey:[aKey index] player:thePlayer isAnalogic:[aKey isAnalogic]];
}

- (void)updateBindingForEvent:(OEHIDEvent *)theEvent block:(void (^)(void))block
{
    if (!theEvent.hasDeviceHandlerPlaceholder) {
        block();
        return;
    }
    
    if (![theEvent.deviceHandler isKindOfClass:OEDeviceHandlerPlaceholder.class]) {
        return;
    }
    
    OEDeviceHandlerPlaceholder *placeholder = theEvent.deviceHandler;
    
    NSMutableArray<void (^)(void)> *pendingBlocks = _pendingDeviceHandlerBindings[placeholder];
    if (pendingBlocks == nil) {
        pendingBlocks = [NSMutableArray new];
    }
    
    __block void (^blockCopy)(void) = [block copy];
    [pendingBlocks addObject:^{
        [theEvent resolveDeviceHandlerPlaceholder];
        blockCopy();
    }];
    
    _pendingDeviceHandlerBindings[placeholder] = pendingBlocks;
}

- (void)systemBindingsDidSetEvent:(OEHIDEvent *)theEvent forBinding:(__kindof OEBindingDescription *)bindingDescription playerNumber:(NSUInteger)playerNumber
{
    __weak __auto_type weakSelf = self;
    [self updateBindingForEvent:theEvent block:^{
        __auto_type self = weakSelf;
        if (self == nil) return;
        
        [self OE_systemBindingsDidSetEvent:theEvent forBinding:bindingDescription playerNumber:playerNumber];
    }];
}

- (void)OE_systemBindingsDidSetEvent:(OEHIDEvent *)theEvent forBinding:(__kindof OEBindingDescription *)bindingDescription playerNumber:(NSUInteger)playerNumber
{
    // Ignore off state events.
    if([theEvent hasOffState]) return;

    switch([theEvent type])
    {
        case OEHIDEventTypeAxis :
        {
            // Register the axis for state watch.
            OEJoystickStatusKey eventStateKey = _OEJoystickStateKeyForEvent(theEvent);
            _joystickStates[eventStateKey] = { .axisEvent={OEHIDEventAxisDirectionNull, 0.0} };

            if (![bindingDescription isKindOfClass:[OEOrientedKeyGroupBindingDescription class]]) {
                _axisSystemKeyTypes[eventStateKey] = OEAxisSystemKeyTypeDisjoint;
                break;
            }

            OEKeyBindingDescription *keyDesc = [bindingDescription baseKey];
            [_keyMap setSystemKey:[self emulatorKeyForKey:keyDesc player:playerNumber] forEvent:theEvent];
            [_keyMap setSystemKey:[self emulatorKeyForKey:[bindingDescription oppositeKey] player:playerNumber] forEvent:[theEvent axisEventWithOppositeDirection]];

            _axisSystemKeyTypes[eventStateKey] = [keyDesc isAnalogic] ?
                OEAxisSystemKeyTypeJointAnalog :
                OEAxisSystemKeyTypeJointDigital;
            return;
        }
            break;
        case OEHIDEventTypeHatSwitch :
            // Register the hat switch for state watch.
            _joystickStates[_OEJoystickStateKeyForEvent(theEvent)] = { .hatEvent=OEHIDEventHatDirectionNull };

            if (![bindingDescription isKindOfClass:[OEOrientedKeyGroupBindingDescription class]])
                break;

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
                    [self->_keyMap setSystemKey:[self emulatorKeyForKey:key player:playerNumber]
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

- (void)systemBindingsDidUnsetEvent:(OEHIDEvent *)theEvent forBinding:(__kindof OEBindingDescription *)bindingDescription playerNumber:(NSUInteger)playerNumber
{
    __weak __auto_type weakSelf = self;
    [self updateBindingForEvent:theEvent block:^{
        __auto_type self = weakSelf;
        if (self == nil) return;
        
        [self OE_systemBindingsDidUnsetEvent:theEvent forBinding:bindingDescription playerNumber:playerNumber];
    }];
}

- (void)OE_systemBindingsDidUnsetEvent:(OEHIDEvent *)theEvent forBinding:(__kindof OEBindingDescription *)bindingDescription playerNumber:(NSUInteger)playerNumber
{
    switch([theEvent type])
    {
        case OEHIDEventTypeAxis :
        {
            OEJoystickStatusKey eventStateKey = _OEJoystickStateKeyForEvent(theEvent);
            _joystickStates.erase(eventStateKey);
            _axisSystemKeyTypes.erase(eventStateKey);

            if([bindingDescription isKindOfClass:[OEOrientedKeyGroupBindingDescription class]])
            {
                [_keyMap removeSystemKeyForEvent:theEvent];
                [_keyMap removeSystemKeyForEvent:[theEvent axisEventWithOppositeDirection]];
                return;
            }
        }
            break;
        case OEHIDEventTypeHatSwitch :
            _joystickStates.erase(_OEJoystickStateKeyForEvent(theEvent));

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

#pragma mark - Event Responder Method

- (void)mouseDownAtPoint:(OEIntPoint)aPoint
{

}

- (void)mouseUpAtPoint
{

}

- (void)rightMouseDownAtPoint:(OEIntPoint)aPoint
{
    
}

- (void)rightMouseUpAtPoint
{
    
}

- (void)mouseMovedAtPoint:(OEIntPoint)aPoint;
{
    
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
    OEJoystickStatusKey     joystickKey       = _OEJoystickStateKeyForEvent(anEvent);
    OEAxisSystemKeyType     keyType           = _axisSystemKeyTypes[joystickKey];
    OEJoystickState_Axis    prevState         = _joystickStates[joystickKey].axisEvent;
    OEHIDEventAxisDirection currentDirection  = [anEvent direction];
    CGFloat                 currentValue      = [anEvent value];

    _joystickStates[joystickKey] = { .axisEvent={currentDirection, currentValue} };
    
    if(keyType == OEAxisSystemKeyTypeJointAnalog) {
        OESystemKey *key;
        
        if (currentDirection == OEHIDEventAxisDirectionNull) {
            if (prevState.direction == OEHIDEventAxisDirectionNull) {
                NSLog(@"-axisMoved: invoked but axis didn't move");
                return;
            }
            key = [_keyMap systemKeyForEvent:[anEvent axisEventWithDirection:prevState.direction]];
        } else {
            key = [_keyMap systemKeyForEvent:anEvent];
        }
        _OEBasicSystemResponderChangeAnalogSystemKey(self, key, [anEvent absoluteValue]);
        return;
    }

    OESystemKey *prevKey = [_keyMap systemKeyForEvent:[anEvent axisEventWithDirection:prevState.direction]];
    OESystemKey *currKey = [_keyMap systemKeyForEvent:anEvent];
    
    /* break previous key, if needed */
    if (prevKey) {
        NSAssert(prevState.direction != OEHIDEventAxisDirectionNull, @"bindings to null directions shouldn't exist");
        if (prevKey && [prevKey isAnalogic]) {
            if (prevState.direction != currentDirection) {
                _OEBasicSystemResponderChangeAnalogSystemKey(self, prevKey, 0.0);
            }
        } else {
            if (ABS(prevState.value) >= _analogToDigitalThreshold &&
                (ABS(currentValue) < _analogToDigitalThreshold || currentDirection != prevState.direction)) {
                _OEBasicSystemResponderReleaseSystemKey(self, prevKey, NO);
            }
        }
    }
    
    /* make the new key, if needed */
    if (currKey) {
        NSAssert(currentDirection != OEHIDEventAxisDirectionNull, @"bindings to null directions shouldn't exist");
        if ([currKey isAnalogic]) {
            _OEBasicSystemResponderChangeAnalogSystemKey(self, currKey, [anEvent absoluteValue]);
        } else {
            if ((ABS(prevState.value) < _analogToDigitalThreshold || currentDirection != prevState.direction) &&
                ABS(currentValue) >= _analogToDigitalThreshold) {
                _OEBasicSystemResponderPressSystemKey(self, currKey, NO);
            }
        }
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
    OEJoystickStatusKey     joystickKey       = _OEJoystickStateKeyForEvent(anEvent);

    OEHIDEventHatDirection  previousDirection = _joystickStates[joystickKey].hatEvent;

    OEHIDEventHatDirection  direction = [anEvent hatDirection];
    OEHIDEventHatDirection  diff      = (OEHIDEventHatDirection)(previousDirection ^ direction);

    void (^directionDiff)(OEHIDEventHatDirection dir) =
    ^(OEHIDEventHatDirection dir)
    {
        if(!(diff & dir)) return;

        OESystemKey *key = [self->_keyMap systemKeyForEvent:[anEvent hatSwitchEventWithDirection:dir]];
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

    _joystickStates[joystickKey] = { .hatEvent=direction };
}

- (void)handleMouseEvent:(OEEvent *)event
{
    OEIntPoint point = [event locationInGameView];

    [_client performBlock:^{
        switch(event.type)
        {
            case NSEventTypeLeftMouseDown :
            case NSEventTypeLeftMouseDragged :
                [self mouseDownAtPoint:point];
                break;
            case NSEventTypeLeftMouseUp :
                [self mouseUpAtPoint];
                break;
            case NSEventTypeRightMouseDown :
            case NSEventTypeRightMouseDragged :
                [self rightMouseDownAtPoint:point];
                break;
            case NSEventTypeRightMouseUp :
                [self rightMouseUpAtPoint];
                break;
            case NSEventTypeMouseMoved :
                [self mouseMovedAtPoint:point];
                break;
            default :
                break;
        }
    }];
}

@end

#pragma clang diagnostic pop

NS_ASSUME_NONNULL_END

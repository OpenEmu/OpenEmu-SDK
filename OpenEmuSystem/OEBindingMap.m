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

#import "OEBindingMap.h"
#import "OEKeyBindingDescription.h"
#import "OESystemController.h"
#import "OEHIDEvent_Internal.h"

@interface OEBindingMap ()
{
    NSMutableDictionary *_keyMap;
    dispatch_queue_t     _queue;
}

@end

static Boolean _OEBindingMapKeyEqualCallBack(OEHIDEvent *value1, OEHIDEvent *value2)
{
    return [value1 isBindingEqualToEvent:value2];
}

static CFHashCode _OEBindingMapKeyHashCallBack(OEHIDEvent *value)
{
    return [value bindingHash];
}

@implementation OEBindingMap

- (instancetype)init
{
    return [self initWithCapacity:16];
}

- (instancetype)initWithSystemController:(OESystemController *)aController;
{
    NSUInteger numberOfPlayers = aController.numberOfPlayers;
    NSUInteger numberOfKeys    = aController.systemKeyBindingsDescriptions.count;

    return [self initWithCapacity:numberOfPlayers * numberOfKeys * 2];
}

- (instancetype)initWithCapacity:(NSUInteger)totalNumberOfKeys;
{
    if((self = [super init]))
    {
        CFDictionaryKeyCallBacks keyCallbacks = {
            .retain          = kCFTypeDictionaryKeyCallBacks.retain,
            .release         = kCFTypeDictionaryKeyCallBacks.release,
            .copyDescription = kCFTypeDictionaryKeyCallBacks.copyDescription,
            .equal           = (CFDictionaryEqualCallBack)_OEBindingMapKeyEqualCallBack,
            .hash            = (CFDictionaryHashCallBack) _OEBindingMapKeyHashCallBack
        };

        _keyMap = (__bridge_transfer NSMutableDictionary *)CFDictionaryCreateMutable(NULL, totalNumberOfKeys, &keyCallbacks, &kCFTypeDictionaryValueCallBacks);
        _queue  = dispatch_queue_create("org.openemu.OEBindingMap.queue", DISPATCH_QUEUE_CONCURRENT);
    }

    return self;
}

- (OESystemKey *)systemKeyForEvent:(OEHIDEvent *)anEvent;
{
    __block OESystemKey *ret = nil;
    dispatch_sync(_queue, ^{
        ret = [self->_keyMap objectForKey:anEvent];
    });

    return ret;
}

- (void)setSystemKey:(OESystemKey *)aKey forEvent:(OEHIDEvent *)anEvent;
{
    dispatch_barrier_async(_queue, ^{
        [self->_keyMap setObject:aKey forKey:anEvent];
    });
}

- (void)removeSystemKeyForEvent:(OEHIDEvent *)anEvent
{
    dispatch_barrier_async(_queue, ^{
        [self->_keyMap removeObjectForKey:anEvent];
    });
}

- (NSString *)description
{
    __block NSString *keyMapDescription = [_keyMap description];
    dispatch_sync(_queue, ^{
        keyMapDescription = [self->_keyMap description];
    });

    return [NSString stringWithFormat:@"<%@ %p events: %@>", [self class], self, keyMapDescription];
}

@end

@implementation OESystemKey

+ (instancetype)systemKeyWithKey:(NSUInteger)key player:(NSUInteger)player isAnalogic:(BOOL)isAnalogic
{
    return [[self alloc] initWithKey:key player:player isAnalogic:isAnalogic];
}

- (instancetype)initWithKey:(NSUInteger)key player:(NSUInteger)player isAnalogic:(BOOL)isAnalogic
{
    if((self = [super init]))
    {
        _key = key;
        _player = player;
        _analogic = isAnalogic;
    }

    return self;
}

- (BOOL)isGlobalButtonKey
{
    return !!(_key & OEGlobalButtonIdentifierFlag);
}

- (NSUInteger)hash
{
    return _key << 32 | _player;
}

- (BOOL)isEqual:(OESystemKey *)object
{
    if(self == object) return YES;

    if([object isKindOfClass:[OESystemKey class]])
        return _key == object->_key && _player == object->_player;

    return NO;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p key: %lu player: %lu>", [self class], self, _key, _player];
}

@end

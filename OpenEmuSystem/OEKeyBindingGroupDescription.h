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

#import <Foundation/Foundation.h>

#import <OpenEmuSystem/OEBindingDescription.h>

NS_ASSUME_NONNULL_BEGIN

@class OEKeyBindingDescription, OEOrientedKeyGroupBindingDescription;

typedef NS_ENUM(NSInteger, OEKeyGroupType) {
    OEKeyGroupTypeUnknown,
    OEKeyGroupTypeAxis,
    OEKeyGroupTypeHatSwitch,
};

extern NSString *NSStringFromOEKeyGroupType(OEKeyGroupType type);

// OEKeyGroupBindingsDescription allows OEKeyBindingsDescription objects to know about their peers, this class is only used by OESystemBindings
@interface OEKeyBindingGroupDescription : OEBindingDescription

@property(readonly) OEKeyGroupType type;
@property(readonly, copy) NSString *groupIdentifier;
@property(readonly, copy) NSArray<OEKeyBindingDescription *> *keys;
@property(readonly, copy) NSArray<NSString *> *keyNames;
@property(readonly, getter=isAnalogic) BOOL analogic;

- (OEKeyBindingDescription *)oppositeKeyOfKey:(OEKeyBindingDescription *)aKey;

- (OEOrientedKeyGroupBindingDescription *)orientedKeyGroupWithBaseKey:(OEKeyBindingDescription *)aKey;

- (NSUInteger)indexOfKey:(OEKeyBindingDescription *)aKey;

- (void)enumerateKeysFromKey:(OEKeyBindingDescription *)baseKey usingBlock:(void(^)(OEKeyBindingDescription *key, BOOL *stop))block;
- (void)enumerateOrientedKeyGroupsFromKey:(OEKeyBindingDescription *)baseKey usingBlock:(void (^)(OEOrientedKeyGroupBindingDescription *key, BOOL *stop))block;

@end

// OEOrientedKeyGroupBindingDescription is used to know to which key of the group a certain value was set when saving the bindings to the disk, it's also used by responders the same way
@interface OEOrientedKeyGroupBindingDescription : OEKeyBindingGroupDescription

@property(readonly, weak) OEKeyBindingGroupDescription *parentKeyGroup;
@property(readonly, weak) OEKeyBindingDescription *baseKey;

@property(readonly) OEKeyBindingDescription *oppositeKey;

@property(readonly) NSUInteger indexOfBaseKey;
- (void)enumerateKeysFromBaseKeyUsingBlock:(void(^)(OEKeyBindingDescription *key, BOOL *stop))block;
- (void)enumerateOrientedKeyGroupsFromBaseKeyUsingBlock:(void(^)(OEOrientedKeyGroupBindingDescription *key, BOOL *stop))block;

@end

NS_ASSUME_NONNULL_END

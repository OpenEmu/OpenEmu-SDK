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

#import <Foundation/Foundation.h>

@class OEFile;
@class OEHIDEvent;
@class OEGlobalKeyBindingDescription;
@class OEKeyBindingDescription;
@class OEKeyBindingGroupDescription;
@class OESystemResponder;

extern NSString *const OESettingValueKey;
extern NSString *const OEHIDEventValueKey;
extern NSString *const OEHIDEventExtraValueKey;
extern NSString *const OEKeyboardEventValueKey;
extern NSString *const OEControlsPreferenceKey;
extern NSString *const OESystemName;
extern NSString *const OESystemType;
extern NSString *const OESystemIdentifier;
extern NSString *const OESystemIconName;
extern NSString *const OESystemCoverAspectRatio;
extern NSString *const OEProjectURLKey;
extern NSString *const OEFileTypes;
extern NSString *const OENumberOfPlayersKey;
extern NSString *const OEResponderClassKey;

extern NSString *const OEKeyboardMappingsFileName;
extern NSString *const OEControllerMappingsFileName;

// NSArray - contains NSString objects representing control names that are independent from a player
extern NSString *const OESystemControlNamesKey;
// NSArray - contains NSString objects representing control names of the system
// it must contain all the keys contained in OESystemControlNamesKey if any.
extern NSString *const OEGenericControlNamesKey;
// NSArray - contains NSString objects representing control names of keys that represent an anlogic control.
extern NSString *const OEAnalogControlsKey;

// NSDictionary - contains OEHatSwitchControlsKey and OEAxisControlsKey keys
extern NSString *const OEControlTypesKey;
// NSDictionay -
// - key: system-unique name for the hat switch
// - value: NSArray - contains strings that are also contained in OEGenericControlNamesKey array
// They represent keys that should be linked together if one of them were to be associated with a hat switch event
// The order of the key follows the rotation order: i.e. [ up, right, down, left ]
extern NSString *const OEHatSwitchControlsKey;
// NSDictionay -
// - key: system-unique name for the axis
// - value: NSArray - contains strings that are also contained in OEGenericControlNamesKey array
// They represent keys that are the opposite of each other on an axis and
// should be associated together if one of them was associated to an axis event
extern NSString *const OEAxisControlsKey;

/* OEControlListKey plist format:
 * <array>                                    <!-- One group with keys in it -->
 *   <string>D-Pad</string>                   <!-- One group label
 *   <dict>                                   <!-- One control with its data -->
 *     <key>OEControlListKeyNameKey</key>
 *     <string>OESMSButtonUp</string>
 *     <key>OEControlListKeyLabelKey</key>
 *     <string>Up</string>                    <!-- The colon is added by the app -->
 *   </dict>
 *   <string>-</string>                       <!-- line separator -->
 * </array>
 */

extern NSString *const OEControlListKey;
extern NSString *const OEControlListKeyNameKey;
extern NSString *const OEControlListKeyLabelKey;
extern NSString *const OEControlListKeyFontFamilyKey;

extern NSString *const OEControllerImageKey;       // NSString - file name of the controller image
extern NSString *const OEControllerImageMaskKey;   // NSString - file name of the controller image mask
extern NSString *const OEControllerKeyPositionKey; // NSDictionary - KeyName -> NSPoint as NSString

typedef NS_ENUM(NSInteger, OEFileSupport) {
    OEFileSupportNo,
    OEFileSupportYes,
    OEFileSupportUncertain,
};

@interface OESystemController : NSObject

+ (OESystemController *)systemControllerWithIdentifier:(NSString *)systemIdentifier;

- (instancetype)initWithBundle:(NSBundle *)aBundle;

@property(readonly) NSBundle *bundle;
@property(readonly, copy) NSString *systemIdentifier;
@property(readonly) NSString *systemName;
@property(readonly) NSString *systemType;
@property(readonly) NSImage *systemIcon;

+ (NSDictionary<NSString *, OEGlobalKeyBindingDescription *> *)globalKeyBindingDescriptions;
@property(readonly) NSDictionary<NSString *, OEGlobalKeyBindingDescription *> *globalKeyBindingDescriptions;

@property(readonly) Class responderClass;
@property(readonly) NSUInteger numberOfPlayers;
@property(readonly) NSDictionary<NSString *, OEKeyBindingDescription *> *allKeyBindingsDescriptions;
@property(readonly) NSDictionary<NSString *, OEKeyBindingDescription *> *systemKeyBindingsDescriptions;
@property(readonly) NSDictionary<NSString *, OEKeyBindingDescription *> *keyBindingsDescriptions;
@property(readonly) NSDictionary<NSString *, OEKeyBindingGroupDescription *> *keyBindingGroupDescriptions;

@property(readonly, copy) NSArray *controlPageList;
@property(readonly, copy) NSDictionary<NSString *, NSValue *> *controllerKeyPositions;
@property(readonly, copy) NSString *controllerImageName;
@property(readonly, copy) NSString *controllerImageMaskName;

@property(readonly, copy) NSImage *controllerImage;
@property(readonly, copy) NSImage *controllerImageMask;

@property(readonly) CGFloat coverAspectRatio;

@property(readonly, nonatomic) BOOL supportsDiscsWithDescriptorFile;

#pragma mark - Bindings settings

// Dictionary containing the default values to register for the system
@property(readonly) NSDictionary<NSString *, NSNumber *> *defaultKeyboardControls;
@property(readonly) NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *defaultDeviceControls;

#pragma mark - Game System Responder objects

- (id)newGameSystemResponder;

#pragma mark - ROM Handling

@property(readonly, copy) NSArray *fileTypes;

/* Whether the system plugin can verifiably handle a file. This should be a more thorough check than just
   testing file extensions, which is what -canHandleFileExtension: does. When importing a file, systems that
   can handle that file are preferred over systems that can only (potentially) handle its extension. Only implement -canHandleFile: if you can verify that it's valid for the system.
*/
- (OEFileSupport)canHandleFile:(__kindof OEFile *)file;
- (BOOL)canHandleFileExtension:(NSString *)fileExtension;

- (NSString *)headerLookupForFile:(__kindof OEFile *)file;
- (NSString *)serialLookupForFile:(__kindof OEFile *)file;

@end

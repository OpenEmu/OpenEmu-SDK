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

#import "OESystemController.h"

#import "OEBindingDescription_Internal.h"
#import "OEBindingsController.h"
#import "OESystemResponder.h"
#import <OpenEmuSystem/OpenEmuSystem-Swift.h>

#define OEHIDAxisTypeString      @"OEHIDAxisType"
#define OEHIDHatSwitchTypeString @"OEHIDEventHatSwitchType"

NSString *const OESettingValueKey            = @"OESettingValueKey";
NSString *const OEHIDEventValueKey           = @"OEHIDEventValueKey";
NSString *const OEHIDEventExtraValueKey      = @"OEHIDEventExtraValueKey";
NSString *const OEKeyboardEventValueKey      = @"OEKeyboardEventValueKey";
NSString *const OEControlsPreferenceKey      = @"OEControlsPreferenceKey";
NSString *const OESystemIdentifier           = @"OESystemIdentifier";
NSString *const OEProjectURLKey              = @"OEProjectURL";
NSString *const OESystemName                 = @"OESystemName";
NSString *const OESystemType                 = @"OESystemType";
NSString *const OESystemMedia                = @"OESystemMedia";
NSString *const OENumberOfPlayersKey         = @"OENumberOfPlayersKey";
NSString *const OEResponderClassKey          = @"OEResponderClassKey";

NSString *const OERegionalizedSystemNames    = @"OERegionalizedSystemNames";
NSString *const OERegionalizedSystemNamesRegionKeyNorthAmerica = @"na";
NSString *const OERegionalizedSystemNamesRegionKeyJapan        = @"jp";
NSString *const OERegionalizedSystemNamesRegionKeyEurope       = @"eu";

NSString *const OEKeyboardMappingsFileName   = @"Keyboard-Mappings";
NSString *const OEControllerMappingsFileName = @"Controller-Mappings";

NSString *const OESystemIconName             = @"OESystemIcon";
NSString *const OESystemCoverAspectRatio     = @"OESystemCoverAspectRatio";
NSString *const OEFileTypes                  = @"OEFileSuffixes";

NSString *const OESystemControlNamesKey      = @"OESystemControlNamesKey";
NSString *const OEGenericControlNamesKey     = @"OEGenericControlNamesKey";
NSString *const OEAnalogControlsKey          = @"OEAnalogControlsKey";
NSString *const OEControlTypesKey            = @"OEControlTypesKey";
NSString *const OEHatSwitchControlsKey       = @"OEHatSwitchControlsKey";
NSString *const OEAxisControlsKey            = @"OEAxisControlsKey";

NSString *const OEControlListKey             = @"OEControlListKey";
NSString *const OEControlListKeyNameKey      = @"OEControlListKeyNameKey";
NSString *const OEControlListKeyLabelKey     = @"OEControlListKeyLabelKey";

NSString *const OEControllerImageKey         = @"OEControllerImageKey";
NSString *const OEControllerImageMaskKey     = @"OEControllerImageMaskKey";
NSString *const OEControllerKeyPositionKey   = @"OEControllerKeyPositionKey";

NSString *const OEPrefControlsShowAllGlobalKeys = @"OEShowAllGlobalKeys";

@implementation OESystemController {
    NSString *_systemName;
    NSDictionary<NSString *, NSString *> *_regionalSystemNames;
    NSString *_systemType;
    NSArray<NSString *> *_systemMedia;
    NSImage *_systemIcon;
    NSImage *_controllerImage;
    NSImage *_controllerImageMask;
}

static NSMapTable<NSString *, OESystemController *> *_registeredSystemController;

+ (void)initialize
{
    if (self != [OESystemController class])
        return;


    _registeredSystemController = [NSMapTable strongToWeakObjectsMapTable];
}

+ (OESystemController *)systemControllerWithIdentifier:(NSString *)systemIdentifier
{
    return [_registeredSystemController objectForKey:systemIdentifier];
}

- (BOOL)OE_isBundleValid:(NSBundle *)aBundle forClass:(Class)aClass
{
    return [aBundle principalClass] == aClass;
}

- (instancetype)init
{
    return [self initWithBundle:[NSBundle bundleForClass:[self class]]];
}

- (nullable instancetype)initWithBundle:(NSBundle *)aBundle
{
    if(![self OE_isBundleValid:aBundle forClass:[self class]])
        return nil;

    if((self = [super init]))
    {
        _bundle = aBundle;
        _systemIdentifier = _bundle.infoDictionary[OESystemIdentifier] ? : _bundle.bundleIdentifier;

        _systemName = [_bundle.infoDictionary[OESystemName] copy];
        _regionalSystemNames = [_bundle.infoDictionary[OERegionalizedSystemNames] copy];
        _systemType = [_bundle.infoDictionary[OESystemType] copy];
        _systemMedia = [_bundle.infoDictionary[OESystemMedia] copy];

        _coverAspectRatio = [_bundle.infoDictionary[OESystemCoverAspectRatio] floatValue];
        _numberOfPlayers = [_bundle.infoDictionary[OENumberOfPlayersKey] integerValue];

        Class cls = NSClassFromString(_bundle.infoDictionary[OEResponderClassKey]);
        if(cls != [OESystemResponder class] && [cls isSubclassOfClass:[OESystemResponder class]])
            _responderClass = cls;

        _defaultKeyboardControls = [self OE_propertyListWithFileName:OEKeyboardMappingsFileName];

        _defaultDeviceControls = [self OE_propertyListWithFileName:OEControllerMappingsFileName];

        [self OE_setUpKeyBindingDescriptions];
        [self OE_setUpControllerPreferencesKeys];

        _fileTypes = _bundle.infoDictionary[OEFileTypes];

        [_registeredSystemController setObject:self forKey:_systemIdentifier];
    }

    return self;
}

- (NSDictionary<NSString *, id> *)OE_propertyListWithFileName:(NSString *)fileName
{
    NSURL *url = [_bundle URLForResource:fileName withExtension:@"plist"];

    id ret = nil;
    if(url != nil)
        ret = [NSPropertyListSerialization propertyListWithData:[NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:NULL] options:0 format:NULL error:NULL];

    return ret;
}

#pragma mark -
#pragma mark Rom Handling

- (OEFileSupport)canHandleFile:(__kindof OEFile *)file
{
    return OEFileSupportUncertain;
}

- (BOOL)canHandleFileExtension:(NSString *)fileExtension
{
    return [_fileTypes containsObject:[fileExtension lowercaseString]];
}

- (NSString *)headerLookupForFile:(__kindof OEFile *)file
{
    return nil;
}

- (NSString *)serialLookupForFile:(__kindof OEFile *)file
{
    return nil;
}

- (NSDictionary<NSString *, id> *)OE_defaultControllerPreferences;
{
    return [NSPropertyListSerialization propertyListWithData:[NSData dataWithContentsOfURL:[_bundle URLForResource:@"Controller-Preferences" withExtension:@"plist"]] options:NSPropertyListImmutable format:NULL error:NULL];
}

- (NSDictionary<NSString *, id> *)OE_localizedControllerPreferences;
{
    NSString *fileName = nil;
    NSURL *fileURL = nil;

    switch([[OELocalizationHelper sharedHelper] region])
    {
        case OERegionEU  : fileName = @"Controller-Preferences-EU";  break;
        case OERegionNA  : fileName = @"Controller-Preferences-NA";  break;
        case OERegionJPN : fileName = @"Controller-Preferences-JAP"; break;
        default : break;
    }

    if(fileName != nil) fileURL = [_bundle URLForResource:fileName withExtension:@"plist"];

    return (fileURL == nil ? nil : [NSPropertyListSerialization propertyListWithData:[NSData dataWithContentsOfURL:fileURL] options:NSPropertyListImmutable format:NULL error:NULL]);
}

- (NSArray<NSArray<NSDictionary<NSString *, NSString *> *> *> *)OE_globalButtonsControlList
{
#define Button(_LABEL_, _NAME_) @{                          \
      OEControlListKeyLabelKey : _LABEL_,\
      OEControlListKeyNameKey : _NAME_,                                    \
      }
    static NSArray<NSArray<NSDictionary<NSString *, NSString *> *> *> *globalKeys;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        globalKeys = @[[[NSUserDefaults standardUserDefaults] boolForKey:OEPrefControlsShowAllGlobalKeys] ?
        // All available 'global' buttons
        @[Button(@"Rapid Fire Toggle", OEGlobalButtonRapidFireToggle),
          Button(@"Rapid Fire Clear", OEGlobalButtonRapidFireClear),
          Button(@"Rapid Fire Reset", OEGlobalButtonRapidFireReset),
          Button(@"Save", OEGlobalButtonSaveState),
          Button(@"Load", OEGlobalButtonLoadState),
          Button(@"Quick Save", OEGlobalButtonQuickSave),
          Button(@"Quick Load", OEGlobalButtonQuickLoad),
          Button(@"Fullscreen", OEGlobalButtonFullScreen),
          Button(@"Mute", OEGlobalButtonMute),
          Button(@"Volume Down", OEGlobalButtonVolumeDown),
          Button(@"Volume Up", OEGlobalButtonVolumeUp),
          Button(@"Stop", OEGlobalButtonStop),
          Button(@"Reset", OEGlobalButtonReset),
          Button(@"Pause/Resume", OEGlobalButtonPause),
          Button(@"Rewind", OEGlobalButtonRewind),
          Button(@"Fast Forward", OEGlobalButtonFastForward),
          //Button(@"Slow Motion", OEGlobalButtonSlowMotion),
          Button(@"Step Backward", OEGlobalButtonStepFrameBackward),
          Button(@"Step Forward", OEGlobalButtonStepFrameForward),
          Button(@"Next Display Mode", OEGlobalButtonNextDisplayMode),
          Button(@"Last Display Mode", OEGlobalButtonLastDisplayMode),
          Button(@"Screenshot", OEGlobalButtonScreenshot),
          ]
        : // Limited selection of global buttons
        @[Button(@"Rapid Fire Toggle", OEGlobalButtonRapidFireToggle),
          Button(@"Rapid Fire Clear", OEGlobalButtonRapidFireClear),
          Button(@"Quick Save", OEGlobalButtonQuickSave),
          Button(@"Quick Load", OEGlobalButtonQuickLoad),
          Button(@"Mute", OEGlobalButtonMute),
          Button(@"Pause/Resume", OEGlobalButtonPause),
          Button(@"Rewind", OEGlobalButtonRewind),
          Button(@"Fast Forward", OEGlobalButtonFastForward),
          Button(@"Step Backward", OEGlobalButtonStepFrameBackward),
          Button(@"Step Forward", OEGlobalButtonStepFrameForward),
          Button(@"Next Display Mode", OEGlobalButtonNextDisplayMode),
          Button(@"Last Display Mode", OEGlobalButtonLastDisplayMode),
          Button(@"Screenshot", OEGlobalButtonScreenshot),
          ]];
    });

    return globalKeys;
#undef Button
}

- (void)OE_setUpControllerPreferencesKeys;
{
    // TODO: Support local setup with different plists
    NSDictionary<NSString *, id> *plist = [self OE_defaultControllerPreferences];
    NSDictionary<NSString *, id> *localizedPlist = [self OE_localizedControllerPreferences];

    _controllerImageName = localizedPlist[OEControllerImageKey] ? : plist[OEControllerImageKey];
    _controllerImageMaskName = localizedPlist[OEControllerImageMaskKey] ? : plist[OEControllerImageMaskKey];

    NSDictionary<NSString *, NSString *> *positions = [plist objectForKey:OEControllerKeyPositionKey];
    NSDictionary<NSString *, NSString *> *localPos = [localizedPlist objectForKey:OEControllerKeyPositionKey];

    NSMutableDictionary<NSString *, NSValue *> *converted = [[NSMutableDictionary alloc] initWithCapacity:[positions count]];

    for(NSString *key in positions)
    {
        NSString *value = [localPos objectForKey:key] ? : [positions objectForKey:key];
        converted[key] = [NSValue valueWithPoint:value != nil ? NSPointFromString(value) : NSZeroPoint];
    }

    _controllerKeyPositions = [converted copy];
    _controlPageList = @[
        @"Gameplay Buttons", [_bundle.infoDictionary objectForKey:OEControlListKey],
        @"Special Keys", [self OE_globalButtonsControlList],
    ];
}

- (OESystemResponder *)newGameSystemResponder;
{
    return [[[self responderClass] alloc] initWithController:self];
}

- (NSString *)systemName
{
    switch ([[OELocalizationHelper sharedHelper] region]) {
        case OERegionNA:
            return _regionalSystemNames[OERegionalizedSystemNamesRegionKeyNorthAmerica] ?: _systemName;
        case OERegionJPN:
            return _regionalSystemNames[OERegionalizedSystemNamesRegionKeyJapan] ?: _systemName;
        case OERegionEU:
            return _regionalSystemNames[OERegionalizedSystemNamesRegionKeyEurope] ?: _systemName;
        case OERegionOther:
        default:
            return _systemName;
    }
}

- (NSString *)systemType
{
    return _systemType;
}

- (NSArray<NSString *> *)systemMedia
{
    return _systemMedia;
}

- (NSImage *)systemIcon
{
    if (!_systemIcon) {
        NSString *iconFileName = _bundle.infoDictionary[OESystemIconName];
        _systemIcon = [_bundle imageForResource:iconFileName];
    }
    return _systemIcon;
}

- (NSImage *)controllerImage;
{
    if(_controllerImage == nil)
        _controllerImage = [_bundle imageForResource:[self controllerImageName]];

    return _controllerImage;
}

- (NSImage *)controllerImageMask;
{
    if(_controllerImageMask == nil)
        _controllerImageMask = [_bundle imageForResource:[self controllerImageMaskName]];

    return _controllerImageMask;
}

- (BOOL)supportsDiscsWithDescriptorFile
{
    // metadata descriptor / sidecar files
    for(NSString *discExtension in @[ @"cue", @"ccd", @"gdi", @"m3u" ]) {
        if ([[self fileTypes] containsObject:discExtension])
            return YES;
    }

    return NO;
}

#pragma mark - Key Descriptions

+ (NSDictionary<NSString *, OEGlobalKeyBindingDescription *> *)globalKeyBindingDescriptions
{
    static NSDictionary<NSString *, OEGlobalKeyBindingDescription *> *keyNameToDescription = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableDictionary *keys = [NSMutableDictionary dictionaryWithCapacity:OEGlobalButtonIdentifierCount];

        for(OEGlobalButtonIdentifier i = 1; i < OEGlobalButtonIdentifierCount; i++) {
            OEGlobalKeyBindingDescription *desc = [[OEGlobalKeyBindingDescription alloc] initWithButtonIdentifier:i];
            if (desc.name != nil)
                keys[desc.name] = desc;
        }

        keyNameToDescription = [keys copy];
    });

    return keyNameToDescription;
}

- (NSDictionary<NSString *, OEGlobalKeyBindingDescription *> *)globalKeyBindingDescriptions
{
    return [self.class globalKeyBindingDescriptions];
}

- (void)OE_setUpKeyBindingDescriptions
{
    NSArray<NSString *> *genericControlNames = _bundle.infoDictionary[OEGenericControlNamesKey];
    NSArray<NSString *> *systemControlNames = _bundle.infoDictionary[OESystemControlNamesKey];

    NSMutableDictionary<NSString *, OEKeyBindingDescription *> *systemKeyDescs  = systemControlNames != nil ? [NSMutableDictionary dictionaryWithCapacity:systemControlNames.count] : nil;
    NSMutableDictionary<NSString *, OEKeyBindingDescription *> *genericKeyDescs = [NSMutableDictionary dictionaryWithCapacity:[genericControlNames count]];
    NSMutableDictionary<NSString *, OEKeyBindingDescription *> *allKeyDescs     = [NSMutableDictionary dictionaryWithCapacity:[genericControlNames count]];

    [genericControlNames enumerateObjectsUsingBlock:^(NSString *name, NSUInteger idx, BOOL *stop) {
        BOOL systemWide = systemControlNames != nil && [systemControlNames containsObject:name];

        OEKeyBindingDescription *keyDesc = [[OEKeyBindingDescription alloc] initWithSystemController:self name:name index:idx isSystemWide:systemWide];

        (systemWide ? systemKeyDescs : genericKeyDescs)[name] = keyDesc;
        allKeyDescs[name] = keyDesc;
    }];

    _systemKeyBindingsDescriptions = [systemKeyDescs  copy];
    _keyBindingsDescriptions = [genericKeyDescs copy];

    [allKeyDescs addEntriesFromDictionary:self.globalKeyBindingDescriptions];
    _allKeyBindingsDescriptions = [allKeyDescs copy];

    [self OE_setUpKeyBindingGroupDescriptions];
}

- (void)OE_setUpKeyBindingGroupDescriptions
{
    NSDictionary<NSString *, NSArray *> *dict = [_bundle infoDictionary][OEControlTypesKey];

    NSArray<NSString *> *analogControls = dict[OEAnalogControlsKey];
    NSArray<NSArray<NSString *> *> *axisControls = dict[OEAxisControlsKey];
    NSArray<NSArray<NSString *> *> *hatSwitchControls = dict[OEHatSwitchControlsKey];

    for(NSString *keyName in analogControls)
        _allKeyBindingsDescriptions[keyName].analogic = YES;

    NSMutableDictionary<NSString *, OEKeyBindingGroupDescription *> *groups = [self OE_keyGroupsForControls:hatSwitchControls type:OEKeyGroupTypeHatSwitch availableKeys:_keyBindingsDescriptions];
    [groups addEntriesFromDictionary:[self OE_keyGroupsForControls:axisControls type:OEKeyGroupTypeAxis availableKeys:_keyBindingsDescriptions]];

    _keyBindingGroupDescriptions = [groups copy];

    for(OEKeyBindingGroupDescription *group in _keyBindingGroupDescriptions.allValues)
        NSAssert([group isMemberOfClass:[OEKeyBindingGroupDescription class]], @"SOMETHING'S FISHY");
}

- (NSMutableDictionary<NSString *, OEKeyBindingGroupDescription *> *)OE_keyGroupsForControls:(NSArray<NSArray<NSString *> *> *)controls type:(OEKeyGroupType)aType availableKeys:(NSDictionary<NSString *, OEKeyBindingDescription *> *)availableKeys;
{
    NSMutableDictionary<NSString *, OEKeyBindingGroupDescription *> *ret = [NSMutableDictionary dictionaryWithCapacity:controls.count];

    for(NSArray<NSString *> *keyNames in controls) {
        NSMutableArray<OEKeyBindingDescription *> *keys = [NSMutableArray arrayWithCapacity:keyNames.count];

        for(NSString *keyName in keyNames)
            [keys addObject:availableKeys[keyName]];

        OEKeyBindingGroupDescription *group = [[OEKeyBindingGroupDescription alloc] initWithSystemController:self groupType:aType keys:keys];
        ret[group.groupIdentifier] = group;
    }

    return ret;
}

@end

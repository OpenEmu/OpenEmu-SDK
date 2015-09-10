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

#import "OEBindingsController.h"
#import "OELocalizationHelper.h"
#import "OESystemResponder.h"

#define OEHIDAxisTypeString      @"OEHIDAxisType"
#define OEHIDHatSwitchTypeString @"OEHIDEventHatSwitchType"

@interface OESystemController ()
{
    NSMutableArray *_gameSystemResponders;

    NSString       *_systemName;
    NSImage        *_systemIcon;
}

@property(readwrite, copy) NSArray *systemControlNames;
@property(readwrite, copy) NSArray *genericControlNames;

@property(readwrite, copy) NSArray *analogControls;
@property(readwrite, copy) NSArray *axisControls;
@property(readwrite, copy) NSArray *hatSwitchControls;

- (void)OE_setUpControlTypes;
- (id)OE_propertyListWithFileName:(NSString *)fileName;

@end

NSString *const OESettingValueKey            = @"OESettingValueKey";
NSString *const OEHIDEventValueKey           = @"OEHIDEventValueKey";
NSString *const OEHIDEventExtraValueKey      = @"OEHIDEventExtraValueKey";
NSString *const OEKeyboardEventValueKey      = @"OEKeyboardEventValueKey";
NSString *const OEControlsPreferenceKey      = @"OEControlsPreferenceKey";
NSString *const OESystemIdentifier           = @"OESystemIdentifier";
NSString *const OEProjectURLKey              = @"OEProjectURL";
NSString *const OESystemName                 = @"OESystemName";
NSString *const OENumberOfPlayersKey         = @"OENumberOfPlayersKey";
NSString *const OEResponderClassKey          = @"OEResponderClassKey";

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
NSString *const OEControlListKeyFontFamilyKey= @"OEControlListKeyFontFamilyKey";

NSString *const OEControllerImageKey         = @"OEControllerImageKey";
NSString *const OEControllerImageMaskKey     = @"OEControllerImageMaskKey";
NSString *const OEControllerKeyPositionKey   = @"OEControllerKeyPositionKey";

NSString *const OEPrefControlsShowAllGlobalKeys = @"OEShowAllGlobalKeys";

@implementation OESystemController
@synthesize controllerImage = _controllerImage, controllerImageMask = _controllerImageMask;

- (BOOL)OE_isBundleValid:(NSBundle *)aBundle forClass:(Class)aClass
{
    return [aBundle principalClass] == aClass;
}

- (id)init
{
    return [self initWithBundle:[NSBundle bundleForClass:[self class]]];
}

- (id)initWithBundle:(NSBundle *)aBundle
{
    if(![self OE_isBundleValid:aBundle forClass:[self class]])
        return nil;

    if((self = [super init]))
    {
        _bundle               = aBundle;
        _gameSystemResponders = [[NSMutableArray alloc] init];
        _systemIdentifier     = ([[_bundle infoDictionary] objectForKey:OESystemIdentifier]
                                 ? : [_bundle bundleIdentifier]);

        _systemName = [[[_bundle infoDictionary] objectForKey:OESystemName] copy];

        NSString *iconFileName = [[_bundle infoDictionary] objectForKey:OESystemIconName];
        NSString *iconFilePath = [_bundle pathForImageResource:iconFileName];
        _systemIcon = [[NSImage alloc] initWithContentsOfFile:iconFilePath];
        _coverAspectRatio = [[[_bundle infoDictionary] objectForKey:OESystemCoverAspectRatio] floatValue];
        _numberOfPlayers = [[[_bundle infoDictionary] objectForKey:OENumberOfPlayersKey] integerValue];

        Class cls = NSClassFromString([[_bundle infoDictionary] objectForKey:OEResponderClassKey]);
        if(cls != [OESystemResponder class] && [cls isSubclassOfClass:[OESystemResponder class]])
            _responderClass = cls;

        _defaultKeyboardControls = [self OE_propertyListWithFileName:OEKeyboardMappingsFileName];

        _defaultDeviceControls = [self OE_propertyListWithFileName:OEControllerMappingsFileName];

        [self setGenericControlNames:[[_bundle infoDictionary] objectForKey:OEGenericControlNamesKey]];
        [self setSystemControlNames: [[_bundle infoDictionary] objectForKey:OESystemControlNamesKey]];

        [self OE_setUpControlTypes];
        [self OE_setUpControllerPreferencesKeys];

        _fileTypes = [[_bundle infoDictionary] objectForKey:OEFileTypes];
    }

    return self;
}

- (id)OE_propertyListWithFileName:(NSString *)fileName
{
    NSString *path = [_bundle pathForResource:fileName ofType:@"plist"];

    id ret = nil;
    if(path != nil)
        ret = [NSPropertyListSerialization propertyListWithData:[NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:NULL] options:0 format:NULL error:NULL];

    return ret;
}

#pragma mark -
#pragma mark Rom Handling

- (OECanHandleState)canHandleFile:(NSString *)path
{
    return OECanHandleUncertain;
}

- (BOOL)canHandleFileExtension:(NSString *)fileExtension
{
    return [_fileTypes containsObject:[fileExtension lowercaseString]];
}

- (NSString *)headerLookupForFile:(NSString *)path
{
    return nil;
}

- (NSString *)serialLookupForFile:(NSString *)path
{
    return nil;
}

- (void)OE_setUpControlTypes;
{
    NSDictionary *dict = [[_bundle infoDictionary] objectForKey:OEControlTypesKey];

    [self setAnalogControls:   [dict objectForKey:OEAnalogControlsKey]];
    [self setHatSwitchControls:[dict objectForKey:OEHatSwitchControlsKey]];
    [self setAxisControls:     [dict objectForKey:OEAxisControlsKey]];
}

- (NSDictionary *)OE_defaultControllerPreferences;
{
    return [NSPropertyListSerialization propertyListWithData:[NSData dataWithContentsOfFile:[_bundle pathForResource:@"Controller-Preferences" ofType:@"plist"]] options:NSPropertyListImmutable format:NULL error:NULL];
}

- (NSDictionary *)OE_localizedControllerPreferences;
{
    NSString *fileName = nil;

    switch([[OELocalizationHelper sharedHelper] region])
    {
        case OERegionEU  : fileName = @"Controller-Preferences-EU";  break;
        case OERegionNA  : fileName = @"Controller-Preferences-NA";  break;
        case OERegionJAP : fileName = @"Controller-Preferences-JAP"; break;
        default : break;
    }

    if(fileName != nil) fileName = [_bundle pathForResource:fileName ofType:@"plist"];

    return (fileName == nil ? nil : [NSPropertyListSerialization propertyListWithData:[NSData dataWithContentsOfFile:fileName] options:NSPropertyListImmutable format:NULL error:NULL]);
}

- (NSArray *)OE_globalButtonsControlList
{
#define Button(_LABEL_, _DESCRIPTION_, _NAME_) @{                          \
      OEControlListKeyLabelKey : NSLocalizedString(_LABEL_, _DESCRIPTION_),\
      OEControlListKeyNameKey : _NAME_,                                    \
      }
    static NSArray *globalKeys;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        globalKeys = @[[[NSUserDefaults standardUserDefaults] boolForKey:OEPrefControlsShowAllGlobalKeys] ?
        // All available 'global' buttons
        @[Button(@"Save", @"Name of the global button to save a state", OEGlobalButtonSaveState),
          Button(@"Load", @"Name of the global button to load a state", OEGlobalButtonLoadState),
          Button(@"Quick Save Button", @"Name of the global button to do a quick save", OEGlobalButtonQuickSave),
          Button(@"Quick Load Button", @"Name of the global button to load a quick save", OEGlobalButtonQuickLoad),
          Button(@"Fullscreen", @"Name of the global button to toggle fullscreen mode", OEGlobalButtonFullScreen),
          Button(@"Mute", @"Name of the global button to toggle sound mute", OEGlobalButtonMute),
          Button(@"Volume Down", @"Name of the global button to decrease the volume", OEGlobalButtonVolumeDown),
          Button(@"Volume Up", @"Name of the global button to increase the volume", OEGlobalButtonVolumeUp),
          Button(@"Stop", @"Name of the global button to stop emulation", OEGlobalButtonStop),
          Button(@"Reset", @"Name of the global button to reset the emulation", OEGlobalButtonReset),
          Button(@"Pause", @"Name of the global button to pause the emulation", OEGlobalButtonPause),
          Button(@"Rewind", @"Name of the global button to rewind the emulation", OEGlobalButtonRewind),
          Button(@"Fast Forward", @"Name of the global button to fast foward the emulation", OEGlobalButtonFastForward),
          //Button(@"Slow Motion", @"Name of the global button to run the emulation in slow motion", OEGlobalButtonSlowMotion),
          //Button(@"Step Backward", @"Name of the global button to step the emulation backward by one frame", OEGlobalButtonStepFrameBackward),
          //Button(@"Step Forward", @"Name of the global button to step the emulation forward by one frame", OEGlobalButtonStepFrameForward),
          Button(@"Display Mode", @"Name of the global button to switch display modes", OEGlobalButtonDisplayMode),
          Button(@"Screenshot", @"Name of the global button to take screenshot", OEGlobalButtonScreenshot),
          ]
        : // Limited selection of global buttons
        @[Button(@"Quick Save", @"Name of the global button to do a quick save", OEGlobalButtonQuickSave),
          Button(@"Quick Load", @"Name of the global button to load a quick save", OEGlobalButtonQuickLoad),
          Button(@"Mute", @"Name of the global button to toggle sound mute", OEGlobalButtonMute),
          Button(@"Pause", @"Name of the global button to pause the emulation", OEGlobalButtonPause),
          Button(@"Rewind", @"Name of the global button to rewind the emulation", OEGlobalButtonRewind),
          Button(@"Fast Forward", @"Name of the global button to fast foward the emulation", OEGlobalButtonFastForward),
          Button(@"Display Mode", @"Name of the global button to switch display modes", OEGlobalButtonDisplayMode),
          Button(@"Screenshot", @"Name of the global button to take screenshot", OEGlobalButtonScreenshot),
          ]];
    });

    return globalKeys;
#undef Button
}

- (void)OE_setUpControllerPreferencesKeys;
{
    // TODO: Support local setup with different plists
    NSDictionary *plist          = [self OE_defaultControllerPreferences];
    NSDictionary *localizedPlist = [self OE_localizedControllerPreferences];

    _controllerImageName     = [localizedPlist objectForKey:OEControllerImageKey]     ? : [plist objectForKey:OEControllerImageKey];
    _controllerImageMaskName = [localizedPlist objectForKey:OEControllerImageMaskKey] ? : [plist objectForKey:OEControllerImageMaskKey];

    NSDictionary *positions = [plist objectForKey:OEControllerKeyPositionKey];
    NSDictionary *localPos  = [localizedPlist objectForKey:OEControllerKeyPositionKey];

    NSMutableDictionary *converted = [[NSMutableDictionary alloc] initWithCapacity:[positions count]];

    for(NSString *key in positions)
    {
        NSString *value = [localPos objectForKey:key] ? : [positions objectForKey:key];

        [converted setObject:[NSValue valueWithPoint:value != nil ? NSPointFromString(value) : NSZeroPoint] forKey:key];
    }

    _controllerKeyPositions = [converted copy];
    _controlPageList = @[
                         NSLocalizedString(@"Gameplay Buttons", @"Title of the gameplay buttons section in controller keys."),
                         [[_bundle infoDictionary] objectForKey:OEControlListKey],

                         NSLocalizedString(@"Special Keys", @"Title of the global buttons section in controller keys."),
                         [self OE_globalButtonsControlList]
                         ];
}

- (id)newGameSystemResponder;
{
    OESystemResponder *responder = [[[self responderClass] alloc] initWithController:self];
    [self registerGameSystemResponder:responder];

    return responder;
}

- (NSString *)systemName
{
    return _systemName;
}

- (NSImage *)systemIcon
{
    return _systemIcon;
}

- (NSImage *)controllerImage;
{
    if(_controllerImage == nil)
        _controllerImage = [[NSImage alloc] initWithContentsOfFile:[_bundle pathForImageResource:[self controllerImageName]]];

    return _controllerImage;
}

- (NSImage *)controllerImageMask;
{
    if(_controllerImageMask == nil)
        _controllerImageMask = [[NSImage alloc] initWithContentsOfFile:[_bundle pathForImageResource:[self controllerImageMaskName]]];

    return _controllerImageMask;
}

- (BOOL)supportsDiscs
{
    NSArray *discBasedExtensions = @[@"cue", @"ccd", @"m3u"];
    for(NSString *discExtension in discBasedExtensions){
        if ([[self fileTypes] containsObject:discExtension])
            return true;
    }
    return false;
}

#pragma mark -
#pragma mark Responder management

- (void)registerGameSystemResponder:(OESystemResponder *)responder;
{
    [[[OEBindingsController defaultBindingsController] systemBindingsForSystemController:self] addBindingsObserver:responder];
    [_gameSystemResponders addObject:responder];
}

- (void)unregisterGameSystemResponder:(OESystemResponder *)responder;
{
    [[[OEBindingsController defaultBindingsController] systemBindingsForSystemController:self] removeBindingsObserver:responder];
    [_gameSystemResponders removeObject:responder];
}

@end

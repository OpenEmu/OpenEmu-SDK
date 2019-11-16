/*
 Copyright (c) 2009, OpenEmu Team

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

#import <Cocoa/Cocoa.h>

extern NSString *const OEAdvancedPreferenceKey;
extern NSString *const OEGameCoreClassKey;
extern NSString *const OEGameCorePlayerCountKey;
extern NSString *const OEGameCoreSupportsCheatCodeKey;
extern NSString *const OEGameCoreRequiresFilesKey;
extern NSString *const OEGameCoreOptionsKey;
extern NSString *const OEGameCoreHasGlitchesKey;
extern NSString *const OEGameCoreSaveStatesNotSupportedKey;
extern NSString *const OEGameCoreSupportsMultipleDiscsKey;
extern NSString *const OEGameCoreSupportsFileInsertionKey;
extern NSString *const OEGameCoreSupportsDisplayModeChangeKey;

/*
 * Keys for displayMode Entries.
 */
 
/* Groups (submenus) */

/** The NSString which will be shown in the Display Mode as the parent menu item
 *  for the submenu. */
#define OEGameCoreDisplayModeGroupNameKey @"OEGameCoreDisplayModeGroupNameKey"
/** An NSArray of NSDictionaries containing the entries in the group.
 *  @warning Only one level of indentation is supported to disallow over-complicated
 *    menus. */
#define OEGameCoreDisplayModeGroupItemsKey @"OEGameCoreDisplayModeGroupItemsKey"

/* Binary (toggleable) and Mutually-Exclusive Display Modes */

/** The NSString which will be shown in the Display Mode menu for this entry. This
 *  string must be unique to each display mode. */
#define OEGameCoreDisplayModeNameKey @"OEGameCoreDisplayModeNameKey"
/** Toggleable modes only. @(YES) if this mode is standalone and can be toggled.
 *  If @(NO) or unspecified, this item is part of a group of mutually-exclusive modes. */
#define OEGameCoreDisplayModeAllowsToggleKey @"OEGameCoreDisplayModeAllowsToggleKey"
/** Mutually-exclusive modes only. An NSString uniquely identifying this display mode
 *  within its group. Optional. if not specified, the value associated with
 *  OEGameCoreDisplayModeNameKey will be used instead. */
#define OEGameCoreDisplayModePrefValueNameKey @"OEGameCoreDisplayModePrefValueNameKey"
/** Toggleable modes: An NSString uniquely identifying this display mode.
 *  Mutually-exclusive modes: An NSString uniquely identifying the group of mutually
 *  exclusive modes this mode is part of.
 *  Every group of mutually-exclusive modes is defined implicitly as a set of modes with
 *  the same OEGameCoreDisplayModePrefValueNameKey. */
#define OEGameCoreDisplayModePrefKeyNameKey @"OEGameCoreDisplayModePrefKeyNameKey"
/** @(YES) if this mode is currently selected. */
#define OEGameCoreDisplayModeStateKey @"OEGameCoreDisplayModeStateKey"
/** @(YES) if this mode is inaccessible through the nextDisplayMode: and lastDisplayMode:
 *  actions */
#define OEGameCoreDisplayModeManualOnlyKey @"OEGameCoreDisplayModeMenuOnlyKey"
/** @(YES) if this mode is not saved in the preferences. */
#define OEGameCoreDisplayModeDisallowPrefSaveKey @"OEGameCoreDisplayModeDisallowPrefSaveKey"

/* Labels & Separators */

/** Separator only. Present if this item is a separator. Value does not matter. */
#define OEGameCoreDisplayModeSeparatorItemKey @"OEGameCoreDisplayModeSeparatorItemKey"
/** Label only. The NSString which will be shown in the Display Mode menu for this label. */
#define OEGameCoreDisplayModeLabelKey @"OEGameCoreDisplayModeLabelKey"

/* Other Keys */

/** An NSNumber specifying the level of indentation of this item. */
#define OEGameCoreDisplayModeIndentationLevelKey @"OEGameCoreDisplayModeIndentationLevelKey"


@class OEGameCore, OEGameDocument, OEHIDEvent, OESystemResponder;

@interface OEGameCoreController : NSResponder

- (id)initWithBundle:(NSBundle *)aBundle;

@property(readonly) NSBundle   *bundle;
@property(readonly) Class       gameCoreClass;

@property(readonly) NSString   *pluginName;
@property(readonly) NSArray    *systemIdentifiers;
@property(readonly) NSDictionary *coreOptions;

@property(readonly) NSString   *supportDirectoryPath;
@property(readonly) NSString   *biosDirectoryPath;
@property(readonly) NSArray    *usedSettingNames;
@property(readonly) NSUInteger  playerCount;

- (bycopy OEGameCore *)newGameCore;
- (NSArray *)requiredFilesForSystemIdentifier:(NSString *)systemIdentifier;
- (BOOL)requiresFilesForSystemIdentifier:(NSString *)systemIdentifier;
- (BOOL)supportsCheatCodeForSystemIdentifier:(NSString *)systemIdentifier;
- (BOOL)hasGlitchesForSystemIdentifier:(NSString *)systemIdentifier;
- (BOOL)saveStatesNotSupportedForSystemIdentifier:(NSString *)systemIdentifier;
- (BOOL)supportsMultipleDiscsForSystemIdentifier:(NSString *)systemIdentifier;
- (BOOL)supportsRewindingForSystemIdentifier:(NSString *)systemIdentifier;
- (BOOL)supportsFileInsertionForSystemIdentifier:(NSString *)systemIdentifier;
- (BOOL)supportsDisplayModeChangeForSystemIdentifier:(NSString *)systemIdentifier;
- (NSUInteger)rewindIntervalForSystemIdentifier:(NSString *)systemIdentifier;
- (NSUInteger)rewindBufferSecondsForSystemIdentifier:(NSString *)systemIdentifier;

@end

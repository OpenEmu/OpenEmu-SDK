// Copyright (c) 2020, OpenEmu Team
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the OpenEmu Team nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

// Note: all definitions here shall be either macros or inline functions, to
// mantain some degree of backwards compatibility with older OpenEmu versions.
// (inlining can be forced by using the NS_INLINE macro instead of the
// standard C `inline` keyword)


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


/*
 * Utility macros
 */
 
#define OEDisplayMode_OptionWithStateValue(_NAME_, _PREFKEY_, _STATE_, _VAL_) @{ \
    OEGameCoreDisplayModeNameKey : _NAME_, \
    OEGameCoreDisplayModePrefKeyNameKey : _PREFKEY_, \
    OEGameCoreDisplayModeStateKey : _STATE_, \
    OEGameCoreDisplayModePrefValueNameKey : _VAL_ }
    
#define OEDisplayMode_OptionWithValue(_NAME_, _PREFKEY_, _VAL_) \
    OEDisplayMode_OptionWithStateValue(_NAME_, _PREFKEY_, @NO, _VAL_)
    
#define OEDisplayMode_OptionDefaultWithValue(_NAME_, _PREFKEY_, _VAL_) \
    OEDisplayMode_OptionWithStateValue(_NAME_, _PREFKEY_, @YES, _VAL_)
 
#define OEDisplayMode_OptionWithState(_NAME_, _PREFKEY_, _STATE_) @{ \
    OEGameCoreDisplayModeNameKey : _NAME_, \
    OEGameCoreDisplayModePrefKeyNameKey : _PREFKEY_, \
    OEGameCoreDisplayModeStateKey : _STATE_ }

#define OEDisplayMode_Option(_NAME_, _PREFKEY_) \
    OEDisplayMode_OptionWithState(_NAME_, _PREFKEY_, @NO)

#define OEDisplayMode_OptionDefault(_NAME_, _PREFKEY_) \
    OEDisplayMode_OptionWithState(_NAME_, _PREFKEY_, @YES)

#define OEDisplayMode_OptionIndentedWithState(_NAME_, _PREFKEY_, _STATE_) @{ \
    OEGameCoreDisplayModeNameKey : _NAME_, \
    OEGameCoreDisplayModePrefKeyNameKey : _PREFKEY_, \
    OEGameCoreDisplayModeStateKey : _STATE_, \
    OEGameCoreDisplayModeIndentationLevelKey : @(1) }
    
#define OEDisplayMode_OptionIndented(_NAME_, _PREFKEY_) \
    OEDisplayMode_OptionIndentedWithState(_NAME_, _PREFKEY_, @NO)
    
#define OEDisplayMode_OptionDefaultIndented(_NAME_, _PREFKEY_) \
    OEDisplayMode_OptionIndentedWithState(_NAME_, _PREFKEY_, @YES)
    
#define OEDisplayMode_OptionToggleableWithState(_NAME_, _PREFKEY_, _STATE_) @{ \
    OEGameCoreDisplayModeNameKey : _NAME_, \
    OEGameCoreDisplayModePrefKeyNameKey : _PREFKEY_, \
    OEGameCoreDisplayModeStateKey : _STATE_, \
    OEGameCoreDisplayModeAllowsToggleKey : @YES }
    
#define OEDisplayMode_OptionToggleable(_NAME_, _PREFKEY_) \
    OEDisplayMode_OptionToggleableWithState(_NAME_, _PREFKEY_, @NO)
    
#define OEDisplayMode_OptionToggleableDefault(_NAME_, _PREFKEY_) \
    OEDisplayMode_OptionToggleableWithState(_NAME_, _PREFKEY_, @YES)
    
#define OEDisplayMode_OptionToggleableNoSaveWithState(_NAME_, _PREFKEY_, _STATE_) @{ \
    OEGameCoreDisplayModeNameKey : _NAME_, \
    OEGameCoreDisplayModePrefKeyNameKey : _PREFKEY_, \
    OEGameCoreDisplayModeStateKey : _STATE_, \
    OEGameCoreDisplayModeAllowsToggleKey : @YES, \
    OEGameCoreDisplayModeDisallowPrefSaveKey : @YES }
    
#define OEDisplayMode_OptionToggleableNoSave(_NAME_, _PREFKEY_) \
    OEDisplayMode_OptionToggleableNoSaveWithState(_NAME_, _PREFKEY_, @NO)
    
#define OEDisplayMode_OptionToggleableNoSaveDefault(_NAME_, _PREFKEY_) \
    OEDisplayMode_OptionToggleableNoSaveWithState(_NAME_, _PREFKEY_, @YES)
    
#define OEDisplayMode_OptionManualWithState(_NAME_, _PREFKEY_, _STATE_) @{ \
    OEGameCoreDisplayModeNameKey : _NAME_, \
    OEGameCoreDisplayModePrefKeyNameKey : _PREFKEY_, \
    OEGameCoreDisplayModeStateKey : _STATE_, \
    OEGameCoreDisplayModeManualOnlyKey : @YES }
    
#define OEDisplayMode_OptionManual(_NAME_, _PREFKEY_) \
    OEDisplayMode_OptionManualWithState(_NAME_, _PREFKEY_, @NO)

#define OEDisplayMode_OptionManualDefault(_NAME_, _PREFKEY_) \
    OEDisplayMode_OptionManualWithState(_NAME_, _PREFKEY_, @YES)
    
#define OEDisplayMode_Label(_NAME_) @{ \
    OEGameCoreDisplayModeLabelKey : _NAME_ }

#define OEDisplayMode_SeparatorItem() @{ \
    OEGameCoreDisplayModeSeparatorItemKey : @"" }

#define OEDisplayMode_Submenu(_NAME_, ...) @{ \
    OEGameCoreDisplayModeGroupNameKey: _NAME_, \
    OEGameCoreDisplayModeGroupItemsKey: __VA_ARGS__ }


NS_INLINE BOOL OEDisplayModeListGetPrefKeyValueFromModeName(
    NSArray<NSDictionary<NSString *,id> *> *list, NSString *name,
    NSString * __autoreleasing *outKey, id __autoreleasing *outValue)
{
    for (NSDictionary<NSString *,id> *option in list) {
        if (option[OEGameCoreDisplayModeGroupNameKey]) {
            NSArray *content = option[OEGameCoreDisplayModeGroupItemsKey];
            BOOL res = OEDisplayModeListGetPrefKeyValueFromModeName(content, name, outKey, outValue);
            if (res) return res;
        } else {
            NSString *optname = option[OEGameCoreDisplayModeNameKey];
            if (!optname) continue;
            if ([optname isEqual:name]) {
                if (outKey) *outKey = option[OEGameCoreDisplayModePrefKeyNameKey];
                if (outValue) {
                    BOOL toggleable = [option[OEGameCoreDisplayModeAllowsToggleKey] boolValue];
                    if (toggleable) {
                        *outValue = option[OEGameCoreDisplayModeStateKey];
                    } else {
                        id val = option[OEGameCoreDisplayModePrefValueNameKey];
                        *outValue = val ?: optname;
                    }
                }
                return YES;
            }
        }
    }
    return NO;
}

NS_INLINE NSString *OEDisplayModeListGetPrefKeyFromModeName(
    NSArray<NSDictionary<NSString *,id> *> *list, NSString *name)
{
    NSString *tmp;
    BOOL res = OEDisplayModeListGetPrefKeyValueFromModeName(list, name, &tmp, NULL);
    return res ? tmp : nil;
}


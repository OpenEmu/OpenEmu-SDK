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
 * Keys for AdvanceMenu Entries.
 */
 
/* Groups (submenus) */

/** This NSString will be used as the Title for the submenu*/
#define OEGameCoreAdvancedMenuGroupNameKey @"OEGameCoreAdvancedMenuGroupNameKey"

/** The NSString which will differentiate submenu items from each other
 *  for the submenu. */
#define OEGameCoreAdvancedMenuGroupIDKey @"OEGameCoreAdvancedMenuGroupIDKey"

/** An NSArray of NSDictionaries containing the entries in the group.
 *  @warning Only one level of indentation is supported to disallow over-complicated
 *    menus. */
#define OEGameCoreAdvancedMenuGroupItemsKey @"OEGameCoreAdvancedMenuGroupItemsKey"

/* Binary (toggleable) and Mutually-Exclusive Display Modes */

/** The NSString which will be shown in the Display Mode menu for this entry. This
 *  string must be unique to each display mode. */
#define OEGameCoreAdvancedMenuNameKey @"OEGameCoreAdvancedMenuNameKey"
/** Toggleable modes only. @(YES) if this mode is standalone and can be toggled.
 *  If @(NO) or unspecified, this item is part of a group of mutually-exclusive modes. */
#define OEGameCoreAdvancedMenuAllowsToggleKey @"OEGameCoreAdvancedMenuAllowsToggleKey"
/** Mutually-exclusive modes only. An NSString uniquely identifying this display mode
 *  within its group. Optional. if not specified, the value associated with
 *  OEGameCoreAdvancedMenuNameKey will be used instead. */
#define OEGameCoreAdvancedMenuPrefValueNameKey @"OEGameCoreAdvancedMenuPrefValueNameKey"
/** Toggleable modes: An NSString uniquely identifying this display mode.
 *  Mutually-exclusive modes: An NSString uniquely identifying the group of mutually
 *  exclusive modes this mode is part of.
 *  Every group of mutually-exclusive modes is defined implicitly as a set of modes with
 *  the same OEGameCoreAdvancedMenuPrefValueNameKey. */
#define OEGameCoreAdvancedMenuPrefKeyNameKey @"OEGameCoreAdvancedMenuPrefKeyNameKey"
/** @(YES) if this mode is currently selected. */
#define OEGameCoreAdvancedMenuStateKey @"OEGameCoreAdvancedMenuStateKey"
/** @(YES) if this mode is inaccessible through the nextAdvanceMenu: and lastAdvanceMenu:
 *  actions */
#define OEGameCoreAdvancedMenuManualOnlyKey @"OEGameCoreAdvancedMenuSubmenuOnlyKey"
/** @(YES) if this mode is not saved in the preferences. */
#define OEGameCoreAdvancedMenuDisallowPrefSaveKey @"OEGameCoreAdvancedMenuDisallowPrefSaveKey"

/* Labels & Separators */

/** Separator only. Present if this item is a separator. Value does not matter. */
#define OEGameCoreAdvancedMenuSeparatorItemKey @"OEGameCoreAdvancedMenuSeparatorItemKey"
/** Label only. The NSString which will be shown in the Display Mode menu for this label. */
#define OEGameCoreAdvancedMenuLabelKey @"OEGameCoreAdvancedMenuLabelKey"

/* Other Keys */

/** An NSNumber specifying the level of indentation of this item. */
#define OEGameCoreAdvancedMenuIndentationLevelKey @"OEGameCoreAdvancedMenuIndentationLevelKey"


/*
 * Utility macros
 */
 
#define OEAdvancedMenu_OptionWithStateValue(_NAME_, _GROUP_, _PREFKEY_, _STATE_, _VAL_) @{ \
    OEGameCoreAdvancedMenuNameKey : _NAME_, \
    OEGameCoreAdvancedMenuGroupIDKey : _GROUP_, \
    OEGameCoreAdvancedMenuPrefKeyNameKey : _PREFKEY_, \
    OEGameCoreAdvancedMenuStateKey : _STATE_, \
    OEGameCoreAdvancedMenuPrefValueNameKey : _VAL_ }
    
#define OEAdvancedMenu_OptionWithValue(_NAME_, _GROUP_, _PREFKEY_, _VAL_) \
    OEAdvancedMenu_OptionWithStateValue(_NAME_, _GROUP_, _PREFKEY_, @NO, _VAL_)
    
#define OEAdvancedMenu_OptionDefaultWithValue(_NAME_, _GROUP_, _PREFKEY_, _VAL_) \
    OEAdvancedMenu_OptionWithStateValue(_NAME_, _GROUP_, _PREFKEY_, @YES, _VAL_)
 
#define OEAdvancedMenu_OptionWithState(_NAME_, _GROUP_, _PREFKEY_, _STATE_) @{ \
    OEGameCoreAdvancedMenuNameKey : _NAME_, \
OEGameCoreAdvancedMenuGroupIDKey : _GROUP_, \
    OEGameCoreAdvancedMenuPrefKeyNameKey : _PREFKEY_, \
    OEGameCoreAdvancedMenuStateKey : _STATE_ }

#define OEAdvancedMenu_Option(_NAME_, _GROUP_, _PREFKEY_) \
    OEAdvancedMenu_OptionWithState(_NAME_, _GROUP_, _PREFKEY_, @NO)

#define OEAdvancedMenu_OptionDefault(_NAME_, _GROUP_, _PREFKEY_) \
    OEAdvancedMenu_OptionWithState(_NAME_, _GROUP_, _PREFKEY_, @YES)

#define OEAdvancedMenu_OptionIndentedWithState(_NAME_, _GROUP_, _PREFKEY_, _STATE_) @{ \
    OEGameCoreAdvancedMenuNameKey : _NAME_, \
    OEGameCoreAdvancedMenuGroupIDKey : _GROUP_, \
    OEGameCoreAdvancedMenuPrefKeyNameKey : _PREFKEY_, \
    OEGameCoreAdvancedMenuStateKey : _STATE_, \
    OEGameCoreAdvancedMenuIndentationLevelKey : @(1) }
    
#define OEAdvancedMenu_OptionIndented(_NAME_, _GROUP_,  _PREFKEY_) \
    OEAdvancedMenu_OptionIndentedWithState(_NAME_, _GROUP_, _PREFKEY_, @NO)
    
#define OEAdvancedMenu_OptionIndentedDefault(_NAME_, _GROUP_,  _PREFKEY_) \
    OEAdvancedMenu_OptionIndentedWithState(_NAME_, _GROUP_,  _PREFKEY_, @YES)
    
#define OEAdvancedMenu_OptionToggleableWithState(_NAME_, _GROUP_, _PREFKEY_, _STATE_) @{ \
    OEGameCoreAdvancedMenuNameKey : _NAME_, \
    OEGameCoreAdvancedMenuGroupIDKey : _GROUP_, \
    OEGameCoreAdvancedMenuPrefKeyNameKey : _PREFKEY_, \
    OEGameCoreAdvancedMenuStateKey : _STATE_, \
    OEGameCoreAdvancedMenuAllowsToggleKey : @YES }
    
#define OEAdvancedMenu_OptionToggleable(_NAME_, _GROUP_,  _PREFKEY_) \
    OEAdvancedMenu_OptionToggleableWithState(_NAME_, _GROUP_, _PREFKEY_, @NO)
    
#define OEAdvancedMenu_OptionToggleableDefault(_NAME_, _GROUP_, _PREFKEY_) \
    OEAdvancedMenu_OptionToggleableWithState(_NAME_, _GROUP_, _PREFKEY_, @YES)
    
#define OEAdvancedMenu_OptionToggleableNoSaveWithState(_NAME_, _GROUP_, _PREFKEY_, _STATE_) @{ \
    OEGameCoreAdvancedMenuNameKey : _NAME_, \
    OEGameCoreAdvancedMenuGroupIDKey : _GROUP_, \
    OEGameCoreAdvancedMenuPrefKeyNameKey : _PREFKEY_, \
    OEGameCoreAdvancedMenuStateKey : _STATE_, \
    OEGameCoreAdvancedMenuAllowsToggleKey : @YES, \
    OEGameCoreAdvancedMenuDisallowPrefSaveKey : @YES }
    
#define OEAdvancedMenu_OptionToggleableNoSave(_NAME_, _GROUP_, _PREFKEY_) \
    OEAdvancedMenu_OptionToggleableNoSaveWithState(_NAME_, _GROUP_, _PREFKEY_, @NO)
    
#define OEAdvancedMenu_OptionToggleableNoSaveDefault(_NAME_, _GROUP_, _PREFKEY_) \
    OEAdvancedMenu_OptionToggleableNoSaveWithState(_NAME_, _GROUP_, _PREFKEY_, @YES)
    
#define OEAdvancedMenu_OptionManualWithState(_NAME_, _GROUP_, _PREFKEY_, _STATE_) @{ \
    OEGameCoreAdvancedMenuNameKey : _NAME_, \
    OEGameCoreAdvancedMenuGroupIDKey : _GROUP_, \
    OEGameCoreAdvancedMenuPrefKeyNameKey : _PREFKEY_, \
    OEGameCoreAdvancedMenuStateKey : _STATE_, \
    OEGameCoreAdvancedMenuManualOnlyKey : @YES }
    
#define OEAdvancedMenu_OptionManual(_NAME_, _GROUP_, _PREFKEY_) \
    OEAdvancedMenu_OptionManualWithState(_NAME_, _GROUP_, _PREFKEY_, @NO)

#define OEAdvancedMenu_OptionManualDefault(_NAME_, _GROUP_, _PREFKEY_) \
    OEAdvancedMenu_OptionManualWithState(_NAME_, _GROUP_, _PREFKEY_, @YES)
    
#define OEAdvancedMenu_Label(_NAME_) @{ \
    OEGameCoreAdvancedMenuLabelKey : _NAME_ }

#define OEAdvancedMenu_SeparatorItem() @{ \
    OEGameCoreAdvancedMenuSeparatorItemKey : @"" }

#define OEAdvancedMenu_Submenu(_NAME_, ...) @{ \
    OEGameCoreAdvancedMenuGroupIDKey: _NAME_, \
    OEGameCoreAdvancedMenuGroupItemsKey: __VA_ARGS__ }


//NS_INLINE BOOL OEAdvancedMenuListGetPrefKeyValueFromModeName(
//    NSArray<NSDictionary<NSString *,id> *> *list, NSString *name,
//    NSString * __autoreleasing *outKey, id __autoreleasing *outValue)
//{
//    for (NSDictionary<NSString *,id> *option in list) {
//        if (option[OEGameCoreAdvancedMenuGroupNameKey]) {
//            NSArray *content = option[OEGameCoreAdvancedMenuGroupItemsKey];
//            BOOL res = OEAdvancedMenuListGetPrefKeyValueFromModeName(content, name, outKey, outValue);
//            if (res) return res;
//        } else {
//            NSString *optname = option[OEGameCoreAdvancedMenuNameKey];
//            if (!optname) continue;
//            if ([optname isEqual:name]) {
//                if (outKey) *outKey = option[OEGameCoreAdvancedMenuPrefKeyNameKey];
//                if (outValue) {
//                    BOOL toggleable = [option[OEGameCoreAdvancedMenuAllowsToggleKey] boolValue];
//                    if (toggleable) {
//                        *outValue = option[OEGameCoreAdvancedMenuStateKey];
//                    } else {
//                        id val = option[OEGameCoreAdvancedMenuPrefValueNameKey];
//                        *outValue = val ?: optname;
//                    }
//                }
//                return YES;
//            }
//        }
//    }
//    return NO;
//}
//
//NS_INLINE NSString *OEAdvancedMenuListGetPrefKeyFromModeName(
//    NSArray<NSDictionary<NSString *,id> *> *list, NSString *name)
//{
//    NSString *tmp;
//    BOOL res = OEAdvancedMenuListGetPrefKeyValueFromModeName(list, name, &tmp, NULL);
//    return res ? tmp : nil;
//}


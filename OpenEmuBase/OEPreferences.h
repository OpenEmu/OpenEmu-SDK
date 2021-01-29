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

/** This NSString will be used as the Title for the Group*/
#define OEPreferenceGroupNameKey @"OEPreferenceGroupNameKey"

/** The NSString which will differentiate Group items from each other when the options have identical names. */
#define OEPreferenceGroupIDKey @"OEPreferenceGroupIDKey"

/** An NSArray of NSDictionaries containing the entries in the group. */
#define OEPreferenceGroupItemsKey @"OEPreferenceGroupItemsKey"

/* Binary (toggleable) and Mutually-Exclusive Display Modes */

/** The NSString which will be shown in the Display Mode menu for this entry. This
 *  string must be unique to each display mode. */
#define OEPreferenceNameKey @"OEPreferenceNameKey"
/** Toggleable modes only. @(YES) if this mode is standalone and can be toggled.
 *  If @(NO) or unspecified, this item is part of a group of mutually-exclusive modes. */
#define OEPreferenceAllowsToggleKey @"OEPreferenceAllowsToggleKey"
/** Mutually-exclusive modes only. An NSString uniquely identifying this display mode
 *  within its group. Optional. if not specified, the value associated with
 *  OEPreferenceNameKey will be used instead. */
#define OEPreferencePrefValueNameKey @"OEPreferencePrefValueNameKey"
/** Toggleable modes: An NSString uniquely identifying this display mode.
 *  Mutually-exclusive modes: An NSString uniquely identifying the group of mutually
 *  exclusive modes this mode is part of.
 *  Every group of mutually-exclusive modes is defined implicitly as a set of modes with
 *  the same OEPreferencePrefValueNameKey. */
#define OEPreferencePrefKeyNameKey @"OEPreferencePrefKeyNameKey"
/** @(YES) if this mode is currently selected. */
#define OEPreferenceStateKey @"OEPreferenceStateKey"
/** @(YES) if this mode is inaccessible through the nextAdvanceMenu: and lastAdvanceMenu:
 *  actions */
#define OEPreferenceManualOnlyKey @"OEPreferenceSubmenuOnlyKey"
/** @(YES) if this mode is not saved in the preferences. */
#define OEPreferenceDisallowPrefSaveKey @"OEPreferenceDisallowPrefSaveKey"

/* Slider */
#define OEPreferenceMinKey @"OEPreferenceMinKey"
#define OEPreferenceMaxKey @"OEPreferenceMaxKey"
#define OEPreferenceDefaultValKey @"OEPreferenceDefaultValKey"
/* Labels & Separators */

/** Separator only. Present if this item is a separator. Value does not matter. */
#define OEPreferenceSeparatorItemKey @"OEPreferenceSeparatorItemKey"
/** Label only. The NSString which will be shown in the Display Mode menu for this label. */
#define OEPreferenceLabelKey @"OEPreferenceLabelKey"

/* Other Keys */

/** An NSNumber specifying the level of indentation of this item. */
#define OEPreferenceIndentationLevelKey @"OEPreferenceIndentationLevelKey"


/*
 * Utility macros
 */
 
#define OEPreference_OptionWithStateValue(_NAME_, _GROUP_, _PREFKEY_, _STATE_, _VAL_) @{ \
    OEPreferenceNameKey : _NAME_, \
    OEPreferenceGroupIDKey : _GROUP_, \
    OEPreferencePrefKeyNameKey : _PREFKEY_, \
    OEPreferenceStateKey : _STATE_, \
    OEPreferencePrefValueNameKey : _VAL_ }
    
#define OEPreference_OptionWithValue(_NAME_, _GROUP_, _PREFKEY_, _VAL_) \
    OEPreference_OptionWithStateValue(_NAME_, _GROUP_, _PREFKEY_, @NO, _VAL_)
    
#define OEPreference_OptionDefaultWithValue(_NAME_, _GROUP_, _PREFKEY_, _VAL_) \
    OEPreference_OptionWithStateValue(_NAME_, _GROUP_, _PREFKEY_, @YES, _VAL_)
 
#define OEPreference_OptionWithState(_NAME_, _GROUP_, _PREFKEY_, _STATE_) @{ \
    OEPreferenceNameKey : _NAME_, \
OEPreferenceGroupIDKey : _GROUP_, \
    OEPreferencePrefKeyNameKey : _PREFKEY_, \
    OEPreferenceStateKey : _STATE_ }

#define OEPreference_Option(_NAME_, _GROUP_, _PREFKEY_) \
    OEPreference_OptionWithState(_NAME_, _GROUP_, _PREFKEY_, @NO)

#define OEPreference_OptionDefault(_NAME_, _GROUP_, _PREFKEY_) \
    OEPreference_OptionWithState(_NAME_, _GROUP_, _PREFKEY_, @YES)

#define OEPreference_OptionIndentedWithState(_NAME_, _GROUP_, _PREFKEY_, _STATE_) @{ \
    OEPreferenceNameKey : _NAME_, \
    OEPreferenceGroupIDKey : _GROUP_, \
    OEPreferencePrefKeyNameKey : _PREFKEY_, \
    OEPreferenceStateKey : _STATE_, \
    OEPreferenceIndentationLevelKey : @(1) }
    
#define OEPreference_OptionIndented(_NAME_, _GROUP_,  _PREFKEY_) \
    OEPreference_OptionIndentedWithState(_NAME_, _GROUP_, _PREFKEY_, @NO)
    
#define OEPreference_OptionIndentedDefault(_NAME_, _GROUP_,  _PREFKEY_) \
    OEPreference_OptionIndentedWithState(_NAME_, _GROUP_,  _PREFKEY_, @YES)
    
#define OEPreference_OptionToggleableWithState(_NAME_, _GROUP_, _PREFKEY_, _STATE_) @{ \
    OEPreferenceNameKey : _NAME_, \
    OEPreferenceGroupIDKey : _GROUP_, \
    OEPreferencePrefKeyNameKey : _PREFKEY_, \
    OEPreferenceStateKey : _STATE_, \
    OEPreferenceAllowsToggleKey : @YES }
    
#define OEPreference_OptionToggleable(_NAME_, _GROUP_,  _PREFKEY_) \
    OEPreference_OptionToggleableWithState(_NAME_, _GROUP_, _PREFKEY_, @NO)
    
#define OEPreference_OptionToggleableDefault(_NAME_, _GROUP_, _PREFKEY_) \
    OEPreference_OptionToggleableWithState(_NAME_, _GROUP_, _PREFKEY_, @YES)
    
#define OEPreference_OptionToggleableNoSaveWithState(_NAME_, _GROUP_, _PREFKEY_, _STATE_) @{ \
    OEPreferenceNameKey : _NAME_, \
    OEPreferenceGroupIDKey : _GROUP_, \
    OEPreferencePrefKeyNameKey : _PREFKEY_, \
    OEPreferenceStateKey : _STATE_, \
    OEPreferenceAllowsToggleKey : @YES, \
    OEPreferenceDisallowPrefSaveKey : @YES }
    
#define OEPreference_OptionToggleableNoSave(_NAME_, _GROUP_, _PREFKEY_) \
    OEPreference_OptionToggleableNoSaveWithState(_NAME_, _GROUP_, _PREFKEY_, @NO)
    
#define OEPreference_OptionToggleableNoSaveDefault(_NAME_, _GROUP_, _PREFKEY_) \
    OEPreference_OptionToggleableNoSaveWithState(_NAME_, _GROUP_, _PREFKEY_, @YES)
    
#define OEPreference_OptionManualWithState(_NAME_, _GROUP_, _PREFKEY_, _STATE_) @{ \
    OEPreferenceNameKey : _NAME_, \
    OEPreferenceGroupIDKey : _GROUP_, \
    OEPreferencePrefKeyNameKey : _PREFKEY_, \
    OEPreferenceStateKey : _STATE_, \
    OEPreferenceManualOnlyKey : @YES }
    
#define OEPreference_OptionManual(_NAME_, _GROUP_, _PREFKEY_) \
    OEPreference_OptionManualWithState(_NAME_, _GROUP_, _PREFKEY_, @NO)

#define OEPreference_OptionManualDefault(_NAME_, _GROUP_, _PREFKEY_) \
    OEPreference_OptionManualWithState(_NAME_, _GROUP_, _PREFKEY_, @YES)
    
#define OEPreference_Slider(_NAME_, _GROUP_, _PREFKEY_, _MIN_, _MAX_, _VAL_) @{ \
    OEPreference_SliderWithDefaultVal(_NAME_, _GROUP_, _PREFKEY_, _MIN_, _MAX_, _MIN_) }

#define OEPreference_SliderWithDefaultVal(_NAME_, _GROUP_, _PREFKEY_, _MIN_, _MAX_, _VAL_) @{ \
    OEPreferenceNameKey : _NAME_, \
    OEPreferenceGroupIDKey : _GROUP_, \
    OEPreferencePrefKeyNameKey : _PREFKEY_, \
    OEPreferenceMinKey : _MIN_, \
    OEPreferenceMaxKey : _MAX_, \
    OEPreferenceDefaultValKey : _VAL_ }

#define OEPreference_Label(_NAME_) @{ \
    OEPreferenceLabelKey : _NAME_ }

#define OEPreference_SeparatorItem() @{ \
    OEPreferenceSeparatorItemKey : @"" }

#define OEPreference_Submenu(_NAME_, ...) @{ \
    OEPreferenceGroupIDKey: _NAME_, \
    OEPreferenceGroupItemsKey: __VA_ARGS__ }


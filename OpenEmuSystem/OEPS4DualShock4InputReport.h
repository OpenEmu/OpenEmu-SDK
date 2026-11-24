// Copyright (c) 2026, OpenEmu Team
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

/*
 * Wire format of the DualShock 4 input reports, kept separate from the device
 * handler so that the decoding can be exercised by unit tests without a controller
 * attached.
 *
 * Documented at https://www.psdevwiki.com/ps4/DS4-BT and implemented in the Linux
 * kernel in drivers/hid/hid-playstation.c (struct dualshock4_input_report_bt) and in
 * SDL's src/joystick/hidapi/SDL_hidapi_ps4.c.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


/* Sony's vendor ID, and the product IDs of the two DualShock 4 revisions. The USB
 * wireless adapter (0x0BA0) is deliberately absent: it is a USB device, and this
 * format is only decoded for Bluetooth connections. */
#define OEDS4VendorIDSony        (0x054C)
#define OEDS4ProductIDDualShock4   (0x05C4) /* CUH-ZCT1 */
#define OEDS4ProductIDDualShock4V2 (0x09CC) /* CUH-ZCT2 */


typedef NS_ENUM(uint8_t, OEDS4InputReportID) {
    /* The short report the controller sends over Bluetooth until something reads
     * one of its feature reports. Its first ten bytes have the same layout as the
     * USB report 0x01. */
    OEDS4InputReportIDSimple   = 0x01,
    /* The full report, whose payload the HID descriptor declares as vendor
     * defined, so IOKit exposes no usable elements for it. */
    OEDS4InputReportIDExtended = 0x11,
};


typedef NS_ENUM(uint8_t, OEDS4FeatureReportID) {
    /* Reading this report is what the Linux driver does on Bluetooth to fetch
     * calibration data; the switch to report 0x11 happens as a side effect. */
    OEDS4FeatureReportIDCalibrationBT = 0x05,
};

/* Matches DS4_FEATURE_REPORT_CALIBRATION_BT_SIZE in hid-playstation.c. */
#define OEDS4_CALIBRATION_BT_FEATURE_REPORT_SIZE (41)

/* Byte 0 of an extended report is the report ID, byte 1 carries flags and byte 2 is
 * reserved. The payload, laid out like the USB report from its byte 1 on, starts at
 * byte 3. */
#define OEDS4_EXTENDED_REPORT_PAYLOAD_OFFSET (3)

/* Full size of an extended report, matching DS4_INPUT_REPORT_BT_SIZE. The last four
 * bytes are a CRC32 which we do not verify: a corrupted report costs at most one
 * frame of wrong input, never corrupted state. */
#define OEDS4_EXTENDED_REPORT_SIZE (78)

/* Bit 7 of byte 1 says whether the report carries controller input at all. SDL
 * skips reports without it; so do we. */
#define OEDS4_EXTENDED_REPORT_FLAG_HAS_INPUT (0x80)

/* The short report is ten bytes including the report ID. Longer reports with ID
 * 0x01 (the 64 byte USB report) share the same layout for these bytes, so anything
 * at least this long decodes the same way. */
#define OEDS4_SIMPLE_REPORT_MIN_SIZE (10)


/* The button bytes are bit-for-bit the same as the DualSense's, minus the mic mute
 * button the DualShock 4 does not have. */
typedef NS_OPTIONS(uint8_t, OEDS4ButtonState0) {
    OEDS4ButtonState0Square   = 1 << 4,
    OEDS4ButtonState0Cross    = 1 << 5,
    OEDS4ButtonState0Circle   = 1 << 6,
    OEDS4ButtonState0Triangle = 1 << 7,
};

/* Bits 0-3 of the first button byte are a hat switch value counting clockwise
 * from north, not flags. */
typedef NS_ENUM(uint8_t, OEDS4HatSwitchValue) {
    OEDS4HatSwitchNorth = 0,
    OEDS4HatSwitchNorthEast,
    OEDS4HatSwitchEast,
    OEDS4HatSwitchSouthEast,
    OEDS4HatSwitchSouth,
    OEDS4HatSwitchSouthWest,
    OEDS4HatSwitchWest,
    OEDS4HatSwitchNorthWest,
    /* every value from here up means the D-Pad is centred */
    OEDS4HatSwitchCentered = 8,
};

typedef NS_OPTIONS(uint8_t, OEDS4ButtonState1) {
    OEDS4ButtonState1L1      = 1 << 0,
    OEDS4ButtonState1R1      = 1 << 1,
    OEDS4ButtonState1L2      = 1 << 2,
    OEDS4ButtonState1R2      = 1 << 3,
    OEDS4ButtonState1Share   = 1 << 4,
    OEDS4ButtonState1Options = 1 << 5,
    OEDS4ButtonState1L3      = 1 << 6,
    OEDS4ButtonState1R3      = 1 << 7,
};

typedef NS_OPTIONS(uint8_t, OEDS4ButtonState2) {
    OEDS4ButtonState2PSHome   = 1 << 0,
    OEDS4ButtonState2Touchpad = 1 << 1,
    /* Bits 2-7 are a free running frame counter in every layout. Reading them as
     * buttons would emit phantom presses at report rate, so they are masked off. */
};

#define OEDS4_BUTTON2_MASK (OEDS4ButtonState2PSHome | OEDS4ButtonState2Touchpad)


/* The part of the payload OpenEmu dispatches; motion, touchpad and battery data
 * follow it. Named after hid-playstation's dualshock4_input_report_common. */
typedef struct __attribute__((packed)) {
    uint8_t leftX, leftY;
    uint8_t rightX, rightY;
    OEDS4ButtonState0 buttons0;
    OEDS4ButtonState1 buttons1;
    OEDS4ButtonState2 buttons2;
    uint8_t l2, r2;
} OEDS4InputReportHead;

_Static_assert(sizeof(OEDS4InputReportHead) == 9,
               "OEDS4InputReportHead must stay a byte-exact overlay of the report payload");


/* The parts of a report OpenEmu dispatches, normalized across the layouts.
 *
 * A zeroed OEDS4InputState is NOT a neutral controller: the sticks would read as
 * pinned to the top-left corner and the hat nibble as north. Use
 * OEDS4InputStateNeutral() instead of {0}. */
typedef struct {
    uint8_t leftX, leftY;
    uint8_t rightX, rightY;
    uint8_t l2, r2;
    OEDS4ButtonState0 buttons0;
    OEDS4ButtonState1 buttons1;
    OEDS4ButtonState2 buttons2;
} OEDS4InputState;

#define OEDS4_STICK_NEUTRAL (0x80)

static inline OEDS4InputState OEDS4InputStateNeutral(void)
{
    return (OEDS4InputState){
        .leftX  = OEDS4_STICK_NEUTRAL, .leftY  = OEDS4_STICK_NEUTRAL,
        .rightX = OEDS4_STICK_NEUTRAL, .rightY = OEDS4_STICK_NEUTRAL,
        .l2 = 0, .r2 = 0,
        .buttons0 = (OEDS4ButtonState0)OEDS4HatSwitchCentered, .buttons1 = 0, .buttons2 = 0,
    };
}


/* Maps each button bit to the button number the existing OEControllerSonyPS4Dualshock4
 * entry in Controller-Database.plist declares, as {mask, number, ..., 0}. Kept here
 * so the tests can check them against the database. */
static inline const uint8_t *OEDS4ButtonState0Map(void)
{
    static const uint8_t map[] = {
        OEDS4ButtonState0Square,   1,
        OEDS4ButtonState0Cross,    2,
        OEDS4ButtonState0Circle,   3,
        OEDS4ButtonState0Triangle, 4,
        0};
    return map;
}

static inline const uint8_t *OEDS4ButtonState1Map(void)
{
    static const uint8_t map[] = {
        OEDS4ButtonState1L1,       5,
        OEDS4ButtonState1R1,       6,
        OEDS4ButtonState1L2,       7,
        OEDS4ButtonState1R2,       8,
        OEDS4ButtonState1Share,    9,
        OEDS4ButtonState1Options, 10,
        OEDS4ButtonState1L3,      11,
        OEDS4ButtonState1R3,      12,
        0};
    return map;
}

static inline const uint8_t *OEDS4ButtonState2Map(void)
{
    static const uint8_t map[] = {
        OEDS4ButtonState2PSHome,   13,
        OEDS4ButtonState2Touchpad, 14,
        0};
    return map;
}


static inline OEDS4HatSwitchValue OEDS4HatSwitchFromButtonState0(OEDS4ButtonState0 buttons0)
{
    uint8_t value = buttons0 & 0x0F;
    return value > OEDS4HatSwitchCentered ? OEDS4HatSwitchCentered : (OEDS4HatSwitchValue)value;
}


typedef NS_ENUM(NSInteger, OEDS4DecodeResult) {
    /* outState holds the controller state carried by the report. */
    OEDS4DecodeResultDecoded,
    /* A well formed report that carries no controller input; nothing to do. */
    OEDS4DecodeResultNoInput,
    /* A report this decoder does not understand: wrong ID or too short. */
    OEDS4DecodeResultUndecodable,
};


static inline void OEDS4CopyHeadToState(const OEDS4InputReportHead *head, OEDS4InputState *outState)
{
    outState->leftX    = head->leftX;
    outState->leftY    = head->leftY;
    outState->rightX   = head->rightX;
    outState->rightY   = head->rightY;
    outState->l2       = head->l2;
    outState->r2       = head->r2;
    outState->buttons0 = head->buttons0;
    outState->buttons1 = head->buttons1;
    outState->buttons2 = head->buttons2 & OEDS4_BUTTON2_MASK;
}


/* Decodes the extended report 0x11. Over Bluetooth it is always
 * OEDS4_EXTENDED_REPORT_SIZE bytes; a shorter one is anomalous, and accepting it
 * would decode whatever followed the truncation as input. */
static inline OEDS4DecodeResult OEDS4DecodeExtendedReport(const uint8_t *data, NSUInteger length, OEDS4InputState *outState)
__attribute__((warn_unused_result));

static inline OEDS4DecodeResult OEDS4DecodeExtendedReport(const uint8_t *data, NSUInteger length, OEDS4InputState *outState)
{
    if (length < OEDS4_EXTENDED_REPORT_SIZE)
        return OEDS4DecodeResultUndecodable;

    if (!(data[1] & OEDS4_EXTENDED_REPORT_FLAG_HAS_INPUT))
        return OEDS4DecodeResultNoInput;

    OEDS4CopyHeadToState((const OEDS4InputReportHead *)(data + OEDS4_EXTENDED_REPORT_PAYLOAD_OFFSET), outState);
    return OEDS4DecodeResultDecoded;
}


/* Decodes report 0x01, whose payload starts right after the report ID. */
static inline OEDS4DecodeResult OEDS4DecodeSimpleReport(const uint8_t *data, NSUInteger length, OEDS4InputState *outState)
__attribute__((warn_unused_result));

static inline OEDS4DecodeResult OEDS4DecodeSimpleReport(const uint8_t *data, NSUInteger length, OEDS4InputState *outState)
{
    if (length < OEDS4_SIMPLE_REPORT_MIN_SIZE)
        return OEDS4DecodeResultUndecodable;

    OEDS4CopyHeadToState((const OEDS4InputReportHead *)(data + 1), outState);
    return OEDS4DecodeResultDecoded;
}


static inline OEDS4DecodeResult OEDS4DecodeInputReport(uint8_t reportID, const uint8_t *data, NSUInteger length, OEDS4InputState *outState)
__attribute__((warn_unused_result));

static inline OEDS4DecodeResult OEDS4DecodeInputReport(uint8_t reportID, const uint8_t *data, NSUInteger length, OEDS4InputState *outState)
{
    switch (reportID) {
        case OEDS4InputReportIDExtended: return OEDS4DecodeExtendedReport(data, length, outState);
        case OEDS4InputReportIDSimple:   return OEDS4DecodeSimpleReport(data, length, outState);
        default:                         return OEDS4DecodeResultUndecodable;
    }
}


NS_ASSUME_NONNULL_END

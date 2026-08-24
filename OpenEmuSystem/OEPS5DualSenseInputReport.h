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
 * Wire format of the DualSense Bluetooth input reports, kept separate from the
 * device handler so that the decoding can be exercised by unit tests without a
 * controller attached.
 *
 * Documented at https://github.com/nondebug/dualsense and implemented in the Linux
 * kernel in drivers/hid/hid-playstation.c
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


/* Sony's vendor ID, and the product IDs of the controllers using this report format. */
#define OEDSVendorIDSony            (0x054C)
#define OEDSProductIDDualSense      (0x0CE6)
#define OEDSProductIDDualSenseEdge  (0x0DF2)


typedef NS_ENUM(uint8_t, OEDSInputReportID) {
    /* Over Bluetooth, the cut-down report the controller sends before something
     * switches it into extended mode. */
    OEDSInputReportIDSimple   = 0x01,
    /* The full report, wrapped in a vendor defined container. */
    OEDSInputReportIDExtended = 0x31,
};


typedef NS_ENUM(uint8_t, OEDSFeatureReportID) {
    /* Reading a feature report appears to be what switches the controller into
     * extended mode. Which report does it is not documented - sources name 0x05,
     * 0x09 and 0x20, and SDL flips it with an output report instead. This is simply
     * the one the Linux driver reads, for calibration data, getting the switch as a
     * side effect. */
    OEDSFeatureReportIDCalibration = 0x05,
};

/* Matches DS_FEATURE_REPORT_CALIBRATION_SIZE in hid-playstation.c. We discard the
 * data itself and only care that the request goes through. */
#define OEDS_CALIBRATION_FEATURE_REPORT_SIZE (41)

/* Byte 0 of an extended report is the report ID; byte 1 carries flags and a rolling
 * counter that nothing here reads. The payload starts at byte 2. */
#define OEDS_EXTENDED_REPORT_PAYLOAD_OFFSET (2)

/* Full size of an extended report, matching DS_INPUT_REPORT_BT_SIZE. The last four
 * bytes are a CRC32 which we do not verify: a corrupted report costs at most one
 * frame of wrong input, never corrupted state. */
#define OEDS_EXTENDED_REPORT_SIZE (78)

/* The cut-down report has exactly one valid size, report ID included. */
#define OEDS_SIMPLE_REPORT_SIZE (10)


typedef NS_OPTIONS(uint8_t, OEDSButtonState0) {
    OEDSButtonState0Square   = 1 << 4,
    OEDSButtonState0Cross    = 1 << 5,
    OEDSButtonState0Circle   = 1 << 6,
    OEDSButtonState0Triangle = 1 << 7,
};

/* Bits 0-3 of the first button byte are not flags but a hat switch value counting
 * clockwise from north. Kept out of OEDSButtonState0 because an NS_OPTIONS is a
 * promise that its constants are disjoint bits to be tested independently. */
typedef NS_ENUM(uint8_t, OEDSHatSwitchValue) {
    OEDSHatSwitchNorth = 0,
    OEDSHatSwitchNorthEast,
    OEDSHatSwitchEast,
    OEDSHatSwitchSouthEast,
    OEDSHatSwitchSouth,
    OEDSHatSwitchSouthWest,
    OEDSHatSwitchWest,
    OEDSHatSwitchNorthWest,
    /* every value from here up means the D-Pad is centred */
    OEDSHatSwitchCentered = 8,
};


typedef NS_OPTIONS(uint8_t, OEDSButtonState1) {
    OEDSButtonState1L1      = 1 << 0,
    OEDSButtonState1R1      = 1 << 1,
    OEDSButtonState1L2      = 1 << 2,
    OEDSButtonState1R2      = 1 << 3,
    OEDSButtonState1Create  = 1 << 4,
    OEDSButtonState1Options = 1 << 5,
    OEDSButtonState1L3      = 1 << 6,
    OEDSButtonState1R3      = 1 << 7,
};


typedef NS_OPTIONS(uint8_t, OEDSButtonState2) {
    OEDSButtonState2PSHome   = 1 << 0,
    OEDSButtonState2Touchpad = 1 << 1,
    OEDSButtonState2MicMute  = 1 << 2,
    /* In an extended report bit 3 is unused and bits 4-7 carry the DualSense Edge's
     * FN1, FN2 and paddle buttons, which OpenEmu does not expose.
     *
     * A cut-down report has no mic mute button at all - its descriptor declares 14
     * buttons where the extended one declares 15 - and bits 2-7 are a free running
     * counter. OEDSDecodeSimpleReport masks the byte accordingly, because reading
     * the counter's low bit as mic mute would emit a phantom press at report rate. */
};

/* The buttons present in a cut-down report: PS and touchpad only. */
#define OEDS_SIMPLE_REPORT_BUTTON2_MASK (OEDSButtonState2PSHome | OEDSButtonState2Touchpad)


/* Head of the payload shared by the USB and Bluetooth full reports. Motion,
 * touchpad, battery and status data follow the fields declared here; OpenEmu has no
 * use for any of it, so the struct deliberately stops early and sizeof() is a lower
 * bound on a usable report rather than the report length. */
typedef struct __attribute__((packed)) {
    /* Field names follow the wire order, not the HID usages they end up dispatched
     * as: the right stick goes out as Z/Rz and the triggers as Rx/Ry. */
    uint8_t leftX, leftY;
    uint8_t rightX, rightY;
    uint8_t l2, r2;
    uint8_t seqNumber;
    OEDSButtonState0 buttons0;
    OEDSButtonState1 buttons1;
    OEDSButtonState2 buttons2;
    /* the kernel's struct declares buttons[4]; the fourth byte is unread */
    uint8_t buttons3;
} OEDSInputReportHead;

/* The extended decode rests on this layout. The assert catches accidental padding
 * or a lost field; a reordering keeps sizeof at 11 and is caught instead by
 * testExtendedReportDecodesCapturedHardwareBytes. */
_Static_assert(sizeof(OEDSInputReportHead) == 11,
               "OEDSInputReportHead must stay a byte-exact overlay of the report payload");


/* The parts of a report OpenEmu dispatches, normalized across the two wire layouts.
 *
 * Note that a zeroed OEDSInputState is NOT a neutral controller: the sticks would
 * read as pinned to the top-left corner (neutral is 0x80) and the hat nibble would
 * read as north. Use OEDSInputStateNeutral() instead of {0}. */
typedef struct {
    uint8_t leftX, leftY;
    uint8_t rightX, rightY;
    uint8_t l2, r2;
    OEDSButtonState0 buttons0;
    OEDSButtonState1 buttons1;
    OEDSButtonState2 buttons2;
} OEDSInputState;

#define OEDS_STICK_NEUTRAL (0x80)

static inline OEDSInputState OEDSInputStateNeutral(void)
{
    return (OEDSInputState){
        .leftX  = OEDS_STICK_NEUTRAL, .leftY  = OEDS_STICK_NEUTRAL,
        .rightX = OEDS_STICK_NEUTRAL, .rightY = OEDS_STICK_NEUTRAL,
        .l2 = 0, .r2 = 0,
        .buttons0 = (OEDSButtonState0)OEDSHatSwitchCentered, .buttons1 = 0, .buttons2 = 0,
    };
}


/* Maps each button bit to the button number the OEControllerSonyPS5DualSense entry
 * in Controller-Database.plist declares. Laid out as {mask, number, ..., 0} so the
 * handler can walk them, and kept here so tests can check them against the database
 * from both sides rather than against a copy of the same list. */
static inline const uint8_t *OEDSButtonState0Map(void)
{
    static const uint8_t map[] = {
        OEDSButtonState0Square,   1,
        OEDSButtonState0Cross,    2,
        OEDSButtonState0Circle,   3,
        OEDSButtonState0Triangle, 4,
        0};
    return map;
}

static inline const uint8_t *OEDSButtonState1Map(void)
{
    static const uint8_t map[] = {
        OEDSButtonState1L1,       5,
        OEDSButtonState1R1,       6,
        OEDSButtonState1L2,       7,
        OEDSButtonState1R2,       8,
        OEDSButtonState1Create,   9,
        OEDSButtonState1Options, 10,
        OEDSButtonState1L3,      11,
        OEDSButtonState1R3,      12,
        0};
    return map;
}

static inline const uint8_t *OEDSButtonState2Map(void)
{
    static const uint8_t map[] = {
        OEDSButtonState2PSHome,   13,
        OEDSButtonState2Touchpad, 14,
        OEDSButtonState2MicMute,  15,
        0};
    return map;
}


static inline OEDSHatSwitchValue OEDSHatSwitchFromButtonState0(OEDSButtonState0 buttons0)
{
    uint8_t value = buttons0 & 0x0F;
    return value > OEDSHatSwitchCentered ? OEDSHatSwitchCentered : (OEDSHatSwitchValue)value;
}


/* Decodes the extended report 0x31. Over Bluetooth this report is always
 * OEDS_EXTENDED_REPORT_SIZE bytes, so a shorter one is anomalous: accepting it
 * would decode whatever happened to follow the truncation as stick and button
 * input, silently and with nothing in the log. Note the fields actually read stop
 * at byte 13; the rest of the report is checked for presence, not consumed. */
static inline BOOL OEDSDecodeExtendedReport(const uint8_t *data, NSUInteger length, OEDSInputState *outState)
__attribute__((warn_unused_result));

static inline BOOL OEDSDecodeExtendedReport(const uint8_t *data, NSUInteger length, OEDSInputState *outState)
{
    if (length < OEDS_EXTENDED_REPORT_SIZE)
        return NO;

    const OEDSInputReportHead *head =
        (const OEDSInputReportHead *)(data + OEDS_EXTENDED_REPORT_PAYLOAD_OFFSET);

    outState->leftX    = head->leftX;
    outState->leftY    = head->leftY;
    outState->rightX   = head->rightX;
    outState->rightY   = head->rightY;
    outState->l2       = head->l2;
    outState->r2       = head->r2;
    outState->buttons0 = head->buttons0;
    outState->buttons1 = head->buttons1;
    outState->buttons2 = head->buttons2;

    return YES;
}


/* Decodes the cut-down report 0x01, which orders its fields differently: the analog
 * triggers come after the buttons rather than before them. The length must match
 * exactly - a longer report 0x01 is the USB full-report layout, and decoding that
 * here would silently read triggers as buttons. This handler only claims Bluetooth,
 * but the decoders are transport agnostic so that they stay unit testable. */
static inline BOOL OEDSDecodeSimpleReport(const uint8_t *data, NSUInteger length, OEDSInputState *outState)
__attribute__((warn_unused_result));

static inline BOOL OEDSDecodeSimpleReport(const uint8_t *data, NSUInteger length, OEDSInputState *outState)
{
    if (length != OEDS_SIMPLE_REPORT_SIZE)
        return NO;

    outState->leftX    = data[1];
    outState->leftY    = data[2];
    outState->rightX   = data[3];
    outState->rightY   = data[4];
    outState->buttons0 = data[5];
    outState->buttons1 = data[6];
    outState->buttons2 = data[7] & OEDS_SIMPLE_REPORT_BUTTON2_MASK;
    outState->l2       = data[8];
    outState->r2       = data[9];

    return YES;
}


/* Routes a report to the decoder for its layout. Split out from the device handler
 * so the dispatch itself is testable. */
static inline BOOL OEDSDecodeInputReport(uint8_t reportID, const uint8_t *data, NSUInteger length, OEDSInputState *outState)
__attribute__((warn_unused_result));

static inline BOOL OEDSDecodeInputReport(uint8_t reportID, const uint8_t *data, NSUInteger length, OEDSInputState *outState)
{
    switch (reportID) {
        case OEDSInputReportIDExtended: return OEDSDecodeExtendedReport(data, length, outState);
        case OEDSInputReportIDSimple:   return OEDSDecodeSimpleReport(data, length, outState);
        default:                        return NO;
    }
}


NS_ASSUME_NONNULL_END

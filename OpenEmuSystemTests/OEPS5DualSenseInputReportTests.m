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

#import <XCTest/XCTest.h>

/* Not part of the framework's public surface, so it is imported by path rather than
 * through the umbrella header. */
#import "../OpenEmuSystem/OEPS5DualSenseInputReport.h"


@interface OEPS5DualSenseInputReportTests : XCTestCase
@end


@implementation OEPS5DualSenseInputReportTests


/* A real extended report, captured from a DualSense (VID 0x054C, PID 0x0CE6) over
 * Bluetooth on macOS 26.6 while the controller sat untouched. The bytes are literal
 * on purpose: deriving them from OEDS_EXTENDED_REPORT_PAYLOAD_OFFSET would make the
 * offset self-consistent with itself and untestable. Only the first 13 bytes are
 * from the capture; the remaining 65 (motion, touchpad, status, CRC32) are zero
 * filled because nothing here reads them.
 *
 *   31    report ID
 *   51    sequence tag
 *   81 80 left stick, 129/128 - resting jitter around neutral (0x80)
 *   7d 80 right stick, 125/128
 *   00 00 L2, R2 released
 *   01    sequence number
 *   08    buttons0: hat nibble 8, D-Pad centred, no face buttons
 *   00 00 buttons1, buttons2
 *   00    buttons3, unread */
static const uint8_t kRestingExtendedReport[OEDS_EXTENDED_REPORT_SIZE] = {
    0x31, 0x51, 0x81, 0x80, 0x7d, 0x80, 0x00, 0x00, 0x01, 0x08, 0x00, 0x00, 0x00,
};

/* The same physical state in the cut-down layout, where the triggers follow the
 * buttons instead of preceding them. */
static const uint8_t kRestingSimpleReport[OEDS_SIMPLE_REPORT_SIZE] = {
    0x01, 0x81, 0x80, 0x7d, 0x80, 0x08, 0x00, 0x00, 0x00, 0x00,
};

#define OEDSAssertRestingState(state) do { \
    XCTAssertEqual((state).leftX,  0x81); \
    XCTAssertEqual((state).leftY,  0x80); \
    XCTAssertEqual((state).rightX, 0x7d); \
    XCTAssertEqual((state).rightY, 0x80); \
    XCTAssertEqual((state).l2,     0x00); \
    XCTAssertEqual((state).r2,     0x00); \
    XCTAssertEqual(OEDSHatSwitchFromButtonState0((state).buttons0), OEDSHatSwitchCentered); \
    XCTAssertEqual((state).buttons1, 0); \
    XCTAssertEqual((state).buttons2, 0); \
} while (0)


#pragma mark - Wire constants, pinned against literals


/* These constants describe hardware, so they are checked against literal values
 * rather than against each other. Every fixture below is built from them, so
 * without this a wrong constant would simply move both sides of its own test. */
- (void)testWireConstantsMatchTheDocumentedProtocol
{
    XCTAssertEqual(OEDSVendorIDSony,            0x054C);
    XCTAssertEqual(OEDSProductIDDualSense,      0x0CE6);
    XCTAssertEqual(OEDSProductIDDualSenseEdge,  0x0DF2);

    XCTAssertEqual(OEDSInputReportIDSimple,     0x01);
    XCTAssertEqual(OEDSInputReportIDExtended,   0x31);
    XCTAssertEqual(OEDSFeatureReportIDCalibration, 0x05);

    XCTAssertEqual(OEDS_EXTENDED_REPORT_SIZE,           78);
    XCTAssertEqual(OEDS_EXTENDED_REPORT_PAYLOAD_OFFSET,  2);
    XCTAssertEqual(OEDS_SIMPLE_REPORT_SIZE,             10);
    XCTAssertEqual(OEDS_STICK_NEUTRAL,                0x80);

    XCTAssertEqual(OEDSButtonState0Square,   0x10);
    XCTAssertEqual(OEDSButtonState0Cross,    0x20);
    XCTAssertEqual(OEDSButtonState0Circle,   0x40);
    XCTAssertEqual(OEDSButtonState0Triangle, 0x80);

    XCTAssertEqual(OEDSButtonState1L1,      0x01);
    XCTAssertEqual(OEDSButtonState1R1,      0x02);
    XCTAssertEqual(OEDSButtonState1L2,      0x04);
    XCTAssertEqual(OEDSButtonState1R2,      0x08);
    XCTAssertEqual(OEDSButtonState1Create,  0x10);
    XCTAssertEqual(OEDSButtonState1Options, 0x20);
    XCTAssertEqual(OEDSButtonState1L3,      0x40);
    XCTAssertEqual(OEDSButtonState1R3,      0x80);

    XCTAssertEqual(OEDSButtonState2PSHome,   0x01);
    XCTAssertEqual(OEDSButtonState2Touchpad, 0x02);
    XCTAssertEqual(OEDSButtonState2MicMute,  0x04);
}


#pragma mark - Payload offsets, pinned against real hardware bytes


- (void)testExtendedReportDecodesCapturedHardwareBytes
{
    OEDSInputState state = OEDSInputStateNeutral();
    XCTAssertTrue(OEDSDecodeExtendedReport(kRestingExtendedReport, sizeof(kRestingExtendedReport), &state));
    OEDSAssertRestingState(state);
}


- (void)testSimpleReportUsesItsOwnFieldOrder
{
    OEDSInputState state = OEDSInputStateNeutral();
    XCTAssertTrue(OEDSDecodeSimpleReport(kRestingSimpleReport, sizeof(kRestingSimpleReport), &state));
    OEDSAssertRestingState(state);
}


/* A binding made in one layout has to mean the same thing in the other. */
- (void)testBothLayoutsDecodeToTheSameState
{
    OEDSInputState extended = OEDSInputStateNeutral(), simple = OEDSInputStateNeutral();
    XCTAssertTrue(OEDSDecodeExtendedReport(kRestingExtendedReport, sizeof(kRestingExtendedReport), &extended));
    XCTAssertTrue(OEDSDecodeSimpleReport(kRestingSimpleReport, sizeof(kRestingSimpleReport), &simple));
    XCTAssertEqual(memcmp(&extended, &simple, sizeof(OEDSInputState)), 0);
}


- (void)testExtendedReportDecodesButtonsAndTriggers
{
    uint8_t report[OEDS_EXTENDED_REPORT_SIZE];
    memcpy(report, kRestingExtendedReport, sizeof(report));
    report[6] = 0x7F;                                              /* L2 half pressed */
    report[9] = OEDSHatSwitchEast | OEDSButtonState0Cross;          /* D-Pad east + Cross */
    report[10] = OEDSButtonState1R1;
    report[11] = OEDSButtonState2PSHome;

    OEDSInputState state = OEDSInputStateNeutral();
    XCTAssertTrue(OEDSDecodeExtendedReport(report, sizeof(report), &state));

    XCTAssertEqual(state.l2, 0x7F);
    XCTAssertEqual(OEDSHatSwitchFromButtonState0(state.buttons0), OEDSHatSwitchEast);
    XCTAssertTrue(state.buttons0 & OEDSButtonState0Cross);
    XCTAssertFalse(state.buttons0 & OEDSButtonState0Square);
    XCTAssertTrue(state.buttons1 & OEDSButtonState1R1);
    XCTAssertFalse(state.buttons1 & OEDSButtonState1L1);
    XCTAssertTrue(state.buttons2 & OEDSButtonState2PSHome);
    XCTAssertFalse(state.buttons2 & OEDSButtonState2Touchpad);
}


/* The resting fixture is zero from byte 6 on, which leaves the trigger and button
 * slots interchangeable. Distinct values pin each one individually. */
- (void)testSimpleReportFieldSlotsAreIndividuallyPinned
{
    const uint8_t report[OEDS_SIMPLE_REPORT_SIZE] = {
        0x01, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99,
    };

    OEDSInputState state = OEDSInputStateNeutral();
    XCTAssertTrue(OEDSDecodeSimpleReport(report, sizeof(report), &state));

    XCTAssertEqual(state.leftX,    0x11);
    XCTAssertEqual(state.leftY,    0x22);
    XCTAssertEqual(state.rightX,   0x33);
    XCTAssertEqual(state.rightY,   0x44);
    XCTAssertEqual(state.buttons0, 0x55);
    XCTAssertEqual(state.buttons1, 0x66);
    XCTAssertEqual(state.buttons2, 0x77 & OEDS_SIMPLE_REPORT_BUTTON2_MASK);
    XCTAssertEqual(state.l2,       0x88);
    XCTAssertEqual(state.r2,       0x99);
}


/* A cut-down report has no mic mute button; bits 2-7 of its third button byte are a
 * free running counter. Reading the counter's low bit as mic mute would emit a
 * phantom press every time it ticks. */
- (void)testSimpleReportDiscardsTheCounterBitsInsteadOfReadingThemAsButtons
{
    uint8_t report[OEDS_SIMPLE_REPORT_SIZE];
    memcpy(report, kRestingSimpleReport, sizeof(report));

    OEDSInputState state = OEDSInputStateNeutral();

    report[7] = 0xFC;   /* counter saturated, neither real button held */
    XCTAssertTrue(OEDSDecodeSimpleReport(report, sizeof(report), &state));
    XCTAssertEqual(state.buttons2, 0);
    XCTAssertFalse(state.buttons2 & OEDSButtonState2MicMute);

    report[7] = 0xFC | OEDSButtonState2PSHome;
    XCTAssertTrue(OEDSDecodeSimpleReport(report, sizeof(report), &state));
    XCTAssertEqual(state.buttons2, OEDSButtonState2PSHome);

    /* the extended report really does carry mic mute, and must keep it */
    uint8_t extended[OEDS_EXTENDED_REPORT_SIZE];
    memcpy(extended, kRestingExtendedReport, sizeof(extended));
    extended[11] = OEDSButtonState2MicMute;
    XCTAssertTrue(OEDSDecodeExtendedReport(extended, sizeof(extended), &state));
    XCTAssertTrue(state.buttons2 & OEDSButtonState2MicMute);
}


#pragma mark - Layout confusion


/* The regression this guards: a full report 0x01 is 64 bytes with the triggers
 * before the buttons. Accepting it in the cut-down decoder would read L2 as the
 * D-Pad and face buttons, and the sequence counter as PS/touchpad/mic mute. */
- (void)testSimpleDecoderRejectsAFullReportLengthPayload
{
    uint8_t usbSizedReport[64] = {OEDSInputReportIDSimple};
    memcpy(usbSizedReport + 1, kRestingExtendedReport + 2, 11);

    OEDSInputState state = OEDSInputStateNeutral();
    XCTAssertFalse(OEDSDecodeSimpleReport(usbSizedReport, sizeof(usbSizedReport), &state));
}


- (void)testTruncatedReportsAreRejected
{
    OEDSInputState state = OEDSInputStateNeutral();

    /* Long enough to read the payload head, but still a truncated 0x31. Accepting
     * these is how a half-delivered report turns into phantom input. */
    XCTAssertFalse(OEDSDecodeExtendedReport(kRestingExtendedReport,
        OEDS_EXTENDED_REPORT_PAYLOAD_OFFSET + sizeof(OEDSInputReportHead), &state));
    XCTAssertFalse(OEDSDecodeExtendedReport(kRestingExtendedReport, 77, &state));
    XCTAssertTrue(OEDSDecodeExtendedReport(kRestingExtendedReport, 78, &state));

    XCTAssertFalse(OEDSDecodeSimpleReport(kRestingSimpleReport, 9, &state));
    XCTAssertFalse(OEDSDecodeSimpleReport(kRestingExtendedReport, 11, &state));
}


#pragma mark - Report routing


- (void)testDecodeInputReportRoutesByReportID
{
    OEDSInputState state = OEDSInputStateNeutral();

    XCTAssertTrue(OEDSDecodeInputReport(kRestingExtendedReport[0],
        kRestingExtendedReport, sizeof(kRestingExtendedReport), &state));
    OEDSAssertRestingState(state);

    state = OEDSInputStateNeutral();
    XCTAssertTrue(OEDSDecodeInputReport(kRestingSimpleReport[0],
        kRestingSimpleReport, sizeof(kRestingSimpleReport), &state));
    OEDSAssertRestingState(state);
}


- (void)testDecodeInputReportRejectsUnknownReportIDs
{
    OEDSInputState state = OEDSInputStateNeutral();
    XCTAssertFalse(OEDSDecodeInputReport(0x00, kRestingExtendedReport, sizeof(kRestingExtendedReport), &state));
    XCTAssertFalse(OEDSDecodeInputReport(0x32, kRestingExtendedReport, sizeof(kRestingExtendedReport), &state));
    XCTAssertFalse(OEDSDecodeInputReport(OEDSInputReportIDExtended, kRestingExtendedReport, 0, &state));
    XCTAssertFalse(OEDSDecodeInputReport(OEDSInputReportIDExtended, kRestingExtendedReport, OEDS_EXTENDED_REPORT_SIZE - 1, &state));
}


#pragma mark - Hat switch


- (void)testHatSwitchNibbleMapsClockwiseFromNorthAndClampsToCentred
{
    const OEDSHatSwitchValue expected[] = {
        OEDSHatSwitchNorth, OEDSHatSwitchNorthEast, OEDSHatSwitchEast, OEDSHatSwitchSouthEast,
        OEDSHatSwitchSouth, OEDSHatSwitchSouthWest, OEDSHatSwitchWest, OEDSHatSwitchNorthWest,
    };
    for (uint8_t nibble = 0; nibble < 8; nibble++)
        XCTAssertEqual(OEDSHatSwitchFromButtonState0(nibble), expected[nibble]);

    for (uint8_t nibble = 8; nibble <= 0x0F; nibble++)
        XCTAssertEqual(OEDSHatSwitchFromButtonState0(nibble), OEDSHatSwitchCentered);

    /* the nibble must stay isolated from the face button bits */
    XCTAssertEqual(OEDSHatSwitchFromButtonState0(OEDSHatSwitchEast | 0xF0), OEDSHatSwitchEast);
}


#pragma mark - Neutral state


/* A zeroed OEDSInputState would read as both sticks pinned to the top-left corner
 * and the D-Pad held north, which is why the neutral constructor exists. */
- (void)testNeutralStateIsActuallyNeutral
{
    OEDSInputState neutral = OEDSInputStateNeutral();

    XCTAssertEqual(neutral.leftX,  0x80);
    XCTAssertEqual(neutral.leftY,  0x80);
    XCTAssertEqual(neutral.rightX, 0x80);
    XCTAssertEqual(neutral.rightY, 0x80);
    XCTAssertEqual(neutral.l2, 0);
    XCTAssertEqual(neutral.r2, 0);
    XCTAssertEqual(OEDSHatSwitchFromButtonState0(neutral.buttons0), OEDSHatSwitchCentered);
    XCTAssertEqual(neutral.buttons1, 0);
    XCTAssertEqual(neutral.buttons2, 0);

    OEDSInputState zeroed = {0};
    XCTAssertNotEqual(memcmp(&neutral, &zeroed, sizeof(OEDSInputState)), 0,
                      @"if these ever match, the neutral constructor has stopped doing anything");
}


#pragma mark - Agreement with the controller database


/* The handler's button numbering has to match the OEControllerSonyPS5DualSense entry
 * the bindings resolve through. Pin the database side here so the two cannot drift
 * apart silently. */
- (void)testControllerDatabaseDeclaresTheExpectedDualSenseControls
{
    Class descriptionClass = NSClassFromString(@"OEControllerDescription");
    XCTAssertNotNil(descriptionClass);

    NSURL *url = [[NSBundle bundleForClass:descriptionClass] URLForResource:@"Controller-Database" withExtension:@"plist"];
    XCTAssertNotNil(url, @"the framework must ship a controller database");

    NSDictionary *database = [NSDictionary dictionaryWithContentsOfURL:url];
    NSDictionary *dualSense = database[@"OEControllerSonyPS5DualSense"];
    XCTAssertNotNil(dualSense, @"the framework's controller database must contain the DualSense");

    NSDictionary *mappings = dualSense[@"OEControllerMappings"];
    NSDictionary<NSString *, NSString *> *expectedButtons = @{
        @"Square": @"1", @"Cross": @"2", @"Circle": @"3", @"Triangle": @"4",
        @"L1": @"5", @"R1": @"6", @"L2Button": @"7", @"R2Button": @"8",
        @"Create": @"9", @"Options": @"10", @"L3": @"11", @"R3": @"12",
        @"Home": @"13", @"Touchpad": @"14", @"MicMute": @"15",
    };
    [expectedButtons enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSString *number, BOOL *stop) {
        NSString *key = [@"OEControllerSonyPS5DualSenseButton" stringByAppendingString:name];
        XCTAssertEqualObjects(mappings[key][@"Type"], @"Button", @"%@", key);
        XCTAssertEqualObjects(mappings[key][@"Usage"], number, @"%@", key);
    }];

    XCTAssertEqualObjects(mappings[@"OEControllerSonyPS5DualSenseLeftAnalogX"][@"Usage"],  @"X");
    XCTAssertEqualObjects(mappings[@"OEControllerSonyPS5DualSenseLeftAnalogY"][@"Usage"],  @"Y");
    XCTAssertEqualObjects(mappings[@"OEControllerSonyPS5DualSenseRightAnalogX"][@"Usage"], @"Z");
    XCTAssertEqualObjects(mappings[@"OEControllerSonyPS5DualSenseRightAnalogY"][@"Usage"], @"Rz");
    XCTAssertEqualObjects(mappings[@"OEControllerSonyPS5DualSenseButtonL2"][@"Usage"],     @"Rx");
    XCTAssertEqualObjects(mappings[@"OEControllerSonyPS5DualSenseButtonR2"][@"Usage"],     @"Ry");
    XCTAssertEqualObjects(mappings[@"OEControllerSonyPS5DualSenseDPad"][@"Type"],          @"HatSwitch");
}


@end

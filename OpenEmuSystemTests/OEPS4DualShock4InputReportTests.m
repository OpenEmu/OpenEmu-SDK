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

/* Not part of the framework's public surface, so it is imported by path. */
#import "../OpenEmuSystem/OEPS4DualShock4InputReport.h"


@interface OEPS4DualShock4InputReportTests : XCTestCase
@end


@implementation OEPS4DualShock4InputReportTests


/* An extended report with every dispatched field set to a distinct value, so that a
 * wrong offset shows up as a specific field holding its neighbour's value. Built
 * from literal bytes on purpose: deriving the positions from
 * OEDS4_EXTENDED_REPORT_PAYLOAD_OFFSET would make the test agree with any offset.
 *
 *   11       report ID
 *   c0       flags: has input (0x80) | has CRC (0x40)
 *   00       reserved
 *   10 20    left stick X, Y
 *   30 40    right stick X, Y
 *   a3       buttons0: triangle (0x80) | cross (0x20) | hat 3 (south-east)
 *   51       buttons1: L3 (0x40) | share (0x10) | L1 (0x01)
 *   fd       buttons2: counter bits set (0xFC) | PS (0x01), touchpad released
 *   50 60    L2, R2 */
static void OEDS4FillExtendedReport(uint8_t report[OEDS4_EXTENDED_REPORT_SIZE])
{
    memset(report, 0, OEDS4_EXTENDED_REPORT_SIZE);
    const uint8_t head[] = { 0x11, 0xC0, 0x00, 0x10, 0x20, 0x30, 0x40, 0xA3, 0x51, 0xFD, 0x50, 0x60 };
    memcpy(report, head, sizeof(head));
}

/* The same state as a short report 0x01. */
static const uint8_t kSimpleReport[OEDS4_SIMPLE_REPORT_MIN_SIZE] = {
    0x01, 0x10, 0x20, 0x30, 0x40, 0xA3, 0x51, 0xFD, 0x50, 0x60,
};

#define OEDS4AssertFilledState(state) do { \
    XCTAssertEqual((state).leftX,  0x10); \
    XCTAssertEqual((state).leftY,  0x20); \
    XCTAssertEqual((state).rightX, 0x30); \
    XCTAssertEqual((state).rightY, 0x40); \
    XCTAssertEqual((state).l2,     0x50); \
    XCTAssertEqual((state).r2,     0x60); \
    XCTAssertEqual(OEDS4HatSwitchFromButtonState0((state).buttons0), OEDS4HatSwitchSouthEast); \
    XCTAssertEqual((state).buttons0 & 0xF0, OEDS4ButtonState0Triangle | OEDS4ButtonState0Cross); \
    XCTAssertEqual((state).buttons1, OEDS4ButtonState1L3 | OEDS4ButtonState1Share | OEDS4ButtonState1L1); \
    XCTAssertEqual((state).buttons2, OEDS4ButtonState2PSHome); \
} while (0)


#pragma mark - Wire constants


- (void)testWireConstantsMatchTheDocumentedProtocol
{
    XCTAssertEqual(OEDS4VendorIDSony,          0x054C);
    XCTAssertEqual(OEDS4ProductIDDualShock4,   0x05C4);
    XCTAssertEqual(OEDS4ProductIDDualShock4V2, 0x09CC);

    XCTAssertEqual(OEDS4InputReportIDSimple,          0x01);
    XCTAssertEqual(OEDS4InputReportIDExtended,        0x11);
    XCTAssertEqual(OEDS4FeatureReportIDCalibrationBT, 0x05);

    XCTAssertEqual(OEDS4_EXTENDED_REPORT_SIZE,            78);
    XCTAssertEqual(OEDS4_EXTENDED_REPORT_PAYLOAD_OFFSET,   3);
    XCTAssertEqual(OEDS4_SIMPLE_REPORT_MIN_SIZE,          10);
    XCTAssertEqual(OEDS4_CALIBRATION_BT_FEATURE_REPORT_SIZE, 41);

    XCTAssertEqual(OEDS4ButtonState2PSHome,   0x01);
    XCTAssertEqual(OEDS4ButtonState2Touchpad, 0x02);
}


#pragma mark - Decoding


- (void)testExtendedReportDecodesEveryFieldFromItsOwnSlot
{
    uint8_t report[OEDS4_EXTENDED_REPORT_SIZE];
    OEDS4FillExtendedReport(report);

    OEDS4InputState state = OEDS4InputStateNeutral();
    XCTAssertEqual(OEDS4DecodeExtendedReport(report, sizeof(report), &state), OEDS4DecodeResultDecoded);
    OEDS4AssertFilledState(state);
}


- (void)testSimpleReportDecodesEveryFieldFromItsOwnSlot
{
    OEDS4InputState state = OEDS4InputStateNeutral();
    XCTAssertEqual(OEDS4DecodeSimpleReport(kSimpleReport, sizeof(kSimpleReport), &state), OEDS4DecodeResultDecoded);
    OEDS4AssertFilledState(state);
}


/* A binding made while one layout is active has to mean the same in the other. */
- (void)testBothLayoutsDecodeToTheSameState
{
    uint8_t report[OEDS4_EXTENDED_REPORT_SIZE];
    OEDS4FillExtendedReport(report);

    OEDS4InputState extended = OEDS4InputStateNeutral(), simple = OEDS4InputStateNeutral();
    XCTAssertEqual(OEDS4DecodeExtendedReport(report, sizeof(report), &extended), OEDS4DecodeResultDecoded);
    XCTAssertEqual(OEDS4DecodeSimpleReport(kSimpleReport, sizeof(kSimpleReport), &simple), OEDS4DecodeResultDecoded);
    XCTAssertEqual(memcmp(&extended, &simple, sizeof(OEDS4InputState)), 0);
}


/* Over USB report 0x01 is 64 bytes long, with the same leading layout. */
- (void)testSimpleDecoderAcceptsTheLongerUSBLayout
{
    uint8_t report[64] = {0};
    memcpy(report, kSimpleReport, sizeof(kSimpleReport));

    OEDS4InputState state = OEDS4InputStateNeutral();
    XCTAssertEqual(OEDS4DecodeSimpleReport(report, sizeof(report), &state), OEDS4DecodeResultDecoded);
    OEDS4AssertFilledState(state);
}


- (void)testCounterBitsAreNeverReadAsButtons
{
    uint8_t report[OEDS4_EXTENDED_REPORT_SIZE];
    OEDS4FillExtendedReport(report);

    for (unsigned counter = 0; counter < 64; counter++) {
        report[OEDS4_EXTENDED_REPORT_PAYLOAD_OFFSET + 6] = (uint8_t)(counter << 2);
        OEDS4InputState state = OEDS4InputStateNeutral();
        XCTAssertEqual(OEDS4DecodeExtendedReport(report, sizeof(report), &state), OEDS4DecodeResultDecoded);
        XCTAssertEqual(state.buttons2, 0, @"counter value %u leaked into the buttons", counter);
    }
}


- (void)testExtendedReportWithoutInputFlagIsSkipped
{
    uint8_t report[OEDS4_EXTENDED_REPORT_SIZE];
    OEDS4FillExtendedReport(report);
    report[1] = 0x40;

    OEDS4InputState state = OEDS4InputStateNeutral();
    XCTAssertEqual(OEDS4DecodeExtendedReport(report, sizeof(report), &state), OEDS4DecodeResultNoInput);
    XCTAssertEqual(state.leftX, OEDS4_STICK_NEUTRAL, @"a skipped report must leave the state untouched");
}


- (void)testTruncatedReportsAreRejected
{
    uint8_t report[OEDS4_EXTENDED_REPORT_SIZE];
    OEDS4FillExtendedReport(report);

    OEDS4InputState state = OEDS4InputStateNeutral();
    XCTAssertEqual(OEDS4DecodeExtendedReport(report, OEDS4_EXTENDED_REPORT_SIZE - 1, &state), OEDS4DecodeResultUndecodable);
    XCTAssertEqual(OEDS4DecodeSimpleReport(kSimpleReport, OEDS4_SIMPLE_REPORT_MIN_SIZE - 1, &state), OEDS4DecodeResultUndecodable);
}


- (void)testDecodeInputReportRoutesByReportID
{
    uint8_t report[OEDS4_EXTENDED_REPORT_SIZE];
    OEDS4FillExtendedReport(report);

    OEDS4InputState state = OEDS4InputStateNeutral();
    XCTAssertEqual(OEDS4DecodeInputReport(0x11, report, sizeof(report), &state), OEDS4DecodeResultDecoded);
    OEDS4AssertFilledState(state);

    state = OEDS4InputStateNeutral();
    XCTAssertEqual(OEDS4DecodeInputReport(0x01, kSimpleReport, sizeof(kSimpleReport), &state), OEDS4DecodeResultDecoded);
    OEDS4AssertFilledState(state);

    XCTAssertEqual(OEDS4DecodeInputReport(0x12, report, sizeof(report), &state), OEDS4DecodeResultUndecodable);
}


- (void)testHatSwitchNibbleMapsClockwiseFromNorthAndClampsToCentred
{
    XCTAssertEqual(OEDS4HatSwitchFromButtonState0(0x00), OEDS4HatSwitchNorth);
    XCTAssertEqual(OEDS4HatSwitchFromButtonState0(0x02), OEDS4HatSwitchEast);
    XCTAssertEqual(OEDS4HatSwitchFromButtonState0(0x04), OEDS4HatSwitchSouth);
    XCTAssertEqual(OEDS4HatSwitchFromButtonState0(0x06), OEDS4HatSwitchWest);
    XCTAssertEqual(OEDS4HatSwitchFromButtonState0(0x08), OEDS4HatSwitchCentered);
    XCTAssertEqual(OEDS4HatSwitchFromButtonState0(0x0F), OEDS4HatSwitchCentered);
    /* face buttons in the high nibble must not move the hat */
    XCTAssertEqual(OEDS4HatSwitchFromButtonState0(0xF4), OEDS4HatSwitchSouth);
}


- (void)testNeutralStateIsActuallyNeutral
{
    OEDS4InputState state = OEDS4InputStateNeutral();
    XCTAssertEqual(state.leftX,  0x80);
    XCTAssertEqual(state.leftY,  0x80);
    XCTAssertEqual(state.rightX, 0x80);
    XCTAssertEqual(state.rightY, 0x80);
    XCTAssertEqual(OEDS4HatSwitchFromButtonState0(state.buttons0), OEDS4HatSwitchCentered);
}


#pragma mark - Agreement with the controller database


/* Collects {button number: mask} from one of the button maps. */
static void OEDS4CollectMap(const uint8_t *map, NSMutableSet<NSNumber *> *numbers)
{
    for (int i = 0; map[i] != 0; i += 2)
        [numbers addObject:@(map[i + 1])];
}


/* The handler's button numbers must be exactly the ones the existing
 * OEControllerSonyPS4Dualshock4 entry declares, checked from both sides. */
- (void)testButtonMapsMatchTheControllerDatabase
{
    Class descriptionClass = NSClassFromString(@"OEControllerDescription");
    XCTAssertNotNil(descriptionClass);

    NSURL *url = [[NSBundle bundleForClass:descriptionClass] URLForResource:@"Controller-Database" withExtension:@"plist"];
    XCTAssertNotNil(url, @"the framework must ship a controller database");

    NSDictionary *database = [NSDictionary dictionaryWithContentsOfURL:url];
    NSDictionary *entry = database[@"OEControllerSonyPS4Dualshock4"];
    XCTAssertNotNil(entry);

    NSArray *devices = entry[@"OEControllerDevices"];
    NSMutableSet *productIDs = [NSMutableSet set];
    for (NSDictionary *device in devices) {
        XCTAssertEqualObjects(device[@"OEControllerVendorID"], @(OEDS4VendorIDSony));
        [productIDs addObject:device[@"OEControllerProductID"]];
    }
    XCTAssertTrue([productIDs containsObject:@(OEDS4ProductIDDualShock4)]);
    XCTAssertTrue([productIDs containsObject:@(OEDS4ProductIDDualShock4V2)]);

    NSDictionary<NSString *, NSDictionary *> *mappings = entry[@"OEControllerMappings"];
    NSMutableSet<NSNumber *> *databaseButtons = [NSMutableSet set];
    NSMutableDictionary<NSString *, NSString *> *axes = [NSMutableDictionary dictionary];
    [mappings enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *control, BOOL *stop) {
        NSString *usage = [control[@"Usage"] description];
        if ([control[@"Type"] isEqualToString:@"Button"])
            [databaseButtons addObject:@([usage integerValue])];
        else
            axes[key] = usage;
    }];

    NSMutableSet<NSNumber *> *handlerButtons = [NSMutableSet set];
    OEDS4CollectMap(OEDS4ButtonState0Map(), handlerButtons);
    OEDS4CollectMap(OEDS4ButtonState1Map(), handlerButtons);
    OEDS4CollectMap(OEDS4ButtonState2Map(), handlerButtons);
    XCTAssertEqualObjects(handlerButtons, databaseButtons);

    XCTAssertEqualObjects([mappings[@"OEControllerSonyPS4Dualshock4ButtonSquare"][@"Usage"] description], @"1");
    XCTAssertEqualObjects([mappings[@"OEControllerSonyPS4Dualshock4ButtonHome"][@"Usage"] description], @"13");

    XCTAssertEqualObjects(axes[@"OEControllerSonyPS4Dualshock4LeftAnalogX"],  @"X");
    XCTAssertEqualObjects(axes[@"OEControllerSonyPS4Dualshock4LeftAnalogY"],  @"Y");
    XCTAssertEqualObjects(axes[@"OEControllerSonyPS4Dualshock4RightAnalogX"], @"Z");
    XCTAssertEqualObjects(axes[@"OEControllerSonyPS4Dualshock4RightAnalogY"], @"Rz");
    XCTAssertEqualObjects(axes[@"OEControllerSonyPS4Dualshock4ButtonL2"],     @"Rx");
    XCTAssertEqualObjects(axes[@"OEControllerSonyPS4Dualshock4ButtonR2"],     @"Ry");
    XCTAssertEqualObjects(mappings[@"OEControllerSonyPS4Dualshock4DPad"][@"Type"], @"HatSwitch");
}


@end

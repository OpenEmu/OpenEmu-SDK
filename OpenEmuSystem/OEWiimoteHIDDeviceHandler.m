/*
 Copyright (c) 2012, OpenEmu Team

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

#import "OEWiimoteHIDDeviceHandler.h"
#import <IOBluetooth/IOBluetooth.h>
#import "OEHIDEvent.h"
#import "OEControllerDescription_Internal.h"

NS_ASSUME_NONNULL_BEGIN

NSNotificationName const OEWiimoteDeviceHandlerDidDisconnectNotification = @"OEWiimoteDeviceHandlerDidDisconnectNotification";

@interface OEHIDEvent ()
- (OEHIDEvent *)OE_eventWithWiimoteDeviceHandler:(OEWiimoteHIDDeviceHandler *)aDeviceHandler;
@end

enum {
    OEWiimoteCommandWrite = 0x16,
    OEWiimoteCommandRead  = 0x17,
};

typedef enum : NSUInteger {
    OEWiimoteButtonIdentifierUnknown      = 0x0000,
    OEWiimoteButtonIdentifierTwo          = 0x0001,
    OEWiimoteButtonIdentifierOne          = 0x0002,
    OEWiimoteButtonIdentifierB            = 0x0004,
    OEWiimoteButtonIdentifierA            = 0x0008,
    OEWiimoteButtonIdentifierMinus        = 0x0010,
    OEWiimoteButtonIdentifierHome         = 0x0080,
    OEWiimoteButtonIdentifierLeft         = 0x0100,
    OEWiimoteButtonIdentifierRight        = 0x0200,
    OEWiimoteButtonIdentifierDown         = 0x0400,
    OEWiimoteButtonIdentifierUp           = 0x0800,
    OEWiimoteButtonIdentifierPlus         = 0x1000,

    OEWiimoteButtonIdentifierNunchuckZ    = 0x0001,
    OEWiimoteButtonIdentifierNunchuckC    = 0x0002,

    OEWiimoteButtonIdentifierClassicUp    = 0x0001,
    OEWiimoteButtonIdentifierClassicLeft  = 0x0002,
    OEWiimoteButtonIdentifierClassicZR    = 0x0004,
    OEWiimoteButtonIdentifierClassicX     = 0x0008,
    OEWiimoteButtonIdentifierClassicA     = 0x0010,
    OEWiimoteButtonIdentifierClassicY     = 0x0020,
    OEWiimoteButtonIdentifierClassicB     = 0x0040,
    OEWiimoteButtonIdentifierClassicZL    = 0x0080,
    // 0x0100 is unsued
    OEWiimoteButtonIdentifierClassicR     = 0x0200,
    OEWiimoteButtonIdentifierClassicPlus  = 0x0400,
    OEWiimoteButtonIdentifierClassicHome  = 0x0800,
    OEWiimoteButtonIdentifierClassicMinus = 0x1000,
    OEWiimoteButtonIdentifierClassicL     = 0x2000,
    OEWiimoteButtonIdentifierClassicDown  = 0x4000,
    OEWiimoteButtonIdentifierClassicRight = 0x8000,

    OEWiimoteButtonIdentifierProR3        = 0x00000001,
    OEWiimoteButtonIdentifierProL3        = 0x00000002,
    OEWiimoteButtonIdentifierProUp        = 0x00000100,
    OEWiimoteButtonIdentifierProLeft      = 0x00000200,
    OEWiimoteButtonIdentifierProZR        = 0x00000400,
    OEWiimoteButtonIdentifierProX         = 0x00000800,
    OEWiimoteButtonIdentifierProA         = 0x00001000,
    OEWiimoteButtonIdentifierProY         = 0x00002000,
    OEWiimoteButtonIdentifierProB         = 0x00004000,
    OEWiimoteButtonIdentifierProZL        = 0x00008000,
    OEWiimoteButtonIdentifierProR         = 0x00020000,
    OEWiimoteButtonIdentifierProPlus      = 0x00040000,
    OEWiimoteButtonIdentifierProHome      = 0x00080000,
    OEWiimoteButtonIdentifierProMinus     = 0x00100000,
    OEWiimoteButtonIdentifierProL         = 0x00200000,
    OEWiimoteButtonIdentifierProDown      = 0x00400000,
    OEWiimoteButtonIdentifierProRight     = 0x00800000,
} OEWiimoteButtonIdentifier;

typedef enum {
    OEWiimoteNunchuckDeadZone               = 10,
    OEWiimoteNunchuckAxisMaximumValue       = 255,
    OEWiimoteNunchuckAxisScaledMinimumValue = -128,
    OEWiimoteNunchuckAxisScaledMaximumValue =  127,

    // Cookies from 0x00 to 0xFF are reserved for buttons
    OEWiimoteNunchuckAxisXCookie = 0x100,
    OEWiimoteNunchuckAxisYCookie = 0x200,
} OEWiimoteNunchuckParameters;

static const OEHIDEventAxis OEWiimoteNunchuckAxisXUsage = OEHIDEventAxisX;
static const OEHIDEventAxis OEWiimoteNunchuckAxisYUsage = OEHIDEventAxisY;

typedef enum {
    OEWiimoteClassicControllerLeftJoystickMaximumValue  = 63,
    OEWiimoteClassicControllerRightJoystickMaximumValue = 31,
    OEWiimoteClassicControllerTriggerMaximumValue       = 31,

    OEWiimoteClassicControllerLeftJoystickScaledMinimumValue = -32,
    OEWiimoteClassicControllerLeftJoystickScaledMaximumValue = 31,

    OEWiimoteClassicControllerRightJoystickScaledMinimumValue = -16,
    OEWiimoteClassicControllerRightJoystickScaledMaximumValue =  15,

    OEWiimoteClassicControllerDeadZone                  = 4,

    OEWiimoteClassicControllerLeftJoystickAxisXCookie   = 0x300,
    OEWiimoteClassicControllerLeftJoystickAxisYCookie   = 0x400,

    OEWiimoteClassicControllerRightJoystickAxisXCookie  = 0x500,
    OEWiimoteClassicControllerRightJoystickAxisYCookie  = 0x600,

    OEWiimoteClassicControllerLeftTriggerAxisCookie     = 0x700,
    OEWiimoteClassicControllerRightTriggerAxisCookie    = 0x800,
} OEWiimoteClassicControllerParameters;

static const OEHIDEventAxis OEWiimoteClassicControllerLeftJoystickAxisXUsage  = OEHIDEventAxisX;
static const OEHIDEventAxis OEWiimoteClassicControllerLeftJoystickAxisYUsage  = OEHIDEventAxisY;

static const OEHIDEventAxis OEWiimoteClassicControllerRightJoystickAxisXUsage = OEHIDEventAxisRx;
static const OEHIDEventAxis OEWiimoteClassicControllerRightJoystickAxisYUsage = OEHIDEventAxisRy;

static const OEHIDEventAxis OEWiimoteClassicControllerLeftTriggerAxisUsage    = OEHIDEventAxisZ;
static const OEHIDEventAxis OEWiimoteClassicControllerRightTriggerAxisUsage   = OEHIDEventAxisRz;

typedef enum {
    OEWiimoteProControllerJoystickMinimumValue = 1155,
    OEWiimoteProControllerJoystickMaximumValue = 2955,
    OEWiimoteProControllerDeadZone = 200,  /* the dead zone is removed from the scaled range! */
    OEWiimoteProControllerJoystickScaledMinimumValue = -700,
    OEWiimoteProControllerJoystickScaledMaximumValue = 700,

    OEWiimoteProControllerLeftJoystickAxisXCookie   = 0x1000,
    OEWiimoteProControllerLeftJoystickAxisYCookie   = 0x2000,

    OEWiimoteProControllerRightJoystickAxisXCookie  = 0x4000,
    OEWiimoteProControllerRightJoystickAxisYCookie  = 0x8000,
} OEWiimoteProControllerParameters;

static const OEHIDEventAxis OEWiimoteProControllerLeftJoystickAxisXUsage  = OEHIDEventAxisX;
static const OEHIDEventAxis OEWiimoteProControllerLeftJoystickAxisYUsage  = OEHIDEventAxisY;

static const OEHIDEventAxis OEWiimoteProControllerRightJoystickAxisXUsage = OEHIDEventAxisRx;
static const OEHIDEventAxis OEWiimoteProControllerRightJoystickAxisYUsage = OEHIDEventAxisRy;

typedef enum {
    OEWiimoteExpansionIdentifierNunchuck          = 0x0000,
    OEWiimoteExpansionIdentifierClassicController = 0x0101,
    OEWiimoteExpansionIdentifierProController     = 0x0120,
    OEWiimoteExpansionIdentifierFightingStick     = 0x0257,
} OEWiimoteExpansionIdentifier;

typedef enum {
    OEExpansionInitializationStepNone,
    OEExpansionInitializationStepWriteOne,
    OEExpansionInitializationStepWriteTwo,
    OEExpansionInitializationStepRead,
} OEExpansionInitializationStep;

// IMPORTANT: The index in the table represents both the usage and the cookie of the buttons
static NSUInteger _OEWiimoteIdentifierToHIDUsage[] = {
    [1]  = OEWiimoteButtonIdentifierUp,
    [2]  = OEWiimoteButtonIdentifierDown,
    [3]  = OEWiimoteButtonIdentifierLeft,
    [4]  = OEWiimoteButtonIdentifierRight,
    [5]  = OEWiimoteButtonIdentifierA,
    [6]  = OEWiimoteButtonIdentifierB,
    [7]  = OEWiimoteButtonIdentifierOne,
    [8]  = OEWiimoteButtonIdentifierTwo,
    [9]  = OEWiimoteButtonIdentifierMinus,
    [10] = OEWiimoteButtonIdentifierHome,
    [11] = OEWiimoteButtonIdentifierPlus,

    [12] = OEWiimoteButtonIdentifierNunchuckC,
    [13] = OEWiimoteButtonIdentifierNunchuckZ,

    [14] = OEWiimoteButtonIdentifierClassicUp,
    [15] = OEWiimoteButtonIdentifierClassicDown,
    [16] = OEWiimoteButtonIdentifierClassicLeft,
    [17] = OEWiimoteButtonIdentifierClassicRight,
    [18] = OEWiimoteButtonIdentifierClassicA,
    [19] = OEWiimoteButtonIdentifierClassicB,
    [20] = OEWiimoteButtonIdentifierClassicX,
    [21] = OEWiimoteButtonIdentifierClassicY,
    [22] = OEWiimoteButtonIdentifierClassicL,
    [23] = OEWiimoteButtonIdentifierClassicR,
    [24] = OEWiimoteButtonIdentifierClassicZL,
    [25] = OEWiimoteButtonIdentifierClassicZR,
    [26] = OEWiimoteButtonIdentifierClassicPlus,
    [27] = OEWiimoteButtonIdentifierClassicHome,
    [28] = OEWiimoteButtonIdentifierClassicMinus,

    [29] = OEWiimoteButtonIdentifierProUp,
    [30] = OEWiimoteButtonIdentifierProLeft,
    [31] = OEWiimoteButtonIdentifierProRight,
    [32] = OEWiimoteButtonIdentifierProDown,
    [33] = OEWiimoteButtonIdentifierProA,
    [34] = OEWiimoteButtonIdentifierProB,
    [35] = OEWiimoteButtonIdentifierProY,
    [36] = OEWiimoteButtonIdentifierProX,
    [37] = OEWiimoteButtonIdentifierProPlus,
    [38] = OEWiimoteButtonIdentifierProMinus,
    [39] = OEWiimoteButtonIdentifierProHome,
    [40] = OEWiimoteButtonIdentifierProR,
    [41] = OEWiimoteButtonIdentifierProL,
    [42] = OEWiimoteButtonIdentifierProZR,
    [43] = OEWiimoteButtonIdentifierProZL,
    [44] = OEWiimoteButtonIdentifierProR3,
    [45] = OEWiimoteButtonIdentifierProL3,
};

static const NSUInteger _OEWiimoteButtonCount = (sizeof(_OEWiimoteIdentifierToHIDUsage)/(sizeof(_OEWiimoteIdentifierToHIDUsage[0]))) - 1;

static const NSRange _OEWiimoteButtonRange  = {  1, 11 };
static const NSRange _OENunchuckButtonRange = { 12,  2 };
static const NSRange _OEClassicButtonRange  = { 14, 15 };
static const NSRange _OEProButtonRange      = { 29, 17 };
static const NSRange _OEAllButtonRange      = {  1, _OEWiimoteButtonCount };

static void _OEWiimoteIdentifierEnumerateUsingBlock(NSRange range, void(^block)(OEWiimoteButtonIdentifier identifier, NSUInteger usage, BOOL *stop))
{
    range = NSIntersectionRange(range, _OEAllButtonRange);

    BOOL stop = NO;
    for(NSUInteger i = range.location, max = NSMaxRange(range); i < max; i++)
    {
        block(_OEWiimoteIdentifierToHIDUsage[i], i, &stop);
        if(stop) return;
    }
}

@interface OEWiimoteHIDDeviceHandler ()
- (void)readReportData:(void*)dataPointer length:(size_t)dataLength;
@end

static void OE_wiimoteIOHIDReportCallback(void            *context,
                                          IOReturn         result,
                                          void            *sender,
                                          IOHIDReportType  type,
                                          uint32_t         reportID,
                                          uint8_t         *report,
                                          CFIndex          reportLength)
{
    [(__bridge OEWiimoteHIDDeviceHandler *)context readReportData:report length:reportLength];
}

@interface OEWiimoteHIDDeviceParser : NSObject <OEHIDDeviceParser>
@end

@implementation OEWiimoteHIDDeviceHandler {
    uint8_t _reportBuffer[128];
    OEWiimoteExpansionType _expansionType;
    OEExpansionInitializationStep _expansionInitilization;
    struct {
        uint16_t wiimote;
        uint8_t  nunchuck;
        uint8_t  nunchuckVirtualJoystick;
        uint16_t classicController;
        uint32_t proController;
    } _latestButtonReports;

    BOOL _statusReportRequested;
    BOOL _isConnected;

    // Value from 0-4.
    uint8_t _batteryLevel;
    BOOL _charging;
    BOOL _pluggedIn;

    // Allows short delay before events are issued; fixes Issue #544.
    BOOL _analogSettled;
}

+ (id<OEHIDDeviceParser>)deviceParser;
{
    static OEWiimoteHIDDeviceParser *parser = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        parser = [[OEWiimoteHIDDeviceParser alloc] init];
    });

    return parser;
}

+ (BOOL)canHandleDevice:(IOHIDDeviceRef)device
{
    NSString *deviceName = (__bridge id)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
    return [self canHandleDeviceWithName:deviceName];
}

+ (BOOL)canHandleDeviceWithName:(NSString *)name
{
    return [name hasPrefix:@"Nintendo RVL-CNT-01"];
}

- (instancetype)initWithIOHIDDevice:(IOHIDDeviceRef)aDevice deviceDescription:(nullable OEDeviceDescription *)deviceDescription
{
    if((self = [super initWithIOHIDDevice:aDevice deviceDescription:deviceDescription]))
    {
        _expansionPortEnabled = YES;
        _expansionPortAttached = NO;
        _expansionType = OEWiimoteExpansionTypeNotConnected;

        _analogSettled = NO;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            self->_analogSettled = YES;
        });
    }

    return self;
}

- (BOOL)connect
{
    [self setRumbleActivated:YES];
    [self setExpansionPortEnabled:YES];

    _isConnected = YES;

    IOHIDDeviceRegisterInputReportCallback([self device], _reportBuffer, 128, OE_wiimoteIOHIDReportCallback, (__bridge void *)self);
    [self OE_requestStatus];
    [self OE_configureReportType];
    [self OE_synchronizeRumbleAndLEDStatus];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.35 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self setRumbleActivated:NO];
    });

    return YES;
}

- (void)disconnect
{
    if ([[[NSBundle mainBundle] bundleIdentifier] isEqual:@"org.openemu.OpenEmu"]) {
        [self OE_disableReports];
        NSString *btAddress = (__bridge id)IOHIDDeviceGetProperty([self device], CFSTR(kIOHIDSerialNumberKey));
        IOBluetoothDevice *btDevice = [IOBluetoothDevice deviceWithAddressString:btAddress];
        [btDevice closeConnection];
    }
    [super disconnect];
}

#pragma mark - Channel connection methods
#pragma mark - Accessor methods

enum {
    OEWiimoteRumbleMask = 0x1,
    OEWiimoteRumbleAndLEDMask = OEWiimoteDeviceHandlerLEDAll | OEWiimoteRumbleMask,
};

- (void)setRumbleActivated:(BOOL)value
{
    value = !!value;
    if(_rumbleActivated != value)
    {
        _rumbleActivated = value;
        [self OE_synchronizeRumbleAndLEDStatus];
    }
}

#pragma mark - Data reading and writing

- (void)OE_writeData:(const uint8_t *)data length:(NSUInteger)length atAddress:(uint32_t)address;
{
    NSAssert(length <= 16, @"The data length written to the wiimote cannot be larger than 16 bytes.");

    uint8_t command[22] = {
        OEWiimoteCommandWrite,
        // Destination address
        ((address >> 24) & 0xFF) | _rumbleActivated,
        (address >> 16) & 0xFF,
        (address >>  8) & 0xFF,
        (address >>  0) & 0xFF,
        // Data length
        length
    };

    memcpy(command + 6, data, length);

    [self OE_sendCommandWithData:command length:22];
}

- (void)OE_readDataOfLength:(NSUInteger)length atAddress:(uint32_t)address;
{
    const uint8_t command[7] = {
        // Ask for a memory read
        OEWiimoteCommandRead,
        ((address >> 24) & 0xFF) | _rumbleActivated,
        (address >> 16) & 0xFF,
        (address >>  8) & 0xFF,
        (address >>  0) & 0xFF,
        (length  >>  8) & 0xFF,
        (length  >>  0) & 0xFF,
    };

    [self OE_sendCommandWithData:command length:7];
}

- (void)OE_sendCommandWithData:(const uint8_t *)data length:(NSUInteger)length
{
    if(!_isConnected) return;

    NSAssert(data[0] != OEWiimoteCommandWrite || length == 22, @"Writing command should have a length of 22, got %ld", length);

    uint8_t buffer[40] = { 0 };

    memcpy(buffer, data, length);

    IOReturn ret = kIOReturnSuccess;
    for(NSUInteger i = 0; i < 10; i++)
    {
        ret = IOHIDDeviceSetReport([self device], kIOHIDReportTypeOutput, 0, buffer, length);

        if(ret != kIOReturnSuccess)
        {
             NSLog(@"Could not send command, error: %x", ret);
             usleep(10000);
        }
        else break;
    }

    if(ret != kIOReturnSuccess)
    {
        // Something terrible has happened DO SOMETHING
        NSLog(@"Could not send command, error: %x", ret);
    }
}

- (void)OE_handleStatusReportData:(const uint8_t *)response length:(NSUInteger)length;
{
    if(!_statusReportRequested) [self OE_configureReportType];
    else _statusReportRequested = NO;

    // battery level is last three bits in upper nibble, values from 0b0000 to 0b0100
    _batteryLevel = (response[7] & 0x70) >> 4;

    if(_expansionType == OEWiimoteExpansionTypeWiiUProController)
    {
        _charging = (response[7] & 0x4) == 0;
        _pluggedIn = (response[7] & 0x8) == 0;
    }

    if(response[4] & 0x2 && !_expansionPortAttached)
    {
        _expansionType = OEWiimoteExpansionTypeUnknown;
        _expansionInitilization = OEExpansionInitializationStepWriteOne;
        [self OE_readExpansionPortType];
    }
    else if(((response[4] & 0x2) == 0) && _expansionPortAttached)
        _expansionPortAttached = NO;

    [self OE_checkBatteryLevel];
}

- (void)OE_handleDataReportData:(const uint8_t *)response length:(NSUInteger)length;
{
    if(response[1] != 0x3D && _expansionType != OEWiimoteExpansionTypeWiiUProController)
        [self OE_parseWiimoteButtonData:(response[2] << 8 | response[3])];

    if(!_expansionPortEnabled || !_expansionPortAttached) return;

    switch(response[1])
    {
        // Right now, we should only get type 0x34; set in OE_configureReportType
        case 0x32 :
        case 0x34 : [self OE_handleExpansionReportData:response +  4 length:length -  4]; break;
        case 0x35 : [self OE_handleExpansionReportData:response +  7 length:length -  7]; break;
        case 0x36 : [self OE_handleExpansionReportData:response + 14 length:length - 14]; break;
        case 0x37 : [self OE_handleExpansionReportData:response + 17 length:length - 17]; break;
        case 0x3D : [self OE_handleExpansionReportData:response +  2 length:length -  2]; break;
        case 0x22 : NSLog(@"Ack %#x, Error: %#x", response[4], response[5]);              break;
    }
}

- (void)OE_handleExpansionReportData:(const uint8_t *)data length:(NSUInteger)length;
{
    if(length < 6) return;

    switch(_expansionType)
    {
        case OEWiimoteExpansionTypeNunchuck :
            [self OE_parseNunchuckButtonData:data[5]];
            [self OE_parseNunchuckJoystickXData:data[0] yData:data[1]];
            break;
        case OEWiimoteExpansionTypeClassicController :
            [self OE_parseClassicControllerButtonData:(data[4] << 8 | data[5])];
            [self OE_parseClassicControllerJoystickAndTriggerData:data];
            break;
        case OEWiimoteExpansionTypeWiiUProController :
            [self OE_parseProControllerButtonData:(data[8] << 16) | (data[9] << 8) | data[10]];
            [self OE_parseProControllerJoystickData:data];
            break;
        case OEWiimoteExpansionTypeFightingStick :
            [self OE_parseNunchuckButtonData:data[5]];
            [self OE_parseNunchuckJoystickXData:data[0] yData:data[1]];
            break;
        default:
            break;
    }

    if(length > 10)
    {
        _batteryLevel = (data[10] & 0x70) >> 4;
        if(_expansionType == OEWiimoteExpansionTypeWiiUProController)
        {
            _charging = (data[10] & 0x4) == 0;
            _pluggedIn = (data[10] & 0x8) == 0;
        }
    }

    [self OE_checkBatteryLevel];
}

- (void)OE_handleWriteResponseData:(const uint8_t *)response length:(NSUInteger)length;
{
    if(length <= 5) return;

    //If we wrote to a register, assume its from expansion init
    if(response[4] == 0x16)
    {
        _expansionInitilization += 1;
        [self OE_readExpansionPortType];
    }
}

- (void)OE_handleReadResponseData:(const uint8_t *)response length:(NSUInteger)length;
{
    uint16_t address = (response[5] << 8) | response[6];

    // Response to expansion type request
    if(address == 0x00F0)
    {
        _expansionInitilization = OEExpansionInitializationStepNone;
        OEWiimoteExpansionType expansion = OEWiimoteExpansionTypeNotConnected;

        uint16_t expansionType = (response[21] << 8) | response[22];
        switch(expansionType)
        {
            case OEWiimoteExpansionIdentifierNunchuck:
                expansion = OEWiimoteExpansionTypeNunchuck;
                break;
            case OEWiimoteExpansionIdentifierClassicController:
                expansion = OEWiimoteExpansionTypeClassicController;
                break;
            case OEWiimoteExpansionIdentifierProController:
                expansion = OEWiimoteExpansionTypeWiiUProController;
                break;
            case OEWiimoteExpansionIdentifierFightingStick:
                expansion = OEWiimoteExpansionTypeFightingStick;
                break;
        }

        if(expansion != _expansionType)
        {
            _latestButtonReports.proController     = 0xFFFF;
            _latestButtonReports.classicController = 0xFFFF;
            _latestButtonReports.nunchuck          = 0xFF;

            _expansionType = expansion;
            _expansionPortAttached = (expansion != OEWiimoteExpansionTypeNotConnected);
            [self OE_initializeCalibration];
        }
    }
}

- (void)OE_initializeCalibration
{
    switch (_expansionType) {
        case OEWiimoteExpansionTypeNunchuck:
        case OEWiimoteExpansionTypeClassicController:
            /* Don't set the default calibration, because
             * all we have are theoretical minima and maxima */
            break;
            
        case OEWiimoteExpansionTypeWiiUProController:
            [self setCalibration:
                OEAxisCalibrationMake(
                    OEWiimoteProControllerJoystickScaledMinimumValue,
                    OEWiimoteProControllerJoystickScaledMaximumValue)
                forControlCookie:OEWiimoteProControllerLeftJoystickAxisXCookie];
            [self setCalibration:
                OEAxisCalibrationMake(
                    OEWiimoteProControllerJoystickScaledMinimumValue,
                    OEWiimoteProControllerJoystickScaledMaximumValue)
                forControlCookie:OEWiimoteProControllerLeftJoystickAxisYCookie];
            [self setCalibration:
                OEAxisCalibrationMake(
                    OEWiimoteProControllerJoystickScaledMinimumValue,
                    OEWiimoteProControllerJoystickScaledMaximumValue)
                forControlCookie:OEWiimoteProControllerRightJoystickAxisXCookie];
            [self setCalibration:
                OEAxisCalibrationMake(
                    OEWiimoteProControllerJoystickScaledMinimumValue,
                    OEWiimoteProControllerJoystickScaledMaximumValue)
                forControlCookie:OEWiimoteProControllerRightJoystickAxisYCookie];
            break;
        
        default:
            break;
    }
}

#pragma mark - Status request methods

- (void)OE_configureReportType;
{
    // Set the report type the Wiimote should send.
    // Buttons + 19 Extension bytes
    [self OE_sendCommandWithData:(const uint8_t[]){ 0x12, 0x02, 0x34 } length:3];
}

- (void)OE_disableReports
{
    [self OE_sendCommandWithData:(const uint8_t[]){ 0x12, 0x00, 0x30 } length:3];
}

- (void)OE_requestStatus
{
    [self OE_sendCommandWithData:(const uint8_t[]){ 0x15, 0x00 } length:2];
    _statusReportRequested = YES;
}

- (void)OE_synchronizeRumbleAndLEDStatus
{
    NSUInteger devNumber = [self deviceNumber];
    BOOL led1 = (devNumber == 1) || (devNumber == 5);
    BOOL led2 = (devNumber == 2) || (devNumber == 6) || (devNumber == 8);
    BOOL led3 = (devNumber == 3) || (devNumber == 7) || (devNumber == 8);
    BOOL led4 = (devNumber == 4) || (devNumber == 6) || (devNumber == 7) || (devNumber == 8);
    uint8_t wiimoteLEDStatus;
         if (led1) wiimoteLEDStatus = OEWiimoteDeviceHandlerLED1;
    else if (led2) wiimoteLEDStatus = OEWiimoteDeviceHandlerLED2;
    else if (led3) wiimoteLEDStatus = OEWiimoteDeviceHandlerLED3;
    else if (led4) wiimoteLEDStatus = OEWiimoteDeviceHandlerLED4;
    else           wiimoteLEDStatus = 0;

    uint8_t rumbleAndLEDStatus = wiimoteLEDStatus | _rumbleActivated;
    [self OE_sendCommandWithData:(uint8_t[]){ 0x11, rumbleAndLEDStatus & OEWiimoteRumbleAndLEDMask } length:2];
}

- (void)OE_checkBatteryLevel
{
    if(_batteryLevel < 1 && !_charging)
    {
        if(!_lowBatteryWarning)
        {
            _lowBatteryWarning = YES;
            [[NSNotificationCenter defaultCenter] postNotificationName:OEDeviceHandlerDidReceiveLowBatteryWarningNotification object:self];
        }
    }
    else if(_charging) _lowBatteryWarning = NO;
}

- (void)OE_readExpansionPortType
{
    // Initializing expansion port based on http://wiibrew.org/wiki/Wiimote/Extension_Controllers#The_New_Way
    switch(_expansionInitilization)
    {
        case OEExpansionInitializationStepWriteOne:
            [self OE_writeData:&(uint8_t){ 0x55 } length:1 atAddress:0x04A400F0];
            break;
        case OEExpansionInitializationStepWriteTwo:
            [self OE_writeData:&(uint8_t){ 0x00 } length:1 atAddress:0x04A400FB];
            break;
        case OEExpansionInitializationStepRead:
            [self OE_readDataOfLength:16 atAddress:0x04A400F0];
            break;
        default:
            break;
    }
}

#pragma mark - Parse methods

- (void)OE_parseWiimoteButtonData:(uint16_t)data;
{
    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];

    uint16_t changes = data ^ _latestButtonReports.wiimote;
    _latestButtonReports.wiimote = data;

    _OEWiimoteIdentifierEnumerateUsingBlock(_OEWiimoteButtonRange, ^(OEWiimoteButtonIdentifier identifier, NSUInteger usage, BOOL *stop) {
        if(changes & identifier)
            [self OE_dispatchButtonEventWithUsage:usage state:(data & identifier ? OEHIDEventStateOn : OEHIDEventStateOff) timestamp:timestamp cookie:usage];
    });
}

- (void)OE_parseNunchuckButtonData:(uint8_t)data;
{
    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];

    uint8_t changes = data ^ _latestButtonReports.nunchuck;
    _latestButtonReports.nunchuck = data;

    _OEWiimoteIdentifierEnumerateUsingBlock(_OENunchuckButtonRange, ^(OEWiimoteButtonIdentifier identifier, NSUInteger usage, BOOL *stop) {
        // Nunchuk uses 0 bit to mean pressed
        if(changes & identifier)
            [self OE_dispatchButtonEventWithUsage:usage state:(data & identifier ? OEHIDEventStateOff : OEHIDEventStateOn) timestamp:timestamp cookie:usage];
    });
}

- (void)OE_parseNunchuckJoystickXData:(uint8_t)xData yData:(uint8_t)yData;
{
    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];

    NSInteger(^scaleValue)(uint8_t value) =
    ^ NSInteger (uint8_t value)
    {
        NSInteger ret = value;
        ret = value;

        ret += OEWiimoteNunchuckAxisScaledMinimumValue;

        if(-OEWiimoteNunchuckDeadZone < ret && ret <= OEWiimoteNunchuckDeadZone) ret = 0;

        return ret;
    };

    [self OE_dispatchAxisEventWithAxis:OEWiimoteNunchuckAxisXUsage
                               minimum:OEWiimoteNunchuckAxisScaledMinimumValue
                                 value:scaleValue(xData)
                               maximum:OEWiimoteNunchuckAxisScaledMaximumValue
                             timestamp:timestamp
                                cookie:OEWiimoteNunchuckAxisXCookie];

    [self OE_dispatchAxisEventWithAxis:OEWiimoteNunchuckAxisYUsage
                               minimum:OEWiimoteNunchuckAxisScaledMinimumValue
                                 value:scaleValue(yData)
                               maximum:OEWiimoteNunchuckAxisScaledMaximumValue
                             timestamp:timestamp
                                cookie:OEWiimoteNunchuckAxisYCookie];
}

- (void)OE_parseClassicControllerButtonData:(uint16_t)data;
{
    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];

    uint16_t changes = data ^ _latestButtonReports.classicController;
    _latestButtonReports.classicController = data;

    _OEWiimoteIdentifierEnumerateUsingBlock(_OEClassicButtonRange, ^(OEWiimoteButtonIdentifier identifier, NSUInteger usage, BOOL *stop) {
        // Classic controller uses 0 for pressed, not 1 like standard wii buttons
        if(changes & identifier)
            [self OE_dispatchButtonEventWithUsage:usage state:((data & identifier) == 0 ? OEHIDEventStateOn : OEHIDEventStateOff) timestamp:timestamp cookie:usage];
    });
}

- (void)OE_parseClassicControllerJoystickAndTriggerData:(const uint8_t *)data;
{
    NSInteger(^scaleValue)(int8_t value) =
    ^ NSInteger (int8_t value)
    {
        NSInteger ret = value;
        ret = value;

        if(-OEWiimoteClassicControllerDeadZone < ret && ret <= OEWiimoteClassicControllerDeadZone) ret = 0;

        return ret;
    };

    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];

    NSInteger leftX  = (data[0] & 0x3F);
    NSInteger leftY  = (data[1] & 0x3F);

    leftX = scaleValue(leftX + OEWiimoteClassicControllerLeftJoystickScaledMinimumValue);
    leftY = scaleValue(leftY + OEWiimoteClassicControllerLeftJoystickScaledMinimumValue);

    NSInteger rightX = (data[0] & 0xC0) >> 3 | (data[1] & 0xC0) >> 5 | (data[2] & 0x80) >> 7;
    NSInteger rightY = (data[2] & 0x1F);

    rightX = scaleValue(rightX + OEWiimoteClassicControllerRightJoystickScaledMinimumValue);
    rightY = scaleValue(rightY + OEWiimoteClassicControllerRightJoystickScaledMinimumValue);

    NSInteger leftTrigger  = (data[2] & 0x60) >> 2 | (data[3] & 0xE0) >> 5;
    NSInteger rightTrigger = (data[3] & 0x1F);

    [self OE_dispatchAxisEventWithAxis:OEWiimoteClassicControllerLeftJoystickAxisXUsage
                               minimum:OEWiimoteClassicControllerLeftJoystickScaledMinimumValue
                                 value:leftX
                               maximum:OEWiimoteClassicControllerLeftJoystickScaledMaximumValue
                             timestamp:timestamp
                                cookie:OEWiimoteClassicControllerLeftJoystickAxisXCookie];

    [self OE_dispatchAxisEventWithAxis:OEWiimoteClassicControllerLeftJoystickAxisYUsage
                               minimum:OEWiimoteClassicControllerLeftJoystickScaledMinimumValue
                                 value:leftY
                               maximum:OEWiimoteClassicControllerLeftJoystickScaledMaximumValue
                             timestamp:timestamp
                                cookie:OEWiimoteClassicControllerLeftJoystickAxisYCookie];

    [self OE_dispatchAxisEventWithAxis:OEWiimoteClassicControllerRightJoystickAxisXUsage
                               minimum:OEWiimoteClassicControllerRightJoystickScaledMinimumValue
                                 value:rightX
                               maximum:OEWiimoteClassicControllerRightJoystickScaledMaximumValue
                             timestamp:timestamp
                                cookie:OEWiimoteClassicControllerRightJoystickAxisXCookie];

    [self OE_dispatchAxisEventWithAxis:OEWiimoteClassicControllerRightJoystickAxisYUsage
                               minimum:OEWiimoteClassicControllerRightJoystickScaledMinimumValue
                                 value:rightY
                               maximum:OEWiimoteClassicControllerRightJoystickScaledMaximumValue
                             timestamp:timestamp
                                cookie:OEWiimoteClassicControllerRightJoystickAxisYCookie];

    [self OE_dispatchTriggerEventWithAxis:OEWiimoteClassicControllerLeftTriggerAxisUsage
                                    value:leftTrigger
                                  maximum:OEWiimoteClassicControllerTriggerMaximumValue
                                timestamp:timestamp
                                   cookie:OEWiimoteClassicControllerLeftTriggerAxisCookie];

    [self OE_dispatchTriggerEventWithAxis:OEWiimoteClassicControllerRightTriggerAxisUsage
                                    value:rightTrigger
                                  maximum:OEWiimoteClassicControllerTriggerMaximumValue
                                timestamp:timestamp
                                   cookie:OEWiimoteClassicControllerRightTriggerAxisCookie];
}

- (void)OE_parseProControllerButtonData:(uint32_t)data
{
    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];

    uint32_t changes = data ^ _latestButtonReports.proController;
    _latestButtonReports.proController = data;

    _OEWiimoteIdentifierEnumerateUsingBlock(_OEProButtonRange, ^(OEWiimoteButtonIdentifier identifier, NSUInteger usage, BOOL *stop) {
        // Pro controller uses 0 for pressed, not 1 like standard wii buttons
        if(changes & identifier)
            [self OE_dispatchButtonEventWithUsage:usage state:((data & identifier) == 0 ? OEHIDEventStateOn : OEHIDEventStateOff) timestamp:timestamp cookie:usage];
    });
}

- (void)OE_parseProControllerJoystickData:(const uint8_t *)data
{
    NSInteger (^decodeJoystickData)(const uint8_t *) =
    ^(const uint8_t *data)
    {
        uint8_t high = data[1] & 0xf;
        uint8_t low  = data[0];
        NSInteger value = (high << 8) | (low);

        NSInteger ret = value;
        ret -= OEWiimoteProControllerJoystickMinimumValue;
        ret += OEWiimoteProControllerJoystickScaledMinimumValue + (-OEWiimoteProControllerDeadZone);

        if (-OEWiimoteProControllerDeadZone < ret && ret <= OEWiimoteProControllerDeadZone)
          ret = 0;
      
        /* since we use a really big center dead zone, we remove it from the
         * reported data, to make it possible to input small movements. */
        if (ret < 0)
          ret += OEWiimoteProControllerDeadZone;
        else if (ret > 0)
          ret -= OEWiimoteProControllerDeadZone;

        return ret;
    };

    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];

    NSInteger leftX  = decodeJoystickData(data);
    NSInteger leftY  = decodeJoystickData(data + 4);

    NSInteger rightX = decodeJoystickData(data + 2);
    NSInteger rightY = decodeJoystickData(data + 6);

    [self OE_dispatchAxisEventWithAxis:OEWiimoteProControllerLeftJoystickAxisXUsage
                               minimum:OEWiimoteProControllerJoystickScaledMinimumValue
                                 value:leftX
                               maximum:OEWiimoteProControllerJoystickScaledMaximumValue
                             timestamp:timestamp
                                cookie:OEWiimoteProControllerLeftJoystickAxisXCookie];

    [self OE_dispatchAxisEventWithAxis:OEWiimoteProControllerLeftJoystickAxisYUsage
                               minimum:OEWiimoteProControllerJoystickScaledMinimumValue
                                 value:leftY
                               maximum:OEWiimoteProControllerJoystickScaledMaximumValue
                             timestamp:timestamp
                                cookie:OEWiimoteProControllerLeftJoystickAxisYCookie];

    [self OE_dispatchAxisEventWithAxis:OEWiimoteProControllerRightJoystickAxisXUsage
                               minimum:OEWiimoteProControllerJoystickScaledMinimumValue
                                 value:rightX
                               maximum:OEWiimoteProControllerJoystickScaledMaximumValue
                             timestamp:timestamp
                                cookie:OEWiimoteProControllerRightJoystickAxisXCookie];

    [self OE_dispatchAxisEventWithAxis:OEWiimoteProControllerRightJoystickAxisYUsage
                               minimum:OEWiimoteProControllerJoystickScaledMinimumValue
                                 value:rightY
                               maximum:OEWiimoteProControllerJoystickScaledMaximumValue
                             timestamp:timestamp
                                cookie:OEWiimoteProControllerRightJoystickAxisYCookie];
}

#pragma mark - Event dispatch methods

- (void)OE_dispatchButtonEventWithUsage:(NSUInteger)usage state:(OEHIDEventState)state timestamp:(NSTimeInterval)timestamp cookie:(NSUInteger)cookie;
{
    [self dispatchEvent:[OEHIDEvent buttonEventWithDeviceHandler:self timestamp:timestamp buttonNumber:usage state:state cookie:cookie]];
}

- (void)OE_dispatchAxisEventWithAxis:(OEHIDEventAxis)axis minimum:(NSInteger)minimum value:(NSInteger)value maximum:(NSInteger)maximum timestamp:(NSTimeInterval)timestamp cookie:(NSUInteger)cookie;
{
    OEAxisCalibration range = OEAxisCalibrationMake(minimum, maximum);
    CGFloat scaledValue = [self scaledValue:value forAxis:axis controlCookie:cookie defaultCalibration:range];
    [self dispatchEvent:[OEHIDEvent axisEventWithDeviceHandler:self timestamp:timestamp axis:axis value:scaledValue cookie:cookie]];
}

- (void)OE_dispatchTriggerEventWithAxis:(OEHIDEventAxis)axis value:(NSInteger)value maximum:(NSInteger)maximum timestamp:(NSTimeInterval)timestamp cookie:(NSUInteger)cookie;
{
    [self dispatchEvent:[OEHIDEvent triggerEventWithDeviceHandler:self timestamp:timestamp axis:axis value:value maximum:maximum cookie:cookie]];
}

- (void)readReportData:(void *)dataPointer length:(size_t)dataLength
{
    uint8_t data[dataLength + 1];
    data[0] = 0xa1;
    memcpy(data+1, dataPointer, dataLength);
    dataLength += 1;

    if(data[1] == 0x20 && dataLength >= 8)
        [self OE_handleStatusReportData:data length:dataLength];
    else if(data[1] == 0x21) // read data response
    {
        [self OE_handleReadResponseData:data length:dataLength];
        [self OE_handleDataReportData:data length:dataLength];
    }
    else if(data[1] == 0x22) // Write data response
    {
        [self OE_handleWriteResponseData:data length:dataLength];
        [self OE_handleDataReportData:data length:dataLength];
    }
    else if((data[1] & 0xF0) == 0x30) // report contains button info
        [self OE_handleDataReportData:data length:dataLength];
}

@end

@implementation OEWiimoteHIDDeviceParser

- (OEWiimoteHIDDeviceHandler *)deviceHandlerForIOHIDDevice:(IOHIDDeviceRef)device
{
    NSUInteger vendorID = [(__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey)) integerValue];
    NSUInteger productID = [(__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey)) integerValue];
    NSString *product = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
    OEControllerDescription *controllerDesc = [OEControllerDescription OE_controllerDescriptionForVendorID:vendorID productID:productID product:product];
    if([controllerDesc numberOfControls] == 0)
    {
        NSDictionary *representations = [OEControllerDescription OE_representationForControllerDescription:controllerDesc];
        [representations enumerateKeysAndObjectsUsingBlock:
         ^(NSString *identifier, NSDictionary *representation, BOOL *stop)
         {
             OEHIDEventType type = OEHIDEventTypeFromNSString(representation[@"Type"]);
             NSUInteger usage = OEUsageFromUsageStringWithType(representation[@"Usage"], type);
             NSUInteger cookie = [representation[@"Cookie"] integerValue] ? : usage;

             OEHIDEvent *event = nil;
             switch(type)
             {
                 case OEHIDEventTypeAxis :
                     event = [OEHIDEvent axisEventWithDeviceHandler:nil timestamp:0 axis:usage direction:OEHIDEventAxisDirectionNull cookie:cookie];
                     break;
                 case OEHIDEventTypeButton :
                     event = [OEHIDEvent buttonEventWithDeviceHandler:nil timestamp:0 buttonNumber:usage state:OEHIDEventStateOn cookie:cookie];
                     break;
                 case OEHIDEventTypeHatSwitch :
                     NSAssert(NO, @"A hat switch on Wiimote?!");
                     break;
                 case OEHIDEventTypeKeyboard :
                     NSAssert(NO, @"A keyboard on Wiimote?!");
                     break;
                 case OEHIDEventTypeTrigger :
                     event = [OEHIDEvent triggerEventWithDeviceHandler:nil timestamp:0 axis:usage direction:OEHIDEventAxisDirectionPositive cookie:cookie];
                     break;
             }

             [controllerDesc addControlWithIdentifier:identifier name:representation[@"Name"] event:event valueRepresentations:representation[@"Values"]];
         }];
    }

    return [[OEWiimoteHIDDeviceHandler alloc] initWithIOHIDDevice:device deviceDescription:[controllerDesc deviceDescriptionForVendorID:vendorID productID:productID cookie:0]];
}

@end

NS_ASSUME_NONNULL_END

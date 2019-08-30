// Copyright (c) 2019, OpenEmu Team
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
 * Most of this code has been written based on the reverse-engineered documentation
 * which can be found at https://github.com/dekuNukem/Nintendo_Switch_Reverse_Engineering
 */

#import "OESwitchProControllerHIDDeviceHandler.h"


#define MAX_INPUT_REPORT_SIZE (256)


enum {
    OEHACSubcmdNoop = 0,
    OEHACSubcmdManualPairing,
    OEHACSubcmdRequestDeviceInfo,
    OEHACSubcmdSetInputReportMode,
    OEHACSubcmdRequestTriggerButtonHeldTime,
    OEHACSubcmdRequestPageListState,
    OEHACSubcmdSetPowerState,
    OEHACSubcmdResetPairing,
    OEHACSubcmdSetFactoryLowPowerState,
    OEHACSubcmdRequestSPIFlashRead = 0x10,
    OEHACSubcmdRequestSPIFlashWrite,
    OEHACSubcmdRequestSPIFlashErase,
    OEHACSubcmdResetNFCIR = 0x20,
    OEHACSubcmdSetNFCIRConfig,
    OEHACSubcmdSetNFCIRState,
    OEHACSubcmdSetPlayerLights = 0x30,
    OEHACSubcmdRequestPlayerLights,
    OEHACSubcmdSetHomeLight = 0x38
};


typedef struct __attribute__((packed)) {
    uint8_t reportID;
    uint8_t seqNumber;
    uint8_t chargingStatus;
    uint8_t buttons[3];
    uint8_t leftStick[3];
    uint8_t rightStick[3];
    uint8_t rumbleStatus;
} OEHACStandardHIDInputReport;

typedef struct __attribute__((packed)) {
    OEHACStandardHIDInputReport parent;
    uint8_t ackStatus;
    uint8_t repliedSubcmdId;
    uint8_t reply[34];
} OEHACAcknowledgmentHIDInputReport;


typedef uint8_t OEHAC12BitPackedPair[3];

typedef struct {
    uint16_t x;
    uint16_t y;
} OEHAC16BitUnsignedPair;


typedef struct __attribute__((packed)) {
    OEHAC12BitPackedPair maxDelta;
    OEHAC12BitPackedPair center;
    OEHAC12BitPackedPair minDelta;
} OEHACStickCalibrationData;

typedef struct __attribute__((packed)) {
    OEHAC12BitPackedPair left_maxDelta;
    OEHAC12BitPackedPair left_zero;
    OEHAC12BitPackedPair left_minDelta;
    // the following 3 lines of code are correct
    // anything suspicious is 100% nintendo's fault
    OEHAC12BitPackedPair right_zero;
    OEHAC12BitPackedPair right_minDelta;
    OEHAC12BitPackedPair right_maxDelta;
} OEHACFactoryStickCalibrationData;

typedef struct __attribute__((packed)) {
    uint16_t leftDataAvailable;
    OEHACStickCalibrationData leftStick;
    uint16_t rightDataAvailable;
    OEHACStickCalibrationData rightStick;
} OEHACUserStickCalibrationData;

enum {
    OEHACFactoryStickCalibrationDataAddress = 0x603D,
    OEHACUserStickCalibrationDataAddress = 0x8010,
    OEHACUserStickDataAvailableMagic = 0xA1B2
};


static void OEHACProControllerHIDReportCallback(
    void * _Nullable        context,
    IOReturn                result,
    void * _Nullable        sender,
    IOHIDReportType         type,
    uint32_t                reportID,
    uint8_t *               report,
    CFIndex                 reportLength);

static OEHAC16BitUnsignedPair OEHACUnpackPair(const OEHAC12BitPackedPair packed)
{
    OEHAC16BitUnsignedPair res;
    res.x = packed[0] | ((packed[1] & 0x0F) << 8);
    res.y = ((packed[1] & 0xF0) >> 4) | (packed[2] << 4);
    return res;
}


typedef struct {
    NSInteger min;
    NSInteger zero;
    NSInteger max;
} OEHACProControllerAxisCalibration;

typedef struct {
    OEHACProControllerAxisCalibration x;
    OEHACProControllerAxisCalibration y;
} OEHACProControllerStickCalibration;

static OEHACProControllerStickCalibration OEHACConvertCalibration(
    const OEHAC12BitPackedPair packed_maxdelta,
    const OEHAC12BitPackedPair packed_zero,
    const OEHAC12BitPackedPair packed_mindelta)
{
    OEHAC16BitUnsignedPair maxdelta, zero, mindelta;
    OEHACProControllerStickCalibration res;
    
    maxdelta = OEHACUnpackPair(packed_maxdelta);
    zero = OEHACUnpackPair(packed_zero);
    mindelta = OEHACUnpackPair(packed_mindelta);
    
    /* The calibration data is specified in the reference system used by
     * Nintendo's proprietary button status reports. Nintendo's reference
     * system flips the Y axis with respect to the HID specification. */
    res.x.max = (zero.x + maxdelta.x) << 4;
    res.x.zero = zero.x << 4;
    res.x.min = (zero.x - mindelta.x) << 4;
    res.y.max = 0x10000 - (NSInteger)((zero.y - mindelta.y) << 4);
    res.y.zero = 0x10000 - (NSInteger)(zero.y << 4);
    res.y.min = 0x10000 - (NSInteger)((zero.y + maxdelta.y) << 4);
    
    return res;
}


@implementation OESwitchProControllerHIDDeviceHandler
{
    uint8_t _reportBuffer[MAX_INPUT_REPORT_SIZE];
    uint8_t _packetCounter;
    dispatch_queue_t _auxCommQueue;
    
    NSData *_currentResponse;
    NSCondition *_responseAvailable;
    
    OEHACProControllerStickCalibration _leftStickCalibration;
    OEHACProControllerStickCalibration _rightStickCalibration;
}


+ (BOOL)canHandleDevice:(IOHIDDeviceRef)aDevice
{
    NSString *deviceName = (__bridge id)IOHIDDeviceGetProperty(aDevice, CFSTR(kIOHIDProductKey));
    
    if ([deviceName isEqualToString:@"Pro Controller"]) {
        NSNumber *vid = (__bridge id)IOHIDDeviceGetProperty(aDevice, CFSTR(kIOHIDVendorIDKey));
        NSNumber *pid = (__bridge id)IOHIDDeviceGetProperty(aDevice, CFSTR(kIOHIDProductIDKey));
        if ([vid integerValue] == 0x57E && [pid integerValue] == 0x2009) {
            return YES;
        }
    }
    
    return NO;
}


- (instancetype)initWithIOHIDDevice:(IOHIDDeviceRef)aDevice deviceDescription:(nullable OEDeviceDescription *)deviceDescription
{
    self = [super initWithIOHIDDevice:aDevice deviceDescription:deviceDescription];
    
    /* plausible default calibration
     * if everything goes according to plan, it will be rewritten by values
     * read from the controller's internal flash memory at connection time */
    _leftStickCalibration = _rightStickCalibration =
        (OEHACProControllerStickCalibration){
            .x = {.min = 8192, .zero = 32768, .max = 57344},
            .y = {.min = 8192, .zero = 32768, .max = 57344},
        };
    
    return self;
}


- (BOOL)connect
{
    _auxCommQueue = dispatch_queue_create("OEHACProControllerHIDDeviceHandler Bidirectional Communication", NULL);
    _responseAvailable = [[NSCondition alloc] init];
    IOHIDDeviceRegisterInputReportCallback([self device], _reportBuffer, MAX_INPUT_REPORT_SIZE, OEHACProControllerHIDReportCallback, (__bridge void *)self);
    
    [self _setPlayerLights:0x0F];
    [self _requestCalibrationData];
    return YES;
}


- (void)disconnect
{
    [self _setPlayerLights:0x00];
}


#pragma mark - Calibration


- (void)_requestCalibrationData
{
    dispatch_async(_auxCommQueue, ^{
        NSData *fact = [self _requestSPIFlashReadAtAddress:OEHACFactoryStickCalibrationDataAddress length:sizeof(OEHACFactoryStickCalibrationData)];
        if (!fact) {
            NSLog(@"cannot read stick calibration data from SPI flash!");
            return;
        }
        const OEHACFactoryStickCalibrationData *calibData = fact.bytes;
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            self->_leftStickCalibration = OEHACConvertCalibration(calibData->left_maxDelta, calibData->left_zero, calibData->left_minDelta);
            self->_rightStickCalibration = OEHACConvertCalibration(calibData->right_maxDelta, calibData->right_zero, calibData->right_minDelta);
            
            NSLog(@"Loaded calibration successfully for Switch Pro Controller %@", self);
            NSLog(@"Left stick (x, y): [+] %d, %d; [0] %d %d; [-] %d %d",
                (int)self->_leftStickCalibration.x.max,
                (int)self->_leftStickCalibration.y.max,
                (int)self->_leftStickCalibration.x.zero,
                (int)self->_leftStickCalibration.y.zero,
                (int)self->_leftStickCalibration.x.min,
                (int)self->_leftStickCalibration.y.min);
            NSLog(@"Right stick (x, y): [+] %d, %d; [0] %d %d; [-] %d %d",
                (int)self->_rightStickCalibration.x.max,
                (int)self->_rightStickCalibration.y.max,
                (int)self->_rightStickCalibration.x.zero,
                (int)self->_rightStickCalibration.y.zero,
                (int)self->_rightStickCalibration.x.min,
                (int)self->_rightStickCalibration.y.min);
        });
    });
}


- (CGFloat)scaledValue:(CGFloat)rawValue forAxis:(OEHIDEventAxis)axis controlCookie:(NSUInteger)cookie
{
    OEHACProControllerAxisCalibration *selectedCalibration;
    switch (axis) {
        case OEHIDEventAxisX:
            selectedCalibration = &(_leftStickCalibration.x);
            break;
        case OEHIDEventAxisY:
            selectedCalibration = &(_leftStickCalibration.y);
            break;
        case OEHIDEventAxisRx:
            selectedCalibration = &(_rightStickCalibration.x);
            break;
        case OEHIDEventAxisRy:
            selectedCalibration = &(_rightStickCalibration.y);
            break;
        default:
            NSLog(@"Apparently this Switch Pro Controller (%@) has an axis of type %@", self, NSStringFromOEHIDEventAxis(axis));
            return -100;
    }
    
    CGFloat res = rawValue - selectedCalibration->zero;
    if (res < 0.0) {
        res /= (CGFloat)(selectedCalibration->zero - selectedCalibration->min);
    } else {
        res /= (CGFloat)(selectedCalibration->max - selectedCalibration->zero);
    }
    
    /* the factory calibration is a bit conservative at the edges; compensate for that */
    res /= 0.90;
    
    return MAX(-1, MIN(res, 1));
}


#pragma mark - Controller-Specific functionality


- (void)_setPlayerLights:(uint8_t)mask
{
    dispatch_async(_auxCommQueue, ^{
        [self _sendSubcommand:OEHACSubcmdSetPlayerLights withData:&mask length:1];
    });
}


- (void)_setReportMode:(uint8_t)mode
{
    dispatch_async(_auxCommQueue, ^{
        [self _sendSubcommand:OEHACSubcmdSetInputReportMode withData:&mode length:1];
    });
}


#pragma mark - Custom HID Reports Send/Receive Primitives


/* Only invoke while in _auxCommQueue, otherwise we'll deadlock! */
- (NSData *)_requestSPIFlashReadAtAddress:(uint32_t)in_base length:(uint8_t)in_len
{
    NSAssert(in_len <= 29, @"cannot read more than 29 bytes from SPI Flash at a time");
    
    struct __attribute__((packed)) {
        uint32_t base;
        uint8_t len;
    } spiReadSubcmdData = {in_base, in_len};
    
    NSData *data = [self _sendSubcommand:OEHACSubcmdRequestSPIFlashRead withData:&spiReadSubcmdData length:sizeof(spiReadSubcmdData)];
    if (!data)
        return nil;
    
    const OEHACAcknowledgmentHIDInputReport *ack = data.bytes;
    const struct __attribute__((packed)) {
        uint32_t base;
        uint8_t len;
        uint8_t data[29];
    } *reply = (void *)ack->reply;

    if (reply->base != in_base || reply->len != in_len) {
        NSLog(@"Wrong ACK from controller (SPI Flash read wrong offset/length)");
        return nil;
    }
    
    return [NSData dataWithBytes:reply->data length:in_len];
}


/* Only invoke while in _auxCommQueue, otherwise we'll deadlock! */
- (NSData *)_sendSubcommand:(uint8_t)cmdid withData:(const void *)data length:(NSUInteger)length
{
    uint8_t buffer[0x40] = { 0 };
    buffer[0] = 0x1;
    buffer[1] = _packetCounter;
    _packetCounter = (_packetCounter + 1) & 0xF;
    buffer[10] = cmdid;
    if (data)
        memcpy(buffer + 11, data, length);
    
    NSData *ack;

    [_responseAvailable lock];
    
    _currentResponse = nil;
    IOReturn ret = IOHIDDeviceSetReport([self device], kIOHIDReportTypeOutput, 0x1, buffer, 0x40);
    if  (ret != kIOReturnSuccess) {
        NSLog(@"Could not send command, error: %x", ret);
        goto fail;
    }
    
    BOOL notTimeout = YES;
    while (_currentResponse == nil && notTimeout)
        notTimeout = [_responseAvailable waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:10]];
    if (!notTimeout) {
        NSLog(@"Did not receive ACK from controller after 10 s (subcommand %02X)", cmdid);
        goto fail;
    }
    
    if ([_currentResponse length] < sizeof(OEHACAcknowledgmentHIDInputReport)) {
        NSLog(@"Invalid ACK from controller (subcommand %02X)", cmdid);
        goto fail;
    }
    const OEHACAcknowledgmentHIDInputReport *response = [_currentResponse bytes];
    if (!(response->ackStatus & 0x80)) {
        NSLog(@"NACK from controller (subcommand %02X)", cmdid);
        goto fail;
    }
    if (response->repliedSubcmdId != cmdid) {
        NSLog(@"Wrong ACK from controller (subcommand %02X expected, %02X received)", cmdid, response->repliedSubcmdId);
        goto fail;
    }
    ack = _currentResponse;
    
fail:
    [_responseAvailable unlock];
    
    return ack;
}


- (void)_didReceiveInputReportWithID:(uint8_t)rid data:(uint8_t *)data length:(NSUInteger)length
{
    if (data[0] != 0x21) {
        #ifdef DEBUG
        if (data[0] != 0x3F) {
            NSLog(@"non-ack report %@", [NSData dataWithBytes:data length:length]);
        }
        #endif
        return;
    }
    
    [_responseAvailable lock];
    _currentResponse = [NSData dataWithBytes:data length:length];
    [_responseAvailable signal];
    [_responseAvailable unlock];
}


@end


static void OEHACProControllerHIDReportCallback(
    void * _Nullable        context,
    IOReturn                result,
    void * _Nullable        sender,
    IOHIDReportType         type,
    uint32_t                reportID,
    uint8_t *               report,
    CFIndex                 reportLength)
{
    [(__bridge OESwitchProControllerHIDDeviceHandler *)context _didReceiveInputReportWithID:reportID data:report length:reportLength];
}


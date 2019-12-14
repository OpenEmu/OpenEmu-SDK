//
//  OEXBox360HIDDeviceHander.m
//  OpenEmu
//
//  Created by Joshua Weinberg on 12/30/12.
//
//

#import "OEXBox360HIDDeviceHander.h"

NS_ASSUME_NONNULL_BEGIN

@interface OEDeviceHandler ()
@property(readwrite) NSUInteger deviceNumber;
@end

@implementation OEXBox360HIDDeviceHander

+ (BOOL)canHandleDevice:(IOHIDDeviceRef)device
{
    NSString *deviceName = (__bridge id)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
    return [deviceName isEqualToString:@"Controller"];
}

- (void)setDeviceNumber:(NSUInteger)deviceNumber
{
    // see: http://tattiebogle.net/index.php/ProjectRoot/Xbox360Controller/UsbInfo#toc3
    [super setDeviceNumber:deviceNumber];

    NSUInteger pattern = deviceNumber + 0x6;
    
    IOHIDDeviceSetReport([self device],
                         kIOHIDReportTypeOutput,
                         0x0,
                         (uint8_t[]){ 0x1, 0x3, pattern },
                         3);
}

@end

NS_ASSUME_NONNULL_END

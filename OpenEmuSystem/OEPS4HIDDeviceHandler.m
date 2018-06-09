/*
 Copyright (c) 2018, OpenEmu Team

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

#import "OEPS4HIDDeviceHandler.h"

NS_ASSUME_NONNULL_BEGIN

@interface OEDeviceHandler ()
@property(readwrite) NSUInteger deviceNumber;
@end

@implementation OEPS4HIDDeviceHandler {
}

- (BOOL)connect
{
    // Unfortunately, HID stops responding after sending an output report.
    // https://stackoverflow.com/questions/30793753/iokit-not-receiving-hid-interrupt-reports-from-dualshock-4-controller-connected
    // https://stackoverflow.com/questions/43852993/macos-hid-usb-control-transfer-hid-api-libusb-macos
#if 0
    CFTypeRef transportType = IOHIDDeviceGetProperty([self device], CFSTR(kIOHIDTransportKey));
    BOOL isBluetooth = CFStringCompare(transportType, CFSTR(kIOHIDTransportBluetoothValue), 0) == kCFCompareEqualTo;

    if (isBluetooth)
    {
        // Turn off lightbar
        // https://github.com/torvalds/linux/blob/a3818841bd5e9b4a7e0e732c19cf3a632fcb525e/drivers/hid/hid-sony.c#L2179
        // http://www.psdevwiki.com/ps4/DS4-BT#0x11_2
        uint8_t data[79];
        memset(data, 0, sizeof(data));
        data[0]  = 0xA2; // Bluetooth header, transaction type DATA (0x0a), report type OUTPUT (0x02).
        data[1]  = 0x11; // protocol code/ID or encoded packet size?
        data[2]  = 0xC0 | 4; // Poll interval 4ms
        data[4]  = 0x07; // Enable LEDs, flash, rumble
        data[7]  = 0x00; // Rumble (right / weak)
        data[8]  = 0x00; // Rumble (left / strong)
        data[9]  = 0x00; // LED Red
        data[10] = 0x00; // LED Green
        data[11] = 0x00; // LED Blue
        data[12] = 0x00; // Duration LED flash bright
        data[13] = 0x00; // Duration LED flash dark

        // Calculate little-endian CRC32, then add the 4 bytes to end of data
        uint32_t crc = rc_crc32(0, data, sizeof(data) - 4);
        data[75] = crc & 0xff;
        data[76] = (crc >> 8) & 0xff;
        data[77] = (crc >> 16) & 0xff;
        data[78] = crc >> 24;

        IOHIDDeviceSetReport([self device],
                             kIOHIDReportTypeOutput,
                             data[0], // Matters?
                             data + 1,
                             sizeof(data) - 1);
    }
#endif
    return YES;
}

- (void)disconnect
{
    [super disconnect];
}

// https://rosettacode.org/wiki/CRC-32#C
// Alternative: use zlib
uint32_t rc_crc32(uint32_t crc, unsigned char const *buf, size_t len)
{
    static uint32_t table[256];
    static int have_table = 0;
    uint32_t rem;
    uint8_t octet;
    int i, j;
    unsigned char const *p, *q;

    /* This check is not thread safe; there is no mutex. */
    if (have_table == 0) {
        /* Calculate CRC table. */
        for (i = 0; i < 256; i++) {
            rem = i;  /* remainder from polynomial division */
            for (j = 0; j < 8; j++) {
                if (rem & 1) {
                    rem >>= 1;
                    rem ^= 0xedb88320;
                } else
                    rem >>= 1;
            }
            table[i] = rem;
        }
        have_table = 1;
    }

    crc = ~crc;
    q = buf + len;
    for (p = buf; p < q; p++) {
        octet = *p;  /* Cast to unsigned octet. */
        crc = (crc >> 8) ^ table[(crc & 0xff) ^ octet];
    }
    return ~crc;
}

@end

NS_ASSUME_NONNULL_END

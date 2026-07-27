// Copyright (c) 2024, OpenEmu Team
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

#import <OpenEmuSystem/OEDeviceHandler.h>

@class GCController;

NS_ASSUME_NONNULL_BEGIN

/// A device handler backed by a controller vended by Apple's GameController
/// framework (`GCController`) rather than by a raw IOKit HID device.
///
/// Since macOS Catalina, several console controllers — most notably
/// Bluetooth-LE Xbox controllers (Xbox Wireless Controller, Xbox Elite
/// Wireless Controller Series 2, Xbox Series X|S), the DualShock 4 /
/// DualSense over BLE, and MFi controllers — are captured by the system and
/// exposed *only* through the GameController framework. They never appear as
/// generic `IOHIDDevice`s, so OpenEmu's IOKit-based `OEDeviceManager`
/// enumeration cannot see them. This handler bridges such a controller into
/// the regular `OEHIDEvent` pipeline so it can be mapped and used like any
/// other gamepad.
///
/// The handler maps the controller's `GCExtendedGamepad` profile onto the
/// `OEControllerGCExtendedGamepadProfile` entry from `Controller-Database.plist`,
/// emitting `OEHIDEvent`s whose usages/cookies match that profile's mappings.
@interface OEGameControllerDeviceHandler : OEDeviceHandler

- (instancetype)initWithDeviceDescription:(nullable OEDeviceDescription *)deviceDescription NS_UNAVAILABLE;

/// Returns a handler wrapping the given GameController-framework controller,
/// or nil if the controller does not expose an extended gamepad profile (in
/// which case it cannot be mapped and is left to be handled elsewhere).
+ (nullable instancetype)deviceHandlerWithController:(GCController *)controller;

@property(readonly) GCController *controller;

@end

NS_ASSUME_NONNULL_END

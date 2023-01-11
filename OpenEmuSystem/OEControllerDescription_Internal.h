/*
 Copyright (c) 2013, OpenEmu Team

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

#import "OEControllerDescription.h"
#import "OEControlDescription.h"
#import "OEDeviceDescription.h"
#import "OEHIDEvent_Internal.h"

@interface OEControllerDescription ()
+ (OEControllerDescription *)OE_controllerDescriptionForVendorID:(NSUInteger)vendorID productID:(NSUInteger)productID product:(NSString *)product;

+ (NSDictionary<NSString *, NSDictionary<NSString *, id> *> *)OE_representationForControllerDescription:(OEControllerDescription *)controllerDescription;

- (OEDeviceDescription *)OE_addDeviceDescriptionWithVendorID:(NSUInteger)vendorID productID:(NSUInteger)productID product:(NSString *)product cookie:(uint32_t)cookie;
- (void)OE_controlDescription:(OEControlDescription *)control didAddControlValue:(OEControlValueDescription *)valueDesc;
@end

@interface OEDeviceDescription ()
- (instancetype)OE_initWithRepresentation:(NSDictionary *)representation controllerDescription:(OEControllerDescription *)controllerDescription __attribute__((objc_method_family(init)));
- (instancetype)OE_deviceDescriptionWithControllerDescription:(OEControllerDescription *)controllerDescription;
@end

@interface OEControlDescription ()
- (instancetype)OE_initWithIdentifier:(NSString *)identifier name:(NSString *)name genericEvent:(OEHIDEvent *)genericEvent controllerDescription:(OEControllerDescription *)controllerDescription __attribute__((objc_method_family(init)));
@end

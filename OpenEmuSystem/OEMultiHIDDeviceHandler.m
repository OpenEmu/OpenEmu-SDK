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

#import "OEMultiHIDDeviceHandler.h"
#import "OEDeviceDescription.h"
#import "OEControllerDescription.h"
#import "OEHIDEvent_Internal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation OEMultiHIDDeviceHandler {
    NSDictionary<NSNumber *, OEHIDSubdeviceHandler *> *_subdeviceHandlers;
}

- (instancetype)initWithIOHIDDevice:(IOHIDDeviceRef)aDevice deviceDescription:(OEDeviceDescription *)deviceDescription subdeviceDescriptions:(NSDictionary<NSNumber *, OEDeviceDescription *> *)descriptions;
{
    if((self = [super initWithIOHIDDevice:aDevice deviceDescription:deviceDescription])) {
        _subdeviceDescriptions = descriptions;

        NSMutableDictionary *subhandlers = [[NSMutableDictionary alloc] initWithCapacity:[_subdeviceDescriptions count]];

        [_subdeviceDescriptions enumerateKeysAndObjectsUsingBlock:^(NSNumber *key, OEDeviceDescription *desc, BOOL *stop) {
            OEHIDSubdeviceHandler *subhandler = [[OEHIDSubdeviceHandler alloc] initWithParentDeviceHandler:self deviceDescription:desc subdeviceIdentifier:key];
            subhandlers[key] = subhandler;
        }];

        _subdeviceHandlers = [subhandlers copy];
    }
    return self;
}

- (NSArray<OEHIDSubdeviceHandler *> *)subdeviceHandlers
{
    return [_subdeviceHandlers allValues];
}

- (OEHIDEvent *)eventWithHIDValue:(IOHIDValueRef)aValue
{
    IOHIDElementRef element = IOHIDValueGetElement(aValue);
    id deviceIdentifier = (__bridge id)IOHIDElementGetProperty(element, CFSTR(kOEHIDElementDeviceIdentifierKey));
    OEHIDSubdeviceHandler *handler = _subdeviceHandlers[deviceIdentifier];

    NSAssert(handler != nil, @"Element %@ received by %@ has an invalid identifier %@ not corresponding to a subdevice handler.", element, self, deviceIdentifier);

    return [OEHIDEvent eventWithDeviceHandler:handler value:aValue];
}

@end

@implementation OEHIDSubdeviceHandler

- (instancetype)initWithParentDeviceHandler:(OEMultiHIDDeviceHandler *)parentHandler deviceDescription:(OEDeviceDescription *)deviceDescription subdeviceIdentifier:(id)identifier;
{
    if((self = [super initWithDeviceDescription:deviceDescription])) {
        _parentDeviceHandler = parentHandler;
        _subdeviceIdentifier = identifier;
    }

    return self;
}

- (NSString *)uniqueIdentifier
{
    return [NSString stringWithFormat:@"%@ %u", [[self parentDeviceHandler] locationID], [[self deviceDescription] cookie]];
}

@end

NS_ASSUME_NONNULL_END

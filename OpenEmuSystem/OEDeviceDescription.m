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

#import "OEDeviceDescription.h"
#import "OEControllerDescription_Internal.h"

@implementation OEDeviceDescription

- (instancetype)OE_initWithRepresentation:(NSDictionary *)representation controllerDescription:(OEControllerDescription *)controllerDescription
{
    if((self = [super init]))
    {
        _name = [representation[@"OEControllerDeviceName"] copy];
        _product = [representation[@"OEControllerProductName"] copy] ?: _name;
        _vendorID = [representation[@"OEControllerVendorID"] integerValue];
        _productID = [representation[@"OEControllerProductID"] integerValue];
        _cookie = [representation[@"OEControllerCookie"] unsignedShortValue];
        _requiresNameMatch = [representation[@"OEControllerRequiresNameMatch"] boolValue];
        _genericDeviceIdentifier = [NSString stringWithFormat:@"OEGenericDeviceIdentifier_%ld_%ld", _vendorID, _productID];
        _controllerDescription = controllerDescription;
    }

    return self;
}

- (instancetype)OE_deviceDescriptionWithControllerDescription:(OEControllerDescription *)controllerDescription
{
    OEDeviceDescription *ret = [[[self class] alloc] init];
    ret->_name = [_name copy];
    ret->_product = [_product copy];
    ret->_vendorID = _vendorID;
    ret->_productID = _productID;
    ret->_cookie = _cookie;
    ret->_genericDeviceIdentifier = _genericDeviceIdentifier;
    ret->_requiresNameMatch = _requiresNameMatch;
    ret->_controllerDescription = controllerDescription;

    return ret;
}

- (id)copyWithZone:(nullable NSZone *)zone
{
    return self;
}

- (NSUInteger)hash;
{
    NSUInteger hash = _vendorID << 32 | _productID;

    if (_requiresNameMatch) {
        hash ^= _product.hash;
    }

    return hash;
}

- (BOOL)isEqual:(OEDeviceDescription *)object;
{
    if(self == object) return YES;

    if(![object isKindOfClass:[OEDeviceDescription class]])
        return NO;

    if (_vendorID != object->_vendorID)
        return NO;

    if (_productID != object->_productID)
        return NO;

    if (_requiresNameMatch != object->_requiresNameMatch)
        return NO;

    if (!_requiresNameMatch)
        return YES;

    return [_product isEqualToString:object->_product];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %@ %ld %ld>", _name, [[self controllerDescription] name], _vendorID, _productID];
}

- (NSString *)identifier
{
    return [self genericDeviceIdentifier];
}

- (NSString *)controllerIdentifier
{
    return [[self controllerDescription] identifier];
}

@end

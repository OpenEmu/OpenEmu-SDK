//
//  OEBindingDescription.m
//  OpenEmu-SDK
//
//  Created by Remy Demarest on 24/11/2015.
//
//

#import "OEBindingDescription.h"

#import "OESystemController.h"

static NSString *const OEBindingDescriptionSystemControllerKey = @"OEBindingDescriptionSystemController";

@implementation OEBindingDescription

- (instancetype)init
{
    return nil;
}

- (instancetype)initWithSystemController:(OESystemController *)systemController;
{
    if (!(self = [super init]))
        return nil;

    _systemController = systemController;

    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (!(self = [super init]))
        return nil;

    _systemController = [OESystemController systemControllerWithIdentifier:[aDecoder decodeObjectOfClass:[NSString class] forKey:OEBindingDescriptionSystemControllerKey]];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_systemController.systemIdentifier forKey:OEBindingDescriptionSystemControllerKey];
}

@end

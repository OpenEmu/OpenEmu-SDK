//
//  OEHIDEvent_Internal.h
//  OpenEmu-SDK
//
//  Created by Remy Demarest on 22/12/2015.
//
//

#import <OpenEmuSystem/OpenEmuSystem.h>
#import <OpenEmuBase/OEPropertyList.h>

@interface OEHIDEvent ()

+ (instancetype)eventWithDictionaryRepresentation:(NSDictionary<NSString *, __kindof id<OEPropertyList>> *)dictionaryRepresentation;
- (NSDictionary<NSString *, __kindof id<OEPropertyList>> *)dictionaryRepresentation;

@end

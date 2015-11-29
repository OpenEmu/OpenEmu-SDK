//
//  OEBindingDescription.h
//  OpenEmu-SDK
//
//  Created by Remy Demarest on 24/11/2015.
//
//

#import <Foundation/Foundation.h>

@class OESystemController;

@interface OEBindingDescription : NSObject <NSCopying, NSSecureCoding>

- (instancetype)init NS_UNAVAILABLE;

@property (weak, readonly, nonatomic) OESystemController *systemController;

@end

//
//  OEBindingDescription.h
//  OpenEmu-SDK
//
//  Created by Remy Demarest on 24/11/2015.
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class OESystemController;

@interface OEBindingDescription : NSObject <NSCopying, NSSecureCoding>

- (instancetype)init NS_UNAVAILABLE;

@property (weak, nullable, readonly, nonatomic) OESystemController *systemController;

@end

NS_ASSUME_NONNULL_END

//
//  OEBindingDescription_Internal.h
//  OpenEmu-SDK
//
//  Created by Remy Demarest on 27/11/2015.
//
//

#import <OpenEmuSystem/OpenEmuSystem.h>

NS_ASSUME_NONNULL_BEGIN

@interface OEBindingDescription ()
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithSystemController:(nullable OESystemController *)systemController NS_DESIGNATED_INITIALIZER;
@end

@interface OEKeyBindingGroupDescription ()
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithSystemController:(nullable OESystemController *)systemController NS_UNAVAILABLE;
- (instancetype)initWithSystemController:(nullable OESystemController *)systemController groupType:(OEKeyGroupType)aType keys:(NSArray<OEKeyBindingDescription *> *)groupedKeys NS_DESIGNATED_INITIALIZER;
@end

@interface OEKeyBindingDescription ()

- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithSystemController:(nullable OESystemController *)systemController NS_UNAVAILABLE;
- (instancetype)initWithSystemController:(nullable OESystemController *)systemController name:(nullable NSString *)keyName index:(NSUInteger)keyIndex isSystemWide:(BOOL)systemWide NS_DESIGNATED_INITIALIZER;

@property(readwrite, getter=isAnalogic, setter=OE_setAnalogic:) BOOL analogic;
@property(weak, readwrite, nullable, nonatomic, setter=OE_setHatSwitchGroup:) OEKeyBindingGroupDescription *hatSwitchGroup;
@property(weak, readwrite, nullable, nonatomic, setter=OE_setAxisGroup:) OEKeyBindingGroupDescription *axisGroup;

@end

@interface OEGlobalKeyBindingDescription ()
- (instancetype)initWithSystemController:(nullable OESystemController *)systemController name:(nullable NSString *)keyName index:(NSUInteger)keyIndex isSystemWide:(BOOL)systemWide NS_UNAVAILABLE;
- (instancetype)initWithButtonIdentifier:(OEGlobalButtonIdentifier)identifier NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_DESIGNATED_INITIALIZER;
@end

NS_ASSUME_NONNULL_END

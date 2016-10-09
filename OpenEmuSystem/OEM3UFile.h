//
//  OEM3UFile.h
//  OpenEmu-SDK
//
//  Created by Remy Demarest on 27/08/2016.
//
//

#import <Foundation/Foundation.h>
#import <OpenEmuSystem/OECDSheet.h>

NS_ASSUME_NONNULL_BEGIN

@class OECUESheet;

extern NSString *const OEM3UFileErrorDomain;

NS_ENUM(NSInteger) {
    OEM3UFileEmptyFileError = -1,
};

@interface OEM3UFile : OECDSheet

@property (nonatomic, copy, readonly) NSArray<OECDSheet *> *referencedCDSheets;

- (NSString *)fileContentWithRelativeFilePaths;

@end

NS_ASSUME_NONNULL_END

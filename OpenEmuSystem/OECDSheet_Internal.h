//
//  OECDSheet_Internal.h
//  OpenEmu-SDK
//
//  Created by Remy Demarest on 27/08/2016.
//
//

#import "OECDSheet.h"

NS_ASSUME_NONNULL_BEGIN

@interface OECDSheet ()

- (BOOL)_setUpFileReferencesWithError:(NSError **)error;
- (nullable NSString *)_fileContentWithError:(NSError **)error;

@property (nonatomic, copy, readwrite) NSArray<NSURL *> *referencedFileURLs;
@property (nonatomic, copy, readwrite) NSArray<NSURL *> *allReferencedFileURLs;
@property (nonatomic, copy, readwrite) NSArray<NSURL *> *referencedBinaryFileURLs;
@property (nonatomic, copy, readwrite) NSURL *dataTrackFileURL;

@end

NS_ASSUME_NONNULL_END

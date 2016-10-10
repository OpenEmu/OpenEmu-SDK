//
//  OEFile.h
//  OpenEmu-SDK
//
//  Created by Remy Demarest on 28/08/2016.
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OEFile : NSObject

+ (void)registerClass:(Class)class forFileExtension:(NSString *)fileExtension;
+ (nullable __kindof OEFile *)fileWithURL:(NSURL *)fileURL error:(NSError **)error;

- (instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initWithFileURL:(NSURL *)fileURL error:(NSError **)error;

/// URL of the file with which the receiver was created.
@property (nonatomic, copy, readonly) NSURL *fileURL;
@property (nonatomic, copy, readonly) NSString *fileExtension;
@property (nonatomic, readonly) NSUInteger fileSize;

@property (nonatomic, copy, readonly) NSArray<NSURL *> *allFileURLs;

/// URL of the main data track file.
@property (nonatomic, copy, readonly) NSURL *dataTrackFileURL;

/// Return empty data if the range is invalid.
- (NSData *)readDataInRange:(NSRange)dataRange;

/// Return empty string if the range is invalid or
/// if the data could not be read as an ASCII string.
- (NSString *)readASCIIStringInRange:(NSRange)dataRange;

- (nullable instancetype)fileByMovingFileToURL:(NSURL *)destinationURL error:(NSError **)error;
- (nullable instancetype)fileByCopyingFileToURL:(NSURL *)destinationURL error:(NSError **)error;

/// Move all the referenced files to the destinationURL directory.
- (BOOL)moveToURL:(NSURL *)destinationURL error:(NSError **)error;

/// Copy all the referenced files to the destinationURL directory.
- (BOOL)copyToURL:(NSURL *)destinationURL error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END

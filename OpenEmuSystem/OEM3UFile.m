//
//  OEM3UFile.m
//  OpenEmu-SDK
//
//  Created by Remy Demarest on 27/08/2016.
//
//

#import "OEM3UFile.h"

#import "OECDSheet_Internal.h"

NSString *const OEM3UFileErrorDomain = @"org.openemu.OEM3UFile.ErrorDomain";

@implementation OEM3UFile

- (BOOL)_setUpFileReferencesWithError:(NSError **)error
{
    NSString *fileContent = [self _fileContentWithError:error];
    if (!fileContent)
        return NO;

    NSURL *directoryURL = self.fileURL.URLByDeletingLastPathComponent;

    NSMutableArray<NSURL *> *referencedFileURLs = [NSMutableArray array];
    NSMutableArray<NSURL *> *allReferencedFileURLs = [NSMutableArray array];
    NSMutableArray<NSURL *> *referencedBinaryFileURLs = [NSMutableArray array];
    NSMutableArray<OECDSheet *> *referencedSheets = [NSMutableArray array];

    __block NSError *localError;
    __block BOOL failedToValidateContainedFiles = NO;
    [fileContent enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        NSURL *url = [NSURL fileURLWithPath:line isDirectory:NO relativeToURL:directoryURL].absoluteURL;

        __kindof OEFile *referencedFile = [OEFile fileWithURL:url error:&localError];
        if (![referencedFile isKindOfClass:[OECDSheet class]]) {
            // Don't import the m3u if it contains invalid referenced files (unreachable or non-OECDSheet).
            failedToValidateContainedFiles = YES;
            return;
        }

        OECDSheet *referencedSheet = referencedFile;

        [referencedFileURLs addObject:url];
        [allReferencedFileURLs addObject:url];
        [allReferencedFileURLs addObjectsFromArray:referencedSheet.allReferencedFileURLs];
        [referencedBinaryFileURLs addObjectsFromArray:referencedSheet.referencedBinaryFileURLs];
        [referencedSheets addObject:referencedSheet];
    }];

    if (failedToValidateContainedFiles) {
        if (error != nil)
            *error = localError;

        return NO;
    }

    self.dataTrackFileURL = referencedBinaryFileURLs.firstObject;
    self.referencedFileURLs = referencedFileURLs;
    self.allReferencedFileURLs = allReferencedFileURLs;
    self.referencedBinaryFileURLs = referencedBinaryFileURLs;

    return YES;
}

- (BOOL)moveToURL:(NSURL *)destinationURL error:(NSError **)error;
{
    // Rewrite the file in case there are relative paths in the original file.
    if (![self.fileContentWithRelativeFilePaths writeToURL:destinationURL atomically:YES encoding:NSUTF8StringEncoding error:error])
        return NO;

    if (![[NSFileManager defaultManager] removeItemAtURL:self.fileURL error:error])
        return NO;

    return [self moveReferencedFilesToDirectoryAtURL:destinationURL.URLByDeletingLastPathComponent error:error];
}

- (BOOL)copyToURL:(NSURL *)destinationURL error:(NSError *__autoreleasing *)error
{
    // Rewrite the file in case there are relative paths in the original file.
    if (![self.fileContentWithRelativeFilePaths writeToURL:destinationURL atomically:YES encoding:NSUTF8StringEncoding error:error])
        return NO;

    return [self copyReferencedFilesToDirectoryAtURL:destinationURL.URLByDeletingLastPathComponent error:error];
}

- (NSString *)fileContentWithRelativeFilePaths
{
    return [[self.referencedFileURLs valueForKey:@"lastPathComponent"] componentsJoinedByString:@"\n"];
}

@end

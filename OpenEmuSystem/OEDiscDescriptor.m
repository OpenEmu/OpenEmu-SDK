/*
 Copyright (c) 2018, OpenEmu Team

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

#import "OEDiscDescriptor.h"

#import "OEDiscDescriptor_Internal.h"

NSString *const OEDiscDescriptorErrorDomain = @"org.openemu.OEDiscDescriptor.ErrorDomain";

@implementation OEDiscDescriptor

@synthesize dataTrackFileURL = _dataTrackFileURL;

- (nullable instancetype)initWithFileURL:(NSURL *)fileURL error:(NSError **)error
{
    if (!(self = [super initWithFileURL:fileURL error:error]))
        return nil;

    if (![self _setUpFileReferencesWithError:error])
        return nil;

    if (![self _validateFileURLs:_referencedFileURLs withError:error])
        return nil;

    return self;
}

- (NSArray<NSURL *> *)allFileURLs
{
    return [@[ self.fileURL ] arrayByAddingObjectsFromArray:self.allReferencedFileURLs];
}

- (BOOL)moveToURL:(NSURL *)destinationURL error:(NSError **)error;
{
    if (![super moveToURL:destinationURL error:error])
        return NO;

    return [self moveReferencedFilesToDirectoryAtURL:destinationURL.URLByDeletingLastPathComponent error:error];
}

- (BOOL)moveReferencedFilesToDirectoryAtURL:(NSURL *)destinationURL error:(NSError **)error
{
    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSMutableDictionary<NSURL *, NSURL *> *destinationToOriginURLs = [NSMutableDictionary dictionary];

    for (NSURL *originFileURL in _allReferencedFileURLs) {
        NSURL *destinationFileURL = [destinationURL URLByAppendingPathComponent:originFileURL.lastPathComponent];

        if ([fileManager moveItemAtURL:originFileURL toURL:destinationFileURL error:error]) {
            destinationToOriginURLs[destinationURL] = originFileURL;
            continue;
        }

        // Move every file that was moved already back to its original location.
        [destinationToOriginURLs enumerateKeysAndObjectsUsingBlock:^(NSURL *destinationFileURL, NSURL *originFileURL, BOOL *stop) {
            [fileManager moveItemAtURL:destinationFileURL toURL:originFileURL error:nil];
        }];

        return NO;
    }

    return YES;
}

- (BOOL)copyToURL:(NSURL *)destinationURL error:(NSError **)error;
{
    if (![super copyToURL:destinationURL error:error])
        return NO;

    return [self copyReferencedFilesToDirectoryAtURL:destinationURL.URLByDeletingLastPathComponent error:error];
}

- (BOOL)copyReferencedFilesToDirectoryAtURL:(NSURL *)destinationURL error:(NSError **)error
{
    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSMutableArray<NSURL *> *destinationURLs = [NSMutableArray array];

    for (NSURL *fileURL in _allReferencedFileURLs) {
        NSURL *destinationFileURL = [destinationURL URLByAppendingPathComponent:fileURL.lastPathComponent];

        if ([fileManager copyItemAtURL:fileURL toURL:destinationFileURL error:error]) {
            [destinationURLs addObject:destinationFileURL];
            continue;
        }

        // Remove every file that was copied already.
        for (NSURL *fileURL in destinationURLs)
            [fileManager removeItemAtURL:fileURL error:nil];

        return NO;
    }
    
    return YES;
}

- (BOOL)_setUpFileReferencesWithError:(NSError **)error
{
    return NO;
}

- (nullable NSString *)_fileContentWithError:(NSError **)error
{
    NSString *fileContent = [NSString stringWithContentsOfURL:self.fileURL usedEncoding:0 error:error];
    if (fileContent != nil) {
        // {\rtf1 - Rich Text Format magic number
        if ([fileContent hasPrefix:@"{\\rtf1"]) {
            if (error) {
                *error = [NSError errorWithDomain:OEDiscDescriptorErrorDomain code:OEDiscDescriptorNotPlainTextFileError userInfo:@{
                    NSLocalizedDescriptionKey: NSLocalizedString(@"File cannot be read", @"Reading descriptor file error description"),
                    NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:NSLocalizedString(@"File %@ is not a plain text file.", @"Reading descriptor file error failure reason."), self.fileURL.lastPathComponent],
                }];
            }

            return nil;
        }

        return fileContent;
    }

    if (error == nil)
        return nil;

    // M3U file contains unreachable cue sheet file reference
    // self.fileURL sent to +[NSString stringWithContentsOfURL:usedEncoding:error] is unreachable
    if ([(*error).domain isEqualToString:NSCocoaErrorDomain] && (*error).code == NSFileReadNoSuchFileError) {
        *error = [NSError errorWithDomain:OEDiscDescriptorErrorDomain code:OEDiscDescriptorMissingFilesError userInfo:@{
            NSLocalizedDescriptionKey: NSLocalizedString(@"M3U missing referenced file", @"M3U missing referenced file error description"),
            NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:NSLocalizedString(@"M3U referencing unreachable file at path %@.", @"M3U missing referenced file error failure reason"), self.fileURL.path],
            NSUnderlyingErrorKey: *error,
        }];

        return nil;
    }

    // File cannot be read due to permission problem
    if ([(*error).domain isEqualToString:NSCocoaErrorDomain] && (*error).code == NSFileReadNoPermissionError) {
        *error = [NSError errorWithDomain:OEDiscDescriptorErrorDomain code:OEDiscDescriptorNoPermissionReadFileError userInfo:@{
            NSLocalizedDescriptionKey: NSLocalizedString(@"File cannot be read (permission problem)", @"Reading descriptor file error permission problem description"),
            NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:NSLocalizedString(@"Could not read file due to permission problem at path %@.", @"Missing referenced file error permission problem failure reason"), self.fileURL.path],
            NSUnderlyingErrorKey: *error,
        }];

        return nil;
    }

    *error = [NSError errorWithDomain:OEDiscDescriptorErrorDomain code:OEDiscDescriptorUnreadableFileError userInfo:@{
        NSLocalizedDescriptionKey: NSLocalizedString(@"File cannot be read", @"Reading descriptor file error description"),
        NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:NSLocalizedString(@"File %@ does not seem to be a plain text file.", @"Reading descriptor file error failure reason."), self.fileURL.lastPathComponent],
        NSUnderlyingErrorKey: *error,
    }];

    return nil;
}

- (BOOL)_validateFileURLs:(NSArray<NSURL *> *)fileURLs withError:(NSError **)error;
{
    for (NSURL *url in fileURLs) {
        if ([url checkResourceIsReachableAndReturnError:error])
            continue;

        if (error == nil)
            return NO;

        *error = [NSError errorWithDomain:OEDiscDescriptorErrorDomain code:OEDiscDescriptorMissingFilesError userInfo:@{
            NSLocalizedDescriptionKey: NSLocalizedString(@"Missing referenced file", @"Missing referenced file error description"),
            NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:NSLocalizedString(@"Could not read file at path %@. Make sure the file is at the indicated location and can be read.", @"Missing referenced file error failure reason"), url.path],
            NSUnderlyingErrorKey: *error,
        }];

        return NO;
    }

    return YES;
}

@end

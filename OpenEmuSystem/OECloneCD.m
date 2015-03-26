/*
 Copyright (c) 2015, OpenEmu Team

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

#import "OECloneCD.h"

@interface OECloneCD ()

@property NSURL *ccdFileURL;
@property NSURL *referencedFilesDirectoryURL;
@property NSArray  *referencedFiles;

- (void)OE_refreshReferencedFiles;

@end

@implementation OECloneCD
/**
 Returns an OECloneCD object initialized from the given file.
 @param path    absolute path to .ccd file
 @returns An initialized OECloneCD object for the given path. Returns nil if the ccd file does not exist or can't be read.
 */
- (id)initWithURL:(NSURL *)url
{
    if((self = [super init]))
    {
        NSString *file = [NSString stringWithContentsOfURL:url usedEncoding:0 error:nil];
        if(file == nil) return nil;

        [self setCcdFileURL:url];

        [self setReferencedFilesDirectoryURL:[url URLByDeletingLastPathComponent]];
        [self OE_refreshReferencedFiles];
    }
    return self;
}

/**
 Returns an OECloneCD object initialized from the given file. The ccd is expected to have additional img and sub files in the specified directory.
 @param path                absolute path to .ccd file
 @param referencedFiles     path to directory containing additional files
 @returns An initialized OECloneCD object for the given path. Returns nil if the ccd file does not exist or can't be read.
 */
- (id)initWithURL:(NSURL *)url andReferencedFilesDirectory:(NSURL *)referencedFiles
{
    if((self = [self initWithURL:url]))
    {
        [self setReferencedFilesDirectoryURL:referencedFiles];
        [self OE_refreshReferencedFiles];
    }
    return self;
}

#pragma mark - File Handling
/**
 Move files referenced by a ccd to a new directory
 @param newDirectory    absolute path to destination directory
 @param outError        On input, a pointer to an error object. If an error occurs, this pointer is set to an actual error object containing the error information. You may specify nil for this parameter if you do not want the error information.
 @returns YES if all files were moved successfully. Returns NO if an error occurred.
 */
- (BOOL)moveReferencedFilesToURL:(NSURL *)newDirectory withError:(NSError **)outError
{
    __block BOOL     success = YES;
    __block NSError *error   = nil;

    NSFileManager *fileManger      = [NSFileManager defaultManager];
    NSURL         *directory       = [self referencedFilesDirectoryURL];
    NSArray       *referencedFiles = [self referencedFiles];

    [referencedFiles enumerateObjectsUsingBlock:
     ^(id obj, NSUInteger idx, BOOL *stop)
     {
         NSURL *fullURL = [directory URLByAppendingPathComponent:obj];
         NSURL *newURL = [newDirectory URLByAppendingPathComponent:[fullURL lastPathComponent]];
         if(![fileManger moveItemAtURL:fullURL toURL:newURL error:&error])
         {
             *stop   = YES;
             success = NO;
         }
     }];

    if(outError != NULL)
        *outError = error;

    return success;
}

/**
 Copies all files referenced by a ccd to a new directory
 @param newDirectory    absolute path to destination directory
 @param outError        On input, a pointer to an error object. If an error occurs, this pointer is set to an actual error object containing the error information. You may specify nil for this parameter if you do not want the error information.
 @returns YES if all files were copied successfully. Returns NO if an error occurred.
 */
- (BOOL)copyReferencedFilesToURL:(NSURL *)newDirectory withError:(NSError **)outError
{
    __block BOOL     success = YES;
    __block NSError *error   = nil;

    NSFileManager *fileManger      = [NSFileManager defaultManager];
    NSURL         *directory       = [self referencedFilesDirectoryURL];
    NSArray       *referencedFiles = [self referencedFiles];

    [referencedFiles enumerateObjectsUsingBlock:
     ^(id obj, NSUInteger idx, BOOL *stop)
     {
         NSURL *fullURL = [directory URLByAppendingPathComponent:obj];
         NSURL *newURL = [newDirectory URLByAppendingPathComponent:[fullURL lastPathComponent]];

         if(![fileManger copyItemAtURL:fullURL toURL:newURL error:&error])
         {
             *stop   = YES;
             success = NO;
         }
     }];

    if(outError != NULL)
        *outError = error;

    return success;
}

/**
 Determine if img/sub files required by a ccd exist.
 @returns YES if all files exist.
 */
- (BOOL)allFilesAvailable
{
    __block BOOL   success         = YES;
    NSURL         *directory       = [self referencedFilesDirectoryURL];
    NSArray       *referencedFiles = [self referencedFiles];

    [referencedFiles enumerateObjectsUsingBlock:
     ^(id obj, NSUInteger idx, BOOL *stop)
     {
         NSURL *fullURL = [directory URLByAppendingPathComponent:obj];
         if(![fullURL checkResourceIsReachableAndReturnError:nil])
         {
             *stop   = YES;
             success = NO;
         }
     }];

    return success;
}

/**
 Get path to file containing the img file.
 @returns Path to img file or nil if no img file is found.
 */
- (NSString *)dataTrackPath
{
    return [self allFilesAvailable] ? [[self referencedFiles] objectAtIndex:0] : nil;
}

/**
 Get files referenced by the ccd.
 @returns Array containing NSString objects that specfiy the names of all referenced files.
 */
- (NSArray *)referencedFileNames
{
    NSArray *files = [self referencedFiles];
    NSMutableArray *names = [NSMutableArray arrayWithCapacity:[files count]];
    [files enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [names addObject:[obj lastPathComponent]];
    }];
    return names;
}

#pragma mark - Private Helpers

- (void)OE_refreshReferencedFiles
{
    NSString *imgFile = [[[[self ccdFileURL] lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"img"];
    NSString *subFile = [[[[self ccdFileURL] lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"sub"];
    NSArray *files = @[imgFile, subFile];

    [self setReferencedFiles:files];
}
@end

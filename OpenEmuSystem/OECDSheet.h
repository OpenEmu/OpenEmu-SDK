/*
 Copyright (c) 2016, OpenEmu Team

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

#import <Foundation/Foundation.h>
#import <OpenEmuSystem/OEFile.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const OECDSheetErrorDomain;

NS_ENUM(NSInteger) {
    OECDSheetUnreadableSheetError = -1,
    OECDSheetMissingFilesError = -2,
};

@interface OECDSheet : OEFile

/// URLs of the files directly referenced by the receiver.
@property (nonatomic, copy, readonly) NSArray<NSURL *> *referencedFileURLs;

/// URLs of the files referenced by the receiver including subsheets where applicable.
@property (nonatomic, copy, readonly) NSArray<NSURL *> *allReferencedFileURLs;

/// URLs of the all the binary files referenced by the receiver.
@property (nonatomic, copy, readonly) NSArray<NSURL *> *referencedBinaryFileURLs;

/// URL of the main data track file.
@property (nonatomic, copy, readonly) NSURL *dataTrackFileURL;

/// Move all the referenced files to the destinationURL directory.
- (BOOL)moveReferencedFilesToDirectoryAtURL:(NSURL *)destinationURL error:(NSError **)error;

/// Copy all the referenced files to the destinationURL directory.
- (BOOL)copyReferencedFilesToDirectoryAtURL:(NSURL *)destinationURL error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END

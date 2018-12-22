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

#import "OEDreamcastGDI.h"

#import "OEDiscDescriptor_Internal.h"

NSString *const OEDreamcastGDIErrorDomain = @"org.openemu.OEDreamcastGDI.ErrorDomain";

@implementation OEDreamcastGDI

- (BOOL)_setUpFileReferencesWithError:(NSError **)error
{
    NSString *fileContent = [self _fileContentWithError:error];
    if (fileContent == nil)
        return NO;

    // Handle both standard and Redump style GDI formats
    // Many ways to do this...
    // (?:(?:2352|2048|2336) "?)(.*\w)(?:"? \d)
    // ^(?:[ ]?\d+[ ]+\d+[ ]+\d+[ ]\d+[ ]"?)(.*\w)(?:"?[ ]\d)$
    // (?:\h*(?:\d+\h+){4})(("(.*)")|(.+))(?: \d)
    NSRegularExpression *fileNamePattern = [NSRegularExpression regularExpressionWithPattern:@"(?:\\h*(?:\\d+\\h+){4}\"?)(.*\\w)(?:\"? \\d)" options:0 error:nil];

    NSRange fullRange = NSMakeRange(0, fileContent.length);
    NSArray *matches = [fileNamePattern matchesInString:fileContent options:0 range:fullRange];
    NSString *trackCount = [fileContent componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet].firstObject;
    NSString *matchCount = [NSString stringWithFormat:@"%@", @(matches.count)];

    if (matches.count == 0) {
        if (error == nil)
            return NO;

        *error = [NSError errorWithDomain:OEDreamcastGDIErrorDomain code:OEDreamcastGDINoFileNameFoundError userInfo:@{
            NSLocalizedDescriptionKey: NSLocalizedString(@"GDI does not contain any tracks", @"Missing track file references in GDI error description"),
            NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:NSLocalizedString(@"The GDI %@ should contain file names referencing tracks but none could be found.", @"Missing track file references in GDI file error failure reason"), self.fileURL.lastPathComponent],
        }];

        return NO;
    }

    if (![trackCount isEqualToString:matchCount]) {
        if (error == nil)
            return NO;

        *error = [NSError errorWithDomain:OEDreamcastGDIErrorDomain code:OEDreamcastGDIInvalidFileCountError userInfo:@{
            NSLocalizedDescriptionKey: NSLocalizedString(@"Track count mismatch", @"Track count mismatch in GDI error description"),
            NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:NSLocalizedString(@"The track count (%@) and the track file references found (%@) in the GDI %@ do not match.", @"Track count mismatch in GDI file error failure reason"), trackCount, matchCount, self.fileURL.lastPathComponent],
        }];

        return NO;
    }

    NSURL *folderURL = self.fileURL.URLByDeletingLastPathComponent;
    NSMutableArray<NSURL *> *fileURLs = [NSMutableArray array];

    for (NSTextCheckingResult *match in matches) {
        NSString *fileNameMatch = [fileContent substringWithRange:[match rangeAtIndex:1]];

        [fileURLs addObject:[folderURL URLByAppendingPathComponent:fileNameMatch]];
    }

    self.dataTrackFileURL = fileURLs.firstObject;
    self.referencedBinaryFileURLs = self.allReferencedFileURLs = self.referencedFileURLs = fileURLs;

    return YES;
}

@end

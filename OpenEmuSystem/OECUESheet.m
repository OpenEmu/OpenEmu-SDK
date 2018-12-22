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

#import "OECUESheet.h"

#import "OEDiscDescriptor_Internal.h"

NSString *const OECUESheetErrorDomain = @"org.openemu.OECUESheet.ErrorDomain";

@implementation OECUESheet

- (BOOL)_setUpFileReferencesWithError:(NSError **)error
{
    NSString *fileContent = [self _fileContentWithError:error];
    if (fileContent == nil)
        return NO;

    NSRegularExpression *fileLinePattern = [NSRegularExpression regularExpressionWithPattern:@"^FILE .+$" options:NSRegularExpressionAnchorsMatchLines error:nil];
    NSRegularExpression *fileNamePattern = [NSRegularExpression regularExpressionWithPattern:@"(?<=FILE \")[^\"]*" options:0 error:nil];

    NSRange fullRange = NSMakeRange(0, fileContent.length);
    NSArray *matches = [fileLinePattern matchesInString:fileContent options:0 range:fullRange];

    if (matches.count == 0) {
        if (error == nil)
            return NO;

        *error = [NSError errorWithDomain:OECUESheetErrorDomain code:OECUESheetNoFileNameFoundError userInfo:@{
            NSLocalizedDescriptionKey: NSLocalizedString(@"CUE sheet does not contain any file name", @"Missing FILE reference in cue file error description"),
            NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:NSLocalizedString(@"The .cue sheet %@ should contain file names referencing CD segments but none could be found.", @"Missing FILE reference in cue file error failure reason"), self.fileURL.lastPathComponent],
        }];

        return NO;
    }

    NSURL *folderURL = self.fileURL.URLByDeletingLastPathComponent;
    NSMutableArray<NSURL *> *fileURLs = [NSMutableArray array];

    for (NSTextCheckingResult *match in matches) {
        NSString *FILEString = [fileContent substringWithRange:match.range];

        NSTextCheckingResult *fileNameMatch = [fileNamePattern firstMatchInString:FILEString options:0 range:NSMakeRange(0, match.range.length)];
        if (fileNameMatch.range.length != 0) {
            [fileURLs addObject:[folderURL URLByAppendingPathComponent:[FILEString substringWithRange:fileNameMatch.range]]];
            continue;
        }

        NSCharacterSet *brokenQuoteCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"'‘’“”„«»‹›<>"];
        NSRange brokenCharacterRange = [FILEString rangeOfCharacterFromSet:brokenQuoteCharacterSet];
        if (brokenCharacterRange.location != NSNotFound) {
            if (error == nil)
                return NO;

            *error = [NSError errorWithDomain:OECUESheetErrorDomain code:OECUESheetInvalidQuotationMarkError userInfo:@{
                NSLocalizedDescriptionKey: NSLocalizedString(@"CUE sheet contains an invalid quotation mark.", @"CUE sheet file quotation format error description"),
                NSLocalizedRecoverySuggestionErrorKey: [NSString stringWithFormat:NSLocalizedString(@"CUE sheet format requires \" quotation marks, but instead uses %@.", @"CUE sheet file quotation format error failure reason"), [fileContent substringWithRange:brokenCharacterRange]],
            }];

            return NO;
        }

        if ([FILEString rangeOfString:@"\""].length == 0) {
            if (error == nil)
                return NO;

            *error = [NSError errorWithDomain:OECUESheetErrorDomain code:OECUESheetInvalidFileFormatError userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedString(@"Invalid CUE sheet format", @"CUE sheet invalid file format error description"), self.fileURL.lastPathComponent],
                NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"CUE sheet format requires \" quotation marks around file names but none were found.", @"CUE sheet invalid file format error failure reason when double quotes are missing"),
            }];

            return NO;
        }

        if (fileNameMatch.range.length == 0) {
            if (error == nil)
                return NO;

            *error = [NSError errorWithDomain:OECUESheetErrorDomain code:OECUESheetInvalidFileFormatError userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedString(@"Invalid CUE sheet format", @"CUE sheet invalid file format error description"), self.fileURL.lastPathComponent],
                NSLocalizedRecoverySuggestionErrorKey: [NSString stringWithFormat:NSLocalizedString(@"The file %@ does not respect the CUE sheet format.", @"CUE sheet invalid file format error failure reason"), self.fileURL.lastPathComponent],
            }];

            return NO;
        }
    }

    self.dataTrackFileURL = fileURLs.firstObject;
    self.referencedBinaryFileURLs = self.allReferencedFileURLs = self.referencedFileURLs = fileURLs;

    return YES;
}

@end

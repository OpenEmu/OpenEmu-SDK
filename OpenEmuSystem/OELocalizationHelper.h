/*
 Copyright (c) 2011, OpenEmu Team
 
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

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, OERegion) {
    OERegionNA NS_SWIFT_NAME(na),
    OERegionJAP NS_SWIFT_NAME(jpn),
    OERegionEU NS_SWIFT_NAME(eu),
    OERegionOther
};

extern NSString *const OERegionKey;

@interface OELocalizationHelper : NSObject

@property(class, readonly) OELocalizationHelper *sharedHelper;

@property OERegion region;

@property(readonly) NSString *regionName;

@property(readonly) BOOL isRegionNA NS_SWIFT_UNAVAILABLE("Use 'region == .na' instead");
@property(readonly) BOOL isRegionEU NS_SWIFT_UNAVAILABLE("Use 'region == .eu' instead");
@property(readonly) BOOL isRegionJAP NS_SWIFT_UNAVAILABLE("Use 'region == .jpn' instead");

@end

NS_ASSUME_NONNULL_END

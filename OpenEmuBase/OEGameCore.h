/*
 Copyright (c) 2009, OpenEmu Team

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

#import <Cocoa/Cocoa.h>
#import "OEGameCoreController.h"
#import "OESystemResponderClient.h"
#import "OEGeometry.h"
#ifndef DLog

#ifdef DEBUG_PRINT
#define DLog(format, ...) NSLog(@"%@:%d: %s: " format, [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, __FUNCTION__, ##__VA_ARGS__)
#else
#define DLog(format, ...) do {} while(0)
#endif

#endif

#define GET_CURRENT_AND_RETURN(...) __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;
#define OE_EXPORTED_CLASS __attribute__((visibility("default")))

#pragma mark -

extern NSString *const OEGameCoreErrorDomain;

enum _OEGameCoreErrorCodes {
    OEGameCoreCouldNotStartCoreError = -1,
    OEGameCoreCouldNotLoadROMError = -2,
    OEGameCoreCouldNotLoadStateError = -3,
    OEGameCoreStateHasWrongSizeError = -4,
    OEGameCoreCouldNotSaveStateError = -5,
};

@protocol OERenderDelegate

@required
- (void)willExecute;
- (void)didExecute;

- (void)willRenderOnAlternateThread;
- (void)startRenderingOnAlternateThread;

- (void)willRenderFrameOnAlternateThread;
- (void)didRenderFrameOnAlternateThread;

- (void)setEnableVSync:(BOOL)flag;

@end

@protocol OEGameCoreDelegate <NSObject>
- (void)gameCoreDidFinishFrameRefreshThread:(OEGameCore *)gameCore;
@end

#pragma mark -

@protocol OEAudioDelegate

@required
- (void)audioSampleRateDidChange;

@end

@class OEHIDEvent, OERingBuffer;

#pragma mark -

@interface OEGameCore : NSResponder <OESystemResponderClient>
{
    void (^_stopEmulationHandler)(void);

    OERingBuffer __strong **ringBuffers;

    NSTimeInterval          frameInterval;
    NSTimeInterval          frameRateModifier;
    
    NSUInteger              frameSkip;
    NSUInteger              frameCounter;
    NSUInteger              tenFrameCounter;
    NSUInteger              autoFrameSkipLastTime;
    NSUInteger              frameskipadjust;

    BOOL                    willSkipFrame;
    BOOL                    isRunning;
    BOOL                    shouldStop;
    BOOL                    isFastForwarding;
    BOOL                    stepFrameForward;
}

@property(weak)     id<OEGameCoreDelegate> delegate;
@property(weak)     id<OERenderDelegate>   renderDelegate;
@property(weak)     id<OEAudioDelegate>    audioDelegate;

@property(weak)     OEGameCoreController *owner;
@property(readonly) NSString             *pluginName;

@property(readonly) NSString             *biosDirectoryPath;
@property(readonly) NSString             *supportDirectoryPath;
@property(readonly) NSString             *batterySavesDirectoryPath;

@property(readonly) NSTimeInterval        frameInterval;
@property(copy)     NSString             *systemIdentifier;

- (void)getAudioBuffer:(void *)buffer frameCount:(NSUInteger)frameCount bufferIndex:(NSUInteger)index;
- (OERingBuffer *)ringBufferAtIndex:(NSUInteger)index;

- (void)calculateFrameSkip:(NSUInteger)rate;
- (void)fastForward:(BOOL)flag;

#pragma mark - Execution

@property(getter=isEmulationPaused) BOOL pauseEmulation;

- (BOOL)rendersToOpenGL;
- (void)setupEmulation;
- (void)startEmulation;
- (void)stopEmulation;

- (void)stopEmulationWithCompletionHandler:(void(^)(void))completionHandler;
- (void)didStopEmulation;

- (void)runStartUpFrameWithCompletionHandler:(void(^)(void))handler;
- (void)frameRefreshThread:(id)anArgument;

// ============================================================================
// Abstract methods: Those methods should be overridden by subclasses
// ============================================================================
- (void)resetEmulation;
- (void)executeFrame;
- (void)executeFrameSkippingFrame:(BOOL) skip;

- (BOOL)loadFileAtPath:(NSString *)path DEPRECATED_ATTRIBUTE;
- (BOOL)loadFileAtPath:(NSString *)path error:(NSError **)error;

#pragma mark - Video

// The full size of the internal video buffer used by the core
// This is typically the largest size possible.
@property(readonly) OEIntSize   bufferSize;

// The size of the current portion of the buffer that is needs to be displayed as "active" to the user
// Note that this rect may not be the same aspect ratio as what the end user sees.
@property(readonly) OEIntRect   screenRect;

// The *USER INTERFACE* aspect of the actual final displayed video on screen.
@property(readonly) OEIntSize   aspectSize;

@property(readonly) const void *videoBuffer;
@property(readonly) GLenum      pixelFormat;
@property(readonly) GLenum      pixelType;
@property(readonly) GLenum      internalPixelFormat;

#pragma mark - Audio

@property(readonly) NSUInteger  audioBufferCount; // overriding it is optional, should be constant

// used when audioBufferCount == 1
@property(readonly) NSUInteger  channelCount;
@property(readonly) NSUInteger  audioBitDepth;
@property(readonly) double      audioSampleRate;

// used when more than 1 buffer
- (NSUInteger)channelCountForBuffer:(NSUInteger)buffer;
- (NSUInteger)audioBufferSizeForBuffer:(NSUInteger)buffer;
- (double)audioSampleRateForBuffer:(NSUInteger)buffer;

#pragma mark - Save state - Optional

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void(^)(BOOL success, NSError *error))block;
- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void(^)(BOOL success, NSError *error))block;

// Deprecated - Called by -saveStateToFileAtPath:completionHandler:.
- (BOOL)saveStateToFileAtPath:(NSString *)fileName;
// Deprecated - Called by -loadStateFromFileAtPath:completionHandler:.
- (BOOL)loadStateFromFileAtPath:(NSString *)fileName;

#pragma mark - Cheats - Optional

- (void)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled;

@end

#pragma mark - Optional

@interface OEGameCore (OptionalMethods)

- (IBAction)pauseEmulation:(id)sender;

- (NSTrackingAreaOptions)mouseTrackingOptions;

- (NSSize)outputSize;
- (void)setRandomByte;

@end

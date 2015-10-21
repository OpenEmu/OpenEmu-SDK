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
#import "OEDiffQueue.h"

#ifndef DLog

#ifdef DEBUG_PRINT
/*!
 * @function DLog
 * @abstract NSLogs when the source is built in Debug, otherwise does nothing.
 */
#define DLog(format, ...) NSLog(@"%@:%d: %s: " format, [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, __FUNCTION__, ##__VA_ARGS__)
#else
#define DLog(format, ...) do {} while(0)
#endif

#endif

/*!
 * @function GET_CURRENT_OR_RETURN
 * @abstract Fetch the current game core, or fail with given return code if there is none.
 */
#define GET_CURRENT_OR_RETURN(...) __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;

/*!
 * @macro OE_EXPORTED_CLASS
 * @abstract Define "Symbols Hidden By Default" on core projects and declare the core class with this
 * for the optimizations. Especially effective for dead code stripping and LTO.
 */
#define OE_EXPORTED_CLASS     __attribute__((visibility("default")))
#define OE_DEPRECATED(reason) __attribute__((deprecated(reason)))

#pragma mark -

extern NSString *const OEGameCoreErrorDomain;

typedef enum : NSInteger {
    OEGameCoreCouldNotStartCoreError = -1,
    OEGameCoreCouldNotLoadROMError   = -2,
    OEGameCoreCouldNotLoadStateError = -3,
    OEGameCoreStateHasWrongSizeError = -4,
    OEGameCoreCouldNotSaveStateError = -5,
} _OEGameCoreErrorCodes;

/*!
 * @enum OEGameCoreRendering
 * @abstract Which renderer will be set up for the game core.
 */
typedef enum : NSUInteger {
    OEGameCoreRendering2DVideo,         //!< The game bitmap will be put directly into an IOSurface.
    OEGameCoreRenderingOpenGL2Video,    //!< The core will be provided a CGL OpenGL 2.1 (Compatibility) context.
    OEGameCoreRenderingOpenGL3Video,    //!< The core will be provided a CGL OpenGL 3.2+ Core/OpenGLES3 context.
    OEGameCoreRenderingMetal1Video      //!< Not yet implemented.
} OEGameCoreRendering;

@protocol OERenderDelegate
@required

/*!
 * @method willExecute
 * @discussion
 * If the core implements its own event loop,
 * call before rendering a frame.
 */
- (void)willExecute;

/*!
 * @method willExecute
 * @discussion
 * If the core implements its own event loop,
 * call after rendering a frame.
 */
- (void)didExecute;

/*!
 * @method willRenderOnAlternateThread
 * @discussion
 * 2D -
 * Not used.
 * 3D -
 * Some cores may run their own video rendering in a different thread.
 * In that case, call this method inside startEmulation or executeFrame before it starts.
 */
- (void)willRenderOnAlternateThread OE_DEPRECATED("move to -hasAlternateRenderingThread on OEGameCore");

/*!
 * @method startRenderingOnAlternateThread
 * @discussion
 * 2D -
 * Not used.
 * 3D -
 * If rendering on an alternate thread, call this to prepare the renderer
 * when that thread starts up. This is only a performance improvement for
 * the first frame and is not necessary to call.
 */
- (void)startRenderingOnAlternateThread;

/*!
 * @method willRenderFrameOnAlternateThread
 * @discussion
 * 2D - Not used.
 * 3D -
 * If rendering video on a secondary thread, call this method before every frame rendered.
 */
- (void)willRenderFrameOnAlternateThread;

/*!
 * @method didRenderFrameOnAlternateThread
 * @discussion
 * 2D - Not used.
 * 3D -
 * If rendering video on a secondary thread, call this method after every frame rendered.
 */
- (void)didRenderFrameOnAlternateThread;

@property (nonatomic) BOOL enableVSync;
@property (nonatomic, readonly) BOOL hasAlternateThreadContext; // TODO: OE_DEPRECATED("move to -hasAlternateRenderingThread on OEGameCore")
@end

@protocol OEGameCoreDelegate <NSObject>
@required
/*!
 * @method willExecute
 * @discussion
 * If the core implements its own event loop,
 * call when the alternate rendering thread is exiting.
 */
- (void)gameCoreDidFinishFrameRefreshThread:(OEGameCore *)gameCore;
@end

#pragma mark -

@protocol OEAudioDelegate
@required
- (void)audioSampleRateDidChange;
@end

@class OEHIDEvent, OERingBuffer;

#pragma mark -

OE_EXPORTED_CLASS
@interface OEGameCore : NSResponder <OESystemResponderClient>
{
    BOOL                    isRunning OE_DEPRECATED("check -rate instead"); //used
}

// TODO: Move all ivars/properties that don't need overriding to a category?
@property(weak)     id<OEGameCoreDelegate> delegate;
@property(weak)     id<OERenderDelegate>   renderDelegate;
@property(weak)     id<OEAudioDelegate>    audioDelegate;

@property(nonatomic, weak)     OEGameCoreController *owner;
@property(nonatomic, readonly) NSString             *pluginName;

@property(nonatomic, readonly) NSString             *biosDirectoryPath;
@property(nonatomic, readonly) NSString             *supportDirectoryPath;
@property(nonatomic, readonly) NSString             *batterySavesDirectoryPath;

@property(nonatomic, readonly) BOOL                  supportsRewinding;
@property(nonatomic, readonly) NSUInteger            rewindInterval;
@property(nonatomic, readonly) NSUInteger            rewindBufferSeconds;
@property(nonatomic, readonly) OEDiffQueue          *rewindQueue;

@property(nonatomic, copy)     NSString             *systemIdentifier;
@property(nonatomic, copy)     NSString             *systemRegion;
@property(nonatomic, copy)     NSString             *ROMCRC32;
@property(nonatomic, copy)     NSString             *ROMMD5;
@property(nonatomic, copy)     NSString             *ROMHeader;
@property(nonatomic, copy)     NSString             *ROMSerial;

#pragma mark - Starting

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError **)error;

- (void)setupEmulation;

#pragma mark - Stopping

- (void)stopEmulation;
- (void)didStopEmulation;

#pragma mark - Execution

/*!
 * @property frameInterval
 * @abstract The ideal time between -executeFrame calls when rate=1.0.
 * This property is only read at the start and cannot be changed.
 */
@property (nonatomic, readonly) NSTimeInterval        frameInterval;

/*!
 * @property rate
 * @discussion
 * The rate the game is currently running at. Generally 1.0.
 * If 0, the core is paused.
 * If >1.0, the core is fast-forwarding and -executeFrame will be called more often.
 * Values <1.0 are not expected.
 *
 * There is no need to check this property if your core does all work inside -executeFrame.
 */
@property (nonatomic, assign) float rate;

/*!
 * @method executeFrame
 * @discussion
 * Called every 1/(rate*frameInterval) seconds by -frameRefreshThread.
 * The core should produce 1 frameInterval worth of audio and can output 1 frame of video.
 * If the game core option OEGameCoreOptionCanSkipFrames is set, the property shouldSkipFrame may be YES.
 * In this case the core can read from videoBuffer but must not write to it. All work done to render video can be skipped.
 */
- (void)executeFrame;

/*!
 * @method resetEmulation
 * @abstract Presses the reset button on the console.
 */
- (void)resetEmulation;

#pragma mark - Video

/*!
 * @method getVideoBufferWithHint:
 * @param hint If possible, use 'hint' as the video buffer for this frame.
 * @discussion
 * Called before each -executeFrame call. The method should return 
 * a video buffer containing 'bufferSize' packed pixels, and -executeFrame
 * should draw into this buffer. If 'hint' is set, using that as the video
 * buffer may be faster. Besides that, returning the same buffer each time
 * may be faster.
 */
- (const void *)getVideoBufferWithHint:(void *)hint;

/*!
 * @method tryToResizeVideoTo:
 * @discussion
 * If the core can natively draw at any resolution, change the resolution
 * to 'size' and return YES. Otherwise, return NO. If YES, the next call to
 * -executeFrame will have a newly sized framebuffer.
 * It is assumed that only 3D cores can do this.
 */
- (BOOL)tryToResizeVideoTo:(OEIntSize)size;

/*!
 * @property gameCoreRendering
 * @discussion
 * What kind of 3D API the core requires, or none.
 * Defaults to 2D.
 */
@property (nonatomic, readonly) OEGameCoreRendering gameCoreRendering;

/*!
 * @property hasAlternateRenderingThread
 * @abstract If the core starts another thread to do 3D operations on.
 */
@property (nonatomic, readonly) BOOL hasAlternateRenderingThread;

/*!
 * @property bufferSize
 * @discussion
 * 2D -
 * The size in pixels to allocate the framebuffer at.
 * Cores should output at their largest native size, including overdraw, without aspect ratio correction.
 * 3D -
 * The initial size to allocate the framebuffer at.
 * The user may decide to resize it later, but OE will try to request new sizes at the same aspect ratio as bufferSize.
 */
@property(readonly) OEIntSize   bufferSize;

/*!
 * @property screenRect
 * @discussion
 * The rect inside the framebuffer showing the currently displayed picture, not including overdraw, but
 * without aspect ratio correction.
 * Aspect ratio correction is not used for 3D.
 */
@property(readonly) OEIntRect   screenRect;

/*!
 * @property aspectSize
 * @discussion
 * The size at the display aspect ratio (DAR) of the picture.
 * The actual pixel values are not used; only the ratio is used.
 * Aspect ratio correction is not used for 3D.
 */
@property(readonly) OEIntSize   aspectSize;

/*!
 * @property internalPixelFormat
 * @discussion
 * The 'internalPixelFormat' parameter to glTexImage2D, used to create the framebuffer.
 * Defaults to GL_RGB.
 * Ignored for 3D cores.
 */
@property(readonly) GLenum internalPixelFormat;

/*!
 * @property pixelFormat
 * @discussion
 * The 'type' parameter to glTexImage2D, used to create the framebuffer.
 * GL_BGRA is preferred, but avoid doing any conversions inside the core.
 * Ignored for 3D cores.
 */
@property(readonly) GLenum      pixelType;

/*!
 * @property pixelFormat
 * @discussion
 * The 'format' parameter to glTexImage2D, used to create the framebuffer.
 * GL_UNSIGNED_SHORT_1_5_5_5_REV or GL_UNSIGNED_INT_8_8_8_8_REV are preferred, but
 * avoid doing any conversions inside the core.
 * Ignored for 3D cores.
 */
@property(readonly) GLenum      pixelFormat;

/*!
 * @property shouldSkipFrame
 * @abstract See -executeFrame.
 */
@property(assign) BOOL shouldSkipFrame;

#pragma mark - Audio

// TODO: Should this return void? What does it do?
- (void)getAudioBuffer:(void *)buffer frameCount:(NSUInteger)frameCount bufferIndex:(NSUInteger)index;
- (OERingBuffer *)ringBufferAtIndex:(NSUInteger)index;

/*!
 * @property audioBufferCount
 * @discussion
 * Defaults to 1. Return a value other than 1 if the core can export
 * multiple audio tracks. There is currently not much need for this.
 */
@property(readonly) NSUInteger  audioBufferCount;

// Used when audioBufferCount == 1
@property(readonly) NSUInteger  channelCount;
@property(readonly) NSUInteger  audioBitDepth;
@property(readonly) double      audioSampleRate;

// Used when audioBufferCount > 1
- (NSUInteger)channelCountForBuffer:(NSUInteger)buffer;
- (NSUInteger)audioBufferSizeForBuffer:(NSUInteger)buffer;
- (double)audioSampleRateForBuffer:(NSUInteger)buffer;

@end

#pragma mark - Optional

@interface OEGameCore (OptionalMethods)

- (IBAction)pauseEmulation:(id)sender;

- (NSTrackingAreaOptions)mouseTrackingOptions;

- (NSSize)outputSize;
- (void)setRandomByte;

#pragma mark - Save state - Optional

- (NSData *)serializeStateWithError:(NSError **)outError;
- (BOOL)deserializeState:(NSData *)state withError:(NSError **)outError;

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void(^)(BOOL success, NSError *error))block;
- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void(^)(BOOL success, NSError *error))block;

#pragma mark - Cheats - Optional

- (void)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled;

#pragma mark - Discs - Optional

@property(readonly) NSUInteger discCount;
- (void)setDisc:(NSUInteger)discNumber;

@end

#pragma mark - Internal

// There should be no need to override these methods.
@interface OEGameCore (Internal)
/*!
 * @method frameRefreshThread:
 * @discussion
 * Cores may implement this if they wish to control their entire event loop.
 * This is not recommended.
 */
- (void)frameRefreshThread:(id)anArgument;

- (void)startEmulation;
- (void)runStartUpFrameWithCompletionHandler:(void(^)(void))handler;

- (void)stopEmulationWithCompletionHandler:(void(^)(void))completionHandler;
@end


#pragma mark - Deprecated

// These methods will be removed after some time.
@interface OEGameCore (Deprecated)

// Deprecated - Called by -saveStateToFileAtPath:completionHandler:.
- (BOOL)saveStateToFileAtPath:(NSString *)fileName OE_DEPRECATED("use the version with completionHandler:");
// Deprecated - Called by -loadStateFromFileAtPath:completionHandler:.
- (BOOL)loadStateFromFileAtPath:(NSString *)fileName OE_DEPRECATED("use the version with completionHandler:");

- (BOOL)loadFileAtPath:(NSString *)path DEPRECATED_ATTRIBUTE;

@property(getter=isEmulationPaused) BOOL pauseEmulation OE_DEPRECATED("use -rate");
- (void)executeFrameSkippingFrame:(BOOL)skip OE_DEPRECATED("check -shouldSkipFrame");

- (void)fastForward:(BOOL)flag OE_DEPRECATED("use -rate");
- (void)rewind:(BOOL)fla OE_DEPRECATED("use -rate");

- (BOOL)rendersToOpenGL OE_DEPRECATED("use -gameCoreRendering");
@property(readonly) const void *videoBuffer OE_DEPRECATED("use -getVideoBufferWithHint:");

@end

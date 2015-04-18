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

#import <Cocoa/Cocoa.h>
#import <OpenEmuBase/OEGameCore.h>
#import <OpenEmuSystem/OEBindingMap.h>
#import <OpenEmuSystem/OEKeyBindingDescription.h>
#import <OpenEmuSystem/OESystemBindings.h>

@class    OEEvent;
@class    OESystemController;
@protocol OESystemResponderClient;
@protocol OEGlobalEventsHandler;

@interface OESystemResponder : NSResponder <OESystemBindingsObserver>

// Designated initializer
- (id)initWithController:(OESystemController *)controller;

@property(strong, readonly) OESystemController *controller;
@property(weak, nonatomic) id<OESystemResponderClient> client;
@property(weak, nonatomic) id<OEGlobalEventsHandler> globalEventsHandler;

- (void)handleMouseEvent:(OEEvent *)event;

@property(nonatomic, strong) OEBindingMap *keyMap;

- (OESystemKey *)emulatorKeyForKey:(OEKeyBindingDescription *)aKey player:(NSUInteger)thePlayer;

- (void)pressEmulatorKey:(OESystemKey *)aKey;
- (void)releaseEmulatorKey:(OESystemKey *)aKey;
- (void)mouseDownAtPoint:(OEIntPoint)aPoint;
- (void)mouseUpAtPoint;
- (void)rightMouseDownAtPoint:(OEIntPoint)aPoint;
- (void)rightMouseUpAtPoint;
- (void)mouseMovedAtPoint:(OEIntPoint)aPoint;
- (void)changeAnalogEmulatorKey:(OESystemKey *)aKey value:(CGFloat)value;

- (void)pressGlobalButtonWithIdentifier:(OEGlobalButtonIdentifier)identifier;
- (void)releaseGlobalButtonWithIdentifier:(OEGlobalButtonIdentifier)identifier;
- (void)changeAnalogGlobalButtonIdentifier:(OEGlobalButtonIdentifier)identifier value:(CGFloat)value;

@end

// Methods that subclasses must override
@interface OESystemResponder (OEGameSystemResponderSubclass)
+ (Protocol *)gameSystemResponderClientProtocol;
@end

@protocol OEGlobalEventsHandler <NSObject>
- (void)saveState:(id)sender;
- (void)loadState:(id)sender;
- (void)quickSave:(id)sender;
- (void)quickLoad:(id)sender;
- (void)toggleFullScreen:(id)sender;
- (void)toggleAudioMute:(id)sender;
- (void)volumeDown:(id)sender;
- (void)volumeUp:(id)sender;
- (void)stopEmulation:(id)sender;
- (void)resetEmulation:(id)sender;
- (void)toggleEmulationPaused:(id)sender;
- (void)takeScreenshot:(id)sender;
@end

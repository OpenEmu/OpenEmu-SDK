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

#import <IOKit/hid/IOHIDLib.h>
#import <IOKit/hid/IOHIDUsageTables.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, OEDeviceAccessType)
{
    /*! User has granted permission to monitor keyboard device */
    OEDeviceAccessTypeGranted,
    
    /*! User has denied permission to monitor keyboard device */
    OEDeviceAccessTypeDenied,
    
    /*! User has not been asked permission to monitor keyboard device */
    OEDeviceAccessTypeUnknown,
};

@class OEHIDEvent;
@class OEDeviceHandler;

extern NSString *const OEWiimoteSupportEnabled;

extern NSNotificationName const OEDeviceManagerDidAddDeviceHandlerNotification;
extern NSNotificationName const OEDeviceManagerDidRemoveDeviceHandlerNotification;

extern NSNotificationName const OEDeviceManagerDidAddGlobalEventMonitorHandlerNotification;
extern NSNotificationName const OEDeviceManagerDidRemoveGlobalEventMonitorHandlerNotification;

extern NSString *const OEDeviceManagerDeviceHandlerUserInfoKey;

@interface OEDeviceManager : NSObject

@property(class, readonly) OEDeviceManager *sharedDeviceManager;

@property(readonly) NSArray<OEDeviceHandler *> *deviceHandlers;
@property(readonly) NSArray<OEDeviceHandler *> *controllerDeviceHandlers;
@property(readonly) NSArray<OEDeviceHandler *> *keyboardDeviceHandlers;
@property(readonly) OEDeviceAccessType          accessType API_AVAILABLE(macosx(10.15));

- (void)startWiimoteSearch;
- (void)stopWiimoteSearch;
- (BOOL)isBluetoothEnabled;

- (BOOL)requestAccess API_AVAILABLE(macosx(10.15));

// If the device has not yet been retrieved, this method will return an OEDeviceHandlerPlaceholder that must be resolved manually.
- (OEDeviceHandler *)deviceHandlerForUniqueIdentifier:(NSString *)uniqueIdentifier;

- (void)deviceHandler:(nullable OEDeviceHandler *)handler didReceiveEvent:(OEHIDEvent *)event;

@property (readonly, nonatomic) BOOL hasEventMonitor;

- (id)addGlobalEventMonitorHandler:(BOOL(^)(OEDeviceHandler *handler, OEHIDEvent *event))handler;
- (id)addEventMonitorForDeviceHandler:(OEDeviceHandler *)device handler:(void(^)(OEDeviceHandler *handler, OEHIDEvent *event))handler;
- (id)addUnhandledEventMonitorHandler:(void(^)(OEDeviceHandler *handler, OEHIDEvent *event))handler;
- (void)removeMonitor:(id)monitor;

@end

NS_ASSUME_NONNULL_END

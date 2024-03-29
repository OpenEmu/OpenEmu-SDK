/*
 Copyright (c) 2013, OpenEmu Team
 
 
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
#import <Carbon/Carbon.h>
#import <ForceFeedback/ForceFeedback.h>
#import <IOKit/hid/IOHIDLib.h>
#import <IOKit/hid/IOHIDUsageTables.h>

#import <OpenEmuSystem/NSResponder+OEHIDAdditions.h>
#import <OpenEmuSystem/OEBindingMap.h>
#import <OpenEmuSystem/OEBindingsController.h>
#import <OpenEmuSystem/OEDiscDescriptor.h>
#import <OpenEmuSystem/OECUESheet.h>
#import <OpenEmuSystem/OECloneCD.h>
#import <OpenEmuSystem/OEControlDescription.h>
#import <OpenEmuSystem/OEControllerDescription.h>
#import <OpenEmuSystem/OEDeviceDescription.h>
#import <OpenEmuSystem/OEDeviceHandler.h>
#import <OpenEmuSystem/OEDeviceManager.h>
#import <OpenEmuSystem/OEDreamcastGDI.h>
#import <OpenEmuSystem/OEEvent.h>
#import <OpenEmuSystem/OEFile.h>
#import <OpenEmuSystem/OEHIDEvent.h>
#import <OpenEmuSystem/OEKeyBindingDescription.h>
#import <OpenEmuSystem/OEKeyBindingGroupDescription.h>
#import <OpenEmuSystem/OEPlayerBindings.h>
#import <OpenEmuSystem/OESystemBindings.h>
#import <OpenEmuSystem/OESystemController.h>
#import <OpenEmuSystem/OESystemResponder.h>

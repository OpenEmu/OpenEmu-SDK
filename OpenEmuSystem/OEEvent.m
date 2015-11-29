/*
 Copyright (c) 2012, OpenEmu Team

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

#import "OEEvent.h"
#import <QuartzCore/QuartzCore.h>

static NSString *const OEEventLocationXKey = @"OEEventLocationX";
static NSString *const OEEventLocationYKey = @"OEEventLocationY";
static NSString *const OEEventRealEventDataKey = @"OEEventRealEventData";

@implementation OEEvent
{
    NSEvent    *_realEvent;
    OEIntPoint  _location;
}

+ (instancetype)eventWithMouseEvent:(NSEvent *)anEvent withLocationInGameView:(OEIntPoint)aLocation;
{
    return [[self alloc] initWithMouseEvent:anEvent withLocationInGameView:aLocation];
}

- (id)init
{
    return nil;
}

- (instancetype)initWithMouseEvent:(NSEvent *)anEvent withLocationInGameView:(OEIntPoint)aLocation;
{
    if((self = [super init]))
    {
        _realEvent = anEvent;
        _location  = aLocation;
    }

    return self;
}

- (OEIntPoint)locationInGameView;
{
    return _location;
}

- (id)forwardingTargetForSelector:(SEL)aSelector
{
    return [_realEvent respondsToSelector:aSelector] ? _realEvent : nil;
}

- (NSEventType)type
{
    return [_realEvent type];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (!(self = [super init]))
        return nil;

    _location.x = [aDecoder decodeIntForKey:OEEventLocationXKey];
    _location.y = [aDecoder decodeIntForKey:OEEventLocationYKey];

    CGEventRef realCGEvent = CGEventCreateFromData(NULL, (__bridge CFDataRef)[aDecoder decodeObjectOfClass:[NSData class] forKey:OEEventRealEventDataKey]);
    _realEvent = [NSEvent eventWithCGEvent:realCGEvent];
    CFRelease(realCGEvent);

    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt:_location.x forKey:OEEventLocationXKey];
    [aCoder encodeInt:_location.y forKey:OEEventLocationYKey];
    [aCoder encodeObject:(__bridge_transfer NSData *)CGEventCreateData(NULL, _realEvent.CGEvent) forKey:OEEventRealEventDataKey];
}

@end

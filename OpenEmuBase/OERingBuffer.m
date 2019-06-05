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

#import "OERingBuffer.h"
#import "TPCircularBuffer.h"
#import <os/lock.h>

@implementation OERingBuffer
{
    TPCircularBuffer buffer;
    os_unfair_lock fifoLock;
    atomic_uint bytesWritten;
#ifdef DEBUG
    BOOL suppressRepeatedLog;
#endif
}

- (id)init
{
    return [self initWithLength:1];
}

- (id)initWithLength:(NSUInteger)length
{
    if((self = [super init]))
    {
        TPCircularBufferInit(&buffer, (int)length);
        fifoLock = OS_UNFAIR_LOCK_INIT;
        _discardPolicy = OERingBufferDiscardPolicyNewest;
    }
    return self;
}

- (void)dealloc
{
    TPCircularBufferCleanup(&buffer);
}

- (NSUInteger)length
{
    return buffer.length;
}

- (void)setLength:(NSUInteger)length
{
    TPCircularBufferCleanup(&buffer);
    TPCircularBufferInit(&buffer, (int)length);
}

- (NSUInteger)write:(const void *)inBuffer maxLength:(NSUInteger)length
{
    NSUInteger res;

    atomic_fetch_add(&bytesWritten, length);
    
    res = TPCircularBufferProduceBytes(&buffer, inBuffer, (int)length);
    if (!res) {
        #ifdef DEBUG
        NSLog(@"OERingBuffer: Tried to write %lu bytes, but only %d bytes free", length, buffer.length - buffer.fillCount);
        #endif
    }
    
    if (!res && _discardPolicy == OERingBufferDiscardPolicyOldest) {
        os_unfair_lock_lock(&fifoLock);

        if (length > buffer.length) {
            NSUInteger discard = length - buffer.length;
            #ifdef DEBUG
            NSLog(@"OERingBuffer: discarding %lu bytes because buffer is too small", discard);
            #endif
            length = buffer.length;
            inBuffer += discard;
        }
        
        NSInteger overflow = MAX(0, (buffer.fillCount + length) - buffer.length);
        if (overflow > 0)
            TPCircularBufferConsume(&buffer, overflow);
        res = TPCircularBufferProduceBytes(&buffer, inBuffer, (int)length);
        
        os_unfair_lock_unlock(&fifoLock);
    }

    return res;
}

- (NSUInteger)read:(void *)outBuffer maxLength:(NSUInteger)len
{
    uint32_t availableBytes = 0;
    OERingBufferDiscardPolicy discardPolicy = _discardPolicy;
    if (discardPolicy == OERingBufferDiscardPolicyOldest)
        os_unfair_lock_lock(&fifoLock);
    
    void *head = TPCircularBufferTail(&buffer, &availableBytes);

    if (_anticipatesUnderflow) {
        if (availableBytes < 2*len) {
            #ifdef DEBUG
            if (!suppressRepeatedLog) {
                NSLog(@"OERingBuffer: available bytes %d <= requested %lu bytes * 2; not returning any byte", availableBytes, len);
                suppressRepeatedLog = YES;
            }
            #endif
            availableBytes = 0;
        } else {
            #ifdef DEBUG
            suppressRepeatedLog = NO;
            #endif
        }
    } else if (availableBytes < len) {
        #ifdef DEBUG
        if (!suppressRepeatedLog) {
            NSLog(@"OERingBuffer: Tried to consume %lu bytes, but only %d available; will not be logged again until next underflow", len, availableBytes);
            suppressRepeatedLog = YES;
        }
        #endif
    } else {
        #ifdef DEBUG
        suppressRepeatedLog = NO;
        #endif
    }

    availableBytes = MIN(availableBytes, (int)len);
    memcpy(outBuffer, head, availableBytes);
    TPCircularBufferConsume(&buffer, availableBytes);
    
    if (discardPolicy == OERingBufferDiscardPolicyOldest)
        os_unfair_lock_unlock(&fifoLock);
    return availableBytes;
}

- (NSUInteger)availableBytes
{
    return buffer.fillCount;
}

- (NSUInteger)bytesWritten
{
    return atomic_load(&bytesWritten);
}

- (NSUInteger)freeBytes
{
    return buffer.length - buffer.fillCount;
}

- (NSUInteger)usedBytes
{
    return buffer.length - buffer.fillCount;
}

@end

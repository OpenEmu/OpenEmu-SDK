/*
 Copyright (c) 2015, OpenEmu Team
 
 
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

#include <vector>
#include <deque>
#import "OEDiffQueue.h"

struct OEDiffData
{
    unsigned long offset;
    char diff;
};

struct OEPatch
{
    std::vector<OEDiffData> diffs;
    size_t length;
};

@implementation OEDiffQueue
{
    char *_currentBytes;
    size_t _currentLength;
    std::deque<std::unique_ptr<OEPatch> > _patches;
    NSUInteger _capacity;
}

- (id)init
{
    return [self initWithCapacity:NSUIntegerMax];
}

- (id)initWithCapacity:(NSUInteger)capacity
{
    if((self = [super init]))
    {
        _currentBytes = NULL;
        _currentLength = 0;
        _capacity = MAX(capacity, 2);
        // Note: A capacity <2 crashes in [OEDiffQueue push:]
    }
    return self;
}

- (void)dealloc
{
    free(_currentBytes);
}

- (void)push:(NSData *)aData
{
    char const *nextBytes = (char const *)[aData bytes];
    size_t nextLength = [aData length];
    
    if(_currentBytes)
    {
        OEPatch *nextPatch = new OEPatch();
        nextPatch->length = _currentLength;
        
        // `realloc(ptr, 0)` is undefined in C99/C11/C++11, and
        // may return NULL, or free the memory of `ptr`
        size_t nextSize = MAX(nextLength, 1);
        _currentBytes = (char *)realloc(_currentBytes, nextSize);
        
        for(NSUInteger offset = 0; offset < nextLength; ++offset)
        {
            char currentPoint = 0;
            if(offset < _currentLength)
            {
                currentPoint = _currentBytes[offset];
            }
            
            char nextPoint = nextBytes[offset];
            char diffPoint = currentPoint ^ nextPoint;
            
            if(diffPoint)
            {
                OEDiffData diff = (OEDiffData){
                    offset, diffPoint
                };
                nextPatch->diffs.push_back(diff);
            }
            
            _currentBytes[offset] = nextPoint;
        }
        
        _currentLength = nextLength;
        
        if([self count] >= _capacity)
        {
            NSUInteger discrepancy = [self count] - _capacity + 1;
            _patches.erase(_patches.begin(), _patches.begin() + discrepancy);
        }
        _patches.push_back(std::unique_ptr<OEPatch>(nextPatch));
    }
    else
    {
        _currentLength = nextLength;
        _currentBytes = (char *)malloc(_currentLength);
        memcpy((void *)_currentBytes, (void *)nextBytes, _currentLength);
    }
}

- (NSData *)pop
{
    if([self isEmpty])
    {
        return nil;
    }
    
    NSData *popData = [NSData dataWithBytes:_currentBytes length:_currentLength];
    
    if(_patches.empty())
    {
        free(_currentBytes);
        _currentBytes = NULL;
        _currentLength = 0;
    }
    else
    {
        OEPatch *patch = _patches.back().get();
        _currentBytes = (char *)realloc(_currentBytes, patch->length);
        _currentLength = patch->length;
        
        for(auto itr = patch->diffs.begin(); itr < patch->diffs.end(); ++itr)
        {
            OEDiffData diff = *itr;
            
            if(diff.offset < _currentLength)
            {
                _currentBytes[diff.offset] ^= diff.diff;
            }
        }
        
        _patches.pop_back();
    }
    
    return popData;
}

- (NSUInteger)count
{
    if ([self isEmpty])
    {
        return 0;
    }
    
    return 1 + _patches.size();
}

- (BOOL)isEmpty
{
    return _currentBytes == NULL;
}

@end

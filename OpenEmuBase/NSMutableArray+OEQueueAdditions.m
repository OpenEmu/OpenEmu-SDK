//
//  NSMutableArray+OEQueueAdditions.m
//  OpenEmu-SDK
//
//  Created by Remy Demarest on 28/07/2016.
//
//

#import "NSMutableArray+OEQueueAdditions.h"

@implementation NSMutableArray (OEQueueAdditions)

- (void)pushObject:(id)object
{
    [self addObject:object];
}

- (id)popObject
{
    id ret = self.firstObject;
    if (ret != nil)
        [self removeObjectAtIndex:0];

    return ret;
}

@end

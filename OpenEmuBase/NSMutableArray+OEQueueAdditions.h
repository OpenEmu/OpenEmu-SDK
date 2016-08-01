//
//  NSMutableArray+OEQueueAdditions.h
//  OpenEmu-SDK
//
//  Created by Remy Demarest on 28/07/2016.
//
//

#import <Foundation/Foundation.h>

@interface NSMutableArray<ObjectType> (OEQueueAdditions)

- (void)pushObject:(ObjectType)object;
- (ObjectType)popObject;

@end

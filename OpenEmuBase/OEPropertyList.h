//
//  OEPropertyList.h
//  OpenEmu-SDK
//
//  Created by Remy Demarest on 22/12/2015.
//
//

@protocol OEPropertyList
@end

@interface NSArray (OEPropertyList) <OEPropertyList>
@end

@interface NSData (OEPropertyList) <OEPropertyList>
@end

@interface NSDate (OEPropertyList) <OEPropertyList>
@end

@interface NSDictionary (OEPropertyList) <OEPropertyList>
@end

@interface NSNumber (OEPropertyList) <OEPropertyList>
@end

@interface NSString (OEPropertyList) <OEPropertyList>
@end

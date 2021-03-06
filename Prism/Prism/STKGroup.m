//
//  STKGroup.m
//  Prizm
//
//  Created by Jonathan Boone on 4/14/15.
//  Copyright (c) 2015 Higher Altitude. All rights reserved.
//

#import "STKGroup.h"
#import "STKOrganization.h"


@implementation STKGroup

@dynamic uniqueID;
@dynamic name;
@dynamic groupDescription;
@dynamic organization;
@dynamic members;
@dynamic messages;
@dynamic leader;
@dynamic status;
@dynamic mutes;
@dynamic unreadCount;

- (NSError *)readFromJSONObject:(id)jsonObject
{
    if([jsonObject isKindOfClass:[NSString class]]) {
        [self setUniqueID:jsonObject];
        return nil;
    }
    
    [self bindFromDictionary:jsonObject keyMap:[[self class] remoteToLocalKeyMap]];
    
    return nil;
}

+ (NSDictionary *)remoteToLocalKeyMap
{
    return @{
             @"_id": @"uniqueID",
             @"name": @"name",
             @"description": @"groupDescription",
             @"organization": [STKBind bindMapForKey:@"organization" matchMap:@{@"uniqueID": @"_id"}],
             @"leader": [STKBind bindMapForKey:@"leader" matchMap:@{@"uniqueID": @"_id"}],
             @"status": @"status",
             @"mutes": [STKBind bindMapForKey:@"mutes" matchMap:@{@"uniqueID": @"_id"}],
             @"unread_count": @"unreadCount"
             };
}

@end

//
//  STKPostComment.m
//  Prism
//
//  Created by Joe Conway on 2/28/14.
//  Copyright (c) 2014 Higher Altitude. All rights reserved.
//

#import "STKPostComment.h"
#import "STKUser.h"
#import "STKUserStore.h"

@implementation STKPostComment
@dynamic uniqueID, text, date, likeCount, likes, post, creator;
- (NSError *)readFromJSONObject:(id)jsonObject
{
    static NSDateFormatter *df = nil;
    if(!df) {
        df = [[NSDateFormatter alloc] init];
        [df setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
        [df setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    }

    [self bindFromDictionary:jsonObject keyMap:@{
        @"_id" : @"uniqueID",
        @"creator" : @{@"key" : @"creator", @"match" : @{@"uniqueID" : @"_id"}},
        @"text" : @"text",
        @"create_date" : ^(NSString *inValue) {
            [self setDate:[df dateFromString:inValue]];
        },
        // post
        @"likes_count" : @"likeCount",
        @"likes" : @{@"key" : @"likes", @"match" : @{@"uniqueID" : @"_id"}},
    }];
    return nil;
}

- (BOOL)isLikedByUser:(STKUser *)u
{
    return [[self likes] member:u] != nil;
}

@end

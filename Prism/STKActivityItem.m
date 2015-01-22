//
//  STKActivity.m
//  Prism
//
//  Created by Joe Conway on 4/8/14.
//  Copyright (c) 2014 Higher Altitude. All rights reserved.
//

#import "STKActivityItem.h"
#import "STKUser.h"


NSString * const STKActivityItemTypePost = @"post";
NSString * const STKActivityItemTypeFollow = @"follow";
NSString * const STKActivityItemTypeUnfollow = @"unfollow";
NSString * const STKActivityItemTypeLike = @"like";
NSString * const STKActivityItemTypeUnlike = @"unlike";
NSString * const STKActivityItemTypeComment = @"comment";
NSString * const STKActivityItemTypeTrustAccepted = @"trust_accepted";
NSString * const STKActivityItemTypeRepost = @"repost";
NSString * const STKActivityItemTypeTag = @"tag";
NSString * const STKActivityItemTypeAccolade = @"accolade";
NSString * const STKActivityItemTypeGroupJoined = @"group_joined";


@implementation STKActivityItem

@dynamic uniqueID;
@dynamic action;
@dynamic dateCreated;
@dynamic hasBeenViewed;
@dynamic post, comment;
@dynamic creator, notifiedUser, insightTarget, insight;

+ (NSDictionary*)remoteToLocalKeyMap
{
    return @{
        @"_id" : @"uniqueID",
        @"from" : [STKBind bindMapForKey:@"creator" matchMap:@{@"uniqueID" : @"_id"}],
        @"to" : [STKBind bindMapForKey:@"notifiedUser" matchMap:@{@"uniqueID" : @"_id"}],
        @"post_id" : [STKBind bindMapForKey:@"post" matchMap:@{@"uniqueID" : @"_id"}],
        @"comment_id" : [STKBind bindMapForKey:@"comment" matchMap:@{@"uniqueID" : @"_id"}],
        @"action" : @"action",
        @"has_been_viewed" : @"hasBeenViewed",
        @"insight_target_id" : [STKBind bindMapForKey:@"insightTarget" matchMap:@{@"uniqueID": @"_id"}],
        @"insight_id" : [STKBind bindMapForKey:@"insight" matchMap:@{@"uniqueID":@"_id"}],
        @"create_date" : [STKBind bindMapForKey:@"dateCreated" transform:STKBindTransformDateTimestamp]
        };
}

- (NSError *)readFromJSONObject:(id)jsonObject
{

    [self bindFromDictionary:jsonObject keyMap:[[self class] remoteToLocalKeyMap]];
    
    return nil;
}

- (NSString *)text
{
    NSMutableString *str = [[NSMutableString alloc] init];
    if ([self insightTarget]) {
        [str appendString:@"sent you an insight."];
        return [str copy];
    }
    if([[self action] isEqualToString:STKActivityItemTypeLike]) {
        [str appendString:@"liked your "];

        if([self comment]) {
            [str appendString:@"comment."];
        } else if([self post]) {
            [str appendString:@"post."];
        }
    } else if([[self action] isEqualToString:STKActivityItemTypeComment]) {
        [str appendString:@"commented on your post."];
        
    } else if([[self action] isEqualToString:STKActivityItemTypeFollow]) {
        [str appendString:@"started following you."];
    } else if ([[self action] isEqualToString:STKActivityItemTypeTrustAccepted]) {
        [str appendString:@"accepted your trust request."];
    } else if ([[self action] isEqualToString:STKActivityItemTypeRepost]) {
        [str appendString:@"reposted your post."];
    } else if ([[self action] isEqualToString:STKActivityItemTypeTag]) {
        [str appendString:@"tagged you in a post."];
    } else if([[self action] isEqualToString:STKActivityItemTypeAccolade]) {
        [str appendString:@"sent you an accolade."];
    } else if([[self action] isEqualToString:@"post"]) {
        [str appendString:@"created a new post."];
    } else if ([[self action] isEqualToString:STKActivityItemTypeGroupJoined]) {
        [str appendString:@"is reviewing your membership request."];
    }
    
    
    
    return [str copy];

}

@end

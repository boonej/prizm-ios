//
//  STKContentStore.m
//  Prism
//
//  Created by Joe Conway on 12/26/13.
//  Copyright (c) 2013 Higher Altitude. All rights reserved.
//

#import "STKContentStore.h"
#import "STKBaseStore.h"
#import "STKPost.h"
#import "STKUserStore.h"
#import "STKUser.h"
#import "STKActivityItem.h"
#import "STKRequestItem.h"
#import "STKConnection.h"
#import "STKFoursquareConnection.h"
#import "STKFoursquareLocation.h"
#import "STKPostComment.h"
#import "STKPostComment.h"

NSString * const STKContentStoreErrorDomain = @"STKContentStoreErrorDomain";

NSString * const STKContentFoursquareClientID = @"NPXBWJD343KPWSECQJM1NKJEZ4SYQ4RGRYWEBTLCU21PNUXO";
NSString * const STKContentFoursquareClientSecret = @"B2KSDXAPXQTWWMZLB2ODCCR3JOJVRQKCS1MNODYKD4TF2VCS";

NSString * const STKContentEndpointPost = @"/posts";


NSString * const STKContentStorePostDeletedNotification = @"STKContentStorePostDeletedNotification";
NSString * const STKContentStorePostDeletedKey = @"STKContentStorePostDeletedKey";

@interface STKContentStore ()

@end

@implementation STKContentStore
+ (STKContentStore *)store
{
    static STKContentStore *store = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        store = [[STKContentStore alloc] init];
    });
    return store;
}


- (NSURLSession *)session
{
    return [[STKBaseStore store] session];
}

- (NSError *)errorForCode:(STKContentStoreErrorCode)code data:(id)data
{
    if(code == STKContentStoreErrorCodeMissingArguments) {
        return [NSError errorWithDomain:STKUserStoreErrorDomain code:code userInfo:@{@"missing arguments" : data}];
    }
    
    return [NSError errorWithDomain:STKUserStoreErrorDomain code:code userInfo:nil];
}

- (void)fetchLocationNamesForCoordinate:(CLLocationCoordinate2D)coord
                             completion:(void (^)(NSArray *locations, NSError *err))block
{
    STKFoursquareConnection *c = [[STKFoursquareConnection alloc] initWithBaseURL:[NSURL URLWithString:@"https://api.foursquare.com"]
                                                                         endpoint:@"/v2/venues/search"];
    [c addQueryValue:[NSString stringWithFormat:@"%.20f,%.20f", coord.latitude, coord.longitude] forKey:@"ll"];
    [c addQueryValue:STKContentFoursquareClientID forKey:@"client_id"];
    [c addQueryValue:STKContentFoursquareClientSecret forKey:@"client_secret"];
    [c addQueryValue:@"20140101" forKey:@"v"];
    
    [c setModelGraph:@{@"venues" : @[@"STKFoursquareLocation"]}];
    [c getWithSession:[self session] completionBlock:^(id obj, NSError *err) {
        if(!err) {
            NSArray *venues = [obj objectForKey:@"venues"];
            block(venues, nil);
        } else {
            block(nil, err);
        }
    }];
}

- (NSArray *)cachedPostsForPredicate:(NSPredicate *)predicate
                         inDirection:(STKQueryObjectPage)fetchDirection
                       referencePost:(STKPost *)referencePost
{
    if(!referencePost) {
        NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"STKPost"];
        [req setPredicate:predicate];
        [req setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"datePosted" ascending:NO]]];
        [req setFetchLimit:30];
        
        return [[[STKUserStore store] context] executeFetchRequest:req error:nil];
    } else {
        NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"STKPost"];
        [req setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"datePosted" ascending:NO]]];
        [req setFetchLimit:30];
        
        if(fetchDirection == STKQueryObjectPageNewer) {
            [req setPredicate:[NSCompoundPredicate andPredicateWithSubpredicates:@[predicate,
                                                                                   [NSPredicate predicateWithFormat:@"datePosted > %@", [referencePost datePosted]]]]];
        } else {
            [req setPredicate:[NSCompoundPredicate andPredicateWithSubpredicates:@[predicate,
                                                                                   [NSPredicate predicateWithFormat:@"datePosted < %@", [referencePost datePosted]]]]];
        }
        
        return [[[STKUserStore store] context] executeFetchRequest:req error:nil];
    }
    return @[];
}

- (void)fetchFeedForUser:(STKUser *)u
             inDirection:(STKQueryObjectPage)fetchDirection
           referencePost:(STKPost *)referencePost
              completion:(void (^)(NSArray *posts, NSError *err))block;
{
    NSArray *cached = [self cachedPostsForPredicate:[NSPredicate predicateWithFormat:@"fInverseFeed == %@", [[STKUserStore store] currentUser]]
                                        inDirection:fetchDirection
                                      referencePost:referencePost];

    
    if([cached count] > 0) {
        if(fetchDirection == STKQueryObjectPageNewer)
            referencePost = [cached firstObject];
        else
            referencePost = [cached lastObject];
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            block(cached, nil);
        }];
    }
    
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            block(nil, err);
            return;
        }
                
        STKConnection *c = [[STKBaseStore store] connectionForEndpoint:@"/users"];
        [c setIdentifiers:@[[u uniqueID], @"feed"]];
        
        STKQueryObject *q = [[STKQueryObject alloc] init];
        [q setLimit:30];
        [q setPageDirection:fetchDirection];
        [q setPageKey:STKPostDateCreatedKey];
        [q setPageValue:[referencePost referenceTimestamp]];
        
        STKResolutionQuery *rq = [STKResolutionQuery resolutionQueryForField:@"creator"];
        [q addSubquery:rq];
        
        STKContainQuery *cq = [STKContainQuery containQueryForField:@"likes" key:@"_id" value:[[[STKUserStore store] currentUser] uniqueID]];
        [q addSubquery:cq];
        
        STKResolutionQuery *originPost = [STKResolutionQuery resolutionQueryForField:@"origin_post_id"];
        STKResolutionQuery *originPostCreator = [STKResolutionQuery resolutionQueryForField:@"creator"];
        [originPost addSubquery:originPostCreator];
        [q addSubquery:originPost];
        
        [c setQueryObject:q];
        
        [c setResolutionMap:@{@"User" : @"STKUser", @"Post" : @"STKPost"}];
        [c setModelGraph:@[@"STKPost"]];
        [c setContext:[[STKUserStore store] context]];
        [c setExistingMatchMap:@{@"uniqueID" : @"_id"}];
        [c setShouldReturnArray:YES];
        [c getWithSession:[self session] completionBlock:^(NSArray *posts, NSError *err) {
            if(!err) {
                [[[[STKUserStore store] currentUser] mutableSetValueForKeyPath:@"fFeedPosts"] addObjectsFromArray:posts];
                [[[STKUserStore store] context] save:nil];
                block(posts, nil);
            } else {
                block(nil, err);
            }
        }];
    }];
}

- (void)fetchExplorePostsInDirection:(STKQueryObjectPage)fetchDirection
                       referencePost:(STKPost *)referencePost
                              filter:(NSDictionary *)filterDict
                          completion:(void (^)(NSArray *posts, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            block(nil, err);
            return;
        }
        STKConnection *c = [[STKBaseStore store] connectionForEndpoint:@"/explore"];
        STKQueryObject *q = [[STKQueryObject alloc] init];
        [q setLimit:30];
        if(referencePost){
            [q setPageDirection:fetchDirection];
            [q setPageKey:STKPostDateCreatedKey];
            [q setPageValue:[referencePost referenceTimestamp]];
        }
        
        [q setFilters:filterDict];
        
        STKResolutionQuery *rq = [STKResolutionQuery resolutionQueryForField:@"creator"];
        [q addSubquery:rq];
        
        STKContainQuery *cq = [STKContainQuery containQueryForField:@"likes" key:@"_id" value:[[[STKUserStore store] currentUser] uniqueID]];
        [q addSubquery:cq];
        
        STKResolutionQuery * originPost = [STKResolutionQuery resolutionQueryForField:@"origin_post_id"];
        STKResolutionQuery * originPostCreator = [STKResolutionQuery resolutionQueryForField:@"creator"];
        [originPost addSubquery:originPostCreator];
        [q addSubquery:originPost];
        
        [c setQueryObject:q];
        
        
        [c setResolutionMap:@{@"User" : @"STKUser", @"Post" : @"STKPost"}];
        [c setModelGraph:@[@"STKPost"]];
        [c setContext:[[STKUserStore store] context]];
        [c setExistingMatchMap:@{@"uniqueID" : @"_id"}];
        [c setShouldReturnArray:YES];
        [c getWithSession:[self session] completionBlock:^(NSArray *obj, NSError *err) {
            if(!err) {
                [[[STKUserStore store] context] save:nil];
                block(obj, nil);
            } else {
                block(nil, err);
            }
        }];
    }];
}

- (void)fetchPostsForLocationName:(NSString *)locationName
                        direction:(STKQueryObjectPage)fetchDirection
                    referencePost:(STKPost *)referencePost
                       completion:(void (^)(NSArray *posts, NSError *err))block
{
    [self fetchExplorePostsInDirection:fetchDirection
                         referencePost:referencePost
                                filter:@{@"location_name" : locationName}
                            completion:block];
}

- (void)fetchExplorePostsInDirection:(STKQueryObjectPage)fetchDirection
                       referencePost:(STKPost *)referencePost
                          completion:(void (^)(NSArray *posts, NSError *err))block
{
    [self fetchExplorePostsInDirection:fetchDirection referencePost:referencePost filter:nil completion:block];
}

- (void)fetchExplorePostsForHashTag:(NSString *)hashTag
                        inDirection:(STKQueryObjectPage)fetchDirection
                      referencePost:(STKPost *)referencePost
                         completion:(void (^)(NSArray *posts, NSError *err))block
{
    [self fetchExplorePostsInDirection:fetchDirection
                         referencePost:referencePost
                                filter:@{@"hash_tags" : hashTag}
                            completion:block];
}

- (void)searchPostsForHashtag:(NSString *)hashTag
                   completion:(void (^)(NSArray *posts, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            block(nil, err);
            return;
        }
        
        NSString *hashEndpoint = [NSString stringWithFormat:@"/search/hashtags/%@", hashTag];
        STKConnection *c = [[STKBaseStore store] connectionForEndpoint:hashEndpoint];
        [c setShouldReturnArray:YES];
        [c getWithSession:[self session] completionBlock:^(NSArray *obj, NSError *err) {
            if(!err) {
                block(obj, nil);
            } else {
                block(nil, err);
            }
        }];
    }];
}

- (void)fetchProfilePostsForUser:(STKUser *)user
                     inDirection:(STKQueryObjectPage)fetchDirection
                   referencePost:(STKPost *)referencePost
                      completion:(void (^)(NSArray *posts, NSError *err))block
{
    NSArray *cached = [self cachedPostsForPredicate:[NSPredicate predicateWithFormat:@"fInverseProfile == %@", user]
                                        inDirection:fetchDirection
                                      referencePost:referencePost];
    
    
    if([cached count] > 0) {
        if(fetchDirection == STKQueryObjectPageNewer)
            referencePost = [cached firstObject];
        else
            referencePost = [cached lastObject];
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            block(cached, nil);
        }];
    }

    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            block(nil, err);
            return;
        }
        STKConnection *c = [[STKBaseStore store] connectionForEndpoint:@"/users"];
        [c setIdentifiers:@[[user uniqueID], @"posts"]];
        
        STKQueryObject *q = [[STKQueryObject alloc] init];
        [q setLimit:30];
        [q setPageDirection:fetchDirection];
        [q setPageKey:STKPostDateCreatedKey];
        [q setPageValue:[referencePost referenceTimestamp]];
        
        STKResolutionQuery *rq = [STKResolutionQuery resolutionQueryForField:@"creator"];
        [q addSubquery:rq];
        
        STKContainQuery *cq = [STKContainQuery containQueryForField:@"likes" key:@"_id" value:[[[STKUserStore store] currentUser] uniqueID]];
        [q addSubquery:cq];
        
        [c setQueryObject:q];
        
        [c setResolutionMap:@{@"User" : @"STKUser"}];
        [c setModelGraph:@[@"STKPost"]];
        [c setContext:[[STKUserStore store] context]];
        [c setExistingMatchMap:@{@"uniqueID" : @"_id"}];
        [c setShouldReturnArray:YES];
        [c getWithSession:[self session] completionBlock:^(NSArray *obj, NSError *err) {
            if(!err) {
                obj = [obj sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"datePosted"
                                                                                       ascending:NO]]];
                for(STKPost *p in obj) {
                    [p setFInverseProfile:user];
                }
                
                [[[STKUserStore store] context] save:nil];
                block(obj, nil);
            } else {
                block(nil, err);
            }
        }];
    }];
}

- (void)likePost:(STKPost *)post completion:(void (^)(STKPost *p, NSError *err))block
{
    [post setLikeCount:[post likeCount] + 1];
    [[post mutableSetValueForKey:@"likes"] addObject:[[STKUserStore store] currentUser]];

    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if(err) {
            [[post mutableSetValueForKey:@"likes"] removeObject:[[STKUserStore store] currentUser]];

            [post setLikeCount:[post likeCount] - 1];

            block(nil, err);
            return;
        }
        
        
        STKConnection *c = [[STKBaseStore store] connectionForEndpoint:STKContentEndpointPost];
        [c setIdentifiers:@[[post uniqueID], @"like"]];
        [c addQueryValue:[[[STKUserStore store] currentUser] uniqueID]
                  forKey:@"creator"];
        [c setModelGraph:@[post]];
        [c setContext:[[STKUserStore store] context]];
        [c postWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            if(err) {
                [[post mutableSetValueForKey:@"likes"] removeObject:[[STKUserStore store] currentUser]];
                [post setLikeCount:[post likeCount] - 1];
            }
            [[[STKUserStore store] context] save:nil];
            block(post, err);
        }];
    }];
}

- (void)flagPost:(STKPost *)post completion:(void (^)(STKPost *p, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if(err){
            block(nil, err);
            return;
        }
        
        STKConnection *c = [[STKBaseStore store] connectionForEndpoint:STKContentEndpointPost];
        [c setIdentifiers:@[[post uniqueID], @"flag"]];
        [c addQueryValue:[[[STKUserStore store] currentUser] uniqueID] forKey:@"reporter"];
        
        [c postWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            if(err || ![obj isKindOfClass:[NSString class]]){
                block(nil, err);
                return;
            }
            block(post, err);
        }];
         
    }];
}

- (void)unlikePost:(STKPost *)post completion:(void (^)(STKPost *p, NSError *err))block
{
    [post setLikeCount:[post likeCount] - 1];
    [[post mutableSetValueForKey:@"likes"] removeObject:[[STKUserStore store] currentUser]];

    void (^reversal)(void) = ^{
        [post setLikeCount:[post likeCount] + 1];
        [[post mutableSetValueForKey:@"likes"] addObject:[[STKUserStore store] currentUser]];
        [[[STKUserStore store] context] save:nil];
    };
    
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if(err) {
            reversal();
            
            block(nil, err);
            return;
        }
        
        
        STKConnection *c = [[STKBaseStore store] connectionForEndpoint:STKContentEndpointPost];
        [c setIdentifiers:@[[post uniqueID], @"unlike"]];
        [c addQueryValue:[[[STKUserStore store] currentUser] uniqueID]
                  forKey:@"creator"];
        [c postWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            if(err) {
                reversal();
            }
            [[[STKUserStore store] context] save:nil];
            block(post, err);
        }];
    }];
}

- (void)deletePost:(STKPost *)post completion:(void (^)(STKPost *p, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            block(nil, err);
            return;
        }
        
        STKConnection *c = [[STKBaseStore store] connectionForEndpoint:@"/posts"];
        [c setIdentifiers:@[[post uniqueID]]];
        [c addQueryValue:[[[STKUserStore store] currentUser] uniqueID] forKey:@"creator"];
        
        [c deleteWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            if(!err) {
                [[NSNotificationCenter defaultCenter] postNotificationName:STKContentStorePostDeletedNotification
                                                                    object:self
                                                                  userInfo:@{STKContentStorePostDeletedKey : post}];
                [[[STKUserStore store] context] deleteObject:post];
                [[[STKUserStore store] context] save:nil];
            }
            
            block(obj, err);
        }];
    }];
}

- (void)likeComment:(STKPostComment *)comment completion:(void (^)(STKPostComment *p, NSError *err))block
{
    if(![comment uniqueID]) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            block(nil, nil);
        }];
        return;
    }
    
    [comment setLikeCount:[comment likeCount] + 1];
    [[comment mutableSetValueForKey:@"likes"] addObject:[[STKUserStore store] currentUser]];
    
    void (^reversal)(void) = ^{
        [comment setLikeCount:[comment likeCount] - 1];
        [[comment mutableSetValueForKey:@"likes"] removeObject:[[STKUserStore store] currentUser]];
        [[[STKUserStore store] context] save:nil];
    };
    
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if(err) {
            reversal();
            
            block(nil, err);
            return;
        }
        STKConnection *c = [[STKBaseStore store] connectionForEndpoint:STKContentEndpointPost];
        [c setIdentifiers:@[[[comment post] uniqueID], @"comments", [comment uniqueID], @"like"]];
        [c addQueryValue:[[[STKUserStore store] currentUser] uniqueID] forKey:@"creator"];

        [c postWithSession:[self session] completionBlock:^(STKPostComment *obj, NSError *err) {
            if(err) {
                reversal();
            } else {
                [[[STKUserStore store] context] save:nil];
            }
            block(obj, err);
        }];
    }];
}

- (void)unlikeComment:(STKPostComment *)comment completion:(void (^)(STKPostComment *p, NSError *err))block
{
    if(![comment uniqueID]) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            block(nil, nil);
        }];
        return;
    }

    [comment setLikeCount:[comment likeCount] - 1];
    [[comment mutableSetValueForKey:@"likes"] removeObject:[[STKUserStore store] currentUser]];
    
    void (^reversal)(void) = ^{
        [comment setLikeCount:[comment likeCount] + 1];
        [[comment mutableSetValueForKey:@"likes"] addObject:[[STKUserStore store] currentUser]];
        [[[STKUserStore store] context] save:nil];
    };

    
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if(err) {
            reversal();
            
            block(nil, err);
            return;
        }
        STKConnection *c = [[STKBaseStore store] connectionForEndpoint:STKContentEndpointPost];
        [c setIdentifiers:@[[[comment post] uniqueID], @"comments", [comment uniqueID], @"unlike"]];
        [c addQueryValue:[[[STKUserStore store] currentUser] uniqueID] forKey:@"creator"];
        [c postWithSession:[self session] completionBlock:^(STKPostComment *obj, NSError *err) {
            if(err) {
                reversal();
            } else {
                [[[STKUserStore store] context] save:nil];
            }
            block(obj, err);
        }];
    }];
}

- (void)fetchLikersForPost:(STKPost *)post completion:(void (^)(NSArray *likers, NSError *err))block
{
    // needs fixin'
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if(err) {
            block(nil, err);
            return;
        }
        STKConnection *c = [[STKBaseStore store] connectionForEndpoint:STKContentEndpointPost];
        [c setIdentifiers:@[[post uniqueID], @"likes"]];

        STKContainQuery *cq = [STKContainQuery containQueryForField:@"followers" key:@"_id" value:[[[STKUserStore store] currentUser] uniqueID]];
        STKResolutionQuery *rq = [STKResolutionQuery resolutionQueryForField:@"likes"];
        [rq addSubquery:cq];
        [c setQueryObject:rq];
        
        [c setResolutionMap:@{@"User" : @"STKUser"}];
        [c setModelGraph:@[@[@"STKUser"]]];
        [c setContext:[[STKUserStore store] context]];
        [c setExistingMatchMap:@{@"uniqueID" : @"_id"}];
        [c getWithSession:[self session] completionBlock:^(NSArray *obj, NSError *err) {
            if(!err) {
                [post setLikes:[NSSet setWithArray:obj]];
            }
            block(obj, err);
        }];
    }];
}


- (void)addComment:(NSString *)comment toPost:(STKPost *)p completion:(void (^)(STKPost *p, NSError *err))block
{
    STKPostComment *pc = [NSEntityDescription insertNewObjectForEntityForName:@"STKPostComment"
                                                       inManagedObjectContext:[[STKUserStore store] context]];
    [pc setCreator:[[STKUserStore store] currentUser]];
    [pc setText:comment];
    [pc setDate:[NSDate date]];
    
    [[p mutableSetValueForKey:@"comments"] addObject:pc];
    [p setCommentCount:[p commentCount] + 1];
    
    void (^reversal)(void) = ^{
        [[[STKUserStore store] context] deleteObject:pc];
        [p setCommentCount:[p commentCount] -1];
        [[[STKUserStore store] context] save:nil];
    };
    
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if(err) {
            reversal();

            block(nil, err);
            return;
        }
       
        STKConnection *c = [[STKBaseStore store] connectionForEndpoint:STKContentEndpointPost];
        [c setIdentifiers:@[[p uniqueID], @"comments"]];
        [c addQueryValue:[[[STKUserStore store] currentUser] uniqueID]
                  forKey:@"creator"];
        [c addQueryValue:comment forKey:@"text"];
        
        [c setContext:[[STKUserStore store] context]];
        [c setModelGraph:@[@{@"comments" : pc}]];
        
        [c postWithSession:[self session] completionBlock:^(NSDictionary *comments, NSError *err) {
            if(err) {
                reversal();
            } else {
                [[[STKUserStore store] context] save:nil];
            }
            block(p, err);
        }];

    }];
}

- (void)deleteComment:(STKPostComment *)comment completion:(void (^)(STKPost *p, NSError *err))block
{
    STKPost *p = [comment post];

    [p setCommentCount:[p commentCount] - 1];
    [[p mutableSetValueForKey:@"comments"] removeObject:comment];
    
    void (^reversal)(void) = ^{
        [p setCommentCount:[p commentCount] + 1];
        [[p mutableSetValueForKey:@"comments"] addObject:comment];
        [[[STKUserStore store] context] save:nil];
    };
        
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if(err) {
            reversal();
            
            block(nil, err);
            return;
        }
        
        STKConnection *c = [[STKBaseStore store] connectionForEndpoint:STKContentEndpointPost];
        [c setIdentifiers:@[[p uniqueID], @"comments", [comment uniqueID]]];
        [c addQueryValue:[[[STKUserStore store] currentUser] uniqueID]
                  forKey:@"creator"];
        
        [c deleteWithSession:[self session] completionBlock:^(id comments, NSError *err) {
            if(err) {
                reversal();
            } else {
                [[[STKUserStore store] context] deleteObject:comment];
                [[[STKUserStore store] context] save:nil];
            }
            block(p, err);
        }];
        
    }];
}

- (void)fetchRecommendedHashtags:(NSString *)baseString
                      completion:(void (^)(NSArray *suggestions))block
{
    NSPredicate *p = [NSPredicate predicateWithFormat:@"title beginswith %@", baseString];
    NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"STKHashTag"];
    [req setPredicate:p];
    [req setFetchLimit:5];
    
    NSArray *results = [[[[STKUserStore store] context] executeFetchRequest:req error:nil] valueForKey:@"title"];
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        block(results);
    }];
}

- (void)addPostWithInfo:(NSDictionary *)info completion:(void (^)(STKPost *p, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            block(nil, err);
            return;
        }

        STKConnection *c = [[STKBaseStore store] connectionForEndpoint:@"/users"];
        [c setIdentifiers:@[[[[STKUserStore store] currentUser] uniqueID], @"posts"]];
        
        [c addQueryValue:[[[STKUserStore store] currentUser] uniqueID] forKey:@"creator"];
        
        for(NSString *key in info) {
            [c addQueryValue:[info objectForKey:key] forKey:key];
        }
        if(![info objectForKey:STKPostVisibilityKey]) {
            [c addQueryValue:STKPostVisibilityTrust forKey:STKPostVisibilityKey];
        }
        
        // This will wash away any Visibility modifiers as intended
        if([[info objectForKey:STKPostTypeKey] isEqualToString:STKPostTypePersonal]) {
            [c addQueryValue:STKPostVisibilityPrivate forKey:STKPostVisibilityKey];
        }
        
        [c setContext:[[STKUserStore store] context]];
        [c setModelGraph:@[@"STKPost"]];
        
        [c postWithSession:[self session] completionBlock:^(STKPost *post, NSError *err) {
            if(!err) {
                [post setFInverseFeed:[[STKUserStore store] currentUser]];
                [[[STKUserStore store] context] save:nil];
            }

            block(post, err);
        }];
    }];
}

- (void)editPost:(STKPost *)p completion:(void (^)(STKPost *p, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            block(nil, err);
            return;
        }
        
        STKConnection *c = [[STKBaseStore store] connectionForEndpoint:@"/posts"];
        [c setIdentifiers:@[[p uniqueID]]];
        
        [c addQueryValue:[[[STKUserStore store] currentUser] uniqueID] forKey:@"creator"];
        
        NSDictionary *changedValues = [p changedValues];
        NSDictionary *keyMap = [STKPost reverseKeyMap];
        for(NSString *key in changedValues) {
            NSString *val = [changedValues objectForKey:key];
            NSString *newKey = [keyMap objectForKey:key];
            if(val && newKey) {
                [c addQueryValue:val
                          forKey:newKey];
            }
        }
        

        [c putWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            if(!err) {
                [[p managedObjectContext] save:nil];
                [[[STKUserStore store] context] save:nil];
            } else {
                
            }
            
            block(obj, err);
        }];
    }];
}

- (void)fetchCommentsForPost:(STKPost *)post completion:(void (^)(NSArray *comments, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            block(nil, err);
            return;
        }
        // needs fixin
        STKConnection *c = [[STKBaseStore store] connectionForEndpoint:@"/posts"];
        [c setIdentifiers:@[[post uniqueID], @"comments"]];

        STKQueryObject *q = [[STKQueryObject alloc] init];
        [q addSubquery:[STKResolutionQuery resolutionQueryForField:@"creator"]];
        [q addSubquery:[STKContainQuery containQueryForField:@"likes" key:@"_id" value:[[[STKUserStore store] currentUser] uniqueID]]];
        
        [c setQueryObject:q];
        
        [c setResolutionMap:@{@"User" : @"STKUser"}];
        [c setModelGraph:@[@[@"STKPostComment"]]];
        [c setExistingMatchMap:@{@"uniqueID" : @"_id"}];
        [c setContext:[[STKUserStore store] context]];
        [c getWithSession:[self session] completionBlock:^(NSArray *comments, NSError *err) {
            if(!err) {
                [post setComments:[NSSet setWithArray:comments]];
                
                [[[STKUserStore store] context] save:nil];
            } else {
                
            }
            
            block(comments, err);
        }];
    }];
}
- (void)fetchLikersForComment:(STKPostComment *)postComment completion:(void (^)(NSArray *likers, NSError *err))block
{
    // needs fixing
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            block(nil, err);
            return;
        }
        STKConnection *c = [[STKBaseStore store] connectionForEndpoint:@"/posts"];
        [c setIdentifiers:@[[[postComment post] uniqueID], @"comments", [postComment uniqueID], @"likes"]];
        [c setModelGraph:@[@{@"likes": @[@"STKUser"]}]];
        [c setExistingMatchMap:@{@"uniqueID": @"_id"}];
        [c setContext:[[STKUserStore store] context]];
        [c getWithSession:[self session] completionBlock:^(NSDictionary *obj, NSError *err) {
            if(!err) {
                [postComment setLikes:[NSSet setWithArray:[obj objectForKey:@"likes"]]];
                [[[STKUserStore store] context] save:nil];
            }
            block([obj objectForKey:@"likes"], err);
        }];
    }];
}


@end

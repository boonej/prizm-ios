//
//  STKUserStore.m
//  Prism
//
//  Created by Joe Conway on 11/7/13.
//  Copyright (c) 2013 Higher Altitude. All rights reserved.
//

#import "STKUserStore.h"
#import "STKUser.h"
#import "STKActivityItem.h"
#import "STKPost.h"
#import "STKPostComment.h"
#import "STKConnection.h"
#import "STKUser.h"
#import <GoogleOpenSource/GoogleOpenSource.h>
#import <GooglePlus/GooglePlus.h>
#import "OAuthCore.h"
#import "NSError+STKConnection.h"
#import "STKSecurePassword.h"
#import "STKBaseStore.h"
#import "STKTrust.h"
#import "STKNetworkStore.h"
#import <Crashlytics/Crashlytics.h>
#import "STKFetchDescription.h"
#import "Mixpanel.h"
#import "STKImageStore.h"
#import "STKInsight.h"
#import "STKInsightTarget.h"
#import "STKInterest.h"
#import "Heap.h"
#import "STKOrganization.h"
#import "STKGroup.h"
#import "STKMessage.h"
#import "STKOrgStatus.h"
#import "STKQuestion.h"
#import "STKSurvey.h"
#import "STKQuestionOption.h"
//ssh -i ~/.ssh/PrismAPIDev.pem ec2-user@ec2-54-186-28-238.us-west-2.compute.amazonaws.com
//ssh -i ~/.ssh/PrismAPIDev.pem ec2-user@ec2-54-200-41-62.us-west-2.compute.amazonaws.com

NSString * const STKUserStoreErrorDomain = @"STKUserStoreErrorDomain";
NSString * const STKUserStoreActivityUpdateNotification = @"STKUserStoreActivityUpdateNotification";
NSString * const STKUserStoreActivityUpdateCountKey = @"STKUSerStoreActivityUpdateCountKey";
NSString * const HAUserStoreActivityUserKey = @"HAUserStoreActivityUserKey";
NSString * const HAUserStoreActivityLikeKey = @"HAUserStoreActivityLikeKey";
NSString * const HAUserStoreActivityTrustKey = @"HAUserStoreActivityTrustKey";
NSString * const HAUserStoreActivityInsightKey = @"HAUserStoreActivityInsightKey";
NSString * const HAUserStoreActivityCommentKey = @"HAUserStoreActivityCommentKey";
NSString * const HAUserStoreActivityLuminaryPostKey = @"HAUserStoreActivityLuminaryPostKey";
NSString * const STKUserStoreCurrentUserKey = @"com.higheraltitude.prism.currentUser";
NSString * const HAUserStoreLoggedInUsersKey = @"com.higheraltitude.prism.loggedInUsers";
NSString * const HANotificationKeyUserLoggedOut = @"HANotificationKeyUserLoggedOut";
NSString * const HAUserStoreInterestsKey = @"HAUserStoreInterestsKey";
NSString * const HAUnreadMessagesUpdated = @"HAUnreadMessagesUpdated";
NSString * const HAUnreadMessagesForGroupsKey = @"HAUnreadMessagesForGroupsKey";
NSString * const HAUnreadMessagesForUserKey = @"HAUnreadMessagesForUserKey";
NSString * const HAUnreadMessagesForOrgKey = @"HAUnreadMessagesForOrgKey";

NSString * const STKUserStoreCurrentUserChangedNotification = @"STKUserStoreCurrentUserChangedNotification";

NSString * const STKUserStoreExternalCredentialGoogleClientID = @"657032544324-o1sm1esga2qtcgcggtaabmqb5rjfkkic.apps.googleusercontent.com";
NSString * const STKUserStoreExternalCredentialFacebookAppID = @"1408826952716972";

NSString * const STKUserStoreExternalCredentialTwitterConsumerKey = @"MzIoqUFCk7BYUNpCNxtGuhuLu";
//@"B8y2wlENU9eQCV2FO2s3rg";
NSString * const STKUserStoreExternalCredentialTwitterConsumerSecret = @"yGhuwPvSljoVJoD4il2qtHZG0q4hWlXC87Mcdly0pxaFrMHEaf";
//@"XKWgxHrWgE8sfnFv7IcrgcvLM6XFZdBGmQexnzwFo";

NSString * const STKUserEndpointUser = @"/users";
NSString * const STKUserEndpointLogin = @"/oauth2/login";

@import CoreData;
@import Accounts;
@import Social;

@interface STKUserStore () <GPPSignInDelegate>

@property (nonatomic, strong) NSTimer *activityUpdateTimer;
@property (nonatomic, copy) void (^googlePlusAuthenticationBlock)(GTMOAuth2Authentication *auth, NSError *err);
@property (nonatomic, copy) void (^googlePlusProcessingBlock)();
@property (nonatomic) BOOL attemptingTransparentLogin;
@property (nonatomic, strong) NSMutableArray *signedInUsers;

@end

@implementation STKUserStore

+ (STKUserStore *)store
{
    static STKUserStore *store = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        store = [[STKUserStore alloc] init];
    });
    return store;
}

- (void)syncInterests
{
    
}


- (NSURLSession *)session
{
    return [[STKBaseStore store] session];
}

- (NSError *)errorForCode:(STKUserStoreErrorCode)code data:(id)data
{
    if(code == STKUserStoreErrorCodeMissingArguments) {
        return [NSError errorWithDomain:STKUserStoreErrorDomain code:code userInfo:@{@"missing arguments" : data}];
    }
    
    return [NSError errorWithDomain:STKUserStoreErrorDomain code:code userInfo:nil];
}

- (id)init
{
    self = [super init];
    if (self) {
        
        _accountStore = [[ACAccountStore alloc] init];
//        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLastModifiedDates:) name:NSManagedObjectContextWillSaveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(connectionDidFailAuthorization:)
                                                     name:STKConnectionUnauthorizedNotification
                                                   object:nil];
        [self establishDatabaseAndCurrentUser];
    }
    return self;
}

- (STKUser *)userForID:(NSString *)userID
{
    NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"STKUser"];
    [req setPredicate:[NSPredicate predicateWithFormat:@"uniqueID == %@", userID]];
    
    return [[[self context] executeFetchRequest:req error:nil] firstObject];
}

- (void)activityUpdateCheck:(NSTimer *)timer
{
    if([self currentUser]) {
        [self getUpdateCounts];
        NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"STKActivityItem"];
        [req setPredicate:[NSPredicate predicateWithFormat:@"notifiedUser == %@", [self currentUser]]];
        [req setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"dateCreated" ascending:NO]]];
        [req setFetchLimit:1];
        NSArray *cachedActivities = [[self context] executeFetchRequest:req error:nil];

        req = [NSFetchRequest fetchRequestWithEntityName:@"STKTrust"];
        [req setPredicate:[NSPredicate predicateWithFormat:@"recepient == %@", [self currentUser]]];
        [req setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"dateCreated" ascending:NO]]];
        [req setFetchLimit:1];
        NSArray *cachedRequests = [[self context] executeFetchRequest:req error:nil];

        STKFetchDescription *activityFd = [[STKFetchDescription alloc] init];
        [activityFd setReferenceObject:[cachedActivities firstObject]];
        [activityFd setDirection:STKQueryObjectPageNewer];
        
        STKFetchDescription *requestFd = [[STKFetchDescription alloc] init];
        [requestFd setReferenceObject:[cachedRequests firstObject]];
        [requestFd setDirection:STKQueryObjectPageNewer];
        
        [self fetchActivityForUser:[self currentUser] fetchDescription:activityFd completion:^(NSArray *activities, NSError *err) {
            [self fetchRequestsForCurrentUserWithFetchDescription:requestFd completion:^(NSArray *requests, NSError *err) {
                [self notifyNotificationCount];
            }];
        }];
    }
}

- (void)getUpdateCounts
{
    STKUser *u = [self currentUser];
    __block double orgCount = 0;
    __block double groupCount = 0;
    if (u.organizations.count > 0) {
        [self fetchUnreadMessageDigestForUser:self.currentUser completion:^(NSArray *messages, NSError *err) {
            if (messages) {
                NSMutableArray *users = [NSMutableArray array];
                [messages enumerateObjectsUsingBlock:^(STKMessage *message, NSUInteger idx, BOOL *stop) {
                    if ([users containsObject:message.creator]) {
                        double unread = message.creator.unreadCount.doubleValue + 1;
                        message.creator.unreadCount = [NSNumber numberWithDouble:unread];
                    } else {
                        message.creator.unreadCount = @1;
                        [users addObject:message.creator];
                    }
                }];
                [[NSUserDefaults standardUserDefaults] setDouble:messages.count forKey:HAUnreadMessagesForUserKey];
                [[NSNotificationCenter defaultCenter] postNotificationName:HAUnreadMessagesUpdated object:nil];
                [self.context save:nil];
            } else {
                [[NSUserDefaults standardUserDefaults] setDouble:0 forKey:HAUnreadMessagesForUserKey];
                [[NSNotificationCenter defaultCenter] postNotificationName:HAUnreadMessagesUpdated object:nil];
            }
        }];
        [u.organizations enumerateObjectsUsingBlock:^(STKOrgStatus *org, BOOL *stop) {
            if ([org.status isEqualToString:@"active"]){
            [self fetchUnreadCountForOrganization:org.organization group:nil completion:^(id obj, NSError *err) {
                if (obj) {
                    STKOrganization *organization = nil;
                    if ([obj isKindOfClass:[NSArray class]]) {
                        organization = [obj objectAtIndex:0];
                    } else {
                        organization = obj;
                    }
                    orgCount += organization.unreadCount.doubleValue;
                    [[NSUserDefaults standardUserDefaults] setDouble:orgCount forKey:HAUnreadMessagesForOrgKey];
                    [[NSNotificationCenter defaultCenter] postNotificationName:HAUnreadMessagesUpdated object:nil];
                    [self.context save:nil];
                    
                }
            }];
            
            if (org.groups.count > 0) {
                [org.groups enumerateObjectsUsingBlock:^(STKGroup *obj, BOOL *stop) {
                    if ([obj.status isEqualToString:@"active"]) {
                        [self fetchUnreadCountForOrganization:org.organization group:obj completion:^(id obj, NSError *err) {
                            if (obj) {
                                STKGroup *group = nil;
                                if ([obj isKindOfClass:[NSArray class]]) {
                                    group = [obj objectAtIndex:0];
                                } else {
                                    group = obj;
                                }
                                groupCount += group.unreadCount.doubleValue;
                                [[NSUserDefaults standardUserDefaults] setDouble:groupCount forKey:HAUnreadMessagesForGroupsKey];
                                [[NSNotificationCenter defaultCenter] postNotificationName:HAUnreadMessagesUpdated object:nil];
                                [self.context save:nil];
                            }
                        }];
                    }
                }];
            }
            }
        }];
    } else if ([u.type isEqualToString:@"institution_verified"]) {
        [self fetchUserOrgs:^(NSArray *organizations, NSError *err) {
            if (organizations && organizations.count > 0) {
                [self fetchUnreadMessageDigestForUser:self.currentUser completion:^(NSArray *messages, NSError *err) {
                    NSMutableArray *users = [NSMutableArray array];
                    if (messages) {
                        [messages enumerateObjectsUsingBlock:^(STKMessage *message, NSUInteger idx, BOOL *stop) {
                            if ([users containsObject:message.creator]) {
                                double unread = message.creator.unreadCount.doubleValue + 1;
                                message.creator.unreadCount = [NSNumber numberWithDouble:unread];
                            } else {
                                message.creator.unreadCount = @1;
                                [users addObject:message.creator];
                            }
                        }];
                        [[NSUserDefaults standardUserDefaults] setDouble:messages.count forKey:HAUnreadMessagesForUserKey];
                        [[NSNotificationCenter defaultCenter] postNotificationName:HAUnreadMessagesUpdated object:nil];
                        [self.context save:nil];
                    } else {
                        [[NSUserDefaults standardUserDefaults] setDouble:0 forKey:HAUnreadMessagesForUserKey];
                        [[NSNotificationCenter defaultCenter] postNotificationName:HAUnreadMessagesUpdated object:nil];
                    }
                }];
                [organizations enumerateObjectsUsingBlock:^(STKOrganization *org, NSUInteger idx, BOOL *stop) {
                    [self fetchUnreadCountForOrganization:org group:nil completion:^(id obj, NSError *err) {
                        if (obj) {
                            STKOrganization *organization = nil;
                            if ([obj isKindOfClass:[NSArray class]]) {
                                organization = [obj objectAtIndex:0];
                            } else {
                                organization = obj;
                            }
                            orgCount += organization.unreadCount.doubleValue;
                            [[NSUserDefaults standardUserDefaults] setDouble:orgCount forKey:HAUnreadMessagesForOrgKey];
                            [[NSNotificationCenter defaultCenter] postNotificationName:HAUnreadMessagesUpdated object:nil];
//                            NSLog(@"Message Count: %f", orgCount + groupCount);
                            [self.context save:nil];
                        }
                    }];
                    if (org.groups.count > 0) {
                        [org.groups enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
                            if ([[obj status]isEqualToString:@"active"]) {
                                [self fetchUnreadCountForOrganization:org group:obj completion:^(id obj, NSError *err) {
                                        if (obj) {
                                            STKGroup *group = nil;
                                            if ([obj isKindOfClass:[NSArray class]]) {
                                                group = [obj objectAtIndex:0];
                                            } else {
                                                group = obj;
                                            }
                                            groupCount += group.unreadCount.doubleValue;
//                                            NSLog(@"Message Count: %f", orgCount + groupCount);
                                            [[NSUserDefaults standardUserDefaults] setDouble:groupCount forKey:HAUnreadMessagesForGroupsKey];
                                            [[NSNotificationCenter defaultCenter] postNotificationName:HAUnreadMessagesUpdated object:nil];
                                            [self.context save:nil];
                                        }
                                }];
                            }
                        }];
                    }
                }];
            }
        }];
    }
         
}

- (void)notifyNotificationCount
{
    NSFetchRequest *aReq = [NSFetchRequest fetchRequestWithEntityName:@"STKActivityItem"];
    [aReq setPredicate:[NSPredicate predicateWithFormat:@"(hasBeenViewed == NO) AND (action <> %@ && action <> %@ && action <> %@)", @"like", @"comment", @"insight"]];
    NSFetchRequest *bReq = [NSFetchRequest fetchRequestWithEntityName:@"STKActivityItem"];
    [bReq setPredicate:[NSPredicate predicateWithFormat:@"(hasBeenViewed == NO) AND (action == %@)", @"like"]];
    NSFetchRequest *cReq = [NSFetchRequest fetchRequestWithEntityName:@"STKActivityItem"];
    [cReq setPredicate:[NSPredicate predicateWithFormat:@"(hasBeenViewed == NO) AND (comment <> NULL) AND (action != %@)", @"like"]];
    NSFetchRequest *dReq = [NSFetchRequest fetchRequestWithEntityName:@"STKActivityItem"];
    [dReq setPredicate:[NSPredicate predicateWithFormat:@"(hasBeenViewed == NO) AND (action == %@)", @"insight"]];
    NSFetchRequest *eReq = [NSFetchRequest fetchRequestWithEntityName:@"STKTrust"];
    [eReq setPredicate:[NSPredicate predicateWithFormat:@"status == %@ and recepient == %@", STKRequestStatusPending, [self currentUser]]];
    NSFetchRequest *fReq = [NSFetchRequest fetchRequestWithEntityName:@"STKActivityItem"];
    [fReq setPredicate:[NSPredicate predicateWithFormat:@"(hasBeenViewed == NO) AND (action == %@)", @"post"]];
    long actCount = [[self context] countForFetchRequest:aReq error:nil];
    long likeCount = [[self context] countForFetchRequest:bReq error:nil];
    long commentCount = [[self context] countForFetchRequest:cReq error:nil];
    long insightCount = [[self context] countForFetchRequest:dReq error:nil];
    
    long trustCount = [[self context] countForFetchRequest:eReq error:nil];
    long luminaryPostCount = [[self context] countForFetchRequest:fReq error:nil];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:STKUserStoreActivityUpdateNotification object:self userInfo:@{STKUserStoreActivityUpdateCountKey : @(actCount + trustCount + likeCount + insightCount+ luminaryPostCount), HAUserStoreActivityLikeKey: @(likeCount), HAUserStoreActivityUserKey: @(actCount), HAUserStoreActivityTrustKey: @(trustCount), HAUserStoreActivityCommentKey: @(commentCount), HAUserStoreActivityInsightKey: @(insightCount), HAUserStoreActivityLuminaryPostKey: @(luminaryPostCount)}];
}

- (void)markActivitiesAsRead
{
    NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"STKActivityItem"];
    [req setPredicate:[NSPredicate predicateWithFormat:@"hasBeenViewed == NO"]];
    NSArray *results = [[self context] executeFetchRequest:req error:nil];
    for(STKActivityItem *i in results) {
        [i setHasBeenViewed:YES];
    }
    
    [[self context] save:nil];
    
    [self notifyNotificationCount];
}

- (void)updateLastModifiedDates:(NSNotification *)note
{
    NSDate *now = [NSDate date];
    for(NSManagedObject *obj in [[note userInfo] objectForKey:NSInsertedObjectsKey]) {
        [obj setValue:now forKey:@"internalLastModified"];
    }
    for(NSManagedObject *obj in [[note userInfo] objectForKey:NSUpdatedObjectsKey]) {
        [obj setValue:now forKey:@"internalLastModified"];
    }
}

- (void)logout
{
    __block NSUInteger index;
    
    __block NSMutableArray *users  = [self.signedInUsers mutableCopy];
    [self.signedInUsers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSMutableDictionary *mobj = [obj mutableCopy];
        if ([[obj valueForKey:@"active"] boolValue]) {
            [mobj setValue:@NO forKey:@"active"];
            index = idx;
        }
        [users replaceObjectAtIndex:idx withObject:[mobj copy]];
    }];
    
    
    [users removeObjectAtIndex:index];
    self.signedInUsers = users;
    [[NSUserDefaults standardUserDefaults] setObject:self.signedInUsers forKey:HAUserStoreLoggedInUsersKey];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"HAGroupContextString"];
    if (self.signedInUsers.count > 0) {
        NSMutableDictionary *mobj = [[self.signedInUsers objectAtIndex:0] mutableCopy];
        NSString *uid =[mobj valueForKey:@"id"];
        STKUser *currentUser = [self userForID:uid];
        [self switchToUser:currentUser];
        [[NSNotificationCenter defaultCenter] postNotificationName:HANotificationKeyUserLoggedOut object:nil];
    } else {
        [self setCurrentUser:nil];
        self.signedInUsers = users;
        [[NSUserDefaults standardUserDefaults] setObject:self.signedInUsers forKey:HAUserStoreLoggedInUsersKey];
        [[STKBaseStore store] cancelAllQueuedRequests];
        [STKConnection cancelAllConnections];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:STKSessionEndedNotification
                                                            object:nil
                                                          userInfo:@{STKSessionEndedReasonKey : STKSessionEndedLogoutValue}];
    }
    

}



- (void)connectionDidFailAuthorization:(NSNotification *)note
{
    
    [[NSNotificationCenter defaultCenter] postNotificationName:STKSessionEndedNotification
                                                        object:nil
                                                      userInfo:@{STKSessionEndedReasonKey : STKSessionEndedAuthenticationValue}];
}

- (void)authenticateUser:(STKUser *)u
{
    [self setCurrentUser:u];
    [[self activityUpdateTimer] invalidate];
    _activityUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(activityUpdateCheck:) userInfo:nil repeats:YES];
    [self activityUpdateCheck:nil];
    [self transferPostsFromSocialNetworks];
}

- (void)transferPostsFromSocialNetworks
{
    if([self currentUser]) {
        __weak STKUser *u = [self currentUser];
        [[STKNetworkStore store] checkAndFetchPostsFromOtherNetworksForCurrentUserCompletion:^(NSDictionary *updatedUserEntries, NSError *err) {
            if(!err) {
                if(u && [[u uniqueID] isEqualToString:[[[STKUserStore store] currentUser] uniqueID]]) {
                    if(updatedUserEntries) {
                        [u setValuesForKeysWithDictionary:updatedUserEntries];
                        [self updateUserDetails:u completion:^(STKUser *updated, NSError *err) {
                            if(!err) {
                                [[self context] save:nil];
                            }
                        }];
                    }
                }
            }
        }];
    }
    
}


- (NSString *)cachePathForDatabase
{
    return [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0]
            stringByAppendingPathComponent:@"user.db"];
}

- (NSManagedObjectContext *)userContextForPath:(NSString *)path
{
    NSManagedObjectModel *mom = [[NSManagedObjectModel alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"User"
                                                                                                            withExtension:@"momd"]];
    NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
    NSError *error = nil;
    
    if(![psc addPersistentStoreWithType:NSSQLiteStoreType
                          configuration:nil
                                    URL:[NSURL fileURLWithPath:path]
                                options:@{NSMigratePersistentStoresAutomaticallyOption: @YES, NSInferMappingModelAutomaticallyOption: @YES}
                                  error:&error]) {
        [NSException raise:@"Open failed" format:@"Reason %@", [error localizedDescription]];
    }
    
    NSManagedObjectContext *ctx = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    [ctx setPersistentStoreCoordinator:psc];
    [ctx setUndoManager:nil];

    return ctx;
}

- (void)updateDeviceTokenForCurrentUser:(NSData *)deviceToken
{
    if([self currentUser]) {
        [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
            if(err) {
                return;
            }
            STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/users", [[self currentUser] uniqueID], @"devices"]];
            
            NSString *deviceString = [deviceToken description];
            deviceString = [deviceString stringByReplacingOccurrencesOfString:@"<" withString:@""];
            deviceString = [deviceString stringByReplacingOccurrencesOfString:@">" withString:@""];
            
            
            [c addQueryValue:deviceString forKey:@"device"];
            [c postWithSession:[self session] completionBlock:^(id obj, NSError *err) {

            }];
        }];
    }
}



- (void)setCurrentUser:(STKUser *)currentUser
{
    _currentUser = currentUser;
    __block BOOL userLoggedIn = NO;
    if(currentUser) {
        __block NSMutableArray *users  = [self.signedInUsers mutableCopy];
        [self.signedInUsers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSMutableDictionary *mobj = [obj mutableCopy];
            if ([[obj valueForKey:@"id"] isEqualToString:currentUser.uniqueID]) {
                [mobj setValue:@YES forKey:@"active"];
                userLoggedIn = YES;
            } else {
                [mobj setValue:@NO forKey:@"active"];
            }
            [users replaceObjectAtIndex:idx withObject:[mobj copy]];
        }];
        if (!userLoggedIn) {
            [users addObject:@{@"id": currentUser.uniqueID, @"active": @YES}];
        }
        self.signedInUsers = users;
        [[NSUserDefaults standardUserDefaults] setObject:self.signedInUsers forKey:HAUserStoreLoggedInUsersKey];
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeAlert)];
        
        [[NSUserDefaults standardUserDefaults] setObject:[currentUser uniqueID]
                                                  forKey:STKUserStoreCurrentUserKey];
        
        [[Crashlytics sharedInstance] setUserIdentifier:[NSString stringWithFormat:@"%@ %@ %@", [currentUser name], [currentUser uniqueID], [[UIDevice currentDevice] name]]];

        NSString *analyticsIdentifier = [NSString stringWithFormat:@"%@ %@", [currentUser name], [currentUser uniqueID]];
//        [[Mixpanel sharedInstance] identify:analyticsIdentifier];
        [[Mixpanel sharedInstance] registerSuperProperties:@{@"Current user" : analyticsIdentifier}];
        [[Mixpanel sharedInstance] startSession];
    } else {
        [[Mixpanel sharedInstance] endSession];
        [[Mixpanel sharedInstance] registerSuperProperties:@{}];

        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:STKUserStoreCurrentUserKey];
            [self setContext:nil];
            [[NSFileManager defaultManager] removeItemAtPath:[self cachePathForDatabase] error:nil];
            [self establishDatabaseAndCurrentUser];
            [[STKImageStore store] deleteAllCachedImages];
        }];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:STKUserStoreCurrentUserChangedNotification object:self];
}

- (void)establishDatabaseAndCurrentUser
{
    NSArray *signedInUsers = [[NSUserDefaults standardUserDefaults] objectForKey:HAUserStoreLoggedInUsersKey];
    if (signedInUsers && signedInUsers.count > 0) {
        self.signedInUsers = [signedInUsers mutableCopy];
    } else {
        self.signedInUsers = [NSMutableArray array];
        NSString *currentuniqueID = [[NSUserDefaults standardUserDefaults] objectForKey:STKUserStoreCurrentUserKey];
        if (currentuniqueID) {
            [self.signedInUsers addObject:@{@"id": currentuniqueID, @"active": @YES}];
        }
        [[NSUserDefaults standardUserDefaults] setObject:[self.signedInUsers copy] forKey:HAUserStoreLoggedInUsersKey];
    }
    __block NSString *currentuniqueID = nil;
    [self.signedInUsers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([[obj valueForKey:@"active"] boolValue]) {
            currentuniqueID = [obj valueForKey:@"id"];
        }
    }];
    NSString *dbPath = [self cachePathForDatabase];
    if(currentuniqueID) {
        if(dbPath && [[NSFileManager defaultManager] fileExistsAtPath:dbPath]) {
            NSManagedObjectContext *ctx = [self userContextForPath:dbPath];
            
            NSPredicate *p = [NSPredicate predicateWithFormat:@"uniqueID == %@", currentuniqueID];
            NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"STKUser"];
            [req setPredicate:p];
            NSArray *results = [ctx executeFetchRequest:req error:nil];
            STKUser *u = nil;
            if (results.count > 0)
                u = [results objectAtIndex:0];
            if(u) {
                [self setContext:ctx];
                [self setCurrentUser:u];

                [[Mixpanel sharedInstance] identify:[u uniqueID]];
                [[Mixpanel sharedInstance].people set:[u mixpanelProperties]];

                [self attemptTransparentLoginWithUser:u];
                
                [self pruneDatabase];
                
                return;
            }
        }
    } else {
        [self setSignedInUsers:[NSMutableArray array]];
        [[NSUserDefaults standardUserDefaults] setObject:[self.signedInUsers copy] forKey:HAUserStoreLoggedInUsersKey];
    }
    
    NSManagedObjectContext *ctx = [self userContextForPath:dbPath];
    [self setContext:ctx];
}

- (void)switchToUser:(STKUser *)u
{
//    NSString *dbPath = [self cachePathForDatabase];
//    NSManagedObjectContext *ctx = [self userContextForPath:dbPath];
//    [self setContext:ctx];
    [[STKBaseStore store] cancelAllQueuedRequests];
    [STKConnection cancelAllConnections];
    
//    [[NSNotificationCenter defaultCenter] postNotificationName:STKSessionEndedNotification
//                                                        object:nil
//                                                      userInfo:@{STKSessionEndedReasonKey : STKSessionEndedLogoutValue}];
    [self setCurrentUser:u];
    
   
//    [self attemptTransparentLoginWithUser:u];
    
    [self pruneDatabase];
}

- (NSArray *)loggedInUsers
{
    __block NSMutableArray *users = [NSMutableArray array];
    
    [self.signedInUsers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        STKUser *user = [self userForID:[obj valueForKey:@"id"]];
        if (user) {
            [users addObject:@{@"user": user, @"active": [obj valueForKey:@"active"]}];
        }
    }];
    return [users copy];
}

//- (void)syncInterests
//{
//    NSURL *plistUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@/files/interests.plist", STKUserBaseURLString]];
//    NSData *data = [NSData dataWithContentsOfURL:plistUrl];
//    
//    NSArray *interests = [[NSArray alloc] initWithContentsOfURL:plistUrl];
//    if (interests && [interests count] > 0) {
//        [[NSUserDefaults standardUserDefaults] setObject:interests forKey:HAUserStoreInterestsKey];
//    }
//}

- (void)fetchTrustPostsForTrust:(STKTrust *)t type:(STKTrustPostType)type completion:(void (^)(NSArray *posts, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            block(nil, err);
            return;
        }
        
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/trusts", [t uniqueID]]];
        
        NSString *diveKey = nil;
        STKQueryObject *obj = [[STKQueryObject alloc] init];
        if(type == STKTrustPostTypeLikes) {
            if([[[self currentUser] uniqueID] isEqualToString:[[t creator] uniqueID]]) {
                diveKey = @"to_post_likes";
            } else {
                diveKey = @"from_post_likes";
            }
        } else if(type == STKTrustPostTypeComments) {
            if([[[self currentUser] uniqueID] isEqualToString:[[t creator] uniqueID]]) {
                diveKey = @"to_comments";
            } else {
                diveKey = @"from_comments";
            }
        } else if(type == STKTrustPostTypeTags) {
            if([[[self currentUser] uniqueID] isEqualToString:[[t creator] uniqueID]]) {
                diveKey = @"to_posts";
            } else {
                diveKey = @"from_posts";
            }
        }
        
        if(diveKey) {
            [obj setFields:@[diveKey]];
        }
        [obj addSubquery:[STKResolutionQuery resolutionQueryForField:diveKey]];

        [c setQueryObject:obj];
        
        [c setModelGraph:@[@{diveKey : @[@"STKPost"]}]];
        [c setExistingMatchMap:@{@"uniqueID" : @"_id"}];
        [c setContext:[self context]];
        [c setResolutionMap:@{@"Post" : @"STKPost"}];
        
        [c getWithSession:[self session] completionBlock:^(NSDictionary *posts, NSError *err) {
            if(err) {
                block(nil, err);
            } else {
                block([posts objectForKey:diveKey], err);
            }
        }];
    }];
}

- (void)fetchTrustForUser:(STKUser *)user otherUser:(STKUser *)otherUser completion:(void (^)(STKTrust *t, NSError *err))block
{
    STKTrust *t = [user trustForUser:otherUser];
    if (t) {
        block(t, nil);
    }

    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            block(nil, err);
            return;
        }
        
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/exists", [user uniqueID], @"trusts", [otherUser uniqueID]]];
        
        [c setModelGraph:@[@"STKTrust"]];
        [c setExistingMatchMap:@{@"uniqueID" : @"_id"}];
        [c setContext:[self context]];
        
        [c getWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            if(err) {

            }
            block(obj, err);
        }];
    }];
    
}

- (void)updateInterestsforUser:(STKUser *)user completion:(void(^)(STKUser *u, NSError *err))block
{
    NSArray *interests = [user.interests allObjects];
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if (err) {
            block (nil, err);
            return;
        }
        
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[STKUserEndpointUser, [user uniqueID], @"interests"]];
        NSMutableArray *interestData = [NSMutableArray array];
        [interests enumerateObjectsUsingBlock:^(STKInterest *interest, NSUInteger idx, BOOL *stop) {
            [interestData addObject:interest.uniqueID];
        }];
        NSDictionary *dataDictionary = @{@"interests": interestData};
        [c addQueryValues:dataDictionary];
        [c setModelGraph:@[user]];
        [c setContext:[user managedObjectContext]];
        [c postWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            [[self context] save:nil];
            block(obj, err);
        }];
        
    }];
}

- (void)updateUserDetails:(STKUser *)user completion:(void (^)(STKUser *u, NSError *err))block
{
    
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            block(nil, err);
            return;
        }
        
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[STKUserEndpointUser, [user uniqueID]]];

        NSMutableDictionary *changedValues = [[user changedValues] mutableCopy];
        if ([changedValues objectForKey:@"organizations"]) {
            [changedValues removeObjectForKey:@"organizations"];
        }
        if([changedValues count] == 0) {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                block(user, nil);
            }];
            return;
        }
        
        NSDictionary *dataDict = [user remoteValueMapForLocalKeys:[changedValues allKeys]];
        [c addQueryValues:dataDict];
        
        [c setModelGraph:@[user]];
        [c setContext:[user managedObjectContext]];
        [c putWithSession:[self session] completionBlock:^(STKUser *user, NSError *err) {
            if(!err) {
                [[user managedObjectContext] save:nil];
                [[self context] save:nil];
            }
            block(user, err);
        }];
    }];
}

- (void)disableUser:(STKUser *)user completion:(void (^)(STKUser *u, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if(err) {
            block(nil, err);
            return;
        }
        
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[STKUserEndpointUser, [user uniqueID]]];
        [c setModelGraph:@[user]];
        [c setContext:[user managedObjectContext]];
        [c deleteWithSession:[self session] completionBlock:^(STKUser *user, NSError *err) {
            if(!err){
                [[user managedObjectContext] save:nil];
                [[self context] save:nil];
            }
            block(user, err);
        }];
        
    }];
}

- (void)setPushEnabled:(STKUser *)user completion:(void(^)(STKUser *u, NSError *err))block
{
    NSArray *identifiers = nil;
    identifiers = @[STKUserEndpointUser,[user uniqueID], @"push_enabled"];
    
    
    STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:identifiers];
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
        UIUserNotificationSettings *settings = [[UIApplication sharedApplication] currentUserNotificationSettings];
        UIUserNotificationType types = settings.types;
        if (types & UIUserNotificationTypeAlert) {
            [c addQueryValue:@"true" forKey:@"push_enabled"];
        } else {
            [c addQueryValue:@"false" forKey:@"push_enabled"];
        }
    } else {
        UIRemoteNotificationType types = [[UIApplication sharedApplication] enabledRemoteNotificationTypes];
        if ((types & UIRemoteNotificationTypeAlert)) {
            [c addQueryValue:@"true" forKey:@"push_enabled"];
        } else {
            [c addQueryValue:@"false" forKey:@"push_enabled"];
        }
    }
    [c setModelGraph:@[user]];
    [c
     postWithSession:[self session] completionBlock:^(id obj, NSError *err) {
         block(obj, err);
    }];

}


- (void)fetchUserDetails:(STKUser *)user additionalFields:(NSArray *)fields completion:(void (^)(STKUser *u, NSError *err))block
{
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"hasPurged"]) {
//        NSLog(@"Purging old org status");
        [self purgeOrgStatus];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"hasPurged"];
    }
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            block(nil, err);
            return;
        }
        
        NSArray *identifiers = nil;
         identifiers = @[STKUserEndpointUser,[user uniqueID]];
        
        
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:identifiers];
        if ([user.uniqueID isEqualToString:[self currentUser].uniqueID]) {
            [self setPushEnabled:user completion:^(STKUser *u, NSError *err) {
                if (err) NSLog(@"%@", err.localizedDescription);
            }];
                    }
        
        STKQueryObject *q = [[STKQueryObject alloc] init];
        
        
        [q setFields:fields];
        if(![[user uniqueID] isEqual:[[self currentUser] uniqueID]]) {
            [q addSubquery:[STKContainQuery containQueryForField:@"followers" key:@"_id" value:[[self currentUser] uniqueID]]];
            [q addSubquery:[STKContainQuery containQueryForField:@"following" key:@"_id" value:[[self currentUser] uniqueID]]];
            
            
            
            //[q addSubquery:[STKContainQuery containQueryForField:@"trusts" key:@"user_id" value:[[self currentUser] uniqueID]]];
//            [q addSubquery:[STKContainQuery containQueryForField:@"trusts" keyValues:@{@"from" : [[self currentUser] uniqueID], @"to" : [[self currentUser] uniqueID]}]];
        } else {
            [q setFormat:@"advanced"];
            [q addSubquery:[STKResolutionQuery resolutionQueryForField:@"interests"]];
            [q addSubquery:[STKResolutionQuery resolutionQueryForField:@"theme"]];
            [q addSubquery:[STKResolutionQuery resolutionQueryForField:@"organization"]];
            [q addSubquery:[STKResolutionQuery resolutionQueryForField:@"org_status.groups"]];
            [q addSubquery:[STKResolutionQuery resolutionQueryForField:@"org_status.organization"]];
            
        }
        
        [c setQueryObject:q];
        
        [c setModelGraph:@[user]];
        [c setResolutionMap:@{@"Interest": @"STKInterest", @"Theme": @"STKTheme", @"Organization": @"STKOrganization"}];
        [c setContext:[self context]];
        [c getWithSession:[self session] completionBlock:^(STKUser *user, NSError *err) {
            if(!err) {
                [[self context] save:nil];
            }
            if ([user.uniqueID isEqualToString:self.currentUser.uniqueID]) {
                [Heap identify:[user heapProperties]];
            }
            
            if ([user.uniqueID isEqualToString:[self.currentUser uniqueID]]) {
                if ([user.type isEqualToString:STKUserTypeInstitution]) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"UserDetailsUpdated" object:nil];
                }
                [user.organizations enumerateObjectsUsingBlock:^(STKOrgStatus *obj, BOOL *stop) {
                    if (obj.organization) {
                        [self fetchUserOrgs:^(NSArray *organizations, NSError *err) {
                            [[NSNotificationCenter defaultCenter] postNotificationName:@"UserDetailsUpdated" object:nil];
                        }];
                    } else {
                        [[NSNotificationCenter defaultCenter] postNotificationName:@"UserDetailsUpdated" object:nil];
                    }
                }];
            }
            block(user, err);
        }];
    }];
}



- (void)searchUsersWithType:(NSString *)type completion:(void (^)(NSArray *profiles, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            block(nil, err);
            return;
        }
        
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/search", @"users"]];
        
        STKQueryObject *q = [[STKQueryObject alloc] init];
        STKSearchQuery *sq = [STKSearchQuery searchQueryForField:@"subtype" value:type];
        STKContainQuery *cq = [STKContainQuery containQueryForField:@"followers" key:@"_id" value:[[self currentUser] uniqueID]];
        [q addSubquery:cq];
        [q addSubquery:sq];
        [c setQueryObject:q];
        
        [c setModelGraph:@[@"STKUser"]];
        
        [c setContext:[self context]];
        [c setExistingMatchMap:@{@"uniqueID" : @"_id"}];
        [c setShouldReturnArray:YES];
        [c getWithSession:[self session] completionBlock:^(NSArray *profiles, NSError *err) {
            if(!err) {
                block(profiles, nil);
            } else {
                block(nil, err);
            }
        }];
    }];
}

- (void)searchUsersWithName:(NSString *)name completion:(void (^)(NSArray *profiles, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            block(nil, err);
            return;
        }
        
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/search", @"users"]];

        STKQueryObject *q = [[STKQueryObject alloc] init];
        STKSearchQuery *sq = [STKSearchQuery searchQueryForField:@"name" value:name];
        STKContainQuery *cq = [STKContainQuery containQueryForField:@"followers" key:@"_id" value:[[self currentUser] uniqueID]];
        [q addSubquery:cq];
        [q addSubquery:sq];
        [c setQueryObject:q];
        
        [c setModelGraph:@[@"STKUser"]];
        [c setContext:[self context]];
        [c setExistingMatchMap:@{@"uniqueID" : @"_id"}];
        [c setShouldReturnArray:YES];
        [c getWithSession:[self session] completionBlock:^(NSArray *profiles, NSError *err) {
            if(!err) {
                
                block(profiles, nil);
            } else {
                block(nil, err);
            }
        }];
    }];
}

- (void)followUser:(STKUser *)user completion:(void (^)(id obj, NSError *err))block
{
    [[self currentUser] setFollowingCount:[[self currentUser] followingCount] + 1];
    [user setFollowerCount:[user followerCount] + 1];
    [[user mutableSetValueForKey:@"followers"] addObject:[self currentUser]];
    
    void (^reversal)(void) = ^{
        [[self currentUser] setFollowingCount:[[self currentUser] followingCount] - 1];
        [user setFollowerCount:[user followerCount] - 1];
        [[user mutableSetValueForKey:@"followers"] removeObject:[self currentUser]];
        [[self context] save:nil];
    };
    
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            reversal();
            
            block(nil, err);
            return;
        }
        
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[STKUserEndpointUser, [user uniqueID], @"follow"]];
        [c addQueryValue:[[self currentUser] uniqueID] forKey:@"creator"];
        [c postWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            if(err) {
                reversal();
            } else {
                [[self context] save:nil];
                
                [self trackFollow:user];
            }
            block(nil, err);
        }];
    }];
}

- (void)unfollowUser:(STKUser *)user completion:(void (^)(id obj, NSError *err))block
{
    [[self currentUser] setFollowingCount:[[self currentUser] followingCount] - 1];
    [[user mutableSetValueForKey:@"followers"] removeObject:[self currentUser]];
    [user setFollowerCount:[user followerCount] - 1];
    
    void (^reversal)(void) = ^{
        [[self currentUser] setFollowingCount:[[self currentUser] followingCount] + 1];
        [[user mutableSetValueForKey:@"followers"] addObject:[self currentUser]];
        [user setFollowerCount:[user followerCount] + 1];
        [[self context] save:nil];
    };

    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            reversal();
            
            block(nil, err);
            return;
        }
        
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[STKUserEndpointUser, [user uniqueID], @"unfollow"]];
        [c addQueryValue:[[self currentUser] uniqueID] forKey:@"creator"];
        [c postWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            if(err) {
                reversal();
            } else {
                [[self context] save:nil];
            }
            block(nil, err);
        }];
    }];
}

- (void)fetchFollowersOfUser:(STKUser *)user completion:(void (^)(NSArray *followers, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            block(nil, err);
            return;
        }
        
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[STKUserEndpointUser, [user uniqueID], @"followers"]];
        [c setModelGraph:@[@"STKUser"]];
        [c setContext:[self context]];
        [c setExistingMatchMap:@{@"uniqueID" : @"_id"}];
        STKResolutionQuery *q = [STKResolutionQuery resolutionQueryForField:@"followers"];
        [q setFormat:STKQueryObjectFormatShort];
        [q addSubquery:[STKContainQuery containQueryForField:@"followers" key:@"_id" value:[[self currentUser] uniqueID]]];
        [c setQueryObject:q];

        
        [c setResolutionMap:@{@"User" : @"STKUser"}];
        [c setShouldReturnArray:YES];

        [c getWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            if(!err) {
                [[self context] save:nil];
            }
            block(obj, err);
        }];
    }];
}

- (void)fetchUsersFollowingOfUser:(STKUser *)user completion:(void (^)(NSArray *followers, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            block(nil, err);
            return;
        }
        
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[STKUserEndpointUser, [user uniqueID], @"following"]];
        [c setModelGraph:@[@"STKUser"]];
        [c setContext:[self context]];
        [c setExistingMatchMap:@{@"uniqueID" : @"_id"}];

        
        STKResolutionQuery *q = [STKResolutionQuery resolutionQueryForField:@"following"];
        [q setFormat:STKQueryObjectFormatShort];
        
        [q addSubquery:[STKContainQuery containQueryForField:@"followers" key:@"_id" value:[[self currentUser] uniqueID]]];
        [c setQueryObject:q];

        [c setResolutionMap:@{@"User" : @"STKUser"}];
        [c setShouldReturnArray:YES];
        [c getWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            if(!err) {
                [[self context] save:nil];
            }

            block(obj, err);
        }];
    }];
}

- (void)requestTrustForUser:(STKUser *)user completion:(void (^)(STKTrust *requestItem, NSError *err))block
{
    NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"STKTrust"];
    NSPredicate *p = [NSPredicate predicateWithFormat:@"((creator == %@ and recepient == %@) or (creator == %@ and recepient == %@)) and status == %@",
                      [self currentUser], user, user, [self currentUser], STKRequestStatusCancelled];
    [req setPredicate:p];
    NSArray *results = [[self context] executeFetchRequest:req error:nil];
    
    BOOL wasInserted = NO;
    STKTrust *t = nil;
    if([results count] > 0) {
        t = [results firstObject];
        [t setStatus:STKRequestStatusPending];
        if(![[[t creator] uniqueID] isEqualToString:[[self currentUser] uniqueID]]) {
            STKUser *oldCreator = [t creator];
            [t setRecepient:oldCreator];
            [t setCreator:[self currentUser]];
        }
    } else {
        wasInserted = YES;
        t = [NSEntityDescription insertNewObjectForEntityForName:@"STKTrust"
                                                    inManagedObjectContext:[self context]];
        [t setStatus:STKRequestStatusPending];
        [t setCreator:[self currentUser]];
        [t setRecepient:user];
        
    }
    
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            block(nil, err);
            return;
        }
        
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[STKUserEndpointUser, [user uniqueID], @"trusts"]];
        [c addQueryValue:[[self currentUser] uniqueID] forKey:@"creator"];
        
        [c setModelGraph:@[t]];
        [c setContext:[self context]];
        [c postWithSession:[self session] completionBlock:^(STKTrust *trust, NSError *err) {
            if(err) {
                if(wasInserted)
                    [[self context] deleteObject:t];
            }
            [[self context] save:nil];
            
            block(trust, err);
        }];
    }];
}

- (void)fetchRequestsForCurrentUserWithFetchDescription:(STKFetchDescription *)fetchDescription completion:(void (^)(NSArray *requests, NSError *err))block
{
    if(![self currentUser]) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            block(nil, nil);
        }];
        return;
    }
    
    int fetchLimit = [fetchDescription limit];
    STKTrust *referenceRequest = [fetchDescription referenceObject];
    STKQueryObjectPage direction = [fetchDescription direction];
    
    if (fetchLimit == 0) {
        fetchLimit = 30;
    }
    
    NSArray *cached = nil;
    if(!referenceRequest) {
        NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"STKTrust"];
        [req setPredicate:[NSPredicate predicateWithFormat:@"recepient == %@", [self currentUser]]];
        [req setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"dateModified" ascending:NO]]];
        cached = [[self context] executeFetchRequest:req error:nil];
    } else {
        NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"STKTrust"];
        if (direction == STKQueryObjectPageNewer) {
            [req setPredicate:[NSPredicate predicateWithFormat:@"recepient == %@ and dateModified > %@", [self currentUser], [referenceRequest dateModified]]];
        } else {
            [req setPredicate:[NSPredicate predicateWithFormat:@"recepient == %@ and dateModified < %@", [self currentUser], [referenceRequest dateModified]]];
        }
        [req setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"dateModified" ascending:NO]]];
        cached = [[self context] executeFetchRequest:req error:nil];
    }
    
    if([cached count] > 0) {

        if (direction == STKQueryObjectPageOlder) {
            referenceRequest = [cached lastObject];
            
            // filter out canceled requests for cached response
            // we don't want to return a whole page of canceled responses from the cache
            cached = [cached filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"status != %@", STKRequestStatusCancelled]];

            if ([cached count] > fetchLimit) {
                cached = [cached subarrayWithRange:NSMakeRange([cached count] - fetchLimit, fetchLimit)];
            }
        } else {
            referenceRequest = [cached firstObject];
            
            // filter out canceled requests for cached response
            // we don't want to return a whole page of canceled responses from the cache
            cached = [cached filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"status != %@", STKRequestStatusCancelled]];

            if ([cached count] > fetchLimit) {
                cached = [cached subarrayWithRange:NSMakeRange(0, fetchLimit)];
            }
        }
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            block(cached, nil);
        }];
    }

    
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            block(nil, err);
            return;
        }
        
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[STKUserEndpointUser, [[self currentUser] uniqueID], @"trusts"]];
        
        STKQueryObject *q = [[STKQueryObject alloc] init];
        if(referenceRequest) {
            [q setPageValue:[STKTimestampFormatter stringFromDate:[referenceRequest dateModified]]];
        }
        [q setPageKey:@"modify_date"];
        [q setLimit:fetchLimit];
        [q setPageDirection:direction];
        
        [q addSubquery:[STKResolutionQuery resolutionQueryForField:@"from"]];
        [q setFilters:@{@"to" : [[self currentUser] uniqueID]}];
        [c setQueryObject:q];
        
        [c setModelGraph:@[@"STKTrust"]];
        [c setResolutionMap:@{@"User" : @"STKUser"}];
        [c setContext:[self context]];
        [c setShouldReturnArray:YES];
        [c setExistingMatchMap:@{@"uniqueID" : @"_id"}];
        [c getWithSession:[self session] completionBlock:^(NSArray *trusts, NSError *err) {
            if(!err) {
                [[self context] save:nil];
                NSPredicate *p = [NSPredicate predicateWithFormat:@"recepient == %@", [self currentUser]];
                NSArray *filtered = [trusts filteredArrayUsingPredicate:p];
                block(filtered, err);
            } else {
                block(nil, err);
            }
        }];
    }];

}

- (void)acceptTrustRequest:(STKTrust *)t completion:(void (^)(STKTrust *requestItem, NSError *err))block
{
    [t setStatus:STKRequestStatusAccepted];
    
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            [t setStatus:STKRequestStatusPending];
            block(nil, err);
            return;
        }
       
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/trusts", [t uniqueID]]];
        [c addQueryValue:STKRequestStatusAccepted forKey:@"status"];
        
        [c setModelGraph:@[t]];
        [c setContext:[self context]];
        
        [c putWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            if(err) {
                [t setStatus:STKRequestStatusPending];
            } else {
                [[self context] save:nil];
                
                // if the current user is not an institution and the requesting user is, then update
                // the current users subtype to luminary
                if(![[self currentUser] isInstitution] && [[t otherUser] isInstitution]) {
                    [[self currentUser] setSubtype:STKUserSubTypeLuminary];
                }
            }
            block(obj, err);
        }];
    }];
    
}

- (void)rejectTrustRequest:(STKTrust *)t completion:(void (^)(STKTrust *requestItem, NSError *err))block
{
    NSString *prevState = [t status];
    [t setStatus:STKRequestStatusCancelled];
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            [t setStatus:prevState];
            block(nil, err);
            return;
        }
        
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/trusts", [t uniqueID]]];

        [c addQueryValue:STKRequestStatusCancelled forKey:@"status"];
        
        [c setModelGraph:@[t]];
        [c setContext:[self context]];

        [c putWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            if(err) {
                [t setStatus:prevState];
            } else {
                [[self context] save:nil];
            }
            block(obj, err);
        }];
    }];
}

- (void)cancelTrustRequest:(STKTrust *)t completion:(void (^)(STKTrust *requestItem, NSError *err))block
{
    NSString *prevState = [t status];
    [t setStatus:STKRequestStatusCancelled];
    
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            [t setStatus:prevState];
            block(nil, err);
            return;
        }
        
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/trusts", [t uniqueID]]];
        [c addQueryValue:STKRequestStatusCancelled forKey:@"status"];
        
        [c setModelGraph:@[t]];
        [c setContext:[self context]];

        [c putWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            if(err) {
                [t setStatus:prevState];
            }
            block(obj, err);
        }];
    }];

}

- (void)submitParentConsent:(NSDictionary *)parent forUser:(STKUser *)user completion:(void(^)(STKUser *user, NSError *err))block {
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            block(nil, err);
            return;
        }
        
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/users", [user uniqueID], @"consent"]];
        [c addQueryValues:parent];
        [c setModelGraph:@[user]];
        [c setContext:[self context]];
        [c putWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            block(obj, err);
        }];
        
    }];
}

- (void)updateTrust:(STKTrust *)t toType:(NSString *)type completion:(void (^)(STKTrust *requestItem, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            block(nil, err);
            return;
        }
        
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/trusts", [t uniqueID]]];
        [c addQueryValue:type forKey:@"type"];
        
        [c setModelGraph:@[t]];
        [c setContext:[self context]];

        [c putWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            block(obj, err);
        }];
    }];
    
}

- (void)fetchTopTrustsForUser:(STKUser *)u completion:(void (^)(NSArray *trusts, NSError *err))block
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"STKTrust"];
    
    NSSortDescriptor *toSort = [NSSortDescriptor sortDescriptorWithKey:@"recepientScore" ascending:NO];
    NSSortDescriptor *fromSort = [NSSortDescriptor sortDescriptorWithKey:@"creatorScore" ascending:NO];
    [request setFetchLimit:5];
    [request setPredicate:[NSPredicate predicateWithFormat:@"status == %@ && (recepient == %@ || creator == %@)", STKRequestStatusAccepted, u, u]];
    
    [request setSortDescriptors:@[toSort]];
    NSArray *to = [[self context] executeFetchRequest:request error:nil];
    [request setSortDescriptors:@[fromSort]];
    NSArray *from = [[self context] executeFetchRequest:request error:nil];
    
    NSMutableSet *all = [NSMutableSet set];
    [all addObjectsFromArray:to];
    [all addObjectsFromArray:from];
    NSArray *allArray = [[all allObjects] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"otherScore" ascending:NO]]];
    if ([allArray count]) {
        block(allArray,nil);
    }
    
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if(err) {
            block(nil, err);
            return;
        }
        
        STKFetchDescription *fdFrom = [[STKFetchDescription alloc] init];
        [fdFrom setLimit:5];
        [fdFrom setFilterDictionary:@{@"recepient" : [u uniqueID], @"status" : STKRequestStatusAccepted}];
        [fdFrom setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"from_score" ascending:NO]]];
        [self fetchTrustsForUserInternal:u fetchDescription:fdFrom completion:^(NSArray *fromTrusts, NSError *fromErr) {
            STKFetchDescription *fdTo = [[STKFetchDescription alloc] init];
            [fdTo setLimit:5];
            [fdTo setFilterDictionary:@{@"creator" : [u uniqueID], @"status" : STKRequestStatusAccepted}];
            [fdTo setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"to_score" ascending:NO]]];
            
            [self fetchTrustsForUserInternal:u fetchDescription:fdTo completion:^(NSArray *toTrusts, NSError *toErr) {
                if (!toErr) {
                    NSMutableArray *all = [[NSMutableArray alloc] init];
                    [all addObjectsFromArray:fromTrusts];
                    [all addObjectsFromArray:toTrusts];
                    [all sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"otherScore" ascending:NO]]];
                    block(all, nil);
                } else {
                    block(nil, toErr);
                }
            }];
        }];
    }];
}

- (void)fetchTrustsForUser:(STKUser *)u fetchDescription:(STKFetchDescription *)fetchDescription completion:(void (^)(NSArray *trusts, NSError *err))block
{
    NSMutableArray *predicates = [[NSMutableArray alloc] init];
    NSPredicate *predicate;
    if ([fetchDescription filterDictionary]) {
        for (NSString *key in [fetchDescription filterDictionary]) {
            [predicates addObject:[NSPredicate predicateWithFormat:@"%K == %@ && (recepient == %@ || creator == %@)", key, [fetchDescription filterDictionary][key], u, u]];
        }
        predicate = [NSCompoundPredicate andPredicateWithSubpredicates:predicates];
    }
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"STKTrust"];
    NSArray *trusts = [[self context] executeFetchRequest:request error:nil];
    if (predicate) {
        trusts = [trusts filteredArrayUsingPredicate:predicate];
    }
    block(trusts, nil);
    
    [self fetchTrustsForUserInternal:u fetchDescription:fetchDescription completion:block];
}

- (void)fetchTrustsForUserInternal:(STKUser *)u fetchDescription:(STKFetchDescription *)fetchDescription completion:(void (^)(NSArray *trusts, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if(err) {
            block(nil, err);
            return;
        }
        
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[STKUserEndpointUser, [u uniqueID], @"trusts"]];
        
        STKQueryObject *q = [[STKQueryObject alloc] init];
        NSMutableDictionary *filters = [[NSMutableDictionary alloc] init];
        for(NSString *key in [fetchDescription filterDictionary]) {
            [filters setObject:[[fetchDescription filterDictionary] objectForKey:key] forKey:[STKTrust remoteKeyForLocalKey:key]];
        }
        [q setFilters:filters];
        
        if([fetchDescription limit])
            [q setLimit:[fetchDescription limit]];
        
        if([[fetchDescription sortDescriptors] count] > 0) {
            [q setSortKey:[[[fetchDescription sortDescriptors] firstObject] key]];
            [q setSortOrder:([[[fetchDescription sortDescriptors] firstObject] ascending] ? STKQueryObjectSortAscending : STKQueryObjectSortDescending)];
        }
        
        STKResolutionQuery *fq = [STKResolutionQuery resolutionQueryForField:@"from"];
        [fq setFields:@[@"create_date", @"email"]];
        STKResolutionQuery *tq = [STKResolutionQuery resolutionQueryForField:@"to"];
        [tq setFields:@[@"create_date", @"email"]];
        
        [q addSubquery:fq];
        [q addSubquery:tq];
        [c setQueryObject:q];
        
        [c setModelGraph:@[@"STKTrust"]];
        [c setContext:[self context]];
        [c setExistingMatchMap:@{@"uniqueID" : @"_id"}];
        [c setShouldReturnArray:YES];
        [c setResolutionMap:@{@"User" : @"STKUser"}];
        [c getWithSession:[self session] completionBlock:^(NSArray *trusts, NSError *err) {
            if(!err) {
                [[self context] save:nil];
            }
            block(trusts, err);
        }];
    }];
}

- (void)fetchSuggestionsForUser:(STKUser *)user completion:(void(^)(NSArray *users, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if (err) {
            block(nil, err);
            return;
        }
        STKConnection *conn = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/users", user.uniqueID, @"suggestions"]];
        [conn setModelGraph:@[@"STKUser"]];
        [conn setContext:[self context]];
        [conn setExistingMatchMap:@{@"uniqueID": @"_id"}];
        [conn setShouldReturnArray:YES];
        [conn getWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            block(obj, err);
        }];
    }];
}

- (void)searchUserTrustsWithName:(NSString *)name completion:(void (^)(id data, NSError *error))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if(err){
            block(nil, err);
            return;
        }
        
        STKConnection *conn = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/search", [[self currentUser] uniqueID], @"trusts", name]];
        [conn setModelGraph:@[@"STKUser"]];
        [conn setContext:[self context]];
        [conn setExistingMatchMap:@{@"uniqueID" : @"_id"}];
        [conn setShouldReturnArray:YES];
        [conn getWithSession:[self session] completionBlock:^(NSArray *users, NSError *err) {
            block(users, err);
        }];
    }];
}

- (void)searchUserNotInTrustWithName:(NSString *)name completion:(void (^)(id data, NSError *error))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if(err){
            block(nil, err);
            return;
        }
        
        STKConnection *conn = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/search", [[self currentUser] uniqueID], @"invite", name]];
        [conn setModelGraph:@[@"STKUser"]];
        [conn setContext:[self context]];
        [conn setExistingMatchMap:@{@"uniqueID" : @"_id"}];
        [conn setShouldReturnArray:YES];
        [conn getWithSession:[self session] completionBlock:^(NSArray *users, NSError *err) {
            NSMutableArray *mUsers = [users mutableCopy];
            [mUsers removeObject:[self currentUser]];
            block(mUsers, err);
        }];
    }];
}

- (void)fetchActivityForUser:(STKUser *)u fetchDescription:(STKFetchDescription *)fetchDescription completion:(void (^)(NSArray *activities, NSError *err))block
{
    int fetchLimit = [fetchDescription limit];
    STKActivityItem *referenceActivity = [fetchDescription referenceObject];
    STKQueryObjectPage direction = [fetchDescription direction];
    
    if (fetchLimit == 0) {
        fetchLimit = 20;
    }

    NSArray *cached = nil;
    if(!referenceActivity) {
        NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"STKActivityItem"];
        [req setPredicate:[NSPredicate predicateWithFormat:@"(notifiedUser == %@) AND (post != nil || comment != nil || insight != nil || action == %@)", u, @"group_joined"]];
        [req setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"dateCreated" ascending:NO]]];
        [req setFetchLimit:fetchLimit];
        cached = [[self context] executeFetchRequest:req error:nil];
    } else {
        NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"STKActivityItem"];
        if (direction == STKQueryObjectPageNewer) {
            [req setPredicate:[NSPredicate predicateWithFormat:@"notifiedUser == %@ and dateCreated > %@ and (post != nil || comment != nil || insight != nil || action == %@)", u, [referenceActivity dateCreated], @"group_joined"]];
        } else {
            [req setPredicate:[NSPredicate predicateWithFormat:@"notifiedUser == %@ and dateCreated < %@ and (post != nil || comment != nil || insight != nil || action == %@)", u, [referenceActivity dateCreated], @"group_joined"]];
        }
        [req setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"dateCreated" ascending:NO]]];
        [req setFetchLimit:fetchLimit];
        cached = [[self context] executeFetchRequest:req error:nil];
    }
    

    if([cached count] > 0) {
        if (direction == STKQueryObjectPageOlder) {
            referenceActivity = [cached lastObject];
        } else {
            referenceActivity = [cached firstObject];
        }
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            block(cached, nil);
        }];
    }

    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            block(nil, err);
            return;
        }
        
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[STKUserEndpointUser, [[self currentUser] uniqueID], @"activites"]];
        
        STKQueryObject *q = [[STKQueryObject alloc] init];
        
        if(referenceActivity) {
            [q setPageValue:[STKTimestampFormatter stringFromDate:[referenceActivity dateCreated]]];
        }
        [q setPageDirection:direction];
        [q setPageKey:@"create_date"];
        [q setLimit:fetchLimit];
        
        [q addSubquery:[STKResolutionQuery resolutionQueryForField:@"from"]];
        STKResolutionQuery *postResolve = [STKResolutionQuery resolutionQueryForField:@"post_id"];
        
        [postResolve addSubquery:[STKContainQuery containQueryForField:@"likes" key:@"_id" value:[[self currentUser] uniqueID]]];
        [q addSubquery:postResolve];
        STKResolutionQuery *insightTargetResolve = [STKResolutionQuery resolutionQueryForField:@"insight_target_id"];
        STKResolutionQuery *insightResolve = [STKResolutionQuery resolutionQueryForField:@"insight_id"];
//        [insightTargetResolve addSubquery:[STKResolutionQuery resolutionQueryForField:@"insight"]];
        [q addSubquery:insightTargetResolve];
        [q addSubquery:insightResolve];
        
        [q addSubquery:[STKResolutionQuery resolutionQueryForField:@"comment_id"]];
        
        [c setQueryObject:q];
        
        [c setModelGraph:@[@"STKActivityItem"]];
        [c setShouldReturnArray:YES];
        [c setContext:[self context]];
        [c setExistingMatchMap:@{@"uniqueID" : @"_id"}];
        [c setResolutionMap:@{@"User" : @"STKUser", @"Post" : @"STKPost", @"Comment" : @"STKComment", @"InsightTarget": @"STKInsightTarget", @"Insight": @"STKInsight"}];
        
        [c getWithSession:[self session] completionBlock:^(NSArray *obj, NSError *err) {
            if(!err) {
                [[self context] save:nil];
            }
            block(obj, err);
        }];
    }];
}

- (void)fetchGraphDataForWeek:(int)week inYear:(int)year previousWeekCount:(int)count completion:(void (^)(NSDictionary *weeks, NSError *err))block
{
    if(week <= 0) {
        week = 52 + week;
        year --;
    }
    
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            block(nil, err);
            return;
        }
        
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[STKUserEndpointUser, [[self currentUser] uniqueID], @"stats", @"category"]];
        
        
        STKQueryObject *obj = [[STKQueryObject alloc] init];
        [obj setFilters:@{@"year" : @(year),
                          @"week" : @(week),
                          @"offset" : @(count)}];
        [c setQueryObject:obj];        
        [c getWithSession:[self session] completionBlock:^(NSDictionary *obj, NSError *err) {
            
            block(obj, err);
        }];
    }];
}
- (void)fetchLifetimeGraphDataWithCompletion:(void (^)(NSDictionary *data, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            block(nil, err);
            return;
        }
        
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[STKUserEndpointUser, [[self currentUser] uniqueID], @"stats", @"category"]];
        
        [c getWithSession:[self session] completionBlock:^(NSDictionary *obj, NSError *err) {

            block(obj, err);
        }];
    }];
}

- (void)fetchHashtagsForPostTypesWithCompletion:(void (^)(NSDictionary *hashTags, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            block(nil, err);
            return;
        }
        
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[STKUserEndpointUser, [[self currentUser] uniqueID], @"stats", @"hashtags"]];
        
        [c getWithSession:[self session] completionBlock:^(NSDictionary *obj, NSError *err) {
            
            block(obj, err);
        }];
    }];

}

- (void)fetchPendingSurveysForUser:(STKUser *) user completion:(void (^)(NSArray * surveys, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if (err) {
            block (nil, err);
            return;
        }
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/users", user.uniqueID, @"surveys"]];
        [c setModelGraph:@[@"STKSurvey"]];
        [c setExistingMatchMap:@{@"uniqueID": @"_id"}];
        [c setShouldReturnArray:YES];
        [c setContext:[self context]];
        [c getWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            NSLog(@"%@", obj);
            block(obj, err);
        }];
    }];
}

- (void)submitSurveyAnswerForUser:(STKUser *)user question:(STKQuestion *)q value:(NSInteger)v completion:(void (^)(STKQuestion * question, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if (err) {
            block (nil, err);
            return;
        }
        
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/surveys", q.survey.uniqueID, @"questions", q.uniqueID]];
        NSLog(@"%ld", (long)v);
        [c addQueryValues:@{@"answer_value": [NSNumber numberWithInteger:v], @"uid": user.uniqueID}];
   
        [c setModelGraph:@[@"STKQuestion"]];
        [c setExistingMatchMap:@{@"uniqueID": @"_id"}];
        [c setShouldReturnArray:YES];
        [c setContext:[self context]];
        [c postWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            NSLog(@"%@", obj);
            block(obj, err);
        }];
    }];
}

- (void)finalizeSurveyForUser:(STKUser *)user survey:(STKSurvey *)s completion:(void (^)(STKSurvey * survey, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if (err) {
            block (nil, err);
            return;
        }
        
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/surveys", s.uniqueID, @"finalize"]];
        [c addQueryValue:user.uniqueID forKey:@"uid"];
        [c setModelGraph:@[@"STKSurvey"]];
        [c setExistingMatchMap:@{@"uniqueID": @"_id"}];
        [c setShouldReturnArray:YES];
        [c setContext:[self context]];
        [c postWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            NSLog(@"%@", obj);
            block(obj, err);
        }];
    }];
}

- (NSArray *)fetchLeaderboardForOrganization:(STKOrganization *)organization completion:(void(^)(NSArray * leaders, NSError *err))block
{
    NSMutableArray *cached = [NSMutableArray array];
    NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName:@"STKLeaderboardItem"];
    NSPredicate *p = [NSPredicate predicateWithFormat:@"organization.uniqueID == %@", organization.uniqueID];
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"points" ascending:NO];
    [fr setPredicate:p];
    [fr setSortDescriptors:@[sort]];
    [cached addObjectsFromArray:[[self context] executeFetchRequest:fr error:nil]];
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if (err) {
            block (nil, err);
            return;
        }
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/organizations", organization.uniqueID, @"surveys", @"leaderboard"]];
        [c setModelGraph:@[@"STKLeaderboardItem"]];
        [c setExistingMatchMap:@{@"userID": @"_id"}];
        [c setShouldReturnArray:YES];
        [c setContext:[self context]];
        [c getWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            block(obj, err);
        }];
        
    }];
    return cached;
}

- (void)fetchCompletedSurveysForUser:(STKUser *)user organization:(STKOrganization *)org completion:(void(^)(NSArray * surveys, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if (err) {
            block (nil, err);
            return;
        }
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/users", user.uniqueID, @"surveys", @"completed"]];
        [c addQueryValue:org.uniqueID forKey:@"organization"];
        [c setModelGraph:@[@"STKSurvey"]];
        [c setExistingMatchMap:@{@"uniqueID": @"_id"}];
        [c setShouldReturnArray:YES];
        [c setContext:[self context]];
        [c getWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            block(obj, err);
        }];
        
    }];
}

- (void)fetchLatestSurveyForOrganization:(STKOrganization *)org completion:(void(^)(STKSurvey *survey, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if (err) {
            block (nil, err);
            return;
        }
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/organizations", org.uniqueID, @"surveys", @"latest"]];
        [c setModelGraph:@[@"STKSurvey"]];
        [c setExistingMatchMap:@{@"uniqueID": @"_id"}];
        [c setShouldReturnArray:NO];
        [c setContext:[self context]];
        [c getWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            block(obj, err);
        }];
        
    }];
}

- (void)fetchInterests:(void (^)(NSArray * interests, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if (err) {
            block (nil, err);
            return;
        }
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/interests"]];
        STKQueryObject *q = [[STKQueryObject alloc] init];
        [q setLimit:200];

        STKResolutionQuery *rq = [STKResolutionQuery resolutionQueryForField:@"subinterests"];
        [rq setField:@"subinterests"];
        [rq setFormat:@"basic"];
        [q addSubquery:rq];
        [c setQueryObject:q];
        [c setModelGraph:@[@"STKInterest"]];
        [c setExistingMatchMap:@{@"uniqueID": @"_id"}];
        [c setResolutionMap:@{@"Interest": @"STKInterest"}];
        [c setShouldReturnArray:YES];
        [c setContext:[self context]];
        [c getWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            block(obj, err);
        }];
        
    }];
}

- (void)fetchUnreadCountForOrganization:(STKOrganization *)organization group:(STKGroup *)group completion:(void (^)(id obj, NSError *err))block

{
    __block STKUser *u = [[STKUserStore store] currentUser];
    if (organization) {
        [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
            if (err) {
                block(nil, err);
                return;
            }
            NSString *obj = @"all";
            
            if (group) obj = group.uniqueID;
            STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/organizations", organization.uniqueID, @"groups", obj, @"messages"]];
            [c addQueryValue:u.uniqueID forKey:@"requestor"];
            [c addQueryValue:@"unread" forKey:@"action"];
            if (group) {
                [c setModelGraph:@[@"STKGroup"]];
            } else {
                [c setModelGraph:@[@"STKOrganization"]];
            }
            [c setExistingMatchMap:@{@"uniqueID": @"_id"}];
            [c setContext:[self context]];
            //            [c setShouldReturnArray:YES];
            [c setShouldReturnArray:YES];
            [c getWithSession:[self session] completionBlock:^(id obj, NSError *err) {
                block(obj, err);
            }];
        }];
    } else {
        block(nil, nil);
    }
}


- (NSArray *)fetchUserOrgs:(void (^)(NSArray *organizations, NSError *err))block
{
    STKUser *u = [self currentUser];
    NSMutableArray *cached = [NSMutableArray array];
    if ([u.type isEqualToString:@"institution_verified"]) {
        NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName:@"STKOrganization"];
        NSPredicate *p = [NSPredicate predicateWithFormat:@"owner.uniqueID == %@", u.uniqueID];
        NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES];
        [fr setPredicate:p];
        [fr setSortDescriptors:@[sort]];
        [cached addObjectsFromArray:[[self context] executeFetchRequest:fr error:nil]];
    } else {
        [u.organizations enumerateObjectsUsingBlock:^(STKOrgStatus *obj, BOOL *stop) {
            if ([obj.status isEqualToString:@"active"]) {
                [cached addObject:obj.organization];
            }
        }];
    }
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if (err) {
            block(nil, err);
            return;
        }
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/users", u.uniqueID, @"organizations"]];
        STKQueryObject *q = [[STKQueryObject alloc] init];
        [c setQueryObject:q];
        [c setModelGraph:@[@"STKOrganization"]];
        [c setExistingMatchMap:@{@"uniqueID": @"_id"}];
        [c setContext:[self context]];
        //            [c setShouldReturnArray:YES];
        [c setShouldReturnArray:YES];
        [c getWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            block(obj, err);
        }];
    }];
    return cached;
}

- (NSArray *)fetchGroupsForOrganization:(STKOrganization *)org completion:(void (^)(NSArray *groups, NSError *err))block
{
    STKUser *user = [self currentUser];
    __block NSArray *cached = [NSArray array];
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES];
    if ([user.type isEqualToString:@"institution_verified"]) {
        NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName:@"STKGroup"];
        NSPredicate *p = [NSPredicate predicateWithFormat:@"organization.uniqueID == %@ && status != %@", org.uniqueID, @"inactive"];
        [fr setPredicate:p];
        [fr setSortDescriptors:@[sort]];
        cached = [[self context] executeFetchRequest:fr error:nil];
    } else {
        [user.organizations enumerateObjectsUsingBlock:^(STKOrgStatus *obj, BOOL *stop) {
            if ([obj.organization.uniqueID isEqualToString:org.uniqueID] && [obj.status isEqualToString:@"active"]) {
                cached = [[obj.groups filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"name!=nil && status!=%@", @"inactive"]] allObjects];
                cached = [cached sortedArrayUsingDescriptors:@[sort]];
                *stop = YES;
            }
        }];
    }
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if (err) {
            block(nil, err);
            return;
        }
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/users", user.uniqueID, @"organizations", org.uniqueID, @"groups"]];
        STKQueryObject *q = [[STKQueryObject alloc] init];
        [c setQueryObject:q];
        [c setModelGraph:@[@"STKGroup"]];
        [c setExistingMatchMap:@{@"uniqueID": @"_id"}];
        [c setContext:[self context]];
        //            [c setShouldReturnArray:YES];
        [c setShouldReturnArray:YES];
        [c getWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            block(obj, err);
        }];
    }];
    return cached;
}

- (void)fetchUpdatedMessagesForOrganization:(STKOrganization *)organization group:(STKGroup *)group completion:(void (^)(NSArray *messages, NSError *err))block
{
    if (organization) {
        NSDate *date = [[NSUserDefaults standardUserDefaults] objectForKey:@"lastMessageUpdate"];
        if (!date) date = [NSDate dateWithTimeIntervalSince1970:0];
        [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
            if (err) {
                block(nil, err);
                return;
            }
            NSString *obj = @"all";
            if (group) obj = group.uniqueID;
            NSTimeZone *timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
            // or specifc Timezone: with name
            STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/organizations", organization.uniqueID, @"groups", obj, @"messages"]];
            if (date) {
                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                [dateFormatter setTimeZone:timeZone];
                [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
                
                NSString *localDateString = [dateFormatter stringFromDate:date];
                [c addQueryValue:localDateString forKey:@"updated"];
            }
            [c addQueryValue:self.currentUser.uniqueID forKey:@"requestor"];
            [c setModelGraph:@[@"STKMessage"]];
            [c setExistingMatchMap:@{@"uniqueID": @"_id"}];
            [c setContext:[self context]];
            //            [c setShouldReturnArray:YES];
            [c setShouldReturnArray:YES];
            [c getWithSession:[self session] completionBlock:^(id obj, NSError *err) {
                [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:@"lastMessageUpdate"];
                block(obj, err);
            }];
        }];
    } else {
        block(nil, nil);
    }
}

- (NSArray *)fetchMessagesForOrganization:(STKOrganization *)organization group:(STKGroup *)group completion:(void (^)(NSArray *messages, NSError *err))block
{
    NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName:@"STKMessage"];
    NSPredicate *p = [NSPredicate predicateWithFormat:@"organization.uniqueID == %@ && group.uniqueID == %@", organization.uniqueID, group.uniqueID];
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"createDate" ascending:YES];
    [fr setPredicate:p];
    [fr setSortDescriptors:@[sort]];
    NSArray *cached = nil;
    cached = [[self context] executeFetchRequest:fr error:nil];
    NSDate *date = nil;
    if (cached.count > 0) {
//        STKMessage *lastMessage = [cached lastObject];
//        date = [lastMessage createDate];
    }
    [self fetchUpdatedMessagesForOrganization:organization group:group completion:^(NSArray *messages, NSError *err) {
        [self fetchLatestMessagesForOrganization:organization group:group user:nil date:date completion:^(NSArray *messages, NSError *err) {
            block(messages, err);
        }];
    }];
//    return @[];
    return cached;
}

- (NSFetchedResultsController *)fetchMessagesForOrganization:(STKOrganization *)organization group:(STKGroup *)group user:(STKUser *)user completion:(void (^)(NSArray *messages, NSError *err))block
{
    NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName:@"STKMessage"];
    NSPredicate *p = nil;
    if (user) {
        p = [NSPredicate predicateWithFormat:@"(target.uniqueID == %@ && creator.uniqueID == %@) || (target.uniqueID == %@ && creator.uniqueID == %@)", [self.currentUser uniqueID], user.uniqueID, user.uniqueID, [self.currentUser uniqueID]];
    } else {
       p = [NSPredicate predicateWithFormat:@"organization.uniqueID == %@ && group.uniqueID == %@ && target == nil", organization.uniqueID, group.uniqueID];
    }
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"createDate" ascending:YES];
    [fr setPredicate:p];
    [fr setSortDescriptors:@[sort]];
    [NSFetchedResultsController deleteCacheWithName:@"Messages"];
    NSFetchedResultsController *fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fr managedObjectContext:self.context sectionNameKeyPath:nil cacheName:@"Messages"];

    NSArray *cached = nil;
    cached = [[self context] executeFetchRequest:fr error:nil];
    NSDate *date = nil;
    if (cached.count > 0) {
        //        STKMessage *lastMessage = [cached lastObject];
        //        date = [lastMessage createDate];
    }
    [self fetchUpdatedMessagesForOrganization:organization group:group  completion:^(NSArray *messages, NSError *err) {
        [self fetchLatestMessagesForOrganization:organization group:group user:user date:date completion:^(NSArray *messages, NSError *err) {
            block(messages, err);
        }];
    }];
    //    return @[];
    return fetchedResultsController;
}

- (void)editMessage:(STKMessage *)message completion:(void (^)(STKMessage *message, NSError *err))block{
    NSString *obj = @"all";
    if (message.group) obj = message.group.uniqueID;
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if (err) {
            block(nil, err);
            return;
        }
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/organizations", message.organization.uniqueID, @"groups", obj, @"messages", message.uniqueID]];
        [c addQueryValue:message.text forKey:@"text"];
        [c setModelGraph:@[@"STKMessage"]];
        [c setExistingMatchMap:@{@"uniqueID": @"_id"}];
        [c setContext:[self context]];
        [c setShouldReturnArray:NO];
        [c putWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            if (obj) {
                [self.context save:nil];
            }
            block(obj, err);
        }];
        
    }];
}

- (void)deleteMessage:(STKMessage *)message completion:(void (^)(NSError *err))block
{
    NSString *obj = @"all";
    if (message.group) obj = message.group.uniqueID;
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if (err) {
            block(err);
            return;
        }
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/organizations", message.organization.uniqueID, @"groups", obj, @"messages", message.uniqueID]];
        [c setContext:[self context]];
        [c setShouldReturnArray:NO];
        [c deleteWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            [self.context deleteObject:message];
            NSError *error;
            [self.context save:&error];
            block(err);
        }];
        
    }];
}

- (NSArray *)getMembersForOrganization:(STKOrganization *)organization group:(STKGroup *)group
{
    NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName:@"STKOrgStatus"];
    NSPredicate *p = [NSPredicate predicateWithFormat:@"organization.uniqueID == %@ && status == %@ && member.active == YES", organization.uniqueID, @"active"];
    [fr setPredicate:p];
    NSArray *cached = nil;
    cached = [[self context] executeFetchRequest:fr error:nil];
    if (group) {
        cached = [cached filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(STKOrgStatus *obj, NSDictionary *bindings) {
            __block BOOL match = false;
           
                [obj.groups enumerateObjectsUsingBlock:^(STKGroup *g, BOOL *stop) {
                    if ([group.uniqueID isEqualToString:g.uniqueID]) {
                        match = YES;
                        *stop = YES;
                        
                    }
                 
                }];
           
            return match;
        }]];
    }
    cached = [cached sortedArrayWithOptions:NSSortConcurrent usingComparator:^NSComparisonResult(STKOrgStatus *obj1, STKOrgStatus *obj2) {
        return [obj1.member.name compare:obj2.member.name];
    }];
    return cached;
}

- (NSArray *)fetchMessagedUsers
{
    NSFetchRequest *fr = [[NSFetchRequest alloc] init];
    [fr setEntity:[NSEntityDescription entityForName:@"STKMessage" inManagedObjectContext:self.context]];
    [fr setIncludesPropertyValues:YES];
    STKOrganization *org = [self activeOrgForUser];
    NSPredicate *sp = nil;
    if ([self.currentUser.type isEqualToString:STKUserTypeInstitution]) {
        sp = [NSPredicate predicateWithFormat:@"(creator.uniqueID == %@ || target.uniqueID == %@) && target != nil", self.currentUser.uniqueID, self.currentUser.uniqueID, org.uniqueID];
    } else {
       sp = [NSPredicate predicateWithFormat:@"(creator.uniqueID == %@ || target.uniqueID == %@) && target != nil && organization.uniqueID == %@", self.currentUser.uniqueID, self.currentUser.uniqueID, org.uniqueID];
    }
    [fr setPredicate:sp];
    NSSortDescriptor *sd = [[NSSortDescriptor alloc] initWithKey:@"createDate" ascending:NO];
    [fr setSortDescriptors:@[sd]];
    NSError *error = nil;
    NSArray *messages = [self.context executeFetchRequest:fr error:&error];
    NSMutableArray *users = [NSMutableArray array];
    if (messages) {
        [messages enumerateObjectsUsingBlock:^(STKMessage *message, NSUInteger idx, BOOL *stop) {
            if ([message.creator.uniqueID isEqualToString:self.currentUser.uniqueID]) {
                if (![users containsObject:message.target]) {
                    [users addObject:message.target];
                }
            } else if ([message.target.uniqueID isEqualToString:self.currentUser.uniqueID]){
                if (! [users containsObject:message.creator]) {
                    [users addObject:message.creator];
                }
            }
        }];
    }
    return users;
}

- (void)fetchUnreadMessageDigestForUser:(STKUser *)user completion:(void (^)(NSArray *messages, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if (err) {
            block(nil, err);
            return;
        }
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/users", user.uniqueID ,@"messages", @"digest"]];
        [c setModelGraph:@[@"STKMessage"]];
        [c setExistingMatchMap:@{@"uniqueID": @"_id"}];
        [c setContext:[self context]];
        [c setShouldReturnArray:YES];
        [c setShouldReturnArray:YES];
        [c getWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            block(obj, err);
        }];
    }];
}

- (void)purgeOrgStatus
{
    NSFetchRequest * os = [[NSFetchRequest alloc] init];
    [os setEntity:[NSEntityDescription entityForName:@"STKOrgStatus" inManagedObjectContext:self.context]];
    [os setIncludesPropertyValues:NO]; //only fetch the managedObjectID
    
    NSError * error = nil;
    NSArray * status = [self.context executeFetchRequest:os error:&error];
 
    for (NSManagedObject * o in status) {
        [self.context deleteObject:o];
    }
    NSError *saveError = nil;
    [self.context save:&saveError];
}

- (void)fetchMembersForOrganization:(STKOrganization *)organization completion:(void (^)(NSArray *messages, NSError *err))block
{
    if (organization) {
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if (err) {
            block(nil, err);
            return;
        }
 
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/organizations", organization.uniqueID, @"members"]];
        STKQueryObject *q = [[STKQueryObject alloc] init];
        [c setQueryObject:q];
        [c setModelGraph:@[@"STKUser"]];
        [c setExistingMatchMap:@{@"uniqueID": @"_id"}];
        [c setContext:[self context]];
        [c setShouldReturnArray:YES];
        [c getWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            [self.context save:nil];
            block(obj, err);
        }];
    }];
    } else {
        block(nil, nil);
    }
}

- (void)fetchLatestMessagesForOrganization:(STKOrganization *)organization group:(STKGroup *)group user:(STKUser *)user date:(NSDate *)date completion:(void (^)(NSArray *messages, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if (err) {
            block(nil, err);
            return;
        }
        NSString *obj = @"all";
        if (group) obj = group.uniqueID;
        NSTimeZone *timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        NSArray *identifiers = nil;
        if (user) {
            identifiers = @[@"/organizations", organization.uniqueID, @"users", user.uniqueID, @"messages"];
        } else {
            identifiers = @[@"/organizations", organization.uniqueID, @"groups", obj, @"messages"];
        }
        // or specifc Timezone: with name
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:identifiers];
        if (date) {
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setTimeZone:timeZone];
            [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
           
            NSString *localDateString = [dateFormatter stringFromDate:date];
            [c addQueryValue:localDateString forKey:@"since"];
        }
        [c addQueryValue:self.currentUser.uniqueID forKey:@"requestor"];
        [c setModelGraph:@[@"STKMessage"]];
        [c setExistingMatchMap:@{@"uniqueID": @"_id"}];
        [c setContext:[self context]];
                    [c setShouldReturnArray:YES];
        [c setShouldReturnArray:YES];
        [c getWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            block(obj, err);
        }];
    }];
}

- (void)fetchOlderMessagesForOrganization:(STKOrganization *)organization group:(STKGroup *)group date:(NSDate *)date completion:(void (^)(NSArray *messages, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if (err) {
            block(nil, err);
            return;
        }
        NSString *obj = @"all";
        if (group) obj = group.uniqueID;
        NSTimeZone *timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        // or specifc Timezone: with name
        
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setTimeZone:timeZone];
        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
        
        NSString *localDateString = [dateFormatter stringFromDate:date];
        
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/organizations", organization.uniqueID, @"groups", obj, @"messages"]];
        [c addQueryValue:localDateString forKey:@"before"];
        [c addQueryValue:self.currentUser.uniqueID forKey:@"requestor"];
        [c setModelGraph:@[@"STKMessage"]];
        [c setExistingMatchMap:@{@"uniqueID": @"_id"}];
        [c setContext:[self context]];
        //            [c setShouldReturnArray:YES];
        [c setShouldReturnArray:YES];
        [c getWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            block(obj, err);
        }];
    }];
}

- (void)fetchOlderMessagesForOrganization:(STKOrganization *)organization group:(STKGroup *)group user:(STKUser *) user date:(NSDate *)date completion:(void (^)(NSArray *messages, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if (err) {
            block(nil, err);
            return;
        }
        NSString *obj = @"all";
        if (group) obj = group.uniqueID;
        NSTimeZone *timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        // or specifc Timezone: with name
        
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setTimeZone:timeZone];
        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
        
        NSString *localDateString = [dateFormatter stringFromDate:date];
        NSArray *identifiers = nil;
        if (user) {
            NSString *fromString = [NSString stringWithFormat:@"messages"];
            identifiers = @[@"/organizations", organization.uniqueID, @"users", self.currentUser.uniqueID, fromString];
        } else {
            identifiers = @[@"/organizations", organization.uniqueID, @"groups", obj, @"messages"];
        }
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:identifiers];
        if (user) {
            [c addQueryValue:self.currentUser.uniqueID forKey:@"sender"];
        }
        [c addQueryValue:localDateString forKey:@"before"];
        [c addQueryValue:self.currentUser.uniqueID forKey:@"requestor"];
        [c setModelGraph:@[@"STKMessage"]];
        [c setExistingMatchMap:@{@"uniqueID": @"_id"}];
        [c setContext:[self context]];
        //            [c setShouldReturnArray:YES];
        [c setShouldReturnArray:YES];
        [c getWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            block(obj, err);
        }];
    }];
}

- (void)likeMessage:(STKMessage *)message completion:(void (^)(STKMessage *message, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if (err) {
            block(nil, err);
            return;
        }
        NSString *groupname = message.group?message.group.uniqueID:@"all";
     
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/organizations", message.organization.uniqueID, @"groups", groupname, @"messages", message.uniqueID]];

        [c addQueryValue:[self currentUser].uniqueID forKey:@"user"];
        [c addQueryValue:@"like" forKey:@"action"];
        [c setModelGraph:@[@"STKMessage"]];
        [c setExistingMatchMap:@{@"uniqueID": @"_id"}];
        [c setContext:[self context]];
        [c setShouldReturnArray:NO];
        [c putWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            block(obj, err);
        }];
    }];
}

- (void)unlikeMessage:(STKMessage *)message completion:(void (^)(STKMessage *message, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if (err) {
            block(nil, err);
            return;
        }
        NSString *group = message.group?message.group.uniqueID:@"all";
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/organizations", message.organization.uniqueID, @"groups", group, @"messages", message.uniqueID]];
        
        [c addQueryValue:[self currentUser].uniqueID forKey:@"user"];
        [c addQueryValue:@"unlike" forKey:@"action"];
        [c setModelGraph:@[@"STKMessage"]];
        [c setExistingMatchMap:@{@"uniqueID": @"_id"}];
        [c setContext:[self context]];
        //            [c setShouldReturnArray:YES];
        [c setShouldReturnArray:NO];
        [c putWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            block(obj, err);
        }];
    }];
}

- (void)postMessage:(NSString*)message toGroup:(STKGroup *)group organization:(STKOrganization *)organization completion:(void (^)(STKMessage *message, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if (err) {
            block(nil, err);
            return;
        }
        NSString *groupName = group?group.uniqueID:@"all";
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/organizations", organization.uniqueID, @"groups", groupName, @"messages"]];
        
        [c addQueryValue:[self currentUser].uniqueID forKey:@"creator"];
        [c addQueryValue:organization.uniqueID forKey:@"organization"];

        [c addQueryValue:groupName forKey:@"group"];
    
        [c addQueryValue:message forKey:@"text"];
        [c setModelGraph:@[@"STKMessage"]];
        [c setExistingMatchMap:@{@"uniqueID": @"_id"}];
        [c setContext:[self context]];
        //            [c setShouldReturnArray:YES];
        [c setShouldReturnArray:YES];
        [c postWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            [self.context save:nil];
            block(obj, err);
        }];
    }];
}

- (void)postMessage:(NSString *)message toUser:(STKUser *)user organization:(STKOrganization *)organization completion:(void (^)(STKMessage *, NSError *))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if (err) {
            block(nil, err);
            return;
        }
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/organizations", organization.uniqueID, @"users", user.uniqueID, @"messages"]];
        
        [c addQueryValue:[self currentUser].uniqueID forKey:@"creator"];
        [c addQueryValue:organization.uniqueID forKey:@"organization"];
        [c addQueryValue:message forKey:@"text"];
        [c setModelGraph:@[@"STKMessage"]];
        [c setExistingMatchMap:@{@"uniqueID": @"_id"}];
        [c setContext:[self context]];
        //            [c setShouldReturnArray:YES];
        [c setShouldReturnArray:NO];
        [c postWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            block(obj, err);
            [self.context save:nil];
        }];
    }];
}

- (void)postMessageImage:(NSString*)imageURL toGroup:(STKGroup *)group organization:(STKOrganization *)organization completion:(void (^)(STKMessage *message, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if (err) {
            block(nil, err);
            return;
        }
        NSString *groupName = group?group.uniqueID:@"all";
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/organizations", organization.uniqueID, @"groups", groupName, @"messages"]];
        
        [c addQueryValue:[self currentUser].uniqueID forKey:@"creator"];
        [c addQueryValue:organization.uniqueID forKey:@"organization"];
        
        [c addQueryValue:groupName forKey:@"group"];
        
        [c addQueryValue:imageURL forKey:@"image_url"];
        [c setModelGraph:@[@"STKMessage"]];
        [c setExistingMatchMap:@{@"uniqueID": @"_id"}];
        [c setContext:[self context]];
        //            [c setShouldReturnArray:YES];
        [c setShouldReturnArray:NO];
        [c postWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            block(obj, err);
        }];
    }];
}

- (void)postMessageImage:(NSString*)imageURL toUser:(STKUser *) user organization:(STKOrganization *)organization completion:(void (^)(STKMessage *message, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if (err) {
            block(nil, err);
            return;
        }
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/organizations", organization.uniqueID, @"users", user.uniqueID, @"messages"]];
        
        [c addQueryValue:[self currentUser].uniqueID forKey:@"creator"];
        [c addQueryValue:organization.uniqueID forKey:@"organization"];
        
        
        
        [c addQueryValue:imageURL forKey:@"image_url"];
        [c setModelGraph:@[@"STKMessage"]];
        [c setExistingMatchMap:@{@"uniqueID": @"_id"}];
        [c setContext:[self context]];
        //            [c setShouldReturnArray:YES];
        [c setShouldReturnArray:NO];
        [c postWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            block(obj, err);
        }];
    }];
}

- (void)fetchOrganizationByCode:(NSString *)code completion:(void (^)(STKOrganization *organization, NSError *err))block
{
    if (code && code.length > 2) {
        [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
            if (err) {
                block (nil, err);
                return;
            }
            STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/organizations", code]];
            
            STKQueryObject *q = [[STKQueryObject alloc] init];
        
            
//            STKResolutionQuery *rq = [STKResolutionQuery resolutionQueryForField:@"theme"];
//            STKResolutionQuery *mq = [STKResolutionQuery resolutionQueryForField:@"members"];
//            [q addSubquery:rq];
//            [q addSubquery:mq];
            [c setQueryObject:q];
            [c setModelGraph:@[@"STKOrganization"]];
            [c setExistingMatchMap:@{@"uniqueID": @"_id"}];
            [c setResolutionMap:@{@"Theme": @"STKTheme", @"User": @"STKUser"}];
            [c setContext:[self context]];
//            [c setShouldReturnArray:YES];
            [c setShouldReturnArray:YES];
            [c getWithSession:[self session] completionBlock:^(id obj, NSError *err) {
                if (obj && [obj isKindOfClass:[NSArray class]]) {
                    if ([obj count] > 0) {
                        obj = [obj objectAtIndex:0];
                        err = nil;
                    } else {
                        obj = nil;
                    }
                }
                block(obj, err);
            }];
        }];
    } else {
        NSError *err = [NSError errorWithDomain:@"STKUserStore" code:9955 userInfo:@{}];
        block(nil, err);
    }
}

- (STKOrganization *)getOrganizationByCode:(NSString *)code
{
    NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName:@"STKOrganization"];
    NSPredicate *p = [NSPredicate predicateWithFormat:@"code == %@", code];
    [fr setPredicate:p];
    NSArray *cached = nil;
    [fr setFetchLimit:1];
    cached = [[self context] executeFetchRequest:fr error:nil];
    if (cached.count > 0) {
        return cached[0];
    } else {
        return nil;
    }
}

- (void)editGroup:(STKGroup *)group name:(NSString *)name description:(NSString *)description leader:(NSString *)leader completion:(void (^)(id data, NSError *error))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if (err) {
            block(nil, err);
            return;
        }
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/organizations", group.organization.uniqueID, @"groups", group.uniqueID]];
        [c addQueryValue:[self currentUser].uniqueID forKey:@"creator"];
        [c addQueryValue:group.organization.uniqueID forKey:@"organization"];
        [c addQueryValue:name forKey:@"name"];
        [c addQueryValue:description forKey:@"description"];
        [c addQueryValue:leader forKey:@"leader"];
        
        [c setModelGraph:@[@"STKGroup"]];
        [c setExistingMatchMap:@{@"uniqueID": @"_id"}];
        [c setContext:[self context]];
        //            [c setShouldReturnArray:YES];
        [c setShouldReturnArray:NO];
        [c putWithSession:[self session] completionBlock:^(STKGroup *obj, NSError *err) {
            block(obj, err);
        }];
    }];
}

- (void)createGroup:(NSString *)name forOrganization:(STKOrganization *)organization withDescription:(NSString *)description leader:(NSString *)leader member:(NSArray *)members completion:(void (^)(id data, NSError *error))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if (err) {
            block(nil, err);
            return;
        }
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/organizations", organization.uniqueID, @"groups"]];
        
        [c addQueryValue:[self currentUser].uniqueID forKey:@"creator"];
        [c addQueryValue:organization.uniqueID forKey:@"organization"];
        [c addQueryValue:name forKey:@"name"];
        [c addQueryValue:description forKey:@"description"];
        [c addQueryValue:leader forKey:@"leader"];
        [c addQueryValue:members forKey:@"members"];
        
        [c setModelGraph:@[@"STKGroup"]];
        [c setExistingMatchMap:@{@"uniqueID": @"_id"}];
        [c setContext:[self context]];
        //            [c setShouldReturnArray:YES];
        [c setShouldReturnArray:NO];
        [c postWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            block(obj, err);
        }];
    }];
}

- (void)deleteGroup:(STKGroup *)group completion:(void (^)(id data, NSError *error))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if (err) {
            block(nil, err);
            return;
        }
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/organizations", group.organization.uniqueID, @"groups", group.uniqueID]];
        
        [c addQueryValue:[self currentUser].uniqueID forKey:@"requestor"];
        
        [c setModelGraph:@[@"STKGroup"]];
        [c setExistingMatchMap:@{@"uniqueID": @"_id"}];
        [c setContext:[self context]];
        [c setShouldReturnArray:NO];
        [c deleteWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            if (!err) {
                [self.context deleteObject:group];
                NSError *err;
                [self.context save:&err];
            }
            block(obj, err);
        }];
    }];
}

- (void)editMembers:(NSArray *)members forGroup:(STKGroup *)group completion:(void (^)(id data, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if (err) {
            block(nil, err);
            return;
        }
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/organizations", group.organization.uniqueID, @"groups", group.uniqueID, @"members"]];
        [c addQueryValue:[self currentUser].uniqueID forKey:@"requestor"];
        [c addQueryValue:members forKey:@"members"];
        
        [c setModelGraph:@[@"STKUser"]];
        [c setExistingMatchMap:@{@"uniqueID": @"_id"}];
        [c setContext:[self context]];
        //            [c setShouldReturnArray:YES];
        [c setShouldReturnArray:YES];
        [c putWithSession:[self session] completionBlock:^(STKGroup *obj, NSError *err) {
            block(obj, err);
        }];
    }];
}

- (void)removeUser:(STKUser *)user fromGroup:(STKGroup *)group completion:(void (^)(id data, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if (err) {
            block(nil, err);
            return;
        }
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/organizations", group.organization.uniqueID, @"groups", group.uniqueID, @"members", user.uniqueID]];
        [c addQueryValue:[self currentUser].uniqueID forKey:@"requestor"];
        
        
        [c setModelGraph:@[@"STKUser"]];
        [c setExistingMatchMap:@{@"uniqueID": @"_id"}];
        [c setContext:[self context]];
        //            [c setShouldReturnArray:YES];
        [c setShouldReturnArray:NO];
        [c deleteWithSession:[self session] completionBlock:^(STKUser *obj, NSError *err) {
            if (!err) {
                __block id object;
                [obj.organizations enumerateObjectsUsingBlock:^(STKOrgStatus *obj, BOOL *stop) {
                    object = obj;
                }];
                if (object) {
                    [obj removeOrganizationsObject:object];
                    NSError *err;
                    [self.context save:&err];
                }
            }
            block(obj, err);
        }];
    }];
}


- (void)muteGroup:(STKGroup *)group muted:(BOOL)muted completion:(void (^)(id, NSError *))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if (err) {
            block(nil, err);
            return;
        }
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/organizations", group.organization.uniqueID, @"groups", group.uniqueID]];
        [c addQueryValue:[self currentUser].uniqueID forKey:@"requestor"];
        NSString *action = muted?@"mute":@"unmute";
        [c addQueryValue:action forKey:@"action"];
        
        [c setModelGraph:@[@"STKGroup"]];
        [c setExistingMatchMap:@{@"uniqueID": @"_id"}];
        [c setContext:[self context]];
        //            [c setShouldReturnArray:YES];
        [c setShouldReturnArray:NO];
        [c putWithSession:[self session] completionBlock:^(STKGroup *obj, NSError *err) {
            block(obj, err);
        }];
    }];
}

- (void)muteOrganization:(STKOrganization *)organization muted:(BOOL)muted completion:(void (^)(id, NSError *))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if (err) {
            block(nil, err);
            return;
        }
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/organizations", organization.uniqueID]];
        [c addQueryValue:[self currentUser].uniqueID forKey:@"requestor"];
        NSString *action = muted?@"mute":@"unmute";
        [c addQueryValue:action forKey:@"action"];
        
        [c setModelGraph:@[@"STKOrganization"]];
        [c setExistingMatchMap:@{@"uniqueID": @"_id"}];
        [c setContext:[self context]];
        //            [c setShouldReturnArray:YES];
        [c setShouldReturnArray:NO];
        [c putWithSession:[self session] completionBlock:^(STKGroup *obj, NSError *err) {
            block(obj, err);
        }];
    }];
}


#pragma mark Authentication Nonsense

- (void)executeSocialRequest:(SLRequest *)req forAccount:(ACAccount *)acct completion:(void (^)(id data, NSError *error))block
{
    [req setAccount:acct];
    
    NSURLRequest *urlRequest = [req preparedURLRequest];
    [NSURLConnection sendAsynchronousRequest:urlRequest
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               block(data, connectionError);
                           }];
}

#pragma mark Twitter

- (void)fetchAvailableTwitterAccounts:(void (^)(NSArray *accounts, NSError *err))block
{
    ACAccountType *type = [[self accountStore] accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    [[self accountStore] requestAccessToAccountsWithType:type
                                                 options:nil
                                              completion:^(BOOL granted, NSError *error) {
                                                  if(granted) {
                                                      [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                                                          NSArray *accounts = [[self accountStore] accountsWithAccountType:type];
                                                          if([accounts count] > 0) {
                                                              block([[self accountStore] accountsWithAccountType:type], nil);
                                                          } else
                                                              block(nil, [self errorForCode:STKUserStoreErrorCodeNoAccount data:nil]);
                                                      }];
                                                  } else {
                                                      [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                                                          block(nil, error);
                                                      }];
                                                  }
                                              }];
}

- (void)connectWithTwitterAccount:(ACAccount *)acct completion:(void (^)(STKUser *existingUser, STKUser *registrationData, NSError *err))block
{
    [self fetchTwitterAccessToken:acct completion:^(NSString *token, NSString *secret, NSError *tokenError) {
        if(!tokenError) {
            [self validateWithTwitterToken:token secret:secret completion:^(STKUser *user, NSError *valErr) {
                if(!valErr) {
                    if (user) {
                        [user setExternalServiceType:STKUserExternalSystemTwitter];
                        [user setAccountStoreID:[acct identifier]];
                        [self authenticateUser:user];
                    }
                    
                    block(user, nil, nil);
                } else {
                    if([valErr isConnectionError]) {
                        block(nil, nil, valErr);
                    } else {
                        // Return Twitter Information for Registration
                        [self fetchTwitterDataForAccount:acct completion:^(STKUser *profInfo, NSError *dataErr) {
                            if([dataErr isConnectionError]) {
                                block(nil, nil, dataErr);
                            } else {
                                [profInfo setToken:token];
                                [profInfo setSecret:secret];
                                block(nil, profInfo, dataErr);
                            }
                        }];
                    }
                }
            }];
        } else {
            // OAuth failed
            block(nil, nil, tokenError);
        }
    }];
}

- (void)validateWithTwitterToken:(NSString *)token secret:(NSString *)secret completion:(void (^)(STKUser *u, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if(err) {
            block(nil, err);
            return;
        }
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[STKUserEndpointLogin]];
        [c addQueryValue:token forKey:@"provider_token"];
        [c addQueryValue:secret forKey:@"provider_token_secret"];
        [c addQueryValue:STKUserExternalSystemTwitter forKey:@"provider"];
        
        if([self currentUser])
            [c setModelGraph:@[[self currentUser]]];
        else
            [c setModelGraph:@[@"STKUser"]];
        [c setContext:[self context]];
        [c setExistingMatchMap:@{@"uniqueID" : @"_id"}];

        [c postWithSession:[self session]
           completionBlock:block];
    }];
}

- (void)fetchTwitterAccessToken:(ACAccount *)acct completion:(void (^)(NSString *token, NSString *tokenSecret, NSError *err))block
{
    NSURL *url = [NSURL URLWithString:@"https://api.twitter.com/oauth/request_token"];
    NSData *bodyData = [@"x_auth_mode=reverse_auth" dataUsingEncoding:NSUTF8StringEncoding];
    NSString *authHeader = OAuthorizationHeader(url,
                                                @"POST",
                                                bodyData,
                                                STKUserStoreExternalCredentialTwitterConsumerKey,
                                                STKUserStoreExternalCredentialTwitterConsumerSecret,
                                                nil, nil);
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    [req addValue:authHeader forHTTPHeaderField:@"Authorization"];
    [req setHTTPBody:bodyData];
    [req setHTTPMethod:@"POST"];
    [NSURLConnection sendAsynchronousRequest:req queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        if(!connectionError) {
            NSString *result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            
            SLRequest *slRequest = [SLRequest requestForServiceType:SLServiceTypeTwitter
                                                      requestMethod:SLRequestMethodPOST
                                                                URL:[NSURL URLWithString:@"https://api.twitter.com/oauth/access_token"]
                                                         parameters:@{@"x_reverse_auth_target" : STKUserStoreExternalCredentialTwitterConsumerKey,
                                                                      @"x_reverse_auth_parameters" : result}];
            [self executeSocialRequest:slRequest forAccount:acct completion:^(NSData *tokenResult, NSError *error) {
                if(!error) {
                    NSString *responseString = [[NSString alloc] initWithData:tokenResult encoding:NSUTF8StringEncoding];
                    NSRegularExpression *exp = [[NSRegularExpression alloc] initWithPattern:@"&?([^=]*)=([^&]*)"
                                                                                    options:0 error:nil];
                    NSArray *matches = [exp matchesInString:responseString options:0 range:NSMakeRange(0, [responseString length])];
                    NSMutableDictionary *values = [NSMutableDictionary dictionary];
                    for(NSTextCheckingResult *match in matches) {
                        if([match numberOfRanges] == 3) {
                            NSString *key = [responseString substringWithRange:[match rangeAtIndex:1]];
                            NSString *val = [responseString substringWithRange:[match rangeAtIndex:2]];
                            [values setObject:val forKey:key];
                        }
                    }
                    NSString *token = [values objectForKey:@"oauth_token"];
                    NSString *secret = [values objectForKey:@"oauth_token_secret"];
                    if(token && secret) {
                        block(token, secret, nil);
                    } else {
                        // Failed because there wasn't token data
                        block(nil, nil, [self errorForCode:STKUserStoreErrorCodeOAuth data:nil]);
                    }
                } else {
                    // Failed getting token
                    block(nil, nil, [self errorForCode:STKUserStoreErrorCodeOAuth data:nil]);
                }
            }];
        } else {
            // Failed Sending oauth
            block(nil, nil, connectionError);
        }
    }];
}


- (void)fetchTwitterDataForAccount:(ACAccount *)acct completion:(void (^)(STKUser *acct, NSError *err))block
{
    NSString *requestString = [NSString stringWithFormat:@"https://api.twitter.com/1/users/lookup.json?screen_name=%@", [acct username]];
    SLRequest *req = [SLRequest requestForServiceType:SLServiceTypeTwitter
                                        requestMethod:SLRequestMethodGET
                                                  URL:[NSURL URLWithString:requestString]
                                           parameters:nil];
    [self executeSocialRequest:req forAccount:acct completion:^(NSData *userData, NSError *userError) {
        if(!userError && userData) {
            NSArray *a = [NSJSONSerialization JSONObjectWithData:userData options:0 error:nil];
        
            STKUser *pi = [NSEntityDescription insertNewObjectForEntityForName:@"STKUser"
                                                        inManagedObjectContext:[self context]];
            
            [pi setValuesFromTwitter:a];
            [pi setAccountStoreID:[acct identifier]];
            
            SLRequest *profReq = [SLRequest requestForServiceType:SLServiceTypeTwitter
                                                    requestMethod:SLRequestMethodGET
                                                              URL:[NSURL URLWithString:@"https://api.twitter.com/1/users/profile_image"]
                                                       parameters:@{@"screen_name" : [acct username], @"size" : @"original"}];
            [self executeSocialRequest:profReq forAccount:acct completion:^(NSData *profData, NSError *profError) {
                if(!profError) {
                    [pi setProfilePhoto:[UIImage imageWithData:profData]];
                }
                
                SLRequest *coverReq = [SLRequest requestForServiceType:SLServiceTypeTwitter
                                                         requestMethod:SLRequestMethodGET
                                                                   URL:[NSURL URLWithString:@"https://api.twitter.com/1.1/users/profile_banner.json"]
                                                            parameters:@{@"screen_name" : [acct username]}];
                [self executeSocialRequest:coverReq forAccount:acct completion:^(NSData *coverData, NSError *coverError) {
                    if(!coverError) {
                        NSDictionary *coverDict = [NSJSONSerialization JSONObjectWithData:coverData options:0 error:nil];
                        NSString *urlString = [coverDict valueForKeyPath:@"sizes.mobile_retina.url"];
                        [pi setCoverPhotoPath:urlString];
                    }
                    block(pi, nil);
                }];
            }];
        } else {
            block(nil, userError);
        }
        
    }];
}


#pragma mark Facebook

- (void)connectWithFacebook:(void (^)(STKUser *existingUser, STKUser *facebookData, NSError *err))block
{
    [self fetchFacebookAccountWithCompletion:^(ACAccount *acct, NSError *err) {
        if(!err) {
            [[self accountStore] renewCredentialsForAccount:acct completion:^(ACAccountCredentialRenewResult renewResult, NSError *error) {
                if(!error) {
                    [self validateWithFacebook:[[acct credential] oauthToken]
                                    completion:^(STKUser *user, NSError *valError) {
                                        if(!valError) {
                                            [user setExternalServiceType:STKUserExternalSystemFacebook];
                                            [user setAccountStoreID:[acct identifier]];
                                            
                                            [self authenticateUser:user];
                                            
                                            block(user, nil, nil);
                                        } else {
                                            if(![[[valError userInfo] objectForKey:@"error"] isEqualToString:STKErrorUserDoesNotExist]) {
                                                block(nil, nil, valError);
                                            } else {
                                                // Fallback to registration
                                                [self fetchFacebookDataForAccount:acct completion:^(STKUser *profInfo, NSError *dataErr) {
                                                    if([dataErr isConnectionError]) {
                                                        block(nil, nil, dataErr);
                                                    } else {
                                                        [profInfo setToken:[[acct credential] oauthToken]];
                                                        block(nil, profInfo, dataErr);
                                                    }
                                                }];
                                            }
                                        }
                                    }];
                } else {
                    block(nil, nil, error);
                }
            }];
        } else {
            block(nil, nil, err);
        }
    }];
}

- (void)fetchFacebookAccountWithCompletion:(void (^)(ACAccount *acct, NSError *err))block
{
    ACAccountType *type = [[self accountStore] accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierFacebook];
    [[self accountStore] requestAccessToAccountsWithType:type options:@{
                                                                        ACFacebookAppIdKey : STKUserStoreExternalCredentialFacebookAppID,
                                                                        ACFacebookPermissionsKey : @[
                                                                                @"email",
                                                                                @"user_birthday",
                                                                                @"user_education_history",
                                                                                @"user_hometown",
                                                                                @"user_location",
                                                                                @"user_photos",
                                                                                @"user_religion_politics"
                                                                            ]
                                                                        }
                                              completion:^(BOOL granted, NSError *error) {
                                                  if(granted) {
                                                      NSArray *accounts = [[self accountStore] accountsWithAccountType:type];

                                                      if([accounts count] == 1) {
                                                          ACAccount *acct = [accounts firstObject];
                                                          [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                                                              block(acct, nil);
                                                          }];
                                                      } else {
                                                          [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                                                              block(nil, [self errorForCode:STKUserStoreErrorCodeNoAccount data:nil]);
                                                          }];
                                                      }
                                                  } else {
                                                      [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                                                          block(nil, error);
                                                      }];
                                                  }
                                              }];
}

- (void)validateWithFacebook:(NSString *)oauthToken completion:(void (^)(STKUser *u, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if(err) {
            block(nil, err);
            return;
        }
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[STKUserEndpointLogin]];
        [c addQueryValue:oauthToken forKey:@"provider_token"];
        [c addQueryValue:STKUserExternalSystemFacebook forKey:@"provider"];

        if([self currentUser])
            [c setModelGraph:@[[self currentUser]]];
        else
            [c setModelGraph:@[@"STKUser"]];
        [c setContext:[self context]];
        [c setExistingMatchMap:@{@"uniqueID" : @"_id"}];
        
        [c postWithSession:[self session] completionBlock:block];
    }];
}

- (void)fetchFacebookDataForAccount:(ACAccount *)acct completion:(void (^)(STKUser *acct, NSError *err))block
{
    SLRequest *req = [SLRequest requestForServiceType:SLServiceTypeFacebook
                                        requestMethod:SLRequestMethodGET
                                                  URL:[NSURL URLWithString:@"https://graph.facebook.com/v2.0/me"]
                                           parameters:nil];
    [self executeSocialRequest:req forAccount:acct completion:^(NSData *userData, NSError *userError) {
        if(!userError && userData) {
            NSDictionary *userDict = [NSJSONSerialization JSONObjectWithData:userData options:0 error:nil];
            
            STKUser *pi = [NSEntityDescription insertNewObjectForEntityForName:@"STKUser" inManagedObjectContext:[self context]];
            [pi setValuesFromFacebook:userDict];
            [pi setToken:[[acct credential] oauthToken]];
            [pi setAccountStoreID:[acct identifier]];
            
            SLRequest *profilePicReq = [SLRequest requestForServiceType:SLServiceTypeFacebook
                                                          requestMethod:SLRequestMethodGET
                                                                    URL:[NSURL URLWithString:@"https://graph.facebook.com/v2.0/me/picture"]
                                                             parameters:@{@"width" : @"600", @"height" : @"600", @"access_token" : [[acct credential] oauthToken]}];
            [self executeSocialRequest:profilePicReq forAccount:acct completion:^(NSData *picData, NSError *picError) {
                if(!picError && picData) {
                    UIImage *image = [UIImage imageWithData:picData];
                    [pi setProfilePhoto:image];
                }
                
                SLRequest *coverPicReq = [SLRequest requestForServiceType:SLServiceTypeFacebook
                                                            requestMethod:SLRequestMethodGET
                                                                      URL:[NSURL URLWithString:[NSString stringWithFormat:@"https://graph.facebook.com/v2.0/me"]]
                                                               parameters:@{@"fields" : @"cover", @"access_token" : [[acct credential] oauthToken]}];
                [self executeSocialRequest:coverPicReq forAccount:acct completion:^(NSData *coverData, NSError *coverError) {
                    if(!coverError && coverData) {
                        NSDictionary *coverDict = [NSJSONSerialization JSONObjectWithData:coverData options:0 error:nil];
                        NSString *source = [coverDict valueForKeyPath:@"cover.source"];
                        [pi setCoverPhotoPath:source];
                    }
                    
                    block(pi, nil);
                }];
                
            }];
        } else {
            block(nil, userError);
        }
    }];
}

#pragma mark Google

- (void)connectWithGoogle:(void (^)(STKUser *existingUser, STKUser *registrationData, NSError *err))completionBlock processing:(void (^)())processingBlock
{
    [self setGooglePlusProcessingBlock:processingBlock];
    [self fetchGoogleAccount:^(GTMOAuth2Authentication *auth, NSError *err) {
        if(!err) {
            [self validateWithGoogle:[auth accessToken] completion:^(STKUser *u, NSError *err) {
                if(!err) {
                    [u setExternalServiceType:STKUserExternalSystemGoogle];

                    [self authenticateUser:u];
                    
                    completionBlock(u, nil, nil);
                } else {
                    if([err isConnectionError]) {
                        completionBlock(nil, nil, err);
                    } else {
                        [self fetchGoogleDataForAuth:auth completion:^(STKUser *pi, NSError *err) {
                            if(!err)
                                completionBlock(nil, pi, nil);
                            else
                                completionBlock(nil, nil, err);
                        }];
                    }
                }
            }];
        } else {
            completionBlock(nil, nil, err);
        }
    }];
}

- (void)fetchGoogleAccount:(void (^)(GTMOAuth2Authentication *auth, NSError *err))block
{
    [self setGooglePlusAuthenticationBlock:block];
    
    [[GPPSignIn sharedInstance] setScopes:@[kGTLAuthScopePlusLogin, kGTLAuthScopePlusMe]];
    [[GPPSignIn sharedInstance] setShouldFetchGooglePlusUser:YES];
    [[GPPSignIn sharedInstance] setShouldFetchGoogleUserEmail:YES];
    [[GPPSignIn sharedInstance] setShouldFetchGoogleUserID:YES];
    [[GPPSignIn sharedInstance] setClientID:STKUserStoreExternalCredentialGoogleClientID];
    [[GPPSignIn sharedInstance] setDelegate:self];
    
    if ([[GPPSignIn sharedInstance] hasAuthInKeychain]) {
        [[GPPSignIn sharedInstance] trySilentAuthentication];
    } else {
        GPPSignInButton *b = [[GPPSignInButton alloc] init];
        [b sendActionsForControlEvents:UIControlEventTouchUpInside];
    }
}


- (void)validateWithGoogle:(NSString *)token completion:(void (^)(STKUser *, NSError *))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err) {
        if(err){
            block(nil, err);
            return;
        }
        STKConnection * c = [[STKBaseStore store] newConnectionForIdentifiers:@[STKUserEndpointLogin]];
        [c addQueryValue:token forKey:@"provider_token"];
        [c addQueryValue:STKUserExternalSystemGoogle forKey:@"provider"];
        
        if([self currentUser])
            [c setModelGraph:@[[self currentUser]]];
        else
            [c setModelGraph:@[@"STKUser"]];
        [c setContext:[self context]];
        [c setExistingMatchMap:@{@"uniqueID" : @"_id"}];
        
        [c postWithSession:[self session] completionBlock:block];
        
    }];
}

- (void)fetchGoogleDataForAuth:(GTMOAuth2Authentication *)auth completion:(void (^)(STKUser *pi, NSError *err))block
{
    STKUser *pi = [NSEntityDescription insertNewObjectForEntityForName:@"STKUser"
                                                inManagedObjectContext:[self context]];
    [pi setEmail:[auth userEmail]];
    [pi setToken:[auth accessToken]];
    
    GTLServicePlus *service = [[GTLServicePlus alloc] init];
    [service setAuthorizer:auth];
    GTLQueryPlus *query = [GTLQueryPlus queryForPeopleGetWithUserId:@"me"];
    
    [service executeQuery:query
        completionHandler:^(GTLServiceTicket *ticket, GTLPlusPerson *object, NSError *queryError) {
            if(!queryError) {
                [pi setValuesFromGooglePlus:object];
                block(pi, nil);
            } else {
                block(nil, queryError);
            }
        }];
}


- (void)finishedWithAuth:(GTMOAuth2Authentication *)auth
                   error:(NSError *)error
{
    if (!error) {
        if ([self googlePlusAuthenticationBlock]) {
            if ([self googlePlusProcessingBlock]) {
                [self googlePlusProcessingBlock]();
            }
            [self googlePlusAuthenticationBlock](auth, error);
        }
    } else {
        if ([self attemptingTransparentLogin] && [error isConnectionError]) {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                [self authenticateUser:[self currentUser]];
                [[self context] save:nil];
            }];
        } else {
            // g+ returns "unknown error" when user hits cancel during the signin process
            // we'll report our authorization error
            NSError *err = [NSError errorWithDomain:STKUserStoreErrorDomain code:STKUserStoreErrorCodeOAuth userInfo:nil];
            [self googlePlusAuthenticationBlock](auth, err);
        }
    }
    [self setGooglePlusAuthenticationBlock:nil];
    [self setGooglePlusProcessingBlock:nil];
    [self setAttemptingTransparentLogin:NO];
}

#pragma mark Standard

- (void)resetPasswordForEmail:(NSString *)email password:(NSString *)password completion:(void (^)(NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            block(err);
            return;
        }
        
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/users", email, @"passwordreset"]];
        [c addQueryValue:password forKey:@"password"];
        
        [c postWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            block(err);
        }];
    }];
}

- (void)changePasswordForEmail:(NSString *)email currentPassword:(NSString *)currentPassword newPassword:(NSString *)newPassword completion:(void (^)(NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            block(err);
            return;
        }
        
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[@"/users", email, @"passwordchange"]];
        [c addQueryValue:newPassword forKey:@"newPassword"];
        [c addQueryValue:currentPassword forKey:@"currentPassword"];
        
        [c postWithSession:[self session] completionBlock:^(id obj, NSError *err) {
            if (!err) {
                STKSecurityStorePassword(email, newPassword);
            }
            block(err);
        }];
    }];
}

- (void)loginWithEmail:(NSString *)email password:(NSString *)password completion:(void (^)(STKUser *user, NSError *err))block
{
    [self validateWithEmail:email password:password completion:^(STKUser *user, NSError *err) {
        if(!err) {
            STKSecurityStorePassword([user email], password);
            
            [self authenticateUser:user];
            [[self context] save:nil];
            
            block(user, nil);
        } else {
            block(nil, err);
        }
    }];
}

- (void)validateWithEmail:(NSString *)email password:(NSString *)password completion:(void (^)(STKUser *user, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            block(nil, err);
            return;
        }
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[STKUserEndpointLogin]];
        [c addQueryValue:[email lowercaseString] forKey:@"email"];
        [c addQueryValue:password forKey:@"password"];
//        
//        if([self currentUser])
//            [c setModelGraph:@[[self currentUser]]];
//        else
            [c setModelGraph:@[@"STKUser"]];
        [c setContext:[self context]];
        [c setExistingMatchMap:@{@"uniqueID" : @"_id"}];
        [c postWithSession:[self session]
           completionBlock:block];
    }];
}

#pragma mark Uniform

- (void)registerAccount:(STKUser *)info completion:(void (^)(STKUser *user, NSError *err))block
{
    [[STKBaseStore store] executeAuthorizedRequest:^(NSError *err){
        if(err) {
            block(nil, err);
            return;
        }
        
        [info setEmail:[[info email] lowercaseString]];
        
        STKConnection *c = [[STKBaseStore store] newConnectionForIdentifiers:@[STKUserEndpointUser]];
        
        if([info isInstitution]) {
            NSDictionary *values = [info remoteValueMapForLocalKeys:@[
                                                                      @"firstName",
                                                                      @"email",
                                                                      @"zipCode",
                                                                      @"city",
                                                                      @"state",
                                                                      @"type",
                                                                      @"coverPhotoPath",
                                                                      @"profilePhotoPath",
                                                                      @"phoneNumber",
                                                                      @"website",
                                                                      @"subtype"
                                                                      ]];
            [c addQueryValues:values];

        } else {
            NSDictionary *values = [info remoteValueMapForLocalKeys:@[
                                                                      @"firstName",
                                                                      @"lastName",
                                                                      @"email",
                                                                      @"gender",
                                                                      @"zipCode",
                                                                      @"city",
                                                                      @"state",
                                                                      @"coverPhotoPath",
                                                                      @"profilePhotoPath",
                                                                      @"birthday",
                                                                      @"phoneNumber",
                                                                      @"programCode"
                                                                      ]];

            [c addQueryValues:values];

        }
        
        
        
        if([info externalServiceType] && [info externalServiceID]) {
            [c addQueryValue:[info externalServiceID] forKey:@"provider_id"];
            [c addQueryValue:[info externalServiceType] forKey:@"provider"];
            [c addQueryValue:[info token] forKey:@"provider_token"];
            if([[info externalServiceType] isEqualToString:STKUserExternalSystemTwitter]) {
                [c addQueryValue:[info secret] forKey:@"provider_token_secret"];
            }
        } else if([info password]) {
            [c addQueryValue:[info password] forKey:@"password"];

        } else {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                block(nil, [self errorForCode:STKUserStoreErrorCodeMissingArguments
                                         data:@[@"password", @"externalServiceType", @"externalServiceID"]]);
            }];
            return;
        }
        
        [c setModelGraph:@[info]];
        [c setContext:[self context]];
        
        [c postWithSession:[self session] completionBlock:^(STKUser *registeredUser, NSError *err) {
            if(!err) {
                void (^validationBlock)(STKUser *, NSError *) = ^(STKUser *u, NSError *valErr) {
                    if(!valErr) {
                        if([info password]) {
                            STKSecurityStorePassword([u email], [info password]);
                        } /*else {
                            [u setExternalServiceType:[info externalService]];
                            [u setAccountStoreID:[info accountStoreID]];
                        }*/
                        [self authenticateUser:u];
                        
                        block(u, nil);
                    } else {
                        block(nil, valErr);
                    }
                };
                
                // Now let us authenticate
                if([[info externalServiceType] isEqualToString:STKUserExternalSystemGoogle]) {
                    [self validateWithGoogle:[info token] completion:validationBlock];
                } else if([[info externalServiceType] isEqualToString:STKUserExternalSystemFacebook]) {
                    validationBlock(registeredUser, nil);
                } else if([[info externalServiceType] isEqualToString:STKUserExternalSystemTwitter]) {
                    validationBlock(registeredUser, nil);
                } else {
                    validationBlock(registeredUser, nil);
                }
            } else {
                block(nil, err);
            }
        }];
    }];
}

- (void)attemptTransparentLoginWithUser:(STKUser *)u
{
    if(!u)
        return;
    
    [self setAttemptingTransparentLogin:YES];

    void (^validationBlock)(STKUser *, NSError *) = ^(STKUser *u, NSError *valErr) {
        [self setAttemptingTransparentLogin:NO];
        if(!valErr || [[valErr domain] isEqualToString:NSURLErrorDomain]) {
            [self authenticateUser:u];
            [[self context] save:nil];
        } else {
            [self setCurrentUser:nil];
    
            if([valErr isConnectionError]) {
                [[NSNotificationCenter defaultCenter] postNotificationName:STKSessionEndedNotification
                                                                    object:nil
                                                                  userInfo:@{STKSessionEndedReasonKey : STKSessionEndedConnectionValue,
                                                                             @"error" : valErr}];
            } else {
                [[NSNotificationCenter defaultCenter] postNotificationName:STKSessionEndedNotification
                                                                    object:nil
                                                                  userInfo:@{STKSessionEndedReasonKey : STKSessionEndedAuthenticationValue,
                                                                             @"error" : valErr}];
            }
        }
    };
    
    NSString *serviceType = [u externalServiceType];
    if([serviceType isEqualToString:STKUserExternalSystemFacebook]) {
        [self fetchFacebookAccountWithCompletion:^(ACAccount *acct, NSError *err) {
            if(!err) {
                [[self accountStore] renewCredentialsForAccount:acct completion:^(ACAccountCredentialRenewResult renewResult, NSError *error) {
                    // can get this far without internet. if error is connection error, return existing user
                    if(!error) {
                        if([[acct identifier] isEqualToString:[u accountStoreID]]) {
                            [self validateWithFacebook:[[acct credential] oauthToken] completion:^(STKUser *u, NSError *err) {
                                validationBlock(u, err);
                            }];
                        } else {
                            validationBlock(nil, [self errorForCode:STKUserStoreErrorCodeWrongAccount data:nil]);
                        }
                    } else {
                        if ([error isConnectionError]) {
                            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                                validationBlock(u,nil);
                            }];
                        } else {
                            validationBlock(nil, error);
                        }
                    }
                    
                }];
            } else {
                validationBlock(nil, err);
            }
        }];
    } else if([serviceType isEqualToString:STKUserExternalSystemGoogle]) {
        [self fetchGoogleAccount:^(GTMOAuth2Authentication *auth, NSError *err) {
            if(!err) {
                [self validateWithGoogle:[auth accessToken] completion:^(STKUser *u, NSError *err) {
                    if(!err) {
                        validationBlock(u, err);
                    } else {
                        validationBlock(nil, err);
                    }
                }];
            } else {
                validationBlock(nil, err);
            }
        }];
    } else if([serviceType isEqualToString:STKUserExternalSystemTwitter]) {
        [self fetchAvailableTwitterAccounts:^(NSArray *accounts, NSError *err) {
            if(!err) {
                ACAccount *activeAccount = nil;
                for(ACAccount *acct in accounts) {
                    if([[acct identifier] isEqualToString:[u accountStoreID]]) {
                        activeAccount = acct;
                        break;
                    }
                }
                
                if(activeAccount) {
                    [self fetchTwitterAccessToken:activeAccount completion:^(NSString *token, NSString *tokenSecret, NSError *err) {
                        if(!err) {
                            [self validateWithTwitterToken:token secret:tokenSecret completion:^(STKUser *u, NSError *err) {
                                if(!err) {
                                    validationBlock(u, nil);
                                } else {
                                    // Spcific account could not be authoriized
                                    validationBlock(nil, err);
                                }
                            }];
                        } else {
                            if ([err isConnectionError]) {
                                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                                    validationBlock(u,nil);
                                }];
                            } else {
                                validationBlock(nil, err);
                            }
                        }
                    }];
                } else {
                    // Could not find matching account
                    validationBlock(nil, [self errorForCode:STKUserStoreErrorCodeWrongAccount data:nil]);
                }
            } else {
                // Could not access accounts
                validationBlock(nil, err);
            }
        }];
    } else {
        // Via Email
        NSString *email = [u email];
        NSString *password = STKSecurityGetPassword(email);
        if(password) {
            [self validateWithEmail:email password:password completion:^(STKUser *user, NSError *err) {
                // can get this far without internet. if error is connection error, return existing user
                if ([err isConnectionError]) {
                    user = u;
                }
                validationBlock(u, err);
            }];
        } else {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                validationBlock(nil, [self errorForCode:STKUserStoreErrorCodeNoPassword data:nil]);
            }];
        }
    }
    
}

- (void)trackFollow:(STKUser *)user
{

    [[Mixpanel sharedInstance] track:@"User followed" properties:mixpanelDataForObject(@{@"Target User" : user.uniqueID,
                                                                   @"Following Count" : @([user followingCount])})];
}

- (void)trackUnfollow:(STKUser *)user
{
    [[Mixpanel sharedInstance] track:@"User un-followed" properties:mixpanelDataForObject(@{@"Target User" : user.uniqueID,
                                                                   @"Following Count" : @([user followingCount])})];
}


#pragma mark Database pruning to test caching mechanism

- (void)pruneDatabase
{
    
    int postLifeInDays = 7;
    int activityLifeInDays = 4;
    
#ifdef DEBUG
    postLifeInDays = 28;
    activityLifeInDays = 28;
#endif
    
    NSFetchRequest *activityRequest = [NSFetchRequest fetchRequestWithEntityName:@"STKActivityItem"];
    NSFetchRequest *postRequest = [NSFetchRequest fetchRequestWithEntityName:@"STKPost"];
    
    NSDate *postCutOff = [NSDate dateWithTimeIntervalSinceNow:-3600*24*postLifeInDays];
    NSDate *activityCutOff = [NSDate dateWithTimeIntervalSinceNow:-3600*24*activityLifeInDays];
    
    [postRequest setPredicate:[NSPredicate predicateWithFormat:@"datePosted < %@", postCutOff]];
    [activityRequest setPredicate:[NSPredicate predicateWithFormat:@"dateCreated < %@", activityCutOff]];
    
    NSArray *posts = [[self context] executeFetchRequest:postRequest error:nil];
    NSArray *activities = [[self context] executeFetchRequest:activityRequest error:nil];
    
    [posts enumerateObjectsUsingBlock:^(STKPost *p, NSUInteger idx, BOOL *stop) {
        [[STKImageStore store] deleteCachedImagesForURLString:[p imageURLString]];
        [[self context] deleteObject:p];
    }];
    [activities enumerateObjectsUsingBlock:^(STKActivityItem *ai, NSUInteger idx, BOOL *stop) {
        [[self context] deleteObject:ai];
    }];
    
    return;
}

- (STKOrganization *)activeOrgForUser
{
    NSString *orgID = [[NSUserDefaults standardUserDefaults] stringForKey:@"HAGroupContextString"];
    __block STKOrganization *org = nil;
    if (orgID) {
        NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName:@"STKOrganization"];
        NSPredicate *sp = [NSPredicate predicateWithFormat:@"uniqueID == %@", orgID];
        [fr setPredicate:sp];
        NSError *err = nil;
        id fetch = [self.context executeFetchRequest:fr error:&err];
        if (err) {
            NSLog(@"%@", err.localizedDescription);
        }
        if ([fetch isKindOfClass:[NSArray class]]) {
            if ([fetch count] > 0){
                org = [fetch objectAtIndex:0];
            }
        } else if ([fetch isKindOfClass:[STKOrganization class]]) {
            org = fetch;
        }
    } else {
        STKUser *u = self.currentUser;
        if (u.organizations.count > 0) {
            [u.organizations enumerateObjectsUsingBlock:^(STKOrgStatus *obj, BOOL *stop) {
                if ([obj.status isEqualToString:@"active"]) {
                    org = obj.organization;
                    [[NSUserDefaults standardUserDefaults] setObject:org.uniqueID forKey:@"HAGroupContextString"];
                    *stop = YES;
                }
            }];
        }
    }
    return org;
}

- (void)changeOrgForUser:(STKOrganization *)org
{
    [[NSUserDefaults standardUserDefaults] setObject:org.uniqueID forKey:@"HAGroupContextString"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"UserDetailsUpdated" object:nil];
}

- (BOOL)currentUserIsOrgLeader
{
    __block BOOL isLeader = YES;
    STKOrganization *activeOrg = [self activeOrgForUser];
    [self.currentUser.organizations enumerateObjectsUsingBlock:^(STKOrgStatus *obj, BOOL *stop) {
        if ([obj.organization.uniqueID isEqualToString:activeOrg.uniqueID]) {
            if ([obj.role isEqualToString:@"leader"]) {
                isLeader = YES;
            }
            *stop = YES;
        }
    }];
    return isLeader;
}

- (BOOL)currentUserIsLeaderOfGroup:(STKGroup *)group
{
    __block BOOL isLeader = YES;
    STKOrganization *activeOrg = [self activeOrgForUser];
    [self.currentUser.organizations enumerateObjectsUsingBlock:^(STKOrgStatus *obj, BOOL *stop) {
        if ([obj.organization.uniqueID isEqualToString:activeOrg.uniqueID]) {
            [obj.groups enumerateObjectsUsingBlock:^(STKGroup *g, BOOL *stopB) {
                if ([group.uniqueID isEqualToString:g.uniqueID]) {
                    if ([group.leader.uniqueID isEqualToString:self.currentUser.uniqueID]) {
                        isLeader = YES;
                    }
                    *stopB = YES;
                }
            }];
            *stop = YES;
        }
    }];
    return isLeader;
}

- (NSFetchedResultsController *)groupsForCurrentUserInOrganization:(STKOrganization *)org
{
    [NSFetchedResultsController deleteCacheWithName:@"MessageGroups"];
    NSPredicate *predicate = nil;
    NSFetchRequest *fr = [[NSFetchRequest alloc] initWithEntityName:@"STKGroup"];
    if ([self.currentUser.type isEqualToString:STKUserTypeInstitution]) {
        predicate = [NSPredicate predicateWithFormat:@"organization.uniqueID == %@ && status == %@", org.uniqueID, @"active"];
    } else {
        predicate = [NSPredicate predicateWithFormat:@"organization.uniqueID == %@ && status == %@ && (SUBQUERY(members, $item, $item.member.uniqueID == %@).@count <> 0)", org.uniqueID, @"active", self.currentUser.uniqueID];
    }

    [fr setPredicate:predicate];
    NSSortDescriptor *desc = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
    [fr setSortDescriptors:@[desc]];
    
    NSFetchedResultsController *frc = [[NSFetchedResultsController alloc] initWithFetchRequest:fr managedObjectContext:self.context sectionNameKeyPath:nil cacheName:@"MessageGroups"];
    [self fetchGroupsForOrganization:org completion:^(NSArray *groups, NSError *err) {
        [self.context save:nil];
    }];
    return frc;
}

@end

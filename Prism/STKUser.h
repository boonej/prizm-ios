//
//  STKUser.h
//  Prism
//
//  Created by Joe Conway on 11/20/13.
//  Copyright (c) 2013 Higher Altitude. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "STKJSONObject.h"


#import <GoogleOpenSource/GoogleOpenSource.h>
#import <GooglePlus/GooglePlus.h>

@class STKActivityItem, STKPost, STKTrust, STKInterest, STKTheme, STKOrganization;

extern NSString * const STKUserGenderMale;
extern NSString * const STKUserGenderFemale;
extern NSString * const STKUserGenderUnknown;

extern NSString * const STKUserExternalSystemFacebook;
extern NSString * const STKUserExternalSystemTwitter;
extern NSString * const STKUserExternalSystemGoogle;

extern CGSize STKUserCoverPhotoSize;
extern CGSize STKUserProfilePhotoSize;

extern NSString * const STKUserTypePersonal;
extern NSString * const STKUserTypeInstitution;
extern NSString * const STKUserTypeInstitutionPending;

extern NSString * const STKUserSubTypeKey;
extern NSString * const STKUserSubTypeMilitary;
extern NSString * const STKUserSubTypeFoundation;
extern NSString * const STKUserSubTypeCompany;
extern NSString * const STKUserSubTypeCommunity;
extern NSString * const STKUserSubTypeEducation;
extern NSString * const STKUserSubTypeLuminary;
extern NSString *const STKIntroCompletedKey;
extern NSString *const STKPrivacyInstructionsDismissedKey;

extern BOOL const STKUserStatusActive;
extern BOOL const STKUserStatusInActive;


@interface STKUser : NSManagedObject <STKJSONObject>

@property (nonatomic) NSString *uniqueID;

@property (nonatomic, retain) NSDate *birthday;
@property (nonatomic, strong) NSString *city;
@property (nonatomic, strong) NSDate *dateCreated;
@property (nonatomic, strong) NSDate *dateDeleted;
@property (nonatomic, retain) NSString *email;
@property (nonatomic, retain) NSString *firstName;
@property (nonatomic, retain) NSString *lastName;
@property (nonatomic, strong) NSSet *interests;


@property (nonatomic, strong) NSString *externalServiceType;
@property (nonatomic, strong) NSString *externalServiceID;
@property (nonatomic, retain) NSString *programCode;

@property (nonatomic, strong) NSString *state;
@property (nonatomic, retain) NSString *zipCode;
@property (nonatomic, retain) NSString *gender;

@property (nonatomic, strong) NSString *blurb;
@property (nonatomic, strong) NSString *website;
@property (nonatomic, strong) NSString *type;
@property (nonatomic, strong) NSString *subtype;
@property (nonatomic, strong) NSString *coverPhotoPath;
@property (nonatomic, strong) NSString *profilePhotoPath;

@property (nonatomic, strong) NSString *religion;
@property (nonatomic, strong) NSString *ethnicity;

@property (nonatomic, strong) NSString *instagramToken;
@property (nonatomic, strong) NSString *instagramLastMinID;
@property (nonatomic, strong) NSString *twitterID;
@property (nonatomic, strong) NSString *twitterLastMinID;
@property (nonatomic, strong) NSString *tumblrTokenSecret;
@property (nonatomic, strong) NSString *tumblrToken;
@property (nonatomic, strong) NSString *tumblrLastMinID;


@property (nonatomic, strong) NSDate *dateFounded;
@property (nonatomic, strong) NSString *mascotName;
@property (nonatomic) NSString *enrollment;
@property (nonatomic, strong) NSString *phoneNumber;

@property (nonatomic) int followerCount;
@property (nonatomic) int followingCount;
@property (nonatomic) int postCount;
@property (nonatomic) int trustCount;
@property (nonatomic) int insightCount;

@property (nonatomic, strong) NSSet *ownedTrusts;
@property (nonatomic, strong) NSSet *receivedTrusts;
@property (nonatomic, strong) NSSet *followers;
@property (nonatomic, strong) NSSet *following;
@property (nonatomic, strong) NSSet *comments;
@property (nonatomic, strong) NSSet *createdPosts;
@property (nonatomic, strong) NSSet *likedComments;
@property (nonatomic, strong) NSSet *likedPosts;
@property (nonatomic, strong) NSSet *fFeedPosts;
@property (nonatomic, strong) NSSet *fProfilePosts;
@property (nonatomic, strong) NSSet *createdActivities;
@property (nonatomic, strong) NSSet *ownedActivities;
@property (nonatomic, strong) NSSet *postsTaggedIn;
@property (nonatomic, retain) NSSet *organizations;
@property (nonatomic, retain) NSSet *messages;
@property (nonatomic, retain) NSSet *likedMessages;
@property (nonatomic, strong) STKTheme *theme;
@property (nonatomic, strong) STKOrganization *organization;
@property (nonatomic, strong) STKOrganization *ownedOrganization;

@property (nonatomic, strong) NSString *accountStoreID;
@property (nonatomic, assign) BOOL active;
@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSString *contactFirstName;
@property (nonatomic, retain) NSString *contactLastName;
@property (nonatomic, retain) NSString *contactEmail;
@property (nonatomic, strong) NSString *completeDate;

- (STKTrust *)trustForUser:(STKUser *)u;
- (BOOL)isFollowedByUser:(STKUser *)u;
- (BOOL)isFollowingUser:(STKUser *)u;

- (BOOL)shouldDisplayGraphInstructions;
- (BOOL)shouldDisplayHomeFeedInstructions;
- (BOOL)shouldDisplayTrustInstructions;
- (BOOL)shouldDisplayIntroScreen;
- (BOOL)shouldDisplayPostInstructions;

- (BOOL)isInstitution;
- (BOOL)isLuminary;
- (BOOL)isAmbassador;

- (BOOL)hasTrusts;
- (NSArray *)trusts;
- (NSDictionary *)heapProperties;

// For auth/creating - not stored, used only for creating a user.
@property (nonatomic, strong) UIImage *profilePhoto;
@property (nonatomic, strong) UIImage *coverPhoto;
@property (nonatomic, strong) NSString *token;
@property (nonatomic, strong) NSString *secret;
@property (nonatomic, strong) NSString *password;
@property (nonatomic, strong) NSNumber *unreadCount;

- (void)setValuesFromFacebook:(NSDictionary *)vals;
- (void)setValuesFromTwitter:(NSArray *)vals;
- (void)setValuesFromGooglePlus:(GTLPlusPerson *)vals;
- (NSDictionary *)mixpanelProperties;

@end

@interface STKUser (CoreDataGeneratedAccessors)

- (void)addFFeedPostsObject:(STKPost *)object;
- (void)addFFeedPosts:(NSSet *)objects;

- (void)addInterestsObject:(STKInterest *)value;
- (void)removeInterestsObject:(STKInterest *)value;

- (void)addInterests:(NSSet *)values;
- (void)removeInterests:(NSSet *)values;

- (void)addOrganizationsObject:(STKOrganization *)organization;
- (void)removeOrganizationsObject:(STKOrganization *)organization;
- (void)addOrganizations:(NSSet *)organizations;
- (void)removeOrganizations:(NSSet *)organizations;
- (NSInteger)matchingInterestsCount;

@end



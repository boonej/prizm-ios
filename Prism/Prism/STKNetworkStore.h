//
//  STKNetworkStore.h
//  Prism
//
//  Created by Joe Conway on 4/2/14.
//  Copyright (c) 2014 Higher Altitude. All rights reserved.
//

#import <Foundation/Foundation.h>

@class STKUser;

typedef enum {
    STKNetworkTypeInstagram,
    STKNetworkTypeTwitter,
    STKNetworkTypeTumblr
} STKNetworkType;

@import Social;

@interface STKNetworkStore : NSObject

+ (STKNetworkStore *)store;

- (void)checkAndFetchPostsFromOtherNetworksForCurrentUserCompletion:(void (^)(NSDictionary *updatedUserValues, NSError *err))block;
- (void)establishMinimumIDForUser:(STKUser *)u networkType:(STKNetworkType)type completion:(void (^)(NSString *minID, NSError *err))block;

@end

//
//  STKBaseStore.m
//  Prism
//
//  Created by Joe Conway on 12/26/13.
//  Copyright (c) 2013 Higher Altitude. All rights reserved.
//

#import "STKBaseStore.h"
#import "STKConnection.h"
#import "STKAuthorizationToken.h"

@import Security;

#ifdef BASE_URL_DEV
NSString * const STKUserBaseURLString = @"https://prizm-fe-prd-1163268161.us-west-2.elb.amazonaws.com";
//NSString * const STKPrismRedirectURI = @"https://ec2-54-186-28-238.us-west-2.compute.amazonaws.com/callback";
NSString * const STKPrismRedirectURI = @"https://prizm-fe-prd-1163268161.us-west-2.elb.amazonaws.com/callback";
#elif BASE_URL_STAGING
NSString * const STKUserBaseURLString = @"https://prizm-fe-prd-1163268161.us-west-2.elb.amazonaws.com";
NSString * const STKPrismRedirectURI = @"https://prizm-fe-prd-1163268161.us-west-2.elb.amazonaws.com/callback";
#elif BASE_URL_USERTESTING
//NSString * const STKUserBaseURLString = @"https://sleepy-eyrie-3962.herokuapp.com";
//NSString * const STKPrismRedirectURI = @"https://sleepy-eyrie-3962.herokuapp.com/callback";
NSString * const STKUserBaseURLString = @"https://localhost:3000";
NSString * const STKPrismRedirectURI = @"https://localhost:3000/callback";
#elif BASE_URL_PRODUCTION
NSString * const STKUserBaseURLString = @"https://prizm-fe-prd-1163268161.us-west-2.elb.amazonaws.com";
NSString * const STKPrismRedirectURI = @"https://prizm-fe-prd-1163268161.us-west-2.elb.amazonaws.com/callback";
#endif

NSString * const STKPrismClientSecret = @"f27198fb-689d-4965-acb0-0e9c5f61ddec";
NSString * const STKPrismClientID = @"67e1fe4f-db1b-4d5c-bdc7-56270b0822e2";

NSString * const STKBaseStoreEndpointAuthorization = @"/oauth2/authorize";
NSString * const STKBaseStoreEndpointToken = @"/oauth2/token";

NSString * const STKSessionEndedNotification = @"STKUserStoreCurrentUserSessionEndedNotification";
NSString * const STKSessionEndedReasonKey = @"STKUserStoreCurrentUserSessionEndedReasonKey";
NSString * const STKSessionEndedConnectionValue = @"STKUserStoreCurrentUserSessionEndedConnectionValue";
NSString * const STKSessionEndedAuthenticationValue = @"STKUserStoreCurrentUserSessionEndedAuthenticationValue";
NSString * const STKSessionEndedLogoutValue = @"STKUserStoreCurrentUserSessionEndedLogoutValue";

NSString * const STKAuthenticationErrorDomain = @"STKAuthenticationErrorDomain";

@interface STKBaseStore () <NSURLSessionDelegate>

@property (nonatomic, strong) NSMutableArray *authorizedRequestQueue;
@property (nonatomic, getter = isAuthenticating) BOOL authenticating;

@end

@implementation STKBaseStore

+ (STKBaseStore *)store
{
    static STKBaseStore *store = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        store = [[STKBaseStore alloc] init];
    });
    
    return store;
}

+ (NSURL *)baseURL
{
    return [NSURL URLWithString:STKUserBaseURLString];
}

- (id)init
{
    self = [super init];
    if(self) {
        _authorizedRequestQueue = [[NSMutableArray alloc] init];
        

        
        _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                                 delegate:self
                                            delegateQueue:[NSOperationQueue mainQueue]];
        

        
        //     "error": "OAuthException",
//        "error_description": "Error validating access token: The session has been invalidated because the user has changed the password."


    }
    return self;
}

- (void)cancelAllQueuedRequests
{
    NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
    for(void (^req)(NSError *err) in [self authorizedRequestQueue]) {
        req(error);
    }
    [[self authorizedRequestQueue] removeAllObjects];
}

- (void)executeAuthorizedRequest:(void (^)(NSError *))request
{
    if([self authorizationToken] && [[[self authorizationToken] expiration] timeIntervalSinceNow] > 10) {
        request(nil);
    } else {
        [[self authorizedRequestQueue] addObject:request];
        
        if(![self isAuthenticating]) {
            [self setAuthenticating:YES];
            void (^completion)(STKAuthorizationToken *token, NSError *err) = ^(STKAuthorizationToken *token, NSError *err) {
                [self setAuthenticating:NO];
                
                NSArray *requests = [[self authorizedRequestQueue] copy];
                [[self authorizedRequestQueue] removeAllObjects];

                for(void (^req)(NSError *err) in requests) {
                    req(err);
                }
            };
            
            if([[self authorizationToken] refreshToken]) {
                [self refreshAccessToken:completion];
            } else {
                [self fetchAccessToken:completion];
            }
        }
    }
}



- (void)URLSession:(NSURLSession *)session
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler
{
    if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]){
        NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
    } 
}

- (NSString *)authenticationString
{
    NSString *authHeaderValue = [NSString stringWithFormat:@"%@:%@", STKPrismClientID, STKPrismClientSecret];
    NSString *base64EncodedValue = [[authHeaderValue dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
    return [NSString stringWithFormat:@"Basic %@", base64EncodedValue];
}

- (void)fetchAuthorizationCodeCompletion:(void (^)(NSString *code, NSError *err))block
{
    STKConnection *c = [self newConnectionForIdentifiers:@[STKBaseStoreEndpointAuthorization]];
    
    [c addQueryValue:@"code" forKey:@"response_type"];
    [c addQueryValue:STKPrismClientID forKey:@"client_id"];
    [c addQueryValue:STKPrismRedirectURI forKey:@"redirect_uri"];
    
    [c setAuthorizationString:[self authenticationString]];

    [c getWithSession:[self session] completionBlock:^(NSDictionary *obj, NSError *err) {
        NSString *authCode = [obj objectForKey:@"authorization_code"];
        block(authCode, err);
    }];
}

- (void)fetchAccessToken:(void (^)(STKAuthorizationToken *token, NSError *err))block
{
    [self fetchAuthorizationCodeCompletion:^(NSString *code, NSError *err) {
        if(!err) {
            STKConnection *c = [self newConnectionForIdentifiers:@[STKBaseStoreEndpointToken]];
            [c addQueryValue:code forKey:@"code"];
            [c addQueryValue:@"authorization_code" forKey:@"grant_type"];
            [c addQueryValue:STKPrismRedirectURI forKey:@"redirect_uri"];
            [c setAuthorizationString:[self authenticationString]];
            
            [c setModelGraph:@[@"STKAuthorizationToken"]];
            
            [c postWithSession:[self session] completionBlock:^(STKAuthorizationToken *obj, NSError *err) {
                [self setAuthorizationToken:obj];
                block(obj, err);
            }];
        } else {
            block(nil, err);
        }
    }];
}

- (void)refreshAccessToken:(void (^)(STKAuthorizationToken *token, NSError *err))block
{
    STKConnection *c = [self newConnectionForIdentifiers:@[STKBaseStoreEndpointToken]];
    [c addQueryValue:[[self authorizationToken] refreshToken] forKey:@"code"];
    [c addQueryValue:@"refresh_token" forKey:@"grant_type"];
    [c addQueryValue:STKPrismRedirectURI forKey:@"redirect_uri"];
    [c setAuthorizationString:[self authenticationString]];
    
    [c setModelGraph:@[[STKAuthorizationToken class]]];
    
    [c postWithSession:[self session] completionBlock:^(STKAuthorizationToken *obj, NSError *err) {
        [self setAuthorizationToken:obj];
        block(obj, err);
    }];
}


- (STKConnection *)newConnectionForIdentifiers:(NSArray *)identifiers
{
    STKConnection *c = [[STKConnection alloc] initWithBaseURL:[[self class] baseURL]
                                                  identifiers:identifiers];
    
    if([self authorizationToken]) {
        [c setAuthorizationString:[NSString stringWithFormat:@"Bearer %@", [[self authorizationToken] accessToken]]];
    }
    
    return c;
}




@end

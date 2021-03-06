//
//  STKConnection.h
//
//  Created by Joe Conway on 3/26/13.
//  Copyright (c) 2013 Stable Kernel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STKJSONObject.h"
#import "STKQueryObject.h"
#import "STKResolutionQuery.h"
#import "STKContainQuery.h"
#import "STKSearchQuery.h"

@import CoreData;

extern NSString * const STKConnectionUnauthorizedNotification;
extern NSString * const STKConnectionErrorDomain;

typedef enum {
    STKConnectionMethodGET,
    STKConnectionMethodPOST,
    STKConnectionMethodPUT,
    STKConnectionMethodDELETE
} STKConnectionMethod;

extern NSString * const STKConnectionErrorDomain;

typedef enum {
    STKConnectionErrorCodeBadRequest,
    STKConnectionErrorCodeParseFailed,
    STKConnectionErrorCodeRequestFailed,
    STKConnectionErrorCodeInvalidModelGraph
    
} STKConnectionErrorCode;

@interface STKConnection : NSObject

+ (NSMutableArray *)activeConnections;
+ (void)cancelAllConnections;

- (id)initWithBaseURL:(NSURL *)url identifiers:(NSArray *)identifiers;

// Request Information
@property (nonatomic) STKConnectionMethod method;
@property (nonatomic, strong) NSArray *identifiers;
@property (nonatomic, strong) NSDictionary *additionalHeaders;
@property (nonatomic, strong) NSString *authorizationString;
@property (nonatomic, strong) NSData *HTTPBody;
@property (nonatomic, strong) STKQueryObject *queryObject;

@property (nonatomic, readonly) NSURLRequest *request;

// Parsing Information
@property (nonatomic, strong) id <STKJSONObject> jsonRootObject;

@property (nonatomic, strong) NSManagedObjectContext *context;
@property (nonatomic, copy) NSString *entityName;

@property (nonatomic, strong) NSDictionary *resolutionMap;
@property (nonatomic) BOOL shouldReturnArray;

// { localKey : remoteKey, ... }
@property (nonatomic, strong) NSDictionary *existingMatchMap;
@property (nonatomic, copy) void (^insertionBlock)(NSManagedObject *rootObject);

// Pass either an array or dictionary containing any number of arrays, dictionaries and strings.
// The structure of the modelGraph is used is to match the structure of the incoming JSON.

// For example, pass @{@"jsonFieldName" : @[@"ClassName]}, will search internal data for key jsonFieldName,
// assume it is an array, and each object in that array will be parsed into ClassName.
// If used in conjunction with context, ClassName will be treated as Core data entities
// Only supports homogenous arrays.
@property (nonatomic, strong) id modelGraph;

// Response Information
@property (nonatomic) NSInteger statusCode;
@property (nonatomic, copy) void (^completionBlock)(id obj, NSError *err);

- (void)beginWithSession:(NSURLSession *)session;
- (void)beginWithSession:(NSURLSession *)session method:(STKConnectionMethod)method completionBlock:(void (^)(id obj, NSError *err))block;

- (void)postWithSession:(NSURLSession *)session completionBlock:(void (^)(id obj, NSError *err))block;
- (void)putWithSession:(NSURLSession *)session completionBlock:(void (^)(id obj, NSError *err))block;
- (void)getWithSession:(NSURLSession *)session completionBlock:(void (^)(id obj, NSError *err))block;
- (void)deleteWithSession:(NSURLSession *)session completionBlock:(void (^)(id obj, NSError *err))block;

- (void)addQueryValue:(id)value forKey:(NSString *)key;
- (void)addQueryValues:(NSDictionary *)dict;

// ------

- (id)populateModelGraphWithData:(id)incomingData error:(NSError **)err;
- (id)populateModelObjectWithData:(id)incomingData error:(NSError **)err;

- (void)reportFailureWithError:(NSError *)err;

@end

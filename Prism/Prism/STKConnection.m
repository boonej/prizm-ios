//
//  STKConnection.m
//  STK
//
//  Created by Joe Conway on 3/26/13.
//  Copyright (c) 2013 STable Kernel. All rights reserved.
//

#import "STKConnection.h"
#import "NSError+STKConnection.h"

NSString * const STKConnectionUnauthorizedNotification = @"STKConnectionUnauthorizedNotification";
NSString * const STKConnectionErrorDomain = @"STKConnectionErrorDomain";


@interface STKConnection ()

@property (nonatomic, weak) NSURLSessionDataTask *internalConnection;
@property (nonatomic, strong) NSMutableDictionary *internalArguments;

@property (nonatomic, strong) NSURL *baseURL;

@property (nonatomic) NSDate *beginTime;


@end

@implementation STKConnection

+ (NSMutableArray *)activeConnections
{
    static NSMutableArray *sharedConnectionList = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedConnectionList = [[NSMutableArray alloc] init];
    });
    return sharedConnectionList;
}

- (id)initWithBaseURL:(NSURL *)url identifiers:(NSArray *)resourceIdentifiers
{
    self = [super init];
    if (self) {
        [self setMethod:STKConnectionMethodGET];
        _internalArguments = [[NSMutableDictionary alloc] init];

        _baseURL = url;
        _identifiers = resourceIdentifiers;

    }
    return self;
}

- (void)beginWithSession:(NSURLSession *)session method:(STKConnectionMethod)method completionBlock:(void (^)(id obj, NSError *err))block
{
    [self setCompletionBlock:block];
    [self setMethod:method];
    [self beginWithSession:session];
}

- (void)beginWithSession:(NSURLSession *)session
{
    _beginTime = [NSDate date];
    
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:[self baseURL]
                                               resolvingAgainstBaseURL:NO];
    if([self identifiers]) {
        NSString *pathIdentifier = [[self identifiers] componentsJoinedByString:@"/"];
//        NSLog(@"Path: %@", pathIdentifier);
        [components setPath:pathIdentifier];
    }
    
    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] init];

    if([[self internalArguments] count] > 0) {
        if([self method] == STKConnectionMethodPOST || [self method] == STKConnectionMethodPUT || [self method] == STKConnectionMethodDELETE) {
            NSError *err;
            if ([NSJSONSerialization isValidJSONObject:[self internalArguments]]) {
            NSData *body =[ NSJSONSerialization dataWithJSONObject:[self internalArguments] options:0 error:&err];
            if (!err) {
                [req setHTTPBody:body];
            } else {
//                NSLog(@"%@", err.localizedDescription);
            }
            }
            [req addValue:@"application/json;charset=utf-8" forHTTPHeaderField:@"Content-Type"];
        } else {
            NSMutableString *queryString = [[NSMutableString alloc] init];
            NSArray *allKeys = [[self internalArguments] allKeys];
            for(NSString *key in allKeys) {
                NSString *value = [[self internalArguments] objectForKey:key];
                
                [queryString appendFormat:@"%@=%@", key, [value stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLArgumentAllowedCharacterSet]]];
                if(key != [allKeys lastObject])
                    [queryString appendString:@"&"];
            }
            
            [components setPercentEncodedQuery:queryString];
        }
    }
    
    for(NSString *headerKey in [self additionalHeaders]) {
        [req addValue:[[self additionalHeaders] objectForKey:headerKey] forHTTPHeaderField:headerKey];
    }
    
    if([self queryObject]) {
        NSData *json = [NSJSONSerialization dataWithJSONObject:[[self queryObject] dictionaryRepresentation] options:0 error:nil];
        NSString *encodedJSON = [json base64EncodedStringWithOptions:0];
        [req addValue:encodedJSON forHTTPHeaderField:@"X-Arguments"];
    }
    
    [req setURL:[components URL]];
    
    [req setHTTPMethod:@{@(STKConnectionMethodGET) : @"GET",
                         @(STKConnectionMethodPOST) : @"POST",
                         @(STKConnectionMethodDELETE) : @"DELETE",
                         @(STKConnectionMethodPUT) : @"PUT"}[@([self method])]];

    // If we set the body manually instead of via query key-values
    if(![req HTTPBody])
        [req setHTTPBody:[self HTTPBody]];
    
    if([self authorizationString])
        [req addValue:[self authorizationString] forHTTPHeaderField:@"Authorization"];
    
    _request = [req copy];

    if(![[self request] URL]) {
//        NSLog(@"OK");
    }
    
    NSURLSessionDataTask *dt = [session dataTaskWithRequest:[self request]
                                          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
  /*
                                              NSMutableURLRequest *snapReq = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://localhost:8080/snap"]];
                                              [snapReq setHTTPMethod:@"POST"];
                                              
                                              NSMutableDictionary *snapData = [NSMutableDictionary dictionary];
                                              [snapData setObject:[[self request] allHTTPHeaderFields] forKey:@"RequestHeaders"];
                                              [snapData setObject:[[[self request] URL] absoluteString] forKey:@"URL"];
                                              if([[self request] HTTPBody]) {
                                                  [snapData setObject:[NSJSONSerialization JSONObjectWithData:[[self request] HTTPBody] options:0 error:nil]
                                                               forKey:@"RequestBody"];
                                              }
                                              [snapData setObject:[[self request] HTTPMethod] forKey:@"Method"];
                                              
                                              NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                                              [snapData setObject:[httpResponse allHeaderFields] forKey:@"ResponseHeaders"];
                                              [snapData setObject:@([httpResponse statusCode]) forKey:@"ResponseStatus"];
                                              [snapData setObject:[NSJSONSerialization JSONObjectWithData:data options:0 error:nil] forKey:@"ResponseBody"];
                                              
                                              [snapData setObject:@"1" forKey:@"User"];
                                              
                                              [snapReq setHTTPBody:[NSJSONSerialization dataWithJSONObject:snapData options:0 error:nil]];
                                              
                                              NSURLSessionDataTask *dtSnap = [session dataTaskWithRequest:snapReq completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                  NSLog(@"%@", response);
                                              }];
                                              [dtSnap resume];
                                                                         */
                                              
                                              if(error) {
                                                  [self handleError:error];
                                              } else {
                                                  NSHTTPURLResponse *r = (NSHTTPURLResponse *)response;
                                                  [self setStatusCode:[r statusCode]];
                                                  [self handleSuccess:data];
                                              }
                                          }];
    [self setInternalConnection:dt];

    // If this is the first connection started, create the array
    // Add the connection to the array so it doesn't get destroyed
    [[STKConnection activeConnections] addObject:self];
    
    [dt resume];
}

- (void)putWithSession:(NSURLSession *)session completionBlock:(void (^)(id obj, NSError *err))block
{
    [self setCompletionBlock:block];
    [self setMethod:STKConnectionMethodPUT];
    [self beginWithSession:session];
}

- (void)postWithSession:(NSURLSession *)session completionBlock:(void (^)(id obj, NSError *err))block
{
    [self setCompletionBlock:block];
    [self setMethod:STKConnectionMethodPOST];
    [self beginWithSession:session];
}

- (void)getWithSession:(NSURLSession *)session completionBlock:(void (^)(id obj, NSError *err))block
{
    [self setCompletionBlock:block];
    [self setMethod:STKConnectionMethodGET];
    [self beginWithSession:session];
}

- (void)deleteWithSession:(NSURLSession *)session completionBlock:(void (^)(id obj, NSError *err))block
{
    [self setCompletionBlock:block];
    [self setMethod:STKConnectionMethodDELETE];
    [self beginWithSession:session];
}

- (void)addQueryValue:(id)value forKey:(NSString *)key
{
    if(!value || !key)
        return;
    
    if([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSNull class]]) {
        [_internalArguments setObject:value forKey:key];
    }
}

- (void)addQueryValues:(NSDictionary *)dict
{
    [_internalArguments addEntriesFromDictionary:dict];
}

- (void)handleError:(NSError *)error
{
#ifdef DEBUG
    NSTimeInterval i = [[NSDate date] timeIntervalSinceDate:_beginTime];
    NSString *requestString = [[[self request] URL] absoluteString];
    
    NSString *dataString = @"";
    if([[self request] HTTPBody]) {
        dataString = [[NSString alloc] initWithData:[[self request] HTTPBody] encoding:NSUTF8StringEncoding];
    }
    
    NSString *argHeaders = @"";
    if([self queryObject]) {
        argHeaders = [[[self queryObject] dictionaryRepresentation] description];
    }
    
//    NSLog(@"%@", [self curlRequest]);

    
    NSLog(@"Request Failed (%.3fs) -> \n%@ %@\n %@ \n %@\nResponse: %d\n%@",
          i,
          [[self request] HTTPMethod],
          requestString,
          argHeaders,
          dataString,
          (int)[self statusCode],
          [error localizedDescription]);

#endif

    [self reportFailureWithError:error];
}


- (NSString *)curlRequest
{
    NSMutableString *str = [[NSMutableString alloc] init];
    [str appendString:@"curl "];
    [str appendString:@"--insecure "];
    [str appendFormat:@"-X %@ ", [[self request] HTTPMethod]];
    
    NSDictionary *headers = [[self request] allHTTPHeaderFields];
    for(NSString *key in headers) {
        [str appendFormat:@"--header \"%@: %@\" ", key, [headers objectForKey:key]];
    }
    /*
    if([[self request] HTTPBody]) {
        [str appendFormat:@"--data %@", [[NSString alloc] initWithData:[[self request] HTTPBody] encoding:NSUTF8StringEncoding]];
    }*/
    
    [str appendString:[[[self request] URL] absoluteString]];
    
    return str;
}

- (void)reportFailureWithError:(NSError *)err
{
    if([err isConnectionError]) {
        NSNotificationCenter *connectionNotification = [NSNotificationCenter defaultCenter];
        [connectionNotification postNotificationName:@"STKConnectionNetworkError" object:nil];
    }
    
    if ([self completionBlock]) {
        [self completionBlock](nil, err);
    }
    [[STKConnection activeConnections] removeObject:self];
}

- (void)handleSuccess:(NSData *)data
{
#ifdef DEBUG
    NSTimeInterval i = [[NSDate date] timeIntervalSinceDate:_beginTime];
    NSString *requestString = [[[self request] URL] absoluteString];
    
    NSString *dataString = @"";
    if([[self request] HTTPBody]) {
        dataString = [[NSString alloc] initWithData:[[self request] HTTPBody] encoding:NSUTF8StringEncoding];
    }
    
    NSString *argHeaders = @"";
    if([self queryObject]) {
        argHeaders = [[[self queryObject] dictionaryRepresentation] description];
    }

    NSLog(@"%@", [self curlRequest]);
    
    NSLog(@"Request Finished (%.3fs) -> \n%@ %@\n %@ \n %@\nResponse: %d\n%@", i, [[self request] HTTPMethod], requestString,
          argHeaders, dataString,
          (int)[self statusCode], [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
#endif


    if ([self statusCode] >= 400) {
        if([self statusCode] == 401) {
            [[NSNotificationCenter defaultCenter] postNotificationName:STKConnectionUnauthorizedNotification
                                                                object:self];
        }

        NSMutableDictionary *errDict = [NSMutableDictionary dictionary];
        if([data length] > 0) {
            NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:data
                                                                       options:0
                                                                         error:nil];
            NSDictionary *errObj = [jsonObject objectForKey:@"error"];
            if([errObj objectForKey:@"error"]) {
                [errDict setObject:[errObj objectForKey:@"error"]
                            forKey:@"error"];
            }
            if([errObj objectForKey:@"error_description"]) {
                [errDict setObject:[errObj objectForKey:@"error_description"]
                            forKey:@"error_description"];
            }
        }
        
        
        [self reportFailureWithError:[NSError errorWithDomain:STKConnectionServiceErrorDomain
                                                         code:STKConnectionErrorCodeRequestFailed
                                                     userInfo:errDict]];
        return;
    }

    NSDictionary *jsonObject = nil;
    if([data length] > 0) {
        NSError *error = nil;
        jsonObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            [self reportFailureWithError:[NSError errorWithDomain:STKConnectionServiceErrorDomain
                                                             code:STKConnectionErrorCodeParseFailed
                                                         userInfo:[error userInfo]]];
            return;
        }
    }
    
    
    id rootObject = nil;

    NSDictionary *responseValue = [jsonObject objectForKey:@"metadata"];
    if(responseValue) {
        BOOL success = [[responseValue objectForKey:@"success"] boolValue];
        if(!success) {
            [self reportFailureWithError:[NSError errorWithDomain:STKConnectionServiceErrorDomain
                                                             code:STKConnectionErrorCodeRequestFailed
                                                         userInfo:nil]];
            return;
        }
        
        NSError *err = nil;
        id internalData = [jsonObject objectForKey:@"data"];
        
        if(![self modelGraph]) {
            rootObject = [self populateModelObjectWithData:internalData error:&err];
        } else {
            rootObject = [self populateModelGraphWithData:internalData error:&err];
        }
        
        if(![self shouldReturnArray]) {
            rootObject = [rootObject lastObject];
        }
        
        if(err) {
            [self reportFailureWithError:err];
            return;
        }
    }
    
    // Check for any 'resolves'.
    NSDictionary *resolveData = [jsonObject objectForKey:@"resolve"];
    if(resolveData) {
        [self processResolvedDictionary:resolveData];
    }
    
    // Then, pass the root object to the completion block - remember,
    // this is the block that the controller supplied.
    if ([self completionBlock])
        [self completionBlock](rootObject, nil);
    
    // Now, destroy this connection
    [[STKConnection activeConnections] removeObject:self];
}

- (id)populateModelGraphWithData:(id)incomingData error:(NSError **)err
{
    return [self populateModelGraphWithData:incomingData
                                       node:[self modelGraph]
                                      error:err];
}

- (id)populateModelGraphWithData:(id)incomingData node:(id)node error:(NSError **)err
{
    // This is a messy way of handling the fact that you can't do a strict
    // class comparison for all of these class clusters.
    if ([node isKindOfClass:[NSArray class]]) {
        
        if(![incomingData isKindOfClass:[NSArray class]]) {
            if(err) {
                *err = [NSError errorWithDomain:STKConnectionErrorDomain
                                           code:STKConnectionErrorCodeInvalidModelGraph
                                       userInfo:@{@"expected" : @"NSArray", @"received" : NSStringFromClass([incomingData class])}];
            }
            return nil;
        }

        NSMutableArray *collection = [NSMutableArray array];
        NSString *internalNode = [node firstObject];
        for(id innerObj in incomingData) {
            NSError *internalError = nil;
            id parsedObject = [self populateModelGraphWithData:innerObj node:internalNode error:&internalError];
            if(internalError) {
                *err = internalError;
                return nil;
            }

            [collection addObject:parsedObject];
        }
        return collection;
    } else if([node isKindOfClass:[NSDictionary class]]) {
        
        if(![incomingData isKindOfClass:[NSDictionary class]]) {
            if(err) {
                *err = [NSError errorWithDomain:STKConnectionErrorDomain
                                           code:STKConnectionErrorCodeInvalidModelGraph
                                       userInfo:@{@"expected" : @"NSDictionary", @"received" : NSStringFromClass([incomingData class])}];
            }
            return nil;
        }
        
        NSMutableDictionary *collection = [NSMutableDictionary dictionary];
        for(NSString *key in node) {
            id innerNode = [node objectForKey:key];
            id incomingInnerObject = [incomingData objectForKey:key];
            
            NSError *internalError = nil;
            id parsedObject = [self populateModelGraphWithData:incomingInnerObject node:innerNode error:&internalError];
            if(internalError) {
                *err = internalError;
                return nil;
            }
            
            [collection setObject:parsedObject forKey:key];
        }
        return collection;
    } else {
        
        if(![incomingData isKindOfClass:[NSDictionary class]]) {
            if(err) {
                *err = [NSError errorWithDomain:STKConnectionErrorDomain
                                           code:STKConnectionErrorCodeInvalidModelGraph
                                       userInfo:@{@"expected" : @"NSDictionary-Model or Model", @"received" : NSStringFromClass([incomingData class])}];
            }
            return nil;
        }
        
        id obj = nil;
        if([node isKindOfClass:[NSString class]]) {
            if([self context]) {
                obj = [[self context] instanceForEntityName:node
                                                     sourceObject:incomingData
                                                   matchMap:[self existingMatchMap]
                                              alreadyExists:nil];
            } else
                obj = [[NSClassFromString(node) alloc] init];
        } else if ([node class] == node) {
            obj = [[node alloc] init];
        } else {
            obj = node;
        }
        
        NSError *resultErr = [obj readFromJSONObject:incomingData];
        if(resultErr) {
            if(err) {
                *err = resultErr;
            }
        }
        return obj;
    }
    return nil;
}

- (id)populateModelObjectWithData:(id)incomingData error:(NSError **)err
{
    if([self jsonRootObject]) {
        NSError *jsonErr = [[self jsonRootObject] readFromJSONObject:incomingData];
        if(err) {
            *err = jsonErr;
        }

        return [self jsonRootObject];
    } else if ([self entityName]) {
        
        id obj = [[self context] instanceForEntityName:[self entityName]
                                                sourceObject:incomingData
                                              matchMap:[self existingMatchMap]
                                         alreadyExists:nil];
        
        NSError *jsonErr = [obj readFromJSONObject:incomingData];
        if(err) {
            *err = jsonErr;
        }
        
        return obj;
    }
    return incomingData;
}

     
- (void)processResolvedDictionary:(NSDictionary *)dict
{
    NSDictionary *resolveToEntityMap = [self resolutionMap];
    for(NSString *key in dict) {
        NSString *entity = [resolveToEntityMap objectForKey:key];
        for(NSString *idKey in [dict objectForKey:key]) {
            NSManagedObject <STKJSONObject> * instance = [[self context] instanceForEntityName:entity
                                                                                  sourceObject:@{@"_id" : idKey}
                                                                                      matchMap:@{@"uniqueID" : @"_id"}
                                                                                 alreadyExists:nil];
            [instance readFromJSONObject:[[dict objectForKey:key] objectForKey:idKey]];
        }
    }
}


+ (void)cancelAllConnections {
	
	for (STKConnection *connection in [STKConnection activeConnections]) {
		[connection.internalConnection cancel];
	}
    [[STKConnection activeConnections] removeAllObjects];
}


@end

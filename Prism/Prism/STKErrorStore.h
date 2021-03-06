//
//  STKErrorStore.h
//  Prism
//
//  Created by Joe Conway on 12/19/13.
//  Copyright (c) 2013 Higher Altitude. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const STKErrorUserDoesNotExist;
extern NSString * const STKErrorBadPassword;
extern NSString * const STKErrorInvalidRequest;
extern NSString * const STKErrorTrustLimit;

@interface STKErrorStore : NSObject

+ (UIAlertView *)alertViewForError:(NSError *)err
                          delegate:(id <UIAlertViewDelegate>)delegate;
+ (UIAlertView *)alertViewForErrorWithOriginMessage:(NSError *)err
                                           delegate:(id <UIAlertViewDelegate>)delegate;
+ (NSString *)errorStringForError:(NSError *)err;

@end

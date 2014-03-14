//
//  STKImageSharer.h
//  Prism
//
//  Created by Joe Conway on 3/5/14.
//  Copyright (c) 2014 Higher Altitude. All rights reserved.
//

#import <Foundation/Foundation.h>

@class STKPost;

@interface STKImageSharer : NSObject

+ (STKImageSharer *)defaultSharer;

- (UIActivityViewController *)activityViewControllerForImage:(UIImage *)image
                                                        text:(NSString *)text
                                               finishHandler:(void (^)(UIDocumentInteractionController *))block;

- (UIActivityViewController *)activityViewControllerForImage:(UIImage *)image
                                                        text:(NSString *)text
                                                      object:(id)object
                                               finishHandler:(void (^)(UIDocumentInteractionController *))block;

@end

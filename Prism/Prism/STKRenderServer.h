//
//  STKRenderServer.h
//  Prism
//
//  Created by Joe Conway on 11/25/13.
//  Copyright (c) 2013 Higher Altitude. All rights reserved.
//

#import <Foundation/Foundation.h>

@class STKRenderProvider;

@interface STKRenderServer : NSObject

+ (STKRenderServer *)renderServer;

- (UIImage *)instantBlurredImageForView:(UIView *)view inSubrect:(CGRect)rect;
- (UIImage *)backgroundBlurredImageForView:(UIView *)view inSubrect:(CGRect)rect;
- (UIImage *)blurredImageWithImage:(UIImage *)img affineClamp:(BOOL)clamp;

@end

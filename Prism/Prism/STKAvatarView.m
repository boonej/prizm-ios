//
//  STKAvatarView.m
//  Prism
//
//  Created by Joe Conway on 3/6/14.
//  Copyright (c) 2014 Higher Altitude. All rights reserved.
//

#import "STKAvatarView.h"
#import "STKImageStore.h"


@implementation STKAvatarView

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if(self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if(self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit
{
    [self setBackgroundColor:[UIColor clearColor]];
}

- (void)setUrlString:(NSString *)urlString
{
    _urlString = urlString;
    
    [self setImage:nil];
    
    if(_urlString) {
        __weak STKAvatarView *iv = self;
        [[STKImageStore store] fetchImageForURLString:_urlString
                                           completion:^(UIImage *img) {
                                               if([urlString isEqualToString:[iv urlString]]) {
                                                   [iv setImage:img];
                                                   [iv setNeedsDisplay];
                                               }
                                           }];
    }
    
}


- (void)drawRect:(CGRect)rect
{
//    UIBezierPath *bpOuter = [UIBezierPath bezierPathWithOvalInRect:CGRectInset([self bounds], 1, 1)];
    UIBezierPath *bpInner = [UIBezierPath bezierPathWithOvalInRect:[self bounds]];

    UIGraphicsPushContext(UIGraphicsGetCurrentContext());
    [bpInner addClip];
    [[self image] drawInRect:[self bounds]];
    UIGraphicsPopContext();
    
    [[UIColor colorWithRed:135 / 255.0 green:135 / 255.0 blue:162 / 255.0 alpha:1] set];
    [bpInner setLineWidth:2];
    [bpInner stroke];
}

@end
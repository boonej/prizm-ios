//
//  STKCircleView.m
//  Prism
//
//  Created by Joe Conway on 11/18/13.
//  Copyright (c) 2013 Higher Altitude. All rights reserved.
//

#import "STKCircleView.h"

@implementation STKCircleView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];

    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if(self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit
{
    [self setBackgroundColor:[UIColor clearColor]];
}

- (void)setImage:(UIImage *)image
{
    _image = image;
    [self setNeedsDisplay];
}
- (void)setBorderColor:(UIColor *)borderColor
{
    _borderColor = borderColor;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    CGRect r = CGRectInset([self bounds], 2, 2);
    UIBezierPath *bp = [UIBezierPath bezierPathWithOvalInRect:r];
    if([self borderColor])
        [[self borderColor] set];
    else
        [STKTextColor set];
    [bp setLineWidth:4];
    [bp stroke];
    [bp addClip];
    
    if([self image]) {
        [[self image] drawInRect:r];
    } else {
        [[UIColor whiteColor] set];
        [bp fill];
    }
}


@end

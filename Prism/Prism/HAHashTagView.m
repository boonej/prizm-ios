//
//  HAHashTagView.m
//  Prizm
//
//  Created by Jonathan Boone on 9/18/14.
//  Copyright (c) 2014 Higher Altitude. All rights reserved.
//

#import "HAHashTagView.h"

@implementation HAHashTagView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        CGRect labelFrame = frame;
        labelFrame.origin.x = 0;
        labelFrame.origin.y = 0;
        self.textLabel = [[UILabel alloc] initWithFrame:labelFrame];
        [self.textLabel setTextColor:STKTextColor];
        [self.textLabel setFont:STKFont(17)];
        UITapGestureRecognizer *tr = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hashTagTapped:)];
        [self addGestureRecognizer:tr];
        [self addSubview:self.textLabel];
        _selected = NO;
    }
    return self;
}

- (void)setText:(NSString *)text
{
    _text = text;
    [self.textLabel setText:[NSString stringWithFormat:@"#%@", _text]];
    [self.textLabel sizeToFit];
    CGRect frame = self.frame;
    frame.size = self.textLabel.bounds.size;
    [self setFrame:frame];
}

- (void)hashTagTapped:(UIGestureRecognizer *)gr
{
    [self setSelected:![self isSelected]];
    if ([self isSelected]) {
        [self setAlpha:1.0f];
        [self.textLabel setTextColor:[UIColor whiteColor]];
        [UIView animateWithDuration:0.5 animations:^{
            self.transform = CGAffineTransformMakeScale(1.3, 1.3);
        }];
    } else {
        [self setAnimating:YES];
        [UIView animateWithDuration:0.5 animations:^{
            [self.textLabel setTextColor:STKTextColor];
            self.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
        } completion:^(BOOL finished) {
            [self setAnimating:NO];
        }];
    }
    if (self.delegate) {
        [self.delegate hashTagTapped:self];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInView:self.superview];
    self.center = location;
    return;
}

- (void)presentAndDismiss
{
    if (! [self isAnimating]) {
        [self setAnimating:YES];
        self.center = randomPointWithinContainer(self.superview.bounds.size, self.bounds.size);
        [UIView animateWithDuration:2.f animations:^{
            [self setAlpha:1.f];
        } completion:^(BOOL finished) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (![self isSelected]) {
                    [UIView animateWithDuration:1.f animations:^{
                        [self setAlpha:0.f];
                    } completion:^(BOOL finished) {
                        [self setAnimating:NO];
                    }];
                } else {
                    [self setAnimating:NO];
                }
            });
        }];
    }
}



/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
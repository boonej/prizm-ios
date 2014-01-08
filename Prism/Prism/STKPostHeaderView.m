//
//  STKPostHeaderView.m
//  Prism
//
//  Created by Joe Conway on 1/6/14.
//  Copyright (c) 2014 Higher Altitude. All rights reserved.
//

#import "STKPostHeaderView.h"
#import "STKResolvingImageView.h"

@interface STKPostHeaderView ()
@property (nonatomic, strong) UIImageView *timeImageView;
@end

@implementation STKPostHeaderView

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
    self = [super initWithFrame:CGRectMake(0, 0, 300, 48)];
    if (self) {
      }
    return self;
}

- (void)commonInit
{
    [self setBackgroundColor:[UIColor clearColor]];
    _avatarView = [[STKResolvingImageView alloc] init];
    _posterLabel = [[UILabel alloc] init];
    _timeLabel = [[UILabel alloc] init];
    _sourceLabel = [[UILabel alloc] init];
    _postTypeView = [[UIImageView alloc] init];
    _timeImageView = [[UIImageView alloc] init];
    
    [_posterLabel setFont:STKFont(20)];
    [_posterLabel setTextColor:STKTextColor];

    [_timeLabel setFont:STKFont(8)];
    [_timeLabel setTextColor:STKTextTransparentColor];
    
    [_sourceLabel setFont:STKFont(10)];
    [_sourceLabel setTextColor:STKTextTransparentColor];
    [_sourceLabel setTextAlignment:NSTextAlignmentRight];
    
    [[_avatarView layer] setCornerRadius:16];
    [_avatarView setClipsToBounds:YES];

    
    [self addSubview:_avatarView];
    [self addSubview:_posterLabel];
    [self addSubview:_timeLabel];
    [self addSubview:_sourceLabel];
    [self addSubview:_postTypeView];
    [self addSubview:_timeImageView];
    
    for(UIView *v in [self subviews]) {
        [v setTranslatesAutoresizingMaskIntoConstraints:NO];
    }
    
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-9-[ava(==30)]-8-[poster]-8-[type(==20)]-9-|"
                                                                 options:NSLayoutFormatAlignAllTop metrics:nil
                                                                   views:@{@"ava" : _avatarView, @"poster" : _posterLabel, @"type" : _postTypeView}]];
    [_avatarView addConstraint:[NSLayoutConstraint constraintWithItem:_avatarView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual
                                                               toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:30]];
    [_postTypeView addConstraint:[NSLayoutConstraint constraintWithItem:_postTypeView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual
                                                               toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:20]];

    [self addConstraint:[NSLayoutConstraint constraintWithItem:_avatarView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual
                                                        toItem:self attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
    [self addConstraint:[NSLayoutConstraint constraintWithItem:_posterLabel attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual
                                                        toItem:_timeImageView attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[tiv(==8)]-2-[time(==100)]-8-[source]-9-|"
                                                                 options:NSLayoutFormatAlignAllCenterY metrics:nil views:@{@"tiv" : _timeImageView, @"time" : _timeLabel, @"source" : _sourceLabel}]];
    
    [self addConstraint:[NSLayoutConstraint constraintWithItem:_avatarView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual
                                                         toItem:_timeImageView attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];

    [_posterLabel addConstraint:[NSLayoutConstraint constraintWithItem:_posterLabel attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute
                                                            multiplier:1 constant:20]];

    [_timeImageView addConstraint:[NSLayoutConstraint constraintWithItem:_timeImageView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual
                                                               toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:8]];

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
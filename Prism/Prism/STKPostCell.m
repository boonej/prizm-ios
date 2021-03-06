//
//  STKHomeCell.m
//  Prism
//
//  Created by Joe Conway on 11/13/13.
//  Copyright (c) 2013 Higher Altitude. All rights reserved.
//

#import "STKPostCell.h"
#import "STKPost.h"
#import "STKRelativeDateConverter.h"
#import "STKAvatarView.h"
#import "STKUserStore.h"
#import "STKHashTag.h"
#import "STKGradientView.h"

@interface STKPostCell ()
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *hashTagHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *hashTagTopOffset;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *headerHeightConstraint;
@property (weak, nonatomic) IBOutlet STKGradientView *hashTagContainer;
@property (weak, nonatomic) IBOutlet UIView *buttonContainer;
@property (nonatomic, weak) STKPost *post;
@property (nonatomic, strong) UIImage *fadeImage;
@end

@implementation STKPostCell

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)populateWithPost:(STKPost *)p
{
    [self setPost:p];
    
    
    [[self contentImageView] setBackgroundColor:[UIColor colorWithWhite:1 alpha:0.2]];
    if([self overrideLoadingImage])
        [[self contentImageView] setLoadingImage:[self overrideLoadingImage]];
    else
        [[self contentImageView] setLoadingImage:[p largeTypeImage]];
    [[self contentImageView] setUrlString:[p imageURLString]];
    
    if(![self displayFullBleed]) {
        [[[self headerView] avatarView] setUrlString:[[p creator] profilePhotoPath]];
        [[[self headerView] posterLabel] setText:[[p creator] name]];
        [[[self headerView] timeLabel] setText:[STKRelativeDateConverter relativeDateStringFromDate:[p datePosted]]];
    
        [[[self headerView] postTypeView] setImage:[p typeImage]];
    }
    
    //if the post object is a re-post set FROM the original creator name in the headerviews source label
    if([p originalPost] && [[[p originalPost] creator] name]){
        NSString * fromUser = [NSString stringWithFormat:@"Post via %@", [[[p originalPost] creator] name]];
        [[[self headerView] sourceLabel] setText:fromUser];
    } else if([p externalProvider]){
        NSString * fromProvider = [NSString stringWithFormat:@"Post via %@", [[p externalProvider] capitalizedString]];
        [[[self headerView] sourceLabel] setText:fromProvider];
        
    } else {
        [[[self headerView] sourceLabel] setText:nil];
    }
    
    if([p commentCount] == 0) {
        [[self commentCountLabel] setText:@""];
    } else {
        [[self commentCountLabel] setText:[NSString stringWithFormat:@"%d", [p commentCount]]];
    }
    
    [[self commentButton] setSelected:NO];
    if([p text] || [p commentCount] > 0) {
        [[self commentButton] setSelected:YES];
    }
    
    if([p likeCount] == 0)
        [[self likeCountLabel] setText:@""];
    else
        [[self likeCountLabel] setText:[NSString stringWithFormat:@"%d", [p likeCount]]];
    
    [[self likeButton] setSelected:[p isPostLikedByUser:[[STKUserStore store] currentUser]]];
    
    if([p locationName]) {
        [[self locationButton] setSelected:YES];
    } else {
        [[self locationButton] setSelected:NO];
    }
    
    NSMutableString *tags = [[NSMutableString alloc] init];
    for(NSString *tag in [[p hashTags] valueForKey:@"title"]) {
        [tags appendFormat:@"#%@ ", tag];
    }
    [[self hashTagLabel] setText:tags];
    
    if ([[[self hashTagLabel] text] length] || [self displayFullBleed]) {
        [[self hashTagContainer] setHidden:NO];
    } else {
        [[self hashTagContainer] setHidden:YES];
    }
}


- (void)setDisplayFullBleed:(BOOL)displayFullBleed
{
    _displayFullBleed = displayFullBleed;
    
    if(_displayFullBleed) {
        [[self hashTagContainer] setHidden:NO];
        
        [[self topInset] setConstant:0];
        [[self leftInset] setConstant:0];
        [[self rightInset] setConstant:0];
        [[self hashTagTopOffset] setConstant:300];
        [[self hashTagHeightConstraint] setConstant:21];
//        [[self headerHeightConstraint] setConstant:64];
//        [[self hashTagContainer] setBackgroundColor:[UIColor colorWithWhite:1 alpha:0.3]];
        [[self hashTagContainer] setColors:@[[UIColor colorWithWhite:1 alpha:0.3], [UIColor colorWithWhite:1 alpha:0.3]]];
        [[self buttonContainer] setBackgroundColor:[UIColor colorWithWhite:1 alpha:0.1]];

        UIBezierPath *bp = [UIBezierPath bezierPathWithRect:CGRectMake(0, 19, 320, 1)];
        [[[self hashTagContainer] layer] setShadowOpacity:1];
        [[[self hashTagContainer] layer] setShadowColor:[[UIColor blackColor] CGColor]];
        [[[self hashTagContainer] layer] setShadowOffset:CGSizeMake(0, 1)];
        [[[self hashTagContainer] layer] setShadowRadius:4];
        [[[self hashTagContainer] layer] setShadowPath:[bp CGPath]];
        
        [[self headerView] setHidden:YES];
    } else {
        
    }
}

- (IBAction)toggleLike:(id)sender
{/*
    if([[self likeButton] isSelected]) {
        [[self likeButton] setSelected:NO];
        int count = [[self post] likeCount] - 1;
        if(count <= 0) {
            [[self likeCountLabel] setHidden:YES];
        } else {
            [[self likeCountLabel] setText:[NSString stringWithFormat:@"%d", count]];
            [[self likeCountLabel] setHidden:NO];
        }
    } else {
        [[self likeButton] setSelected:YES];
        int count = [[self post] likeCount] + 1;
        [[self likeCountLabel] setHidden:NO];
        [[self likeCountLabel] setText:[NSString stringWithFormat:@"%d", count]];
    }*/
    ROUTE(sender);
}

- (IBAction)showComments:(id)sender
{
    ROUTE(sender);
}

- (IBAction)addToPrism:(id)sender
{
    ROUTE(sender);
}

- (IBAction)sharePost:(id)sender
{
    ROUTE(sender);
}

- (IBAction)showLocation:(id)sender
{
    ROUTE(sender);
}

- (IBAction)imageTapped:(id)sender
{
    ROUTE(sender);
}

- (void)avatarTapped:(id)sender 
{
    ROUTE(sender);
}

- (void)sourceTapped:(id)sender
{
    ROUTE(sender);
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    
}



- (void)awakeFromNib
{
    static UIImage *fadeImage = nil;
    static UIColor *fadeColor = nil;
    if(!fadeImage || !fadeColor || ![fadeColor isEqual:[UIColor HADominantColor]]) {
        fadeColor = [UIColor HADominantColor];
        UIGraphicsBeginImageContext(CGSizeMake(2, 2));
        [fadeColor set];
        UIRectFill(CGRectMake(0, 0, 2, 2));
        fadeImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    [[[self headerView] backdropFadeView] setImage:fadeImage];
    [self setSelectionStyle:UITableViewCellSelectionStyleNone];
    [[self headerView] setBackgroundColor:[UIColor colorWithWhite:1.0 alpha:0.2]];
    [[[self headerView] avatarButton] addTarget:self action:@selector(avatarTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    [[[self headerView] sourceButton] addTarget:self action:@selector(sourceTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    [[self contentImageView] setPreferredSize:STKImageStoreThumbnailNone];
    [[self contentImageView] setLoadingContentMode:UIViewContentModeCenter];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshHeaderView) name:@"UserDetailsUpdated" object:nil];
}

- (void)refreshHeaderView
{
    static UIImage *fadeImage = nil;
    static UIColor *fadeColor = nil;
    fadeColor = [UIColor HADominantColor];
    UIGraphicsBeginImageContext(CGSizeMake(2, 2));
    [fadeColor set];
    UIRectFill(CGRectMake(0, 0, 2, 2));
    fadeImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    [[[self headerView] backdropFadeView] setImage:fadeImage];
}

- (void)cellDidLoad
{
    
    
//    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    //        UIView *bg = [[UIView alloc] initWithCoder:frame];
//    CGRect frame = [self.headerView frame];
//    UIVisualEffectView  *blurview = [[UIVisualEffectView alloc] initWithEffect:blur];
//    UIVibrancyEffect *vib = [UIVibrancyEffect effectForBlurEffect:blur];
//    [blurview setFrame:frame];
//    [self.headerView insertSubview:blurview atIndex:0];
    //        [[vibView contentView] addSubview:self.tableView];
//    [[(UIVisualEffectView *)view contentView] addSubview:vibView];
    
    
    //        [view setBackgroundColor:[UIColor clearColor]];
    //        [view setTintColor:[UIColor clearColor]];
//    [view setFrame:frame];

}

@end

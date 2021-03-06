//
//  STKTriImageCell.m
//  Prism
//
//  Created by Joe Conway on 1/14/14.
//  Copyright (c) 2014 Higher Altitude. All rights reserved.
//

#import "STKTriImageCell.h"
#import "STKPost.h"
#import "STKResolvingImageView.h"

@implementation STKTriImageCell

- (void)cellDidLoad
{
    [self setSelectionStyle:UITableViewCellSelectionStyleNone];
    [[self leftImageView] setPreferredSize:STKImageStoreThumbnailMedium];
    [[self centerImageView] setPreferredSize:STKImageStoreThumbnailMedium];
    [[self rightImageView] setPreferredSize:STKImageStoreThumbnailMedium];

    [[self leftImageView] setLoadingContentMode:UIViewContentModeCenter];
    [[self centerImageView] setLoadingContentMode:UIViewContentModeCenter];
    [[self rightImageView] setLoadingContentMode:UIViewContentModeCenter];

}

- (void)layoutContent
{
}

- (void)populateWithPosts:(NSArray *)posts indexOffset:(NSInteger)arrayIndex
{
    if(arrayIndex + 0 < [posts count]) {
        STKPost *p = [posts objectAtIndex:arrayIndex + 0];
        [[self leftImageView] setLoadingImage:[p disabledTypeImage]];
        [[self leftImageView] setBackgroundColor:[UIColor colorWithWhite:1 alpha:0.2]];
        [[self leftImageView] setUrlString:[p imageURLString]];
    } else {
        [[self leftImageView] setBackgroundColor:[UIColor clearColor]];
        [[self leftImageView] setUrlString:nil];
    }
    if(arrayIndex + 1 < [posts count]) {
        STKPost *p = [posts objectAtIndex:arrayIndex + 1];
        [[self centerImageView] setLoadingImage:[p disabledTypeImage]];
        [[self centerImageView] setBackgroundColor:[UIColor colorWithWhite:1 alpha:0.2]];
        [[self centerImageView] setUrlString:[p imageURLString]];
    } else {
        [[self centerImageView] setBackgroundColor:[UIColor clearColor]];
        [[self centerImageView] setUrlString:nil];
    }
    
    if(arrayIndex + 2 < [posts count]) {
        STKPost *p = [posts objectAtIndex:arrayIndex + 2];
        [[self rightImageView] setLoadingImage:[p disabledTypeImage]];
        [[self rightImageView] setBackgroundColor:[UIColor colorWithWhite:1 alpha:0.2]];
        [[self rightImageView] setUrlString:[p imageURLString]];
    } else {
        [[self rightImageView] setBackgroundColor:[UIColor clearColor]];
        [[self rightImageView] setUrlString:nil];
    }
}

- (IBAction)leftImageButtonTapped:(id)sender
{
    ROUTE(sender);
}

- (IBAction)centerImageButtonTapped:(id)sender
{
    ROUTE(sender);
}
- (IBAction)rightImageButtonTapped:(id)sender
{
    ROUTE(sender);
}
@end

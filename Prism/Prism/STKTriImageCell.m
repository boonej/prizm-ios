//
//  STKTriImageCell.m
//  Prism
//
//  Created by Joe Conway on 1/14/14.
//  Copyright (c) 2014 Higher Altitude. All rights reserved.
//

#import "STKTriImageCell.h"

@implementation STKTriImageCell

- (void)cellDidLoad
{
    [self setSelectionStyle:UITableViewCellSelectionStyleNone];
}

- (void)layoutContent
{
    
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

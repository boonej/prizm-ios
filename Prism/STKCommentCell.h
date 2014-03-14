//
//  STKCommentCell.h
//  Prism
//
//  Created by Joe Conway on 1/24/14.
//  Copyright (c) 2014 Higher Altitude. All rights reserved.
//

#import "STKTableViewCell.h"

@class STKAvatarView;

@interface STKCommentCell : STKTableViewCell
@property (weak, nonatomic) IBOutlet STKAvatarView *avatarImageView;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *commentLabel;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;
@property (weak, nonatomic) IBOutlet UIImageView *clockImageView;
@property (weak, nonatomic) IBOutlet UIControl *likeButton;
@property (weak, nonatomic) IBOutlet UIImageView *likeImageView;
@property (weak, nonatomic) IBOutlet UILabel *likeCountLabel;

@end

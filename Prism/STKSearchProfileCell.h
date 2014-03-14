//
//  STKSearchProfileCell.h
//  Prism
//
//  Created by Joe Conway on 1/24/14.
//  Copyright (c) 2014 Higher Altitude. All rights reserved.
//

#import "STKTableViewCell.h"
#import "STKResolvingImageView.h"

@interface STKSearchProfileCell : STKTableViewCell

@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet STKResolvingImageView *avatarView;

@end

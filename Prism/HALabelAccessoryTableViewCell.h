//
//  HALabelAccessoryTableViewCell.h
//  Prizm
//
//  Created by Jonathan Boone on 5/2/15.
//  Copyright (c) 2015 Higher Altitude. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "HACellProtocol.h"

@interface HALabelAccessoryTableViewCell : UITableViewCell<HACellProtocol>

@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) UIImageView *accessoryImageView;

@end
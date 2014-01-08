//
//  STKCreateProfileViewController.h
//  Prism
//
//  Created by Joe Conway on 12/6/13.
//  Copyright (c) 2013 Higher Altitude. All rights reserved.
//

#import <UIKit/UIKit.h>

@import Accounts;
@class STKProfileInformation;

@interface STKCreateProfileViewController : UIViewController

@property (nonatomic, strong) STKProfileInformation *profileInformation;

@end
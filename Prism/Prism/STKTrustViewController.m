//
//  STKTrustViewController.m
//  Prism
//
//  Created by Joe Conway on 11/6/13.
//  Copyright (c) 2013 Higher Altitude. All rights reserved.
//

#import "STKTrustViewController.h"
#import "UIViewController+STKControllerItems.h"

@interface STKTrustViewController ()

@end

@implementation STKTrustViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [[self navigationItem] setLeftBarButtonItem:[self menuBarButtonItem]];
        [[self navigationItem] setRightBarButtonItem:[self postBarButtonItem]];
        [[self tabBarItem] setImage:[UIImage imageNamed:@"menu_trust"]];
        [[self tabBarItem] setSelectedImage:[UIImage imageNamed:@"menu_trust_selected"]];

    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
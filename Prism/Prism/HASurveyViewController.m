//
//  HASurveyViewController.m
//  Prizm
//
//  Created by Jonathan Boone on 4/15/15.
//  Copyright (c) 2015 Higher Altitude. All rights reserved.
//

#import "HASurveyViewController.h"
#import "UIViewController+STKControllerItems.h"

@interface HASurveyViewController ()

@end

@implementation HASurveyViewController

- (id)init
{
    self = [super init];
    if (self) {
        [self.tabBarItem setTitle:@"Survey"];
        [[self tabBarItem] setImage:[UIImage imageNamed:@"menu_survey"]];
        [[self tabBarItem] setSelectedImage:[UIImage imageNamed:@"menu_survey_selected"]];
    }
    return self;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    UIImageView *iv = [[UIImageView alloc] initWithImage:[UIImage HABackgroundImage]];
    iv.frame = self.view.bounds;
    [self.view insertSubview:iv atIndex:0];
    self.title = @"Survey";
    UIBarButtonItem *bbi = [self menuBarButtonItem];
    [[self navigationItem] setLeftBarButtonItem:bbi];
    [self.navigationItem setHidesBackButton:YES];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
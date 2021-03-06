//
//  STKLoginViewController.m
//  Prism
//
//  Created by Joe Conway on 12/5/13.
//  Copyright (c) 2013 Higher Altitude. All rights reserved.
//

#import "STKLoginViewController.h"
#import "STKUserStore.h"
#import "STKProcessingView.h"
#import "STKLoginResetViewController.h"
#import "Mixpanel.h"
#import "UIViewController+STKControllerItems.h"
#import "UIERealTimeBlurView.h"

@interface STKLoginViewController () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UIButton *forgotPasswordButton;
@property (weak, nonatomic) IBOutlet UITextField *emailField;
@property (weak, nonatomic) IBOutlet UITextField *passwordField;
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (nonatomic, strong) Mixpanel *mixpanel;

- (IBAction)forgotPassword:(id)sender;

@end

@implementation STKLoginViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.mixpanel = [Mixpanel sharedInstance];
    NSDictionary *attrs = @{NSForegroundColorAttributeName : [UIColor colorWithWhite:1 alpha:.8],
                            NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle),
                            NSFontAttributeName : STKFont(14)};
    NSAttributedString *str = [[NSAttributedString alloc] initWithString:@"Forgot Password?"
                                                              attributes:attrs];
    [[self forgotPasswordButton] setAttributedTitle:str
                                           forState:UIControlStateNormal];
    [self.mixpanel track:@"Login Page loaded" properties:@{@"status":@"begin"}];
    if (![self presentingViewController]) {
        UIBarButtonItem *bbi = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btn_back"]
                                                  landscapeImagePhone:nil style:UIBarButtonItemStylePlain
                                                               target:self action:@selector(back:)];
        [[self navigationItem] setLeftBarButtonItem:bbi];
        self.title = @"Add Profile";
    }
   
    
    if (!self.presentingViewController) {
        UIImage *i = [UIImage HABackgroundImage];
        UIImageView *iv = [[UIImageView alloc] initWithImage:i];
        [self.view insertSubview:iv atIndex:0];
        CGRect frame = [[UIScreen mainScreen] bounds];
        frame.size.height = 64;
        UIERealTimeBlurView *blurView = [[UIERealTimeBlurView alloc] initWithFrame:frame];
        [self.view addSubview:blurView];
    }


}

- (void)back:(id)sender
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if([[[self emailField] text] length] > 0 && [[[self passwordField] text] length] > 0) {
        [[self view] endEditing:YES];
        [STKProcessingView present];
        [[STKUserStore store] loginWithEmail:[[self emailField] text]
                                    password:[[self passwordField] text]
                                  completion:^(STKUser *u, NSError *err) {
                                      [STKProcessingView dismiss];
                                      if(!err) {
                                          [self.mixpanel track:@"Login Success" properties:@{@"status":@"success"}];
                                          if ([self presentingViewController]) {
                                              [[self presentingViewController] dismissViewControllerAnimated:YES completion:nil];
                                          } else {
                                              [[STKUserStore store] switchToUser:u];
                                              [self.menuController recreateAllViewControllers];
                                              [self dismissViewControllerAnimated:YES completion:nil];
                                          }
                                          
                                          
                                          
                                          
                                      } else {
                                          [self.mixpanel track:@"Login Failure" properties:@{@"status":@"failure"}];
                                          [[STKErrorStore alertViewForError:err delegate:nil] show];
                                      }
                                  }];
    } else if([[[self emailField] text] length] == 0) {
        [[self emailField] becomeFirstResponder];
    } else {
        [[self passwordField] becomeFirstResponder];
    }
    
    return YES;
}


- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [[self emailField] becomeFirstResponder];
}

- (void)keyboardWillAppear:(NSNotification *)note
{
    [self.verticalController setBackButtonHidden:YES];
}

- (void)keyboardWillDisappear:(NSNotification *)note
{
    [self.verticalController setBackButtonHidden:NO];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated
{
//    [[NSNotificationCenter defaultCenter] addObserver:self
//                                             selector:@selector(keyboardWillAppear:)
//                                                 name:UIKeyboardWillShowNotification
//                                               object:nil];
//    [[NSNotificationCenter defaultCenter] addObserver:self
//                                             selector:@selector(keyboardWillDisappear:)
//                                                 name:UIKeyboardWillHideNotification
//                                               object:nil];
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super viewWillDisappear:animated];
}

- (IBAction)forgotPassword:(id)sender
{
    STKLoginResetViewController *rvc = [[STKLoginResetViewController alloc] init];
    [[self navigationController] pushViewController:rvc animated:YES];
}



@end

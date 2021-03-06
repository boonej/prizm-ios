//
//  STKIntroViewController.m
//  Prism
//
//  Created by Jonathan Boone on 7/25/14.
//  Copyright (c) 2014 Higher Altitude. All rights reserved.
//

#import "STKIntroViewController.h"
#import "Mixpanel.h"



@interface STKIntroViewController () <UIScrollViewDelegate>

@property (nonatomic, weak) IBOutlet UIButton *button;
@property (nonatomic, weak) IBOutlet UIScrollView *scrollView;
@property (nonatomic, weak) IBOutlet UIPageControl *pageControl;
@property (nonatomic, strong) NSArray *imageNames;
@property (nonatomic, strong) Mixpanel *mixpanel;

- (IBAction)buttonTapped:(id)sender;

@end

@implementation STKIntroViewController

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
    // Do any additional setup after loading the view from its nib.
    self.mixpanel = [Mixpanel sharedInstance];
    self.imageNames = @[@"intro_1", @"intro_2", @"intro_3", @"intro_4"];
    [self.mixpanel track:@"Intro Begin" properties:@{}];
    [self configure];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)buttonTapped:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:STKIntroCompletedKey];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.mixpanel track:@"Intro End" properties:@{}];
    [super viewWillDisappear:animated];
}

- (void)configure
{
    CGRect bounds = [[UIScreen mainScreen] bounds];
    UIImageView *backgroundImage = [[UIImageView alloc] initWithFrame:bounds];
    [backgroundImage setImage:[UIImage HABackgroundImage]];
    [self.view insertSubview:backgroundImage atIndex:0];
    [self.scrollView setBackgroundColor:[UIColor clearColor]];
//    [self.scrollView setBackgroundColor:[UIColor colorWithPatternImage:[UIImage HABackgroundImage]]];
    [self.scrollView setDelegate:self];
    NSArray *names = self.imageNames;
    for (NSInteger i = 0; i != [names count]; ++i) {
        NSString *name = names[i];
        UIImage *img = [UIImage imageNamed:name];
        UIImageView *iv = [[UIImageView alloc] initWithImage:img];
        CGRect frame = bounds;
        frame.origin.x = frame.size.width * i;
        [iv setFrame:frame];
        if (i == [names count] - 1) {
            CGPoint center = self.view.center;
            center.y = bounds.size.height - 34;
            UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 300, 44)];
            [iv setUserInteractionEnabled:YES];
            [button setBackgroundImage:[UIImage imageNamed:@"btn_lg"] forState:UIControlStateNormal];
            [button setCenter:center];
            [button setTitle:@"Let's Go" forState:UIControlStateNormal];
            [[button titleLabel] setFont:[UIFont fontWithName:@"HelveticaNeue-Light" size:15.0f]];
            [button addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
            [iv addSubview:button];
        }
        [self.scrollView addSubview:iv];
    }
    
    [self.pageControl setNumberOfPages:[names count]];
    
    NSInteger contentWidth = bounds.size.width;
    contentWidth = contentWidth * [names count];
    [self.scrollView setContentSize:CGSizeMake(contentWidth, bounds.size.height)];
    [self.scrollView setContentMode:UIViewContentModeCenter];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat pageWidth = scrollView.frame.size.width;
    NSInteger page = floor((scrollView.contentOffset.x - pageWidth / 2) / pageWidth) + 1;
    [self.pageControl setCurrentPage:page];
}

- (IBAction)pageControlValueChanged:(UIPageControl *)sender
{
    CGRect frame = [[UIScreen mainScreen] bounds];
    frame.origin.x = frame.size.width * (sender.currentPage - 1);
    [self.scrollView scrollRectToVisible:frame animated:YES];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}


- (BOOL)shouldAutorotate
{
    return NO;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    
    return UIInterfaceOrientationPortrait;
}


@end

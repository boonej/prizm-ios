//
//  STKInviteFriendsViewController.m
//  Prism
//
//  Created by Jesse Stevens Black on 6/24/14.
//  Copyright (c) 2014 Higher Altitude. All rights reserved.
//

#import "STKInviteFriendsViewController.h"
#import "STKUserStore.h"
#import "STKUser.h"
#import "STKMarkupUtilities.h"
#import "STKImageSharer.h"
#import "STKPost.h"
#import "UIERealTimeBlurView.h"
#import "STKInviteFriendsShareCell.h"
#import "STKProcessingView.h"
#import "UIViewController+STKControllerItems.h"

@import Social;
@import MessageUI;

NSString * const STKInviteFriendsShareText = @"Join me on Prizm! Download it so we can connect: https://prizmapp.com/download";
NSString * const STKInviteFriendsEmailSubject = @"Join me on Prizm!";

@interface STKInviteFriendsViewController ()
    <UITableViewDataSource, UITableViewDelegate, UIDocumentInteractionControllerDelegate,
    MFMessageComposeViewControllerDelegate, MFMailComposeViewControllerDelegate,
    UINavigationControllerDelegate>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
//@property (weak, nonatomic) IBOutlet UIERealTimeBlurView *blurView;


@property (nonatomic, strong) UIImage *shareCard;
@property (nonatomic, strong) NSArray *activities;
@property (nonatomic, strong) NSArray *availableServiceTypes;
@property (nonatomic, strong) NSArray *emailServiceArray;
@property (nonatomic, strong) NSArray *messageServiceArray;

@property (nonatomic, strong) STKImageSharer *imageSharer;

// grab the navigationbarbackround image so we can customize and restore navigation bar
@property (nonatomic, strong) UIImage *navigationBackgroundImage;
@property (nonatomic, strong) UIColor *textFieldTintColor;
@end

@implementation STKInviteFriendsViewController

-(id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (self) {
        UIBarButtonItem *bbi = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btn_back"]
                                                  landscapeImagePhone:nil style:UIBarButtonItemStylePlain
                                                               target:self action:@selector(back:)];
        [[self navigationItem] setLeftBarButtonItem:bbi];
        [[self navigationItem] setTitle:@"Invite"];
    }
    
    return self;
}

- (void)back:(id)sender
{
    [[self navigationController] popViewControllerAnimated:YES];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
//    [[[self blurView] displayLink] setPaused:NO];
    
    NSMutableArray *serviceTypes = [NSMutableArray array];
    if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeFacebook]) {
        [serviceTypes addObject:SLServiceTypeFacebook];
    }
    if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeTwitter]) {
        [serviceTypes addObject:SLServiceTypeTwitter];
    }
    if ([MFMailComposeViewController canSendMail]) {
        [self setEmailServiceArray:@[@"Email"]];
    }
    if ([MFMessageComposeViewController canSendAttachments]) {
        [self setMessageServiceArray:@[@"Message"]];
    }
    
    [self setAvailableServiceTypes:serviceTypes];
    [self configureInterface];
    
    [STKProcessingView present];
    [STKMarkupUtilities imageForInviteCard:[[STKUserStore store] currentUser] withCompletion:^(UIImage *img) {
        [STKProcessingView dismiss];
        [self setShareCard:img];
    }];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
//    [[[self blurView] displayLink] setPaused:YES];
}

- (void)setShareCard:(UIImage *)shareCard
{
    _shareCard = shareCard;
    
    [self setImageSharer:[[STKImageSharer alloc] init]];
    
    [self setActivities:[[self imageSharer] activitiesForImage:shareCard title:STKInviteFriendsShareText viewController:self]];

    [self configureInterface];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    UIImageView *iv = [[UIImageView alloc] initWithImage:[UIImage HABackgroundImage]];
    [iv setFrame:[self.view bounds]];
    [self.view insertSubview:iv atIndex:0];
    [[self tableView] setContentInset:UIEdgeInsetsMake(65, 0, 0, 0)];
    [[self tableView] setBackgroundView:[[UIImageView alloc] initWithImage:[UIImage HABackgroundImage]]];
    [[self tableView] setSeparatorInset:UIEdgeInsetsMake(0, 0, 0, 0)];
    [[self tableView] setSeparatorColor:STKTextTransparentColor];
    [self addBlurViewWithHeight:64.f];
}

- (void)configureInterface
{
    [[self tableView] reloadData];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([indexPath section] == 0) {
        UITableViewCell *c = [tableView dequeueReusableCellWithIdentifier:@"InviteCardCell"];
        if(!c) {
            c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"InviteCardCell"];
        }
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:[c bounds]];
        [imageView setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight];
        [imageView setImage:[self shareCard]];
        [c addSubview:imageView];
        [c setSelectionStyle:UITableViewCellSelectionStyleNone];

        return c;
    }
    STKInviteFriendsShareCell *c;
    c = [STKInviteFriendsShareCell cellForTableView:tableView target:self];
    NSString *text;
    UIImage *image;
    if ([indexPath section] == 1) {
        NSString *serviceType = [self availableServiceTypes][[indexPath row]];
        text = [self prettifyServiceType:serviceType];
        image = [self imageForServiceType:serviceType];
    }
    if ([indexPath section] == 2) {
        UIActivity *activity = [self activities][[indexPath row]];
        text = [activity activityTitle];
        image = [self imageForActivity:activity];
    }
    if ([indexPath section] == 3) {
        text = [[self messageServiceArray] firstObject];
        image = [UIImage imageNamed:@"sharing_message"];
    }
    if ([indexPath section] == 4) {
        text = [[self emailServiceArray] firstObject];
        image = [UIImage imageNamed:@"sharing_mail"];
    }

    [[c textView] setText:text];
    [[c networkImageView] setImage:image];
    
    return c;
}

- (NSString *)prettifyServiceType:(NSString *)serviceType
{
    return @{SLServiceTypeFacebook : @"Facebook", SLServiceTypeTwitter : @"Twitter"}[serviceType];
}

- (UIImage *)imageForServiceType:(NSString *)serviceType
{
    NSDictionary *map = @{SLServiceTypeTwitter : @"sharing_twitter", SLServiceTypeFacebook : @"sharing_facebook"};
    
    return [UIImage imageNamed:map[serviceType]];
}

- (UIImage *)imageForActivity:(UIActivity *)activity
{
    NSDictionary *map = @{STKActivityTypeWhatsapp : @"sharing_whatsapp", STKActivityTypeTumblr : @"sharing_tumblr",
                          STKActivityTypeInstagram : @"sharing_instagram"};
    return [UIImage imageNamed:map[[activity activityType]]];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 5;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return 1;
    }
    if (section == 1) {
        return [[self availableServiceTypes] count];
    }
    if (section == 2) {
        return [[self activities] count];
    }
    if (section == 3) {
        return [[self messageServiceArray] count];
    }
    return [[self emailServiceArray] count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([indexPath section] == 0) {
        return 320;
    }

    return 44;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    [cell setBackgroundColor:[UIColor colorWithWhite:1 alpha:0.1]];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self setNavigationBackgroundImage:[[UINavigationBar appearance] backgroundImageForBarMetrics:UIBarMetricsDefault]];
    [self setTextFieldTintColor:[[UITextField appearance] tintColor]];
    [[UITextField appearance] setTintColor:nil];
    [[UITextView appearance] setTintColor:nil];
    if ([indexPath section] == 1) {
        NSString *serviceType = [self availableServiceTypes][[indexPath row]];
        SLComposeViewController *vc = [SLComposeViewController composeViewControllerForServiceType:serviceType];
        [vc setInitialText:STKInviteFriendsShareText];
        [vc addImage:[self shareCard]];
        [self presentViewController:vc animated:YES completion:nil];
        return;
    }
    
    if ([indexPath section] == 2) {
        UIActivity *activity = [self activities][[indexPath row]];
        [activity performActivity];
    }
    
    if ([indexPath section] == 3) {
#warning smelly, but no direct manipulations on the nav controller had any effect
//        [[UINavigationBar appearance] setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
        
        MFMessageComposeViewController *vc = [[MFMessageComposeViewController alloc] init];
        
        [vc setMessageComposeDelegate:self];
        [vc setBody:STKInviteFriendsShareText];
        [vc addAttachmentData:UIImageJPEGRepresentation([self shareCard], 1.0) typeIdentifier:@"public.data" filename:@"prizm-share-card.jpeg"];
        [self presentViewController:vc animated:YES completion:nil];
    }
    
    if ([indexPath section] == 4) {
        [[UINavigationBar appearance] setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
        [[UITextField appearance] setTintColor:nil];
        
        MFMailComposeViewController *vc = [[MFMailComposeViewController alloc] init];
        
        [vc setMailComposeDelegate:self];
        [vc setSubject:STKInviteFriendsEmailSubject];
        [vc setMessageBody:STKInviteFriendsShareText isHTML:NO];
        [vc addAttachmentData:UIImageJPEGRepresentation([self shareCard], 1.0) mimeType:@"public.data" fileName:@"prizm-share-card.jpeg"];
        [self presentViewController:vc animated:YES completion:nil];
    }
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult)result
{
    [[UINavigationBar appearance] setBackgroundImage:[self navigationBackgroundImage] forBarMetrics:UIBarMetricsDefault];
    [[UITextField appearance] setTintColor:[self textFieldTintColor]];

    [controller dismissViewControllerAnimated:YES completion:^{
    }];
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    [[UINavigationBar appearance] setBackgroundImage:[self navigationBackgroundImage] forBarMetrics:UIBarMetricsDefault];
    [[UITextField appearance] setTintColor:[self textFieldTintColor]];
    
    [controller dismissViewControllerAnimated:YES completion:^{
    }];
}

@end

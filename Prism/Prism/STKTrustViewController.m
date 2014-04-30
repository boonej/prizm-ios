//
//  STKTrustViewController.m
//  Prism
//
//  Created by Joe Conway on 11/6/13.
//  Copyright (c) 2013 Higher Altitude. All rights reserved.
//

#import "STKTrustViewController.h"
#import "UIViewController+STKControllerItems.h"
#import "STKTrustView.h"
#import "STKCountView.h"
#import "STKUserStore.h"
#import "STKImageStore.h"
#import "STKUser.h"
#import "STKRenderServer.h"
#import "STKUserListViewController.h"
#import "STKProfileViewController.h"
#import "STKTrust.h"
#import "STKUserPostListViewController.h"

@import MessageUI;

@interface STKTrustViewController () <STKTrustViewDelegate, MFMailComposeViewControllerDelegate, STKCountViewDelegate>

@property (weak, nonatomic) IBOutlet UILabel *selectedNameLabel;
@property (weak, nonatomic) IBOutlet UIImageView *backgroundImageView;
@property (weak, nonatomic) IBOutlet STKTrustView *trustView;
@property (weak, nonatomic) IBOutlet STKCountView *countView;
@property (weak, nonatomic) IBOutlet UIToolbar *toolbar;
@property (weak, nonatomic) IBOutlet UIView *underlayView;
@property (nonatomic, strong) NSArray *trusts;
@property (weak, nonatomic) IBOutlet UIImageView *numberImageView;
@property (weak, nonatomic) IBOutlet UILabel *dateLabel;
@property (nonatomic, weak) STKUser *selectedUser;

- (IBAction)showList:(id)sender;
- (IBAction)sendEmail:(id)sender;

@end

@implementation STKTrustViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [[self navigationItem] setLeftBarButtonItem:[self menuBarButtonItem]];
        [[self navigationItem] setTitle:@"Trust"];
        [[self navigationItem] setRightBarButtonItem:[self postBarButtonItem]];
        [[self tabBarItem] setImage:[UIImage imageNamed:@"menu_trust"]];
        [[self tabBarItem] setSelectedImage:[UIImage imageNamed:@"menu_trust_selected"]];
        [[self tabBarItem] setTitle:@"Trust"];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(currentUserChanged:) name:STKUserStoreCurrentUserChangedNotification object:nil];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[self countView] setCircleTitles:@[@"Likes", @"Comments", @"Posts"]];
    [[self countView] setCircleValues:@[@"0", @"0", @"0"]];
    [[self countView] setDelegate:self];
    
    [[self trustView] setDelegate:self];

    [[self dateLabel] setBackgroundColor:[UIColor colorWithWhite:1 alpha:0.2]];
    [[self dateLabel] setClipsToBounds:YES];
    [[[self dateLabel] layer] setCornerRadius:5];

}

- (void)currentUserChanged:(NSNotification *)note
{
    if([[[STKUserStore store] currentUser] isInstitution]) {
        [[self tabBarItem] setTitle:@"Luminary"];
        [[self navigationItem] setTitle:@"Luminary"];
    } else {
        [[self tabBarItem] setTitle:@"Trust"];
        [[self navigationItem] setTitle:@"Trust"];
    }
}

- (void)countView:(STKCountView *)countView didSelectCircleAtIndex:(int)index
{
    STKTrust *t = [[self trusts] objectAtIndex:[[[self trustView] users] indexOfObject:[self selectedUser]]];
    NSString *otherName = [[t otherUser] name];
    
    if(index == 0) {
        [[STKUserStore store] fetchTrustPostsForTrust:t type:STKTrustPostTypeLikes completion:^(NSArray *posts, NSError *err) {
            STKUserPostListViewController *pvc = [[STKUserPostListViewController alloc] init];
            [pvc setShowsFilterBar:NO];
            [pvc setTitle:otherName];
            [pvc setPosts:posts];
            [pvc setAllowPersonalFilter:NO];
            [[self navigationController] pushViewController:pvc animated:YES];

        }];
    } else if(index == 1) {
        [[STKUserStore store] fetchTrustPostsForTrust:t type:STKTrustPostTypeComments completion:^(NSArray *posts, NSError *err) {
            STKUserPostListViewController *pvc = [[STKUserPostListViewController alloc] init];
            [pvc setTitle:otherName];
            [pvc setPosts:posts];
            [pvc setAllowPersonalFilter:NO];
            [pvc setShowsFilterBar:NO];
            [[self navigationController] pushViewController:pvc animated:YES];
            
        }];
    }
}

- (void)trustView:(STKTrustView *)tv didSelectCircleAtIndex:(int)idx
{
    [self selectUserAtIndex:idx];
}

- (void)selectUserAtIndex:(int)idx
{
    if(idx >= 0 && idx < [[self trusts] count]) {
        STKUser *u = [[[self trustView] users] objectAtIndex:idx];
        if([[u uniqueID] isEqualToString:[[self selectedUser] uniqueID]]) {
            STKProfileViewController *pvc = [[STKProfileViewController alloc] init];
            [pvc setProfile:u];
            [[self navigationController] pushViewController:pvc animated:YES];
            return;
        }
        [self setSelectedUser:u];
        [self configureInterface];
    }
}

- (void)configureInterface
{
    if([self selectedUser]) {
        NSUInteger idx = [[[self trustView] users] indexOfObject:[self selectedUser]];
        if(idx == NSNotFound) {
            [self setSelectedUser:nil];
        } else {
            [[self selectedNameLabel] setText:[[self selectedUser] name]];

            [[self trustView] setSelectedIndex:idx + 1];
            
            NSDictionary *lookup = @{@(0) : @"trust_one",
                                     @(1) : @"trust_two",
                                     @(2) : @"trust_three",
                                     @(3) : @"trust_four",
                                     @(4) : @"trust_five"};
            UIImage *img = [UIImage imageNamed:[lookup objectForKey:@(idx)]];
            [[self numberImageView] setImage:img];
            
            NSDate *dateCreated = [[self selectedUser] dateCreated];
            NSDateFormatter *df = [[NSDateFormatter alloc] init];
            [df setDateFormat:@"MMM yyyy"];
            [df setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
            [[self dateLabel] setText:[NSString stringWithFormat:@" Member Since %@ ", [df stringFromDate:dateCreated]]];
            
            STKTrust *t = [[self trusts] objectAtIndex:idx];
            
            int lCount = 0, cCount, pCount = 0;
            if([[[t creator] uniqueID] isEqualToString:[[[STKUserStore store] currentUser] uniqueID]]) {
                lCount = [t recepientLikesCount];
                cCount = [t recepientCommentsCount];
                pCount = [t recepientPostsCount];
            } else {
                lCount = [t creatorLikesCount];
                cCount = [t creatorCommentsCount];
                pCount = [t creatorPostsCount];
                
            }
            [[self countView] setCircleValues:@[
                [NSString stringWithFormat:@"%d", lCount],
                [NSString stringWithFormat:@"%d", cCount],
                [NSString stringWithFormat:@"%d", pCount]
            ]];
        }
        
    }
    
    if(![self selectedUser]) {
        [[self selectedNameLabel] setText:nil];
        [[self trustView] setSelectedIndex:0];
        [[self dateLabel] setText:nil];
        [[self numberImageView] setImage:nil];

        [[self countView] setCircleValues:@[@"0", @"0", @"0"]];
    }

}


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [[self trustView] setUser:[[STKUserStore store] currentUser]];
    
    if(![[self backgroundImageView] image]) {
        [[STKImageStore store] fetchImageForURLString:[[[STKUserStore store] currentUser] profilePhotoPath] preferredSize:STKImageStoreThumbnailSmall completion:^(UIImage *img) {
            UIGraphicsBeginImageContext(CGSizeMake(80, 80));
            [img drawInRect:CGRectMake(0, 0, 80, 80)];
            UIImage *blurredImage = [[STKRenderServer renderServer] blurredImageWithImage:UIGraphicsGetImageFromCurrentImageContext() affineClamp:YES];
            [[self backgroundImageView] setImage:blurredImage];
            UIGraphicsEndImageContext();
        }];
    }
    
    [[STKUserStore store] fetchTrustsForUser:[[STKUserStore store] currentUser] completion:^(NSArray *trusts, NSError *err) {
        [self setTrusts:trusts];
        NSMutableArray *otherUsers = [[NSMutableArray alloc] init];
        for(STKTrust *t in [self trusts]) {
            if([[t creator] isEqual:[[STKUserStore store] currentUser]]) {
                [otherUsers addObject:[t recepient]];
            } else {
                [otherUsers addObject:[t creator]];
            }
        }
        [[self trustView] setUsers:otherUsers];
        [self configureInterface];
    }];
    
    [self configureInterface];
}
- (IBAction)promptTitleChange:(id)sender
{
    if([self selectedUser]) {

    }
}


- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)menuWillAppear:(BOOL)animated
{
    if(animated) {
        [UIView animateWithDuration:0.1 animations:^{
            [[self underlayView] setAlpha:0.5];
        }];
    } else {
        [[self underlayView] setAlpha:0.5];
    }
}

- (void)menuWillDisappear:(BOOL)animated
{
    if(animated) {
        [UIView animateWithDuration:0.1 animations:^{
            [[self underlayView] setAlpha:0.0];
        }];
    } else {
        [[self underlayView] setAlpha:0.0];
    }
}


- (IBAction)showList:(id)sender
{
    STKUserListViewController *lvc = [[STKUserListViewController alloc] init];
    [lvc setType:STKUserListTypeTrust];
    NSMutableArray *otherUsers = [[NSMutableArray alloc] init];
    for(STKTrust *t in [self trusts]) {
        if([[t creator] isEqual:[[STKUserStore store] currentUser]]) {
            [otherUsers addObject:[t recepient]];
        } else {
            [otherUsers addObject:[t creator]];
        }
    }
    [lvc setUsers:otherUsers];
    [[self navigationController] pushViewController:lvc animated:YES];
}

- (IBAction)sendEmail:(id)sender
{
    if(![self selectedUser]) {
        UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Select a User" message:@"Select a user from your trust to send them a message." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [av show];
        return;
    }
    
    if(![MFMailComposeViewController canSendMail]) {
        UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Configure Mail"
                                                     message:[NSString stringWithFormat:@"To send an e-mail to %@, configure a mail account in your device's settings.", [[self selectedUser] name]]
                                                    delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [av show];
        return;
    }

    if(![[self selectedUser] email]) {
        UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"No E-mail" message:@"This user doesn't have an e-mail account available in Prizm." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [av show];
        return;
    }
    
    MFMailComposeViewController *mvc = [[MFMailComposeViewController alloc] init];
    [mvc setMailComposeDelegate:self];
    [mvc setToRecipients:@[[[self selectedUser] email]]];
    [mvc setSubject:@"Prizm Contact"];
    [self presentViewController:mvc animated:YES completion:nil];
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    [self dismissViewControllerAnimated:YES completion:nil];
    if(error) {
        UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Send Error" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [av show];
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

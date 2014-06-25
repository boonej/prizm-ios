//
//  STKSettingsViewController.m
//  Prism
//
//  Created by Joe Conway on 4/3/14.
//  Copyright (c) 2014 Higher Altitude. All rights reserved.
//

#import "STKSettingsViewController.h"
#import "STKInstagramAuthViewController.h"
#import "STKTumblrAuthViewController.h"
#import "STKLabelCell.h"
#import "STKSettingsShareCell.h"
#import "STKUserStore.h"
#import "STKUser.h"
#import "STKNetworkStore.h"
#import "STKProcessingView.h"
#import "STKAccountChooserViewController.h"
#import "STKWebViewController.h"
#import "UIERealTimeBlurView.h"
#import "STKSearchUsersViewController.h"
#import "STKInviteFriendsViewController.h"

@import Social;
@import Accounts;
@import MessageUI;

@interface STKSettingsViewController () <STKAccountChooserDelegate, MFMailComposeViewControllerDelegate, UIAlertViewDelegate>
@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, strong) NSArray *settings;
@property (nonatomic, weak) UIButton *logoutButton;
@property (weak, nonatomic) IBOutlet UIERealTimeBlurView *blurView;
@property (nonatomic, strong) UILabel *versionLabel;
@end

@implementation STKSettingsViewController


- (id)initWithItems:(NSArray *)items
{
    self = [super initWithNibName:nil bundle:nil];
    if(self) {
        UIBarButtonItem *bbi = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btn_back"]
                                                  landscapeImagePhone:nil style:UIBarButtonItemStylePlain
                                                               target:self action:@selector(back:)];
        [[self navigationItem] setLeftBarButtonItem:bbi];

//        UIBarButtonItem *bbi = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done:)];
        
//        [bbi setTitleTextAttributes:@{NSForegroundColorAttributeName : STKTextColor, NSFontAttributeName : STKFont(16)} forState:UIControlStateNormal];

//        [[self navigationItem] setRightBarButtonItem:bbi];
        [[self navigationItem] setTitle:@"Settings"];
        [self setAutomaticallyAdjustsScrollViewInsets:NO];
        [self setSettings:items];
        if(![self settings]) {
            _settings = @[
                          @{@"title" : @"Friends", @"type" : @"STKLabelCell", @"next" : [self friendsSettings]},
                          @{@"title": @"Sharing", @"type" : @"STKLabelCell", @"next" : [self sharingSettings]},
                          @{@"title" : @"Notifications", @"type" : @"STKLabelCell", @"next" : [self notificationSettings]},
                          @{@"title" : @"Support", @"type" : @"STKLabelCell", @"next" : [self supportSettings]},
                          @{@"title" : @"Send Feedback", @"type" : @"STKLabelCell", @"selectionSelector" : @"sendFeedbackEmail:"}
                        ];
        }
    }
    return self;
}

- (NSArray *)supportSettings
{
    return @[@{@"title" : @"Terms of Use", @"type" : @"STKLabelCell", @"url" : @"http://prizmapp.com/terms.html"},
             @{@"title" : @"Privacy Policy", @"type" : @"STKLabelCell", @"url" : @"http://prizmapp.com/privacy.html"},
             @{@"title" : @"Support Questions", @"type" : @"STKLabelCell", @"url" : @"http://prizmapp.com/support.html"},
             @{@"title" : @"Version", @"type" : @"STKDetailCell", @"value" : [[[NSBundle mainBundle] infoDictionary] objectForKey:(__bridge id)kCFBundleVersionKey]},
             @{@"title" : @"Disable Account", @"type" : @"STKLabelCell", @"selectionSelector" : @"disableAccount:"}
             ];
}

- (NSArray *)friendsSettings
{
    return @[@{@"title" : @"Find Friends on Prizm", @"type" : @"STKLabelCell", @"selectionSelector" : @"findFriends:"},
             @{@"title" : @"Invite Friends", @"type" : @"STKLabelCell", @"selectionSelector" : @"inviteFriends:"}
             ];
}

- (NSArray *)notificationSettings
{
    return @[];
}

- (NSArray *)sharingSettings
{
    
    return
    @[
      @{@"title": @"Instagram", @"image" : @"sharing_instagram", @"type" : @"STKSettingsShareCell", @"actionSelector" : @"configureInstagram:", @"configure": ^(STKUser *u, UITableViewCell *cell) {
          [[(STKSettingsShareCell *)cell toggleSwitch] setOn:([u instagramToken] != nil)];
      }},
      @{@"title": @"Twitter", @"image" : @"sharing_twitter", @"type" : @"STKSettingsShareCell", @"actionSelector" : @"configureTwitter:", @"configure": ^(STKUser *u, UITableViewCell *cell) {
          [[(STKSettingsShareCell *)cell toggleSwitch] setOn:([u twitterID] != nil)];
      }},
      @{@"title": @"Tumblr", @"image" : @"sharing_tumblr", @"type" : @"STKSettingsShareCell", @"actionSelector" : @"configureTumblr:", @"configure": ^(STKUser *u, UITableViewCell *cell) {
          [[(STKSettingsShareCell *)cell toggleSwitch] setOn:([u tumblrAccessToken] != nil)];
      }}
    ];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    return [self initWithItems:nil];
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    [self dismissViewControllerAnimated:YES completion:nil];
}


- (void)accountChooser:(STKAccountChooserViewController *)chooser didChooseAccount:(ACAccount *)account
{
    [self connectTwitterAccount:account];
    [[self navigationController] popViewControllerAnimated:YES];
}

- (void)configureTwitter:(NSNumber *)activating
{
    if([activating boolValue]) {
        [[STKUserStore store] fetchAvailableTwitterAccounts:^(NSArray *accounts, NSError *err) {
            if(err) {
                UIAlertView *av = [STKErrorStore alertViewForError:err delegate:nil];
                [av show];
                return;
            }
            
            if([accounts count] == 0) {
                UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"No Twitter Account"
                                                             message:@"You do not have a Twitter account configured for this device. Use the Settings application to securely enter your Twitter credentials before giving Prizm access."
                                                            delegate:nil
                                                   cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [av show];
                return;
            }
            
            if([accounts count] == 1) {
                [self connectTwitterAccount:[accounts firstObject]];
            } else {
                STKAccountChooserViewController *cvc = [[STKAccountChooserViewController alloc] initWithAccounts:accounts];
                [cvc setBackgroundImage:[UIImage imageNamed:@"img_background"]];
                [cvc setDelegate:self];
                [[self navigationController] pushViewController:cvc animated:YES];
            }
        }];
    } else {
        [[[STKUserStore store] currentUser] setTwitterLastMinID:nil];
        [[[STKUserStore store] currentUser] setTwitterID:nil];
        [[STKUserStore store] updateUserDetails:[[STKUserStore store] currentUser] completion:^(STKUser *u, NSError *err) {
            
        }];
    }
}

- (void)sendFeedbackEmail:(id)sender
{
    if([MFMailComposeViewController canSendMail]) {
        MFMailComposeViewController *mvc = [[MFMailComposeViewController alloc] init];
        [mvc setMailComposeDelegate:self];
        
        [mvc setSubject:@"Prizm Feedback"];
        [mvc setToRecipients:@[@"feedback@prizmapp.com"]];
        [mvc setMessageBody:@"Summary: \nSteps to Reproduce: \nExpected Results: \nActual Results: \nAdditional Notes: \n" isHTML:NO];
        [self presentViewController:mvc animated:YES completion:nil];
        
    } else {
        UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"No E-mail setup" message:@"Please set up an e-mail account in your device's settings." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [av show];
    }
}

- (void)findFriends:(id)sender
{
    STKSearchUsersViewController *stvc = [[STKSearchUsersViewController alloc] initWithSearchType:STKSearchUsersTypeToFollow];
    [stvc setTitle:@"Find Friends"];
    [[self navigationController] pushViewController:stvc animated:YES];
}

- (void)inviteFriends:(id)sender
{
    STKInviteFriendsViewController *vc = [[STKInviteFriendsViewController alloc] init];
    [[self navigationController] pushViewController:vc animated:YES];
}

- (void)disableAccount:(id)sender
{
    STKUser *user = [[STKUserStore store] currentUser];
    [[STKUserStore store] disableUser:user completion:^(STKUser *u, NSError *err) {
        NSString *title, *message;
        if(err) {
            title = @"Disable Account Error";
            message = err.description;
        } else {
            title = @"Disable Account Success";
            message = @"Your account is now inactive";
        }
        
        UIAlertView *av = [[UIAlertView alloc] initWithTitle:title
                                                     message:message
                                                    delegate:self
                                           cancelButtonTitle:@"Dismiss"
                                           otherButtonTitles:nil , nil];
        [av show];
        
    }];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 0) {
        [[STKUserStore store] logout];
    }
}

- (void)connectTwitterAccount:(ACAccount *)acct
{
    [[[STKUserStore store] currentUser] setTwitterID:[acct username]];
    
    [STKProcessingView present];
    [[STKNetworkStore store] establishMinimumIDForUser:[[STKUserStore store] currentUser] networkType:STKNetworkTypeTwitter completion:^(NSString *minID, NSError *err) {
        [[[STKUserStore store] currentUser] setTwitterLastMinID:minID];
        [[STKUserStore store] updateUserDetails:[[STKUserStore store] currentUser] completion:^(STKUser *u, NSError *err) {
            [STKProcessingView dismiss];
            if(err) {
                UIAlertView *av = [STKErrorStore alertViewForError:err delegate:nil];
                [av show];
            } else {
                NSLog(@"Twitter: %@ %@", [acct username], minID);
            }
        }];
    }];
}

- (void)toggleNetwork:(id)sender atIndexPath:(NSIndexPath *)ip
{
    NSString *selName = [self actionSelectorForIndexPath:ip];
    if(selName) {
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:NSSelectorFromString(selName) withObject:@([sender isOn])];
        return;
    }
}


- (void)configureInstagram:(NSNumber *)activating
{
    if([activating boolValue]) {
        STKInstagramAuthViewController *vc = [[STKInstagramAuthViewController alloc] init];
        [vc setTokenFound:^(NSString *token) {
            if(token) {
                [[[STKUserStore store] currentUser] setInstagramToken:token];
                [[STKNetworkStore store] establishMinimumIDForUser:[[STKUserStore store] currentUser] networkType:STKNetworkTypeInstagram completion:^(NSString *minID, NSError *err) {
                    [[[STKUserStore store] currentUser] setInstagramLastMinID:minID];
                    [[STKUserStore store] updateUserDetails:[[STKUserStore store] currentUser] completion:^(STKUser *u, NSError *err) {
                        
                    }];
                }];
            }
        }];
        [[self navigationController] pushViewController:vc animated:YES];
    } else {
        [[[STKUserStore store] currentUser] setInstagramLastMinID:nil];
        [[[STKUserStore store] currentUser] setInstagramToken:nil];
        [[STKUserStore store] updateUserDetails:[[STKUserStore store] currentUser] completion:^(STKUser *u, NSError *err) {
            
        }];
    }
}

- (void)configureTumblr:(NSNumber *)activating
{
    if ([activating boolValue]) {
        STKTumblrAuthViewController *vc = [[STKTumblrAuthViewController alloc] init];
        [vc setTokenFound:^(NSString *token) {
            if(token) {
                [[[STKUserStore store] currentUser] setTumblrAccessToken:token];
                [[STKNetworkStore store] establishMinimumIDForUser:[[STKUserStore store] currentUser] networkType:STKNetworkTypeTumblr completion:^(NSString *minID, NSError *err) {
                    [[[STKUserStore store] currentUser] setTumblrLastMinID:minID];
                    [[STKUserStore store] updateUserDetails:[[STKUserStore store] currentUser] completion:^(STKUser *u, NSError *err) {
                        
                    }];
                }];
            }
        }];
        [[self navigationController] pushViewController:vc animated:YES];
    } else {
        [[[STKUserStore store] currentUser] setTumblrLastMinID:nil];
        [[[STKUserStore store] currentUser] setTumblrAccessToken:nil];
        [[STKUserStore store] updateUserDetails:[[STKUserStore store] currentUser] completion:^(STKUser *u, NSError *err) {
            
        }];
    }
}

- (void)done:(id)sender
{
    [[self presentingViewController] dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[self tableView] setBackgroundView:[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"img_background"]]];
    [[self tableView] setSeparatorInset:UIEdgeInsetsMake(0, 20, 0, 0)];
    [[self tableView] setSeparatorColor:STKTextTransparentColor];

    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 200)];
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    [[b titleLabel] setFont:STKFont(18)];
    [[b titleLabel] setTextColor:STKTextColor];
    [b addTarget:self action:@selector(logout:) forControlEvents:UIControlEventTouchUpInside];
    [b setBackgroundImage:[UIImage imageNamed:@"btn_lg"] forState:UIControlStateNormal];
    [b setTitle:@"Logout" forState:UIControlStateNormal];
    [b setFrame:CGRectMake(10, 50, 300, 51)];
    [v addSubview:b];
    [v setBackgroundColor:[UIColor clearColor]];
    
    [self setLogoutButton:b];
    
    [[self tableView] setTableFooterView:v];
    [[self tableView] setContentInset:UIEdgeInsetsMake(65, 0, 0, 0)];
}

- (void)logout:(id)sender
{
    [[STKUserStore store] logout];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[[self blurView] displayLink] setPaused:YES];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[self tableView] reloadData];
    [[[self blurView] displayLink] setPaused:NO];
    
    if([[[self navigationController] viewControllers] indexOfObject:self] != 1) {
        [[self logoutButton] setHidden:YES];
        [[self versionLabel] setHidden:YES];
        UIBarButtonItem *bbi = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btn_back"]
                                                  landscapeImagePhone:nil style:UIBarButtonItemStylePlain
                                                               target:self action:@selector(back:)];
        [[self navigationItem] setLeftBarButtonItem:bbi];

    }
}

- (void)back:(id)sender
{
    [[self navigationController] popViewControllerAnimated:YES];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    [cell setBackgroundColor:[UIColor colorWithWhite:1 alpha:0.1]];
}

- (NSDictionary *)settingsItemAtIndexPath:(NSIndexPath *)ip
{
    return [[self settings] objectAtIndex:[ip row]];
}

- (NSString *)cellTypeForIndexPath:(NSIndexPath *)ip
{
    return [[self settingsItemAtIndexPath:ip] objectForKey:@"type"];
}

- (UIImage *)imageForIndexPath:(NSIndexPath *)ip
{
    return [UIImage imageNamed:[[self settingsItemAtIndexPath:ip] objectForKey:@"image"]];
}

- (NSString *)valueForIndexPath:(NSIndexPath *)ip
{
    return [[self settingsItemAtIndexPath:ip] objectForKey:@"value"];
}

- (NSString *)titleForIndexPath:(NSIndexPath *)ip
{
    return [[self settingsItemAtIndexPath:ip] objectForKey:@"title"];
}

- (NSArray *)nextItemsForIndexPath:(NSIndexPath *)ip
{
    return [[self settingsItemAtIndexPath:ip] objectForKey:@"next"];
}

- (void (^)(STKUser *, UITableViewCell *))configureBlockForIndexPath:(NSIndexPath *)ip
{
    return [[self settingsItemAtIndexPath:ip] objectForKey:@"configure"];
}

- (Class)viewControllerClassForIndexPath:(NSIndexPath *)ip
{
    return [[self settingsItemAtIndexPath:ip] objectForKey:@"viewController"];
}

- (NSString *)selectionSelectorForIndexPath:(NSIndexPath *)ip
{
    return [[self settingsItemAtIndexPath:ip] objectForKey:@"selectionSelector"];
}

- (NSString *)actionSelectorForIndexPath:(NSIndexPath *)ip
{
    return [[self settingsItemAtIndexPath:ip] objectForKey:@"actionSelector"];
}

- (NSString *)urlForIndexPath:(NSIndexPath *)ip
{
    return [[self settingsItemAtIndexPath:ip] objectForKey:@"url"];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSArray *nextItems = [self nextItemsForIndexPath:indexPath];
    if(nextItems) {
        STKSettingsViewController *svc = [[STKSettingsViewController alloc] initWithItems:nextItems];
        [[self navigationController] pushViewController:svc animated:YES];
        [svc setTitle:[self titleForIndexPath:indexPath]];
        return;
    }
    
    NSString *url = [self urlForIndexPath:indexPath];
    if(url) {
        STKWebViewController *wvc = [[STKWebViewController alloc] init];
        [wvc setUrl:[NSURL URLWithString:url]];
        UINavigationController *nvc = [[UINavigationController alloc] initWithRootViewController:wvc];

        [self presentViewController:nvc animated:YES completion:nil];
        return;
    }
    
    
    Class cls = [self viewControllerClassForIndexPath:indexPath];
    if(cls) {
        UIViewController *vc = [[cls alloc] init];
        [[self navigationController] pushViewController:vc animated:YES];
        return;
    }
    
    NSString *selName = [self selectionSelectorForIndexPath:indexPath];
    if(selName) {
        [self performSelector:NSSelectorFromString(selName) withObject:self];
        return;
    }
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[self settings] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *cellType = [self cellTypeForIndexPath:indexPath];
    
    UITableViewCell *returnCell = nil;
    
    if([cellType isEqualToString:@"STKLabelCell"]) {
        STKLabelCell *cell = [STKLabelCell cellForTableView:tableView target:self];
        [[cell overlayView] setBackgroundColor:[UIColor clearColor]];
        [[cell label] setText:[self titleForIndexPath:indexPath]];
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        returnCell = cell;
    }
    if([cellType isEqualToString:@"STKSettingsShareCell"]) {
        STKSettingsShareCell *cell = [STKSettingsShareCell cellForTableView:tableView target:self];
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        [[cell networkTitleLabel] setText:[self titleForIndexPath:indexPath]];
        [[cell networkImageView] setImage:[self imageForIndexPath:indexPath]];
        [cell setSeparatorInset:UIEdgeInsetsMake(0, 55, 0, 0)];
        returnCell = cell;
    }
    if([cellType isEqualToString:@"STKDetailCell"]) {
        UITableViewCell *c = [tableView dequeueReusableCellWithIdentifier:@"UITableViewCell-Detail"];
        if(!c) {
            c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"UITableViewCell-Detail"];
            [c setSelectionStyle:UITableViewCellSelectionStyleNone];
            [[c textLabel] setFont:STKFont(16)];
            [[c textLabel] setTextColor:[UIColor whiteColor]];
            
            [[c detailTextLabel] setFont:STKFont(16)];
            [[c detailTextLabel] setTextColor:[UIColor whiteColor]];
        }
        
        [[c textLabel] setText:[self titleForIndexPath:indexPath]];
        [[c detailTextLabel] setText:[self valueForIndexPath:indexPath]];
        
        return c;
    }
    
    void (^configureBlock)(STKUser *u, UITableViewCell *c) = [self configureBlockForIndexPath:indexPath];
    if(configureBlock) {
        configureBlock([[STKUserStore store] currentUser], returnCell);
    }
    
    if([self nextItemsForIndexPath:indexPath] || [self urlForIndexPath:indexPath]) {
        [returnCell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    } else {
        [returnCell setAccessoryType:UITableViewCellAccessoryNone];
    }
    
    return returnCell;
}



@end

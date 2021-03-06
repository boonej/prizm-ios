 //
//  STKCreateProfileViewController.m
//  Prism
//
//  Created by Joe Conway on 12/6/13.
//  Copyright (c) 2013 Higher Altitude. All rights reserved.
//

#import "STKCreateProfileViewController.h"
#import "STKTextFieldCell.h"
#import "STKGenderCell.h"
#import "STKWebViewController.h"
#import "STKDateCell.h"
#import "STKUserStore.h"
#import "STKResolvingImageView.h"
#import "STKImageStore.h"
#import "STKProcessingView.h"
#import "STKImageChooser.h"
#import "STKUser.h"
#import "STKBaseStore.h"
#import "STKTextInputViewController.h"
#import "STKAvatarView.h"
#import "STKLockCell.h"
#import "UIViewController+STKControllerItems.h"
#import "STKSegmentedControl.h"
#import "STKSegmentedControlCell.h"
#import "STKSegmentedPanel.h"
#import "STKItemListViewController.h"
#import "STKExploreViewController.h"
#import "UIERealTimeBlurView.h"
#import "Mixpanel.h"
#import "STKPhoneNumberFormatter.h"
#import "HAInterestsViewController.h"
#import "HANavigationController.h"
#import "STKOrganization.h"
#import "HAChangePasswordViewController.h"
#import "HAItemListViewController.h"
#import "HAWelcomeViewController.h"
#import "STKTheme.h"
#import "STKOrganization.h"
#import "HAConsentViewController.h"

@import AddressBook;
@import Social;
@import CoreLocation;

const long STKCreateProgressUploadingCover = 1;
const long STKCreateProgressUploadingProfile = 2;
const long STKCreateProgressGeocoding = 4;

@interface STKCreateProfileViewController ()
    <UITableViewDataSource, UITableViewDelegate, CLLocationManagerDelegate, UINavigationControllerDelegate, UIActionSheetDelegate>

@property (nonatomic, strong) STKUser *user;
@property (weak, nonatomic) IBOutlet UIImageView *backgroundImageView;

@property (nonatomic, strong) NSString *confirmedPassword;

@property (nonatomic) long progressMask;
@property (nonatomic) BOOL retrySyncOnProgressMaskClear;

@property (nonatomic, strong) CLGeocoder *geocoder;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) NSArray *items;
@property (nonatomic, strong) NSArray *requiredKeys;
@property (nonatomic, strong) NSMutableDictionary *previousValues;

@property (strong, nonatomic) IBOutlet UIToolbar *toolbar;
@property (weak, nonatomic) IBOutlet UIView *topContainer;

@property (weak, nonatomic) IBOutlet STKResolvingImageView *coverPhotoImageView;
@property (weak, nonatomic) IBOutlet STKAvatarView *avatarView;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) IBOutlet UIView *footerView;

@property (nonatomic, strong) NSIndexPath *editingIndexPath;

@property (weak, nonatomic) IBOutlet UIButton *profilePhotoButton;
@property (weak, nonatomic) IBOutlet UIButton *coverPhotoButton;

@property (weak, nonatomic) IBOutlet UIButton *tosButton;
@property (nonatomic, strong) NSDictionary *subtypeFormatters;

@property (nonatomic, strong) NSArray *religionValues;
@property (nonatomic, strong) NSArray *ethnicityValues;

@property (weak, nonatomic) IBOutlet UIView *coverOverlayView;
@property (nonatomic, getter = isEditingProfile) BOOL editingProfile;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *topOffset;
@property (weak, nonatomic) IBOutlet UIERealTimeBlurView *blurView;
@property (nonatomic) BOOL orgPresent;
@property (nonatomic) BOOL underThirteen;

- (IBAction)previousTapped:(id)sender;
- (IBAction)nextTapped:(id)sender;
- (IBAction)doneTapped:(id)sender;
- (IBAction)changeCoverPhoto:(id)sender;
- (IBAction)changeProfilePhoto:(id)sender;
- (IBAction)showTOS:(id)sender;
- (IBAction)finishProfile:(id)sender;

@end

@implementation STKCreateProfileViewController

- (id)initWithProfileForCreating:(STKUser *)user
{
    self = [super initWithNibName:nil bundle:nil];
    if(self) {
        if(!user) {
            user = [NSEntityDescription insertNewObjectForEntityForName:@"STKUser" inManagedObjectContext:[[STKUserStore store] context]];
        }
        [self setUser:user];
        [user setType:@"user"];
        
        [self sortReligionsAndEthinicitiesIntoSortedArrays];
        
        [self configureItemsForCreation];
        
        _locationManager = [[CLLocationManager alloc] init];
        [_locationManager setDesiredAccuracy:kCLLocationAccuracyKilometer];
        [_locationManager setDelegate:self];
        
        _subtypeFormatters = @{
                               STKUserSubTypeEducation : @"Education",
                               STKUserSubTypeMilitary : @"Military",
                               STKUserSubTypeCommunity : @"Community",
                               STKUserSubTypeFoundation : @"Foundation",
                               STKUserSubTypeCompany : @"Corporate"
                               };
        
    }
    return self;
}

- (void)configureItemsForCreation
{
    if([[self user] isInstitution]) {
        _items = @[
                   @{@"key" : @"type", @"cellType" : @"segmented", @"values" : @[@"Partner", @"Individual"]},

                   @{@"title" : @"Organization", @"key" : @"firstName",
                     @"options" : @{@"autocapitalizationType" : @(UITextAutocapitalizationTypeWords)}},
                   @{@"title" : @"Type", @"key" : @"subtype", @"cellType" : @"list",
                     @"values" :
                         @[STKUserSubTypeEducation, STKUserSubTypeMilitary, STKUserSubTypeCommunity,
                           STKUserSubTypeFoundation, STKUserSubTypeCompany]},
                         
                   
                   @{@"title" : @"Email", @"key" : @"email",
                     @"options" : @{@"keyboardType" : @(UIKeyboardTypeEmailAddress)}},
                   
                   @{@"title" : @"Password", @"key" : @"password",
                     @"options" : @{@"secureTextEntry" : @(YES)}},
                   
                   @{@"title" : @"Confirm Password", @"key" : @"confirmPassword",
                     @"options" : @{@"secureTextEntry" : @(YES)}},

                   
                   @{@"title" : @"Zip Code", @"key" : @"zipCode", @"options" : @{@"keyboardType" : @(UIKeyboardTypeNumberPad)}},
                   @{@"title" : @"Phone Number", @"key" : @"phoneNumber", @"options" : @{@"keyboardType" : @(UIKeyboardTypeNumberPad), @"formatter" : @"phoneNumber"}},
                   @{@"title" : @"Website", @"key" : @"website", @"options" : @{@"keyboardType" : @(UIKeyboardTypeURL)}},
                   @{@"title" : @"Contact First Name", @"key": @"contactFirstName", @"options": @{@"autocapitalizationType" : @(UITextAutocapitalizationTypeWords)}},
                   @{@"title" : @"Contact Last Name", @"key": @"contactLastName", @"options": @{@"autocapitalizationType" : @(UITextAutocapitalizationTypeWords)}},
                   @{@"title" : @"Contact Email", @"key" : @"contactEmail",
                     @"options" : @{@"keyboardType" : @(UIKeyboardTypeEmailAddress)}},
                   ];
        
        _requiredKeys = @[@"email", @"password", @"firstName", @"zipCode", @"website", @"subtype", @"phoneNumber"];
    } else {
        _items = @[
                   @{@"key" : @"type", @"cellType" : @"segmented", @"values" : @[@"Partner", @"Individual"]},
                   @{@"title" : @"Email", @"key" : @"email",
                     @"options" : @{@"keyboardType" : @(UIKeyboardTypeEmailAddress)}},
                   
                   @{@"title" : @"Password", @"key" : @"password",
                     @"options" : @{@"secureTextEntry" : @(YES)}},
                   
                   @{@"title" : @"Confirm Password", @"key" : @"confirmPassword",
                     @"options" : @{@"secureTextEntry" : @(YES)}},
                   
                   @{@"title" : @"First Name", @"key" : @"firstName",
                     @"options" : @{@"autocapitalizationType" : @(UITextAutocapitalizationTypeWords)}},
                   
                   @{@"title" : @"Last Name", @"key" : @"lastName",
                     @"options" : @{@"autocapitalizationType" : @(UITextAutocapitalizationTypeWords)}},
                   
                   
                   
                   @{@"title" : @"Date of Birth", @"key" : @"birthday", @"cellType" : @"date"},
                   @{@"title" : @"Gender", @"key" : @"gender", @"cellType" : @"gender"},
                   @{@"title" : @"Zip Code", @"key" : @"zipCode", @"options" : @{@"keyboardType" : @(UIKeyboardTypeNumberPad)}},
                   @{@"title" : @"Phone Number", @"key" : @"phoneNumber", @"options" : @{@"keyboardType" : @(UIKeyboardTypeNumberPad), @"formatter" : @"phoneNumber"}},
                   @{@"title" : @"Program Code", @"key" : @"programCode", @"options" : @{@"keyboardType" : @(UIKeyboardTypeAlphabet)}},
                   @{@"title" : @"Ethnicity", @"key" : @"ethnicity", @"cellType" : @"ethnicity",
                     @"values" : [self ethnicityValues]},
                   @{@"title" : @"Religion", @"key" : @"religion", @"cellType" : @"religion",
                     @"values" : [self religionValues]}
                   ];
        
        _requiredKeys = @[@"email", @"password", @"firstName", @"lastName", @"gender", @"birthday"];
   
    }
    if([[self user] externalServiceType]) {
        _items = [[self items] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"key != %@ and key != %@", @"password", @"confirmPassword"]];
        _requiredKeys = [[self requiredKeys] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self != %@", @"password"]];
    }

}


- (id)initWithProfileForEditing:(STKUser *)user
{
    self = [super initWithNibName:nil bundle:nil];
    if(self) {
        STKUser *u = [[user managedObjectContext] obtainEditableCopy:user];
        [self setUser:u];

        [self setEditingProfile:YES];
        [[self navigationItem] setTitle:@"Edit Profile"];
        
        [self sortReligionsAndEthinicitiesIntoSortedArrays];
        
        UIBarButtonItem *bbi = [[UIBarButtonItem alloc] initWithTitle:@"Save" style:UIBarButtonItemStyleBordered target:self action:@selector(finishProfile:)];
        [bbi setTitlePositionAdjustment:UIOffsetMake(-3, 0) forBarMetrics:UIBarMetricsDefault];
        [[self navigationItem] setRightBarButtonItem:bbi];
        
        if([u isInstitution]) {
            _items = @[
                       // Public
                       @{@"title" : @"Organization", @"key" : @"firstName",
                         @"options" : @{@"autocapitalizationType" : @(UITextAutocapitalizationTypeWords)}},
                       
                       @{@"title" : @"Info", @"key" : @"blurb", @"cellType" : @"textView"},
                       
                       @{@"title" : @"Website", @"key" : @"website",
                         @"options" : @{@"keyboardType" : @(UIKeyboardTypeURL)}},
                       
                       @{@"title" : @"Date Founded", @"key" : @"dateFounded", @"cellType" : @"date"},
                       @{@"title" : @"Mascot", @"key" : @"mascotName"},
                       @{@"title" : @"Population", @"key" : @"enrollment", @"options" : @{@"keyboardType" : @(UIKeyboardTypeNumberPad)}},

                       // Private
                       @{@"title" : @"Private", @"image" : [UIImage imageNamed:@"lockpassword"], @"cellType" : @"lock"},
                       
                       @{@"title" : @"Email", @"key" : @"email",
                         @"options" : @{@"keyboardType" : @(UIKeyboardTypeEmailAddress)}},
                       
                       
                       @{@"title" : @"Zip Code", @"key" : @"zipCode", @"options" : @{@"keyboardType" : @(UIKeyboardTypeNumberPad)}},
                       @{@"title" : @"Phone Number", @"key" : @"phoneNumber", @"options" : @{@"keyboardType" : @(UIKeyboardTypeNumberPad), @"formatter" : @"phoneNumber"}},
                       @{@"title" : @"Contact First Name", @"key": @"contactFirstName", @"options": @{@"autocapitalizationType" : @(UITextAutocapitalizationTypeWords)}},
                       @{@"title" : @"Contact Last Name", @"key": @"contactLastName", @"options": @{@"autocapitalizationType" : @(UITextAutocapitalizationTypeWords)}},
                       @{@"title" : @"Contact Email", @"key" : @"contactEmail",
                         @"options" : @{@"keyboardType" : @(UIKeyboardTypeEmailAddress)}},
                       @{@"title" : @"Change Password", @"key" : @"password", @"cellType" : @"password"}
                       ];
            _requiredKeys = @[@"email", @"firstName", @"zipCode", @"subtype", @"phoneNumber", @"zipCode"];
        } else {
            _items = @[
                       // Public
                       @{@"title" : @"First Name", @"key" : @"firstName",
                         @"options" : @{@"autocapitalizationType" : @(UITextAutocapitalizationTypeWords)}},
                       
                       @{@"title" : @"Last Name", @"key" : @"lastName",
                         @"options" : @{@"autocapitalizationType" : @(UITextAutocapitalizationTypeWords)}},

                       @{@"title" : @"Info", @"key" : @"blurb", @"cellType" : @"textView"},
                       
                       @{@"title" : @"Website", @"key" : @"website",
                         @"options" : @{@"keyboardType" : @(UIKeyboardTypeURL)}},
                       
                       
                       // Private
                       @{@"title" : @"Private", @"image" : [UIImage imageNamed:@"lockpassword"], @"cellType" : @"lock"},
                       
                       @{@"title" : @"Email", @"key" : @"email",
                         @"options" : @{@"keyboardType" : @(UIKeyboardTypeEmailAddress)}},
                       
                       //@{@"title" : @"Password", @"key" : @"password",
                    //@"options" : @{@"secureTextEntry" : @(YES)}},
                       
                       
                       @{@"title" : @"Gender", @"key" : @"gender", @"cellType" : @"gender"},
                       
                       @{@"title" : @"Date of Birth", @"key" : @"birthday", @"cellType" : @"date"},
                       
                       @{@"title" : @"Zip Code", @"key" : @"zipCode", @"options" : @{@"keyboardType" : @(UIKeyboardTypeNumberPad)}},
                       @{@"title" : @"Phone Number", @"key" : @"phoneNumber", @"options" : @{@"keyboardType" : @(UIKeyboardTypeNumberPad), @"formatter" : @"phoneNumber"}},
                       @{@"title" : @"Program Code", @"key" : @"programCode", @"options" : @{@"keyboardType" : @(UIKeyboardTypeAlphabet)}},
                       @{@"title" : @"Ethnicity", @"key" : @"ethnicity", @"cellType" : @"ethnicity",
                         @"values" : [self ethnicityValues]},
                       @{@"title" : @"Religion", @"key" : @"religion", @"cellType" : @"religion",
                         @"values" : [self religionValues]},
                       @{@"title" : @"Change Password", @"key" : @"password", @"cellType" : @"password"}
                       ];
            _requiredKeys = @[@"email", @"firstName", @"lastName", @"gender", @"birthday"];
        }
        
        
        
        _previousValues = [[NSMutableDictionary alloc] init];
        for(NSDictionary *d in [self items]) {
            NSString *key = [d objectForKeyedSubscript:@"key"];
            if(key) {
                NSString *val = [[self user] valueForKey:key];
                if(val) {
                    [[self previousValues] setObject:val forKey:key];
                } else {
                    [[self previousValues] setObject:[NSNull null] forKey:key];
                }
            }
        }
        
    }
    return self;
}


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    @throw [NSException exceptionWithName:@"STKCreateProfileViewController"
                                   reason:@"Must pick editing/editing"
                                 userInfo:nil];
    return nil;
}

- (void)configureInterface
{
    [[self backgroundImageView] setHidden:![self isEditingProfile]];
        
    if([[self user] coverPhotoPath] || [[self user] coverPhoto] || [self progressMask] & STKCreateProgressUploadingCover) {
        [[self coverOverlayView] setHidden:NO];
        [[self coverPhotoButton] setTitle:@"Edit" forState:UIControlStateNormal];
        [[self coverPhotoButton] setTitleColor:[UIColor HATextColor] forState:UIControlStateNormal];
        [[self coverPhotoButton] setImage:[UIImage imageNamed:@"btn_pic_uploadedit"] forState:UIControlStateNormal];
    } else {
        [[self coverOverlayView] setHidden:YES];
        [[self coverPhotoButton] setTitleColor:STKLightBlueColor forState:UIControlStateNormal];
        [[self coverPhotoButton] setTitle:@"Upload" forState:UIControlStateNormal];
        [[self coverPhotoButton] setImage:[UIImage imageNamed:@"upload_image"] forState:UIControlStateNormal];
    }
    
    if([[self user] profilePhotoPath] || [[self user] profilePhoto] || [self progressMask] & STKCreateProgressUploadingProfile) {
        [[self profilePhotoButton] setTitle:@"Edit" forState:UIControlStateNormal];
        [[self profilePhotoButton] setTitleColor:[UIColor HATextColor] forState:UIControlStateNormal];
        [[self profilePhotoButton] setBackgroundImage:nil forState:UIControlStateNormal];
        [[self avatarView] setOverlayColor:[UIColor colorWithWhite:0.0 alpha:0.5]];
        [[self avatarView] setHidden:NO];
    } else {
        [[self profilePhotoButton] setBackgroundImage:[UIImage imageNamed:@"upload_camera"] forState:UIControlStateNormal];
        [[self profilePhotoButton] setTitle:@"Upload" forState:UIControlStateNormal];
        [[self profilePhotoButton] setTitleColor:STKLightBlueColor forState:UIControlStateNormal];
        [[self avatarView] setHidden:YES];
    }

}

- (CGFloat)topOffsetConstant
{
    if([self isEditingProfile]) {
        return 64;
    }
    
    return 0;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self addBackgroundImage];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleUserUpdate) name:@"UserDetailsUpdated" object:nil];
    
    if(![self isEditingProfile]) {
        [[Mixpanel sharedInstance] track:@"Entered Profile Creation"];
        [[self tableView] setTableFooterView:[self footerView]];
    } else {
        [[Mixpanel sharedInstance] track:@"Entered Profile Editing"];
    }
    
    [[self topOffset] setConstant:[self topOffsetConstant]];
    
    [[self tableView] setRowHeight:44];
    [[self tableView] setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    [[self tableView] setSeparatorInset:UIEdgeInsetsMake(0, 0, 0, 0)];
    [[self tableView] setIndicatorStyle:UIScrollViewIndicatorStyleWhite];
    [[self tableView] setDelaysContentTouches:YES];
    
    NSMutableAttributedString *title = [[[self tosButton] attributedTitleForState:UIControlStateNormal] mutableCopy];
    [title addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:NSMakeRange(0, [title length])];
    [title addAttribute:NSForegroundColorAttributeName value:[UIColor colorWithRed:33.0 / 255.0
                                                                             green:144.0 / 255.0
                                                                              blue:255.0 / 255.0
                                                                             alpha:1] range:NSMakeRange(0, [title length])];
    [[self tosButton] setAttributedTitle:title forState:UIControlStateNormal];
    
    [[self coverOverlayView] setHidden:YES];
    
    [[self avatarView] setOutlineWidth:3];
    [[self avatarView] setOutlineColor:[UIColor HATextColor]];
    if (self.isEditingProfile){
        [self addBlurViewWithHeight:64.f];
    }
//    [self addBlurViewWithHeight:64.f];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if ([self user] == nil) {
        [[self navigationController] popViewControllerAnimated:YES];
    }
    [[self tableView] flashScrollIndicators];
}

- (void)setProgressMask:(long)progressMask
{
    long old = _progressMask;
    _progressMask = progressMask;
    
    if([self retrySyncOnProgressMaskClear] && old != 0 && _progressMask == 0) {
        [self setRetrySyncOnProgressMaskClear:NO];
        [self finishProfile:nil];
    }
}


- (void)dateChanged:(id)sender atIndexPath:(NSIndexPath *)ip
{
    NSString *key = [[[self items] objectAtIndex:[ip row]] objectForKey:@"key"];
    [[self user] setValue:[sender date] forKey:key];
    [[Mixpanel sharedInstance] track:@"Selected Birthday"];
}

- (BOOL)verifyValue:(id)val forKey:(NSString *)key errorMessage:(NSString **)msg
{
    if(!msg)
        @throw [NSException exceptionWithName:@"STKCreateProfileViewController" reason:@"Have to pass errorMessage param to verifyValue:forKey:errorMessage:" userInfo:nil];
    
    
    __block NSString *title = nil;
    [[self items] enumerateObjectsUsingBlock:^(NSDictionary *d, NSUInteger idx, BOOL *stop) {
        if([[d objectForKey:@"key"] isEqualToString:key]) {
            title = [d objectForKey:@"title"];
            *stop = YES;
        }
    }];

    if(!title) {
        // Specific keys
        if([key isEqualToString:@"coverPhotoPath"])
            title = @"A cover photo";
        if([key isEqualToString:@"profilePhotoPath"])
            title = @"A profile photo";
    }
    
    if(!val) {
        *msg = [NSString stringWithFormat:@"%@ is required.", title];
        return NO;
    }
    
    if([key isEqualToString:@"email"]) {
        NSRegularExpression *exp = [[NSRegularExpression alloc] initWithPattern:@"[^@]*@[^\\.]*\\..{2,}" options:0 error:nil];
        NSTextCheckingResult *tr = [exp firstMatchInString:val options:0 range:NSMakeRange(0, [val length])];
        if(!tr) {
            *msg = [NSString stringWithFormat:@"Email address must be valid."];
            return NO;
        }
    }

    
    if([key isEqualToString:@"firstName"] || [key isEqualToString:@"lastName"] || [key isEqualToString:@"zipCode"]) {
        if([val length] < 1) {
            *msg = [NSString stringWithFormat:@"%@ is required.", title];
            return NO;
        }
    }
    if([key isEqualToString:@"password"]) {
        if([val length] < 6) {
            *msg = [NSString stringWithFormat:@"Please choose a password that is at least 6 characters long."];
            return NO;
        }
    }
    if([key isEqualToString:@"birthday"]) {
        NSDate *ageMin = [NSDate dateWithTimeIntervalSinceNow:-60 * 60 * 24 * 365.25 * 13];
        if([val timeIntervalSinceDate:ageMin] > 0) {
            *msg = @"You must be 13 years of age to create an account.";
//            UIAlertView *av = [UIAlertView alloc] initWith
//            return YES;
            self.underThirteen = YES;
        } else {
            self.underThirteen = NO;
        }
    }
    
    return YES;
}

- (BOOL)verifyFields:(BOOL)displayFailures
{
    NSArray *filteredKeys = [self requiredKeys];
    
    // If we're in the process of uploading these images, then don't consider them required for this purpose and kick the
    // delay to the registration process
    if([self progressMask] & STKCreateProgressUploadingCover) {
        filteredKeys = [filteredKeys filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self != %@", @"coverPhotoPath"]];
    }
    if([self progressMask] & STKCreateProgressUploadingProfile) {
        filteredKeys = [filteredKeys filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self != %@", @"profilePhotoPath"]];
    }
    
    for(NSString *key in filteredKeys) {
        NSString *val = [[self user] valueForKey:key];
        NSString *outMsg = nil;
        if(![self verifyValue:val forKey:key errorMessage:&outMsg]) {
            
            if(displayFailures) {
                UIAlertView *av = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Registration Incomplete", @"registration incomplete title")
                                                             message:outMsg
                                                            delegate:nil
                                                   cancelButtonTitle:NSLocalizedString(@"OK", @"standard dismiss button title")
                                                   otherButtonTitles:nil];
                [av show];
            }
            
            return NO;
        }
    }
    
    if([[self requiredKeys] containsObject:@"password"]) {
        if(![[[self user] password] isEqualToString:[self confirmedPassword]]) {
            UIAlertView *av = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Confirm Password", @"confirm password title - create profile")
                                                         message:NSLocalizedString(@"Oops. The password and confirmation password don't match.", @"confirm password message - create profile")
                                                        delegate:nil
                                               cancelButtonTitle:NSLocalizedString(@"OK", @"standard dismiss button title")
                                               otherButtonTitles:nil];
            [av show];
            return NO;
        }
    }
    
    if ([self.user valueForKey:@"programCode"]) {
        if (![self.user valueForKey:@"phoneNumber"]) {
            UIAlertView *av = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Enter Phone Number", @"phone number title - create profile")
                                                         message:NSLocalizedString(@"Oops. You must provide your phone number if a program code is entered.", @"phone number message - create profile")
                                                        delegate:nil
                                               cancelButtonTitle:NSLocalizedString(@"OK", @"standard dismiss button title")
                                               otherButtonTitles:nil];
            [av show];
            return NO;
        }
    }
    
    return YES;
}
- (void)back:(id)sender
{
    // Restore values
    for(NSString *key in [self previousValues]) {
        id val = [[self previousValues] objectForKey:key];
        if([val isKindOfClass:[NSNull class]]) {
            [[self user] setValue:nil forKey:key];
        } else {
            [[self user] setValue:val forKey:key];
        }
    }
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"HAIsCreatingProfile"];
    [[self navigationController] popViewControllerAnimated:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
 
    if([self isMovingFromParentViewController]) {
        [[[self user] managedObjectContext] discardChangesToEditableObject:[self user]];
        [self setUser:nil];
    }
    
    [[[self blurView] displayLink] setPaused:YES];
    
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillAppear:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillDisappear:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    [[self locationManager] startUpdatingLocation];
    
    
    if([self isEditingProfile]) {
        [[self navigationItem] setLeftBarButtonItem:[self backButtonItem]];
    } else {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"HAIsCreatingProfile"];
    }
    
    
    if(![[self user] gender]) {
        [[self user] setGender:STKUserGenderUnknown];
    }
  
    // If we got the profile/cover photo from ane external service, upload it to our server
    if([self isEditingProfile]) {
        if([[self user] coverPhotoPath]) {

            NSString *imageURLString = [[self user] coverPhotoPath];
            [[STKImageStore store] fetchImageForURLString:imageURLString
                                               completion:^(UIImage *img) {
                                                   [[self coverPhotoImageView] setImage:img];
                                                   [self configureInterface];
                                               }];
        }
        if([[self user] profilePhotoPath]) {
            NSString *imageURLString = [[self user] profilePhotoPath];
            [[STKImageStore store] fetchImageForURLString:imageURLString
                                               completion:^(UIImage *img) {
                                                   [[self avatarView] setImage:img];
                                                   [self configureInterface];
                                               }];
        }

    } else {
        if([[self user] profilePhoto]) {
            [self setProfileImage:[[self user] profilePhoto]];
        }
        if([[self user] coverPhoto]) {
            [self setCoverImage:[[self user] coverPhoto]];
        }
        if([[self user] coverPhotoPath]) {
            NSString *imageURLString = [[self user] coverPhotoPath];
            [[self user] setCoverPhotoPath:nil];
            [self setProgressMask:STKCreateProgressUploadingCover | [self progressMask]];
            [[STKImageStore store] fetchImageForURLString:imageURLString
                                               completion:^(UIImage *img) {
                                                   [self setCoverImage:img];
                                               }];
        }
        if([[self user] profilePhotoPath]) {
            NSString *imageURLString = [[self user] profilePhotoPath];
            [[self user] setProfilePhotoPath:nil];
            [self setProgressMask:STKCreateProgressUploadingProfile | [self progressMask]];

            [[STKImageStore store] fetchImageForURLString:imageURLString
                                               completion:^(UIImage *img) {
                                                   [self setProfileImage:img];
                                               }];
        }
    }
    [self configureInterface];
    [[self tableView] reloadData];
    
    if([self isEditingProfile]) {
        if([self isMovingToParentViewController]) {
            [STKProcessingView present];
            NSArray *additionalFields = nil;
            if([[self user] isInstitution]) {
                additionalFields = @[@"zip_postal", @"date_founded", @"mascot", @"enrollment", @"phone_number", @"interests", @"theme"];
            } else {
                additionalFields = @[@"zip_postal", @"birthday", @"gender", @"theme"];
            }
            [[STKUserStore store] fetchUserDetails:[self user] additionalFields:additionalFields
                                        completion:^(STKUser *u, NSError *err) {
                                            [STKProcessingView dismiss];
                                            if(err ) {
                                                [[STKErrorStore alertViewForError:err delegate:nil] show];
                                                [self setUser:nil];
                                            }
                                            if (u.programCode && ![u.programCode isEqualToString:@""]) {
                                                [[STKUserStore store] fetchOrganizationByCode:u.programCode completion:^(STKOrganization *organization, NSError *err) {
                                                    if (!err && organization){
                                                        [[NSUserDefaults standardUserDefaults] setObject:organization.uniqueID forKey:@"STKOrganizationId"];
                                                    } else {
                                                        [[NSUserDefaults standardUserDefaults] setObject:nil forKey:@"STKOrganizationId"];
                                                    }
                                                }];
                                            }
                                            [[self tableView] reloadData];
                                        }];
        }
    }
    
    if([self isEditingProfile]) {
        [[self blurView] setHidden:NO];
        [[[self blurView] displayLink] setPaused:NO];
    } else {
        [[self blurView] setHidden:YES];
        [[[self blurView] displayLink] setPaused:YES];
    }
    if (self.user.organization) {
        self.orgPresent = YES;
    } else {
        self.orgPresent = NO;
    }
}

- (void)keyboardWillAppear:(NSNotification *)note
{
    [[self verticalController] setBackButtonHidden:YES];
    
    CGRect r = [[[note userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    [[self tableView] setContentInset:UIEdgeInsetsMake(0, 0, r.size.height, 0)];
    
    [[self topOffset] setConstant:-[[self topContainer] bounds].size.height + 64];

    [UIView animateWithDuration:[[[note userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue]
                          delay:0
                        options:[[[note userInfo] objectForKey:UIKeyboardAnimationCurveUserInfoKey] intValue]
                     animations:^{
                         [[self view] layoutIfNeeded];
                     } completion:^(BOOL finished) {
                         
                     }];
}

- (void)keyboardWillDisappear:(NSNotification *)note
{
    [[self verticalController] setBackButtonHidden:NO];

    [[self tableView] setContentInset:UIEdgeInsetsMake(0, 0, 0, 0)];
    [[self topOffset] setConstant:[self topOffsetConstant]];
}

- (UITableViewCell *)visibleCellForKey:(NSString *)key
{
    NSArray *visibleCells = [[self tableView] visibleCells];
    
    __block long zipIndex = -1;
    [[self items] enumerateObjectsUsingBlock:^(NSDictionary *d, NSUInteger idx, BOOL *stop) {
        if([[d objectForKey:@"key"] isEqualToString:key]) {
            zipIndex = idx;
            *stop = YES;
        }
    }];
    
    for(UITableViewCell *c in visibleCells) {
        NSIndexPath *ip = [[self tableView] indexPathForCell:c];
        if([ip row] == zipIndex) {
            return c;
        }
    }
    return nil;
}

- (void)textFieldDidChange:(UITextField *)sender atIndexPath:(NSIndexPath *)ip
{
    NSString *text = [sender text];
    NSDictionary *item = [[self items] objectAtIndex:[ip row]];

    if([[item objectForKey:@"key"] isEqualToString:@"confirmPassword"]) {
        [self setConfirmedPassword:text];
        return;
    }
    
    if([[item objectForKey:@"key"] isEqualToString:@"phoneNumber"]) {
        NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern:@"[^0-9]" options:0 error:nil];
        NSString *convertedPhoneNumber = [regex stringByReplacingMatchesInString:[sender text] options:0 range:NSMakeRange(0, [[sender text] length]) withTemplate:@""];
        [[self user] setPhoneNumber:convertedPhoneNumber];
        return;
    }
    
    [[self user] setValue:text forKey:[item objectForKey:@"key"]];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
                     atIndexPath:(NSIndexPath *)ip
{
    if([[[[self items] objectAtIndex:[ip row]] objectForKey:@"cellType"] isEqualToString:@"date"]) {
        STKDateCell *c = (STKDateCell *)[[self tableView] cellForRowAtIndexPath:ip];
        NSString *key = [[[self items] objectAtIndex:[ip row]] objectForKey:@"key"];
        [[self user] setValue:[c date] forKey:key];
    }
    [self setEditingIndexPath:ip];
}



- (void)textFieldShouldReturn:(UITextField *)textField
                  atIndexPath:(NSIndexPath *)ip
{/*
    NSArray *allKeys = [[self items] valueForKey:@"key"];
    for(NSString *k in allKeys) {
        if(![k isKindOfClass:[NSNull class]]) {
            if([[self user] valueForKey:k]) {
                NSLog(@"OK");
            } else {
                NSLog(@"not ok %@", k);
            }
        }
    }*/
    NSDictionary *item = [[self items] objectAtIndex:[ip row]];
    [[Mixpanel sharedInstance] track:[NSString stringWithFormat:@"%@ entered", [item objectForKey:@"key"]]];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    CLLocation *l = [locations lastObject];
    if([[NSDate date] timeIntervalSinceDate:[l timestamp]] < 5 * 60) {
        
        [self setProgressMask:[self progressMask] | STKCreateProgressGeocoding];
        if(l) {
            _geocoder = [[CLGeocoder alloc] init];
            [_geocoder reverseGeocodeLocation:l
                            completionHandler:^(NSArray *placemarks, NSError *error) {
                                [self setProgressMask:[self progressMask] & ~STKCreateProgressGeocoding];
                                if(!error) {
                                    CLPlacemark *cp = [placemarks lastObject];
                                    if([cp postalCode] && ![[self user] zipCode]) {
                                        [[self user] setZipCode:[cp postalCode]];
                                        [[self user] setCity:[cp locality]];
                                        
                                        [[self user] setState:[cp administrativeArea]];

                                        
                                        UITableViewCell *c = [self visibleCellForKey:@"zipCode"];
                                        if(c) {
                                            [[self tableView] reloadRowsAtIndexPaths:@[[[self tableView] indexPathForCell:c]]
                                                                    withRowAnimation:UITableViewRowAnimationAutomatic];
                                        }
                                    }
                                }
                                _geocoder = nil;
                            }];
        }
        [[self locationManager] stopUpdatingLocation];
    }
}


- (IBAction)changeCoverPhoto:(id)sender
{
    [[STKImageChooser sharedImageChooser] initiateImageChooserForViewController:self
                                                                        forType:STKImageChooserTypeCover
                                                                     completion:^(UIImage *img, UIImage *originalImage, NSDictionary *imageInfo) {
        if(img)
            [self setCoverImage:img];
        [self configureInterface];
    }];
}

- (IBAction)changeProfilePhoto:(id)sender
{
    [[STKImageChooser sharedImageChooser] initiateImageChooserForViewController:self
                                                                        forType:STKImageChooserTypeProfile
                                                                     completion:^(UIImage *img, UIImage *originalImage, NSDictionary *imageInfo) {
        if(img)
            [self setProfileImage:img];
        [self configureInterface];
    }];
}


- (void)setProfileImage:(UIImage *)img
{
    if(img) {
        [self setProgressMask:[self progressMask] | STKCreateProgressUploadingProfile];
        
        [[STKImageStore store] uploadImage:img thumbnailCount:3 intoDirectory:@"profile" completion:^(NSString *URLString, NSError *err) {
            if(!err) {
                [[self user] setProfilePhotoPath:URLString];
            } else {
                if(![self isEditingProfile]) {
                    [[self user] setProfilePhotoPath:nil];
                    [[self user] setProfilePhoto:nil];
                }
                
                UIAlertView *av = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Profile Image Upload Failed", @"profile image upload failed title")
                                                             message:NSLocalizedString(@"Oops. The profile image failed to upload. Ensure you have an internet connection and try again.", @"profile image upload failed message")
                                                            delegate:nil
                                                   cancelButtonTitle:NSLocalizedString(@"OK", @"standard dismiss button title")
                                                   otherButtonTitles:nil];
                [av show];
                
            }

            [self setProgressMask:[self progressMask] & ~STKCreateProgressUploadingProfile];
            [self configureInterface];
        }];
  
    }
    [[self avatarView] setImage:img];
    [self configureInterface];
}

- (void)setCoverImage:(UIImage *)img
{
    UIImage *resizedImage = img;
    if(img) {
        [self setProgressMask:[self progressMask] | STKCreateProgressUploadingCover];
        [[STKImageStore store] uploadImage:img intoDirectory:@"covers" completion:^(NSString *URLString, NSError *err) {
            if(!err) {
                [[self user] setCoverPhotoPath:URLString];
            } else {
                if(![self isEditingProfile]) {
                    [[self user] setCoverPhotoPath:nil];
                    [self setCoverImage:nil];
                }
                UIAlertView *av = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Cover Image Upload Failed", @"cover image upload failed title")
                                                             message:NSLocalizedString(@"Oops. The cover image failed to upload. Ensure you have an internet connection and try again.", @"cover image upload failed message")
                                                            delegate:nil
                                                   cancelButtonTitle:NSLocalizedString(@"OK", @"standard dismiss button title")
                                                   otherButtonTitles:nil];
                [av show];
            }
            [self setProgressMask:[self progressMask] & ~STKCreateProgressUploadingCover];
        }];
    }

    [[self coverPhotoImageView] setImage:resizedImage];
    [self configureInterface];
}

- (void)controlChanged:(UISegmentedControl *)sender atIndexPath:(NSIndexPath *)ip
{
    NSDictionary *item = [[self items] objectAtIndex:[ip row]];
    if([[item objectForKey:@"key"] isEqualToString:@"type"]) {
        NSString *t = nil;
        if([sender selectedSegmentIndex] == 0)
            t = @"user";
        else
            t = @"institution";
        [[self user] setType:t];
        [self configureItemsForCreation];
        [[self tableView] reloadData];
        if ([t isEqualToString:@"institution"]) {
            UIAlertView *av = [[UIAlertView alloc] initWithTitle:nil message:@"This is the signup page for education, military, community organizations, foundations and corporate partners to engage with students on Prizm.  You will receive a confirmation email once we have verified your entity and approved your status.  Thank you!" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [av show];
        }
    }
}

- (IBAction)showTOS:(id)sender
{
    STKWebViewController *vc = [[STKWebViewController alloc] init];
    [vc setUrl:[NSURL URLWithString:@"https://prizmapp.com/terms"]];
    UINavigationController *nvc = [[UINavigationController alloc] initWithRootViewController:vc];

    [self presentViewController:nvc animated:YES completion:nil];
}

- (IBAction)finishProfile:(id)sender
{
    
    
    [[self view] endEditing:YES];
    if([self verifyFields:YES]) {
        [STKProcessingView present];
        
        if([self progressMask] != 0) {
            [self setRetrySyncOnProgressMaskClear:YES];
            return;
        }
        
        NSString *firstName = [[self user] firstName];
        if([firstName length] > 0) {
            NSString *firstChar = [[firstName substringToIndex:1] uppercaseString];
            [[self user] setFirstName:[firstChar stringByAppendingString:[firstName substringFromIndex:1]]];
        }
        
        NSString *lastName = [[self user] lastName];
        if([lastName length] > 0) {
            NSString *firstChar = [[lastName substringToIndex:1] uppercaseString];
            [[self user] setLastName:[firstChar stringByAppendingString:[lastName substringFromIndex:1]]];
        }
        
        void (^registerBlock)(void) = nil;
        
        if([self isEditingProfile]) {
            registerBlock = ^{
                [[STKUserStore store] updateUserDetails:[self user] completion:^(STKUser *u, NSError *err) {
                    [STKProcessingView dismiss];
                    if(err) {
                        [[STKErrorStore alertViewForError:err delegate:nil] show];
                    } else {
                        [[self navigationController] popViewControllerAnimated:YES];
                        if (! self.orgPresent){
                            [[NSNotificationCenter defaultCenter] postNotificationName:@"ShowWelcome" object:nil];
                        }
                        
                    }
                }];
            };
        } else {
            registerBlock = ^{
                [[STKUserStore store] registerAccount:[self user]
                                           completion:^(STKUser *user, NSError *err) {
                                               [STKProcessingView dismiss];
                                               if(!err) {
                                                   if([[self presentingViewController] isKindOfClass:[STKMenuController class]]){
                                                      
                                                       STKMenuController *menuController = (STKMenuController *)[self presentingViewController];
                                        
                                                       [menuController setSelectedViewController:[[menuController viewControllers] objectAtIndex:1]];
                                                       
                                                     
                                                   }

                                                   UIViewController *menuController = [self presentingViewController];
                                                   [[STKUserStore store] fetchUserDetails:self.user additionalFields:nil completion:^(STKUser *u, NSError *err) {
                                                       if ([self underThirteen]) {
                                                           [self dismissViewControllerAnimated:NO completion:^{
                                                               HAConsentViewController *hvc = [[HAConsentViewController alloc] init];
                                                               [hvc setUser:u];
                                                               HANavigationController *nvc = [[HANavigationController alloc] init];
                                                               [nvc addChildViewController:hvc];
                                                               [menuController presentViewController:nvc animated:NO completion:nil];
                                                           }];
                                                       } else {
                                                           [self dismissViewControllerAnimated:NO completion:^{
                                                               HAInterestsViewController *ivc = [[HAInterestsViewController alloc] init];
                                                               [ivc setUser:u];
                                                               HANavigationController *nvc = [[HANavigationController alloc] init];
                                                               [nvc addChildViewController:ivc];
                                                               [menuController presentViewController:nvc animated:NO completion:nil];
                                                           }];
                                                       }
                                                       
                                                       
                                                   }];
                                                   
                                                   
                                                  
                                                   
                                                   // profile created
                                                   // report event and type of account created
                                                   NSString *val = [user externalServiceType];
                                                   if(!val)
                                                       val = @"email";
                                                   [[Mixpanel sharedInstance] track:@"Profile Created"];
                                               } else {
                                                   [[STKErrorStore alertViewForError:err delegate:nil] show];
                                               }
                                           }];
            };
        }
        
        if((![[self user] city] || [[[self user] changedValues] objectForKey:@"zipCode"]) && [[self user] zipCode]) {
            CLGeocoder *gc = [[CLGeocoder alloc] init];
            [gc geocodeAddressDictionary:@{(__bridge NSString *)kABPersonAddressZIPKey : [[self user] zipCode]}
                       completionHandler:^(NSArray *placemarks, NSError *error) {
                           if(!error) {
                               CLPlacemark *cp = [placemarks lastObject];
                               [[self user] setCity:[cp locality]];

                               NSString *state = [cp administrativeArea];
                               [[self user] setState:state];
                               
                               registerBlock();
                           } else {
                               [STKProcessingView dismiss];
                               UIAlertView *av = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Zip Code Error", @"zip code error title")
                                                                            message:NSLocalizedString(@"Oops. There was a problem determining your location from the provided zip code. Ensure you have an internet connection and a valid zip code and try again.", @"zip code error message")
                                                                           delegate:nil
                                                                  cancelButtonTitle:NSLocalizedString(@"OK", @"standard dismiss button title")
                                                                  otherButtonTitles:nil];
                               [av show];
                           }
                       }];
        } else {
            registerBlock();
        }
    }
}


- (void)maleButtonTapped:(id)sender atIndexPath:(NSIndexPath *)ip
{
    [[self user] setGender:STKUserGenderMale];
}

- (void)femaleButtonTapped:(id)sender atIndexPath:(NSIndexPath *)ip
{
    [[self user] setGender:STKUserGenderFemale];
}

- (void)notSetButtonTapped:(id)sender atIndexPath:(NSIndexPath *)ip
{
    [[self user] setGender:STKUserGenderUnknown];
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *item = [[self items] objectAtIndex:[indexPath row]];
    if([[item objectForKey:@"cellType"] isEqualToString:@"textView"]) {
        STKTextInputViewController *ivc = [[STKTextInputViewController alloc] init];
        [ivc setText:[[self user] valueForKeyPath:[item objectForKey:@"key"]]];
        
        __weak STKTextInputViewController *wivc = ivc;
        [ivc setCompletion:^(NSString *str) {
            [[self user] setValue:str forKeyPath:[item objectForKey:@"key"]];
            [[wivc navigationController] popViewControllerAnimated:YES];
        }];
        [[self navigationController] pushViewController:ivc animated:YES];
    } else if ([[item objectForKey:@"cellType"] isEqualToString:@"list"]) {
        STKItemListViewController *lvc = [[STKItemListViewController alloc] init];
        
        NSMutableArray *orderedTitles = [[NSMutableArray alloc] init];
        for(NSString *key in [item objectForKey:@"values"]) {
            [orderedTitles addObject:[[self subtypeFormatters] objectForKey:key]];
        }
        [lvc setItems:orderedTitles];
        [[self navigationController] pushViewController:lvc animated:YES];
        
        [lvc setSelectionBlock:^(int idx) {
            [[self user] setSubtype:[[item objectForKey:@"values"] objectAtIndex:idx]];
            [[self navigationController] popViewControllerAnimated:YES];
        }];
    } else if ([[item objectForKey:@"cellType"] isEqualToString:@"religion"]) {
        HAItemListViewController *lvc = [[HAItemListViewController alloc] init];
        [lvc setTitle:@"Religion"];
        NSMutableArray *orderedTitles = [[NSMutableArray alloc] init];
        for(NSString *key in [item objectForKey:@"values"]) {
            [orderedTitles addObject:[[self religions] objectForKey:key]];
        }
        [lvc setItems:orderedTitles];
        [[self navigationController] pushViewController:lvc animated:YES];
        
        [lvc setSelectionBlock:^(int idx) {
            [[self user] setReligion:[[item objectForKey:@"values"] objectAtIndex:idx]];
            [[self navigationController] popViewControllerAnimated:YES];
        }];
        
    } else if ([[item objectForKey:@"cellType"] isEqualToString:@"ethnicity"]) {
        HAItemListViewController *lvc = [[HAItemListViewController alloc] init];
        [lvc setTitle:@"Ethnicity"];
        NSMutableArray *orderedTitles = [[NSMutableArray alloc] init];
        for(NSString *key in [item objectForKey:@"values"]) {
            [orderedTitles addObject:[[self ethnicities] objectForKey:key]];
        }
        [lvc setItems:orderedTitles];
        [[self navigationController] pushViewController:lvc animated:YES];
        
        [lvc setSelectionBlock:^(int idx) {
            [[self user] setEthnicity:[[item objectForKey:@"values"] objectAtIndex:idx]];
            [[self navigationController] popViewControllerAnimated:YES];
        }];
    } else if ([[item objectForKey:@"cellType"] isEqualToString:@"password"]) {
        HAChangePasswordViewController *pvc = [[HAChangePasswordViewController alloc] init];
//        [pvc setUserEmail:[[self user] email]];
        [[self navigationController] pushViewController:pvc animated:YES];
    }
    
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[self items] count];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    [cell setBackgroundColor:[UIColor clearColor]];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *item = [[self items] objectAtIndex:[indexPath row]];

    NSString *cellType = [item objectForKey:@"cellType"];
    if(cellType) {
        if([cellType isEqualToString:@"gender"]) {
            STKGenderCell *c = [STKGenderCell cellForTableView:tableView target:self];
            if([[[self user] gender] isEqualToString:STKUserGenderFemale]) {
                [[c notSetButton] setSelected:NO];
                [[c femaleButton] setSelected:YES];
                [[c maleButton] setSelected:NO];
            } else  if ([self.user.gender isEqualToString:STKUserGenderMale]){
                [[c femaleButton] setSelected:NO];
                [[c maleButton] setSelected:YES];
                [[c notSetButton] setSelected:NO];
            } else {
                [[c maleButton] setSelected:NO];
                
                if ([self isEditingProfile]) {
                    [[c femaleButton] setSelected:NO];
                    [[c notSetButton] setSelected:YES];
                } else {
                    [self.user setGender:STKUserGenderFemale];
                    [[c femaleButton] setSelected:YES];
                    [[c notSetButton] setSelected:NO];
                }
            }
            return c;
        } else if([cellType isEqualToString:@"date"]) {
            STKDateCell *c = [STKDateCell cellForTableView:tableView target:self];
            [c setDefaultDate:[NSDate dateWithTimeIntervalSinceNow:-60*60*24*365.25*16]];
            [[c label] setText:[item objectForKey:@"title"]];
            
            NSString *key = [item objectForKey:@"key"];
            [c setDate:[[self user] valueForKey:key]];
            [[c textField] setInputAccessoryView:[self toolbar]];
            return c;
        } else if([cellType isEqualToString:@"lock"]) {
            STKLockCell *c = [STKLockCell cellForTableView:tableView target:self];

            return c;
        } else if([cellType isEqualToString:@"segmented"]) {
            STKSegmentedControlCell *c = [STKSegmentedControlCell cellForTableView:tableView target:self];
            NSInteger selected = [[c control] selectedSegmentIndex];
            [[c control] removeAllSegments];
            for(NSString *n in [item objectForKey:@"values"]) {
                [[c control] insertSegmentWithTitle:n atIndex:0 animated:NO];
            }
            [[c control] setSelectedSegmentIndex:selected];
            
            return c;
        }
    }
    
    STKTextFieldCell *c = [STKTextFieldCell cellForTableView:tableView target:self];
    
    if([cellType isEqual:@"textView"] ||
       [cellType isEqualToString:@"list"] ||
       [cellType isEqualToString:@"password"] ||
       [cellType isEqualToString:@"religion"] ||
       [cellType isEqualToString:@"ethnicity"]) {
        [[c textField] setEnabled:NO];
    } else {
        [[c textField] setEnabled:YES];
    }
    
    
    [[c label] setText:[item objectForKey:@"title"]];
    NSString *value = nil;
    if([[item objectForKey:@"key"] isEqualToString:@"confirmPassword"])
        value = [self confirmedPassword];
    else if ([[item objectForKey:@"key"] isEqualToString:@"subtype"]) {
        value = [[self subtypeFormatters] objectForKey:[[self user] valueForKey:@"subtype"]];
    } else
        value = [[self user] valueForKey:[item objectForKey:@"key"]];
    
    [[c textField] setText:value];
    
    [[c textField] setAttributedPlaceholder:nil];
    
    if(![[item objectForKey:@"key"] isEqualToString:@"confirmPassword"]) {
        if(![[self requiredKeys] containsObject:[item objectForKey:@"key"]]) {
            NSAttributedString *placeholder = [[NSAttributedString alloc] initWithString:@"optional"
                                                                              attributes:@{NSFontAttributeName : STKFont(14), NSForegroundColorAttributeName : [UIColor HATextColor]}];
            [[c textField] setAttributedPlaceholder:placeholder];
        }
    }
    
    NSDictionary *textOptions = [item objectForKey:@"options"];
    [[c textField] setAutocapitalizationType:UITextAutocapitalizationTypeNone];
    [[c textField] setSecureTextEntry:NO];
    [[c textField] setKeyboardType:UIKeyboardTypeDefault];
    
    if([textOptions objectForKey:@"formatter"]) {
        if([[textOptions objectForKey:@"formatter"] isEqualToString:@"phoneNumber"]) {
            static STKPhoneNumberFormatter *phoneFormatter = nil;
            if(!phoneFormatter) {
                phoneFormatter = [[STKPhoneNumberFormatter alloc] init];
            }
            [c setTextFormatter:phoneFormatter];
        }
        [[c textField] setText:[[c textFormatter] stringForObjectValue:[[c textField] text]]];
    } else {
        [c setTextFormatter:nil];
    }
    
    for(NSString *optKey in textOptions) {
        if([optKey isEqualToString:@"autocapitalizationType"])
            [[c textField] setAutocapitalizationType:[[textOptions objectForKey:optKey] intValue]];
        
        
        if([optKey isEqualToString:@"secureTextEntry"])
            [[c textField] setSecureTextEntry:[[textOptions objectForKey:optKey] boolValue]];
        
        if([optKey isEqualToString:@"keyboardType"])
            [[c textField] setKeyboardType:[[textOptions objectForKey:optKey] intValue]];

    }

    [[c textField] setInputAccessoryView:[self toolbar]];

    [[c textField] setAutocorrectionType:UITextAutocorrectionTypeNo];
    
    return c;
}
- (IBAction)previousTapped:(id)sender
{
    int row = (int)[[self editingIndexPath] row] - 1;
    if(row < 0)
        row = (int)[[self items] count] - 1;
    
    [self setEditingIndexPath:[NSIndexPath indexPathForRow:row
                                                 inSection:0]];
    UITableViewCell *c = [[self tableView] cellForRowAtIndexPath:[self editingIndexPath]];
    if(!c) {
        [[self tableView] scrollToRowAtIndexPath:[self editingIndexPath]
                                atScrollPosition:UITableViewScrollPositionNone
                                        animated:NO];
        c = [[self tableView] cellForRowAtIndexPath:[self editingIndexPath]];
    }
    if([c respondsToSelector:@selector(textField)]) {
        [[(STKTextFieldCell *)c textField] becomeFirstResponder];
    } else {
        [self previousTapped:nil];
    }
}

- (NSDictionary *)religions
{
    NSDictionary *religions = @{@"Anglican (Episcopal)" : @"Anglican (Episcopal)",
                                @"Bahá'í" : @"Bahá'í",
                                @"Buddhist" : @"Buddhist",
                                @"Caodalist" : @"Caodalist",
                                @"Cheondoist" : @"Cheondoist",
                                @"Christian" : @"Christian",
                                @"Christian Scientist" : @"Christian Scientist",
                                @"Church of World Messianity" : @"Church of World Messianity",
                                @"Congregatonalist (UCC)" : @"Congregatonalist (UCC)",
                                @"Disciples of Christ" : @"Disciples of Christ",
                                @"Friend (Quaker)" : @"Friend (Quaker)",
                                @"Hindu" : @"Hindu",
                                @"Jain" : @"Jain",
                                @"Jehovah's Witness" : @"Jehovah's Witness",
                                @"Jewish" : @"Jewish",
                                @"Latter-day Saint (Mormon)" : @"Latter-day Saint (Mormon)",
                                @"Lutheran" : @"Lutheran",
                                @"Methodist" : @"Methodist",
                                @"Moravian" : @"Moravian",
                                @"Muslim" : @"Muslim",
                                @"None" : @"None",
                                @"Orthodox" : @"Orthodox",
                                @"Other - Non-Christian" : @"Other - Non-Christian",
                                @"Pentacostal" : @"Pentacostal",
                                @"Presbyterian" : @"Presbyterian",
                                @"Rastafari" : @"Rastafari",
                                @"Reformed" : @"Reformed",
                                @"Roman Chatholic" : @"Roman Chatholic",
                                @"Seicho-no-le-ist" : @"Seicho-no-le-ist",
                                @"Seventh Day Adventist" : @"Seventh Day Adventist",
                                @"Sikh" : @"Sikh",
                                @"Taoist" : @"Taoist",
                                @"Unitarian Universalist (UU)" : @"Unitarian Universalist (UU)",
                                @"Wiccan (Pagan)" : @"Wiccan (Pagan)",
                                @"Yazidi" : @"Yazidi"
                                };
    return religions;
}

- (NSDictionary *)ethnicities
{
    NSDictionary *ethnicities = @{@"African-American or Black" : @"African-American or Black",
                                  @"American Indian or Alaska Native" : @"American Indian or Alaska Native",
                                  @"Asian" : @"Asian",
                                  @"Caucasian or White" : @"Caucasian or White",
                                  @"Hispanic or Latino" : @"Hispanic or Latino",
                                  @"Native Hawaiian or Other Pacific Islander" : @"Native Hawaiian or Other Pacific Islander"
                                  };
    return ethnicities;
}

- (void)sortReligionsAndEthinicitiesIntoSortedArrays
{
    NSSortDescriptor *sd = [NSSortDescriptor sortDescriptorWithKey:nil ascending:YES selector:@selector(localizedStandardCompare:)];
    
    _religionValues = [[[self religions] allValues] sortedArrayUsingDescriptors:@[sd]];
    _ethnicityValues = [[[self ethnicities] allValues] sortedArrayUsingDescriptors:@[sd]];
}

- (IBAction)nextTapped:(id)sender
{
    int row = (int)[[self editingIndexPath] row] + 1;
    if(row >= [[self items] count])
        row = 0;
    
    [self setEditingIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
    UITableViewCell *c = [[self tableView] cellForRowAtIndexPath:[self editingIndexPath]];
    if(!c) {
        [[self tableView] scrollToRowAtIndexPath:[self editingIndexPath]
                                atScrollPosition:UITableViewScrollPositionNone
                                        animated:NO];
        c = [[self tableView] cellForRowAtIndexPath:[self editingIndexPath]];
    }
    if([c respondsToSelector:@selector(textField)]) {
        if([[(STKTextFieldCell *)c textField] canBecomeFirstResponder]) {
            [[(STKTextFieldCell *)c textField] becomeFirstResponder];
        } else {
            [self nextTapped:nil];
        }
    } else {
        [self nextTapped:nil];
    }
}

- (IBAction)doneTapped:(id)sender
{
    [[self view] endEditing:YES];
}

@end


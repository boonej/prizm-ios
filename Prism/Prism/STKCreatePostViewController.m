//
//  STKCreatePostViewController.m
//  Prism
//
//  Created by Joe Conway on 11/7/13.
//  Copyright (c) 2013 Higher Altitude. All rights reserved.
//

#import "STKCreatePostViewController.h"
#import "STKHashtagToolbar.h"
#import "STKTextImageCell.h"
#import "STKImageCollectionViewCell.h"
#import "STKImageChooser.h"
#import "STKPost.h"
#import "STKContentStore.h"
#import "UITextView+STKHashtagDetector.h"
#import "STKImageStore.h"
#import "STKProcessingView.h"
#import "STKBaseStore.h"
#import "STKUserStore.h"
#import "STKUser.h"
#import "STKLocationListViewController.h"
#import "STKFoursquareLocation.h"
#import "STKHomeViewController.h"
#import "UIViewController+STKControllerItems.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "STKMarkupController.h"
#import "STKMarkupUtilities.h"
#import "UIImage+STKLocation.h"
#import "HANavigationController.h"

#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

NSString * const STKCreatePostPlaceholderText = @"Caption your post...";

@interface STKCreatePostViewController ()
    <STKHashtagToolbarDelegate, UICollectionViewDataSource, UICollectionViewDelegate, UITextViewDelegate, STKMarkupControllerDelegate, UIAlertViewDelegate, STKLocationListViewControllerDelegate, UICollectionViewDelegateFlowLayout, UINavigationControllerDelegate>

@property (weak, nonatomic) IBOutlet UIImageView *locationIndicator;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *optionHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *optionBottomConstraint;
@property (weak, nonatomic) IBOutlet UITextView *postTextView;
@property (weak, nonatomic) IBOutlet UICollectionView *categoryCollectionView;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UICollectionView *optionCollectionView;
@property (weak, nonatomic) IBOutlet UILabel *locationField;
@property (nonatomic, weak) IBOutlet UIView *privacyInstructions;
@property (nonatomic, strong) STKMarkupController *markupController;


@property (nonatomic, getter = isUploadingImage) BOOL uploadingImage;
@property (nonatomic) BOOL waitingForImageToFinish;

@property (nonatomic, strong) NSArray *categoryItems;
@property (nonatomic, strong) NSArray *optionItems;

@property (nonatomic, strong) NSMutableDictionary *postInfo;
@property (nonatomic, strong) UIImage *postImage;
@property (nonatomic, strong) UIImage *originalPostImage;


- (void)changeImage:(id)sender;
- (IBAction)adjustImage:(id)sender;
- (IBAction)closePrivacy:(id)sender;

@end

@implementation STKCreatePostViewController


- (void)keyboardWillAppear:(NSNotification *)note
{
    CGRect r = [[[note userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    r.origin.y -= _markupController.view.frame.size.height;
    r.origin.x = 0;
    r.size.height = _markupController.view.frame.size.height;
    r.size.width = _markupController.view.frame.size.width;
    [_markupController.view setFrame:r];
    [_markupController.view setHidden:NO];

    [[self view] setNeedsUpdateConstraints];
    
//    [[[self markupController] view] setFrame:CGRectMake(0, [[self view] bounds].size.height - r.size.height - [[self postTextView] bounds].size.height - 45, 320, 44)];
    
}

- (void)keyboardWillDissapear:(NSNotification *)note
{
//    CGRect r = [[[note userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
//    r.origin.y -= _markupController.view.frame.size.height;
//    r.origin.x = 0;
//    r.size.height = _markupController.view.frame.size.height;
//    r.size.width = _markupController.view.frame.size.width;
//    [_markupController.view setFrame:r];
    [_markupController.view setHidden:YES];
    
    [[self view] setNeedsUpdateConstraints];
    
    //    [[[self markupController] view] setFrame:CGRectMake(0, [[self view] bounds].size.height - r.size.height - [[self postTextView] bounds].size.height - 45, 320, 44)];
    
}


- (void)resizeTextArea
{
    CGRect currentMarkupFrame = [[[self markupController] view] frame];
//    float delta = ([[self view] bounds].size.height - ([[self heightContainerConstraint] constant] + [[self bottomContainerConstraint] constant])) - currentMarkupFrame.size.height;
//    currentMarkupFrame.origin.y = delta - 1;
    [[[self markupController] view] setFrame:currentMarkupFrame];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _postInfo = [[NSMutableDictionary alloc] init];
        [_postInfo setObject:STKPostVisibilityPublic forKey:STKPostVisibilityKey];
        UIBarButtonItem *bbiCancel = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain target:self action:@selector(cancel:)];
        UIBarButtonItem *bbiPost = [[UIBarButtonItem alloc] initWithTitle:@"Save" style:UIBarButtonItemStylePlain target:self action:@selector(post:)];
        
        [[self navigationItem] setLeftBarButtonItem:bbiCancel];
        [[self navigationItem] setRightBarButtonItem:bbiPost];
        [[self navigationItem] setTitle:@"Post"];
        
        _categoryItems = @[
            @{@"title" : @"Aspiration", STKPostTypeKey : STKPostTypeAspiration, @"image" : [UIImage imageNamed:@"category_aspiration_disabled"],
              @"selectedImage" : [UIImage imageNamed:@"category_aspirations_selected"]},
            @{@"title" : @"Passion", STKPostTypeKey : STKPostTypePassion, @"image" : [UIImage imageNamed:@"category_passions_disabled"],
              @"selectedImage" : [UIImage imageNamed:@"category_passions_selected"]},
            @{@"title" : @"Experience", STKPostTypeKey : STKPostTypeExperience, @"image" : [UIImage imageNamed:@"category_experiences_disabled"],
              @"selectedImage" : [UIImage imageNamed:@"category_experiences_selected"]},
            @{@"title" : @"Achievement", STKPostTypeKey : STKPostTypeAchievement, @"image" : [UIImage imageNamed:@"category_achievements_disabled"],
              @"selectedImage" : [UIImage imageNamed:@"category_achievements_selected"]},
            @{@"title" : @"Inspiration", STKPostTypeKey : STKPostTypeInspiration, @"image" : [UIImage imageNamed:@"category_inspiration_disabled"],
              @"selectedImage" : [UIImage imageNamed:@"category_inspiration_selected"]},
            @{@"title" : @"Private", STKPostTypeKey : STKPostTypePersonal, @"image" : [UIImage imageNamed:@"category_personal_disabled"],
              @"selectedImage" : [UIImage imageNamed:@"category_personal_selected"]}
        ];
        
        _optionItems = @[
                         @{@"key" : @"camera", @"image" : [UIImage imageNamed:@"btn_camera"], @"selectedImage" : [UIImage imageNamed:@"btn_camera_selected"], @"action" : @"changeImage:"},
                         @{@"key" : @"location", @"image" : [UIImage imageNamed:@"btn_pin"], @"selectedImage" : [UIImage imageNamed:@"btn_pin_selected"], @"action" : @"findLocation:"},
                         @{@"key" : @"user", @"image" : [UIImage imageNamed:@"btn_usertag_create_post"], @"selectedImage" : [UIImage imageNamed:@"btn_usertag_create_post"], @"action" : @"addUserTags:"},
                         @{@"key" : @"visibility", @"image" : [UIImage imageNamed:@"btn_globe"], @"selectedImage" : [UIImage imageNamed:@"globe_glow"], @"action" : @"toggleTrust:"},
                         @{@"key" : @"facebook", @"image" : [UIImage imageNamed:@"btn_facebook"], @"selectedImage" : [UIImage imageNamed:@"btn_facebook_selected"]},
                         @{@"key" : @"twitter", @"image" : [UIImage imageNamed:@"btn_twitter"], @"selectedImage" : [UIImage imageNamed:@"btn_twitter_selected"]},
                         @{@"key" : @"tumblr", @"image" : [UIImage imageNamed:@"btn_tumblr"], @"selectedImage" : [UIImage imageNamed:@"btn_tumblr_selected"]},
                         @{@"key" : @"personal", @"image" : [UIImage imageNamed:@"btn_foursquare"], @"selectedImage" : [UIImage imageNamed:@"btn_foursquare_selected"]}
        ];
    }
    return self;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [[[self navigationController] navigationBar] setBarStyle:UIBarStyleBlackTranslucent];
    [[[self navigationController] navigationBar] setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor HATextColor],
                                                                          NSFontAttributeName : STKFont(22)}];
    [[[self navigationController] navigationBar] setTintColor:[[UIColor HATextColor] colorWithAlphaComponent:0.8]];

    if([[[STKUserStore store] currentUser] isInstitution]) {
        [[self postInfo] setObject:STKPostVisibilityPublic forKey:STKPostVisibilityKey];
    }
    
    [[self locationIndicator] setHidden:[[self postInfo] objectForKey:STKPostLocationNameKey] == nil];
    
    if([self originalPost]) {
        [[self navigationItem] setTitle:@"Repost"];
        [[self postInfo] setObject:[[self originalPost] imageURLString] forKey:STKPostURLKey];
        [[self postInfo] setObject:[[self originalPost] uniqueID] forKey:STKPostOriginIDKey];
        [[STKImageStore store] fetchImageForURLString:[[self originalPost] imageURLString]
                                           completion:^(UIImage *img) {
                                               [[self imageView] setImage:img];
                                           }];
        //[[self optionHeightConstraint] setConstant:47];
    }
    
    // This will temporarily hide the four share options, which should always be hidden if this is a repost
    [[self optionHeightConstraint] setConstant:47];
    
    [[self optionCollectionView] reloadData];
    if ([[[STKUserStore store] currentUser] shouldDisplayPostInstructions]) {
        [self.postTextView setHidden:YES];
        [self.privacyInstructions setHidden:NO];
    } else {
        [self.postTextView setHidden:NO];
        [self.privacyInstructions setHidden:YES];
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillAppear:)
                                                 name:UIKeyboardDidShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillDissapear:)
                                                 name:UIKeyboardDidHideNotification
                                               object:nil];
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillAppear:)
//                                                 name:UIKeyboardDidChangeFrameNotification
//                                               object:nil];
    
}

- (void)setPostImage:(UIImage *)postImage
{
    _postImage = postImage;
    [self setUploadingImage:YES];
    [[self optionCollectionView] reloadData];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString: @"prefs:root=LOCATION_SERVICES"]];
    
    [[STKImageStore store] uploadImage:_postImage thumbnailCount:2 intoDirectory:[[[STKUserStore store] currentUser] uniqueID] completion:^(NSString *URLString, NSError *err) {
        if(postImage == [self postImage]) {
            
            if(![[self imageView] image]){
                [[self imageView] setImage:postImage];
            }
            
            [self setUploadingImage:NO];
            
            if(!err) {
                [[self postInfo] setObject:URLString forKey:STKPostURLKey];
                if([self waitingForImageToFinish]) {
                    [self createPost];
                }
            } else {
                [self setWaitingForImageToFinish:NO];
                
                [[self imageView] setImage:nil];
                
                UIAlertView *av = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error Uploading Image", @"image upload error title")
                                                             message:NSLocalizedString(@"Oops! The image you selected failed to upload. Make sure you have an internet connection and try again.", @"image upload error message")
                                                            delegate:self
                                                   cancelButtonTitle:NSLocalizedString(@"Never mind", @"cancel button title")
                                                   otherButtonTitles:NSLocalizedString(@"Try Again", @"try again button title"), nil];
                [av show];
            }
        }
    }];
}

- (void)addUserTags:(id)sender
{
    [[self postTextView] becomeFirstResponder];
    [[self markupController] displayAllUserResults];
}

- (void)findLocation:(id)sender
{
    STKLocationListViewController *lvc = nil;
    if ([self.postInfo objectForKey:STKPostLocationLatitudeKey] && [self.postInfo objectForKey:STKPostLocationLongitudeKey]) {
        double latitude = [[self.postInfo objectForKey:STKPostLocationLatitudeKey] doubleValue];
        double longitude = [[self.postInfo objectForKey:STKPostLocationLongitudeKey] doubleValue];
        CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(latitude, longitude);
        lvc = [[STKLocationListViewController alloc] initWithLocationCoordinate:coordinate];
    } else {
        lvc = [[STKLocationListViewController alloc] init];
    }
    
    [lvc setDelegate:self];
    HANavigationController *nvc = [[HANavigationController alloc] initWithRootViewController:lvc];
    [[nvc navigationBar] setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
    [self presentViewController:nvc animated:YES completion:nil];
}

- (void)locationListViewController:(STKLocationListViewController *)lvc choseLocation:(STKFoursquareLocation *)loc
{
    [[self postInfo] setObject:[NSString stringWithFormat:@"%@", [NSNumber numberWithDouble:[loc location].latitude]] forKey:STKPostLocationLatitudeKey];
    [[self postInfo] setObject:[NSString stringWithFormat:@"%@", [NSNumber numberWithDouble:[loc location].longitude]] forKey:STKPostLocationLongitudeKey];
    if([loc name]) {
        [[self postInfo] setObject:[loc name] forKey:STKPostLocationNameKey];
        [[self locationField] setText:[loc name]];
    }
    [[self locationIndicator] setHidden:[[self postInfo] objectForKey:STKPostLocationNameKey] == nil];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex == 0) {
        [self setPostImage:[self postImage]];
    }
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    if([[textView text] isEqualToString:STKCreatePostPlaceholderText]) {
        [textView setText:@""];
    }
    
}


- (void)textViewDidChange:(UITextView *)textView
{
    [textView setFont:STKFont(14)];
    [textView setTintColor:[UIColor HATextColor]];
    [[self markupController] textView:textView updatedWithText:[textView text]];
    [self resizeTextArea];
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    if([textView text] == nil || [[textView text] isEqualToString:@""]) {
        [textView setText:STKCreatePostPlaceholderText];
    }
}

- (void)toggleTrust:(id)sender
{
    NSString *postType = [[self postInfo] objectForKey:STKPostTypeKey];
    if ([postType isEqualToString:STKPostTypePersonal]) return;
    
//    if([postType isEqualToString:STKPostTypePersonal]) {
//        UIAlertView *av = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Sharing", @"visibility title")
//                                                     message:NSLocalizedString(@"This button changes whether this post is visible to everyone or just members of your Trust. Right now this post is marked as \"Personal\" which will only be seen by you. If you want to share this post with others, select a new category and then choose the sharing options.", @"viibility message")
//                                                    delegate:nil
//                                           cancelButtonTitle:NSLocalizedString(@"OK", @"standard dismiss button title")
//                                           otherButtonTitles:nil];
//        [av show];
//        return;
//    }
    
    NSString *postVisibility = [[self postInfo] objectForKey:STKPostVisibilityKey];
    if(!postVisibility) {
        [[self postInfo] setObject:STKPostVisibilityPublic forKey:STKPostVisibilityKey];
    } else if([postVisibility isEqualToString:STKPostVisibilityPublic]) {
        UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Privacy" message:@"This button changes this post from public to trust and will only be visible to you and your trust." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [av show];
        [[self postInfo] setObject:STKPostVisibilityTrust forKey:STKPostVisibilityKey];
    } else {
        [[self postInfo] setObject:STKPostVisibilityPublic forKey:STKPostVisibilityKey];
    }
    
    [[self optionCollectionView] reloadData];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    UIImageView *iv = [[UIImageView alloc] initWithImage:[UIImage HABackgroundImage]];
    [iv setFrame:[self.view bounds]];
    [self.view insertSubview:iv atIndex:0];
//    [[[self imageView] layer] setBorderColor:[[UIColor HATextColor] CGColor]];
//    [[[self imageView] layer] setBorderWidth:2];
    UIImage *img;
    UIGraphicsBeginImageContext(CGSizeMake(10, 10));
    [[UIColor colorWithWhite:1 alpha:0.2] set];
    UIRectFill(CGRectMake(0, 0, 10, 10));
    img = UIGraphicsGetImageFromCurrentImageContext();
    
    
    UIGraphicsEndImageContext();
    [self.navigationController.navigationBar setBackgroundImage:img forBarMetrics:UIBarMetricsDefault];
    
    _markupController = [[STKMarkupController alloc] initWithDelegate:self];
    if (SYSTEM_VERSION_LESS_THAN(@"8.0")) {
        [self.optionBottomConstraint setConstant:-6];
    }
    
    [[self postTextView] setText:STKCreatePostPlaceholderText];
    [[self view] addSubview:[[self markupController] view]];
    [_markupController.view setHidden:YES];
    [self.postTextView setFont:STKFont(14)];
    [self.postTextView setTintColor:[UIColor HATextColor]];
    
    [[self categoryCollectionView] registerNib:[UINib nibWithNibName:@"STKTextImageCell" bundle:nil]
                    forCellWithReuseIdentifier:@"STKTextImageCell"];
    [[self categoryCollectionView] setBackgroundColor:[UIColor clearColor]];
    [[self categoryCollectionView] setScrollEnabled:NO];
    
    [[self optionCollectionView] registerNib:[UINib nibWithNibName:@"STKImageCollectionViewCell" bundle:nil]
                    forCellWithReuseIdentifier:@"STKImageCollectionViewCell"];
    [self.view setAutoresizesSubviews:YES];
    [self.optionCollectionView setAutoresizesSubviews:YES];
    [[self optionCollectionView] setBackgroundColor:[UIColor clearColor]];
    [[self optionCollectionView] setScrollEnabled:NO];
    [self addBlurViewWithHeight:64.f];
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    if(collectionView == [self categoryCollectionView]) {
        return [[self categoryItems] count];
    }
    

//    return [[self optionItems] count];
    return 4;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if(collectionView == [self categoryCollectionView]) {
        NSDictionary *item = [[self categoryItems] objectAtIndex:[indexPath row]];
        STKTextImageCell *cell = (STKTextImageCell *)[collectionView dequeueReusableCellWithReuseIdentifier:@"STKTextImageCell"
                                                                                               forIndexPath:indexPath];
        [[cell label] setText:[item objectForKey:@"title"]];
        [[cell label] setTextColor:[UIColor HATextColor]];
        [[cell imageView] setImage:[item objectForKey:@"image"]];
        [cell setBackgroundColor:[UIColor clearColor]];
        
        if([[[self postInfo] objectForKey:STKPostTypeKey] isEqual:[item objectForKey:STKPostTypeKey]]) {
            [[cell imageView] setImage:[item objectForKey:@"selectedImage"]];
            [[cell label] setTextColor:[UIColor whiteColor]];
        }

        return cell;
    }
    
    if(collectionView == [self optionCollectionView]) {
        NSDictionary *item = [[self optionItems] objectAtIndex:[indexPath row]];
        STKImageCollectionViewCell *cell = (STKImageCollectionViewCell *)[collectionView dequeueReusableCellWithReuseIdentifier:@"STKImageCollectionViewCell"
                                                                                               forIndexPath:indexPath];
        [cell setBackgroundColor:[UIColor clearColor]];
        [[cell imageView] setImage:[item objectForKey:@"image"]];

        if([[item objectForKey:@"key"] isEqualToString:@"visibility"]) {
            if([[[self postInfo] objectForKey:STKPostVisibilityKey] isEqualToString:STKPostVisibilityPublic]) {
                [[cell imageView] setImage:[item objectForKey:@"selectedImage"]];
            }
        }
        if([[item objectForKey:@"key"] isEqualToString:@"location"]) {
            if([[self postInfo] objectForKey:STKPostLocationNameKey]) {
                [[cell imageView] setImage:[item objectForKey:@"selectedImage"]];
            }
        }
        
        if([[item objectForKey:@"key"] isEqualToString:@"camera"]) {
            if([self postImage]) {
                [[cell imageView] setImage:[item objectForKey:@"selectedImage"]];
            }
        }
//        NSLog(@"%f", self.optionCollectionView.frame.size.height);
        return cell;
    }


    return nil;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if(collectionView == [self categoryCollectionView]) {
        NSString *category = [[[self categoryItems] objectAtIndex:[indexPath row]] objectForKey:STKPostTypeKey];
        [[self postInfo] setObject:category
                            forKey:STKPostTypeKey];
        [collectionView reloadData];
        
        if([category isEqualToString:STKPostTypePersonal]) {
            [[self postInfo] removeObjectForKey:STKPostVisibilityKey];
            [[self optionCollectionView] reloadData];
        }
    } else if(collectionView == [self optionCollectionView]) {
        NSString *action = [[[self optionItems] objectAtIndex:[indexPath row]] objectForKey:@"action"];
        if(action) {
            [self performSelector:NSSelectorFromString(action) withObject:nil];
        }
    }
}


- (void)cancel:(id)sender
{
    [[self presentingViewController] dismissViewControllerAnimated:YES completion:nil];
}


- (void)createPost
{
    
    if(![[self postInfo] objectForKey:STKPostURLKey] && ![self isUploadingImage]) {
        // Do a card
        NSString *postText = [[self postInfo] objectForKey:STKPostTextKey];
        UIImage *img = [STKMarkupUtilities imageForText:postText];
        [self setPostImage:img];
    }
    
    if([self isUploadingImage]) {
        [STKProcessingView present];
        [self setWaitingForImageToFinish:YES];
        return;
    }

    // If we were waiting, the processing view is already up, but if we were not, make sure it goes up
    if(![self waitingForImageToFinish]) {
        [STKProcessingView present];
    }
    
    [[STKContentStore store] addPostWithInfo:[self postInfo] completion:^(STKPost *post, NSError *err) {
        [STKProcessingView dismiss];
        if(!err) {
            //if repost return user back to there home feed
            if([self originalPost]) {
                __block STKMenuController *menuController = (STKMenuController *)[self presentingViewController];
                [menuController setSelectedViewController:[[menuController viewControllers] objectAtIndex:0]];
                [menuController dismissViewControllerAnimated:YES completion:^{
                    [[menuController navigationController] popToRootViewControllerAnimated:NO];
                }];
                
            } else {
                [[self presentingViewController] dismissViewControllerAnimated:YES completion:nil];
            }
        } else {
            [[STKErrorStore alertViewForError:err delegate:nil] show];
        }
    }];
}

- (void)post:(id)sender
{
    NSString *msg = nil;
    // Verify that we have everything
    if(![[self postInfo] objectForKey:STKPostTypeKey]) {
        msg = NSLocalizedString(@"Choose the category this post belongs to from the bottom of the screen before posting.", @"choose category error message");
    }

    if(msg) {
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Missing Information", @"missing info title")
                                    message:msg
                                   delegate:nil
                          cancelButtonTitle:NSLocalizedString(@"OK", @"standard dismiss button title")
                          otherButtonTitles:nil] show];
        return;
    }
    
    if([[[self postTextView] text] length] > 0 && ![[[self postTextView] text] isEqualToString:STKCreatePostPlaceholderText]) {
        NSMutableAttributedString *text = [[[self postTextView] attributedText] mutableCopy];
        
        [text enumerateAttributesInRange:NSMakeRange(0, [text length]) options:0 usingBlock:^(NSDictionary *attrs, NSRange range, BOOL *stop) {
            NSTextAttachment *attachment = [attrs objectForKey:NSAttachmentAttributeName];
            if(attachment) {
                NSURL *userURL = [attrs objectForKey:NSLinkAttributeName];
                if(userURL) {
                    NSString *uniqueID = [userURL host];
                    [text replaceCharactersInRange:range withString:[NSString stringWithFormat:@"@%@", uniqueID]];
                }
            }
        }];
        [[self postInfo] setObject:[text string]
                            forKey:STKPostTextKey];
    }
    
    if(![[self postInfo] objectForKey:STKPostTextKey] && ![[self postInfo] objectForKey:STKPostURLKey] && ![self isUploadingImage]) {
        UIAlertView *av = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Missing Information", @"missing info title")
                                                     message:NSLocalizedString(@"A post must contain an image, text or both.", @"missing info text")
                                                    delegate:nil
                                           cancelButtonTitle:NSLocalizedString(@"OK", @"standard dismiss button title")
                                           otherButtonTitles:nil];
        [av show];
        return;
    }
    
    [self createPost];
}


- (void)markupController:(STKMarkupController *)markupController
           didSelectUser:(STKUser *)user
        forMarkerAtRange:(NSRange)range
{
    NSAttributedString *str = [STKMarkupUtilities userTagForUser:user attributes:@{NSFontAttributeName : STKFont(14), NSForegroundColorAttributeName : [UIColor HATextColor]}];
    
    if(range.location == NSNotFound) {
        range = NSMakeRange([[[self postTextView] textStorage] length], 0);
    }
    
    [[[self postTextView] textStorage] replaceCharactersInRange:range
                                           withAttributedString:str];
    [[[self postTextView] textStorage] appendAttributedString:[[NSAttributedString alloc] initWithString:@" "
                                                                                              attributes:@{NSFontAttributeName : STKFont(14), NSForegroundColorAttributeName : [UIColor HATextColor]}]];
    
    NSInteger newIndex = range.location + [str length] + 2;
    [[self postTextView] setSelectedRange:NSMakeRange(newIndex, 0)];

}

- (void)markupController:(STKMarkupController *)markupController
        didSelectHashTag:(NSString *)hashTag
        forMarkerAtRange:(NSRange)range
{
    if(range.location == NSNotFound) {
        range = NSMakeRange([[[self postTextView] textStorage] length], 0);
    }

    [[[self postTextView] textStorage] replaceCharactersInRange:range
                                                     withString:[NSString stringWithFormat:@"#%@ ", hashTag]];
    [[[self postTextView] textStorage] appendAttributedString:[[NSAttributedString alloc] initWithString:@" "
                                                                                              attributes:@{NSFontAttributeName : STKFont(14), NSForegroundColorAttributeName : [UIColor HATextColor]}]];
    
    NSInteger newIndex = range.location + [hashTag length] + 2;
    [[self postTextView] setSelectedRange:NSMakeRange(newIndex, 0)];
}

- (void)markupControllerDidFinish:(STKMarkupController *)markupController
{
    [self.markupController.view setHidden:YES];
    [[self postTextView] resignFirstResponder];
}


- (void)changeImage:(id)sender
{
   
    [[STKImageChooser sharedImageChooser] initiateImageChooserForViewController:self
                                                                        forType:STKImageChooserTypeImage
                                                                     completion:^(UIImage *img, UIImage *originalImage, NSDictionary *imageInfo) {
                                                                         [UIImage LocationCoordinateFromImageInfo:imageInfo completion:^(NSError *err, CLLocationCoordinate2D coordinate) {
                                                                             if (!err) {
                                                                                 [[self postInfo] setObject:[NSString stringWithFormat:@"%@", [NSNumber numberWithDouble:coordinate.latitude]] forKey:STKPostLocationLatitudeKey];
                                                                                 [[self postInfo] setObject:[NSString stringWithFormat:@"%@",[NSNumber numberWithDouble:coordinate.longitude]] forKey:STKPostLocationLongitudeKey];
                                                                             }
                                                                             [self setOriginalPostImage:originalImage];
                                                                             [self setPostImage:img];
                                                                             [[self imageView] setImage:img];
                                                                         }];
                                                                         
                                                                     }];
}

- (IBAction)adjustImage:(id)sender
{
    if(![self postImage]) {
        return;
    }
    
    [[STKImageChooser sharedImageChooser] initiateImageEditorForViewController:self
                                                                       forType:STKImageChooserTypeImage
                                                                         image:[self originalPostImage]
                                                                    completion:^(UIImage *img, UIImage *originalImage, NSDictionary *imageInfo) {
                                                                        [self setOriginalPostImage:originalImage];
                                                                        [self setPostImage:img];
                                                                        [[self imageView] setImage:img];

                                                                    }];
}


- (IBAction)closePrivacy:(id)sender
{
    [self.privacyInstructions setHidden:YES];
    [self.postTextView setHidden:NO];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:STKPrivacyInstructionsDismissedKey];
}




@end

//
//  HAInterestsViewController.m
//  Prizm
//
//  Created by Jonathan Boone on 9/18/14.
//  Copyright (c) 2014 Higher Altitude. All rights reserved.
//

#import "HAInterestsViewController.h"
#import "HAHashTagView.h"
#import "STKUserStore.h"
#import "STKProcessingView.h"
#import "STKInterest.h"
#import "HAInterestCell.h"
#import "UIViewController+STKControllerItems.h"
#import "HAFollowViewController.h"
#import "HAWelcomeViewController.h"
@interface HAInterestsViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

@property (nonatomic, weak) IBOutlet UIView * tagView;
@property (nonatomic, weak) IBOutlet UICollectionView *collectionView;
@property (nonatomic, strong) NSMutableArray * tagObjects;
//@property (nonatomic, strong) NSMutableArray * selectedHashTags;
@property (nonatomic, strong) NSMutableArray *selectedInterests;
@property (nonatomic, strong) NSArray *interests;
@property (nonatomic, weak) IBOutlet UIView * overlayView;
@property (nonatomic, strong) UIBarButtonItem * doneButton;
@property (nonatomic, strong) NSMutableDictionary *tagPositions;
@property (nonatomic, strong) NSMutableArray *cellSizes;

- (IBAction)doneButtonTapped:(id)sender;
- (IBAction)overlayCloseTapped:(id)sender;

@end

@implementation HAInterestsViewController

#pragma mark View Lifecycle

- (id)init
{
    self = [super init];
    if (self) {
        [self setStandalone:NO];
    }
    return self;
}

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
    self.user = [[STKUserStore store] currentUser];
    self.selectedInterests = [NSMutableArray array];
    [self addBlurViewWithHeight:64.f];
    self.tagObjects = [NSMutableArray array];
    [self.collectionView registerNib:[UINib nibWithNibName:@"HAInterestCell" bundle:nil] forCellWithReuseIdentifier:@"InterestCell"];
    [self.collectionView setAllowsMultipleSelection:YES];
    self.tagPositions = [NSMutableDictionary dictionary];
    [self.collectionView setContentInset:UIEdgeInsetsMake(75, 10, 0, 10)];
    // Do any additional setup after loading the view from its nib.
    if ([self isStandalone]){
        UIBarButtonItem *bbi = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btn_back"]
                                                  landscapeImagePhone:nil style:UIBarButtonItemStylePlain
                                                               target:self action:@selector(back:)];
        [self.navigationItem setLeftBarButtonItem:bbi];
        self.doneButton = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStylePlain target:self action:@selector(doneButtonTapped:)];
        [bbi setEnabled:(self.selectedInterests > 0)];
    } else {
        self.doneButton = [[UIBarButtonItem alloc] initWithTitle:@"Next" style:UIBarButtonItemStylePlain target:self action:@selector(nextButtonTapped:)];
    }
    
    
    [self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor HATextColor],
                                                                      NSFontAttributeName : STKFont(22)}];
    [self.navigationController.navigationBar setTintColor:[UIColor HATextColor]];
//    [self.doneButton setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor HATextColor],
//                                              NSFontAttributeName : STKFont(16)} forState:UIControlStateNormal];
//    [self.doneButton setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor clearColor],
//                                              NSFontAttributeName : STKFont(16)} forState:UIControlStateDisabled];
    
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    [layout setMinimumInteritemSpacing:2.f];
    [layout setMinimumLineSpacing:6.f];
    [layout setScrollDirection:UICollectionViewScrollDirectionVertical];
    [self.collectionView setCollectionViewLayout:layout];
    
    [self.navigationItem setRightBarButtonItem:self.doneButton];
    
    
    
    self.title = @"Interests";
    UIImage *backgroundImage = [UIImage HABackgroundImage];
    UIImageView *backgroundView = [[UIImageView alloc] initWithImage:backgroundImage];
    [self.view insertSubview:backgroundView atIndex:0];
    
}

- (void)loadCollectionData
{
    self.tagObjects = [NSMutableArray array];
    NSMutableArray *associatedInterests = [NSMutableArray array];
    [self.selectedInterests enumerateObjectsUsingBlock:^(STKInterest *interest, NSUInteger idx, BOOL *stop) {
        [self.tagObjects addObject:interest];
        if ([interest.subinterests count] > 0) {
            [associatedInterests addObjectsFromArray:[interest.subinterests allObjects]];
        }
    }];
    
    [associatedInterests enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([self.selectedInterests indexOfObjectPassingTest:^BOOL(STKInterest *in, NSUInteger idx, BOOL *stop) {
            return [in.uniqueID isEqualToString:[obj uniqueID]];
        }] == NSNotFound) {
            [self.tagObjects addObject:obj];
        }
    }];
  
    [self.interests enumerateObjectsUsingBlock:^(STKInterest *interest, NSUInteger idx, BOOL *stop) {
        NSArray *matchedObjects = [self.tagObjects filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
            return [[evaluatedObject uniqueID] isEqualToString:[interest uniqueID]];
        }]];
        if ([matchedObjects count] == 0) {
            [self.tagObjects addObject:interest];
        }
    }];
    [self sizeCells];
    [self.collectionView reloadData];
}

- (void)sizeCells
{
    self.cellSizes = [NSMutableArray array];
    NSInteger maxWidth = self.collectionView.contentSize.width;
    UIFont *font = STKFont(16);
    for (int i = 0; i < self.tagObjects.count + 2; i = i + 3) {
        STKInterest *i1 = i < self.tagObjects.count?[self.tagObjects objectAtIndex:i]:nil;
        STKInterest *i2 = i +1 < self.tagObjects.count?[self.tagObjects objectAtIndex:i + 1]:nil;
        STKInterest *i3 = i+2 < self.tagObjects.count?[self.tagObjects objectAtIndex:i + 2]:nil;
        CGSize size1;
        CGSize size2;
        CGSize size3;
        if (i1) {
            size1 = [i1.text sizeWithAttributes:@{NSFontAttributeName: font}];
        } else {
            size1 = CGSizeMake(0, 0);
        }
        if (i2) {
            size2 = [i2.text sizeWithAttributes:@{NSFontAttributeName: font}];
        } else {
            size2 = CGSizeMake(0, 0);
        }
        if (i3) {
            size3 = [i3.text sizeWithAttributes:@{NSFontAttributeName :font}];
        } else {
            size3 = CGSizeMake(0, 0);
        }
        
        NSInteger totalWidth = size1.width + size2.width + size3.width;
        NSInteger diff = maxWidth - totalWidth - 8;
        size1.width = size1.width + (diff/3);
        size2.width = size2.width + (diff/3);
        size3.width = size3.width + (diff/3);
        if (size1.height){
            [self.cellSizes addObject:@{@"width": @(size1.width)}];
        }
        if (size2.height){
            [self.cellSizes addObject:@{@"width": @(size2.width)}];
        }
        if (size3.height){
            [self.cellSizes addObject:@{@"width": @(size3.width)}];
        }
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    self.selectedInterests = [NSMutableArray array];
    [[STKUserStore store] fetchUserDetails:self.user additionalFields:nil completion:^(STKUser *u, NSError *err) {
        [self.selectedInterests addObjectsFromArray:[u.interests allObjects]];
        [self.tagObjects addObjectsFromArray:self.selectedInterests];
        [[STKUserStore store] fetchInterests:^(NSArray *interests, NSError *err) {
//            NSLog(@"%@", interests);
            self.interests = [interests filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(STKInterest *interest, NSDictionary *bindings) {
                return ![interest isSubinterest];
            }]];
            if ([self.selectedInterests count] < 3) {
                //                [self.collectionView setHidden:YES];
                [self.overlayView setHidden:NO];
                [self.doneButton setEnabled:NO];
            } else {
                //                [self.collectionView setHidden:NO];
                [self.overlayView setHidden:YES];
                [self.doneButton setEnabled:YES];
            }
            
            [self loadCollectionData];
        }];
    }];
    [super viewWillAppear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark Actions

- (IBAction)doneButtonTapped:(id)sender
{
//    __block NSMutableArray *hashtags = [NSMutableArray array];
//
//    [STKProcessingView present];
//    [self loadCollectionData];
    [STKProcessingView present];
    [[STKUserStore store] updateInterestsforUser:self.user completion:^(STKUser *u, NSError *err) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"HADidDisplayInterestPage"];
        [STKProcessingView dismiss];
        if ([self isStandalone]){
            [self.navigationController popViewControllerAnimated:YES];
        } else {
            [[self presentingViewController] dismissViewControllerAnimated:YES completion:nil];
        }
    }];
    
}

- (void)nextButtonTapped:(id)sender
{
    [[STKUserStore store] updateInterestsforUser:self.user completion:^(STKUser *u, NSError *err) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"HADidDisplayInterestPage"];
        [STKProcessingView dismiss];
        if (self.user.organization){
            HAWelcomeViewController *wvc = [[HAWelcomeViewController alloc] init];
            [wvc setOrganization:self.user.organization];
            [wvc setIntroFlow:YES];
            [self.navigationController pushViewController:wvc animated:YES];
        } else {
            HAFollowViewController *fvc = [[HAFollowViewController alloc] init];
            [fvc setStandalone:YES];
            [self.navigationController pushViewController:fvc animated:YES];
        }
        
    }];
    
}

- (IBAction)overlayCloseTapped:(id)sender
{
    [self.overlayView setHidden:YES];
    [self.collectionView setHidden:NO];
}

- (void)hideOverlayView
{
    [self.overlayView setHidden:YES];
}


- (void)back:(id)sender
{
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark Collection View Datasource


- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.tagObjects.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    HAInterestCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"InterestCell" forIndexPath:indexPath];
    STKInterest *interest = [self.tagObjects objectAtIndex:indexPath.row];
    [cell setInterest:interest];
    if ([self.selectedInterests indexOfObject:interest] != NSNotFound){
        [cell setSelected:YES];
        [cell setStored:YES];
        [self.collectionView selectItemAtIndexPath:indexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
//        [cell setSelected:YES];
        
    }
    if ([self.user.interests containsObject:interest]) {
        [cell setSelected:YES];
        [self.collectionView selectItemAtIndexPath:indexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
    }
    //    CGRect frame = cell.frame;
//    frame.size.width += 10;
//    cell.frame = frame;
//    label.center = cell.center;
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    float width = [[[self.cellSizes objectAtIndex:indexPath.row] objectForKey:@"width"] floatValue];
    CGSize size = CGSizeMake(width, 24);
    return size;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    HAInterestCell *cell = (HAInterestCell *)[collectionView cellForItemAtIndexPath:indexPath];
    [cell setSelected:YES];
    [cell setStored:NO];
    __block NSInteger row = indexPath.row;
    if (cell.interest.subinterests.count > 0 && [[self selectedInterests] indexOfObject:cell.interest] == NSNotFound) {
        NSMutableArray *ips = [NSMutableArray array];
        [cell.interest.subinterests enumerateObjectsUsingBlock:^(STKInterest *interest, BOOL *stop) {
            if ([self.tagObjects indexOfObject:interest] == NSNotFound) {
                [self.tagObjects insertObject:interest atIndex:++row];
                [ips addObject:[NSIndexPath indexPathForRow:row inSection:0]];
            }
        }];
        [self sizeCells];
        [collectionView insertItemsAtIndexPaths:ips];
        
    }
//    [self.selectedInterests addObject:cell.interest];
    [self.user addInterestsObject:cell.interest];
    if (self.user.interests.count > 2) {
        [self.doneButton setEnabled:YES];
    }
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath
{
    HAInterestCell *cell = (HAInterestCell *)[collectionView cellForItemAtIndexPath:indexPath];
    [self.selectedInterests removeObject:cell.interest];
    [self.user removeInterestsObject:cell.interest];
    [cell setSelected:NO];
    [cell setStored:NO];
    if (self.user.interests.count < 3) {
        [self.doneButton setEnabled:NO];
    }
}


@end

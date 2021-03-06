//
//  STKLocationListViewController.m
//  Prism
//
//  Created by Joe Conway on 1/27/14.
//  Copyright (c) 2014 Higher Altitude. All rights reserved.
//

#import "STKLocationListViewController.h"
#import "STKFoursquareLocation.h"
#import "STKContentStore.h"
#import "STKErrorStore.h"
#import "UIViewController+STKControllerItems.h"

@import CoreLocation;

@interface STKLocationListViewController () <CLLocationManagerDelegate, UISearchDisplayDelegate>
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) UISearchDisplayController *searchController;
@property (nonatomic, strong) NSArray *filteredLocations;

@property (nonatomic, strong) UIBarButtonItem *refreshButtonItem;
@property (nonatomic, strong) UIBarButtonItem *spinningButtonItem;
@property (nonatomic) CLLocationCoordinate2D locationCoordinate;
@property (nonatomic) BOOL fetchingLocations;

@end

@implementation STKLocationListViewController

- (id)initWithLocationCoordinate:(CLLocationCoordinate2D)locationCoordinate
{
    self = [super init];
    if (self) {
        self.locationCoordinate = locationCoordinate;
        
    }
    return  self;
}

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        _locationManager = [[CLLocationManager alloc] init];
        [_locationManager setDesiredAccuracy:kCLLocationAccuracyBest];
        [_locationManager setDelegate:self];
        self.locationCoordinate = CLLocationCoordinate2DMake(0, 0);
        
        UIColor *clr = [UIColor colorWithRed:49.0 / 255.0 green:141.0 / 255.0 blue:205.0 / 255.0 alpha:1];

        UIBarButtonItem *bbi = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain target:self action:@selector(cancel:)];
        [[self navigationItem] setRightBarButtonItem:bbi];
        [[self navigationItem] setTitle:@"Locations"];
        
        _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        bbi = [[UIBarButtonItem alloc] initWithCustomView:_activityIndicator];
        [[self navigationItem] setLeftBarButtonItem:bbi];
        
        _refreshButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"location"] landscapeImagePhone:nil style:UIBarButtonItemStylePlain target:self action:@selector(refresh:)];

        _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        [_activityIndicator setColor:clr];
        
        _spinningButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_activityIndicator];
        
        UISearchBar *sb = [[UISearchBar alloc] init];

        [sb setPlaceholder:@"Find location"];
        UISearchDisplayController *sdc = [[UISearchDisplayController alloc] initWithSearchBar:sb contentsController:self];
        [sdc setDelegate:self];
        [self setSearchController:sdc];
    }
    return self;
}

- (void)refresh:(id)sender
{
    if(![self fetchingLocations]) {
        [self fetchLocations];
    }
}

- (void)cancel:(id)sender
{
    [[self presentingViewController] dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[[self navigationController] navigationBar] setBackgroundImage:[UIImage imageNamed:@"nav_bar"] forBarMetrics:UIBarMetricsDefault];
    [[[self navigationController] navigationBar] setTranslucent:YES];
    [[[self navigationController] navigationBar] setBarStyle:UIBarStyleBlackTranslucent];
    [[[self navigationController] navigationBar] setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor HATextColor],
                                                                          NSFontAttributeName : STKFont(22)}];
    [[[self navigationController] navigationBar] setTintColor:[[UIColor HATextColor] colorWithAlphaComponent:0.8]];

    [[[self searchDisplayController] searchResultsTableView] setDataSource:self];
    [[[self searchDisplayController] searchResultsTableView] setDelegate:self];
    
    [[self tableView] setTableHeaderView:[[self searchDisplayController] searchBar]];
    
    UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"poweredByFoursquare_gray"]];
    [imageView setContentMode:UIViewContentModeScaleAspectFit];
    [imageView setFrame:CGRectMake(0, 0, 320, 100)];
    [[self tableView] setTableFooterView:imageView];
//    [self addBlurViewWithHeight:64.f];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    
    [[[self navigationController] navigationBar] setBarStyle:UIBarStyleBlackTranslucent];
    [[[self navigationController] navigationBar] setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor HATextColor],
                                                                          NSFontAttributeName : STKFont(22)}];
    [[[self navigationController] navigationBar] setTintColor:[[UIColor HATextColor] colorWithAlphaComponent:0.8]];
    
    if (self.locationCoordinate.longitude != 0 && self.locationCoordinate.latitude != 0) {
        [[STKContentStore store] fetchLocationNamesForCoordinate:self.locationCoordinate completion:^(NSArray *locations, NSError *err) {
            [self finishFetchingLocations];
            if(!err) {
                [self setLocations:locations];
                [[self tableView] reloadData];
            } else {
                
                UIAlertView *av = [STKErrorStore alertViewForError:err delegate:nil];
                [av show];
            }
        }];
    } else {
        [self fetchLocations];
    }
}

- (void)fetchLocations
{
    // 'requestWhenInUseAuthorization' is new for iOS8, also needs
    // 'NSLocationWhenInUseUsageDescription' key in Prism-Info.plist
    if ([[self locationManager] respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
        [[self locationManager] requestWhenInUseAuthorization];
    }
    [[self locationManager] startUpdatingLocation];
    [[self navigationItem] setLeftBarButtonItem:[self spinningButtonItem]];
    [[self activityIndicator] startAnimating];
    [self setFetchingLocations:YES];
}


- (void)finishFetchingLocations
{
    [self setFetchingLocations:NO];
    [[self activityIndicator] stopAnimating];
    [[self navigationItem] setLeftBarButtonItem:[self refreshButtonItem]];

}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    CLLocation *l = [locations lastObject];
    if([[l timestamp] timeIntervalSinceNow] > -60 * 3) {
        [[self locationManager] stopUpdatingLocation];
        
        [[STKContentStore store] fetchLocationNamesForCoordinate:[l coordinate] completion:^(NSArray *locations, NSError *err) {
            [self finishFetchingLocations];
            if(!err) {
                [self setLocations:locations];
                [[self tableView] reloadData];
            } else {
                
                UIAlertView *av = [STKErrorStore alertViewForError:err delegate:nil];
                [av show];
            }
        }];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(tableView == [self tableView]) {
        [[self delegate] locationListViewController:self
                                      choseLocation:[[self locations] objectAtIndex:[indexPath row]]];
    } else {
        [[self delegate] locationListViewController:self
                                      choseLocation:[[self filteredLocations] objectAtIndex:[indexPath row]]];
    }
    [[self presentingViewController] dismissViewControllerAnimated:YES completion:nil];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    UIAlertView *av = [STKErrorStore alertViewForError:error delegate:nil];
    [av show];
    [manager stopUpdatingLocation];
    [self finishFetchingLocations];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[self locationManager] stopUpdatingLocation];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if(tableView == [self tableView]) {
        if(![self locations]) {
            return 1;
        }
        
        return [[self locations] count];
    }
    
    return [[self filteredLocations] count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(![self locations]) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"UITableViewCell"];
        if(!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"UITableViewCell"];
        }
        [[cell textLabel] setTextColor:[UIColor darkGrayColor]];
        [[cell textLabel] setText:@"Searching nearby..."];
        [[cell textLabel] setFont:STKFont(16)];
        [[cell imageView] setImage:nil];
        return cell;
    }
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"UITableViewCell"];
    if(!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"UITableViewCell"];
    }
    [[cell textLabel] setTextColor:[UIColor darkGrayColor]];
    [[cell textLabel] setFont:STKBoldFont(16)];
    [[cell detailTextLabel] setTextColor:[UIColor darkGrayColor]];
    [[cell detailTextLabel] setFont:STKFont(14)];

    NSString *locationName = nil;
    NSString *address = nil;
    if(tableView != [self tableView]) {
        locationName = [[[self filteredLocations] objectAtIndex:[indexPath row]] name];
        address = [(STKFoursquareLocation *)[[self filteredLocations] objectAtIndex:[indexPath row]] address];
    } else {
        locationName = [[[self locations] objectAtIndex:[indexPath row]] name];
        address = [(STKFoursquareLocation *)[[self locations] objectAtIndex:[indexPath row]] address];
    }
    [[cell textLabel] setText:locationName];
    [[cell detailTextLabel] setText:address];
    
    return cell;
}

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    if(![self locations])
        return NO;
    
    _filteredLocations = [[self locations] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"name contains[cd] %@", searchString]];
    
    
    return YES;
}



@end

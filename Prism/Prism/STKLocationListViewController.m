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
@import CoreLocation;

@interface STKLocationListViewController () <CLLocationManagerDelegate, UISearchDisplayDelegate>
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) UISearchDisplayController *searchController;
@property (nonatomic, strong) NSArray *filteredLocations;
@end

@implementation STKLocationListViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        _locationManager = [[CLLocationManager alloc] init];
        [_locationManager setDesiredAccuracy:kCLLocationAccuracyBest];
        [_locationManager setDelegate:self];
        
        UIBarButtonItem *bbi = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel:)];
        [bbi setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor blueColor], NSFontAttributeName : [UIFont fontWithName:@"HelveticaNeue-Bold" size:16]} forState:UIControlStateNormal];
        [[self navigationItem] setRightBarButtonItem:bbi];
        [[self navigationItem] setTitle:@"Locations"];
        
        _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        bbi = [[UIBarButtonItem alloc] initWithCustomView:_activityIndicator];
        [[self navigationItem] setLeftBarButtonItem:bbi];
        
        UISearchBar *sb = [[UISearchBar alloc] init];

        [sb setPlaceholder:@"Find location"];
        UISearchDisplayController *sdc = [[UISearchDisplayController alloc] initWithSearchBar:sb contentsController:self];
        [sdc setDelegate:self];
        [self setSearchController:sdc];
    }
    return self;
}

- (void)cancel:(id)sender
{
    [[self presentingViewController] dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[self tableView] registerClass:[UITableViewCell class]
             forCellReuseIdentifier:@"UITableViewCell"];

    [[[self searchDisplayController] searchResultsTableView] setDataSource:self];
    [[[self searchDisplayController] searchResultsTableView] setDelegate:self];
    [[[self searchDisplayController] searchResultsTableView] registerClass:[UITableViewCell class]
                                                    forCellReuseIdentifier:@"UITableViewCell"];
    
    [[self tableView] setTableHeaderView:[[self searchDisplayController] searchBar]];
    
    UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"poweredByFoursquare_gray"]];
    [imageView setContentMode:UIViewContentModeScaleAspectFit];
    [imageView setFrame:CGRectMake(0, 0, 320, 100)];
    [[self tableView] setTableFooterView:imageView];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[self locationManager] startUpdatingLocation];
    [[self activityIndicator] startAnimating];
    [[[self navigationController] navigationBar] setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor blackColor], NSFontAttributeName : STKFont(22)}];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    CLLocation *l = [locations lastObject];
    if([[l timestamp] timeIntervalSinceNow] > -60 * 3) {
        [[self activityIndicator] stopAnimating];
        [[self locationManager] stopUpdatingLocation];
        
        [[STKContentStore store] fetchLocationNamesForCoordinate:[l coordinate] completion:^(NSArray *locations, NSError *err) {
            if(!err) {
                [self setLocations:locations];
                [[self tableView] reloadData];
            } else {
                UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Error Finding Location"
                                                             message:[err localizedDescription]
                                                            delegate:nil
                                                   cancelButtonTitle:@"OK"
                                                   otherButtonTitles:nil];
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
    UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Error Finding Location"
                                                 message:[error localizedDescription]
                                                delegate:nil
                                       cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [av show];
    [manager stopUpdatingLocation];
    [[self activityIndicator] stopAnimating];
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
    // poweredByFoursquare_gray
    if(![self locations]) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"UITableViewCell" forIndexPath:indexPath];
        [[cell textLabel] setTextColor:[UIColor darkGrayColor]];
        [[cell textLabel] setText:@"Searching nearby..."];
        [[cell textLabel] setFont:STKFont(16)];
        [[cell imageView] setImage:nil];
        return cell;
    }
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"UITableViewCell" forIndexPath:indexPath];
    [[cell textLabel] setTextColor:[UIColor darkGrayColor]];
    [[cell textLabel] setFont:STKFont(16)];

    NSString *locationName = nil;
    
    if(tableView != [self tableView]) {
        locationName = [[[self filteredLocations] objectAtIndex:[indexPath row]] name];
    } else {
        locationName = [[[self locations] objectAtIndex:[indexPath row]] name];
    }
    [[cell textLabel] setText:locationName];
    
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

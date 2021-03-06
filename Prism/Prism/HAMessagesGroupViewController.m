//
//  HAMessagesGroupViewController.m
//  Prizm
//
//  Created by Jonathan Boone on 8/14/15.
//  Copyright (c) 2015 Higher Altitude. All rights reserved.
//

#import "HAMessagesGroupViewController.h"
#import "HAGroupCell.h"
#import "UITableViewCell+HAExtensions.h"
#import "UIViewController+STKControllerItems.h"
#import "STKUser.h"
#import "STKUserStore.h"
#import "STKOrganization.h"
#import "STKOrgStatus.h"
#import "STKGroup.h"
#import "STKNavigationButton.h"
#import "HACreateGroupViewController.h"
#import "HAMessagesViewController.h"
#import "HAMessagesDirectViewController.h"

@interface HAMessagesGroupViewController ()<UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) STKUser *user;
@property (nonatomic, strong) STKOrganization *organization;
@property (nonatomic, strong) NSMutableArray *groups;
@property (nonatomic) BOOL userIsLeader;
@property (nonatomic) BOOL userIsOwner;
@property (nonatomic, strong) UIBarButtonItem *plusButton;

@property (nonatomic, strong) NSFetchedResultsController *frc;
@property (nonatomic, strong) NSIndexPath *selectedIndex;

@end

@implementation HAMessagesGroupViewController

- (id)init
{
    self = [super init];
    if (self) {
        [self.tabBarItem setTitle:@"Message"];
        [[self tabBarItem] setImage:[UIImage imageNamed:@"menu_message"]];
        [[self tabBarItem] setSelectedImage:[UIImage imageNamed:@"menu_message_selected"]];
        STKNavigationButton *view = [[STKNavigationButton alloc] init];
        [view addTarget:self action:@selector(createNewGroup:) forControlEvents:UIControlEventTouchUpInside];
        [view setOffset:9];
        
        [view setImage:[UIImage imageNamed:@"btn_addcontent"]];
        [view setHighlightedImage:[UIImage imageNamed:@"btn_addcontent_active"]];
        self.plusButton = [[UIBarButtonItem alloc] initWithCustomView:view];
        self.groups = [@[] mutableCopy];
        [self layoutViews];
        [self layoutConstraints];
    }
    return self;
}


#pragma mark View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self.tableView registerNib:[UINib nibWithNibName:[HAGroupCell reuseIdentifier] bundle:nil] forCellReuseIdentifier:[HAGroupCell reuseIdentifier]];
    [self.tableView setContentInset:UIEdgeInsetsMake(64.f, 0, 80.f, 0)];
    [self setTitle:@"Messages"];
    [self.navigationItem setLeftBarButtonItem:[self menuBarButtonItem]];
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshColor) name:@"UserDetailsUpdated" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTable) name:@"DidSwitchGroups" object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
//    [self.groups removeAllObjects];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (self.selectedIndex) {
        [self.tableView deselectRowAtIndexPath:self.selectedIndex animated:NO];
        self.selectedIndex = nil;
    }
    self.user = [[STKUserStore store] currentUser];


    if (self.user) {
        [self syncGroups];
    }
}

- (void)menuWillAppear:(BOOL)animated
{
    [self.groups removeAllObjects];
    [[self navigationItem] setRightBarButtonItem:[self switchGroupItem]];
}

- (void)menuWillDisappear:(BOOL)animated
{
    if ([self userIsLeader] || [self userIsOwner]) {
        [[self navigationItem] setRightBarButtonItem:[self plusButton]];
    } else {
        [[self navigationItem] setRightBarButtonItem:nil];
    }
//    [self.tableView reloadData];

}


#pragma mark Configuration
- (void)layoutViews
{
    self.tableView = [[UITableView alloc] init];
    [self.tableView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.tableView setBackgroundColor:[UIColor clearColor]];
    [self.tableView setDataSource:self];
    [self.tableView setDelegate:self];
    [self.view addSubview:self.tableView];
    [self addBackgroundImage];
    [self addBlurViewWithHeight:64.f];
}

- (void)layoutConstraints
{
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.tableView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeHeight multiplier:1.f constant:0.f]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.tableView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeWidth multiplier:1.f constant:0.f]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.tableView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeCenterY multiplier:1.f constant:0.f]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.tableView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeCenterX multiplier:1.f constant:0.f]];
}

#pragma mark Actors

- (void)createNewGroup:(id)sender
{
    HACreateGroupViewController *cgvc = [[HACreateGroupViewController alloc] init];
    [cgvc setOrganization:self.organization];
    [self.navigationController pushViewController:cgvc animated:YES];
}

#pragma mark Workers

- (void)editGroupAtIndexPath:(NSIndexPath *)ip
{
    NSIndexPath *ipx = [NSIndexPath indexPathForRow:ip.row - 1 inSection:ip.section - 1];
    STKGroup *group = [self.frc objectAtIndexPath:ipx];
    HACreateGroupViewController *cgvc = [[HACreateGroupViewController alloc] initWithGroup:group];
    [self.navigationController pushViewController:cgvc animated:YES];
}

- (void)deleteGroupAtIndexPath:(NSIndexPath *)ip
{
    NSIndexPath *ipx = [NSIndexPath indexPathForRow:ip.row - 1 inSection:ip.section - 1];
    STKGroup *group = [self.frc objectAtIndexPath:ipx];
    [[STKUserStore store] deleteGroup:group completion:^(id data, NSError *error) {
        if (error) {
            UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Uh oh..." message:@"This group could not be deleted. Please try again later." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [av show];
        } else {
            [self.groups removeObject:group];
//            [self.tableView deleteRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationAutomatic];
            [self.tableView endEditing:YES];
        }
    }];
}

- (void)refreshColor
{
    [self handleUserUpdate];
//    [self.tableView reloadData];
}

- (void)reloadTable
{
    self.organization = [[STKUserStore store] activeOrgForUser];
    NSError *err = nil;
    self.frc = [[STKUserStore store] groupsForCurrentUserInOrganization:self.organization];
    [self.frc setDelegate:self];
    [self.frc performFetch:&err];
    [self.tableView reloadData];
}

- (void)syncGroups
{
    if (! self.frc) {
        if ([self.user.type isEqualToString:STKUserTypeInstitution]) {
            self.frc = [[NSFetchedResultsController alloc] init];
            [[STKUserStore store] fetchUserOrgs:^(NSArray *organizations, NSError *err) {
                if (organizations) {
                    self.organization = [organizations objectAtIndex:0];
                    self.frc = [[STKUserStore store] groupsForCurrentUserInOrganization:self.organization];
                    [self.frc setDelegate:self];
                    NSError *err = nil;
                    [self.frc performFetch:&err];
                    [self.tableView reloadData];
                    [[STKUserStore store] fetchMembersForOrganization:self.organization completion:^(NSArray *messages, NSError *err) {
                        [[NSNotificationCenter defaultCenter] postNotificationName:@"DidUpdateMembers" object:nil];
                    }];
                }
            }];
        } else {
            self.organization = [[STKUserStore store] activeOrgForUser];
            self.frc = [[STKUserStore store] groupsForCurrentUserInOrganization:self.organization];
            [self.frc setDelegate:self];
            NSError *err = nil;
            [self.frc performFetch:&err];
            [[STKUserStore store] fetchMembersForOrganization:self.organization completion:^(NSArray *messages, NSError *err) {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"DidUpdateMembers" object:nil];
            }];
        }
    } else {
        [[STKUserStore store] fetchGroupsForOrganization:self.organization completion:^(NSArray *groups, NSError *err) {
            
        }];
        [[STKUserStore store] fetchMembersForOrganization:self.organization completion:^(NSArray *messages, NSError *err) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"DidUpdateMembers" object:nil];
        }];
    }
    
    
//    [gp enumerateObjectsUsingBlock:^(STKGroup *obj, NSUInteger idx, BOOL *stop) {
//        if ([obj name] && ![obj.name isEqualToString:@""]){
//            if (![self.groups containsObject:obj]) {
//                [self.groups addObject:obj];
//            }
//        }
//    }];
//    if ([self.user.type isEqualToString:@"institution_verified"]) {
//        [[STKUserStore store] fetchUserOrgs:^(NSArray *organizations, NSError *err) {
//            if (organizations) {
//                self.organization = [organizations objectAtIndex:0];
//                self.userIsOwner = YES;
//                NSArray *groups = [[self.organization.groups filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"status == %@", @"active"]] allObjects];
//                groups = [[groups sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]] mutableCopy];
//                __block BOOL changed = NO;
//                [groups enumerateObjectsUsingBlock:^(STKGroup *obj, NSUInteger idx, BOOL *stop) {
//                    if (![self.groups containsObject:obj]) {
//                        [self.groups addObject:obj];
//                        changed = YES;
//                    }
//                }];
//                [self.navigationItem setRightBarButtonItem:self.plusButton];
//                if (changed) {
//                    [self.groups sortUsingDescriptors:@[[[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES]]];
//                    [self.tableView reloadData];
//                }
//            }
//            [[STKUserStore store] fetchMembersForOrganization:self.organization completion:^(NSArray *messages, NSError *err) {
//                NSLog(@"Fetched users for future use");
//            }];
//        }];
//    } else if (self.user.organizations.count > 0) {
//        self.organization = [[STKUserStore store] activeOrgForUser];
//        self.userIsLeader = [[STKUserStore store] currentUserIsOrgLeader];
//        if (self.userIsLeader) {
//            [self.navigationItem setRightBarButtonItem:self.plusButton];
//        } else {
//            [self.navigationItem setRightBarButtonItem:nil];
//        }
//        
//        [[STKUserStore store] fetchUserDetails:self.user additionalFields:nil completion:^(STKUser *u, NSError *err) {
//            NSArray *groups = [[STKUserStore store] groupsForCurrentUser];
//            __block BOOL changed = NO;
//            [groups enumerateObjectsUsingBlock:^(STKGroup *obj, NSUInteger idx, BOOL *stop) {
//                if (![self.groups containsObject:obj]) {
//                    [self.groups addObject:obj];
//                    changed = YES;
//                }
//            }];
//            if (changed) {
//                [self.groups sortUsingDescriptors:@[[[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES]]];
//                [self.tableView reloadData];
//            }
//        }];
//        
//        //            [[STKUserStore store] fetchGroupsForOrganization:self.organization completion:^(NSArray *groups, NSError *err) {
//        //                self.groups = [[[status groups] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]] mutableCopy];
//        //                self.groups = [[self.groups filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"status == %@", @"active"]] mutableCopy];
//        //                [self.tableView reloadData];
//        //            }];
//        [[STKUserStore store] fetchMembersForOrganization:self.organization completion:^(NSArray *messages, NSError *err) {
//            NSLog(@"Fetched users for future use");
//        }];
//        
//    }
    
}

#pragma mark Cell Generation
- (UITableViewCell *)directMessageCell
{
    HAGroupCell *cell = [self.tableView dequeueReusableCellWithIdentifier:[HAGroupCell reuseIdentifier]];
    [cell.title setText:@"@direct"];
    double uc = [[NSUserDefaults standardUserDefaults] doubleForKey:HAUnreadMessagesForUserKey];
    [cell setMessageCount:[NSNumber numberWithDouble:uc]];
    return cell;
}

- (UITableViewCell *)groupCellAtIndex:(NSIndexPath *)ip
{
    HAGroupCell *cell = [self.tableView dequeueReusableCellWithIdentifier:[HAGroupCell reuseIdentifier]];
    if (ip.row == 0) {
        [cell.title setText:@"#all"];
        [cell setMessageCount:self.organization.unreadCount];
    } else {
        NSIndexPath *idx = [NSIndexPath indexPathForRow:(ip.row - 1) inSection:(ip.section - 1)];
        STKGroup *group = [self.frc objectAtIndexPath:idx];
        NSString *groupName = [group.name lowercaseString];
        [cell.title setText:[NSString stringWithFormat:@"#%@", groupName]];
        [cell setMessageCount:group.unreadCount];
    }
    
    return cell;
}

#pragma mark Table View Delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 48.f;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    STKGroup *group = nil;
    self.selectedIndex = indexPath;
    if (indexPath.section == 1) {
        if (indexPath.row > 0) {
            NSIndexPath *idx = [NSIndexPath indexPathForRow:(indexPath.row - 1) inSection:(indexPath.section - 1)];
            group = [self.frc objectAtIndexPath:idx];
        }
        HAMessagesViewController *mvc = [[HAMessagesViewController alloc] initWithOrganization:self.organization group:group];
        [self.navigationController pushViewController:mvc animated:YES];
    } else {
        HAMessagesDirectViewController *dbc = [[HAMessagesDirectViewController alloc] init];
        [dbc setUser:self.user];
        [dbc setOrganization:self.organization];
        [self.navigationController pushViewController:dbc animated:YES];
    }
    
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {

    if (indexPath.row == 0) {
        return NO;
    }
    if ([self.user.type isEqualToString:@"institution_verified"]) {
        return YES;
    } else if ([self.user.type isEqualToString:@"user"]) {
        __block BOOL canEdit = NO;
        [self.user.organizations enumerateObjectsUsingBlock:^(STKOrgStatus *obj, BOOL *stop) {
            if ([obj.organization.uniqueID isEqualToString:self.organization.uniqueID] && [obj.role isEqualToString:@"leader"]) {
                canEdit = YES;
                *stop = YES;
            }
        }];
        return canEdit;
    }
    return NO;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    
}

- (NSArray *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewRowAction *moreAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDefault title:@"      " handler:^(UITableViewRowAction *action, NSIndexPath *indexPath){
  
        [self editGroupAtIndexPath:indexPath];
    }];
    float width =[moreAction.title sizeWithAttributes:@{NSFontAttributeName:[UIFont fontWithName:@"Helvetica" size:15.0]}].width;
    width = width+40;
    float height = [self tableView:tableView heightForRowAtIndexPath:indexPath];
    UIImage *moreImage = [UIImage HAPatternImage:[UIImage imageNamed:@"edit_edit"] withHeight:height andWidth:width bgColor:[UIColor colorWithRed:142.f/255.f green:152.f/255.f blue:179.f/255.f alpha:1.f]];
    [moreAction setBackgroundColor:[UIColor colorWithPatternImage:moreImage]];
    
    
    UITableViewRowAction *deleteAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDefault title:@"      "  handler:^(UITableViewRowAction *action, NSIndexPath *indexPath){
        //        [self.objects removeObjectAtIndex:indexPath.row];
        
        [self deleteGroupAtIndexPath:indexPath];
        
    }];
    UIImage *deleteImage = [UIImage HAPatternImage:[UIImage imageNamed:@"edit_delete"] withHeight:height andWidth:width bgColor:[UIColor colorWithRed:221.f/255.f green:75.f/255.f blue:75.f/255.f alpha:1.f]];
    [deleteAction setBackgroundColor:[UIColor colorWithPatternImage:deleteImage]];
  
    return @[deleteAction, moreAction];
    
}


#pragma mark Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return 1;
    }
//    NSLog(@"Returning %u count for section 1", self.groups.count + 1);
    id sectionInfo = [self.frc.sections objectAtIndex:(section - 1)];
    NSUInteger count = [sectionInfo numberOfObjects];
    return count + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        return [self directMessageCell];
    } else {
        return [self groupCellAtIndex:indexPath];
    }
}

#pragma mark Fetched Results Controller Delegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    // The fetch controller is about to start sending change notifications, so prepare the table view for updates.
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath
{
    NSIndexPath *ip = [NSIndexPath indexPathForRow:(indexPath.row + 1) inSection:(indexPath.section + 1)];
    NSIndexPath *newIp = nil;
    if (newIndexPath) {
       newIp = [NSIndexPath indexPathForRow:(newIndexPath.row + 1) inSection:(newIndexPath.section + 1)];
    }
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertRowsAtIndexPaths:@[newIp] withRowAnimation:UITableViewRowAnimationTop];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationBottom];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self.tableView reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationNone];
            break;
            
        case NSFetchedResultsChangeMove:
            [self.tableView deleteRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationNone];
            [self.tableView insertRowsAtIndexPaths:@[newIp] withRowAnimation:UITableViewRowAnimationNone];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];
//    if (!self.initialLoadComplete) {
//        self.initialLoadComplete = YES;
//        [self scrollToBottom:NO];
//    }
//    if ([self pendingIndex]) {
//        [self.tableView reloadData];
//        [self.tableView scrollToRowAtIndexPath:self.pendingIndex atScrollPosition:UITableViewScrollPositionTop animated:NO];
//        self.pendingIndex = nil;
//    }
}

@end

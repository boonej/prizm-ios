//
//  UIViewController+STKControllerItems.m
//  Prism
//
//  Created by Joe Conway on 11/11/13.
//  Copyright (c) 2013 Higher Altitude. All rights reserved.
//

#import "UIViewController+STKControllerItems.h"
#import "STKCreatePostViewController.h"
#import "STKMenuController.h"
#import "STKNavigationButton.h"

@implementation UIViewController (STKMenuControllerExtensions)

- (STKMenuController *)menuController
{
    UIViewController *parent = [self parentViewController];
    while(parent != nil) {
        if([parent isKindOfClass:[STKMenuController class]])
            return (STKMenuController *)parent;
        
        parent = [parent parentViewController];
    }
    return nil;
}

- (void)menuWillAppear:(BOOL)animated
{
    for(UIViewController *vc in [self childViewControllers]) {
        [vc menuWillAppear:animated];
    }
}

- (void)menuWillDisappear:(BOOL)animated
{
    for(UIViewController *vc in [self childViewControllers]) {
        [vc menuWillDisappear:animated];
    }
}

- (UIBarButtonItem *)settingsBarButtonItem
{
    UIButton *view = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 40, 32)];
    [[view imageView] setContentMode:UIViewContentModeCenter];
    [view setContentHorizontalAlignment:UIControlContentHorizontalAlignmentRight];
//    [view setContentVerticalAlignment:UIControlContentVerticalAlignmentBottom];
    [[view imageView] setClipsToBounds:NO];
    [view setClipsToBounds:NO];
    [view addTarget:self action:@selector(showSettings:) forControlEvents:UIControlEventTouchUpInside];
    [view setImage:[UIImage imageNamed:@"btn_settings"] forState:UIControlStateNormal];
    UIBarButtonItem *bbi = [[UIBarButtonItem alloc] initWithCustomView:view];
    
    return bbi;
}

- (UIBarButtonItem *)searchBarButtonItem
{
    STKNavigationButton *view = [[STKNavigationButton alloc] init];
    [view setImage:[UIImage imageNamed:@"btn_search"]];
    [view setSelectedImage:[UIImage imageNamed:@"btn_search_selected"]];
    [view setOffset:8];

    [view addTarget:self action:@selector(initiateSearch:) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *bbi = [[UIBarButtonItem alloc] initWithCustomView:view];
    
    return bbi;
}

- (UIBarButtonItem *)postBarButtonItem
{
    STKNavigationButton *view = [[STKNavigationButton alloc] init];
    [view addTarget:self action:@selector(createNewPost:) forControlEvents:UIControlEventTouchUpInside];
    [view setOffset:8];

    [view setImage:[UIImage imageNamed:@"btn_addcontent"]];
    [view setSelectedImage:[UIImage imageNamed:@"btn_addcontent_active"]];
    UIBarButtonItem *bbi = [[UIBarButtonItem alloc] initWithCustomView:view];
    
    return bbi;
}

- (UIBarButtonItem *)menuBarButtonItem
{
    STKNavigationButton *view = [[STKNavigationButton alloc] init];
    [view addTarget:self action:@selector(toggleMenu:) forControlEvents:UIControlEventTouchUpInside];
    [view setImage:[UIImage imageNamed:@"btn_menu"]];
    [view setSelectedImage:[UIImage imageNamed:@"btn_menu_active"]];
    [view setOffset:-8];
    UIBarButtonItem *bbi = [[UIBarButtonItem alloc] initWithCustomView:view];
    
    
    return bbi;
}


- (void)createNewPost:(id)sender
{
    STKCreatePostViewController *cpc = [[STKCreatePostViewController alloc] init];
    UINavigationController *nvc = [[UINavigationController alloc] initWithRootViewController:cpc];
    [self presentViewController:nvc animated:YES completion:nil];
}

- (void)toggleMenu:(id)sender
{
    STKMenuController *tbc = (STKMenuController *)[self menuController];
    [tbc setMenuVisible:![tbc isMenuVisible] animated:YES];
}

- (void)initiateSearch:(id)sender
{
    
}

- (void)showSettings:(id)sender
{
    
}

@end

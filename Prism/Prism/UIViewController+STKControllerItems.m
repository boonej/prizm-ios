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
#import "STKUserStore.h"
#import "HAFastSwitchViewController.h"

@implementation UIViewController (STKMenuControllerExtensions)

- (UIBarButtonItem *)backButtonItem
{
    UIBarButtonItem *bbi = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btn_back"]
                                              landscapeImagePhone:nil style:UIBarButtonItemStylePlain
                                                           target:self action:@selector(back:)];
    return bbi;
}

- (void)back:(id)sender
{
    [[self navigationController] popViewControllerAnimated:YES];
}

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
    STKNavigationButton *view = [[STKNavigationButton alloc] init];
    [view setImage:[UIImage imageNamed:@"btn_settings"]];
    [view setHighlightedImage:[UIImage imageNamed:@"btn_settings"]];
    [view setOffset:8];
    
    [view addTarget:self action:@selector(showSettings:) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *bbi = [[UIBarButtonItem alloc] initWithCustomView:view];
    
    return bbi;
}


- (UIBarButtonItem *)postBarButtonItem
{
    STKNavigationButton *view = [[STKNavigationButton alloc] init];
    [view addTarget:self action:@selector(createNewPost:) forControlEvents:UIControlEventTouchUpInside];
    [view setOffset:9];

    [view setImage:[UIImage imageNamed:@"btn_addcontent"]];
    [view setHighlightedImage:[UIImage imageNamed:@"btn_addcontent_active"]];
    UIBarButtonItem *bbi = [[UIBarButtonItem alloc] initWithCustomView:view];
    
    return bbi;
}

- (UIBarButtonItem *)menuBarButtonItem
{
    STKNavigationButton *view = [[STKNavigationButton alloc] init];
    [view addTarget:self action:@selector(toggleMenu:) forControlEvents:UIControlEventTouchUpInside];
    
//    BOOL longPressExists = NO;
//    for (id obj in view.gestureRecognizers) {
//        if ([obj isKindOfClass:[UILongPressGestureRecognizer class]]) {
//            longPressExists = YES;
//        }
//    }
//    if (! longPressExists){
//        UIGestureRecognizer *longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(showFastSwitchMenu:)];
//        [view addGestureRecognizer:longPressRecognizer];
//    }
    
    [view setImage:[UIImage imageNamed:@"btn_menu"]];
    [view setHighlightedImage:[UIImage imageNamed:@"btn_menu_active"]];
    [view setOffset:-11];
    [view setBadgeable:YES];
    UIBarButtonItem *bbi = [[UIBarButtonItem alloc] initWithCustomView:view];
    
    
    return bbi;
}


- (void)createNewPost:(id)sender
{
    STKCreatePostViewController *cpc = [[STKCreatePostViewController alloc] init];
    UINavigationController *nvc = [[UINavigationController alloc] initWithRootViewController:cpc];
    [self presentViewController:nvc animated:YES completion:^{
        [[self menuController] setMenuVisible:NO];
    }];
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

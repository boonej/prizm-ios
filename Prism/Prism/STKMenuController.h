//
//  STKNavigationController.h
//  Prism
//
//  Created by Joe Conway on 11/6/13.
//  Copyright (c) 2013 Higher Altitude. All rights reserved.
//

#import <UIKit/UIKit.h>

@class STKPost;
@class STKInsightTarget;

@interface STKMenuController : UIViewController

@property (nonatomic, strong) UIImage *backgroundImage;

@property (nonatomic, copy) NSArray *viewControllers;
@property (nonatomic, strong) UIViewController *selectedViewController;
@property (nonatomic, getter = isMenuVisible) BOOL menuVisible;

@property (nonatomic, readonly) UIImage *transitioningImage;

- (UIViewController *)childViewControllerForType:(Class)cls;

- (void)setMenuVisible:(BOOL)menuVisible animated:(BOOL)animated;

// Pass image's rect in vc's view coordinate space
- (void)transitionToPost:(STKPost *)p
                fromRect:(CGRect)r
              usingImage:(UIImage *)image
        inViewController:(UIViewController *)vc
                animated:(BOOL)animated;

- (void)transitionToInsightTarget:(STKInsightTarget *)it
                         fromRect:(CGRect)r
                       usingImage:(UIImage *)image
                 inViewController:(UIViewController *)vc
                         animated:(BOOL)animated;

// Pass another applications image to create a new post, dismissing any present modal view
- (void)transitionToCreatePostWithImage:(UIImage *)image;
- (void)recreateAllViewControllers;
@end

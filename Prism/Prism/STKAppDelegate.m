//
//  STKAppDelegate.m
//  Prism
//
//  Created by Joe Conway on 11/6/13.
//  Copyright (c) 2013 Higher Altitude. All rights reserved.
//

#import "STKAppDelegate.h"
#import "STKMenuController.h"
#import "STKHomeViewController.h"
#import "STKExploreViewController.h"
#import "STKTrustViewController.h"
#import "STKProfileViewController.h"
#import "STKActivityViewController.h"
#import "STKGraphViewController.h"
#import "STKRegisterViewController.h"
#import "STKVerticalNavigationController.h"
#import "STKUserStore.h"

#import <GooglePlus/GooglePlus.h>

@interface STKAppDelegate ()

@end

@implementation STKAppDelegate 

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    
    [self configureAppearanceProxies];
    
    UIViewController *hvc = [[STKHomeViewController alloc] init];
    UIViewController *evc = [[STKExploreViewController alloc] init];
    UIViewController *tvc = [[STKTrustViewController alloc] init];
    UIViewController *pvc = [[STKProfileViewController alloc] init];
    UIViewController *avc = [[STKActivityViewController alloc] init];
    UIViewController *gvc = [[STKGraphViewController alloc] init];

    STKMenuController *nvc = [[STKMenuController alloc] init];
    [nvc setViewControllers:@[
        [[UINavigationController alloc] initWithRootViewController:hvc],
        [[UINavigationController alloc] initWithRootViewController:evc],
        [[UINavigationController alloc] initWithRootViewController:tvc],
        [[UINavigationController alloc] initWithRootViewController:pvc],
        [[UINavigationController alloc] initWithRootViewController:avc],
        [[UINavigationController alloc] initWithRootViewController:gvc]                              
    ]];
    [nvc setBackgroundImage:[UIImage imageNamed:@"img_background"]];
    
    for(UINavigationController *vc in [nvc viewControllers]) {
        [[vc navigationBar] setTranslucent:YES];
    }    
    
    [[self window] setRootViewController:nvc];

    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    
    
    if(![[STKUserStore store] currentUser]) {
        STKRegisterViewController *rvc = [[STKRegisterViewController alloc] init];
        STKVerticalNavigationController *registerNVC = [[STKVerticalNavigationController alloc] initWithRootViewController:rvc];
        
        [nvc presentViewController:registerNVC animated:NO completion:nil];
    }
    return YES;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    if([[url scheme] isEqualToString:[[NSBundle mainBundle] bundleIdentifier]])
        [[GPPSignIn sharedInstance] handleURL:url sourceApplication:sourceApplication annotation:annotation];
    return YES;
}


- (void)configureAppearanceProxies
{
    UIGraphicsBeginImageContext(CGSizeMake(10, 10));
    [[UIColor colorWithWhite:1 alpha:0.3] set];
    UIRectFill(CGRectMake(0, 0, 10, 10));
    
    [[UINavigationBar appearance] setBackgroundImage:UIGraphicsGetImageFromCurrentImageContext()
             forBarMetrics:UIBarMetricsDefault];
    [[UINavigationBar appearance] setShadowImage:[[UIImage alloc] init]];
    [[UIToolbar appearance] setBackgroundImage:UIGraphicsGetImageFromCurrentImageContext()
                            forToolbarPosition:UIBarPositionAny
                                    barMetrics:UIBarMetricsDefault];
    [[UIToolbar appearance] setShadowImage:[[UIImage alloc] init]
                        forToolbarPosition:UIBarPositionAny];
    UIGraphicsEndImageContext();

}

@end

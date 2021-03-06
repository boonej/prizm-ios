//
//  STKMarkupController.h
//  Prism
//
//  Created by Joe Conway on 5/2/14.
//  Copyright (c) 2014 Higher Altitude. All rights reserved.
//

#import <Foundation/Foundation.h>

@class STKMarkupController, STKUser, STKGroup, STKOrganization;

@protocol STKMarkupControllerDelegate <NSObject>

- (void)markupController:(STKMarkupController *)markupController
           didSelectUser:(STKUser *)user
        forMarkerAtRange:(NSRange)range;

- (void)markupController:(STKMarkupController *)markupController
        didSelectHashTag:(NSString *)hashTag
        forMarkerAtRange:(NSRange)range;

- (void)markupControllerDidFinish:(STKMarkupController *)markupController;

@end

@interface STKMarkupController : NSObject

- (id)initWithDelegate:(id <STKMarkupControllerDelegate>)delegate;

@property (nonatomic, weak) id <STKMarkupControllerDelegate> delegate;
@property (nonatomic, strong, readonly) UIView *view;
@property (nonatomic) BOOL hidesDoneButton;
@property (nonatomic) BOOL preventsUserTagging;
@property (nonatomic) BOOL allowsAllUserTagging;
@property (nonatomic, strong) STKOrganization *organization;
@property (nonatomic, strong) STKGroup *group;

- (void)textView:(UITextView *)textView updatedWithText:(NSString *)text;

- (void)displayAllUserResults;

@end

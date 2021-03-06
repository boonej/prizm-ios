//
//  STKImageSharer.m
//  Prism
//
//  Created by Joe Conway on 3/5/14.
//  Copyright (c) 2014 Higher Altitude. All rights reserved.
//


#import "STKImageSharer.h"
#import "STKPost.h"
#import "STKImageStore.h"
#import "STKContentStore.h"
#import "STKInsight.h"
#import <MobileCoreServices/MobileCoreServices.h>

NSString * const STKActivityTypeInstagram = @"STKActivityInstagram";
NSString * const STKActivityTypeTumblr = @"STKActivityTumblr";
NSString * const STKActivityTypeWhatsapp = @"STKActivityWhatsapp";
NSString * const HANotificationReportInappropriate = @"HANotificationReportInappropriate";

@class STKActivity;

@protocol STKActivityDelegate <NSObject>

- (void)activity:(STKActivity *)activity
wantsToPresentDocumentController:(UIDocumentInteractionController *)doc;


@end


@interface STKImageSharer () <STKActivityDelegate>

@end

@interface STKActivity : UIActivity

@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong) NSString *text;
@property (nonatomic, weak) id <STKActivityDelegate> delegate;

- (id)initWithDelegate:(id <STKActivityDelegate>)delegate;

@end

@interface HAItemSource:NSObject <UIActivityItemSource>

@property (nonatomic, strong) NSString * text;
@property (nonatomic, strong) UIImage * image;
@property (nonatomic, strong) STKPost *post;
@property (nonatomic, strong) STKInsight *insight;
@property (nonatomic, strong) NSString *baseText;

@end


@implementation HAItemSource

#pragma mark Activity Item Protocol
- (id)activityViewControllerPlaceholderItem:(UIActivityViewController *)activityViewController
{
    NSMutableDictionary *a = [NSMutableDictionary dictionary];
    if ([self image]) {
        [a setValue:self.image forKey:@"image"];
    }
    else if ([self text]) {
//        NSLog(@"Text is present in placeholder");
        [a setValue:self.text forKey:@"text"];
    } else return @"";
    
    return a;
}

- (id)activityViewController:(UIActivityViewController *)activityViewController itemForActivityType:(NSString *)activityType
{
//    NSLog(@"In the activity item");
    self.baseText = @"";
    if ([self post]) {
        NSMutableArray *textArr = [[self.post.text componentsSeparatedByString:@" "] mutableCopy];
        __block NSInteger i = 0;
        NSArray *hashTags = [self.post.tags allObjects];
        [textArr enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if ([(NSString *)obj rangeOfString:@"@"].location != NSNotFound) {
                if ([hashTags count] >= i + 1) {
                    STKUser *user = [hashTags objectAtIndex:i];
                    NSString *newObj = user.name;
                    ++i;
                    [textArr replaceObjectAtIndex:idx withObject:newObj];
                }
                
            }
        }];
        self.baseText = [textArr componentsJoinedByString:@" "];
    }
    
    if ([self insight]){
        NSMutableArray *textArr = [[self.insight.text componentsSeparatedByString:@" "] mutableCopy];
        __block NSInteger i = 0;
        NSArray *hashTags = [self.post.tags allObjects];
        [textArr enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if ([(NSString *)obj rangeOfString:@"@"].location != NSNotFound) {
                if ([hashTags count] >= i + 1) {
                    STKUser *user = [hashTags objectAtIndex:i];
                    NSString *newObj = user.name;
                    ++i;
                    [textArr replaceObjectAtIndex:idx withObject:newObj];
                }
                
            }
        }];
        self.baseText = [textArr componentsJoinedByString:@" "];
    }
    
    if ([activityType isEqualToString:UIActivityTypePostToTwitter]){
        return [self twitterItem];
    } else  if ([activityType isEqualToString:@"STKActivityReport"]) {
        return [self post];
    } else if ([activityType isEqualToString:UIActivityTypeCopyToPasteboard]) {
        return [self urlToCopy];
    } else if ([activityType isEqualToString:STKActivityTypeInstagram] || [activityType isEqualToString:STKActivityTypeWhatsapp]) {
        return [self customItem];
    } else if ([activityType isEqualToString:STKActivityTypeWhatsapp]) {
        return [self dictionaryItem];
    } else if ([activityType isEqualToString:UIActivityTypeSaveToCameraRoll]) {
        return [self dictionaryItem];
    } else if ([activityType isEqualToString:UIActivityTypeMessage] || [activityType isEqualToString:UIActivityTypeMail]) {
        return [self dictionaryItem];
    }
    else {
        return [self genericItem];
        
    }
    return nil;
}

- (NSDictionary *)dictionaryItem
{
    NSString *t = @"";
    NSString *link = @"https://www.prizmapp.com/download";
    if ([self post]) {
        if ([self.post text]){
            t = [NSString stringWithFormat:@"%@ %@", self.baseText, link];
        }
    }
    if ([self insight]) {
        t = [NSString stringWithFormat:@"%@ %@ %@", self.insight.text, [self.insight.linkURL absoluteString], link];
    }
    UIImage *image = nil;
    if (self.image) {
        image = self.image;
    }
    return @{@"text": t, @"image": image};
}

- (NSArray *)arrayItem
{
    NSString *t = @"";
    NSString *link = @"https://www.prizmapp.com/download";
    if ([self post]) {
        
        if ([self.post text]){
            t = [NSString stringWithFormat:@"%@ %@", self.baseText, link];
        }
    }
    if ([self insight]) {
        t = [NSString stringWithFormat:@"%@ %@ %@", self.insight.text, [self.insight.linkURL absoluteString], link];
    }
    return @[self.image, t];
}

//- (NSString *)activityViewController:(UIActivityViewController *)activityViewController
//              subjectForActivityType:(NSString *)activityType
//{
//    NSDictionary *obj = [self genericItem];
//    return [obj objectForKey:@"text"];
//}

- (id)customItem
{
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    NSString *link = @"https://www.prizmapp.com/download";
    if (self.image){
        [d setObject:self.image forKey:@"image"];
    }
    NSString *t = @"";
    if ([self post]) {
        t = [NSString stringWithFormat:@"https://prizmapp.com/posts/%@", self.post.uniqueID];
        if ([self.post text]){
            t = [NSString stringWithFormat:@"%@ @beprizmatic %@", self.baseText, t];
        }
    }
    
    if ([self insight]) {
        t = [NSString stringWithFormat:@"%@ %@ %@", self.insight.text, [self.insight.linkURL absoluteString], link];
    }
    [d setObject:t forKey:@"text"];
    return d;
}

- (id)twitterItem
{
    id obj = nil;
    NSString *t = @"";
//    NSString *link = @"https://www.prizmapp.com/download";
    if ([self post]) {
        t = [NSString stringWithFormat:@"https://prizmapp.com/posts/%@", self.post.uniqueID];
        if ([self.post text]){
            t = [NSString stringWithFormat:@"%@ @beprizmatic %@", self.baseText, t];
        }
        obj = t;
    }
    
    if ([self insight]) {
        return [self genericItem];
    }
    return obj;
}
    
- (id)genericItem
{
    NSString *t = @"";
    NSString *link = @"https://www.prizmapp.com/download";
    if ([self post]) {
        NSString *link = @"https://www.prizmapp.com/download";
        if ([self.post text]){
            t = [NSString stringWithFormat:@"%@ %@", self.baseText, link];
        }
    }
    if ([self insight]) {
        t = [NSString stringWithFormat:@"%@ %@ %@", self.insight.text, [self.insight.linkURL absoluteString], link];
    }
    NSExtensionItem *i = [[NSExtensionItem alloc] init];
    [i setAttributedContentText:[[NSAttributedString alloc] initWithString:t]];
    if (self.image) {
        NSArray *att = @[[[NSItemProvider alloc] initWithItem:UIImageJPEGRepresentation(self.image, 8.0f) typeIdentifier:(NSString *)kUTTypeJPEG]];
        [i setAttachments:att];
    }
    return i;
}

- (id)urlToCopy
{
    if (self.post) {
        NSString *url = [NSString stringWithFormat:@"https://www.prizmapp.com/posts/%@", [self.post uniqueID]];
        return [NSURL URLWithString:url];
    }
    return @"";
}

@end

@implementation STKActivity
- (id)initWithDelegate:(id <STKActivityDelegate>)delegate
{
    self = [super init];
    if(self) {
        [self setDelegate:delegate];
    }
    return self;
}
+ (UIActivityCategory)activityCategory
{
    return UIActivityCategoryShare;
}
/*
- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems
{
    for(id obj in activityItems) {
        if(!([obj isKindOfClass:[UIImage class]] || [obj isKindOfClass:[NSString class]])) {
            return NO;
        }
    }
    return YES;
}*/

@end

@interface STKActivityInstagram : STKActivity
@end
@implementation STKActivityInstagram

- (NSString *)activityType
{
    return STKActivityTypeInstagram;
}
- (NSString *)activityTitle
{
    return @"Instagram";
}
- (UIImage *)activityImage
{
    return [UIImage imageNamed:@"instagram"];
}

- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems
{
    for(id obj in activityItems) {
//        NSLog(@"Object: %@", [obj class]);
        if([obj isKindOfClass:[UIImage class]]) {
            [self setImage:obj];
        }
        if([obj isKindOfClass:[NSString class]]) {
            [self setText:obj];
        }
        if([obj isKindOfClass:[NSDictionary class]]) {
            [self setImage:[obj valueForKey:@"image"]];
            [self setText:[obj valueForKey:@"text"]];
        }
    }
    return [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"instagram://app"]];
}

- (void)prepareWithActivityItems:(NSArray *)activityItems
{
    for(id obj in activityItems) {
//        NSLog(@"Object: %@", [obj class]);
        if([obj isKindOfClass:[UIImage class]]) {
            [self setImage:obj];
        }
        if([obj isKindOfClass:[NSString class]]) {
            [self setText:obj];
        }
        if([obj isKindOfClass:[NSDictionary class]]) {
            [self setImage:[obj valueForKey:@"image"]];
            [self setText:[obj valueForKey:@"text"]];
        }
    }
}

- (void)performActivity
{
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"tmp.igo"];
    [UIImageJPEGRepresentation([self image], 1.0) writeToFile:tempPath atomically:YES];

    UIDocumentInteractionController *doc = [UIDocumentInteractionController interactionControllerWithURL:[NSURL fileURLWithPath:tempPath]];
    [doc setUTI:@"com.instagram.exclusivegram"];
    if ([self text]) {
        [doc setAnnotation:@{@"InstagramCaption" : [self text]}];
    }

    [[self delegate] activity:self wantsToPresentDocumentController:doc];
}

@end

@interface STKActivityTumblr : STKActivity
@end
@implementation STKActivityTumblr
- (NSString *)activityType
{
    return STKActivityTypeTumblr;
}
- (NSString *)activityTitle
{
    return @"Tumblr";
}
- (UIImage *)activityImage
{
    return [UIImage imageNamed:@"tumblr"];
}
- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems
{
    for(id obj in activityItems) {
//        NSLog(@"Object: %@", [obj class]);
        if([obj isKindOfClass:[UIImage class]]) {
            [self setImage:obj];
        }
        if([obj isKindOfClass:[NSString class]]) {
            [self setText:obj];
        }
        if([obj isKindOfClass:[NSDictionary class]]) {
            [self setImage:[obj valueForKey:@"image"]];
            [self setText:[obj valueForKey:@"text"]];
        }
    }
    return [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tumblr://"]];
}

- (void)prepareWithActivityItems:(NSArray *)activityItems
{
    for(id obj in activityItems) {
//        NSLog(@"Object: %@", [obj class]);
        if([obj isKindOfClass:[UIImage class]]) {
            [self setImage:obj];
        }
        if([obj isKindOfClass:[NSString class]]) {
            [self setText:obj];
        }
        if([obj isKindOfClass:[NSDictionary class]]) {
            [self setImage:[obj valueForKey:@"image"]];
            [self setText:[obj valueForKey:@"text"]];
        }
    }
}

- (void)performActivity
{
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"tmp.tumblrphoto"];
    [UIImageJPEGRepresentation([self image], 1.0) writeToFile:tempPath atomically:YES];
    
    UIDocumentInteractionController *doc = [UIDocumentInteractionController interactionControllerWithURL:[NSURL fileURLWithPath:tempPath]];
    [doc setUTI:@"com.tumblr.photo"];
    
    if([self text]) {
        [doc setAnnotation:@{@"TumblrCaption" : [self text]}];
    }
    
    [[self delegate] activity:self wantsToPresentDocumentController:doc];
}


@end

@interface STKActivityWhatsapp : STKActivity
@end
@implementation STKActivityWhatsapp
- (NSString *)activityType
{
    return STKActivityTypeWhatsapp;
}
- (NSString *)activityTitle
{
    return @"Whatsapp";
}
- (UIImage *)activityImage
{
    return [UIImage imageNamed:@"whatsapp"];
}
- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems
{
    for(id obj in activityItems) {
//        NSLog(@"Object: %@", [obj class]);
        if([obj isKindOfClass:[UIImage class]]) {
            [self setImage:obj];
        }
        if([obj isKindOfClass:[NSString class]]) {
            [self setText:obj];
        }
        if([obj isKindOfClass:[NSDictionary class]]) {
            [self setImage:[obj valueForKey:@"image"]];
            [self setText:[obj valueForKey:@"text"]];
        }
    }
    return [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"whatsapp://"]];
    
}

- (void)prepareWithActivityItems:(NSArray *)activityItems
{
    for(id obj in activityItems) {
//        NSLog(@"Object: %@", [obj class]);
        if([obj isKindOfClass:[UIImage class]]) {
            [self setImage:obj];
        }
        if([obj isKindOfClass:[NSString class]]) {
            [self setText:obj];
        }
        if([obj isKindOfClass:[NSDictionary class]]) {
            [self setImage:[obj valueForKey:@"image"]];
            [self setText:[obj valueForKey:@"text"]];
        }
    }
}

- (void)performActivity
{
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"tmp.wai"];
    [UIImageJPEGRepresentation([self image], 1.0) writeToFile:tempPath atomically:YES];
    
    UIDocumentInteractionController *doc = [UIDocumentInteractionController interactionControllerWithURL:[NSURL fileURLWithPath:tempPath]];
    [doc setUTI:@"net.whatsapp.image"];
    
    
    [[self delegate] activity:self wantsToPresentDocumentController:doc];
}


@end

@interface STKActivityReport : STKActivity
@property (nonatomic, strong) STKPost *currentPost;
@end
@implementation STKActivityReport
- (NSString *)activityType
{
    return @"STKActivityReport";
}
- (NSString *)activityTitle
{
    return @"Report as Inappropriate";
}
- (UIImage *)activityImage
{
    return [UIImage imageNamed:@"warning"];
}
+ (UIActivityCategory)activityCategory
{
    return UIActivityCategoryAction;
}

- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems
{
    for(id obj in activityItems) {
        if([obj isKindOfClass:[STKPost class]]) {
            [self setCurrentPost:(STKPost *)obj];
            self.image = [UIImage imageNamed:@"warning"];
        }
    }
    
    if(!_currentPost)
        return NO;

    return YES;
}

- (void)performActivity
{
    [[STKContentStore store] flagPost:_currentPost completion:^(STKPost *p, NSError *err) {
        if(err){
            //user must have already reported it -- need some sort of ui action?
            if ([err isConnectionError]) {
                [[STKErrorStore alertViewForError:err delegate:nil] show];
            }
        }
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Thank You" message:@"Thank you for your report. We will remove this photo if it violates our Community Guidelines." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alertView show];
        [[NSNotificationCenter defaultCenter] postNotificationName:HANotificationReportInappropriate object:nil];
        [self activityDidFinish:YES];
    }];
}

@end

@interface STKImageSharer () <UIDocumentInteractionControllerDelegate>
@property (nonatomic, strong) UIActivity *continuingActivity;
@property (nonatomic, strong) UIDocumentInteractionController *documentControllerRef;
@property (nonatomic, weak) STKPost *currentPost;
@property (nonatomic, strong) id currentObject;
@property (nonatomic, strong) void (^finishHandler)(UIDocumentInteractionController *);

@property (nonatomic, strong) UIViewController *viewController;
@end

@implementation STKImageSharer

+ (STKImageSharer *)defaultSharer
{
    static STKImageSharer *sharer = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharer = [[STKImageSharer alloc] init];
    });
    
    return sharer;
}

- (NSArray *)activitiesForImage:(UIImage *)image title:(NSString *)title viewController:(UIViewController *)viewController
{
    [self setViewController:viewController];
    
    NSMutableArray *a = [NSMutableArray array];
    if(image)
        [a addObject:image];
    if(title)
        [a addObject:[NSString stringWithFormat:@"%@ @beprizmatic", title]];
    else
        [a addObject:@"@beprizmatic"];
    
    NSArray *activities = @[[[STKActivityInstagram alloc] initWithDelegate:self],
                            [[STKActivityTumblr alloc] initWithDelegate:self],
                            [[STKActivityWhatsapp alloc] initWithDelegate:self]];
    NSMutableArray *mutableCopy = [activities mutableCopy];
    for (UIActivity *activity in activities) {
        if ([activity canPerformWithActivityItems:a] == NO) {
            [mutableCopy removeObject:activity];
        }
    }
    
    return mutableCopy;
}

- (UIActivityViewController *)activityViewControllerForPost:(STKPost *)post
                                              finishHandler:(void (^)(UIDocumentInteractionController *))block
{
    HAItemSource *is = [[HAItemSource alloc] init];
    UIImage *image = [[STKImageStore store] cachedImageForURLString:[post imageURLString]];
    NSString *text = [NSString stringWithFormat:@"%@ @beprizmatic %@", [post text], @"https://www.prizmapp.com/download"];
    [is setPost:post];
    [is setImage:image];
    [is setText: text];
    
    STKActivityReport *report = [[STKActivityReport alloc] initWithDelegate:self];
   
    report.currentPost = post;
    [self setFinishHandler:block];
    NSArray *activities = nil;
    if (SYSTEM_VERSION_LESS_THAN(@"8.0")) {
        activities = @[[[STKActivityInstagram alloc] initWithDelegate:self],
                             report,
                             [[STKActivityTumblr alloc] initWithDelegate:self],
                             [[STKActivityWhatsapp alloc] initWithDelegate:self]];;
    } else {
        activities = @[report];
    }
    
    NSArray *excludedActivities =  @[UIActivityTypeAssignToContact, UIActivityTypePrint, UIActivityTypeMail];;
    UIActivityViewController *controller = [[UIActivityViewController alloc] initWithActivityItems:@[is]
                                                                                         applicationActivities:activities];
    
  
    [controller setCompletionHandler:[self completionHandlerForActivity]];
    [controller.navigationController.navigationBar setTranslucent:NO];
    [controller setExcludedActivityTypes:excludedActivities];
    if (! controller) return nil;
    [self setViewController:controller];
    
    return controller;
}

- (UIActivityViewControllerCompletionHandler)completionHandlerForActivity
{
    __block UIColor *tintColor = [[UITextField appearance] tintColor];
    __block UIColor *tintB = [[UITextView appearance] tintColor];
    [[UITextField appearance] setTintColor:nil];
    [[UITextView appearance] setTintColor:nil];
    return ^(NSString *activityType, BOOL completed){
        [[UITextField appearance] setTintColor:tintColor];
        [[UITextView appearance] setTintColor:tintB];
        [self presentMessageAlertForActivityType:activityType completed:completed];
    };

}

- (UIActivityViewController *)activityViewControllerForInsight:(STKInsight *)insight finishHandler:(void (^)(UIDocumentInteractionController *))block
{
    HAItemSource *is = [[HAItemSource alloc] init];
    UIImage *image = [[STKImageStore store] cachedImageForURLString:[insight filePath]];
    NSString *text = [NSString stringWithFormat:@"%@ %@", [insight text], @"https://www.prizmapp.com/download"];
    [is setInsight:insight];
    [is setImage:image];
    [is setText: text];
    [self setFinishHandler:block];
    NSArray *activities = nil;
    if (SYSTEM_VERSION_LESS_THAN(@"8.0")) {
        activities = @[[[STKActivityInstagram alloc] initWithDelegate:self],
                       [[STKActivityTumblr alloc] initWithDelegate:self],
                       [[STKActivityWhatsapp alloc] initWithDelegate:self]];;
    } else {
        activities = @[];
    }
    
    NSArray *excludedActivities =  @[UIActivityTypeAssignToContact, UIActivityTypePrint, UIActivityTypeCopyToPasteboard, UIActivityTypeMail];;
    UIActivityViewController *controller = [[UIActivityViewController alloc] initWithActivityItems:@[is]
                                                                             applicationActivities:activities];
    [controller setCompletionHandler:[self completionHandlerForActivity]];
    [controller setExcludedActivityTypes:excludedActivities];
    if (! controller) return nil;
    [self setViewController:controller];
    
    return controller;
}

- (UIActivityViewController *)activityViewControllerForImage:(UIImage *)image object:(id)object
                                               finishHandler:(void (^)(UIDocumentInteractionController *))block
{
    if(!image) {
        return nil;
    }

    
    NSMutableArray *a = [NSMutableArray array];
    STKActivityReport *report = [[STKActivityReport alloc] initWithDelegate:self];
    if(image) {
        [a addObject:image];
    }
    if([object isKindOfClass:[STKPost class]]) {
        NSString *t =[NSString stringWithFormat:@"%@ @beprizmatic %@", [object valueForKey:@"text"], @"https://www.prizmapp.com/download"];
        [a addObject:t];
        report.currentPost = object;
    }
    else {
        NSString *t =[NSString stringWithFormat:@"%@ %@", [object valueForKey:@"text"], @"https://www.prizmapp.com/download"];
        [a addObject:t];
    }
    
    
    [self setFinishHandler:block];
    
    NSArray *activities =  @[];;
    
    
//    NSArray *activities =  @[[[STKActivityInstagram alloc] initWithDelegate:self],
//                             report,
//                             [[STKActivityTumblr alloc] initWithDelegate:self],
//                             [[STKActivityWhatsapp alloc] initWithDelegate:self]];;
    NSArray *excludedActivities = nil;
    if ([object isKindOfClass:[STKPost class]]){
        excludedActivities = @[UIActivityTypeAssignToContact, UIActivityTypePrint, UIActivityTypeCopyToPasteboard, UIActivityTypeMail];
    } else {
        excludedActivities = @[UIActivityTypeAssignToContact, UIActivityTypePrint, UIActivityTypeCopyToPasteboard];
    }
    
    
    
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:a
                                                                                         applicationActivities:activities];
    [activityViewController setExcludedActivityTypes:excludedActivities];
    if (![object isKindOfClass:[STKPost class]]) {
        [activityViewController setTitle:@"Look who's on Prizm!"];
    }
    

    // revert appearance proxies to get default iOS behavior when sharing through Messages
    
    [activityViewController setCompletionHandler:[self completionHandlerForActivity]];
    
    [self setViewController:activityViewController];
    
    return activityViewController;
}

- (void)presentMessageAlertForActivityType:(NSString *)activityType completed:(BOOL)completed
{
    if (activityType == UIActivityTypeSaveToCameraRoll) {
        NSString *message = nil;
        NSString *title = nil;
        if (completed) {
            title = @"Image Saved";
            message = @"The image has been saved \n to your camera roll.";
        } else {
            title = @"Error";
            message = @"The image could not be saved.";
        }
        UIAlertView *av = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [av show];
    }
}


- (void)activity:(STKActivity *)activity
wantsToPresentDocumentController:(UIDocumentInteractionController *)doc
{
    void (^completion)(void) = ^{
        [doc setDelegate:self];
        [self setContinuingActivity:activity];
        [self setDocumentControllerRef:doc];
    };
    
    // finish handler is provided when we want to dismiss the view asking to share
    if ([self finishHandler]) {
        [[self viewController] dismissViewControllerAnimated:YES completion:^{
            completion();
            if ([self finishHandler]) {
                [self finishHandler](doc);
            }

        }];
        return;
    }
    

    completion();
    [doc presentOpenInMenuFromRect:[[[self viewController] view] bounds]
                                inView:[[self viewController] view]
                              animated:YES];
    
}


- (void)documentInteractionController:(UIDocumentInteractionController *)controller didEndSendingToApplication:(NSString *)application
{
    [[self continuingActivity] activityDidFinish:YES];
    [self setContinuingActivity:nil];
    [self setDocumentControllerRef:nil];
}




@end




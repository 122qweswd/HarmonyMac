//
//  ViewController.m
//  IQTextInputViewNotification_ObjcExample
//
//  Created by Iftekhar on 8/7/24.
//  Copyright © 2024 CocoaPods. All rights reserved.
//

#import "ViewController.h"
#import <IQTextInputViewNotification/IQTextInputViewNotification-Swift.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    IQTextInputViewNotification *notification = [[IQTextInputViewNotification alloc] init];
    [notification subscribeWithIdentifier:@"ViewController" changeHandler:^(enum Event event, id<IQTextInputView> _Nonnull textInputView) {

    }];

    if ([notification isSubscribedWithIdentifier:@"ViewController"]) {
        [notification unsubscribeWithIdentifier:@"ViewController"];
    }

    [notification textInputView];
    [[notification textInputViewInfoObjc] textInputView];
    [[notification textInputViewInfoObjc] event];
}

@end

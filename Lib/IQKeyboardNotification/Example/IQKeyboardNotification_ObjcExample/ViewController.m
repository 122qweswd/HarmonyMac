//
//  ViewController.m
//  IQKeyboardNotification_ObjcExample
//
//  Created by Iftekhar on 8/6/24.
//  Copyright © 2024 CocoaPods. All rights reserved.
//

#import "ViewController.h"
#import <IQKeyboardNotification/IQKeyboardNotification-Swift.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    IQKeyboardNotification *keyboard = [[IQKeyboardNotification alloc] init];

    [keyboard subscribeWithIdentifier:@"ViewController" changeHandler:^(enum Event event, CGRect endFrame) {
    }];

    if ([keyboard isSubscribedWithIdentifier:@"ViewController"]) {
        [keyboard unsubscribeWithIdentifier:@"ViewController"];
    }

    [keyboard animateAlongsideTransition:^{
    } completion:^{
    }];

    NSLog(@"%ld",keyboard.keyboardInfoObjc.event);
    NSLog(@"%d",keyboard.keyboardInfoObjc.isLocal);
    NSLog(@"%@",NSStringFromCGRect(keyboard.keyboardInfoObjc.beginFrame));
    NSLog(@"%@",NSStringFromCGRect(keyboard.keyboardInfoObjc.endFrame));
    NSLog(@"%f",keyboard.keyboardInfoObjc.animationDuration);
    NSLog(@"%ld",keyboard.keyboardInfoObjc.animationCurve);
    NSLog(@"%ld",keyboard.keyboardInfoObjc.animationOptions);
    NSLog(@"%d",keyboard.keyboardInfoObjc.isVisible);
    NSLog(@"%d",keyboard.isVisible);
    NSLog(@"%@",NSStringFromCGRect(keyboard.frame));
}


@end

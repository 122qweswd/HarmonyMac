//
//  ViewController.m
//  IQTextView_ObjcExample
//
//  Created by Iftekhar on 8/8/24.
//  Copyright © 2024 CocoaPods. All rights reserved.
//

#import "ViewController.h"
#import <IQTextView/IQTextView-Swift.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    IQTextView *textView = [[IQTextView alloc] init];
    [textView placeholderLabel];
    [textView placeholderTextColor];
    [textView placeholder];
    [textView attributedPlaceholder];
    [textView text];
    [textView attributedText];
}


@end

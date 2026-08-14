//
//  ViewController.m
//  IQKeyboardToolbar_ObjcExample
//
//  Created by Iftekhar on 8/8/24.
//  Copyright © 2024 CocoaPods. All rights reserved.
//

#import "ViewController.h"
#import <IQKeyboardToolbar/IQKeyboardToolbar-Swift.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    IQKeyboardToolbar *toolbar = [[IQKeyboardToolbar alloc] init];
    toolbar.additionalLeadingItems = @[];
    toolbar.additionalTrailingItems = @[];

    NSLog(@"%@",toolbar.previousBarButton);
    NSLog(@"%@",toolbar.nextBarButton);
    NSLog(@"%@",toolbar.titleBarButton);
    NSLog(@"%@",toolbar.doneBarButton);
    NSLog(@"%@",toolbar.fixedSpaceBarButton);

    toolbar.doneBarButton.invocation = [[IQInvocation alloc] initWithTarget:self action:@selector(previousAction)];

    toolbar.titleBarButton.titleFont = [UIFont italicSystemFontOfSize:13];
    toolbar.titleBarButton.title = @"Something";
    toolbar.titleBarButton.titleColor = UIColor.systemGreenColor;
    toolbar.titleBarButton.selectableTitleColor = UIColor.systemBlueColor;

    IQKeyboardToolbarConfiguration *configuration = [[IQKeyboardToolbarConfiguration alloc] init];
    configuration.useTextInputViewTintColor = true;
    configuration.tintColor = UIColor.systemGreenColor;
    configuration.barTintColor = UIColor.systemBlueColor;
    configuration.previousNextDisplayMode = IQPreviousNextDisplayModeAlwaysShow;
    configuration.manageBehavior = IQKeyboardToolbarManageBehaviorByTag;

    IQBarButtonItemConfiguration *itemConfiguration = [[IQBarButtonItemConfiguration alloc] initWithTitle:@"Previous" action:@selector(previousAction)];
    configuration.previousBarButtonConfiguration = itemConfiguration;

    configuration.placeholderConfiguration.showPlaceholder = true;
    configuration.placeholderConfiguration.font = [UIFont italicSystemFontOfSize:15];
    configuration.placeholderConfiguration.color = UIColor.systemYellowColor;
    configuration.placeholderConfiguration.buttonColor = UIColor.systemCyanColor;

    UITextField *textField = [[UITextField alloc] init];
    NSLog(@"%@",textField.iq_toolbar);
    NSLog(@"%d",textField.iq_hidePlaceholder);
    NSLog(@"%@",textField.iq_placeholder);
    NSLog(@"%@",textField.iq_drawingPlaceholder);
    [textField iq_addToolbarWithTarget:self previousConfiguration:itemConfiguration nextConfiguration:itemConfiguration rightConfiguration:itemConfiguration title:@"Something" titleAccessibilityLabel:nil];
}

-(void)previousAction
{

}

@end

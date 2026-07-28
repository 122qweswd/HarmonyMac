//
//  DelegateManager.mm
//  MutualInfection
//
//  Created by apple on 2025/9/12.
//

#import "DelegateManager.h"

@implementation DelegateManager

+ (instancetype)shared {
    static DelegateManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}


@end

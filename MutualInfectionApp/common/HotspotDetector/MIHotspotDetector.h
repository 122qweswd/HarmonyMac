//
//  MIHotspotDetector.h
//  MutualInfectionApp
//
//  Created by tsbook on 2025/10/11.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MIHotspotDetector : NSObject

+ (instancetype)shared;

- (BOOL)isPersonalHotspotEnabled;

@end

NS_ASSUME_NONNULL_END

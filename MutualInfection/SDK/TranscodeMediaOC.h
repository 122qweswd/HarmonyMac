//
//  TransocdeMediaOC.h
//  MutualInfection
//
//  Created by mac on 2025/10/30.
//

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

typedef void (^LivePhotoCompletionBlock)(BOOL success);
@interface TranscodeMediaOC : NSObject

/// 获取单例实例
+ (instancetype)sharedInstance;

/**
 判断是否为HVC1格式
@param videoPath 输入视频文件路径
@param isSupported 判断结果
*/
- (BOOL)checkVideoCodecSupport:(NSString *)videoPath
                   isSupported:(BOOL *)isSupported;

/**
 将视频转换为 HVC1 (HEVC) 格式，确保 iOS 13+ 兼容性
 @param videoPath 输入视频文件路径
 @param outputPath 输出视频文件路径（HVC1 格式）
 @param completion 完成回调
    - success: 是否转换成功
    - errorMessage: 错误信息（失败时返回）
 */
- (void)convertToHVC1:(NSString *)videoPath
           outputPath:(NSString *)outputPath
           completion:(void(^)(BOOL success, NSString * _Nullable errorMessage))completion;

@end

NS_ASSUME_NONNULL_END

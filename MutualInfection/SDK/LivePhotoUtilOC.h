//
//  Untitled.h
//  MutualInfection
//
//  Created by mac on 2025/9/15.
//
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LivePhotoUtilOC : NSObject

+ (instancetype)sharedInstance;

/// 分离实况照片为静态图片和视频
/// @param livePhotoPath 实况照片路径
/// @param imagePath 输出静态图片路径
/// @param videoPath 输出视频路径
- (BOOL)splitLivePhoto:(NSString *)livePhotoPath
            imagePath:(NSString *)imagePath
            videoPath:(NSString *)videoPath;

// / 创建可播放的实况照片
// / @param imagePath 静态图片路径
// / @param videoPath 视频路径
// / @param livePhotoPath 输出实况照片路径
// / @param coverPosition 封面位置（时间戳）
- (BOOL)createPlayableLivePhotoWithImagePath:(NSString *)imagePath
                                   videoPath:(NSString *)videoPath
                               livePhotoPath:(NSString *)livePhotoPath;
- (BOOL) isLivePhoto:(NSString *)path;
@end

NS_ASSUME_NONNULL_END

//
//  LivePhotoUtilOC.mm
//  MutualInfection
//
//  Created by mac on 2025/9/15.
//
#import "LivePhotoUtilOC.h"
#import "LivePhotoUtil.h"

@implementation LivePhotoUtilOC

+ (instancetype)sharedInstance {
    static LivePhotoUtilOC *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[LivePhotoUtilOC alloc] init];
    });
    return instance;
}

- (BOOL)splitLivePhoto:(NSString *)livePhotoPath
            imagePath:(NSString *)imagePath
            videoPath:(NSString *)videoPath {
    
    std::string cppLivePhotoPath = [livePhotoPath UTF8String];
    std::string cppImagePath = [imagePath UTF8String];
    std::string cppVideoPath = [videoPath UTF8String];

    bool success = LivePhotoUtil::Instance().SplitLivePhoto(cppLivePhotoPath, cppImagePath, cppVideoPath);

    return success;
}

- (BOOL)createPlayableLivePhotoWithImagePath:(NSString *)imagePath
                                   videoPath:(NSString *)videoPath
                              livePhotoPath:(NSString *)livePhotoPath {
    
    std::string cppImagePath = [imagePath UTF8String];
    std::string cppVideoPath = [videoPath UTF8String];
    std::string cppLivePhotoPath = [livePhotoPath UTF8String];
    
    return LivePhotoUtil::Instance().CreatePlayableLivePhoto(cppImagePath,
                                                           cppVideoPath,
                                                           cppLivePhotoPath);
}

- (BOOL)isLivePhoto:(NSString *)path {
    std::string cppPath = [path UTF8String];
    return LivePhotoUtil::Instance().IsLivePhoto(cppPath);
}

@end

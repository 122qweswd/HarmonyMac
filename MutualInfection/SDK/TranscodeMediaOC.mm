//
//  TransocdeMediaOC.mm
//  MutualInfection
//
//  Created by mac on 2025/10/30.
//

#import "TranscodeMediaOC.h"
#import "TranscodeMedia.h"
#include <functional>
#include <thread>
#include <chrono>

@implementation TranscodeMediaOC

+ (instancetype)sharedInstance {
    static TranscodeMediaOC *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (BOOL)checkVideoCodecSupport:(NSString *)videoPath
                    isSupported:(BOOL *)isSupported{
    
    std::string path = [videoPath UTF8String];
    bool cppIsSupported = false;
    std::string cppReason;
    std::vector<std::string> cppAllCodecs; // 忽略这个输出
    
    // 调用 C++ 检测函数
    BOOL success = TranscodeMedia::Instance().checkVideoCodecSupport(path, cppIsSupported, cppReason, cppAllCodecs);
    
    if (!success) {
        return NO;
    }
    
    // 转换结果到 Objective-C
    *isSupported = cppIsSupported;
    return YES;
}

- (void)convertToHVC1:(NSString *)videoPath
           outputPath:(NSString *)outputPath
           completion:(void(^)(BOOL success, NSString * _Nullable errorMessage))completion {
    
    // 参数校验
    if (!completion) {
        NSLog(@"错误: completion 回调不能为空");
        return;
    }
    
    // 将 NSString 转换为 std::string
    std::string inputPath = [videoPath UTF8String];
    std::string outputPathStr = [outputPath UTF8String];
    
    // 启动异步线程执行任务
    std::thread([=]() {
        NSLog(@"开始异步转换 HVC1 格式...");
        
        bool success = false;
        NSString *errorMessage = nil;
        
        try {
            // 这里需要创建局部变量来接收可能的修改
            std::string localOutputPath = outputPathStr;
            
            // 使用信号量在异步线程内等待回调
            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
            
            // 使用堆分配的变量，避免lambda捕获问题
            bool *conversionSuccess = new bool(false);
            
            // 调用实际的 C++ 方法，传递回调函数
            TranscodeMedia::Instance().convertToHVC1(
                inputPath,
                localOutputPath,
                [conversionSuccess, semaphore](bool result) {
                    *conversionSuccess = result;
                    dispatch_semaphore_signal(semaphore);
                }
            );
            
            // 等待转换完成（设置超时时间）
            dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC);
            long waitResult = dispatch_semaphore_wait(semaphore, timeout);
            
            if (waitResult == 0) {
                success = *conversionSuccess;
                if (success) {
                    NSLog(@"✅ HVC1 转换完成！");
                    NSLog(@"输入视频路径: %s", inputPath.c_str());
                    NSLog(@"输出视频路径: %s", localOutputPath.c_str());
                } else {
                    errorMessage = @"HVC1 转换失败";
                    NSLog(@"❌ %@", errorMessage);
                }
            } else {
                errorMessage = @"HVC1 转换超时";
                NSLog(@"❌ %@", errorMessage);
                success = false;
            }
            
            // 释放堆内存
            delete conversionSuccess;
            
        } catch (const std::exception& e) {
            errorMessage = [NSString stringWithFormat:@"HVC1 转换异常: %s", e.what()];
            NSLog(@"❌ %@", errorMessage);
            success = false;
        } catch (...) {
            errorMessage = @"HVC1 转换未知异常";
            NSLog(@"❌ %@", errorMessage);
            success = false;
        }
        
        // 任务完成，回到主线程触发回调
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(success, errorMessage);
        });
        
    }).detach(); // 分离线程，不阻塞调用方
}
@end

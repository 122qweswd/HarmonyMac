//
//  TranscodeMedia.h
//  MutualInfectionApp
//
//  Created by mac on 2025/10/27.
//

#ifndef TranscodeMedia_h
#define TranscodeMedia_h

// 在包含 FFmpeg 头文件之前重定义
#define AVMediaType FFMAVMediaType

// 包含 FFmpeg 头文件
// 在函数开头添加这些包含语句
// 在函数开头添加这些包含语句
extern "C" {
    #include <libavformat/avformat.h>
    #include <libavcodec/avcodec.h>
    #include <libavutil/avutil.h>
    #include <libavutil/imgutils.h>
    #include <libswscale/swscale.h>
    #include <libavutil/opt.h>
    #include <libavutil/pixdesc.h>
}
// 取消定义
#undef AVMediaType

#include <string>
#include <iostream>
#include <filesystem>

#include <Foundation/Foundation.h>
#include <VideoToolbox/VideoToolbox.h>
#include <CoreMedia/CoreMedia.h>
#include <AVFoundation/AVFoundation.h>
#include <CoreFoundation/CoreFoundation.h>

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/avutil.h>

#include <sys/stat.h>  // 用于 stat 结构体
#include <unistd.h>    // 用于 access 函数
#include <cstring>     // 用于 strerror
#include <cstdio>      // 用于 FILE, fopen, fclose
#include <cmath>

enum VideoOrientation {
    ORIENTATION_PORTRAIT, // 竖屏
    ORIENTATION_LANDSCAPE //横屏
};

class TranscodeMedia{
public:
    TranscodeMedia();
    static TranscodeMedia &Instance();
    bool checkVideoCodecSupport(const std::string &videoPath, bool &isSupported, std::string &reason, std::vector<std::string> &allCodecs);
    void convertToHVC1(const std::string &videoPath, std::string &outputPath, std::function<void(bool)> completion);
     
private:
    void convertEntireVideoToHVC1(AVAsset* asset, NSURL* outputURL, std::function<void(bool)> completion);
    std::string generateOutputPath(const std::string& inputPath);
    AVURLAsset* createAssetSafely(NSString* path);
    VideoOrientation getVideoOrientation(const std::string& videoPath);
    void rotateVideoAfterConversion(NSURL *videoURL, std::function<void(bool)> completion);
};
#endif /* TranscodeMedia_h */

//
//  LivePhotoUtil.h
//  MutualInfection
//
//  Created by Law on 2025/9/14.
//

#ifndef LIVE_PHOTO_UTIL_H
#define LIVE_PHOTO_UTIL_H

#include <string>

// 实况照片标记
const std::string LIVE_TAG = "LIVE_";
const int32_t LIVE_TAG_LEN = 20;
const int32_t PLAY_INFO_LEN = 20;
const int32_t VERSION_TAG_LEN = 20;
const int32_t MIN_STANDARD_SIZE = LIVE_TAG_LEN + PLAY_INFO_LEN + VERSION_TAG_LEN;

class LivePhotoUtil
{
public:
    static LivePhotoUtil &Instance();
    bool SplitLivePhoto(std::string &livePhotoPath,
                        std::string &imagePath,
                        std::string &videoPath);
    bool CreatePlayableLivePhoto(std::string &imagePath,
                                 std::string &videoPath,
                                 std::string &livePhotoPath);
    bool IsLivePhoto(std::string &path);

private:
    LivePhotoUtil();
    off_t GetFileSize(int32_t fd);
    bool GetMovingPhotoDetailedSize(int32_t fd, int64_t &imageSize, int64_t &videoSize, int64_t &extraDataSize, uint32_t &coverFrame);
    bool WriteDataToFile(int fd, const char *data, size_t length);
    std::string GetVersionPositionTag(uint32_t frameIndex, bool hasExtraData);
    std::string GetDurationTag(uint32_t frameIndex, bool hasExtraData);
    std::string GetVideoInfoTag(off_t fileSize);
};
#endif // LIVE_PHOTO_UTIL_H
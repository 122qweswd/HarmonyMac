//
//  LivePhotoUtil.mm
//  MutualInfection
//
//  Created by Law on 2025/9/14.
//

#include "LivePhotoUtil.h"
#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <libgen.h>
#include <algorithm>

bool CreateDirectory(const std::string &filePath)
{
    // 复制路径字符串，因为dirname可能会修改输入字符串
    char *pathCopy = strdup(filePath.c_str());
    char *dir = dirname(pathCopy);
    
    // 获取目录字符串长度
    size_t len = strlen(dir);
    char *tempPath = (char*)malloc(len + 1);
    if (tempPath == nullptr) {
        free(pathCopy);
        return false;
    }
    
    // 逐级创建目录
    for (size_t i = 1; i < len; i++) {
        if (dir[i] == '/') {
            strncpy(tempPath, dir, i);
            tempPath[i] = 0;
            
            // 创建目录
            int result = mkdir(tempPath, S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH);
            if (result != 0 && errno != EEXIST) {
                free(tempPath);
                free(pathCopy);
                return false;
            }
        }
    }
    
    // 创建最终目录
    int result = mkdir(dir, S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH);
    if (result != 0 && errno != EEXIST) {
        free(tempPath);
        free(pathCopy);
        return false;
    }
    
    free(tempPath);
    free(pathCopy);

    // 检查目录是否确实存在
    struct stat st{};
    if (stat(dir, &st) == 0 && S_ISDIR(st.st_mode))
    {
        return true;
    }

    return false;
}

LivePhotoUtil::LivePhotoUtil() = default;

LivePhotoUtil &LivePhotoUtil::Instance()
{
    static LivePhotoUtil instance;
    return instance;
}

bool LivePhotoUtil::SplitLivePhoto(std::string &livePhotoPath, std::string &imagePath, std::string &videoPath)
{
    uint32_t coverFrame = 31;
    // 检查实况照片文件是否存在
    struct stat bufferStat{};
    if (stat(livePhotoPath.c_str(), &bufferStat) != 0)
    {
        std::cerr << "Live photo file does not exist: " << livePhotoPath << std::endl;
        return false;
    }

    // 检查是否为有效的实况照片
    if (!IsLivePhoto(livePhotoPath))
    {
        std::cerr << "File is not a valid live photo: " << livePhotoPath << std::endl;
        return false;
    }

    // 打开实况照片文件
    int livePhotoFd = open(livePhotoPath.c_str(), O_RDONLY);
    if (livePhotoFd < 0)
    {
        std::cerr << "Failed to open live photo file: " << livePhotoPath << ", errno: " << errno << std::endl;
        return false;
    }

    // 获取各部分大小信息和封面帧号
    int64_t imageSize = 0;
    int64_t videoSize = 0;
    int64_t extraDataSize = 0;
    int32_t result = GetMovingPhotoDetailedSize(livePhotoFd, imageSize, videoSize, extraDataSize, coverFrame);
    if (result != true)
    {
        std::cerr << "Failed to get detailed size of live photo" << std::endl;
        close(livePhotoFd);
        return result;
    }

    // 创建并写入图片文件
    if (!CreateDirectory(imagePath))
    {
        std::cerr << "Failed to create imagePath file directory: " << imagePath << ", errno: " << errno << std::endl;
        close(livePhotoFd);
        return false;
    }

    // 检查图片文件是否已存在
    if (access(imagePath.c_str(), F_OK) == 0)
    {
        // 如果文件已存在，尝试删除它
        if (unlink(imagePath.c_str()) != 0)
        {
            std::cerr << "Failed to remove existing image file: " << imagePath << ", errno: " << errno << " " << strerror(errno) << std::endl;
            close(livePhotoFd);
            return false;
        }
    }

    int imageFd = open(imagePath.c_str(), O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (imageFd < 0)
    {
        std::cerr << "Failed to create image file: " << imagePath << ", errno: " << errno << " " << strerror(errno) << std::endl;
        close(livePhotoFd);
        return false;
    }

    // 重置文件指针到开始位置
    if (lseek(livePhotoFd, 0, SEEK_SET) == -1)
    {
        std::cerr << "Failed to seek live photo file, errno: " << errno << std::endl;
        close(livePhotoFd);
        close(imageFd);
        unlink(imagePath.c_str()); // 删除已创建的文件
        return false;
    }

    // 复制图片数据
    const size_t BUFFER_SIZE = 16 * 1024;
    char *dataBuffer = new char[BUFFER_SIZE];
    int64_t remaining = imageSize;
    while (remaining > 0)
    {
        size_t toRead = (remaining > BUFFER_SIZE) ? BUFFER_SIZE : remaining;
        ssize_t bytesRead = read(livePhotoFd, dataBuffer, toRead);
        if (bytesRead <= 0)
        {
            std::cerr << "Failed to read from live photo file, errno: " << errno << std::endl;
            delete[] dataBuffer;
            close(livePhotoFd);
            close(imageFd);
            unlink(imagePath.c_str()); // 删除已创建的文件
            return false;
        }

        ssize_t bytesWritten = write(imageFd, dataBuffer, bytesRead);
        if (bytesWritten != bytesRead)
        {
            std::cerr << "Failed to write to image file, errno: " << errno << std::endl;
            delete[] dataBuffer;
            close(livePhotoFd);
            close(imageFd);
            unlink(imagePath.c_str()); // 删除已创建的文件
            return false;
        }

        remaining -= bytesRead;
    }

    close(imageFd);

    std::cerr << "write " << imagePath << " ok!" << std::endl;

    // 创建并写入视频文件
    if (!CreateDirectory(videoPath))
    {
        std::cerr << "Failed to create videoPath file directory: " << videoPath << ", errno: " << errno << std::endl;
        delete[] dataBuffer;
        close(livePhotoFd);
        unlink(imagePath.c_str()); // 删除已创建的图片文件
        return false;
    }

    // 检查视频文件是否已存在
    if (access(videoPath.c_str(), F_OK) == 0)
    {
        // 如果文件已存在，尝试删除它
        if (unlink(videoPath.c_str()) != 0 && errno != ENOENT)
        {
            std::cerr << "Failed to remove existing video file: " << videoPath << ", errno: " << errno << " " << strerror(errno) << std::endl;
            delete[] dataBuffer;
            close(livePhotoFd);
            unlink(imagePath.c_str()); // 删除已创建的图片文件
            return false;
        }
    }

    int videoFd = open(videoPath.c_str(), O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (videoFd < 0)
    {
        std::cerr << "Failed to create video file: " << videoPath << ", errno: " << errno << strerror(errno) << std::endl;
        delete[] dataBuffer;
        close(livePhotoFd);
        unlink(imagePath.c_str()); // 删除已创建的图片文件
        return false;
    }

    // 复制视频数据
    if (lseek(livePhotoFd, imageSize, SEEK_SET) == -1)
    {
        std::cerr << "Failed to seek video data in live photo file, errno: " << errno << std::endl;
        delete[] dataBuffer;
        close(livePhotoFd);
        close(videoFd);
        unlink(imagePath.c_str()); // 删除已创建的图片文件
        unlink(videoPath.c_str()); // 删除已创建的视频文件
        return false;
    }
    remaining = videoSize;
    while (remaining > 0)
    {
        size_t toRead = (remaining > BUFFER_SIZE) ? BUFFER_SIZE : remaining;
        ssize_t bytesRead = read(livePhotoFd, dataBuffer, toRead);
        if (bytesRead <= 0)
        {
            std::cerr << "Failed to read from live photo file, errno: " << errno << std::endl;
            delete[] dataBuffer;
            close(livePhotoFd);
            close(videoFd);
            unlink(imagePath.c_str()); // 删除已创建的图片文件
            unlink(videoPath.c_str()); // 删除已创建的视频文件
            return false;
        }

        ssize_t bytesWritten = write(videoFd, dataBuffer, bytesRead);
        if (bytesWritten != bytesRead)
        {
            std::cerr << "Failed to write to video file, errno: " << errno << std::endl;
            delete[] dataBuffer;
            close(livePhotoFd);
            close(videoFd);
            unlink(imagePath.c_str());
            unlink(videoPath.c_str());
            return false;
        }

        remaining -= bytesRead;
    }

    delete[] dataBuffer;
    close(livePhotoFd);
    close(videoFd);
    std::cerr << "write " << videoPath << " ok!" << std::endl;

    memset(&bufferStat, 0, sizeof(bufferStat));
    if (stat(imagePath.c_str(), &bufferStat) != 0)
    {
        std::cerr << "Live photo file does not exist: " << livePhotoPath << std::endl;
        return false;
    }

    std::cerr << "read " << imagePath << " size: " << bufferStat.st_size << std::endl;

    memset(&bufferStat, 0, sizeof(bufferStat));
    if (stat(videoPath.c_str(), &bufferStat) != 0)
    {
        std::cerr << "Live photo file does not exist: " << livePhotoPath << std::endl;
        return false;
    }

    std::cerr << "read " << videoPath << " size: " << bufferStat.st_size << std::endl;

    return true;
}

bool LivePhotoUtil::CreatePlayableLivePhoto(std::string &imagePath, std::string &videoPath,
                                            std::string &livePhotoPath)
{
    uint32_t frameIndex = 31;
    // 检查输入文件是否存在
    struct stat imageStat{},
        videoStat{};
    if (stat(imagePath.c_str(), &imageStat) != 0)
    {
        std::cerr << "Image file does not exist: " << imagePath << std::endl;
        return false;
    }

    if (stat(videoPath.c_str(), &videoStat) != 0)
    {
        std::cerr << "Video file does not exist: " << videoPath << std::endl;
        return false;
    }

    // 打开输入文件
    int imageFd = open(imagePath.c_str(), O_RDONLY);
    if (imageFd < 0)
    {
        std::cerr << "Failed to open image file: " << imagePath << ", errno: " << errno << std::endl;
        return false;
    }

    int videoFd = open(videoPath.c_str(), O_RDONLY);
    if (videoFd < 0)
    {
        std::cerr << "Failed to open video file: " << videoPath << ", errno: " << errno << std::endl;
        close(imageFd);
        return false;
    }

    // 创建输出文件
    int livePhotoFd = open(livePhotoPath.c_str(), O_WRONLY | O_CREAT | O_TRUNC, 0666);
    if (livePhotoFd < 0)
    {
        std::cerr << "Failed to create live photo file: " << livePhotoPath << ", errno: " << errno << std::endl;
        close(imageFd);
        close(videoFd);
        return false;
    }

    // 复制图片数据到实况照片文件
    const size_t BUFFER_SIZE = 16 * 1024;
    char *dataBuffer = new char[BUFFER_SIZE];

    // 复制图片数据
    off_t imageSize = imageStat.st_size;
    off_t remaining = imageSize;
    while (remaining > 0)
    {
        size_t toRead = (remaining > BUFFER_SIZE) ? BUFFER_SIZE : remaining;
        ssize_t bytesRead = read(imageFd, dataBuffer, toRead);
        if (bytesRead <= 0)
        {
            std::cerr << "Failed to read from image file, errno: " << errno << std::endl;
            delete[] dataBuffer;
            close(imageFd);
            close(videoFd);
            close(livePhotoFd);
            unlink(livePhotoPath.c_str());
            return false;
        }

        ssize_t bytesWritten = write(livePhotoFd, dataBuffer, bytesRead);
        if (bytesWritten != bytesRead)
        {
            std::cerr << "Failed to write to live photo file, errno: " << errno << std::endl;
            delete[] dataBuffer;
            close(imageFd);
            close(videoFd);
            close(livePhotoFd);
            unlink(livePhotoPath.c_str());
            return false;
        }

        remaining -= bytesRead;
    }

    // 复制视频数据
    off_t videoSize = videoStat.st_size;
    remaining = videoSize;
    while (remaining > 0)
    {
        size_t toRead = (remaining > BUFFER_SIZE) ? BUFFER_SIZE : remaining;
        ssize_t bytesRead = read(videoFd, dataBuffer, toRead);
        if (bytesRead <= 0)
        {
            std::cerr << "Failed to read from video file, errno: " << errno << std::endl;
            delete[] dataBuffer;
            close(imageFd);
            close(videoFd);
            close(livePhotoFd);
            unlink(livePhotoPath.c_str()); // 删除已创建的文件
            return false;
        }

        ssize_t bytesWritten = write(livePhotoFd, dataBuffer, bytesRead);
        if (bytesWritten != bytesRead)
        {
            std::cerr << "Failed to write to live photo file, errno: " << errno << std::endl;
            delete[] dataBuffer;
            close(imageFd);
            close(videoFd);
            close(livePhotoFd);
            unlink(livePhotoPath.c_str()); // 删除已创建的文件
            return false;
        }

        remaining -= bytesRead;
    }

    // 1. Version & Frame num (VERSION_TAG) - 倒数40~60字节，格式为"v6_fxx"
    std::string versionTag = GetVersionPositionTag(frameIndex, false); // 帧索引作为参数
    if (WriteDataToFile(livePhotoFd, versionTag.c_str(), versionTag.length()) != true)
    {
        delete[] dataBuffer;
        close(imageFd);
        close(videoFd);
        close(livePhotoFd);
        unlink(livePhotoPath.c_str());
        return false;
    }

    // 2. Sight tremble metadata (PLAY_INFO_TAG) - 倒数20~40字节
    std::string durationTag = GetDurationTag(frameIndex, false);
    if (WriteDataToFile(livePhotoFd, durationTag.c_str(), durationTag.length()) != true)
    {
        delete[] dataBuffer;
        close(imageFd);
        close(videoFd);
        close(livePhotoFd);
        unlink(livePhotoPath.c_str());
        return false;
    }

    // 3. Video info metadata (LIVE_TAG) - 倒数0~20字节
    std::string videoInfoTag = GetVideoInfoTag(videoSize + VERSION_TAG_LEN);
    if (WriteDataToFile(livePhotoFd, videoInfoTag.c_str(), videoInfoTag.length()) != true)
    {
        delete[] dataBuffer;
        close(imageFd);
        close(videoFd);
        close(livePhotoFd);
        unlink(livePhotoPath.c_str());
        return false;
    }

    delete[] dataBuffer;
    close(imageFd);
    close(videoFd);
    close(livePhotoFd);

    return true;
}

off_t LivePhotoUtil::GetFileSize(const int32_t fd)
{
    if (fd < 0)
    {
        std::cerr << "Invalid file descriptor" << std::endl;
        return -1;
    }
    struct stat st = {0};
    if (fstat(fd, &st) != 0)
    {
        std::cerr << "Failed to get file size, errno: " << errno << std::endl;
        return -1;
    }
    return st.st_size;
}

bool LivePhotoUtil::IsLivePhoto(std::string &path)
{
    struct stat bufferStat{};
    if (stat(path.c_str(), &bufferStat) != 0)
    {
        std::cerr << "File does not exist: " << path << std::endl;
        return false;
    }

    int fd = open(path.c_str(), O_RDONLY);
    if (fd < 0)
    {
        std::cerr << "Failed to open file: " << path << std::endl;
        return false;
    }

    off_t fileSize = GetFileSize(fd);
    if (fileSize < LIVE_TAG_LEN)
    {
        std::cerr << "File size is too small to be a live photo" << std::endl;
        close(fd);
        return false;
    }

    off_t offset = lseek(fd, -LIVE_TAG_LEN, SEEK_END);
    if (offset == -1)
    {
        std::cerr << "Failed to seek file, errno: " << errno << std::endl;
        close(fd);
        return false;
    }

    char bufferTag[LIVE_TAG_LEN + 1];
    ssize_t bytesRead = read(fd, bufferTag, LIVE_TAG_LEN);
    if (bytesRead == -1)
    {
        std::cerr << "Failed to read file, errno: " << errno << std::endl;
        close(fd);
        return false;
    }

    bufferTag[bytesRead] = '\0';
    close(fd);

    // 检查是否以LIVE_开头
    if (strncmp(bufferTag, LIVE_TAG.c_str(), LIVE_TAG.length()) == 0)
    {
        return true;
    }

    return false;
}

bool LivePhotoUtil::GetMovingPhotoDetailedSize(int32_t fd, int64_t &imageSize, int64_t &videoSize, int64_t &extraDataSize, uint32_t &coverFrame)
{
    if (fd < 0)
    {
        std::cerr << "Invalid file descriptor" << std::endl;
        return false;
    }

    struct stat st;
    if (fstat(fd, &st) != 0)
    {
        std::cerr << "Failed to get file state, errno: " << errno << std::endl;
        return false;
    }

    int64_t totalSize = st.st_size;
    if (totalSize <= MIN_STANDARD_SIZE)
    {
        std::cerr << "File size is too small to be a valid live photo" << std::endl;
        return false;
    }

    // 读取LIVE_标签 (Video info metadata)
    char liveTag[LIVE_TAG_LEN + 1] = {0};
    if (lseek(fd, -(LIVE_TAG_LEN), SEEK_END) == -1)
    {
        std::cerr << "Failed to seek live tag, errno: " << errno << std::endl;
        return false;
    }

    if (read(fd, liveTag, LIVE_TAG_LEN) == -1)
    {
        std::cerr << "Failed to read live tag, errno: " << errno << std::endl;
        return false;
    }

    // 检查是否以LIVE_开头
    if (strncmp(liveTag, LIVE_TAG.c_str(), LIVE_TAG.length()) != 0)
    {
        std::cerr << "File is not a valid live photo" << std::endl;
        return false;
    }

    // liveSize是从LIVE_标签中解析出来的数值
    int64_t liveSize = atoi(liveTag + LIVE_TAG.length());

    // imageSize = 总大小 - liveSize - LIVE_TAG_LEN - PLAY_INFO_LEN
    imageSize = totalSize - liveSize - LIVE_TAG_LEN - PLAY_INFO_LEN;

    // 读取播放信息标签 (PLAY_INFO_TAG)以获取封面帧号
    char playInfoTag[PLAY_INFO_LEN + 1] = {0};
    if (lseek(fd, -(LIVE_TAG_LEN + PLAY_INFO_LEN), SEEK_END) == -1)
    {
        std::cerr << "Failed to seek play info tag, errno: " << errno << std::endl;
        return false;
    }

    if (read(fd, playInfoTag, PLAY_INFO_LEN) == -1)
    {
        std::cerr << "Failed to read play info tag, errno: " << errno << std::endl;
        return false;
    }

    // 读取版本和帧号标签 (VERSION_TAG)
    char versionTag[VERSION_TAG_LEN + 1] = {0};
    if (lseek(fd, -(LIVE_TAG_LEN + PLAY_INFO_LEN + VERSION_TAG_LEN), SEEK_END) == -1)
    {
        std::cerr << "Failed to seek version tag, errno: " << errno << std::endl;
        return false;
    }

    if (read(fd, versionTag, VERSION_TAG_LEN) == -1)
    {
        std::cerr << "Failed to read version tag, errno: " << errno << std::endl;
        return false;
    }

    // 解析版本和帧号标签，提取封面帧号
    std::string versionStr(versionTag);
    size_t pos = versionStr.find("v6_f");
    bool hasCinemagraphInfo = false;

    if (pos != std::string::npos)
    {
        // 检查是否包含CinemaGraph数据 (_c后缀)
        if (versionStr.find("_c", pos) != std::string::npos)
        {
            hasCinemagraphInfo = true;
        }

        try
        {
            std::string frameStr = versionStr.substr(pos + 4); // "v6_f"之后的部分
            // 如果有_c后缀，需要截取到_c之前
            size_t cPos = frameStr.find("_c");
            if (cPos != std::string::npos)
            {
                frameStr = frameStr.substr(0, cPos);
            }

            // 去除可能的空格
            frameStr.erase(std::remove(frameStr.begin(), frameStr.end(), ' '), frameStr.end());
            if (!frameStr.empty())
            {
                coverFrame = static_cast<uint32_t>(std::stoi(frameStr));
            }
            else
            {
                coverFrame = 0; // 默认值
            }
        }
        catch (const std::exception &e)
        {
            std::cerr << "Failed to parse frame index from version tag: " << versionStr << ", error: " << e.what() << std::endl;
            coverFrame = 0; // 默认值
        }
    }
    else
    {
        // 尝试查找v3_f格式
        pos = versionStr.find("v3_f");
        if (pos != std::string::npos)
        {
            // 检查是否包含CinemaGraph数据 (_c后缀)
            if (versionStr.find("_c", pos) != std::string::npos)
            {
                hasCinemagraphInfo = true;
            }

            try
            {
                std::string frameStr = versionStr.substr(pos + 4); // "v3_f"之后的部分
                // 如果有_c后缀，需要截取到_c之前
                size_t cPos = frameStr.find("_c");
                if (cPos != std::string::npos)
                {
                    frameStr = frameStr.substr(0, cPos);
                }

                // 去除可能的空格
                frameStr.erase(std::remove(frameStr.begin(), frameStr.end(), ' '), frameStr.end());
                if (!frameStr.empty())
                {
                    coverFrame = static_cast<uint32_t>(std::stoi(frameStr));
                }
                else
                {
                    coverFrame = 0; // 默认值
                }
            }
            catch (const std::exception &e)
            {
                std::cerr << "Failed to parse frame index from version tag: " << versionStr << ", error: " << e.what() << std::endl;
                coverFrame = 0; // 默认值
            }
        }
        else
        {
            std::cerr << "Failed to find frame index in version tag: " << versionStr << std::endl;
            coverFrame = 0; // 默认值
        }
    }

    // 计算额外数据大小（包含所有元数据）
    if (hasCinemagraphInfo)
    {
        // 如果有CinemaGraph数据，需要从文件中读取CinemaGraph数据大小
        char cinemagraphSizeTag[4] = {0};
        if (lseek(fd, -(LIVE_TAG_LEN + PLAY_INFO_LEN + VERSION_TAG_LEN + 4), SEEK_END) != -1)
        {
            if (read(fd, cinemagraphSizeTag, 4) != -1)
            {
                std::stringstream cinemagraphSizeStream;
                for (int32_t i = 0; i < 4; i++)
                {
                    // 将每个字节转换为两位十六进制字符串
                    cinemagraphSizeStream << std::setfill('0') << std::setw(2) << std::hex << static_cast<int32_t>(static_cast<unsigned char>(cinemagraphSizeTag[i]));
                }

                try
                {
                    // 检查字符串长度，避免stoi溢出
                    std::string hexStr = cinemagraphSizeStream.str();
                    if (hexStr.length() <= 8)
                    { // 32位整数最多8个十六进制字符
                        uint32_t cinemagraphDataSize = std::stoul(hexStr, 0, 16);
                        extraDataSize = LIVE_TAG_LEN + PLAY_INFO_LEN + VERSION_TAG_LEN + cinemagraphDataSize;
                    }
                    else
                    {
                        std::cerr << "Cinemagraph data size hex string too long: " << hexStr << std::endl;
                        extraDataSize = LIVE_TAG_LEN + PLAY_INFO_LEN + VERSION_TAG_LEN;
                    }
                }
                catch (const std::exception &e)
                {
                    std::cerr << "Failed to parse cinemagraph data size, error: " << e.what() << std::endl;
                    extraDataSize = LIVE_TAG_LEN + PLAY_INFO_LEN + VERSION_TAG_LEN;
                }
            }
            else
            {
                extraDataSize = LIVE_TAG_LEN + PLAY_INFO_LEN + VERSION_TAG_LEN;
            }
        }
        else
        {
            extraDataSize = LIVE_TAG_LEN + PLAY_INFO_LEN + VERSION_TAG_LEN;
        }
    }
    else
    {
        extraDataSize = LIVE_TAG_LEN + PLAY_INFO_LEN + VERSION_TAG_LEN;
    }

    // 根据新格式重新计算视频大小
    // 总大小 = 图片数据 + 视频数据 + 额外元数据
    videoSize = totalSize - imageSize - extraDataSize;

    if (imageSize <= 0 || videoSize <= 0)
    {
        std::cerr << "Invalid image or video size" << std::endl;
        return false;
    }

    return true;
}

bool LivePhotoUtil::WriteDataToFile(int fd, const char *data, size_t length)
{
    ssize_t bytesWritten = write(fd, data, length);
    if (bytesWritten < 0 || static_cast<size_t>(bytesWritten) != length)
    {
        std::cerr << "Failed to write data to file, errno: " << errno << std::endl;
        return false;
    }
    return true;
}

std::string LivePhotoUtil::GetVersionPositionTag(uint32_t frameIndex, bool hasExtraData)
{
    std::string buffer;
    if (!hasExtraData)
    {
        // 根据新格式要求，使用v6版本格式
        buffer = "v6_f" + std::to_string(frameIndex);
    }
    else
    {
        // 如果有额外数据，保持空字符串
        return buffer;
    }

    // 填充空格至指定长度
    uint32_t left = VERSION_TAG_LEN - buffer.length();
    for (uint32_t i = 0; i < left; ++i)
    {
        buffer += ' ';
    }
    return buffer;
}

std::string LivePhotoUtil::GetDurationTag(uint32_t frameIndex, bool hasExtraData)
{
    // 将帧号转换为时间（毫秒）
    int64_t milliseconds = static_cast<int64_t>(frameIndex) * 100 / 3;

    std::string buffer;
    if (hasExtraData)
    {
        // 如果有额外数据，保持空字符串
        return buffer;
    }

    if (milliseconds < 600)
    {
        buffer = "0:" + std::to_string(milliseconds);
    }
    else
    {
        buffer = std::to_string(milliseconds - 600) + ":" + std::to_string(milliseconds);
    }

    // 填充空格至指定长度
    uint16_t left = PLAY_INFO_LEN - buffer.length();
    for (uint16_t i = 0; i < left; ++i)
    {
        buffer += ' ';
    }
    return buffer;
}

std::string LivePhotoUtil::GetVideoInfoTag(off_t fileSize)
{
    std::string buffer = "LIVE_" + std::to_string(fileSize);
    uint16_t left = LIVE_TAG_LEN - buffer.length();
    for (uint16_t i = 0; i < left; ++i)
    {
        buffer += ' ';
    }
    return buffer;
}

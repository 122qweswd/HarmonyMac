//
//  TransManager.h
//  MutualInfection
//
//  Created by apple on 2025/9/4.
//

#ifndef TRANS_MANAGER_H
#define TRANS_MANAGER_H

#include <map>
#include <string>
#include "DFile/nstackx_dfile.h"
#include "ShareSerializer.h"

typedef struct stTransFileInfo {
    std::string fileName;
    std::string fileUrl;
    uint64_t fileSize;
    std::string fileType;
    std::string date_added;
    std::string date_taken;
    int fd;
    bool isFinish;
    bool sended;
} TransFileInfo;

class TransManager
{
public:
    int32_t Start(const std::string &ip, uint16_t port, bool isServer, const std::vector<uint8_t> &dFileSessionKey, const FileShareInfo &shareInfo);
    bool IsStart();
    void Stop();
    void SendFiles(const std::multimap<std::string, TransFileInfo> &fileList, std::string sendType);
//    static std::string GetFileList(const DFileMsg *msg);

private:
    static void dfileCallback(int32_t sessionId, DFileMsgType msgType, const DFileMsg *msg);
    // static int handleFileOpt(int32_t sessionId, FileCallbackType type, const char *fileName, void *data, uint64_t len);
    static int handleFileOpt(int32_t sessionId, FileCallbackType type, const char *fileName, void *data, uint64_t len);

private:
    bool isServer { false };
    std::multimap<std::string, TransFileInfo> fileList;
    int32_t currentProgress { 0 };
    bool isFinished { false };
    int nextSendIndex { 0 };
    uint64_t recvSize { 0 };
    uint64_t totalSize { 0 };
    uint32_t fileCount { 0 };
};

#endif // TRANS_MANAGER_H

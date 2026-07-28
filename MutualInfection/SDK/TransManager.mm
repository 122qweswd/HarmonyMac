//
//  TransManager.mm
//  MutualInfection
//
//  Created by apple on 2025/9/4.
//

#include "TransManager.h"
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include "DFile/securec.h"
#include "DFile/nstackx_file_manager.h"
#include "Common.h"
#include "SocketManager.h"
#include <stdlib.h>
#include "LogHelper.h"
#include "ShareManager.h"
#include "json.hpp"

static std::map<int32_t, TransManager*> g_sessionList {};
static bool sendPreview = false;

//TransManager &TransManager::shared()
//{
//    static TransManager instance;
//    return instance;
//}
//
//TransManager::TransManager()
//{
//}

int TransManager::handleFileOpt(int32_t sessionId, FileCallbackType type, const char *fileName, void *data, uint64_t len)
{
    auto it = g_sessionList.find(sessionId);
    if (it == g_sessionList.end()) {
        return -1;
    }
    TransManager *thiz = it->second;
    switch (type) {
        case FILE_GET_STAT:
            {
                *(uint64_t*)data = 0;
                auto it = thiz->fileList.find(fileName);
                if (it != thiz->fileList.end()) {
                    struct stat sts;
                    if (stat(it->second.fileUrl.c_str(), &sts) == 0) {
                        it->second.fileSize = sts.st_size;
                    }
                    *(uint64_t *)data = it->second.fileSize;
                    return 0;
                }
            }
            break;
        case FILE_RECV_START:
            {
                std::string fileUrl = ShareManager::shared().OnFileTransStatus(RECV_FILE_START, fileName);
                if (!fileUrl.empty()) {
                    TransFileInfo info;
                    info.fileUrl = fileUrl;
                    info.fd = open(fileUrl.c_str(), O_WRONLY | O_CREAT, 0644);
                    info.fileSize = 0;
                    info.isFinish = false;
                    info.sended = false;
                    if (info.fd >= 0) {
                        thiz->fileList.emplace(fileName, info);
                    } else {
                        LOG_ERROR_S("fail to open file: %s", fileUrl.c_str());
                    }
                    return info.fd;
                }
                return -1;
            }
            break;
        case FILE_RECV_DATA:
        {
            auto range = thiz->fileList.equal_range(fileName);
            for (auto it = range.first; it != range.second; it++) {
                if (it->second.fd >= 0) {
                    it->second.fileSize += len;
                    break;
                }
            }
        }
            break;

        case FILE_RECV_END:
            {
                auto range = thiz->fileList.equal_range(fileName);
                for (auto it = range.first; it != range.second; it++) {
                    if (it->second.fd >= 0) {
                        it->second.isFinish = true;
                        it->second.fd = -1;
                        ShareManager::shared().OnFileTransStatus(RECV_FILE_END, fileName, it->second.fileSize);
                        break;
                    }
                }
            }
            break;
            
        case FILE_SEND_START:
            {
                auto it = thiz->fileList.find(fileName);
                if (it != thiz->fileList.end()) {
                    it->second.fd = open(it->second.fileUrl.c_str(), O_RDONLY);
                    if (it->second.fd >= 0) {
                        ShareManager::shared().OnFileTransStatus(SEND_FILE_START, fileName);
                    } else {
                        int errCode = ERROR_TRANS_SELF_ERROR + 2000;
                        int open_errno = errno;
                        LOG_ERROR_S("fail to open file: %s, errno: %d", it->second.fileUrl.c_str(), open_errno);
                        if (it->second.fileUrl == "") {
                            LOG_ERROR_S("fileUrl is empty for fileName: %s", fileName);
                            ShareManager::shared().SendShareEvent(SHARE_ERROR_TRANS_SELF, ERROR_TRANS_SELF_OPEN_FILEURL_EMPTY);
                        } else {
                            errCode += open_errno;
                            std::string errUrl = it->second.fileUrl;
                            ShareManager::shared().SetErrorFileUrl(errUrl);
                            ShareManager::shared().SendShareEvent(SHARE_ERROR_TRANS_SELF, errCode);
                        }
                    }
                    return it->second.fd;
                }
            }
            break;
        case FILE_SEND_DATA:
            break;

        case FILE_SEND_END:
            {
                auto it = thiz->fileList.find(fileName);
                if (it != thiz->fileList.end()) {
                    it->second.fd = -1;
                    it->second.isFinish = true;
                    ShareManager::shared().OnFileTransStatus(SEND_FILE_END, fileName);
                }
            }
            break;
        default:
            break;
    }
    return 0;
}

int32_t TransManager::Start(const std::string &ip, uint16_t port, bool isServer,
                         const std::vector<uint8_t> &dFileSessionKey, const FileShareInfo &shareInfo)
{
    int32_t sessionId = -1;
    struct sockaddr_in localAddr;
    memset_s(&localAddr, sizeof(struct sockaddr_in), 0, sizeof(struct sockaddr_in));
    localAddr.sin_family = AF_INET;
    localAddr.sin_port = port;
    if (isServer) {
        localAddr.sin_addr.s_addr = INADDR_ANY;
    } else {
        uint32_t inetAddr = inet_addr(ip.c_str());
        localAddr.sin_addr.s_addr = NTOHL(inetAddr);
    }
    
    std::string anoIP = AnonymizeIP(ip);
    LOG_DEBUG_S("ip: %s, port: %d", anoIP.c_str(), port);
    socklen_t addrLen = sizeof(struct sockaddr_in);
    if (isServer) {
        sessionId = NSTACKX_DFileServer(&localAddr, addrLen, dFileSessionKey.data(),
                                        static_cast<uint32_t>(dFileSessionKey.size()), dfileCallback);

    } else {
        sessionId = NSTACKX_DFileClient(&localAddr, addrLen, dFileSessionKey.data(),
                                        static_cast<uint32_t>(dFileSessionKey.size()), dfileCallback);
    }
    fileCount = strtod(shareInfo.itemCount.c_str(), nullptr);
    if (shareInfo.sendType == "3" || shareInfo.sendType == "4") {
        fileCount = strtod(shareInfo.fileCount.c_str(), nullptr);
    }
    if (shareInfo.sendType == "0") {
        sendPreview = true;
    } else {
        sendPreview = false;
    }
    totalSize = strtoull(shareInfo.totalSize.c_str(), nullptr, 10);
    fileList.clear();
    NSTACKX_DFileSetCallback(sessionId, TransManager::handleFileOpt);
    isFinished = false;
    currentProgress = 0;
    recvSize = 0;
    this->isServer = isServer;
    std::string anoLocalIP = AnonymizeIP(ip);
    LOG_DEBUG_S("current localIP: %s, port: %d, sessionId: %d", anoLocalIP.c_str(), port, sessionId);
    if (sessionId >= 0) {
        g_sessionList.emplace(sessionId, this);
    }
    return sessionId;
}

bool TransManager::IsStart()
{
    return g_sessionList.size() > 0;
}

void TransManager::Stop()
{
    for (auto it = g_sessionList.begin(); it != g_sessionList.end();) {
        if (it->second == this) {
            NSTACKX_DFileClose(it->first);
            it = g_sessionList.erase(it);
        } else {
            ++it;
        }
    }
}

void TransManager::SendFiles(const std::multimap<std::string, TransFileInfo> &files, std::string sendType)
{
    if (g_sessionList.empty()) {
        return;
    }
    fileList.clear();
    fileList = files;
    int sendSize = static_cast<int>(fileList.size());
    nextSendIndex = sendSize;
    if (sendSize > 500) {
        sendSize = 100;
        nextSendIndex = 100;
    } else if ((sendType == "3" || sendType == "4") && sendSize > 100) {
        sendSize = 100;
        nextSendIndex = 100;
    }
    std::vector<TransFileInfo> preview;
    char **sendFiles = new char* [sendSize];
    int index = 0;
    for (auto &item : fileList) {
        sendFiles[index++] = (char*)item.first.c_str();
        item.second.fileName = item.first;
        preview.emplace_back(item.second);
        if (index >= nextSendIndex) {
            break;
        }
    }
    
    int32_t sessionId = g_sessionList.begin()->first;
    if (sendPreview) {
        ShareManager::shared().SendFilePreview(preview);
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(200 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        NSTACKX_DFileSendFiles(sessionId, (const char **)sendFiles, sendSize, nullptr);
    });
}

void TransManager::dfileCallback(int32_t sessionId, DFileMsgType msgType, const DFileMsg *msg)
{
    auto it = g_sessionList.find(sessionId);
    if (it == g_sessionList.end()) {
        return;
    }
    TransManager *thiz = it->second;
    int errorCode = ERROR_TRANS_SELF_ERROR + 1000;
    switch (msgType) {
        case DFILE_ON_CONNECT_SUCCESS:
            LOG_DEBUG_S("receive DFILE_ON_CONNECT_SUCCESS");
            ShareManager::shared().OnTransStatus(TRANS_CONNECTED, msg);
            if (thiz->currentProgress == 0) {
                thiz->currentProgress = 1;
            }
            break;
        case DFILE_ON_CONNECT_FAIL:
            errorCode += msg->errorCode;
            ShareManager::shared().SendShareEvent(SHARE_ERROR_TRANS_SELF, errorCode);
            LOG_DEBUG_S("receive DFILE_ON_CONNECT_FAIL");
            break;
        case DFILE_ON_FILE_LIST_RECEIVED:
            LOG_DEBUG_S("receive DFILE_ON_FILE_LIST_RECEIVED");
            ShareManager::shared().OnTransStatus(TRANS_RECV_FILE_LIST, msg);
            if (thiz->currentProgress == 0) {
                thiz->currentProgress = 1;
            }
            break;

        case DFILE_ON_FILE_RECEIVE_SUCCESS:
            if (thiz->fileCount == static_cast<uint32_t>(thiz->fileList.size())) {
                LOG_DEBUG_S("receive DFILE_ON_FILE_RECEIVE_SUCCESS");
                ShareManager::shared().SendShareEvent(SHARE_SUCCESS, SUCCESS);
                thiz->isFinished = true;
            } else {
                LOG_DEBUG_S("receive DFILE_ON_FILE_RECEIVE_SUCCESS of next segment: %zu", thiz->fileList.size());
                thiz->recvSize += msg->transferUpdate.totalBytes;
            }
            break;

        case DFILE_ON_FILE_RECEIVE_FAIL:
            if (!thiz->isFinished) {
                errorCode += msg->errorCode;
                ShareManager::shared().SendShareEvent(SHARE_ERROR_TRANS_SELF, errorCode);
                LOG_DEBUG_S("receive DFILE_ON_FILE_RECEIVE_FAIL");
            }
            break;

        case DFILE_ON_FILE_SEND_SUCCESS:
            if (thiz->nextSendIndex == thiz->fileList.size()) {
                LOG_DEBUG_S("receive DFILE_ON_FILE_SEND_SUCCESS");
                ShareManager::shared().SendShareEvent(SHARE_SUCCESS, SUCCESS);
                thiz->isFinished = true;
            } else {
                LOG_DEBUG_S("receive DFILE_ON_FILE_SEND_SUCCESS of next segement: %d", thiz->nextSendIndex);
                int startIndex = thiz->nextSendIndex;
                int sendSize = static_cast<int>(thiz->fileList.size()) - thiz->nextSendIndex;
                if (sendSize > 100) {
                    sendSize = 100;
                }

                char **sendFiles = new char* [sendSize];
                int index = 0;
                auto it = thiz->fileList.begin();
                std::advance(it, thiz->nextSendIndex);
                std::vector<TransFileInfo> preview;
                while (it != thiz->fileList.end()) {
                    sendFiles[index++] = (char*)it->first.c_str();
                    it->second.fileName = it->first;
                    preview.emplace_back(it->second);
                    if (index >= sendSize) {
                        break;
                    }
                    it++;
                }
                thiz->nextSendIndex += sendSize;
                LOG_DEBUG_S("send size = %d", thiz->nextSendIndex);
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (sendPreview) {
                        ShareManager::shared().SendFilePreview(preview);
                    }
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(200 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                        NSTACKX_DFileSendFiles(sessionId, (const char **)sendFiles, sendSize, nullptr);
                    });
                });
            }
            break;

        case DFILE_ON_FILE_SEND_FAIL:
            if (!thiz->isFinished) {
                errorCode += msg->errorCode;
                ShareManager::shared().SendShareEvent(SHARE_ERROR_TRANS_SELF, errorCode);
                LOG_DEBUG_S("receive DFILE_ON_FILE_SEND_FAIL");
            }
            break;

        case DFILE_ON_FATAL_ERROR:
            if (!thiz->isFinished) {
                errorCode += msg->errorCode;
                ShareManager::shared().SendShareEvent(SHARE_ERROR_TRANS_SELF, errorCode);
                LOG_DEBUG_S("receive DFILE_ON_FATAL_ERROR");
            }
            break;

        case DFILE_ON_SESSION_IN_PROGRESS:
            LOG_DEBUG_S("receive DFILE_ON_SESSION_IN_PROGRESS");
            break;

        case DFILE_ON_TRANS_IN_PROGRESS:
            {
                uint64_t bytesTransferred = thiz->recvSize + msg->transferUpdate.bytesTransferred;
                if (bytesTransferred * 100 >= thiz->currentProgress * thiz->totalSize) {
                    LOG_DEBUG_S("receive DFILE_ON_TRANS_IN_PROGRESS: %d", thiz->currentProgress);
                    ShareManager::shared().OnSharePercent(bytesTransferred * 100.0 / thiz->totalSize, msg, thiz->fileList, bytesTransferred);
                    thiz->currentProgress++;
                }
            }
            break;
        case DFILE_ON_SESSION_TRANSFER_RATE:
            {
                LOG_DEBUG_S("receive DFILE_ON_SESSION_TRANSFER_RATE");
                ShareManager::shared().SetShareRate(msg->rate);
            }
            break;
        case DFILE_ON_BIND:
            LOG_DEBUG_S("receive DFILE_ON_BIND");
            break;
        case DFILE_ON_CLEAR_POLICY_FILE_LIST:
            LOG_DEBUG_S("receive DFILE_ON_CLEAR_POLICY_FILE_LIST");
            break;
        default:
            break;
    }
}

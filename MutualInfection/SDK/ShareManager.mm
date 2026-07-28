////
////  Share.mm
////  MutualInfection
////
////  Created by apple on 2025/9/4.
////
//
#include "ShareManager.h"

#include <openssl/rand.h>
#include <chrono>
#include <stdlib.h>
#include <atomic>
#include <Foundation/Foundation.h>
#include <sys/utsname.h>

#include "COAPDiscSerializer.hpp"
#include "Common.h"
#include "LogHelper.h"
#include "ShareSerializer.h"
#include "ShareHelper.h"
#include "TcpChannel.h"
#include "json.hpp"

#import "MIHotspotDetector.h"

#include <fstream>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#elif TARGET_OS_MAC
#import <AppKit/AppKit.h>
#endif

#define TIMEOUT_MS_UNIT         1000
#define FULL_CONNECT_TIMEOUT    (90 * 1000)
#define JOIN_WIFI_TIMEOUT       (30 * 1000)
#define MI_GET_IP_TIMEOUT       (200)
#define MI_GET_IP_MAX_COUNT     (100)

static std::atomic<bool> isProgressUpdatePending{false};
static int16_t g_SessionId = 0;

ShareManager &ShareManager::shared()
{
    static ShareManager instance;
    return instance;
}

ShareManager::ShareManager()
{
    // TODO:
//    memset(&authChannel, 0, sizeof(authChannel));
}

bool ShareManager::Initialize()
{
    authMgr = std::make_shared<AuthManager>();
    if (authMgr == nullptr) {
        return false;
    }
    std::vector<uint8_t> hash;
    authMgr->GetDeviceHash(hash, HASH_KEY_LEN >> 1);
    hostDeviceHash = byte2hexstr(hash.data(), hash.size(), true);

    connectMgr = std::make_shared<ConnectManager>();
    if (connectMgr == nullptr) {
        return false;
    }
    
    networkMgr = [NetworkManager shared];
    if (networkMgr == nil) {
        return false;
    }
    [networkMgr StartNetworkMonitor];
    
    delegateMgr = [DelegateManager shared];
    if (delegateMgr == nil) {
        return false;
    }

//    deviceMgr = std::make_shared<DeviceManager>();
//    if (deviceMgr == nullptr) {
//        return false;
//    }
    
    transMgr = std::make_shared<TransManager>();
    if (transMgr == nullptr) {
        return false;
    }
    
    timerQueue.start();
    isInit = true;
    return isInit;
}

void ShareManager::Finalize()
{
    if (isInit) {
        timerQueue.stop();
        transMgr.reset();
//        deviceMgr.reset();
        authMgr.reset();
        connectMgr.reset();
        isInit = false;
    }
}

int16_t ShareManager::ShareFiles(const std::string &udid, ShareNode &node)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    if (!isInit) {
        LOG_ERROR_S("not yet init");
        return -1;
    }
    
    MIHotspotDetector *hotspot = [MIHotspotDetector shared];
    if (hotspot.isPersonalHotspotEnabled) {
        LOG_ERROR_S("Hotspot is enable");
        return -1;
    }
    
    if (state >= SHARE_AUTHCHANNEL_OPENED && !isSender) {
        LOG_ERROR_S("support multiply sender only");
        return -1;
    }

    uint64_t deviceId = strtoull(udid.c_str(), nullptr, 16);
    if (!DeviceManager::shared().hasDevice(deviceId) && !DeviceManager::shared().hasCoapDevice(deviceId)) {
        LOG_ERROR_S("invalid device: %s", udid.c_str());
        return -1;
    }

    int16_t sessionId = g_SessionId++;
    if (g_SessionId < 0) {
        g_SessionId = 0;
        sessionId = 0;
    }

    node.emplace("udid", udid);
    shareList.emplace(sessionId, node);
    sessionList.push(sessionId);
    if (state == SHARE_IDLE && shareList.size() == 1 && sendCheckTimer == -1) {
        bool isHighSpeed = false;
        if (node.find("highSpeed") != node.end()) {
            isHighSpeed = true;
        }
        connectMgr->ShareFiles(udid, isHighSpeed);
        if (currentSSID != "") {
            savedLastSSID = currentSSID;
        }
        currentShareNode.clear();
        sessionId = sessionList.front();
        currentShareNode = shareList.at(sessionId);
        LOG_DEBUG_S("set share node");
        sessionList.pop();
        shareList.erase(sessionId);
        DeviceManager::shared().SetShareDevice(udid);
    }
    return sessionId;
}

void ShareManager::TraverseFolder(NSURL *folderURL, std::multimap<std::string, TransFileInfo> &fileList, const TransFileInfo &parentFolderInfo, const std::string &basePath)
{
    NSArray *directoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:folderURL.path error:nil];

    for (NSString *item in directoryContents) {
        NSString *itemPath = [folderURL.path stringByAppendingPathComponent:item];
        NSURL *itemURL = [NSURL fileURLWithPath:itemPath];

        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:itemPath error:nil];
        if ([attrs[NSFileType] isEqualToString:NSFileTypeDirectory]) {

            std::string newBasePath = basePath.empty() ? std::string([item UTF8String]) : (basePath + "/" + std::string([item UTF8String]));
            TraverseFolder(itemURL, fileList, parentFolderInfo, newBasePath);
        } else {

            TransFileInfo fileInfo;
            fileInfo.fileName = basePath.empty() ? std::string([item UTF8String]) : (basePath + "/" + std::string([item UTF8String]));
            fileInfo.fileUrl = std::string([itemPath UTF8String]);
            fileInfo.fileSize = [attrs[NSFileSize] unsignedLongLongValue];

            auto fileName = fileInfo.fileName;
            fileName = GetNewFileName(fileName, fileList);
            fileList.emplace(fileName, fileInfo);
        }
    }
}

// 按字节数截断字符串，确保不破坏多字节字符
std::string ShareManager::truncateStringByBytes(const std::string &str, size_t maxBytes)
{
    size_t byteLength = 0;
    size_t charIndex = 0;
    while (charIndex < str.size() && byteLength < maxBytes) {
        // 检查当前字符是否为多字节字符（UTF-8编码）
        unsigned char c = static_cast<unsigned char>(str[charIndex]);
        if (c < 0x80) {
            // 单字节字符
            byteLength += 1;
            charIndex += 1;
        } else if (c < 0xE0) {
            // 双字节字符
            if (byteLength + 2 <= maxBytes) {
                byteLength += 2;
                charIndex += 2;
            } else {
                break;
            }
        } else if (c < 0xF0) {
            // 三字节字符（如中文）
            if (byteLength + 3 <= maxBytes) {
                byteLength += 3;
                charIndex += 3;
            } else {
                break;
            }
        } else {
            // 四字节字符
            if (byteLength + 4 <= maxBytes) {
                byteLength += 4;
                charIndex += 4;
            } else {
                break;
            }
        }
    }
    
    if (charIndex < str.size()) {
        return str.substr(0, charIndex);
    }
    return str;
}

std::string ShareManager::GetNewFileName(const std::string &fileName, const std::multimap<std::string, TransFileInfo> &fileList)
{
    std::string originalFileName = fileName;
    size_t prefixPos = originalFileName.find_last_of('.');
    if (prefixPos == std::string::npos) {//防止无后缀
        prefixPos = originalFileName.length();
    }
    std::string preName = originalFileName.substr(0, prefixPos);
    std::string suffix = originalFileName.substr(prefixPos);

    int index = 0;
    bool conflict = false;
    std::string newFileName;
    
    do {
        conflict = false;

        // 构建当前文件名
        std::string currentPreName = preName;
        if (index > 0) {//只有重名才会命名，如A(1).jpg,不存在a(0).jpg的情况
            currentPreName = preName + "(" + std::to_string(index) + ")";
        }
        
        // 检查文件名长度，若超过255字节则截断
        size_t maxTotalLength = 255;
        size_t suffixLength = suffix.size();
        size_t maxPreNameLength = maxTotalLength - suffixLength;
        
        // 确保前缀长度不小于0
        if (suffixLength > maxTotalLength) {
            maxPreNameLength = 0;
        }
        
        // 按字节数截断，确保不破坏多字节字符
        currentPreName = truncateStringByBytes(currentPreName, maxPreNameLength);
        
        newFileName = currentPreName + suffix;

        // 检查是否与现有文件名冲突
        if (fileList.find(newFileName) != fileList.end()) {
            conflict = true;
        } else {
            // 检查是否与现有文件的基础名称冲突
            for (const auto& pair : fileList) {
                const std::string& existingFileName = pair.first;
                size_t existingPrefixPos = existingFileName.find_last_of('.');
                std::string existingBaseName = (existingPrefixPos != std::string::npos) ?
                                              existingFileName.substr(0, existingPrefixPos) :
                                              existingFileName;

                if (currentPreName == existingBaseName) {
                    conflict = true;
                    break;
                }
            }
        }

        if (conflict) {
            index++;
        }
    } while (conflict);

    return newFileName;
}

void ShareManager::SendFiles(const std::string &udid, std::vector<TransFileInfo> files)
{
    std::multimap<std::string, TransFileInfo> fileList;
    for (auto &file : files) {
        if (file.fileType == "public.folder") {
            NSURL *folderURL = [NSURL fileURLWithPath:[NSString stringWithUTF8String:file.fileUrl.c_str()]];
            TraverseFolder(folderURL, fileList, file, file.fileName);
        } else {
            auto fileName = file.fileName;
            fileName = GetNewFileName(fileName, fileList);
            fileList.emplace(fileName, file);
        }
    }
    LOG_DEBUG_S("SendFiles Start: udid:%s", udid.c_str());
    transMgr->SendFiles(fileList, shareInfo.sendType);
}

void ShareManager::CancelSender(const std::string &udid)
{
    sharingUdid = udid;
    OnShareCancel(true);
}

void ShareManager::CancelReceiver(const std::string &udid)
{
    sharingUdid = udid;
    OnShareCancel(true);
}

void ShareManager::AcceptRequest(const std::string &udid)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    if (sharingUdid != udid) {
        LOG_ERROR_S("NOT Match!!! Sharing: %s, caller: %s", sharingUdid.c_str(), udid.c_str());
        return;
    }
    std::vector<uint8_t> request;
    BuildMetaPayload(0, request);
    connectMgr->SendData(udid, request);
}

void ShareManager::OnShareReject(bool isSelf)
{
    if (isSelf) {
        std::lock_guard<std::recursive_mutex> lock(mutex);
        std::vector<uint8_t> request;
        BuildMetaPayload(1, request);
        connectMgr->SendData(sharingUdid, request);
        OnShareComplete(sharingUdid, SHARE_REJECT_SELF, REJECT_SELF);
    } else {
        OnShareComplete(sharingUdid, SHARE_REJECT_PEER, REJECT_PEER);
    }
}

void ShareManager::OnShareCancel(bool isSelf)
{
    if (isSelf) {
        std::vector<uint8_t> payload;
        bool isCancel;
        if (isSender) {
            BuildMetaPayload(2, payload);
        } else {
            BuildMetaPayload(4, payload);
        }
        if (transMgr->IsStart()) {
            connectMgr->SendByteData(isSender, payload);
        } else {
            connectMgr->SendData(sharingUdid, payload);
        }

        if (cancelTimer >= 0) {
            timerQueue.cancelTask(cancelTimer);
        }
        if (state < SHARE_COMPLETING) {
            SetShareState(SHARE_COMPLETING);
            cancelTimer = timerQueue.addTask(1000, 1, CancelShareTimeout);
            LOG_DEBUG_S("cancelTimer: %d", cancelTimer);
            isCancel = true;
        } else {
            LOG_DEBUG_S("share has been completed, ignore canncel");
            isCancel = false;
        }
        if ([delegateMgr.transDelegate respondsToSelector:@selector(didIsCancel:)]) {
            [delegateMgr.transDelegate didIsCancel:isCancel];
        }

    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            OnShareComplete(sharingUdid, SHARE_CANCEL_PEER, CANCEL_PEER_CANCEL_INPROGRESS);
        });
        
    }
}
void ShareManager::OnShareCancelSelf(const std::string &udid)
{
    NSString *udidString = [NSString stringWithUTF8String:sharingUdid.c_str()];
    if ([delegateMgr.connectDelegate respondsToSelector:@selector(didDisconnect:reason:errorCode:)]) {
        [delegateMgr.connectDelegate didDisconnect:udidString reason:@"peer_busy" errorCode:0];
    }
}

void ShareManager::OnShareStart(const std::string &channelId, const std::string &udid)
{
//    int taskId = timerQueue.addTask(FULL_CONNECT_TIMEOUT, 1, ShareTimeout);
    if (udid.empty()) {
        LOG_ERROR_S("wrong channel id: %s", channelId.c_str());
        return;
    }
    if (timerTaskList.find(udid) == timerTaskList.end() && timerUdid == "") {
        shareStartTime = GetCurrentTime();
        lastSSID = currentSSID;
        SetShareState(SHARE_STARTED);
        timerUdid = udid;
        int taskId = timerQueue.addTask(FULL_CONNECT_TIMEOUT, 1, ShareTimeout);
        LOG_DEBUG_S("start share timeout timer[%s]: %d", udid.c_str(), taskId);
        timerTaskList.emplace(udid, taskId);
    }
}

//void ShareManager::HandlePostComplete()
//{
//    if (state == SHARE_JOIN_WIFI) {
//        SetShareState(SHARE_CONNECTED);
//        OnShareComplete(sharingUdid, savedResult, 0);
//        savedResult = SHARE_RESULT_BUTT;
//    }
//}

void ShareManager::OnShareComplete(const std::string &udid, ShareResult result, int errCode)
{
    LOG_DEBUG_S("Complete [%s] result: %d, current status: %d", udid.c_str(), result, state);

    if (udid != "emulate" && (!isInit || state <= SHARE_IDLE)) {
        return;
    }

    if (result == SHARE_BLE_TIMEOUT || result == SHARE_BLE_LTK) {
        sharingUdid = udid;
        isSender = true;
    }

    if (sharingUdid != udid && udid != "emulate") {
        LOG_ERROR_S("NOT Match!!! Sharing: %s, caller: %s", sharingUdid.c_str(), udid.c_str());
        return;
    }
    
    auto it = timerTaskList.find(sharingUdid);
    if (it != timerTaskList.end()) {
        LOG_DEBUG_S("stop share timeout timer: %s %d", sharingUdid.c_str(), it->second);
        timerQueue.cancelTask(it->second);
        timerTaskList.erase(it);
    }
    
//    if (connectWifiTimer >= 0) {
//        timerQueue.cancelTask(connectWifiTimer);
//        connectWifiTimer = -1;
//    }
    
    if (disconnectWifiTimer >= 0) {
        timerQueue.cancelTask(disconnectWifiTimer);
        disconnectWifiTimer = -1;
    }
    
    if (disconnectCheckTimer >= 0) {
        timerQueue.cancelTask(disconnectCheckTimer);
        disconnectCheckTimer = -1;
    }
    
    if (getIPTimer >= 0) {
        timerQueue.cancelTask(getIPTimer);
        getIPTimer = -1;
    }
    
    if (sendPercentTimer >= 0) {
        timerQueue.cancelTask(sendPercentTimer);
        sendPercentTimer = -1;
    }
    
    if (keepAliveTimer >= 0) {
        timerQueue.cancelTask(keepAliveTimer);
        keepAliveTimer = -1;
    }
    
//    if (state == SHARE_JOIN_WIFI && result != SHARE_SUCCESS && result != SHARE_CANCEL_PEER && result != SHARE_CANCEL_SELF) {
//        LOG_DEBUG_S("ignore complete result, network dialog not dismiss");
//        if (savedResult == SHARE_RESULT_BUTT) {
//            savedResult = result;
//            LOG_DEBUG_S("saved complete result: %d", savedResult);
//        }
//        return;
//    }
    
    if (state == SHARE_COMPLETING && result != SHARE_SUCCESS && result != SHARE_CANCEL_SELF) {
        LOG_DEBUG_S("complete will be handled soon, ignore other error");
        return;
    }
    
    if (cancelTimer >= 0) {
        timerQueue.cancelTask(cancelTimer);
        cancelTimer = -1;
    }
    if (shareSuccessTimer >= 0) {
        timerQueue.cancelTask(shareSuccessTimer);
        shareSuccessTimer = -1;
    }
    
    NSString *udidString = [NSString stringWithUTF8String:sharingUdid.c_str()];
    switch (result) {
        case SHARE_SUCCESS:
            if (isSender) {
                if ([delegateMgr.transDelegate respondsToSelector:@selector(didSendEnd:file:isFinished:)]) {
                    [delegateMgr.transDelegate didSendEnd:udidString file:@"" isFinished:true];
                }
            } else {
                UpdateProgress();
                if ([delegateMgr.transDelegate respondsToSelector:@selector(didRecvEnd:file:isFinished:fileSize:)]) {
                    [delegateMgr.transDelegate didRecvEnd:udidString file:@"" isFinished:true fileSize:0];
                }
            }
            break;
            
        case SHARE_REJECT_SELF:
            LOG_DEBUG_S("reject state: share is rejected by self");
            break;
            
        case SHARE_REJECT_PEER:
            LOG_DEBUG_S("reject state: share is rejected by peer");
            if ([delegateMgr.connectDelegate respondsToSelector:@selector(didReject:)]) {
                [delegateMgr.connectDelegate didReject:udidString];
            }
            break;
            
        case SHARE_CANCEL_SELF:
            LOG_DEBUG_S("cancel state: share is cancelled by self");
            if (getIPTimeout) {
                LOG_DEBUG_S("cancel state: share is cancelled by self, but get ip timeout");
                // result = SHARE_GET_IP_TIMEOUT;
                getIPTimeout = false;
                // errCode = ERROR_GET_IP_TIMEOUT;
            }
            if ([delegateMgr.connectDelegate respondsToSelector:@selector(didSelfCancel:)]) {
                [delegateMgr.connectDelegate didSelfCancel:udidString];
            }
            break;
            
        case SHARE_CANCEL_PEER:
            LOG_DEBUG_S("cancel state: share is cancelled by peer");
            if ([delegateMgr.connectDelegate respondsToSelector:@selector(didCancel:)]) {
                [delegateMgr.connectDelegate didCancel:udidString];
            }
            break;
            
        case SHARE_CANCEL_PEER_BUSY:
            LOG_DEBUG_S("cancel state: share is cancelled by peer device is busy");
            if ([delegateMgr.connectDelegate respondsToSelector:@selector(didDisconnect:reason:errorCode:)]) {
                [delegateMgr.connectDelegate didDisconnect:udidString reason:@"peer_busy" errorCode:errCode];
            }
            break;
            
        case SHARE_ERROR_TIMEOUT:
        case SHARE_BLE_TIMEOUT:
        case SHARE_ERROR_TCP_TIMEOUT:
            LOG_DEBUG_S("timeout state: share is timeout");
            if ([delegateMgr.connectDelegate respondsToSelector:@selector(didDisconnect:reason:errorCode:)]) {
                [delegateMgr.connectDelegate didDisconnect:udidString reason:@"timeout" errorCode:errCode];
            }
            break;

        case SHARE_ERROR_TRANS_SELF:
        case SHARE_ERROR_TRANS_PEER:
        case SHARE_ERROR_BYTE_CHANNEL:
        case SHARE_ERROR_WIFI:
        case SHARE_ERROR_BLE:
        case SHARE_ERROR_BLE_ADD_SERVICE:
            if (result == SHARE_ERROR_WIFI) {
                // 发送transerror -> H侧
                SendTransError();
            }
            if (result == SHARE_ERROR_BYTE_CHANNEL && errCode % 100 == 65) {
                [delegateMgr.connectDelegate didDisconnect:udidString reason:@"network_permission" errorCode:errCode];
                break;
            }
            if ([delegateMgr.connectDelegate respondsToSelector:@selector(didDisconnect:reason:errorCode:)]) {
                if (networkErrCode == ERRCODE_WIFI_NETWORK_INTERNAL_ERROR || networkErrCode == ERRCODE_WIFI_NOT_MATCH_SSID) {
                    [delegateMgr.connectDelegate didDisconnect:udidString reason:@"network_error" errorCode:errCode];
                } else {
                    [delegateMgr.connectDelegate didDisconnect:udidString reason:@"trans_error" errorCode:errCode];
                }
            }
            break;
            
        case SHARE_COMPLETED_FORCE:
            LOG_DEBUG_S("unknown state: share is forcely completed");
            if ([delegateMgr.connectDelegate respondsToSelector:@selector(didDisconnect:reason:errorCode:)]) {
                [delegateMgr.connectDelegate didDisconnect:udidString reason:@"trans_error" errorCode:errCode];
            }
            break;
            
        case SHARE_ERROR_NOSPACE:
            LOG_DEBUG_S("no space state: has not enough space");
            if ([delegateMgr.connectDelegate respondsToSelector:@selector(didDisconnect:reason:errorCode:)]) {
                [delegateMgr.connectDelegate didDisconnect:udidString reason:@"nospace" errorCode:errCode];
            }
            break;
        case SHARE_HOTSPOT_ENABLED:
            LOG_DEBUG_S("Hotspot is enabled");
            if ([delegateMgr.connectDelegate respondsToSelector:@selector(didDisconnect:reason:errorCode:)]) {
                [delegateMgr.connectDelegate didDisconnect:udidString reason:@"hotspotOn" errorCode:errCode];
            }
            break;
        case SHARE_BLE_LTK:
            LOG_DEBUG_S("BLE LTK error");
            if ([delegateMgr.connectDelegate respondsToSelector:@selector(didDisconnect:reason:errorCode:)]) {
                [delegateMgr.connectDelegate didDisconnect:udidString reason:@"ble_ltk" errorCode:errCode];
            }
        default:
            break;
    }
    std::lock_guard<std::recursive_mutex> lock(mutex);
    if (udid == "emulate" && errCode == 0 && result == SHARE_ERROR_NOSPACE) {
        isSender = true;
        shareInfo = { "" };
    }
    SendDfxReport(result, errCode);
    bool isFileOpened = transMgr->IsStart();
    if (isFileOpened) {
        transMgr->Stop();
    }
    COAPDiscSerializer::GetInstance()->CheckCoapDevice();
    COAPDiscSerializer::GetInstance()->SetIsBLEConnectToWifiValue(false);
    if (isSender) {
        if (isFileOpened) {
            connectMgr->CloseFileChannel(sharingUdid);
        }
        if (state > SHARE_STARTED) {
            connectMgr->CloseProxyChannel(sharingUdid);
        }
        connectMgr->DecreaseRef(sharingUdid);
    }
    connectMgr->CloseBleChannel(sharingUdid);
    connectMgr->CloseTcpChannel(sharingUdid);
    connectMgr->CloseAuthChannel(sharingUdid);
    connectMgr->Disconnect(sharingUdid);
    
    authMgr->ClearDFileSessionKey();
    authMgr->ClearByteSessionKey();
    if (!peerSSID.empty() && m_isWifiConnected) {
        if (peerSSID != savedLastSSID) {
            [networkMgr RemoveSSID:[NSString stringWithUTF8String:peerSSID.c_str()] isRetry:NO];
        }
        currentIP = "";
        currentSSID = "";
        peerIP = "";
    }
    m_isWifiConnected = false;
    getIPTimeout = false;
    SetShareState(SHARE_IDLE);
    DeviceManager::shared().SetShareDevice("");
    sharingUdid = "";
    sharingChannelId = "";
    timerUdid = "";
    currentPercent = 0.0;
    bytesTransferred = 0;
    totalBytes = 0;
    shareRate = "0MB/s";
    shareSize = "";
    shareType = "";
    enterBackgroundCount = 0;
    errorFileUrl = "";
    pagesCount = "";
    numbersCount = "";
    keynoteCount = "";
    shotGapDays = "";
    savedResult = SHARE_RESULT_BUTT;
    currentShareNode.clear();
    LOG_DEBUG_S("clear share node");
    if (isSender) {
        isSender = false;
        if (sendCheckTimer >= 0) {
            timerQueue.cancelTask(sendCheckTimer);
        }
        sendCheckTimer = timerQueue.addTask(3500, 1, SendCheckTimeout);
    }
}


// H侧蓝牙主动断开/异常断开回调
void ShareManager::OnBleUnsubscribe(const std::string &uuid)
{
    if (sharingUdid != "" && sharingChannelId == uuid && state < SHARE_COMPLETING) {
        OnShareComplete(sharingUdid, SHARE_ERROR_BLE, ERROR_BLE_UNSUBSCRIBE);
    }
}

void ShareManager::SendCheckTimeout()
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (ShareManager::shared().shareList.size() >= 1) {
            auto sessionId = ShareManager::shared().sessionList.front();
            auto it = ShareManager::shared().shareList.find(sessionId);
            if (it == ShareManager::shared().shareList.end() || it->second.find("udid") == it->second.end()) {
                LOG_ERROR_S("invalid sessionId: %d", sessionId);
                return;
            }
            uint64_t deviceId = strtoull(it->second.at("udid").c_str(), nullptr, 16);
            if (DeviceManager::shared().hasDevice(deviceId)) {
                bool isHighSpeed = false;
                if (it->second.find("highSpeed") != it->second.end()) {
                    isHighSpeed = true;
                }
                ShareManager::shared().currentShareNode = it->second;
                LOG_DEBUG_S("set share node 2");
                ShareManager::shared().connectMgr->ShareFiles(it->second.at("udid"), isHighSpeed);

                ShareManager::shared().sessionList.pop();
                ShareManager::shared().shareList.erase(it);
            } else {
                LOG_ERROR_S("invalid device: %s", it->second.at("udid").c_str());
            }
        }
        ShareManager::shared().sendCheckTimer = -1;
    });
}

uint16_t ShareManager::GetDeviceId(int index)
{
    return authMgr->GetDeviceId(index);
}

void ShareManager::OnBleConnect(const std::string &channelId, const std::string &udid)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    if (udid.empty()) {
        LOG_ERROR_S("empty udid");
        return;
    }
    bleConnectedTime = GetCurrentTime();
    LOG_DEBUG_S("ble device connected: %s, channelId: %s", udid.c_str(), channelId.c_str());
    if (connectedBleList.find(channelId) != connectedBleList.end()) {
        LOG_ERROR_S("alreay connected channel");
        return;
    }
    connectedBleList.emplace(channelId);
    connectMgr->SendBLECachedData(channelId);
}

void ShareManager::OnBleDisconnect(const std::string &channelId, const std::string &udid)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    if (udid.empty()) {
        LOG_ERROR_S("empty udid");
        return;
    }
    LOG_DEBUG_S("ble device disconnected: %s", udid.c_str());
    if (connectedBleList.find(channelId) == connectedBleList.end()) {
        LOG_ERROR_S("invalid channel id");
        return;
    }
    connectedBleList.erase(channelId);
    if (state >= SHARE_COMPLETING) {
        OnShareComplete(udid, SHARE_SUCCESS, SUCCESS);
    } else {
        if (sendCheckTimer >= 0) {
            timerQueue.cancelTask(sendCheckTimer);
            SendCheckTimeout();
        } else if (sharingUdid == udid) {
            OnShareComplete(udid, SHARE_COMPLETED_FORCE, ERROR_COMPLETED_FORCE);
        }
    }
}

bool ShareManager::IsBleConnected(const std::string &channelId)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    return connectedBleList.find(channelId) != connectedBleList.end();
}

void ShareManager::RefreshNetwork()
{
    if (!isInit) {
        LOG_ERROR_S("not yet init");
        return;
    }
    [networkMgr RefreshNetwork];
}

void ShareManager::TmpDelayRefreshNetwork()
{
    ShareManager::shared().RefreshNetwork();
}

void ShareManager::DelayRefreshNetwork()
{
    timerQueue.addTask(500, 1, &ShareManager::TmpDelayRefreshNetwork);
}

void ShareManager::SetShareRate(int rate)
{
    shareRate = std::to_string(rate) + "MB/s";
}

void ShareManager::SetShareSize(long long size)
{
    char buffer[32];
    if (size >= 1024LL * 1024 * 1024) {
        snprintf(buffer, sizeof(buffer), "%.2f", size / (1024.0 * 1024.0 * 1024.0));
        shareSize = std::string(buffer) + "GB";
    } else if (size >= 1024LL * 1024) {
        snprintf(buffer, sizeof(buffer), "%.2f", size / (1024.0 * 1024.0));
        shareSize = std::string(buffer) + "MB";
    } else if (size >= 1024LL) {
        snprintf(buffer, sizeof(buffer), "%.2f", size / 1024.0);
        shareSize = std::string(buffer) + "KB";
    } else {
        snprintf(buffer, sizeof(buffer), "%lld", size);
        shareSize = std::string(buffer) + "B";
    }
}

void ShareManager::SetShareType(const std::string &sharedType)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    shareType = sharedType;
}

void ShareManager::SetEnterBackgroundCountIncrement(int count)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    enterBackgroundCount += count;
}

void ShareManager::SetErrorFileUrl(const std::string &fileUrl)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    errorFileUrl = fileUrl;
}

void ShareManager::SetIWorkCount(int pages, int numbers, int keynote)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    pagesCount = std::to_string(pages);
    numbersCount = std::to_string(numbers);
    keynoteCount = std::to_string(keynote);
}

std::string ShareManager::GetPeerIP()
{
    return peerIP;
}

void ShareManager::OnAuthChannelConnect(const AuthChannel &channel, bool isSender)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    LOG_DEBUG_S("sharing device: %s, new sharing device: %s", sharingUdid.c_str(), channel.udid.c_str());
    if (sharingUdid == "") {
        sharingUdid = channel.udid;
        sharingChannelId = channel.channelId;
        this->isSender = isSender;
        deviceHash.clear();
        peerSSID = "";
        peerPSK = "";
        peerIP = "";
        DeviceManager::shared().SetShareDevice(sharingUdid);
        SetShareState(SHARE_AUTHCHANNEL_OPENED);
        if (isSender) {
            std::vector<uint8_t> request;
            PackCompetencyNego(ISHARE_APPLE_ECOLOGY_COMPETENCY_NEGO_REQ_ID, request);
            connectMgr->SendData(sharingUdid, request);
        }
        keepAliveTimer = timerQueue.addTask(5000, 0, KeepAlive);
    }
}

void ShareManager::OnAuthChannelDisConnect(const AuthChannel &channel, bool isSender)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    LOG_DEBUG_S("close auth channel, udid: %s, sharingUdid: %s", channel.udid.c_str(), sharingUdid.c_str());
    if (channel.udid == sharingUdid && this->isSender != isSender) {
        LOG_DEBUG_S("not support bi-direction transfer");
        return;
    }
    if (channel.udid != sharingUdid) {
        connectMgr->CloseAuthChannel(channel.udid);
    }
    auto it = timerTaskList.find(channel.udid);
    if (it != timerTaskList.end()) {
        if (it->second >= 0) {
            if (channel.udid != sharingUdid) {
                timerQueue.cancelTask(it->second);
            } else if (state > SHARE_IDLE) {
                timerQueue.cancelTask(it->second);
                if (state > SHARE_JOIN_WIFI) {
                    OnShareComplete(sharingUdid, SHARE_ERROR_TRANS_SELF, ERROR_TRANS_SELF_AUTH_DISCONNECT);
                } else {
                    OnShareComplete(sharingUdid, SHARE_CANCEL_PEER, CANCEL_PEER_SEND_CANCEL);
                }
            }
        }
    }
}

void ShareManager::OnByteChannelOpen()
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    byteChannelTime = GetCurrentTime();
    LOG_DEBUG_S("open byte channel: %s", sharingUdid.c_str());
}

void ShareManager::OnByteChanelClose()
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    LOG_DEBUG_S("close byte channel: %s", sharingUdid.c_str());
}

void ShareManager::HandleDisconnect()
{
}

void ShareManager::FastFetchIP()
{
    if (getIPTimer >= 0) {
        timerQueue.cancelTask(getIPTimer);
    }
    getIPTimer = timerQueue.addTask(MI_GET_IP_TIMEOUT, MI_GET_IP_MAX_COUNT, GetIPTimeout);
}

void ShareManager::OnNetworkDisconnect()
{
    std::string anoPeerSSID = AnonymizeString(peerSSID);
    LOG_DEBUG_S("WLAN disconnect detected, peerSSID: %s, disconnectWifiTimer = %d", anoPeerSSID.c_str(), disconnectWifiTimer);
    if (state == SHARE_JOIN_WIFI && networkMgr != nil) {
        if (disconnectWifiTimer >= 0) {
            timerQueue.cancelTask(disconnectWifiTimer);
            disconnectWifiTimer = -1;
            HandleDisconnect();
        }
        SetShareState(SHARE_DISCONNECTED);
    } else {
        currentSSID = "";
        currentBSSID = "";
        currentIP = "";
        currentNetmask = "";
        if (state >= SHARE_CONNECTED && sharingUdid != "") {
            if (disconnectCheckTimer >= 0) {
                timerQueue.cancelTask(disconnectCheckTimer);
                disconnectCheckTimer = -1;
                OnShareComplete(sharingUdid, SHARE_ERROR_WIFI, ERROR_WIFI_DISCONNECT);
            } else {
                disconnectCheckTimer = timerQueue.addTask(1000, 1, DisconnectCheckTimeout);
            }
        }
    }
}

void ShareManager::OnNetworkConnect(int code, const std::map<std::string, std::string> network)
{
    LOG_DEBUG_S("code: %d", code);
    for (auto &item : network) {
        if (item.first == "ssid" || item.first == "bssid") {
            std::string anoItem = AnonymizeString(item.second);
            LOG_DEBUG_S("%s: %s", item.first.c_str(), anoItem.c_str());
        } else if (item.first == "ip" || item.first == "netmask" || item.first == "broadcastIp") {
            std::string anoIP = AnonymizeIP(item.second);
            LOG_DEBUG_S("%s: %s", item.first.c_str(), anoIP.c_str());
        } else if (item.first == "error") {
            LOG_DEBUG_S("%s: %s", item.first.c_str(), item.second.c_str());
        }
    }
    if (code == 0) {
        currentSSID = network.at("ssid");
        currentBSSID = network.at("bssid");
        currentIP = network.at("ip");
        currentIPV6 = network.at("ipv6");
        currentIPV6Prefix = network.at("ipv6Prefix");
        currentNetmask = network.at("netmask");
        if (state >= SHARE_JOIN_WIFI && state < SHARE_CONNECTED) {
            if (IsInSameNetwork(currentIP, currentNetmask, peerIP)) {
                LOG_DEBUG_S("send ip by event: %d", state);
                SendWifiInfo(currentIP, currentIPV6);
            }
        } else if (state >= SHARE_CONNECTED) {
            if (disconnectCheckTimer >= 0) {
                timerQueue.cancelTask(disconnectCheckTimer);
                disconnectCheckTimer = -1;
            }
//        } else if (state == SHARE_IDLE) {
//            if (peerSSID != "" && peerSSID == currentSSID) {
//                LOG_ERROR_S("retry to previous network");
//                [networkMgr RemoveSSID:[NSString stringWithUTF8String:peerSSID.c_str()] isRetry:YES];
//            }
        }
    }
}

//void ShareManager::OnNetworkCancel(int errcode)
//{
//    if (errcode == ERRCODE_USER_DECLINE_TO_JOIN_WIFI_NETWORK) {
//        m_isWifiConnected = false; // 如果用户拒绝加入wifi网络，不调用removeSSID，清空当前已连接的wifi信息，如：currentSSID, currentIP
//    }
//
//    SetShareState(SHARE_DISCONNECTED);
//    OnShareCancel(true);
//}

void ShareManager::OnNetworkError(long errCode)
{
    networkErrCode = errCode;
    if (errCode == ERRCODE_USER_DECLINE_TO_JOIN_WIFI_NETWORK) {
        m_isWifiConnected = false; // 如果用户拒绝加入wifi网络，不调用removeSSID，清空当前已连接的wifi信息，如：currentSSID, currentIP
    }
    if (state > SHARE_IDLE) {
        SetShareState(SHARE_DISCONNECTED);
        if (errCode == ERRCODE_USER_DECLINE_TO_JOIN_WIFI_NETWORK) {
            OnShareCancel(true);
        } else {
            OnShareComplete(sharingUdid, SHARE_ERROR_WIFI, ERROR_WIFI_CONNECTING_ERROR);
        }
    }
}

std::string ShareManager::OnFileTransStatus(TransFileStatus status, const std::string &file, uint64_t fileSize)
{
    std::string fileUrl = "";
    if (state < SHARE_CONNECTED) {
        return "";
    }
    NSString *udidString = [NSString stringWithUTF8String:sharingUdid.c_str()];
    NSString *fileName = [NSString stringWithUTF8String:file.c_str()];
    switch (status) {
        case RECV_FILE_START:
            if ([delegateMgr.transDelegate respondsToSelector:@selector(didRecvStart:file:)]) {
                NSString * realFile = [delegateMgr.transDelegate didRecvStart:udidString file:fileName];
                if (realFile) {
                    fileUrl = [realFile UTF8String];
                }
            }
            break;
        
        case RECV_FILE_END:
            if ([delegateMgr.transDelegate respondsToSelector:@selector(didRecvEnd:file:isFinished:fileSize:)]) {
                [delegateMgr.transDelegate didRecvEnd:udidString file:fileName isFinished:false fileSize:fileSize];
            }
            break;
            
        case SEND_FILE_START:
            if ([delegateMgr.transDelegate respondsToSelector:@selector(didSendStart:file:)]) {
                [delegateMgr.transDelegate didSendStart:udidString file:fileName];
            }
            break;
            
        case SEND_FILE_END:
            if ([delegateMgr.transDelegate respondsToSelector:@selector(didSendEnd:file:isFinished:)]) {
                [delegateMgr.transDelegate didSendEnd:udidString file:fileName isFinished:false];
            }
            break;

        default:
            LOG_ERROR_S("wrong trans file status: %d", status);
            break;
    }
    return fileUrl;
}

void ShareManager::OnTransStatus(TransStatus status, const DFileMsg *msg)
{
    if (state < SHARE_CONNECTED) {
        return;
    }
    NSString *udidString = [NSString stringWithUTF8String:sharingUdid.c_str()];
    switch (status) {
        case TRANS_CONNECTED:
            if ([delegateMgr.connectDelegate respondsToSelector:@selector(didConnect:status:)]) {
                [delegateMgr.connectDelegate didConnect:udidString status:@"connected"];
            }
            break;

        case TRANS_RECV_FILE_LIST:
        {
            NSMutableArray<NSString *> *fileList = [NSMutableArray array];
            for (int index = 0; index < msg->fileList.fileNum; index++) {
                [fileList addObject:[NSString stringWithUTF8String:msg->fileList.files[index]]];
            }
            NSNumber *totalBytes = [NSNumber numberWithLongLong:msg->transferUpdate.totalBytes];
            if ([delegateMgr.transDelegate respondsToSelector:@selector(didRecvAllFiles:files:totalBytes:)]) {
                [delegateMgr.transDelegate didRecvAllFiles:udidString files:fileList totalBytes:totalBytes];
            }
        }
            break;

        default:
            LOG_ERROR_S("wrong trans status: %d", status);
            break;
    }
}

bool ShareManager::HandleBLE(const std::string &channelId, const std::vector<uint8_t> &packet, bool isSender)
{
    return connectMgr->HandleBLE(channelId, packet, isSender);
}

bool ShareManager::HandleTcp(const std::string &channelId, const std::vector<uint8_t> &packet)
{
    return connectMgr->HandleTcp(channelId, packet);
}

bool ShareManager::EncryptWithAESGCM(const std::vector<uint8_t> &data,const std::vector<uint8_t> &nonce, std::vector<uint8_t> &ciphertext)
{
    if (isInit) {
        return authMgr->EncryptWithAESGCM(data, sessionKey, nonce, ciphertext);
    }
    return false;
}

bool ShareManager::DecryptWithAESGCM(const std::vector<uint8_t> &data, const std::vector<uint8_t> &nonce, std::vector<uint8_t> &plaintext)
{
    if (isInit) {
        return authMgr->DecryptWithAESGCM(data, sessionKey, nonce, plaintext);
    }
    return false;
}

void ShareManager::GetByteSessionKey(std::vector<uint8_t> &sessionKey)
{
    authMgr->GetByteSessionKey(sessionKey);
}

void ShareManager::SetByteSessionKey(const std::vector<uint8_t> &sessionKey)
{
    authMgr->SetByteSessionKey(sessionKey);
}

void ShareManager::GetDFileSessionKey(std::vector<uint8_t> &sessionKey)
{
    authMgr->GetDFileSessionKey(sessionKey);
}

void ShareManager::SetDFileSessionKey(const std::vector<uint8_t> &sessionKey)
{
    authMgr->SetDFileSessionKey(sessionKey);
}

void ShareManager::OnFileChannelOpen(const std::string &ip, uint16_t port, bool isServer)
{
    std::vector<uint8_t> dFileSessionKey;
    GetDFileSessionKey(dFileSessionKey);
    sendPercentTimer = timerQueue.addTask(1000, 0, SendSharePercent);
//    keepAliveTimer = timerQueue.addTask(5000, 0, KeepAlive);
    fileChannelTime = GetCurrentTime();
    int32_t sessionId = transMgr->Start(ip, port, isServer, dFileSessionKey, shareInfo);
    if (sessionId < 0) {
        std::string anoIP = AnonymizeIP(ip);
        LOG_ERROR_S("transMgr start failed, ip: %s, port: %d", anoIP.c_str(), port);
        OnShareComplete(sharingUdid, SHARE_ERROR_TRANS_SELF, ERROR_TRANS_SELF_FILE_CHANNEL_OPEN_FAILED);
        return;
    }
    auto it = timerTaskList.find(sharingUdid);
    if (it != timerTaskList.end()) {
        LOG_DEBUG_S("stop share timeout timer: %s %d", sharingUdid.c_str(), it->second);
        timerQueue.cancelTask(it->second);
        timerTaskList.erase(it);
    }
    recvFileList = nlohmann::json::array();
}

void ShareManager::SendWifiInfo(const std::string &ip, const std::string &ipv6)
{
    if (state >= SHARE_CONNECTED) {
        LOG_DEBUG_S("ip has already sent");
        return;
    }
    sendIPTime = GetCurrentTime();
    SetShareState(SHARE_CONNECTED);
    if (getIPTimer >= 0) {
        timerQueue.cancelTask(getIPTimer);
        getIPTimer = -1;
    }
    std::vector<uint8_t> vectAck;
    PackBleConnectOk(ip, ipv6, vectAck);
    std::vector<uint8_t> request;
    AssemblePacket(vectAck, request, AES_256_ENCRYPTION_FLAG);
    connectMgr->SendData(sharingUdid, request);
}

void ShareManager::SendNotEnoughSpace()
{
    std::vector<uint8_t> vectAck;
    PackNotEnoughSpace(vectAck);
    std::vector<uint8_t> request;
    AssemblePacket(vectAck, request, AES_256_ENCRYPTION_FLAG);
    connectMgr->SendData(sharingUdid, request);
}

void ShareManager::SendHotspotNoti()
{
    std::vector<uint8_t> vectAck;
    std::vector<uint8_t> request;
//    PackHotspotNoti(vectAck);
//    AssemblePacket(vectAck, request, NO_ENCRYPTION_FLAG);
//    connectMgr->SendData(sharingUdid, request);

    PackAlreadyRecv(vectAck);
    AssemblePacket(vectAck, request, NO_ENCRYPTION_FLAG);
    connectMgr->SendData(sharingUdid, request);
}

void ShareManager::SendTransError(void)
{
    std::vector<uint8_t> vectAck;
    PackTransError(vectAck);
    std::vector<uint8_t> request;
    AssemblePacket(vectAck, request, AES_256_ENCRYPTION_FLAG);
    connectMgr->SendData(sharingUdid, request);
}

void ShareManager::SendFilePreview(const std::vector<TransFileInfo> &files)
{
    std::vector<uint8_t> vectAck;
    CommonTwoTlvsInfo_t ci;
    std::string allFileName;
    nlohmann::json dateAddedArray = nlohmann::json::array();
    nlohmann::json dateTakenArray = nlohmann::json::array();
    nlohmann::json detailTimeArray = nlohmann::json::array();

    auto now = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();
    int minTimeGapDays = 0;
    try {
        if (shotGapDays != "") {
            minTimeGapDays = std::stoi(shotGapDays);
        } else {
            minTimeGapDays = 0;
        }
    } catch (...) {
        minTimeGapDays = 0;
    }

    bool first = true;
    for (const auto &item : files) {
        if (!first) {
            allFileName += "|";
        }
        allFileName += item.fileName;
        first = false;

        int64_t dateAdded = -1;
        try {
            if (!item.date_added.empty()) {
                dateAdded = std::stoll(item.date_added);
            }
        } catch (...) {
            LOG_ERROR_S("date_added add failed");
        }
        dateAddedArray.push_back(dateAdded);

        int64_t dateTaken = -1;
        try {
            if (!item.date_taken.empty()) {
                dateTaken = std::stoll(item.date_taken);
            }
        } catch (...) {
            LOG_ERROR_S("date_taken add failed");
        }
        dateTakenArray.push_back(dateTaken);

        int64_t timeDiff = (dateTaken > 0) ? (now - dateTaken) : 0;
        int days = timeDiff / (24LL * 3600 * 1000);

        if ((minTimeGapDays != 0 && days < minTimeGapDays && days > 0) || 
            (minTimeGapDays == 0 && days > 0)) {
            minTimeGapDays = days;
        }

        detailTimeArray.push_back("");
    }

    ci.strValue1 = allFileName;
    nlohmann::json jsonObj;
    jsonObj["date_added"] = dateAddedArray;
    jsonObj["date_taken"] = dateTakenArray;
    jsonObj["detail_time"] = detailTimeArray;

    shotGapDays = std::to_string(minTimeGapDays);

    ci.strValue2 = jsonObj.dump();
    PackFilePreview(ci, vectAck);
    std::vector<uint8_t> request;
    AssemblePacket(vectAck, request, AES_256_ENCRYPTION_FLAG);
    connectMgr->SendByteData(true, request);
}

bool ShareManager::ConnectToWiFi(const std::string &ssid, const std::string &password, int timeout)
{
    if (!isInit) {
        LOG_ERROR_S("not yet initialized");
        return false;
    }
    showNetworkTime = GetCurrentTime();
    m_isWifiConnected = true;
    auto it = timerTaskList.find(sharingUdid);
    if (it != timerTaskList.end()) {
        timerQueue.cancelTask(it->second);
        auto taskId = timerQueue.addTask(timeout, 1, ShareTimeout);
        LOG_DEBUG_S("extend share timeout timer: %s %d -> %d", sharingUdid.c_str(), it->second, taskId);
        timerTaskList.erase(it);
        timerTaskList.emplace(sharingUdid, taskId);
    }
    std::string anoSSID = AnonymizeString(ssid);
    LOG_DEBUG_S("try to connect wifi:%s", anoSSID.c_str());
    COAPDiscSerializer::GetInstance()->SetIsBLEConnectToWifiValue(true);
    if ([delegateMgr.connectDelegate respondsToSelector:@selector(didConnect:status:)]) {
        [delegateMgr.connectDelegate didConnect:[NSString stringWithUTF8String:sharingUdid.c_str()] status:@"joinwifi"];
    }
    [networkMgr ConnectSSID:[NSString stringWithUTF8String:ssid.c_str()]
                 passphrase:[NSString stringWithUTF8String:password.c_str()]];
    return true;
}

void ShareManager::OnSharePercent(double percent, const DFileMsg *msg, std::multimap<std::string, TransFileInfo> &fileLists, uint64_t currentSize)
{
    if (!isInit) {
        return;
    }
    if (msg != nullptr){
        bytesTransferred = currentSize;
        totalBytes = msg->transferUpdate.totalBytes;
    } else {
        bytesTransferred = 0;
        totalBytes = 1;
    }
    currentPercent = percent;
    GetFileList(fileLists);
}

bool ShareManager::RejectByInRecv(const std::string &udid)
{
    if (!isInit) {
        LOG_ERROR_S("share manager not yet init");
        return false;
    }
//    AuthChannel channel;
//    if (!connectMgr->GetChannel(udid, channel)) {
//        LOG_ERROR_S("no channel for device: %s", udid.c_str());
//        return false;
//    }
    auto it = timerTaskList.find(udid);
    if (it != timerTaskList.end()) {
        LOG_DEBUG_S("stop share timeout timer: %s %d", udid.c_str(), it->second);
        timerQueue.cancelTask(it->second);
        timerTaskList.erase(it);
    }
    std::vector<uint8_t> payload;
    std::vector<uint8_t> packet;
    PackAlreadyRecv(payload);
    AssemblePacket(payload, packet, NO_ENCRYPTION_FLAG);
    connectMgr->SendData(udid, packet);
    connectMgr->CloseTcpChannel(udid);
    return true;
}

bool ShareManager::OnRecvPacket(const std::string &udid, const std::vector<uint8_t> &request, std::vector<uint8_t> &response)
{
    if (deviceHash.empty()) {
        deviceHash.resize(HASH_KEY_LEN);
        memcpy(deviceHash.data(), request.data(), HASH_KEY_LEN);
    }
    if (memcmp(deviceHash.data(), request.data(), HASH_KEY_LEN)) {
        LOG_ERROR_S("not match device hash");
        return RejectByInRecv(udid);
    }
    
    // 解析包头字段，使用EA解码
    unsigned int offset = 16;
    std::vector<uint8_t> packet(request);

    // 解析businessId字段
    uint32_t businessId = ParseEaUint32(packet, offset);
    if (businessId != 0x01) {
        LOG_DEBUG_S("invalid business Id: %d", businessId);
        return false;
    }

    // 解析module字段
    uint32_t module = ParseEaUint32(packet, offset);
    if (module != 0x65) {
        LOG_DEBUG_S("invalid business Id: %d", module);
        return false;
    }

    // 解析encFlag字段
    uint32_t encFlag = ParseEaUint32(packet, offset);

    // 解析encLength字段
    uint32_t encLength = ParseEaUint32(packet, offset);
    
    std::vector<uint8_t> decRandomKey;
    if (encFlag > 0) {
        ParseEaUint32(packet, offset);
        encLength = ParseEaUint32(packet, offset);
        decRandomKey.insert(decRandomKey.end(), packet.begin() + offset, packet.begin() + offset + encLength);
        offset += encLength;
    }
    
    // 解析payload length字段
    uint32_t length = ParseEaUint32(packet, offset);

    // 提取payload数据
    if (packet.size() < offset + length) {
        return false;
    }
    
    std::vector<uint8_t> payload(packet.begin() + offset, packet.begin() + offset + length);
    offset = 0;

    if (encFlag > 0) {
        std::vector<uint8_t> plainData;
        if (encFlag == AES_256_ENCRYPTION_FLAG) {
            authMgr->DecryptWithAESGCM(payload, sessionKey, decRandomKey, plainData);
        } else {
            authMgr->DecryptWithRSA(payload, plainData);
        }
        payload.clear();
        payload.insert(payload.end(), plainData.begin(), plainData.end());
    }
    
    // 解析第一个EA-TLV字段的commandID
    uint32_t commandID = ParseEaUint32(payload, offset);

    // 解析length
    uint32_t subLength = ParseEaUint32(payload, offset);

    // 检查剩余数据是否足够
    if (payload.size() < offset + subLength) {
        return false;
    }

    payload.erase(payload.begin(), payload.begin() + offset);
    offset = 0;
    uint32_t subType = ParseEaUint32(payload, offset);

    LOG_DEBUG_S("commandID: %02x, subType: %02x", commandID, subType);
    std::vector<uint8_t> outPacket;
//    std::vector<uint8_t> vectAck;
    bool ret = false;
    switch (commandID) {
        case ISHARE_APPLE_ECOLOGY_COMMAND_ID:
            switch (subType) {
                case ISHARE_ECOLOGY_POPUP_CONFIRM:
                {
                    bool isConfirm = false;
                    if (ParseUserAckPayload(payload, isConfirm)) {
                        if (isConfirm) {
                            NetworkInfo_t ni;
                            payload.clear();
                            ni.apSsid = currentSSID;
                            ni.staSsid = currentSSID;
                            ni.staIp = currentIP;
                            PackDirectConnectReq(ni, payload);
                            AssemblePacket(payload, outPacket, AES_256_ENCRYPTION_FLAG);
                            if ([delegateMgr.connectDelegate respondsToSelector:@selector(didAccept:)]) {
                                NSString *udidString = [NSString stringWithUTF8String:udid.c_str()];
                                [delegateMgr.connectDelegate didAccept:udidString];
                            }
                        } else {
                            OnShareReject(false);
                        }
                        ret = true;
                    }
                    break;
                }
                case ISHARE_ECOLOGY_SENDER_CANCEL:
                {
                    bool isConfirm = false;
                    if (ParseUserAckPayload(payload, isConfirm) && isConfirm) {
                        OnShareCancel(false);
                        BuildMetaPayload(ISHARE_ECOLOGY_SENDER_CANCEL_ACK, outPacket);
                        ret = true;
                    }
                    break;
                }
                case ISHARE_ECOLOGY_RECEIVE_CANCEL:
                {
                    bool isConfirm = false;
                    if (ParseUserAckPayload(payload, isConfirm) && isConfirm) {
                        OnShareCancel(false);
                        BuildMetaPayload(ISHARE_ECOLOGY_RECEIVE_CANCEL_ACK, outPacket);
                        ret = true;
                    }
                    break;
                }
                case ISHARE_ECOLOGY_SENDER_CANCEL_ACK:
                case ISHARE_ECOLOGY_RECEIVE_CANCEL_ACK:
                {
                    bool isConfirm = false;
                    if (ParseUserAckPayload(payload, isConfirm) && isConfirm) {
                        if (cancelTimer >= 0) {
                            LOG_DEBUG_S("cancel timer: %d", cancelTimer);
                            timerQueue.cancelTask(cancelTimer);
                            OnShareComplete(sharingUdid, SHARE_CANCEL_SELF, CANCEL_SELF_RECEIVE_CANCEL);
                            cancelTimer = -1;
                        }
                        ret = true;
                    }
                    break;
                }
                case ISHARE_ECOLOGY_ALREADY_IN_RECEIVE:
                    if (ParseAlreadyRecv(payload)) {
                        OnShareComplete(udid, SHARE_CANCEL_PEER_BUSY, CANCEL_PEER_BUSY);
                    }
                    break;

                case ISHARE_ECOLOGY_TRANS_ERROR:
                    if (ParseTransError(payload)) {
                        OnShareComplete(sharingUdid, SHARE_ERROR_TRANS_PEER, ERROR_TRANS_PEER);
                    }
                    break;

                case ISHARE_ECOLOGY_DFILE_RECV_PERCENT:
                {
                    double percent = 0.0;
                    if (ParseRecvPercentPayload(payload, percent)) {
                        currentPercent = percent;
                        UpdateProgress();
                    }
                    break;
                }

                case ISHARE_ECOLOGY_NOT_ENOUGH_SPACE:
                {
                    if (ParseNotEnoughSpace(payload)) {
                        OnShareComplete(udid, SHARE_ERROR_NOSPACE, ERROR_NOSPACE_PEER);
                    }
                    break;
                }

                case ISHARE_ECOLOGY_SAVE_AVATER:
                {
                    CommonOneTlvInfo_t ci;
                    LOG_DEBUG_S("ISHARE_ECOLOGY_SAVE_AVATER");
                    if (!payload.empty()) {
                        std::vector<uint8_t> vectData;
                        vectData.resize(payload.size());
                        memcpy(vectData.data(), payload.data(), payload.size());
                        uint64_t deviceId = strtoull(sharingUdid.c_str(), nullptr, 16);
                        auto device = DeviceManager::shared().getDevice(deviceId);
                        std::string avatarData;
                        std::string hwId = "";
                        if (device != nullptr && !device->hwContactId.empty()) {
                            hwId = DeviceManager::shared().getHwidStr(device->hwContactId);
                        }
                        if (ParseAvatarData(vectData, avatarData) && SaveAvatar(sharingUdid, hwId, avatarData)) {
                            LOG_DEBUG_S("save avatar ok");
                            ret = true;
                        }
                    }
                    break;
                }
                default:
                    break;
            }
            break;

        case ISHARE_APPLE_ECOLOGY_COMPETENCY_NEGO_REQ_ID:
            if (isSender) {
                std::vector<uint8_t> payload;
                PackAlreadyRecv(payload);
                AssemblePacket(payload, response, NO_ENCRYPTION_FLAG);
                ret = true;
            } else if (ParseCompetencyNego(payload)) {
                MIHotspotDetector *hotspot = [MIHotspotDetector shared];
                if (hotspot.isPersonalHotspotEnabled) {
                    SendHotspotNoti();
                    OnShareComplete(sharingUdid, SHARE_HOTSPOT_ENABLED, ERROR_HOTSPOT_ENABLED);
                    return true;
                }
                PackCompetencyNego(ISHARE_APPLE_ECOLOGY_COMPETENCY_NEGO_RSP_ID, outPacket);
                ret = true;
            }
            break;

        case ISHARE_APPLE_ECOLOGY_COMPETENCY_NEGO_RSP_ID:
            if (!isSender) {
                std::vector<uint8_t> payload;
                PackAlreadyRecv(payload);
                AssemblePacket(payload, response, NO_ENCRYPTION_FLAG);
                ret = true;
            } else if (ParseCompetencyNego(payload)) {
                PackPubKeyHandShake(GET_RSA_PUBLIC_KEY, outPacket);
                ret = true;
            }
            break;

        case ISHARE_APPLE_ECOLOGY_CCMP_ID:
            switch (subType) {
                case GET_RSA_PUBLIC_KEY:
                    if (ParsePubKeyHandShake(payload)) {
                        PackPubKeyHandShake(GET_RSA_PUBLIC_KEY_RESPONSE, outPacket);
                        ret = true;
                    }
                    break;

                case GET_RSA_PUBLIC_KEY_RESPONSE:
                    if (ParsePubKeyHandShake(payload)) {
                        PackAESKeyHandShakeReq(outPacket);
                        ret = true;
                    }
                    break;

                case GET_AES_KEY:
                    if (ParseAESKeyHandShakeReq(payload, handShakeSalt, handShakeAesKey)) {
                        PackAESKeyHandShakeRsp(handShakeSalt, handShakeAesKey, outPacket);
                        ret = true;
                    }
                    break;
                    
                case GET_AES_KEY_RESPONSE:
                    if (ParseAESKeyHandShakeRsp(payload) && currentShareNode.size())
                    {
                        ShareNode shareNode = currentShareNode;
                        if (shareNode.find("sendType") != shareNode.end()) {
                            shareInfo.sendType = shareNode["sendType"];
                        }
                        if (shareNode.find("senderName") != shareNode.end()) {
                            shareInfo.senderName = shareNode["senderName"];
                        }
                        if (shareNode.find("itemCount") != shareNode.end()) {
                            shareInfo.itemCount = shareNode["itemCount"];
                        }
                        if (shareNode.find("totalSize") != shareNode.end()) {
                            shareInfo.totalSize = shareNode["totalSize"];
                        }
                        if (shareNode.find("folderCount") != shareNode.end()) {
                            shareInfo.folderCount = shareNode["folderCount"];
                        }
                        if (shareNode.find("fileCount") != shareNode.end()) {
                            shareInfo.fileCount = shareNode["fileCount"];
                        }
                        if (shareNode.find("previewSummary") != shareNode.end()) {
                            shareInfo.previewSummary = shareNode["previewSummary"];
                        }
                        LOG_DEBUG_S("Send share info: sendType:%s, senderName:%s, itemCount:%s, totalSize:%s, folderCount:%s, fileCount:%s, previewSummary:%s",
                                   shareInfo.sendType.c_str(), shareInfo.senderName.c_str(), shareInfo.itemCount.c_str(),
                                   shareInfo.totalSize.c_str(), shareInfo.folderCount.c_str(), shareInfo.fileCount.c_str(),
                                   shareInfo.previewSummary.c_str());
                        payload.clear();
                        PackFileShareInfoPayload(shareInfo, payload);
                        AssemblePacket(payload, outPacket, AES_256_ENCRYPTION_FLAG);
                        showPreviewTime = GetCurrentTime();
                        ret = true;
                    }
                    break;
                default:
                    break;
            }
            break;
        case ISHARE_APPLE_ECOLOGY_PREVIEW_SHOW_ID:
            LOG_DEBUG_S("ISHARE_APPLE_ECOLOGY_PREVIEW_SHOW_ID");
            if (ParseFileShareInfoPayload(payload, shareInfo))
            {
                bool isCoap = false;
                NSMutableDictionary *dict = [NSMutableDictionary dictionary];
                [dict setValue:[NSString stringWithUTF8String:shareInfo.sendType.c_str()] forKey:@"sendType"];
                [dict setValue:[NSString stringWithUTF8String:shareInfo.fileCount.c_str()] forKey:@"fileCount"];
                [dict setValue:[NSString stringWithUTF8String:shareInfo.folderCount.c_str()] forKey:@"folderCount"];
                [dict setValue:[NSString stringWithUTF8String:shareInfo.senderName.c_str()] forKey:@"senderName"];
                [dict setValue:[NSString stringWithUTF8String:shareInfo.itemCount.c_str()] forKey:@"itemCount"];
                [dict setValue:[NSString stringWithUTF8String:shareInfo.totalSize.c_str()] forKey:@"totalSize"];
                [dict setValue:[NSString stringWithUTF8String:shareInfo.previewSummary.c_str()] forKey:@"previewSummary"];
                LOG_DEBUG_S("Recv share info: sendType:%s, fileCount:%s, folderCount:%s, itemCount:%s, totalSize:%s, previewSummary:%s",
                            shareInfo.sendType.c_str(), shareInfo.fileCount.c_str(), shareInfo.folderCount.c_str(),
                            shareInfo.itemCount.c_str(),
                            shareInfo.totalSize.c_str(), shareInfo.previewSummary.c_str());
                NSString *hwid = @"";
                uint64_t deviceId = strtoull(sharingUdid.c_str(), nullptr, 16);
                auto device = DeviceManager::shared().getDevice(deviceId);
                int deviceType = 0;
                if (device != nullptr) {
                    if (!device->hwContactId.empty()) {
                        std::string hwidString = DeviceManager::shared().getHwidStr(device->hwContactId);
                        hwid = [NSString stringWithUTF8String:hwidString.c_str()];
                    }
                    if (connectMgr->GetChannelType(udid) == CONN_TYPE_TCP) {
                        deviceType = device->info.type;
                        isCoap = true;
                    } else {
                        deviceType = device->type;
                    }
                }
                showPreviewTime = GetCurrentTime();
                [dict setValue:@(deviceType) forKey:@"deviceType"];
                long long freeSpace = GetFreeDiskSpace();
                long long recvSize = atoll(shareInfo.totalSize.c_str());
                SetShareSize(recvSize);
                long long requiredSpace = recvSize;
                if (shareInfo.sendType == "0") {
                    requiredSpace += 1024LL * 1024 * 1024; // 冗余1G防止存储空间不足
                }
                if (freeSpace < requiredSpace) {
                    LOG_DEBUG_S("Current device has no space to receive file, current size is %lld, required is %lld", freeSpace, requiredSpace);
                    PackNotEnoughSpace(payload);
                    AssemblePacket(payload, outPacket, AES_256_ENCRYPTION_FLAG);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        OnShareComplete(sharingUdid, SHARE_ERROR_NOSPACE, ERROR_NOSPACE_SELF);
                    });
                } else if ([delegateMgr.connectDelegate respondsToSelector:@selector(didMetaRecv:hwid:metadata:isCoap:)]) {
                    [delegateMgr.connectDelegate didMetaRecv:[NSString stringWithUTF8String:sharingUdid.c_str()] hwid:hwid metadata:dict isCoap:isCoap];
                }
                ret = true;
            }
            break;

        case ISHARE_APPLE_ECOLOGY_NETWORKINFO_NEGO_REQ_ID:
        {
            LOG_DEBUG_S("ISHARE_APPLE_ECOLOGY_NETWORKINFO_NEGO_REQ_ID");
            // 1 解析直连请求
            NetworkInfo_t ni;
            if (ParseDirectConnect(payload.data(), payload.size(), ni)) {
                std::string anoCurrentSSID = AnonymizeString(currentSSID);
                std::string anoCurrentIP = AnonymizeIP(currentIP);
                LOG_DEBUG_S("currentSSID: %s, currentIP: %s", anoCurrentSSID.c_str(), anoCurrentIP.c_str());
                ni.apSsid = currentSSID;
                ni.apIp = "";
                ni.staSsid = "";
                ni.staIp = "";
                if (currentIP != "") {
                    ni.staSsid = currentSSID;
                    ni.staIp = currentIP;
                }
                PackDirectConnectAck(ni, payload);
                AssemblePacket(payload, outPacket, AES_256_ENCRYPTION_FLAG);
                ret = true;
            }
            break;
        }

        case ISHARE_APPLE_ECOLOGY_NETWORKINFO_NEGO_RSP_ID:
        {
            LOG_DEBUG_S("ISHARE_APPLE_ECOLOGY_NETWORKINFO_NEGO_RSP_ID");
            // 1 解析直连请求
            NetworkInfo_t ni;
            if (ParseDirectConnect(payload.data(), payload.size(), ni)) {
                if ((connectMgr->GetChannelType(udid) == CONN_TYPE_BLE) && 
                    (ni.apIp == "" || ni.apSsid == "" || GetGatewayIp(currentIP) != ni.apIp || currentSSID != ni.apSsid)) {
                    LOG_DEBUG_S("[ISHARE_APPLE_ECOLOGY_NETWORKINFO_NEGO_RSP_ID]go ble");
                    payload.clear();
                    std::vector<uint8_t> pkt;
                    PackEaUint32(ISHARE_ECOLOGY_GET_PHYSICAL_CONNECTION_INFO, pkt);
                    PackEaUint32(0, pkt);
                    PackEaUint32(ISHARE_APPLE_ECOLOGY_COMMAND_ID, payload);
                    PackEaUint32(static_cast<uint32_t>(pkt.size()), payload);
                    payload.insert(payload.end(), pkt.begin(), pkt.end());
                    AssemblePacket(payload, outPacket, AES_256_ENCRYPTION_FLAG);
                } else {
                    LOG_DEBUG_S("[ISHARE_APPLE_ECOLOGY_NETWORKINFO_NEGO_RSP_ID]go tcp");
                    std::vector<uint8_t> vectAck;
                    PackBleConnectOk(currentIP, currentIPV6, vectAck);
                    AssemblePacket(vectAck, outPacket, AES_256_ENCRYPTION_FLAG);
                    SetShareState(SHARE_CONNECTED);
                }
                ret = true;
            }
            break;
        }

        case ISHARE_APPLE_ECOLOGY_PHYSICAL_CONNECTION_INFO_ID:
        {
            LOG_DEBUG_S("ISHARE_APPLE_ECOLOGY_PHYSICAL_CONNECTION_INFO_ID");
            ConnectInfo rci;
            if (ParseRequestConnect(payload.data(), static_cast<uint32_t>(payload.size()), rci)) {
                // 2 用ssid，psk连接H侧热点
                peerSSID = rci.peerSSID;
                peerPSK = rci.peerPSK;
                peerIP = rci.peerIP;
                std::string anoCurrentSSID = AnonymizeString(currentSSID);
                std::string anoPeerSSID = AnonymizeString(peerSSID);
                std::string anoPeerIP = AnonymizeIP(peerIP);
                LOG_DEBUG_S("currentSSID: %s, peerSSID: %s, peerIP: %s", anoCurrentSSID.c_str(), anoPeerSSID.c_str(), anoPeerIP.c_str());
                if ((connectMgr->GetChannelType(udid) == CONN_TYPE_BLE) &&
                    ((GetGatewayIp(currentIP) != peerIP) || (currentSSID != peerSSID))) {
                    LOG_DEBUG_S("[ISHARE_APPLE_ECOLOGY_PHYSICAL_CONNECTION_INFO_ID]go ble");
//                    if (connectWifiTimer >= 0) {
//                        timerQueue.cancelTask(connectWifiTimer);
//                        connectWifiTimer = -1;
//                    }
                    if (disconnectWifiTimer >= 0) {
                        timerQueue.cancelTask(disconnectWifiTimer);
                        disconnectWifiTimer = -1;
                    }
                    if (getIPTimer >= 0) {
                        timerQueue.cancelTask(getIPTimer);
                        getIPTimer = -1;
                    }
                    int timeout = JOIN_WIFI_TIMEOUT;
                    if (!rci.timeout.empty()) {
                        timeout = std::atoi(rci.timeout.c_str()) * TIMEOUT_MS_UNIT;
                    }
                    ConnectToWiFi(peerSSID, peerPSK, timeout);
//                    connectWifiTimer = timerQueue.addTask(MI_GET_IP_TIMEOUT, 1, GetIPTimeout);
                    SetShareState(SHARE_JOIN_WIFI);
                } else {
                    LOG_DEBUG_S("[ISHARE_APPLE_ECOLOGY_PHYSICAL_CONNECTION_INFO_ID]go tcp");
                    std::vector<uint8_t> vectAck;
                    PackBleConnectOk(currentIP, currentIPV6, vectAck);
                    AssemblePacket(vectAck, outPacket, AES_256_ENCRYPTION_FLAG);
                    SetShareState(SHARE_CONNECTED);
                    ret = true;
                }
            }
        }
            break;

        case ISHARE_APPLE_ECOLOGY_LOGICAL_CONNECTION_INFO_ID:
        {
            LOG_DEBUG_S("ISHARE_APPLE_ECOLOGY_LOGICAL_CONNECTION_INFO_ID");
            // 1 解析连接成功报文
            CommonTwoTlvsInfo_t ci;
            if (ParseBleConnectOk(payload.data(), static_cast<uint32_t>(payload.size()), ci)) {
                std::string anoIP = AnonymizeIP(ci.strValue1);
                LOG_DEBUG_S("received ip: %s", anoIP.c_str());
                if (state < SHARE_CONNECTED && currentIP != "") {
                    std::vector<uint8_t> vectAck;
                    PackBleConnectOk(currentIP, currentIPV6, vectAck);
                    AssemblePacket(vectAck, outPacket, AES_256_ENCRYPTION_FLAG);
                }
                SetShareState(SHARE_CONNECTED);
                ret = true;
            }
            break;
        }

        case ISHARE_APPLE_ECOLOGY_PREVIEW_RECV_ID:
        {
            CommonTlvInfo_t cti;
            CommonOneTlvInfo_t ci;
            LOG_DEBUG_S("ISHARE_APPLE_ECOLOGY_PREVIEW_RECV_ID");
            // 1 解析FilePreview报文
            if (ParseFilePreview(payload.data(), payload.size(), cti) && SaveThumbnail(cti)) {
                LOG_DEBUG_S("file name: %s", cti.strVals[0].c_str());
                SaveTimeInfo(cti);
                // 发送FilePreview ack
                ci.strValue = "previewOK";
                PackFilePreviewAck(ci, payload);
                AssemblePacket(payload, outPacket, AES_256_ENCRYPTION_FLAG);
                ret = true;
            }
            break;
        }

        case ISHARE_APPLE_ECOLOGY_AVATAR:
        {
            CommonOneTlvInfo_t ci;
            LOG_DEBUG_S("ISHARE_APPLE_ECOLOGY_AVATAR");
            if (!payload.empty()) {
                std::vector<uint8_t> vectData;
                vectData.resize(payload.size());
                memcpy(vectData.data(), payload.data(), payload.size());
                uint64_t deviceId = strtoull(sharingUdid.c_str(), nullptr, 16);
                auto device = DeviceManager::shared().getDevice(deviceId);
                std::string avatarData(vectData.begin(), vectData.end());
                std::string hwId = "";
                if (device != nullptr && !device->hwContactId.empty()) {
                    hwId = DeviceManager::shared().getHwidStr(device->hwContactId);
                }
                if (SaveAvatar(sharingUdid, hwId, avatarData)) {
                    LOG_DEBUG_S("save avatar ok");
                    ret = true;
                }
            }
            break;
        }

        default:
            break;
    }
    if (outPacket.size()) {
        if (udid != "") {
            connectMgr->SendData(udid, outPacket);
        } else {
            connectMgr->SendByteData(isSender, outPacket);
        }
    }
    return true;
}

uint32_t ShareManager::ParseEaUint32(const std::vector<uint8_t> &data, unsigned int &offset)
{
    UnPackagedEA result = ShareHelper::removeEA(data, offset);
    offset = result.offset;
    return result.value;
}

// EA打包辅助函数
void ShareManager::PackEaUint32(uint32_t value, std::vector<uint8_t> &packet)
{
    std::vector<uint8_t> pkt;
    ShareHelper::addEA(static_cast<int>(value), pkt);
    packet.insert(packet.end(), pkt.begin(), pkt.end());
}

void ShareManager::BuildMetaPayload(int type, std::vector<uint8_t> &payload)
{
    payload.clear();
    std::vector<uint8_t> vectAck;
    PackUserAckPayload(type, vectAck);
    AssemblePacket(vectAck, payload, AES_256_ENCRYPTION_FLAG);
}

bool ShareManager::ParseCompetencyNego(const std::vector<uint8_t> &payload)
{
    unsigned int offset = 0;
    // 解析第一个子EA-TLV字段
    uint32_t type = ParseEaUint32(payload, offset);
    uint32_t length = ParseEaUint32(payload, offset);

    if (payload.size() < offset + length) {
        return false;
    }

    // 根据type1获取数据
    std::string value(payload.begin() + offset, payload.begin() + offset + length);
    offset += length;
    switch (type) {
        case ISHARE_APPLE_ECOLOGY_SUPPORT_SECURE_VERSION:
            if (value.size() && supportSecureVersion != static_cast<uint32_t>(std::stoi(value))) {
                return false;
            }
            break;
        default:
            // 未知的type
            break;
    }
    
    if (payload.size() > offset) {
        // 解析第二个子EA-TLV字段
        type = ParseEaUint32(payload, offset);
        length = ParseEaUint32(payload, offset);

        if (payload.size() < offset + length) {
            return false;
        }

        // 根据type2获取数据
        std::string value(payload.begin() + offset, payload.begin() + offset + length);
        offset += length;
        switch (type) {
            case ISHARE_APPLE_ECOLOGY_SUPPORT_FILE_TYPE_ABILITY:
                // 解析支持的文件类型
                if (value.size() && supportFileTypeAbility != static_cast<uint32_t>(std::stoi(value))) {
                    return false;
                }
                break;
            default:
                // 未知的type
                break;
        }
    }
    return true;
}

void ShareManager::PackCompetencyNego(uint32_t commandId, std::vector<uint8_t> &packet)
{
    std::vector<uint8_t> payload;

    // 构造Value部分（两个EA-TLV字段）
    std::vector<uint8_t> valuePart;
    std::vector<uint8_t> valueOSVersion;
    std::vector<uint8_t> valueDevModel;

    // 第一个子EA-TLV字段: 能力协商版本
    PackEaUint32(ISHARE_APPLE_ECOLOGY_SUPPORT_SECURE_VERSION, valuePart);
    PackEaUint32(0, valuePart);

    PackEaUint32(ISHARE_APPLE_ECOLOGY_APP_VERSION, valuePart);
    std::string versionStr = GetAppVersion();
    PackEaUint32(static_cast<uint32_t>(versionStr.length()), valuePart);
    valuePart.insert(valuePart.end(), versionStr.begin(), versionStr.end());
    // 获取当前系统版本号
    PackEaUint32(ISHARE_APPLE_ECOLOGY_OS_VERSION, valuePart);
    std::string osVersionStr = GetOSVersion();
    PackEaUint32(static_cast<uint32_t>(osVersionStr.length()), valuePart);
    valuePart.insert(valuePart.end(), osVersionStr.begin(), osVersionStr.end());
    
    // 获取设备型号
    PackEaUint32(ISHARE_APPLE_ECOLOGY_DEV_MODEL, valuePart);
    std::string devModel = GetDeviceModel();
    PackEaUint32(static_cast<uint32_t>(devModel.length()), valuePart);
    valuePart.insert(valuePart.end(), devModel.begin(), devModel.end());
    // 能力协商版本 bit0:通过公钥交换建立会话密钥 (1<<0 = 1)
//    std::string versionStr = std::to_string(supportSecureVersion);
//    PackEaUint32(static_cast<uint32_t>(versionStr.length()), valuePart);
//    valuePart.insert(valuePart.end(), versionStr.begin(), versionStr.end());

//    // 第二个子EA-TLV字段: 支持的文件类型
//    PackEaUint32(ISHARE_APPLE_ECOLOGY_SUPPORT_FILE_TYPE_ABILITY, valuePart;
//
//    // 支持所有文件类型 (SEND_TYPE_PHOTO_ASSET to SEND_TYPE_LINK)
//    std::string fileTypeStr = "2047"; // 1<<0|1<<1|...|1<<10 = 2047
//    PackEaUint32(static_cast<uint32_t>(fileTypeStr.length()), valuePart);
//    valuePart.insert(valuePart.end(), fileTypeStr.begin(), fileTypeStr.end());

    // 构造TLV结构: type(4字节) + length(4字节) + value(valuePart)
    std::vector<uint8_t> tlvPart;

    // type字段: commandID
    PackEaUint32(commandId, tlvPart);
    // length字段
    PackEaUint32(static_cast<uint32_t>(valuePart.size()), tlvPart);
    // value字段
    tlvPart.insert(tlvPart.end(), valuePart.begin(), valuePart.end());

    // 将TLV结构添加到payload
    payload.insert(payload.end(), tlvPart.begin(), tlvPart.end());

    // 使用assemblePacket方法构造完整packet
    AssemblePacket(payload, packet, NO_ENCRYPTION_FLAG);
}

// 打包CCMP-公钥交换
void ShareManager::PackPubKeyHandShake(uint32_t commandId, std::vector<uint8_t> &packet)
{
  // 获取本端公钥
    std::vector<uint8_t> publicKey;
    authMgr->ExportPublicKey(publicKey);

    std::vector<uint8_t> payload;
    std::string algorithmStr = "1";
    
    // 构造Value部分（两个EA-TLV字段）
    std::vector<uint8_t> valuePart;

    // 第一个子EA-TLV字段: RSA公钥或AES密钥
    PackEaUint32(commandId, valuePart);

    PackEaUint32(static_cast<uint32_t>(publicKey.size()), valuePart);
    valuePart.insert(valuePart.end(), publicKey.begin(), publicKey.end());

//    // 第二个子EA-TLV字段: 算法类型
//    PackEaUint32(PUBLIC_KEY_ALGORITHM_TYPE, valuePart);
//    PackEaUint32(static_cast<uint32_t>(algorithmStr.length()), valuePart);
//    valuePart.insert(valuePart.end(), algorithmStr.begin(), algorithmStr.end());

    // 构造TLV结构: type(4字节) + length(4字节) + value(valuePart)
    std::vector<uint8_t> tlvPart;

    // type字段: commandID
    PackEaUint32(ISHARE_APPLE_ECOLOGY_CCMP_ID, tlvPart);
    // length字段
    PackEaUint32(static_cast<uint32_t>(valuePart.size()), tlvPart);
    // value字段
    tlvPart.insert(tlvPart.end(), valuePart.begin(), valuePart.end());

    // 将TLV结构添加到payload
    payload.insert(payload.end(), tlvPart.begin(), tlvPart.end());

  // 使用assemblePacket方法构造完整packet
    AssemblePacket(payload, packet, NO_ENCRYPTION_FLAG);
}

bool ShareManager::ParsePubKeyHandShake(const std::vector<uint8_t> &payload)
{
    unsigned int offset = 0;
    // 解析第一个子EA-TLV字段
    uint32_t type = ParseEaUint32(payload, offset);
    uint32_t length = ParseEaUint32(payload, offset);

    if (payload.size() < offset + length) {
        return false;
    }
    std::vector<uint8_t> publicKeyData(payload.begin() + offset, payload.begin() + offset + length);
    // 根据type获取数据
    switch (type) {
        case GET_RSA_PUBLIC_KEY:
        case GET_RSA_PUBLIC_KEY_RESPONSE:
            // 解析能力协商版本
            if (!authMgr->ImportPeerPublicKey(publicKeyData)) {
                LOG_ERROR_S("Fail to import pub key from H");
                return false;
            }
            break;
        default:
            // 未知的type
            return false;
    }
    offset += length;
    if (offset >= payload.size()) {
        return true;
    }

    // 解析第二个子EA-TLV字段
    type = ParseEaUint32(payload, offset);
    length = ParseEaUint32(payload, offset);

    if (payload.size() < offset + length) {
        return false;
    }

    // 根据type2获取数据
    std::string value2(payload.begin() + offset, payload.begin() + offset + length);
    offset += length;

    switch (type) {
        case PUBLIC_KEY_ALGORITHM_TYPE:
            // 解析公钥算法类型
            publicKeyAlgorithmType = static_cast<uint32_t>(std::stoi(value2));
            break;

        case SESSION_KEY_ALGORITHM_TYPE:
            // 解析会话密钥算法类型
            sessionKeyAlgorithmType = static_cast<uint32_t>(std::stoi(value2));
            break;

        case ISHARE_APPLE_ECOLOGY_SUPPORT_FILE_TYPE_ABILITY:
            // 解析支持的文件类型
            supportFileTypeAbility = static_cast<uint32_t>(std::stoi(value2));
            break;
        default:
            // 未知的type
            break;
    }
    return true;
}

void ShareManager::PackAESKeyHandShakeRsp(std::vector<uint8_t> &salt, std::vector<uint8_t> &aesKey, std::vector<uint8_t> &packet)
{
    // 第一层加密：使用之前解密出来的随机数加密会话密钥 (aesGcmRandomKey作为key,
    // randomKey作为nonce)
    sessionKey.resize(32);
    RAND_bytes(sessionKey.data(), 32);

    std::vector<uint8_t> encryptSessionKey;
    authMgr->EncryptWithAESGCM(sessionKey, aesKey, salt, encryptSessionKey);

    std::vector<uint8_t> payload;
    
    // 构造Value部分（两个EA-TLV字段）
    std::vector<uint8_t> valuePart;

    // 第一个子EA-TLV字段: RSA公钥或AES密钥
    PackEaUint32(GET_AES_KEY_RESPONSE, valuePart);

    PackEaUint32(static_cast<uint32_t>(encryptSessionKey.size()), valuePart);
    valuePart.insert(valuePart.end(), encryptSessionKey.begin(), encryptSessionKey.end());

//    // 第二个子EA-TLV字段: 算法类型
//    PackEaUint32(SESSION_KEY_ALGORITHM_TYPE, valuePart);
//
//    std::string algorithmStr = "0";
//    PackEaUint32(static_cast<uint32_t>(algorithmStr.length()), valuePart);
//    valuePart.insert(valuePart.end(), algorithmStr.begin(), algorithmStr.end());

    // 构造TLV结构: type(4字节) + length(4字节) + value(valuePart)
    std::vector<uint8_t> tlvPart;

    // type字段: commandID
    PackEaUint32(ISHARE_APPLE_ECOLOGY_CCMP_ID, tlvPart);
    // length字段
    PackEaUint32(static_cast<uint32_t>(valuePart.size()), tlvPart);

    // value字段
    tlvPart.insert(tlvPart.end(), valuePart.begin(), valuePart.end());

    // 将TLV结构添加到payload
    payload.insert(payload.end(), tlvPart.begin(), tlvPart.end());

    // 使用assemblePacket方法构造完整packet，使用RSA加密标志
    AssemblePacket(payload, packet, RSA_PUBLIC_ENCRYPTION_FLAG);
}

bool ShareManager::ParseAESKeyHandShakeReq(const std::vector<uint8_t> &payload, std::vector<uint8_t> &salt, std::vector<uint8_t> &aesKey)
{
    uint32_t offset = 0;
    uint32_t commandId = ParseEaUint32(payload, offset);
    if (commandId != GET_AES_KEY) {
        return false;
    }
    uint32_t length = ParseEaUint32(payload, offset);
    // 随机数应该是48字节 (16字节randomKey + 32字节aesGcmRandomKey)
    if (length != 48) {
        return false;
    }
    salt.assign(payload.begin() + offset, payload.begin() + offset + 16);
    aesKey.assign(payload.begin() + offset + 16, payload.end());
    return true;
}

void ShareManager::PackAESKeyHandShakeReq(std::vector<uint8_t> &packet)
{
    // 生成随机数
    authMgr->GenRandomNumber(handShakeSalt, handShakeAesKey);

    // 使用对端公钥加密随机数
    std::vector<uint8_t> tempRandomKey;
    tempRandomKey.insert(tempRandomKey.end(), handShakeSalt.begin(), handShakeSalt.end());
    tempRandomKey.insert(tempRandomKey.end(), handShakeAesKey.begin(), handShakeAesKey.end());
    
    std::vector<uint8_t> payload;
    
    // 构造Value部分（两个EA-TLV字段）
    std::vector<uint8_t> valuePart;

    // 第一个子EA-TLV字段: RSA公钥或AES密钥
    PackEaUint32(GET_AES_KEY, valuePart);

    PackEaUint32(static_cast<uint32_t>(tempRandomKey.size()), valuePart);
    valuePart.insert(valuePart.end(), tempRandomKey.begin(), tempRandomKey.end());

//    // 第二个子EA-TLV字段: 算法类型
//    std::string algorithmStr = "0";
//    PackEaUint32(SESSION_KEY_ALGORITHM_TYPE, valuePart);
//
//    PackEaUint32(static_cast<uint32_t>(algorithmStr.length()), valuePart);
//    valuePart.insert(valuePart.end(), algorithmStr.begin(), algorithmStr.end());

    // 构造TLV结构: type(4字节) + length(4字节) + value(valuePart)
    std::vector<uint8_t> tlvPart;

    // type字段: commandID
    PackEaUint32(ISHARE_APPLE_ECOLOGY_CCMP_ID, tlvPart);

    // length字段
    PackEaUint32(static_cast<uint32_t>(valuePart.size()), tlvPart);

    // value字段
    tlvPart.insert(tlvPart.end(), valuePart.begin(), valuePart.end());

    // 将TLV结构添加到payload
    payload.insert(payload.end(), tlvPart.begin(), tlvPart.end());

    // 使用assemblePacket方法构造完整packet，使用RSA加密标志
    AssemblePacket(payload, packet, RSA_PUBLIC_ENCRYPTION_FLAG);
}

bool ShareManager::ParseAESKeyHandShakeRsp(const std::vector<uint8_t> &payload)
{
    uint32_t offset = 0;
    uint32_t commandId = ParseEaUint32(payload, offset);
    if (commandId != GET_AES_KEY_RESPONSE) {
        return false;;
    }
    uint32_t length = ParseEaUint32(payload, offset);
    // 将rsaPublicKey转换为vector<uint8_t>
    std::vector<uint8_t> onceDecryptedSessionKey(payload.begin() + offset, payload.begin() + offset + length);

    return authMgr->DecryptWithAESGCM(onceDecryptedSessionKey, handShakeAesKey, handShakeSalt, sessionKey);
}

// 将包头和payload组合成完整的packet
void ShareManager::AssemblePacket(const std::vector<uint8_t> &payload, std::vector<uint8_t> &packet, uint32_t flag)
{
    // 构造EA-TLV格式数据
    // 16字节udidHash (使用deviceHash)
    packet.clear();
    packet.resize(HASH_KEY_LEN);
    packet.assign(hostDeviceHash.begin(), hostDeviceHash.end());

    // 4字节businessId (固定为0x01，使用EA编码)
    PackEaUint32(0x01, packet);
    // 4字节module (固定为0x65，使用EA编码)
    PackEaUint32(0x65, packet);

    // 4字节flag (根据flag设置，使用EA编码)
    PackEaUint32(static_cast<uint32_t>(flag), packet);
    // 4字节seclength (加密类型数据长度，使用EA编码)
    std::vector<uint8_t> secPayload;
    std::vector<uint8_t> salt;
    if (flag > 0) {
        PackEaUint32(0x01, secPayload);
        if (flag == RSA_PUBLIC_ENCRYPTION_FLAG) {
            salt.resize(8);
            RAND_bytes(salt.data(), 8);
        } else {
            salt.resize(16);
            RAND_bytes(salt.data(), 16);
        }
        PackEaUint32(static_cast<uint32_t>(salt.size()), secPayload);
        secPayload.insert(secPayload.end(), salt.begin(), salt.end());
    }
    PackEaUint32(static_cast<uint32_t>(secPayload.size()), packet);
    if (secPayload.size() > 0) {
        packet.insert(packet.end(), secPayload.begin(), secPayload.end());
    }
    
    // 4字节totalLength（使用EA编码）
    switch (flag) {
        case AES_256_ENCRYPTION_FLAG:
            authMgr->EncryptWithAESGCM(payload, sessionKey, salt, secPayload);
            PackEaUint32(static_cast<uint32_t>(secPayload.size()), packet);
            packet.insert(packet.end(), secPayload.begin(), secPayload.end());
            break;
        
        case RSA_PUBLIC_ENCRYPTION_FLAG:
            authMgr->EncryptWithRSA(payload, secPayload);
            PackEaUint32(static_cast<uint32_t>(secPayload.size()), packet);
            packet.insert(packet.end(), secPayload.begin(), secPayload.end());
            break;

        case NO_ENCRYPTION_FLAG:
        default:
            PackEaUint32(static_cast<uint32_t>(payload.size()), packet);
            packet.insert(packet.end(), payload.begin(), payload.end());
            break;
    }
}

bool ShareManager::SaveThumbnail(const CommonTlvInfo_t &cti)
{
    const std::string &filename = cti.strVals[0];
    const std::string &strJson = cti.strVals[1];
    if (filename.empty() || strJson.empty()) {
        LOG_ERROR_S("SaveThumbnail: invald paramter!");
        return false;
    }

    std::string content;
    try {
        // 解析字符串
        nlohmann::json json_data = nlohmann::json::parse(strJson);

        // 检查解析后是否为数组
        if (json_data.is_array()) {
            // 遍历数组中的每个元素（这里是对象）
            for (auto& element : json_data) {
                // 访问对象中的 "utd" 和 "thumbnail" 字段
                content = element["thumbnail"];
                break;
            }
        }
    } catch (const nlohmann::json::exception& e) {
        LOG_ERROR_S("JSON parsing error: %s", e.what());
        return false;
    } catch (const std::exception& e) {
        LOG_ERROR_S("error: %s", e.what());
        return false;
    }

    size_t pos = content.find("base64");
    if (pos != std::string::npos) {
        // base64 decode
        pos = content.find(",");
        if (pos == std::string::npos) {
            LOG_ERROR_S("SaveThumbnail:  , not found!");
            return false;
        }
        std::string strBase64 = content.substr(pos + 1);

        NSString *thumb = [NSString stringWithUTF8String:strBase64.c_str()];
        if ([delegateMgr.transDelegate respondsToSelector:@selector(didRecvThumb:)]) {
            [delegateMgr.transDelegate didRecvThumb:thumb];
        }
        return true;
    }
    
    LOG_ERROR_S("SaveThumbnail: not base64 encode");
    return false;
}

bool ShareManager::SaveTimeInfo(const CommonTlvInfo_t &cti)
{
    std::string timeJson = cti.strVals[2];
    if (timeJson.empty()) {
        LOG_DEBUG_S("SaveTimeInfo: no time info, ignore this message, it will go to filemanager save");
        return false;
    }
    NSString *timeInfo = [NSString stringWithUTF8String:timeJson.c_str()];
    if ([delegateMgr.transDelegate respondsToSelector:@selector(didRecvTime:)]) {
        [delegateMgr.transDelegate didRecvTime:timeInfo];
    }
    return true;
}

bool ShareManager::SaveAvatar(const std::string &udid, const std::string &hwid, const std::string &avatarData)
{
    NSString *avatar = [NSString stringWithUTF8String:avatarData.c_str()];
    NSString *udidStr = [NSString stringWithUTF8String:udid.c_str()];
    NSString *hwidStr = [NSString stringWithUTF8String:hwid.c_str()];
    if ([delegateMgr.transDelegate respondsToSelector:@selector(didRecvAvatar:hwid:avatar:)]) {
        [delegateMgr.transDelegate didRecvAvatar:udidStr hwid:hwidStr avatar:avatar];
    }
    return true;
}

void ShareManager::UpdateProgress()
{
    NSMutableDictionary *statDict = [NSMutableDictionary dictionary];
    [statDict setValue:[NSNumber numberWithLongLong:bytesTransferred] forKey:@"totalTransfer"];
    [statDict setValue:[NSNumber numberWithLongLong:totalBytes] forKey:@"totalBytes"];
    std::lock_guard<std::mutex> fileLock(fileListMutex);
    std::string currentFileList = recvFileList.dump();
    recvFileList.clear();
    if (!currentFileList.empty()) {
        NSString *fileListString = [NSString stringWithUTF8String:currentFileList.c_str()];
        if (fileListString) {
            [statDict setValue:fileListString forKey:@"fileList"];
        } else {
            [statDict setValue:@"" forKey:@"fileList"];
        }
    } else {
        [statDict setValue:@"" forKey:@"fileList"];
    }
    LOG_DEBUG_S("currentPercent = %f", currentPercent.load());
    if ([delegateMgr.transDelegate respondsToSelector:@selector(didUpdateProgress:percent:stat:)] && currentPercent != 0.0) {
        NSString *udidString = [NSString stringWithUTF8String:sharingUdid.c_str()];
        [delegateMgr.transDelegate didUpdateProgress:udidString percent:currentPercent stat:statDict];
    }
}

void ShareManager::GetFileList(std::multimap<std::string, TransFileInfo> &fileLists)
{
    if (fileLists.empty()) {
        return;
    }
    std::lock_guard<std::mutex> fileLock(fileListMutex);
    for (auto it = fileLists.begin(); it != fileLists.end(); ++it) {
            if ((it == fileLists.begin() && !it->second.sended) || (it->second.isFinish && !it->second.sended)) {
                nlohmann::json j;
                j["filename"] = it->first;
                j["status"] = "completed";
                it->second.sended = true;
                recvFileList.push_back(j);
            }
    }
}

//void ShareManager::ConnectWiFiTimeout()
//{
//    dispatch_async(dispatch_get_main_queue(), ^{
////        if (thiz == nullptr) {
////            LOG_ERROR_S("wrong parameter");
////            return;
////        }
//        if (ShareManager::shared().connectWifiTimer >= 0) {
//            ShareManager::shared().connectWifiTimer = -1;
//            ShareManager::shared().ConnectToWiFi(ShareManager::shared().peerSSID,
//                                                 ShareManager::shared().peerPSK);
//        }
//    });
//}

void ShareManager::DisconnectWiFiTimeout()
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (ShareManager::shared().disconnectWifiTimer >= 0) {
            ShareManager::shared().disconnectWifiTimer = -1;
            ShareManager::shared().HandleDisconnect();
        }
    });
}

void ShareManager::DisconnectCheckTimeout()
{
    dispatch_sync(dispatch_get_main_queue(), ^{
        if (ShareManager::shared().disconnectCheckTimer >= 0) {
            ShareManager::shared().disconnectCheckTimer = -1;
            NetworkManager *mgr = ShareManager::shared().networkMgr;
            if (mgr != nil && ShareManager::shared().state >= SHARE_CONNECTED && (![mgr IsConnected]
                || ShareManager::shared().currentSSID != ShareManager::shared().peerSSID)) {
                ShareManager::shared().OnShareComplete(ShareManager::shared().sharingUdid, SHARE_ERROR_WIFI, ERROR_WIFI_DISCONNECT_CHECK_TIMEOUT);
            }
        }
    });
}

void ShareManager::GetIPTimeout()
{
    std::string ip = "";
    std::string netmask = "";
    std::string broadcastIp = "";
    std::string peerIP = ShareManager::shared().peerIP;
    std::string ipv6 = "";
    std::string ipv6Prefix = "";
    std::string macAddr = "";
    bool hasIp = false;
    if (ShareManager::shared().getIPTimer >= 0) {
        ip = peerIP;
        if (GetLocalWifiIPAddr(ip, netmask, broadcastIp, ipv6, ipv6Prefix, macAddr, 0)) {
            ShareManager::shared().currentIP = ip;
            ShareManager::shared().currentNetmask = netmask;
            ShareManager::shared().currentIPV6 = ipv6;
            ShareManager::shared().currentIPV6Prefix = ipv6Prefix;
            ShareManager::shared().currentMacAddr = macAddr;
            hasIp = true;
        }
    }

    if (!hasIp) {
//        LOG_ERROR_S("can't get local ip!");
        ShareManager::shared().getIPTimeout = true;
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if (ShareManager::shared().getIPTimer >= 0) {
            LOG_DEBUG_S("send ip by timer: %d", ShareManager::shared().state);
            ShareManager::shared().SendWifiInfo(ip, ipv6);
        }
    });
}

void ShareManager::ShareTimeout()
{
    dispatch_async(dispatch_get_main_queue(), ^{
//        if (thiz == nullptr) {
//            LOG_ERROR_S("wrong parameter");
//            return;
//        }
        if (ShareManager::shared().sharingUdid == "") {
            ShareManager::shared().sharingUdid = ShareManager::shared().timerUdid;
        }
        std::string udid = ShareManager::shared().sharingUdid;
        if (udid != "") {
            if (ShareManager::shared().timerTaskList.find(udid) != ShareManager::shared().timerTaskList.end()) {
                ShareManager::shared().OnShareComplete(udid, SHARE_ERROR_TIMEOUT, ERROR_TIMEOUT);
            }
        }
    });
}

void ShareManager::CancelShareTimeout()
{
    dispatch_async(dispatch_get_main_queue(), ^{
//        if (thiz == nullptr) {
//            LOG_ERROR_S("wrong parameter");
//            return;
//        }
        std::string udid = ShareManager::shared().sharingUdid;
        if (ShareManager::shared().cancelTimer >= 0) {
            ShareManager::shared().OnShareComplete(udid, SHARE_CANCEL_SELF, CANCEL_SELF_CANCEL_INPROGRESS);
            ShareManager::shared().cancelTimer = -1;
        }
    });
};

void ShareManager::SendShareEvent(ShareResult result, int errCode)
{
    if (result == SHARE_SUCCESS) {
        if (shareSuccessTimer >= 0) {
            timerQueue.cancelTask(shareSuccessTimer);
            shareSuccessTimer = -1;
        }
        if (state < SHARE_COMPLETING) {
            int timeout = 1500;
            sendCompleteTime = GetCurrentTime();
            SetShareState(SHARE_COMPLETING);
            shareSuccessTimer = timerQueue.addTask(timeout, 1, ShareSuccessTimeout);
        } else {
            LOG_DEBUG_S("share has been completed, ignore success");
        }
    } else if (result == SHARE_ERROR_BYTE_CHANNEL) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            LOG_DEBUG_S("byte channel closed, current state: %d", state);
            if (state >= SHARE_CONNECTED && state < SHARE_COMPLETING) {
                OnShareComplete(sharingUdid, SHARE_ERROR_BYTE_CHANNEL, errCode);
            }
        });
    } else {
        if (state == SHARE_COMPLETING) {
            result = SHARE_SUCCESS;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            OnShareComplete(sharingUdid, result, errCode);
        });
    }
}

void ShareManager::ShareSuccessTimeout()
{
    dispatch_async(dispatch_get_main_queue(), ^{
//        if (thiz == nullptr) {
//            LOG_ERROR_S("wrong parameter");
//            return;
//        }
        std::string udid = ShareManager::shared().sharingUdid;
        if (ShareManager::shared().shareSuccessTimer >= 0) {
            ShareManager::shared().OnShareComplete(udid, SHARE_SUCCESS, SUCCESS);
            ShareManager::shared().shareSuccessTimer = -1;
        }
    });
}

void ShareManager::SendSharePercent()
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (ShareManager::shared().sendPercentTimer >= 0) {
            if (!ShareManager::shared().isSender) {
                std::vector<uint8_t> payload;
                std::vector<uint8_t> packet;
                PackRecvPercentPayload(ShareManager::shared().currentPercent, payload);
                ShareManager::shared().AssemblePacket(payload, packet, AES_256_ENCRYPTION_FLAG);
                ShareManager::shared().connectMgr->SendData(ShareManager::shared().sharingUdid, packet);
                ShareManager::shared().UpdateProgress();
            }
        }
    });
}

void ShareManager::UpdateChannel(const std::string &udid, const std::string &channelId)
{
    if (!isInit) {
        return;
    }
    connectMgr->UpdateChannel(udid, channelId);
}

void ShareManager::KeepAlive()
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (ShareManager::shared().keepAliveTimer >= 0) {
            std::vector<uint8_t> payload;
            std::vector<uint8_t> packet;
            PackKeepAlive(payload);
            ShareManager::shared().AssemblePacket(payload, packet, AES_256_ENCRYPTION_FLAG);
            ShareManager::shared().connectMgr->SendData(ShareManager::shared().sharingUdid, packet);
            LOG_DEBUG_S("Keep alive invoked");
        }
    });
}

void ShareManager::SetShareState(ShareState newState)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    LOG_DEBUG_S("state: %d -> %d", state, newState);
    state = newState;
}

std::string ShareManager::GetDeviceId()
{
    uint16_t temp1 = GetDeviceId(0);
    uint16_t temp2 = GetDeviceId(1);
    uint16_t temp3 = GetDeviceId(2);

    std::ostringstream oss;
    oss << std::hex << std::setfill('0')
        << std::setw(4) << temp1
        << std::setw(4) << temp2
        << std::setw(4) << temp3;
    
    return oss.str();
}

void ShareManager::SendDfxReport(ShareResult result, int errCode)
{
    if (!isInit) {
        LOG_ERROR_S("not yet init");
        return;
    }
    long long freeSpace = GetFreeDiskSpace();
    char buffer[32];
    snprintf(buffer, sizeof(buffer), "%.2f", freeSpace / (1024.0 * 1024.0 * 1024.0));
    std::string freeSpaceGB = std::string(buffer) + "GB";
    uint64_t completeTime = GetCurrentTime();
    uint64_t transferTimeMs = 0;
    if (fileChannelTime > 0 && completeTime >= fileChannelTime) {
        transferTimeMs = completeTime - fileChannelTime;
    }
    uint64_t tSeconds = transferTimeMs / 1000;
    uint64_t tHours = tSeconds / 3600;
    uint64_t tMinutes = (tSeconds % 3600) / 60;
    uint64_t tSecs = tSeconds % 60;
    char transferTimeStr[32];
    snprintf(transferTimeStr, sizeof(transferTimeStr), "%02llu:%02llu:%02llu", tHours, tMinutes, tSecs);

    uint64_t shareTimeMs = 0;
    if (shareStartTime > 0 && completeTime >= shareStartTime) {
        shareTimeMs = completeTime - shareStartTime;
    }
    uint64_t sSeconds = shareTimeMs / 1000;
    uint64_t sHours = sSeconds / 3600;
    uint64_t sMinutes = (sSeconds % 3600) / 60;
    uint64_t sSecs = sSeconds % 60;
    char shareTimeStr[32];
    snprintf(shareTimeStr, sizeof(shareTimeStr), "%02llu:%02llu:%02llu", sHours, sMinutes, sSecs);

    nlohmann::json report;
    report["device_id"] = GetDeviceId();
#if TARGET_OS_IOS
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        report["device_type"] = "iPad";
    } else {
        report["device_type"] = "iPhone";
    }
#elif TARGET_OS_MAC
    report["device_type"] = "iMac";
#endif
    report["peer_deviceId"] = sharingUdid;
    report["connect_type"] = connectMgr->GetChannelType(sharingUdid);
    report["device_model"] = GetDeviceModel();
    report["os_version"] = GetOSVersion();
    report["app_version"] = GetAppVersion();
    report["type"] = isSender ? "send" : "recv";
    report["sendType"] = shareInfo.sendType;
    report["total_size"] = shareInfo.totalSize;
    report["preview_summary"] = shareInfo.previewSummary;
    report["pages_count"] = pagesCount;
    report["numbers_count"] = numbersCount;
    report["keynote_count"] = keynoteCount;
    report["shot_gap_days"] = shotGapDays;
    report["wifi_last_ssid"] = lastSSID;
    report["wifi_conn_ssid"] = currentSSID;
    report["wifi_target_ssid"] = peerSSID;
    report["peer_ip"] = AnonymizeIP(peerIP);
    report["local_ip"] = AnonymizeIP(currentIP);
    report["network_err"] = networkErrCode;
    report["ble_err"] = bleErrCode;
    report["ble_uuid"] = sharingChannelId;
    report["start_time"] = shareStartTime;
    if (bleConnectedTime == 0) {
        report["ble_time"] = shareStartTime;
    } else {
        report["ble_time"] = bleConnectedTime;
    }
    report["preview_time"] = showPreviewTime;
    report["network_time"] = showNetworkTime;
    report["sendip_time"] = sendIPTime;
    report["byteChannel_time"] = byteChannelTime;
    report["fileChannel_time"] = fileChannelTime;
    report["sendComplete_time"] = sendCompleteTime;
    report["share_rate"] = shareRate;
    report["share_size"] = shareSize;
    report["free_space"] = freeSpaceGB;
    report["system_share"] = shareType;
    report["transfer_time"] = transferTimeStr;
    report["share_time"] = shareTimeStr;
    report["enter_background_count"] = enterBackgroundCount;
    report["complete_time"] = completeTime;
    report["error_file_url"] = errorFileUrl;
    if (result == SHARE_SUCCESS) {
        report["result"] = "succeed";
        report["err_code"] = 0;
        report["min_err_code"] = 0;
    } else if (result >= SHARE_REJECT_SELF && result <= SHARE_CANCEL_PEER_BUSY) {
        report["result"] = "cancel";
        report["err_code"] = result;
        report["min_err_code"] = 0;
    } else if (result == SHARE_ERROR_BLE || result == SHARE_BLE_LTK || (result == SHARE_ERROR_TRANS_SELF && errCode == ERROR_TRANS_SELF_OPEN_FILEURL_EMPTY) || result == SHARE_ERROR_NOSPACE || result == SHARE_HOTSPOT_ENABLED || result == SHARE_BROADCAST_FAIL) {
        report["result"] = "ignore";
        report["err_code"] = result;
        report["min_err_code"] = errCode;
    } else {
        report["result"] = "fail";
        if (result == SHARE_ERROR_WIFI && networkErrCode == ERRCODE_USER_DECLINE_TO_JOIN_WIFI_NETWORK) {
            report["result"] = "cancel";
        }
        report["err_code"] = result;
        report["min_err_code"] = errCode;
    }
    NSString *dfxLog = [NSString stringWithUTF8String:report.dump().c_str()];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([delegateMgr.dfxDelegate respondsToSelector:@selector(dfxReport:)]) {
            [delegateMgr.dfxDelegate dfxReport:dfxLog];
        }
    });

    lastSSID = "";
    networkErrCode = 0;
    bleErrCode = 0;
    shareStartTime = 0;
    bleConnectedTime = 0;
    showPreviewTime = 0;
    showNetworkTime = 0;
    sendIPTime = 0;
    byteChannelTime = 0;
    fileChannelTime = 0;
    sendCompleteTime = 0;
}



void ShareManager::OnBroadcastFail()
{
    dispatch_async(dispatch_get_main_queue(), ^{
        ShareManager::shared().SendDfxReport(SHARE_BROADCAST_FAIL, ERROR_BROADCAST_FAIL);
    });
}

uint64_t ShareManager::GetCurrentTime()
{
    auto now = std::chrono::system_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch());
    return static_cast<uint64_t>(duration.count());
}

std::string ShareManager::GetDeviceModel()
{
    struct utsname systemInfo;
    uname(&systemInfo);
    return std::string(systemInfo.machine);
}

std::string ShareManager::GetOSVersion()
{
    NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
    NSString *versionString = [NSString stringWithFormat:@"%ld.%ld.%ld",
                              (long)version.majorVersion,
                              (long)version.minorVersion,
                              (long)version.patchVersion];
    return std::string([versionString UTF8String]);
}

std::string ShareManager::GetAppVersion()
{
    NSString *appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    NSString *buildString = [infoDictionary objectForKey:@"CFBundleVersion"];
    std::string versionStr = std::string([appVersion UTF8String]);
    std::string buildVersion = [buildString UTF8String];
    size_t dotCount = std::count(versionStr.begin(), versionStr.end(), '.');
    if (dotCount == 1) {
        versionStr = versionStr + ".0";
    }
    versionStr = versionStr + "." + buildVersion;
    return versionStr;
}

bool ShareManager::VerifyIP(const std::string &gwip)
{
    return IsInSameNetwork(currentIP, currentNetmask, gwip);
}

std::string ShareManager::GetGatewayIP()
{
    std::string gwIP = currentIP;
    if (gwIP.rfind(".") == std::string::npos) {
        return "";
    }
    gwIP = gwIP.substr(0, gwIP.rfind(".")) + ".1";
    return gwIP;
}

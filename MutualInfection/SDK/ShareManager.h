////
////  Share.h
////  MutualInfection
////
////  Created by apple on 2025/9/4.
////
//
#ifndef SHARE_MANAGER_H
#define SHARE_MANAGER_H

#include <map>
#include <memory>
#include <mutex>
#include <queue>
#include <string>
#include <vector>
#include "ConnectManager.h"
#include "AuthManager.h"
#include "TransManager.h"
#include "DeviceManager.h"
#import "NetworkManager.h"
#import "DelegateManager.h"
#include "Timer.h"

#define ERRCODE_USER_DECLINE_TO_JOIN_WIFI_NETWORK (7)
#define ERRCODE_WIFI_NETWORK_INTERNAL_ERROR (8)
#define ERRCODE_WIFI_NOT_MATCH_SSID (1000)

typedef std::map<std::string, std::string> ShareNode;
typedef std::map<int16_t, ShareNode> ShareList;
typedef std::queue<int16_t> ShareSessionList;

typedef enum {
    SHARE_IDLE,
    SHARE_STARTED,
    SHARE_AUTHCHANNEL_OPENED,
    SHARE_JOIN_WIFI,
    SHARE_DISCONNECTED,
    SHARE_CONNECTED,
//    SHARE_RECVING,
//    SHARE_SENDING,
//    SHARE_NETWORK_CONNECTED,
    SHARE_COMPLETING,
    SHARE_BUTT,
} ShareState;

typedef enum {
    RECV_FILE_START,
    RECV_FILE_END,
    SEND_FILE_START,
    SEND_FILE_END,
    TRANS_FILE_BUTT,
} TransFileStatus;

typedef enum {
    TRANS_CONNECTED,
    TRANS_RECV_FILE_LIST,
    TRANS_BUTT,
} TransStatus;

typedef enum {
    SHARE_SUCCESS,
    SHARE_REJECT_SELF,
    SHARE_REJECT_PEER,
    SHARE_CANCEL_SELF,
    SHARE_CANCEL_PEER,
    SHARE_CANCEL_PEER_BUSY,
    SHARE_ERROR_TIMEOUT,
    SHARE_ERROR_TRANS_SELF,
    SHARE_ERROR_TRANS_PEER,
    SHARE_ERROR_BYTE_CHANNEL,
    SHARE_ERROR_WIFI,
    SHARE_ERROR_BLE,
    SHARE_ERROR_BLE_ADD_SERVICE,
    SHARE_COMPLETED_FORCE,
    SHARE_ERROR_NOSPACE,
    SHARE_HOTSPOT_ENABLED,
    SHARE_BLE_TIMEOUT,
    SHARE_BLE_LTK,
    SHARE_ERROR_TCP_TIMEOUT,
    SHARE_BROADCAST_FAIL,
    SHARE_GET_IP_TIMEOUT,
    SHARE_RESULT_BUTT,
} ShareResult;

typedef enum {
    SUCCESS = 0,
    REJECT_SELF = 10000,
    REJECT_PEER = 20000,
    CANCEL_SELF_RECEIVE_CANCEL = 30000,
    CANCEL_SELF_CANCEL_INPROGRESS = 30001,
    CANCEL_PEER_SEND_CANCEL = 40000,
    CANCEL_PEER_CANCEL_INPROGRESS = 40001,
    CANCEL_PEER_BUSY = 50000,
    ERROR_TIMEOUT = 60000,
    ERROR_TRANS_SELF_ERROR = 70000,//+1000 indicates the presence of an DFile error code, +2000 indicates the presence of an file open error code, +3000 indicates the presence of an TCP send error code.
    ERROR_TRANS_SELF_AUTH_DISCONNECT = 70001,
    ERROR_TRANS_SELF_FILE_CHANNEL_OPEN_FAILED = 70002,
    ERROR_TRANS_SELF_PARSE_BIND_BYTES_ACK_FAILED = 70004,
    ERROR_TRANS_SELF_OPEN_FILEURL_EMPTY = 70005,
    ERROR_TRANS_PEER = 80000,
    ERROR_BYTE_CHANNEL_P2P_FAILED = 90000,//+5000 indicates an IP error, and +1000 indicates the presence of an error code.
    ERROR_BYTE_CHANNEL_CONNECTION_CLOSED = 90001,
    ERROR_WIFI_DISCONNECT = 100000,
    ERROR_WIFI_DISCONNECT_CHECK_TIMEOUT = 100001,
    ERROR_WIFI_CONNECTING_ERROR = 100002,
    ERROR_BLE_POWER_OFF = 110000,
    ERROR_BLE_UNSUBSCRIBE = 110001,
    ERROR_BLE_ADD_SERVICE = 120000,
    ERROR_COMPLETED_FORCE = 130000,
    ERROR_NOSPACE_SELF = 140000,
    ERROR_NOSPACE_PEER = 140001,
    ERROR_HOTSPOT_ENABLED = 150000,
    ERROR_BLE_TIMEOUT = 160000,//+1000 indicates the presence of an error code.
    ERROR_BLE_LTK = 170000,
    ERROR_TCP_TIMEOUT = 180000,//+1000 indicates the presence of an error code.
    ERROR_BROADCAST_FAIL = 190000,
    ERROR_GET_IP_TIMEOUT = 200000,
} ShareCode;

class ShareManager
{
public:
    static ShareManager &shared();
    bool Initialize();
    void Finalize();

    int16_t ShareFiles(const std::string &udid, ShareNode &node);
    void CancelSender(const std::string &udid);
    void CancelReceiver(const std::string &udid);
    void SendFiles(const std::string &udid, std::vector<TransFileInfo> files);
    void TraverseFolder(NSURL *folderURL, std::multimap<std::string, TransFileInfo> &fileList, const TransFileInfo &parentFolderInfo, const std::string &basePath);
    void AcceptRequest(const std::string &udid);

    void OnBleConnect(const std::string &channelId, const std::string &udid);
    void OnBleDisconnect(const std::string &channelId, const std::string &udid);
    void OnAuthChannelConnect(const AuthChannel &channel, bool isSender);
    void OnAuthChannelDisConnect(const AuthChannel &channel, bool isSender);
    void OnByteChannelOpen();
    void OnByteChanelClose();
    void OnFileChannelOpen(const std::string &ip, uint16_t port, bool isServer);
    void OnFileChannelClose();
    void OnNetworkDisconnect();
    void OnNetworkConnect(int code, const std::map<std::string, std::string> network);
    void OnNetworkError(long errcode);
    std::string OnFileTransStatus(TransFileStatus status, const std::string &file, uint64_t fileSize = 0);
    void OnTransStatus(TransStatus status, const DFileMsg *msg);

    void OnSharePercent(double percent, const DFileMsg *msg, std::multimap<std::string, TransFileInfo> &fileList, uint64_t currentSize);
    void OnShareReject(bool isSelf);
    void OnShareCancel(bool isSelf);
    void OnShareCancelSelf(const std::string &udid);
    void OnShareStart(const std::string &channelId, const std::string &udid);
    void OnShareComplete(const std::string &udid, ShareResult result, int errCode);
    void SendShareEvent(ShareResult result, int errCode);

    bool OnRecvPacket(const std::string &udid, const std::vector<uint8_t> &packet, std::vector<uint8_t> &response);
    
    bool HandleBLE(const std::string &channelId, const std::vector<uint8_t> &packet, bool isSender);
    bool HandleTcp(const std::string &channelId, const std::vector<uint8_t> &packet);

    bool EncryptWithAESGCM(const std::vector<uint8_t> &data, const std::vector<uint8_t> &nonce, std::vector<uint8_t> &ciphertext);
    bool DecryptWithAESGCM(const std::vector<uint8_t> &data, const std::vector<uint8_t> &nonce, std::vector<uint8_t> &plaintext);
    void GetByteSessionKey(std::vector<uint8_t> &sessionKey);
    void SetByteSessionKey(const std::vector<uint8_t> &sessionKey);
    void GetDFileSessionKey(std::vector<uint8_t> &sessionKey);
    void SetDFileSessionKey(const std::vector<uint8_t> &sessionKey);
    
    uint16_t GetDeviceId(int index);
    void SendWifiInfo(const std::string &ip, const std::string &ipv6);
    void SendNotEnoughSpace();
    void SendHotspotNoti();
    void SendTransError(void);
    void SendFilePreview(const std::vector<TransFileInfo> &files);
    std::string GetNewFileName(const std::string &fileName, const std::multimap<std::string, TransFileInfo> &fileList);
    static std::string truncateStringByBytes(const std::string &str, size_t maxBytes);
    std::string GetLocalIP() const { return currentIP; }
    
//    bool IsCompleted() const { return savedResult != SHARE_RESULT_BUTT; }
//    void HandlePostComplete();
    void UpdateChannel(const std::string &udid, const std::string &channelId);
    bool IsBleConnected(const std::string &channelId);
    void RefreshNetwork();
    std::string GetDeviceId();
    void FastFetchIP();
    bool VerifyIP(const std::string &gwip);
    std::string GetGatewayIP();
    // H侧蓝牙主动断开/异常断开回调
    void OnBleUnsubscribe(const std::string &uuid);

    void DelayRefreshNetwork();
    void SetShareRate(int rate);
    void SetShareSize(long long size);
    void SetShareType(const std::string &sharedType);
    void SetEnterBackgroundCountIncrement(int count);
    void SetErrorFileUrl(const std::string &fileUrl);
    void SetIWorkCount(int pages, int numbers, int keynote);

    std::string GetPeerIP();
    
    void OnBroadcastFail();

private:
    uint32_t ParseEaUint32(const std::vector<uint8_t> &data, unsigned int &offset);
    void PackEaUint32(uint32_t value, std::vector<uint8_t> &packet);
    void BuildMetaPayload(int type, std::vector<uint8_t> &payload);
    bool ParseCompetencyNego(const std::vector<uint8_t> &payload);
    void PackCompetencyNego(uint32_t commandId, std::vector<uint8_t> &packet);
    
    void PackPubKeyHandShake(uint32_t commandId, std::vector<uint8_t> &packet);
    bool ParsePubKeyHandShake(const std::vector<uint8_t> &packet);
    
    bool ParseAESKeyHandShakeReq(const std::vector<uint8_t> &payload, std::vector<uint8_t> &salt, std::vector<uint8_t> &aesKey);
    void PackAESKeyHandShakeRsp(std::vector<uint8_t> &salt, std::vector<uint8_t> &aesKey, std::vector<uint8_t> &packet);
    
    void PackAESKeyHandShakeReq(std::vector<uint8_t> &packet);
    bool ParseAESKeyHandShakeRsp(const std::vector<uint8_t> &payload);
    
    bool DecryptRandomNumber(const std::vector<uint8_t> &payload,
                             std::vector<uint8_t> &randomKey,
                             std::vector<uint8_t> &aesGcmRandomKey);
    void AssemblePacket(const std::vector<uint8_t> &payload, std::vector<uint8_t> &packet, uint32_t flag);

    bool SaveThumbnail(const CommonTlvInfo_t &cti);
    bool SaveTimeInfo(const CommonTlvInfo_t &cti);
    bool SaveAvatar(const std::string &udid, const std::string &hwid, const std::string &avatarData);
    void UpdateProgress();
    bool RejectByInRecv(const std::string &udid);
    void GetFileList(std::multimap<std::string, TransFileInfo> &fileList);
    
    bool ConnectToWiFi(const std::string &ssid, const std::string &password, int timeout);
    void HandleDisconnect();
    void SetShareState(ShareState newState);
    void SendDfxReport(ShareResult result, int errCode);
    uint64_t GetCurrentTime();
    std::string GetDeviceModel();
    std::string GetOSVersion();
    std::string GetAppVersion();
    
    static void ConnectWiFiTimeout();
    static void DisconnectWiFiTimeout();
    static void DisconnectCheckTimeout();
    static void GetIPTimeout();
    static void SendIPTimeout();
    static void ShareTimeout();
    static void CancelShareTimeout();
    static void ShareSuccessTimeout();
    static void SendSharePercent();
    static void KeepAlive();
    static void SendCheckTimeout();
    static void TmpDelayRefreshNetwork();

private:
    ShareManager();

private:
    std::recursive_mutex mutex;
    ShareList shareList;
    ShareSessionList sessionList;
    ShareNode currentShareNode;
    bool isInit { false };
    ShareState state { SHARE_IDLE };
//    bool isSharing { false };
    bool isSender { false };
    std::string shareType { "" };
    int enterBackgroundCount { 0 };
    std::string shareSessionId { "" };
//    int16_t currentSessionId { -1 };
    std::shared_ptr<AuthManager> authMgr { nullptr };
    std::shared_ptr<ConnectManager> connectMgr {nullptr };
    std::shared_ptr<TransManager> transMgr { nullptr };
    
    NetworkManager *networkMgr { nullptr };
    DelegateManager *delegateMgr { nullptr };
//    std::shared_ptr<DeviceManager> deviceMgr { nullptr };
    
    uint32_t supportSecureVersion { 1 };// 能力协商支持的版本
    uint32_t supportFileTypeAbility { 0 };// 支持的文件类型能力
    uint32_t publicKeyAlgorithmType;    // 公钥算法类型
    uint32_t sessionKeyAlgorithmType;   // 会话密钥算法类型

    std::vector<uint8_t> handShakeSalt;   // 随机数
    std::vector<uint8_t> handShakeAesKey;  // AES-GCM随机密钥
    std::vector<uint8_t> sessionKey;        // session密钥

    std::vector<uint8_t> deviceHash;
    std::string hostDeviceHash { "" };
    
    std::string currentSSID { "" };
    std::string currentBSSID { "" };
    std::string currentIP { "" };
    std::string currentIPV6 { "" };
    std::string currentIPV6Prefix { "" };
    std::string currentNetmask { "" };
    std::string currentMacAddr { "" };
    std::string savedLastSSID { "" };

    std::string peerSSID { "" };
    std::string peerPSK { "" };
    std::string peerIP { "" };
    FileShareInfo shareInfo;
    std::string shareRate { "0MB/s" };
    std::string shareSize { "" };
    std::string errorFileUrl { "" };
    std::string pagesCount { "" };
    std::string numbersCount { "" };
    std::string keynoteCount { "" };
    std::string shotGapDays { "" };

//    AuthChannel authChannel;
    std::string sharingUdid { "" };
    std::string sharingChannelId { "" };
    std::string timerUdid { "" };
    
//    bool cancelTimeout;
    bool getIPTimeout { false };
    TimerQueue timerQueue;
    std::map<std::string, int> timerTaskList;
    int cancelTimer { -1 };
    int disconnectWifiTimer { -1 };
    int disconnectCheckTimer { -1 };
//    int connectWifiTimer { -1 };
    int getIPTimer { -1 };
    int shareSuccessTimer { -1 };
    int sendPercentTimer { -1 };
    int keepAliveTimer { -1 };
    int sendCheckTimer { -1 };
    nlohmann::json recvFileList;
    std::atomic<uint64_t> bytesTransferred;
    std::atomic<uint64_t> totalBytes;
    std::atomic<double> currentPercent;

    ShareResult savedResult { SHARE_RESULT_BUTT };
    bool m_isWifiConnected = false;
    
    std::set<std::string> connectedBleList {};
    std::mutex fileListMutex;
    
    std::string lastSSID { "" };
    long networkErrCode { 0 };
    long bleErrCode { 0 };
    uint64_t shareStartTime { 0 };
    uint64_t bleConnectedTime { 0 };
    uint64_t showPreviewTime { 0 };
    uint64_t showNetworkTime { 0 };
    uint64_t sendIPTime { 0 };
    uint64_t byteChannelTime { 0 };
    uint64_t fileChannelTime { 0 };
    uint64_t sendCompleteTime { 0 };
};

#endif // SHARE_MANAGER_H

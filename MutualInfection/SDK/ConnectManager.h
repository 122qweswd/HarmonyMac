//
//  ConnectManager.h
//  MutualInfection
//
//  Created by apple on 2025/9/3.
//
#ifndef CONNECT_MANAGER_H
#define CONNECT_MANAGER_H

#include <map>
#include <set>
#include <vector>
#include "AuthChannel.h"
#include "SocketManager.h"
#include "CircularBuffer.h"

typedef enum {
    CONN_TYPE_NONE,
    CONN_TYPE_BLE,
    CONN_TYPE_TCP,
    CONN_TYPE_BUTT,
} ConnType;

typedef enum {
    CONN_IDLE,
    CONN_BASIC_INFO,
    CONN_REF_SYNC,
    CONN_AUTH_OPEN,
    CONN_SHARE,
    CONN_AUTH_META,
    CONN_VERIFY_P2P,
    CONN_BIND_BYTE,
    CONN_BIND_FILE,
    CONN_RUNNING,
    CONN_AUTH_CLOSE,
    CONN_BUTT,
} ConnectState;

const uint16_t INVALID_CHANNEL_ID = -1;

//typedef struct stChannelInfo
//{
//    PayloadBasicInfo basicInfo;
//    RefNumSync refNum;
//    NakedChannelHandshake ncsh;
//} ChannelInfo;

class ConnectManager
{
public:
    ConnectManager();
    ~ConnectManager();

    void Connect(const std::string &udid);
    void Disconnect(const std::string &uuid);
    bool HandleBLE(const std::string &channelId, const std::vector<uint8_t> &packet, bool isSender);
    bool HandleTcp(const std::string &channelId, const std::vector<uint8_t> &packet);

    void CloseFileChannel(const std::string &udid);
    void CloseProxyChannel(const std::string &udid);
    void CloseBleChannel(const std::string &udid);
    void CloseTcpChannel(const std::string &udid);
    void DecreaseRef(const std::string &udid);
    
    void SendData(const std::string &udid, const std::vector<uint8_t> &packet);
    void SendByteData(bool isSender, const std::vector<uint8_t> &packet);
    void ShareFiles(const std::string &udid, bool isHighSpeed);
    
    bool OpenAuthChannel(const std::string &udid, const std::string &channelId, uint16_t peerId = -1);
    bool GetChannel(const std::string &udid, AuthChannel &channel);
    void CloseAuthChannel(const std::string &udid);
    bool IsChannelExist(const std::string &udid);
    void UpdateChannel(const std::string &udid, const std::string &channelId);
    
    ConnType GetChannelType(const std::string &udid);
    void SendBLECachedData(const std::string &udid);

private:
    void BuildBasicInfoReq(std::vector<uint8_t> &request);
    bool HandleBasicInfoRsp(const std::vector<uint8_t> &response);
    
    bool HandleConnChannel(const std::string &channelId, const std::vector<uint8_t> &packet, std::vector<uint8_t> &response);
    bool HandleProxyChannel(const std::string &channelId, const std::vector<uint8_t> &inPacket, std::vector<uint8_t> &outPaket);
    bool HandleAuthChannel(const std::string &channelId, const std::vector<uint8_t> &inPacket, std::vector<uint8_t> &outPaket);

    bool HandleAuthChannelRsp(const std::vector<uint8_t> &packet, std::vector<uint8_t> &request);

    bool HandleRefSync(const std::vector<uint8_t> &packet, std::vector<uint8_t> &response);
    void BuildRefSyncReq(std::vector<uint8_t> &request);

    bool HandleNakedChannelNego(const std::vector<uint8_t> &packet, std::vector<uint8_t> &response);
    void BuildNakedChannelReq(std::vector<uint8_t> &request);
    bool HandleNakedChannelAck(const std::vector<uint8_t> &response);
    
    bool BuildBLEReq(ConnectState state, std::vector<uint8_t> &request);
    void BuildOwnBasicInfo(bool supportAutoSync, std::vector<uint8_t> &packet);
    void BuildRefSync(bool isAdd, std::vector<uint8_t> &packet);
    void BuildNakedChannel(uint16_t channelId, std::vector<uint8_t> &packet);
    void BuildNakedChannel(std::vector<uint8_t> &packet);
    
    bool UpdateChannel(const std::string &udid, uint16_t peerId, bool isSender);
//    bool UpdateChannel(const std::string &udid, bool isSender);
    void HandleByteData(const std::string &channelId, const std::vector<uint8_t> &data, bool isSender, int fd = -1);
    
    void SendBLEDataInner(const std::string &channelId, const std::vector<uint8_t> &packet, bool isSender, bool useFirst = false);
    
    bool IsTcpChannel(const std::string &channelId) const;
    bool IsBleChannel(const std::string &channelId) const;
    std::string GetUdidByChannel(const std::string &channelId);

private:
    uint16_t peerFileChannelId { 0 };
    uint16_t myFileChannelId { 0 };
    PayloadBasicInfo basicInfo;
    RefNumSync refNum;
    NakedChannelHandshake ncsh;
//    ConnectState state { CONN_IDLE };
    SocketManager smSrv;
    SocketManager smCli;
//    bool isSender { false };
//    std::map<std::string, AuthChannel> deviceList;
    std::map<std::string, AuthChannel> channelList;
    std::map<std::string, std::string> channelMap;
//    std::set<std::string> connectList;
    std::recursive_mutex mutex;

    bool isByteChannelOpen;
    CircularBuffer totalPacket;
    std::map<std::string, std::shared_ptr<CircularBuffer>> tcpPacketList;
//    bool hasTimeout { false };
};

#endif // CONNECT_MANAGER_H

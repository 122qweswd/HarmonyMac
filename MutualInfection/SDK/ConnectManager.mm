//
//  ConnectManager.mm
//  MutualInfection
//
//  Created by apple on 2025/9/4.
//

#include "ConnectManager.h"
#include <openssl/rand.h>
#include "Common.h"
#include "LogHelper.h"
#include "MetaNodeSerializer.h"
#include "DiscManager.h"
#include "ShareManager.h"
#include "TcpChannel.h"

static uint16_t g_MyChannelId = 1030;
static uint16_t g_FileChannelId = 0x01;
static uint32_t g_ChannelId = 0;

const uint32_t MAX_BYTE_CHANNWL = 8 * 1024 * 1024;

//typedef struct stWholePkg{
//    std::vector<uint8_t> pkg;
//    uint32_t curSize;
//    uint32_t totalSize;
//} WholePkg;
//
//static WholePkg g_wholePkg;
//
//// return values: true - received all; false - not all
//static bool RecvAllSlicePackage(uint32_t total, const std::vector<uint8_t> &pkg, std::vector<uint8_t> &all)
//{
//    static std::vector<uint8_t> recvPkg;
//    if ((recvPkg.size() + pkg.size()) < total) {
//        recvPkg.insert(recvPkg.end(), pkg.begin(), pkg.end());
//        return false;
//    }
//
//    recvPkg.insert(recvPkg.end(), pkg.begin(), pkg.end());
//
//    all = recvPkg;
//    recvPkg.clear();
//    return true;
//}
//
//static bool CheckBleIsWholePackage(std::vector<uint8_t> pkg)
//{
////    BleTransHeader *bth = (BleTransHeader *)(pkg.data());
////    bool isWholePkg = ((bth->total - ) == bth->size0) ? true:false;
////
////
////    if (!isWholePkg) {
////        g_wholePkg.total = bth->total
////        uint32_t dataSize=bth->total - sizeof(BleTransHeader);
////        if (g_wholePkg.totalSize - bth->total)
////        return true;
////    }
////
////    g_wholePkg.totalSize = bth->total;
////
////    return isWholePkg;
//    return false;
//}

ConnectManager::ConnectManager()
{
    totalPacket.SetSize(MAX_BYTE_CHANNWL);
//    TcpChannel::GetInstance()->StartListenFd();
}

ConnectManager::~ConnectManager()
{
    totalPacket.SetSize(0);
    for (auto &item : tcpPacketList) {
        item.second->SetSize(0);
    }
    tcpPacketList.clear();
}

void ConnectManager::Connect(const std::string &udid)
{
    auto channelId = DeviceManager::shared().GetDeviceUUID(udid);
    if (!OpenAuthChannel(udid, channelId)) {
        LOG_ERROR_S("Fail to allocate auth channel for connect:%s", udid.c_str());
        return;
    }
    AuthChannel channel;
    GetChannel(udid, channel);
    std::vector<uint8_t> request;
    peerFileChannelId = -1;
    myFileChannelId = -1;
    BuildOwnBasicInfo(false, request);
    SendBLEDataInner(channelId, request, true, true);

    BuildRefSync(true, request);
    SendBLEDataInner(channelId, request, true);
    
    ShareManager::shared().OnShareStart(channelId, udid);
    BuildNakedChannel(channel.myId, request);
    SendBLEDataInner(channelId, request, true);
}

void ConnectManager::Disconnect(const std::string &udid)
{
    isByteChannelOpen = false;
    totalPacket.Clear();
    smSrv.Stop();
    smCli.Stop();
}

bool ConnectManager::HandleBLE(const std::string &channelId, const std::vector<uint8_t> &packet, bool isSender)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    ConnPktHead connHdr;
    NetCtrlMsgHead netHdr;
    std::vector<uint8_t> payload(packet);
    std::vector<uint8_t> request;
    bool useFirst = false;
    if (IsConnPacket(packet)) {
        if (!ParseConnHeader(payload, connHdr)) {
            return false;
        }
        switch (connHdr.module) {
            case MODULE_CONNECTION:
                HandleConnChannel(channelId, payload, request);
                break;

            case MODULE_PROXY_CHANNEL:
                HandleProxyChannel(channelId, payload, request);
                break;

            case MODULE_META_AUTH:
                HandleAuthChannel(channelId, payload, request);
                break;

            default:
                break;
        }
    } else {
        if (!ParseNetCtrlHeader(payload, netHdr)) {
            return false;
        }
        if (!ParseBasicInfoExchange(payload, basicInfo)) {
            return false;
        }
        if (!IsChannelExist(channelId)) {
            BuildOwnBasicInfo(false, request);
            useFirst = true;
        }
    }
    SendBLEDataInner(channelId, request, isSender, useFirst);
    return true;
}

bool ConnectManager::HandleConnChannel(const std::string &channelId, const std::vector<uint8_t> &packet, std::vector<uint8_t> &response)
{
    if (!ParseRefNumSync(packet, refNum)) {
        return false;
    }
    LOG_DEBUG_S("refNum.KEY_DELTA = %d", refNum.KEY_DELTA);
    response.clear();
    return true;
}

bool ConnectManager::HandleProxyChannel(const std::string &channelId, const std::vector<uint8_t> &inPacket, std::vector<uint8_t> &outPacket)
{
    ProxyMessageHead hdr;
    NakedChannelHandshakeAck ncsha;
    std::vector<uint8_t> payload(inPacket);
    if (!ParseProxyHeader(payload, hdr)) {
        return false;
    }
    
    std::string udid = GetUdidByChannel(channelId);
    AuthChannel channel;
    bool ret = false;
    bool isBidirection = false;
    switch (hdr.TYPE) {
        case 0x10:
            if (!ShareManager::shared().OnRecvPacket(udid, payload, outPacket)) {
                return false;
            }
            if (!outPacket.empty()) {
                AuthChannel channel;
                GetChannel(udid, channel);
                channel.myId = hdr.peerId;
                channel.peerId = hdr.myId;
                PackShareHeader(channel, outPacket);
            }
            ret = true;
            break;
        case 0x11:
            if (!ParseNakedChannelHandshakeReq(payload, ncsh)) {
                NakedChannelHandshakeExcept except;
                except.ERR_CODE = -1;
                PackNakedChannelHandshakeExcept(except, hdr, outPacket);
                return true;
            }
            udid = DeviceManager::shared().GetHashStringUDID(ncsh.DEVICE_ID).substr(0, 16);
            hdr.peerId = hdr.myId;
            if (GetChannel(udid, channel) && channel.peerId != (uint16_t)-1 &&channel.isSender) {
                isBidirection = true;
                channel.myId = g_MyChannelId++;
            } else {
                OpenAuthChannel(udid, channelId, hdr.peerId);
            }
            if (!GetChannel(udid, channel)) {
                NakedChannelHandshakeExcept except;
                except.ERR_CODE = -1;
                PackNakedChannelHandshakeExcept(except, hdr, outPacket);
            } else {
                hdr.myId = channel.myId;
                ncsha.IDENTITY = ncsh.IDENTITY;
                ncsha.DEVICE_ID = ShareManager::shared().GetDeviceId();
                ncsha.PKG_NAME = ncsh.PKG_NAME;
                ncsha.MTU_SIZE =  ncsh.MTU_SIZE;
                ncsha.TRANS_CAPABILITY = 0;
                PackNakedChannelHandshakeAck(ncsha, hdr, outPacket);
                if (!isBidirection && UpdateChannel(udid, hdr.peerId, false)) {
                    ShareManager::shared().OnShareStart(channelId, udid);
                    ShareManager::shared().OnAuthChannelConnect(channel, false);
                }
            }
            break;
        case 0x12:
            if (!ParseNakedChannelHandshakeAck(payload, ncsha)) {
                NakedChannelHandshakeExcept except;
                except.ERR_CODE = -1;
                PackNakedChannelHandshakeExcept(except, hdr, outPacket);
            } else {
                if (GetChannel(udid, channel) && channel.peerId != (uint16_t)-1 && !channel.isSender) {
                    isBidirection = true;
                }
                if (!isBidirection && UpdateChannel(udid, hdr.myId, true)) {
                    GetChannel(udid, channel);
                    ShareManager::shared().OnAuthChannelConnect(channel, true);
                    ret = true;
                }
            }
            break;
        case 0x13:
            // close auth session channel
            if (GetChannel(udid, channel)) {
                ShareManager::shared().OnAuthChannelDisConnect(channel, false);
            }
            break;
        default:
            break;
    }
    return ret;
}

bool ConnectManager::HandleAuthChannel(const std::string &channelId,
                                       const std::vector<uint8_t> &inPacket,
                                       std::vector<uint8_t> &outPacket)
{
    AuthHead authHdr;
    std::vector<uint8_t> payload(inPacket);
    if (!ParseAuthHeader(payload, authHdr)) {
        return false;
    }
    
    if (payload.size() < 12) {
        return false;
    }
    
    std::string udid = GetUdidByChannel(channelId);
    AuthChannel channel;
    if (!GetChannel(udid, channel)) {
        LOG_ERROR_S("invalid udid: %s", udid.c_str());
        return false;
    }
    
    switch (authHdr.dataType) {
        case 0xFFFF0002:
            {
                DeviceInfo info;
                MetaNodeSerializer::shared().ParseDeviceInfo(payload, info);
                MetaNodeSerializer::shared().CreateDeviceInfo(outPacket);
            }
            break;

        case 0xFFFF0004:
        {
            nlohmann::json jsPacket;
            if (!ParseChannelPacket(payload, jsPacket)) {
                LOG_DEBUG_S("ParseChannelPacket failed!");
                return false;
            }
            uint16_t code = jsPacket.at("CODE").get<uint16_t>();
            if (code == 0x03) {
                VerifyP2p vp;
                if (ParseVerifyP2p(jsPacket, vp)) {
                    if (!channel.isSender) {
                        int sockfd;
                        uint16_t port;
                        if (GetRandomPortAndSockfd(port, sockfd) != 0) {
                            LOG_DEBUG_S("GetRandomPortAndSockfd failed!");
                            return false;
                        }
                        
                        vp.CODE = 0x03;
                        vp.P2P_IP = ShareManager::shared().GetLocalIP();
                        vp.P2P_PORT = port;
                        vp.PROTOCOL_TYPE = 0x04;
                        // 1 启动tcp server
                        std::string anoIP = AnonymizeIP(vp.P2P_IP);
                        LOG_DEBUG_S("StartListen %s:%u......", anoIP.c_str(), vp.P2P_PORT);
                        smSrv.StartListenFd(sockfd, [=, this](const std::vector<uint8_t>& data, int clientFd) {
                            this->HandleByteData(channelId, data, false, clientFd);
                        }, true, true);
                        PacketVerifyP2p(vp, outPacket);
                        authHdr.flag = 0x01;
                    } else {
                        int errCode = ERROR_BYTE_CHANNEL_P2P_FAILED;
                        if (!ShareManager::shared().VerifyIP(vp.P2P_IP)) {
                            LOG_ERROR_S("get default gw ip");
                            vp.P2P_IP = ShareManager::shared().GetGatewayIP();
                            errCode += 5000;
                        }
                        std::string anoIP = AnonymizeIP(vp.P2P_IP);
                        LOG_DEBUG_S("P2P_IP: %s", anoIP.c_str());
                        LOG_DEBUG_S("P2P_PORT: %d", vp.P2P_PORT);
                        bool ret = false;
                        int retry = 0;
                        int errnoCode = 0;
                        do {
                            ret = smCli.StartConnect(vp.P2P_IP, vp.P2P_PORT, [=, this](const std::vector<uint8_t>& data, int clientFd) {        this->HandleByteData(channelId, data, true);
                            }, errnoCode);
                            if (ret || ++retry >= 11) {
                                break;
                            }
                            // usleep(200 * 1000);
                        } while (true);
                        if (!ret) {
                            LOG_DEBUG_S("Connect P2P server failed!");
                            errCode = errCode + errnoCode + 1000;
                            if (errnoCode == 65) {
                                errCode += 1000;
                            }
                            ShareManager::shared().OnShareComplete(udid, SHARE_ERROR_BYTE_CHANNEL, errCode);
                            return false;
                        }
                        
                        BytesChannelHandshake bbsh;
                        bbsh.CODE = 1;
                        bbsh.API_VERSION = 2;
                        bbsh.DEVICE_ID = ShareManager::shared().GetDeviceId();
                        bbsh.BUS_NAME = "IShareReceiverBytesSession";
                        bbsh.CLIENT_BUS_NAME = "IShareSenderBytesSession";
                        bbsh.TRANS_CAPABILITY = 0;
                        bbsh.MTU_SIZE = 4194304;
                        bbsh.PKG_NAME = "ohos.InterConnection.iShare";
                        bbsh.ROUTE_TYPE = 0x02;
                        bbsh.BUSINESS_TYPE = 0x01;
                        bbsh.TRANS_FLAGS = 0x02;
                        PackBindBytesSessionHandshake(bbsh, payload);
                        
                        TdcPacketHead tdcHdr;
                        tdcHdr.magicNumber = MAGIC_NUMBER;
                        tdcHdr.module = 0x06;
                        RAND_bytes((unsigned char*)(&tdcHdr.seq), 8);
                        tdcHdr.flags = 148;
                        tdcHdr.dataLen = static_cast<uint32_t>(payload.size());
                        std::vector<uint8_t> tdcPacket;
                        PackTdcHeader(payload, tdcHdr, tdcPacket);
                        ssize_t send_size = smCli.send(tdcPacket);
                        LOG_DEBUG_S("smCli.send %ld", send_size);
                    }
                }
            } else if (code == 0x0602) {
                if (!channel.isSender) {
                    if (jsPacket.contains("CHANNEL_TYPE")) {
                        uint8_t channelType = jsPacket.at("CHANNEL_TYPE").get<uint8_t>();
                        if (channelType == 0x01) {
                            FileChannelOpenHandshake bfsho;
                            FileChannelOpenHandshakeAck bfshoa;
                            if (!ParseBindFileSessionHandshakeOpen(jsPacket, bfsho)) {
                                return false;
                            }
                            
                            // payload
                            uint16_t port = GetRandomPort();
                            std::string ip = ShareManager::shared().GetLocalIP();
                            ShareManager::shared().OnFileChannelOpen(ip, port, true);
                            bfshoa.MY_CHANNEL_ID = bfsho.MY_CHANNEL_ID;
                            bfshoa.P2P_PORT = port;
                            bfshoa.MY_IP = ip;
                            bfshoa.CODE = bfsho.CODE;
                            bfshoa.PKG_NAME = bfsho.PKG_NAME;
                            bfshoa.BUSINESS_TYPE = bfsho.BUSINESS_TYPE;
                            bfshoa.STREAM_TYPE = bfsho.STREAM_TYPE;
                            bfshoa.API_VERSION = bfsho.API_VERSION;
                            bfshoa.TRANS_CAPABILITY = bfsho.TRANS_CAPABILITY;
                            PackBindFileSessionHandshakeOpenAck(bfshoa, outPacket);
                            authHdr.flag = 0x01;
                        } else if (channelType == 0x02) {
                            FileChannelCloseHandshake bfshc;
                            FileChannelCloseHandshakeAck bfshca;
                            if (!ParseBindFileSessionHandshakeClose(jsPacket, bfshc)) {
                                return false;
                            }
                            // payload
                            bfshca.CODE = bfshc.CODE;
                            bfshca.PKG_NAME = bfshc.PKG_NAME;
                            bfshca.BUSINESS_TYPE = bfshc.BUSINESS_TYPE;
                            bfshca.STREAM_TYPE = bfshc.STREAM_TYPE;
                            bfshca.API_VERSION = bfshc.API_VERSION;
                            bfshca.TRANS_CAPABILITY = bfshc.TRANS_CAPABILITY;
                            PackBindFileSessionHandshakeCloseAck(bfshca, outPacket);
                            authHdr.flag = 0x01;
                        }
                    }
                } else {
                    if (jsPacket.contains("P2P_PORT")) {
                        FileChannelOpenHandshakeAck bfshoa;
                        if (!ParseBindFileSessionHandshakeOpenAck(jsPacket, bfshoa)) {
                            LOG_DEBUG_S("ParseBindFileSessionHandshakeOpenAck failed!");
                            return false;
                        }
                        
                        peerFileChannelId = bfshoa.MY_CHANNEL_ID;
                        ShareManager::shared().OnFileChannelOpen(bfshoa.MY_IP, bfshoa.P2P_PORT, false);
                    } else {
                        FileChannelCloseHandshakeAck bfshca;
                        if (!ParseBindFileSessionHandshakeCloseAck(jsPacket, bfshca)) {
                            return false;
                        }
                    }
                }
            }
            break;
        }

        case 0xFFFF0008:
            if (MetaNodeSerializer::shared().ParseAck(payload)) {
                MetaNodeSerializer::shared().CreateAck(outPacket);
                if (channel.isSender) {
                    authHdr.len = static_cast<uint32_t>(outPacket.size());
                    PackMetaNodeHeader(outPacket, authHdr, IsBleChannel(channelId));
                    if (IsBleChannel(channelId)) {
                        SendBLEDataInner(channelId, outPacket, channel.isSender);
                    } else {
                        TcpChannel::GetInstance()->SendTcpData(channelId, MODULE_META_AUTH, outPacket);
                    }

                    VerifyP2p vp;
                    vp.CODE = 3;
                    vp.P2P_IP = ShareManager::shared().GetLocalIP();
                    vp.P2P_PORT = GetRandomPort();
                    vp.PROTOCOL_TYPE = 4;
                    authHdr.dataType = 0xFFFF0004;
                    authHdr.module = 0x10;
                    RAND_bytes((unsigned char*)(&authHdr.seq), 8);
                    authHdr.flag = 0;
                    PacketVerifyP2p(vp, outPacket);
                }
            }
            break;

        default:
            break;
    }
    if (!outPacket.empty()) {
        authHdr.len = static_cast<uint32_t>(outPacket.size());
        PackMetaNodeHeader(outPacket, authHdr, IsBleChannel(channelId));
    }
    return true;
}

bool ConnectManager::OpenAuthChannel(const std::string &udid, const std::string &channelId, uint16_t peerId)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    bool isOverwrite = false;
    AuthChannel channel;
    if (channelList.find(udid) != channelList.end()) {
        LOG_ERROR_S("overwrite auth channel for device:%s", udid.c_str());
        channelMap.erase(channelList[udid].channelId);
        isOverwrite = true;
    }
    memset(&channel, 0, sizeof(channel));
    channel.udid = udid;
    channel.channelId = channelId;
    channel.myId = g_MyChannelId++;
    if (channel.myId == INVALID_CHANNEL_ID) {
        channel.myId = g_MyChannelId++;
    }
    channel.peerId = peerId;
    if (isOverwrite) {
        channelList[udid] = channel;
    } else {
        channelList.emplace(udid, channel);
    }
    channelMap.emplace(channelId, udid);
    return true;
}

void ConnectManager::CloseAuthChannel(const std::string &udid)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    auto it = channelList.find(udid);
    if (it != channelList.end()) {
        auto channelIt = channelMap.find(it->second.channelId);
        if (channelIt != channelMap.end()) {
            channelMap.erase(channelIt);
        }
        channelList.erase(it);
    }
}

bool ConnectManager::IsChannelExist(const std::string &channelId)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    if (channelMap.find(channelId) != channelMap.end()) {
        return true;
    }
    return false;
}

bool ConnectManager::UpdateChannel(const std::string &udid, uint16_t peerId, bool isSender)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    auto it = channelList.find(udid);
    if (it != channelList.end()) {
        it->second.peerId = peerId;
        it->second.isSender = isSender;
        return true;
    }
    return false;
}

void ConnectManager::UpdateChannel(const std::string &udid, const std::string &channelId)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    auto it = channelList.find(udid);
    if (it != channelList.end()) {
        std::string oldChannelId = it->second.channelId;
        it->second.channelId = channelId;
        auto channelIt = channelMap.find(oldChannelId);
        if (channelIt != channelMap.end()) {
            channelMap.erase(channelIt);
            channelMap.emplace(channelId, udid);
        }
    }
}

bool ConnectManager::GetChannel(const std::string &udid, AuthChannel &channel)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    auto it = channelList.find(udid);
    if (it != channelList.end()) {
        channel = it->second;
        return true;
    }
    return false;
}

ConnType ConnectManager::GetChannelType(const std::string &udid)
{
    AuthChannel channel;
    if (!GetChannel(udid, channel)) {
        LOG_ERROR_S("invalid device: %s", udid.c_str());
        return CONN_TYPE_NONE;
    }
    if (IsTcpChannel(channel.channelId)) {
        return CONN_TYPE_TCP;
    }
    return CONN_TYPE_BLE;
}

void ConnectManager::SendBLEDataInner(const std::string &channelId, const std::vector<uint8_t> &packet, bool isSender, bool useFirst)
{
    if (packet.empty()) {
        return;
    }
    DiscManager *manager = [DiscManager shared];
    if (manager != nil) {
        NSString *uuidString = [NSString stringWithUTF8String:channelId.c_str()];
        NSData *data = [NSData dataWithBytes:packet.data() length:packet.size()];
        [manager sendPacket:uuidString data:data useFirst:useFirst isSender:isSender];
    }
}

void ConnectManager::SendBLECachedData(const std::string &uuid)
{
    DiscManager *manager = [DiscManager shared];
    if (manager == nil) {
        LOG_ERROR_S("manager is nil");        
        return;
    }

    [manager SendCachedBlePackage:[NSString stringWithUTF8String:uuid.c_str()]];
}

void ConnectManager::SendData(const std::string &udid, const std::vector<uint8_t> &packet)
{
    AuthChannel channel;
    if (!GetChannel(udid, channel)) {
        LOG_ERROR_S("no connected channel for device: %s", udid.c_str());
        return;
    }
    if (IsBleChannel(channel.channelId)) {
        std::vector<uint8_t> request(packet);
        PackShareHeader(channel, request);
        SendBLEDataInner(channel.channelId, request, channel.isSender);
    } else if (IsTcpChannel(channel.channelId)){
        TcpChannel::GetInstance()->SendTcpData(channel.channelId, MODULE_AUTH_MSG, packet);
    } else {
        LOG_ERROR_S("unkonwn connect type for device: %s", udid.c_str());
    }
}

void ConnectManager::SendByteData(bool isSender, const std::vector<uint8_t> &packet)
{
    if (packet.empty()) {
        return;
    }

    std::vector<uint8_t> sessionKey;
    std::vector<uint8_t> reqeust;
    ShareManager::shared().GetByteSessionKey(sessionKey);
    if (TransTdcPackData((const char *)sessionKey.data(), packet, reqeust)) {
        LOG_DEBUG_S("TransTdcPackData failed!");
        return;
    }

    ssize_t sendSize = 0;
    if (isSender) {
        sendSize = smCli.send(reqeust);
        LOG_DEBUG_S("[SEND BYTE OUT]] %ld", sendSize);
    } else {
        sendSize = smSrv.send(reqeust);
        LOG_DEBUG_S("[RECV BYTE OUT]  %ld", sendSize);
    }
}

void ConnectManager::BuildOwnBasicInfo(bool supportAutoSync, std::vector<uint8_t> &packet)
{
    PayloadBasicInfo selfBasicInfo;
    selfBasicInfo.FEATURE_SUPPORT = 0;
    if (supportAutoSync) {
        selfBasicInfo.FEATURE_SUPPORT = 2;
    }
    selfBasicInfo.devid = ShareManager::shared().GetDeviceId();
    selfBasicInfo.TYPE = 0x02;
    selfBasicInfo.deviceType = 0xFF;
    PackBasicInfoExchange(selfBasicInfo, packet);
}

void ConnectManager::BuildRefSync(bool isAdd, std::vector<uint8_t> &packet)
{
    RefNumSync refNum;
    refNum.KEY_DELTA = 1;
    refNum.KEY_METHOD = 1;
    refNum.KEY_REF_NUM = 1;
    refNum.KEY_CHALLENGE = 0;
    PackRefNumSync(refNum, packet);
}

void ConnectManager::BuildNakedChannel(uint16_t myId, std::vector<uint8_t> &packet)
{
    NakedChannelHandshake ncsh;
    memset(&ncsh, 0, sizeof(ncsh));
    ncsh.TYPE = 0x02;
    uint16_t temp1 = ShareManager::shared().GetDeviceId(0);
    uint16_t temp2 = ShareManager::shared().GetDeviceId(1);
    uint16_t temp3 = ShareManager::shared().GetDeviceId(2);
    snprintf(ncsh.DEVICE_ID, sizeof(ncsh.DEVICE_ID) - 1, "%04X%04X%04X", temp1, temp2, temp3);
    strcpy(ncsh.SRC_BUS_NAME, "IShareEcologyAuthSession");
    strcpy(ncsh.DST_BUS_NAME, "IShareEcologyAuthSession");
    ncsh.API_VERSION = 0x02;
    ncsh.MTU_SIZE =  39968;
    ncsh.TRANS_CAPABILITY = 0;
    ncsh.HAS_PRIORITY = 1;
    strcpy(ncsh.PKG_NAME, "ohos.InterConnection.iShare");
    PackNakedChannelHandshakeReq(ncsh, myId, packet);
}

void ConnectManager::BuildNakedChannel(std::vector<uint8_t> &packet)
{
    NakedChannelHandshakeWlan ncs;
    ncs.CODE = 0x04;
    ncs.DEVICE_ID = ShareManager::shared().GetDeviceId();
    ncs.PEER_NETWORK_ID = ncs.DEVICE_ID;
    ncs.PKG_NAME = "ohos.InterConnection.iShare";
    ncs.SRC_BUS_NAME = "IShareEcologyAuthSession";
    ncs.DST_BUS_NAME = "IShareEcologyAuthSession";
    ncs.REQ_ID = "0";
    ncs.API_VERSION = 0x02;
    ncs.MTU_SIZE = 39968;
    ncs.ROUTE_TYPE = 0x02;
    PackNakedChannelHandshakeWlan(ncs, packet);
}

void ConnectManager::CloseFileChannel(const std::string &udid)
{
    AuthChannel channel;
    if (!GetChannel(udid, channel)) {
        LOG_ERROR_S("no channel for device: %s", udid.c_str());
        return;
    }
    bool isBleChannel = IsBleChannel(channel.channelId);
    FileChannelCloseHandshake bfshc;
    bfshc.PEER_CHANNEL_ID = peerFileChannelId;
    bfshc.MY_CHANNEL_ID = myFileChannelId;
    bfshc.MY_IP = ShareManager::shared().GetLocalIP();
    bfshc.CODE = 0x0602;
    bfshc.API_VERSION = 0x02;
    bfshc.BUSINESS_TYPE = 0x03;
    bfshc.STREAM_TYPE = -1;
    bfshc.CHANNEL_TYPE = 2;
    bfshc.UDP_CONN_TYPE = 1;
    bfshc.BUS_NAME = "IShareReceiverFileSession";
    bfshc.CLIENT_BUS_NAME = "IShareSenderFileSession";
    bfshc.PKG_NAME = "ohos.InterConnection.iShare";
    bfshc.TRANS_CAPABILITY = 0;
    std::vector<uint8_t> request;
    PackBindFileSessionHandshakeClose(bfshc, request);

    AuthHead ah;
    ah.dataType = 0xFFFF0004;
    ah.flag = 0;
    ah.module = 0x11;
    RAND_bytes((unsigned char*)(&ah.seq), 8);
    ah.len = static_cast<uint32_t>(request.size());

    PackMetaNodeHeader(request, ah, isBleChannel);
    if (isBleChannel) {
        SendBLEDataInner(channel.channelId, request, channel.isSender);
    } else {
        TcpChannel::GetInstance()->SendTcpData(channel.channelId, MODULE_META_AUTH, request);
    }
}

void ConnectManager::CloseProxyChannel(const std::string &udid)
{
    AuthChannel channel;
    if (GetChannel(udid, channel) && IsBleChannel(channel.channelId)) {
        std::vector<uint8_t> request;
        PackCloseProxyChannelReq(channel, request);
        SendBLEDataInner(channel.channelId, request, channel.isSender);
    }
}

void ConnectManager::DecreaseRef(const std::string &udid)
{
    AuthChannel channel;
    if (GetChannel(udid, channel) && IsBleChannel(channel.channelId)) {
        std::vector<uint8_t> request;
        RefNumSync refNum;
        refNum.KEY_DELTA = -1;
        refNum.KEY_METHOD = 1;
        refNum.KEY_REF_NUM = 0;
        refNum.KEY_CHALLENGE = 0;
        PackRefNumSync(refNum, request);
        SendBLEDataInner(channel.channelId, request, channel.isSender);
    }
}

void ConnectManager::CloseBleChannel(const std::string &udid)
{
    DiscManager *manager = [DiscManager shared];
    if (manager != nil) {
        AuthChannel channel;
        if (GetChannel(udid, channel) && IsBleChannel(channel.channelId)) {
            [manager ClearBLECache:[NSString stringWithUTF8String:channel.channelId.c_str()]];
        }
    }
}

void ConnectManager::CloseTcpChannel(const std::string &udid)
{
    AuthChannel channel;
    if (GetChannel(udid, channel) && IsTcpChannel(channel.channelId)) {
        CloseAuthChannel(udid);
        auto it = tcpPacketList.find(channel.channelId);
        if (it != tcpPacketList.end()) {
            LOG_DEBUG_S("free cc buffer for TCP channel: %s", channel.channelId.c_str());
            it->second->SetSize(0);
            tcpPacketList.erase(it);
        } else {
            LOG_ERROR_S("no cc buffer for TCP channel: %s", channel.channelId.c_str());
        }
        TcpChannel::GetInstance()->CloseChannel(channel.channelId);
    }
}

void ConnectManager::ShareFiles(const std::string &udid, bool isHighSpeed)
{
    LOG_DEBUG_S("start ShareFiles");
    AuthChannel channel;
    if (GetChannel(udid, channel)) {
        ShareManager::shared().OnShareCancelSelf(udid);
        return;
    }
    uint64_t deviceId = strtoull(udid.c_str(), nullptr, 16);
    auto device = DeviceManager::shared().getDevice(deviceId);
    if (device != nullptr && (isHighSpeed || !(device->foundType & 0x02))) {
        Connect(udid);
//        DiscManager *manager = [DiscManager shared];
//        if (manager != nil) {
//            
////            std::string channelId = DeviceManager::shared().GetDeviceUUID(udid);
////            NSString *udidString = [NSString stringWithUTF8String:channelId.c_str()];
////            if ([manager isDeviceConnected:udidString]) {
////                
////            } else {
////                [manager connectDevice:udidString];
////            }
//        }
    } else {
        int errCode = 0;
        std::string channelId = TcpChannel::GetInstance()->StartConnect(udid, errCode);
        if (channelId != "") {
            if (!OpenAuthChannel(udid, channelId)) {
                LOG_ERROR_S("Fail to allocate auth tcp channel for device:%s", udid.c_str());
                return;
            }

            std::vector<uint8_t> packet;
            BuildNakedChannel(packet);
            TcpChannel::GetInstance()->SendTcpData(channelId, MODULE_AUTH_CHANNEL, packet);
        } else {
            LOG_ERROR_S("Connect tcp channel timeout for device:%s", udid.c_str());
            errCode = errCode + ERROR_TCP_TIMEOUT + 1000;
            ShareManager::shared().SendShareEvent(SHARE_ERROR_TCP_TIMEOUT, errCode);
        }
    }
}

void ConnectManager::HandleByteData(const std::string &channelId, const std::vector<uint8_t> &data, bool isSender, int fd)
{
    if (!totalPacket.Put(data)) {
        return;
    }
    
    std::vector<uint8_t> packet;
    do {
        packet.clear();
        if (!isByteChannelOpen) {
            TdcPacketHead hdr;
            if (!totalPacket.Get(hdr, packet)) {
                break;
            }
            if (isSender) {
                BytesChannelHandshakeAck bbsha;
                // 解析Bind bytes协商ACK报文
                if (!ParseBindBytesSessionHandshakeAck(packet, bbsha)) {
                    LOG_DEBUG_S("ParseBindBytesSessionHandshake failed!");
                    ShareManager::shared().SendShareEvent(SHARE_ERROR_TRANS_SELF, ERROR_TRANS_SELF_PARSE_BIND_BYTES_ACK_FAILED);
                    break;
                }
                isByteChannelOpen = true;
                ShareManager::shared().OnByteChannelOpen();

                myFileChannelId = g_FileChannelId++;
                FileChannelOpenHandshake bfsho = {0};
                bfsho.MY_CHANNEL_ID = myFileChannelId;
                bfsho.MY_IP = ShareManager::shared().GetLocalIP();
                bfsho.DEVICE_ID = ShareManager::shared().GetDeviceId();
                bfsho.CODE = 0x0602;
                bfsho.API_VERSION = 0x02;
                bfsho.BUSINESS_TYPE = 3;
                bfsho.STREAM_TYPE = -1;
                bfsho.CHANNEL_TYPE = 1;
                bfsho.UDP_CONN_TYPE = 1;
                bfsho.BUS_NAME = "IShareReceiverFileSession";
                bfsho.CLIENT_BUS_NAME = "IShareSenderFileSession";
                bfsho.PKG_NAME = "ohos.InterConnection.iShare";
                bfsho.TRANS_CAPABILITY = 0;
                
                std::vector<uint8_t> blePacket;
                peerFileChannelId = -1;
                PackBindFileSessionHandshakeOpen(bfsho, blePacket);

                AuthHead ah;
                ah.dataType = 0xFFFF0004;
                ah.flag = 0;
                ah.module = 0x11;
                RAND_bytes((unsigned char*)(&ah.seq), 8);
                ah.len = static_cast<uint32_t>(blePacket.size());
                bool isBleChannel = IsBleChannel(channelId);
                PackMetaNodeHeader(blePacket, ah, isBleChannel);

                if (isBleChannel) {
                    if (blePacket.size() > 509) {
                        LOG_DEBUG_S("packet will be splitted");
                    }
                    SendBLEDataInner(channelId, blePacket, isSender);
                } else {
                    TcpChannel::GetInstance()->SendTcpData(channelId, MODULE_META_AUTH, blePacket);
                }
            } else {
                BytesChannelHandshake bbsh;
                // 1 解析Bind bytes协商报文
                if (!ParseBindBytesSessionHandshake(packet, bbsh)) {
                    LOG_DEBUG_S("ParseBindBytesSessionHandshake failed!");
                    break;
                }
                packet.clear();

                // 2 回应Bind bytes协商报文ACK
                std::vector<uint8_t> rsp;
                ssize_t send_size;
                BytesChannelHandshakeAck bbsha;
                bbsha.CODE = 0x01;
                bbsha.API_VERSION = 0x02;
                bbsha.DEVICE_ID = ShareManager::shared().GetDeviceId();
                bbsha.TRANS_CAPABILITY = 0;
                bbsha.MTU_SIZE = 4194304;
                bbsha.PKG_NAME = "ohos.InterConnection.iShare";
                PackBindBytesSessionHandshakeAck(bbsha, packet);
                hdr.flags |= 0x01;
                hdr.dataLen = static_cast<uint32_t>(packet.size());
                PackTdcHeader(packet, hdr, rsp);
                send_size = smSrv.send(rsp, fd);
                if (send_size > 0) {
                    isByteChannelOpen = true;
                    ShareManager::shared().OnByteChannelOpen();
                }
                LOG_DEBUG_S("smSrv.send %ld", send_size);
            }
        } else {
            TdcDataPacketHead hdr;
            if (!totalPacket.Get(hdr, packet)) {
                break;
            }
            std::vector<uint8_t> plain;
            plain.resize(hdr.dataLen - OVERHEAD_LEN);
            uint32_t plainLen = (uint32_t)plain.size();
            std::vector<uint8_t> sessionKey;
            ShareManager::shared().GetByteSessionKey(sessionKey);
            if (TransTdcUnPackData((const char *)sessionKey.data(), (char *)plain.data(), &plainLen, packet)) {
                LOG_DEBUG_S("TransTdcUnPackData failed!");
                break;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                // 在主线程执行
                std::vector<uint8_t> temp;
                ShareManager::shared().OnRecvPacket("", plain, temp);
            });
        }
    } while (packet.size());
}

bool ConnectManager::HandleTcp(const std::string &channelId, const std::vector<uint8_t> &packet)
{
    std::shared_ptr<CircularBuffer> tcpAuthChannelPkt = nullptr;
    auto it = tcpPacketList.find(channelId);
    if (it == tcpPacketList.end()) {
        auto ccPacket = std::make_shared<CircularBuffer>();
        ccPacket->SetSize(128 * 1024);
        tcpPacketList.emplace(channelId, ccPacket);
        tcpAuthChannelPkt = ccPacket;
    } else {
        tcpAuthChannelPkt = it->second;
    }
    
    if (tcpAuthChannelPkt == nullptr) {
        LOG_ERROR_S("system error, no circulaar buffer for TCP channel: %s", channelId.c_str());
        return false;
    }
    if (!tcpAuthChannelPkt->Put(packet)) {
        return false;
    }
    
    std::vector<uint8_t> data;
    do {
        TdcPacketHead hdr;
        if (!tcpAuthChannelPkt->Get(hdr, data)) {
            break;
        }
        NakedChannelHandshakeWlan ncs;
        std::vector<uint8_t> payload;
        std::vector<uint8_t> response;
    //    size_t sendSize = 0;
        std::string udid = GetUdidByChannel(channelId);
        switch (hdr.module) {
            case MODULE_AUTH_CHANNEL:
            {
                if (!ParseNakedChannelHandshakeWlan(data, ncs)) {
                    LOG_ERROR_S("wrong ncs for tcp channel");
                    return false;
                }
                bool isSender = true;
                bool isBidirection = false;
                AuthChannel channel;
                if (hdr.flags == 0) {
                    udid = DeviceManager::shared().GetHashStringUDID(ncs.DEVICE_ID).substr(0, 16);
                    if (GetChannel(udid, channel) && channel.peerId != (uint16_t)-1 && channel.isSender) {
                        isBidirection = true;
                    } else {
                        if (!OpenAuthChannel(udid, channelId, 0)) {
                            LOG_ERROR_S("Fail to allocate auth tcp channel for device:%s", udid.c_str());
                            return false;
                        }
                    }
                    ncs.DEVICE_ID = ShareManager::shared().GetDeviceId();
                    ncs.PEER_NETWORK_ID = ncs.DEVICE_ID;
                    ncs.API_VERSION = 0x02;
                    ncs.ROUTE_TYPE = 0x02;
                    PackNakedChannelHandshakeWlan(ncs, payload);
                    TcpChannel::GetInstance()->SendTcpData(channelId, MODULE_AUTH_CHANNEL, payload);
                    isSender = false;
                } else {
                    if (GetChannel(udid, channel) && channel.peerId != (uint16_t)-1 &&!channel.isSender) {
                        isBidirection = true;
                    }
                }
                if (!isBidirection && GetChannel(udid, channel) && UpdateChannel(udid, 0, isSender)) {
                    ShareManager::shared().OnShareStart(channelId, udid);
                    ShareManager::shared().OnAuthChannelConnect(channel, isSender);
                }
                break;
            }

            case MODULE_AUTH_MSG:
                ShareManager::shared().OnRecvPacket(udid, data, response);
                if (!response.empty()) {
                    TcpChannel::GetInstance()->SendTcpData(channelId, MODULE_AUTH_MSG, response);
                }
                break;

            case MODULE_META_AUTH:
                HandleAuthChannel(channelId, data, payload);
                TcpChannel::GetInstance()->SendTcpData(channelId, MODULE_META_AUTH, payload);
                break;

            default:
                break;
        }
    } while (data.size());
    return true;
}

bool ConnectManager::IsTcpChannel(const std::string &channelId) const
{
    if (channelId.empty()) {
        return false;
    }
    if (channelId.find("tcp-") != std::string::npos) {
        return true;
    }
    return false;
}

bool ConnectManager::IsBleChannel(const std::string &channelId) const
{
    if (channelId.empty()) {
        return false;
    }
    if (channelId.find("tcp-") == std::string::npos) {
        return true;
    }
    return false;
}

std::string ConnectManager::GetUdidByChannel(const std::string &channelId)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    if (channelMap.find(channelId) != channelMap.end()) {
        return channelMap.at(channelId);
    }
    LOG_ERROR_S("invlaid channelId: %s", channelId.c_str());
    return "";
}

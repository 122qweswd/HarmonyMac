//
//  TcpChannel.mm
//  MutualInfection
//
//  Created by apple on 2025/10/12.
//

#include "TcpChannel.h"
#include "LogHelper.h"
#include "Common.h"
#include <netinet/tcp.h>
#include "COAPDiscSerializer.hpp"

#include "DeviceManager.h"
#include "AuthChannel.h"
#include "ShareManager.h"

TcpChannel* TcpChannel::GetInstance()
{
    static TcpChannel instance;
    return &instance;
}

void TcpChannel::SetPortAndFd(int port, int fd)
{
    this->port = port;
    this->socketFd = fd;
}

void TcpChannel::StartListenFd()
{
    if (this->port != -1) {
        StopListen();
    }
    int sockfd;
    uint16_t port;
    if (GetRandomPortAndSockfd(port, sockfd) != 0) {
        LOG_ERROR_S("GetRandomPortAndSockfd failed!");
        return;
    }
    this->port = port;
    this->socketFd = sockfd;
    SetTcpKeepalive(sockfd);
    COAPDiscSerializer::GetInstance()->SetPortAndFd(port, sockfd);
    service.StartListenFd(sockfd, [=, this](const std::vector<uint8_t>& data, int clientFd) {
        auto it = this->recvChannelSets.find(clientFd);
        if (it == this->recvChannelSets.end()) {
            this->recvChannelSets.emplace(clientFd);
        }
        std::string channelId = "tcp-recvchannel-" + std::to_string(clientFd);
        LOG_DEBUG_S("[RECV TCP IN] totalSize = %zu, channelId = %s", data.size(), channelId.c_str());
        dispatch_sync(dispatch_get_main_queue(), ^{
            // 在主线程执行
            ShareManager::shared().HandleTcp(channelId, data);
        });
    });
}

void TcpChannel::StopListen()
{
    if (this->port != -1) {
        service.Stop();
        this->port = -1;
        this->socketFd = -1;
    }
    
}

void TcpChannel::SetTcpKeepalive(int fd)
{
    if (fd < 0 ) {
        LOG_ERROR_S("invalid param");
        return;
    }
    int enable = 1;
    setsockopt(fd, SOL_SOCKET, SO_KEEPALIVE, &enable, sizeof(enable));
        
    int keepidle = 10 * 60 * 60;
    int keepintvl = 4;
    int keepcnt = 5;
    
    setsockopt(fd, IPPROTO_TCP, TCP_KEEPALIVE, &keepidle, sizeof(keepidle));
    setsockopt(fd, IPPROTO_TCP, TCP_KEEPINTVL, &keepintvl, sizeof(keepintvl));
    setsockopt(fd, IPPROTO_TCP, TCP_KEEPCNT, &keepcnt, sizeof(keepcnt));
}

std::string TcpChannel::StartConnect(std::string udid, int &errCode)
{
    uint64_t deviceId = strtoull(udid.c_str(), nullptr, 16);
    auto device = DeviceManager::shared().getDevice(deviceId);
    if (device == nullptr && !(device->foundType & 0x02)) {
        LOG_ERROR_S("the udid is error, udid is %s", udid.c_str());
        return "";
    }
    sendChannelId = "";
    bool ret = false;
    int retry = 0;
    do {
        ret = client.StartConnect(device->info.wlanIp, device->info.port, [=, this](const std::vector<uint8_t>& data, int clientFd) {
            LOG_DEBUG_S("[SEND TCP IN] totalSize = %zu, channelId = %s", data.size(), sendChannelId.c_str());
            dispatch_sync(dispatch_get_main_queue(), ^{
                // 在主线程执行
                ShareManager::shared().HandleTcp(sendChannelId, data);
            });
        }, errCode);
        if (ret || ++retry >= 5) {
            break;
        }
    } while (true);

    if (ret) {
        sendChannelId = "tcp-" + udid;
    } else {
        LOG_DEBUG_S("Connect TCP timeout!");
        return "";
    }
    return sendChannelId;
}

static uint64_t g_CoapSeq = 0;

void TcpChannel::SendTcpData(const std::string &channelId, int moduleId, const std::vector<uint8_t> &data)
{
    size_t sendSize = 0;
    std::vector<uint8_t> packet;
    TdcPacketHead hdr;
    hdr.magicNumber = MAGIC_NUMBER;
    hdr.module = moduleId;
    hdr.seq = g_CoapSeq++;
    hdr.flags = 0;
    bool isSender = false;
    std::string tag = "tcp-recvchannel-";
    if (channelId.find(tag) == std::string::npos) {
        isSender = true;
    }
    if (moduleId == MODULE_AUTH_CHANNEL && !isSender) {
        hdr.flags = 1;
    }
    hdr.dataLen = static_cast<uint32_t>(data.size());
    PackTdcHeader(data, hdr, packet);
    if (isSender) {
        sendSize = client.send(packet);
        LOG_DEBUG_S("[SEND TCP OUT]sendSize: %d, channelId = %s", sendSize, channelId.c_str());
    } else {
        int clientFd = -1;
        std::string fdString = channelId.substr(channelId.find(tag) + tag.length(), channelId.length() - tag.length());
        clientFd = strtod(fdString.c_str(), nullptr);
        sendSize = service.send(packet, clientFd);
        if (sendSize == -1) {
            int errCode = ERROR_TRANS_SELF_ERROR;
            errCode += 3000;
            errCode += errno;
            LOG_ERROR_S("send tcp data failed, channelId = %s", channelId.c_str());
            ShareManager::shared().SendShareEvent(SHARE_ERROR_TRANS_SELF, errCode);
        }
        LOG_DEBUG_S("[RECV TCP OUT]sendSize: %d, channelId = %s", sendSize, channelId.c_str());
    }
} 

void TcpChannel::CloseChannel(const std::string &channelId)
{
    if (channelId == sendChannelId) {
        client.Stop();
    } else {
        int clientFd = -1;
        std::string tag = "tcp-recvchannel-";
        std::string fdString = channelId.substr(channelId.find(tag) + tag.length(), channelId.length() - tag.length());
        clientFd = strtod(fdString.c_str(), nullptr);
        if (clientFd >= 0) {
            recvChannelSets.erase(clientFd);
        }
    }
}

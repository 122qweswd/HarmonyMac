//
//  TcpChannel.h
//  MutualInfection
//
//  Created by apple on 2025/10/12.
//
#include "SocketManager.h"
#include <set>

class TcpChannel
{
public:
    TcpChannel() {}
    ~TcpChannel() {}
    static TcpChannel *GetInstance();
    void SetPortAndFd(int port, int fd);
    void StartListenFd();
    std::string StartConnect(std::string udid, int &errCode);
    void SendTcpData(const std::string &uuid, int moduleId, const std::vector<uint8_t> &data);
    void CloseChannel(const std::string &channelId);
    void SetTcpKeepalive(int fd);
    void StopListen();
private:
    SocketManager client;
    SocketManager service;
    std::set<int> recvChannelSets {};
    std::string sendChannelId { "" };
    int port { -1 };
    int socketFd { -1 };
};

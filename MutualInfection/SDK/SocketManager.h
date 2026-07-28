//
//  SocketManager.h
//  MutualInfection
//
//  Created by apple on 2025/9/11.
//
#pragma once
#include "socket.h"

class SocketManager
{
public:
    SocketManager();
    ~SocketManager();
    
    // 删除拷贝构造和赋值
    SocketManager(const SocketManager&) = delete;
    SocketManager& operator=(const SocketManager&) = delete;
    void StartListen(uint16_t port, ReceiveCallback callback, bool isAccept = true);
    void StartListenFd(int sockfd, ReceiveCallback callback, bool isAccept = true, bool bAcceptOnce = false);
    bool StartConnect(const std::string& host, uint16_t port, ReceiveCallback callback, int &errCode);
    void Stop();
    void ServerThread();
    ssize_t send(const std::string& data);
    ssize_t send(const std::vector<uint8_t>& data);
    ssize_t send(const std::string& data, int clientFd);
    ssize_t send(const std::vector<uint8_t>& data, int clientFd);
private:
    std::shared_ptr<Socket> socket = nullptr;
};

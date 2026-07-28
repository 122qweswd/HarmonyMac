//
//  SocketManager.mm
//  MutualInfection
//
//  Created by apple on 2025/9/11.
//
#import "SocketManager.h"
#include <iostream>
#include <unistd.h>

SocketManager::SocketManager()
{

}

SocketManager::~SocketManager()
{
    
}

void SocketManager::StartListen(uint16_t port, ReceiveCallback callback, bool isAccpet)
{
    socket = nullptr;
    socket = std::make_shared<Socket>();
    socket->setReceiveCallback(callback);
    socket->listen(port);
    if (isAccpet) {
        std::thread t = std::thread(&SocketManager::ServerThread, this);
        t.detach();
    }
}

void SocketManager::StartListenFd(int sockfd, ReceiveCallback callback, bool isAccpet, bool bAcceptOnce)
{
    socket = nullptr;
    socket = std::make_shared<Socket>(bAcceptOnce);
    socket->setReceiveCallback(callback);
    socket->listenfd(sockfd);
    if (isAccpet) {
        std::thread t = std::thread(&SocketManager::ServerThread, this);
        t.detach();
    }
}

void SocketManager::ServerThread()
{
    if (socket == nullptr) {
        return;
    }
    socket->accept();
}

ssize_t SocketManager::send(const std::string& data)
{
    if (socket == nullptr) {
        return -1;
    }
    return socket->send(data);
}

ssize_t SocketManager::send(const std::vector<uint8_t>& data)
{
    if (socket == nullptr) {
        return -1;
    }
    return socket->send(data);
}

ssize_t SocketManager::send(const std::string& data, int clientFd)
{
    if (socket == nullptr) {
        return -1;
    }
    return socket->send(data, clientFd);
}

ssize_t SocketManager::send(const std::vector<uint8_t>& data, int clientFd)
{
    if (socket == nullptr) {
        return -1;
    }
    return socket->send(data, clientFd);
}

bool SocketManager::StartConnect(const std::string& host, uint16_t port, ReceiveCallback callback, int& errCode)
{
    socket = nullptr;
    socket = std::make_shared<Socket>();
    socket->setReceiveCallback(callback);
    bool result = socket->connect(host, port, errCode);
    return result;
}

void SocketManager::Stop()
{
    if (socket != nullptr) {
        socket->disconnect();
        // socket.reset();
    }
}

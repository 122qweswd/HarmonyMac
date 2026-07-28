//
//  socket.h
//  MutualInfection
//
//  Created by apple on 2025/9/11.
//

#pragma once
#include <string>
#include <vector>
#include <functional>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <thread>
//using ReceiveCallback = std::function<void(const std::vector<uint8_t>&)>;
using ReceiveCallback = std::function<void(const std::vector<uint8_t>& data, int clientFd)>;

class Socket
{
public:
    Socket();
    Socket(bool bAcceptOnce);
    ~Socket();
    
    // 删除拷贝构造和赋值
    Socket(const Socket&) = delete;
    Socket& operator=(const Socket&) = delete;
    
        
    // 客户端方法
    bool connect(const std::string& host, uint16_t port, int &errorCode);
    ssize_t send(const std::string& data);
    ssize_t send(const std::vector<uint8_t>& data);
    ssize_t send(const std::string& data, int targetFd);
    ssize_t send(const std::vector<uint8_t>& data, int targetFd);
    void setReceiveCallback(ReceiveCallback callback);
    
    // 服务器方法
    bool listen(uint16_t port);
    bool listenfd(int fd);
    bool accept();
    
    void disconnect();
        
private:
    int sockfd;
    int clientSockfd;
    bool isServer;
    ReceiveCallback receiveCallback;
    void receiveThreadFunc();
    void receiveServerThreadFunc();
    std::thread receiveThread;
    bool running;
    bool m_bAcceptOnce = false;
};

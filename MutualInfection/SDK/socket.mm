//
//  socket.mm
//  MutualInfection
//
//  Created by apple on 2025/9/11.
//

#import "socket.h"
#include <iostream>
#include <unistd.h>

#include <sys/types.h>
#include <sys/event.h>
#include <sys/time.h>
#include <sys/socket.h>
#include <fcntl.h>
#include <unistd.h>
#include <iostream>
#include <vector>

#include "LogHelper.h"
#include "ShareManager.h"

Socket::Socket() : sockfd(-1), clientSockfd(-1), isServer(false), running(false) {}

Socket::Socket(bool bAcceptOnce) : sockfd(-1), clientSockfd(-1), isServer(false), running(false),m_bAcceptOnce(bAcceptOnce) {}


Socket::~Socket()
{
    disconnect();
}

bool Socket::connect(const std::string& host, uint16_t port, int& errCode)
{
    sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd < 0) {
        LOG_ERROR_S("socket errno: %d %s", errno, strerror(errno));
        errCode = errno;
        return false;
    }
    
    int flags = fcntl(sockfd, F_GETFL, 0);
    if (flags == -1) {
        LOG_ERROR_S("fcntl F_GETFL failed, errno:%d, desc:%s", errno, strerror(errno));
        close(sockfd);
        errCode = errno;
        return false;
    }
    
    if (fcntl(sockfd, F_SETFL, flags | O_NONBLOCK) == -1) {
        LOG_ERROR_S("fcntl F_SETFL O_NONBLOCK failed, errno:%d, desc:%s", errno, strerror(errno));
        close(sockfd);
        errCode = errno;
        return false;
    }
    struct sockaddr_in server_addr;
    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(port);
    
    if (inet_pton(AF_INET, host.c_str(), &server_addr.sin_addr) <= 0) {
        LOG_DEBUG_S("inet_pton errno: %d %s", errno, strerror(errno));
        close(sockfd);
        errCode = errno;
        return false;
    }
    
    int ret = ::connect(sockfd, (struct sockaddr*)&server_addr, sizeof(server_addr));
    if (ret == 0) {
        running = true;
        receiveThread = std::thread(&Socket::receiveThreadFunc, this);
        receiveThread.detach();
        return true;
    }
    
    if (errno != EINPROGRESS) {
        LOG_ERROR_S("connect failed :%d, desc:%s", errno, strerror(errno));
        if (errno == 51) {
            usleep(200 * 1000);
        }
        close(sockfd);
        errCode = errno;
        return false;
    }
    struct timeval timeout;
    timeout.tv_sec = 0;
    timeout.tv_usec = 200 * 1000;
    
    fd_set writefds;
    FD_ZERO(&writefds);
    FD_SET(sockfd, &writefds);
    
    int select_ret = select(sockfd + 1, nullptr, &writefds, nullptr, &timeout);
    if (select_ret < 0) {
        LOG_ERROR_S("select error :%d, desc:%s", errno, strerror(errno));
        close(sockfd);
        errCode = errno;
        return false;
    } else if (select_ret == 0) {
        LOG_ERROR_S("connect timeout");
        close(sockfd);
        errCode = errno;
        return false;
    }
    running = true;
    receiveThread = std::thread(&Socket::receiveThreadFunc, this);
    receiveThread.detach();
    return true;
}

bool Socket::listen(uint16_t port)
{
    isServer = true;
    sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd < 0) {
        LOG_ERROR("socket: %s", strerror(errno));
        return false;
    }
    
    int opt = 1;
    setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    
    struct sockaddr_in server_addr;
    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = INADDR_ANY;
    server_addr.sin_port = htons(port);
    
    if (bind(sockfd, (struct sockaddr*)&server_addr, sizeof(server_addr)) < 0) {
        LOG_ERROR("bind: %s", strerror(errno));
        close(sockfd);
        return false;
    }
    
    if (::listen(sockfd, 5) < 0) {
        LOG_ERROR("listen: %s", strerror(errno));
        close(sockfd);
        return false;
    }
    
    return true;
}

bool Socket::listenfd(int fd)
{
    isServer = true;
    sockfd = fd;
    
    if (::listen(sockfd, 5) < 0) {
        LOG_ERROR_S("listen: %s", strerror(errno));
        close(sockfd);
        return false;
    }
    
    return true;
}

bool Socket::accept()
{
    if (m_bAcceptOnce) {
        struct sockaddr_in client_addr;
        socklen_t client_len = sizeof(client_addr);

        clientSockfd = ::accept(sockfd, (struct sockaddr*)&client_addr, &client_len);
        if (clientSockfd < 0) {
            LOG_ERROR_S("accept:%s", strerror(errno));
            return false;
        }
        
        running = true;
        receiveThread = std::thread(&Socket::receiveThreadFunc, this);
    } else {
        if (!isServer) {
            LOG_ERROR_S("accept called on client socket");
            return false;
        }
        
        if (sockfd < 0) {
            LOG_ERROR_S("accept: invalid server socket");
            return false;
        }
        
        running = true;
        receiveThread = std::thread(&Socket::receiveServerThreadFunc, this);
    }
    
    receiveThread.detach();
    return true;
}

ssize_t Socket::send(const std::string& data)
{
    int targetSock = isServer ? clientSockfd : sockfd;
    if (targetSock < 0) return -1;
    
    return ::send(targetSock, data.c_str(), data.length(), 0);
}

ssize_t Socket::send(const std::vector<uint8_t>& data)
{
    int targetSock = isServer ? clientSockfd : sockfd;
    if (targetSock < 0) return -1;
    
    return ::send(targetSock, data.data(), data.size(), 0);
}

ssize_t Socket::send(const std::string& data, int targetFd)
{
    if (targetFd < 0) return -1;
    
    return ::send(targetFd, data.c_str(), data.length(), 0);
}

ssize_t Socket::send(const std::vector<uint8_t>& data, int targetFd)
{
    if (targetFd < 0) return -1;
    
    return ::send(targetFd, data.data(), data.size(), 0);
}

void Socket::setReceiveCallback(ReceiveCallback callback)
{
    receiveCallback = callback;
}

#if 0
void Socket::receiveThreadFunc()
{
    std::vector<uint8_t> buffer;
    buffer.resize(1024+1);
    
//    uint8_t buffer[1024] = {0};
    int targetSock = isServer ? clientSockfd : sockfd;
    
    while (running) {
        ssize_t bytesReceived = recv(targetSock, buffer.data(), buffer.size() - 1, 0);
        if (bytesReceived <= 0) {
            if (bytesReceived == 0) {
                LOG_DEBUG_S("Connection closed");
            } else {
                LOG_ERRO_R("recv:%s", strerror(errno));
            }
            break;
        }
        
        buffer.resize(bytesReceived);
//        buffer.data()[bytesReceived] = '\0';
        if (receiveCallback) {
            receiveCallback(buffer);
        }
    }
}
#endif

void Socket::receiveThreadFunc()
{
    int targetSock = isServer ? clientSockfd : sockfd;
    
    // 创建 kqueue 实例
    int kq = kqueue();
    if (kq == -1) {
        LOG_ERROR_S("kqueue: %s", strerror(errno));
        return;
    }
    
    // 设置非阻塞模式（可选，但推荐）
    int flags = fcntl(targetSock, F_GETFL, 0);
    fcntl(targetSock, F_SETFL, flags | O_NONBLOCK);
    
    // 初始化事件结构，监听读事件
    struct kevent changeEvent;
    EV_SET(&changeEvent, targetSock, EVFILT_READ, EV_ADD | EV_ENABLE, 0, 0, NULL);
    
    // 将事件添加到 kqueue
    if (kevent(kq, &changeEvent, 1, NULL, 0, NULL) == -1) {
        LOG_ERROR_S("kevent: %s", strerror(errno));
        close(kq);
        return;
    }
    
    std::vector<uint8_t> buffer(1024+1); // 预分配缓冲区
    bool isClosed = false;
    try {
        while (running) {
        struct kevent event;
        struct timespec timeout = {1, 0}; // 1秒超时
        
        // 等待事件发生
        int nev = kevent(kq, NULL, 0, &event, 1, &timeout);
        if (nev == -1) {
            LOG_ERROR_S("kevent wait: %s", strerror(errno));
            break;
        } else if (nev == 0) {
            // 超时，检查是否仍在运行
            continue;
        }
        
        // 检查是否是我们要的读事件
        if (event.filter == EVFILT_READ) {
            if (event.flags & EV_EOF) {
                // 连接已关闭
                LOG_DEBUG_S("Connection closed");
                isClosed = true;
                break;
            }
            
            // 接收数据
            ssize_t bytesReceived = recv(targetSock, buffer.data(), buffer.size()-1, 0);
            if (bytesReceived <= 0) {
                if (bytesReceived == 0) {
                    LOG_DEBUG_S("Connection closed");
                    isClosed = true;
                } else if (errno != EAGAIN && errno != EWOULDBLOCK) {
                    LOG_ERROR_S("recv: %s", strerror(errno));
                }
                break;
            }
            
            // 调用回调函数
            if (receiveCallback) {
                std::vector<uint8_t> receivedData(buffer.begin(), buffer.begin() + bytesReceived);
                receiveCallback(receivedData, targetSock);
            }
        }
    }
    } catch (...) {

    }
    
    if (isClosed) {
        ShareManager::shared().SendShareEvent(SHARE_ERROR_BYTE_CHANNEL, ERROR_BYTE_CHANNEL_CONNECTION_CLOSED);
    }
    // 清理资源
    close(kq);
}

void Socket::receiveServerThreadFunc()
{
    // 创建 kqueue 实例
    int kq = kqueue();
    if (kq == -1) {
        LOG_ERROR_S("kqueue: %s", strerror(errno));
        return;
    }
    
    // 服务器模式下监听服务端socket和已连接的客户端socket
    if (isServer) {
        // 监听服务器socket用于接受新连接
        struct kevent serverEvent;
        EV_SET(&serverEvent, sockfd, EVFILT_READ, EV_ADD | EV_ENABLE, 0, 0, NULL);
        
        if (kevent(kq, &serverEvent, 1, NULL, 0, NULL) == -1) {
            LOG_ERROR_S("kevent add server socket: %s", strerror(errno));
            close(kq);
            return;
        }
        
        // 存储所有客户端连接
        std::vector<int> clientSockets;
        try {
            while (running) {
            struct kevent events[32]; // 一次处理最多32个事件
            struct timespec timeout = {1, 0}; // 1秒超时
            
            // 等待事件发生
            int nev = kevent(kq, NULL, 0, events, 32, &timeout);
            if (nev == -1) {
                LOG_ERROR_S("kevent wait: %s", strerror(errno));
                break;
            } else if (nev == 0) {
                // 超时，检查是否仍在运行
                continue;
            }
            
            for (int i = 0; i < nev; i++) {
                int eventFd = (int)events[i].ident;
                
                // 检查是否是服务器socket有新连接
                if (eventFd == sockfd) {
                    if (events[i].filter == EVFILT_READ) {
                        // 接受新连接
                        struct sockaddr_in client_addr;
                        socklen_t client_len = sizeof(client_addr);
                        
                        int newClientFd = ::accept(sockfd, (struct sockaddr*)&client_addr, &client_len);
                        if (newClientFd < 0) {
                            LOG_ERROR_S("accept:%s", strerror(errno));
                            continue;
                        }
                        
                        // 设置非阻塞模式
                        int flags = fcntl(newClientFd, F_GETFL, 0);
                        fcntl(newClientFd, F_SETFL, flags | O_NONBLOCK);
                        
                        // 添加到kqueue监听
                        struct kevent clientEvent;
                        EV_SET(&clientEvent, newClientFd, EVFILT_READ, EV_ADD | EV_ENABLE, 0, 0, NULL);
                        
                        if (kevent(kq, &clientEvent, 1, NULL, 0, NULL) == -1) {
                            LOG_ERROR_S("kevent add client socket: %s", strerror(errno));
                            close(newClientFd);
                            continue;
                        }
                        
                        // 存储客户端socket
                        clientSockets.push_back(newClientFd);
                        LOG_DEBUG_S("New client connected, fd: %d, total clients: %zu", newClientFd, clientSockets.size());
                    }
                }
                // 处理客户端socket数据
                else {
                    if (events[i].filter == EVFILT_READ) {
                        if (events[i].flags & EV_EOF) {
                            // 客户端连接关闭
                            LOG_DEBUG_S("Client fd %d disconnected", eventFd);
                            
                            // 从kqueue移除
                            struct kevent removeEvent;
                            EV_SET(&removeEvent, eventFd, EVFILT_READ, EV_DELETE, 0, 0, NULL);
                            kevent(kq, &removeEvent, 1, NULL, 0, NULL);
                            
                            // 关闭socket并从列表中移除
                            close(eventFd);
                            clientSockets.erase(
                                std::remove(clientSockets.begin(), clientSockets.end(), eventFd),
                                clientSockets.end()
                            );
                            continue;
                        }
                        
                        // 接收客户端数据
                        std::vector<uint8_t> buffer(1024 + 1);
                        ssize_t bytesReceived = recv(eventFd, buffer.data(), buffer.size() - 1, 0);
                        
                        if (bytesReceived > 0) {
                            // 调用回调函数，传递客户端fd和数据
                            if (receiveCallback) {
                                std::vector<uint8_t> receivedData(buffer.begin(), buffer.begin() + bytesReceived);
                                receiveCallback(receivedData, eventFd);
                            }
                        } else if (bytesReceived == 0) {
                            // 客户端正常关闭
                            LOG_DEBUG_S("Client fd %d closed connection", eventFd);
                            
                            struct kevent removeEvent;
                            EV_SET(&removeEvent, eventFd, EVFILT_READ, EV_DELETE, 0, 0, NULL);
                            kevent(kq, &removeEvent, 1, NULL, 0, NULL);
                            
                            close(eventFd);
                            clientSockets.erase(
                                std::remove(clientSockets.begin(), clientSockets.end(), eventFd),
                                clientSockets.end()
                            );
                        } else if (errno != EAGAIN && errno != EWOULDBLOCK) {
                            LOG_ERROR_S("recv from client fd %d: %s", eventFd, strerror(errno));
                        }
                    }
                }
            }
        }
        } catch (...) {

        }
        // 清理所有客户端连接
        for (int clientFd : clientSockets) {
            close(clientFd);
        }
        
    }
    // 客户端模式（保持原有逻辑）
    else {
        int targetSock = sockfd;
        
        // 设置非阻塞模式
        int flags = fcntl(targetSock, F_GETFL, 0);
        fcntl(targetSock, F_SETFL, flags | O_NONBLOCK);
        
        // 初始化事件结构，监听读事件
        struct kevent changeEvent;
        EV_SET(&changeEvent, targetSock, EVFILT_READ, EV_ADD | EV_ENABLE, 0, 0, NULL);
        
        // 将事件添加到 kqueue
        if (kevent(kq, &changeEvent, 1, NULL, 0, NULL) == -1) {
            LOG_ERROR_S("kevent: %s", strerror(errno));
            close(kq);
            return;
        }
        
        std::vector<uint8_t> buffer(1024 + 1);
        
        while (running) {
            struct kevent event;
            struct timespec timeout = {1, 0}; // 1秒超时
            
            // 等待事件发生
            int nev = kevent(kq, NULL, 0, &event, 1, &timeout);
            if (nev == -1) {
                LOG_ERROR_S("kevent wait: %s", strerror(errno));
                break;
            } else if (nev == 0) {
                // 超时，检查是否仍在运行
                continue;
            }
            
            // 检查是否是我们要的读事件
            if (event.filter == EVFILT_READ) {
                if (event.flags & EV_EOF) {
                    // 连接已关闭
                    LOG_DEBUG_S("Connection closed");
                    break;
                }
                
                // 接收数据
                ssize_t bytesReceived = recv(targetSock, buffer.data(), buffer.size() - 1, 0);
                if (bytesReceived <= 0) {
                    if (bytesReceived == 0) {
                        LOG_DEBUG_S("Connection closed");
                    } else if (errno != EAGAIN && errno != EWOULDBLOCK) {
                        LOG_ERROR_S("recv: %s", strerror(errno));
                    }
                    break;
                }
                
                // 调用回调函数
                if (receiveCallback) {
                    std::vector<uint8_t> receivedData(buffer.begin(), buffer.begin() + bytesReceived);
                    receiveCallback(receivedData, targetSock); // 客户端模式下fd就是sockfd
                }
            }
        }
    }
    
    // 清理资源
    close(kq);
}

void Socket::disconnect()
{
    running = false;
    if (sockfd >= 0) {
        close(sockfd);
        sockfd = -1;
    }
    
    if (clientSockfd >= 0) {
        close(clientSockfd);
        clientSockfd = -1;
    }
    
    // if (receiveThread.joinable()) {
    //     receiveThread.join();
    // }
}

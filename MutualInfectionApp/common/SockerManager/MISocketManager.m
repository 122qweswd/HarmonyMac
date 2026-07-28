//
//  MISocketManager.m
//  MutualInfectionApp
//
//  Created by Niko on 2025/9/9.
//

#import "MISocketManager.h"

@interface MISocketManager ()
@property (nonatomic, strong) GCDAsyncSocket *serverSocket;
@property (nonatomic, strong) GCDAsyncSocket *clientSocket;
@property (nonatomic, assign, readwrite) SocketMode mode;
@end

@implementation MISocketManager

+ (instancetype)sharedManager {
    static MISocketManager *mgr;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mgr = [[MISocketManager alloc] init];
    });
    return mgr;
}

#pragma mark - Server

- (BOOL)startServerOnPort:(uint16_t)port error:(NSError **)error {
    self.mode = SocketModeServer;
    self.serverSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    BOOL success = [self.serverSocket acceptOnPort:port error:error];
    if (success) NSLog(@"服务端启动成功，监听端口: %d", port);
    return success;
}

#pragma mark - Client

- (BOOL)connectToServer:(NSString *)host port:(uint16_t)port error:(NSError **)error {
    self.mode = SocketModeClient;
    self.clientSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    BOOL success = [self.clientSocket connectToHost:host onPort:port error:error];
    if (success) NSLog(@"客户端正在连接 %@:%d", host, port);
    return success;
}

#pragma mark - Send

- (void)sendMessage:(NSString *)msg {
    if (!self.clientSocket) return;
    NSString *fullMsg = [msg stringByAppendingString:@"\r\n"]; // 使用 CRLF 作为分隔符
    NSData *data = [fullMsg dataUsingEncoding:NSUTF8StringEncoding];
    [self.clientSocket writeData:data withTimeout:-1 tag:0];
}

- (void)stop {
    if (self.serverSocket) {
        [self.serverSocket disconnect];
        self.serverSocket = nil;
    }
    
    if (self.clientSocket) {
        [self.clientSocket disconnect];
        self.clientSocket = nil;
    }
    
    NSLog(@"Socket 已停止");
}

#pragma mark - GCDAsyncSocketDelegate

/// 服务端接收新连接
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    NSLog(@"服务端收到新连接: %@", newSocket.connectedHost);
    self.clientSocket = newSocket;
    if (self.onConnect) self.onConnect(newSocket.connectedHost, newSocket.connectedPort);
    [newSocket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
}

/// 客户端连接成功
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    NSLog(@"客户端连接成功: %@:%d", host, port);
    if (self.onConnect) self.onConnect(host, port);
    [sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
}

/// 收到消息
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    NSString *msg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    msg = [msg stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSLog(@"收到消息: %@", msg);
    if (self.onReceiveMessage) self.onReceiveMessage(msg);
    
    // 继续监听
    [sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
}

/// 连接断开
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    NSLog(@"Socket 断开: %@", err);
    if (self.onDisconnect) self.onDisconnect(err);
}


@end

//
//  MISocketManager.h
//  MutualInfectionApp
//
//  Created by Niko on 2025/9/9.
//

#import <Foundation/Foundation.h>
#import <GCDAsyncSocket.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SocketMode) {
    SocketModeServer,
    SocketModeClient
};

@interface MISocketManager : NSObject <GCDAsyncSocketDelegate>

+ (instancetype)sharedManager;

@property (nonatomic, assign, readonly) SocketMode mode;

/// 连接成功回调
@property (nonatomic, copy) void(^onConnect)(NSString *host, uint16_t port);

/// 断开连接回调
@property (nonatomic, copy) void(^onDisconnect)(NSError * _Nullable error);

/// 收到消息回调
@property (nonatomic, copy) void(^onReceiveMessage)(NSString *msg);


/// 启动socket服务端
/// - Parameters:
///   - port: 端口
///   - error: 错误信息
- (BOOL)startServerOnPort:(uint16_t)port error:(NSError **)error;


/// 连接到socket服务端
/// - Parameters:
///   - host: IP
///   - port: 端口
///   - error: 错误信息
- (BOOL)connectToServer:(NSString *)host port:(uint16_t)port error:(NSError **)error;


/// 发送数据（自动加 \r\n 分隔）
/// - Parameter msg: 发送的内容
- (void)sendMessage:(NSString *)msg;

/// 停止
- (void)stop;

@end


NS_ASSUME_NONNULL_END

//
//  NetworkManager.h
//
//  Created by Niko on 2025/9/2.
//
#import <Foundation/Foundation.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NetworkStatus) {
    NetworkStatusDisconnected,   // 网络断开
    NetworkStatusWiFi,           // Wi-Fi 已连接
    NetworkStatusOther           // 其他网络（蜂窝、有线、虚拟等）
};

typedef void(^NetworkStatusChangedBlock)(NetworkStatus status);
typedef void(^NetworkInfoCompletionBlock)(NSDictionary *);

@interface NetworkManager : NSObject <CLLocationManagerDelegate>

+ (instancetype)shared;

// 停止监听
- (void)StopMonitoring;

// 开始监听网络状态，监听到 WIFI 后给c++传参数
- (void)StartNetworkMonitor;

- (void)RemoveSSID:(NSString *)ssid isRetry:(BOOL)isRetry;
- (void)ConnectSSID:(NSString *)ssid passphrase:(NSString *)passphrase;
- (BOOL)IsConnected;
- (void)RefreshNetwork;
@end

NS_ASSUME_NONNULL_END

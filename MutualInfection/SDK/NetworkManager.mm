//
//  NetworkManager.mm
//
//  Created by Niko on 2025/9/2.
//

#import "NetworkManager.h"
#import <Network/Network.h>
//#import <NetworkExtension/NetworkExtension.h>
//#import <CoreLocation/CoreLocation.h>
//#import <SystemConfiguration/CaptiveNetwork.h>
#import <Foundation/Foundation.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <net/if.h>
#include "LogHelper.h"
#include "ShareManager.h"
#include "COAPDiscSerializer.hpp"
#include <TargetConditionals.h>
#include "TcpChannel.h"

// 平台特定的导入
#if TARGET_OS_IOS
#import <NetworkExtension/NetworkExtension.h>
#import <CoreLocation/CoreLocation.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#elif TARGET_OS_MAC
#import <SystemConfiguration/SystemConfiguration.h>
#import <CoreWLAN/CoreWLAN.h>
#import <CoreLocation/CoreLocation.h>
#import <Cocoa/Cocoa.h>
#import <AppKit/AppKit.h>
#import <CoreWLAN/CoreWLAN.h>
#endif

@interface NetworkManager ()
@property (nonatomic, strong) nw_path_monitor_t monitor;
@property (nonatomic, strong) dispatch_queue_t monitorQueue;
@property (nonatomic, strong) dispatch_queue_t wifiQueue;
@property (nonatomic, copy) NetworkStatusChangedBlock statusChangedBlock;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, copy) NetworkInfoCompletionBlock fetchCompletionHandler;
@property (nonatomic, assign) NetworkStatus currentStatus;
@property (nonatomic, strong) NSString *targetSSID;
@end

@implementation NetworkManager

+ (instancetype)shared {
    static NetworkManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _monitorQueue = dispatch_queue_create("com.wifiInfo.networkmonitor", DISPATCH_QUEUE_SERIAL);
        _wifiQueue = dispatch_queue_create("com.wifi.connection", DISPATCH_QUEUE_SERIAL);
        _monitor = nw_path_monitor_create_with_type(nw_interface_type_wifi);
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        _currentStatus = NetworkStatusDisconnected;

        // 设置网络监控回调
        __weak typeof(self) weakSelf = self;
        nw_path_monitor_set_update_handler(_monitor, ^(nw_path_t  _Nonnull path) {
            [weakSelf handleNetworkPathUpdate:path];
        });
    }
    return self;
}

- (void)startMonitoringWithStatusCallback:(NetworkStatusChangedBlock)statusCallback {
    self.statusChangedBlock = statusCallback;
    
    if (!self.monitor) {
        LOG_ERROR_S("Monitor not initialized");
        return;
    }

    nw_path_monitor_set_queue(self.monitor, self.monitorQueue);
    nw_path_monitor_start(self.monitor);
    LOG_DEBUG_S("Network monitoring started");
}

- (void)StopMonitoring {
    if (self.monitor) {
        nw_path_monitor_cancel(self.monitor);
        LOG_DEBUG_S("Network monitoring stopped");
    }
}

- (void)handleNetworkPathUpdate:(nw_path_t)path {
    nw_path_status_t status = nw_path_get_status(path);
//    LOG_DEBUG_S("real network statue from native: %d, old status: %d", status, self.currentStatus);
    NetworkStatus newStatus = NetworkStatusWiFi;
    if (status == nw_path_status_unsatisfied) {
        newStatus = NetworkStatusDisconnected;
    }

    // 只有当状态真正改变时才回调
//    if (newStatus == NetworkStatusWiFi || self.currentStatus != newStatus) {
    LOG_DEBUG_S("real network statue from native: %d, new status: %d, old status: %d", status, newStatus, self.currentStatus);
    if (self.currentStatus != newStatus) {
        self.currentStatus = newStatus;
        if (self.statusChangedBlock) {
            self.statusChangedBlock(newStatus);
        }
    }
}

- (void)fetchCurrentNetworkInfoWithCompletion:(NetworkInfoCompletionBlock)completion {
//    self.fetchCompletionHandler = completion;
    
#if TARGET_OS_IOS
    // 先检查位置权限
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    if (status == kCLAuthorizationStatusNotDetermined) {
        // 如果尚未请求，则请求使用期间的位置权限
        LOG_DEBUG_S("request location in use authorization");
        [self.locationManager requestWhenInUseAuthorization];
        return;
    } else if (status != kCLAuthorizationStatusAuthorizedAlways && 
               status != kCLAuthorizationStatusAuthorizedWhenInUse) {
        // 用户已拒绝或限制权限
        if (completion) {
            LOG_DEBUG_S("user reject location authorization");
            NSDictionary *networkInfo = @{
                @"code":@"403",
                @"erro":@"no location authorization"
            };
            completion(networkInfo);
        }
        return;
    }
#endif
        
#if TARGET_OS_MAC
        CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
        if (status == kCLAuthorizationStatusNotDetermined || status == kCLAuthorizationStatusRestricted) {
            [self.locationManager requestLocation];
        } else if (status == kCLAuthorizationStatusDenied) {
            [self showLocationPermissionDeniedAlert];
        }
#endif
    // 已有权限，直接获取网络信息
    [self sendCurrentNetworkInfo:completion];
}
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {

}
- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {

}

- (void)showLocationPermissionDeniedAlert {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"定位权限已被拒绝"];
        [alert setInformativeText:@"请前往”系统设置“->“隐私与安全性”->“定位服务”中开启权限，以便于您正常使用分享功能。"];
        [alert addButtonWithTitle:@"去设置"];
        [alert addButtonWithTitle:@"取消"];
        
        [alert beginSheetModalForWindow:[NSApp mainWindow] completionHandler:^(NSModalResponse returnCode) {
            if (returnCode == NSAlertFirstButtonReturn) {
                NSURL *url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices"];
                [[NSWorkspace sharedWorkspace] openURL:url];
            }
        }];
    });
}

// 获取当前网络信息（SSID、BSSID、IP地址）
- (void)sendCurrentNetworkInfo:(NetworkInfoCompletionBlock)completion {
    __block NSString *ssid = [NSString string];
    __block NSString *bssid = [NSString string];
    
    LOG_DEBUG_S("connect wifi success");
    self.fetchCompletionHandler = completion;
    
    std::string ip = ShareManager::shared().GetPeerIP();
    std::string netmask = "";
    std::string broadcastIp = "";
    std::string ipv6 = "";
    std::string ipv6Prefix = "";
    std::string macAddr = "";
    std::string error = "";
    std::string code = "0";
    if (!GetLocalWifiIPAddr(ip, netmask, broadcastIp, ipv6, ipv6Prefix, macAddr, 10)) {
        code = "404";
    }

    // 获取当前所有网络接口信息
#if TARGET_OS_IOS
    if (@available(iOS 14.0, *)) {
        // iOS 14+ 使用异步方式获取
        [NEHotspotNetwork fetchCurrentWithCompletionHandler:^(NEHotspotNetwork * _Nullable currentNetwork) {
            if (currentNetwork) {
                ssid = currentNetwork.SSID;
                bssid = currentNetwork.BSSID;
            } else {
                LOG_DEBUG_S("No current network found");
            }
            if (self.fetchCompletionHandler != nil) {
                self.fetchCompletionHandler(@{
                    @"code": [NSString stringWithUTF8String:code.c_str()],
                    @"ssid": ssid,
                    @"bssid": bssid,
                    @"ip": [NSString stringWithUTF8String:ip.c_str()],
                    @"netmask": [NSString stringWithUTF8String:netmask.c_str()],
                    @"broadcastIp": [NSString stringWithUTF8String:broadcastIp.c_str()],
                    @"ipv6": [NSString stringWithUTF8String:ipv6.c_str()],
                    @"ipv6Prefix": [NSString stringWithUTF8String:ipv6Prefix.c_str()],
                    @"error": [NSString stringWithUTF8String:error.c_str()],
                });
            }
            self.fetchCompletionHandler = nil;
        }];
    } else {
        // iOS 14 以下版本
        NSArray *interfaceNames = (__bridge_transfer NSArray *)CNCopySupportedInterfaces();
        LOG_DEBUG_S("current interfaceNames.count = %d", interfaceNames.count);
        for (NSString *interfaceName in interfaceNames) {
            // 获取指定接口的信息
            NSDictionary *networkInfo = (__bridge_transfer NSDictionary *)CNCopyCurrentNetworkInfo((__bridge CFStringRef)interfaceName);
            if (networkInfo[@"SSID"]) {
                ssid = networkInfo[@"SSID"];
                bssid = networkInfo[@"BSSID"];
                break; // 通常第一个有效的就是当前连接的Wi-Fi
            }
        }
        if (self.fetchCompletionHandler != nil) {
            self.fetchCompletionHandler(@{
                @"code": [NSString stringWithUTF8String:code.c_str()],
                @"ssid": ssid,
                @"bssid": bssid,
                @"ip": [NSString stringWithUTF8String:ip.c_str()],
                @"netmask": [NSString stringWithUTF8String:netmask.c_str()],
                @"broadcastIp": [NSString stringWithUTF8String:broadcastIp.c_str()],
                @"ipv6": [NSString stringWithUTF8String:ipv6.c_str()],
                @"ipv6Prefix": [NSString stringWithUTF8String:ipv6Prefix.c_str()],
                @"error": [NSString stringWithUTF8String:error.c_str()],
            });
        }
        self.fetchCompletionHandler = nil;
    }
#elif TARGET_OS_MAC
    @try {
        // 使用 CoreWLAN 框架获取 WiFi 信息
        CWInterface *wifiInterface = [CWWiFiClient sharedWiFiClient].interface;
        NSString *ssid = wifiInterface.ssid ?: @"";
        NSString *bssid = wifiInterface.bssid ?: @"";

        COAPDiscSerializer::GetInstance()->SetWifiIp(ip, broadcastIp);
        if (self.fetchCompletionHandler != nil && ![ssid  isEqual: @""]) {
            self.fetchCompletionHandler(@{
                @"code": @"0",
                @"ssid": ssid,
                @"bssid": bssid,
                @"ip": [NSString stringWithUTF8String:ip.c_str()],
                @"netmask": [NSString stringWithUTF8String:netmask.c_str()],
                @"broadcastIp": [NSString stringWithUTF8String:broadcastIp.c_str()],
                @"ipv6": [NSString stringWithUTF8String:ipv6.c_str()],
                @"ipv6Prefix": [NSString stringWithUTF8String:ipv6Prefix.c_str()],
                @"error": [NSString stringWithUTF8String:error.c_str()],
            });
            self.fetchCompletionHandler = nil;
        } else {
            LOG_DEBUG_S("No current network found");
        }
    } @catch (NSException *exception) {
        LOG_DEBUG_S("Error getting WiFi info: %s", [exception.reason UTF8String]);
        return;
    }
#endif
}

#pragma mark - CLLocationManagerDelegate
- (void)locationManagerDidChangeAuthorization {
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    if (status == kCLAuthorizationStatusAuthorizedAlways
#if TARGET_IOS
        || status == kCLAuthorizationStatusAuthorizedWhenInUse
#endif
        )
    {
        // 用户授权，重新尝试获取网络信息
        if (self.fetchCompletionHandler) {
            [self sendCurrentNetworkInfo:self.fetchCompletionHandler];
        }
        self.fetchCompletionHandler = nil;
        
    } else if (status != kCLAuthorizationStatusNotDetermined) {
        // 用户拒绝
        if (self.fetchCompletionHandler) {
            self.fetchCompletionHandler(@{
                @"code": @"403",
                @"error": @"user reject the location authorization"
            });
        }
        self.fetchCompletionHandler = nil;
    }
}

- (void)dealloc {
    [self StopMonitoring];
}

/// 开始监听网络状态，监听到 WIFI 后给c++传参数
- (void)StartNetworkMonitor {
    [[NetworkManager shared] startMonitoringWithStatusCallback:^(NetworkStatus status) {
        switch (status) {
            case NetworkStatusDisconnected:
                dispatch_async(dispatch_get_main_queue(), ^{
                    COAPDiscSerializer::GetInstance()->SetWifiStatus(false);
                    COAPDiscSerializer::GetInstance()->StopService();
                    ShareManager::shared().OnNetworkDisconnect();
                });
                break;
            case NetworkStatusWiFi:
                LOG_DEBUG_S("WIFI connection succeed!!");
#if TARGET_OS_IOS
                if (@available(iOS 14.0, *)) {
                    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
                    BOOL isFullAccuracy = self.locationManager.accuracyAuthorization == CLAccuracyAuthorizationFullAccuracy;
                    if (!isFullAccuracy) {
                        [self.locationManager requestTemporaryFullAccuracyAuthorizationWithPurposeKey:@"UTGetWiFiSSID" completion:^(NSError * _Nullable error) {
                            LOG_ERROR_S("requestTemporaryFullAccuracyAuthorizationWithPurposeKey: %s", [error.localizedFailureReason UTF8String]);
                        }];
                    }
                }
#endif
                // 获取WiFi详细信息
                [[NetworkManager shared] fetchCurrentNetworkInfoWithCompletion:^(NSDictionary* networkInfo) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        std::map<std::string, std::string> networkMap;
                        int code = 404;
                        if (networkInfo != nil) {
                            if (networkInfo[@"code"]) {
                                code = std::atoi([networkInfo[@"code"] UTF8String]);
                            }
                            if (networkInfo[@"error"]) {
                                networkMap.emplace("error", [networkInfo[@"error"] UTF8String]);
                            }
                        }
                        if (code == 0) {
                            if (networkInfo[@"ssid"]) {
                                networkMap.emplace("ssid", [networkInfo[@"ssid"] UTF8String]);
                            }

                            if (networkInfo[@"bssid"]) {
                                networkMap.emplace("bssid", [networkInfo[@"bssid"] UTF8String]);
                            }

                            if (networkInfo[@"ip"]) {
                                networkMap.emplace("ip", [networkInfo[@"ip"] UTF8String]);
                            }

                            if (networkInfo[@"netmask"]) {
                                networkMap.emplace("netmask", [networkInfo[@"netmask"] UTF8String]);
                            }

                            if (networkInfo[@"broadcastIp"]) {
                                networkMap.emplace("broadcastIp", [networkInfo[@"broadcastIp"] UTF8String]);
                            }

                            // 添加IPv6地址处理
                            if (networkInfo[@"ipv6"]) {
                                networkMap.emplace("ipv6", [networkInfo[@"ipv6"] UTF8String]);
                            }

                            // 添加IPv6地址处理
                            if (networkInfo[@"ipv6Prefix"]) {
                                networkMap.emplace("ipv6Prefix", [networkInfo[@"ipv6Prefix"] UTF8String]);
                            }

                            COAPDiscSerializer::GetInstance()->SetWifiIp(networkMap["ip"], networkMap["broadcastIp"]);
                            ShareManager::shared().OnNetworkConnect(code, networkMap);
                            COAPDiscSerializer::GetInstance()->CreateServiceThread();
                            COAPDiscSerializer::GetInstance()->SetWifiStatus(true);
                            TcpChannel::GetInstance()->StartListenFd();
                        } else {
                            LOG_ERROR_S("system error, null network info");
                        }
                    });
                }];
                break;
            case NetworkStatusOther:
                LOG_ERROR_S("other network status change");
                break;
        }
    }];
}

- (void)RemoveSSID:(NSString *)ssid isRetry:(BOOL)isRetry {
    std::string anoSSID = AnonymizeString([ssid UTF8String]);
    LOG_DEBUG_S("remove ssid: %s, retry: %d", anoSSID.c_str(), isRetry);
    //    [[NEHotspotConfigurationManager sharedManager] removeConfigurationForSSID:ssid];
    //    self.currentStatus = NetworkStatusDisconnected;
#if TARGET_OS_IOS
    if (!isRetry) {
        [[NEHotspotConfigurationManager sharedManager] removeConfigurationForSSID:ssid];
    } else {
        [[NEHotspotConfigurationManager sharedManager] getConfiguredSSIDsWithCompletionHandler:^(NSArray<NSString *> * ssidList) {
            for (int index = 0; index < ssidList.count; index++) {
                if ([ssidList[index] isEqualToString:ssid]) {
                    [[NEHotspotConfigurationManager sharedManager] removeConfigurationForSSID:ssid];
                }
            }
        }];
    }
#elif TARGET_OS_MAC
    // macOS 移除已知网络
    dispatch_async(self.wifiQueue, ^{
        CWInterface *interface = [[CWWiFiClient sharedWiFiClient] interface];
        [interface disassociate];
    });
#endif
    self.currentStatus = NetworkStatusDisconnected;
    COAPDiscSerializer::GetInstance()->SetWifiStatus(false);
    ShareManager::shared().OnNetworkDisconnect();
}

- (void)ConnectSSID:(NSString *)ssid passphrase:(NSString *)passphrase {
#if TARGET_OS_IOS
    NEHotspotConfiguration *configuration = [[NEHotspotConfiguration alloc] initWithSSID:ssid
                                                                             passphrase:passphrase
                                                                                   isWEP:FALSE];
    self.targetSSID = ssid;
    [[NEHotspotConfigurationManager sharedManager] applyConfiguration:configuration
                                                    completionHandler:^(NSError* _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LOG_DEBUG_S("connect wifi callback");
            if (error != nil) {
                if (error.code == 7) {
                    LOG_DEBUG_S("user decline to join wifi network");
                    ShareManager::shared().OnNetworkError(ERRCODE_USER_DECLINE_TO_JOIN_WIFI_NETWORK);
                } else if (error.code == 8){
                    LOG_DEBUG_S("internal error");
                    ShareManager::shared().OnNetworkError(ERRCODE_WIFI_NETWORK_INTERNAL_ERROR);
                } else {
                    LOG_DEBUG_S("connect wifi error[%d]: %s", error.code, [error.localizedDescription UTF8String]);
                    ShareManager::shared().OnNetworkError(error.code);
                }
            } else {
                LOG_DEBUG_S("fetech current ssid info");
                if (@available(iOS 14.0, *)) {
                    // iOS 14+ 使用异步方式获取
                    __block NSString *ssid = @"";
                    [NEHotspotNetwork fetchCurrentWithCompletionHandler:^(NEHotspotNetwork * _Nullable currentNetwork) {
                        if (currentNetwork) {
                            ssid = currentNetwork.SSID;
                        }
                        [self HandleConnected:ssid];
                    }];
                } else {
                    // iOS 14 以下版本
                    NSArray *interfaceNames = (__bridge_transfer NSArray *)CNCopySupportedInterfaces();
                    LOG_DEBUG_S("current interfaceNames.count = %d", interfaceNames.count);
                    for (NSString *interfaceName in interfaceNames) {
                        // 获取指定接口的信息
                        NSDictionary *networkInfo = (__bridge_transfer NSDictionary *)CNCopyCurrentNetworkInfo((__bridge CFStringRef)interfaceName);
                        if (networkInfo[@"SSID"]) {
                            [self HandleConnected:networkInfo[@"SSID"]];
                            break; // 通常第一个有效的就是当前连接的Wi-Fi
                        }
                    }
                    LOG_DEBUG_S("complete enumerate all interfaces");
                }
            }
        });
    }];

#elif TARGET_OS_MAC
    self.targetSSID = ssid;
    dispatch_async(self.wifiQueue, ^{
        NSError *error = nil;
        int retry = 0;
        NSString *result = @"";
        CWInterface *interface = [[CWWiFiClient sharedWiFiClient] interface];
        if (!interface) {
            LOG_DEBUG_S("Failed to get WiFi interface");
            dispatch_async(dispatch_get_main_queue(), ^(){
                [self HandleConnected:@""];
            });
        }
        while (retry < 7) {
            NSSet<CWNetwork*> *networks = [interface scanForNetworksWithSSID:[ssid dataUsingEncoding:NSUTF8StringEncoding] error:&error];
            if (error) {
                std::string anoSSID = AnonymizeString([ssid UTF8String]);
                LOG_DEBUG_S("Failed to scan target network:%s, retry %d times", anoSSID.c_str(), retry);
                retry++;
                [NSThread sleepForTimeInterval:0.5];
                continue;
            }
            for (CWNetwork *network in networks) {
                if ([interface associateToNetwork:network password:passphrase error:&error]) {
                    retry = 7;
                    std::string anoSuccessSSID = AnonymizeString([ssid UTF8String]);
                    LOG_DEBUG_S("Success to connect target network:%s, error:%s", anoSuccessSSID.c_str(), [[error localizedDescription] UTF8String]);
                    result = ssid;
                    break;
                }
                std::string anoFailSSID = AnonymizeString([ssid UTF8String]);
                LOG_DEBUG_S("Failed to connect target network:%s", anoFailSSID.c_str());
            }
            retry++;
        }
        dispatch_async(dispatch_get_main_queue(), ^(){
            [self HandleConnected:result];
        });
    });
#endif
}

- (void)HandleConnected:(NSString *)ssid {
    if (ssid == nil) {
        LOG_ERROR_S("network error: ssid is nil");
        ShareManager::shared().OnNetworkError(ERRCODE_WIFI_NETWORK_INTERNAL_ERROR);
        return;
    }
    std::string anoSSID = AnonymizeString([ssid UTF8String]);
    std::string anoTargetSSID = AnonymizeString([self.targetSSID UTF8String]);
    LOG_DEBUG_S("current assoicate network: %s, target network:%s", anoSSID.c_str(), anoTargetSSID.c_str());
    if (![ssid isEqualToString:self.targetSSID]) {
        ShareManager::shared().OnNetworkError(ERRCODE_WIFI_NOT_MATCH_SSID);
    } else {
        ShareManager::shared().FastFetchIP();
    }
}

- (BOOL)IsConnected {
    if (self.currentStatus != NetworkStatusWiFi) {
        return FALSE;
    }
    return TRUE;
}

- (void)RefreshNetwork {
    if (self.statusChangedBlock) {
        dispatch_async(_monitorQueue, ^{
            self.statusChangedBlock(self.currentStatus);
        });
        
    }
}
@end

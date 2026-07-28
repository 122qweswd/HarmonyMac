//
//  MIHotspotDetector.m
//  MutualInfectionApp
//
//  Created by tsbook on 2025/10/11.
//

#import "MIHotspotDetector.h"
#import "ShareAPI.h"
#import <ifaddrs.h>    // 网络接口操作
#import <arpa/inet.h>  // IP地址转换（inet_ntoa、inet_addr）
#import <netinet/in.h> // 定义sockaddr_in等结构体
#import <sys/socket.h> //  socket相关常量（如AF_INET）

@interface MIHotspotDetector ()

@property(nonatomic,strong)ShareAPI *manager;

@end

@implementation MIHotspotDetector

+ (instancetype)shared {
    static MIHotspotDetector *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _manager = [ShareAPI shared];
    }
    return self;
}


/**
 *  字符串IP转32位整数（如 "172.20.10.5" → 0xAC140A05）
 *  @param ipStr  IPv4地址字符串（如 "172.20.10.5"）
 *  @return 32位无符号整数（大端序转主机序）
 */
static uint32_t ipStrToUInt32(NSString *ipStr) {
    if (!ipStr || ipStr.length == 0) return 0;
    // inet_addr将字符串IP转为网络字节序（大端）的32位整数
    in_addr_t addr = inet_addr(ipStr.UTF8String);
    // 转为主机字节序（小端），方便计算
    return ntohl(addr);
}

/**
 *  判断IP是否在目标网段内
 *  @param ipUInt32      待判断的IP（32位整数）
 *  @param networkUInt32 目标网段的网络地址（如 172.20.10.0 → 0xAC140A00）
 *  @param subnetMaskUInt32 子网掩码（如 /28 → 255.255.255.240 → 0xFFFFFFF0）
 *  @return YES：在网段内；NO：不在
 */
static BOOL isIPInSubnet(uint32_t ipUInt32, uint32_t networkUInt32, uint32_t subnetMaskUInt32) {
    // IP与掩码运算得到网络地址 → 与目标网络地址比较
    return (ipUInt32 & subnetMaskUInt32) == (networkUInt32 & subnetMaskUInt32);
}

/**
 *  判断iOS是否开启个人热点（通过ap0接口+172.20.10.x/28网段）
 *  @return YES：可能开启热点；NO：未开启
 */
- (BOOL)isPersonalHotspotEnabled {
    // 1. 目标网段配置（172.20.10.0/28）
    NSString *targetNetworkStr = @"172.20.10.0";   // 网络地址
    NSString *targetSubnetMaskStr = @"255.255.255.240"; // 子网掩码
    uint32_t targetNetworkUInt32 = ipStrToUInt32(targetNetworkStr);
    uint32_t targetSubnetMaskUInt32 = ipStrToUInt32(targetSubnetMaskStr);
    
    // 2. 获取所有网络接口列表（getifaddrs需传入指针的指针）
    struct ifaddrs *ifap = NULL;
    if (getifaddrs(&ifap) != 0) {
        NSLog(@"获取接口失败：%s", strerror(errno));
        return NO;
    }
    
    // 3. 遍历接口列表（注意：需用临时指针遍历，避免修改原始ifap）
    BOOL isHotspot = NO;
    struct ifaddrs *ifa = ifap;
    while (ifa != NULL) {
        // --------------------------
        // 筛选条件1：接口名称（优先ap0，次选en0）
        // --------------------------
        NSString *ifName = [NSString stringWithUTF8String:ifa->ifa_name];
//        if (![ifName isEqualToString:@"ap0"] && ![ifName isEqualToString:@"en0"]) {
//            ifa = ifa->ifa_next; // 不是目标接口，跳过
//            continue;
//        }
        
        // --------------------------
        // 筛选条件2：仅处理IPv4地址（AF_INET）
        // --------------------------
        // ifa_addr 存储接口地址，需判断地址族是否为IPv4

//        if (ifa->ifa_addr == NULL || ifa->ifa_addr->sa_family != AF_INET) {
//            ifa = ifa->ifa_next; // 非IPv4，跳过
//            continue;
//        }
        
        // --------------------------
        // 筛选条件3：解析IP并验证网段
        // --------------------------
        // 将sockaddr转为sockaddr_in（IPv4专用结构体）
        struct sockaddr_in *addrIn = (struct sockaddr_in *)ifa->ifa_addr;
        // inet_ntoa 将网络字节序的IP转为字符串（如 0xAC140A05 → "172.20.10.5"）
        NSString *ipStr = [NSString stringWithUTF8String:inet_ntoa(addrIn->sin_addr)];
        uint32_t ipUInt32 = ipStrToUInt32(ipStr);
        NSString *ipStrLog = [NSString stringWithFormat:@"ifaName: %@ -- sa_family: %hhu, ip地址：%@ ",ifName,ifa->ifa_addr->sa_family,ipStr];
//        NSLog(@"%@",ipStrLog);
//        [_manager Log:1 :ipStrLog];
        // 验证IP是否在目标网段（排除网络地址.0和广播地址.15）
        if (isIPInSubnet(ipUInt32, targetNetworkUInt32, targetSubnetMaskUInt32)) {
            uint32_t ipLastByte = ipUInt32 & 0xFF; // 获取IP最后一段（如172.20.10.5 → 5）
            if (ipLastByte > 0 && (ipLastByte == 1 || ipLastByte == 28)) { // 可用IP：1~14
//                NSLog(@"[%@] 接口存在目标IP：%@", ifName, ipStr);
                isHotspot = YES;
                break; // 找到一个符合条件的IP即可退出
            }
        }
        
        ifa = ifa->ifa_next; // 遍历下一个接口
    }
    
    // 4. 释放接口列表内存（必须调用，避免内存泄漏）
    freeifaddrs(ifap);
    return isHotspot;
}

@end

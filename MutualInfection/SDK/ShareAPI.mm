//
//  ShareAPI.mm
//  MutualInfection
//
//  Created by Law on 2025/9/22.
//

#import "ShareAPI.h"
#include <map>
#include <string>
#include "ShareManager.h"
#include "LogHelper.h"

// 添加OpenSSL头文件
#include <openssl/evp.h>
#include <openssl/rsa.h>
#include <openssl/pem.h>

#include "COAPDiscSerializer.hpp"
#include "TcpChannel.h"

@interface ShareAPI ()

@property (strong, nonatomic) DiscManager *discManager;
@property (strong, nonatomic) DelegateManager *delegateManager;
@property (strong, nonatomic) LivePhotoUtilOC *livePhotoUtil;
@property (strong, nonatomic) TranscodeMediaOC *transcodeMediaUtil;

@end

@implementation ShareAPI

+ (instancetype)shared {
    static ShareAPI *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        LOG_START("");
        _delegateManager = [DelegateManager shared];
        _livePhotoUtil = [LivePhotoUtilOC sharedInstance];
        _transcodeMediaUtil = [TranscodeMediaOC sharedInstance];
    }
    return self;
}

- (void)start {
    _discManager = [DiscManager shared]; // 蓝牙权限
    ShareManager::shared().Initialize(); // 位置权限
    // 在最后添加本地网络权限申请
    [self triggerLocalNetworkPermission];
    COAPDiscSerializer::GetInstance()->Init();
    COAPDiscSerializer::GetInstance()->CreateClientThread();
}


- (void)triggerLocalNetworkPermission {
#if TARGET_OS_IOS
    if (@available(iOS 14.0, *)) {
        // 方法1: 使用 Bonjour 服务浏览器搜索（最有效）
        NSNetServiceBrowser *browser = [[NSNetServiceBrowser alloc] init];
        browser.delegate = self;

        // 搜索本地网络中的服务 - 这会触发权限弹窗
        [browser searchForServicesOfType:@"_http._tcp." inDomain:@"local."];

        // 5秒后停止搜索
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [browser stop];
        });

    }
#elif TARGET_OS_MAC
    if (@available(macOS 11.0, *)) {
        // 发布 Bonjour 服务触发权限弹窗
        NSNetService *service = [[NSNetService alloc] initWithDomain:@"local."
                                                                type:@"_http._tcp."
                                                                name:@"LocalNetworkTest"
                                                                port:8080];
        service.delegate = self;
        [service publish];

        // 5秒后停止
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [service stop];
        });
    }
#endif
}

- (void)enterForeground {
    DeviceManager::shared().SwitchToForeground();
    [self.discManager startScanning];
    [self.discManager startAdvertising];
    ShareManager::shared().DelayRefreshNetwork();
   COAPDiscSerializer::GetInstance()->SetEnterBackgroundStatus(false);
}

- (void)enterBackground {
    DeviceManager::shared().SwitchToBackground();
    [self.discManager stopScanning];
    [self.discManager stopAdvertising];
    COAPDiscSerializer::GetInstance()->SetEnterBackgroundStatus(true);
    COAPDiscSerializer::GetInstance()->StopService();
}

- (void)setDeviceDelegate:(id<DeviceDelegate> _Nullable)delegate {
    self.delegateManager.deviceDelegate = delegate;
}

- (void)setConnectDelegate:(id<ConnectDelegate> _Nullable)delegate {
    self.delegateManager.connectDelegate = delegate;
}

- (void)setTransDelegate:(id<TransDelegate> _Nullable)delegate {
    self.delegateManager.transDelegate = delegate;
}

- (void)setDFXDelegate:(id<DFXDelegate> _Nullable)delegate {
    self.delegateManager.dfxDelegate = delegate;
}

- (NSString *)shareFiles:(NSString *)udid metadata:(NSDictionary *) metadata {
    ShareNode node;
    NSArray<NSString*> *allKeys = metadata.allKeys;
    for (int keyIndex = 0; keyIndex < allKeys.count; keyIndex++) {
        if ([[allKeys objectAtIndex:keyIndex] isEqualToString:@"sendType"]) {
            node.emplace("sendType", [metadata[@"sendType"] UTF8String]);
        }
        if ([[allKeys objectAtIndex:keyIndex] isEqualToString:@"senderName"]) {
            node.emplace("senderName", [metadata[@"senderName"] UTF8String]);
        }
        if ([[allKeys objectAtIndex:keyIndex] isEqualToString:@"itemCount"]) {
            node.emplace("itemCount", [metadata[@"itemCount"] UTF8String]);
        }
        if ([[allKeys objectAtIndex:keyIndex] isEqualToString:@"totalSize"]) {
            node.emplace("totalSize", [metadata[@"totalSize"] UTF8String]);
        }
        if ([[allKeys objectAtIndex:keyIndex] isEqualToString:@"folderCount"]) {
            node.emplace("folderCount", [metadata[@"folderCount"] UTF8String]);
        }
        if ([[allKeys objectAtIndex:keyIndex] isEqualToString:@"fileCount"]) {
            node.emplace("fileCount", [metadata[@"fileCount"] UTF8String]);
        }
        if ([[allKeys objectAtIndex:keyIndex] isEqualToString:@"previewSummary"]) {
            node.emplace("previewSummary", [metadata[@"previewSummary"] UTF8String]);
        }
        if ([[allKeys objectAtIndex:keyIndex] isEqualToString:@"isHighSpeed"]) {
            node.emplace("isHighSpeed", [metadata[@"isHighSpeed"] UTF8String]);
        }
    }
    std::string udidString = [udid UTF8String];
    auto sessioId = ShareManager::shared().ShareFiles(udidString, node);
    if (sessioId >= 0) {
        return [NSString stringWithUTF8String:std::to_string(sessioId).c_str()];
    }
    return nil;
}

- (void)cancelShare:(NSString *)udid {
    std::string udidString = [udid UTF8String];
    ShareManager::shared().CancelSender(udidString);
}

- (void)cancelReceiveShare:(NSString *)udid {
    std::string udidString = [udid UTF8String];
    ShareManager::shared().CancelReceiver(udidString);
}

- (void)sendFiles:(NSString *)udid files:(NSArray<NSDictionary *> *)files {
    std::vector<TransFileInfo> fileList;
    for (int index = 0; index < files.count; index++) {
        NSDictionary * keyInfo = [files objectAtIndex:index];
        NSArray<NSString*> *allKeys = keyInfo.allKeys;
        TransFileInfo info;
        for (int keyIndex = 0; keyIndex < allKeys.count; keyIndex++) {
            if ([[allKeys objectAtIndex:keyIndex] isEqualToString:@"fileName"]) {
                info.fileName = [[keyInfo valueForKey:@"fileName"] UTF8String];
            }
            if ([[allKeys objectAtIndex:keyIndex] isEqualToString:@"fileSize"]) {
                info.fileSize = strtoull([[keyInfo valueForKey:@"fileSize"] UTF8String], 0, 10);
            }
            if ([[allKeys objectAtIndex:keyIndex] isEqualToString:@"fileUrl"]) {
#if TARGET_OS_IOS
                NSString *fileUrlString = [keyInfo valueForKey:@"fileUrl"];
                NSString *decodedUrl = [fileUrlString stringByRemovingPercentEncoding];
                if (decodedUrl == nil) {
                    decodedUrl = fileUrlString;
                }
                info.fileUrl = [decodedUrl UTF8String];
#elif TARGET_OS_MAC
                info.fileUrl = [[keyInfo valueForKey:@"fileUrl"] UTF8String];
#endif
            }
            if ([[allKeys objectAtIndex:keyIndex] isEqualToString:@"fileType"]) {
                info.fileType = [[keyInfo valueForKey:@"fileType"] UTF8String];
            }
            if ([[allKeys objectAtIndex:keyIndex] isEqualToString:@"date_added"]) {
                info.date_added = [[keyInfo valueForKey:@"date_added"] UTF8String];
            }
            if ([[allKeys objectAtIndex:keyIndex] isEqualToString:@"date_taken"]) {
                info.date_taken = [[keyInfo valueForKey:@"date_taken"] UTF8String];
            }
        }
        fileList.emplace_back(info);
    }
    std::string udidString = [udid UTF8String];
    ShareManager::shared().SendFiles(udidString, fileList);
}

- (void)acceptRequest:(NSString *)udid {
    std::string udidString = [udid UTF8String];
    ShareManager::shared().AcceptRequest(udidString);
}
- (void)rejectRequest:(NSString *)udid {
    std::string udidString = [udid UTF8String];
    ShareManager::shared().OnShareReject(true);
}
- (NSDictionary *)queryMetadata:(NSString *)udid {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    return dictionary;
}

- (void)changeBtName:(NSString *)name {
    if (self.discManager != nil) {
        [self.discManager changeBtName:name];
    }
}

- (void)StartLogging:(NSString *)path {
//    const char *cStringPath = [path UTF8String];
//    LOG_START(cStringPath);
}

- (void)CleanupLogging {
    LogHelper::GetInstance()->Cleanup();
}

- (void)Log:(int)grade : (NSString *)log {
    const char *cStringLog = [log UTF8String];
    switch (grade) {
        case LOG_I_GRADE:
            LOG_INFO_S("%s", cStringLog);
            break;
        case LOG_D_GRADE:
            LOG_DEBUG_S("%s", cStringLog);
            break;
        case LOG_E_GRADE:
            LOG_ERROR_S("%s", cStringLog);
            break;
        case LOG_F_GRADE:
            LOG_FATAL_S("%s", cStringLog);
            break;
        default:
            break;
    }
}

- (void)splitLivePhoto:(NSString *)livePhotoPath imagePath:(NSString *)imagePath videoPath:(NSString *)videoPath {
    BOOL success = [self.livePhotoUtil splitLivePhoto:livePhotoPath imagePath:imagePath videoPath:videoPath];
    // 添加回调调用
    if ([self.delegateManager.transDelegate respondsToSelector:@selector(didLivePhotoReady:videoPath:)]) {
        if (success) {
            [self.delegateManager.transDelegate didLivePhotoReady:imagePath videoPath:videoPath];
        } else {
            [self.delegateManager.transDelegate didLivePhotoReady:@"" videoPath:@""];
        }
    }
}

- (BOOL)isLivePhoto:(NSString *)livePhotoPath {
    return [self.livePhotoUtil isLivePhoto:livePhotoPath];
}

- (BOOL)createPlayableLivePhotoWithImagePath:(NSString *)imagePath
                                   videoPath:(NSString *)videoPath
                              livePhotoPath:(NSString *)livePhotoPath {
    return [self.livePhotoUtil createPlayableLivePhotoWithImagePath:imagePath videoPath:videoPath livePhotoPath:livePhotoPath];
}

- (NSString*)GetHostUDID {
    NSString *udid = [[NSUserDefaults standardUserDefaults] stringForKey:@"HOST_UDID"];
    return udid;
}

- (BOOL)checkHostKeyPairExists {
    NSString *keyTag = @"HOST_RSA_KEY";
    
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassKey,
        (__bridge id)kSecAttrApplicationTag: [keyTag dataUsingEncoding:NSUTF8StringEncoding],
        (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeRSA,
        (__bridge id)kSecReturnData: @NO
    };
    
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, NULL);
    
    return status == errSecSuccess;
}

- (nullable NSData *)getHostPublicKey {
    NSString *keyTag = @"HOST_RSA_KEY";
    
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassKey,
        (__bridge id)kSecAttrApplicationTag: [keyTag dataUsingEncoding:NSUTF8StringEncoding],
        (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeRSA,
        (__bridge id)kSecReturnData: @YES
    };
    
    CFDataRef publicKeyData = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&publicKeyData);
    
    if (status != errSecSuccess) {
        NSLog(@"获取公钥失败: %ld", (long)status);
        return nil;
    }
    
    NSData *result = (__bridge_transfer NSData *)publicKeyData;
    return result;
}

- (nullable NSData *)getHostPrivateKey {

    NSString *keyTag = @"HOST_RSA_KEY";
    
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassKey,
        (__bridge id)kSecAttrApplicationTag: [keyTag dataUsingEncoding:NSUTF8StringEncoding],
        (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeRSA,
        (__bridge id)kSecReturnData: @YES,
        (__bridge id)kSecAttrIsPermanent: @YES
    };
    
    CFDataRef privateKeyData = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&privateKeyData);
    
    if (status != errSecSuccess) {
        NSLog(@"获取私钥失败: %ld", (long)status);
        return nil;
    }
    
    NSData *result = (__bridge_transfer NSData *)privateKeyData;
    return result;
}

- (void)sendSDKEvent:(int)eventId {
    ShareManager::shared().OnShareComplete("emulate", (ShareResult)eventId, 0);
}

- (NSString *)getUploadLogFile:(NSString *)id ts:(NSString *)ts {
    std::string appleId = [id UTF8String];
    std::string timeStamp = [ts UTF8String];
    std::string uploadFile = LogHelper::GetInstance()->GetUploadFile(appleId, timeStamp);
    return [NSString stringWithUTF8String:uploadFile.c_str()];
}

- (void)stopCoap {
    COAPDiscSerializer::GetInstance()->StopClient();
    COAPDiscSerializer::GetInstance()->StopService();
}

- (void)setSpeedMode:(bool)isSpeedMode {
    COAPDiscSerializer::GetInstance()->SetSpeedMode(isSpeedMode);
    if (isSpeedMode) {
        COAPDiscSerializer::GetInstance()->CoapDeviceLost();
    }
}

- (void)setShareSize:(long long)shareSize {
    ShareManager::shared().SetShareSize(shareSize);
}

- (void)SetShareType:(NSString*)shareType {// System:系统分享。DeviceFirst:先设备后文件。FileFirst:先文件后设备。
    std::string shareTypeString = [shareType UTF8String];
    ShareManager::shared().SetShareType(shareTypeString);
}

- (void)setEnterBackgroundCountIncrement:(int)count {
    ShareManager::shared().SetEnterBackgroundCountIncrement(count);
}

- (void)setIWorkCount:(int)pages :(int)numbers :(int)keynote {
    ShareManager::shared().SetIWorkCount(pages, numbers, keynote);
}

- (NSString *)anonymizeString:(NSString *)input {
    std::string anoStr = AnonymizeString([input UTF8String]);
    return [NSString stringWithUTF8String:anoStr.c_str()];
}
@end

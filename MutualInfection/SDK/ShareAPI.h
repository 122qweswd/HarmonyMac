//
//  ShareAPI.h
//  MutualInfection
//
//  Created by Law on 2025/9/22.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <Security/Security.h>
#import <Network/Network.h>
#import "DiscManager.h"
#import "DelegateManager.h"
#import "LivePhotoUtilOC.h"
#import "TranscodeMediaOC.h"

NS_ASSUME_NONNULL_BEGIN

@interface ShareAPI : NSObject

//@property (nonatomic, weak) id<DiscDelegate> discDelegate;
//@property (nonatomic, weak) id<ConnectDelegate> connectDelegate;

+ (instancetype)shared NS_SWIFT_NAME(shared());
- (void)start;
- (void)triggerLocalNetworkPermission;
- (void)enterForeground;
- (void)enterBackground;
- (void)setDeviceDelegate:(id<DeviceDelegate> _Nullable)delegate;
- (void)setConnectDelegate:(id<ConnectDelegate> _Nullable)delegate;
- (void)setTransDelegate:(id<TransDelegate> _Nullable)delegate;
- (void)setDFXDelegate:(id<DFXDelegate> _Nullable)delegate;
//
// MetaData JSON format:
//  {
//      sendType：“1”,
//      senderName：“iphone”,
//      itemCount：“1”,
//      totalSize：“1234567”,
//      folderCount：“0”,
//      fileCount：“0“,
//      previewSummary：“xxx”
//  }
//
- (NSString*)shareFiles:(NSString *)udid metadata:(NSDictionary *) metadata;
- (void)cancelShare:(NSString *)udid;
- (void)cancelReceiveShare:(NSString *)udid;

- (void)sendFiles:(NSString *)udid files:(NSArray<NSDictionary *> *)files;

- (void)acceptRequest:(NSString *)udid;
- (void)rejectRequest:(NSString *)udid;

- (NSDictionary *)queryMetadata:(NSString *)udid;
- (void)changeBtName:(NSString *)name;

- (void)splitLivePhoto:(NSString *)livePhotoPath imagePath:(NSString *)imagePath videoPath:(NSString *)videoPath;
- (BOOL)isLivePhoto:(NSString *)path;
- (BOOL)createPlayableLivePhotoWithImagePath:(NSString *)imagePath
                                   videoPath:(NSString *)videoPath
                              livePhotoPath:(NSString *)livePhotoPath;
- (void)StartLogging:(NSString *)path;
- (void)Log:(int)grade : (NSString *)log;
- (void)CleanupLogging;
//- (NSString *)GenerateUDID;
//- (NSString *)GetHostUDID;

- (BOOL)checkHostKeyPairExists;

//- (BOOL)generateAndSaveHostKeyPair;

- (nullable NSData *)getHostPublicKey;

- (nullable NSData *)getHostPrivateKey;
//typedef enum {
//    SHARE_SUCCESS,
//    SHARE_REJECT_SELF,
//    SHARE_REJECT_PEER,
//    SHARE_CANCEL_SELF,
//    SHARE_CANCEL_PEER,
//    SHARE_CANCEL_PEER_BUSY,
//    SHARE_ERROR_TIMEOUT,
//    SHARE_ERROR_TRANS_SELF,
//}
- (void)sendSDKEvent:(int)eventId;

- (NSString *)getUploadLogFile:(NSString *)id ts:(NSString *)ts;

- (void)stopCoap;

- (void)setSpeedMode:(bool)isSpeedMode;

- (void)setShareSize:(long long)shareSize;

- (void)SetShareType:(NSString *)shareType;

- (void)setEnterBackgroundCountIncrement:(int)count;

- (void)setIWorkCount:(int)pages :(int)numbers :(int)keynote;

- (NSString *)anonymizeString:(NSString *)input;
@end

NS_ASSUME_NONNULL_END

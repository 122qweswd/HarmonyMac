//
//  DelegateManager.h
//  MutualInfection
//
//  Created by apple on 2025/9/12.
//

// DelegateManager.h
#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

NS_ASSUME_NONNULL_BEGIN

@protocol DFXDelegate <NSObject>
@optional
- (void)dfxReport:(NSString *)log;
@end

@protocol DeviceDelegate <NSObject>
@optional
// Device JSON format:
//  {
//      udid：“1234ABCD”,
//      name：“Mate80”,
//      type：“1”
//  }
- (void)didDeviceFound:(NSString *)udid device:(NSDictionary *)device;
- (void)didDeviceUpdate:(NSString *)udid device:(NSDictionary *)device;
- (void)didDeviceLost:(NSString *)udid;
@end

@protocol ConnectDelegate <NSObject>
@optional
//
// Status Enumerate：
//  - "connecting":       connected the BLE device
//  - "channelConnected": complete auth session setup
//  - "joinwifi":         start to join wifi
//  - "ccmpPassed":       complete CCMP
//  - "connected":        complete connection
//
- (void)didConnect:(NSString *)udid status:(NSString *)status;

//
// reanson: peer_busy | trans_error | timeout | nospace
//
- (void)didDisconnect:(NSString *)udid reason:(NSString *)reason errorCode:(int)errorCode;

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
- (void)didMetaRecv:(NSString *)udid hwid:(NSString *)hwid metadata:(NSDictionary *)metadata isCoap:(bool)isCoap;

- (void)didAccept:(NSString *)udid;
- (void)didReject:(NSString *)udid;
- (void)didCancel:(NSString *)udid;
- (void)didSelfCancel:(NSString *)udid;
@end

@protocol TransDelegate <NSObject>
@optional
- (void)didRecvAllFiles:(NSString *)udid files:(NSArray<NSString*> *)files totalBytes:(NSNumber *)totalBytes;
- (NSString *)didRecvStart:(NSString *)udid file:(NSString*)file;
- (void)didRecvData:(NSString *)udid data:(NSData*) data file:(NSString *)file;
//
// STAT JSON format:
// {
//      totalBytes: xxxx,
//      totalTransfer: xxxx,
//      fileList: [{
//                  filename: xxxx,
//                  status: "completed" | "inprogress" | "notstart"
//              }, xxx]
//  }
//
- (void)didUpdateProgress:(NSString *)udid percent:(double)percent stat:(NSDictionary *)stat;
- (void)didRecvEnd:(NSString *)udid file:(NSString *)file isFinished:(bool)isFinished fileSize:(long long)fileSize;
- (void)didLivePhotoReady:(NSString *)imagePath videoPath:(NSString *)videoPath;

- (void)didSendStart:(NSString *)udid file:(NSString *)file;
- (void)didSendData:(NSString *)udid data:(NSData*) data file:(NSString *)file;
// - (void)didTransFail:(NSString *)udid type:(int)type errorCode:(int)errorCode;

- (void)didRecvThumb:(NSString *) thumbnail;
- (void)didRecvTime:(NSString *) timeInfo;
- (void)didRecvAvatar:(NSString *)udid hwid:(NSString *)hwid avatar:(NSString *)avatar;

- (void)didSendEnd:(NSString *)udid file:(NSString *)file isFinished:(bool)isFinished;

- (void)didIsCancel:(bool) isCancel;

// - (void)didSendFiles:(int)startIndex endIndex:(int)endIndex;
@end

@interface DelegateManager : NSObject

@property (nonatomic, weak) id<DeviceDelegate> deviceDelegate;
@property (nonatomic, weak) id<ConnectDelegate> connectDelegate;
@property (nonatomic, weak) id<TransDelegate> transDelegate;
@property (nonatomic, weak) id<DFXDelegate> dfxDelegate;

+ (instancetype)shared NS_SWIFT_NAME(shared());
@end

NS_ASSUME_NONNULL_END

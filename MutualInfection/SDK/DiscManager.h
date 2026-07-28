// DiscManager.h
#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

NS_ASSUME_NONNULL_BEGIN

@interface DiscManager : NSObject


+ (instancetype)shared NS_SWIFT_NAME(shared());
- (void)start;
- (void)stop;
- (void)changeBtName:(NSString *)name;
- (bool)isDeviceConnected:(NSString *)uuid;
- (void)startScanning;
- (void)stopScanning;
- (void)startAdvertising;
- (void)stopAdvertising;
//- (void)accept;
//- (void)reject;
//- (void)cancelShare;
//- (void)cancelReceiveShare;
- (void)sendPacket:(NSString *)uuid data: (NSData *)data useFirst:(bool)useFirst isSender:(bool)isSender;
- (void)SendCachedBlePackage:(NSString *)udid;
- (void)ClearBLECache:(NSString *)uuid;

@end

NS_ASSUME_NONNULL_END

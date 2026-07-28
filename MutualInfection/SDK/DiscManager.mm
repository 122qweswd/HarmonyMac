// DiscManager.mm
#import "DiscManager.h"
#include <ctime>
#include <Foundation/Foundation.h>
#include <CoreBluetooth/CoreBluetooth.h>
#include <string>
#include <set>
#include <algorithm>
#include <map>
#include <memory>
#include "Device.h"
#include "BLEDiscSerializer.h"
//#include "AuthSessionSerializer.h"
#include "ShareHelper.h"
#include "DeviceManager.h"
#include "DelegateManager.h"
//#include "BleConncetBusinessCtrlProtol.h"
//#include "MetaNodeSerializer.h"

#include <openssl/evp.h>
#include <openssl/pem.h>
#include <openssl/rand.h>
#include <openssl/rsa.h>
#include <openssl/hmac.h>

#include "Common.h"
#include "SocketManager.h"
#include "TransManager.h"
#include "LogHelper.h"
//#include "AuthSessionSerializer.h"
#include "ConnectManager.h"
#include "ShareManager.h"
#include "COAPDiscSerializer.hpp"
#include <TargetConditionals.h>
#include <arpa/inet.h>

#ifdef __OBJC__
    #if TARGET_OS_IOS
    #import <UIKit/UIKit.h>
    #elif TARGET_OS_MAC
        #import <AppKit/AppKit.h>
        #import <IOKit/IOKitLib.h>
    #endif
#endif
#include "Timer.h"

typedef struct MIBleDataToSend {
    std::string udid;
    std::vector<uint8_t> packet;
    bool useFirst;   
} MICachedBlePkg_t;

std::vector<MICachedBlePkg_t> g_vectMICachedBlePkg;

static NSString *const kServiceUUID = @"11C8B310-80E4-4276-AFC0-F81590B2177F";
static NSString *const kCharacteristicUUID1 = @"00002B00-0000-1000-8000-00805F9B34FB";
static NSString *const kCharacteristicUUID2 = @"00002B01-0000-1000-8000-00805F9B34FB";
NSString *const kDescriptorUUID = @"00002902-0000-1000-8000-00805F9B34FB";

static int8_t PEER_CHANNEL_ID = -1;

typedef enum {
    bleUnconnect = 0,               // ble未连接
    bleConnectedServiceUnDiscover,  // ble连接成功，未发现服务 (数据交互暂停，数据存放在g_vectMICachedBlePkg中)
    bleConnectedServiceDiscovered,  // ble连接成功，已发现服务
} BleConnectStatus;

typedef struct stBleConnection {
    int timerId;
    int retry;
    BleConnectStatus connectStatus;
    std::string uuid;
    std::string udid;
} BleConnection;

//static int connectBleTimer = -1;
static TimerQueue timerQueue;
static std::map<std::string, BleConnection> bleConnectList;
static std::mutex bleMapMutex;
static std::string g_udid = "";
//std::map<std::string, int>

std::string nsStringToString(NSString* uuidString) {
    if (uuidString == nil) {
        return "";
    }
    return std::string([uuidString UTF8String]);
}

std::vector<uint8_t> nsDataToVector(NSData* data) {
    if (!data || data.length == 0) {
        return {};
    }
    
    const uint8_t* bytes = static_cast<const uint8_t*>(data.bytes);
    return std::vector<uint8_t>(bytes, bytes + data.length);
}

@interface DiscManager ()<CBCentralManagerDelegate, CBPeripheralManagerDelegate, CBPeripheralDelegate>
@property (strong, nonatomic) CBCentralManager *centralManager;
@property (nonatomic, strong, nullable) CBPeripheralManager *peripheralManager;
@property (nonatomic, assign) BOOL isScanning;
@property (nonatomic, assign) BOOL isAdvertising;
@property (nonatomic, assign) NSUInteger advertisingRetryTimers;
@property (nonatomic, copy) NSString *btName;
@property (nonatomic, copy) NSString *deviceDID;
// 是否正在文件传输中，解决H->A传输中A切后台时A侧主动removeservice，导致H侧传输失败
@property (nonatomic, assign) BOOL isHToATransit;

@property (nonatomic, strong) CBMutableService *service;
@property (nonatomic, assign) NSUInteger serviceRetryTimers;
@property (nonatomic, strong) CBMutableCharacteristic *characteristic1;
@property (nonatomic, strong) CBMutableCharacteristic *characteristic2;
@property (nonatomic, strong) CBMutableDescriptor *descriptor;
@property (nonatomic, strong) NSDictionary *advertisementData;

@property (nonatomic, strong) NSMutableDictionary *peripheralList;
@property (nonatomic, strong) NSMutableDictionary *centralList;

@property (nonatomic, strong) DelegateManager *delegate;

- (void)startScanning;
- (void)stopScanning;
- (void)startAdvertising;
- (void)stopAdvertising;
- (void)connectDevice:(NSString *)uuid udid:(NSString *)udid;
- (NSDictionary *)castUIDevice:(std::shared_ptr<Device>)device;
- (void)fragmentAndSendData:(NSData *)data mtu:(NSInteger)mtu writeChunk:(void(^)(NSData *chunkData))writeBlock;
@end

static std::map<std::string, std::shared_ptr<Device>> tempList;

static void ConnectBleTimeout(const std::string &uuid)
{
    LOG_DEBUG_S("SHARE_BLE_TIMEOUT");
    dispatch_sync(dispatch_get_main_queue(), ^{
        auto it = bleConnectList.find(uuid);
        if (it == bleConnectList.end()) {
            LOG_DEBUG_S("no timer for device[%s]", uuid.c_str());
            return;
        }
        DiscManager *mgr = [DiscManager shared];
        if (mgr == nil) {
            LOG_ERROR_S("system error: invalid manager");
            return;
        }
        if (it->second.retry >= 2) {
            LOG_ERROR_S("exceed to maximum ble connection[%d] for device[%s]", it->second.retry, it->second.udid.c_str());
            ShareManager::shared().OnShareComplete(it->second.udid, SHARE_BLE_TIMEOUT, ERROR_BLE_TIMEOUT);
            bleConnectList.erase(it);
            return;
        }

        CBPeripheral *peripheral = [mgr.peripheralList objectForKey:[NSString stringWithUTF8String:it->second.uuid.c_str()]];
        if (peripheral != nil) {
            [mgr.centralManager cancelPeripheralConnection:peripheral];
        }
    });
}

@implementation DiscManager

+ (instancetype)shared {
    static DiscManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue() options:@{CBCentralManagerOptionShowPowerAlertKey: @NO}];
        _isScanning = NO;
        _isAdvertising = NO;
        _isHToATransit = NO;
        _btName = @"iPhone";
        _serviceRetryTimers = 0;
        _advertisingRetryTimers = 0;
        _delegate = [DelegateManager shared];
        _peripheralList = [NSMutableDictionary dictionary];
        _centralList = [NSMutableDictionary dictionary];
        timerQueue.start();
        // 使用主队列并设置选项以提高广播性能
        NSDictionary *options = @{
            CBPeripheralManagerOptionShowPowerAlertKey: @YES
        };
        _peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil options:options];
    }
    return self;
}
- (void)start {
    [self startAdvertising];
    [self startScanning];
}

- (void)stop {
    [self stopScanning];
    [self stopAdvertising];
}

- (void)startScanning {
    if (self.centralManager.state == CBManagerStatePoweredOn) {
        NSDictionary *options = @{CBCentralManagerScanOptionAllowDuplicatesKey: @YES};
        [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:@"FE35"]] options:options];
        self.isScanning = YES;
        LOG_DEBUG_S("Start BLE Adv Scan");
    }
}

- (void)stopScanning {
    [self.centralManager stopScan];
    self.isScanning = NO;
    LOG_DEBUG_S("Stop BLE Adv Scan");
}

- (void)changeBtName:(NSString *)name {
    if (name && [name length] != 0) {
        NSData *utf8Data = [name dataUsingEncoding:NSUTF8StringEncoding];
        if ([utf8Data length] > 12) {
            NSString *substring = nil;
            for (NSInteger i = name.length; i >= 0; i--) {
                substring = [name substringToIndex:i];
                NSData *subData = [substring dataUsingEncoding:NSUTF8StringEncoding];
                if ([subData length] <= 12) {
                    name = substring;
                    break;
                }
            }
        }
    }
    self.btName = name;
    const char *cString = [name UTF8String];
    if (cString != nullptr) {
        COAPDiscSerializer::GetInstance()->SetDeviceName(cString);
        std::string anoName = AnonymizeString(cString);
        LOG_DEBUG_S("update bt name: %s", anoName.c_str());
    } else {
        LOG_DEBUG_S("update bt name: (empty)");
    }
    [self stopAdvertising];
    [self startAdvertising];
}

- (void)SendCachedBlePackage:(NSString *)uuid {
    CBPeripheral *peripheral = [self.peripheralList objectForKey:uuid];
    auto connectIt = bleConnectList.find([uuid UTF8String]);
    if (connectIt == bleConnectList.end()) {
        LOG_ERROR_S("invalid channel: %s", [uuid UTF8String]);
        return;
    }
    if (peripheral != nil) {
        LOG_DEBUG_S("uuid: %s, pkg.udid: %s", [uuid UTF8String], connectIt->second.udid.c_str());
        auto it = g_vectMICachedBlePkg.begin();
        while (it != g_vectMICachedBlePkg.end()) {
            if (it->udid == connectIt->second.udid) {
                int index = 0;
                if (!it->useFirst) {
                    index = 1;
                }
                NSData *data = [NSData dataWithBytes:it->packet.data() length:it->packet.size()];
                LOG_DEBUG_S("[SEND OUT]: uuid = %s useFirst = %d total length = %d, model = %d",
                            [peripheral.identifier.UUIDString UTF8String], it->useFirst, data.length, *((uint8_t*)[data bytes] + 20));

                NSInteger mtu = [peripheral maximumWriteValueLengthForType:CBCharacteristicWriteWithoutResponse] - 3;
                [self fragmentAndSendData:data mtu:mtu writeChunk:^(NSData *chunkData){
                    if (peripheral.services.count > 0 && peripheral.services[0].characteristics.count > index && peripheral.services[0].characteristics[index] != nil) {
                        [peripheral writeValue:chunkData forCharacteristic:peripheral.services[0].characteristics[index] type:CBCharacteristicWriteWithoutResponse];
                    }
                }];
                it = g_vectMICachedBlePkg.erase(it);
                usleep(1000);
                continue;
            }
            it++;
        }
    }
}

- (void)ClearBLECache:(NSString *)uuid {
    g_udid = "";
    g_vectMICachedBlePkg.clear();
    CBPeripheral *peripheral = [self.peripheralList objectForKey:uuid];
    if (peripheral != nil) {
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
}

- (void)sendPacket:(NSString *)uuid data:(NSData *)data useFirst:(bool)useFirst isSender:(bool)isSender {
    @try {
        int index = 0;
        if (!useFirst) {
            index = 1;
        }
        if (isSender) {
            CBPeripheral *peripheral = [self.peripheralList objectForKey:uuid];
            if (peripheral != nil) {
                auto it = bleConnectList.find([uuid UTF8String]);
                std::string udid = DeviceManager::shared().GetDeviceUDID([uuid UTF8String]);
                if (it == bleConnectList.end()) {
                    [self connectDevice:uuid udid:[NSString stringWithUTF8String:udid.c_str()]];
                } else {
                    udid = it->second.udid;
                }
                if (!ShareManager::shared().IsBleConnected([peripheral.identifier.UUIDString UTF8String])) {
                    MICachedBlePkg_t pkg = {
                        .udid = udid,
                        .packet = nsDataToVector(data),
                        .useFirst = useFirst,
                    };

                    LOG_DEBUG_S("uuid: %s, pkg.udid: %s", [uuid UTF8String], pkg.udid.c_str());
                    g_vectMICachedBlePkg.push_back(pkg);
                } else {
                    LOG_DEBUG_S("[SEND OUT]: uuid = %s useFirst = %d total length = %d, model = %d",
                                [peripheral.identifier.UUIDString UTF8String], useFirst, data.length, *((uint8_t*)[data bytes] + 20));
                    NSInteger mtu = [peripheral maximumWriteValueLengthForType:CBCharacteristicWriteWithoutResponse] - 3;
                    [self fragmentAndSendData:data mtu:mtu writeChunk:^(NSData *chunkData){
                        if (peripheral.services.count > 0 && peripheral.services[0].characteristics.count > index && peripheral.services[0].characteristics[index] != nil) {
                            [peripheral writeValue:chunkData forCharacteristic:peripheral.services[0].characteristics[index] type:CBCharacteristicWriteWithoutResponse];
                        }
                    }];
                }
                return;
            }
        } else {
            CBCentral *central = [self.centralList objectForKey:uuid];
            if (central != nil) {
                NSArray<CBCentral *> *centrals = @[ central ];
                CBMutableCharacteristic *characteristic = self.characteristic2;
                if (useFirst) {
                    characteristic = self.characteristic1;
                }
                LOG_DEBUG_S("[RECV OUT]: uuid = %s useFirst = %d total length = %d, model = %d",
                            [central.identifier.UUIDString UTF8String], useFirst, data.length, *((uint8_t*)[data bytes] + 20));
                [self fragmentAndSendData:data mtu:509 writeChunk:^(NSData *chunkData){
                    if (characteristic != nil) {
                        [self.peripheralManager updateValue:chunkData forCharacteristic:characteristic onSubscribedCentrals:centrals];
                    }
                }];
                return;
            }
        }
        LOG_ERROR_S("invalid %s device object: %s", isSender ? "send" : "recv", [uuid UTF8String]);
    } @catch (NSException *exception) {
        NSLog(@"sendPacket failed: %@", exception);
    }
}

- (void)connectDevice:(NSString *)uuid udid:(NSString *)udid {
    if (udid == nil) {
        LOG_ERROR_S("nil udid parameter");
        return;
    }
    std::string udidString = [udid UTF8String];
    std::string uuidString = DeviceManager::shared().GetDeviceUUID(udidString);
    NSString * currnetUUID = [NSString stringWithUTF8String:uuidString.c_str()];
    CBPeripheral *peripheral = [self.peripheralList objectForKey:currnetUUID];
    LOG_DEBUG_S("connect BLE device[%s]: %s %p", udidString.c_str(), uuidString.c_str(), peripheral);
    if (peripheral == nil) {
        LOG_ERROR_S("invalid device object: %s", uuidString.c_str());
        return;
    }

    auto it = bleConnectList.find([uuid UTF8String]);
    if (it == bleConnectList.end()) {
        BleConnection connect = {
            .timerId = -1,
            .retry = 0,
            .connectStatus = bleUnconnect,
            .udid = udidString,
            .uuid = uuidString,
        };
        bleConnectList.emplace(uuidString, connect);
        it = bleConnectList.find(uuidString);
    } else {
        it->second.retry++;
        if (![uuid isEqualToString:currnetUUID]) {
            BleConnection connect = {
                .timerId = -1,
                .retry = it->second.retry,
                .connectStatus = bleUnconnect,
                .udid = udidString,
                .uuid = uuidString,
            };
            bleConnectList.erase(it);
            bleConnectList.emplace(uuidString, connect);
            ShareManager::shared().UpdateChannel(udidString, uuidString);
            it = bleConnectList.find(uuidString);
        }
    }
    if (it->second.connectStatus != bleUnconnect) {
        return;
    }
    peripheral.delegate = self;
    [self.centralManager connectPeripheral:peripheral options:nil];
    if (it->second.timerId >= 0) {
        LOG_DEBUG_S("stop ble timeout: %d", it->second.timerId);
        timerQueue.cancelTask(it->second.timerId);
    }

    auto timerId = timerQueue.addTask(3500, 1, ConnectBleTimeout, uuidString);
    it->second.timerId = timerId;
    LOG_DEBUG_S("add ble timeout[%s]: %d", udidString.c_str(), timerId);
}

- (bool)isDeviceConnected:(NSString *)uuid {
    CBPeripheral *peripheral = [self.peripheralList objectForKey:uuid];
    if (peripheral == nil) {
        LOG_ERROR_S("invalid device object: %s", [uuid UTF8String]);
        return false;
    }
    if (peripheral.services[0].characteristics.count != 2) {
        return false;
    }
    return true;
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    switch (central.state) {
        case CBManagerStatePoweredOn:
            if (!self.isScanning) {
                [self startScanning];
            }
            break;
        case CBManagerStatePoweredOff:
            if (self.isScanning) {
                [self stopScanning];
            }
            LOG_DEBUG_S("BLE PowerOff");
            [self blePowerOff];
            ShareManager::shared().SendShareEvent(SHARE_ERROR_BLE, ERROR_BLE_POWER_OFF);
            break;
        case CBManagerStateUnauthorized:
            LOG_DEBUG_S("BLE Unauthorized");
            break;
        case CBManagerStateUnsupported:
            LOG_DEBUG_S("BLE Unsupported");
            break;
        case CBManagerStateResetting:
            LOG_DEBUG_S("BLE Resetting");
            break;
        default:
            LOG_DEBUG_S("BLE Unknown state");
            break;
    }
}

- (NSString *)DataToHexStr:(NSData *)data {
    if (!data || [data length] == 0) {
        return @"";
    }
    NSMutableString *string = [[NSMutableString alloc] initWithCapacity:[data length] * 2 + 2];
    [string appendString:@"0x"];
    [data enumerateByteRangesUsingBlock:^(const void * _Nonnull bytes, NSRange byteRange, BOOL * _Nonnull stop) {
        unsigned char *dataBytes = (unsigned char*)bytes;
        for (NSInteger i = 0; i < byteRange.length; i++) {
            NSString *hexStr = [NSString stringWithFormat:@"%02x", dataBytes[i]];
            [string appendString:hexStr];
        }
    }];
    return string;
}

- (void)    centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary<NSString *, id> *)advertisementData
                   RSSI:(NSNumber *)RSSI {
    try {
        if (advertisementData == nil || peripheral == nil) {
            return;
        }
        NSData *advData = (NSData *)advertisementData[CBAdvertisementDataManufacturerDataKey];
        
        BLEDiscSerializer serializer;
        NSDictionary *serviceData = advertisementData[CBAdvertisementDataServiceDataKey];
        NSString *serviceUUID = [[NSString alloc] initWithUTF8String:serializer.GetServiceUUID().c_str()];
        std::string uuidString = [peripheral.identifier.UUIDString UTF8String];
//        NSArray *serviceKeys = serviceData.allKeys;
//        std::string advString = [[self DataToHexStr:advData] UTF8String];
//        LOG_DEBUG_S("uuidString:%s, advData:%s ", uuidString.c_str(), advString.c_str());
//        for (CBUUID *serviceKey in serviceKeys) {
//            NSData *rspData = serviceData[serviceKey];
//            std::string rspString = [[self DataToHexStr:rspData] UTF8String];
//            std::string serviceKeyString = [serviceKey.UUIDString UTF8String];
//            LOG_DEBUG_S("uuidString:%s, serviceKey:%s, rspData:%s", uuidString.c_str(), serviceKeyString.c_str(), rspString.c_str());
//        }

        auto it = tempList.find(uuidString);
        if (it == tempList.end()) {
            std::shared_ptr<Device> device = std::make_shared<Device>();
            auto now = std::chrono::system_clock::now();
            auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch());
            device->updateTime = static_cast<uint64_t>(duration.count());
            device->discoverStartTime = device->updateTime;
            device->packet = 0;
            device->deviceId = INVALID_UDID;
            tempList.emplace(uuidString, device);
//            LOG_DEBUG_S("tempList emplace device uuidString: %s", uuidString.c_str());
        }
        if (advData != nil && !serializer.IsValidPacket((const uint8_t *)[advData bytes], advData.length)) {
//            LOG_ERROR_S("Invalid adv pack, serviceid is %s", serviceUUID.UTF8String);
            return;
        }
        std::string updateTimeUdid = "";
        if (advData != nil) {
            uint8_t *advPacket = (uint8_t *)[advData bytes] + 2;
            size_t advLen = advData.length - 2;
            if (serializer.IsValidAdvPacket(advPacket, advLen)) {
                bool isSender = false;
                bool ret = false;
                auto item = tempList.find(uuidString);
                if (item == tempList.end()) {
                    return;
                }
                ret = serializer.ParseAdvPacket(advPacket, advLen, isSender, item->second);
                if (ret == false) {
                    std::string advString = [[self DataToHexStr:advData] UTF8String];
                    LOG_ERROR_S("parse adv pack fail：%s",advString.c_str());
                    return;
                }
                item->second->packet |= 0x01;
            }
            if (serializer.IsValidSecPacket(advPacket, advLen)) {
                auto item = tempList.find(uuidString);
                if (item == tempList.end()) {
                    return;
                }
                serializer.ParseSecPacket(advPacket, advLen, item->second);
                item->second->packet |= 0x04;
            }
        }
        if (serviceData != nil) {
            NSData *rspData = serviceData[[CBUUID UUIDWithString:serviceUUID]];
            uint8_t rspLen = rspData.length;
            const uint8_t *rspPacket = (const uint8_t *)[rspData bytes];
            auto item = tempList.find(uuidString);
            if (serializer.IsValidAdvRspPacket(rspPacket, rspLen)) {
                if (item == tempList.end()) {
                    return;
                }
                serializer.ParseAdvRspPacket(rspPacket, rspLen, item->second);
                item->second->packet |= 0x02;
            }
            if (serializer.IsValidSecRspPacket(rspPacket, rspLen)) {
                if (item == tempList.end()) {
                    return;
                }
                serializer.ParseSecRspPacket(rspPacket, rspLen, item->second);
                item->second->packet |= 0x08;
            }
            updateTimeUdid = DeviceManager::shared().GetDeviceUDID(uuidString);
        }
        auto item = tempList.find(uuidString);
        if (item != tempList.end() && (item->second->packet == 0x0F)) {
            item->second->uuid = uuidString;
            if (item->second->deviceId != INVALID_UDID && item->second->isSupportIOS && [self.delegate.deviceDelegate respondsToSelector:@selector(didDeviceFound:device:)]) {
                if (!DeviceManager::shared().hasDevice(item->second->deviceId)) {
                    LOG_DEBUG_S("discover new device: [%llX][%s], discover start: %lld, discover end: %lld, elapsed time: %lldms",
                                item->second->deviceId, item->second->uuid.c_str(), item->second->discoverStartTime,
                                item->second->discoverEndTime, item->second->discoverEndTime - item->second->discoverStartTime);
                    item->second->foundType |= 0x01;
                    DeviceManager::shared().addDevice(item->second->deviceId, item->second);
                    NSString *udid = [self deviceId2UDID:item->second->deviceId];
                    [self.peripheralList setValue:peripheral forKey:peripheral.identifier.UUIDString];
                    [self.delegate.deviceDelegate didDeviceFound:udid device:[self castUIDevice:item->second]];
                } else {
                    std::string prevUUID = DeviceManager::shared().GetDeviceUUID(item->second->deviceId);
                    if (prevUUID != uuidString) {
                        LOG_DEBUG_S("update uuid for device[%llX]: %s -> %s", item->second->deviceId, prevUUID.c_str(), uuidString.c_str());
                        [self.peripheralList setValue:peripheral forKey:peripheral.identifier.UUIDString];
                        std::string udid = [[self deviceId2UDID:item->second->deviceId] UTF8String];
                        if (bleConnectList.find(prevUUID) == bleConnectList.end()) {
                            LOG_DEBUG_S("old BLE channel[%s] not yet connected", prevUUID.c_str());
                            [self.peripheralList removeObjectForKey:[NSString stringWithUTF8String:prevUUID.c_str()]];
                        }
                    }
                    auto oldDevice = DeviceManager::shared().getDevice(item->second->deviceId);
                    if (oldDevice != nullptr) {
                        if (!(oldDevice->foundType & 0x02)) {
                            if ([self.delegate.deviceDelegate respondsToSelector:@selector(didDeviceUpdate:device:)]) {
                                NSString *udid = [self deviceId2UDID:item->second->deviceId];
                                NSDictionary *deviceInfo = [self castUIDevice:item->second];
                                if (deviceInfo && [deviceInfo[@"name"] length] > 0) {
                                    [self.delegate.deviceDelegate didDeviceUpdate:udid device:deviceInfo];
                                }
                            }
                        }
                    }
                    DeviceManager::shared().updateDevice(item->second->deviceId, item->second);
                }
            }
//            LOG_DEBUG_S("tempList erase device uuidString:%s, btName:%s, deviceId: %llX, isSupportOS: %u", uuidString.c_str(),
//                        (char*)item->second->btName.data(), item->second->deviceId, item->second->isSupportIOS);
            tempList.erase(item);
        } else {
//            LOG_DEBUG_S("device uuidString: %s, packet not 0x0F, packet: %u", uuidString.c_str(), item->second->packet);
        }
        if (!updateTimeUdid.empty()) {
            uint64_t deviceId = strtoull(updateTimeUdid.c_str(), nullptr, 16);
            DeviceManager::shared().updateDeviceTime(deviceId);
        }
    } catch (...) {
        LOG_DEBUG_S("Unknown exception devices");
    }
}

- (void)centralManager:(CBCentralManager *)manager
    didFailToConnectPeripheral:(nonnull CBPeripheral *)peripheral error:(nullable NSError *)error {
    std::string uuid = [peripheral.identifier.UUIDString UTF8String];
    if (error) {
        LOG_DEBUG_S("fail to connect BLE device - uuid:[%s] - error[%d]：%s",  uuid.c_str(), error.code ,[error.localizedDescription UTF8String]);
    } else {
        LOG_DEBUG_S("fail to connect BLE device - uuid:[%s] - error: nil", uuid.c_str());
    }
    auto it = bleConnectList.find(uuid);
    if (it != bleConnectList.end()) {
        // A与H手动蓝牙配对导致必现连接失败场景
        if (error && error.code == 14) {
            std::string udid = DeviceManager::shared().GetDeviceUDID(uuid);
            ShareManager::shared().OnShareComplete(udid, SHARE_BLE_LTK, ERROR_BLE_LTK);
            bleConnectList.erase(it);
            return;
        }
        if (it->second.retry >= 2) {
            LOG_ERROR_S("exceed to maximum ble connection[%d] for device[%s]", it->second.retry, it->second.udid.c_str());
            int errCode = (int)error.code + ERROR_BLE_TIMEOUT + 1000;
            ShareManager::shared().OnShareComplete(it->second.udid, SHARE_BLE_TIMEOUT, errCode);
            bleConnectList.erase(it);
            return;
        }
        [self connectDevice:peripheral.identifier.UUIDString udid:[NSString stringWithUTF8String:it->second.udid.c_str()]];
    }
}

- (void)centralManager:(CBCentralManager *)manager didConnectPeripheral:(nonnull CBPeripheral *)peripheral {
    LOG_DEBUG_S("connect BLE device - uuid:[%s]", [peripheral.identifier.UUIDString UTF8String]);
    std::string uuid = [peripheral.identifier.UUIDString UTF8String];
    auto it = bleConnectList.find(uuid);
    if (it != bleConnectList.end()) {
        it->second.connectStatus = bleConnectedServiceUnDiscover;
    }
    [peripheral discoverServices:@[[CBUUID UUIDWithString:kServiceUUID]]];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    std::string uuid = [peripheral.identifier.UUIDString UTF8String];
    if (error) {
        LOG_DEBUG_S("disconnect peripheral - uuid:[%s] - error[%d]：%s", uuid.c_str(), error.code, [error.localizedDescription UTF8String]);
    } else {
        LOG_DEBUG_S("disconnect peripheral - uuid:[%s] - error: nil", uuid.c_str());
    }

    auto it = bleConnectList.find(uuid);
    if (it == bleConnectList.end()) {
        LOG_ERROR_S("ble connection channel has been excluded");
        return;
    }
    if (it->second.connectStatus != bleUnconnect) {
        ShareManager::shared().OnBleDisconnect(uuid, it->second.udid);
        bleConnectList.erase(it);
        peripheral.delegate = nil;
    } else {
        [self connectDevice:peripheral.identifier.UUIDString udid:[NSString stringWithUTF8String:it->second.udid.c_str()]];
    }
}

- (void)centralManager:(CBCentralManager *)central connectionEventDidOccur:(CBConnectionEvent)event forPeripheral:(CBPeripheral *)peripheral {
    LOG_DEBUG_S("Event Did Occur peripheral: %s, event: %d", [peripheral.identifier.UUIDString UTF8String], event);
}

#pragma mark - CBPeripheralManagerDelegate

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
    switch (peripheral.state) {
        case CBManagerStatePoweredOn:
            LOG_DEBUG_S("BLE PowerOn，Try to start advertising");
            [self startAdvertising];
            break;
        case CBManagerStatePoweredOff:
            LOG_DEBUG_S("BLE PowerOff");
            if (self.isAdvertising) {
                [self stopAdvertising];
            }
            break;
        case CBManagerStateUnsupported:
            LOG_DEBUG_S("BLE Unsupported");
            break;
        case CBManagerStateUnauthorized:
            LOG_DEBUG_S("BLE Unauthorized");
            break;
        case CBManagerStateResetting:
            LOG_DEBUG_S("BLE Resetting");
            break;
        default:
            LOG_DEBUG_S("BLE Unknown State");
            break;
    }
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(nullable NSError *)error {
    if (error) {
        self.isAdvertising = NO; // 广播启动失败，重置为NO
        if (error.code == 9) {
            LOG_DEBUG_S("Advertising already started, ignore error.");
            return;
        }
        LOG_ERROR_S("Fail to start BLE advertising - error[%d]：%s", error.code, [error.localizedDescription UTF8String]);
        // startAdvertising失败，增加重试机制
        if (self.advertisingRetryTimers < 3) {
            [self retryAdvertising];
        }else {// 启动广播失败，移除服务后
            LOG_DEBUG_S("retryAdvertising failed and retry exhausted, - timers:%d", self.advertisingRetryTimers);
            ShareManager::shared().OnBroadcastFail();
            self.advertisingRetryTimers = 0; // 重置计数
            [self removeService];
        }
    } else {
        self.isAdvertising = YES; // 广播真正启动成功，设为YES
        std::string anoName = AnonymizeString([self.btName UTF8String]);
        LOG_DEBUG_S("Succeed to start BLE advertising，device name: %s", anoName.c_str());
    }
}

- (void)peripheralManagerDidStopAdvertising:(CBPeripheralManager *)peripheral {
    self.isAdvertising = NO; // 广播停止，重置为NO
    LOG_DEBUG_S("Stop BLE advertising");
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(nullable NSError *)error {
    if (error) {
        LOG_ERROR_S("Fail to add service - error[%d]：%s", error.code, [error.localizedDescription UTF8String]);
        // 服务添加失败，增加重试机制
        _serviceRetryTimers ++;
        if (_serviceRetryTimers <= 2) {
            [self createService];
        }else {
            // 服务添加失败且重试耗尽，重置isAdvertising为NO，避免状态错乱
            self.isAdvertising = NO;
            LOG_DEBUG_S("Service add failed and retry exhausted, reset isAdvertising to NO");
            [self removeService];
            _serviceRetryTimers = 0;
            std::string uuid = [service.UUID.UUIDString UTF8String];
            std::string udid = DeviceManager::shared().GetDeviceUDID(uuid);
            ShareManager::shared().OnShareComplete(udid, SHARE_ERROR_BLE_ADD_SERVICE, ERROR_BLE_ADD_SERVICE);
        }
    } else {
        const char *cString = [service.UUID.UUIDString UTF8String];
        LOG_DEBUG_S("Succeed to add service：%s", cString);
        [self.peripheralManager startAdvertising:self.advertisementData];
    }
}

// 中心设备订阅特征
- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic {
    NSString *devUUID = central.identifier.UUIDString;
    NSString *charaUUID = characteristic.UUID.UUIDString;
    _isHToATransit = YES;
    LOG_DEBUG_S("Subscribe Characteristic on central: %s, chara uuid: %s", [devUUID UTF8String], [charaUUID UTF8String]);
    if ([characteristic.UUID.UUIDString isEqualToString:kCharacteristicUUID1]) {
        if ([self.centralList objectForKey:devUUID] == nil) {
            [self.centralList setValue:central forKey:devUUID];
        }
    }
}

// 中心设备取消订阅特征
- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic {
    NSString *devUUID = central.identifier.UUIDString;
    NSString *charaUUID = characteristic.UUID.UUIDString;
    _isHToATransit = NO;
    LOG_DEBUG_S("Unsubscribe Characteristic on central: %s, chara uuid:%s", [devUUID UTF8String], [charaUUID UTF8String]);
    if ([characteristic.UUID.UUIDString isEqualToString:kCharacteristicUUID1]) {
        if ([self.centralList objectForKey:devUUID] != nil) {
            ShareManager::shared().OnBleUnsubscribe([devUUID UTF8String]);
//            [self.centralList removeObjectForKey:devUUID];
        }
    }
}

#pragma mark - CBPeripheralDelegate
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    NSArray<CBUUID *> *characteristics = @[
        [CBUUID UUIDWithString:kCharacteristicUUID1],
        [CBUUID UUIDWithString:kCharacteristicUUID2]
    ];
    if (peripheral.services.count == 1) {
        LOG_DEBUG_S("start discover characteristics of service:%s", [peripheral.services[0].UUID.UUIDString UTF8String]);
        [peripheral discoverCharacteristics:characteristics forService:peripheral.services[0]];
    }
    if (error != nil) {
        LOG_DEBUG_S("didDiscoverServices - error[%d]:%s", error.code, [error.localizedDescription UTF8String]);
    }
    LOG_DEBUG_S("discover service for %s", [peripheral.identifier.UUIDString UTF8String]);
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    LOG_DEBUG_S("discover character for %s, character size: %d",
                [peripheral.identifier.UUIDString UTF8String], service.characteristics.count);
    for (int index = 0; index < service.characteristics.count; index++) {
        LOG_DEBUG_S("register notificaiton: %s", [service.characteristics[index].UUID.UUIDString UTF8String]);
        [peripheral setNotifyValue:TRUE forCharacteristic:service.characteristics[index]];
    }
    if (service.characteristics.count == 2) {
        std::string uuid = [peripheral.identifier.UUIDString UTF8String];
        auto it = bleConnectList.find(uuid);
        if (it != bleConnectList.end()) {
            it->second.connectStatus = bleConnectedServiceDiscovered;
            if (it->second.timerId >= 0) {
                LOG_ERROR_S("stop ble timeout: %d", it->second.timerId);
                timerQueue.cancelTask(it->second.timerId);
                it->second.timerId = -1;
            }
            ShareManager::shared().OnBleConnect(uuid, it->second.udid);
        }
    }
    if (error != nil) {
        LOG_DEBUG_S("didDiscoverCharacteristicsForService - error[%d]:%s", error.code, [error.localizedDescription UTF8String]);
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    std::string uuid = [peripheral.identifier.UUIDString UTF8String];
    if (error != nil) {
        LOG_DEBUG_S("didUpdateNotificationStateForCharacteristic - failed[%d]:%s", error.code, [error.localizedDescription UTF8String]);
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didModifyServices:(NSArray<CBService *> *)invalidatedServices {
    std::string uuid = [peripheral.identifier.UUIDString UTF8String];
    
    BOOL needReDiscoverService = NO;
    
    for (CBService *service in invalidatedServices) {
        if (service &&
            [service isKindOfClass:[CBService class]] &&
            service.UUID &&
            service.UUID.UUIDString) {
            NSString *serviceUUID = service.UUID.UUIDString;
            if ([serviceUUID isEqualToString:kServiceUUID]) {
                needReDiscoverService = YES;
                break;
            }
        }
    }
    
    if (needReDiscoverService) {
        LOG_ERROR_S("share service has updated, peripheral uuid: %s", uuid.c_str());
        auto it = bleConnectList.find(uuid);
        if (it != bleConnectList.end()) {
            it->second.connectStatus = bleConnectedServiceUnDiscover;
            LOG_DEBUG_S("reset connectStatus to serviceUndiscover for device: %s", it->second.udid.c_str());
        }
        
        [peripheral discoverServices:@[[CBUUID UUIDWithString:kServiceUUID]]];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if ([self.peripheralList objectForKey:peripheral.identifier.UUIDString] == nil) {
        LOG_ERROR_S("Invalid device object: %s", [peripheral.identifier.UUIDString UTF8String]);
        return;
    }
    
    NSData *data = (NSData *)characteristic.value;
    static std::vector<uint8_t> packet;
    static bool isSlice = false;

    std::vector<uint8_t> temp;
    temp.resize(16);
    memcpy(const_cast<uint8_t*>(temp.data()), [data bytes], 16);
    uint32_t currentSize = (((((temp[4] << 8) + temp[5]) << 8) + temp[6]) << 8) + temp[7];
    uint32_t totalSize = (((((temp[12] << 8) + temp[13]) << 8) + temp[14]) << 8) + temp[15];
    if (isSlice) {
        size_t size = packet.size();
        const uint8_t *tempData = (const uint8_t *)[data bytes];
        packet.resize(size + data.length - 16);
        memcpy(const_cast<uint8_t*>(packet.data() + size), tempData + 16, data.length - 16);
        packet[4] = packet[12];
        packet[5] = packet[13];
        packet[6] = packet[14];
        packet[7] = packet[15];
    } else {
        packet.clear();
        packet.resize(data.length);
        memcpy(const_cast<uint8_t*>(packet.data()), [data bytes], data.length);
    }
    isSlice = false;
    if (currentSize < totalSize && packet.size() != totalSize + 16) {
        isSlice = true;
        return;
    }

    // packet.resize(data.length);
    // memcpy(const_cast<uint8_t*>(packet.data()), [data bytes], data.length);
    BleTransHeader bleHdr;

    if (!ParseBleHeader(packet, bleHdr)) {
        return;
    }
    std::string devUUID = [peripheral.identifier.UUIDString UTF8String];
    LOG_DEBUG_S("[SEND IN]: uuid = %s total length = %d, model = %d", devUUID.c_str(), packet.size() + sizeof(BleTransHeader), packet[4]);
    ShareManager::shared().HandleBLE(devUUID, packet, true);
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        LOG_ERROR_S("Fail to write value[%d]：%s %s", error.code,
                    [peripheral.identifier.UUIDString UTF8String], [error.localizedDescription UTF8String]);
    } else {
        LOG_DEBUG_S("Succeed to write value to characteristic");
    }
}

#pragma mark - Private Methods

- (void)startAdvertising {
    LOG_DEBUG_S("startAdvertising - isAdvertising:%d - isHToATransit：%d",self.isAdvertising, self.isHToATransit);
    if (self.peripheralManager.state != CBManagerStatePoweredOn) {
        LOG_DEBUG_S("BLE is unavailable");
        return;
    }
    
    // 增加此处逻辑是解决MAC合上屏幕几分钟后重新打开屏幕会同时触发systemDidWake和CBManagerStatePoweredOn导致
    if (self.isAdvertising) {
        LOG_DEBUG_S("Already advertising, skip");
        return;
    }
    // 重置重试计数
    self.advertisingRetryTimers = 0;
    self.isAdvertising = YES;
    
    // 传输中就不在重新createService，直接startAdvertising
    if (self.isHToATransit && self.service) {
        std::string anoName = AnonymizeString([self.btName UTF8String]);
        LOG_DEBUG_S("H to A transit, start BLE advertising direct，device name: %s", anoName.c_str());
        [self.peripheralManager startAdvertising:self.advertisementData];
        return;
    }
    
    // 从生成的DID中提取三个部分
    char temp[16] = { 0 };
    NSString *versionType;
#ifdef __OBJC__
#if TARGET_OS_IOS
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        versionType = @"953E";
    } else if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomMac) {
        versionType = @"933E";
    } else {
        versionType = @"903E";
    }
#elif TARGET_OS_MAC
    // macOS 设备类型判断
    versionType = @"933E"; // 为 macOS 设置默认值
#endif
#endif
    
    snprintf(temp, 15, "%04X", ShareManager::shared().GetDeviceId(0));
    NSString *uuidPart1 = [NSString stringWithUTF8String:temp];
    memset(temp, 0, 16);
    
    snprintf(temp, 15, "%04X", ShareManager::shared().GetDeviceId(1));
    NSString *uuidPart2 = [NSString stringWithUTF8String:temp];
    memset(temp, 0, 16);
    
    snprintf(temp, 15, "%04X", ShareManager::shared().GetDeviceId(2));
    NSString *uuidPart3 = [NSString stringWithUTF8String:temp];
    
    // 简化广播数据，移除不支持的Service Data
    self.advertisementData = @{
        CBAdvertisementDataLocalNameKey: self.btName,
        CBAdvertisementDataServiceUUIDsKey: @[
            [CBUUID UUIDWithString:@"FE35"],
            [CBUUID UUIDWithString:versionType],
            [CBUUID UUIDWithString:uuidPart1.length > 0 ? uuidPart1 : @"1111"],
            [CBUUID UUIDWithString:uuidPart2.length > 0 ? uuidPart2 : @"2222"],
            [CBUUID UUIDWithString:uuidPart3.length > 0 ? uuidPart3 : @"3333"],
            [CBUUID UUIDWithString:@"0300"]
        ],
    };
    
    // 创建并添加服务 - 为了解决A侧手机长时间放在前台，系统回收service场景，每次启动广播时都需要创建service
    _serviceRetryTimers = 0;
    [self createService];
}

- (void)stopAdvertising {
    LOG_DEBUG_S("stopAdvertising - isAdvertising:%d - isHToATransit：%d",self.isAdvertising, self.isHToATransit);
    if (self.isAdvertising) {
        [self.peripheralManager stopAdvertising];
        self.isAdvertising = NO;
        if (!_isHToATransit) {
            [self removeService];
        }
    }
}

- (void)retryAdvertising {
    // 增加重试计数
    self.advertisingRetryTimers++;
    
    LOG_DEBUG_S("retryAdvertising - timers:%d", self.advertisingRetryTimers);
    
    // 简单等待后重试
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.peripheralManager.state == CBManagerStatePoweredOn &&
            !self.isAdvertising) {
            // 停止当前广告
            [self.peripheralManager stopAdvertising];

            // 重新启动广告
            self.isAdvertising = YES;
            [self.peripheralManager startAdvertising:self.advertisementData];
        }
    });
}

- (NSDictionary*)castUIDevice:(std::shared_ptr<Device>)device {
    NSMutableDictionary *deviceInfo = [NSMutableDictionary dictionary];
    NSString *udid = [self deviceId2UDID:device->deviceId];
    BOOL isShowIcon = device->isShowIcon;
    NSString *hwid = @"";
    int deviceType = device->type;
    if (!device->hwContactId.empty()) {
        std::string hwidString = DeviceManager::shared().getHwidStr(device->hwContactId);
        hwid = [NSString stringWithUTF8String:hwidString.c_str()];
    }
    [deviceInfo setValue:udid forKey:@"udid"];
    if (!device->btName.empty()) {
        // 确保btName以null结尾
        std::vector<uint8_t> btNameWithNull = device->btName;
        btNameWithNull.push_back(0);
        [deviceInfo setValue:[[NSString alloc] initWithUTF8String:(char*)btNameWithNull.data()] forKey:@"name"];
    } else {
        [deviceInfo setValue:@"" forKey:@"name"];
    }
    [deviceInfo setValue:[NSDate date] forKey:@"timestamp"];
    [deviceInfo setValue:@(isShowIcon) forKey:@"icon"];
    [deviceInfo setValue:hwid forKey:@"hwid"];
    [deviceInfo setValue:@(deviceType) forKey:@"deviceType"];
    return deviceInfo;
}

- (void)createService {
    // 如果服务已经添加，先移除
    [self removeService];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        CBUUID *serviceUUID = [CBUUID UUIDWithString:kServiceUUID];
        // 创建服务
        self.service = [[CBMutableService alloc] initWithType:serviceUUID primary:YES];
        
    //    // 创建描述符
        CBUUID *descriptorUUID = [CBUUID UUIDWithString:kDescriptorUUID];
        NSData *descriptorValue = [@"Sample Descriptor" dataUsingEncoding:NSUTF8StringEncoding];
        self.descriptor = [[CBMutableDescriptor alloc] initWithType:descriptorUUID value:descriptorValue];

        // 创建特征
        CBUUID *characteristicUUID1 = [CBUUID UUIDWithString:kCharacteristicUUID1];
        CBCharacteristicProperties properties =  CBCharacteristicPropertyWriteWithoutResponse | CBCharacteristicPropertyWrite | CBCharacteristicPropertyNotify | CBCharacteristicPropertyIndicate;
        CBAttributePermissions permissions = CBAttributePermissionsReadable | CBAttributePermissionsWriteable;
        
        self.characteristic1 = [[CBMutableCharacteristic alloc] initWithType:characteristicUUID1
                                                                 properties:properties
                                                                       value:nil
                                                                permissions:permissions];
    //    self.characteristic1.descriptors = @[self.descriptor];

        CBUUID *characteristicUUID2 = [CBUUID UUIDWithString:kCharacteristicUUID2];
        self.characteristic2 = [[CBMutableCharacteristic alloc] initWithType:characteristicUUID2
                                                                 properties:properties
                                                                      value:nil
                                                                permissions:permissions];
    //    self.characteristic2.descriptors = @[self.descriptor];

        // 将特征添加到服务
        self.service.characteristics = @[self.characteristic1, self.characteristic2];
        
        // 添加服务到外设管理器
        [self.peripheralManager addService:self.service];
    });
}

- (void)removeService {
    LOG_DEBUG_S("remove existing all service");
    if (self.service) {
        [self.peripheralManager removeAllServices];
        self.service = nil;
    }
}

- (void)fragmentAndSendData:(NSData *)data mtu:(NSInteger)mtu writeChunk:(void(^)(NSData *chunkData))writeBlock {
    const size_t HDR_SIZE = sizeof(BleTransHeader);
    const uint8_t *bytes = (const uint8_t *)[data bytes];
    size_t dataLen = (size_t)data.length;
    if (dataLen <= mtu) {
        if (writeBlock) {
            writeBlock(data);
        }
        return;
    }
    if (dataLen < HDR_SIZE) {
        LOG_ERROR_S("invalid ble packet too small");
        return;
    }
    BleTransHeader orig;
    memcpy(&orig, bytes, HDR_SIZE);
    uint32_t seq = ntohl(orig.seq);
    uint32_t total = ntohl(orig.total);
    const uint8_t *payloadPtr = bytes + HDR_SIZE;
    size_t chunkPayloadCap = mtu - HDR_SIZE;
    uint32_t offset = 0;
    while (offset < total) {
        uint32_t remain = total - offset;
        uint32_t chunkSize = (uint32_t)std::min((uint32_t)chunkPayloadCap, remain);
        std::vector<uint8_t> chunk;
        chunk.resize(HDR_SIZE + chunkSize);
        BleTransHeader nh;
        nh.seq = htonl(seq);
        nh.size = htonl(chunkSize);
        nh.offset = htonl(offset);
        nh.total = htonl(total);
        memcpy(chunk.data(), &nh, HDR_SIZE);
        memcpy(chunk.data() + HDR_SIZE, payloadPtr + offset, chunkSize);
        NSData *chunkData = [NSData dataWithBytes:chunk.data() length:chunk.size()];
        if (writeBlock) {
            writeBlock(chunkData);
        }
        offset += chunkSize;
        usleep(1000);
    }
}

// 收到写入请求
- (void)peripheralManager:(CBPeripheralManager *) peripheral didReceiveWriteRequests:(NSArray<CBATTRequest *> *)requests {
    NSData *data = NULL;
    static std::vector<uint8_t> packet;
//    NSData *notifyValue = NULL;
    std::vector<uint8_t> rsp;
    static bool isSlice = false;
    
    BleTransHeader bleHdr;
    
    for (CBATTRequest *request in requests) {
        data = (NSData *)request.value;
        rsp.clear();
        std::vector<uint8_t> temp;
        temp.resize(16);
        memcpy(const_cast<uint8_t*>(temp.data()), [data bytes], 16);
        uint32_t currentSize = (((((temp[4] << 8) + temp[5]) << 8) + temp[6]) << 8) + temp[7];
        uint32_t totalSize = (((((temp[12] << 8) + temp[13]) << 8) + temp[14]) << 8) + temp[15];
        if (isSlice) {
            size_t size = packet.size();
            const uint8_t *tempData = (const uint8_t *)[data bytes];
            packet.resize(size + data.length - 16);
            memcpy(const_cast<uint8_t*>(packet.data() + size), tempData + 16, data.length - 16);
            packet[4] = packet[12];
            packet[5] = packet[13];
            packet[6] = packet[14];
            packet[7] = packet[15];
        } else {
            packet.clear();
            packet.resize(data.length);
            memcpy(const_cast<uint8_t*>(packet.data()), [data bytes], data.length);
        }
        isSlice = false;
        if (currentSize < totalSize && packet.size() != totalSize + 16) {
            isSlice = true;
            continue;
        }
        
        if (!ParseBleHeader(packet, bleHdr)) {
            continue;
        }
        std::string devUUID = [request.central.identifier.UUIDString UTF8String];
        LOG_DEBUG_S("[RECV IN]: uuid = %s total length = %d, model = %d", devUUID.c_str(), packet.size() + sizeof(BleTransHeader), packet[4]);
        if (!ShareManager::shared().HandleBLE(devUUID, packet, false)) {
            continue;
        }
    }
}

- (NSString *)deviceId2UDID:(uint64_t)deviceID {
    char temp[32] = { 0 };
    snprintf(temp, sizeof(temp) - 1, "%016llX", deviceID);
    NSString *udid = [NSString stringWithUTF8String:temp];
    return udid;
}


/// MARK: 蓝牙断开后需要清除数据状态（central）
- (void)blePowerOff {
    std::lock_guard<std::mutex> lock(bleMapMutex);
    
    std::vector<std::string> uuidList;
    for(const auto& pair : bleConnectList) {
        const std::string& uuid = pair.second.uuid;
        uuidList.push_back(uuid);
    }
    
    for(const auto& uuid : uuidList) {
        auto it = bleConnectList.find(uuid);
        if (it == bleConnectList.end()) {
            LOG_ERROR_S("ble connection channel has been excluded2");
            return;
        }
        if (it->second.connectStatus != bleUnconnect) {
            ShareManager::shared().OnBleDisconnect(uuid, it->second.udid);
        }
    }

    if (!bleConnectList.empty()) {
        bleConnectList.clear();
    }
}

@end

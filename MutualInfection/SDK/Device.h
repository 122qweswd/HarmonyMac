//
//  Device.h
//  MutualInfection
//
//  Created by apple on 2025/9/3.
//

#ifndef DEVICE_H
#define DEVICE_H

#include <vector>
#include "ShareSerializer.h"

typedef enum {
    DEV_PHONE_0 = 1,
    DEV_PHONE_1,
    DEV_NO_BLE_PC,
    DEV_TV,
    DEV_PAD,
    DEV_BLE_PC,
    DEV_TYPE_BUTT,
} DeviceType;

typedef enum
{
    PARSE_ADV,
    PARSE_ADV_RSP,
    PARSE_SEC,
    PARSE_SEC_RSP,
    PARSE_BUTT,
} ParsePhase;

typedef enum {
    DEVICE_IDLE,
    DEVICE_BASIC_INFO,
    DEVICE_REF_SYNC,
    DEVICE_AUTH_OPEN,
    DEVICE_SHARE,
    DEVICE_AUTH_META,
    DEVICE_VERIFY_P2P,
    DEVICE_BIND_BYTE,
    DEVICE_BIND_FILE,
    DEVICE_RUNNING,
    DEVICE_AUTH_CLOSE,
    DEVICE_BUTT,
} DeviceState;

// 设备信息结构
typedef struct
{
    char udid[97];
    char devicename[65];
    int type;
    int mode;
    uint64_t updateTime;
    char serviceData[65];
    char wlanIp[17];
    char broadcastIp[17];
    int capabilityBitmap[2];
    char coapUri[257];
    int port;
    int fd;
    int seqNo;
} device_info_t;

typedef struct _stDevice {
    uint64_t deviceId;
    std::string uuid;
    uint8_t version;
    DeviceType type;
    uint8_t feature;
    uint8_t extFeature;
    bool isSupportIOS;
    bool isShowIcon;
    uint8_t foundType;
    uint8_t packet;
    device_info_t info;
    uint64_t updateTime;
    uint64_t discoverStartTime;
    uint64_t discoverEndTime;
    std::vector<uint8_t> deviceKey;
    std::vector<uint8_t> hwContactId;
    std::vector<uint8_t> nickName;
    std::vector<uint8_t> btName;
    std::vector<uint8_t> apMac;
    std::vector<uint8_t> buildLink;
    std::vector<uint8_t> deviceHash;
    
    void UpdateFrom(const std::shared_ptr<struct _stDevice>& other) {
        if (!other->isSupportIOS) {
            return;
        }
        
        deviceId = other->deviceId;
        uuid = other->uuid;
        version = other->version;
        type = other->type;
        feature = other->feature;
        extFeature = other->extFeature;
        isSupportIOS = other->isSupportIOS;
        isShowIcon = other->isShowIcon;
        updateTime = other->updateTime;
 
        if (!other->deviceKey.empty()) {
            deviceKey = other->deviceKey;
        }
        
        if (!other->hwContactId.empty()) {
            hwContactId = other->hwContactId;
        }
        
        if (!other->nickName.empty()) {
            nickName = other->nickName;
        }
        
        if (!other->btName.empty()) {
            btName = other->btName;
        }
        
        if (!other->apMac.empty()) {
            apMac = other->apMac;
        }
        
        if (!other->buildLink.empty()) {
            buildLink = other->buildLink;
        }
        
        if (!other->deviceHash.empty()) {
            deviceHash = other->deviceHash;
        }
     }
} Device;
#endif // DEVICE_H

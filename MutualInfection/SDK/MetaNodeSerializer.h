//
//  MetaNodeSerializer.h
//  MutualInfection
//
//  Created by Law on 2025/9/9.
//

#ifndef META_NODE_SERIALIZER_H
#define META_NODE_SERIALIZER_H

#ifdef __cplusplus

#include <cstdint>
#include <string>
#include <vector>

#include "Device.h"

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#endif

#define HA_DEVICE_NAME "DEVICE_NAME"
#define HA_DEVICE_TYPE_ID "DEVICE_TYPE_ID"
#define HA_META_NODE_ID "META_NODE_ID"
#define HA_FLAG "FLAG"

#define META_DEVICE_INFO_ACK "META_DEVICE_INFO_ACK"

typedef struct
{
    char deviceName[128 + 1];
    int deviceTypeId;
    char metaNodeId[64 + 1];
    int flag;
} DeviceInfo;

class MetaNodeSerializer
{
public:
    static MetaNodeSerializer &shared();
    DeviceInfo GetDeviceInfo();
    bool ParseDeviceInfo(const std::vector<uint8_t> &packet, DeviceInfo &info);
    bool CreateDeviceInfo(std::vector<uint8_t> &payload);
    bool ParseAck(const std::vector<uint8_t> &packet);
    bool CreateAck(std::vector<uint8_t> &payload);

private:
    //Functions
    std::string GenerateMetaNodeId();
    std::vector<uint8_t> GenerateRandomKey();
    std::shared_ptr<Device> GetLocalDevice();
    void SetDeviceInfo();
    bool ParseDeviceInfoJson(std::string json, DeviceInfo &info);
    std::string CreateDeviceInfoJson();

    //Variables
    DeviceInfo myDevice;

protected:
    MetaNodeSerializer();
};
#endif
#endif

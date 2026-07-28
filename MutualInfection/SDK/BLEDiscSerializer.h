//
//  BLEDiscSerializer.h
//  MutualInfection
//
//  Created by apple on 2025/9/3.
//

#ifndef BLE_DISC_SERIALIZER_H
#define BLE_DISC_SERIALIZER_H

#include <string>
#include <vector>
#include "Device.h"

//typedef struct stAdvPacket
//{
//    uint8_t version;
//    DeviceType type;
//    bool isSender;
//
//} AdvPacket;

typedef enum {
    TLV_DID = 0,
    TLV_CONTACT_ID,
    TLV_NICK_NAME,
    TLV_BT_NAME,
    TLV_ABILITY,
    TLV_AP_MAC,
    TLV_BUILD_LINK,
    TLV_DID_HASH,
    TLV_UDID,
    TLV_BUTT,
} TLVType;

const uint64_t INVALID_UDID = 0;

class BLEDiscSerializer
{
public:
    bool IsValidPacket(const uint8_t *buffer, size_t len);
    bool IsValidAdvPacket(const uint8_t *buffer, size_t len);
    bool IsValidAdvRspPacket(const uint8_t *buffer, size_t len);
    bool IsValidSecPacket(const uint8_t *buffer, size_t len);
    bool IsValidSecRspPacket(const uint8_t *buffer, size_t len);
    std::string GetServiceUUID() const;

    void AssembleDiscPacket(std::vector<uint8_t> &packet, const std::string deviceId, bool isSender, bool isReciver);
    bool ParseAdvPacket(const uint8_t *buffer, size_t len, bool &isSender, std::shared_ptr<Device> device);
    void ParseAdvRspPacket(const uint8_t *buffer, size_t len, std::shared_ptr<Device> device);
    void ParseSecPacket(const uint8_t *buffer, size_t len, std::shared_ptr<Device> device);
    void ParseSecRspPacket(const uint8_t *buffer, size_t len, std::shared_ptr<Device> device);
    
private:
    void ParseTLV(const uint8_t *buffer, int len, bool isRspData, std::shared_ptr<Device> device);
    TLVType GetTLVType(uint8_t tlv);
    size_t GetTLVLen(uint8_t tlv);
};
#endif // BLE_DISC_SERIALIZER_H

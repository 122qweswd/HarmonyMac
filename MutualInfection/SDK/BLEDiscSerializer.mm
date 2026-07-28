//
//  BLEDiscSerializer.mm
//  MutualInfection
//
//  Created by apple on 2025/9/3.
//

#include "BLEDiscSerializer.h"
#include <TargetConditionals.h>

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#elif TARGET_OS_MAC
#import <AppKit/AppKit.h>
#endif

const uint8_t COMPANY_ID_0 = 0x7D;
const uint8_t COMPANY_ID_1 = 0x02;
const std::string RSP_SERVICE_UUID = "FE35";

const uint8_t COMMAND_ADV_ID = 0x0E;
const uint8_t COMMAND_ADV_RSP_ID = 0x0F;
const uint8_t COMMAND_SEC_ID = 0x1E;
const uint8_t COMMAND_SEC_PC_ID = 0x1F;
const uint8_t COMMAND_SEC_RSP_ID = 0x2F;

const uint8_t VERSION_MASK = 0xF0;
const uint8_t DEVICE_TYPE_MASK = 0x0F;
const uint8_t SHARE_TYPE_MASK = 0x01;
const uint8_t TLV_TYPE_MASK = 0xE0;
const uint8_t TLV_LEN_MASK = 0x1F;
const uint8_t IOS_ABILITY_MASK = 0x08;
const uint8_t SEC_UDID_MASK = 0x01;
const uint8_t SEC_ABILITY_MASK = 0x02;
const uint8_t SEC_ICON_MASK = 0x02;

const uint8_t VERSION_OFFSET = 4;
const uint8_t TLV_TYPE_OFFSET = 5;

const uint8_t COMPANY_ID_INDEX0 = 0;
const uint8_t COMPANY_ID_INDEX1 = 1;
const uint8_t COMMAND_INDEX = 0;
const uint8_t VERSION_INDEX = 1;
const uint8_t FEATURE_INDEX = 2;
const uint8_t SENDER_INDEX = 3;
const uint8_t SENDER_BID_INDEX = 4;
const uint8_t RECV_INDEX = 6;
const uint8_t RECV_BID_INDEX = 7;
const uint8_t TLV_START_INDEX = 9;
const uint8_t RSP_TLV_START_INDEX = 1;
const uint8_t SEC_RSP_TLV_START_INDEX = 2;
const uint8_t EXT_FEATURE_INDEX = 1;
const uint8_t EXT_TYPE_INDEX_HIGH = 2;
const uint8_t EXT_TYPE_INDEX_LOW = 3;

bool BLEDiscSerializer::IsValidPacket(const uint8_t *buffer, size_t len)
{
    if (buffer == nullptr || len <= COMPANY_ID_INDEX1) {
        return false;
    }

    if (buffer[COMPANY_ID_INDEX0] != COMPANY_ID_0
        || buffer[COMPANY_ID_INDEX1] != COMPANY_ID_1) {
        return false;
    }
    return true;
}

const uint8_t MAX_ADV_SIZE = 12;
const uint8_t RSP_COMPANY_ID_0 = 0x35;
const uint8_t RSP_COMPANY_ID_1 = 0xFE;
const uint8_t RSP_ADV_COMMAND_ID = 0x3E;
const uint8_t RSP_FIX_VERSION_IPHONE = 0x90;
const uint8_t RSP_FIX_VERSION_MAC = 0x93;
const uint8_t RSP_FIX_VERSION_IPAD = 0x95;
const uint8_t RSP_SEND_MASK = 0x01;
const uint8_t RSP_RECV_MASK = 0x02;

void BLEDiscSerializer::AssembleDiscPacket(std::vector<uint8_t> &packet, const std::string deviceId, bool isSender, bool isReciver)
{
    packet.resize(MAX_ADV_SIZE);
    size_t index = 0;
    packet[index++] = RSP_COMPANY_ID_0;
    packet[index++] = RSP_COMPANY_ID_1;
    packet[index++] = RSP_ADV_COMMAND_ID;
    
    // Replace the UIDevice usage with platform-specific code
#if TARGET_OS_IOS
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        packet[index++] = RSP_FIX_VERSION_IPAD;
    } else if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomMac) {
        packet[index++] = RSP_FIX_VERSION_MAC;
    } else {
        packet[index++] = RSP_FIX_VERSION_IPHONE;
    }
#elif TARGET_OS_MAC
    // For macOS, use the MAC version directly
    packet[index++] = RSP_FIX_VERSION_MAC;
#else
    packet[index++] = RSP_FIX_VERSION_IPHONE; // Default fallback
#endif
    
    uint8_t didStep = 0;
    const uint8_t MAX_DID_LEN = 6;
    uint8_t *didBuffer = (uint8_t*)deviceId.c_str();
    while (didStep++ < MAX_DID_LEN) {
        packet[index] = didBuffer[index++];
    }

    uint8_t indicator = 0;
    if (isSender) {
        indicator |= RSP_SEND_MASK;
    }
    if (isReciver) {
        indicator |= RSP_RECV_MASK;
    }
    packet[index++] = indicator;
    packet[index++] = 0;
}

bool BLEDiscSerializer::ParseAdvPacket(const uint8_t *buffer, size_t len, bool &isSender, std::shared_ptr<Device> device)
{
    if (!IsValidAdvPacket(buffer, len)) {
        return false;
    }
    if (!(buffer[SENDER_INDEX] & SHARE_TYPE_MASK) && !(buffer[RECV_INDEX] & SHARE_TYPE_MASK)) {
        return false;
    }
    
//    device->deviceId = INVALID_UDID;
    device->version = (buffer[VERSION_INDEX] & VERSION_MASK) >> VERSION_OFFSET;
    device->type = (DeviceType)(buffer[VERSION_INDEX] & DEVICE_TYPE_MASK);
    device->feature = buffer[FEATURE_INDEX];
    isSender = false;
    if (buffer[SENDER_INDEX] & SHARE_TYPE_MASK) {
        isSender = true;
    }
    ParseTLV(buffer + TLV_START_INDEX, len - TLV_START_INDEX, isSender, device);
    auto now = std::chrono::system_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch());
    device->updateTime = static_cast<uint64_t>(duration.count());
    device->discoverStartTime = device->updateTime;
    return true;
}

void BLEDiscSerializer::ParseAdvRspPacket(const uint8_t *buffer, size_t len, std::shared_ptr<Device> device)
{
    if (!IsValidAdvRspPacket(buffer, len) || device == nullptr) {
        return;
    }
    ParseTLV(buffer + RSP_TLV_START_INDEX, len - RSP_TLV_START_INDEX, false, device);
    auto now = std::chrono::system_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch());
    device->updateTime = static_cast<uint64_t>(duration.count());
}

void BLEDiscSerializer::ParseSecPacket(const uint8_t *buffer, size_t len, std::shared_ptr<Device> device)
{
    if (!IsValidSecPacket(buffer, len) || device == nullptr) {
        return;
    }
    ParseTLV(buffer + RSP_TLV_START_INDEX, len - RSP_TLV_START_INDEX, false, device);
    auto now = std::chrono::system_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch());
    device->updateTime = static_cast<uint64_t>(duration.count());
}

void BLEDiscSerializer::ParseSecRspPacket(const uint8_t *buffer, size_t len, std::shared_ptr<Device> device)
{
    if (!IsValidSecRspPacket(buffer, len) || device == nullptr) {
        return;
    }
    device->extFeature = buffer[EXT_FEATURE_INDEX];
    device->isShowIcon = false;
    if (device->extFeature & SEC_ICON_MASK) {
        device->isShowIcon = true;
    }
    uint8_t index = EXT_TYPE_INDEX_LOW + 1;
    const uint8_t MAX_UDID_LEN = 8;
//    uint8_t udidLen = 8;
    if (buffer[EXT_TYPE_INDEX_LOW] & SEC_UDID_MASK) {
        uint8_t step = 0;
        uint8_t i = 0;
        while (step++ < MAX_UDID_LEN) {
            device->deviceId = (device->deviceId << 8) + buffer[index + i];
            i++;
        }
    }
    index += 8;
    if (buffer[EXT_TYPE_INDEX_LOW] & SEC_ABILITY_MASK) {
        device->isSupportIOS = false;
        if (buffer[index++] & IOS_ABILITY_MASK) {
            device->isSupportIOS = true;
        }
    }
    auto now = std::chrono::system_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch());
    device->updateTime = static_cast<uint64_t>(duration.count());
    device->discoverEndTime = device->updateTime;
}

bool BLEDiscSerializer::IsValidAdvPacket(const uint8_t *buffer, size_t len)
{
    if (buffer == nullptr || len <= COMMAND_INDEX || buffer[COMMAND_INDEX] != COMMAND_ADV_ID) {
        return false;
    }
    
    return true;
}

void BLEDiscSerializer::ParseTLV(const uint8_t *buffer, int len, bool isSender, std::shared_ptr<Device> device)
{
    if (device == nullptr) {
        return;
    }

    TLVType type = TLV_BUTT;
    size_t tlvLen = 0;
    while (len > 0) {
        type = GetTLVType(buffer[0]);
        tlvLen = GetTLVLen(buffer[0]);
        switch (type) {
            case TLV_DID:
                device->deviceKey.clear();
                device->deviceKey.insert(device->deviceKey.begin(), buffer + 1, buffer + 1 + tlvLen);
                break;

            case TLV_CONTACT_ID:
                device->hwContactId.clear();
                device->hwContactId.insert(device->hwContactId.begin(), buffer + 1, buffer + 1 + tlvLen);
                break;

            case TLV_NICK_NAME:
                device->nickName.clear();
                device->nickName.insert(device->nickName.begin(), buffer + 1, buffer + 1 + tlvLen);
                break;

            case TLV_BT_NAME:
                if (isSender && buffer[1] == 0) {
                    device->isSupportIOS = false;
                    if (buffer[2] & IOS_ABILITY_MASK) {
                        device->isSupportIOS = true;
                    }
                } else {
                    device->btName.clear();
                    device->btName.insert(device->btName.begin(), buffer + 1, buffer + 1 + tlvLen);
                    device->btName.emplace_back('\0');
                }
                break;
                
            case TLV_ABILITY:
//                device->isSupportIOS = false;
//                if (buffer[1] & IOS_ABILITY_MASK) {
//                    device->isSupportIOS = true;
//                }
                break;

            case TLV_AP_MAC:
                device->apMac.clear();
                device->apMac.insert(device->apMac.begin(), buffer + 1, buffer + 1 + tlvLen);
                break;

            case TLV_BUILD_LINK:
                device->buildLink.clear();
                device->buildLink.insert(device->buildLink.begin(), buffer + 1, buffer + 1 + tlvLen);
                break;
                
            case TLV_DID_HASH:
                device->deviceHash.clear();
                device->deviceHash.insert(device->deviceHash.begin(), buffer + 1, buffer + 1 + tlvLen);
                break;
            default:
                break;
        }
        len -= tlvLen + 1;
        buffer += tlvLen + 1;
    }
}

TLVType BLEDiscSerializer::GetTLVType(uint8_t tlv)
{
    return (TLVType)((tlv & TLV_TYPE_MASK) >> TLV_TYPE_OFFSET);
}

size_t BLEDiscSerializer::GetTLVLen(uint8_t tlv)
{
    return tlv & TLV_LEN_MASK;
}

bool BLEDiscSerializer::IsValidAdvRspPacket(const uint8_t *buffer, size_t len)
{
    if (buffer != nullptr && len > COMMAND_INDEX && buffer[COMMAND_INDEX] == COMMAND_ADV_RSP_ID) {
        return true;
    }
    
    return false;
}

bool BLEDiscSerializer::IsValidSecPacket(const uint8_t *buffer, size_t len)
{
    if (buffer == nullptr || len <= COMMAND_INDEX) {
        return false;
    }
    if (buffer[COMMAND_INDEX] != COMMAND_SEC_ID
        && buffer[COMMAND_INDEX] != COMMAND_SEC_PC_ID) {
        return false;
    }
    return true;
}

bool BLEDiscSerializer::IsValidSecRspPacket(const uint8_t *buffer, size_t len)
{
    if (buffer != nullptr && len > COMMAND_INDEX && buffer[COMMAND_INDEX] == COMMAND_SEC_RSP_ID) {
        return true;
    }
    return false;
}

std::string BLEDiscSerializer::GetServiceUUID() const
{
    return RSP_SERVICE_UUID;
}

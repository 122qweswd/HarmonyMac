//
//  BleConncetBusinessCtrlProtol.mm
//  MutualInfection
//
//  Created by apple on 2025/9/8.
//
#include "ShareSerializer.h"
#include "ShareHelper.h"
#include "LogHelper.h"
#include "AuthManager.h"
#include <cstdint>

// 二级 command id
#define ISHARE_APPLE_ECOLOGY_AP_SSID 0x01
#define ISHARE_APPLE_ECOLOGY_AP_IP 0x02

#define ISHARE_APPLE_ECOLOGY_STA_SSID 0x03
#define ISHARE_APPLE_ECOLOGY_STA_IP 0x04

#define ISHARE_APPLE_ECOLOGY_GO_SSID 0x05
#define ISHARE_APPLE_ECOLOGY_GO_IP 0x06

#define ISHARE_APPLE_ECOLOGY_PHY_SSID 0x01
#define ISHARE_APPLE_ECOLOGY_PHY_PSK 0x02
#define ISHARE_APPLE_ECOLOGY_PHY_IP 0x03
#define ISHARE_APPLE_ECOLOGY_PHY_TIMEOUT 0x04

#define ISHARE_APPLE_ECOLOGY_CONNECTION_IP      0x01
#define ISHARE_APPLE_ECOLOGY_AP_STATION_IPV6    0x02

#define INSHARE_APPLE_ECOLOGY_AVATAR_DATA 0x01

// File preview
#define ISHARE_APPLE_ECOLOGY_FILE_PREVIEW       0x0B
#define ISHARE_APPLE_ECOLOGY_FILE_PREVIEW_IMAGE 0x0C
#define ISHARE_APPLE_ECOLOGY_MEDIA_DATA_INFO    0x0D

#define ISHARE_APPLE_ECOLOGY_FILE_PREVIEW_ACK   0x08

#define ISHARE_POPUP_CONFIRM 0xd6
#define ISHARE_RECEIVER_DBAC_STATUS 0xd8

const std::string DFILE_PERCENT_PREFIX = "dfileRecvPercent#";
const std::string ALREADY_IN_RECV = "next_recv";
const std::string TRANS_ERR = "transErr";
const std::string TRANS_ERR_ACK = "transErrAck";
const std::string NOT_ENOUGH_SPACE = "notEnoughSpace";
const std::string HOTSPOT_ENABLED = "hotspotOn";
const std::string KEEP_ALIVE = "keepAlive";

static uint32_t parseEaUint32(const std::vector<uint8_t> &data, unsigned int &offset)
{
    UnPackagedEA result = ShareHelper::removeEA(data, offset);
    offset = result.offset;
    return result.value;
}

static void PackTlvStr(int type, const std::string &str, std::vector<uint8_t> &packet)
{
    // type
    std::vector<uint8_t> tmp;
	ShareHelper::addEA(type, tmp);
    packet.insert(packet.end(), tmp.begin(), tmp.end());

    // length
	ShareHelper::addEA(static_cast<uint32_t>(str.size()), tmp);
    packet.insert(packet.end(), tmp.begin(), tmp.end());

    if (str.size() > 0) {
        // value
        packet.insert(packet.end(), str.begin(), str.end());
    }
}

void PackFileShareInfoPayload(FileShareInfo &fileShareInfo, std::vector<uint8_t> &out_payload)
{
    out_payload.clear();
    std::vector<uint8_t> children;
    std::vector<uint8_t> type;
	ShareHelper::addEA(0x01, type);
    children.insert(children.end(), type.begin(), type.end());
    std::vector<uint8_t> length;
    ShareHelper::addEA(fileShareInfo.sendType.size(), length);
    children.insert(children.end(), length.begin(), length.end());
    children.insert(children.end(), fileShareInfo.sendType.begin(),
                    fileShareInfo.sendType.end());
    
	ShareHelper::addEA(0x02, type);
    children.insert(children.end(), type.begin(), type.end());
	ShareHelper::addEA(fileShareInfo.senderName.size(), length);
    children.insert(children.end(), length.begin(), length.end());
    children.insert(children.end(), fileShareInfo.senderName.begin(),
                    fileShareInfo.senderName.end());
    
	ShareHelper::addEA(0x03, type);
    children.insert(children.end(), type.begin(), type.end());
	ShareHelper::addEA(fileShareInfo.itemCount.size(), length);
    children.insert(children.end(), length.begin(), length.end());
    children.insert(children.end(), fileShareInfo.itemCount.begin(),
                    fileShareInfo.itemCount.end());
    
	ShareHelper::addEA(0x04, type);
    children.insert(children.end(), type.begin(), type.end());
	ShareHelper::addEA(fileShareInfo.totalSize.size(), length);
    children.insert(children.end(), length.begin(), length.end());
    children.insert(children.end(), fileShareInfo.totalSize.begin(),
                    fileShareInfo.totalSize.end());

	ShareHelper::addEA(0x05, type);
    children.insert(children.end(), type.begin(), type.end());    
	ShareHelper::addEA(fileShareInfo.folderCount.size(), length);
    children.insert(children.end(), length.begin(), length.end());
    children.insert(children.end(), fileShareInfo.folderCount.begin(),
                    fileShareInfo.folderCount.end());

	ShareHelper::addEA(0x06, type);
    children.insert(children.end(), type.begin(), type.end());
	ShareHelper::addEA(fileShareInfo.fileCount.size(), length);
    children.insert(children.end(), length.begin(), length.end());
    children.insert(children.end(), fileShareInfo.fileCount.begin(),
                    fileShareInfo.fileCount.end());
    
	ShareHelper::addEA(0x07, type);
    children.insert(children.end(), type.begin(), type.end());
	ShareHelper::addEA(fileShareInfo.previewSummary.size(), length);
    children.insert(children.end(), length.begin(), length.end());
    children.insert(children.end(), fileShareInfo.previewSummary.begin(),
                    fileShareInfo.previewSummary.end());

    std::vector<uint8_t> commandID;
	ShareHelper::addEA(0x07, commandID);
    out_payload.insert(out_payload.end(), commandID.begin(), commandID.end());
    std::vector<uint8_t> children_length;
	ShareHelper::addEA(children.size(), children_length);
    out_payload.insert(out_payload.end(), children_length.begin(),
                       children_length.end());
    out_payload.insert(out_payload.end(), children.begin(), children.end());
}

bool ParseFileShareInfoPayload(std::vector<uint8_t> &data, FileShareInfo &fileShareInfo)
{
    uint32_t offset = 0;
    uint32_t valueType = 0;
    uint32_t valueLength = 0;

    while (offset < data.size()) {
        valueType = parseEaUint32(data, offset);
        valueLength = parseEaUint32(data, offset);

        std::string value(data.begin() + offset,
                          data.begin() + offset + valueLength);
        offset += valueLength;
        switch (valueType)
        {
        case 0x01:
            fileShareInfo.sendType = value;
            break;
        case 0x02:
            fileShareInfo.senderName = value;
            break;
        case 0x03:
            fileShareInfo.itemCount = value;
            break;
        case 0x04:
            fileShareInfo.totalSize = value;
            break;
        case 0x05:
            fileShareInfo.folderCount = value;
            break;
        case 0x06:
            fileShareInfo.fileCount = value;
            break;
        case 0x07:
            fileShareInfo.previewSummary = value;
            break;
        default:
            LOG_DEBUG_S("Unknown valueType: %u", valueType);
            break;
        }
    }
    return true;
}

void PackUserAckPayload(int type, std::vector<uint8_t> &out_payload)
{
    out_payload.clear();
    std::vector<uint8_t> children;
    std::string messageType = "";
    uint8_t tType = 0x01;
    switch (type) {
        case 0:
            messageType = "user_confirm";
            tType = 0x01;
            break;
        case 1:
            messageType = "user_reject";
            tType = 0x01;
            break;
        case 2:
            messageType = "senderCancel";
            tType = 0x02;
            break;
        case 3:
            tType = 0x03;
            messageType = "senderCancelACK";
            break;
        case 4:
            tType = 0x04;
            messageType = "receiverCancel";
            break;
        case 5:
            tType = 0x05;
            messageType = "receiverCancelACK";
            break;
        default:
            break;
    }
    std::vector<uint8_t> tempType;
    ShareHelper::addEA(tType, tempType);
    children.insert(children.end(), tempType.begin(), tempType.end());
    std::vector<uint8_t> length;
    ShareHelper::addEA(messageType.size(), length);
    children.insert(children.end(), length.begin(), length.end());
    children.insert(children.end(), messageType.begin(), messageType.end());
    std::vector<uint8_t> commandID;
    ShareHelper::addEA(0x01, commandID);
    out_payload.insert(out_payload.end(), commandID.begin(), commandID.end());
    std::vector<uint8_t> children_length;
    ShareHelper::addEA(children.size(), children_length);
    out_payload.insert(out_payload.end(), children_length.begin(),
                       children_length.end());
    out_payload.insert(out_payload.end(), children.begin(), children.end());
}

bool ParseUserAckPayload(std::vector<uint8_t> &data, bool &is_confirm)
{
    uint32_t offset = 0;
    uint32_t commandID = parseEaUint32(data, offset);
    if (commandID != 0x01 && commandID != 0x02 && commandID != 0x03 && commandID != 0x04 && commandID != 0x05) {
        return false;
    }
    uint32_t length = parseEaUint32(data, offset);

    std::string ackValue(data.begin() + offset, data.begin() + offset + length);
    offset += length;
    if (ackValue.compare("user_confirm") == 0) {
        is_confirm = true;
    } else if (ackValue.compare("user_reject") == 0) {
        is_confirm = false;
    } else if (ackValue.compare("senderCancel") == 0 || ackValue.compare("receiverCancel") == 0) {
        is_confirm = true;
    } else if (ackValue.compare("senderCancelACK") == 0 || ackValue.compare("receiverCancelACK") == 0) {
        is_confirm = true;
    }
    return true;
}

static void PackDirectConnectCommon(int cmdId, const NetworkInfo_t &ni, std::vector<uint8_t> &packet)
{
    std::vector<uint8_t> payload;
    PackTlvStr(ISHARE_APPLE_ECOLOGY_AP_SSID, ni.apSsid, payload);
    PackTlvStr(ISHARE_APPLE_ECOLOGY_AP_IP, ni.apIp, payload);
    PackTlvStr(ISHARE_APPLE_ECOLOGY_STA_SSID, ni.staSsid, payload);
    PackTlvStr(ISHARE_APPLE_ECOLOGY_STA_IP, ni.staIp, payload);

    // type
	ShareHelper::addEA(cmdId, packet);

    // length
    std::vector<uint8_t> tmp;
	ShareHelper::addEA(static_cast<uint32_t>(payload.size()), tmp);
    packet.insert(packet.end(), tmp.begin(), tmp.end());
    packet.insert(packet.end(), payload.begin(), payload.end());
}

void PackDirectConnectReq(const NetworkInfo_t &ni, std::vector<uint8_t> &packet)
{
    packet.clear();
    PackDirectConnectCommon(ISHARE_APPLE_ECOLOGY_NETWORKINFO_NEGO_REQ_ID, ni, packet);
}

void PackDirectConnectAck(const NetworkInfo_t &ni, std::vector<uint8_t> &packet)
{
    packet.clear();
    PackDirectConnectCommon(ISHARE_APPLE_ECOLOGY_NETWORKINFO_NEGO_RSP_ID, ni, packet);
}

bool ParseDirectConnect(uint8_t *data, size_t datalen, NetworkInfo_t &ni)
{
    uint32_t type = 0;
    uint32_t tlvLen = 0;
    uint32_t offset = 0;

    std::vector<uint8_t> vectData;
    vectData.resize(datalen);
    memcpy(vectData.data(), data, datalen);

    while (offset < vectData.size()) {
        type = parseEaUint32(vectData, offset);
        tlvLen = parseEaUint32(vectData, offset);

        std::string value(vectData.begin() + offset, vectData.begin() + offset + tlvLen);

        switch (type)
        {
            case ISHARE_APPLE_ECOLOGY_AP_SSID:
                ni.apSsid = value;
                break;
            case ISHARE_APPLE_ECOLOGY_AP_IP:
                ni.apIp = value;
                break;
            case ISHARE_APPLE_ECOLOGY_STA_SSID:
                ni.staSsid = value;
                break;
            case ISHARE_APPLE_ECOLOGY_STA_IP:
                ni.staIp = value;
                break;
            case ISHARE_APPLE_ECOLOGY_GO_SSID:
                ni.goSsid = value;
                break;
            case ISHARE_APPLE_ECOLOGY_GO_IP:
                ni.goIp = value;
                break;
            default:
                break;
        }
        offset += tlvLen;
    }

    return true;
}

void PackRequestConnect(const CommonTwoTlvsInfo_t &rci, std::vector<uint8_t> &packet)
{
    packet.clear();
    std::vector<uint8_t> payload;
    PackTlvStr(ISHARE_APPLE_ECOLOGY_PHY_SSID, rci.strValue1, payload);
    PackTlvStr(ISHARE_APPLE_ECOLOGY_PHY_PSK, rci.strValue2, payload);

    // type
	ShareHelper::addEA(ISHARE_APPLE_ECOLOGY_PHYSICAL_CONNECTION_INFO_ID, packet);

    // length
    std::vector<uint8_t> tmp;
	ShareHelper::addEA(static_cast<uint32_t>(payload.size()), tmp);
    packet.insert(packet.end(), tmp.begin(), tmp.end());
    packet.insert(packet.end(), payload.begin(), payload.end());
}

bool ParseRequestConnect(uint8_t *data, uint32_t datalen, ConnectInfo &rci)
{
    uint32_t type = 0;
    uint32_t tlvLen = 0;
    uint32_t offset = 0;

    std::vector<uint8_t> vectData;
    vectData.resize(datalen);
    memcpy(vectData.data(), data, datalen);

    while (offset < vectData.size()) {
        type = parseEaUint32(vectData, offset);
        tlvLen = parseEaUint32(vectData, offset);

        std::string value(vectData.begin() + offset, vectData.begin() + offset + tlvLen);

        switch (type)
        {
        case ISHARE_APPLE_ECOLOGY_PHY_SSID:
            rci.peerSSID = value;
            break;
        case ISHARE_APPLE_ECOLOGY_PHY_PSK:
            rci.peerPSK = value;
            break;
        case ISHARE_APPLE_ECOLOGY_PHY_IP:
            rci.peerIP = value;
            break;
        case ISHARE_APPLE_ECOLOGY_PHY_TIMEOUT:
            rci.timeout = value;
            break;
        default:
            break;
        }

        offset += tlvLen;
    }

    return true;
}

void PackBleConnectOk(const std::string &ip, const std::string &ipv6, std::vector<uint8_t> &packet)
{
    packet.clear();
    std::vector<uint8_t> payload;
    PackTlvStr(ISHARE_APPLE_ECOLOGY_CONNECTION_IP, ip, payload);
    if (!ipv6.empty()) {
        PackTlvStr(ISHARE_APPLE_ECOLOGY_AP_STATION_IPV6, ipv6, payload);
    }

    // type
	ShareHelper::addEA(ISHARE_APPLE_ECOLOGY_LOGICAL_CONNECTION_INFO_ID, packet);

    // length
    std::vector<uint8_t> tmp;
	ShareHelper::addEA(static_cast<uint32_t>(payload.size()), tmp);
    packet.insert(packet.end(), tmp.begin(), tmp.end());
    packet.insert(packet.end(), payload.begin(), payload.end());
}

bool ParseBleConnectOk(uint8_t *data, uint32_t datalen, CommonTwoTlvsInfo_t &ci)
{
    uint32_t type = 0;
    uint32_t tlvLen = 0;
    uint32_t offset = 0;

    std::vector<uint8_t> vectData;
    vectData.resize(datalen);
    memcpy(vectData.data(), data, datalen);

    while (offset < vectData.size()) {
        type = parseEaUint32(vectData, offset);
        tlvLen = parseEaUint32(vectData, offset);

        // value
        std::string value(vectData.begin() + offset, vectData.begin() + offset + tlvLen);
        switch (type)
        {
        case ISHARE_APPLE_ECOLOGY_CONNECTION_IP:
            ci.strValue1 = value;
            break;
        case ISHARE_APPLE_ECOLOGY_AP_STATION_IPV6:
            ci.strValue2 = value;
            break;
        default:
            break;
        }
        offset += tlvLen;
    }

    return true;
}

void PackFilePreview(const CommonTwoTlvsInfo_t &ci, std::vector<uint8_t> &packet)
{
    packet.clear();
    std::vector<uint8_t> payload;
    PackTlvStr(ISHARE_APPLE_ECOLOGY_FILE_PREVIEW, ci.strValue1, payload);
    PackTlvStr(ISHARE_APPLE_ECOLOGY_MEDIA_DATA_INFO, ci.strValue2, payload);

    // type
	ShareHelper::addEA(ISHARE_APPLE_ECOLOGY_PREVIEW_RECV_ID, packet);

    // length
    std::vector<uint8_t> tmp;
	ShareHelper::addEA(static_cast<uint32_t>(payload.size()), tmp);
    packet.insert(packet.end(), tmp.begin(), tmp.end());
    packet.insert(packet.end(), payload.begin(), payload.end());
}

bool ParseFilePreview(uint8_t *data, uint32_t datalen, CommonTlvInfo_t &ci)
{
    uint32_t type = 0;
    uint32_t tlvLen = 0;
    uint32_t offset = 0;

    std::vector<uint8_t> vectData;
    vectData.resize(datalen);
    memcpy(vectData.data(), data, datalen);

    while (offset < vectData.size()) {
        type = parseEaUint32(vectData, offset);
        tlvLen = parseEaUint32(vectData, offset);

        // value
        std::string value(vectData.begin() + offset, vectData.begin() + offset + tlvLen);
        switch (type)
        {
        case ISHARE_APPLE_ECOLOGY_FILE_PREVIEW:
            ci.strVals[0] = value;
            break;
        case ISHARE_APPLE_ECOLOGY_FILE_PREVIEW_IMAGE:
            ci.strVals[1] = value;
            break;
        case ISHARE_APPLE_ECOLOGY_MEDIA_DATA_INFO:
            ci.strVals[2] = value;
            break;
        default:
            break;
        }
        offset += tlvLen;
    }

    return true;
}

void PackFilePreviewAck(const CommonOneTlvInfo_t &ci, std::vector<uint8_t> &packet)
{
    packet.clear();
    std::vector<uint8_t> payload;
    PackTlvStr(ISHARE_APPLE_ECOLOGY_FILE_PREVIEW_ACK, ci.strValue, payload);

    // type
    ShareHelper::addEA(ISHARE_APPLE_ECOLOGY_COMMAND_ID, packet);

    // length
    std::vector<uint8_t> tmp;
    ShareHelper::addEA(static_cast<uint32_t>(payload.size()), tmp);
    packet.insert(packet.end(), tmp.begin(), tmp.end());
    packet.insert(packet.end(), payload.begin(), payload.end());
}


bool ParseFilePreviewAck(uint8_t *data, uint32_t datalen, CommonOneTlvInfo_t &ci)
{
    return true;
}

bool ParseRecvPercentPayload(const std::vector<uint8_t> &data, double &percent)
{
    uint32_t offset = 0;
    uint32_t commandID = parseEaUint32(data, offset);
    if (commandID != ISHARE_ECOLOGY_DFILE_RECV_PERCENT) {
        return false;
    }
    uint32_t length = parseEaUint32(data, offset);

    std::string recvString(data.begin() + offset, data.begin() + offset + length);
    auto pos = recvString.find(DFILE_PERCENT_PREFIX);
    if (pos != std::string::npos) {
        percent = atof(recvString.substr(pos + DFILE_PERCENT_PREFIX.length()).c_str());
        return true;
    }
    return false;
}

void PackRecvPercentPayload(double percent, std::vector<uint8_t> &packet)
{
    packet.clear();
    std::string percentString = DFILE_PERCENT_PREFIX + std::to_string(percent);
    std::vector<uint8_t> payload;
    PackTlvStr(ISHARE_ECOLOGY_DFILE_RECV_PERCENT, percentString, payload);
    
    // type
    ShareHelper::addEA(ISHARE_APPLE_ECOLOGY_COMMAND_ID, packet);

    // length
    std::vector<uint8_t> tmp;
    ShareHelper::addEA(static_cast<uint32_t>(payload.size()), tmp);
    packet.insert(packet.end(), tmp.begin(), tmp.end());
    packet.insert(packet.end(), payload.begin(), payload.end());
}

bool ParseAlreadyRecv(const std::vector<uint8_t> &data)
{
    uint32_t offset = 0;
    uint32_t commandID = parseEaUint32(data, offset);
    if (commandID != ISHARE_ECOLOGY_ALREADY_IN_RECEIVE) {
        return false;
    }
    return true;
}

void PackAlreadyRecv(std::vector<uint8_t> &packet)
{
    packet.clear();
    std::vector<uint8_t> payload;
    PackTlvStr(ISHARE_ECOLOGY_ALREADY_IN_RECEIVE, ALREADY_IN_RECV, payload);
    
    // type
    ShareHelper::addEA(ISHARE_APPLE_ECOLOGY_COMMAND_ID, packet);

    // length
    std::vector<uint8_t> tmp;
    ShareHelper::addEA(static_cast<uint32_t>(payload.size()), tmp);
    packet.insert(packet.end(), tmp.begin(), tmp.end());
    packet.insert(packet.end(), payload.begin(), payload.end());
}

bool ParseTransError(const std::vector<uint8_t> &data)
{
    uint32_t offset = 0;
    uint32_t commandID = parseEaUint32(data, offset);
    if (commandID != ISHARE_ECOLOGY_TRANS_ERROR) {
        return false;
    }
    uint32_t length = parseEaUint32(data, offset);

    std::string recvString(data.begin() + offset, data.begin() + offset + length);
    if (recvString == TRANS_ERR) {
        return true;
    }
    return false;
}

void PackTransError(std::vector<uint8_t> &packet)
{
    packet.clear();
    std::vector<uint8_t> payload;
    PackTlvStr(ISHARE_ECOLOGY_TRANS_ERROR, TRANS_ERR, payload);
    
    // type
    ShareHelper::addEA(ISHARE_APPLE_ECOLOGY_COMMAND_ID, packet);

    // length
    std::vector<uint8_t> tmp;
    ShareHelper::addEA(static_cast<uint32_t>(payload.size()), tmp);
    packet.insert(packet.end(), tmp.begin(), tmp.end());
    packet.insert(packet.end(), payload.begin(), payload.end());
}

bool ParseNotEnoughSpace(const std::vector<uint8_t> &data)
{
    uint32_t offset = 0;
    uint32_t commandID = parseEaUint32(data, offset);
    if (commandID != ISHARE_ECOLOGY_NOT_ENOUGH_SPACE)
    {
        return false;
    }
    uint32_t length = parseEaUint32(data, offset);

    std::string recvString(data.begin() + offset, data.begin() + offset + length);
    if (recvString == NOT_ENOUGH_SPACE)
    {
        return true;
    }
    return false;
}

void PackNotEnoughSpace(std::vector<uint8_t> &packet)
{
    packet.clear();
    std::vector<uint8_t> payload;
    PackTlvStr(ISHARE_ECOLOGY_NOT_ENOUGH_SPACE, NOT_ENOUGH_SPACE, payload);

    // type
    ShareHelper::addEA(ISHARE_APPLE_ECOLOGY_COMMAND_ID, packet);

    // length
    std::vector<uint8_t> tmp;
    ShareHelper::addEA(static_cast<uint32_t>(payload.size()), tmp);
    packet.insert(packet.end(), tmp.begin(), tmp.end());
    packet.insert(packet.end(), payload.begin(), payload.end());
}

void PackHotspotNoti(std::vector<uint8_t> &packet)
{
    packet.clear();
    std::vector<uint8_t> payload;
    PackTlvStr(ISHARE_ECOLOGY_HOTSPOT_ENABLED, HOTSPOT_ENABLED, packet);
    ShareHelper::addEA(ISHARE_APPLE_ECOLOGY_COMMAND_ID, packet);
    
    std::vector<uint8_t> tmp;
    ShareHelper::addEA(static_cast<uint32_t>(payload.size()), tmp);
    packet.insert(packet.end(), tmp.begin(), tmp.end());
    packet.insert(packet.end(), payload.begin(), payload.end());
}

bool ParseAvatarData(const std::vector<uint8_t> &data, std::string &avatar)
{
    uint32_t offset = 0;
    uint32_t commandID = parseEaUint32(data, offset);
    if (commandID != ISHARE_ECOLOGY_SAVE_AVATER)
    {
        return false;
    }
    uint32_t length = parseEaUint32(data, offset);

    std::string avatarData(data.begin() + offset, data.begin() + offset + length);
    avatar = avatarData;
    return true;
}

void PackKeepAlive(std::vector<uint8_t> &packet)
{
    packet.clear();
    std::vector<uint8_t> payload;
    PackTlvStr(ISHARE_ECOLOGY_KEEP_ALIVE, KEEP_ALIVE, payload);

    // type
    ShareHelper::addEA(ISHARE_APPLE_ECOLOGY_COMMAND_ID, packet);

    // length
    std::vector<uint8_t> tmp;
    ShareHelper::addEA(static_cast<uint32_t>(payload.size()), tmp);
    packet.insert(packet.end(), tmp.begin(), tmp.end());
    packet.insert(packet.end(), payload.begin(), payload.end());
}

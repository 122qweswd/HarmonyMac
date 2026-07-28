//
//  ble_packet.mm
//  Service
//
//  Created by apple on 2025/9/2.
//
#include "AuthChannel.h"
#include <cstring>
#include "DeviceManager.h"
#include "AuthManager.h"
#include <openssl/rand.h>
#include "Common.h"
#include "LogHelper.h"
#include "DFile/securec.h"
#include "ShareManager.h"

#define MODULE_SESSION 6
#define MAX_DATA_LEN (40 * 1000)

#define NET_CTRL_MSG_TYPE_HEADER_SIZE             4
#define VERSION 1
#define PROXY_CHANNEL_HEAD_LEN 8
#define PROXY_CHANNEL_D2D_HEAD_LEN 6
#define PROXY_CHANNEL_MESSAGE_HEAD_LEN 7
#define PROXY_CHANNEL_BYTES_HEAD_LEN 6
#define PAGING_CHANNEL_HEAD_LEN 4
#define PAGING_CHANNEL_HANDSHAKE_HEAD_LEN 14
#define VERSION_SHIFT 4
#define FOUR_BIT_MASK 0xF
#define ENCRYPTED 0x1
#define AUTH_SERVER_SIDE 0x2
#define USE_BLE_CIPHER 0x4
#define BAD_CIPHER 0x8
#define CS_MODE 0x10
#define AUTH_SINGLE_CIPHER 0x28 // To be compatible with LegacyOs, use 0x28 which & BAD_CIPHER also BAD_CIPHER
#define PROXY_BYTES_LENGTH_MAX (4 * 1024 * 1024)
#define PROXY_MESSAGE_LENGTH_MAX 1024

#define FLAG_REQUEST 0
#define FLAG_REPLY 1
#define FLAG_WIFI 0
#define FLAG_BR 2
#define FLAG_BLE 4
#define FLAG_P2P 8
#define FLAG_AUTH_META 16
#define FLAG_ENHANCE_P2P 32
#define FLAG_SESSION_KEY 64
#define FLAG_SLE 64
#define FLAG_NEW 128
#define AUTH_CONN_SERVER_SIDE 0x01
#define NAKEDCHANNELSESSIONHANDSHAKE_DATA_OFFSET (sizeof(BleTransHeader) + sizeof(ConnPktHead))

#define AUTH_HEAD_SIZE             24

typedef enum {
    PROXYCHANNEL_MSG_TYPE_NORMAL,
    PROXYCHANNEL_MSG_TYPE_HANDSHAKE,
    PROXYCHANNEL_MSG_TYPE_HANDSHAKE_ACK,
    PROXYCHANNEL_MSG_TYPE_RESET,
    PROXYCHANNEL_MSG_TYPE_KEEPALIVE,
    PROXYCHANNEL_MSG_TYPE_KEEPALIVE_ACK,
    PROXYCHANNEL_MSG_TYPE_HANDSHAKE_AUTH,
    PROXYCHANNEL_MSG_TYPE_PAGING_HANDSHAKE = 10,
    PROXYCHANNEL_MSG_TYPE_PAGING_HANDSHAKE_ACK,
    PROXYCHANNEL_MSG_TYPE_PAGING_BADKEY,
    PROXYCHANNEL_MSG_TYPE_PAGING_RESET,
    PROXYCHANNEL_MSG_TYPE_D2D,
    PROXYCHANNEL_MSG_TYPE_MAX
} MsgType;

typedef enum {
    CONNECT_TCP = 1,
    CONNECT_BR,
    CONNECT_BLE,
    CONNECT_P2P,
    CONNECT_P2P_REUSE,
    CONNECT_BLE_DIRECT,
    CONNECT_HML,
    CONNECT_TRIGGER_HML,
    CONNECT_SLE,
    CONNECT_SLE_DIRECT,
    CONNECT_BLE_GENERAL,
    CONNECT_TRIGGER_HML_V2C,
    CONNECT_PROXY_CHANNEL,
    CONNECT_PAGING,
    CONNECT_TYPE_MAX
} ConnectType;

typedef enum {
    CONN_DEFAULT = 0,
    CONN_LOW,
    CONN_MIDDLE,
    CONN_HIGH
} SendPriority;

enum BleNetCtrlMsgType {
    NET_CTRL_MSG_TYPE_UNKNOW = -1,
    NET_CTRL_MSG_TYPE_AUTH = 0,
    NET_CTRL_MSG_TYPE_BASIC_INFO = 1,
    NET_CTRL_MSG_TYPE_DEV_INFO = 2,
};

static const size_t BLE_TRANS_HEADER_SIZE = sizeof(BleTransHeader);

static bool IsLittleEndian(void)
{
    uint32_t data = 0x1;
    if (data == ntohl(data)) {
        return false;
    } else {
        return true;
    }
}

static void ShiftByte(uint8_t *in, int8_t inSize)
{
    int8_t left = 0;
    int8_t right = inSize - 1;
    while (left < right) {
        in[left] ^= in[right];
        in[right] ^= in[left];
        in[left] ^= in[right];
        ++left;
        --right;
    }
}

static void ProcByteOrder(uint8_t *value, int8_t size)
{
    if (IsLittleEndian()) {
        return;
    }
    ShiftByte(value, size);
}

uint32_t SoftBusHtoLl(uint32_t value)
{
    uint32_t res = value;
    ProcByteOrder((uint8_t *)&res, (int8_t)sizeof(res));
    return res;
}

uint64_t SoftBusHtoLll(uint64_t value)
{
    uint64_t res = value;
    ProcByteOrder((uint8_t *)&res, (int8_t)sizeof(res));
    return res;
}

uint32_t SoftBusLtoHl(uint32_t value)
{
	uint32_t res = value;
	ProcByteOrder((uint8_t*)&res, (int8_t)sizeof(res));
	return res;
}

uint16_t SoftBusLEtoBEs(uint16_t value)
{
	if (!IsLittleEndian()) {
		return value;
	}
	uint16_t res = value;
	ShiftByte((uint8_t*)&res, (int8_t)sizeof(res));
	return res;
}

uint16_t SoftBusLtoHs(uint16_t value)
{
	uint16_t res = value;
	ProcByteOrder((uint8_t*)&res, (int8_t)sizeof(res));
	return res;
}

void PackProxyMessageHead(ProxyMessageHead *msg)
{
	if (msg == nullptr) {
        return;
    }
	msg->myId = htons(msg->myId);
	msg->peerId = htons(msg->peerId);
	msg->reserved = htons(msg->reserved);
}

void UnpackProxyMessageHead(ProxyMessageHead *msg)
{
	if (msg == nullptr) {
        return;
    }
	msg->myId = ntohs(msg->myId);
	msg->peerId = ntohs(msg->peerId);
	msg->reserved = ntohs(msg->reserved);
}

void PackConnPktHead(ConnPktHead *data)
{
    if (data == NULL) {
        return;
    }
    data->magic = (int32_t)SoftBusHtoLl((uint32_t)data->magic);
    data->flag = (int32_t)SoftBusHtoLl((uint32_t)data->flag);
    data->module = (int32_t)SoftBusHtoLl((uint32_t)data->module);
    data->len = SoftBusHtoLl(data->len);
    data->seq = (int64_t)SoftBusHtoLll((uint64_t)data->seq);
}

static void ConnBlePackCtrlMsgHeader(ConnPktHead *header, int32_t module, uint32_t dataLen)
{
    static int64_t ctlMsgSeqGenerator = 0;
    int64_t seq = ctlMsgSeqGenerator++;

    header->magic = MAGIC_NUMBER;
    header->module = module; // MODULE_PROXY_CHANNEL;
    header->seq = seq;
    header->flag = CONN_HIGH;
    header->len = dataLen;
    PackConnPktHead(header);
}

static void PackBleTransHeader(BleTransHeader *bth, uint32_t size)
{
    if (bth == NULL) {
        return;
    }

    static uint32_t bleTransHeaderMsgSeqGenerator = 0;
    uint32_t seq = bleTransHeaderMsgSeqGenerator++;
    bth->seq = htonl(seq);
    bth->size = htonl(size);
    bth->offset = 0;
    bth->total = htonl(size);
}

static int32_t UnpackTransHeader(uint8_t *data, uint32_t dataLen, BleTransHeader *header)
{
    if (dataLen < BLE_TRANS_HEADER_SIZE) {
        return 1;
    }
    BleTransHeader *tmp = (BleTransHeader *)data;
    header->seq = ntohl(tmp->seq);
    header->size = ntohl(tmp->size);
    header->offset = ntohl(tmp->offset);
    header->total = ntohl(tmp->total);
    if ((header->size != dataLen - BLE_TRANS_HEADER_SIZE) || (header->total > MAX_DATA_LEN) ||
        (header->size > header->total) || (header->total - header->size < header->offset)) {
        LOG_DEBUG_S("unpack ble trans header fail, dataLen=%u, total=%u, currentPacketSize=%u",
            dataLen, header->total, header->size);
        return 1;
    }
    return 0;
}

uint32_t GetAuthDataSize(uint32_t len)
{
    return AUTH_HEAD_SIZE + len;
}

int32_t PackAuthData(const AuthHead *head, const uint8_t *data,
    uint8_t *buf, uint32_t size)
{
    if (head == NULL || data == NULL || buf == NULL) {
        LOG_DEBUG_S("param error");
        return 1;
    }
//    if (size < GetAuthDataSize(head->len)) {
//        return 1;
//    }
    uint32_t offset = 0;
    *(uint32_t *)buf = (head->dataType);
    offset += sizeof(uint32_t);
    *(uint32_t *)(buf + offset) = ((uint32_t)head->module);
    offset += sizeof(uint32_t);
    *(uint64_t *)(buf + offset) = ((uint64_t)head->seq);
    offset += sizeof(uint64_t);
    *(uint32_t *)(buf + offset) = ((uint32_t)head->flag);
    offset += sizeof(uint32_t);
    *(uint32_t *)(buf + offset) = (head->len);
    offset += sizeof(uint32_t);

    memcpy(buf + offset, data, head->len);
    return 0;
}

static const uint8_t *UnpackAuthHead(const uint8_t *data, uint32_t len, AuthHead *head)
{
    if (len < GetAuthDataSize(0)) {
        LOG_DEBUG_S("head not enough");
        return NULL;
    }
    uint32_t offset = 0;
    head->dataType = *(uint32_t *)data; //ntohl(*(uint32_t *)data);
    offset += sizeof(uint32_t);
    head->module = *(uint32_t *)(data + offset);//(int32_t)ntohl(*(uint32_t *)(data + offset));
    offset += sizeof(uint32_t);
    head->seq = *(uint64_t *)(data + offset);// (int64_t)ntohl(*(uint64_t *)(data + offset));
    offset += sizeof(uint64_t);
    head->flag = *(uint32_t *)(data + offset);//(int32_t)ntohl(*(uint32_t *)(data + offset));
    offset += sizeof(uint32_t);
    head->len = *(uint32_t *)(data + offset);// ntohl(*(uint32_t *)(data + offset));
    offset += sizeof(uint32_t);
    uint32_t dataLen = GetAuthDataSize(head->len);
    if (len < dataLen || dataLen < GetAuthDataSize(0)) {
        LOG_DEBUG_S("data not enough");
        return NULL;
    }
    return (data + offset);
}

void PackTdcPacketHead(TdcPacketHead *tph, int cipherFlag, uint32_t datalen)
{
    static uint32_t tdcPacketHeadMsgSeqGenerator = 0;
    uint32_t seq = tdcPacketHeadMsgSeqGenerator++;
    tph->magicNumber = MAGIC_NUMBER;
    tph->module = MODULE_SESSION;
    tph->seq = seq;
    tph->flags = cipherFlag;//
    tph->dataLen = datalen; /* reset after encrypt */
}

// void PackProxyMessageHead(ProxyMessageHead *pmh)
// {
//     if (pmh == NULL) {
//         return;
//     }
//     pmh->TYPE = (PROXYCHANNEL_MSG_TYPE_NORMAL & FOUR_BIT_MASK) | (VERSION << VERSION_SHIFT);
//     pmh->cipher = (pmh->cipher | ENCRYPTED);
//     // pmh->myId = 0;
//     // pmh->peerId = 0;
// }

static int currentMyId = 1030;
//static int peerId = -1;

//void PackRequest(const std::vector<uint8_t> &payload, std::vector<uint8_t> &request, int peerId, bool isProxy)
//{
//    // pack BLEHeader
//    request.resize(48);
//    BleTransHeader bleHead;
//    PackBleTransHeader(&bleHead, 32 + payload.size());
//    memcpy(request.data(), &bleHead, 16);
//
//    // pack connect head
//    ConnPktHead connHead;
//    ConnBlePackCtrlMsgHeader(&connHead, MODULE_PROXY_CHANNEL, 8 + payload.size());
//    PackConnPktHead(&connHead);
//    memcpy(request.data() + 16, &connHead, 24);
//
//    // pack proxy message
//    ProxyMessageHead msg;
//    if (isProxy) {
//        msg.TYPE = 0x11;
//    } else {
//        msg.TYPE = 0x10;
//    }
//
//    msg.cipher = 0x10;
//    msg.myId = currentMyId;
//    msg.peerId = peerId;
//    msg.reserved = 0;
//    PackProxyMessageHead(&msg);
//    memcpy(request.data() + 40, &msg, 8);
//    request.insert(request.end(), payload.begin(), payload.end());
//}

// Bind File会话协商Close ACK报文
void PackBindFileSessionHandshakeCloseAck(const FileChannelCloseHandshakeAck &bfshca, std::vector<uint8_t> &data)
{
    try {
        nlohmann::json j;
        j["CODE"] = bfshca.CODE;
        j["PKG_NAME"] = std::string(bfshca.PKG_NAME);
        j["BUSINESS_TYPE"] = bfshca.BUSINESS_TYPE;
        j["STREAM_TYPE"] = bfshca.STREAM_TYPE;
        j["API_VERSION"] = bfshca.API_VERSION;
        j["TRANS_CAPABILITY"] = bfshca.TRANS_CAPABILITY;
        
        std::string json_str = j.dump();
        std::vector<uint8_t> rspPayload(json_str.begin(), json_str.end() + 1);
        std::vector<uint8_t> rspRandomKey;
        rspRandomKey.resize(12);
        RAND_bytes(rspRandomKey.data(), 12);
        std::vector<uint8_t> sessionKey;
        ShareManager::shared().EncryptWithAESGCM(rspPayload, rspRandomKey, data);
        data.insert(data.begin(), rspRandomKey.begin(), rspRandomKey.end());
    } catch (const nlohmann::json::exception& e) {
        LOG_DEBUG_S("JSON parsing error: %s", e.what());
    } catch (const std::exception& e) {
        LOG_DEBUG_S("error: %s", e.what());
    } catch (...) {
        LOG_DEBUG_S("Unknown exception during JSON parsing");
    }
}

bool ParseBindFileSessionHandshakeCloseAck(nlohmann::json &j, FileChannelCloseHandshakeAck &bfshca)
{
    try {
        bfshca.CODE = j.at("CODE").get<uint16_t>();

        bfshca.PKG_NAME = j.at("PKG_NAME").get<std::string>();        
        bfshca.BUSINESS_TYPE = j.at("BUSINESS_TYPE").get<uint8_t>();
        bfshca.STREAM_TYPE = j.at("STREAM_TYPE").get<uint8_t>();
        bfshca.API_VERSION = j.at("API_VERSION").get<uint8_t>();
        bfshca.TRANS_CAPABILITY = j.at("TRANS_CAPABILITY").get<uint8_t>();
        return true;
    } catch (const nlohmann::json::exception& e) {
        LOG_DEBUG_S("JSON parsing error: %s", e.what());
    } catch (const std::exception& e) {
        LOG_DEBUG_S("error: %s", e.what());
    } catch (...) {
        LOG_DEBUG_S("Unknown exception during JSON parsing");
    }
    return false;
}

static uint32_t g_SeqBlePacket = 0;
static uint64_t g_SeqConnPacket = 0;
static uint64_t g_SeqAuthPacket = 0;

bool IsPartialBLEPacket(const std::vector<uint8_t> &packet)
{
    BleTransHeader hdr;
    memcpy_s(&hdr, sizeof(hdr), packet.data(), sizeof(hdr));
    hdr.size = ntohl(hdr.size);
    hdr.total = ntohl(hdr.total);
    return hdr.size != hdr.total;
}

bool IsConnPacket(const std::vector<uint8_t> &packet)
{
    ConnPktHead hdr;
    memcpy_s(&hdr, sizeof(hdr), packet.data(), sizeof(hdr));
    return hdr.magic == MAGIC_NUMBER;
}

bool ParseBleHeader(std::vector<uint8_t> &packet, BleTransHeader &hdr)
{
    memcpy_s(&hdr, sizeof(hdr), packet.data(), sizeof(hdr));
    hdr.seq = ntohl(hdr.seq);
    hdr.size = ntohl(hdr.size);
    hdr.offset = ntohl(hdr.offset);
    hdr.total = ntohl(hdr.total);
    if (packet.size() != hdr.size + sizeof(hdr)) {
        LOG_ERROR_S("Invalid BLE packet, discard it");
        return false;
    }
    packet.erase(packet.begin(), packet.begin() + sizeof(hdr));
    return true;
}

void PackBleHeader(const std::vector<uint8_t> &payload, BleTransHeader &hdr, std::vector<uint8_t> &packet)
{
    hdr.seq = htonl(hdr.seq);
    hdr.size = htonl(hdr.size);
    hdr.offset = htonl(hdr.offset);
    hdr.total = htonl(hdr.total);
    packet.resize(sizeof(hdr));
    memcpy(packet.data(), &hdr, sizeof(hdr));
    packet.insert(packet.end(), payload.begin(), payload.end());
}

bool ParseNetCtrlHeader(std::vector<uint8_t> &packet, NetCtrlMsgHead &hdr)
{
    memcpy_s(&hdr, sizeof(hdr), packet.data(), sizeof(hdr));
    if (hdr.type != NET_CTRL_MSG_TYPE_BASIC_INFO) {
        LOG_ERROR_S("Invalid net control header, discard it");
        return false;
    }
    packet.erase(packet.begin(), packet.begin() + sizeof(hdr));
    return true;
}

void PackNetCtrlHeader(const std::vector<uint8_t> &payload, NetCtrlMsgHead &hdr, std::vector<uint8_t> &packet)
{
    packet.resize(sizeof(hdr));
    memcpy(packet.data(), &hdr, sizeof(hdr));
    packet.insert(packet.end(), payload.begin(), payload.end());
}

bool ParseConnHeader(std::vector<uint8_t> &packet, ConnPktHead &hdr)
{
    memcpy_s(&hdr, sizeof(hdr), packet.data(), sizeof(hdr));
    if (hdr.magic != MAGIC_NUMBER) {
        LOG_ERROR_S("invalid magic number of connect header, discard it");
        return false;
    }
    if (packet.size() != hdr.len + sizeof(hdr)) {
        LOG_ERROR_S("invalid length of connect header, discard it");
        return false;
    }
    packet.erase(packet.begin(), packet.begin() + sizeof(hdr));
    return true;
}

void PackConnHeader(const std::vector<uint8_t> &payload, ConnPktHead &hdr, std::vector<uint8_t> &packet)
{
    packet.resize(sizeof(hdr));
    memcpy(packet.data(), &hdr, sizeof(hdr));
    packet.insert(packet.end(), payload.begin(), payload.end());
}

bool ParseProxyHeader(std::vector<uint8_t> &packet, ProxyMessageHead &hdr)
{
    memcpy_s(&hdr, sizeof(hdr), packet.data(), sizeof(hdr));
    hdr.myId = ntohs(hdr.myId);
    hdr.peerId = ntohs(hdr.peerId);
    hdr.reserved = ntohs(hdr.reserved);
    packet.erase(packet.begin(), packet.begin() + sizeof(hdr));
    return true;
}

void PackProxyHeader(const std::vector<uint8_t> &payload, ProxyMessageHead &hdr, std::vector<uint8_t> &packet)
{
    hdr.myId = htons(hdr.myId);
    hdr.peerId = htons(hdr.peerId);
    hdr.reserved = htons(hdr.reserved);
    packet.resize(sizeof(hdr));
    memcpy(packet.data(), &hdr, sizeof(hdr));
    packet.insert(packet.end(), payload.begin(), payload.end());
}

bool ParseAuthHeader(std::vector<uint8_t> &packet, AuthHead &hdr)
{
    memcpy_s(&hdr, sizeof(hdr), packet.data(), sizeof(hdr));
    if (packet.size() != hdr.len + sizeof(hdr)) {
        LOG_ERROR_S("invalid length of auth header, discard it");
        return false;
    }
    packet.erase(packet.begin(), packet.begin() + sizeof(hdr));
    return true;
}

void PackAuthHeader(const std::vector<uint8_t> &payload, AuthHead &hdr, std::vector<uint8_t> &packet)
{
    packet.resize(sizeof(hdr));
    memcpy(packet.data(), &hdr, sizeof(hdr));
    packet.insert(packet.end(), payload.begin(), payload.end());
}

// 基本信息交换报文
void PackBasicInfoExchange(const PayloadBasicInfo &basicInfo, std::vector<uint8_t> &data)
{
    try {
        // 将 PayloadBasicInfo 转换为 JSON 对象
        nlohmann::json j;
        j["devid"] = basicInfo.devid;
        j["type"] = basicInfo.TYPE;
        j["devtype"] = basicInfo.deviceType;
        j["FEATURE_SUPPORT"] = basicInfo.FEATURE_SUPPORT;

        // 序列化 JSON 为字符串
        std::string json_str = j.dump();
        data.resize(json_str.length() + 1);
        memcpy(data.data(), json_str.c_str(), json_str.length());

        NetCtrlMsgHead netHdr;
        netHdr.type = NET_CTRL_MSG_TYPE_BASIC_INFO;
        std::vector<uint8_t> temp;
        PackNetCtrlHeader(data, netHdr, temp);
        
        BleTransHeader bleHdr;
        bleHdr.seq = g_SeqBlePacket++;
        bleHdr.size = static_cast<uint32_t>(temp.size());
        bleHdr.offset = 0;
        bleHdr.total = static_cast<uint32_t>(temp.size());
        PackBleHeader(temp, bleHdr, data);
    } catch (const nlohmann::json::exception& e) {
        LOG_DEBUG_S("JSON parsing error: %s", e.what());
    } catch (const std::exception& e) {
        LOG_DEBUG_S("error: %s", e.what());
    } catch (...) {
        LOG_DEBUG_S("Unknown exception during JSON parsing");
    }
}

bool ParseBasicInfoExchange(const std::vector<uint8_t> &packet, PayloadBasicInfo &basicInfo)
{
    try {
        uint8_t *json_data = const_cast<uint8_t *>(packet.data());
        size_t json_len = packet.size();
            
        // 将 JSON 数据转换为字符串
        std::string json_str(reinterpret_cast<char*>(json_data), json_len);
        // 解析 JSON
        nlohmann::json j = nlohmann::json::parse(json_str);
        
        // 提取字段到 PayloadBasicInfo 结构体
        if (j.contains("devid")) {
            basicInfo.devid = j.at("devid").get<std::string>();
            if (basicInfo.devid.length() > 64) {
                LOG_DEBUG_S("device ID too long");
                return false;
            }
        }
        basicInfo.TYPE = j.at("type").get<int8_t>();
        basicInfo.deviceType = j.at("devtype").get<int8_t>();
        basicInfo.FEATURE_SUPPORT = j.at("FEATURE_SUPPORT").get<int8_t>();
        return true;
    } catch (const nlohmann::json::exception& e) {
        LOG_DEBUG_S("JSON parsing error: %s", e.what());
    } catch (const std::exception& e) {
        LOG_DEBUG_S("error: %s", e.what());
    } catch (...) {
        LOG_DEBUG_S("Unknown exception during JSON parsing");
    }
    return false;
}

// 引用计数同步报文
void PackRefNumSync(const RefNumSync &rns, std::vector<uint8_t> &data)
{
    try {
        nlohmann::json j;
        j["KEY_METHOD"] = rns.KEY_METHOD;
        j["KEY_DELTA"] = rns.KEY_DELTA;
        j["KEY_REF_NUM"] = rns.KEY_REF_NUM;
        j["KEY_CHALLENGE"] = rns.KEY_CHALLENGE;
        
        // 序列化 JSON 为字符串
        std::string json_str = j.dump();
        data.resize(json_str.length());
        memcpy(data.data(), json_str.c_str(), json_str.length());

        ConnPktHead connHdr;
        connHdr.magic = MAGIC_NUMBER;
        connHdr.module = MODULE_CONNECTION;
        connHdr.seq = g_SeqConnPacket++;
        connHdr.flag = 0x03;
        connHdr.len = static_cast<uint32_t>(data.size());
        std::vector<uint8_t> temp;
        PackConnHeader(data, connHdr, temp);
        
        BleTransHeader bleHdr;
        bleHdr.seq = g_SeqBlePacket++;
        bleHdr.size = static_cast<uint32_t>(temp.size());
        bleHdr.offset = 0;
        bleHdr.total = static_cast<uint32_t>(temp.size());
        PackBleHeader(temp, bleHdr, data);
    } catch (const nlohmann::json::exception& e) {
        LOG_DEBUG_S("JSON parsing error: %s", e.what());
    } catch (const std::exception& e) {
        LOG_DEBUG_S("error: %s", e.what());
    } catch (...) {
        LOG_DEBUG_S("Unknown exception during JSON parsing");
    }
}

bool ParseRefNumSync(const std::vector<uint8_t> &packet, RefNumSync &rns)
{
    try {
        uint8_t *json_data = const_cast<uint8_t *>(packet.data());
        size_t json_len = packet.size();
    
        std::string json_str(reinterpret_cast<char*>(json_data), json_len);
        nlohmann::json j = nlohmann::json::parse(json_str);
        
        rns.KEY_METHOD = j.at("KEY_METHOD").get<uint8_t>();
        rns.KEY_DELTA = j.at("KEY_DELTA").get<int8_t>();
        rns.KEY_REF_NUM = j.at("KEY_REF_NUM").get<uint8_t>();
        rns.KEY_CHALLENGE = j.at("KEY_CHALLENGE").get<uint8_t>();
        return true;
    } catch (const nlohmann::json::exception& e) {
        LOG_DEBUG_S("JSON parsing error: %s", e.what());
    } catch (const std::exception& e) {
        LOG_DEBUG_S("error: %s", e.what());
    } catch (...) {
        LOG_DEBUG_S("Unknown exception during JSON parsing");
    }
    return false;
}

// 裸通道会话协商请求报文
void PackNakedChannelHandshakeReq(const NakedChannelHandshake &ncsh, uint16_t myId, std::vector<uint8_t> &data)
{
    try {
        nlohmann::json j;
        j["TYPE"] = ncsh.TYPE;
        j["IDENTITY"] = std::string(ncsh.IDENTITY);
        j["DEVICE_ID"] = std::string(ncsh.DEVICE_ID);
        j["SRC_BUS_NAME"] = std::string(ncsh.SRC_BUS_NAME);
        j["DST_BUS_NAME"] = std::string(ncsh.DST_BUS_NAME);
        j["API_VERSION"] = ncsh.API_VERSION;
        j["MTU_SIZE"] = ncsh.MTU_SIZE;
        j["TRANS_CAPABILITY"] = ncsh.TRANS_CAPABILITY;
        j["HAS_PRIORITY"] = ncsh.HAS_PRIORITY;
        j["REQUEST_ID"] = std::string(ncsh.REQUEST_ID);
        j["PKG_NAME"] = std::string(ncsh.PKG_NAME);
        
        // 序列化 JSON 为字符串
        std::string json_str = j.dump();
        data.resize(json_str.length() + 1);
        memcpy(data.data(), json_str.c_str(), json_str.length());
        
        std::vector<uint8_t> temp;
        ProxyMessageHead proxyHdr;
        proxyHdr.TYPE = 0x11;
        proxyHdr.cipher = 0x10;
        proxyHdr.myId = myId; //ShareManager::shared().GetMyChannelId();
        proxyHdr.peerId = 0xFFFF; //ShareManager::shared().GetPeerChannelId();
        proxyHdr.reserved = 0;
        PackProxyHeader(data, proxyHdr, temp);

        std::vector<uint8_t> temp2;
        ConnPktHead connHdr;
        connHdr.magic = MAGIC_NUMBER;
        connHdr.module = MODULE_PROXY_CHANNEL;
        connHdr.seq = g_SeqConnPacket++;
        connHdr.flag = 0x03;
        connHdr.len = static_cast<uint32_t>(temp.size());
        PackConnHeader(temp, connHdr, temp2);
        
        BleTransHeader bleHdr;
        bleHdr.seq = g_SeqBlePacket++;
        bleHdr.size = static_cast<uint32_t>(temp2.size());
        bleHdr.offset = 0;
        bleHdr.total = static_cast<uint32_t>(temp2.size());
        PackBleHeader(temp2, bleHdr, data);
    } catch (const nlohmann::json::exception& e) {
        LOG_DEBUG_S("JSON parsing error: %s", e.what());
    } catch (const std::exception& e) {
        LOG_DEBUG_S("error: %s", e.what());
    } catch (...) {
        LOG_DEBUG_S("Unknown exception during JSON parsing");
    }
}

bool ParseNakedChannelHandshakeReq(const std::vector<uint8_t> &packet, NakedChannelHandshake &ncsh)
{
    try {
        uint8_t *json_data = const_cast<uint8_t *>(packet.data());
        size_t json_len = packet.size();
    
        std::string json_str(reinterpret_cast<char*>(json_data), json_len);
        nlohmann::json j = nlohmann::json::parse(json_str);
        
        ncsh.TYPE = j.at("TYPE").get<uint8_t>();
        
        std::string IDENTITY = j.at("IDENTITY").get<std::string>();
        if (IDENTITY.size() >= sizeof(ncsh.IDENTITY)) {
            LOG_DEBUG_S("IDENTITY too long");
            return false;
        }
        strncpy(ncsh.IDENTITY, IDENTITY.c_str(), sizeof(ncsh.IDENTITY) - 1);
        ncsh.IDENTITY[sizeof(ncsh.IDENTITY) - 1] = '\0';
        
        std::string DEVICE_ID = j.at("DEVICE_ID").get<std::string>();
        if (DEVICE_ID.size() >= sizeof(ncsh.DEVICE_ID)) {
            LOG_DEBUG_S("DEVICE_ID too long");
            return false;
        }
        strncpy(ncsh.DEVICE_ID, DEVICE_ID.c_str(), sizeof(ncsh.DEVICE_ID) - 1);
        ncsh.DEVICE_ID[sizeof(ncsh.DEVICE_ID) - 1] = '\0';
        
        std::string SRC_BUS_NAME = j.at("SRC_BUS_NAME").get<std::string>();
        if (SRC_BUS_NAME.size() >= sizeof(ncsh.SRC_BUS_NAME)) {
            LOG_DEBUG_S("SRC_BUS_NAME too long");
            return false;
        }
        strncpy(ncsh.SRC_BUS_NAME, SRC_BUS_NAME.c_str(), sizeof(ncsh.SRC_BUS_NAME) - 1);
        ncsh.SRC_BUS_NAME[sizeof(ncsh.SRC_BUS_NAME) - 1] = '\0';
        
        std::string DST_BUS_NAME = j.at("DST_BUS_NAME").get<std::string>();
        if (DST_BUS_NAME.size() >= sizeof(ncsh.DST_BUS_NAME)) {
            LOG_DEBUG_S("DST_BUS_NAME too long");
            return false;
        }
        strncpy(ncsh.DST_BUS_NAME, DST_BUS_NAME.c_str(), sizeof(ncsh.DST_BUS_NAME) - 1);
        ncsh.DST_BUS_NAME[sizeof(ncsh.DST_BUS_NAME) - 1] = '\0';
        
        ncsh.API_VERSION = j.at("API_VERSION").get<uint8_t>();
        ncsh.MTU_SIZE = j.at("MTU_SIZE").get<uint32_t>();
        ncsh.TRANS_CAPABILITY = j.at("TRANS_CAPABILITY").get<uint8_t>();
        ncsh.HAS_PRIORITY = j.at("HAS_PRIORITY").get<uint8_t>();
        
        std::string REQUEST_ID = j.at("REQUEST_ID").get<std::string>();
        if (REQUEST_ID.size() >= sizeof(ncsh.REQUEST_ID)) {
            LOG_DEBUG_S("REQUEST_ID too long");
            return false;
        }
        strncpy(ncsh.REQUEST_ID, REQUEST_ID.c_str(), sizeof(ncsh.REQUEST_ID) - 1);
        ncsh.REQUEST_ID[sizeof(ncsh.REQUEST_ID) - 1] = '\0';
        
        std::string PKG_NAME = j.at("PKG_NAME").get<std::string>();
        if (PKG_NAME.size() >= sizeof(ncsh.PKG_NAME)) {
            LOG_DEBUG_S("PKG_NAME too long");
            return false;
        }
        strncpy(ncsh.PKG_NAME, PKG_NAME.c_str(), sizeof(ncsh.PKG_NAME) - 1);
        ncsh.PKG_NAME[sizeof(ncsh.PKG_NAME) - 1] = '\0';
        return true;
    } catch (const nlohmann::json::exception& e) {
        LOG_DEBUG_S("JSON parsing error: %s", e.what());
    } catch (const std::exception& e) {
        LOG_DEBUG_S("error: %s", e.what());
    } catch (...) {
        LOG_DEBUG_S("Unknown exception during JSON parsing");
    }
    return false;
}

void PackNakedChannelHandshakeAck(const NakedChannelHandshakeAck &ncsha, const ProxyMessageHead &hdr, std::vector<uint8_t> &data)
{
    try {
        nlohmann::json j;
        j["IDENTITY"] = std::string(ncsha.IDENTITY);
        j["DEVICE_ID"] = std::string(ncsha.DEVICE_ID);
        j["TRANS_CAPABILITY"] = ncsha.TRANS_CAPABILITY;
        j["MTU_SIZE"] = ncsha.MTU_SIZE;
        j["PKG_NAME"] = std::string(ncsha.PKG_NAME);
        
        std::string json_str = j.dump();
        data.resize(json_str.length() + 1);
        memcpy(data.data(), json_str.c_str(), json_str.length());
        
        std::vector<uint8_t> temp;
        ProxyMessageHead proxyHdr;
        proxyHdr.TYPE = 0x12;
        proxyHdr.cipher = 0x10;
        proxyHdr.myId = hdr.myId;
        proxyHdr.peerId = hdr.peerId;
        proxyHdr.reserved = 0;
        PackProxyHeader(data, proxyHdr, temp);

        std::vector<uint8_t> temp2;
        ConnPktHead connHdr;
        connHdr.magic = MAGIC_NUMBER;
        connHdr.module = MODULE_PROXY_CHANNEL;
        connHdr.seq = g_SeqConnPacket++;
        connHdr.flag = 0x03;
        connHdr.len = static_cast<uint32_t>(temp.size());
        PackConnHeader(temp, connHdr, temp2);
        
        BleTransHeader bleHdr;
        bleHdr.seq = g_SeqBlePacket++;
        bleHdr.size = static_cast<uint32_t>(temp2.size());
        bleHdr.offset = 0;
        bleHdr.total = static_cast<uint32_t>(temp2.size());
        PackBleHeader(temp2, bleHdr, data);
    } catch (const nlohmann::json::exception& e) {
        LOG_DEBUG_S("JSON parsing error: %s", e.what());
    } catch (const std::exception& e) {
        LOG_DEBUG_S("error: %s", e.what());
    } catch (...) {
        LOG_DEBUG_S("Unknown exception during JSON parsing");
    }
}

bool ParseNakedChannelHandshakeAck(const std::vector<uint8_t> &packet, NakedChannelHandshakeAck &ncsha)
{
    try {
        uint8_t *json_data = const_cast<uint8_t *>(packet.data());
        size_t json_len = packet.size();
    
        std::string json_str(reinterpret_cast<char*>(json_data), json_len);
        nlohmann::json j = nlohmann::json::parse(json_str);
        
        ncsha.IDENTITY = j.at("IDENTITY").get<std::string>();
        ncsha.DEVICE_ID = j.at("DEVICE_ID").get<std::string>();
        ncsha.TRANS_CAPABILITY = j.at("TRANS_CAPABILITY").get<uint8_t>();
        ncsha.MTU_SIZE = j.at("MTU_SIZE").get<uint32_t>();
        ncsha.PKG_NAME = j.at("PKG_NAME").get<std::string>();
        return true;
    } catch (const nlohmann::json::exception& e) {
        LOG_DEBUG_S("JSON parsing error: %s", e.what());
    } catch (const std::exception& e) {
        LOG_DEBUG_S("error: %s", e.what());
    } catch (...) {
        LOG_DEBUG_S("Unknown exception during JSON parsing");
    }
    return false;
}

// 裸通道会话协商异常报文
void PackNakedChannelHandshakeExcept(const NakedChannelHandshakeExcept &ncshe, const ProxyMessageHead &hdr, std::vector<uint8_t> &data)
{
    try {
        nlohmann::json j;
        j["ERR_CODE"] = ncshe.ERR_CODE;
        
        std::string json_str = j.dump();
        data.resize(json_str.length() + 1);
        memcpy(data.data(), json_str.c_str(), json_str.length());
        
        std::vector<uint8_t> temp;
        ProxyMessageHead proxyHdr;
        proxyHdr.TYPE = 0x12;
        proxyHdr.cipher = 0x10;
        proxyHdr.myId = hdr.myId;
        proxyHdr.peerId = hdr.peerId;
        proxyHdr.reserved = 0;
        PackProxyHeader(data, proxyHdr, temp);

        std::vector<uint8_t> temp2;
        ConnPktHead connHdr;
        connHdr.magic = MAGIC_NUMBER;
        connHdr.module = MODULE_PROXY_CHANNEL;
        connHdr.seq = g_SeqConnPacket++;
        connHdr.flag = 0x03;
        connHdr.len = static_cast<uint32_t>(temp.size());
        PackConnHeader(temp, connHdr, temp2);
        
        BleTransHeader bleHdr;
        bleHdr.seq = g_SeqBlePacket++;
        bleHdr.size = static_cast<uint32_t>(temp2.size());
        bleHdr.offset = 0;
        bleHdr.total = static_cast<uint32_t>(temp2.size());
        PackBleHeader(temp2, bleHdr, data);
    } catch (const nlohmann::json::exception& e) {
        LOG_DEBUG_S("JSON parsing error: %s", e.what());
    } catch (const std::exception& e) {
        LOG_DEBUG_S("error: %s", e.what());
    } catch (...) {
        LOG_DEBUG_S("Unknown exception during JSON parsing");
    }
}

bool ParseNakedChannelHandshakeExcept(uint8_t *pkt, size_t pktLen, NakedChannelHandshakeExcept &ncshe)
{
    try {
        uint8_t *json_start = pkt + sizeof(ProxyMessageHead);
        size_t json_len = pktLen - sizeof(ProxyMessageHead);
        
        std::string json_str(reinterpret_cast<char*>(json_start), json_len);
        nlohmann::json j = nlohmann::json::parse(json_str);
        
        ncshe.ERR_CODE = j.at("ERR_CODE").get<int32_t>();
        return true;
    } catch (const nlohmann::json::exception& e) {
        LOG_DEBUG_S("JSON parsing error: %s", e.what());
    } catch (const std::exception& e) {
        LOG_DEBUG_S("error: %s", e.what());
    } catch (...) {
        LOG_DEBUG_S("Unknown exception during JSON parsing");
    }
    return false;
}

void PackNakedChannelHandshakeWlan(const NakedChannelHandshakeWlan &ncsh, std::vector<uint8_t> &data)
{
    try {
        nlohmann::json j;
        j["CODE"] = ncsh.CODE;
        j["DEVICE_ID"] = ncsh.DEVICE_ID;
        j["PEER_NETWORK_ID"] = ncsh.PEER_NETWORK_ID;
        j["PKG_NAME"] = ncsh.PKG_NAME;
        j["SRC_BUS_NAME"] = ncsh.SRC_BUS_NAME;
        j["DST_BUS_NAME"] = ncsh.DST_BUS_NAME;
        j["REQ_ID"] = ncsh.REQ_ID;
        j["API_VERSION"] = ncsh.API_VERSION;
        j["MTU_SIZE"] = ncsh.MTU_SIZE;
        j["ROUTE_TYPE"] = ncsh.ROUTE_TYPE;
        
        // 序列化 JSON 为字符串
        std::string json_str = j.dump();
        data.resize(json_str.length() + 1);
        memcpy(data.data(), json_str.c_str(), json_str.length());
        
        //        // auth channel data header
        //        AuthChannelData acd = {
        //            .module = MODULE_AUTH_CHANNEL,
        //            .flag = AUTH_CHANNEL_REPLY,
        //            .seq = 0,
        //            .len = (int32_t)(json_str.length() + 1),
        //            .data = (const uint8_t *)json_str.c_str(),
        //        };
        //
        //        // auth header
        //        AuthDataHead adh = {
        //            .dataType = DATA_TYPE_CONNECTION,
        //            .module = acd.module,
        //            .seq = acd.seq,
        //            .len = (uint32_t)acd.len,
        //        };
        //
        //        // socket pkt header
        //        SocketPktHead sph = {
        //            .magic = (int32_t)MAGIC_NUMBER,
        //            .module = adh.module,
        //            .seq = adh.seq,
        //            .flag = adh.flag,
        //            .len = (uint32_t)adh.len,
        //        };
        //
        //        std::vector<uint8_t> packet;
        //        uint32_t size = AUTH_PKT_HEAD_LEN + adh.len;
        //        packet.resize(size);
        //
        //        uint8_t *buf = packet.data();
        //        memcpy(buf, &sph, sizeof(SocketPktHead));
        //        memcpy(buf+sizeof(SocketPktHead), acd.data, acd.len);
    } catch (const nlohmann::json::exception& e) {
        LOG_DEBUG_S("JSON parsing error: %s", e.what());
    } catch (const std::exception& e) {
        LOG_DEBUG_S("error: %s", e.what());
    } catch (...) {
        LOG_DEBUG_S("Unknown exception during JSON parsing");
    }
}

bool ParseNakedChannelHandshakeWlan(const std::vector<uint8_t> &packet, NakedChannelHandshakeWlan &ncsh)
{
    try {
        uint8_t *json_data = const_cast<uint8_t *>(packet.data());
        size_t json_len = packet.size();
    
        std::string json_str(reinterpret_cast<char*>(json_data), json_len);
        nlohmann::json j = nlohmann::json::parse(json_str);
        
        ncsh.CODE = j.at("CODE").get<uint8_t>();
        ncsh.DEVICE_ID = j.at("DEVICE_ID").get<std::string>();
        ncsh.PEER_NETWORK_ID = j.at("PEER_NETWORK_ID").get<std::string>();
        ncsh.PKG_NAME = j.at("PKG_NAME").get<std::string>();
        ncsh.SRC_BUS_NAME = j.at("SRC_BUS_NAME").get<std::string>();
        ncsh.DST_BUS_NAME = j.at("DST_BUS_NAME").get<std::string>();
        ncsh.REQ_ID = j.at("REQ_ID").get<std::string>();
        ncsh.API_VERSION = j.at("API_VERSION").get<uint8_t>();
        ncsh.MTU_SIZE = j.at("MTU_SIZE").get<uint32_t>();
        ncsh.ROUTE_TYPE = j.at("ROUTE_TYPE").get<uint8_t>();
        return true;
    } catch (const nlohmann::json::exception& e) {
        LOG_DEBUG_S("JSON parsing error: %s", e.what());
    } catch (const std::exception& e) {
        LOG_DEBUG_S("error: %s", e.what());
    } catch (...) {
        LOG_DEBUG_S("Unknown exception during JSON parsing");
    }
    return false;
}

void PackShareHeader(const AuthChannel &channel, std::vector<uint8_t> &packet)
{
    std::vector<uint8_t> temp;
    ProxyMessageHead proxyHdr;
    proxyHdr.TYPE = 0x10;
    proxyHdr.cipher = 0x10;
    proxyHdr.myId = channel.myId;
    proxyHdr.peerId = channel.peerId;
    proxyHdr.reserved = 0;
    PackProxyHeader(packet, proxyHdr, temp);


    std::vector<uint8_t> temp2;
    ConnPktHead connHdr;
    connHdr.magic = MAGIC_NUMBER;
    connHdr.module = MODULE_PROXY_CHANNEL;
    connHdr.seq = g_SeqConnPacket++;
    connHdr.flag = 0x03;
    connHdr.len = static_cast<uint32_t>(temp.size());
    PackConnHeader(temp, connHdr, temp2);

    BleTransHeader bleHdr;
    bleHdr.seq = g_SeqBlePacket++;
    bleHdr.size = static_cast<uint32_t>(temp2.size());
    bleHdr.offset = 0;
    bleHdr.total = static_cast<uint32_t>(temp2.size());
    PackBleHeader(temp2, bleHdr, packet);
}

//void PackAuthChannelHeader(std::vector<uint8_t> &packet)
//{
//    std::vector<uint8_t> temp;
//    ConnPktHead connHdr;
//    connHdr.magic = MAGIC_NUMBER;
//    connHdr.module = MODULE_PROXY_CHANNEL;
//    connHdr.seq = g_SeqConnPacket++;
//    connHdr.flag = 0x03;
//    connHdr.len = static_cast<uint32_t>(packet.size());
//    PackConnHeader(packet, connHdr, temp);
//    
//    BleTransHeader bleHdr;
//    bleHdr.seq = g_SeqBlePacket++;
//    bleHdr.size = static_cast<uint32_t>(temp.size());
//    bleHdr.offset = 0;
//    bleHdr.total = static_cast<uint32_t>(temp.size());
//    PackBleHeader(temp, bleHdr, packet);
//}

void PackMetaNodeHeader(std::vector<uint8_t> &packet, AuthHead &hdr, bool isBleChannel)
{
    std::vector<uint8_t> temp;
    PackAuthHeader(packet, hdr, temp);

    if (isBleChannel) {
        std::vector<uint8_t> temp2;
        ConnPktHead connHdr;
        connHdr.magic = MAGIC_NUMBER;
        connHdr.module = MODULE_META_AUTH;
        connHdr.seq = g_SeqConnPacket++;
        connHdr.flag = 0x03;
        connHdr.len = static_cast<uint32_t>(temp.size());
        PackConnHeader(temp, connHdr, temp2);
        
        BleTransHeader bleHdr;
        bleHdr.seq = g_SeqBlePacket++;
        bleHdr.size = static_cast<uint32_t>(temp2.size());
        bleHdr.offset = 0;
        bleHdr.total = static_cast<uint32_t>(temp2.size());
        PackBleHeader(temp2, bleHdr, packet);
    } else {
        packet.resize(temp.size());
        memcpy(packet.data(), temp.data(), temp.size());
    }
}

// VerifyP2p报文
void PacketVerifyP2p(const VerifyP2p &vp, std::vector<uint8_t> &data)
{
    try {
        nlohmann::json j;
        j["CODE"] = vp.CODE;
        j["P2P_IP"] = vp.P2P_IP;
        j["P2P_PORT"] = vp.P2P_PORT;
        j["PROTOCOL_TYPE"] = vp.PROTOCOL_TYPE;
        
        std::string json_str = j.dump();
        std::vector<uint8_t> rspPayload(json_str.begin(), json_str.end() + 1);
        std::vector<uint8_t> rspRandomKey;
        rspRandomKey.resize(12);
        RAND_bytes(rspRandomKey.data(), 12);
        std::vector<uint8_t> sessionKey;
        ShareManager::shared().EncryptWithAESGCM(rspPayload, rspRandomKey, data);
        data.insert(data.begin(), rspRandomKey.begin(), rspRandomKey.end());
    } catch (const nlohmann::json::exception& e) {
        LOG_DEBUG_S("JSON parsing error: %s", e.what());
    } catch (const std::exception& e) {
        LOG_DEBUG_S("error: %s", e.what());
    } catch (...) {
        LOG_DEBUG_S("Unknown exception during JSON parsing");
    }
}

bool ParseChannelPacket(const std::vector<uint8_t> &packet, nlohmann::json &jsPacket)
{
    try {
        std::vector<uint8_t> payload;
        std::vector<uint8_t> salt;
        salt.insert(salt.end(), packet.begin(), packet.begin() + 12);
        payload.insert(payload.end(), packet.begin() + 12, packet.end());
        
        std::vector<uint8_t> jsonData;
        ShareManager::shared().DecryptWithAESGCM(payload, salt, jsonData);

        uint8_t *json_start = jsonData.data();
        size_t json_len = jsonData.size();
    
        std::string json_str(reinterpret_cast<char*>(json_start), json_len);
        jsPacket = nlohmann::json::parse(json_str);
        return true;
    } catch (const nlohmann::json::exception& e) {
        LOG_DEBUG_S("JSON parsing error: %s", e.what());
    } catch (const std::exception& e) {
        LOG_DEBUG_S("error: %s", e.what());
    } catch (...) {
        LOG_DEBUG_S("Unknown exception during JSON parsing");
    }
    return false;
}

bool ParseVerifyP2p(nlohmann::json &jsPacket, VerifyP2p &vp)
{
    try {
        vp.CODE = jsPacket.at("CODE").get<uint16_t>();
        vp.P2P_IP = jsPacket.at("P2P_IP").get<std::string>();
        vp.P2P_PORT = jsPacket.at("P2P_PORT").get<uint32_t>();
        vp.PROTOCOL_TYPE = jsPacket.at("PROTOCOL_TYPE").get<uint8_t>();
        return true;
    } catch (const nlohmann::json::exception& e) {
        LOG_DEBUG_S("JSON parsing error: %s", e.what());
    } catch (const std::exception& e) {
        LOG_DEBUG_S("error: %s", e.what());
    } catch (...) {
        LOG_DEBUG_S("Unknown exception during JSON parsing");
    }
    return false;
}

// Bind Bytes会话协商报文
void PackBindBytesSessionHandshake(const BytesChannelHandshake &bbsh, std::vector<uint8_t> &data)
{
    try {
        std::vector<uint8_t> byteSessionKey;
        byteSessionKey.resize(32);
        RAND_bytes(byteSessionKey.data(), 32);
        ShareManager::shared().SetByteSessionKey(byteSessionKey);
        std::vector<uint8_t> base64SessionKey;
        base64SessionKey.resize(64 + 1);
        SoftBusBase64Encode(base64SessionKey.data(), base64SessionKey.size(), byteSessionKey.data(), byteSessionKey.size());
        
        nlohmann::json j;
        j["CODE"] = bbsh.CODE;
        j["API_VERSION"] = bbsh.API_VERSION;
        j["BUS_NAME"] = std::string(bbsh.BUS_NAME);
        j["MTU_SIZE"] = bbsh.MTU_SIZE;
        j["TRANS_CAPABILITY"] = bbsh.TRANS_CAPABILITY;
        j["PKG_NAME"] = std::string(bbsh.PKG_NAME);
        j["CLIENT_BUS_NAME"] = std::string(bbsh.CLIENT_BUS_NAME);
        j["ROUTE_TYPE"] = bbsh.ROUTE_TYPE;
        j["DEVICE_ID"] = std::string(bbsh.DEVICE_ID);
        j["BUSINESS_TYPE"] = bbsh.BUSINESS_TYPE;
        j["TRANS_FLAGS"] = bbsh.TRANS_FLAGS;
        j["SESSION_KEY"] = std::string((char*)base64SessionKey.data());
        
        std::string json_str = j.dump();
        std::vector<uint8_t> reqPayload(json_str.begin(), json_str.end() + 1);
        std::vector<uint8_t> reqRandomKey;
        reqRandomKey.resize(12);
        RAND_bytes(reqRandomKey.data(), 12);
        ShareManager::shared().EncryptWithAESGCM(reqPayload, reqRandomKey, data);
        data.insert(data.begin(), reqRandomKey.begin(), reqRandomKey.end());
    } catch (const nlohmann::json::exception& e) {
        LOG_DEBUG_S("JSON parsing error: %s", e.what());
    } catch (const std::exception& e) {
        LOG_DEBUG_S("error: %s", e.what());
    } catch (...) {
        LOG_DEBUG_S("Unknown exception during JSON parsing");
    }
}

bool ParseBindBytesSessionHandshake(const std::vector<uint8_t> &packet, BytesChannelHandshake &bbsh)
{
    try {
        std::vector<uint8_t> payload;
        std::vector<uint8_t> salt;
        salt.insert(salt.end(), packet.begin(), packet.begin() + 12);
        payload.insert(payload.end(), packet.begin() + 12, packet.end());

        std::vector<uint8_t> jsonData;
        ShareManager::shared().DecryptWithAESGCM(payload, salt, jsonData);

        uint8_t *json_start = jsonData.data();
        size_t json_len = jsonData.size();

        std::string json_str(reinterpret_cast<char*>(json_start), json_len);
        nlohmann::json j = nlohmann::json::parse(json_str);
        bbsh.CODE = j.at("CODE").get<uint16_t>();
        bbsh.API_VERSION = j.at("API_VERSION").get<uint8_t>();
        
        std::string BUS_NAME = j.at("BUS_NAME").get<std::string>();
        bbsh.BUS_NAME = BUS_NAME;
        
        std::string SESSION_KEY = j.at("SESSION_KEY").get<std::string>();
        bbsh.SESSION_KEY = SESSION_KEY;

        
        bbsh.MTU_SIZE = j.at("MTU_SIZE").get<uint32_t>();
        bbsh.TRANS_CAPABILITY = j.at("TRANS_CAPABILITY").get<uint8_t>();
        
        std::string PKG_NAME = j.at("PKG_NAME").get<std::string>();
        bbsh.PKG_NAME = PKG_NAME;
        
        std::string CLIENT_BUS_NAME = j.at("CLIENT_BUS_NAME").get<std::string>();
        bbsh.CLIENT_BUS_NAME = CLIENT_BUS_NAME;
        
        bbsh.ROUTE_TYPE = j.at("ROUTE_TYPE").get<uint8_t>();
        
        std::string DEVICE_ID = j.at("DEVICE_ID").get<std::string>();
        bbsh.DEVICE_ID = DEVICE_ID;
        
        bbsh.BUSINESS_TYPE = j.at("BUSINESS_TYPE").get<uint8_t>();
        bbsh.TRANS_FLAGS = j.at("TRANS_FLAGS").get<uint8_t>();
        bbsh.SESSION_KEY = j.at("SESSION_KEY").get<std::string>();

        std::vector<uint8_t> byteSessionKey;
        byteSessionKey.resize(SESSION_KEY_LENGTH);
        if (SoftBusBase64Decode(byteSessionKey.data(), byteSessionKey.size(),
                (unsigned char *)bbsh.SESSION_KEY.c_str(), bbsh.SESSION_KEY.length()) != 0) {
            LOG_DEBUG_S("Failed to decode sink byte session key");
            return false;
        }
        ShareManager::shared().SetByteSessionKey(byteSessionKey);
        return true;
    } catch (const nlohmann::json::exception& e) {
        LOG_DEBUG_S("JSON parsing error: %s", e.what());
    } catch (const std::exception& e) {
        LOG_DEBUG_S("error: %s", e.what());
    } catch (...) {
        LOG_DEBUG_S("Unknown exception during JSON parsing");
    }
    return false;
}

// Bind Bytes会话协商ACK报文
void PackBindBytesSessionHandshakeAck(const BytesChannelHandshakeAck &bbsha, std::vector<uint8_t> &data)
{
    try {
        nlohmann::json j;
        j["CODE"] = bbsha.CODE;
        j["API_VERSION"] = bbsha.API_VERSION;
        j["DEVICE_ID"] = std::string(bbsha.DEVICE_ID);
        j["TRANS_CAPABILITY"] = bbsha.TRANS_CAPABILITY;
        j["MTU_SIZE"] = bbsha.MTU_SIZE;
        j["PKG_NAME"] = std::string(bbsha.PKG_NAME);
        
        std::string json_str = j.dump();
        std::vector<uint8_t> rspPayload(json_str.begin(), json_str.end() + 1);
        std::vector<uint8_t> rspRandomKey;
        rspRandomKey.resize(12);
        RAND_bytes(rspRandomKey.data(), 12);
        ShareManager::shared().EncryptWithAESGCM(rspPayload, rspRandomKey, data);
        data.insert(data.begin(), rspRandomKey.begin(), rspRandomKey.end());
    } catch (const nlohmann::json::exception& e) {
        LOG_DEBUG_S("JSON parsing error: %s", e.what());
    } catch (const std::exception& e) {
        LOG_DEBUG_S("error: %s", e.what());
    } catch (...) {
        LOG_DEBUG_S("Unknown exception during JSON parsing");
    }
}

bool ParseBindBytesSessionHandshakeAck(const std::vector<uint8_t> &packet, BytesChannelHandshakeAck &bbsha)
{
    try {
        std::vector<uint8_t> payload;
        std::vector<uint8_t> salt;
        salt.insert(salt.end(), packet.begin(), packet.begin() + 12);
        payload.insert(payload.end(), packet.begin() + 12, packet.end());

        std::vector<uint8_t> jsonData;
        ShareManager::shared().DecryptWithAESGCM(payload, salt, jsonData);

        uint8_t *json_start = jsonData.data();
        size_t json_len = jsonData.size();
    
        std::string json_str(reinterpret_cast<char*>(json_start), json_len);
        nlohmann::json j = nlohmann::json::parse(json_str);

        LOG_DEBUG_S("JSON string length: %zu, content: %s", json_len, json_str.c_str());
        bbsha.CODE = j.at("CODE").get<uint16_t>();
        bbsha.API_VERSION = j.at("API_VERSION").get<uint8_t>();
        
        std::string DEVICE_ID = j.at("DEVICE_ID").get<std::string>();
        bbsha.DEVICE_ID = DEVICE_ID;
        
        bbsha.TRANS_CAPABILITY = j.at("TRANS_CAPABILITY").get<uint8_t>();
        bbsha.MTU_SIZE = j.at("MTU_SIZE").get<uint32_t>();
        
        std::string PKG_NAME = j.at("PKG_NAME").get<std::string>();
        bbsha.PKG_NAME = PKG_NAME;
        LOG_DEBUG_S("Parsed fields - CODE: %u, API_VERSION: %u, DEVICE_ID: %s, TRANS_CAPABILITY: %u, MTU_SIZE: %u, PKG_NAME: %s",
            bbsha.CODE, bbsha.API_VERSION, bbsha.DEVICE_ID.c_str(), 
            bbsha.TRANS_CAPABILITY, bbsha.MTU_SIZE, bbsha.PKG_NAME.c_str());
        return true;
    } catch (const nlohmann::json::exception& e) {
        LOG_DEBUG_S("JSON parsing error: %s", e.what());
    } catch (const std::exception& e) {
        LOG_DEBUG_S("error: %s", e.what());
    } catch (...) {
        LOG_DEBUG_S("Unknown exception during JSON parsing");
    }
    return false;
}

// Bind File会话协商Open报文
void PackBindFileSessionHandshakeOpen(const FileChannelOpenHandshake &bfsho, std::vector<uint8_t> &data)
{
    try {
        std::vector<uint8_t> dFileSessionKey;
        dFileSessionKey.resize(32);
        RAND_bytes(dFileSessionKey.data(), 32);
        ShareManager::shared().SetDFileSessionKey(dFileSessionKey);
        std::vector<uint8_t> base64SessionKey;
        base64SessionKey.resize(64 + 1);
        SoftBusBase64Encode(base64SessionKey.data(), base64SessionKey.size(), dFileSessionKey.data(), dFileSessionKey.size());

        nlohmann::json j;
        j["MY_CHANNEL_ID"] = bfsho.MY_CHANNEL_ID;
        j["MY_IP"] = bfsho.MY_IP;
        j["DEVICE_ID"] = bfsho.DEVICE_ID;
        j["CODE"] = bfsho.CODE;
        j["API_VERSION"] = bfsho.API_VERSION;
        j["BUSINESS_TYPE"] = bfsho.BUSINESS_TYPE;
        j["STREAM_TYPE"] = bfsho.STREAM_TYPE;
        j["CHANNEL_TYPE"] = bfsho.CHANNEL_TYPE;
        j["UDP_CONN_TYPE"] = bfsho.UDP_CONN_TYPE;
        j["BUS_NAME"] = bfsho.BUS_NAME;
        j["CLIENT_BUS_NAME"] = bfsho.CLIENT_BUS_NAME;
        j["PKG_NAME"] = bfsho.PKG_NAME;
        j["TRANS_CAPABILITY"] = bfsho.TRANS_CAPABILITY;
        j["SESSION_KEY"] = std::string((char*)base64SessionKey.data());
        
        std::string json_str = j.dump();
        std::vector<uint8_t> rspPayload(json_str.begin(), json_str.end() + 1);
        std::vector<uint8_t> rspRandomKey;
        rspRandomKey.resize(12);
        RAND_bytes(rspRandomKey.data(), 12);
        ShareManager::shared().EncryptWithAESGCM(rspPayload, rspRandomKey, data);
        data.insert(data.begin(), rspRandomKey.begin(), rspRandomKey.end());
    } catch (const nlohmann::json::exception& e) {
        LOG_DEBUG_S("JSON parsing error: %s", e.what());
    } catch (const std::exception& e) {
        LOG_DEBUG_S("error: %s", e.what());
    } catch (...) {
        LOG_DEBUG_S("Unknown exception during JSON parsing");
    }
}

bool ParseBindFileSessionHandshakeOpen(nlohmann::json &j, FileChannelOpenHandshake &bfsho)
{
    try {
        bfsho.MY_CHANNEL_ID = j.at("MY_CHANNEL_ID").get<uint8_t>();
        
        bfsho.MY_IP = j.at("MY_IP").get<std::string>();
        
        bfsho.DEVICE_ID = j.at("DEVICE_ID").get<std::string>();
        
        bfsho.CODE = j.at("CODE").get<uint16_t>();
        bfsho.API_VERSION = j.at("API_VERSION").get<uint8_t>();
        bfsho.BUSINESS_TYPE = j.at("BUSINESS_TYPE").get<uint8_t>();
        bfsho.STREAM_TYPE = j.at("STREAM_TYPE").get<uint8_t>();

        if (j.contains("CHANNEL_TYPE")) {
            bfsho.CHANNEL_TYPE = j.at("CHANNEL_TYPE").get<uint8_t>();
        }

        bfsho.UDP_CONN_TYPE = j.at("UDP_CONN_TYPE").get<uint32_t>();
        
        bfsho.BUS_NAME = j.at("BUS_NAME").get<std::string>();
        
        bfsho.CLIENT_BUS_NAME = j.at("CLIENT_BUS_NAME").get<std::string>();
        bfsho.PKG_NAME = j.at("PKG_NAME").get<std::string>();
        
        bfsho.TRANS_CAPABILITY = j.at("TRANS_CAPABILITY").get<uint8_t>();
        
        std::string sk = j.at("SESSION_KEY").get<std::string>();
        LOG_DEBUG_S("[ENCRYPTED]SESSION_KEY %lu, %s", sk.size(), sk.c_str());
        std::vector<uint8_t> dFileSessionKey;
        dFileSessionKey.resize(SESSION_KEY_LENGTH);
        if (SoftBusBase64Decode(dFileSessionKey.data(), dFileSessionKey.size(),
                (unsigned char *)sk.data(), sk.length()) != 0) {
            LOG_DEBUG_S("Failed to decode sink session key");
            return false;
        }
        ShareManager::shared().SetDFileSessionKey(dFileSessionKey);
        
        bfsho.SESSION_KEY = dFileSessionKey;
        return true;
    } catch (const nlohmann::json::exception& e) {
        LOG_DEBUG_S("JSON parsing error: %s", e.what());
    } catch (const std::exception& e) {
        LOG_DEBUG_S("error: %s", e.what());
    } catch (...) {
        LOG_DEBUG_S("Unknown exception during JSON parsing");
    }
    return false;
}

// Bind File会话协商Open ACK报文
void PackBindFileSessionHandshakeOpenAck(const FileChannelOpenHandshakeAck &bfshoa, std::vector<uint8_t> &data)
{
    try {
        nlohmann::json j;
        j["MY_CHANNEL_ID"] = bfshoa.MY_CHANNEL_ID;
        j["P2P_PORT"] = bfshoa.P2P_PORT;
        j["MY_IP"] = bfshoa.MY_IP;
        j["CODE"] = bfshoa.CODE;
        j["PKG_NAME"] = bfshoa.PKG_NAME;
        j["BUSINESS_TYPE"] = bfshoa.BUSINESS_TYPE;
        j["STREAM_TYPE"] = bfshoa.STREAM_TYPE;
        j["API_VERSION"] = bfshoa.API_VERSION;
        j["TRANS_CAPABILITY"] = bfshoa.TRANS_CAPABILITY;
        
        std::string json_str = j.dump();
        std::vector<uint8_t> rspPayload(json_str.begin(), json_str.end() + 1);
        std::vector<uint8_t> rspRandomKey;
        rspRandomKey.resize(12);
        RAND_bytes(rspRandomKey.data(), 12);
        ShareManager::shared().EncryptWithAESGCM(rspPayload, rspRandomKey, data);
        data.insert(data.begin(), rspRandomKey.begin(), rspRandomKey.end());
    } catch (const nlohmann::json::exception& e) {
        LOG_DEBUG_S("JSON parsing error: %s", e.what());
    } catch (const std::exception& e) {
        LOG_DEBUG_S("error: %s", e.what());
    } catch (...) {
        LOG_DEBUG_S("Unknown exception during JSON parsing");
    }
}

bool ParseBindFileSessionHandshakeOpenAck(nlohmann::json &j, FileChannelOpenHandshakeAck &bfshoa)
{
    try {
        bfshoa.MY_CHANNEL_ID = j.at("MY_CHANNEL_ID").get<uint8_t>();
        bfshoa.P2P_PORT = j.at("P2P_PORT").get<uint32_t>();
        bfshoa.MY_IP = j.at("MY_IP").get<std::string>();
        bfshoa.CODE = j.at("CODE").get<uint16_t>();
        bfshoa.PKG_NAME = j.at("PKG_NAME").get<std::string>();
        bfshoa.BUSINESS_TYPE = j.at("BUSINESS_TYPE").get<uint8_t>();
        bfshoa.STREAM_TYPE = j.at("STREAM_TYPE").get<uint8_t>();
        bfshoa.API_VERSION = j.at("API_VERSION").get<uint8_t>();
        bfshoa.TRANS_CAPABILITY = j.at("TRANS_CAPABILITY").get<uint8_t>();
        return true;
    } catch (const nlohmann::json::exception& e) {
        LOG_DEBUG_S("JSON parsing error: %s", e.what());
    } catch (const std::exception& e) {
        LOG_DEBUG_S("error: %s", e.what());
    } catch (...) {
        LOG_DEBUG_S("Unknown exception during JSON parsing");
    }
    return false;
}

// Bind File会话协商Close报文
void PackBindFileSessionHandshakeClose(const FileChannelCloseHandshake &bfshc, std::vector<uint8_t> &data)
{
    try {
        std::vector<uint8_t> dFileSessionKey;
        ShareManager::shared().GetDFileSessionKey(dFileSessionKey);
        std::vector<uint8_t> base64SessionKey;
        base64SessionKey.resize(64 + 1);
        SoftBusBase64Encode(base64SessionKey.data(), base64SessionKey.size(), dFileSessionKey.data(), dFileSessionKey.size());
        
        nlohmann::json j;
        j["PEER_CHANNEL_ID"] = bfshc.PEER_CHANNEL_ID;
        j["MY_CHANNEL_ID"] = bfshc.MY_CHANNEL_ID;
        j["MY_IP"] = std::string(bfshc.MY_IP);
        j["CODE"] = bfshc.CODE;
        j["API_VERSION"] = bfshc.API_VERSION;
        j["BUSINESS_TYPE"] = bfshc.BUSINESS_TYPE;
        j["STREAM_TYPE"] = bfshc.STREAM_TYPE;
        j["CHANNEL_TYPE"] = bfshc.CHANNEL_TYPE;
        j["UDP_CONN_TYPE"] = bfshc.UDP_CONN_TYPE;
        j["BUS_NAME"] = bfshc.BUS_NAME;
        j["CLIENT_BUS_NAME"] = bfshc.CLIENT_BUS_NAME;
        j["PKG_NAME"] = bfshc.PKG_NAME;
        j["TRANS_CAPABILITY"] = bfshc.TRANS_CAPABILITY;
        j["SESSION_KEY"] = std::string((char*)base64SessionKey.data());
        
        std::string json_str = j.dump();
        std::vector<uint8_t> rspPayload(json_str.begin(), json_str.end() + 1);
        std::vector<uint8_t> rspRandomKey;
        rspRandomKey.resize(12);
        RAND_bytes(rspRandomKey.data(), 12);
        ShareManager::shared().EncryptWithAESGCM(rspPayload, rspRandomKey, data);
        data.insert(data.begin(), rspRandomKey.begin(), rspRandomKey.end());
    } catch (const nlohmann::json::exception& e) {
        LOG_DEBUG_S("JSON parsing error: %s", e.what());
    } catch (const std::exception& e) {
        LOG_DEBUG_S("error: %s", e.what());
    } catch (...) {
        LOG_DEBUG_S("Unknown exception during JSON parsing");
    }
}

bool ParseBindFileSessionHandshakeClose(nlohmann::json &j, FileChannelCloseHandshake &bfshc)
{
    try {
        bfshc.PEER_CHANNEL_ID = j.at("PEER_CHANNEL_ID").get<uint8_t>();
        bfshc.MY_CHANNEL_ID = j.at("MY_CHANNEL_ID").get<uint8_t>();
        
        bfshc.MY_IP = j.at("MY_IP").get<std::string>();
        bfshc.CODE = j.at("CODE").get<uint16_t>();
        bfshc.API_VERSION = j.at("API_VERSION").get<uint8_t>();
        bfshc.BUSINESS_TYPE = j.at("BUSINESS_TYPE").get<uint8_t>();
        bfshc.STREAM_TYPE = j.at("STREAM_TYPE").get<uint8_t>();

        if (j.contains("CHANNEL_TYPE")) {
            bfshc.CHANNEL_TYPE = j.at("CHANNEL_TYPE").get<uint8_t>();
        }

        bfshc.UDP_CONN_TYPE = j.at("UDP_CONN_TYPE").get<uint32_t>();
        
        bfshc.BUS_NAME = j.at("BUS_NAME").get<std::string>();
        
        bfshc.CLIENT_BUS_NAME = j.at("CLIENT_BUS_NAME").get<std::string>();
        
        bfshc.PKG_NAME = j.at("PKG_NAME").get<std::string>();
        bfshc.TRANS_CAPABILITY = j.at("TRANS_CAPABILITY").get<uint8_t>();
        return true;
    } catch (const nlohmann::json::exception& e) {
        LOG_DEBUG_S("JSON parsing error: %s", e.what());
    } catch (const std::exception& e) {
        LOG_DEBUG_S("error: %s", e.what());
    } catch (...) {
        LOG_DEBUG_S("Unknown exception during JSON parsing");
    }
    return false;
}

// VerifyP2p/BindByte/BindFile 异常报文
void PacketConnExcept(const PayloadExcept &pe, std::vector<uint8_t> &data)
{
    try {
        nlohmann::json j;
        j["CODE"] = pe.CODE;
        j["ERR_CODE"] = pe.ERR_CODE;
        j["ERR_DESC"] = std::string(pe.ERR_DESC);
        
        std::string json_str = j.dump();
        std::vector<uint8_t> rspPayload(json_str.begin(), json_str.end() + 1);
        std::vector<uint8_t> rspRandomKey;
        rspRandomKey.resize(12);
        RAND_bytes(rspRandomKey.data(), 12);
        ShareManager::shared().EncryptWithAESGCM(rspPayload, rspRandomKey, data);
        data.insert(data.begin(), rspRandomKey.begin(), rspRandomKey.end());
    } catch (const nlohmann::json::exception& e) {
        LOG_DEBUG_S("JSON parsing error: %s", e.what());
    } catch (const std::exception& e) {
        LOG_DEBUG_S("error: %s", e.what());
    } catch (...) {
        LOG_DEBUG_S("Unknown exception during JSON parsing");
    }
}

bool ParseConnExcept(const std::vector<uint8_t> &packet, PayloadExcept &pe)
{
    try {
        std::vector<uint8_t> payload;
        std::vector<uint8_t> salt;
        salt.insert(salt.end(), packet.begin(), packet.begin() + 12);
        payload.insert(payload.end(), packet.begin() + 12, packet.end());
        
        std::vector<uint8_t> jsonData;
        ShareManager::shared().DecryptWithAESGCM(payload, salt, jsonData);

        uint8_t *json_start = jsonData.data();
        size_t json_len = jsonData.size();
        
        std::string json_str(reinterpret_cast<char*>(json_start), json_len);
        nlohmann::json j = nlohmann::json::parse(json_str);
        
        pe.CODE = j.at("CODE").get<uint16_t>();
        pe.ERR_CODE = j.at("ERR_CODE").get<int32_t>();
        
        pe.ERR_DESC = j.at("ERR_DESC").get<std::string>();
        return true;
    } catch (const nlohmann::json::exception& e) {
        LOG_DEBUG_S("JSON parsing error: %s", e.what());
    } catch (const std::exception& e) {
        LOG_DEBUG_S("error: %s", e.what());
    } catch (...) {
        LOG_DEBUG_S("Unknown exception during JSON parsing");
    }
    return false;
}

bool ParseTdcHeader(std::vector<uint8_t> &packet, TdcPacketHead &hdr)
{
    memcpy_s(&hdr, sizeof(hdr), packet.data(), sizeof(hdr));
    if (packet.size() != hdr.dataLen + sizeof(hdr)) {
        LOG_ERROR_S("invalid length of tdc header, discard it");
        return false;
    }
    packet.erase(packet.begin(), packet.begin() + sizeof(hdr));
    return true;
}

void PackTdcHeader(const std::vector<uint8_t> &payload, TdcPacketHead &hdr, std::vector<uint8_t> &packet)
{
    packet.resize(sizeof(hdr));
    memcpy(packet.data(), &hdr, sizeof(hdr));
    packet.insert(packet.end(), payload.begin(), payload.end());
}

void PackCloseProxyChannelReq(const AuthChannel &channel, std::vector<uint8_t> &data)
{
    try {
        nlohmann::json j;
        j["IDENTITY"] = std::string("");
        
        // 序列化 JSON 为字符串
        std::string json_str = j.dump();
        data.resize(json_str.length() + 1);
        memcpy(data.data(), json_str.c_str(), json_str.length());
        
        std::vector<uint8_t> temp;
        ProxyMessageHead proxyHdr;
        proxyHdr.TYPE = 0x13;
        proxyHdr.cipher = 0x10;
        proxyHdr.myId = channel.myId;
        proxyHdr.peerId = channel.peerId;
        proxyHdr.reserved = 0;
        PackProxyHeader(data, proxyHdr, temp);

        std::vector<uint8_t> temp2;
        ConnPktHead connHdr;
        connHdr.magic = MAGIC_NUMBER;
        connHdr.module = MODULE_PROXY_CHANNEL;
        connHdr.seq = g_SeqConnPacket++;
        connHdr.flag = 0x03;
        connHdr.len = static_cast<uint32_t>(temp.size());
        PackConnHeader(temp, connHdr, temp2);
        
        BleTransHeader bleHdr;
        bleHdr.seq = g_SeqBlePacket++;
        bleHdr.size = static_cast<uint32_t>(temp2.size());
        bleHdr.offset = 0;
        bleHdr.total = static_cast<uint32_t>(temp2.size());
        PackBleHeader(temp2, bleHdr, data);
    } catch (const nlohmann::json::exception& e) {
        LOG_DEBUG_S("JSON parsing error: %s", e.what());
    } catch (const std::exception& e) {
        LOG_DEBUG_S("error: %s", e.what());
    } catch (...) {
        LOG_DEBUG_S("Unknown exception during JSON parsing");
    }
}

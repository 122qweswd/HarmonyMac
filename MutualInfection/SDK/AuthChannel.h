#ifndef AUTH_CHANNEL_H
#define AUTH_CHANNEL_H

#include <string>
#include <stdint.h>
#include <vector>
#include "json.hpp"

#define AUTH_CHANNEL_REQ    0
#define AUTH_CHANNEL_REPLY  1

#define DATA_TYPE_CONNECTION 0xFFFF0004

#define AUTH_PKT_HEAD_LEN 24

typedef enum {
    MODULE_TRUST_ENGINE = 1,
    MODULE_HICHAIN = 2,
    MODULE_AUTH_SDK = 3,
    MODULE_AUTH_CONNECTION = 5,
    MODULE_AUTH_CANCEL = 6,
    MODULE_MESSAGE_SERVICE = 8,
    MODULE_AUTH_CHANNEL = 8,
    MODULE_AUTH_MSG = 9,
    MODULE_BLUETOOTH_MANAGER = 9,
    MODULE_CONNECTION = 11,
    MODULE_DIRECT_CHANNEL = 12,
    MODULE_PROXY_CHANNEL = 13,
    MODULE_DEVICE_AUTH = 14,
    MODULE_P2P_LINK = 15,
    MODULE_P2P_LISTEN = 16,
    MODULE_UDP_INFO = 17,
    MODULE_P2P_NETWORKING_SYNC = 18,
    MODULE_TIME_SYNC = 19,
    MODULE_PKG_VERIFY = 20,
    MODULE_META_AUTH = 21,
    MODULE_P2P_NEGO = 22,
    MODULE_AUTH_SYNC_INFO = 23,
    MODULE_PTK_VERIFY = 24,
    MODULE_SESSION_AUTH = 25,
    MODULE_SESSION_KEY_AUTH = 26,
    MODULE_SLE_AUTH_CMD = 27,
    MODULE_APPLY_KEY_CONNECTION = 28,
    MODULE_LANE_SELECT = 29,
    MODULE_VIRTUAL_LINK = 30,
    MODULE_BLE_NET = 100,
    MODULE_BLE_CONN = 101,
    MODULE_BLE_GENERAL = 102,
    MODULE_PAGING_CONN = 103,
    MODULE_NIP_BR_CHANNEL = 201,
    MODULE_OLD_NEARBY = 300,
} ConnModule;

typedef struct stConnPktHead{
    uint32_t magic;
    int32_t module;
    int64_t seq;
    int32_t flag;
    uint32_t len;
} ConnPktHead;

typedef struct stNetCtrlMsgHead {
    uint32_t type;
} NetCtrlMsgHead;

typedef struct stBleTransHeader{
    uint32_t seq;
    uint32_t size;
    uint32_t offset;
    uint32_t total;
} BleTransHeader;

typedef struct stProxyMessageHead{
    uint8_t TYPE; // MsgType
    uint8_t cipher;
    int16_t myId;
    int16_t peerId;
    int16_t reserved;
}ProxyMessageHead;

typedef struct stAuthDataHead{
   uint32_t dataType;
   int32_t module;
   int64_t seq;
   int32_t flag;
   uint32_t len;
} AuthHead;

typedef struct stTdcPacketHead{
    uint32_t magicNumber;
    uint32_t module;
    uint64_t seq;
    uint32_t flags;
    uint32_t dataLen;
} TdcPacketHead;

// payload json
typedef struct stPayloadBasicInfo{
    std::string devid;  // maxium: 64 bytes
    int8_t TYPE;
    uint8_t deviceType; // optional, skipped
    int8_t FEATURE_SUPPORT;
} PayloadBasicInfo;

typedef struct stRefNumSync {
    uint8_t KEY_METHOD;
    int8_t KEY_DELTA;
    uint8_t KEY_REF_NUM;
    uint8_t KEY_CHALLENGE; // optional, skipped
} RefNumSync;

typedef struct stNakedChannelHandshake {
    uint8_t TYPE;
    char IDENTITY[32+1];
    char DEVICE_ID[64+1];
    char SRC_BUS_NAME[255+1];
    char DST_BUS_NAME[255+1];
    uint8_t API_VERSION;
    uint32_t MTU_SIZE;
    uint8_t TRANS_CAPABILITY;
    uint8_t HAS_PRIORITY;
    char REQUEST_ID[64+1];
    char PKG_NAME[32+1];
} NakedChannelHandshake;

typedef struct stNakedChannelHandshakeAck {
    std::string IDENTITY;
    std::string DEVICE_ID;
    uint8_t TRANS_CAPABILITY;
    uint32_t MTU_SIZE;
    std::string PKG_NAME;
} NakedChannelHandshakeAck;

typedef struct stNakedChannelHandshakeExcept {
    int32_t ERR_CODE;
} NakedChannelHandshakeExcept;

typedef struct stNakedChannelHandshakeWlan {
    uint8_t CODE;
    std::string DEVICE_ID;
    std::string PEER_NETWORK_ID;
    std::string PKG_NAME;
    std::string SRC_BUS_NAME;
    std::string DST_BUS_NAME;
    std::string REQ_ID;
    uint8_t API_VERSION;
    uint32_t MTU_SIZE;
    uint8_t ROUTE_TYPE;
} NakedChannelHandshakeWlan;

typedef struct stVerifyP2p {
    uint16_t CODE;
    std::string P2P_IP;
    uint32_t P2P_PORT;
    uint8_t PROTOCOL_TYPE;
} VerifyP2p;

typedef struct stPayloadExcept {
    uint16_t CODE;
    int32_t ERR_CODE;
    std::string ERR_DESC;
} PayloadExcept;

typedef struct stBytesChannelHandshake {
    uint16_t CODE;
    uint8_t API_VERSION;
    std::string BUS_NAME;
    uint32_t MTU_SIZE;
    uint8_t TRANS_CAPABILITY;
    std::string PKG_NAME;
    std::string CLIENT_BUS_NAME;
    uint8_t ROUTE_TYPE;
    std::string DEVICE_ID;
    uint8_t BUSINESS_TYPE;
    uint8_t TRANS_FLAGS;
    std::string SESSION_KEY;
} BytesChannelHandshake;

typedef struct stBytesChannelHandshakeAck {
    uint16_t CODE;
    uint8_t API_VERSION;
    std::string DEVICE_ID;
    uint8_t TRANS_CAPABILITY;
    uint32_t MTU_SIZE;
    std::string PKG_NAME;
} BytesChannelHandshakeAck;

typedef struct stFileChannelOpenHandshake {
    uint8_t MY_CHANNEL_ID;
    std::string MY_IP;
    std::string DEVICE_ID;
    uint16_t CODE;
    uint8_t API_VERSION;
    uint8_t BUSINESS_TYPE;
    int8_t STREAM_TYPE;
    uint8_t CHANNEL_TYPE;
    uint32_t UDP_CONN_TYPE;
    std::string BUS_NAME;
    std::string CLIENT_BUS_NAME;
    std::string PKG_NAME;
    uint8_t TRANS_CAPABILITY;
    std::vector<uint8_t> SESSION_KEY;
} FileChannelOpenHandshake;

typedef struct stFileChannelOpenHandshakeAck {
    uint8_t MY_CHANNEL_ID;
    uint32_t P2P_PORT;
    std::string MY_IP;
    uint16_t CODE;
    std::string PKG_NAME;
    uint8_t BUSINESS_TYPE;
    uint8_t STREAM_TYPE;
    uint8_t API_VERSION;
    uint8_t TRANS_CAPABILITY;
} FileChannelOpenHandshakeAck;

typedef struct stFileChannelCloseHandshake {
    int8_t PEER_CHANNEL_ID;
    int8_t MY_CHANNEL_ID;
    std::string MY_IP;
    uint16_t CODE;
    uint8_t API_VERSION;
    uint8_t BUSINESS_TYPE;
    int8_t STREAM_TYPE;
    uint8_t CHANNEL_TYPE;
    uint32_t UDP_CONN_TYPE;
    std::string BUS_NAME;
    std::string CLIENT_BUS_NAME;
    std::string PKG_NAME;
    uint8_t TRANS_CAPABILITY;
} FileChannelCloseHandshake;

typedef struct stFileChannelCloseHandshakeAck {
    uint16_t CODE;
    std::string PKG_NAME;
    uint8_t BUSINESS_TYPE;
    uint8_t STREAM_TYPE;
    uint8_t API_VERSION;
    uint8_t TRANS_CAPABILITY;
} FileChannelCloseHandshakeAck;

typedef struct stAuthChannel {
//    uint32_t channelId;
    std::string channelId;
    std::string udid;
    uint16_t myId;
    uint16_t peerId;
    bool isSender;
} AuthChannel;

// refactor API
bool IsPartialBLEPacket(const std::vector<uint8_t> &packet);
bool IsConnPacket(const std::vector<uint8_t> &packet);

bool ParseBleHeader(std::vector<uint8_t> &packet, BleTransHeader &hdr);
void PackBleHeader(const std::vector<uint8_t> &packet, BleTransHeader &hdr, std::vector<uint8_t> &payload);

bool ParseNetCtrlHeader(std::vector<uint8_t> &packet, NetCtrlMsgHead &hdr);
void PackNetCtrlHeader(const std::vector<uint8_t> &packet, NetCtrlMsgHead &hdr, std::vector<uint8_t> &payload);

bool ParseConnHeader(std::vector<uint8_t> &packet, ConnPktHead &hdr);
void PackConnHeader(const std::vector<uint8_t> &payload, ConnPktHead &hdr, std::vector<uint8_t> &packet);

bool ParseProxyHeader(std::vector<uint8_t> &packet, ProxyMessageHead &hdr);
void PackProxyHeader(const std::vector<uint8_t> &payload, ProxyMessageHead &hdr, std::vector<uint8_t> &packet);

bool ParseAuthHeader(std::vector<uint8_t> &packet, AuthHead &hdr);
void PackAuthHeader(const std::vector<uint8_t> &payload, AuthHead &hdr, std::vector<uint8_t> &packet);

/* basic info报文格式: BleTransHeader +NetCtrlMsgHead +<payload> */
void PackBasicInfoExchange(const PayloadBasicInfo &basicInfo, std::vector<uint8_t> &data);
bool ParseBasicInfoExchange(const std::vector<uint8_t> &packet, PayloadBasicInfo &basicInfo);

/* 引用计数同步请求报文格式: BleTransHeader +ConnPktHead +<payload> */
void PackRefNumSync(const RefNumSync &rns, std::vector<uint8_t> &data);
bool ParseRefNumSync(const std::vector<uint8_t> &packet, RefNumSync &rns);

/* 裸通道会话协商报文格式：ProxyMessageHead +<payload> */
void PackNakedChannelHandshakeReq(const NakedChannelHandshake &ncsh, uint16_t myId, std::vector<uint8_t> &data);
bool ParseNakedChannelHandshakeReq(const std::vector<uint8_t> &packet, NakedChannelHandshake &ncsh);
void PackNakedChannelHandshakeAck(const NakedChannelHandshakeAck &ncsha, const ProxyMessageHead &hdr, std::vector<uint8_t> &data);
bool ParseNakedChannelHandshakeAck(const std::vector<uint8_t> &packet, NakedChannelHandshakeAck &ncsha);
void PackNakedChannelHandshakeExcept(const NakedChannelHandshakeExcept &ncshe, const ProxyMessageHead &hdr, std::vector<uint8_t> &data);
bool ParseNakedChannelHandshakeExcept(const std::vector<uint8_t> &packet, NakedChannelHandshakeExcept &ncshe);

/* 裸通道(WLAN)会话协商报文 */
void PackNakedChannelHandshakeWlan(const NakedChannelHandshakeWlan &ncsh, std::vector<uint8_t> &data);
bool ParseNakedChannelHandshakeWlan(const std::vector<uint8_t> &packet, NakedChannelHandshakeWlan &ncsh);

void PackShareHeader(const AuthChannel &channel, std::vector<uint8_t> &packet);
void PackMetaNodeHeader(std::vector<uint8_t> &packet, AuthHead &hdr, bool isBleChannel);

bool ParseChannelPacket(const std::vector<uint8_t> &packet, nlohmann::json &jsPacket);
/* VerifyP2p报文报文格式：AuthHead +<payload> */
void PacketVerifyP2p(const VerifyP2p &vp, std::vector<uint8_t> &data);
bool ParseVerifyP2p(nlohmann::json &j, VerifyP2p &vp);

/* Bind Bytes会话协商报文报文格式：TdcPacketHead +<payload> */
void PackBindBytesSessionHandshake(const BytesChannelHandshake &bbsh, std::vector<uint8_t> &data);
bool ParseBindBytesSessionHandshake(const std::vector<uint8_t> &packet, BytesChannelHandshake &bbsh);
/* Bind Bytes会话协商ACK报文报文格式：TdcPacketHead +<payload> */
void PackBindBytesSessionHandshakeAck(const BytesChannelHandshakeAck &bbsha, std::vector<uint8_t> &data);
bool ParseBindBytesSessionHandshakeAck(const std::vector<uint8_t> &packet, BytesChannelHandshakeAck &bbsha);

/* Bind File会话协商报文(Open)报文格式：AuthHead +<payload> */
void PackBindFileSessionHandshakeOpen(const FileChannelOpenHandshake &bfsho, std::vector<uint8_t> &data);
bool ParseBindFileSessionHandshakeOpen(nlohmann::json &j, FileChannelOpenHandshake &bfsho);
/* Bind File会话协商ACK报文(Open)报文格式：AuthHead +<payload> */
void PackBindFileSessionHandshakeOpenAck(const FileChannelOpenHandshakeAck &bfshoa, std::vector<uint8_t> &data);
bool ParseBindFileSessionHandshakeOpenAck(nlohmann::json &j, FileChannelOpenHandshakeAck &bfshoa);

/* Bind File会话协商报文(CLOSE) AuthHead +<payload> */
void PackBindFileSessionHandshakeClose(const FileChannelCloseHandshake &bfshc, std::vector<uint8_t> &data);
bool ParseBindFileSessionHandshakeClose(nlohmann::json &j, FileChannelCloseHandshake &bfshc);
/* Bind File会话协商ACK报文(CLOSE)报文格式：AuthHead +<payload> ß*/
void PackBindFileSessionHandshakeCloseAck(const FileChannelCloseHandshakeAck &bfshca, std::vector<uint8_t> &data);
bool ParseBindFileSessionHandshakeCloseAck(nlohmann::json &j, FileChannelCloseHandshakeAck &bfshca);

// VerifyP2p/BindByte/BindFile 异常报文
void PacketConnExcept(const PayloadExcept &pe, std::vector<uint8_t> &data);
bool ParseConnExcept(const std::vector<uint8_t> &packet, PayloadExcept &pe);


bool IsTdcHeader(const std::vector<uint8_t> &packet);
bool IsTdcDataHeader(const std::vector<uint8_t> &packet);
bool ParseTdcHeader(std::vector<uint8_t> &packet, TdcPacketHead &hdr);
void PackTdcHeader(const std::vector<uint8_t> &payload, TdcPacketHead &hdr, std::vector<uint8_t> &packet);

void PackCloseProxyChannelReq(const AuthChannel &channel, std::vector<uint8_t> &data);
#endif // AUTH_CHANNEL_H

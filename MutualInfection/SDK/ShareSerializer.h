#ifndef __BLE_CONNCET_BUSINESS_CTRL_PROTOL_H__
#define __BLE_CONNCET_BUSINESS_CTRL_PROTOL_H__

#include <string>
#include <vector>

#define COMMON_TLV_SIZE 3

typedef struct NetworkInfo {
    std::string apSsid;
    std::string apIp;
    std::string staSsid;
    std::string staIp;
    std::string goSsid;
    std::string goIp;
} NetworkInfo_t;

typedef struct ConnectInfo {
    std::string peerSSID;
    std::string peerPSK;
    std::string peerIP;
    std::string timeout;
} ConnectInfo_t;

typedef struct CommonTwoTlvsInfo {
    std::string strValue1;
    std::string strValue2;
} CommonTwoTlvsInfo_t;

typedef struct CommonThreeTlvsInfo {
    std::string strVals[3];
} CommonThreeTlvsInfo_t;

typedef struct CommonOneTlvInfo {
    std::string strValue;
} CommonOneTlvInfo_t;

typedef struct CommonTlvInfo {
    std::string strVals[COMMON_TLV_SIZE];
} CommonTlvInfo_t;

typedef struct {
  std::string sendType;
  std::string senderName;
  std::string itemCount;
  std::string totalSize;
  std::string folderCount;
  std::string fileCount;
  std::string previewSummary;
} FileShareInfo;

// 文件简要信息
void PackFileShareInfoPayload(FileShareInfo &fileShareInfo, std::vector<uint8_t> &out_payload);
bool ParseFileShareInfoPayload(std::vector<uint8_t> &data, FileShareInfo &fileShareInfo);

// 用户响应请求
void PackUserAckPayload(int type, std::vector<uint8_t> &out_payload);
bool ParseUserAckPayload(std::vector<uint8_t> &data, bool &is_confirm);

// 网络信息请求和网络信息回应用的同一个结构体：NetworkInfo_t
void PackDirectConnectReq(const NetworkInfo_t &ni, std::vector<uint8_t> &packet);
void PackDirectConnectAck(const NetworkInfo_t &ni, std::vector<uint8_t> &packet);
bool ParseDirectConnect(uint8_t *data, size_t datalen, NetworkInfo_t &ni);

// 请求连接
void PackRequestConnect(const CommonTwoTlvsInfo_t &rci, std::vector<uint8_t> &packet);
bool ParseRequestConnect(uint8_t *data, uint32_t datalen, ConnectInfo &rci);

// 连接成功，ip 地址交换
void PackBleConnectOk(const std::string &ip, const std::string &ipv6, std::vector<uint8_t> &packet);
bool ParseBleConnectOk(uint8_t *data, uint32_t datalen, CommonTwoTlvsInfo_t &ci);

void PackFilePreview(const CommonTwoTlvsInfo_t &ci, std::vector<uint8_t> &packet);
bool ParseFilePreview(uint8_t *data, uint32_t datalen, CommonTlvInfo_t &ci);

void PackFilePreviewAck(const CommonOneTlvInfo_t &ci, std::vector<uint8_t> &packet);
bool ParseFilePreviewAck(uint8_t *data, uint32_t datalen, CommonOneTlvInfo_t &ci);

bool ParseRecvPercentPayload(const std::vector<uint8_t> &data, double &percent);
void PackRecvPercentPayload(double percent, std::vector<uint8_t> &packet);

bool ParseAlreadyRecv(const std::vector<uint8_t> &data);
void PackAlreadyRecv(std::vector<uint8_t> &packet);

bool ParseTransError(const std::vector<uint8_t> &data);
void PackTransError(std::vector<uint8_t> &packet);

bool ParseNotEnoughSpace(const std::vector<uint8_t> &data);
void PackNotEnoughSpace(std::vector<uint8_t> &packet);
void PackHotspotNoti(std::vector<uint8_t> &packet);

bool ParseAvatarData(const std::vector<uint8_t> &data, std::string &avatar);

void PackKeepAlive(std::vector<uint8_t> &packet);

#endif // __BLE_CONNCET_BUSINESS_CTRL_PROTOL_H__

//
//  Common.h
//  MutualInfection
//
//  Created by mac on 2025/9/13.
//
#ifndef __COMMON_H__
#define __COMMON_H__

#include <string>
#include <vector>

#define DC_DATA_HEAD_SIZE 16
//#define DC_DATA_HEAD_SIZE sizeof(TdcDataPacketHead)

#define HUKS_AES_GCM_KEY_LEN 256
#define GCM_IV_LEN 12
#define AAD_LEN 16
#define HKDF_BYTES_LEN 32

#define GCM_KEY_BITS_LEN_128 128
#define GCM_KEY_BITS_LEN_256 256
#define KEY_BITS_UNIT 8

#define BLE_BROADCAST_IV_LEN 16

#define BASE64_SESSION_KEY_LEN 45

#define SESSION_KEY_LENGTH 32

#define TAG_LEN 16
#define SHORT_TAG_LEN 8
#define OVERHEAD_LEN (GCM_IV_LEN + TAG_LEN)

#define MAGIC_NUMBER 0xBABEFACE

typedef struct {
    uint32_t magicNumber;
    int32_t seq;
    uint32_t flags;
    uint32_t dataLen;
} __attribute__((packed)) TdcDataPacketHead;

typedef struct {
    const char *in;
    uint32_t inLen;
    char *out;
    uint32_t *outLen;
} EncrptyInfo;

bool GetLocalWifiIPAddr(std::string& ip, std::string& netmask, std::string& broadcast_ip,
                       std::string& ipv6, std::string& ipv6_prefix, std::string& mac_addr, int retry = 0);

uint16_t GetRandomPort();
int GetRandomPortAndSockfd(uint16_t &port, int &sockfd);

int32_t SoftBusBase64Encode(unsigned char *dst, size_t dlen, const unsigned char *src, size_t slen);
int32_t SoftBusBase64Decode(unsigned char *dst, size_t dlen, const unsigned char *src, size_t slen);

std::string GetDeviceId(void);
std::string GetIPAddress();
void SetIPAddresss(std::string ipAddressIn);

int32_t TransTdcEncryptWithSeq(const char *sessionKey, int32_t seqNum, EncrptyInfo *info);
int32_t TransTdcUnPackData(const char *sessionKey, char *plain, uint32_t *plainLen, const std::vector<uint8_t> &in);

int32_t SaveFile(const char *filename, const uint8_t *content, size_t size);

int32_t TransTdcPackData(const char *sessionKey, const std::vector<uint8_t> payload, std::vector<uint8_t> &packet);

std::string byte2hexstr(const uint8_t* data, size_t length, bool uppercase = false, const std::string& separator = "");

std::vector<uint8_t> HexString2Bytes(const std::string& hex);

void BytesToHExString(char *outBuff, uint32_t outBufflen, const unsigned char *inBuff, uint32_t inLen);

bool IsInSameNetwork(const std::string &localIP, const std::string &netmask, const std::string& serverIP);

bool isMediaUTI(const std::string& utiString);

std::string GetGatewayIp(const std::string &ip);
long long GetFreeDiskSpace();

std::string AnonymizeIP(const std::string ip);
std::string AnonymizeIP(const char *ip);
std::string AnonymizeString(const std::string input);
std::string AnonymizeString(const char *input);
#endif

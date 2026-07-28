//
//  Common.mm
//  MutualInfection
//
//  Created by mac on 2025/9/13.
//
#include "Common.h"

#include <string.h>
#include <vector>
#include <sstream>
#include <iomanip>

#include <sys/socket.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <net/if.h>
#include <sys/ioctl.h>
#include <net/if_dl.h>

#include <openssl/evp.h>
#include <openssl/hmac.h>
#include <openssl/kdf.h>
#include <openssl/rand.h>

#include <unistd.h>
#include <errno.h>
#include <pthread.h>

#include "ShareManager.h"
#include "LogHelper.h"

#import <Foundation/Foundation.h>
//#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <CoreServices/CoreServices.h>
#if TARGET_OS_MAC
#import <CoreWLAN/CoreWLAN.h>
#endif

#define RETRY_TIMES_MAX 3

#define EVP_AES_128_KEYLEN 16
#define EVP_AES_256_KEYLEN 32

#define OPENSSL_EVP_PADDING_FUNC_OPEN  (1)
#define OPENSSL_EVP_PADDING_FUNC_CLOSE (0)

enum {
    FLAG_BYTES = 0,
    FLAG_ACK = 1,
    FLAG_MESSAGE = 2,
    FILE_FIRST_FRAME = 3,
    FILE_ONGOINE_FRAME = 4,
    FILE_LAST_FRAME = 5,
    FILE_ONLYONE_FRAME = 6,
    FILE_ALLFILE_SENT = 7,
    FLAG_ASYNC_MESSAGE = 8,
    FLAG_SET_LOW_LATENCY = 9
};

static constexpr std::array<char, 16> hex_chars_lower = {
    '0', '1', '2', '3', '4', '5', '6', '7',
    '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'
};

static constexpr std::array<char, 16> hex_chars_upper = {
    '0', '1', '2', '3', '4', '5', '6', '7',
    '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'
};

typedef struct {
    uint32_t keyLen;
    unsigned char key[SESSION_KEY_LENGTH];
    unsigned char iv[GCM_IV_LEN];
} AesGcmCipherKey;

static pthread_mutex_t g_randomLock;

static EVP_CIPHER *GetGcmAlgorithmByKeyLen(uint32_t keyLen)
{
    switch (keyLen) {
        case EVP_AES_128_KEYLEN:
            return (EVP_CIPHER *)EVP_aes_128_gcm();
        case EVP_AES_256_KEYLEN:
            return (EVP_CIPHER *)EVP_aes_256_gcm();
        default:
            return NULL;
    }
    return NULL;
}

static int32_t OpensslEvpInit(EVP_CIPHER_CTX **ctx, uint32_t keyLen, bool mode)
{
    EVP_CIPHER *cipher = GetGcmAlgorithmByKeyLen(keyLen);
    if (cipher == NULL) {
        LOG_DEBUG_S("get cipher fail.");
        return 1;
    }
    int32_t ret;
    *ctx = EVP_CIPHER_CTX_new();
    if (*ctx == NULL) {
        return 1;
    }
    EVP_CIPHER_CTX_set_padding(*ctx, OPENSSL_EVP_PADDING_FUNC_OPEN);
    if (mode == true) {
        ret = EVP_EncryptInit_ex(*ctx, cipher, NULL, NULL, NULL);
        if (ret != 1) {
            LOG_DEBUG_S("EVP_EncryptInit_ex fail.");
            EVP_CIPHER_CTX_free(*ctx);
            return 1;
        }
    } else {
        ret = EVP_DecryptInit_ex(*ctx, cipher, NULL, NULL, NULL);
        if (ret != 1) {
            LOG_DEBUG_S("EVP_DecryptInit_ex fail.");
            EVP_CIPHER_CTX_free(*ctx);
            return 1;
        }
    }
    ret = EVP_CIPHER_CTX_ctrl(*ctx, EVP_CTRL_GCM_SET_IVLEN, GCM_IV_LEN, NULL);
    if (ret != 1) {
        LOG_DEBUG_S("Set iv len fail.");
        EVP_CIPHER_CTX_free(*ctx);
        return 1;
    }
    return 0;
}

static int32_t SslAesGcmDecrypt(const AesGcmCipherKey *cipherkey, const unsigned char *cipherText,
    uint32_t cipherTextSize, unsigned char *plain, uint32_t plainLen)
{
    if ((cipherkey == NULL) || (cipherText == NULL) || (cipherTextSize <= OVERHEAD_LEN) || plain == NULL ||
        (plainLen < cipherTextSize - OVERHEAD_LEN)) {
        LOG_DEBUG_S("Decrypt invalid para.");
        return 1;
    }

    int32_t outLen = 0;
    EVP_CIPHER_CTX *ctx = NULL;
    int32_t ret = OpensslEvpInit(&ctx, cipherkey->keyLen, false);
    if (ret != 0) {
        LOG_DEBUG_S("OpensslEvpInit fail.");
        return 1;
    }
    ret = EVP_DecryptInit_ex(ctx, NULL, NULL, cipherkey->key, cipherkey->iv);
    if (ret != 1) {
        LOG_DEBUG_S("EVP_EncryptInit_ex fail.");
        goto EXIT;
    }
    ret = EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, TAG_LEN, (void *)(cipherText + (cipherTextSize - TAG_LEN)));
    if (ret != 1) {
        LOG_DEBUG_S("EVP_DecryptUpdate fail.");
        goto EXIT;
    }
    ret = EVP_DecryptUpdate(ctx, plain, (int32_t *)&plainLen, cipherText + GCM_IV_LEN, cipherTextSize - OVERHEAD_LEN);
    if (ret != 1) {
        LOG_DEBUG_S("EVP_DecryptUpdate fail.");
        goto EXIT;
    }
    if (plainLen > INT32_MAX) {
        LOG_DEBUG_S("PlainLen convert overflow.");
        goto EXIT;
    }
    outLen += (int32_t)plainLen;
    ret = EVP_DecryptFinal_ex(ctx, plain + plainLen, (int32_t *)&plainLen);
    if (ret != 1) {
        LOG_DEBUG_S("EVP_DecryptFinal_ex fail.");
        goto EXIT;
    }
    if ((int32_t)plainLen > INT32_MAX - outLen) {
        LOG_DEBUG_S("outLen convert overflow.");
        goto EXIT;
    }
    outLen += (int32_t)plainLen;
    EVP_CIPHER_CTX_free(ctx);
    return outLen;
EXIT:
    EVP_CIPHER_CTX_free(ctx);
    return 0;
}

static bool ParseIPv4(const struct ifaddrs *temp_addr, const std::string &peerIP, std::string &ip, std::string &netmask, std::string &broadcastIP)
{
    if (temp_addr == nullptr) {
        return false;
    }
    if (temp_addr->ifa_addr && temp_addr->ifa_addr->sa_family == AF_INET) {
        struct sockaddr_in *ifa_addr = reinterpret_cast<struct sockaddr_in*>(temp_addr->ifa_addr);
        char ip_str[INET_ADDRSTRLEN];
        char interfaceNetmask[INET_ADDRSTRLEN];
        char broadcast_ip_str[INET_ADDRSTRLEN];
        
        inet_ntop(AF_INET, &(ifa_addr->sin_addr), ip_str, INET_ADDRSTRLEN);
        inet_ntop(AF_INET, &((struct sockaddr_in*)temp_addr->ifa_netmask)->sin_addr, interfaceNetmask, INET_ADDRSTRLEN);
        inet_ntop(AF_INET, &((struct sockaddr_in*)temp_addr->ifa_dstaddr)->sin_addr, broadcast_ip_str, INET_ADDRSTRLEN);
        std::string anoIP = AnonymizeIP(ip_str);
        std::string anoNetmask = AnonymizeIP(interfaceNetmask);
        std::string anoBroadcast = AnonymizeIP(broadcast_ip_str);
        LOG_DEBUG_S("%s IPv4: %s, netmask: %s, broadcast: %s", temp_addr->ifa_name, anoIP.c_str(), anoNetmask.c_str(), anoBroadcast.c_str());
        
        if (peerIP.empty() || IsInSameNetwork(ip_str, interfaceNetmask, peerIP)) {
            std::string temp_ip = ip_str;
            if ((temp_addr->ifa_flags & IFF_UP) == IFF_UP && temp_ip.find("169.254") == std::string::npos) {
                ip = temp_ip;
                netmask = interfaceNetmask;
                broadcastIP = broadcast_ip_str;
                return true;
            }
        }
    }
    return false;
}

static bool ParseIPv6(const struct ifaddrs *temp_addr, std::string &ipv6, std::string &ipv6_prefix)
{
    if (temp_addr == nullptr) {
        return false;
    }
    if (temp_addr->ifa_addr && temp_addr->ifa_addr->sa_family == AF_INET6) {
        struct sockaddr_in6 *ifa_addr6 = reinterpret_cast<struct sockaddr_in6*>(temp_addr->ifa_addr);
        char ipv6_str[INET6_ADDRSTRLEN];
        
        inet_ntop(AF_INET6, &(ifa_addr6->sin6_addr), ipv6_str, INET6_ADDRSTRLEN);
        
        // 排除链路本地地址 (fe80::) 和回环地址 (::1)
        if (strncmp(ipv6_str, "fe80::", 6) != 0 &&
            strcmp(ipv6_str, "::1") != 0) {
            
            // 计算 IPv6 前缀长度
            std::string current_prefix;
            if (temp_addr->ifa_netmask) {
                struct sockaddr_in6 *netmask6 = reinterpret_cast<struct sockaddr_in6*>(temp_addr->ifa_netmask);
                int prefix_length = 0;
                for (int i = 0; i < 16; i++) {
                    unsigned char byte = netmask6->sin6_addr.s6_addr[i];
                    for (int j = 0; j < 8; j++) {
                        if (byte & (1 << (7 - j))) {
                            prefix_length++;
                        } else {
                            // 遇到0就停止计数（连续1的个数）
                            i = 16; // 跳出外层循环
                            j = 8;  // 跳出内层循环
                            break;
                        }
                    }
                }
                current_prefix = std::to_string(prefix_length);
            }
            // LOG_DEBUG_S("%s IPv6: %s/%s", temp_addr->ifa_name, ipv6_str, current_prefix.c_str());
            
            // 将多个IPv6地址用逗号分隔
            if (ipv6.find(ipv6_str) == std::string::npos) {
                if (!ipv6.empty()) {
                    ipv6 += ",";
                    ipv6_prefix += ",";
                }
                ipv6 += ipv6_str;
                ipv6_prefix += current_prefix;
            }
            return true;
        }
    }
    return false;
}

static bool ParseMac(const struct ifaddrs *temp_addr, std::string &mac_addr)
{
    if (temp_addr == nullptr) {
        return false;
    }
    if (temp_addr->ifa_addr && temp_addr->ifa_addr->sa_family == AF_LINK) {
        struct sockaddr_dl* sdl = reinterpret_cast<struct sockaddr_dl*>(temp_addr->ifa_addr);
        if (sdl->sdl_alen == 6) {  // MAC地址长度为6字节
            unsigned char* mac = reinterpret_cast<unsigned char*>(LLADDR(sdl));
            char mac_str[18];
            snprintf(mac_str, sizeof(mac_str), "%02x:%02x:%02x:%02x:%02x:%02x",
                     mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
            mac_addr = mac_str;
            // LOG_DEBUG_S("%s MAC: %s", temp_addr->ifa_name, mac_str);
            return true;
        }
    }
    return false;
}

bool GetLocalWifiIPAddr(std::string& ip, std::string& netmask, std::string& broadcast_ip,
                       std::string& ipv6, std::string& ipv6_prefix, std::string& mac_addr, int retry)
{
    struct ifaddrs *interfaces = nullptr;
    struct ifaddrs *temp_addr = nullptr;
    std::string wifiName = "";
    std::string peerIP = ip;
    
    // 清空输出参数
    ip.clear();
    netmask.clear();
    broadcast_ip.clear();
    ipv6.clear();
    ipv6_prefix.clear();
    mac_addr.clear();
    
    do {
        wifiName = "";
        if (getifaddrs(&interfaces) == 0) {
            temp_addr = interfaces;
            while (temp_addr != nullptr) {
                std::string ifa_name(temp_addr->ifa_name);
                std::string wifiInterfaceName;
#if TARGET_OS_MAC
                CWWiFiClient *wifiClient = [CWWiFiClient sharedWiFiClient];
                CWInterface *wifiInterface = wifiClient.interface;
                NSString *interfaceName = wifiInterface.interfaceName;
                wifiInterfaceName = [interfaceName UTF8String];
#endif
                    if ((!ifa_name.empty() && ifa_name.find("en") == 0) || ifa_name == wifiInterfaceName) {
                    LOG_DEBUG_S("get IP info from ifa_name: %s", ifa_name.c_str());
                    // 处理 IPv4 地址
                    if (ParseIPv4(temp_addr, peerIP, ip, netmask, broadcast_ip)) {
                        wifiName = ifa_name;
#if TARGET_OS_MAC
                        wifiName = wifiInterfaceName;
#endif
                        break;
                    }
                }
                temp_addr = temp_addr->ifa_next;
            }
            if (!wifiName.empty()) {
                temp_addr = interfaces;
                while (temp_addr != nullptr) {
                    std::string ifa_name(temp_addr->ifa_name);
                    if (ifa_name == wifiName) {
                        // 处理 IPv6 地址
                        ParseIPv6(temp_addr, ipv6, ipv6_prefix);
                        ParseMac(temp_addr, mac_addr);
                    }
                    temp_addr = temp_addr->ifa_next;
                }
            }
        }
        
        freeifaddrs(interfaces);
        interfaces = NULL;
        
        // 如果找到了IPv4或IPv6地址，或者重试次数用尽，则退出
        if (!wifiName.empty() || retry == 0) {
            break;
        }
        sleep(1);
    } while (--retry);

    return !wifiName.empty();
}

// 将IP字符串转换为整数形式（便于按位操作）
static uint32_t IpToInt(const std::string& ip) {
    struct sockaddr_in sa;
    inet_pton(AF_INET, ip.c_str(), &(sa.sin_addr));
    return ntohl(sa.sin_addr.s_addr);
}

// 判断是否在同一网络
bool IsInSameNetwork(const std::string &localIP, const std::string &netmask, const std::string& serverIP)
{
    uint32_t localIPInt = IpToInt(localIP);
    uint32_t serverIPInt = IpToInt(serverIP);
    uint32_t netmaskInt = IpToInt(netmask);
    
    // 按位与运算得到网络地址
    uint32_t localNetwork = localIPInt & netmaskInt;
    uint32_t serverNetwork = serverIPInt & netmaskInt;
    
    return localNetwork == serverNetwork;
}

long long Fibonacci(int n) {
    if (n <= 0) return 0;
    if (n == 1) return 1;
    
    long long prev = 0;    // F(0)
    long long current = 1; // F(1)
    
    for (int i = 2; i <= n; i++) {
        long long next = prev + current;
        prev = current;
        current = next;
    }
    
    LOG_DEBUG_S("fibonacci value: %lld");
    return current;
}

static int IsPortOccupied(int port, int &fd)
{
    int sockfd = -1;
    struct sockaddr_in server_addr;

    // 创建TCP套接字
    sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd < 0) {
        LOG_ERROR_S("socket creation failed");
        return -1;
    }

    // 设置套接字选项，允许地址重用（可选，但有助于避免TIME_WAIT状态的影响）
    int optval = 1;
    if (setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &optval, sizeof(optval)) < 0) {
        LOG_ERROR_S("setsockopt failed");
        close(sockfd);
        return -1;
    }

    // 设置服务器地址结构
    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(port); // 转换为网络字节序
    server_addr.sin_addr.s_addr = INADDR_ANY; // 绑定所有可用接口

    // 尝试绑定端口
    if (bind(sockfd, (struct sockaddr*)&server_addr, sizeof(server_addr)) != 0) {
        if (errno == EADDRINUSE) {
            // 端口已被占用
            close(sockfd);
            return 1;
        } else {
            // 其他绑定错误
            LOG_ERROR_S("bind failed");
            close(sockfd);
            return -1;
        }
    }

    // 绑定成功，端口未被占用
    // close(sockfd);
    fd = sockfd;
    return 0;
}

static int FindAvailablePort(uint16_t basePort, uint16_t &port, int &sockfd)
{
    int ret = 0;
    for (int i = 0; i < 255; i++) {
        ret = IsPortOccupied(basePort * 256 + i, sockfd);
        if (ret == 0) {
            port = basePort * 256 + i;
            return 0;
        }
    }
    
    return 1;
}

static unsigned char SimpleRandomInRange(unsigned char min, unsigned char max) {
    unsigned char random_byte;
    if (RAND_bytes(&random_byte, sizeof(random_byte)) != 1) {
        return min;
    }
    
    return min + (random_byte % (max - min + 1));
}

uint16_t GetRandomPort()
{
    uint16_t port = 0;
    int sockfd;
    uint8_t n = SimpleRandomInRange(0x40, 0xBF);
    
    if ((n >= 0x04) && (n <= 0xBF)) {
        if (FindAvailablePort(n, port, sockfd) == 0) {
            close(sockfd);
            return port;
        } else {
            return 0x4000;
        }
    }
    else {
        return 0x4000;
//        if (n < 0x04) {
//            n = (n +1) << 2;
//        } else if (n > 0xBF) {
//            n >>= 1;
//        }
//        
//        if ((n < 0x04) || (n > 0xBF))
//        {
//            LOG_DEBUG_S("invalid port %u", n);
//        }
//        
//        if (FindAvailablePort(n, port) == 0) {
//            return port;
//        } else {
//            return 0xFFFF;
//        }
    }
}

int GetRandomPortAndSockfd(uint16_t &port, int &sockfd)
{
    uint16_t tmpPort = 0;
    int tmpSockfd;
    uint8_t n = SimpleRandomInRange(0x40, 0xBF);
    
    if ((n >= 0x04) && (n <= 0xBF)) {
        if (FindAvailablePort(n, tmpPort, tmpSockfd) == 0) {
            port = tmpPort;
            sockfd = tmpSockfd;
            return 0;
        }
    }
    return 1;
}

int32_t SoftBusBase64Encode(unsigned char *dst, size_t dlen, const unsigned char *src, size_t slen)
{
    if (dst == nullptr || dlen == 0 || src == nullptr || slen == 0) {
        return 1;
    }

    size_t olen = 0;
    EVP_ENCODE_CTX *ctx = EVP_ENCODE_CTX_new();
    if (ctx == nullptr) {
        return 1;
    }

    size_t bufferSize = EVP_ENCODE_LENGTH(slen);
    std::vector<unsigned char> dstTmp(bufferSize);

    int outlen1 = 0, outlen2 = 0;
    EVP_EncodeInit(ctx);
    EVP_EncodeUpdate(ctx, dstTmp.data(), &outlen1, src, slen);
    EVP_EncodeFinal(ctx, dstTmp.data() + outlen1, &outlen2);

    olen = outlen1 + outlen2;

    if (olen > dlen) {
        LOG_DEBUG_S("[TRANS] invalid dlen=%zu, olen=%zu.", dlen, olen);
        EVP_ENCODE_CTX_free(ctx);
        return 1;
    }

    memcpy(dst, dstTmp.data(), olen);

    if (olen > 0 && dst[olen - 1] == '\n') {
        (olen)--;
        dst[olen] = '\0';
    }

    EVP_ENCODE_CTX_free(ctx);
    return 0;
}

int32_t SoftBusBase64Decode(unsigned char *dst, size_t dlen,
                           const unsigned char *src, size_t slen)
{
    if (dst == nullptr || dlen == 0 || src == nullptr || slen == 0) {
        return 1;
    }
    
    size_t olen = 0;
    EVP_ENCODE_CTX *ctx = EVP_ENCODE_CTX_new();
    if (ctx == nullptr) {
        return 1;
    }

    // Calculate buffer size for decoded data
    size_t bufferSize = EVP_DECODE_LENGTH(slen);
    std::vector<unsigned char> dstTmp(bufferSize);

    int outlen1 = 0, outlen2 = 0;
    int ret = 0;
    
    EVP_DecodeInit(ctx);
    
    // First pass: decode the main data
    int evp_ret = EVP_DecodeUpdate(ctx, dstTmp.data(), &outlen1, src, slen);
    if (evp_ret == -1) {
        LOG_DEBUG_S("[TRANS] EVP_DecodeUpdate fail: Invalid base64 data.");
        ret = 1;
        goto FINISHED;
    }
    
    olen = outlen1;
    
    // Finalize decoding
    evp_ret = EVP_DecodeFinal(ctx, dstTmp.data() + outlen1, &outlen2);
    if (evp_ret != 1) {
        LOG_DEBUG_S("[TRANS] EVP_DecodeFinal fail: Incomplete base64 data.");
        ret = 1;
        goto FINISHED;
    }
    
    olen += outlen2;
    
    if (olen > dlen) {
        LOG_DEBUG_S("[TRANS] invalid dlen=%zu, olen=%zu.", dlen, olen);
        ret = 1;
        goto FINISHED;
    }

    // Copy the decoded data to the destination buffer
    memcpy(dst, dstTmp.data(), olen);
    ret = 0;

FINISHED:
    EVP_ENCODE_CTX_free(ctx);
    return ret;
}

// encrypt part
static void BuildInnerTdcSendDataInfo(EncrptyInfo *enInfo, char *finalData, uint32_t inLen, char *out, uint32_t *outLen)
{
    enInfo->in = finalData;
    enInfo->inLen = inLen;
    enInfo->out = out;
    enInfo->outLen = outLen;
}

int32_t SoftBusGenerateRandomArray(unsigned char *randStr, uint32_t len)
{
    if (randStr == NULL || len == 0) {
        return 1;
    }

    static bool initFlag = false;
    int32_t ret;

    if (pthread_mutex_init(&g_randomLock, NULL) != 0) {
        LOG_DEBUG_S("init mutex failed.");
        return 1;
    }

    if (pthread_mutex_lock(&g_randomLock) != 0) {
        LOG_DEBUG_S("lock mutex failed");
        return 1;
    }
    if (initFlag == false) {
        RAND_seed(randStr, (int32_t)len);
        initFlag = true;
    }

    ret = RAND_bytes(randStr, (int32_t)len);
    pthread_mutex_unlock(&g_randomLock);
    if (ret != 1) {
        LOG_DEBUG_S("gen random error, ret=%d", ret);
        return 1;
    }
    return 0;
}

static int32_t PackIvAndTag(EVP_CIPHER_CTX *ctx, const AesGcmCipherKey *cipherkey, uint32_t dataLen,
    unsigned char *cipherText, uint32_t cipherTextLen)
{
    if ((dataLen + OVERHEAD_LEN) > cipherTextLen) {
        LOG_DEBUG_S("Encrypt invalid para.");
        return 1;
    }
    if (memcpy(cipherText, cipherkey->iv, GCM_IV_LEN) == NULL) {
        LOG_DEBUG_S("EVP memcpy iv fail.");
        return 1;
    }
    char tagbuf[TAG_LEN];
    int ret = EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, TAG_LEN, (void *)tagbuf);
    if (ret != 1) {
        LOG_DEBUG_S("EVP_CIPHER_CTX_ctrl fail.");
        return 1;
    }
    if (memcpy(cipherText + dataLen + GCM_IV_LEN, tagbuf, TAG_LEN) == NULL) {
        LOG_DEBUG_S("EVP memcpy tag fail.");
        return 1;
    }
    return 0;
}

static int32_t SslAesGcmEncrypt(const AesGcmCipherKey *cipherkey, const unsigned char *plainText,
uint32_t plainTextSize, unsigned char *cipherText, uint32_t cipherTextLen)
{
    if ((cipherkey == NULL) || (plainText == NULL) || (plainTextSize == 0) || cipherText == NULL ||
        (cipherTextLen < plainTextSize + OVERHEAD_LEN)) {
        LOG_DEBUG_S("Encrypt invalid para.");
        return 1;
    }

    int32_t outlen = 0;
    int32_t outbufLen;
    EVP_CIPHER_CTX *ctx = NULL;
    int32_t ret = OpensslEvpInit(&ctx, cipherkey->keyLen, true);
    if (ret != 0) {
        LOG_DEBUG_S("OpensslEvpInit fail.");
        return 1;
    }
    ret = EVP_EncryptInit_ex(ctx, NULL, NULL, cipherkey->key, cipherkey->iv);
    if (ret != 1) {
        LOG_DEBUG_S("EVP_EncryptInit_ex fail.");
        EVP_CIPHER_CTX_free(ctx);
        return 1;
    }
    ret = EVP_EncryptUpdate(ctx, cipherText + GCM_IV_LEN, (int32_t *)&outbufLen, plainText, plainTextSize);
    if (ret != 1) {
        LOG_DEBUG_S("EVP_EncryptUpdate fail.");
        EVP_CIPHER_CTX_free(ctx);
        return 1;
    }
    outlen += outbufLen;
    ret = EVP_EncryptFinal_ex(ctx, cipherText + GCM_IV_LEN + outbufLen, (int32_t *)&outbufLen);
    if (ret != 1) {
        LOG_DEBUG_S("EVP_EncryptFinal_ex fail.");
        EVP_CIPHER_CTX_free(ctx);
        return 1;
    }
    outlen += outbufLen;
    ret = PackIvAndTag(ctx, cipherkey, outlen, cipherText, cipherTextLen);
    if (ret != 0) {
        LOG_DEBUG_S("pack iv and tag fail.");
        EVP_CIPHER_CTX_free(ctx);
        return 1;
    }
    EVP_CIPHER_CTX_free(ctx);
    return (outlen + OVERHEAD_LEN);
}

int32_t SoftBusEncryptDataWithSeq(AesGcmCipherKey *cipherKey, const unsigned char *input, uint32_t inLen,
    unsigned char *encryptData, uint32_t *encryptLen, int32_t seqNum)
{
    if (cipherKey == NULL || input == NULL || inLen == 0 || encryptData == NULL || encryptLen == NULL) {
        return 1;
    }
    if (SoftBusGenerateRandomArray(cipherKey->iv, sizeof(cipherKey->iv)) != 0) {
        LOG_DEBUG_S("generate random iv error.");
        return 1;
    }
    if (memcpy(cipherKey->iv, &seqNum, sizeof(int32_t)) == NULL) {
        return 1;
    }
    uint32_t outLen = inLen + OVERHEAD_LEN;
    int32_t result = SslAesGcmEncrypt(cipherKey, input, inLen, encryptData, outLen);
    if (result <= 0) {
        return 1;
    }
    *encryptLen = result;
    return 0;
}

int32_t TransTdcEncryptWithSeq(const char *sessionKey, int32_t seqNum, EncrptyInfo *info)
{
    if (info == NULL || sessionKey == NULL) {
        LOG_DEBUG_S("param invalid.");
        return 1;
    }
    AesGcmCipherKey cipherKey = {0};
    cipherKey.keyLen = SESSION_KEY_LENGTH;
    if (memcpy(cipherKey.key, sessionKey, SESSION_KEY_LENGTH) == NULL) {
        LOG_DEBUG_S("memcpy key error.");
        return 1;
    }
    int32_t ret = SoftBusEncryptDataWithSeq(&cipherKey, (unsigned char*)info->in, info->inLen,
        (unsigned char*)info->out, info->outLen, seqNum);
    if (memset_s(&cipherKey, sizeof(AesGcmCipherKey), 0, sizeof(AesGcmCipherKey)) != 0) {
        LOG_DEBUG_S("memset cipherKey failed.");
        return 1;
    }
    if (ret != 0 || *info->outLen != info->inLen + OVERHEAD_LEN) {
        LOG_DEBUG_S("encrypt error, ret=%d", ret);
        return 1;
    }
    return 0;
}

// decrypt part
int32_t SoftBusDecryptData(AesGcmCipherKey *cipherKey, const unsigned char *input, uint32_t inLen,
    unsigned char *decryptData, uint32_t *decryptLen)
{
    if (cipherKey == NULL || input == NULL || inLen < GCM_IV_LEN || decryptData == NULL || decryptLen == NULL) {
        return 1;
    }

    if (memcpy(cipherKey->iv, input, GCM_IV_LEN) == NULL) {
        LOG_DEBUG_S("copy iv failed.");
        return 1;
    }
    uint32_t outLen = inLen - OVERHEAD_LEN;
    int32_t result = SslAesGcmDecrypt(cipherKey, input, inLen, decryptData, outLen);
    if (result <= 0) {
        return 1;
    }
    *decryptLen = (uint32_t)result;
    return 0;
}

int32_t SoftBusDecryptDataWithSeq(AesGcmCipherKey *cipherKey, const unsigned char *input, uint32_t inLen,
    unsigned char *decryptData, uint32_t *decryptLen, int32_t seqNum)
{
    (void)seqNum;
    return SoftBusDecryptData(cipherKey, input, inLen, decryptData, decryptLen);
}

int32_t TransTdcDecrypt(const char *sessionKey, const char *in, uint32_t inLen, char *out, uint32_t *outLen)
{
    if (sessionKey == NULL || in == NULL || out == NULL || outLen == NULL) {
        LOG_DEBUG_S("invalid param");
        return 1;
    }
    AesGcmCipherKey cipherKey = { 0 };
    cipherKey.keyLen = SESSION_KEY_LENGTH; // 256 bit encryption
    if (memcpy(cipherKey.key, sessionKey, SESSION_KEY_LENGTH) == NULL) {
        LOG_DEBUG_S("memcpy key error.");
        return 1;
    }
    int32_t ret = SoftBusDecryptData(&cipherKey, (unsigned char*)in, inLen, (unsigned char*)out, outLen);
    (void)memset(&cipherKey, 0, sizeof(AesGcmCipherKey));
    if (ret != 0) {
        LOG_DEBUG_S("dectypt data fail ret=%d", ret);
        return 1;
    }
    return 0;
}

int32_t TransTdcUnPackData(const char *sessionKey, char *plain, uint32_t *plainLen, const std::vector<uint8_t> &in)
{
    if (sessionKey == NULL || plain == NULL || plainLen == NULL) {
        LOG_DEBUG_S("invalid param");
        return 1;
    }
//    TdcDataPacketHead *pktHead = (TdcDataPacketHead *)(in.data());
    uint32_t dataLen = static_cast<uint32_t>(in.size());
//    LOG_DEBUG_S("data received, dataLen=%u, inLen=%d, seq=%d", dataLen, (int)in.size(), pktHead->seq);
    LOG_DEBUG_S("data received, dataLen=%u", dataLen);
    
    int32_t ret = TransTdcDecrypt(sessionKey, (char *)(in.data()), dataLen, plain, plainLen);
    if (ret != 0) {
        LOG_DEBUG_S("decrypt fail, dataLen=%u", dataLen);
        return 1;
    }

    return 0;
}

int32_t SaveFile(const char *filename, const uint8_t *content, size_t size) {
    // 检查输入参数
    if (filename == NULL || strlen(filename) == 0) {
        fprintf(stderr, "Filename is null or empty");
        return -1;
    }
    
    if (content == NULL && size > 0) {
        fprintf(stderr, "Content is null but size > 0");
        return -2;
    }
    
    // 尝试打开文件
    FILE *file = fopen(filename, "wb");
    if (file == NULL) {
        int error_code = errno;
        fprintf(stderr, "Failed to open file '%s': %s", filename, strerror(error_code));
        
        // 如果是路径不存在错误，尝试创建目录
        if (error_code == ENOENT) {
            return -4;
        } else {
            return -5; // 其他错误
        }
    }
    
    // 写入数据
    if (size > 0) {
        size_t written = fwrite(content, 1, size, file);
        if (written != size) {
            fprintf(stderr, "Write error: wrote %zu of %zu bytes", written, size);
            fclose(file);
            return -6;
        }
    }
    
    // 关闭文件
    if (fclose(file) != 0) {
        fprintf(stderr, "Error closing file: %s", strerror(errno));
        return -7;
    }
    
    return 0; // 成功
}

int32_t TransTdcPackData(const char *sessionKey, const std::vector<uint8_t> payload, std::vector<uint8_t> &packet)
{
    EncrptyInfo enInfo = { 0 };
    TdcDataPacketHead pktHead = {
        .magicNumber = MAGIC_NUMBER,
        .seq = 1,
        .flags = (uint32_t)FLAG_BYTES,
        .dataLen = (uint32_t)(OVERHEAD_LEN + payload.size()),
    };

    // char *buf = TransPackData(dataLen, finalSeq, flags);
    packet.resize(DC_DATA_HEAD_SIZE + OVERHEAD_LEN + payload.size());
    uint8_t *ptr = packet.data();
    memcpy(ptr, &pktHead, sizeof(pktHead));
    ptr += DC_DATA_HEAD_SIZE;


    uint32_t outLen;
    BuildInnerTdcSendDataInfo(&enInfo, (char *)payload.data(), payload.size(), (char *)ptr, &outLen);
    int32_t ret = TransTdcEncryptWithSeq(sessionKey, pktHead.seq, &enInfo);
    if (ret != 0) {
        return NULL;
    }

    return 0;
}

std::string byte2hexstr(const uint8_t* data, size_t length, bool uppercase, const std::string& separator)
{
    if (length == 0) return "";
    
    const auto& hex_chars = uppercase ? hex_chars_upper : hex_chars_lower;
    std::string result;
    result.reserve(length * (2 + separator.size()));
    
    for (size_t i = 0; i < length; ++i) {
        result += hex_chars[(data[i] >> 4) & 0x0F];
        result += hex_chars[data[i] & 0x0F];
        
        if (i < length - 1 && !separator.empty()) {
            result += separator;
        }
    }
    return result;
}

std::vector<uint8_t> HexString2Bytes(const std::string& hex)
{
    std::vector<uint8_t> bytes;
    if (hex.length() % 2 != 0) {
        LOG_ERROR_S("hex string lenth is not even length");
        return bytes;
    }
    for (size_t i = 0; i < hex.length(); i += 2) {
        std::string byteString = hex.substr(i, 2);
        uint8_t byte = static_cast<uint8_t>(std::stoi(byteString, nullptr, 16));
        bytes.push_back(byte);
    }
    return bytes;
}

void BytesToHExString(char *outBuff, uint32_t outBufflen, const unsigned char *inBuff, uint32_t inLen)
{
    if (outBuff == nullptr || inBuff == nullptr || outBufflen < inLen * 2) {
        return;
    }
    while (inLen > 0) {
        unsigned char h = *inBuff / 16;
        unsigned char l = *inBuff % 16;
        if (h < 10) {
            *outBuff++ = '0' + h;
        } else {
            *outBuff++ = 'A' + h - 10;
        }
        if (l < 10) {
            *outBuff++ = '0' + l;
        } else {
            *outBuff++ = 'A' + l - 10;
        }
        ++inBuff;
        inLen--;
    }
}

bool isMediaUTI(const std::string& utiString)
{
    NSString *nsUTI = [NSString stringWithUTF8String:utiString.c_str()];
    if (!nsUTI) return false;

//    if (@available(iOS 14.0, *)) {
//        UTType *type = [UTType typeWithIdentifier:nsUTI];
//        return [type conformsToType:UTTypeImage] ||
//               [type conformsToType:UTTypeMovie] ||
//               [type.identifier isEqualToString:@"com.apple.live-photo"];
//    }else {
        CFStringRef cfUTI = (__bridge CFStringRef)nsUTI;
        return UTTypeConformsTo(cfUTI, kUTTypeImage) ||
               UTTypeConformsTo(cfUTI, kUTTypeMovie) ||
               CFEqual(cfUTI, CFSTR("com.apple.live-photo"));
//    }
}

std::string GetGatewayIp(const std::string &ip)
{
    std::string gwIp = ip;
    size_t lastDot = gwIp.rfind('.');
    if (lastDot != std::string::npos) {
        gwIp.replace(lastDot + 1, std::string::npos, "1");
    }
    
    return gwIp;
}

long long GetFreeDiskSpace() {
    NSError *error = nil;
    NSURL *fileURL = [NSURL fileURLWithPath:NSHomeDirectory()];
    NSDictionary *results = [fileURL resourceValuesForKeys:@[NSURLVolumeAvailableCapacityForImportantUsageKey] error:&error];
    NSNumber *freeSpaceNumber = results[NSURLVolumeAvailableCapacityForImportantUsageKey];
    if (freeSpaceNumber == nil) {
        LOG_ERROR_S("Failed to get free disk space");
        return -1;
    }
    return [freeSpaceNumber longLongValue];
}

std::string AnonymizeIP(const std::string ip)
{
    if (ip.empty()) {
        return ip;
    }
    
    std::vector<std::string> parts;
    std::stringstream ss(ip);
    std::string part;
    
    while (std::getline(ss, part, '.')) {
        parts.push_back(part);
    }
    
    if (parts.size() != 4) {
        return ip;
    }
    
    return parts[0] + "." + std::string(parts[1].length(), '*') + "." + parts[2] + "." + parts[3];
}

std::string AnonymizeIP(const char *ip)
{
    if (ip == nullptr) {
        return "";
    }
    return AnonymizeIP(std::string(ip));
}

std::string AnonymizeString(const std::string input)
{
    if (input.empty()) {
        return input;
    }
    
    int len = input.length();
    
    if (len <= 4) {
        return std::string(len, '*');
    }
    
    int keepCount = len - 4;
    int keepBack = (keepCount + 1) / 2;
    int keepFront = keepCount - keepBack;
    
    std::string result;
    
    if (keepFront > 0 && keepFront <= len) {
        result += input.substr(0, keepFront);
    }
    
    result += "****";
    
    int backStart = len - keepBack;
    if (keepBack > 0 && backStart < len) {
        result += input.substr(backStart);
    }
    
    return result;
}

std::string AnonymizeString(const char *input)
{
    if (input == nullptr) {
        return "";
    }
    return AnonymizeString(std::string(input));
}
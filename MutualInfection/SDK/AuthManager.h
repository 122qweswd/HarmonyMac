//
//  AuthManager.h
//  MutualInfection
//
//  Created by apple on 2025/9/4.
//

#ifndef AUTH_MANAGER_H
#define AUTH_MANAGER_H

#ifdef __cplusplus

#include <cstdint>
#include <map>
#include <string>
#include <vector>
#include <openssl/evp.h>
#include "Device.h"
#ifdef __OBJC__
#import <Foundation/Foundation.h>
#endif
//#include "AuthSessionSerializer.h"

// 前向声明
struct evp_pkey_st;
typedef struct evp_pkey_st EVP_PKEY;

// 加密类型标志
static const uint32_t NO_ENCRYPTION_FLAG = 0x00;
static const uint32_t AES_256_ENCRYPTION_FLAG = 0x02;
static const uint32_t RSA_PUBLIC_ENCRYPTION_FLAG = 0x03;

// Command ID
static const uint32_t ISHARE_APPLE_ECOLOGY_COMMAND_ID = 0x01;
static const uint32_t ISHARE_APPLE_ECOLOGY_COMPETENCY_NEGO_REQ_ID = 0x02;
static const uint32_t ISHARE_APPLE_ECOLOGY_COMPETENCY_NEGO_RSP_ID = 0x03;
static const uint32_t ISHARE_APPLE_ECOLOGY_NETWORKINFO_NEGO_REQ_ID = 0x04;
static const uint32_t ISHARE_APPLE_ECOLOGY_NETWORKINFO_NEGO_RSP_ID = 0x05;
static const uint32_t ISHARE_APPLE_ECOLOGY_CCMP_ID = 0x06;
static const uint32_t ISHARE_APPLE_ECOLOGY_PREVIEW_SHOW_ID = 0x07;
static const uint32_t ISHARE_APPLE_ECOLOGY_PREVIEW_RECV_ID = 0x08;
static const uint32_t ISHARE_APPLE_ECOLOGY_PHYSICAL_CONNECTION_INFO_ID = 0x09;
static const uint32_t ISHARE_APPLE_ECOLOGY_LOGICAL_CONNECTION_INFO_ID = 0x0A;
static const uint32_t ISHARE_APPLE_ECOLOGY_AVATAR = 0x0F;

// Type values
static const uint32_t ISHARE_ECOLOGY_POPUP_CONFIRM = 0x01;
static const uint32_t ISHARE_ECOLOGY_SENDER_CANCEL = 0x02;
static const uint32_t ISHARE_ECOLOGY_SENDER_CANCEL_ACK = 0x03;
static const uint32_t ISHARE_ECOLOGY_RECEIVE_CANCEL = 0x04;
static const uint32_t ISHARE_ECOLOGY_RECEIVE_CANCEL_ACK = 0x05;
static const uint32_t ISHARE_ECOLOGY_NOT_ENOUGH_SPACE = 0x06;
static const uint32_t ISHARE_ECOLOGY_ALREADY_IN_RECEIVE = 0x07;
static const uint32_t ISHARE_ECOLOGY_PREVIEW_OK = 0x08;
static const uint32_t ISHARE_ECOLOGY_DFILE_RECV_PERCENT = 0x09;
static const uint32_t ISHARE_ECOLOGY_TRANS_ERROR = 0x0A;
static const uint32_t ISHARE_ECOLOGY_TRANS_ERROR_ACK = 0x0B;
static const uint32_t ISHARE_ECOLOGY_GET_PHYSICAL_CONNECTION_INFO = 0x0D;
static const uint32_t ISHARE_ECOLOGY_SAVE_AVATER = 0x0F;
static const uint32_t ISHARE_ECOLOGY_HOTSPOT_ENABLED = 0x10;
static const uint32_t ISHARE_ECOLOGY_KEEP_ALIVE = 0x10;
static const uint32_t ISHARE_APPLE_ECOLOGY_SUPPORT_SECURE_VERSION = 0x01;
static const uint32_t ISHARE_APPLE_ECOLOGY_APP_VERSION = 0x02;
static const uint32_t ISHARE_APPLE_ECOLOGY_OS_VERSION = 0x03;
static const uint32_t ISHARE_APPLE_ECOLOGY_DEV_MODEL = 0x04;
static const uint32_t GET_RSA_PUBLIC_KEY = 0x01;
static const uint32_t GET_RSA_PUBLIC_KEY_RESPONSE = 0x02;
static const uint32_t GET_AES_KEY = 0x03;
static const uint32_t GET_AES_KEY_RESPONSE = 0x04;

static const uint32_t ISHARE_APPLE_ECOLOGY_SUPPORT_FILE_TYPE_ABILITY = 0x02;
static const uint32_t PUBLIC_KEY_ALGORITHM_TYPE = 0x05;
static const uint32_t SESSION_KEY_ALGORITHM_TYPE = 0x06;

// File types
static const uint32_t SEND_TYPE_PHOTO_ASSET = 0;
static const uint32_t SEND_TYPE_MIX = 1;
static const uint32_t SEND_TYPE_ALBUM = 2;
static const uint32_t SEND_TYPE_FILE_MANAGER_FILE = 3;
static const uint32_t SEND_TYPE_FOLDER = 4;
static const uint32_t SEND_TYPE_ATOMIC_SERVICE = 5;
static const uint32_t SEND_TYPE_ATOMIC_CARD = 6;
static const uint32_t SEND_TYPE_HAP = 7;
static const uint32_t SEND_TYPE_SAND_BOX_FILE = 8;
static const uint32_t SEND_TYPE_TEXT = 9;
static const uint32_t SEND_TYPE_LINK = 10;

// Algorithm types
static const uint32_t ALGORITHM_RSA_4096 = 0;
static const uint32_t ALGORITHM_RSA_2048 = 1;

static const uint32_t ALGORITHM_AES_256 = 0;
static const uint32_t ALGORITHM_DES_64 = 1;
static const uint32_t ALGORITHM_3DES_112 = 2;

const size_t HASH_LEN = 20;
const size_t HASH_KEY_LEN = 16;

class AuthManager {
public:
    AuthManager();
    ~AuthManager();

    // 获取DeviceHash
    void GetDeviceHash(std::vector<uint8_t> &deviceShortHash, size_t maxLen);
    uint16_t GetDeviceId(int index);

    // 使用RSA加解密
    bool EncryptWithRSA(const std::vector<uint8_t> &data, std::vector<uint8_t> &ciphertext);
    bool DecryptWithRSA(const std::vector<uint8_t> &data, std::vector<uint8_t> &plaintext);

    // 使用AES-GCM加解密
    bool EncryptWithAESGCM(const std::vector<uint8_t> &data, const std::vector<uint8_t> &key,
                           const std::vector<uint8_t> &nonce, std::vector<uint8_t> &ciphertext);
    bool DecryptWithAESGCM(const std::vector<uint8_t> &data, const std::vector<uint8_t> &key,
                           const std::vector<uint8_t> &nonce, std::vector<uint8_t> &plaintext);
    void GenRandomNumber(std::vector<uint8_t> &randomKey, std::vector<uint8_t> &aesGcmRandomKey);


    void GetByteSessionKey(std::vector<uint8_t> &sessionKey);
    void SetByteSessionKey(const std::vector<uint8_t> &sessionKey);
    void ClearByteSessionKey();

    void GetDFileSessionKey(std::vector<uint8_t> &sessionKey);
    void SetDFileSessionKey(const std::vector<uint8_t> &sessionKey);
    void ClearDFileSessionKey();

    void ExportPublicKey(std::vector<uint8_t> &pubKey);
    bool ImportPeerPublicKey(const std::vector<uint8_t> &publicKeyData);

    void StrHas(const unsigned char *str, uint32_t len, unsigned char *hash);
private:
    // 将密钥对保存到Keychain
    bool saveRsaKeyPairToKeychain(EVP_PKEY* keyPair);
    // 从Keychain获取私钥数据
    std::vector<uint8_t> getKeychainKey();
    void buildDeviceHash(EVP_PKEY *savedKeyPair);

    // 使用RSA加解密
    bool encryptWithRSA(const std::vector<uint8_t> &data, EVP_PKEY *publicKey, std::vector<uint8_t> &ciphertext);
    bool decryptWithRSA(const std::vector<uint8_t> &data, EVP_PKEY *keyPair, std::vector<uint8_t> &plaintext);
    bool decryptRandomNumber(const std::vector<uint8_t> &payload,
                             std::vector<uint8_t> &randomKey,
                             std::vector<uint8_t> &aesGcmRandomKey);

    EVP_PKEY *genRsaKeyPair();
    void buildHmac(const std::vector<uint8_t> &pubKey, std::vector<uint8_t> &deviceHash);
    void exportPublicKey(EVP_PKEY *keyPair, std::vector<uint8_t> &pubKey);
    void convertPEMToDER(const std::vector<uint8_t> &pemKey, std::vector<uint8_t> &derKey);
    void convertDERToPEM(const std::vector<uint8_t> &derKey, std::vector<uint8_t> &pemKey);

private:
    EVP_PKEY *rsaKeyPair { nullptr };               // RSA密钥对
    EVP_PKEY *peerPublicKey { nullptr };    // 对端公钥
    
    std::vector<uint8_t> deviceHash;    // 当前设备的hash

    std::vector<uint8_t> byteSessionKey;        // byte通道会话密钥
    std::vector<uint8_t> dFileSessionKey;   // DFile通道会话密钥

    std::vector<uint8_t> rsaPublicKey;  // RSA公钥字符串
    std::vector<uint8_t> aesKey;        // AES密钥字符串
};

#endif // __cplusplus

#endif /* AUTH_MANAGER_H */

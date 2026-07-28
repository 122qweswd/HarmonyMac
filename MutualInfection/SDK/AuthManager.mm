//
//  AuthManager.mm
//  MutualInfection
//
//  Created by apple on 2025/9/4.
//
#include "AuthManager.h"
#include <string>
#include <set>

// OpenSSL头文件
#include <openssl/evp.h>
#include <openssl/pem.h>
#include <openssl/rand.h>
#include <openssl/rsa.h>
#include <openssl/hmac.h>
#include <vector>

#include "Common.h"
#include "LogHelper.h"

//
//// 静态实例指针
//AuthManager *AuthManager::instance_ = nullptr;
//
// 获取单例实例
//AuthManager &AuthManager::shared() {
//    static AuthManager manager;
//    return manager;
//}

// 从Keychain获取私钥数据
// std::vector<uint8_t> AuthManager::getKeychainKey() {
//     std::vector<uint8_t> privateKeyData;
    
//     const char* keyTag = "HOST_RSA_KEY";
    
//     // 构建查询字典
//     CFStringRef tag = CFStringCreateWithCString(NULL, keyTag, kCFStringEncodingUTF8);
//     CFDataRef tagData = CFStringCreateExternalRepresentation(NULL, tag, kCFStringEncodingUTF8, 0);
    
//     CFMutableDictionaryRef query = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
//     CFDictionaryAddValue(query, kSecClass, kSecClassKey);
//     CFDictionaryAddValue(query, kSecAttrApplicationTag, tagData);
//     CFDictionaryAddValue(query, kSecAttrKeyType, kSecAttrKeyTypeRSA);
//     CFDictionaryAddValue(query, kSecReturnData, kCFBooleanTrue);
//     CFDictionaryAddValue(query, kSecAttrIsPermanent, kCFBooleanTrue);
    
//     CFDataRef privateKeyRef = NULL;
//     OSStatus status = SecItemCopyMatching(query, (CFTypeRef *)&privateKeyRef);
    
//     if (status != errSecSuccess) {
//         NSLog(@"获取私钥失败: %ld", (long)status);
//     } else if (privateKeyRef) {
//         CFIndex dataLength = CFDataGetLength(privateKeyRef);
//         privateKeyData.resize(dataLength);
//         CFDataGetBytes(privateKeyRef, CFRangeMake(0, dataLength), privateKeyData.data());
//         CFRelease(privateKeyRef);
//     }
    
//     if (query) CFRelease(query);
//     if (tagData) CFRelease(tagData);
//     if (tag) CFRelease(tag);
    
//     return privateKeyData;
// }

std::vector<uint8_t> AuthManager::getKeychainKey() {
    std::vector<uint8_t> privateKeyData;
    
    const char* keyTag = "HOST_RSA_KEY";
    
    // 从UserDefaults获取数据
    NSString *key = [NSString stringWithUTF8String:keyTag];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSData *privateKeyNSData = [defaults objectForKey:key];
    
    if (privateKeyNSData) {
        privateKeyData.resize([privateKeyNSData length]);
        memcpy(privateKeyData.data(), [privateKeyNSData bytes], [privateKeyNSData length]);
    }
    
    return privateKeyData;
}

// 构造函数
AuthManager::AuthManager()
    : rsaKeyPair(nullptr)
{
    std::vector<uint8_t> KeyData = getKeychainKey();
    
    if (!KeyData.empty()) {
        const unsigned char *pData = KeyData.data();
        size_t dataLen = KeyData.size();
        rsaKeyPair = d2i_PrivateKey(EVP_PKEY_RSA, NULL, &pData, dataLen);
    }
    buildDeviceHash(rsaKeyPair);
}

// 析构函数
AuthManager::~AuthManager() {
  if (rsaKeyPair != nullptr) {
    EVP_PKEY_free(rsaKeyPair);
  }
}

// // 生成设备HASH
// EVP_PKEY * AuthManager::genRsaKeyPair() {
//     NSString *keyTag = @"HOST_RSA_KEY";
    
//     // 定义密钥对生成参数
//     NSDictionary *privateKeyParams = @{
//         (id)kSecAttrIsPermanent: @NO,  // 不永久保存
//         (id)kSecAttrApplicationTag: [keyTag dataUsingEncoding:NSUTF8StringEncoding],
//         (id)kSecAttrKeyType: (id)kSecAttrKeyTypeRSA,
//         (id)kSecAttrKeySizeInBits: @2048
//     };
    
//     NSDictionary *keyPairParams = @{
//         (id)kSecAttrKeyType: (id)kSecAttrKeyTypeRSA,
//         (id)kSecAttrKeySizeInBits: @2048,
//         (id)kSecPrivateKeyAttrs: privateKeyParams
//     };
    
//     // 生成密钥对
//     SecKeyRef publicKeyRef = NULL;
//     SecKeyRef privateKeyRef = NULL;
//     OSStatus status = SecKeyGeneratePair((CFDictionaryRef)keyPairParams, &publicKeyRef, &privateKeyRef);
    
//     if (status != errSecSuccess) {
//         NSLog(@"生成密钥对失败%ld", (long)status);
//         return nullptr;
//     }
    
//     // 将SecKeyRef转换为EVP_PKEY
//     CFErrorRef error = NULL;
//     NSData *privateKeyData = (NSData *)CFBridgingRelease(SecKeyCopyExternalRepresentation(privateKeyRef, &error));
    
//     EVP_PKEY *pkey = nullptr;
//     if (privateKeyData && !error) {
//         // 将NSData转换为EVP_PKEY
//         const unsigned char *pData = (const unsigned char *)[privateKeyData bytes];
//         pkey = d2i_PrivateKey(EVP_PKEY_RSA, NULL, &pData, [privateKeyData length]);
//     }
    
//     // 清理资源
//     if (publicKeyRef) CFRelease(publicKeyRef);
//     if (privateKeyRef) CFRelease(privateKeyRef);
//     if (error) CFRelease(error);
    
//     return pkey;
//}

EVP_PKEY * AuthManager::genRsaKeyPair() {
    NSString *keyTag = @"HOST_RSA_KEY";
    
    // 生成RSA密钥对
    EVP_PKEY *pkey = nullptr;
    RSA *rsa = RSA_new();
    BIGNUM *bn = BN_new();
    
    if (BN_set_word(bn, RSA_F4) != 1) {
        BN_free(bn);
        RSA_free(rsa);
        return nullptr;
    }
    
    if (RSA_generate_key_ex(rsa, 2048, bn, NULL) != 1) {
        BN_free(bn);
        RSA_free(rsa);
        return nullptr;
    }
    
    pkey = EVP_PKEY_new();
    if (EVP_PKEY_assign_RSA(pkey, rsa) != 1) {
        EVP_PKEY_free(pkey);
        BN_free(bn);
        RSA_free(rsa);
        return nullptr;
    }
    
    BN_free(bn);
    return pkey;
}

// 将密钥对保存到Keychain
bool AuthManager::saveRsaKeyPairToKeychain(EVP_PKEY* keyPair) {
    if (!keyPair) {
        return false;
    }
    
    // 将EVP_PKEY转换为NSData
    BIO *bio = BIO_new(BIO_s_mem());
    if (!bio) {
        return false;
    }
    
    // 将私钥以PKCS#8格式写入BIO
    if (i2d_PKCS8PrivateKey_bio(bio, keyPair, NULL, NULL, 0, NULL, NULL) <= 0) {
        BIO_free(bio);
        return false;
    }
    
    // 获取BIO中的数据
    char *privateKeyData = NULL;
    long privateKeyLen = BIO_get_mem_data(bio, &privateKeyData);
    if (privateKeyLen <= 0 || !privateKeyData) {
        BIO_free(bio);
        return false;
    }
    
    NSData *keyData = [NSData dataWithBytes:privateKeyData length:(NSUInteger)privateKeyLen];
    BIO_free(bio);
    
    if (!keyData) {
        return false;
    }
    
    
    // // 保存到Keychain
    // NSString *keyTag = @"HOST_RSA_KEY";
    // NSDictionary *keyQuery = @{
    //     (id)kSecClass: (id)kSecClassKey,
    //     (id)kSecAttrApplicationTag: [keyTag dataUsingEncoding:NSUTF8StringEncoding],
    //     (id)kSecAttrKeyType: (id)kSecAttrKeyTypeRSA,
    //     (id)kSecValueData: keyData,
    //     (id)kSecAttrIsPermanent: @YES
    // };
    
    // // 先删除可能已存在的密钥
    // NSDictionary *deleteQuery = @{
    //     (id)kSecClass: (id)kSecClassKey,
    //     (id)kSecAttrApplicationTag: [keyTag dataUsingEncoding:NSUTF8StringEncoding],
    //     (id)kSecAttrKeyType: (id)kSecAttrKeyTypeRSA
    // };
    
    // SecItemDelete((CFDictionaryRef)deleteQuery);
    
    // // 添加新密钥
    // OSStatus status = SecItemAdd((CFDictionaryRef)keyQuery, NULL);
    // return status == errSecSuccess;



    // 保存到UserDefaults
    NSString *keyTag = @"HOST_RSA_KEY";
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:keyData forKey:keyTag];
    [defaults synchronize];
    
    return true;
}

void AuthManager::StrHas(const unsigned char *str, uint32_t len, unsigned char *hash)
{
    if (str == nullptr || hash == nullptr || len == 0) {
        return;
    }
    uint32_t olen;
    int32_t ret = EVP_Digest(str, len, hash, &olen, EVP_sha256(), NULL);
    if (ret != 1) {
        return;
    }
}

void AuthManager::buildHmac(const std::vector<uint8_t> &pubKey, std::vector<uint8_t> &deviceHash) {
    if (pubKey.empty()) {
        return;
    }
    std::vector<uint8_t> hashKey(HASH_KEY_LEN);
    memcpy(hashKey.data(), pubKey.data(), HASH_KEY_LEN);
    
    HMAC_CTX *ctx = HMAC_CTX_new();
    if (ctx == nullptr) {
        return;
    }
    
    if (HMAC_CTX_reset(ctx) != 1) {
        HMAC_CTX_free(ctx);
        return;
    }
    
    if (HMAC_Init_ex(ctx, hashKey.data(), hashKey.size(), EVP_sha256(), nullptr) != 1) {
        HMAC_CTX_free(ctx);
        return;
    }
    
    if (HMAC_Update(ctx, pubKey.data(), pubKey.size()) != 1) {
        HMAC_CTX_free(ctx);
        return;
    }
    uint32_t outLen;
    std::vector<uint8_t> resultHash(EVP_MAX_MD_SIZE);
    if (HMAC_Final(ctx, resultHash.data(), &outLen) != 1) {
        HMAC_CTX_free(ctx);
        return;
    }
    HMAC_CTX_free(ctx);
    if (resultHash.size() < HASH_LEN) {
        return;
    }
    deviceHash.clear();
    deviceHash.insert(deviceHash.end(), resultHash.begin(), resultHash.end());
}

// 获取本端UDID Hash
void AuthManager::buildDeviceHash(EVP_PKEY *savedKeyPair) {
    EVP_PKEY *keyPair = nullptr;
    bool hasFound = false;
    std::vector<uint8_t> pubKey;
    std::set<uint16_t> forbidUUIDs;
    forbidUUIDs.insert(0xFE35);
    forbidUUIDs.insert(0x903E);
    forbidUUIDs.insert(0x933E);
    forbidUUIDs.insert(0x953E);
    forbidUUIDs.insert(0x0300);
    while (!hasFound) {
        if (savedKeyPair != nullptr) {
            keyPair = savedKeyPair;
        } else {
            keyPair = genRsaKeyPair();
            if (keyPair == nullptr) {
                continue;
            }
        }

        exportPublicKey(keyPair, pubKey);
        buildHmac(pubKey, deviceHash);
        if (forbidUUIDs.find(GetDeviceId(0)) == forbidUUIDs.end()
            && forbidUUIDs.find(GetDeviceId(1)) == forbidUUIDs.end()
            && forbidUUIDs.find(GetDeviceId(2)) == forbidUUIDs.end()) {
            hasFound = true;
            rsaKeyPair = keyPair;
            saveRsaKeyPairToKeychain(keyPair);
        } else {
            EVP_PKEY_free(keyPair);
        }
    }
}

void AuthManager::GetDeviceHash(std::vector<uint8_t> &deviceShortHash, size_t maxLen)
{
    deviceShortHash.clear();
    size_t copyed = maxLen;
    if (deviceHash.size() < maxLen) {
        copyed = deviceHash.size();
    }
    deviceShortHash.insert(deviceShortHash.end(), deviceHash.begin(), deviceHash.begin() + copyed);
}

void AuthManager::convertPEMToDER(const std::vector<uint8_t> &pemKey, std::vector<uint8_t> &derKey) {
    // 创建BIO内存结构
    BIO *bio = BIO_new_mem_buf(pemKey.data(), static_cast<int>(pemKey.size()));
    if (!bio) {
        return;
    }

    // 从BIO中读取公钥
    EVP_PKEY *pubKey = PEM_read_bio_PUBKEY(bio, nullptr, nullptr, nullptr);
    BIO_free(bio);

    // 创建内存BIO用于存储DER格式数据
    BIO *derBio = BIO_new(BIO_s_mem());
    if (!derBio) {
        EVP_PKEY_free(pubKey);
        return;
    }

    // 将公钥以DER格式写入BIO
    if (!i2d_PUBKEY_bio(derBio, pubKey)) {
        EVP_PKEY_free(pubKey);
        BIO_free(derBio);
        return;
    }

    // 获取BIO中的数据长度
    int derLen = BIO_pending(derBio);
    if (derLen <= 0) {
        EVP_PKEY_free(pubKey);
        BIO_free(derBio);
        return;
    }

    // 分配内存并读取DER数据
    derKey.resize(derLen);
    BIO_read(derBio, derKey.data(), derLen);

    // 清理资源
    EVP_PKEY_free(pubKey);
    BIO_free(derBio);
}

void AuthManager::convertDERToPEM(const std::vector<uint8_t> &derKey, std::vector<uint8_t> &pemKey) {
    
    // 使用d2i_PUBKEY函数将DER格式数据转换为EVP_PKEY结构
    const unsigned char *p = derKey.data();
    EVP_PKEY *pubKey = d2i_PUBKEY(NULL, &p, derKey.size());

    // 创建内存BIO用于存储PEM格式数据
    BIO *bio = BIO_new(BIO_s_mem());
    if (!bio) {
        EVP_PKEY_free(pubKey);
        return;
    }
    
    // 将公钥以PEM格式写入BIO
    if (!PEM_write_bio_PUBKEY(bio, pubKey)) {
        EVP_PKEY_free(pubKey);
        BIO_free(bio);
        return;
    }
    
    // 获取BIO中的数据长度
    int pemLen = BIO_pending(bio);
    if (pemLen <= 0) {
        EVP_PKEY_free(pubKey);
        BIO_free(bio);
        return;
    }
    
    // 分配内存并读取PEM数据
    pemKey.resize(pemLen);
    BIO_read(bio, pemKey.data(), pemLen);
    
    // 清理资源
    EVP_PKEY_free(pubKey);
    BIO_free(bio);
}

// 导出本端公钥
void AuthManager::ExportPublicKey(std::vector<uint8_t> &pubKey)
{
    exportPublicKey(rsaKeyPair, pubKey);
}

void AuthManager::exportPublicKey(EVP_PKEY *keyPair, std::vector<uint8_t> &pubKey)
{
    pubKey.clear();
    if (keyPair == nullptr) {
        return;
    }

    // 创建BIO内存结构
    BIO *bio = BIO_new(BIO_s_mem());
    if (!bio) {
        return;
    }

    // 将公钥以PEM格式写入BIO
    if (!PEM_write_bio_PUBKEY(bio, keyPair)) {
        BIO_free(bio);
        return;
    }

    // 获取BIO中的数据长度
    int keylen = BIO_pending(bio);
    if (keylen <= 0) {
        BIO_free(bio);
        return;
    }

    // 分配内存并读取数据
    std::vector<uint8_t> tempKey(keylen);
    BIO_read(bio, tempKey.data(), keylen);

    // 释放BIO
    BIO_free(bio);
    convertPEMToDER(tempKey, pubKey);
}

// 导入对端公钥
bool AuthManager::ImportPeerPublicKey(const std::vector<uint8_t> &keyData) {
    if (keyData.empty()) {
        return false;
    }
    
    // 如果已有对端公钥，先释放
    if (peerPublicKey != nullptr) {
        EVP_PKEY_free((EVP_PKEY*)peerPublicKey);
        peerPublicKey = nullptr;
    }

    std::vector<uint8_t> pemKey;
    convertDERToPEM(keyData, pemKey);

    // 创建BIO内存结构
    BIO *bio = BIO_new_mem_buf(pemKey.data(), static_cast<int>(pemKey.size()));
    if (!bio) {
        return false;
    }

    // 从BIO中读取公钥
    peerPublicKey = PEM_read_bio_PUBKEY(bio, nullptr, nullptr, nullptr);
    BIO_free(bio);
    if (peerPublicKey == nullptr) {
        return false;
    }
    return true;
}

// 生成随机数 (16字节randomKey + 32字节aesGcmRandomKey)
void AuthManager::GenRandomNumber(std::vector<uint8_t> &randomKey, std::vector<uint8_t> &aesGcmRandomKey) {
    // 生成16字节randomKey
    randomKey.resize(16);
    RAND_bytes(randomKey.data(), 16);
    aesGcmRandomKey.resize(32);
    RAND_bytes(aesGcmRandomKey.data(), 32);
}

// 使用AES-GCM加密
bool AuthManager::EncryptWithAESGCM(const std::vector<uint8_t> &plaintext, const std::vector<uint8_t> &key,
                                    const std::vector<uint8_t> &nonce, std::vector<uint8_t> &ciphertext) {
    
    if (key.size() != 32 || (nonce.size() != 16 && nonce.size() != 12)) { // AES-256需要32字节密钥
        return false;
    }

    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    if (!ctx) {
        return false;
    }

    // 初始化加密操作
    if (EVP_EncryptInit_ex(ctx, EVP_aes_256_gcm(), nullptr, nullptr, nullptr) <= 0) {
        EVP_CIPHER_CTX_free(ctx);
        return false;
    }

    if (EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, nonce.size(), NULL) <= 0) {
        EVP_CIPHER_CTX_free(ctx);
        return false;
    }

    // 设置密钥和nonce
    if (EVP_EncryptInit_ex(ctx, nullptr, nullptr, key.data(), nonce.data()) <= 0) {
        EVP_CIPHER_CTX_free(ctx);
        return false;
    }

    ciphertext.resize(plaintext.size() + 16); // 预留空间给tag
    int len = 0;
    int ciphertext_len = 0;

    // 执行加密
    if (EVP_EncryptUpdate(ctx, ciphertext.data(), &len, plaintext.data(),
                    static_cast<int>(plaintext.size())) <= 0) {
        EVP_CIPHER_CTX_free(ctx);
        return false;
    }
    ciphertext_len = len;

    // 完成加密
    if (EVP_EncryptFinal_ex(ctx, ciphertext.data() + len, &len) <= 0) {
        EVP_CIPHER_CTX_free(ctx);
        return false;
    }
    ciphertext_len += len;

    // 获取tag
    std::vector<uint8_t> tag(16);
    if (EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, 16, tag.data()) <= 0) {
        EVP_CIPHER_CTX_free(ctx);
        return false;
    }

    // 调整密文大小并附加tag
    ciphertext.resize(ciphertext_len);
    ciphertext.insert(ciphertext.end(), tag.begin(), tag.end());

    EVP_CIPHER_CTX_free(ctx);
    return true;
}

// 使用AES-GCM解密
bool AuthManager::DecryptWithAESGCM(const std::vector<uint8_t> &ciphertext, const std::vector<uint8_t> &key,
                                    const std::vector<uint8_t> &nonce, std::vector<uint8_t> &plaintext)
{
    if (key.size() != 32 || (nonce.size() != 16 && nonce.size() != 12) || ciphertext.size() < 16) { // AES-256需要32字节密钥，至少16字节tag
        return false;
    }

    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    if (!ctx) {
        return false;
    }

    // 初始化解密操作
    if (EVP_DecryptInit_ex(ctx, EVP_aes_256_gcm(), nullptr, nullptr, nullptr) <= 0) {
        EVP_CIPHER_CTX_free(ctx);
        return false;
    }

    if (EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, nonce.size(), NULL) <= 0)
    {
        EVP_CIPHER_CTX_free(ctx);
        return false;
    }

    // 设置密钥和nonce
    if (EVP_DecryptInit_ex(ctx, nullptr, nullptr, key.data(), nonce.data()) <= 0) {
        EVP_CIPHER_CTX_free(ctx);
        return false;
    }

    // 分离密文和tag
    std::vector<uint8_t> encrypted_data(ciphertext.begin(), ciphertext.end() - 16);
    std::vector<uint8_t> tag(ciphertext.end() - 16, ciphertext.end());

    // 设置tag
    if (EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, 16, tag.data()) <= 0) {
        EVP_CIPHER_CTX_free(ctx);
        return false;
    }

    plaintext.resize(encrypted_data.size());
    int len = 0;
    int plaintext_len = 0;

    // 执行解密
    if (EVP_DecryptUpdate(ctx, plaintext.data(), &len, encrypted_data.data(),
                    static_cast<int>(encrypted_data.size())) <= 0) {
        EVP_CIPHER_CTX_free(ctx);
        return false;
    }
    plaintext_len = len;

    // 完成解密
    if (EVP_DecryptFinal_ex(ctx, plaintext.data() + len, &len) <= 0) {
        EVP_CIPHER_CTX_free(ctx);
        return false; // 验证失败
    }
    plaintext_len += len;

    // 调整明文大小
    plaintext.resize(plaintext_len);

    EVP_CIPHER_CTX_free(ctx);
    return true;
}

// 使用RSA加密
bool AuthManager::encryptWithRSA(const std::vector<uint8_t> &plaintext, struct evp_pkey_st *rsaKey, std::vector<uint8_t> &encrypted) {
    if (!rsaKey || plaintext.empty()) {
        return false;
    }

    EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new(rsaKey, nullptr);
    if (!ctx) {
        return false;
    }

    if (EVP_PKEY_encrypt_init(ctx) <= 0) {
        EVP_PKEY_CTX_free(ctx);
        return false;
    }

    // 设置OAEP填充
    if (EVP_PKEY_CTX_set_rsa_padding(ctx, RSA_PKCS1_OAEP_PADDING) <= 0) {
        EVP_PKEY_CTX_free(ctx);
        return false;
    }

    if (EVP_PKEY_CTX_set_rsa_oaep_md(ctx, EVP_sha256()) <= 0 && EVP_PKEY_CTX_set_rsa_mgf1_md(ctx, EVP_sha256()) <= 0)
    {
        EVP_PKEY_CTX_free(ctx);
        return false;
    }

    size_t outlen = 0;
    // 获取加密后数据的长度
    if (EVP_PKEY_encrypt(ctx, nullptr, &outlen, plaintext.data(),
                       plaintext.size()) <= 0) {
        EVP_PKEY_CTX_free(ctx);
        return false;
    }

    encrypted.resize(outlen);
    if (EVP_PKEY_encrypt(ctx, encrypted.data(), &outlen, plaintext.data(), plaintext.size()) <= 0) {
        EVP_PKEY_CTX_free(ctx);
        return false;
    }

    EVP_PKEY_CTX_free(ctx);

    // 调整大小到实际加密结果大小
    encrypted.resize(outlen);

    return true;
}

// 使用RSA解密
bool AuthManager::decryptWithRSA(const std::vector<uint8_t> &ciphertext, EVP_PKEY *rsaKey, std::vector<uint8_t> &decrypted)
{
    if (!rsaKeyPair || ciphertext.empty()) {
        return false;
    }

    EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new(rsaKey, nullptr);
    if (!ctx) {
        return false;
    }

    if (EVP_PKEY_decrypt_init(ctx) <= 0) {
        EVP_PKEY_CTX_free(ctx);
        return false;
    }

    // 设置OAEP填充
    if (EVP_PKEY_CTX_set_rsa_padding(ctx, RSA_PKCS1_OAEP_PADDING) <= 0) {
        EVP_PKEY_CTX_free(ctx);
        return false;
    }

    if (EVP_PKEY_CTX_set_rsa_oaep_md(ctx, EVP_sha256()) <= 0 && EVP_PKEY_CTX_set_rsa_mgf1_md(ctx, EVP_sha256()) <= 0)
    {
        EVP_PKEY_CTX_free(ctx);
        return false;
    }

    size_t outlen = 0;
    // 获取解密后数据的长度
    if (EVP_PKEY_decrypt(ctx, nullptr, &outlen, ciphertext.data(),
                       ciphertext.size()) <= 0) {
        EVP_PKEY_CTX_free(ctx);
        return false;
    }

    decrypted.resize(outlen);
    if (EVP_PKEY_decrypt(ctx, decrypted.data(), &outlen, ciphertext.data(), ciphertext.size()) <= 0) {
        EVP_PKEY_CTX_free(ctx);
        return false;
    }

    EVP_PKEY_CTX_free(ctx);

    // 调整大小到实际解密结果大小
    decrypted.resize(outlen);

    return true;
}

uint16_t AuthManager::GetDeviceId(int index)
{
    if (index * 2 > deviceHash.size()) {
        return 0;
    }
    return (deviceHash[index * 2 + 1] << 8) | deviceHash[index * 2];
}

bool AuthManager::EncryptWithRSA(const std::vector<uint8_t> &data, std::vector<uint8_t> &ciphertext)
{
    return encryptWithRSA(data, peerPublicKey, ciphertext);
}

bool AuthManager::DecryptWithRSA(const std::vector<uint8_t> &data, std::vector<uint8_t> &plaintext)
{
    return decryptWithRSA(data, rsaKeyPair, plaintext);
}

void AuthManager::GetByteSessionKey(std::vector<uint8_t> &sessionKey)
{
    sessionKey.clear();
    sessionKey.insert(sessionKey.end(), byteSessionKey.begin(), byteSessionKey.end());
}

void AuthManager::SetByteSessionKey(const std::vector<uint8_t> &sessionKey)
{
    byteSessionKey.clear();
    byteSessionKey.insert(byteSessionKey.end(), sessionKey.begin(), sessionKey.end());
}

void AuthManager::ClearByteSessionKey()
{
    byteSessionKey.clear();
}

void AuthManager::GetDFileSessionKey(std::vector<uint8_t> &sessionKey)
{
    sessionKey.clear();
    sessionKey.insert(sessionKey.end(), dFileSessionKey.begin(), dFileSessionKey.end());
}

void AuthManager::SetDFileSessionKey(const std::vector<uint8_t> &sessionKey)
{
    dFileSessionKey.clear();
    dFileSessionKey.insert(dFileSessionKey.end(), sessionKey.begin(), sessionKey.end());
}

void AuthManager::ClearDFileSessionKey()
{
    dFileSessionKey.clear();
}


////
////  HostDeviceManager.mm
////  MutualInfection
////
////  Created by Law on 2025/9/13.
////
//
//
//#include "HostDeviceManager.h"
//#include "DeviceManager.h"
//
//#include <iostream>
//#include <openssl/evp.h>
//#include <openssl/hmac.h>
//#include <openssl/pem.h>
//#include <openssl/rsa.h>
//#include <set>
//#include <string>
//#include <vector>
//#include <TargetConditionals.h>
//
//#ifdef __OBJC__
//    #if TARGET_OS_IOS
//        #import <UIKit/UIKit.h>
//    #elif TARGET_OS_MAC
//        #import <AppKit/AppKit.h>
//        #import <SystemConfiguration/SystemConfiguration.h>
//    #endif
//#endif
//
//HostDeviceManager::HostDeviceManager()
//{
//	InitHostDevice();
//}
//HostDeviceManager::~HostDeviceManager()
//{
//}
//HostDeviceManager &HostDeviceManager::shared()
//{
//	static HostDeviceManager instance;
//	return instance;
//}
//
//std::string HostDeviceManager::GetDeviceName()
//{
//#ifdef __OBJC__
//    #if TARGET_OS_IOS
//        // iOS 版本
//        UIDevice *device = [UIDevice currentDevice];
//        NSString *deviceName = device.name;
//    #elif TARGET_OS_MAC
//        // macOS 版本
//        NSString *deviceName = [[NSHost currentHost] localizedName];
//    #else
//        NSString *deviceName = @"Unknown Device";
//    #endif
//    
//    const char *cStringDeviceName = [deviceName UTF8String];
//    std::string deviceNameString(cStringDeviceName ? cStringDeviceName : "");
//    return deviceNameString;
//#else
//    return "";
//#endif
//}
//
////uint16_t HostDeviceManager::GetDeviceId(int index)
////{
////	if (index * 2 > hostDevice->deviceHash.size())
////	{
////		return 0;
////	}
////	return (hostDevice->deviceHash[index * 2 + 1] << 8) | hostDevice->deviceHash[index * 2];
////}
//
//std::vector<uint8_t> HostDeviceManager::GetDeviceHash()
//{
//	return hostDevice->deviceHash;
//}
//
////void HostDeviceManager::InitHostDevice()
////{
////	hostDevice = std::make_shared<Device>();
////	BuildDeviceHash();
////    std::string btNameString = GetDeviceName();
////    std::vector<uint8_t> btName(btNameString.begin(), btNameString.end());
////	hostDevice->btName = btName;
////}
//
//std::shared_ptr<Device> HostDeviceManager::GetHostDevice()
//{
//	return hostDevice;
//}
//
////void HostDeviceManager::BuildDeviceHash()
////{
////	EVP_PKEY *keyPair = nullptr;
////	bool hasFound = false;
////	std::vector<uint8_t> pubKey;
////	std::set<uint16_t> forbidUUIDs;
////	forbidUUIDs.insert(0xFE35);
////	forbidUUIDs.insert(0x903E);
////	forbidUUIDs.insert(0x0300);
////	while (!hasFound) {
////		keyPair = GenRsaKeyPair();
////		if (keyPair == nullptr) {
////			continue;
////		}
////		ExportPublicKey(keyPair, pubKey);
////		BuildHmac(pubKey, hostDevice->deviceHash);
////		if (forbidUUIDs.find(GetDeviceId(0)) == forbidUUIDs.end() && forbidUUIDs.find(GetDeviceId(1)) == forbidUUIDs.end() && forbidUUIDs.find(GetDeviceId(2)) == forbidUUIDs.end()) {
////			hasFound = true;
////			ImportPublicKey(hostDevice, pubKey);
////		} else {
////			// 修复内存泄漏：释放未使用的keyPair
////			EVP_PKEY_free(keyPair);
////		}
////	}
////}
//
//EVP_PKEY *HostDeviceManager::GenRsaKeyPair()
//{
//	// 创建EVP密钥上下文
//	EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new_id(EVP_PKEY_RSA, nullptr);
//	if (!ctx) {
//		return nullptr;
//	}
//
//	// 初始化密钥生成
//	if (EVP_PKEY_keygen_init(ctx) <= 0) {
//		EVP_PKEY_CTX_free(ctx);
//		return nullptr;
//	}
//
//	// 设置RSA密钥大小为2048位
//	if (EVP_PKEY_CTX_set_rsa_keygen_bits(ctx, 2048) <= 0) {
//		EVP_PKEY_CTX_free(ctx);
//		return nullptr;
//	}
//
//	// 生成密钥对
//	EVP_PKEY *keyPair = nullptr;
//	if (EVP_PKEY_keygen(ctx, &keyPair) <= 0) {
//		EVP_PKEY_CTX_free(ctx);
//		return nullptr;
//	}
//	EVP_PKEY_CTX_free(ctx);
//	return keyPair;
//}
//
//void HostDeviceManager::ExportPublicKey(EVP_PKEY *keyPair, std::vector<uint8_t> &pubKey)
//{
//	pubKey.clear();
//	if (keyPair == nullptr) {
//		return;
//	}
//
//	// 创建BIO内存结构
//	BIO *bio = BIO_new(BIO_s_mem());
//	if (!bio) {
//		return;
//	}
//
//	// 将公钥以PEM格式写入BIO
//	if (!PEM_write_bio_PUBKEY(bio, keyPair)) {
//		BIO_free(bio);
//		return;
//	}
//
//	// 获取BIO中的数据长度
//	int keylen = BIO_pending(bio);
//	if (keylen <= 0) {
//		BIO_free(bio);
//		return;
//	}
//
//	// 分配内存并读取数据
//	std::vector<uint8_t> tempKey(keylen);
//	BIO_read(bio, tempKey.data(), keylen);
//
//	// 释放BIO
//	BIO_free(bio);
//	convertPEMToDER(tempKey, pubKey);
//}
//
//void HostDeviceManager::BuildHmac(const std::vector<uint8_t> &pubKey, std::vector<uint8_t> &deviceHash)
//{
//	if (pubKey.empty()) {
//		return;
//	}
//	std::vector<uint8_t> hashKey(HASH_KEY_LEN);
//	memcpy(hashKey.data(), pubKey.data(), HASH_KEY_LEN);
//
//	HMAC_CTX *ctx = HMAC_CTX_new();
//	if (ctx == nullptr) {
//		return;
//	}
//
//	if (HMAC_CTX_reset(ctx) != 1) {
//		HMAC_CTX_free(ctx);
//		return;
//	}
//
//	if (HMAC_Init_ex(ctx, hashKey.data(), hashKey.size(), EVP_sha256(), nullptr) != 1) {
//		HMAC_CTX_free(ctx);
//		return;
//	}
//
//	if (HMAC_Update(ctx, pubKey.data(), pubKey.size()) != 1) {
//		HMAC_CTX_free(ctx);
//		return;
//	}
//	uint32_t outLen;
//	std::vector<uint8_t> resultHash(EVP_MAX_MD_SIZE);
//	if (HMAC_Final(ctx, resultHash.data(), &outLen) != 1) {
//		HMAC_CTX_free(ctx);
//		return;
//	}
//	HMAC_CTX_free(ctx);
//	if (resultHash.size() < HASH_LEN) {
//		return;
//	}
//	deviceHash.clear();
//	deviceHash.insert(deviceHash.end(), resultHash.begin(), resultHash.end());
//}
//
//void HostDeviceManager::GetSpecLenDeviceHash(std::shared_ptr<Device> device, std::vector<uint8_t> &deviceShortHash, size_t maxLen)
//{
//	deviceShortHash.clear();
//	size_t copied = maxLen;
//	if (device->deviceHash.size() < maxLen) {
//		copied = device->deviceHash.size();
//	}
//	deviceShortHash.insert(deviceShortHash.end(), device->deviceHash.begin(), device->deviceHash.begin() + copied);
//}
//
//bool HostDeviceManager::ImportPublicKey(std::shared_ptr<Device> device, const std::vector<uint8_t> &keyData)
//{
////	if (keyData.empty()) {
////		return false;
////	}
////
////	if (pubKey != nullptr) {
////		EVP_PKEY_free((EVP_PKEY *)pubKey);
////		pubKey = nullptr;
////	}
////
////	std::vector<uint8_t> pemKey;
////	convertDERToPEM(keyData, pemKey);
////
////	// 创建BIO内存结构
////	BIO *bio = BIO_new_mem_buf(pemKey.data(), static_cast<int>(pemKey.size()));
////	if (!bio) {
////		return false;
////	}
////
////	// 从BIO中读取公钥
////	device->pubKey = PEM_read_bio_PUBKEY(bio, nullptr, nullptr, nullptr);
////	BIO_free(bio);
////	if (device->pubKey == nullptr) {
////		return false;
////	}
//	return true;
//}
//
//void HostDeviceManager::convertPEMToDER(const std::vector<uint8_t> &pemKey, std::vector<uint8_t> &derKey)
//{
//	// 创建BIO内存结构
//	BIO *bio = BIO_new_mem_buf(pemKey.data(), static_cast<int>(pemKey.size()));
//	if (!bio) {
//		return;
//	}
//
//	// 从BIO中读取公钥
//	EVP_PKEY *pubKey = PEM_read_bio_PUBKEY(bio, nullptr, nullptr, nullptr);
//	BIO_free(bio);
//
//	// 创建内存BIO用于存储DER格式数据
//	BIO *derBio = BIO_new(BIO_s_mem());
//	if (!derBio) {
//		EVP_PKEY_free(pubKey);
//		return;
//	}
//
//	// 将公钥以DER格式写入BIO
//	if (!i2d_PUBKEY_bio(derBio, pubKey)) {
//		EVP_PKEY_free(pubKey);
//		BIO_free(derBio);
//		return;
//	}
//
//	// 获取BIO中的数据长度
//	int derLen = BIO_pending(derBio);
//	if (derLen <= 0) {
//		EVP_PKEY_free(pubKey);
//		BIO_free(derBio);
//		return;
//	}
//
//	// 分配内存并读取DER数据
//	derKey.resize(derLen);
//	BIO_read(derBio, derKey.data(), derLen);
//
//	// 清理资源
//	EVP_PKEY_free(pubKey);
//	BIO_free(derBio);
//}
//
//void HostDeviceManager::convertDERToPEM(const std::vector<uint8_t> &derKey, std::vector<uint8_t> &pemKey)
//{
//	// 使用d2i_PUBKEY函数将DER格式数据转换为EVP_PKEY结构
//	const unsigned char *p = derKey.data();
//	EVP_PKEY *pubKey = d2i_PUBKEY(NULL, &p, derKey.size());
//
//	// 创建内存BIO用于存储PEM格式数据
//	BIO *bio = BIO_new(BIO_s_mem());
//	if (!bio) {
//		EVP_PKEY_free(pubKey);
//		return;
//	}
//
//	// 将公钥以PEM格式写入BIO
//	if (!PEM_write_bio_PUBKEY(bio, pubKey)) {
//		EVP_PKEY_free(pubKey);
//		BIO_free(bio);
//		return;
//	}
//
//	// 获取BIO中的数据长度
//	int pemLen = BIO_pending(bio);
//	if (pemLen <= 0) {
//		EVP_PKEY_free(pubKey);
//		BIO_free(bio);
//		return;
//	}
//
//	// 分配内存并读取PEM数据
//	pemKey.resize(pemLen);
//	BIO_read(bio, pemKey.data(), pemLen);
//
//	// 清理资源
//	EVP_PKEY_free(pubKey);
//	BIO_free(bio);
//}

//
//  HostDeviceManager.h
//  MutualInfection
//
//  Created by Law on 2025/9/13.
//

#ifndef HOST_DEVICE_MANAGER_H
#define HOST_DEVICE_MANAGER_H

#ifdef __cplusplus

#include <iostream>
#include <openssl/evp.h>
#include "Device.h"

const size_t HASH_LEN = 20;
const size_t HASH_KEY_LEN = 16;

class HostDeviceManager
{
public:
	static HostDeviceManager &shared();

	//Getter
	std::shared_ptr<Device> GetHostDevice();
	std::string GetDeviceName();
	uint16_t GetDeviceId(int index);
	std::vector<uint8_t> GetDeviceHash();
	void *GetDeviceKeyPair();
	void *GetDevicePublicKey();
	std::vector<uint8_t> GetDeviceRandomKey();
	std::vector<uint8_t> GetDeviceAesGcmRandomKey();
	std::vector<uint8_t> GetDeviceSessionKey();

	//Utils
	void GetSpecLenDeviceHash(std::shared_ptr<Device> device, std::vector<uint8_t> &deviceShortHash, size_t maxLen);
	bool ImportPublicKey(std::shared_ptr<Device> device, const std::vector<uint8_t> &keyData);
	void convertPEMToDER(const std::vector<uint8_t> &pemKey, std::vector<uint8_t> &derKey);
	void convertDERToPEM(const std::vector<uint8_t> &derKey, std::vector<uint8_t> &pemKey);

private:
	HostDeviceManager();
	~HostDeviceManager();
	void InitHostDevice();
	void BuildDeviceHash();
	EVP_PKEY *GenRsaKeyPair();
	void ExportPublicKey(EVP_PKEY *keyPair, std::vector<uint8_t> &pubKey);
	void BuildHmac(const std::vector<uint8_t> &pubKey, std::vector<uint8_t> &deviceHash);
	std::shared_ptr<Device> hostDevice;
};
#endif // __cplusplus
#endif // HOST_DEVICE_MANAGER_H

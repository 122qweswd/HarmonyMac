//
//  MetaNodeSerializer.mm
//  MutualInfection
//
//  Created by Law on 2025/9/9.
//

#include "MetaNodeSerializer.h"

#include <iostream>
#include <openssl/rand.h>
#include <sstream>
#include <string>
#include <vector>

#include "ShareManager.h"
#include "Device.h"
#include "DeviceManager.h"
#include "json.hpp"
#include "LogHelper.h"

//获取单例实例
MetaNodeSerializer &MetaNodeSerializer::shared()
{
	static MetaNodeSerializer instance;
	return instance;
}

//构造函数
MetaNodeSerializer::MetaNodeSerializer()
{
	SetDeviceInfo();
}

//获取设备信息
DeviceInfo MetaNodeSerializer::GetDeviceInfo()
{
	return myDevice;
}

std::string MetaNodeSerializer::GenerateMetaNodeId()
{
	// 生成32字节的随机数据（64个十六进制字符）
	unsigned char randomBuffer[32];
	if (RAND_bytes(randomBuffer, 32) != 1) {
		std::cout << "Error generating MetaNodeId." << std::endl;
	}

	// 手动转换为十六进制字符串
	std::stringstream metaNodeId;
	metaNodeId << std::hex << std::setfill('0');

	for (int i = 0; i < 32; ++i) {
		metaNodeId << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(randomBuffer[i]);
	}
	return metaNodeId.str();
}

//生成nonce
std::vector<uint8_t> MetaNodeSerializer::GenerateRandomKey()
{
	std::vector<uint8_t> salt(16);
	if (RAND_bytes(salt.data(), static_cast<int>(salt.size())) != 1) {
		std::cout << "Error generating salt." << std::endl;
	}
	return salt;
}

//std::shared_ptr<Device> MetaNodeSerializer::GetLocalDevice()
//{
//    return DeviceManager::shared().getConnectDevice();
//}

//设置设备信息
void MetaNodeSerializer::SetDeviceInfo()
{
	std::string deviceName("iPhone");
	strncpy(myDevice.deviceName, deviceName.c_str(), deviceName.length());
	myDevice.deviceTypeId = 0x14;
	std::string metaNodeId = GenerateMetaNodeId();
	strncpy(myDevice.metaNodeId, metaNodeId.c_str(), metaNodeId.length());
	myDevice.flag = 100; //固定传100
}

bool MetaNodeSerializer::ParseDeviceInfo(const std::vector<uint8_t> &packet, DeviceInfo &devInfo)
{
    std::vector<uint8_t> payload;
    std::vector<uint8_t> salt;
    salt.insert(salt.end(), packet.begin(), packet.begin() + 12);
    payload.insert(payload.end(), packet.begin() + 12, packet.end());

	std::vector<uint8_t> jsonData;
    ShareManager::shared().DecryptWithAESGCM(payload, salt, jsonData);
	std::string json(jsonData.begin(), jsonData.end());
    memset(&devInfo, 0, sizeof(DeviceInfo));
	return ParseDeviceInfoJson(json, devInfo);
}

//解析设备信息JSON字符串
bool MetaNodeSerializer::ParseDeviceInfoJson(std::string json, DeviceInfo &devInfo)
{
	if (!nlohmann::json::accept(json)) {
		LOG_ERROR_S("json is not json.");
		return false;
	}
	nlohmann::json j = nlohmann::json::parse(json);
	if (!j.contains(HA_DEVICE_NAME) || !j[HA_DEVICE_NAME].is_string() || !j.contains(HA_DEVICE_TYPE_ID) || !j[HA_DEVICE_TYPE_ID].is_number() || !j.contains(HA_META_NODE_ID) || !j[HA_META_NODE_ID].is_string() || !j.contains(HA_FLAG) || !j[HA_FLAG].is_number()) {
		std::cout << "json format error." << std::endl;
		return false;
	}
	std::string deviceName = j[HA_DEVICE_NAME].get<std::string>();
	strncpy(devInfo.deviceName, deviceName.c_str(),deviceName.length());
	devInfo.deviceTypeId = j[HA_DEVICE_TYPE_ID].get<int>();
	std::string metaNodeId = j[HA_META_NODE_ID].get<std::string>();
	strncpy(devInfo.metaNodeId, metaNodeId.c_str(),metaNodeId.length());
	devInfo.flag = j[HA_FLAG].get<int>();
	return true;
}

//创建设备信息JSON字符串
std::string MetaNodeSerializer::CreateDeviceInfoJson()
{
	auto deviceInfo = MetaNodeSerializer::shared().GetDeviceInfo();

	// 创建设备信息JSON
	nlohmann::json jsValue;
	jsValue[HA_DEVICE_NAME] = deviceInfo.deviceName;
	// jsValue[HA_DEVICE_NAME] = "iPhone 16"; // TODO: User for test
	jsValue[HA_DEVICE_TYPE_ID] = deviceInfo.deviceTypeId;
	jsValue[HA_META_NODE_ID] = deviceInfo.metaNodeId;
	jsValue[HA_FLAG] = deviceInfo.flag;
	std::string deviceJson = jsValue.dump();
	return deviceJson;
}

bool MetaNodeSerializer::CreateDeviceInfo(std::vector<uint8_t> &payload)
{
	std::string deviceJson = CreateDeviceInfoJson();
	std::vector<uint8_t> jsonData(deviceJson.begin(), deviceJson.end());
    
    std::vector<uint8_t> salt;
    salt.resize(12);
    RAND_bytes(salt.data(), salt.size());
    ShareManager::shared().EncryptWithAESGCM(jsonData, salt, payload);
    payload.insert(payload.begin(), salt.begin(), salt.end());
	return true;
}

//解析ACK
bool MetaNodeSerializer::ParseAck(const std::vector<uint8_t> &packet)
{
    std::vector<uint8_t> payload;
    std::vector<uint8_t> salt;
    salt.insert(salt.end(), packet.begin(), packet.begin() + 12);
    payload.insert(payload.end(), packet.begin() + 12, packet.end());

	std::vector<uint8_t> ackData;
    ShareManager::shared().DecryptWithAESGCM(payload, salt, ackData);
	std::string ackStr(ackData.begin(), ackData.end() - 1);
	if (ackStr != META_DEVICE_INFO_ACK) {
        LOG_ERROR_S("Join Metanode ACK error");
		return false;
	}
	return true;
}

//创建ACK
bool MetaNodeSerializer::CreateAck(std::vector<uint8_t> &payload)
{
    std::vector<uint8_t> salt;
    salt.resize(12);
    RAND_bytes(salt.data(), salt.size());

	std::string ackStr = META_DEVICE_INFO_ACK;
	std::vector<uint8_t> ackData(ackStr.begin(), ackStr.end());
    ackData.resize(ackData.size() + 1);
    ShareManager::shared().EncryptWithAESGCM(ackData, salt, payload);
    payload.insert(payload.begin(), salt.begin(), salt.end());
	return true;
}

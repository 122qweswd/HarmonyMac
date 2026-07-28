//
//  DeviceManager.mm
//  MutualInfection
//
//  Created by apple on 2025/9/3.
//

#include "DeviceManager.h"
#include "Common.h"
#include "AuthManager.h"
#include "LogHelper.h"
#include "DelegateManager.h"
#include <iomanip>
#include <algorithm>

DeviceManager::DeviceManager()
{
    timerQueue.start();
}

DeviceManager::~DeviceManager()
{
    timerQueue.stop();
}

DeviceManager &DeviceManager::shared()
{
    static DeviceManager manager;
    return manager;
}

std::shared_ptr<Device> DeviceManager::getDevice(uint64_t deviceId)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
	if (deviceList.empty()) {
		auto device = std::make_shared<Device>();
		deviceList.emplace(0, device);
	}
    auto it = deviceList.find(deviceId);
    if (it == deviceList.end()) {
        return nullptr;
    }
    return it->second;
}

void DeviceManager::addDevice(uint64_t deviceId, std::shared_ptr<Device> device)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    auto it = deviceList.find(deviceId);
    if (it != deviceList.end()) {
        it->second = device;
    } else {
        deviceList.emplace(deviceId, device);
    }
}

void DeviceManager::updateDevice(uint64_t deviceId, std::shared_ptr<Device> device)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    auto it = deviceList.find(deviceId);
    if (it != deviceList.end()) {
        updateBLEDevice(it->second, device);
    }
}

void DeviceManager::updateBLEDevice(std::shared_ptr<Device>& destDevice, std::shared_ptr<Device> srcDevice)
{
    destDevice->foundType |= 0x01;
    destDevice->deviceId = srcDevice->deviceId;
    destDevice->uuid = srcDevice->uuid;
    destDevice->version = srcDevice->version;
    destDevice->type = srcDevice->type;
    destDevice->feature = srcDevice->feature;
    destDevice->extFeature = srcDevice->extFeature;
    destDevice->isSupportIOS = srcDevice->isSupportIOS;
    destDevice->isShowIcon = srcDevice->isShowIcon;
    destDevice->updateTime = srcDevice->updateTime;

    if (!srcDevice->deviceKey.empty()) {
        destDevice->deviceKey = srcDevice->deviceKey;
    }
    
    if (!srcDevice->hwContactId.empty()) {
        destDevice->hwContactId = srcDevice->hwContactId;
    }
    
    if (!srcDevice->nickName.empty()) {
        destDevice->nickName = srcDevice->nickName;
    }
    
    if (!srcDevice->btName.empty()) {
        destDevice->btName = srcDevice->btName;
    }
    
    if (!srcDevice->apMac.empty()) {
        destDevice->apMac = srcDevice->apMac;
    }
    
    if (!srcDevice->buildLink.empty()) {
        destDevice->buildLink = srcDevice->buildLink;
    }
    
    if (!srcDevice->deviceHash.empty()) {
        destDevice->deviceHash = srcDevice->deviceHash;
    }
}

void DeviceManager::updateDeviceTime(uint64_t deviceId)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    auto it = deviceList.find(deviceId);
    if (it != deviceList.end()) {
        auto now = std::chrono::system_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch());
        it->second->updateTime = static_cast<uint64_t>(duration.count());
        UpdateDeviceList();
    }
}

void DeviceManager::updateCoapDevice(uint64_t deviceId, device_info_t info)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    auto it = deviceList.find(deviceId);
    if (it != deviceList.end()) {
        it->second->foundType |= 0x02;
        it->second->info = info;
    }
}

void DeviceManager::addCoapDevice(std::string udid, device_info_t& info)
{
    std::lock_guard<std::recursive_mutex> lock(coapListMutex);
    auto it = coapDeviceList.find(udid);
    if (it != coapDeviceList.end()) {
        it->second = info;
    } else {
        coapDeviceList.emplace(udid, info);
    }
}

bool DeviceManager::hasDevice(uint64_t deviceId)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    if (deviceList.find(deviceId) == deviceList.end()) {
        return false;
    }
    return true;
}

bool DeviceManager::hasCoapDevice(std::string udid)
{
    std::lock_guard<std::recursive_mutex> lock(coapListMutex);
    if (coapDeviceList.find(udid) == coapDeviceList.end()) {
        return false;
    }
    return true;
}

bool DeviceManager::hasCoapDevice(uint64_t deviceId)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    auto it = deviceList.find(deviceId);
    if (it == deviceList.end()) {
        return false;
    }
    if (it->second->foundType & 0x02) {
        it->second->foundType &= 0xFE;
        return true;
    }
    return false;
}

std::string DeviceManager::GetHashStringUDID(std::string udid)
{
    if (udid.length() <= 6) {
        std::lock_guard<std::recursive_mutex> lock(mutex);
        std::transform(udid.begin(), udid.end(), udid.begin(), [](unsigned char c) {
            return std::toupper(c);
        });
        for (auto & device : deviceList) {
            char temp[32] = { 0 };
            snprintf(temp, sizeof(temp) - 1, "%llX", device.first);
            std::string fullDeviceId = temp;
            if (fullDeviceId.find(udid) != std::string::npos) {
                return fullDeviceId;
            }
        }
    }
    AuthManager am;
    char hashResult[32] = {0};
    am.StrHas((unsigned char*)(udid.c_str()), static_cast<uint32_t>(udid.length()), (unsigned char*)hashResult);
    char coapDeviceId[96] = {0};
    BytesToHExString(coapDeviceId, 96, (unsigned char*)hashResult, 32);
    std::string strDeviceId(coapDeviceId);
//    LOG_DEBUG_S("coap h device udid is %s", strDeviceId.c_str());
    return strDeviceId;
}

bool DeviceManager::hasDevice(std::string udid, uint64_t& deviceId, std::string& hashDeviceId)
{
    std::string hashUDID = GetHashStringUDID(udid);
    if (hashUDID.empty()) {
        return false;
    }
    hashDeviceId = hashUDID.substr(0,16);
    if (hashDeviceId.empty() || hashDeviceId.length() < 16) {
        return false;
    }
    deviceId = strtoull(hashDeviceId.c_str(), nullptr, 16);
    std::lock_guard<std::recursive_mutex> lock(mutex);
    if (deviceList.find(deviceId) == deviceList.end()) {
        return false;
    }
    return true;
}

void DeviceManager::removeDevice(uint64_t deviceId)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    auto it = deviceList.find(deviceId);
    if (it != deviceList.end()) {
        deviceList.erase(it);
    }
}

void DeviceManager::removeCoapDevice(std::string udid)
{
    std::lock_guard<std::recursive_mutex> lock(coapListMutex);
    auto it = coapDeviceList.find(udid);
    if (it != coapDeviceList.end()) {
        coapDeviceList.erase(it);
    }
}

uint32_t DeviceManager::count() const
{
    return static_cast<uint32_t>(deviceList.size());
}

uint32_t DeviceManager::coapCount() const
{
    return static_cast<uint32_t>(coapDeviceList.size());
}

uint64_t DeviceManager::getDisconnectDevices(uint64_t nowTime, std::vector<uint64_t> &removedList)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    uint64_t oldestTime = -1;
    for (auto &item : deviceList) {
        if (item.first == shareDeviceId) {
            continue;
        }
        if (item.second->updateTime + 5 * 1000 < nowTime) {
            if (item.second->foundType & 0x02) {
                item.second->foundType &= 0xFE;
                item.second->btName.clear();
                continue;
            }
            removedList.emplace_back(item.second->deviceId);
            continue;
        }
        if (item.second->updateTime < oldestTime) {
            oldestTime = item.second->updateTime;
        }
    }
    for (auto &removeId : removedList) {
        deviceList.erase(removeId);
    }
    return oldestTime;
}

void DeviceManager::checkCoapDevice(uint64_t timeNow, std::vector<uint64_t> &removedList)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    for (auto &item : deviceList) {
        if (!(item.second->foundType & 0x02)) {
            continue;
        }
        if (item.second->info.updateTime + 5 * 1000 < timeNow) {
            if (item.second->foundType & 0x01) {
                item.second->foundType &= 0xFD;
                continue;
            }
            removedList.emplace_back(item.first);
            continue;
        }
    }
    for (auto &removeId : removedList) {
        deviceList.erase(removeId);
    }
}

uint64_t DeviceManager::getCoapDisconnectDevices(uint64_t nowTime, std::vector<uint64_t> &removedList)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    uint64_t oldestTime = -1;
    for (auto &item : deviceList) {
        if (item.first == shareDeviceId) {
            continue;
        }

        if (!(item.second->foundType & 0x02)) {
            continue;
        }
        if (item.second->info.updateTime + 5 * 1000 < nowTime) {
            if (item.second->foundType & 0x01) {
                item.second->foundType &= 0xFD;
                continue;
            }
            removedList.emplace_back(item.first);
            continue;
        }
        if (item.second->info.updateTime < oldestTime) {
            oldestTime = item.second->info.updateTime;
        }
    }
    for (auto &removeId : removedList) {
        deviceList.erase(removeId);
    }
    return oldestTime;
}


void DeviceManager::SetShareDevice(const std::string &udid)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    if (udid != "") {
        shareDeviceId = strtoull(udid.c_str(), nullptr, 16);
    } else {
        auto now = std::chrono::system_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch());
        if (deviceList.find(shareDeviceId) != deviceList.end()) {
            deviceList[shareDeviceId]->updateTime = static_cast<uint64_t>(duration.count());
            shareDeviceId = 0;
            UpdateDeviceList();
        }
    }
}

std::string DeviceManager::GetDeviceUUID(const std::string &udid)
{
    uint64_t deviceId = strtoull(udid.c_str(), nullptr, 16);
    return GetDeviceUUID(deviceId);
}

std::string DeviceManager::GetDeviceUUID(uint64_t deviceId)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    auto it = deviceList.find(deviceId);
    if (it != deviceList.end()) {
        return it->second->uuid;
    }
    return "";
}

std::string DeviceManager::GetDeviceUDID(const std::string &uuid)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    for (auto &item : deviceList) {
        if (item.second->uuid == uuid) {
            char temp[32] = { 0 };
            snprintf(temp, sizeof(temp) - 1, "%016llX", item.first);
            return temp;
        }
    }
    return "";
}

bool DeviceManager::getDeviceInfoByUdid(std::string udid, device_info_t& info)
{
    if (udid.empty()) {
        return false;
    }
    for (auto &it:coapDeviceList) {
        std::string udidHash = GetHashStringUDID(it.first);
        if (udidHash.find(udid) != std::string::npos) {
            info = it.second;
            return true;
        }
    }
    return false;
}

void DeviceManager::UpdateDeviceList()
{
    if (deviceAgingTimer >= 0) {
        timerQueue.cancelTask(deviceAgingTimer);
        deviceAgingTimer = -1;
    }
    auto now = std::chrono::system_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch());
    uint64_t nowTime = static_cast<uint64_t>(duration.count());
    std::vector<uint64_t> removedList;
    uint64_t oldestTime = getDisconnectDevices(nowTime, removedList);
    
    DelegateManager *delegateMgr = [DelegateManager shared];
    for (auto &removeId : removedList) {
        if ([delegateMgr.deviceDelegate respondsToSelector:@selector(didDeviceLost:)]) {
            char temp[32] = { 0 };
            snprintf(temp, sizeof(temp) - 1, "%016llX", removeId);
            NSString *udid = [NSString stringWithUTF8String:temp];
            [delegateMgr.deviceDelegate didDeviceLost:udid];
        }
    }
    if (DeviceManager::shared().count() > 0) {
        int interval = oldestTime + 5.0 * 1000 - nowTime;
        // 确保interval不为负数，避免计时器立即触发导致循环
        if (interval < 0) {
            interval = 1000; // 设置最小间隔为1秒
        }
        deviceAgingTimer = timerQueue.addTask(interval, 1, DeviceManager::DeviceAgingTimeout);
    }
}

void DeviceManager::DeviceAgingTimeout()
{
    dispatch_sync(dispatch_get_main_queue(), ^{
        LOG_DEBUG_S("invoke device aging by timer start: %zu", DeviceManager::shared().deviceList.size());
        if (DeviceManager::shared().deviceAgingTimer >= 0) {
            DeviceManager::shared().deviceAgingTimer = -1;
            DeviceManager::shared().UpdateDeviceList();
        }
        LOG_DEBUG_S("invoke device aging by timer end: %zu", DeviceManager::shared().deviceList.size());
    });
}

std::string DeviceManager::getHwidStr(const std::vector<uint8_t> &hwid)
{
    std::stringstream hexStream;
    hexStream << std::hex << std::setfill('0');
    for (uint8_t byte: hwid) {
        hexStream << std::setw(2) << static_cast<unsigned>(byte);
    }
    return hexStream.str();
}

void DeviceManager::SwitchToBackground()
{
    LOG_DEBUG_S("deviceAgingTimer: %d", deviceAgingTimer);
    if (deviceAgingTimer >= 0) {
        LOG_DEBUG_S("AgingTimer cancelled");
        timerQueue.cancelTask(deviceAgingTimer);
        deviceAgingTimer = -1;
    }
}

void DeviceManager::SwitchToForeground()
{
    if (deviceAgingTimer >= 0) {
        LOG_DEBUG_S("AgingTimer restart");
        timerQueue.cancelTask(deviceAgingTimer);
        deviceAgingTimer = -1;
    }
    if (DeviceManager::shared().count() > 0) {
        deviceAgingTimer = timerQueue.addTask(5000, 1, DeviceManager::DeviceAgingTimeout);
    }
}

void DeviceManager::lostCoapDevice(std::vector<uint64_t> &removedList)
{
    std::lock_guard<std::recursive_mutex> lock(mutex);
    for (auto &item : deviceList) {
        if (!(item.second->foundType & 0x01)) {
            removedList.emplace_back(item.first);
        } else {
            item.second->foundType &= 0xFD;
        }
    }
    for (auto &removeId : removedList) {
        deviceList.erase(removeId);
    }
}

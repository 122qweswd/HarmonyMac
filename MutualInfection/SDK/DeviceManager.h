//
//  DeviceManager.h
//  MutualInfection
//
//  Created by apple on 2025/9/3.
//

#ifndef DEVICE_MANAGER_H
#define DEVICE_MANAGER_H

#include <map>
#include <memory>
#include "Device.h"
#include "Timer.h"

class DeviceManager
{
public:
    static DeviceManager &shared();
    std::shared_ptr<Device> getDevice(uint64_t deviceId);
    void addDevice(uint64_t deviceId, std::shared_ptr<Device> device);
    void addCoapDevice(std::string udid, device_info_t& info);
    void updateDevice(uint64_t deviceId, std::shared_ptr<Device> device);
    void updateCoapDevice(uint64_t deviceId, device_info_t info);
    void updateBLEDevice(std::shared_ptr<Device>& destDevice, std::shared_ptr<Device> srcDevice);
    void updateDeviceTime(uint64_t deviceId);
    bool hasDevice(uint64_t deviceId);
    bool hasCoapDevice(std::string udid);
    bool hasCoapDevice(uint64_t deviceId);
    bool hasDevice(std::string udid, uint64_t& deviceId, std::string& hashDeviceId);
    void removeDevice(uint64_t deviceId);
    void removeCoapDevice(std::string udid);
    bool getDeviceInfoByUdid(std::string udid, device_info_t& info);
    uint32_t count() const;
    uint32_t coapCount() const;
    uint64_t getDisconnectDevices(uint64_t timeNow, std::vector<uint64_t> &removedList);
    uint64_t getCoapDisconnectDevices(uint64_t timeNow, std::vector<uint64_t> &removedList);
    void checkCoapDevice(uint64_t timeNow, std::vector<uint64_t> &removedList);
    void SetShareDevice(const std::string &udid);
    std::string GetDeviceUUID(const std::string &udid);
    std::string GetDeviceUUID(uint64_t deviceId);
    std::string GetDeviceUDID(const std::string &uuid);
    std::string GetHashStringUDID(std::string udid);
    void UpdateDeviceList();
    std::string getHwidStr(const std::vector<uint8_t> &hwid);
    void SwitchToBackground();
    void SwitchToForeground();
    void lostCoapDevice(std::vector<uint64_t> &removedList);

protected:
    DeviceManager();
    ~DeviceManager();
    static void DeviceAgingTimeout();
    
private:
    std::recursive_mutex mutex;
    std::recursive_mutex coapListMutex;
    uint64_t shareDeviceId { 0 };
    std::map<uint64_t, std::shared_ptr<Device>> deviceList;
    std::map<std::string, device_info_t> coapDeviceList;
    std::shared_ptr<Device> currentDevice { nullptr };
    TimerQueue timerQueue;
    int deviceAgingTimer { -1 };
};

#endif // DEVICE_MANAGER_H

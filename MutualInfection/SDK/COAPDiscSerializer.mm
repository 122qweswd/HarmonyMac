//
//  COAPDiscSerializer.mm
//  Service
//
//  Created by apple on 2025/8/28.
//
#include "COAPDiscSerializer.hpp"
#include <arpa/inet.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#ifdef __OBJC__
    #if TARGET_OS_IOS
        #import <UIKit/UIKit.h>
    #elif TARGET_OS_MAC
        #import <AppKit/AppKit.h>
        #import <SystemConfiguration/SystemConfiguration.h>
    #endif
#endif
#include "json.hpp"
#include <string>
#include <thread>
#include <SystemConfiguration/SystemConfiguration.h>
#include <netdb.h>
#include "Common.h"
#include "LogHelper.h"
#include "DeviceManager.h"
#include "DelegateManager.h"
#include "ShareManager.h"
#include "StringParse.h"
#define DFINDER_COAP_ACK_TIMEOUT ((coap_fixed_point_t){1, 0}) // 1 seconds
#define DFINDER_COAP_ACK_RANDOM_FACTOR ((coap_fixed_point_t){1, 200}) // 1.2
#define DFINDER_COAP_MAX_RETRANSMIT_TIMES 2 // retransmit 2 times for CON packets
#define NSTACKX_MAX_IP_STRING_LEN                 46
#define INTERFACE_MAX 16
#define SIOCGIFCONF     _IOWR('i', 36, struct ifconf)   /* get ifnet list */
#define NSTACKX_IPV6_MULTICAST_ADDR "FF02::1"
std::recursive_mutex resMutex;
static uint16_t seqNo = 0;
static int sendBroadcastCnt = 0;
COAPDiscSerializer* COAPDiscSerializer::GetInstance()
{
    static COAPDiscSerializer instance;
    return &instance;
}

device_info_t COAPDiscSerializer::GetDeviceInfo()
{
    std::lock_guard<std::recursive_mutex> lock(resMutex);
    return my_device;
}

void COAPDiscSerializer::CreateServiceThread()
{
    std::lock_guard<std::recursive_mutex> lock(apiMutex);
    if (thread_ != nullptr) {
        return;
    }
    {
        std::lock_guard<std::recursive_mutex> lock(serviceResMutex);
        isStartService = true;
        coap_startup();
    }
    thread_ = std::make_shared<std::thread>(&COAPDiscSerializer::StartService, this);
    LOG_DEBUG_S("satrt coap service");
}

void COAPDiscSerializer::CreateClientThread()
{
    std::lock_guard<std::recursive_mutex> lock(apiMutex);
    if (clientTaskId >= 0) {
        LOG_DEBUG_S("timer is exist, clientTaskId is %d", clientTaskId);
        return;
    }
    clientTaskId = timerQueue.addTask(200, 0, &COAPDiscSerializer::StartScan);
    LOG_DEBUG_S("start coap scan, taskId is %d", clientTaskId);
}

// 处理发现请求的回调函数
void COAPDiscSerializer::handle_discovery(coap_resource_t *resource,
                     coap_session_t *session,
                     const coap_pdu_t *request,
                     const coap_string_t *query,
                     coap_pdu_t *response)
{
    if (COAPDiscSerializer::GetInstance()->GetSpeedMode()) {
        return;
    }

    if (request == nullptr) {
        LOG_DEBUG_S("pdu is null");
        return;
    }
    
    if (coap_pdu_get_code(request) != COAP_REQUEST_CODE_POST) {
        LOG_DEBUG_S("pdu is not get request");
        return;
    }
    
    // 取 payload
    const uint8_t* payload = nullptr;
    size_t payload_len = 0;
    if (!coap_get_data(request, &payload_len, &payload) || payload_len < 0) {
        LOG_DEBUG_S("payload is null");
        return;
    }
    // 把 payload 转成 string
    std::string payload_str(reinterpret_cast<const char*>(payload), payload_len);
    
    device_info_t info;
    memset(&info, 0, sizeof(device_info_t));
    bool isBoardcast = false;
    if (!COAPDiscSerializer::GetInstance()->ParseCoapRespone(payload_str, info, isBoardcast)) {
        return;
    }

    if (!isBoardcast) {
        uint64_t deviceId = 0;
        std::string hashDeviceId = "";
        auto delegateMgr = [DelegateManager shared];
        if (!DeviceManager::shared().hasDevice(info.udid, deviceId, hashDeviceId) && [delegateMgr.deviceDelegate respondsToSelector:@selector(didDeviceFound:device:)]) {
            auto startScanTime = COAPDiscSerializer::GetInstance()->GetStartScanTime();
            std::string anoName = AnonymizeString(info.devicename);
            LOG_DEBUG_S("coap discover new device: %s, discover start: %lld, discover end: %lld, elapsed time: %lldms",
                        anoName.c_str(), startScanTime,
                        info.updateTime, info.updateTime - startScanTime);
            auto delegateMgr = [DelegateManager shared];
            auto device = std::make_shared<Device>();
            device->deviceId = deviceId;
            device->foundType |= 0x02;
            device->info = info;
            if (!hashDeviceId.empty() && deviceId != 0) {
                NSMutableDictionary *deviceInfo = [NSMutableDictionary dictionary];
                char temp[32] = { 0 };
                snprintf(temp, sizeof(temp) - 1, "%016llX", deviceId);
                NSString *udid = [NSString stringWithUTF8String:temp];
                NSString *name = [NSString stringWithUTF8String:info.devicename];
                BOOL isShowIcon = device->isShowIcon;
                int deviceType = info.type;
                NSString *hwid = @"";
                if (!device->hwContactId.empty()) {
                    std::string hwidString = DeviceManager::shared().getHwidStr(device->hwContactId);
                    hwid = [NSString stringWithUTF8String:hwidString.c_str()];
                }
                [deviceInfo setValue:udid forKey:@"udid"];
                [deviceInfo setValue:name forKey:@"name"];
                [deviceInfo setValue:[NSDate date] forKey:@"timestamp"];
                [deviceInfo setValue:@(isShowIcon) forKey:@"icon"];
                [deviceInfo setValue:hwid forKey:@"hwid"];
                [deviceInfo setValue:@(deviceType) forKey:@"deviceType"];
                [delegateMgr.deviceDelegate didDeviceFound:udid device:deviceInfo];
            }
            DeviceManager::shared().addDevice(deviceId, device);
        } else {
            auto oldDevice = DeviceManager::shared().getDevice(deviceId);
            if (!hashDeviceId.empty() && oldDevice != nullptr) {
                NSMutableDictionary *deviceInfo = [NSMutableDictionary dictionary];
                char temp[32] = { 0 };
                snprintf(temp, sizeof(temp) - 1, "%016llX", deviceId);
                BOOL isShowIcon = oldDevice->isShowIcon;
                int deviceType = info.type;
                NSString *hwid = @"";
                if (!oldDevice->hwContactId.empty()) {
                    std::string hwidString = DeviceManager::shared().getHwidStr(oldDevice->hwContactId);
                    hwid = [NSString stringWithUTF8String:hwidString.c_str()];
                }
                NSString *udid = [NSString stringWithUTF8String:temp];
                NSString *name = [NSString stringWithUTF8String:info.devicename];
                [deviceInfo setValue:udid forKey:@"udid"];
                [deviceInfo setValue:name forKey:@"name"];
                [deviceInfo setValue:[NSDate date] forKey:@"timestamp"];
                [deviceInfo setValue:@(isShowIcon) forKey:@"icon"];
                [deviceInfo setValue:hwid forKey:@"hwid"];
                [deviceInfo setValue:@(deviceType) forKey:@"deviceType"];
                if ([delegateMgr.deviceDelegate respondsToSelector:@selector(didDeviceUpdate:device:)]) {
                    [delegateMgr.deviceDelegate didDeviceUpdate:udid device:deviceInfo];
                }
            }
            DeviceManager::shared().updateCoapDevice(deviceId, info);
        }
        COAPDiscSerializer::GetInstance()->TimeAction(info);
        return;
    }
    COAPDiscSerializer::GetInstance()->SendUnicastResponse(session, info, request, isBoardcast);
    return;
}

// 设备发现回调函数
enum coap_response_t COAPDiscSerializer::discovery_callback(coap_session_t *session,
                       const coap_pdu_t *sent,
                       const coap_pdu_t *received,
                       const coap_mid_t mid)
{
    // 检查是否有数据

    auto messageId = coap_pdu_get_mid(received);
    coap_pdu_type_t type = coap_pdu_get_type(received);
    coap_pdu_code_t code = coap_pdu_get_code(received);

    if (type == COAP_MESSAGE_CON) {
        // 创建ACK响应
        coap_pdu_t *ack = coap_pdu_init(COAP_MESSAGE_ACK, code, messageId, coap_session_max_pdu_size(session));
        
        if (!ack) {
            LOG_ERROR_S("Failed to create ACK PDU");
            return COAP_RESPONSE_FAIL;
        }
        
        // 发送ACK
        coap_send(session, ack);
        LOG_DEBUG_S("Sent ACK for CON message");
    }
    return COAP_RESPONSE_OK;
}

void COAPDiscSerializer::StartService()
{
    if (!serviceCtx) {
        const char* localPort = "5684";
        const char* addrStr = "0.0.0.0";
        serviceCtx = CoapGetContextEx(addrStr, localPort, AF_INET);
        if (!serviceCtx) {
            LOG_ERROR_S("Failed to create context");
            return;
        }
    }

    // 创建设备发现资源
    coap_str_const_t *discovery_uri = coap_make_str_const("device_discover");
    coap_resource_t *discovery_resource = coap_resource_init(discovery_uri, 0);
    coap_register_request_handler(discovery_resource, COAP_REQUEST_POST, handle_discovery);
    coap_resource_set_get_observable(discovery_resource, 1);
    coap_add_resource(serviceCtx, discovery_resource);
    LOG_DEBUG_S("Waiting for discovery requests...");
    while (COAPDiscSerializer::GetInstance()->GetServiceStatus()) {
        coap_io_process(serviceCtx, 100);
    }
    return;
}

coap_context_t *COAPDiscSerializer::GetClientCtx()
{
    if (clientCtx == nullptr) {
        clientCtx = coap_new_context(NULL);
    }
    return clientCtx;
}

void COAPDiscSerializer::StartScan()
{
    if (!COAPDiscSerializer::GetInstance()->IsNeedScan()) {
        return;
    }
    sendBroadcastCnt++;
    if (sendBroadcastCnt >= 10) {
        sendBroadcastCnt = 0;
        if (seqNo >= 0xFFFF) {
            seqNo = 0;
        }
        seqNo++;
    }
    coap_address_t dest_addr;
    coap_session_t *session = nullptr;
    coap_pdu_t *pdu;
    auto info = COAPDiscSerializer::GetInstance()->GetDeviceInfo();
    if (info.broadcastIp[0] == '\0' || info.wlanIp[0] == '\0') {
        LOG_ERROR_S("wlan ip is empty");
        return;
    }
    // 创建 CoAP 上下文
    std::lock_guard<std::recursive_mutex> lock(resMutex);
    coap_context_t * ctx = COAPDiscSerializer::GetInstance()->GetClientCtx();
    if (!ctx) {
        LOG_ERROR_S("Failed to create context");
        coap_cleanup();
        return;
    }
    // 设置目标地址（多播地址）
    coap_address_init(&dest_addr);
    dest_addr.addr.sin.sin_family = AF_INET;
    dest_addr.addr.sin.sin_port = htons(5684);
    inet_pton(AF_INET, info.broadcastIp, &dest_addr.addr.sin.sin_addr);
    dest_addr.size = sizeof(struct sockaddr_in);
    session = COAPDiscSerializer::GetInstance()->CoapGetSessionEx(ctx, &dest_addr);
    if (session == nullptr) {
        LOG_ERROR_S("Failed to get session, errno:%d, desc:%s", errno, strerror(errno));
        return;
    }

    // 创建发现请求PDU - 标准发现资源
    auto msgId = COAPDiscSerializer::GetInstance()->GetMessageId();
    pdu = coap_pdu_init(COAP_MESSAGE_NON, COAP_REQUEST_CODE_POST, msgId, coap_session_max_pdu_size(session));
    if (!pdu) {
        LOG_ERROR_S("Failed to create PDU, errno:%d, desc:%s", errno, strerror(errno));
        coap_session_release(session);
        return;
    }
    
    // 设置URI路径：device_discover
    coap_add_option(pdu, COAP_OPTION_URI_PATH, 15, (const uint8_t *)"device_discover");
    std::string request = COAPDiscSerializer::GetInstance()->CreateJsonRequest(true);
    coap_add_option(pdu, COAP_OPTION_URI_HOST, strlen(info.broadcastIp), (const uint8_t *)(info.broadcastIp));
    coap_add_data(pdu, request.length() + 1, (const uint8_t *)request.c_str());

    // 发送请求
    int32_t res = coap_send(session, pdu);
    if (res == COAP_INVALID_MID) {
        LOG_ERROR_S("coap send failed, errno:%d, desc:%s", errno, strerror(errno));
        coap_session_release(session);
        COAPDiscSerializer::GetInstance()->ReleaseClientCtx();
        return;
    }
    coap_session_release(session);
    return;
}

coap_mid_t COAPDiscSerializer::GetMessageId()
{
    if (messageId >= 0xFFFF) {
        messageId= 0;
    }
    return messageId++;
}

uint16_t COAPDiscSerializer::GetSeqNo()
{
    // std::lock_guard<std::recursive_mutex> lock(resMutex);
    if (seqNo >= 0xFFFF) {
        seqNo = 0;
    }
    return seqNo;
}

void COAPDiscSerializer::GetUriHostByIp(std::string& wlanIp)
{
    if (wlanIp.empty()) {
        LOG_ERROR_S("wlanId is null");
        return;
    }
    size_t last_dot_pos = wlanIp.find_last_of(".");
    if (last_dot_pos == std::string::npos) {
        LOG_ERROR_S("invaild ip");
        return ;
    }
    wlanIp.replace(last_dot_pos + 1, std::string::npos, "255");
}

void COAPDiscSerializer::StopService()
{
    std::lock_guard<std::recursive_mutex> apiLock(apiMutex);
    {
        std::lock_guard<std::recursive_mutex> resLock(serviceResMutex);
        isStartService = false;
    }
    if (thread_ != nullptr && thread_->joinable()) {
        thread_->join();
    }
    thread_ = nullptr;
    if (serviceCtx) {
        coap_free_context(serviceCtx);
        serviceCtx = nullptr;
    }
    {
        std::lock_guard<std::recursive_mutex> resLock(resMutex);
        if (!isBleConnectToWifi) {
            coap_cleanup();
        }
    }
    LOG_DEBUG_S("stop coap service");
}

void COAPDiscSerializer::ReleaseClientCtx()
{
    if (clientCtx != nullptr) {
        coap_free_context(clientCtx);
        clientCtx = nullptr;
    }
}

void COAPDiscSerializer::StopClient()
{
    std::lock_guard<std::recursive_mutex> apiLock(apiMutex);
    std::lock_guard<std::recursive_mutex> resLock(resMutex);
    messageId = 0;
    seqNo = 0;
    if (clientTaskId >= 0) {
        bool ret = timerQueue.cancelTask(clientTaskId);
        if (!ret) {
            LOG_ERROR_S("not found the task, task id is %d", clientTaskId);
        }
        clientTaskId = -1;
    }
    if (clientCtx != nullptr) {
        coap_free_context(clientCtx);
        clientCtx = nullptr;
    }
    LOG_DEBUG_S("Stop coap broadcast");
}

COAPDiscSerializer::COAPDiscSerializer()
{
    isSpeedMode = false;
    isConnectWifi = false;
    messageId = 0;
    seqNo = 0;
    startScanTime = 0;
    clientTaskId = -1;
    isStartService = false;
    isBleConnectToWifi = false;
    isEnterBackground = false;
    task.clear();
    std::memset(&my_device, 0, sizeof(device_info_t));
    serviceCtx = nullptr;
    clientCtx= nullptr;
    thread_ = nullptr;
}

void COAPDiscSerializer::Init()
{
    SetDeviceInfo();
//    coap_startup();
    timerQueue.start();
//    const char* localPort = "5684";
//    const char* addrStr = "0.0.0.0";
//    serviceCtx = CoapGetContextEx(addrStr, localPort, AF_INET);
//    clientCtx = coap_new_context(NULL);
}

void COAPDiscSerializer::CheckCoapDevice()
{
    std::lock_guard<std::recursive_mutex> apiLock(apiMutex);
    std::lock_guard<std::recursive_mutex> lock(resMutex);
    if (isBleConnectToWifi) {
        return;
    }
    auto now = std::chrono::system_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch());
    uint64_t nowTime = static_cast<uint64_t>(duration.count());
    std::vector<uint64_t> removedList;
    DeviceManager::shared().checkCoapDevice(nowTime, removedList);
    
    for (auto &removeId : removedList) {
        DelegateManager *manager = [DelegateManager shared];
        char temp[32] = { 0 };
        snprintf(temp, sizeof(temp) - 1, "%016llX", removeId);
        NSString *udid = [NSString stringWithUTF8String:temp];
        if ([manager.deviceDelegate respondsToSelector:@selector(didDeviceLost:)]) {
            [manager.deviceDelegate didDeviceLost:udid];
        }
    }
}

void COAPDiscSerializer::TimeAction(device_info_t& info)
{
    auto now = std::chrono::system_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch());
    uint64_t nowTime = static_cast<uint64_t>(duration.count());
    std::vector<uint64_t> removedList;
    uint64_t oldestTime = DeviceManager::shared().getCoapDisconnectDevices(nowTime, removedList);
    
    for (auto &removeId : removedList) {
        DelegateManager *manager = [DelegateManager shared];
        char temp[32] = { 0 };
        snprintf(temp, sizeof(temp) - 1, "%016llX", removeId);
        NSString *udid = [NSString stringWithUTF8String:temp];
        if ([manager.deviceDelegate respondsToSelector:@selector(didDeviceLost:)]) {
            [manager.deviceDelegate didDeviceLost:udid];
        }
    }
    if (DeviceManager::shared().count() > 0) {
        int interval = oldestTime + 5.0 * 1000 - nowTime;
        COAPDiscSerializer::GetInstance()->TimeExcute(interval, info);
    }
}

void COAPDiscSerializer::TimeExcute(int delay, device_info_t& info)
{
    int taskID = timerQueue.addTask(delay, 1, &COAPDiscSerializer::TimeAction, info);
    auto it = task.find(info.udid);
    if (it != task.end()) {
        timerQueue.cancelTask(it->second);
        it->second = taskID;
    } else {
        task.insert(std::pair<std::string, int>(info.udid, taskID));
    }
}

void COAPDiscSerializer::SetDeviceInfo()
{
    std::lock_guard<std::recursive_mutex> lock(resMutex);
    if (my_device.udid[0] == '\0') {
        std::string udid = ShareManager::shared().GetDeviceId();
        std::string udidHash = "";
        for (int i = 0; i < udid.length(); i += 4 ) {
            udidHash += udid.substr(i + 2, 2) + udid.substr(i, 2);
        }
        strncpy(my_device.udid, udidHash.c_str(), udidHash.length());
        LOG_DEBUG_S("my device udid is %s", udidHash.c_str());
    }
#ifdef __OBJC__
#if TARGET_OS_IOS
        if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            my_device.type = 0x11;
        } else if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomMac) {
            my_device.type = 0x0C;
        } else {
            my_device.type = 0x0E;
        }
#elif TARGET_OS_MAC
            // macOS 设备类型判断
        my_device.type = 0x0C; // 为 macOS 设置默认值
#endif
#endif
}

COAPDiscSerializer::~COAPDiscSerializer()
{
    isStartService = false;
    if (thread_ != nullptr && thread_->joinable()) {
        thread_->join();
    }
    thread_ = nullptr;
    if (!serviceCtx) {
        coap_free_context(serviceCtx);
        serviceCtx = nullptr;
    }
    if (!clientCtx) {
        coap_free_context(clientCtx);
        clientCtx = nullptr;
    }
    timerQueue.stop();
    coap_cleanup();
}

bool COAPDiscSerializer::GetServiceStatus()
{
    std::lock_guard<std::recursive_mutex> lock(serviceResMutex);
    return isStartService;
}

bool COAPDiscSerializer::ParseCoapRespone(std::string payload, device_info_t& info, bool& isBroadcast)
{
    if (!nlohmann::json::accept(payload)) {
        LOG_ERROR_S("payload is not json.");
        return false;
    }
    nlohmann::json j = nlohmann::json::parse(payload);
    if(!j.contains("deviceId") || !j["deviceId"].is_string() || !j.contains("devicename") ||
        !j["devicename"].is_string() || !j.contains("type") || !j["type"].is_number() ||
        !j.contains("mode") || !j["mode"].is_number() || !j.contains("serviceData") ||
        !j["serviceData"].is_string() || !j.contains("wlanIp") || !j["wlanIp"].is_string() ||
        !j.contains("capabilityBitmap") || !j["capabilityBitmap"].is_array()) {
//        LOG_ERROR_S("parse payload fail.");
        return false;
    }
    std::string coapUri = "";
    if (j.contains("coapUri") && j["coapUri"].is_string()) {
        isBroadcast = true;
        coapUri = j["coapUri"].get<std::string>();
    } else {
        isBroadcast = false;
    }
    if (j.contains("extendServiceData") && j["extendServiceData"].is_string()) {
        std::string extendData = j["extendServiceData"].get<std::string>();
        int ablVlaue = StringParser::get_field_int_value(extendData, "abl");
        if (extendData.find("osType") != std::string::npos || ablVlaue == -1 || !(ablVlaue & 0x0008)) {
//            LOG_DEBUG_S("device is not h device");
            return false;
        }
        int ohVlaue = StringParser::get_field_int_value(extendData, "OH");
        if (!isBroadcast && (ohVlaue == -1 || ohVlaue != 1)) {
            return false;
        }
    }
    std::vector<int> capabilityBitmap = j["capabilityBitmap"].get<std::vector<int>>();
    std::string serviceData = j["serviceData"].get<std::string>();
    info.port = StringParser::get_field_int_value(serviceData, "port");
    
    if (!isBroadcast) {
        bool isShare = false;
        for (auto &it : capabilityBitmap) {
            if (it & 0x0100) {
                isShare = true;
                break;
            }
        }
        if (!isShare) {
            return false;
        }
    }

    if (j.contains("seqNo") && j["seqNo"].is_number()) {
        info.seqNo = j["seqNo"].get<int>();
    }
    std::string deviceId = j["deviceId"].get<std::string>();
    if (!nlohmann::json::accept(deviceId)) {
        LOG_DEBUG_S("deviceId is not json.");
    } else {
        nlohmann::json jValue = nlohmann::json::parse(deviceId);
        if (!jValue.contains("UDID") || !jValue["UDID"].is_string()) {
            LOG_DEBUG_S("parse deviceId fail.");
        } else {
            std::string udid = jValue["UDID"].get<std::string>();
            strncpy(info.udid, udid.c_str(), udid.length());
        }
    }
    std::string devicename = j["devicename"].get<std::string>();
    std::string wlanIp = j["wlanIp"].get<std::string>();
    int type = j["type"].get<int>();
    int mode = j["mode"].get<int>();
    strncpy(info.devicename, devicename.c_str(), devicename.length());
    strncpy(info.serviceData, serviceData.c_str(), serviceData.length());
    strncpy(info.wlanIp, wlanIp.c_str(), wlanIp.length());
    strncpy(info.coapUri, coapUri.c_str(), coapUri.length());
    info.type = type;
    info.mode = mode;
    for (size_t i = 0; i < capabilityBitmap.size() && i < 2; i++) {
        info.capabilityBitmap[i] = capabilityBitmap[i];
    }
    auto now = std::chrono::system_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch());
    info.updateTime = static_cast<uint64_t>(duration.count());
    return true;
}

std::string COAPDiscSerializer::CreateJsonRequest(bool isBroadCast)
{
    auto deviceInfo = COAPDiscSerializer::GetInstance()->GetDeviceInfo();
    // 创建设备信息JSON
    nlohmann::json jsValue;
    nlohmann::json deviceIdValue;
    deviceIdValue["UDID"] = deviceInfo.udid;
    std::string deviceId = deviceIdValue.dump();
    jsValue["deviceId"] = deviceId;
    jsValue["devicename"] = deviceInfo.devicename;
    jsValue["type"] = deviceInfo.type;
    if (isBroadCast) {
        jsValue["mode"] = 1;
        jsValue["coapUri"] = deviceInfo.coapUri;
    } else {
        jsValue["mode"] = 10;
    }
    // jsValue["seqNo"] = GetSeqNo();
    jsValue["seqNo"] = seqNo;
    jsValue["bType"] = 5;
    jsValue["serviceData"] = deviceInfo.serviceData;
    jsValue["wlanIp"] = deviceInfo.wlanIp;
    jsValue["extendServiceData"] = "osType:2,nbVer:9,rssi:-58,abl:8";
    nlohmann::json arrary = nlohmann::json::array();
    arrary.push_back(256);
    jsValue["capabilityBitmap"] = arrary;
    std::string device_json = jsValue.dump();
    return device_json;
}

coap_session_t *COAPDiscSerializer::CoapGetSessionEx(coap_context_t *ctx, coap_address_t *dest_addr)
{
    std::lock_guard<std::mutex> lock(sessionMutex);
    coap_session_t* new_session = nullptr;
    new_session = coap_session_get_by_peer(ctx, dest_addr, 0);
    if (new_session != nullptr) {
        coap_session_reference(new_session);
        CoapSetAckTimeOut(new_session);
        return new_session;
    }
    struct addrinfo hints;
    struct addrinfo *result = NULL;
    (void)memset_s(&hints, sizeof(struct addrinfo), 0, sizeof(struct addrinfo));
    hints.ai_family = AF_INET;  /* Allow IPv4 or IPv6 */
    hints.ai_socktype = SOCK_DGRAM; /* Coap uses UDP */
    hints.ai_flags = AI_PASSIVE | AI_NUMERICHOST | AI_ADDRCONFIG;
    const char* localPort = "5684";
    auto info = GetDeviceInfo();
    if (info.broadcastIp[0] == '\0' || info.wlanIp[0] == '\0') {
        LOG_ERROR_S("ip is empty");
        return nullptr;
    }
    int s = getaddrinfo(info.wlanIp, localPort, &hints, &result);
    if (s != 0) {
        std::string anoIp = AnonymizeIP(info.wlanIp);
        LOG_ERROR_S("getaddrinfo failed, error: %d, desc: %s, device ip: %s", errno, strerror(errno), anoIp.c_str());
        return nullptr;
    }
    new_session = CoapGetSessionInner(result, ctx, dest_addr);
    freeaddrinfo(result);
    CoapSetAckTimeOut(new_session);
    return new_session;
}

coap_pdu_t *COAPDiscSerializer::CoapPackToPdu(coap_pdu_type_t type, coap_pdu_code_t code,
                                              coap_session_t *session, coap_mid_t msgId, device_info_t info)
{
    if (session == nullptr) {
        LOG_ERROR_S("session is null");
        return nullptr;
    }
    coap_pdu_t *pdu = coap_pdu_init(type, code, msgId, coap_session_max_pdu_size(session));
    if (pdu == nullptr) {
        LOG_ERROR_S("coap new pdu fail");
        return nullptr;
    }
    if (type == COAP_MESSAGE_ACK) {
        return pdu;
    }
    // 设置选项
    unsigned char format_buf[2];
    size_t format_len = coap_encode_var_safe(format_buf, sizeof(format_buf),
                                            COAP_MEDIATYPE_APPLICATION_JSON);
    coap_add_option(pdu, COAP_OPTION_CONTENT_FORMAT, format_len, format_buf);
    
    coap_add_option(pdu, COAP_OPTION_URI_HOST, strlen(info.wlanIp), (const uint8_t *)(info.wlanIp));
    
    coap_add_option(pdu, COAP_OPTION_URI_PATH, 15, (const uint8_t *)"device_discover");
    // 创建设备信息JSON
    std::string device_json = COAPDiscSerializer::GetInstance()->CreateJsonRequest(false);

    // 添加响应数据
    coap_add_data(pdu, device_json.length() + 1, (const uint8_t *)(device_json.c_str()));
    return pdu;
}

void COAPDiscSerializer::SendUnicastResponse(coap_session_t *original_session, device_info_t info, const coap_pdu_t *request, bool isBoardcast)
{
    if (!IsNeedSend(info)) {
        return;
    }
    coap_context_t *ctx = coap_session_get_context(original_session);
    coap_address_t dest_addr;
    coap_address_init(&dest_addr);
    dest_addr.addr.sin.sin_family = AF_INET;
    dest_addr.addr.sin.sin_port = htons(5684);
    dest_addr.size = sizeof(struct sockaddr_in);
    inet_pton(AF_INET, info.wlanIp, &dest_addr.addr.sin.sin_addr);
    coap_session_t* new_session = CoapGetSessionEx(ctx, &dest_addr);
    if (new_session == nullptr) {
        LOG_ERROR_S("Get client session fail, errno:%d, desc:%s", errno, strerror(errno));
        return;
    }
    coap_pdu_t *pdu = nullptr;
    if (!isBoardcast) {
        pdu = CoapPackToPdu(COAP_MESSAGE_ACK, COAP_REQUEST_CODE_POST, new_session, coap_pdu_get_mid(request), info);
    } else {
        pdu = CoapPackToPdu(COAP_MESSAGE_CON, COAP_REQUEST_CODE_POST, new_session, GetMessageId(), info);
    }
    if (pdu == nullptr) {
        LOG_ERROR_S("pack to pdu fail, errno:%d, desc:%s", errno, strerror(errno));
        coap_session_release(new_session);
        return;
    }
    int32_t res = coap_send(new_session, pdu);
    if (res == COAP_INVALID_MID) {
        LOG_ERROR_S("coap send failed, errno:%d, desc:%s", errno, strerror(errno));
        coap_session_release(new_session);
        return;
    }
    coap_session_release(new_session);
}

coap_session_t *COAPDiscSerializer::CoapGetSessionInner(struct addrinfo *result, coap_context_t *ctx, coap_address_t *dest_addr)
{
    coap_session_t *session = NULL;
    struct addrinfo *rp = NULL;
    const coap_address_t *dst = dest_addr;

    for (rp = result; rp != NULL; rp = rp->ai_next) {
        coap_address_t bindAddr;
        if (rp->ai_addrlen > (socklen_t)sizeof(bindAddr.addr) || rp->ai_addr == NULL ||
            dst->addr.sa.sa_family != rp->ai_addr->sa_family) {
            continue;
        }
        (void)memset_s(&bindAddr, sizeof(bindAddr), 0, sizeof(bindAddr));
        coap_address_init(&bindAddr);
        bindAddr.size = rp->ai_addrlen;
        memcpy(&bindAddr.addr, rp->ai_addr, rp->ai_addrlen);
        char ip[NSTACKX_MAX_IP_STRING_LEN];
        if (bindAddr.addr.sa.sa_family == AF_INET) {
            (void)inet_ntop(AF_INET, &(bindAddr.addr.sin.sin_addr), ip, sizeof(ip));
        } else {
            (void)inet_ntop(AF_INET6, &(bindAddr.addr.sin6.sin6_addr), ip, sizeof(ip));
        }
        session = coap_new_client_session(ctx, &bindAddr, dst, COAP_PROTO_UDP);
        if (session != NULL) {
            break;
        } else {
//            LOG_ERROR_S("coap_new_client_session error");
        }
    }
    return session;
}

void COAPDiscSerializer::SetDeviceName(std::string deviceName)
{
    if (deviceName.empty()) {
        return;
    }
    std::lock_guard<std::recursive_mutex> apiLock(apiMutex);
    std::lock_guard<std::recursive_mutex> lock(resMutex);
    memset(my_device.devicename, 0, 64);
    strncpy(my_device.devicename, deviceName.c_str(), deviceName.length());
    std::string anoName = AnonymizeString(deviceName);
    LOG_DEBUG_S("device name changed, new name is %s", anoName.c_str());
}

void COAPDiscSerializer::SetPortAndFd(int port, int fd)
{
    std::lock_guard<std::recursive_mutex> apiLock(apiMutex);
    std::lock_guard<std::recursive_mutex> lock(resMutex);
    my_device.port = port;
    my_device.fd = fd;
    std::string serviceData = "";
    serviceData = "port:" + std::to_string(my_device.port);
    memset(my_device.serviceData, 0, 64);
    strncpy(my_device.serviceData, serviceData.c_str(), serviceData.length());
    LOG_DEBUG_S("set port :%d, fd :%d", port, fd);
}

void COAPDiscSerializer::SetWifiIp(std::string wlanIp, std::string broadcastIp)
{
    if (wlanIp.empty() || broadcastIp.empty()) {
        LOG_ERROR_S("wlan ip is empty");
        return;
    }
    std::lock_guard<std::recursive_mutex> lock(resMutex);
    memset(my_device.wlanIp, 0, 16);
    memset(my_device.broadcastIp, 0, 16);
    memset(my_device.coapUri, 0, 256);
    strncpy(my_device.wlanIp, wlanIp.c_str(), wlanIp.length());
    strncpy(my_device.broadcastIp, broadcastIp.c_str(), broadcastIp.length());
    std::string coap = "coap://";
    std::string coapUri = coap + my_device.wlanIp + "/device_discover";
    strncpy(my_device.coapUri, coapUri.c_str(), coapUri.length());
    if (clientCtx != nullptr) {
        coap_free_context(clientCtx);
        clientCtx = nullptr;
    }
    seqNo = 0;
    sendBroadcastCnt = 0;
    std::string anoWlanIp = AnonymizeIP(wlanIp);
    std::string anoBroadcastIp = AnonymizeIP(broadcastIp);
    LOG_DEBUG_S("Wifi ip changed, ip :%s, broadcast ip :%s", anoWlanIp.c_str(), anoBroadcastIp.c_str());
}

void COAPDiscSerializer::CoapSetAckTimeOut(coap_session_t *session)
{
    if (session == nullptr) {
        return;
    }
    coap_session_set_ack_timeout(session, DFINDER_COAP_ACK_TIMEOUT);
    coap_session_set_ack_random_factor(session, DFINDER_COAP_ACK_RANDOM_FACTOR);
    coap_session_set_max_retransmit(session, DFINDER_COAP_MAX_RETRANSMIT_TIMES);
}

coap_context_t *COAPDiscSerializer::CoapGetContextEx(const char *node, const char *port, uint8_t af)
{
    struct addrinfo hints;
    struct addrinfo *result = nullptr;
    struct addrinfo *rp = nullptr;
    coap_endpoint_t *ep = nullptr;
    coap_context_t *ctx = coap_new_context(NULL);
    if (ctx == nullptr) {
        LOG_ERROR_S("coap new context fail");
        return nullptr;
    }
    (void)memset_s(&hints, sizeof(struct addrinfo), 0, sizeof(struct addrinfo));
    hints.ai_family = AF_INET;  /* Allow IPv4 or IPv6 */
    hints.ai_socktype = SOCK_DGRAM; /* Coap uses UDP */
    hints.ai_flags = AI_PASSIVE | AI_NUMERICHOST;
    
    if (getaddrinfo(node, port, &hints, &result) != 0) {
        std::string anoNode = AnonymizeIP(node);
        LOG_ERROR_S("get addrinfo fail, error: %d, desc: %s, device ip: %s", errno, strerror(errno), anoNode.c_str());
        coap_free_context(ctx);
        return nullptr;
    }
    coap_address_t addr;
    for (rp = result; rp != nullptr; rp = rp->ai_next) {
        if (rp->ai_addrlen > (socklen_t)sizeof(addr.addr)) {
            continue;
        }
        
        coap_address_init(&addr);
        addr.size = rp->ai_addrlen;
        if (rp->ai_family != af) {
            continue;
        }
        memcpy(&addr.addr, rp->ai_addr, rp->ai_addrlen);
        ep = CoapCreateEndpoint(ctx, &addr, af);
        if (ep == nullptr) {
            LOG_ERROR_S("coap new endpoint return null");
            coap_free_context(ctx);
            ctx = nullptr;
        }
        break;
    }
    freeaddrinfo(result);
    return ctx;
}

coap_endpoint_t *COAPDiscSerializer::CoapCreateEndpoint(coap_context_t *ctx, coap_address_t *addr, uint8_t af)
{
    if (ctx == nullptr || addr == nullptr) {
        return nullptr;
    }
    coap_endpoint_t *ep = coap_new_endpoint(ctx, addr, COAP_PROTO_UDP);
    if (ep == nullptr) {
        LOG_ERROR_S("coap new endpoint get null");
        return nullptr;
    }
    return ep;
}

void COAPDiscSerializer::SetIsBLEConnectToWifiValue(bool isBleConnect)
{
    std::lock_guard<std::recursive_mutex> apiLock(apiMutex);
    std::lock_guard<std::recursive_mutex> resLock(resMutex);
    isBleConnectToWifi = isBleConnect;
    LOG_DEBUG_S("ble connect to wifi, status is %d", isBleConnect);
}

bool COAPDiscSerializer::IsNeedScan()
{
    std::lock_guard<std::recursive_mutex> lock(resMutex);
    if (!isConnectWifi || isBleConnectToWifi || isEnterBackground || isSpeedMode) {
        return false;
    }
    return true;
}

void COAPDiscSerializer::SetWifiStatus(bool wifiStatus)
{
    std::lock_guard<std::recursive_mutex> apiLock(apiMutex);
    std::lock_guard<std::recursive_mutex> lock(resMutex);
    if (wifiStatus) {
        auto now = std::chrono::system_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch());
        startScanTime = static_cast<uint64_t>(duration.count());
    }
    isConnectWifi = wifiStatus;
    if (wifiStatus && !isBleConnectToWifi) {
        if (clientCtx) {
            coap_free_context(clientCtx);
            clientCtx = nullptr;
        }
    }
    LOG_DEBUG_S("wifi status changed, status is %d", wifiStatus);
}

void COAPDiscSerializer::SetEnterBackgroundStatus(bool backgroundStatus)
{
    std::lock_guard<std::recursive_mutex> apiLock(apiMutex);
    std::lock_guard<std::recursive_mutex> lock(resMutex);
    isEnterBackground = backgroundStatus;
    LOG_DEBUG_S("device enter background, status is %d", backgroundStatus);
}

bool COAPDiscSerializer::IsNeedSend(device_info_t info)
{
    if (oldDeviceInfo.empty()) {
        oldDeviceInfo.insert(std::make_pair(info.udid, info));
        return true;
    }
    std::string udid(info.udid);
    if (udid.empty()) {
        return false;
    }
    auto it = oldDeviceInfo.find(udid);
    if (it == oldDeviceInfo.end()) {
        oldDeviceInfo.insert(std::make_pair(udid, info));
        return true;
    }
    if (CompareInfo(it->second, info)) {
        it->second = info;
        return true;
    }
    return false;
}

bool COAPDiscSerializer::CompareInfo(device_info_t oldInfo, device_info_t info)
{
    if (strncmp(oldInfo.udid, info.udid, sizeof(info.udid) - 1) != 0
        || strncmp(oldInfo.devicename, info.devicename, sizeof(info.devicename) - 1) != 0
        || strncmp(oldInfo.wlanIp, info.wlanIp, sizeof(info.wlanIp) - 1) != 0
        || strncmp(oldInfo.coapUri, info.coapUri, sizeof(info.coapUri) - 1) != 0
        || oldInfo.seqNo != info.seqNo
        || oldInfo.type != info.type) {
        return true;
    }
    return false;
}

void COAPDiscSerializer::SetSpeedMode(bool isSpeedMode)
{
    std::lock_guard<std::recursive_mutex> apiLock(apiMutex);
    std::lock_guard<std::recursive_mutex> lock(resMutex);
    this->isSpeedMode = isSpeedMode;
    LOG_DEBUG_S("set speedmode, mode is %d", isSpeedMode);
}

bool COAPDiscSerializer::GetSpeedMode()
{
    std::lock_guard<std::recursive_mutex> lock(resMutex);
    return isSpeedMode;
}

void COAPDiscSerializer::CoapDeviceLost()
{
    std::vector<uint64_t> removedList;
    DeviceManager::shared().lostCoapDevice(removedList);
    for (auto &removeId : removedList) {
        DelegateManager *manager = [DelegateManager shared];
        char temp[32] = { 0 };
        snprintf(temp, sizeof(temp) - 1, "%016llX", removeId);
        NSString *udid = [NSString stringWithUTF8String:temp];
        if ([manager.deviceDelegate respondsToSelector:@selector(didDeviceLost:)]) {
            [manager.deviceDelegate didDeviceLost:udid];
        }
    }
}

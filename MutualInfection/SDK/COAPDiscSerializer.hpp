//
//  COAPDiscSerializer.hpp
//  Service
//
//  Created by apple on 2025/8/28.
//

#ifndef COAP_DISC_SERIALIZER_H
#define COAP_DISC_SERIALIZER_H
#include <stdio.h>
#include <cstring>
#include <unistd.h>
#include "coap3/coap.h"
#include <mutex>
#include <map>
#include "Device.h"
#include "Timer.h"

class COAPDiscSerializer
{
public:
    COAPDiscSerializer();
    ~COAPDiscSerializer();
    static COAPDiscSerializer *GetInstance();
    void Init();
    void CreateServiceThread();
    void CreateClientThread();
    void SetDeviceInfo();
    void StopService();
    void StopClient();
    void ReleaseClientCtx();
    bool GetServiceStatus();
    void GetUriHostByIp(std::string& wlanIp);
    static void TimeAction(device_info_t& info);
    void TimeExcute(int delay, device_info_t& info);
    void SendUnicastResponse(coap_session_t *original_session, device_info_t info, const coap_pdu_t *request, bool isBoardcast);
    int GetBroadcastIp(coap_address_t *local_addr, char *ipStr, size_t ipStrLen);
    coap_context_t *GetClientCtx();
    coap_mid_t GetMessageId();
    uint16_t GetSeqNo();
    void SetDeviceName(std::string deviceName);
    void SetPortAndFd(int port, int fd);
    void SetWifiIp(std::string wlanIp, std::string broadcastIp);
    uint64_t GetStartScanTime() { return startScanTime; }
    void SetIsBLEConnectToWifiValue(bool isBleConnect);
    bool IsNeedScan();
    void SetWifiStatus(bool wifiStatus);
    void SetEnterBackgroundStatus(bool backgroundStatus);
    void CheckCoapDevice();
    void SetSpeedMode(bool isSpeedMode);
    bool GetSpeedMode();
    void CoapDeviceLost();
private:
    device_info_t GetDeviceInfo();
    void StartService();
    coap_context_t *CoapGetContextEx(const char *node, const char *port, uint8_t af);
    coap_endpoint_t *CoapCreateEndpoint(coap_context_t *ctx, coap_address_t *addr, uint8_t af);
    static void StartScan();
    static enum coap_response_t discovery_callback(coap_session_t *session,
                                                   const coap_pdu_t *sent,
                                                   const coap_pdu_t *received,
                                                   const coap_mid_t mid);
    static void handle_discovery(coap_resource_t *resource,
                                 coap_session_t *session,
                                 const coap_pdu_t *request,
                                 const coap_string_t *query,
                                 coap_pdu_t *response);
    bool ParseCoapRespone(std::string payload, device_info_t &info, bool& isBroadcast);
    bool IsNeedSend(device_info_t info);
    bool CompareInfo(device_info_t oldInfo, device_info_t info);
    coap_session_t *CoapGetSessionEx(coap_context_t *ctx, coap_address_t *dest_addr);
    coap_session_t *CoapGetSessionInner(struct addrinfo *result, coap_context_t *ctx, coap_address_t *dest_addr);
    coap_pdu_t *CoapPackToPdu(coap_pdu_type_t type, coap_pdu_code_t code, coap_session_t *session,
                              coap_mid_t messageId, device_info_t info);
    std::string CreateJsonRequest(bool isBroadCast);
    void CoapSetAckTimeOut(coap_session_t *session);
    device_info_t my_device;
    std::map<std::string, device_info_t> oldDeviceInfo;
    std::recursive_mutex apiMutex;
    std::recursive_mutex serviceResMutex;
    std::mutex sessionMutex;
    std::map<std::string, int> task;
    TimerQueue timerQueue;
    int clientTaskId;
    uint64_t startScanTime;
    std::shared_ptr<std::thread> thread_;
    bool isBleConnectToWifi;
    bool isConnectWifi;
    std::atomic<bool> isStartService;
    bool isEnterBackground;
    bool isSpeedMode;
    coap_mid_t messageId;
    coap_context_t *serviceCtx;
    coap_context_t *clientCtx;
};
#endif

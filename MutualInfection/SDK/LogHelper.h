//
//  LogHelper.h
//  MutualInfection
//
//  Created by apple on 2025/9/17.
//

#ifndef LOG_HELPER_H
#define LOG_HELPER_H

#include <stdio.h>
#include <time.h>
#include <list>
#include <mutex>
#include <thread>
#include <string>
#include <memory>
#include <condition_variable>
#include <cstdint>

#define LOG_I_GRADE          1
#define LOG_D_GRADE          2
#define LOG_E_GRADE          3
#define LOG_F_GRADE          4

#define MAX_CHAR 4096

using stLogItem = struct stLogItem_ {
    uint16_t year;
    uint16_t month;
    uint16_t day;
    uint16_t hour;
    uint16_t minute;
    uint16_t second;
    uint16_t milliseconds;
    std::string threadId;
    uintptr_t caller;
    std::string logFlag;
    std::string funcName;
    int line;
    char logBuff[MAX_CHAR];
};

#define LOG_START(file) LogHelper::GetInstance()->Init(file)

#define LOG_INFO(format, ...) LogHelper::GetInstance()->Log(__FUNCTION__,   \
    __LINE__, LOG_I_GRADE, this, format, ##__VA_ARGS__)
#define LOG_INFO_S(format, ...) LogHelper::GetInstance()->Log(__FUNCTION__, \
    __LINE__, LOG_I_GRADE, NULL, format, ##__VA_ARGS__)

#define LOG_DEBUG(format, ...) LogHelper::GetInstance()->Log(__FUNCTION__,  \
    __LINE__, LOG_D_GRADE, this, format, ##__VA_ARGS__)
#define LOG_DEBUG_S(format, ...) LogHelper::GetInstance()->Log(__FUNCTION__,    \
    __LINE__, LOG_D_GRADE, NULL, format, ##__VA_ARGS__)

#define LOG_ERROR(format, ...) LogHelper::GetInstance()->Log(__FUNCTION__,  \
    __LINE__, LOG_E_GRADE, this, format, ##__VA_ARGS__)
#define LOG_ERROR_S(format, ...) LogHelper::GetInstance()->Log(__FUNCTION__,    \
    __LINE__, LOG_E_GRADE, NULL, format, ##__VA_ARGS__)

#define LOG_FATAL(format, ...) LogHelper::GetInstance()->Log(__FUNCTION__,  \
    __LINE__, LOG_F_GRADE, this, format, ##__VA_ARGS__)
#define LOG_FATAL_S(format, ...) LogHelper::GetInstance()->Log(__FUNCTION__,    \
    __LINE__, LOG_F_GRADE, NULL, format, ##__VA_ARGS__)

class LogHelper {
public:
    static std::shared_ptr<LogHelper> GetInstance();
    explicit LogHelper();
    ~LogHelper();

    void Log(const std::string& func, const int line, unsigned long grade,
        const void* caller, const char* format, ...);
    void Init(const std::string& filePath = "");
    void SetLevel(int logLevel);
    static void DFileLog(const char *moduleName, uint32_t logLevel, const char *format, ...);
    
    std::string GetUploadFile(const std::string &appleId, const std::string &timeStamp);
    void Cleanup();

private:
    std::string GetThreadId();
    void WriteData2File(std::shared_ptr<stLogItem> saveLog);
    static void Run(LogHelper* param);
    uint32_t FindLogIndex(const std::string& filePath);
private:
    static std::shared_ptr<LogHelper> instance_;
    static std::mutex instanceLock_;

    std::shared_ptr<std::thread> thread_;
    uint32_t debugLevel_;
};
#endif // LOG_HELPER_H

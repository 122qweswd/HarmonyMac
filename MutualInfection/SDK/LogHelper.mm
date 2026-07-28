//
//  LogHelper.mm
//  MutualInfection
//
//  Created by apple on 2025/9/17.
//
#include "LogHelper.h"

#include <cstdarg>
#include <Foundation/Foundation.h>
#include <sstream>
#include <sys/stat.h>
#include <unistd.h>
#include <dirent.h>
#include <cstring>
#include <iostream>
#include <iomanip>
#include <chrono>
#include <ctime>
#include <openssl/rand.h>
#include "DFile/nstackx_dfile.h"

#include <Compression.h>

const uint32_t MAX_LOG_SIZE = 10 * 1024 * 1024; // 10MB
const uint32_t MAX_FILE_COUNT = 90;
const int32_t FILE_NOT_FOUND = -1;
const uint32_t MAX_BUFFER_LEN = 1024;
const size_t MAX_LOG_LIST_SIZE = 10;
const std::string DEFAULT_FILE_NAME = "App.log";

std::shared_ptr<LogHelper> LogHelper::instance_ = nullptr;
std::mutex LogHelper::instanceLock_;
static std::string logFile_ = "";
static bool isRunning_ = false;
static std::list<std::shared_ptr<stLogItem>> logList_;
std::mutex mutex_;
std::condition_variable cv_;
static uint32_t fileIndex_ = 0;
uint32_t fileCount_ = MAX_FILE_COUNT;
uint64_t fileSize_ = MAX_LOG_SIZE;
// 将字符串解析为时间点
static std::chrono::system_clock::time_point parseTime(const std::string& timeStr) {
    std::tm tm = {};
    std::istringstream ss(timeStr);
    ss >> std::get_time(&tm, "%Y-%m-%d %H:%M");
    std::time_t tt = std::mktime(&tm);
    return std::chrono::system_clock::from_time_t(tt);
}

// 将时间点转换为字符串
static std::string formatTime(const std::chrono::system_clock::time_point& timePoint) {
    std::time_t tt = std::chrono::system_clock::to_time_t(timePoint);
    std::tm *tm = std::localtime(&tt); // 得到当地时间
    std::ostringstream oss;
    oss << std::put_time(tm, "%Y-%m-%d %H:%M");
    return oss.str();
}

static std::string GetLogFolder()
{
    // 获取iOS文档目录
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    NSString *buildString = [infoDictionary objectForKey:@"CFBundleVersion"];
    if (buildString != nil) {
        std::string newBuildString = [buildString UTF8String];
        auto pos = newBuildString.find(".");
        if (pos != std::string::npos) {
            newBuildString = newBuildString.substr(pos + 1, newBuildString.length() - pos - 1);
        }
        int buildVersion = std::atoi(newBuildString.c_str());
        if (buildVersion < 2500) {
            paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        }
    }

    NSString *documentsDirectory = [paths firstObject];
    std::string root = [documentsDirectory UTF8String];
    root += "/logs";
    NSFileManager *fm = [NSFileManager defaultManager];
    if (fm == nil) {
        return "";
    }
    [fm createDirectoryAtPath:[NSString stringWithUTF8String:root.c_str()]
        withIntermediateDirectories:YES attributes:nil error:nil];
    return root;
}

static std::string GetReportFolder()
{
    // 获取iOS文档目录
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths firstObject];
    std::string root = [documentsDirectory UTF8String];
    root += "/report";
    NSFileManager *fm = [NSFileManager defaultManager];
    if (fm == nil) {
        return "";
    }
    [fm createDirectoryAtPath:[NSString stringWithUTF8String:root.c_str()]
        withIntermediateDirectories:NO attributes:nil error:nil];
    return root;
}

static void BuildLogTime(const std::string &timestamp, std::vector<std::string> &timeList, std::string &endTime)
{
    std::chrono::system_clock::time_point baseTime = parseTime(timestamp);
    for (int index = 30; index > 0; index--) {
        timeList.emplace_back(formatTime(baseTime - std::chrono::minutes(index)));
    }
    timeList.emplace_back(formatTime(baseTime));
    for (int index = 0; index <= 30; index++) {
        timeList.emplace_back(formatTime(baseTime + std::chrono::minutes(index)));
    }
    endTime = formatTime(baseTime + std::chrono::minutes(61));
}

LogHelper::LogHelper() : thread_(nullptr), debugLevel_(LOG_I_GRADE)
{
}

LogHelper::~LogHelper()
{
}
void LogHelper::Cleanup()
{
    if (isRunning_) {
        isRunning_ = false;
        cv_.notify_one();
        
        std::shared_ptr<std::thread> threadRef;
        threadRef.swap(thread_);
        
        if (threadRef != nullptr && threadRef->joinable()) {
            threadRef->join();
        }
    }
    
    std::unique_lock<std::mutex> lock(mutex_);
    logList_.clear();
}

static FILE* GetLogFile(const std::string& filePath)
{
    FILE* fp = nullptr;
    char buffer[MAX_BUFFER_LEN] = { 0 };
    int err = snprintf(buffer, MAX_BUFFER_LEN, "%s_%d.log", filePath.c_str(), fileIndex_);
    if (err < 0) {
        return nullptr;
    }
    
    fp = fopen(buffer, "a");
    if (fp == nullptr) {
        return nullptr;
    }
    
    fseek(fp, 0, SEEK_END);
    long fileSize = ftell(fp);
    if (fileSize > fileSize_) {
        fclose(fp);
        fileIndex_ = (fileIndex_ + 1) % fileCount_;
        err = snprintf(buffer, MAX_BUFFER_LEN, "%s_%d.log", filePath.c_str(), fileIndex_);
        if (err < 0) {
            return nullptr;
        }
        fp = fopen(buffer, "w");
        if (fp == nullptr) {
            return nullptr;
        }
    }
    return fp;
}

uint32_t LogHelper::FindLogIndex(const std::string& filePath)
{
    char buffer[MAX_BUFFER_LEN] = { 0 };
    uint32_t fileIndex = 0;
    time_t ctime = 0;
    uint32_t latestIndex = 0;
    time(&ctime);
    
    while (fileIndex < MAX_FILE_COUNT) {
        if (snprintf(buffer, MAX_BUFFER_LEN, "%s_%d.log", filePath.c_str(), fileIndex) < 0) {
            break;
        }
        
        if (access(buffer, F_OK) != 0) {
            break;
        }
        
        struct stat st;
        if (stat(buffer, &st) != 0) {
            break;
        }
        
        if (st.st_size < fileSize_) {
            break;
        }
        
        if (st.st_ctime < ctime) {
            latestIndex = fileIndex;
            ctime = st.st_ctime;
        }
        fileIndex++;
    }
    
    if (fileIndex == MAX_FILE_COUNT) {
        fileIndex = latestIndex;
        if (snprintf(buffer, MAX_BUFFER_LEN, "%s_%d.log", filePath.c_str(), fileIndex) >= 0) {
            FILE* fp = fopen(buffer, "w");
            if (fp != nullptr) {
                fclose(fp);
            }
        }
    }
    
    return fileIndex;
}

static bool GetLogItem(std::list<std::shared_ptr<stLogItem>>& list)
{
    std::unique_lock<std::mutex> lock(mutex_);
    try {
        cv_.wait_for(lock, std::chrono::seconds(1));
        
        if (logList_.empty()) {
            return false;
        }

        list.splice(list.end(), logList_);
        return true;
    } catch (const std::system_error &e) {
        printf("LogHelper cv wait_for system_error: %s\n", e.what());
        return false;
    } catch (const std::exception &e) {
        printf("LogHelper GetLogItem exception: %s\n", e.what());
        return false;
    } catch (...) {
        printf("LogHelper GetLogItem unknown exception\n");
        return false;
    }
}

void LogHelper::Run(LogHelper* thisVal)
{
    if (thisVal == nullptr) {
        return;
    }
    size_t pos = logFile_.find_last_of("/");
    if (pos != std::string::npos) {
        std::string dirPath = logFile_.substr(0, pos);
        mkdir(dirPath.c_str(), 0755);
    }

    std::list<std::shared_ptr<stLogItem>> list;
    try {
        while (isRunning_) {
            if (!GetLogItem(list)) {
                continue;
            }
            
            FILE* fp = GetLogFile(logFile_);
            if (fp == nullptr) {
                if (list.size() > MAX_LOG_LIST_SIZE) {
                    list.clear();
                }
                continue;
            }

            for (auto& item : list) {
                if (item != nullptr) {
                    fprintf(fp, "%04d-%02d-%02d %02d:%02d:%02d.%03d TID%s %08lX (%s:%d): (%s) %s\n",
                            item->year, item->month, item->day,
                            item->hour, item->minute, item->second, item->milliseconds,
                            item->threadId.c_str(), item->caller,
                            item->funcName.c_str(), item->line,
                            item->logFlag.c_str(), item->logBuff);
                    printf("%04d-%02d-%02d %02d:%02d:%02d.%03d TID%s %08lX (%s:%d): (%s) %s\n",
                            item->year, item->month, item->day,
                            item->hour, item->minute, item->second, item->milliseconds,
                            item->threadId.c_str(), item->caller,
                            item->funcName.c_str(), item->line,
                            item->logFlag.c_str(), item->logBuff);
                }
            }
            fclose(fp);
            list.clear();
        }
    } catch (const std::exception& e) {
        printf("LogHelper thread exception: %s\n", e.what());
    } catch (...) {
        printf("LogHelper thread unknown exception\n");
    }
    
}

void LogHelper::Init(const std::string& filePath)
{
    if (isRunning_) {
        return;
    }

    logFile_ = filePath;
    if (logFile_.empty()) {
        std::string root = GetLogFolder();
        if (!root.empty()) {
            logFile_ = root + "/" + DEFAULT_FILE_NAME;
        } else {
            logFile_ = "./" + DEFAULT_FILE_NAME;
        }
    }

    size_t pos = logFile_.rfind('.');
    if (pos != std::string::npos) {
        logFile_ = logFile_.substr(0, pos);
    }
    
    fileIndex_ = FindLogIndex(logFile_);
    isRunning_ = true;
    thread_ = std::make_shared<std::thread>(Run, this);
    NSTACKX_DFileRegisterLogCallback(LogHelper::DFileLog);
}

void LogHelper::SetLevel(int logLevel)
{
    debugLevel_ = logLevel;
}

std::string LogHelper::GetThreadId()
{
    std::thread::id id = std::this_thread::get_id();
    std::stringstream sin;
    sin << id;
    return sin.str();
}

void LogHelper::DFileLog(const char *moduleName, uint32_t logLevel, const char *format, ...)
{
    auto thiz = LogHelper::GetInstance();
    if (thiz->debugLevel_ > logLevel || logLevel > LOG_F_GRADE) {
        return;
    }
    
    auto saveLog = std::make_shared<stLogItem>();
    const std::string logFlag[] = { "INFO", "DEBUG", "ERROR", "FATAL" };
    
    // 获取当前时间
    auto now = std::chrono::system_clock::now();
    auto now_t = std::chrono::system_clock::to_time_t(now);
    auto now_ms = std::chrono::duration_cast<std::chrono::milliseconds>(
                                                                        now.time_since_epoch()) % 1000;
    
    std::tm* tm_now = std::localtime(&now_t);
    
    saveLog->year = tm_now->tm_year + 1900;
    saveLog->month = tm_now->tm_mon + 1;
    saveLog->day = tm_now->tm_mday;
    saveLog->hour = tm_now->tm_hour;
    saveLog->minute = tm_now->tm_min;
    saveLog->second = tm_now->tm_sec;
    saveLog->milliseconds = now_ms.count();
    saveLog->threadId =thiz-> GetThreadId();
    saveLog->caller = 0;
    saveLog->line = 0;
    saveLog->logFlag = logFlag[logLevel - 1];
    saveLog->funcName = moduleName;
    
    memset(saveLog->logBuff, 0, sizeof(saveLog->logBuff));
    va_list varArgs;
    va_start(varArgs, format);
    int err = vsnprintf(saveLog->logBuff, sizeof(saveLog->logBuff) - 1, format, varArgs);
    va_end(varArgs);
    
    if (err < 0) {
        return;
    }
    
    thiz->WriteData2File(saveLog);
}

// 检查文件是否包含时间列表中的任何时间
static bool ContainsTimeInList(const std::string &filePath, const std::vector<std::string> &timeList)
{
    FILE *file = fopen(filePath.c_str(), "rb");
    if (file == nullptr) {
        return false;
    }
    
    std::vector<uint8_t> buffer;
    buffer.resize(64 * 1024 + 1);

    bool found = false;
    size_t currentPos = 0;
    size_t lineFeedPos = std::string::npos;
    size_t startPos = std::string::npos;
    
    do {
        fseek(file, currentPos, SEEK_SET);
        size_t bytesRead = fread(buffer.data(), 1, 2 * 1024, file);
        if (bytesRead == 0) break;
        
        std::string logBuffer = reinterpret_cast<char*>(buffer.data());
        lineFeedPos = logBuffer.rfind('\n') + 1;
        if (lineFeedPos == 0) {
            currentPos += logBuffer.length();
            continue;
        }
        currentPos += lineFeedPos;
        startPos = std::string::npos;
        
        // 检查是否包含时间列表中的任何时间
        for (auto &time: timeList) {
            startPos = logBuffer.find(time);
            if (startPos != std::string::npos) {
                found = true;
                break;
            }
        }
        
        if (found) {
            break;
        }
    } while (!feof(file));
    
    fclose(file);
    return found;
}


// 辅助函数：使用 Compression.h 创建ZIP文件
static bool CreateCompressedZipWithFiles(NSArray<NSURL *> *fileURLs, NSString *zipPath) {
    @autoreleasepool {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSMutableData *zipData = [NSMutableData data];
        
        // ZIP file header signatures
        const uint32_t localFileHeaderSignature = 0x04034b50;
        const uint32_t centralDirectoryHeaderSignature = 0x02014b50;
        const uint32_t endOfCentralDirectorySignature = 0x06054b50;
        
        NSMutableArray *centralDirectoryEntries = [NSMutableArray array];
        uint32_t offset = 0;
        
        for (NSURL *fileURL in fileURLs) {
            @autoreleasepool {
                NSString *fileName = [fileURL lastPathComponent];
                NSData *fileData = [NSData dataWithContentsOfURL:fileURL];
                
                if (!fileData) {
                    continue;
                }
                
                // Use Compression.h for data compression
                size_t sourceSize = [fileData length];
                const uint8_t *sourceBuffer = (const uint8_t *)[fileData bytes];
                
                // Calculate compressed buffer size
                size_t compressedBufferSize = compression_encode_scratch_buffer_size(COMPRESSION_ZLIB);
                if (compressedBufferSize == 0) {
                    continue;
                }
                
                // Allocate compression buffer
                size_t maxCompressedSize = sourceSize + (sourceSize >> 3) + 32;
                NSMutableData *compressedData = [NSMutableData dataWithLength:maxCompressedSize];
                uint8_t *compressedBuffer = (uint8_t *)[compressedData mutableBytes];
                
                // Perform compression
                size_t actualCompressedSize = compression_encode_buffer(compressedBuffer, maxCompressedSize,
                                                                       sourceBuffer, sourceSize,
                                                                       NULL, COMPRESSION_ZLIB);
                
                if (actualCompressedSize == 0) {
                    continue;
                }
                
                // Resize to actual compressed size
                [compressedData setLength:actualCompressedSize];
                
                // Calculate CRC32
                uint32_t crc = 0;
                uint32_t *crcTable = (uint32_t *)malloc(256 * sizeof(uint32_t));
                
                // Generate CRC32 table
                for (uint32_t i = 0; i < 256; i++) {
                    uint32_t c = i;
                    for (int j = 0; j < 8; j++) {
                        if (c & 1) {
                            c = 0xEDB88320 ^ (c >> 1);
                        } else {
                            c = c >> 1;
                        }
                    }
                    crcTable[i] = c;
                }
                
                // Calculate file CRC32
                crc = 0xFFFFFFFF;
                const uint8_t *data = (const uint8_t *)[fileData bytes];
                for (size_t i = 0; i < sourceSize; i++) {
                    crc = crcTable[(crc ^ data[i]) & 0xFF] ^ (crc >> 8);
                }
                crc = ~crc;
                
                free(crcTable);
                
                // Local file header
                struct {
                    uint32_t signature;
                    uint16_t versionNeeded;
                    uint16_t flags;
                    uint16_t compressionMethod;
                    uint16_t lastModTime;
                    uint16_t lastModDate;
                    uint32_t crc32;
                    uint32_t compressedSize;
                    uint32_t uncompressedSize;
                    uint16_t fileNameLength;
                    uint16_t extraFieldLength;
                } __attribute__((packed)) localHeader;
                
                localHeader.signature = localFileHeaderSignature;
                localHeader.versionNeeded = 20;
                localHeader.flags = 0;
                localHeader.compressionMethod = 8; // DEFLATED
                localHeader.lastModTime = 0x4a71;
                localHeader.lastModDate = 0x54a5;
                localHeader.crc32 = crc;
                localHeader.compressedSize = (uint32_t)actualCompressedSize;
                localHeader.uncompressedSize = (uint32_t)sourceSize;
                localHeader.fileNameLength = (uint16_t)fileName.length;
                localHeader.extraFieldLength = 0;
                
                [zipData appendBytes:&localHeader length:sizeof(localHeader)];
                [zipData appendData:[fileName dataUsingEncoding:NSUTF8StringEncoding]];
                
                // Record central directory info
                NSDictionary *centralDirEntry = @{
                    @"localHeaderOffset": @(offset),
                    @"fileName": fileName,
                    @"compressedSize": @(actualCompressedSize),
                    @"uncompressedSize": @(sourceSize),
                    @"crc32": @(crc)
                };
                [centralDirectoryEntries addObject:centralDirEntry];
                
                offset += sizeof(localHeader) + fileName.length;
                
                // File data
                [zipData appendData:compressedData];
                offset += actualCompressedSize;
            }
        }
        
        if (centralDirectoryEntries.count == 0) {
            return false;
        }
        
        uint32_t centralDirectoryStart = offset;
        
        // Central directory records
        for (NSDictionary *entry in centralDirectoryEntries) {
            struct {
                uint32_t signature;
                uint16_t versionMadeBy;
                uint16_t versionNeeded;
                uint16_t flags;
                uint16_t compressionMethod;
                uint16_t lastModTime;
                uint16_t lastModDate;
                uint32_t crc32;
                uint32_t compressedSize;
                uint32_t uncompressedSize;
                uint16_t fileNameLength;
                uint16_t extraFieldLength;
                uint16_t fileCommentLength;
                uint16_t diskNumberStart;
                uint16_t internalFileAttributes;
                uint32_t externalFileAttributes;
                uint32_t relativeOffsetOfLocalHeader;
            } __attribute__((packed)) centralHeader;
            
            centralHeader.signature = centralDirectoryHeaderSignature;
            centralHeader.versionMadeBy = 20;
            centralHeader.versionNeeded = 20;
            centralHeader.flags = 0;
            centralHeader.compressionMethod = 8;
            centralHeader.lastModTime = 0x4a71;
            centralHeader.lastModDate = 0x54a5;
            centralHeader.crc32 = [entry[@"crc32"] unsignedIntValue];
            centralHeader.compressedSize = [entry[@"compressedSize"] unsignedIntValue];
            centralHeader.uncompressedSize = [entry[@"uncompressedSize"] unsignedIntValue];
            centralHeader.fileNameLength = (uint16_t)[entry[@"fileName"] length];
            centralHeader.extraFieldLength = 0;
            centralHeader.fileCommentLength = 0;
            centralHeader.diskNumberStart = 0;
            centralHeader.internalFileAttributes = 0;
            centralHeader.externalFileAttributes = 0;
            centralHeader.relativeOffsetOfLocalHeader = [entry[@"localHeaderOffset"] unsignedIntValue];
            
            [zipData appendBytes:&centralHeader length:sizeof(centralHeader)];
            [zipData appendData:[entry[@"fileName"] dataUsingEncoding:NSUTF8StringEncoding]];
        }
        
        uint32_t centralDirectorySize = (uint32_t)(zipData.length - centralDirectoryStart);
        
        // End of central directory record
        struct {
            uint32_t signature;
            uint16_t diskNumber;
            uint16_t diskStart;
            uint16_t numEntriesOnDisk;
            uint16_t totalEntries;
            uint32_t centralDirectorySize;
            uint32_t centralDirectoryOffset;
            uint16_t commentLength;
        } __attribute__((packed)) endRecord;
        
        endRecord.signature = endOfCentralDirectorySignature;
        endRecord.diskNumber = 0;
        endRecord.diskStart = 0;
        endRecord.numEntriesOnDisk = (uint16_t)centralDirectoryEntries.count;
        endRecord.totalEntries = (uint16_t)centralDirectoryEntries.count;
        endRecord.centralDirectorySize = centralDirectorySize;
        endRecord.centralDirectoryOffset = centralDirectoryStart;
        endRecord.commentLength = 0;
        
        [zipData appendBytes:&endRecord length:sizeof(endRecord)];
        
        // Write to file
        NSError *writeError = nil;
        if ([zipData writeToFile:zipPath options:NSDataWritingAtomic error:&writeError]) {
            return true;
        } else {
            return false;
        }
    }
}

static void PackLogFiles(const std::vector<std::string> &timeList, const std::string &uploadFile)
{
    LOG_INFO_S("Start packing log files (Compression.h + Foundation)");
    
    @autoreleasepool {
        NSString *zipPathStr = [NSString stringWithUTF8String:uploadFile.c_str()];
        NSMutableArray *fileURLs = [NSMutableArray array];
        NSFileManager *fm = [NSFileManager defaultManager];
        
        LOG_INFO_S("ZIP target path: %@", zipPathStr);
        
        // Get logs directory
        NSString *logsDir = [NSString stringWithUTF8String:GetLogFolder().c_str()];

        // Check if logs directory exists
        BOOL isDir = NO;
        if (![fm fileExistsAtPath:logsDir isDirectory:&isDir] || !isDir) {
            LOG_ERROR_S("Logs directory does not exist: %@", logsDir);
            return;
        }
        
        // Read all files in logs directory
        NSError *error = nil;
        NSArray *files = [fm contentsOfDirectoryAtPath:logsDir error:&error];
        if (error) {
            LOG_ERROR_S("Failed to read logs directory: %@", error);
            return;
        }
        
        // Function to check if string contains Chinese characters
        BOOL (^containsChinese)(NSString *) = ^BOOL(NSString *str) {
            for (int i = 0; i < [str length]; i++) {
                unichar c = [str characterAtIndex:i];
                // Check for Chinese characters in basic and extended ranges
                if ((c >= 0x4E00 && c <= 0x9FFF) ||     // CJK Unified Ideographs
                    (c >= 0x3400 && c <= 0x4DBF) ||     // CJK Unified Ideographs Extension A
                    (c >= 0x20000 && c <= 0x2A6DF) ||   // CJK Unified Ideographs Extension B
                    (c >= 0x2A700 && c <= 0x2B73F) ||   // CJK Unified Ideographs Extension C
                    (c >= 0x2B740 && c <= 0x2B81F) ||   // CJK Unified Ideographs Extension D
                    (c >= 0x2B820 && c <= 0x2CEAF) ||   // CJK Unified Ideographs Extension E
                    (c >= 0xF900 && c <= 0xFAFF) ||     // CJK Compatibility Ideographs
                    (c >= 0x2F800 && c <= 0x2FA1F)) {   // CJK Compatibility Ideographs Supplement
                    return YES;
                }
            }
            return NO;
        };
        
        // Filter log files
        for (NSString *file in files) {
            @autoreleasepool {
                if ([file hasPrefix:@"App_"] && [file hasSuffix:@".log"]) {
                    
                    // Skip files containing Chinese characters - 在创建URL之前检测
                    if (containsChinese(file)) {
                        LOG_INFO_S("Skipping file with Chinese characters: %@", file);
                        continue;
                    }
                    
                    NSString *filePath = [logsDir stringByAppendingPathComponent:file];
                    
                    // Check if file exists and is valid
                    BOOL fileIsDir = NO;
                    BOOL exists = [fm fileExistsAtPath:filePath isDirectory:&fileIsDir];
                    
                    if (!exists || fileIsDir) {
                        continue;
                    }
                    
                    NSError *attrError = nil;
                    NSDictionary *attrs = [fm attributesOfItemAtPath:filePath error:&attrError];
                    if (attrError) {
                        continue;
                    }
                    
                    unsigned long long fileSize = [attrs fileSize];
                    if (fileSize == 0) {
                        continue;
                    }
                    
                    [fileURLs addObject:[NSURL fileURLWithPath:filePath]];
                }
            }
        }
        
        if (fileURLs.count == 0) {
            LOG_INFO_S("No valid log files found (excluding files with Chinese characters)");
            return;
        }
        
        LOG_INFO_S("Found %lu valid log files (excluding files with Chinese characters)", (unsigned long)fileURLs.count);
        
        // Check and create target directory
        NSString *zipDir = [zipPathStr stringByDeletingLastPathComponent];
        if (![fm fileExistsAtPath:zipDir]) {
            if (![fm createDirectoryAtPath:zipDir withIntermediateDirectories:YES attributes:nil error:&error]) {
                LOG_ERROR_S("Failed to create directory: %@", error);
                return;
            }
        }
        
        // Delete existing ZIP file
        if ([fm fileExistsAtPath:zipPathStr]) {
            if (![fm removeItemAtPath:zipPathStr error:&error]) {
                LOG_ERROR_S("Failed to delete old file: %@", error);
            }
        }
        
        // Create compressed ZIP file using Compression.h
        bool success = CreateCompressedZipWithFiles(fileURLs, zipPathStr);
        
        if (success) {
            LOG_INFO_S("Log files packed successfully: %@", zipPathStr);
        } else {
            LOG_ERROR_S("Failed to pack log files");
        }
    }
}

std::string LogHelper::GetUploadFile(const std::string &appleId, const std::string &timeStamp)
{
    std::string root = GetReportFolder();
    std::string uploadFile = "";
    char temp[32] = { 0 };
    uint64_t random;
    RAND_bytes((uint8_t*)&random, sizeof(random));
    snprintf(temp, sizeof(temp) - 1, "%llX.zip", random); // 改为zip格式
    if (!root.empty()) {
        // 替换时间戳中的空格为下划线
        std::string safeTimeStamp = timeStamp;
        std::replace(safeTimeStamp.begin(), safeTimeStamp.end(), ' ', '_');
        uploadFile = root + "/" + appleId + "_" + safeTimeStamp + "_" + temp;
    } else {
        // 替换时间戳中的空格为下划线
        std::string safeTimeStamp = timeStamp;
        std::replace(safeTimeStamp.begin(), safeTimeStamp.end(), ' ', '_');
        uploadFile = "./" + appleId + "_" + safeTimeStamp + "_" + temp;
    }
    
    std::vector<std::string> timeList;
//    std::string endTime;
//    BuildLogTime(timeStamp, timeList, endTime);
    
    // 改为打包符合条件的完整文件
    PackLogFiles(timeList, uploadFile);
    return uploadFile;
}

void LogHelper::Log(const std::string& func, const int line,
    unsigned long grade, const void* caller, const char* format, ...)
{
    if (debugLevel_ > grade || grade > LOG_F_GRADE) {
        return;
    }

    auto saveLog = std::make_shared<stLogItem>();
    const std::string logFlag[] = { "INFO", "DEBUG", "ERROR", "FATAL" };
    
    // 获取当前时间
    auto now = std::chrono::system_clock::now();
    auto now_t = std::chrono::system_clock::to_time_t(now);
    auto now_ms = std::chrono::duration_cast<std::chrono::milliseconds>(
        now.time_since_epoch()) % 1000;
    
    std::tm* tm_now = std::localtime(&now_t);
    
    saveLog->year = tm_now->tm_year + 1900;
    saveLog->month = tm_now->tm_mon + 1;
    saveLog->day = tm_now->tm_mday;
    saveLog->hour = tm_now->tm_hour;
    saveLog->minute = tm_now->tm_min;
    saveLog->second = tm_now->tm_sec;
    saveLog->milliseconds = now_ms.count();
    saveLog->threadId = GetThreadId();
    saveLog->caller = reinterpret_cast<uintptr_t>(caller);
    saveLog->line = line;
    saveLog->logFlag = logFlag[grade - 1];
    saveLog->funcName = func;
    
    memset(saveLog->logBuff, 0, sizeof(saveLog->logBuff));
    va_list varArgs;
    va_start(varArgs, format);
    int err = vsnprintf(saveLog->logBuff, sizeof(saveLog->logBuff) - 1, format, varArgs);
    va_end(varArgs);
    
    if (err < 0) {
        return;
    }

    WriteData2File(saveLog);
}

void LogHelper::WriteData2File(std::shared_ptr<stLogItem> saveLog)
{
    std::unique_lock<std::mutex> lock(mutex_);
    if (isRunning_) {
        logList_.push_back(saveLog);
        cv_.notify_one();
    }
}

std::shared_ptr<LogHelper> LogHelper::GetInstance(void)
{
    if (instance_ == nullptr) {
        std::lock_guard<std::mutex> autoLock(instanceLock_);
        if (instance_ == nullptr) {
            instance_ = std::shared_ptr<LogHelper>(new LogHelper());
        }
    }
    return instance_;
}

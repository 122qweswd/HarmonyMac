//
//  LTSLoggerLevel.h
//  LTSSDK
//
//  Created by LTS on 2023/6/6.
//

#ifndef LTSLoggerLevel_h
#define LTSLoggerLevel_h

/** 日志级别 */
typedef NS_ENUM(NSUInteger, LTSLoggerLevel) {
    LTSLoggerLevelDebug, /// 输出所有级别日志
    LTSLoggerLevelInfo,  /// 输出Info级别以上日志
    LTSLoggerLevelWarn,  /// 输出Warn级别以上日志
    LTSLoggerLevelError, /// 仅输出Error日志
    LTSLoggerLevelOff    /// 不输出日志
};

#endif /* LTSLoggerLevel_h */

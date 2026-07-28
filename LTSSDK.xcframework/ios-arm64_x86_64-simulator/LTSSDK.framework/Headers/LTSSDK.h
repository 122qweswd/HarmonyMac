//
//  LTSSDK.h
//  LTSSDK
//
//  Created by LTS on 2023/5/19.
//
//

#import <Foundation/Foundation.h>
#import <LTSSDK/LTSConfigParams.h>
#import <LTSSDK/LTSLoggerLevel.h>

NS_ASSUME_NONNULL_BEGIN

@interface LTSSDK : NSObject

/**
 使用配置项初始化实例对象
 
 @param params 配置项.
 */
- (instancetype)initWithConfig:(LTSConfigParams *)params;

/**
 设置配置项
 
 @param params 配置项.
 @return 入参检测通过返回YES，否则返回NO.
 */
- (BOOL)config:(LTSConfigParams *)params DEPRECATED_MSG_ATTRIBUTE("Use initWithConfig instead");

/**
 上报日志：先存入本地数据库，根据策略实施上报.
 
 @param content 日志内容。支持字典或字典数组；最外层键值对最多300个；字典转JSON字符串最大支持长度为30720，超出部分将被截断再上报。
 @param labels 日志标签。支持字典或空值；最外层键值对最多50个；最外层key最大长度为64，支持字母、数字和下划线组合，首字符须是字母；字典转JSON字符串最大支持长度为30720，超出则该条日志无法上报。
 @return 入参及内部状态检测通过返回YES，否则返回NO.
 */
- (BOOL)report:(id)content labels:(nullable NSDictionary<NSString *, id> *)labels;

/**
 立即上报日志.
 
 @param content 日志内容。支持字典或字典数组；最外层键值对最多300个；字典转JSON字符串最大支持长度为30720，超出部分将被截断再上报。
 @param labels 日志标签。支持字典或空值；最外层键值对最多50个；最外层key最大长度为64，支持字母、数字和下划线组合，首字符须是字母；字典转JSON字符串最大支持长度为30720，超出则该条日志无法上报。
 @return 入参及内部状态检测通过返回YES，否则返回NO.
 */
- (BOOL)reportImmediately:(id)content labels:(nullable NSDictionary<NSString *, id> *)labels;

/**
 设置Debug日志级别. 【默认不输出调试日志】
 
 @param logLevel 日志级别.
 */
+ (void)setLogLevel:(LTSLoggerLevel)logLevel;

@end

NS_ASSUME_NONNULL_END

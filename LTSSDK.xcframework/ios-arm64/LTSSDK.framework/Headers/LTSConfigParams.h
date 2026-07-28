//
//  LTSConfigParams.h
//  LTSSDK
//
//  Created by LTS on 2023/5/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 @warning 扩充字段后，需在.m文件copy函数添加代码.
 */
@interface LTSConfigParams : NSObject<NSCopying>

/**
 上报LTS所处的region.
 
 @note 必填，length <= 128.
 */
@property (nonatomic, copy) NSString *region;

/**
 项目ID.
 
 @note 必填，length <= 128.
 */
@property (nonatomic, copy) NSString *projectId;

/**
 日志组ID.
 
 @note 必填，length <= 128.
 */
@property (nonatomic, copy) NSString *groupId;

/**
 日志流ID.
 
 @note 必填，length <= 128.
 */
@property (nonatomic, copy) NSString *streamId;

/**
 华为云访问密钥
 
 @note 必填，length <= 128.
 */
@property (nonatomic, copy) NSString *accessKey;

/**
 华为云秘密访问密钥.
 
 @note 必填，length <= 128.
 */
@property (nonatomic, copy) NSString *secretKey;

/**
 要上报的LTS的公网地址域名.
 
 @note 选填，为空时SDK将使用region拼接url.
 */
@property (nonatomic, copy, nullable) NSString *url;

/**
 缓存阈值.
 
 @note 选填，日志缓存数量达到该阈值会触发上报，默认值200，合法区间[30, 1000]
 */
@property (nonatomic, assign) NSUInteger cacheThreshold;

/**
 定时上报时间间隔.
 
 @note 选填，定时器每隔该阈值会触发上报，默认值3秒，合法区间[1, 1800].
 */
@property (nonatomic, assign) NSUInteger timeInterval;

/**
 是否开启进入后台时上报功能.
 
 @note 选填，默认值YES.
 */
@property (nonatomic, assign, getter=isReportWhenEnterBackgroundEnabled) BOOL reportWhenEnterBackgroundEnabled;

/**
 是否开启APP启动时上报功能.
 
 @note 选填，默认值NO，请在UIApplicationDidFinishLaunchingNotification通知发送前完成配置.
 */
@property (nonatomic, assign, getter=isReportWhenAPPLaunchEnabled) BOOL reportWhenAPPLaunchEnabled;

@end

NS_ASSUME_NONNULL_END

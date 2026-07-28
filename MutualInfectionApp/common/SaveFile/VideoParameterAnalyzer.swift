//
//  VideoParameterAnalyzer.swift
//  MutualInfection
//
//  Created by apple on 2025/11/29.
//


import AVFoundation
import UIKit

class VideoParameterAnalyzer: NSObject {
    
    // MARK: - 公开方法
    func analyzeVideoParameters(videoURL: URL, completion: @escaping ([String: Any]?, Error?) -> Void) {
        
        // 验证文件存在性
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            completion(nil, NSError(domain: "VideoParameterAnalyzer", code: 404,
                                    userInfo: [NSLocalizedDescriptionKey: "视频文件不存在"]))
            return
        }
        
        let asset = AVAsset(url: videoURL)
        
        // 异步加载轨道信息
        asset.loadValuesAsynchronously(forKeys: ["tracks", "duration"]) {
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let parameters = try self.extractVideoParameters(from: asset)
                    DispatchQueue.main.async {
                        completion(parameters, nil)
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(nil, error)
                    }
                }
            }
        }
    }
    
    // MARK: - 私有方法
    private func extractVideoParameters(from asset: AVAsset) throws -> [String: Any] {
        var parameters: [String: Any] = [:]
        
        // 1. 获取视频轨道
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            throw NSError(domain: "VideoParameterAnalyzer", code: 400,
                          userInfo: [NSLocalizedDescriptionKey: "未找到视频轨道"])
        }
        
        // 2. 提取基础视频信息
        parameters["basicInfo"] = self.extractBasicVideoInfo(from: videoTrack, asset: asset)
        
        // 3. 获取推荐的写入参数
        parameters["recommendedSettings"] = self.getRecommendedWriterSettings(for: videoTrack)
        
        // 4. 获取格式描述信息
        parameters["formatDescriptions"] = self.extractFormatDescriptions(from: videoTrack)
        
        // 5. 获取编码级别支持
        parameters["codecCapabilities"] = self.analyzeCodecCapabilities(for: videoTrack)
        
        return parameters
    }
    
    private func extractBasicVideoInfo(from videoTrack: AVAssetTrack, asset: AVAsset) -> [String: Any] {
        var basicInfo: [String: Any] = [:]
        
        // 分辨率
        basicInfo["naturalSize"] = [
            "width": videoTrack.naturalSize.width,
            "height": videoTrack.naturalSize.height
        ]
        
        // 帧率
        if !videoTrack.nominalFrameRate.isZero {
            basicInfo["frameRate"] = videoTrack.nominalFrameRate
        }
        
        // 时长
        basicInfo["duration"] = CMTimeGetSeconds(asset.duration)
        
        // 码率（估算）
        basicInfo["estimatedDataRate"] = videoTrack.estimatedDataRate
        
        // 旋转和变换信息
        basicInfo["preferredTransform"] = [
            "a": videoTrack.preferredTransform.a,
            "b": videoTrack.preferredTransform.b,
            "c": videoTrack.preferredTransform.c,
            "d": videoTrack.preferredTransform.d
        ]
        
        // 时间范围
        basicInfo["timeRange"] = [
            "start": CMTimeGetSeconds(videoTrack.timeRange.start),
            "duration": CMTimeGetSeconds(videoTrack.timeRange.duration)
        ]
        
        return basicInfo
    }
    
    private func getRecommendedWriterSettings(for videoTrack: AVAssetTrack) -> [String: Any] {
        var settings: [String: Any] = [:]
        
        let naturalSize = videoTrack.naturalSize
        let frameRate = videoTrack.nominalFrameRate
        let originalBitrate = Int(videoTrack.estimatedDataRate)
        
        ShareAPI.shared().log(2, "originalBitrate: \(originalBitrate/1_000_000) Mbps")
        
        // 计算目标比特率
        let targetBitrate: Int
        if originalBitrate > 20_000_000 {
            targetBitrate = 15_000_000 // 如果原始太高，限制到15Mbps
        } else if originalBitrate > 0 {
            targetBitrate = originalBitrate // 保持原始
        } else {
            targetBitrate = 12_000_000 // 默认值
        }
        
        ShareAPI.shared().log(2, "targetBitrate: \(targetBitrate/1_000_000) Mbps")
        
        // HEVC 设置 - 简洁版本
        if #available(iOS 11.0, *) {
            let profileLevel = "HEVC_Main_AutoLevel"
            
            settings["hevc"] = [
                AVVideoCodecKey: AVVideoCodecType.hevc,
                AVVideoWidthKey: naturalSize.width,
                AVVideoHeightKey: naturalSize.height,
                AVVideoScalingModeKey: AVVideoScalingModeResizeAspect,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: targetBitrate,
                    AVVideoMaxKeyFrameIntervalKey: 30,
                    AVVideoProfileLevelKey: profileLevel,
                    AVVideoExpectedSourceFrameRateKey: frameRate > 0 ? frameRate : 30,
                    AVVideoAllowFrameReorderingKey: false
                    
                ] as [String: Any]
            ] as [String: Any]
        }
        
        // H.264 设置
        settings["h264"] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: naturalSize.width,
            AVVideoHeightKey: naturalSize.height,
            AVVideoScalingModeKey: AVVideoScalingModeResizeAspect,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: Int(Double(targetBitrate) * 1.5),
                AVVideoMaxKeyFrameIntervalKey: 30,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoExpectedSourceFrameRateKey: frameRate > 0 ? frameRate : 30,
                AVVideoAllowFrameReorderingKey: false
            ] as [String: Any]
        ] as [String: Any]
        
        // 记录原始信息
        if let originalCodec = getOriginalCodec(from: videoTrack) {
            settings["originalCodec"] = originalCodec
            settings["originalBitrate"] = originalBitrate
        }
        
        return settings
    }
    
    // 新增函数1：获取原始编码（必须新增）
    private func getOriginalCodec(from videoTrack: AVAssetTrack) -> String? {
        let formatDescriptions = videoTrack.formatDescriptions as? [CMFormatDescription]
        guard let formatDescription = formatDescriptions?.first else {
            return nil
        }
        
        let codecType = CMFormatDescriptionGetMediaSubType(formatDescription)
        
        switch codecType {
        case kCMVideoCodecType_HEVC:
            return "HEVC"
        case kCMVideoCodecType_H264:
            return "H.264"
        case kCMVideoCodecType_MPEG4Video:
            return "MPEG-4"
        default:
            return "UNKNOWN"
        }
    }
    
    // 可选：新增函数2 - 简化创建设置的函数（可选，也可以内联）
    private func createVideoSettings(codec: AVVideoCodecType,
                                     size: CGSize,
                                     bitrate: Int,
                                     frameRate: Float,
                                     profileLevel: Any) -> [String: Any] {
        
        let compressionProperties: [String: Any] = [
            AVVideoAverageBitRateKey: bitrate,
            AVVideoMaxKeyFrameIntervalKey: 30,
            AVVideoQualityKey: 0.94,
            AVVideoProfileLevelKey: profileLevel,
            AVVideoExpectedSourceFrameRateKey: frameRate > 0 ? frameRate : 30,
            AVVideoAllowFrameReorderingKey: false
        ]
        
        return [
            AVVideoCodecKey: codec,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height,
            AVVideoScalingModeKey: AVVideoScalingModeResizeAspect,
            AVVideoCompressionPropertiesKey: compressionProperties
        ] as [String: Any]
    }
    
    private func extractFormatDescriptions(from videoTrack: AVAssetTrack) -> [[String: Any]] {
        var formatDescriptions: [[String: Any]] = []
        
        for formatDescription in videoTrack.formatDescriptions {
            var formatInfo: [String: Any] = [:]
            
            let mediaType = CMFormatDescriptionGetMediaType(formatDescription as! CMFormatDescription)
            formatInfo["mediaType"] = mediaType
            
            // 获取编码类型
            let codecType = CMFormatDescriptionGetMediaSubType(formatDescription as! CMFormatDescription)
            formatInfo["codecType"] = codecType
            
            // 获取扩展信息
            if let extensions = CMFormatDescriptionGetExtensions(formatDescription as! CMFormatDescription) as? [String: Any] {
                formatInfo["extensions"] = extensions
            }
            
            // 获取视频维度
            let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription as! CMFormatDescription)
            formatInfo["dimensions"] = [
                "width": dimensions.width,
                "height": dimensions.height
            ]
            
            formatDescriptions.append(formatInfo)
        }
        
        return formatDescriptions
    }
    
    private func analyzeCodecCapabilities(for videoTrack: AVAssetTrack) -> [String: Any] {
        var capabilities: [String: Any] = [:]
        
        // 编码器支持情况
        capabilities["supportedCodecs"] = [
            "h264": true,
            "hevc": true,
            "prores": true,
            "jpeg": false
        ]
        
        // 支持的像素格式
        let pixelFormats: [String: Bool] = [
            "32BGRA": true,
            "420YpCbCr8BiPlanarVideoRange": true,
            "420YpCbCr8BiPlanarFullRange": true
        ]
        capabilities["pixelFormats"] = pixelFormats
        
        // 最大分辨率支持
        capabilities["maxResolution"] = [
            "width": 4096,
            "height": 2160
        ]
        
        return capabilities
    }
    
    // MARK: - 实用工具方法
    static func createWriterSettings(from parameters: [String: Any]) -> [String: Any]? {
        guard let recommendedSettings = parameters["recommendedSettings"] as? [String: Any] else {
            ShareAPI.shared().log(3, "createWriterSettings: no recommendedSettings")
            return nil
        }
        
        // 尝试获取原始编码
        var originalCodec: String?
        
        // 1. 从 recommendedSettings 获取
        originalCodec = recommendedSettings["originalCodec"] as? String
        
        // 2. 从 basicInfo 获取
        if originalCodec == nil, let basicInfo = parameters["basicInfo"] as? [String: Any] {
            originalCodec = basicInfo["codec"] as? String
        }
        
        ShareAPI.shared().log(2, "originalCodec: \(originalCodec ?? "unknown")")
        
        // 如果是 HEVC 且有 HEVC 设置，使用 HEVC
        if let codec = originalCodec?.lowercased(),
           (codec.contains("hevc") || codec.contains("h265")),
           let hevcSettings = recommendedSettings["hevc"] as? [String: Any] {
            ShareAPI.shared().log(2, "codec is hevc")
            return hevcSettings
        }
        
        // 其他情况使用 H.264
        if let h264Settings = recommendedSettings["h264"] as? [String: Any] {
            ShareAPI.shared().log(2, "codec is h.264")
            return h264Settings
        }
        
        ShareAPI.shared().log(3, "codec is unknown")
        return nil
    }
}

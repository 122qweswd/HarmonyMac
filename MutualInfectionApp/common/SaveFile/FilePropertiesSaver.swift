//
//  FileProoertiesSaver.swift
//  MutualInfection
//
//  Created by apple on 2025/12/3.
//

import ImageIO
import CoreGraphics
import CoreImage
import AVFoundation
import CoreMedia


class FilePropertiesSaver {
    
    // 获取文件元数据
    static func getProperties(from sourceImageURL: URL) -> [CFString: Any]? {
        guard let imageSource = CGImageSourceCreateWithURL(sourceImageURL as CFURL, nil) else {
            ShareAPI.shared().log(3, "[SaveFile] [FilePropertiesSaver] create image source fail")
            return nil
        }
        
        guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            ShareAPI.shared().log(3, "[SaveFile] [FilePropertiesSaver] can not read image properties")
            return nil
        }
        
        return imageProperties
    }
    
    
    /// 向MP4文件添加元数据而不重新编码视频内容
    /// - Parameters:
    ///   - sourceURL: 源文件URL
    ///   - destinationURL: 目标文件URL
    ///   - metadata: 要添加的元数据字典
    ///   - completion: 完成回调
    static func addMetadata(
        sourceURL: URL,
        destinationURL: URL,
        metadata: [(String, String, Any, String)],
        completion: @escaping (Bool, Error?) -> Void
    ) {
        // 创建AVAsset实例
        let asset = AVAsset(url: sourceURL)
        
        // 创建导出会话
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            completion(false, NSError(domain: "MP4MetadataWriter", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法创建导出会话"]))
            return
        }
        
        // 配置导出会话
        exportSession.outputURL = destinationURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        // 创建元数据项
        var metadataItems = asset.metadata
    
        for (key, keySpace, value, dataType) in metadata {
            metadataItems = metadataItems.filter {
                !($0.key as? String == key &&
                  $0.keySpace?.rawValue == keySpace)
            }
            
            let item = AVMutableMetadataItem()
            item.key = key as (NSCopying & NSObjectProtocol)?
            item.keySpace = AVMetadataKeySpace(rawValue: keySpace)
            item.value = value as? NSCopying & NSObjectProtocol
            item.dataType = dataType
            metadataItems.append(item)
        }
        
        // 设置元数据
        exportSession.metadata = metadataItems
        
        // 开始导出
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                completion(true, nil)
            case .failed:
                completion(false, exportSession.error)
            case .cancelled:
                completion(false, NSError(domain: "MP4MetadataWriter", code: 2, userInfo: [NSLocalizedDescriptionKey: "导出被取消"]))
            default:
                completion(false, NSError(domain: "MP4MetadataWriter", code: 2, userInfo: [NSLocalizedDescriptionKey: "未知原因取消"]))
                break
            }
        }
    }
}

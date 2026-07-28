//
//  LivePhotoPreprocessor.swift
//  MutualInfection
//
//  Created by mac on 2025/10/23.
//


import Photos
#if MAIN_APP || SHARE_EXTENSION
import MobileCoreServices
#endif
import ImageIO
import AVFoundation

class LivePhotoPreprocessor {
    
    /// 验证JPG和MOV文件的元数据完整性
    static func validateMetadata(jpgURL: URL, movURL: URL) -> Bool {
        // 验证JPG文件是否为有效图像
        guard let jpgSource = CGImageSourceCreateWithURL(jpgURL as CFURL, nil),
              CGImageSourceGetCount(jpgSource) > 0 else {
            ShareAPI.shared().log(3, "[SaveFile] [LivePhotoPreprocessor] 实况图落盘：JPG文件无效或损坏")
            return false
        }
        
        // 验证MOV文件是否为有效视频
        let movAsset = AVAsset(url: movURL)
        guard movAsset.isReadable, !movAsset.tracks(withMediaType: .video).isEmpty else {
            ShareAPI.shared().log(3, "[SaveFile] [LivePhotoPreprocessor] 实况图落盘：MOV文件无效或损坏")
            return false
        }
        
        // 1. 检查content identifier一致性
        if !checkContentIdentifierConsistency(jpgURL: jpgURL, movURL: movURL) {
            ShareAPI.shared().log(3, "[SaveFile] [LivePhotoPreprocessor] 实况图落盘：content identifier不一致")
            return false
        }
        
        // 2. 检查时间戳一致性（JPG拍摄时间与MOV首帧时间）
//        if !checkTimestampConsistency(jpgURL: jpgURL, movURL: movURL) {
//            ShareAPI.shared().log(3, "实况图落盘：时间戳不一致")
//            return false
//        }
        
        return true
    }
    
    private static func checkTimestampConsistency(jpgURL: URL, movURL: URL) -> Bool {
        // 获取JPG文件的拍摄时间
        guard let jpgTimestamp = getImageCreationDate(from: jpgURL) else {
            ShareAPI.shared().log(3, "[SaveFile] [LivePhotoPreprocessor] 无法读取JPG文件的拍摄时间")
            return false
        }
        
        // 获取MOV文件的首帧时间戳
        guard let movFirstFrameTime = getFirstFrameTimestamp(from: movURL) else {
            ShareAPI.shared().log(3, "[SaveFile] [LivePhotoPreprocessor] 无法读取MOV文件的首帧时间")
            return false
        }
        
        // 比较时间戳是否一致（允许一定的误差范围）
        let timeDifference = abs(jpgTimestamp.timeIntervalSince(movFirstFrameTime))
        let tolerance: TimeInterval = 2.0 // 允许2秒的误差
        
        return timeDifference <= tolerance
    }

    // 辅助函数：从JPG文件中提取拍摄时间
    private static func getImageCreationDate(from url: URL) -> Date? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        
        let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any]
        let exifDict = properties?[kCGImagePropertyExifDictionary as String] as? [String: Any]
        
        // 优先使用Exif中的DateTimeOriginal，这是最准确的拍摄时间
        if let dateTimeOriginal = exifDict?[kCGImagePropertyExifDateTimeOriginal as String] as? String {
            return parseExifDateString(dateTimeOriginal)
        }
        
        // 如果没有DateTimeOriginal，则使用文件的创建时间
        do {
            let resourceValues = try url.resourceValues(forKeys: [.creationDateKey])
            return resourceValues.creationDate
        } catch {
            return nil
        }
    }

    // 辅助函数：从MOV文件中获取首帧时间戳
    private static func getFirstFrameTimestamp(from url: URL) -> Date? {
        let asset = AVAsset(url: url)
        
        // 获取视频轨道
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            return nil
        }
        
        // 读取第一个视频样本（帧）的时间戳
        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            return nil
        }
        
        let output = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)
        reader.add(output)
        
        guard reader.startReading() else {
            return nil
        }
        
        // 获取第一个样本
        if let sampleBuffer = output.copyNextSampleBuffer() {
            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            let seconds = CMTimeGetSeconds(presentationTime)
            
            // 将相对时间转换为绝对时间（基于文件的创建时间）
            do {
                let resourceValues = try url.resourceValues(forKeys: [.creationDateKey])
                if let fileCreationDate = resourceValues.creationDate {
                    return fileCreationDate.addingTimeInterval(seconds)
                }
            } catch {
                return nil
            }
        }
        
        return nil
    }

    // 辅助函数：解析Exif日期字符串
    private static func parseExifDateString(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        return formatter.date(from: dateString)
    }

    
    /// 检查JPG和MOV文件的content identifier一致性
    private static func checkContentIdentifierConsistency(jpgURL: URL, movURL: URL) -> Bool {
        let jpgIdentifier = getContentIdentifier(from: jpgURL)
        let movIdentifier = getContentIdentifier(from: movURL)
        
        // 如果标识符都存在但不一致，需要统一
        if let jpgID = jpgIdentifier, let movID = movIdentifier {
            if jpgID != movID {
                ShareAPI.shared().log(3, "[SaveFile] [LivePhotoPreprocessor] 检测到不一致的content identifier: JPG=\(jpgID), MOV=\(movID)")
                return false
            }
            return true
        }
        if jpgIdentifier == nil || movIdentifier == nil {
            ShareAPI.shared().log(3, "[SaveFile] [LivePhotoPreprocessor] 检测到content identifier为空: JPG:\(jpgIdentifier ?? ""), MOV\(movIdentifier ?? "")")
        }
        
        // 如果标识符缺失，需要补充
        return jpgIdentifier == nil && movIdentifier == nil
    }
    
    /// 从文件中提取content identifier
    private static func getContentIdentifier(from fileURL: URL) -> String? {
        if fileURL.pathExtension.lowercased() == "mov" {
            return getContentIdentifierFromMOV(url: fileURL)
        } else {
            return getContentIdentifierFromJPG(url: fileURL)
        }
    }
    
    /// 从MOV文件提取content identifier
    private static func getContentIdentifierFromMOV(url: URL) -> String? {
        let asset = AVAsset(url: url)
        let metadata = asset.metadata
        
        for item in metadata {
            if item.identifier == .quickTimeMetadataContentIdentifier {
                return item.stringValue
            }
        }
        return nil
    }
    
    /// 从JPG文件提取content identifier
    private static func getContentIdentifierFromJPG(url: URL) -> String? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return nil
        }
        
        // 在JPG的Exif或TIFF数据中查找标识符
        if let exif = metadata["{MakerApple}"] as? [String: Any],
           let identifier = exif["17"] as? String {
            return identifier
        }
        
        return nil
    }
}

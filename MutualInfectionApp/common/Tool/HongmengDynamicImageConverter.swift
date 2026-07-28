//
//  HongmengDynamicImageConverter.swift
//  FrameProduct
//
//  Created by delegate on 2025/9/11.
//

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import Photos
import AVFoundation
import ImageIO
#if MAIN_APP || SHARE_EXTENSION
import MobileCoreServices
#endif

// 定义转换过程中的错误类型
enum HarmonyConversionError: Error {
    case permissionDenied
    case noLivePhotoData
    case imageExtractionFailed
    case videoExtractionFailed
    case fileCreationFailed
    case fileWritingFailed
    case partialFailure(String)
}

extension HarmonyConversionError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "相册权限被拒绝"
        case .noLivePhotoData: return "无法获取Live Photo资源"
        case .imageExtractionFailed: return "静态图片提取失败"
        case .videoExtractionFailed: return "动态视频提取失败"
        case .fileCreationFailed: return "临时文件创建失败"
        case .fileWritingFailed: return "文件写入失败"
        case .partialFailure(let msg): return "部分操作失败: \(msg)"
        }
    }
}

class HongmengDynamicImageConverter: NSObject {
    // 单例模式避免重复创建
    static let shared = HongmengDynamicImageConverter()
    private let UTTypePublicJPEG = "public.jpeg" as CFString
    private override init() {}
    
    // 专用队列处理异步操作，避免阻塞主线程
    private let conversionQueue = DispatchQueue(label: "com.converter.harmony", qos: .userInitiated)
    // 缓存权限状态，减少系统调用
    private var photoPermissionCache: PHAuthorizationStatus?
    
    /// 转换Live Photo为鸿蒙动态照片
    /// - Parameters:
    ///   - asset: Live Photo资源
    ///   - completion: 完成回调，返回包含图片和视频URL的数组
    func convertLivePhoto(_ asset: PHAsset, completion: @escaping (Result<[URL], Error>) -> Void) {
        // 检查资源类型是否为Live Photo
        guard asset.mediaType == .image, asset.mediaSubtypes.contains(.photoLive) else {
            completion(.failure(HarmonyConversionError.noLivePhotoData))
            return
        }
        
        // 权限检查与转换操作串联执行
        checkPhotoPermission { [weak self] granted in
            guard let self = self, granted else {
                completion(.failure(HarmonyConversionError.permissionDenied))
                return
            }
            
            // 在专用队列处理资源提取
            self.conversionQueue.async {
                self.extractLivePhotoResources(asset: asset) { result in
                    DispatchQueue.main.async { // 确保回调在主线程
                        completion(result)
                    }
                }
            }
        }
    }
    
    /// 清理临时文件
    /// - Parameter urls: 需要清理的文件URL数组
    func cleanTempFiles(_ urls: [URL]) {
        conversionQueue.async {
            urls.forEach { url in
                do {
                    if FileManager.default.fileExists(atPath: url.path) {
                        try FileManager.default.removeItem(at: url)
                    }
                } catch {
                    print("清理临时文件失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 提取Live Photo资源
    private func extractLivePhotoResources(asset: PHAsset, completion: @escaping (Result<[URL], Error>) -> Void) {
        let group = DispatchGroup()
        var imageURL: URL?
        var videoURL: URL?
        var currentError: Error?
        
        // 提取静态图片
        group.enter()
        let imageOptions = PHImageRequestOptions()
        imageOptions.isNetworkAccessAllowed = true
        imageOptions.deliveryMode = .highQualityFormat
        imageOptions.resizeMode = .none // 不缩放，保持原始质量
        
        let imageRequestID = PHImageManager.default().requestImageDataAndOrientation(for: asset, options: imageOptions) {[weak self] data, _, _, _ in
            defer { group.leave() }
            guard let self = self, let data = data else {
                currentError = HarmonyConversionError.imageExtractionFailed
                return
            }
            
            do {
                imageURL = try self.writeImageDataToTempFile(data)
            } catch {
                currentError = error
            }
        }
        // 提取视频资源
        group.enter()
        guard let videoResource = PHAssetResource.assetResources(for: asset).first(where: { $0.type == .pairedVideo }) else {
            currentError = HarmonyConversionError.videoExtractionFailed
            group.leave()
            return
        }
        
        let videoOptions = PHAssetResourceRequestOptions()
        videoOptions.isNetworkAccessAllowed = true
        let tempVideoURL = self.createTempFileURL(withExtension: "mov")
        
        let videoRequestID = PHAssetResourceManager.default().requestData(for: videoResource, options: videoOptions) { data in
            do {
                if FileManager.default.fileExists(atPath: tempVideoURL.path) {
                    let handle = try FileHandle(forWritingTo: tempVideoURL)
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                } else {
                    try data.write(to: tempVideoURL)
                }
            } catch {
                currentError = HarmonyConversionError.fileWritingFailed
            }
        } completionHandler: { _ in
            defer { group.leave() }
            if currentError == nil {
                videoURL = tempVideoURL
            }
        }
        
        // 监控组完成状态
        group.notify(queue: conversionQueue) {
            if let error = currentError {
                completion(.failure(error))
                // 清理已创建的临时文件
                self.cleanTempFiles([imageURL, videoURL].compactMap { $0 })
            } else if let imageURL = imageURL, let videoURL = videoURL {
                completion(.success([imageURL, videoURL]))
            } else {
                completion(.failure(HarmonyConversionError.noLivePhotoData))
            }
        }
    }
    
    // 检查相册权限（跨平台实现）
    private func checkPhotoPermission(completion: @escaping (Bool) -> Void) {
        // 优先使用缓存的权限状态
        if let cachedStatus = photoPermissionCache {
            #if os(iOS)
            if #available(iOS 14, *) {
                completion(cachedStatus == .authorized || cachedStatus == .limited)
            } else {
                completion(cachedStatus == .authorized)
            }
            #elseif os(macOS)
            completion(cachedStatus == .authorized)
            #endif
            return
        }
        
        #if os(iOS)
        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
                self?.photoPermissionCache = status
                // iOS 平台通知：应用回到前台时清除缓存
                NotificationCenter.default.addObserver(
                    forName: UIApplication.willEnterForegroundNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    self?.photoPermissionCache = nil
                }
                completion(status == .authorized || status == .limited)
            }
        } else {
            PHPhotoLibrary.requestAuthorization { [weak self] status in
                self?.photoPermissionCache = status
                // iOS 平台通知：应用回到前台时清除缓存
                NotificationCenter.default.addObserver(
                    forName: UIApplication.willEnterForegroundNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    self?.photoPermissionCache = nil
                }
                completion(status == .authorized)
            }
        }
        #elseif os(macOS)
        // macOS 平台权限请求
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            self?.photoPermissionCache = status
            // macOS 平台通知：应用激活时清除缓存
            NotificationCenter.default.addObserver(
                forName: NSApplication.willBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.photoPermissionCache = nil
            }
            completion(status == .authorized)
        }
        #endif
    }
    
    // 辅助方法：创建临时文件URL
    private func createTempFileURL(withExtension ext: String) -> URL {
        let fileName = UUID().uuidString
        return FileManager.default.temporaryDirectory.appendingPathComponent("\(fileName).\(ext)")
    }
    
    // 辅助方法：将图片数据写入临时文件（保留元数据）
    private func writeImageDataToTempFile(_ data: Data) throws -> URL {
        let tempURL = createTempFileURL(withExtension: "jpeg")
        
        // 1. 从原始数据获取图片源和元数据
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw HarmonyConversionError.fileCreationFailed
        }
        
        // 获取原始图片的元数据（如EXIF、GPS、方向等）
        guard let originalProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            throw HarmonyConversionError.fileCreationFailed
        }
        
        // 2. 获取原始图片
        guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw HarmonyConversionError.fileCreationFailed
        }
        
        // 3. 创建图片目标，并合并元数据
        guard let destination = CGImageDestinationCreateWithURL(tempURL as CFURL, UTTypePublicJPEG, 1, nil) else {
            throw HarmonyConversionError.fileCreationFailed
        }
        
        // 合并原始元数据与新设置（压缩质量等）
        var outputProperties = originalProperties
        outputProperties[kCGImageDestinationLossyCompressionQuality] = 0.9 // 保留高质量
        
        // 4. 写入图片并保留元数据
        CGImageDestinationAddImage(destination, cgImage, outputProperties as CFDictionary)
        
        guard CGImageDestinationFinalize(destination) else {
            throw HarmonyConversionError.fileWritingFailed
        }
        
        return tempURL
    }
    
    // 清理通知观察者
    deinit {
        #if os(iOS)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
        #elseif os(macOS)
        NotificationCenter.default.removeObserver(self, name: NSApplication.willBecomeActiveNotification, object: nil)
        #endif
    }
}

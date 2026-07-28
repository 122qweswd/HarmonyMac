//
//  PhotoLibraryManager.swift
//  MutualInfectionApp
//
//  Created by Niko on 2025/9/29.
//

import Foundation
import Photos
import PhotosUI
//import UIKit

/// 照片库操作的单例管理器，具有广泛的兼容性 (iOS 13+)。
@objc public class PhotoLibraryManager: NSObject {
    @objc public static let shared = PhotoLibraryManager()

    private override init() {
        super.init()
    }

    // MARK: - 授权辅助方法 (兼容)

    /// 检查当前授权状态 (兼容 iOS13+)。
    /// 在 iOS14+ 上，当可用时我们查询 .readWrite 权限。
    @objc public func checkAuthorizationStatus(completion: @escaping (PHAuthorizationStatus) -> Void) {
        if #available(iOS 14, *) {
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            completion(status)
        } else {
            let status = PHPhotoLibrary.authorizationStatus()
            completion(status)
        }
    }

    /// 请求授权 (基于完成回调)。在 iOS13+ 上工作。
    @objc public func requestAuthorization(completion: @escaping (PHAuthorizationStatus) -> Void) {
        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async { completion(status) }
            }
        } else {
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async { completion(status) }
            }
        }
    }

    /// requestAuthorization 的异步变体，供使用 await 的调用者使用 (iOS15+ 将使用原生 API)。
    @available(iOS 13.0, *)
    @objc public func requestAuthorization() async -> PHAuthorizationStatus {
        if #available(iOS 15, *) {
            return await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        } else {
            return await withCheckedContinuation { continuation in
                self.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
        }
    }

    // MARK: - 展示受限照片库选择器 (保留方法名称)

    /// 从视图控制器展示受限照片库选择器。
    /// 在 iOS15+ 上当可用时使用异步版本。在 iOS14 上使用同步调用。
    /// 在 iOS13 上显示提示，指示用户在设置中更改权限。
    @objc public func presentLimitedLibraryPicker(from viewController: UIViewController) {
        if #available(iOS 15, *) {
            Task {
                // Photos API 在 iOS15+ 上提供异步版本
                await PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: viewController)
            }
        } else if #available(iOS 14, *) {
            PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: viewController)
        } else {
            // iOS13 不支持受限选择器 - 指导用户前往设置
            let alert = UIAlertController(title: NSLocalizedString("需要访问照片", comment: ""),
                                          message: NSLocalizedString("请前往 设置 -> 隐私 -> 照片 打开权限", comment: ""),
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: NSLocalizedString("去设置", comment: ""), style: .default, handler: { _ in
                if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)
                }
            }))
            viewController.present(alert, animated: true, completion: nil)
        }
    }

    // MARK: - 删除资源 (保留方法名称)

    /// 通过本地标识符删除资源 (异步版本)。在 iOS15+ 上使用 async/await；否则使用 performChanges 并桥接到 async。
    /// 如果删除成功返回 true。
    @available(iOS 13.0, *)
    @objc public func deleteAssets(localIdentifiers: [String]) async throws -> Bool {
        if #available(iOS 15, *) {
            // 在 iOS15+ 上我们仍然可以使用 performChanges，但为了整洁的调用点而包装在 async 中
            return try await withCheckedThrowingContinuation { continuation in
                let assets = PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: nil)
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.deleteAssets(assets)
                }, completionHandler: { success, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: success)
                    }
                })
            }
        } else {
            // iOS13/14 的回退方案
            return try await withCheckedThrowingContinuation { continuation in
                let assets = PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: nil)
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.deleteAssets(assets)
                }, completionHandler: { success, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: success)
                    }
                })
            }
        }
    }

    /// 使用完成处理程序删除资源，供异步之前的调用者使用。
    @objc public func deleteAssets(localIdentifiers: [String], completion: @escaping (Bool, Error?) -> Void) {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: nil)
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assets)
        }, completionHandler: { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        })
    }

    // MARK: - 获取辅助方法 (兼容)

    /// 通过本地标识符获取 PHAsset。
    @objc public func fetchAsset(localIdentifier: String) -> PHAsset? {
        let results = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        return results.firstObject
    }

    /// 获取资源的 UIImage (尽可能使用异步)
    @available(iOS 13.0, *)
    @objc public func requestImage(for asset: PHAsset, targetSize: CGSize, contentMode: PHImageContentMode = .aspectFit) async -> UIImage? {
        if #available(iOS 15, *) {
            return await withCheckedContinuation { continuation in
                let options = PHImageRequestOptions()
                options.isSynchronous = false
                options.deliveryMode = .highQualityFormat
                options.resizeMode = .fast
                PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: contentMode, options: options) { image, _ in
                    continuation.resume(returning: image)
                }
            }
        } else {
            return await withCheckedContinuation { continuation in
                let options = PHImageRequestOptions()
                options.isSynchronous = false
                options.deliveryMode = .highQualityFormat
                options.resizeMode = .fast
                PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: contentMode, options: options) { image, _ in
                    continuation.resume(returning: image)
                }
            }
        }
    }

    /// requestImage 的非异步变体
    @objc public func requestImage(for asset: PHAsset, targetSize: CGSize, contentMode: PHImageContentMode = .aspectFit, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: contentMode, options: options) { image, _ in
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }

    // MARK: - 保存图片/视频辅助方法

    /// 将 UIImage 保存到照片库。成功时返回本地标识符字符串。
    @available(iOS 13.0, *)
    @objc public func saveImage(_ image: UIImage, albumTitle: String? = nil) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            var placeholderLocalId: String?
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
                if let albumTitle = albumTitle, !albumTitle.isEmpty {
                    // 尝试查找或创建相册
                    let collection = self.fetchAssetCollectionForAlbum(title: albumTitle)
                    if let collection = collection {
                        if let addAssetRequest = PHAssetCollectionChangeRequest(for: collection) {
                            placeholderLocalId = request.placeholderForCreatedAsset?.localIdentifier
                            if let placeholder = request.placeholderForCreatedAsset {
                                addAssetRequest.addAssets([placeholder] as NSArray)
                            }
                        }
                    } else {
                        // 创建相册并添加
                        let creationRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumTitle)
                        if let placeholder = request.placeholderForCreatedAsset {
                            creationRequest.addAssets([placeholder] as NSArray)
                        }
                        placeholderLocalId = request.placeholderForCreatedAsset?.localIdentifier
                    }
                } else {
                    placeholderLocalId = request.placeholderForCreatedAsset?.localIdentifier
                }
            }, completionHandler: { success, error in
                DispatchQueue.main.async {
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if success, let id = placeholderLocalId {
                        continuation.resume(returning: id)
                    } else {
                        continuation.resume(throwing: NSError(domain: "PhotoLibraryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "未知的保存错误"]))
                    }
                }
            })
        }
    }

    /// 辅助方法：通过相册标题查找资源集合
    @objc public func fetchAssetCollectionForAlbum(title: String) -> PHAssetCollection? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "localizedTitle = %@", title)
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        return collections.firstObject
    }

    // MARK: - 实用工具

    /// 通过将图片/视频写入临时位置并将 URL 返回，将资源转换为文件 URL。
    /// 如果原始资源是视频，它将把 AVAsset 导出到临时文件。
    @objc public func assetToTemporaryFileURL(asset: PHAsset, completion: @escaping (URL?, Error?) -> Void) {
        if asset.mediaType == .image {
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .highQualityFormat
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, uti, orientation, info in
                guard let data = data else {
                    DispatchQueue.main.async { completion(nil, NSError(domain: "PhotoLibraryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法获取图片数据"])) }
                    return
                }
                let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
                do {
                    try data.write(to: tmp)
                    DispatchQueue.main.async { completion(tmp, nil) }
                } catch {
                    DispatchQueue.main.async { completion(nil, error) }
                }
            }
        } else if asset.mediaType == .video {
            let options = PHVideoRequestOptions()
            options.version = .original
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, audioMix, info in
                guard let avAsset = avAsset else {
                    DispatchQueue.main.async { completion(nil, NSError(domain: "PhotoLibraryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法获取视频资源"])) }
                    return
                }
                // 导出到临时文件
                let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetHighestQuality)
                let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
                exportSession?.outputURL = tmp
                exportSession?.outputFileType = .mp4
                exportSession?.exportAsynchronously {
                    if exportSession?.status == .completed {
                        DispatchQueue.main.async { completion(tmp, nil) }
                    } else {
                        let err = exportSession?.error ?? NSError(domain: "PhotoLibraryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "视频导出失败"])
                        DispatchQueue.main.async { completion(nil, err) }
                    }
                }
            }
        } else {
            DispatchQueue.main.async { completion(nil, NSError(domain: "PhotoLibraryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "不支持的媒体类型"])) }
        }
    }

    // MARK: - 受限照片库信息的向后兼容辅助方法 (仅 iOS14+)

    /// 获取应用当前是否具有受限访问权限 (iOS14+)。在 iOS13 上返回 false。
    @objc public func isLimitedLibrary() -> Bool {
        if #available(iOS 14, *) {
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            return status == .limited
        } else {
            return false
        }
    }

    // MARK: - 保留常用名称的其他辅助方法

    /// 辅助方法，确保期望异步方法的代码可以在两个世界中调用。
    /// 保留的示例用法：await PhotoLibraryManager.shared.ensureAuthorized()
    @available(iOS 13.0, *)
    @objc public func ensureAuthorized() async throws {
        let status: PHAuthorizationStatus = await requestAuthorization()
        switch status {
        case .authorized, .limited:
            return
        case .notDetermined:
            throw NSError(domain: "PhotoLibraryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "权限未确定"])
        default:
            throw NSError(domain: "PhotoLibraryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "未授权访问照片"])
        }
    }
}

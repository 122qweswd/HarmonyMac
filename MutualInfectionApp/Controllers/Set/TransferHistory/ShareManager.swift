//
//  ShareManager.swift
//  MutualInfectionApp
//
//  Created by Niko on 2025/9/29.
//

import UIKit
import Photos

class ShareManager {
   
    /// 通用分享接口：自动判断是文件 URL 还是图片 identifier（带存在性检查）
    static func share(file: MITransferFile, from viewController: UIViewController, completion: ShareCompletion? = nil) {
        if file.fileType == .file || file.fileType == .contacts || file.fileType == .location, let absoluteFileUrl = file.absoluteFileUrl {
            shareFile(at: absoluteFileUrl, from: viewController, completion: completion)
        } else if file.fileType == .photoAndVideo, let identifier = file.identifier {
            sharePhoto(identifier: identifier, from: viewController, completion: completion)
        } else {
            let errorMessage = "不支持的分享类型"
            print(errorMessage)
            completion?(false, errorMessage)
        }
    }
    
    /// 查看
    static func open(file: MITransferFile, completion: ShareCompletion? = nil) {
        if file.fileType == .photoAndVideo {
            // 检查照片是否存在
            guard let identifier = file.identifier, photoExists(identifier: identifier) else {
                completion?(false, "")
                return
            }
            
            MIImagePickerManager.shared.openPhotoURLScheme { value in }
        } else {
            // 检查文件是否存在
            guard let absoluteFileUrl = file.absoluteFileUrl, fileExists(at: absoluteFileUrl) else {
                completion?(false, "")
                return
            }
            
            MIDocumentBrowserManager.share.openFileURLScheme { value in }
        }
    }
    
    // MARK: - 分享结果回调
    typealias ShareCompletion = (Bool, String?) -> Void
    
    /// 分享文件（带存在性检查）
    static func shareFile(at filePath: String, from viewController: UIViewController, completion: ShareCompletion? = nil) {
        // 检查文件是否存在
        guard fileExists(at: filePath) else {
            let errorMessage = "文件不存在: \(filePath)"
            print(errorMessage)
            completion?(false, errorMessage)
            return
        }
        
        guard let fileURL = URL(fileURLWithPath: filePath) as URL? else {
            let errorMessage = "无效的文件路径: \(filePath)"
            print(errorMessage)
            completion?(false, errorMessage)
            return
        }
        
        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = viewController.view
        
        // 设置完成回调
        activityVC.completionWithItemsHandler = { activityType, completed, returnedItems, error in
            if let error = error {
                print("分享失败: \(error)")
                completion?(true, "分享失败: \(error.localizedDescription)")
            } else if completed {
                print("分享成功")
                completion?(true, nil)
            } else {
                print("用户取消了分享")
                completion?(true, "用户取消了分享")
            }
        }
        
        viewController.present(activityVC, animated: true, completion: nil)
    }
    
    /// 分享相册图片（带存在性检查）
    static func sharePhoto(identifier: String, from viewController: UIViewController, completion: ShareCompletion? = nil) {
        // 检查照片是否存在
        guard photoExists(identifier: identifier) else {
            let errorMessage = "照片不存在: \(identifier)"
            print(errorMessage)
            completion?(false, errorMessage)
            return
        }
        
        let assetResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = assetResult.firstObject else {
            let errorMessage = "无法获取照片资源: \(identifier)"
            print(errorMessage)
            completion?(false, errorMessage)
            return
        }
        
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true  // 允许从 iCloud 下载
        
        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
            guard let data = data else {
                let errorMessage = "无法获取照片数据: \(identifier)"
                print(errorMessage)
                DispatchQueue.main.async {
                    completion?(false, errorMessage)
                }
                return
            }
            
            
            // 写入临时文件再分享
            let resources = PHAssetResource.assetResources(for: asset)
            let originalFilename = resources.first?.originalFilename ?? "\(identifier).tmp"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(originalFilename)
            
            do {
                try data.write(to: tempURL)
                DispatchQueue.main.async {
                    let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
                    activityVC.popoverPresentationController?.sourceView = viewController.view
                    
                    // 设置完成回调
                    activityVC.completionWithItemsHandler = { activityType, completed, returnedItems, error in
                        // 清理临时文件
                        try? FileManager.default.removeItem(at: tempURL)
                        
                        if let error = error {
                            print("分享失败: \(error)")
                            completion?(true, "分享失败: \(error.localizedDescription)")
                        } else if completed {
                            print("分享成功")
                            completion?(true, nil)
                        } else {
                            print("用户取消了分享")
                            completion?(true, "用户取消了分享")
                        }
                    }
                    
                    viewController.present(activityVC, animated: true, completion: nil)
                }
            } catch {
                let errorMessage = "写入临时文件失败: \(error)"
                print(errorMessage)
                DispatchQueue.main.async {
                    completion?(false, errorMessage)
                }
            }
        }
    }
      
    // MARK: - 文件存在性检查方法
    /// 检查文件是否存在
    static func fileExists(at path: String) -> Bool {
        // 支持相对路径（如 /Documents/xxx），自动拼接 NSHomeDirectory()
        let absolutePath: String
        if path.hasPrefix("/Documents") {
            absolutePath = NSHomeDirectory() + path
        } else {
            absolutePath = path
        }
        return FileManager.default.fileExists(atPath: absolutePath)
    }
    
    /// 检查相册照片是否存在
    static func photoExists(identifier: String) -> Bool {
        let assetResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        return assetResult.count > 0
    }
}

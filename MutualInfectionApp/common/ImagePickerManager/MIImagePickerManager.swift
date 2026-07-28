//
//  MIImagePickerManager.swift
//  MutualInfectionApp
//
//  Created by Niko on 2025/8/31.
//

import Foundation
import UIKit
import XXPhotoPicker
import Photos


class MIImagePickerManager: NSObject {
    
    // 单例实例
    static let shared = MIImagePickerManager()
    
    /// 所有资源处理完后的回调
    private var completion: (()->Void)?
    
    // 私有化初始化方法，确保单例唯一性
    private override init() {
        super.init()
        
    }
    
    // 配置对象
    private var config: PickerConfiguration = PhotoTools.getCustomPickerConfig()
    
    /// 点击完成后回调
    /// result: 图片选择后的回调对象
    /// pickerController: 图片选择器中创建的导航栏，外部可自行添加push事件
    public typealias CompletionHandler = (_ result: PickerResult?, _ pickerController: PhotoPickerController?) -> Void
    // 完成回调
    private var completionHandler: CompletionHandler?
    
    /// 打开系统相册
    func openPhotoURLScheme(completion: (Int) -> Void) {
        if let url = URL(string: "photos-redirect://") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                completion(1)
            }else {
                completion(0)
            }
        }else {
            completion(0)
        }
    }
    /// 打开相册, 多选
    func openPhotoLibrary(completionHandler: @escaping CompletionHandler) {
        self.openPhotoLibrary(autoDismiss: true, completionHandler: completionHandler)
    }
    
    
    /// 打开相册选择照片
    /// - Parameters:
    ///   - autoDismiss: 是否内部自动dismiss
    ///   - completionHandler: 选择完成后回调
    func openPhotoLibrary(autoDismiss: Bool = true, completionHandler: @escaping CompletionHandler) {
        self.completionHandler = completionHandler
        
        let pickerController = PhotoPickerController.init(config: config) { [weak self] result, pickerController in
            guard let self = self else { return }
            
            if result.photoAssets.isEmpty {
                return
            }
            self.completionHandler?(result, pickerController)
        } cancel: { pickerController in
            
            pickerController.dismiss(true) { [weak self] in
                guard let self = self else { return }
                self.completionHandler?(nil, pickerController)
            }
        }
        
        pickerController.autoDismiss = autoDismiss
        pickerController.actionHandler = { [weak self] result, controller, completion in
            guard let self = self else { return }
            actionHandler(result, controller, completion)
        }
        
        let topVC = UIViewController.topViewController
        topVC?.present(pickerController, animated: true, completion: nil)
    }
}


extension MIImagePickerManager {
    func actionHandler(_ result: PickerResult,_ controller: PhotoPickerController, _ completion: @escaping () -> Void) {
        self.completion = completion
        PhotoManager.HUDView.show(with: nil, delay: 0, animated: true, addedTo: MIKeyWindow)
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            resourceComputing(pickerResult: result)
        }
    }
    
    /// 资源计算
    /// 用于计算所有选中图片视频资源总大小，总长数
    func resourceComputing(pickerResult: PickerResult) {
        
        /// 当前路径与Live处理总数，
        var actionCount: Int = pickerResult.photoAssets.count {
            didSet {
                /// 当 actionCount == 0 表示所有任务已处理完成，可执行下一步操作
                if actionCount == 0 {
                    DispatchQueue.main.async {
                        PhotoManager.HUDView.dismiss(delay: 0, animated: true, for: MIKeyWindow)
                        self.completion?()
                    }
                }
            }
        }
        
        for asset in pickerResult.photoAssets {
            guard let phAsset = asset.phAsset else { break }
            
            let assetResources = PHAssetResource.assetResources(for: phAsset)
            
            guard let resource = assetResources.first else { return }
            
            /// 获取图库中的真实图片名...但是有个问题啊，图片中的真实文件名会重复，不知道咋整...先就这样吧
            var originalFilename = resource.originalFilename
            print("The original filename is: \(originalFilename)")
            if #available(iOS 13, *) {
                if originalFilename.lowercased().contains(".mov") {
                    originalFilename = String(originalFilename.dropLast(4)) + ".heic"
                }
            }
            asset.fileName = originalFilename
            
            if asset.mediaSubType == .livePhoto {
                
                /// live 拆分 ... 其实...Picker库中返回的就是拆好的资源...先这样吧，不敢乱改，搞坏了得背锅
                HongmengDynamicImageConverter.shared.convertLivePhoto(phAsset) { [weak self] result in
                    
                    switch result {
                    case .success(let success):
                        guard let imageURL = success.first, let videoURL = success.last, let self = self else { return }
                        
                        /// 当选中资源为Live时
                        /// 生成 A to H Live存储地址
                        var livePhotoTmpStr = replaceHEICWithJPG(in: FileManager.default.temporaryDirectory.relativeString + originalFilename)
                        
                        /// 移除路径前面的file:// C++那边说是无法识别带file://的路径
                        livePhotoTmpStr = replaceString(in: livePhotoTmpStr)
                        
                        /// 将 Live 拆分好的视频和图片传入C++合成 H 端的动图并保存到指定路径下
                        let isSuccess = LivePhotoUtilOC.sharedInstance().createPlayableLivePhoto(withImagePath: imageURL.path, videoPath: videoURL.path, livePhotoPath: livePhotoTmpStr)
                        
                        /// 合成成功
                        if isSuccess {
                            /// 将合成后的路径保存到图片对象，供外部使用
                            asset.filePath = livePhotoTmpStr
                            
                            /// 记录资源总数，图片 = X，视频 = X Live也属于图片，计算合成后的 Live 资源大小并记录
                            pickerResult.phontCount += 1
                            pickerResult.photoSize += getFileSizeSimple(atPath: livePhotoTmpStr)
                        } else {
                            /// 不用多说了吧...很显然是合成失败
                            print("实况图：" + originalFilename + "转换失败")
                        }
                        break
                    case .failure(let failure):
                        /// 拆分失败
                        print("发生错误 - \(failure.localizedDescription)")
                        break
                    }
                    
                    /// 任务总数 -1
                    actionCount -= 1
                }
            } else {
                /// 记录资源总数，图片 = X，视频 = X
                if asset.mediaType == .photo {
                    pickerResult.phontCount += 1
                    pickerResult.photoSize += asset.fileSize
                } else if asset.mediaType == .video {
                    pickerResult.videoCount += 1
                    pickerResult.videoSize += asset.fileSize
                }

                if asset.fileName.hasSuffix("heic") || asset.fileName.hasSuffix("HEIC") {
                    /// 获取非Live以外资源的路径
                    asset.getURL(toFile: PhotoAsset.FileConfig.init(imageURL: PhotoTools.getImageTmpURL())) { [weak self] result in
                        switch result {
                            case .success(let urlResult):
                                asset.filePath = self?.replaceString(in: urlResult.url.absoluteString) ?? ""
                                asset.fileName = urlResult.url.lastPathComponent
                                print("filePath：\(asset.filePath), fileName: \(asset.fileName)")
                            case .failure(let error):
                                print("图片路径获取失败：\(error)")
                        }
                        
                        /// 任务总数 -1
                        actionCount -= 1
                    }
                } else {
                    /// 获取非Live以外资源的路径
                    asset.getURL { [weak self] result in
                        switch result {
                            case .success(let urlResult):
                                asset.filePath = self?.replaceString(in: urlResult.url.absoluteString) ?? ""
                            case .failure(let error):
                                print("图片路径获取失败：\(error)")
                        }
                        
                        /// 任务总数 -1
                        actionCount -= 1
                    }
                }
            }
        }
    }
    
    /// 获取转换后的Live大小
    func getFileSizeSimple(atPath path: String) -> Int {
        return Int(MIImagePickerManager.getFileSizeSimple(atPath: path))
    }
    
    /// 获取转换后的Live大小
    static func getFileSizeSimple(atPath path: String) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    func replaceHEICWithJPG(in filename: String) -> String {
        return MIImagePickerManager.replaceHEICWithJPG(in: filename)
    }
    
    static func replaceHEICWithJPG(in filename: String) -> String {
        // 检查文件名是否以 .HEIC 或 .heic 结尾
        if filename.lowercased().hasSuffix(".heic") {
            // 移除 .heic 扩展名（不区分大小写）
            let nameWithoutExtension = String(filename.dropLast(5))
            // 添加 .JPG 扩展名
            return nameWithoutExtension + ".jpg"
        }
        return filename
    }
    
    func replaceJPEGWithJPG(in filename: String) -> String {
        // 检查文件名是否以 .HEIC 或 .heic 结尾
        if filename.lowercased().hasSuffix(".jpeg") {
            // 移除 .heic 扩展名（不区分大小写）
            let nameWithoutExtension = String(filename.dropLast(5))
            // 添加 .JPG 扩展名
            return nameWithoutExtension + ".jpg"
        }
        return filename
    }
    
    func replaceString(in fileName: String) -> String {
        return MIImagePickerManager.replaceString(in: fileName)
    }
    
    static func replaceString(in fileName: String) -> String {
        return NSString(string: fileName).replacingOccurrences(of: "file://", with: "")
    }
}

// MARK: - PhotoPickerControllerDelegate
extension MIImagePickerManager: PhotoPickerControllerDelegate {
    /// Picker 选择与任务处理完成后回调
    func pickerController(_ pickerController: PhotoPickerController, didFinishSelection result: PickerResult) {
        if result.photoAssets.isEmpty {
            return
        }
        self.completionHandler?(result, pickerController)
    }
}

// MARK: -  删除图库中的图片
extension MIImagePickerManager {
    
    /// 通过标识符删除系统图库中的照片或视频资源
    /// - Parameters:
    ///   - identifiers: 要删除的资源标识符数组
    ///   - completion: 删除完成后的回调，返回是否删除成功
    func deleteAssetsFromPhotoLibrary(withIdentifiers identifiers: [String], completion: @escaping (Bool) -> Void) {
        // 兼容 iOS13 及以下与 iOS14+ 的权限 API
        let status: PHAuthorizationStatus
        if #available(iOS 14, *) {
            status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        } else {
            status = PHPhotoLibrary.authorizationStatus()
        }
        
        func proceedDeletion() {
            self.fetchAssets(withIdentifiers: identifiers) { [weak self] phAssets in
                guard let self = self else {
                    DispatchQueue.main.async { completion(false) }
                    return
                }
                if phAssets.isEmpty {
                    DispatchQueue.main.async { completion(false) }
                    return
                }
                self.deleteAssets(phAssets, completion: completion)
            }
        }
        
        switch status {
        case .authorized:
            proceedDeletion()
        case .limited:
            // iOS14+ 的有限访问通常不允许删除，视为无权限
            fallthrough
        case .denied, .restricted:
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "需要权限", message: "请在设备的设置中允许应用删除照片。", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "确定", style: .default, handler: { _ in
                    completion(false)
                }))
                if let topVC = UIViewController.topViewController {
                    topVC.present(alert, animated: true, completion: nil)
                }
                
                AlertManager.showAlert(title: "需要权限".localized, message: "请在设备的设置中允许应用删除照片".localized, cancelTitle: "取消".localized, confirmTitle: "确定".localized) {
                    if let url = URL(string: UIApplication.openSettingsURLString + "App-Prefs:root=APP") {
                        UIApplication.shared.open(url)
                    }
                }
            }
        case .notDetermined:
            if #available(iOS 14, *) {
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                    if newStatus == .authorized {
                        proceedDeletion()
                    } else {
                        DispatchQueue.main.async { completion(false) }
                    }
                }
            } else {
                PHPhotoLibrary.requestAuthorization { newStatus in
                    if newStatus == .authorized {
                        proceedDeletion()
                    } else {
                        DispatchQueue.main.async { completion(false) }
                    }
                }
            }
        @unknown default:
            DispatchQueue.main.async { completion(false) }
        }
    }
    
    /// 根据标识符查询PHAsset
    private func fetchAssets(withIdentifiers identifiers: [String], completion: @escaping ([PHAsset]) -> Void) {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var assets: [PHAsset] = []
        
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        
        completion(assets)
    }
    
    /// 执行实际的删除操作
    private func deleteAssets(_ assets: [PHAsset], completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assets as NSArray)
        }) { success, error in
            if let error = error {
                print("删除照片失败: \(error.localizedDescription)")
            }
            
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
}

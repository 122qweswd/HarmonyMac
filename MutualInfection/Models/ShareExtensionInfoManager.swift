//
//  ShareExtensionInfoManager.swift
//  MutualInfection
//
//  Created by Niko on 2025/10/16.
//

import Foundation
import Photos

#if MAIN_APP || SHARE_EXTENSION
import MobileCoreServices
#endif


// ShareExtensionInfoManager.swift

class ShareExtensionInfoManager {
    
    /// 自定义错误类型，用于 Live Photo 查找失败的情况
    enum LivePhotoError: Error {
        case notFound(message: String)
        case limited
        case notAuthorized
        case userCancelled // 新增：用户取消操作
    }
    
    static let shared = ShareExtensionInfoManager()
    
    /// 共享数据
    var shareInfoModel: ShareInfoModel?
    
    /// 用于存储授权 continuation
    private var authorizationContinuation: CheckedContinuation<Bool, Never>?
    
    /// 获取最新的共享数据
    func loadShareInfoModel()  {
        if let sharedDefaults = UserDefaults(suiteName: groupID) {
            shareInfoModel = sharedDefaults.loadShareInfo()
        }
    }
    
    func clearShareInfo() {
        shareInfoModel = nil
#if MAIN_APP
        /// 删除共享文件
        let groupFileManager = GroupFileManager(groupIdentifier: groupID)
        Task {
            await groupFileManager?.clearDirectory(folderName: shareExtensionRootDirectoryName)
            
            let livePathList = shareInfoModel?.fileInfos.filter { $0.fileType == .photo(.livePhoto) }.map { $0.filePath }
            for filePath in livePathList ?? [] {
                try? FileManager.default.removeItem(atPath: filePath)
            }
        }
#endif
    }
    
#if MAIN_APP
    /// 处理数据 - 返回 Bool 表示是否继续执行后续代码
    func handleShareInfoModel() async -> (Bool,[String:String]?) {
        // 检查是否有不支持的类型
        if let errorModel = shareInfoModel?.fileInfos.first(where: { $0.fileType == .none }) {
            await MainActor.run {
                let _ = AlertManager.showAlert(title: "对方暂不支持接收此类型内容".localized,cancelTitle: nil, confirmTitle: "知道了".localized)
                

                guard let topVC = MIGetTopViewController(), let errorMessage = errorModel.errorMessage else { return }
                topVC.view.pickerMakeToast(errorMessage, duration: 6.0, point: topVC.view.center, title: nil, image: nil, completion: nil)
            }
            
            clearShareInfo()
            return (false,nil)
        } else {
            do {
                MIWCDBManager.showLoading()
                // 处理 LivePhoto，如果抛出 userCancelled 错误则中断
                try await imageNameToLivePhoto()
                
                let dic = self.getGroupData()
                MIWCDBManager.dismissLoading()
                return (true,dic)
            } catch LivePhotoError.userCancelled {
                MIWCDBManager.dismissLoading()
                clearShareInfo()
                // 用户取消，中断后续代码
                print("ShareExtension ======= 处理 LivePhoto 时发生错误: 用户取消")
                ShareAPI.shared().log(3, "ShareExtension ======= 处理 LivePhoto 时发生错误: 用户取消")
                return (false,nil)
            } catch {
                
                let dic = self.getGroupData()
                MIWCDBManager.dismissLoading()
                // 其他错误，可以根据需要决定是否继续
                print("ShareExtension ======= 处理 LivePhoto 时发生错误: \(error)")
                ShareAPI.shared().log(3, "ShareExtension ======= 处理 LivePhoto 时发生错误: \(error)")
                return (true,dic)
            }
        }
    }
    
    /// 处理LivePhoto - 改为抛出错误
    func imageNameToLivePhoto() async throws {
        guard let shareInfoModel = shareInfoModel else { return }
        
        let livePhotoList = shareInfoModel.fileInfos.filter{ $0.fileType == .photo(.livePhoto) }
        
        // 如果没有 LivePhoto 直接返回
        if livePhotoList.isEmpty { return }
        // 处理每个 LivePhoto
        for fileInfo in livePhotoList {
            do {
                /// 先查询路径下是否存在转换后的同名 H 动图
                var livePhotoTmpStr = MIImagePickerManager.replaceHEICWithJPG(in: FileManager.default.temporaryDirectory.relativeString + fileInfo.fileName)
                livePhotoTmpStr = MIImagePickerManager.replaceString(in: livePhotoTmpStr)
                let exists = FileManager.default.fileExists(atPath: livePhotoTmpStr)
                if !exists {
                    let asset = try await fetchLivePhoto(by: fileInfo)
                    livePhotoTmpStr = try await saveHIECToJPEG(livePhotoAsset: asset, fileInfoModel: fileInfo)
                }
                fileInfo.filePath = livePhotoTmpStr
                print("ShareExtension ======= livePhoto to jpg filepath ====== \(livePhotoTmpStr)")
                ShareAPI.shared().log(1, "ShareExtension ======= livePhoto to jpg filepath ====== \(livePhotoTmpStr)")
            } catch LivePhotoError.limited, LivePhotoError.notAuthorized {
                
                // 未（完全）授权，展示授权弹窗并等待用户操作
                let userChoice = await showLivePhotoView()
                
                if userChoice {
                    
                    // 用户点击继续，跳过权限检查直接获取 LivePhoto
                    let asset = try await fetchLivePhotoWithoutAuthCheck(by: fileInfo)
                    let livePhotoFilePath = try await saveHIECToJPEG(livePhotoAsset: asset, fileInfoModel: fileInfo)
                    fileInfo.filePath = livePhotoFilePath
                    
                } else {
                    // 用户点击取消，抛出中断错误
                    throw LivePhotoError.userCancelled
                }
            } catch LivePhotoError.notFound(let message) {
                // 其他错误，记录但继续处理下一个
                ShareAPI.shared().log(3, "ShareExtension ======= \(message)")
                print("ShareExtension ======= 处理 LivePhoto \(fileInfo.fileName) 时发生错误: \(message)")
            } catch {
                ShareAPI.shared().log(3, "ShareExtension ======= 处理 LivePhoto \(fileInfo.fileName) 时发生错误: \(error)")
                print("ShareExtension ======= 处理 LivePhoto \(fileInfo.fileName) 时发生错误: \(error)")
            }
        }
    }
    
    func getGroupData() -> [String:String]? {
        
       // dict========[AnyHashable("contactsCount"): "0" AnyHashable("folderCount"): "0", AnyHashable("photoCount"): "0", AnyHashable("fileCount"): "0" ]
        
        guard let shareFileInfoModel = ShareExtensionInfoManager.shared.shareInfoModel else { return nil }
        //ShareAPI.shared().log(1, "共享数据获取中")
        
        
        var dict : [String:String] = [:]
        var previewSummary : [String:Int] = [:]
        
        dict["itemCount"] = shareFileInfoModel.totalCount
        
 
        
        if shareFileInfoModel.fileInfos.first?.fileType == .file {
            dict["sendType"] = "3"
            dict["fileCount"] = shareFileInfoModel.fileCount
            var imageCount = 0
            var mediaVideoCount = 0
            var otherTypeCount = 0
            if let shareInfoList =  ShareExtensionInfoManager.shared.shareInfoModel?.fileInfos {
                for shareInfo in shareInfoList {
                    if shareInfo.isImageType {
                        imageCount += 1
                    }
                    if shareInfo.isVideoType {
                        mediaVideoCount += 1
                    }
                    if !shareInfo.isImageType && !shareInfo.isVideoType {
                        otherTypeCount += 1
                    }
                }
                if otherTypeCount == 0 && (imageCount + mediaVideoCount) > 0 {
                    dict["sendType"] = "0"
                    dict["photoCount"] = "\(imageCount)"
                    dict["videoCount"] = "\(mediaVideoCount)"
                }
            }
            
            
            
            var newStr = ""
             if otherTypeCount > 0 {
                 newStr = "\(otherTypeCount)" + "个文件".localized + ((imageCount > 0 || mediaVideoCount > 0) ? "," : "")
             }
             if imageCount > 0 {
                 newStr = newStr + "\(imageCount)" + "张图片".localized + ((mediaVideoCount > 0) ? "," : "")
             }
             
             if mediaVideoCount > 0 {
                 newStr = newStr + "\(mediaVideoCount)" + "个视频".localized
             }
            
            dict["navStr"] = newStr
        } else if shareFileInfoModel.fileInfos.first?.fileType == .contact {
            
            dict["sendType"] = "8"
            dict["itemCount"] = "1"
            dict["fileCount"] = "1"
            dict["contactsCount"] = shareFileInfoModel.contactCount
            dict["navStr"] = "\(shareFileInfoModel.contactCount)" + "个联系人".localized
        } else {
            dict["sendType"] = "0"
            if Int(shareFileInfoModel.photoCount) ?? 0 > 0 {
                dict["photoCount"] = shareFileInfoModel.photoCount
            }
            
            if Int(shareFileInfoModel.videoCount) ?? 0 > 0 {
                dict["videoCount"] = shareFileInfoModel.videoCount
            }
            dict["fileCount"] = "0"
            
            
            if (Int(shareFileInfoModel.photoCount) ?? 0 > 0) && (Int(shareFileInfoModel.videoCount) ?? 0 > 0){
                let photoCountStr = "\(shareFileInfoModel.photoCount)" + "张图片".localized
                let videoCountStr = ",\(shareFileInfoModel.videoCount)" + "个视频(共".localized
                dict["navStr"] =  photoCountStr + videoCountStr

            }else if (Int(shareFileInfoModel.photoCount) ?? 0 > 0) {
                dict["navStr"] = "\(shareFileInfoModel.photoCount)张图片"
            }else if (Int(shareFileInfoModel.videoCount) ?? 0 > 0) {
                dict["navStr"] = "\(shareFileInfoModel.videoCount)个视频"
            }
   
        }
        
        for fileInfoModel in shareFileInfoModel.fileInfos {
            if let fileType = fileInfoModel.fileName.components(separatedBy: ".").last{
                if let filetypeNum = previewSummary[".\(fileType)"]  {
                    previewSummary[".\(fileType)"] = filetypeNum + 1
                }else{
                    previewSummary[".\(fileType)"] = 1
                }
            }
        }
        
        
        let previewSummaryStr = dictionaryToJSON(previewSummary).replacingOccurrences(of: "\n", with: "")
        dict["previewSummary"] = previewSummaryStr
        
        dict["totalSize"] = shareFileInfoModel.totalSize
        
        
        
        dict["folderCount"] = "0" //文件总数
        
        return dict
        
    }

    func dictionaryToJSON(_ dictionary: [String: Any]) -> String {
        if let jsonData = try? JSONSerialization.data(withJSONObject: dictionary, options: .prettyPrinted) {
            return String(data: jsonData, encoding: .utf8) ?? ""
        }
        return ""
    }

    
    
    
    
    /// 显示 Live Photo 授权弹窗（异步版本）
    @MainActor
    func showLivePhotoView() async -> Bool {
        return await withCheckedContinuation { continuation in
            // 存储 continuation 以便在用户操作后恢复
            self.authorizationContinuation = continuation
            
            // 假设您的弹窗有两个按钮：取消和继续
            // 您需要修改 MILivePhotoAuthorizedView 来支持这两个回调
            MILivePhotoAuthorizedView.showLivePhotoAuthorizedView(
                onContinue: {
                    // 用户点击继续
                    self.authorizationContinuation?.resume(returning: true)
                    self.authorizationContinuation = nil
                },
                onCancel: {
                    // 用户点击开启权限
                    self.authorizationContinuation?.resume(returning: false)
                    self.authorizationContinuation = nil
                }
            )
        }
    }
    
    /// 通过图片名称查找到相册中的LivePhoto（带权限检查）
    func fetchLivePhoto(by fileInfoModel: ShareFileInfModel) async throws -> PHAsset {
        return try await withCheckedThrowingContinuation { continuation in
            let status: PHAuthorizationStatus
            if #available(iOS 14, *) {
                status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            } else {
                status = PHPhotoLibrary.authorizationStatus()
            }
            
            switch status {
            case .authorized:
                // 已授权，直接查找
                self.findLivePhotoInLibrary(by: fileInfoModel, continuation: continuation)
            case .notDetermined:
                // 未决定，请求授权
                if #available(iOS 14, *) {
                    PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] newStatus in
                        guard let self = self else { return }
                        if newStatus == .authorized {
                            findLivePhotoInLibrary(by: fileInfoModel, continuation: continuation)
                        } else if newStatus == .limited {
                            // 部分授权
                            continuation.resume(throwing: LivePhotoError.limited)
                        } else {
                            // 没有权限
                            continuation.resume(throwing: LivePhotoError.notAuthorized)
                        }
                    }
                } else {
                    PHPhotoLibrary.requestAuthorization { [weak self] newStatus in
                        guard let self = self else { return }
                        if newStatus == .authorized {
                            findLivePhotoInLibrary(by: fileInfoModel, continuation: continuation)
                        } else {
                            // 没有权限
                            continuation.resume(throwing: LivePhotoError.notAuthorized)
                        }
                    }
                }
            case .limited:
                // 部分授权
                continuation.resume(throwing: LivePhotoError.limited)
            default:
                // 没有权限
                continuation.resume(throwing: LivePhotoError.notAuthorized)
            }
        }
    }
    
    /// 通过图片名称查找到相册中的LivePhoto（跳过权限检查）
    func fetchLivePhotoWithoutAuthCheck(by fileInfoModel: ShareFileInfModel) async throws -> PHAsset {
        return try await withCheckedThrowingContinuation { continuation in
            self.findLivePhotoInLibrary(by: fileInfoModel, continuation: continuation)
        }
    }
    
    /// 在相册中查找 LivePhoto 的公共方法
    private func findLivePhotoInLibrary(by fileInfoModel: ShareFileInfModel, continuation: CheckedContinuation<PHAsset, Error>) {
        let baseName = (fileInfoModel.fileName as NSString).deletingPathExtension
        var matchedAsset: PHAsset?
        
        let allAssets = PHAsset.fetchAssets(with: .image, options: nil)
        
        allAssets.enumerateObjects { asset, _, stop in
            if asset.mediaSubtypes.contains(.photoLive) {
                let resources = PHAssetResource.assetResources(for: asset)
                
                if let _ = resources.first(where: { $0.originalFilename.hasPrefix(baseName) }) {
                    matchedAsset = asset
                    stop.pointee = true
                }
            }
        }
        
        if let asset = matchedAsset {
            continuation.resume(returning: asset)
        } else {
            continuation.resume(throwing: LivePhotoError.notFound(message: "未找到文件名为 '\(fileInfoModel.fileName)' 的 Live Photo"))
        }
    }
    
    /// 将 Live Photo 转换为 JPEG
    func saveHIECToJPEG(livePhotoAsset: PHAsset, fileInfoModel: ShareFileInfModel) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            HongmengDynamicImageConverter.shared.convertLivePhoto(livePhotoAsset) { result in
                switch result {
                case .success(let success):
                    guard let imageURL = success.first, let videoURL = success.last else {
                        continuation.resume(returning: "")
                        return
                    }
                    
                    var livePhotoTmpStr = MIImagePickerManager.replaceHEICWithJPG(in: FileManager.default.temporaryDirectory.relativeString + fileInfoModel.fileName)
                    
                    /// 移除路径前面的file:// C++那边说是无法识别带file://的路径
                    livePhotoTmpStr = MIImagePickerManager.replaceString(in: livePhotoTmpStr)
                    /// 将 Live 拆分好的视频和图片传入C++合成 H 端的动图并保存到指定路径下
                    let isSuccess = LivePhotoUtilOC.sharedInstance().createPlayableLivePhoto(withImagePath: imageURL.path, videoPath: videoURL.path, livePhotoPath: livePhotoTmpStr)
                    fileInfoModel.fileSize = MIImagePickerManager.getFileSizeSimple(atPath: livePhotoTmpStr)
                    
                    if isSuccess {
                        continuation.resume(returning: livePhotoTmpStr)
                        ShareAPI.shared().log(1, "实况图：" + "转换成功" + livePhotoTmpStr)
                    } else {
                        ShareAPI.shared().log(3, "实况图：" + "转换失败")
                        continuation.resume(throwing: LivePhotoError.notFound(message: "实况图转换失败"))
                    }
                case .failure(let failure):
                    /// 拆分失败
                    ShareAPI.shared().log(3, "发生错误 - \(failure.localizedDescription)")
                    continuation.resume(throwing: LivePhotoError.notFound(message: "实况图拆分失败"))
                }
            }
        }
    }
#endif
}


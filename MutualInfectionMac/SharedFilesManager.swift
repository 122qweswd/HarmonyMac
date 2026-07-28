//
//  SharedFilesManager.swift
//  MutualInfectionMac
//
//  Created by NB1539 on 2025/11/6.
//
import Cocoa
import AVFoundation
import Photos

struct FileInfo {
    let name: String
    let path: String
    let size: UInt64
    let type: String
    let modifiedDate: Date
    var isAccessible: Bool = false
}

class SharedFilesManager {
    static let shared = SharedFilesManager()
    var receivedFiles: [FileInfo] = []
    private var securityScopedURLs: [URL] = [] // 跟踪需要释放的URL
    
    private init() {}
    
    deinit {
        releaseAllSecurityScopedResources()
    }
    
    func checkSharedFiles(completion: ((Bool, [FileInfo]) -> Void)? = nil) {
        print("开始检查共享文件...")
        
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("❌ 无法访问 App Group: \(appGroupIdentifier)")
            completion?(false, [])
            return
        }
        //        let arr = sharedDefaults.object(forKey: "sharedFilesInfo")
        //        
        guard let filesInfo = sharedDefaults.array(forKey: "sharedFilesInfo") as? [[String: Any]],
              !filesInfo.isEmpty else {
            print("没有找到共享文件数据")
            completion?(false, [])
            return
        }
        
        guard let timestamp = sharedDefaults.object(forKey: "sharedFilesTimestamp") as? Date else {
            print("没有找到时间戳")
            completion?(false, [])
            return
        }
        
        ShareAPI.shared().log(1, "找到共享文件 ====== \(filesInfo.count)个 ，时间戳: \(timestamp)")
        ShareAPI.shared().log(1, "arr = \(filesInfo)")

        
        // 检查是否已处理过这批文件
        let lastProcessedKey = "lastProcessedTimestamp"
        if let lastProcessed = sharedDefaults.object(forKey: lastProcessedKey) as? Date,
           lastProcessed >= timestamp {
            print("这批文件已于 \(lastProcessed) 处理过，跳过")
            completion?(false, [])
            return
        }
        
        print("======================================")
        ShareAPI.shared().log(1, "开始处理来自 Share Extension 的文件")

        
        // 清空之前的文件列表和资源
        receivedFiles.removeAll()
        releaseAllSecurityScopedResources()
        
        
        let serialQueue = DispatchQueue(label: "com.MutualInfection.serial")
        let dispatchMacGroup = DispatchGroup()
        AppDelegate.shared.showLoadingState(for:"1") 
        

        // 处理每个文件信息
        for (index, info) in filesInfo.enumerated() {
            print("\n处理文件 \(index + 1):")
            let path = (info["path"] as? String)!
            let fileURL = URL(fileURLWithPath: path)

            if iCloudFileUtility.isPhotoLibraryPlaceholder(at: fileURL) {
                let alert = NSAlert()
                alert.informativeText = "非本地文件，请先存到本地后再重试".localized
                alert.alertStyle = .warning
                alert.addButton(withTitle: "我知道了".localized)
                alert.runModal()
                // 恢复UI状态
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    AppDelegate.shared.hideLoadingState(for: "1")
                    completion?(true, self.receivedFiles)
                    return
                }
            }
            
            dispatchMacGroup.enter()
            serialQueue.sync {
                self.createFileInfo(from: info, index: index) { [weak self] infoFile in
                    if infoFile != nil {
                        self?.receivedFiles.append(infoFile!)
                        ShareAPI.shared().log(1, "✅ 成功添加文件: \(infoFile!.name)")
                    } else {
                        ShareAPI.shared().log(1, "❌ 文件信息不完整，跳过")
                    }
                    do{
                        dispatchMacGroup.leave() 
                    }
                }
            }
        }
        dispatchMacGroup.notify(queue: .main) {
            // 标记为已处理并清理
            sharedDefaults.set(timestamp, forKey: lastProcessedKey)
            sharedDefaults.removeObject(forKey: "sharedFilesInfo")
            sharedDefaults.removeObject(forKey: "sharedFilesTimestamp")
            sharedDefaults.synchronize()
            
            ShareAPI.shared().log(1, "✅ 共享文件处理完成，共 \(self.receivedFiles.count) 个文件")
            ShareAPI.shared().log(1, "发送通知")

            // 发送通知
            NotificationCenter.default.post(
                name: NSNotification.Name("FilesReceived"),
                object: self.receivedFiles)
            // 恢复UI状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                AppDelegate.shared.hideLoadingState(for: "1")
                completion?(true, self.receivedFiles)
            }
        }
    }
    
    private func createFileInfo(from info: [String: Any], index: Int,completion:@escaping(FileInfo?)->Void?) {
        var infoModel:FileInfo?
        guard let path = info["path"] as? String,
              let name = info["name"] as? String,
              let type = info["type"] as? String else {
            ShareAPI.shared().log(1, "❌ 文件 \(index + 1) 缺少必要信息")
            completion(nil)
            return
        }
        ShareAPI.shared().log(1, "path分享的路径 \(path)")

        let size = info["size"] as? UInt64 ?? 0
        let modifiedTimestamp = info["modifiedDate"] as? TimeInterval ?? Date().timeIntervalSince1970
        let modifiedDate = Date(timeIntervalSince1970: modifiedTimestamp)
        
        // 验证文件可访问性
        let fileURL = URL(fileURLWithPath: path)
        let isAccessible = verifyFileAccessibility(at: fileURL)
        
        ShareAPI.shared().log(1, "  文件名: \(name)")
        print("  路径: \(path)")
        print("  类型: \(type)")
        print("  大小: \(formatFileSize(size))")
        print("  修改日期: \(formatDate(modifiedDate))")
        print("  可访问: \(isAccessible ? "是" : "否")")
        if LivePhotoAddressFetcher().isFromSystemPhotoLibrary(fileURL) == false {
            if fileURL.isImageFile {
             let hdrUrl = LivePhotoAddressFetcher().getHDRimgUrl(url: fileURL)
                infoModel = FileInfo(name: name,path: hdrUrl.path,size: size,type: type,modifiedDate: modifiedDate,isAccessible: isAccessible)
                completion(infoModel)
                return
            }
            else{
                infoModel = FileInfo(name: name,path: path,size: size,type: type,modifiedDate: modifiedDate,isAccessible: isAccessible)
                completion(infoModel)
                return 
            }
        }
        
        if let uuid = LivePhotoAddressFetcher().extractUUIDFromPath(fileURL.path),let asset = LivePhotoAddressFetcher().fetchPhotoAsset(uuid) {
            //实况图
            if LivePhotoAddressFetcher().checkAssetIsPhotoLive(asset) {
                HongmengDynamicImageConverter.shared.convertLivePhoto(asset) { result in
                    switch result {
                    case .success(let success):
                        guard let imageURL = success.first, let videoURL = success.last else {
                            infoModel = FileInfo(name: name,path: path,size: size,type: type,modifiedDate: modifiedDate,isAccessible: isAccessible)
                            completion(infoModel)
                            return
                        }
                        /// 当选中资源为Live时
                        /// 生成 A to H Live存储地址
                        var livePhotoTmpStr = FileManager.default.temporaryDirectory.relativeString + name
                        livePhotoTmpStr = SharedFilesManager.replaceHEICToJPGUrl(in: livePhotoTmpStr)+".jpg"
                        /// 移除路径前面的file:// C++那边说是无法识别带file://的路径
                        livePhotoTmpStr = NSString(string: livePhotoTmpStr).replacingOccurrences(of: "file://", with: "")
                        ShareAPI.shared().log(1, "livePhotoTmpStr ========\(livePhotoTmpStr)")
                        /// 将 Live 拆分好的视频和图片传入C++合成 H 端的动图并保存到指定路径下
                        let isSucc = ShareAPI.shared().createPlayableLivePhoto(withImagePath: imageURL.path, videoPath: videoURL.path, livePhotoPath: livePhotoTmpStr)
                        
                        if isSucc {
                            let liveSize = self.getFileSize(for: URL(string: livePhotoTmpStr)!)
                            infoModel = FileInfo(name: name,path: path,size: UInt64(liveSize ?? 0),type: type,modifiedDate: modifiedDate,isAccessible: isAccessible)
//                                let fileM = FileManager.default
//                                do{
//                                    try fileM.removeItem(at: imageURL)
//                                    try fileM.removeItem(at: videoURL)
//                                }
                            ShareAPI.shared().log(1, "实况图：转换成功=" + livePhotoTmpStr)
                            completion(infoModel)
                        } else {
                            ShareAPI.shared().log(1, "实况图：转换失败")
                            infoModel = FileInfo(name: name,path: path,size: size,type: type,modifiedDate: modifiedDate,isAccessible: isAccessible)
                            completion(infoModel)
                        }
                    case .failure(let failure):
                        /// 拆分失败
                        ShareAPI.shared().log(1, "发生错误 - 实况图拆分失败 =\(failure.localizedDescription)")

                        infoModel = FileInfo(name: name,path: path,size: size,type: type,modifiedDate: modifiedDate,isAccessible: isAccessible)
                        completion(infoModel)
                    }
                }
            }
            else{
                ShareAPI.shared().log(1, "是 HDR 图片")

                MainWindowController().getShareableFileURL(for: asset) { targetURL, originalFilename in
                    LivePhotoAddressFetcher.isHDRAssetAsync(asset) { isHdr in
                        if isHdr {
                            let hdrUrl = LivePhotoAddressFetcher().urlToHDRimgUrl(url: targetURL!)
                            let hdrSize = self.getFileSize(for: hdrUrl)
                            infoModel = FileInfo(name: name,path: hdrUrl.path,size:UInt64(hdrSize ?? 0),type: type,modifiedDate: modifiedDate,isAccessible: isAccessible)
                            completion(infoModel)
                            return
                        }else{
                            infoModel = FileInfo(name: name,path: fileURL.path,size:size,type: type,modifiedDate: modifiedDate,isAccessible: isAccessible)
                            completion(infoModel)
                            return 
                        }
                    }
                }
            }
//            else{
//                infoModel = FileInfo(name: name,path: fileURL.path,size: size,type: type,modifiedDate: modifiedDate,isAccessible: isAccessible)
//                completion(infoModel)
//                return
//            } 
        }else{
            if fileURL.isImageFile {
             let hdrUrl = LivePhotoAddressFetcher().getHDRimgUrl(url: fileURL)
                let hdrSize = self.getFileSize(for: hdrUrl)
                infoModel = FileInfo(name: name,path: fileURL.path,size:UInt64(hdrSize ?? 0),type: type,modifiedDate: modifiedDate,isAccessible: isAccessible)
                completion(infoModel)
                return
            }else{
                infoModel = FileInfo(name: name,path: fileURL.path,size: size,type: type,modifiedDate: modifiedDate,isAccessible: isAccessible)
                completion(infoModel) 
                return 
            }
        }
    }

    
    func verifyFileAccessibility(at url: URL) -> Bool {
        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ 文件不存在: \(url.path)")
            return false
        }
        
        // 尝试获取安全作用域访问权限
        let accessing = url.startAccessingSecurityScopedResource()
        if accessing {
            securityScopedURLs.append(url)
        }
        
        do {
            // 尝试读取文件属性来验证访问权限
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? UInt64 ?? 0
            print("✅ 文件可访问: \(url.lastPathComponent), 大小: \(formatFileSize(fileSize))")
            return true
        } catch {
            print("❌ 文件访问失败: \(url.lastPathComponent), 错误: \(error.localizedDescription)")
            if accessing {
                url.stopAccessingSecurityScopedResource()
                if let index = securityScopedURLs.firstIndex(of: url) {
                    securityScopedURLs.remove(at: index)
                }
            }
            return false
        }
    }
    
    func getSecureFileURL(for fileInfo: FileInfo) -> URL? {
        let fileURL = URL(fileURLWithPath: fileInfo.path)
        
        guard fileURL.startAccessingSecurityScopedResource() else {
            print("❌ 无法开始安全作用域访问: \(fileInfo.name)")
            return nil
        }
        
        securityScopedURLs.append(fileURL)
        return fileURL
    }
    
    func stopFileAccess(for fileURL: URL) {
        fileURL.stopAccessingSecurityScopedResource()
        if let index = securityScopedURLs.firstIndex(of: fileURL) {
            securityScopedURLs.remove(at: index)
        }
    }
    
    private func releaseAllSecurityScopedResources() {
        for url in securityScopedURLs {
            url.stopAccessingSecurityScopedResource()
        }
        securityScopedURLs.removeAll()
    }
    
    // MARK: - 工具方法
    private func formatFileSize(_ size: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
    
    func getAccessibleFiles() -> [FileInfo] {
        return receivedFiles.filter { $0.isAccessible }
    }
    
    func clearFiles() {
        receivedFiles.removeAll()
        releaseAllSecurityScopedResources()
        print("已清空文件列表")
    }
    
    
    func convertMovToMp4(movURL: URL, completion: @escaping (URL?) -> Void) {
        let asset = AVAsset(url: movURL)
        let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)
        
        // 创建输出URL
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        exportSession?.outputURL = outputURL
        exportSession?.outputFileType = .mp4
        exportSession?.shouldOptimizeForNetworkUse = true
        
        exportSession?.exportAsynchronously {
            switch exportSession?.status {
            case .completed:
                print("转换完成: \(outputURL)")
                completion(outputURL)
            case .failed, .cancelled:
                print("转换失败: \(exportSession?.error?.localizedDescription ?? "未知错误")")
                completion(nil)
            default:
                break
            }
        }
    }
    
    static func replaceHEICToJPGUrl(in filename: String) -> String {
         // 检查文件名是否以 .HEIC 或 .heic 结尾
         if filename.lowercased().hasSuffix(".heic") {
             // 移除 .heic 扩展名（不区分大小写）
             let nameWithoutExtension = String(filename.dropLast(5))
             // 添加 .JPG 扩展名
             return nameWithoutExtension + ".jpg"
         }
         return filename
     }
    
    static func getLiveURL(asset:PHAsset)->String{
         /// 当选中资源为Live时
         /// 生成 A to H Live存储地址
         let nameStr = PHAssetResource.assetResources(for: asset).first?.originalFilename
         var livePhotoTmpStr = FileManager.default.temporaryDirectory.relativeString + (nameStr ?? ".jpg")
         livePhotoTmpStr = SharedFilesManager.replaceHEICToJPGUrl(in: livePhotoTmpStr)
         /// 移除路径前面的file:// C++那边说是无法识别带file://的路径
         livePhotoTmpStr = NSString(string: livePhotoTmpStr).replacingOccurrences(of: "file://", with: "")
         print("livePhotoTmpStr ========\(livePhotoTmpStr)")
         return livePhotoTmpStr
     }
    func getFileSize(for fileURL: URL) -> Int? {
        let hasAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                fileURL.stopAccessingSecurityScopedResource() // 用完释放权限
            }
        }
        do {
            // 读取文件的 "fileSize" 属性
            let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
            if resourceValues.fileSize ?? 0 > 0{
                return resourceValues.fileSize
            }
            let fileManager = FileManager.default
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            return attributes[.size] as? Int
        } catch {
            print("获取文件大小失败：\(error.localizedDescription)")
            return nil
        }
    }


}

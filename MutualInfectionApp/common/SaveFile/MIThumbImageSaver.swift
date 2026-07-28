//
//  MIThumbImageSaver.swift
//  MutualInfection
//
//  Created by apple on 2025/12/1.
//

import Photos
import Foundation
import QuickLookThumbnailing

#if os(macOS)
import AppKit
typealias SystemImage = NSImage
#else
import UIKit
typealias SystemImage = UIImage
#endif

class MIThumbImageDataFileManager {
    
    static let shared = MIThumbImageDataFileManager()

    /// 超过多少就开始存数据库
    let DB_HANDLE_MAX_COUNT = 100
    
    var transferFiles: [MITransferFile] = []
    
    /// 恢复默认值
    func setupDefautValues() {
        transferFiles = []
    }
    
    /// 重新请求
    let batchProcessor = MIBatchProcessor()
    /// 上一次请求时间
    var lastRequestTimeInterval: TimeInterval = 0
    /// 重新请求缩略图
    func requestThumbnailImageDataAgain() {
        let thisTimeInterval = Date().timeIntervalSince1970
        let compareTimeInterval = thisTimeInterval - lastRequestTimeInterval
        // 请求时间小于20分钟
        if compareTimeInterval < 20 * 60 {
            return
        }
        lastRequestTimeInterval = thisTimeInterval

        var thumbImageItems: [MIThumbImageOperation] = []
        let unrequestFiles =  MIWCDBManager.shared.getUnrequestThumbImageDataFiles()
        for unrequestThumbImageDataFile in unrequestFiles {
            let item = MIThumbImageOperation()
            item.file = unrequestThumbImageDataFile
            item.filePath = unrequestThumbImageDataFile.thumbnailImageFilePath
            item.fileName = unrequestThumbImageDataFile.fileName
            thumbImageItems.append(item)
        }
        
        if thumbImageItems.count > 0 {
            batchProcessor.cancelAll()
            batchProcessor.processBatchWithOperationQueue(items: thumbImageItems) {
                
            }
        }
    }
    
    /// 判断是否更新数据库
    func updateThumbnailImageData() {
        if transferFiles.count > DB_HANDLE_MAX_COUNT {
            changeThumbnailImageData()
        }
    }
    
    /// 所有进程都结束
    func operationFinish() {
        changeThumbnailImageData()
    }
    
    /// 更新数据库
    func changeThumbnailImageData() {
        let files = transferFiles
        transferFiles = []
        
        let unrequestFiles = MIWCDBManager.shared.getUnrequestThumbImageDataFiles()
        var needUpdateFiles: [MITransferFile] = []
        for file in files {
            for unrequestThumbImageDataFile in unrequestFiles {
                if file.thumbnailImageCheckId.count > 0,
                   file.thumbnailImageCheckId == unrequestThumbImageDataFile.thumbnailImageCheckId {
                    unrequestThumbImageDataFile.thumbnailImageData = file.thumbnailImageData
                    unrequestThumbImageDataFile.haveRequestThumbnailImageData = true
                    needUpdateFiles.append(unrequestThumbImageDataFile)
                    break
                }
            }
        }
        
        if needUpdateFiles.count > 0 {
            MIWCDBManager.shared.updateFileThumbImageData(files: needUpdateFiles)
        }
    }
}

class MIThumbImageOperation: MIAsynchronousOperation, @unchecked Sendable {
    
    static var handleIndex: Int = 0
    
    var file: MITransferFile?
    var filePath: String?
    var fileName: String?
    
    init(file: MITransferFile? = nil, filePath: String? = nil, fileName: String? = nil) {
        file?.thumbnailImageCheckId = UUID().uuidString
        file?.thumbnailImageFilePath = filePath
        
        self.file = file
        self.filePath = filePath
        self.fileName = fileName
    }
    
    override func main() {
        let path = filePath ?? ""
        let fileIdentifier = self.file?.identifier ?? ""
        if path.count > 0,
           FileManager.default.fileExists(atPath: path) == false,
           fileIdentifier.count > 0 {
            MIThumbImageSaver.shared.fetchThumbnail(for: fileIdentifier) { [weak self] thumbnailImageData in
                self?.updateThumbnailImageFileData(thumbnailImageData: thumbnailImageData)
            }
            return
        }
        
        MIThumbImageSaver.shared.changeImageToData((URL(fileURLWithPath: filePath ?? "")), fileName: fileName ?? "", completion: { [weak self] thumbnailImageData in
            self?.updateThumbnailImageFileData(thumbnailImageData: thumbnailImageData)
        })
    }
    
    func updateThumbnailImageFileData(thumbnailImageData: Data?) {
        MIThumbImageOperation.handleIndex += 1
        ShareAPI.shared().log(1, "[MIThumbImageSaver] changeImageToData 当前已处理\(MIThumbImageOperation.handleIndex)个")
        self.file?.thumbnailImageData = thumbnailImageData
        
        if let file = self.file {
            MIThumbImageDataFileManager.shared.transferFiles.append(file)
            MIThumbImageDataFileManager.shared.updateThumbnailImageData()
        }
        
        self.finish()
    }
}

class MIBatchProcessor {
    
    private let operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.MIThumbImageSaver.batchProcessor"
        // 核心控制：设置最大并发操作数
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    func processBatchWithOperationQueue(items: [MIThumbImageOperation],
                                         completion: @escaping () -> Void) {
        MIThumbImageOperation.handleIndex = 0
        ShareAPI.shared().log(1, "[MIThumbImageSaver] changeImageToData 总数:\(items.count)个")
        
        MIThumbImageDataFileManager.shared.setupDefautValues()
        let group = DispatchGroup()
        
        for item in items {
            group.enter()
            
            item.completionBlock = {
                group.leave()
            }
            
            // 将操作添加到队列（队列会自动管理并发）
            operationQueue.addOperation(item)
        }
        
        // 所有操作完成后通知
        group.notify(queue: .main) {
            ShareAPI.shared().log(1, "[MIThumbImageSaver] 所有Operation已完成")
            MIThumbImageDataFileManager.shared.operationFinish()
            completion()
        }
    }
    
    // 可以随时取消所有任务
    func cancelAll() {
        operationQueue.cancelAllOperations()
    }
}


class MIThumbImageSaver {
    
    static let shared = MIThumbImageSaver()
    
    func changeImageToData(_ url: URL?, fileName: String, width: Int = 100, height: Int = 100, completion: @escaping (Data?) -> Void) {
        autoreleasepool{
            _changeImageToData(url, fileName: fileName, width: width, height: height, completion: completion)
        }
    }
    func _changeImageToData(_ url: URL?, fileName: String, width: Int, height: Int, completion: @escaping (Data?) -> Void) {
        guard let url = url else {
            completion(nil)
            return
        }
        
        var imageData: Data?
        
        let type = SaveFileHandler.shared.getFileTypeByFileName(fileName)
        
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        
        /// 文档类
        if type == FileDirectoryType.doc.rawValue && fileExtension != "txt" || fileExtension == "svg"{
            thumbnail(filePath: url.path, size: CGSize(width: width, height: height)) { [weak self] image in
                guard let self = self else { return }
                
                imageData = convertImageToData(image)
                completion(imageData)
            }
        } else
        
        /// 视频
        if type == "library_video" {
            fetchFirstFrame(from: url) { [weak self] image in
                if let image = image {
#if os(macOS)
                    let cImage = self?.resizeImageKeepingAspectRatio(sourceImage: image, toFit: NSSize(width: width, height: height))
                    //                    print("cImage:\(String(describing: cImage))")
                    imageData = self?.convertImageToData(cImage ?? nil) ?? nil
#else
                    let cImage = self?.resizeImageKeepingAspectRatio(sourceImage: image, toFit: CGSize(width: width, height: height))
                    //                    print("cImage:\(String(describing: cImage))")
                    imageData = self?.convertImageToData(cImage ?? nil) ?? nil
#endif
                    completion(imageData)
                    return
                }
                completion(nil)
            }
            return
        } else
        /// 图片
        if type == "library_image" || type == "is_live_or_image" {
#if os(macOS)
            let image = NSImage(contentsOf: url)
            if let image = image {
                let cImage = resizeImageKeepingAspectRatio(sourceImage: image, toFit: NSSize(width: width, height: height))
                imageData = convertImageToData(cImage)
            }
#else
//            let filePath = url.absoluteString.removingPercentEncoding ?? ""
//            let imagePath = filePath.replacingOccurrences(of: "file://", with: "")
//            let image = UIImage(contentsOfFile: imagePath)
            let image = UIImage(contentsOfFile: url.path.removingPercentEncoding ?? "")
            if let image = image {
                let cImage = resizeImageKeepingAspectRatio(sourceImage: image, toFit: CGSize(width: width, height: height))
                imageData = convertImageToData(cImage)
            }
#endif
            completion(imageData)
        }
        /// 不支持类型
        else {
            completion(nil)
        }
    }
    
#if os(macOS)
    func resizeImageKeepingAspectRatio(sourceImage: NSImage, toFit targetSize: NSSize) -> NSImage {
        // 1. 计算原图与目标尺寸的宽高比
        let sourceRatio = sourceImage.size.width / sourceImage.size.height
        let targetRatio = targetSize.width / targetSize.height
        
        // 2. 决定以哪条边为基准进行缩放（Fit模式：缩放到能完全放入目标框）
        var drawingSize = NSSize.zero
        if sourceRatio > targetRatio {
            // 原图更“宽”，以目标宽度为基准缩放
            drawingSize.width = targetSize.width
            drawingSize.height = targetSize.width / sourceRatio
        } else {
            // 原图更“高”，以目标高度为基准缩放
            drawingSize.height = targetSize.height
            drawingSize.width = targetSize.height * sourceRatio
        }
        
        // 3. 创建新图像并绘制
        let resizedImage = NSImage(size: drawingSize)
        resizedImage.lockFocus()
        
        // 设置高质量插值
        NSGraphicsContext.current?.imageInterpolation = .high
        
        // 在计算出的尺寸内绘制原图
        sourceImage.draw(in: NSRect(origin: .zero, size: drawingSize),
                         from: NSRect(origin: .zero, size: sourceImage.size),
                         operation: .copy,
                         fraction: 1.0)
        
        resizedImage.unlockFocus()
        return resizedImage
    }
    
    func convertImageToData(_ image: NSImage?) -> Data? {
        guard let image = image else {
            return nil
        }
        
        // 获取图像的位图表示（NSBitmapImageRep）
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        // 转换为 JPEG 数据
        let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
        
        return jpegData
    }
#else
    func resizeImageKeepingAspectRatio(sourceImage: UIImage, toFit targetSize: CGSize) -> UIImage {

        let sourceWidth = sourceImage.size.width
        let sourceHeight = sourceImage.size.height
        
        let sourceRatio = sourceWidth / sourceHeight
        let targetRatio = targetSize.width / targetSize.height
        
        var drawingSize = CGSize.zero
        
        if sourceRatio > targetRatio {
            // 原图更“宽”
            let newWidth = targetSize.width
            let newHeight = targetSize.width / sourceRatio
            drawingSize = CGSize(width: round(newWidth), height: round(newHeight))
        } else {
            // 原图更“高”
            let newHeight = targetSize.height
            let newWidth = targetSize.height * sourceRatio
            drawingSize = CGSize(width: round(newWidth), height: round(newHeight))
        }

        // 使用 renderer 绘制（推荐使用 scale: sourceImage.scale）
        let format = UIGraphicsImageRendererFormat()
        format.scale = sourceImage.scale
        
        let renderer = UIGraphicsImageRenderer(size: drawingSize, format: format)
        let resizedImage = renderer.image { _ in
            sourceImage.draw(in: CGRect(origin: .zero, size: drawingSize))
        }
        
        return resizedImage
    }
    
    func convertImageToData(_ image: UIImage?) -> Data? {
        guard let image = image else {
            return nil
        }
        
        if let data = image.pngData() {
            return data
        }
        
        return image.jpegData(compressionQuality: 0.8)
    }
#endif
    
    /// 获取视频图片
    func fetchFirstFrame(from videoURL: URL, completion: @escaping (SystemImage?) -> Void) {
        // 1. 创建资源对象
        let asset = AVURLAsset(url: videoURL)
        
        // 2. 创建图像生成器
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true // 修正视频方向[citation:1][citation:6]
        generator.requestedTimeToleranceBefore = .zero // 可设为CMTime.zero以提高精确度
        generator.requestedTimeToleranceAfter = .zero
        
        let time = CMTime(seconds: 0, preferredTimescale: 600) // 取第0秒[citation:1][citation:9]
        
        // 3. 异步生成图像
        generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImage, _, _, error in
            if let error = error {
                print("生成图像失败：\(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            guard let cgImage = cgImage else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            // 4. 将 CGImage 转换为系统图像类型
            #if canImport(UIKit)
            let image = UIImage(cgImage: cgImage)
            #elseif canImport(AppKit)
            let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            #endif
            
            DispatchQueue.main.async { completion(image) }
        }
    }
    
    
    /// 生成文件缩略图
    /// - Parameters:
    ///   - filePath: 文件路径
    ///   - size: 目标缩略图尺寸
    ///   - completion: 返回图像
    func thumbnail(filePath: String, size: CGSize, completion: @escaping (SystemImage?) -> Void) {
        let url = URL(fileURLWithPath: filePath)
        let scale: CGFloat
#if os(iOS)
        scale = UIScreen.main.scale
#elseif os(macOS)
        scale = NSScreen.main?.backingScaleFactor ?? 2.0
#endif
        let request = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: scale, representationTypes: .all)
        
        // 通用生成 API
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { rep, error in
            
            guard let rep = rep else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
#if os(iOS)
            let image = rep.uiImage
#elseif os(macOS)
            let image = rep.nsImage
#endif
            
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }
    
    func fetchThumbnail(for localIdentifier: String, targetSize: CGSize = CGSize(width: 200, height: 200), contentMode: PHImageContentMode = .aspectFill, completion: @escaping (Data?) -> Void
    ) {
        guard let asset = getAssetFromLocalIdentifier(localIdentifier) else {
            completion(nil)
            return
        }
        
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .opportunistic  // 先返回低质量图片，再返回高质量图片
        options.isNetworkAccessAllowed = false  // 不允许从iCloud下载
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: contentMode,
            options: options
        ) { [weak self] image, info in
            DispatchQueue.main.async {
                var imageData: Data?
#if os(macOS)
                if let image = image {
                    let cImage = self?.resizeImageKeepingAspectRatio(sourceImage: image, toFit: NSSize(width: targetSize.width, height: targetSize.height))
                    imageData = self?.convertImageToData(cImage)
                }
#else
                if let image = image {
                    let cImage = self?.resizeImageKeepingAspectRatio(sourceImage: image, toFit: CGSize(width: targetSize.width, height: targetSize.height))
                    imageData = self?.convertImageToData(cImage)
                }
#endif
                completion(imageData)
            }
        }
    }
    
    /// 根据标识符查询PHAsset
    func getAssetFromLocalIdentifier(_ localIdentifier: String) -> PHAsset? {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        return fetchResult.firstObject
    }
    
    /// 获取文件图标
    func getFileIcon(fileExtension: String) -> SystemImage? {
        var image: SystemImage?
        switch fileExtension {
        case "7z":
            image = SystemImage.icon7Z
        case "amr":
            image = SystemImage.iconAmr
        case "ape":
            image = SystemImage.iconApe
        case "bag":
            image = SystemImage.iconBag
        case "caj":
            image = SystemImage.iconCaj
        case "chm":
            image = SystemImage.iconChm
        case "flac":
            image = SystemImage.iconFlac
        case "fold":
            image = SystemImage.iconFold
        case "html":
            image = SystemImage.iconHtml
        case "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp", "svg", "heic", "heif", "ico", "psd", "jpg":
            image = SystemImage.iconImg
        case "kdh":
            image = SystemImage.iconKdh
        case "link":
            image = SystemImage.iconLink
        case "log":
            image = SystemImage.iconLog
        case "m4a":
            image = SystemImage.iconM4A
        case "mp3":
            image = SystemImage.iconMp3
        case "nh":
            image = SystemImage.iconNh
        case "overlap":
            image = SystemImage.iconOverlap
        case "pdf":
            image = SystemImage.iconPdf
        case "ppt":
            image = SystemImage.iconPpt
        case "rar":
            image = SystemImage.iconRar
        case "teb":
            image = SystemImage.iconTeb
        case "vcf", "zcf", "text":
            image = SystemImage.iconText
        case "txt":
            image = SystemImage.iconTxt
        case "wav":
            image = SystemImage.iconWav
        case "wma":
            image = SystemImage.iconWma
        case "doc", "docx", "docm", "dot", "dotx", "dotm", "rtf":
            image = SystemImage.iconWord
        case "xml":
            image = SystemImage.iconXml
        case "zip":
            image = SystemImage.iconZip
        default:
            image = SystemImage.iconUnknown
        }
        return image
    }
}

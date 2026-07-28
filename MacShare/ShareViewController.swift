//
//  ShareViewController.swift
//  MacShare
//
//  Created by NB1539 on 2025/11/6.
//

import Cocoa
import Photos
import ImageIO
import CommonCrypto
import AppKit
import UniformTypeIdentifiers
import AVFoundation
import CoreServices


public enum LivePhotoErr: Error {
    case imageErr(String)
    case videoErr(String)
    case allErr(String)
    
    var assetErr: String {
        switch self {
        case .imageErr(_):
            return "imageErr"
        case .videoErr(_):
            return "videoErr"
        case .allErr(_):
            return "allErr"
        }
    }
}


class ShareViewController: NSViewController {
    
    
    // UI 组件
    private var containerView: NSView!
    private var previewImageView: NSImageView!
    private var fileInfoLabel: NSTextField!
    private var countLabel: NSTextField!
    private var sendButton: NSButton!
    private var cancelButton: NSButton!
    
    // 存储文件 URLs
    private var fileURLs: [URL] = []
    private var securityScopedResources: [URL] = [] // 保持安全访问
    
    override func loadView() {
        // 提供一个空视图，避免加载xib
        self.view = NSView(frame: NSMakeRect(0, 0, 0, 0))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        print("======================================")
        print("Share Extension 已加载")
        // 处理共享的文件
        processSharedItems{ }        
    }
    
    deinit {
        print("Share Extension --- 已释放")
        releaseSecurityScopedResources()
    }
    private func releaseSecurityScopedResources() {
        for url in securityScopedResources {
            url.stopAccessingSecurityScopedResource()
        }
        securityScopedResources.removeAll()
    }
        
    
    private func getFileSize(url: URL) -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let size = attributes[.size] as? UInt64 {
                return formatFileSize(size)
            }
        } catch {
            print("获取文件大小失败: \(error)")
        }
        return "未知大小".localized
    }
    
    private func processSharedItems(completion: @escaping() -> Void){
        guard let extensionContext = self.extensionContext,
              let inputItems = extensionContext.inputItems as? [NSExtensionItem] else {
            print("错误: 没有输入项")
            completion()
            return
        }
        
        let group = DispatchGroup()
        
        for item in inputItems {
            guard let attachments = item.attachments else { continue }
            
            print("收到 \(attachments.count) 个附件")
            
            for (index, attachment) in attachments.enumerated() {
                print("\n处理附件 \(index + 1):")
                // 检查是否为文件 URL
               if attachment.hasItemConformingToTypeIdentifier("public.file-url") {
                    group.enter()
                    
                    attachment.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (item, error) in
                        defer { group.leave() }
                        
                        if let error = error {
                            print("  错误: \(error.localizedDescription)")
                            return
                        }
                        
                        if let url = item as? URL {
                            print("  文件 URL: \(url.path)")
                            // 开始访问安全范围资源
                            let accessing = url.startAccessingSecurityScopedResource()
                            if accessing {
                                self.securityScopedResources.append(url)
                            }
                            self.fileURLs.append(url)
                            
                            // 停止访问（在这里停止，因为我们已经保存了路径）
                            if accessing {
                                url.stopAccessingSecurityScopedResource()
                            }
                        } 
                        else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                            print("  文件 URL (从 Data): \(url.path)")
                            if !self.isScreenCaptureTempFile(url.path) {
                                print("  不是截屏或录屏")
                                let accessing = url.startAccessingSecurityScopedResource()
                                if accessing {
                                    self.securityScopedResources.append(url)
                                }
                                self.fileURLs.append(url)
                            }
                        }
                    }
                }
            }
        }
        
        
        
        

        // 等待所有文件处理完成
        group.notify(queue: .main) {
            print("\n所有文件处理完成，共== \(self.fileURLs.count) 个文件")
            // 1. 立即让系统继续它的保存流程
            print("🔄 让出控制权，让系统先处理保存...")
            
            // 2. 延迟读取（给系统时间完成保存）
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                if self.fileURLs.count > 0{
                    // 保存文件到 App Group
                    self.saveFilesToAppGroup(self.fileURLs)
                    
                    // 使用 URL Scheme 打开主应用（无需自动化权限！）
                    self.openMainAppWithURLScheme()
                    
                    // 延迟关闭扩展，给应用时间启动
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                    }
                }else{
                    self.temporaryItems(inputItems: inputItems)
                }
            }
            
        }
    }
    
    func temporaryItems(inputItems:[NSExtensionItem]){
        print("  如果没有文件，进行截图数据的判断")
        // 如果没有文件，进行截图数据的判断
        let groupItems = DispatchGroup()
        for item in inputItems {
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier("public.image") {
                    print("截屏图片")
                    groupItems.enter()
                    provider.loadDataRepresentation(forTypeIdentifier: kUTTypeImage as String) { [weak self] data, error in
                        DispatchQueue.main.async {
                            guard let data = data else {
                                print("kUTTypeImage获取图片失败:\(String(describing: error?.localizedDescription))")
                                defer { groupItems.leave() }
                                return
                            }
                            //MARK: 这里的data不是图片数据，也不是像素数据，是macOS封装的Plist数据
                            // 解析plist并提取图片Data（核心步骤）
                            do {
                                let plistObject = try PropertyListSerialization.propertyList(from: data, options: .mutableContainers, format: nil)
                                
                                var candidateImageDatas: [Data] = []
                                self?.traversePlistObject(plistObject, collectedDatas: &candidateImageDatas)
                                
                                // 验证所有候选数据，找到第一个有效图片Data
                                guard let realImageData = self?.findValidImageData(from: candidateImageDatas) else {
                                    print("遍历所有元素未找到有效图片数据")
                                    defer { groupItems.leave() }
                                    return
                                }
                                
                                print("从plist提取到图片Data长度：\(realImageData.count) 字节")
                                print("图片Data前8字节（格式签名）：\(realImageData.prefix(8).map { String(format: "%02X", $0) }.joined(separator: " "))")
                                // 转NSImage + 编码为PNG
                                self?.convertToPNG(from: realImageData) { [weak self] url in
                                    guard let s = self, let testUrl = url else {
                                        defer { groupItems.leave() }
                                        return
                                    }
                                    s.fileURLs.append(testUrl)
                                    do { groupItems.leave() }
                                }
                            } catch {
                                self?.countLabel.stringValue = "解析plist失败：".localized + "\(error.localizedDescription)"
                                do { groupItems.leave() }
                            }
                        }
                    }
                }
                else if provider.hasItemConformingToTypeIdentifier("com.apple.quicktime-movie") {
                    print("录屏视频==")
                    groupItems.enter()
                    provider.loadDataRepresentation(forTypeIdentifier: kUTTypeMovie as String) { [weak self] data, error in
                        DispatchQueue.main.async {
                            guard let data = data else {
                                print("kUTTypeMovie获取视频失败:\(String(describing: error?.localizedDescription))")
                                defer { groupItems.leave() }
                                return
                            } 
                            guard let containerURL = self?.getPrivateCacheDirectory()else{
                                print("为能生成临时路径")
                                return
                            }
                            // 处理并保存录屏
                            self?.processScreenRecordingData(data, saveTo: containerURL) { url in
                                if let url = url {
                                    self?.fileURLs.append(url)
                                }
                                do { groupItems.leave() }
                            }
                        }
                    }
                }
            }
        }

        groupItems.notify(queue: .main) {
            // 保存文件到 App Group
            self.saveFilesToAppGroup(self.fileURLs)
            
            // 使用 URL Scheme 打开主应用（无需自动化权限！）
            self.openMainAppWithURLScheme()
            
            // 延迟关闭扩展，给应用时间启动
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
        }
    }
    
    func saveToSharedContainer(url: URL) -> URL  {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else { return url}
        
        let filename = url.lastPathComponent
        let destinationURL = containerURL.appendingPathComponent(filename)
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: url, to: destinationURL)
            print("已保存录屏到: \(destinationURL.path)")
            return destinationURL
        } catch {
            print("复制文件失败: \(error)")
            return url
        }
    }
    
    // MARK: - 核心工具方法
   
    
    
        
        // MARK: - 主处理方法
        
        /// 处理录屏二进制数据并保存为系统标准命名的.mov文件
        /// - Parameters:
        ///   - videoData: 录屏原始二进制数据
        ///   - destinationDirectory: 目标保存目录
        ///   - completion: 完成后返回文件URL
        func processScreenRecordingData(_ videoData: Data, saveTo destinationDirectory: URL,completion: @escaping (URL?) -> Void) {
            
            DispatchQueue.global(qos: .userInitiated).async {
                // 1. 验证数据
                guard self.validateVideoData(videoData) else {
                    DispatchQueue.main.async {
                        print("❌ 视频数据验证失败")
                        completion(nil)
                    }
                    return
                }
                // 2. 生成系统标准文件名
                let fileName = self.generateSystemStyleFilename()
                
                // 3. 确保目标目录存在
                let destinationURL = destinationDirectory.appendingPathComponent(fileName)
                let finalURL = self.resolveFilenameConflict(destinationURL)
                // 4. 写入文件
                do {
                    try videoData.write(to: finalURL)
                    // 5. 验证文件完整性
                    let isValid = self.validateWithoutAffectingSystem(finalURL)
                    DispatchQueue.main.async {
                        if isValid {
                            print("✅ 录屏文件保存成功:")
                            print("   文件名: \(finalURL.lastPathComponent)")
                            print("   路径: \(finalURL.path)")
                            print("   大小: \(self.getFileSizeMB(finalURL)) MB")
                            print("   时长: \(self.getVideoDuration(finalURL)) 秒")
                            self.markAsTemporaryFile(finalURL)
                            completion(finalURL)
                        } else {
                            print("⚠️ 文件保存但验证失败，可能需要用户点击'完成'")
                            // 仍返回文件URL，但标记为临时
                            completion(finalURL)
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        print("❌ 保存文件失败: \(error.localizedDescription)")
                        completion(nil)
                    }
                }
            }
        }
        
        // MARK: - 数据验证
        private func validateVideoData(_ data: Data) -> Bool {
            // 1. 基本大小检查
            guard data.count > 1024 * 10 else { // 至少100KB
                print("数据过小: \(data.count) 字节")
                return false
            }
            
            // 2. 检查QuickTime签名
            guard isQuickTimeFormat(data) else {
                print("不是QuickTime格式")
                return false
            }
            
            // 3. 检查关键原子结构
            let hasRequiredAtoms = checkRequiredAtoms(data)
            if !hasRequiredAtoms {
                print("⚠️ 缺少完整原子结构（可能在编辑中）")
                // 仍然尝试处理，但标记为可能不完整
            }
            
            return true
        }
        private func isQuickTimeFormat(_ data: Data) -> Bool {
            guard data.count >= 12 else { return false }
            
            // QuickTime标准签名: ftyp atom
            let expectedHeader: [UInt8] = [0x00, 0x00, 0x00, 0x14, 0x66, 0x74, 0x79, 0x70]
            let actualHeader = [UInt8](data.prefix(8))
            
            if actualHeader == expectedHeader {
                print("✅ 确认: QuickTime .mov 格式")
                return true
            }
            
            // 也可能是其他变体
            if data.count >= 20 {
                let headerStr = String(data: data[4..<8], encoding: .utf8)
                if headerStr == "ftyp" {
                    print("✅ 确认: 变体QuickTime格式")
                    return true
                }
            }
            
            return false
        }
        private func checkRequiredAtoms(_ data: Data) -> Bool {
            var hasFtyp = false
            var hasMdat = false
            
            // 扫描关键原子
            var offset = 0
            while offset + 8 < data.count {
                // 读取原子大小和类型
                let sizeRange = offset..<(offset + 4)
                let typeRange = (offset + 4)..<(offset + 8)
                
                guard sizeRange.upperBound < data.count, 
                        typeRange.upperBound < data.count else { break }
                
                // 获取原子类型
                if let type = String(data: data[typeRange], encoding: .utf8) {
                    if type == "ftyp" { hasFtyp = true }
                    if type == "mdat" { hasMdat = true }
                    
                    // 读取原子大小（大端序）
                    let size = data[sizeRange].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
                    if size == 0 { break } // size=0表示到文件末尾
                    
                    offset += Int(size)
                } else {
                    break
                }
                
                if hasFtyp && hasMdat { break }
            }
            
            print("原子检查: ftyp=\(hasFtyp), mdat=\(hasMdat)")
            return hasFtyp && hasMdat
        }
        
        // MARK: - 文件名生成（系统标准）
        private func generateSystemStyleFilename() -> String {
            let dateFormatter = DateFormatter()
            
            // 获取系统语言设置
            let locale = Locale.current
            let isChinese = locale.identifier.hasPrefix("zh")
            
            if isChinese {
                // 中文系统: "屏幕录制 YYYY-MM-DD HH.mm.ss.mov"
                dateFormatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
                return "屏幕录制 \(dateFormatter.string(from: Date())).mov"
            } else {
                // 英文系统: "Screen Recording YYYY-MM-DD at HH.mm.ss.mov"
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let dateStr = dateFormatter.string(from: Date())
                
                dateFormatter.dateFormat = "HH.mm.ss"
                let timeStr = dateFormatter.string(from: Date())
                
                return "Screen Recording \(dateStr) at \(timeStr).mov"
            }
        }
        private func resolveFilenameConflict(_ originalURL: URL) -> URL {
            let fileManager = FileManager.default
            var finalURL = originalURL
            var counter = 1
            
            while fileManager.fileExists(atPath: finalURL.path) {
                let baseName = originalURL.deletingPathExtension().lastPathComponent
                let ext = originalURL.pathExtension
                
                // 系统风格的冲突解决: "Screen Recording 2024-01-15 at 10.30.00 1.mov"
                let newName: String
                let locale = Locale.current
                let isChinese = locale.identifier.hasPrefix("zh")
                
                if isChinese {
                    newName = "\(baseName) \(counter).\(ext)"
                } else {
                    newName = "\(baseName) \(counter).\(ext)"
                }
                
                finalURL = originalURL.deletingLastPathComponent()
                    .appendingPathComponent(newName)
                counter += 1
            }
            
            if counter > 1 {
                print("⚠️ 文件名冲突，重命名为: \(finalURL.lastPathComponent)")
            }
            
            return finalURL
        }
        
        // MARK: - 文件验证和工具方法
    private func validateWithoutAffectingSystem(_ url: URL) -> Bool {
        // 基本文件存在检查
        guard FileManager.default.fileExists(atPath: url.path) else {
            return false
        }
        
        // 简单的文件大小检查（不调用AVFoundation，避免系统资源占用）
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = (attributes[.size] as? Int) ?? 0
            
            // 录屏文件通常大于100KB
            return fileSize > 10 * 1024
            
        } catch {
            return false
        }
    }
    private func getFileSizeMB(_ url: URL) -> String {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                let fileSize = (attributes[.size] as? NSNumber)?.doubleValue ?? 0
                return String(format: "%.2f", fileSize / (1024 * 1024))
            } catch {
                return "未知"
            }
        }
    private func getVideoDuration(_ url: URL) -> String {
        let asset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)
        return String(format: "%.1f", duration)
    }
    /// 标记为临时文件
    private func markAsTemporaryFile(_ url: URL) {
        do {
            // 3. 标记为临时文件，系统可清理
            var mutableURL = url
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try mutableURL.setResourceValues(resourceValues)
            print("✅ 文件已标记为临时文件: \(url.lastPathComponent)")
        } catch {
            print("标记临时文件失败: \(error)")
        }
    }
    
    /// 获取私有缓存目录（不影响用户文件系统）
    private func getPrivateCacheDirectory() -> URL? {
        // 1. 使用应用的私有缓存目录
        guard let cacheDir = FileManager.default.urls(
            for: .cachesDirectory, 
            in: .userDomainMask
        ).first else {
            return nil
        }
        
        // 2. 创建子目录
        var privateDir = cacheDir.appendingPathComponent("TempRecordings")
        
        do {
            try FileManager.default.createDirectory(at: privateDir, 
                                                    withIntermediateDirectories: true)
            
            // 3. 标记为临时文件，系统可清理
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try privateDir.setResourceValues(resourceValues)
            
            return privateDir
            
        } catch {
            print("创建私有目录失败: \(error)")
            return nil
        }
    }
    
    
    
    /// 递归遍历plist所有元素（支持字典/数组嵌套），收集可能的图片数据
    private func traversePlistObject(_ object: Any, collectedDatas: inout [Data]) {
        // 如果是Data，直接加入候选
        if let data = object as? Data {
            collectedDatas.append(data)
            print("收集到Data：长度 \(data.count) 字节，前8字节：\(data.prefix(8).map { String(format: "%02X", $0) }.joined(separator: " "))")
            return
        }
        
        // 如果是字符串，尝试Base64解码（可能图片数据被Base64编码）
        if let string = object as? String {
            if let base64Data = Data(base64Encoded: string, options: .ignoreUnknownCharacters) {
                collectedDatas.append(base64Data)
                print("收集到Base64字符串，解码后长度 \(base64Data.count) 字节")
            }
            return
        }
        
        // 如果是字典，递归遍历所有value
        if let dict = object as? [String: Any] {
            print("遍历字典，key数量：\(dict.count)，key列表：\(dict.keys.joined(separator: ", "))")
            for (key, value) in dict {
                print("  递归处理key：\(key)，值类型：\(type(of: value))")
                traversePlistObject(value, collectedDatas: &collectedDatas)
            }
            return
        }
        
        // 如果是数组，递归遍历所有元素
        if let array = object as? [Any] {
            print("遍历数组，元素数量：\(array.count)")
            for (index, item) in array.enumerated() {
                print("  递归处理数组索引 \(index)，元素类型：\(type(of: item))")
                traversePlistObject(item, collectedDatas: &collectedDatas)
            }
            return
        }
        
        // 其他类型（数字、布尔等）忽略
        print("忽略非目标类型：\(type(of: object))")
    }
    /// 验证候选Data是否为有效图片（支持PNG/JPG/TIFF/WebP等）
    private func findValidImageData(from candidateDatas: [Data]) -> Data? {
        guard !candidateDatas.isEmpty else {
            print("无候选图片数据")
            return nil
        }
        
        for (index, data) in candidateDatas.enumerated() {
            // 跳过过小的数据（小于100字节不可能是图片）
            guard data.count > 100 else {
                print("候选数据 \(index)：长度过小（\(data.count) 字节），跳过")
                continue
            }
            
            // 直接用NSImage验证
            if NSImage(data: data) != nil {
                print("候选数据 \(index)：NSImage验证有效，确认为图片Data")
                return data
            }
            
            // 用ImageIO验证（兼容更多格式）
            if let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
               CGImageSourceCreateImageAtIndex(imageSource, 0, nil) != nil {
                print("候选数据 \(index)：ImageIO验证有效，确认为图片Data")
                return data
            }
            
            // 检查图片格式签名（兜底）
            let signature = data.prefix(4).map { String(format: "%02X", $0) }.joined()
            let validSignatures = ["8950", "FFD8", "4949", "4D4D", "5249"] // PNG/JPG/TIFF/WebP
            if validSignatures.contains(signature) {
                print("候选数据 \(index)：格式签名匹配（\(signature)），确认为图片Data")
                return data
            }
            
            print("候选数据 \(index)：无效图片数据，跳过")
        }
        
        return nil
    }    
    /// 真实图片Data转PNG
    private func convertToPNG(from realImageData: Data, completion: @escaping (URL?) ->Void) {
        // 先验证图片Data是否有效
        guard let image = NSImage(data: realImageData) else {
            // 若直接转失败，用ImageIO解析（兼容更多格式）
            guard let imageSource = CGImageSourceCreateWithData(realImageData as CFData, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                self.countLabel.stringValue = "图片Data无效，无法转成图像".localized
                return
            }
            
            // 直接用CGImage编码PNG
            if let pngData = self.encodeCGImageToPNG(cgImage) {
                self.countLabel.stringValue = "plist提取数据转PNG成功！PNG大小：".localized + "\(pngData.count)" + "字节".localized
                self.savePNGData(pngData, fileName: "截屏".localized + " \(getCurrentTimeFormatted())", completion: completion)
            } else {
                self.countLabel.stringValue = "CGImage编码PNG失败".localized
            }
            return
        }
        
        // 若直接转NSImage成功，编码为PNG
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            self.countLabel.stringValue = "NSImage转PNG失败".localized
            return
        }
        
        self.savePNGData(pngData, fileName: "截屏".localized + " \(getCurrentTimeFormatted())", completion: completion)
    }

    private func encodeCGImageToPNG(_ cgImage: CGImage) -> Data? {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            kUTTypePNG as CFString,
            1,
            nil
        ) else {
            print("创建PNG编码器失败")
            return nil
        }
        
        let pngOptions: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 1.0,
        ]
        
        CGImageDestinationAddImage(destination, cgImage, pngOptions as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            print("PNG编码失败")
            return nil
        }
        return mutableData as Data
    }

    // 保存PNG到沙盒的documentDirectory目录下
    private func savePNGData(_ pngData: Data, fileName: String, completion: @escaping (URL?) ->Void) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let targetURL = documentsURL.appendingPathComponent("\(fileName).png")
        do {
            try pngData.write(to: targetURL)
            print("PNG保存成功：\(targetURL.path)")
            completion(targetURL)
        } catch {
            completion(nil)
            print("PNG保存失败：\(error.localizedDescription)")
        }
    }
    
    /// 返回当前时间
    func getCurrentTimeFormatted() -> String {
        let dateFormatter = DateFormatter()
        // 配置格式：年-月-日 时.分.秒（24小时制）
        dateFormatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        // 时区：使用系统当前时区（可选，默认就是 current）
        dateFormatter.timeZone = TimeZone.current
        // 地区：确保格式不随系统语言变化（关键）
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        // 获取当前时间并格式化
        return dateFormatter.string(from: Date())
    }
    

    
    //发送保存数据到共享目录
    private func saveFilesToAppGroup(_ fileURLs: [URL]) {
            guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
                print("错误: 无法访问 App Group")
                return
            }
            
            // 提取并保存文件信息（不只是路径）
            var filesInfo: [[String: Any]] = []
        let group = DispatchGroup()
        
            for url in fileURLs {
                
                var fileInfo: [String: Any] = [:]
                fileInfo["path"] = url.path
                fileInfo["name"] = url.deletingPathExtension().lastPathComponent
                fileInfo["type"] = url.pathExtension.isEmpty ? "未知" : url.pathExtension.uppercased()
                var urlPath = url.path

                group.enter()
                print("分享的文件地址=========\(url.path)")
                    
                    if self.isFromSystemPhotoLibrary(url) == true {
                        print("是相册中内容")
                        if let uuid = self.extractUUIDFromPath(url.path),let asset = self.fetchPhotoAsset(uuid) {
                            print("已获取到asset")
                            self.getTemporaryPathWithUUID(from: asset) { photoUrl, uuidstr in
                                if photoUrl != nil {
                                    urlPath = photoUrl!.path
                                }else{
                                    urlPath = url.path
                                }
                                group.leave()
                            }
                            print("通过uuid拿到了phasset=====")
                            print("通过uuid拿到了phasset=====\(url)")
                        }else{
                            urlPath = url.path
                            group.leave()
                        }
                    }else{
                        if let copiedFileInfo = self.copyContactFileToSharedSandbox(sourceURL: url) {
                            let dic = copiedFileInfo as? [String:Any]
                            urlPath = dic?["path"] as! String
                            defer { group.leave() }
                            print("✅ 文件拷贝成功==urlPath===\(urlPath)")
                        } else{
                            urlPath = url.path
                            print("❌ 文件拷贝失败")
                            group.leave()
                        }
                    }                    
//                }
                fileInfo["path"] = urlPath
                
                print("✅ 分享文件的==urlPath===\(urlPath)")
                
                // 在 Share Extension 中获取文件属性（这里有权限）
                if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) {
                    if let size = attributes[.size] as? UInt64 {
                        fileInfo["size"] = size
                    }
                    if let modifiedDate = attributes[.modificationDate] as? Date {
                        fileInfo["modifiedDate"] = modifiedDate.timeIntervalSince1970
                    }
                }
                
                filesInfo.append(fileInfo)
            }
            
            // 保存文件信息数组 
            sharedDefaults.set(filesInfo, forKey: "sharedFilesInfo")
            sharedDefaults.set(Date(), forKey: "sharedFilesTimestamp")
            sharedDefaults.synchronize()
            
        }
    func copyContactFileToSharedSandbox(sourceURL: URL) -> [String: Any]? {
        
        print("💾 开始拷贝文件到共享沙盒...")
        
        // 1. 获取共享容器目录
        guard let sharedContainerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            print("❌ 无法获取共享容器 URL")
            return nil
        }
        
        print("📁 共享容器路径: \(sharedContainerURL.path)")
        
        // 2. 创建共享联系人文件目录
        let contactsDirectory = sharedContainerURL.appendingPathComponent("SharedContacts")
        
        do {
            // 确保目录存在
            try FileManager.default.createDirectory(
                at: contactsDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            print("✅ 创建共享联系人目录成功")
            
            // 3. 生成唯一文件名（避免冲突）
            let originalFileName = sourceURL.lastPathComponent
            let fileExtension = sourceURL.pathExtension
            let uniqueFileName = "\(UUID().uuidString).\(fileExtension)"
            let destinationURL = contactsDirectory.appendingPathComponent(originalFileName)
            
            print("📄 文件信息:")
            print("   - 原始文件: \(originalFileName)")
            print("   - 目标文件: \(uniqueFileName)")
            print("   - 目标路径: \(destinationURL.path)")
            
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            // 4. 拷贝文件
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            print("✅ 文件拷贝操作完成")
            
            // 5. 验证拷贝是否成功
            guard FileManager.default.fileExists(atPath: destinationURL.path) else {
                print("❌ 拷贝验证失败: 目标文件不存在")
                return nil
            }
            
            // 6. 获取文件属性
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
            let fileSize = fileAttributes[.size] as? Int ?? 0
            
            print("✅ 文件拷贝验证成功")
            print("   - 文件大小: \(fileSize) 字节")
            print("   - 文件路径: \(destinationURL.lastPathComponent)")
            
            // 7. 创建文件信息字典
            let fileInfo: [String: Any] = [
                "fileName": uniqueFileName,
                "originalFileName": originalFileName,
                "fileType": fileExtension,
                "fileSize": fileSize,
                "filePath": "SharedContacts/\(uniqueFileName)", // 相对路径
                "timestamp": Date().timeIntervalSince1970,
                "isProcessed": false,
                "fileURL": destinationURL.lastPathComponent, // 只存储文件名
                "path": destinationURL.path // 路径
            ]
            
            return fileInfo
            
        } catch {
            print("❌ 文件拷贝过程中出错: \(error.localizedDescription)")
            return nil
        }
    }
    
    func saveFilesUsingSecureFileStorage(_ filesInfo: [[String: Any]]) -> Bool {
        let appGroupIdentifier = appGroupIdentifier // 替换为您的实际 App Group
        
        print("💾 开始安全文件存储...")
        
        // 1. 检查 App Group 容器访问
        guard let sharedContainerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            print("❌ 无法访问 App Group 容器: \(appGroupIdentifier)")
            print("   请检查:")
            print("   - App Group 是否在开发者中心配置")
            print("   - Bundle ID 前缀是否匹配")
            print("   - 证书和配置文件是否正确")
            return false
        }
        
        print("✅ 成功访问共享容器: \(sharedContainerURL.path)")
        
        // 2. 创建共享数据目录
        let sharedDataDir = sharedContainerURL.appendingPathComponent("sharedFilesInfo")
        
        do {
            // 确保目录存在
            try FileManager.default.createDirectory(at: sharedDataDir, withIntermediateDirectories: true, attributes: nil)
            print("✅ 创建共享数据目录成功")
            
            // 3. 保存主数据文件 (JSON 格式)
            let dataFileURL = sharedDataDir.appendingPathComponent("contact_files.json")
            let jsonData = try JSONSerialization.data(withJSONObject: filesInfo, options: .prettyPrinted)
            try jsonData.write(to: dataFileURL)
            print("✅ 数据文件保存成功: \(dataFileURL.lastPathComponent)")
            
            // 4. 保存状态标记
            let statusFileURL = sharedDataDir.appendingPathComponent("import_status.plist")
            let statusData: [String: Any] = [
                "status": "pending",
                "fileCount": filesInfo.count,
                "timestamp": Date().timeIntervalSince1970,
                "source": "ShareExtension"
            ]
            let statusPlistData = try PropertyListSerialization.data(fromPropertyList: statusData, format: .xml, options: 0)
            try statusPlistData.write(to: statusFileURL)
            print("✅ 状态文件保存成功")
            
            // 5. 验证所有文件都已写入
            let fileManager = FileManager.default
            let dataExists = fileManager.fileExists(atPath: dataFileURL.path)
            let statusExists = fileManager.fileExists(atPath: statusFileURL.path)
            
            print("🔍 存储验证:")
            print("   - 数据文件存在: \(dataExists)")
            print("   - 状态文件存在: \(statusExists)")
            
            if dataExists && statusExists {
                // 6. 列出目录内容确认
                let contents = try fileManager.contentsOfDirectory(atPath: sharedDataDir.path)
                print("📁 共享目录内容: \(contents)")
                
                // 7. 读取并验证数据完整性
                if let verifiedData = try? Data(contentsOf: dataFileURL),
                   let verifiedJSON = try? JSONSerialization.jsonObject(with: verifiedData) as? [[String: Any]] {
                    print("✅ 数据完整性验证成功: \(verifiedJSON.count) 个文件")
                    return true
                }
            }
            
            return false
            
        } catch {
            print("❌ 文件存储过程中出错: \(error.localizedDescription)")
            return false
        }
    }
    
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

    @IBAction func send(_ sender: AnyObject?) {
        let outputItem = NSExtensionItem()
        // Complete implementation by setting the appropriate value on the output item
    
        let outputItems = [outputItem]
        print("用户点击发送")
        
        // 保存文件到 App Group
        saveFilesToAppGroup(fileURLs)
        
        // 使用 URL Scheme 打开主应用（无需自动化权限！）
        openMainAppWithURLScheme()
        
        // 延迟关闭扩展，给应用时间启动
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
}
    
    private func openMainAppWithURLScheme() {
        // 使用自定义 URL Scheme 打开应用（不需要自动化权限）
//        let urlString = macShareUrlSchemes
//        guard let url = URL(string: urlString) else {
//            print("错误: URL 格式不正确")
//            return
//        }
        
        var components = URLComponents()
        components.scheme = macShareUrlSchemes  // 替换为你的应用Scheme
        components.host = macShareHost
        guard let appURL = components.url else { 
            print("错误: URL 格式不正确")
            return
        }
        print("使用 URL Scheme 打开应用: \(appURL)")
        
        // 使用 NSWorkspace.shared.open(url) 打开 URL Scheme
        // 这个方法不需要自动化权限！
//        NSWorkspace.shared.open(url)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        
        NSWorkspace.shared.open(appURL, configuration: configuration) { (app, error) in
            if let error = error {
                print("打开应用失败: \(error.localizedDescription)")
            } else {
                print("✅ 已成功发送打开请求")
            }
        }
        
        print("✅ 已发送打开请求")
    }
    @IBAction func cancel(_ sender: AnyObject?) {
        print("用户取消")
        let cancelError = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil)
        self.extensionContext!.cancelRequest(withError: cancelError)
    }

}

extension ShareViewController {
    
    func isFromSystemPhotoLibrary(_ url: URL) -> Bool {
        guard url.isFileURL else { return false }
        
        let path = url.path
        // 检查系统相库路径
        let photoLibraryPaths = [
            "/Users/\(NSUserName())/Pictures/Photos Library.photoslibrary",
            "/var/folders",// 临时文件路径也可能包含相册图片
            "/com.apple.Photos"
        ]
        
        return photoLibraryPaths.contains { path.contains($0) }
    }    
    func getTemporaryPathWithUUID(from asset: PHAsset, completion: @escaping (URL?, String) -> Void) {
        let options = PHContentEditingInputRequestOptions()
        options.canHandleAdjustmentData = { _ in return true }
        
        asset.requestContentEditingInput(with: options) { contentEditingInput, info in
            guard let input = contentEditingInput,
                  let fullSizeImageURL = input.fullSizeImageURL else {
                completion(nil, asset.localIdentifier)
                return
            }
            
            // 直接使用原始文件路径，避免复制
            completion(fullSizeImageURL, asset.localIdentifier)
        }
    }
    func extractUUIDFromPath(_ path: String) -> String? {
        // 从路径中提取 UUID 模式
        // 提取UUID部分
        if path.contains("ShareKit-Exports") {
            let components = path.split(separator: "/")
            guard components.count >= 4 else { return nil }
            // 提取UUID部分
            let shareExportIndex = components.firstIndex(of: "ShareKit-Exports")
            guard let startIndex = shareExportIndex, components.count > startIndex + 2 else { return nil }
            
            return String(components[startIndex + 2])
        }else{
            let uuidPattern = "[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}"
            
            if let range = path.range(of: uuidPattern, options: .regularExpression) {
                print("找到uuid====\(String(path[range]))")
                return String(path[range])
            }
        }        
        print("没找到uuid====")
        return nil
    }
    func fetchPhotoAsset(_ uuid: String) -> PHAsset? {
        // 使用提取的UUID查找照片资产
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [uuid], options: nil)
        
        if let asset = fetchResult.firstObject {
            return asset
        }
        
        return nil
    }
    
    /// 判断文件是否来自macOS截屏/录屏的临时文件
    func isScreenCaptureTempFile(_ filePath: String) -> Bool {
        // 1. 快速路径检查
        if !filePath.contains("/var/folders/") || !filePath.contains("/T/") {
            return false
        }
        
        let url = URL(fileURLWithPath: filePath)
        let fileName = url.lastPathComponent
        
        // 2. 检查扩展名
        let fileExtension = url.pathExtension.lowercased()
        let validExtensions = ["png", "jpg", "jpeg", "heic", "mov", "mp4", "m4v"]
        guard validExtensions.contains(fileExtension) else {
            return false
        }
        
        // 3. 检查文件名是否包含截屏关键词（放松条件）
        let screenCaptureKeywords = ["屏幕快照", "Screen Shot", "Screenshot", "截屏", "录屏", "屏幕录制", "Recording", "Screen Recording"]
        let hasScreenCaptureKeyword = screenCaptureKeywords.contains { fileName.contains($0) }
        
        // 4. 检查macOS截屏特有的时间戳格式（修复版）
        // 支持多种格式：
        // 英文：Screen Shot 2025-12-22 at 9.44.14 AM.png
        // 中文：录屏2025-12-22 上午9.53.17.mov
        // 中文：屏幕快照 2025-12-22 上午9.53.17.png
        
        let timestampPatterns = [
            // 英文格式：YYYY-MM-DD at HH.MM.SS [AM|PM]
            "\\d{4}-\\d{2}-\\d{2} at \\d{1,2}\\.\\d{2}\\.\\d{2} (AM|PM|am|pm)",
            
            // 中文格式：YYYY-MM-DD 上午/下午 HH.MM.SS
            "\\d{4}-\\d{2}-\\d{2} [上下]午\\d{1,2}\\.\\d{2}\\.\\d{2}",
            
            // 简化的时间戳：确保至少有日期和时分秒
            "\\d{4}-\\d{2}-\\d{2}.*\\d{1,2}[\\.,:]\\d{2}[\\.,:]\\d{2}"
        ]
        
        let hasMacOSTimestamp = timestampPatterns.contains { pattern in
            fileName.range(of: pattern, options: .regularExpression) != nil
        }
        
        // 5. 判断逻辑（更宽松）
        // 条件1：必须有有效的扩展名
        // 条件2：必须有截屏关键词或时间戳格式（满足其一即可）
        print("hasScreenCaptureKeyword ==\(hasScreenCaptureKeyword),hasMacOSTimestamp===\(hasMacOSTimestamp)")
        return hasScreenCaptureKeyword || hasMacOSTimestamp
    }
}


import Foundation

class iCloudFileUtility {
    // MARK: 检查文件是否是本地可访问的
    /// 判断文件是否为照片库占位符或衍生文件（主要检查方法）
    static func isPhotoLibraryPlaceholder(at url: URL) -> Bool {
//        print("🔍 检查文件: \(url.lastPathComponent)")
//        let path = url.path.lowercased()
//        // 关键检查：是否在照片库包内
//        // 关键检查：是否在照片库包内
//        guard path.contains(".photoslibrary") else {
//            return false
//        }
//        
//        if path.contains(".AddressBook")  {
//            return false
//        }
        
        
        
        // 1. 快速路径检查（最快排除）
        if isInternalPhotoLibraryFile(at: url) {
            print("❌ 路径特征: 位于照片库内部目录")
            return true
        }
        
        
        // 2. 文件属性检查
        let propertyCheck = checkFileProperties(at: url)
        if propertyCheck.isPlaceholder {
            print("❌ 文件属性: \(propertyCheck.reason)")
            return true
        }
        
        let path = url.path.lowercased()
        // 关键检查：是否在照片库包内
        if path.contains(".photoslibrary") {
            // 3. 尝试加载验证（最终确认）
            let loadCheck = attemptToLoadImage(at: url)
            if !loadCheck.isValid {
                print("❌ 加载失败: \(loadCheck.reason)")
                return true
            }
        }else {
            return false
        }
        
        
        print("✅ 文件似乎是可用的原始图片")
        return false
    }
    /// 1. 路径特征检查 - 这是最快最直接的方法
    private static func isInternalPhotoLibraryFile(at url: URL) -> Bool {
        let path = url.path.lowercased()
        
        // 关键检查：是否在照片库包内
        guard path.contains(".photoslibrary") else {
            return false
        }
        
        if path.contains(".AddressBook")  {
            return false
        }
        
        // 检查是否在特定的内部目录中
        let internalDirectories = [
            "/resources/proxies/",      // 代理文件
            "/masters/",                // 主文件目录
            "/private/",                // 私有数据
            "/thumbnails/",             // 缩略图
            "/renders/",                // 渲染文件
            "/caches/"                  // 缓存
        ]
        
        return internalDirectories.contains { path.contains($0) }
    }
    /// 2. 文件属性检查
    private static func checkFileProperties(at url: URL) -> (isPlaceholder: Bool, reason: String) {
        do {
            let resourceValues = try url.resourceValues(forKeys: [
                .fileSizeKey,
                .typeIdentifierKey,
                .isRegularFileKey,
                .isSymbolicLinkKey
            ])
            
            // 检查文件大小（占位符通常很小）
            if let size = resourceValues.fileSize {
                if size == 0 {
                    return (true, "文件大小为0字节")
                } 
//                else if size < 2048 { // 小于2KB
//                    return (true, "文件过小 (\(size) 字节)")
//                }
                print("📊 文件大小: \(size) 字节")
            }
            
            // 检查文件类型标识
            if let type = resourceValues.typeIdentifier {
                print("📄 文件类型: \(type)")
                
                // 系统明确标记的类型
                if type == "com.apple.photo.placeholder" {
                    return (true, "系统标识为照片占位符")
                }
                if type == "com.apple.icloud.file-icon" {
                    return (true, "iCloud占位符")
                }
                if type == "com.apple.directory" {
                    return (true, "这是一个目录而非文件")
                }
            }
            
            // 检查是否为符号链接
            if let isSymbolicLink = resourceValues.isSymbolicLink, isSymbolicLink {
                if let destination = try? FileManager.default.destinationOfSymbolicLink(atPath: url.path) {
                    return (true, "符号链接，指向: \(destination)")
                }
                return (true, "这是一个符号链接")
            }
            
            return (false, "文件属性正常")
            
        } catch {
            // 如果无法读取属性，很可能是受保护文件
            return (true, "无法读取文件属性: \(error.localizedDescription)")
        }
    }
    /// 3. 尝试加载图像数据
    private static func attemptToLoadImage(at url: URL) -> (isValid: Bool, reason: String, image: NSImage?) {
        // 尝试直接加载图片
        guard let image = NSImage(contentsOf: url) else {
            return (false, "无法加载图片数据", nil)
        }
        
        // 检查图片是否有效
        guard image.isValid else {
            return (false, "图片对象无效", image)
        }
        
        // 检查图片尺寸（预览图标通常很小）
        let size = image.size
        print("📐 图片尺寸: \(Int(size.width))×\(Int(size.height)) 像素")
        
        if size.width < 50 || size.height < 50 {
            return (false, "尺寸过小，可能只是预览图标", image)
        }
        
        // 尝试获取图像数据
        guard let tiffData = image.tiffRepresentation else {
            return (false, "无法生成TIFF数据", image)
        }
        
        guard let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return (false, "无法创建位图表示", image)
        }
        
        // 检查实际数据大小
        let actualSize = bitmapRep.size
        print("🎯 实际位图尺寸: \(Int(actualSize.width))×\(Int(actualSize.height))")
        
        return (true, "成功加载有效图片", image)
    }
}


//
//  MIDocumentPickerManager.swift
//  MutualInfectionApp
//
//  Created by delegate on 2025/9/19.
//

import UIKit
import MobileCoreServices

class MIDocumentPickerManager: NSObject {
    /// 点击完成后回调
    public typealias CompletionHandler = (_ result: [FileModel]?, _ documentVC: MIDocumentPickerViewController?) -> Void
    // 完成回调
    private var completionHandler: CompletionHandler?
    
    private var documentPicker: MIDocumentPickerViewController?
    
    private var fileModelArr = [FileModel]()
    static let share = MIDocumentPickerManager()
    
    private override init() { super.init() }
    
    func openDocumentPicker(completionHandler: @escaping CompletionHandler) {
        self.completionHandler = completionHandler
        let topVC = UIViewController.topViewController
        if #available(iOS 14, *) {
            documentPicker = MIDocumentPickerViewController(forOpeningContentTypes: [.item])
        } else {
            let allTypes = [kUTTypeItem as String]
            documentPicker = MIDocumentPickerViewController( documentTypes: allTypes, in: .import)
        }
        documentPicker?.delegate = self
        documentPicker?.allowsMultipleSelection = true
//        let navi = MIBaseNavigationViewController(rootViewController: documentPicker!)
//        navi.modalPresentationStyle = .overCurrentContext
//        navi.modalPresentationStyle = .fullScreen
        if UIDevice.current.userInterfaceIdiom == .pad {
            documentPicker?.modalPresentationStyle = .pageSheet // 或 .pageSheet

            if let popover = documentPicker?.popoverPresentationController, let topVC = topVC {
                popover.sourceView = topVC.view
                popover.sourceRect = CGRect(
                    x: topVC.view.bounds.midX,
                    y: topVC.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                popover.permittedArrowDirections = []
                popover.canOverlapSourceViewRect = true
            }
        } else {
            documentPicker?.modalPresentationStyle = .fullScreen
        }
        
        topVC?.present(documentPicker!, animated: true)
    }
}
extension MIDocumentPickerManager: UIDocumentPickerDelegate {
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        completionHandler?(nil, documentPicker)
        print("documentPickerWasCancelled")
    }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        print("urls - \(urls)")
        self.fileModelArr.removeAll()
        let totalCount = urls.count // 总文件数
        var completedCount = 0 // 已完成解析的文件数
        
        for fileUrl in urls {
            getSecureFileProperties(for: fileUrl) { [weak self] in
                completedCount += 1
                // 所有文件解析完成后，再回调
                if completedCount == totalCount {
                    self?.completionHandler?(self?.fileModelArr, self?.documentPicker)
                }
            }
        }
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        print("url - \(url)")
    }
    
    private func getSecureFileProperties(for url: URL, completion: @escaping () -> Void) {
        guard url.startAccessingSecurityScopedResource() else {
            print("无法获取文件权限")
            completion() // 即使失败，也要计数
            return
        }
        
        defer { url.stopAccessingSecurityScopedResource() }
        
        guard let sandboxURL = copyFileToSandbox(sourceURL: url) else {
            print("文件转存沙盒失败")
            completion()
            return
        }
        
        let fileCoordinator = NSFileCoordinator()
        let errorPointer: NSErrorPointer = nil
        
        fileCoordinator.coordinate(readingItemAt: sandboxURL, options: .withoutChanges, error: errorPointer) { (secureURL) in
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: secureURL.path)
                self.parseFileAttributes(attributes, url: secureURL)
            } catch {
                print("获取属性失败: \(error)")
            }
            completion() // 解析完成，触发计数
        }
    }
    
    // 复制文件到应用沙盒的Documents目录
    private func copyFileToSandbox(sourceURL: URL) -> URL? {
        do {
            // 1. 获取应用沙盒Documents目录路径
            let documentsDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            // 2. 目标路径（保留原文件名）
            let destinationURL = documentsDirectory.appendingPathComponent(sourceURL.lastPathComponent)
            
            // 3. 若文件已存在，先删除（或根据需求处理，如跳过）
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try? FileManager.default.removeItem(at: destinationURL)
            }
            /*
            // 4. 使用文件协调器安全复制（避免文件冲突）
            let fileCoordinator = NSFileCoordinator()
            var error: NSError?
            fileCoordinator.coordinate(
                writingItemAt: sourceURL,
                options: .forMoving,
                writingItemAt: destinationURL,
                options: .forReplacing,
                error: &error
            ) { (source, destination) in
                do {
                    try FileManager.default.copyItem(at: source, to: destination)
                } catch {
                    print("文件复制失败: \(error.localizedDescription)")
                }
            }
            
            if let error = error {
                print("协调复制失败: \(error.localizedDescription)")
                return nil
            }
            */
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            
            // 校验文件大小，确保复制有效
            let attributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
            guard let size = attributes[.size] as? Int64, size > 0 else {
                print("复制的文件为空")
                try FileManager.default.removeItem(at: destinationURL) // 删除空文件
                return nil
            }
            
            print("文件已复制到沙盒: \(destinationURL.path)")
            return destinationURL
        } catch {
            print("沙盒路径处理失败: \(error.localizedDescription)")
            return nil
        }
    }
    // 解析并打印文件属性
    private func parseFileAttributes(_ attributes: [FileAttributeKey: Any], url: URL) {
        
        var fileModel = FileModel()
        
        // 文件名
        let fileName = url.lastPathComponent
        print("文件名: \(fileName)")
        fileModel.name = fileName
        
        // 文件大小
        if let size = attributes[.size] as? Int64 {
            let sizeMB = Double(size) / (1024 * 1024)
            print("大小: \(size) 字节 (\(String(format: "%.2f", sizeMB)) MB)")
            fileModel.size = formatFileSize(byteSize: size)
            fileModel.sizeInBytes = size
        }
        
        // 创建日期
        if let createDate = attributes[.creationDate] as? Date {
            print("创建日期: \(formatDate(createDate))")
            fileModel.creationDate = createDate
        }
        
        // 修改日期
        if let modifyDate = attributes[.modificationDate] as? Date {
            print("修改日期: \(formatDate(modifyDate))")
            fileModel.modificationDate = modifyDate
        }
        
        // 文件类型（UTI）
        if let fileType = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier {
            print("文件类型(UTI): \(fileType)")
            fileModel.type = fileType
        }
        
        // 文件路径（沙盒内的安全路径）
        fileModel.url = url
        print("安全路径: \(url.path)")
        
        // 判断是否为媒体类型
        fileModel.isMediaType = isMediaType(fileURL: url)
        fileModel.isImageType = isMediaImageType(fileURL: url)
        fileModel.isVideoType = isMediaVideoType(fileURL: url)
        
        fileModelArr.append(fileModel)
    }
    
    // 日期格式化
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
    
    /// 判断文件是否为媒体图片类型
    /// - Parameter fileURL: 选中文件的本地URL
    /// - Returns: 是否为媒体图片类型
    func isMediaImageType(fileURL: URL) -> Bool {
        guard let fileUTI = try? fileURL.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier else {
            return false
        }
        let mediaTypeUTIs: [CFString] = [
            kUTTypeImage,
            kUTTypeLivePhoto // 添加 Live Photo 类型标识
        ]
        return mediaTypeUTIs.contains { mediaUTI in
            UTTypeConformsTo(fileUTI as CFString, mediaUTI)
        }
    }
    /// 判断文件是否为媒体视频类型
    /// - Parameter fileURL: 选中文件的本地URL
    /// - Returns: 是否为媒体视频类型
    func isMediaVideoType(fileURL: URL) -> Bool {
        guard let fileUTI = try? fileURL.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier else {
            return false
        }
        let mediaTypeUTIs: [CFString] = [ kUTTypeMovie ]
        return mediaTypeUTIs.contains { mediaUTI in
            UTTypeConformsTo(fileUTI as CFString, mediaUTI)
        }
    }
    /// 判断文件是否为媒体类型（图片、音频、视频）
    /// - Parameter fileURL: 选中文件的本地URL
    /// - Returns: 是否为媒体类型
    func isMediaType(fileURL: URL) -> Bool {
        // 1. 获取文件的UTI（类型标识符）
        guard let fileUTI = try? fileURL.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier else {
            return false // 无法获取UTI，视为非媒体文件
        }
        // 2. 定义需要判断的媒体类型UTI（通用类型，涵盖所有子类型）
        let mediaTypeUTIs: [CFString] = [
            kUTTypeImage,    // 图片类型（如JPEG、PNG等）
            kUTTypeAudio,    // 音频类型（如MP3、AAC等）
            kUTTypeMovie     // 视频类型（如MP4、MOV等）
        ]
        // 3. 检查文件UTI是否符合任一媒体类型
        return mediaTypeUTIs.contains { mediaUTI in
            UTTypeConformsTo(fileUTI as CFString, mediaUTI)
        }
    }
}




///// 文件选择相关
//extension MIHuaweiShareViewController: UIDocumentPickerDelegate {
//    private func presentCustomDocumentPicker() {
//        let documentPicker: UIDocumentPickerViewController
//        if #available(iOS 14, *) {
//            documentPicker = UIDocumentPickerViewController(
//                forOpeningContentTypes: [.item]
//            )
//        } else {
//            let allTypes = [kUTTypeItem as String]
//            documentPicker = UIDocumentPickerViewController(
//                documentTypes: allTypes,
//                in: .import
//            )
//        }
//        documentPicker.delegate = self
//        documentPicker.allowsMultipleSelection = true
//        present(documentPicker, animated: true)
//    }
//    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
//        
//        self.showActionAlertSheet(sender: self.sendButton)
//        
//        
//        print("documentPickerWasCancelled")
//    }
//    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
//        
//        print("urls - \(urls)")
//        
//        for fileUrl in urls {
//            
//            getSecureFileProperties(for: fileUrl)
//            
//        }
//        
//        fileType = 3
//        nav = self.navigationController
//        
//        self.sendContentToDevice()
//        
//        
//    }
//    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
//        print("url - \(url)")
//    }
//    
//    // 通过文件协调器安全获取文件属性
//    private func getSecureFileProperties(for url: URL) {
//        // 1. 检查是否需要访问安全范围的资源
//        if url.startAccessingSecurityScopedResource() {
//            let fileCoordinator = NSFileCoordinator()
//            let errorPointer: NSErrorPointer = nil
//            fileArr.removeAll()
//            // 2. 使用文件协调器访问文件
//            fileCoordinator.coordinate(readingItemAt: url, options: .withoutChanges, error: errorPointer) { (secureURL) in
//                do {
//                    // 3. 从安全 URL 获取属性
//                    let attributes = try FileManager.default.attributesOfItem(atPath: secureURL.path)
//                    self.parseFileAttributes(attributes, url: secureURL)
//                } catch {
//                    print("获取属性失败: \(error.localizedDescription)")
//                }
//            }
//            
//            // 4. 停止访问安全资源（必须调用）
//            url.stopAccessingSecurityScopedResource()
//            
//            // 处理协调器错误
//            if let error = errorPointer?.pointee {
//                print("文件协调失败: \(error.localizedDescription)")
//            }
//        } else {
//            print("无法访问安全范围的文件资源")
//        }
//    }
//    
//    // 解析并打印文件属性
//    private func parseFileAttributes(_ attributes: [FileAttributeKey: Any], url: URL) {
//        var fileModel = FileModel()
//        // 文件名
//        let fileName = url.lastPathComponent
//        print("文件名: \(fileName)")
//        fileModel.name = fileName
//        
//        // 文件大小
//        if let size = attributes[.size] as? Int64 {
//            let sizeMB = Double(size) / (1024 * 1024)
//            print("大小: \(size) 字节 (\(String(format: "%.2f", sizeMB)) MB)")
//            fileModel.size = formatFileSize(bytes: size)
//            fileModel.sizeInBytes = size
//        }
//        
//        // 创建日期
//        if let createDate = attributes[.creationDate] as? Date {
//            print("创建日期: \(formatDate(createDate))")
//            fileModel.creationDate = createDate
//        }
//        
//        // 修改日期
//        if let modifyDate = attributes[.modificationDate] as? Date {
//            print("修改日期: \(formatDate(modifyDate))")
//            fileModel.modificationDate = modifyDate
//        }
//        
//        // 文件类型（UTI）
//        if let fileType = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier {
//            print("文件类型(UTI): \(fileType)")
//            fileModel.type = fileType
//        }
//        fileModel.url = url
//        // 文件路径（沙盒内的安全路径）
//        print("安全路径: \(url.path)")
//        
//        fileArr.append(fileModel)
//    }
//    
//    // 日期格式化
//    private func formatDate(_ date: Date) -> String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
//        formatter.locale = Locale.current
//        return formatter.string(from: date)
//    }
//}

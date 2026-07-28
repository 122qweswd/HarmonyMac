//
//  MICustomImageView.swift
//  MutualInfectionMac
//
//  Created by delegate on 2025/10/21.
//

import AppKit
import AVFoundation
import Photos

var globalDragEnabled = true
class MICustomImageView: NSImageView {
    var dragOperationBlock: (([URL]) -> Void)?
    var allFileURLs: [URL] = []
    var dropDestinationURL: URL = URL(fileURLWithPath: NSTemporaryDirectory())
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        // 注册支持的拖拽类型
        self.registerForDraggedTypes([
            .fileURL,
            NSPasteboard.PasteboardType(rawValue: "com.apple.pasteboard.promised-file-url")
        ])
    }
    
    // 实现 NSDraggingDestination 协议
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if !globalDragEnabled {
            return []
        }
        let pasteboard = sender.draggingPasteboard
        
        // 检查是否包含文件或文件承诺
        if pasteboard.canReadObject(forClasses: [NSURL.self, NSFilePromiseReceiver.self], options: nil) {
            return .copy
        }
        
        return []
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if !globalDragEnabled {
            return false
        }
        let pasteboard = sender.draggingPasteboard
        
        // 处理文件承诺
//        if pasteboard.canReadObject(forClasses: [NSFilePromiseReceiver.self], options: nil) {
//            return handleFilePromises(from: pasteboard)
//        }
        
        // 处理普通文件
        return handleRegularFiles(from: pasteboard)
    }
    // 处理文件承诺
    private func handleFilePromises(from pasteboard: NSPasteboard) -> Bool {
        // 创建唯一的目标目录
        let promiseDir = dropDestinationURL.appendingPathComponent(UUID().uuidString)
        
        if let objects = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil) {
            guard let receivers = objects as? [NSFilePromiseReceiver] else {
                ShareAPI.shared().log(1, "未找到文件承诺接收器")
                dragOperationBlock?([])
                return false
            }
            
            ShareAPI.shared().log(1, "找到 \(receivers.count) 个文件承诺")
            allFileURLs = []
            let group = DispatchGroup()
            for (index, receiver) in receivers.enumerated() {
                ShareAPI.shared().log(1, "处理文件承诺 \(index + 1):")
                ShareAPI.shared().log(1, "  支持类型: \(receiver.fileTypes.joined(separator: ", "))")
                
                group.enter()
                self.fulfillFilePromise(receiver, at: promiseDir) { [weak self] fileURL in
                    if let fileURL = fileURL {
                        self?.allFileURLs.append(fileURL)
                    }
                    group.leave()
                }
            }
            
            // 设置组完成回调
            group.notify(queue: .main) { [weak self] in
                self?.dragOperationBlock?(self?.allFileURLs ?? [])
            }
        } else {
            dragOperationBlock?([])
        }
        return true
    }
    
    private func handleRegularFiles(from pasteboard: NSPasteboard) -> Bool {
        allFileURLs = []
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in fileURLs {
                ShareAPI.shared().log(1, "普通文件:\(url.lastPathComponent)")
                ShareAPI.shared().log(1, "路径: \(url.path)")
                if iCloudFileUtility.isPhotoLibraryPlaceholder(at: url) {
                
                    let alert = NSAlert()
                    alert.informativeText = "非本地文件，请先存到本地后再重试".localized
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "我知道了".localized)
                    alert.runModal()
                    return false
                }
            }
            if fileURLs.count > 0 {
                dragOperationBlock?(fileURLs)
            }else{
                let alert = NSAlert()
                alert.informativeText = "一次最多只能拖拽100个，超出数量将无法捕获拖拽内容".localized
                alert.alertStyle = .warning
                alert.addButton(withTitle: "确定".localized)
                alert.runModal()
            }
            
            return !fileURLs.isEmpty
        }
        dragOperationBlock?([])
        return false
    }
}

extension MICustomImageView {
    private func fulfillFilePromise(_ receiver: NSFilePromiseReceiver, at destinationDir: URL, completeBlock: @escaping  ((URL?) -> Void)) {
        do {
            try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)
        } catch {
            ShareAPI.shared().log(1, "创建目标目录失败: \(error)")
            completeBlock(nil)
            return
        }
        
        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated
        receiver.receivePromisedFiles(atDestination: destinationDir, options: [:], operationQueue: operationQueue) { (fileURL, error) in
            DispatchQueue.main.async {
                if let error = error {
                    ShareAPI.shared().log(1, "文件承诺履行失败: \(error)")
                    completeBlock(nil)
                } else {
                    ShareAPI.shared().log(1, "✅ 文件承诺履行成功!")
                    ShareAPI.shared().log(1, "   文件名: \(fileURL.lastPathComponent)")
                    ShareAPI.shared().log(1, "   完整路径: \(fileURL.path)")
                    completeBlock(fileURL)
                }
            }
        }
    }
}

/*
class MICustomImageView: NSImageView {
    
    var dragOperationBlock: (([URL]) -> Void)?
    
    open override func viewDidMoveToWindow() {
        
        registerForDraggedTypes([.fileURL])
        
    }
    // 拖拽进入视图时触发：判断是否接受拖拽
    open override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        // 检查拖拽内容是否包含文件URL
        if sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: nil) {
            return .copy // 接受“复制”操作（表示允许拖拽）
        }
        return [] // 不接受拖拽
    }
    
    // 拖拽在视图内释放时触发：处理文件
    open override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        
        // 检查是否是从照片App拖拽的资源
        var isFromPhotoApp = false
        if let types = pasteboard.types {
            isFromPhotoApp = types.contains { type in
                let typeString = type.rawValue
                return typeString.contains("com.apple.photos.object-reference.asset") ||
                       typeString.contains("PHObjectReferenceCookieType")
            }
            print("照片应用资源检测结果：\(isFromPhotoApp)")
        }
        
        // 检查是否有文件承诺类型
        let hasFilePromiseType = pasteboard.availableType(from: [
            NSPasteboard.PasteboardType(rawValue: "com.apple.pasteboard.promised-file-url"),
            NSPasteboard.PasteboardType(rawValue: "com.apple.pasteboard.promised-file-name")
        ]) != nil
        print("文件承诺类型检测结果：\(hasFilePromiseType)")
        
        // 对于照片App资源，使用特殊处理
        if isFromPhotoApp {
            print("使用照片应用资源特殊处理流程")
            
            // 创建一个临时目录来接收照片应用导出的文件
            // 使用UUID创建唯一的临时目录，避免权限冲突
            let tempDir = NSTemporaryDirectory() + "PhotoAppImport_" + UUID().uuidString + "/"
            do {
                // 先检查目录是否存在，如果存在则清理其中的旧文件
                if FileManager.default.fileExists(atPath: tempDir) {
                    try FileManager.default.removeItem(atPath: tempDir)
                    print("已清理旧临时目录：\(tempDir)")
                }
                
                // 确保目录存在并设置适当的权限
                try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true, attributes: [
                    .posixPermissions: 0o755 // 设置权限为rwxr-xr-x
                ])
                print("创建临时目录：\(tempDir)，权限已设置为0o755")
                
                // 处理文件承诺操作
                // 创建数组收集所有处理好的文件URL
                var allFileURLs: [URL] = []
                
                // 获取拖拽项目总数
                let draggingItemsCount = sender.draggingPasteboard.pasteboardItems?.count ?? 0
                var processedItemsCount = 0
                
                // 注意：namesOfPromisedFilesDropped只需要调用一次，用于整个拖拽操作
                // 为整个拖拽操作指定主临时目录
                sender.namesOfPromisedFilesDropped(atDestination: URL(fileURLWithPath: tempDir))
                print("为整个拖拽操作注册文件接收目录：\(tempDir)")
                
                sender.enumerateDraggingItems(options: [], for: nil, classes: [NSPasteboardItem.self], searchOptions: [:]) { item, _, _ in
                    guard let pasteboardItem = item.item as? NSPasteboardItem else {
                        // 处理失败，增加计数
                        processedItemsCount += 1
                        return
                    }
                    
                    // 获取承诺的文件名
                    let fileNameType = NSPasteboard.PasteboardType(rawValue: "com.apple.pasteboard.promised-file-name")
                    if let fileNameData = pasteboardItem.data(forType: fileNameType),
                       let fileName = String(data: fileNameData, encoding: .utf8) {
                        // 注意：此时从承诺机制获取的文件名可能包含URL编码字符（如%20代表空格）
                        // 对文件名进行URL解码，去除可能的编码字符
                        let decodedFileName = (fileName as NSString).removingPercentEncoding ?? fileName
                        var finalFileName = URL(fileURLWithPath: decodedFileName)
                        // 过滤文件名末尾的"%202"或" 2"模式
                        if let url = URL(string: fileName) {
                            let fileName = url.lastPathComponent
                            // 使用 NSString 的方法去除扩展名
                            let fileNameWithoutExtension = (fileName as NSString).deletingPathExtension
                            print("fileNameWithoutExtension : \(fileNameWithoutExtension)") // 输出: "nature_shot_photo 2"
                            var testExtension = ""
                            if fileNameWithoutExtension.contains("%202") {
                                // 移除末尾的"%202"
                                testExtension = fileNameWithoutExtension.replacingOccurrences(of: "%202", with: "")
                                
                                
                            } else if fileNameWithoutExtension.contains(" 2") {
                                testExtension = fileNameWithoutExtension.replacingOccurrences(of: " 2", with: "")
                                
                            }
                            
                            if testExtension.contains("%20") {
                                let filePath = URL(fileURLWithPath: tempDir + testExtension.replacingOccurrences(of: "%20", with: " ") + "." + (decodedFileName.components(separatedBy: ".").last ?? ""))
                                finalFileName = filePath
                            } else {
                                let filePath = URL(fileURLWithPath: tempDir + testExtension + "." + (decodedFileName.components(separatedBy: ".").last ?? ""))
                                finalFileName = filePath
                            }
                            
                            
                        }
                        
                        print("原始承诺文件名：\(fileName)")
                        print("解码后文件名：\(decodedFileName)")
                        print("过滤后文件名：\(finalFileName)")
                        let fileURL = finalFileName
                        if !allFileURLs.contains(fileURL) {
                            allFileURLs.append(fileURL)
                        }
                        
                        // 确保临时目录的权限正确设置
                        do {
                            try FileManager.default.setAttributes([
                                .posixPermissions: 0o755 // 确保权限为rwxr-xr-x
                            ], ofItemAtPath: tempDir)
                        } catch {
                            print("设置临时目录权限失败：\(error)")
                        }
                        
                        // 不再为每个项创建独立子目录，而是直接使用主临时目录
                        // 我们将通过监控整个目录来获取所有导出的文件
                        
                        // 注意：不再为每个项目单独创建重试函数，而是使用统一的监控机制
                        // 在循环外部使用定时器监控整个目录
                        // 这里只增加处理计数，实际文件收集由外部统一处理
                        processedItemsCount += 1
                        print("已处理\(processedItemsCount)/\(draggingItemsCount)个项目")
                    } else {
                        // 无法获取文件名，增加计数
                        processedItemsCount += 1
                    }
                    
                }
                
                
                
                // 创建统一的目录监控函数
                func monitorTempDirectory(retryCount: Int = 0) {
                    let maxRetries = 8 // 增加重试次数
                    let retryDelay: TimeInterval = retryCount < 3 ? 1.0 : 2.0 // 前3次快速重试，之后延迟增加
                    
                    do {
                        // 检查主临时目录中的所有文件
                        let directoryContents = try FileManager.default.contentsOfDirectory(atPath: tempDir)
                        
                        // 收集所有尚未添加的文件
                        var newlyAddedFiles = 0
                        for fileName in directoryContents {
                            let fileURL = URL(fileURLWithPath: tempDir + fileName)
                            if !allFileURLs.contains(fileURL) && allFileURLs.count < processedItemsCount {
                                allFileURLs.append(fileURL)
                                newlyAddedFiles += 1
                                print("找到新导出文件：\(fileName)")
                            }
                        }
                        
                        // 检查是否所有预期的文件都已导出或达到重试上限
                        if retryCount >= maxRetries {
                            print("达到最大重试次数\(maxRetries)，结束监控")
                            if !allFileURLs.isEmpty {
                                print("监控结束，共找到\(allFileURLs.count)个文件")
                                self.dragOperationBlock?(allFileURLs)
                            } else {
                                print("监控结束，但未找到任何文件，尝试备用方案")
                                // 备用方案：直接从粘贴板读取文件URL
//                                if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
//                                   !fileURLs.isEmpty {
//                                    print("备用方案：直接从粘贴板读取到\(fileURLs.count)个文件URL")
//                                    self.dragOperationBlock?(fileURLs)
//                                }
                                print("当前的url数组：\(allFileURLs)")
                                self.dragOperationBlock?(allFileURLs)
                            }
                        } else if allFileURLs.count >= draggingItemsCount {
                            // 如果有新文件添加，或者文件数量已达到拖拽项目数量
                            print("发现\(newlyAddedFiles)个新文件，当前累计\(allFileURLs.count)个文件")
                            
                            if allFileURLs.count >= draggingItemsCount {
                                // 文件数量已达到或超过拖拽项目数量，认为导出完成
                                print("文件数量已达到拖拽项目数量，导出完成")
                                self.dragOperationBlock?(allFileURLs)
                            } else {
                                // 继续监控，可能还有文件在导出中
                                print("继续监控目录，等待更多文件导出，重试次数：\(retryCount + 1)")
                                DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) {
                                    monitorTempDirectory(retryCount: retryCount + 1)
                                }
                            }
                        } else {
                            // 没有新文件，但还没达到最大重试次数，继续监控
                            print("未发现新文件，继续监控，重试次数：\(retryCount + 1)")
                            DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) {
                                monitorTempDirectory(retryCount: retryCount + 1)
                            }
                        }
                    } catch {
                        print("读取目录内容失败：\(error)")
                        
                        // 出错时继续重试，直到达到最大次数
                        if retryCount < maxRetries {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                monitorTempDirectory(retryCount: retryCount + 1)
                            }
                        } else {
                            // 达到最大重试次数且出错，尝试备用方案
                            print("监控出错且达到最大重试次数，尝试备用方案")
//                            if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
//                               !fileURLs.isEmpty {
//                                print("备用方案：直接从粘贴板读取到\(fileURLs.count)个文件URL")
//                                self.dragOperationBlock?(fileURLs)
//                            }
                            print("当前的url数组：\(allFileURLs)")
                            self.dragOperationBlock?(allFileURLs)
                        }
                    }
                }
                
                // 启动目录监控，延迟1秒开始以确保文件有时间开始导出
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    monitorTempDirectory()
                }
                
                return true
            } catch {
                print("创建临时目录失败：\(error)")
            }
        }
        
        // 标准文件拖拽处理
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            print("标准文件拖拽处理，文件数：\(fileURLs.count)")
            
            // 直接处理所有文件
            dragOperationBlock?(fileURLs)
            return true
        }
        
        return false
    }
}
*/





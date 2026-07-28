//
//  ShareExtension.swift
//  AppShare
//
//  Created by Niko on 2025/10/14.
//

import Foundation
import UIKit
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif
import MobileCoreServices
import Contacts

class ShareExtension: UIViewController {
    
    var context: NSExtensionContext!
    
    /// 共享数据模型
    var shareInfoModel = ShareInfoModel()
    
    /// group 管理类
    let groupFileManager = GroupFileManager(groupIdentifier: groupID)
    
    let chainGroup = TaskQueueManager.createChainGroup()
    
    /// 总任务数
    private var totalTasks: Int = 0
    /// 已完成任务数
    private var completedTasks: Int = 0
    
    // MARK: - UI Elements
    
    /// 容器视图
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 8
        return view
    }()
    
    /// 标题标签
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "正在处理文件..."
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .black
        label.textAlignment = .center
        return label
    }()
    
    /// 进度条
    private lazy var progressView: ProgressView = {
        let view = ProgressView()
        view.progressColor = .systemBlue
        view.trackColor = .systemGray5
        view.lineWidth = 4
        return view
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    /// 入口
    override func beginRequest(with context: NSExtensionContext) {
        self.context = context
        if #available(iOS 15, *) {
            // Fallback on earlier versions
            Task {
                /// 清除目录下所有内容，避免浪费闪存
                await groupFileManager?.clearDirectory(folderName: shareExtensionRootDirectoryName)
                /// 获取分享对象
                guard let item = context.inputItems.first as? NSExtensionItem,
                      let attachments = item.attachments,
                      !attachments.isEmpty else { 
                    return finishShare() 
                }
                /// 初始化任务数
                totalTasks = attachments.count
                completedTasks = 0
                
                updateProgress()
                
                /// 处理分享资源
                await processAttachments(attachments: attachments)
                
                /// 所有任务完成
                chainGroup.onAllTasksFinished = { [weak self] success in
                    print("Chain completed: \(success)")
                    guard let self = self, success else { return }
                    
                    queueFinish()
                }
                chainGroup.start()
            }
        }
        else{
            groupFileManager?.clearDirectory(folderName: shareExtensionRootDirectoryName) { [weak self] success in
                guard let self = self else { return }
                // 第二步：获取分享对象
                guard let item = context.inputItems.first as? NSExtensionItem,
                      let attachments = item.attachments,
                      !attachments.isEmpty else {
                    return self.finishShare()
                }
                // 第三步：初始化任务数
                self.totalTasks = attachments.count
                self.completedTasks = 0
                self.updateProgress()
                
                /// 处理分享资源
                processAttachments(attachments: attachments) { 
                    self.chainGroup.onAllTasksFinished = { [weak self] success in
                        print("Chain completed: \(success)")
                        guard let self = self, success else { return }
                        queueFinish()
                    }
                    self.chainGroup.start()
                }
            }
            
        }
        
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        //view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        
        view.addSubview(containerView)
        containerView.addSubview(progressView)
        containerView.addSubview(titleLabel)
        
        // 布局
        containerView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 容器视图居中
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 160),
            containerView.heightAnchor.constraint(equalToConstant: 160),
            
            // 环形进度条（居中显示）
            progressView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            progressView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 35),
            progressView.widthAnchor.constraint(equalToConstant: 60),
            progressView.heightAnchor.constraint(equalToConstant: 60),
            
            // 标题
            titleLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 20),
            titleLabel.leftAnchor.constraint(equalTo: containerView.leftAnchor, constant: 16),
            titleLabel.rightAnchor.constraint(equalTo: containerView.rightAnchor, constant: -16),
        ])
    }
    
    /// 处理分享资源
    func processAttachments(attachments: [NSItemProvider]) async {
        /// 遍历分享内容
        for (index, provider) in attachments.enumerated() {
            // 添加任务
            let task = TaskOperation.async(identifier: "Shar Step \(index + 1)") { task in
                Task { [weak self] in
                    guard let self = self else { return }
                    
                    await configProvider(provider: provider)
                    /// 更新进度
                    incrementProgress()
                    
                    task.finish(true) // 继续下一步
                }
            }
            chainGroup.add(task)
        }
    }
    func processAttachments(attachments: [NSItemProvider], completion: @escaping () -> Void) {
        /// 遍历分享内容
//        let dispatchGroup = DispatchGroup()
        
        for (index, provider) in attachments.enumerated() {
            
            // 创建 TaskOperation 实例
            let task = TaskOperation(identifier: "Shar Step \(index + 1)") { task in
                // 使用 completion handler 版本的 configProvider
//                dispatchGroup.enter()
                self.configProvider(provider: provider) { [weak self] success in
                    guard let self = self else {
//                        dispatchGroup.leave()
                        task.finish(false)
                        return
                    }
//                    dispatchGroup.leave()
                    DispatchQueue.main.async {
                        // 更新进度
                        self.incrementProgress()
                        task.finish(true) // 继续下一步
                    }
                }
            }
            chainGroup.add(task)
        }
        // 所有任务完成后的回调
//        dispatchGroup.notify(queue: .main) {
            completion()
//        }
    }    
    // MARK: - Progress Management
    
    /// 更新进度
    @MainActor
    private func updateProgress() {
        let progress = totalTasks > 0 ? CGFloat(completedTasks) / CGFloat(totalTasks) : 0
        progressView.setProgress(progress, animated: true)
    }
    
    /// 增加已完成任务数
    @MainActor
    private func incrementProgress() {
        completedTasks += 1
        updateProgress()
    }
    
    /// 处理分享资源
    func configProvider(provider: NSItemProvider) async {
        let fileInfoModel = ShareFileInfModel()
        
        fileInfoModel.fileType = ShareFileType.getShareFileType(provider: provider)
        guard fileInfoModel.fileType != .none else {
            fileInfoModel.errorMessage = "不支持此类型 provider：\(provider)"
            return shareInfoModel.fileInfos.append(fileInfoModel)
        }
        
        guard let identifier = provider.getIdentifier() else {
            fileInfoModel.fileType = .none
            fileInfoModel.errorMessage = "读取 identifiers 失败 provider: \(provider)"
            return shareInfoModel.fileInfos.append(fileInfoModel)
        }
        
        fileInfoModel.identifier = identifier
        
        do {
            let item = try await provider.loadItem(forTypeIdentifier: identifier)
            if let fileUrl = item as? URL {
                if let (fileName, _) = await groupFileManager?.storeMediaFile(from: fileUrl, to: shareExtensionRootDirectoryName, customFileName: fileUrl.lastPathComponent),let fileName = fileName,let fileSize = await groupFileManager?.getFileSize(fileName: fileName, in: shareExtensionRootDirectoryName) {
                    fileInfoModel.fileName = fileName
                    fileInfoModel.fileSize = fileSize
                    fileInfoModel.isImageType = isMediaImageType(fileName: fileName)
                    fileInfoModel.isVideoType = isMediaVideoType(fileName: fileName)
                    print("分享资源模型创建成功：\(fileInfoModel)")
                } else {
                    fileInfoModel.fileType = .none
                    fileInfoModel.errorMessage = "图片视频资源写入沙盒失败：\(item) identifier：\(identifier)"
                }
            } 
            else if let fileData = item as? Data {
                /// 通讯录
                if fileInfoModel.fileType == .contact {
                    do {
                        // 解析vCard数据为CNContact数组
                        let contacts = try CNContactVCardSerialization.contacts(with: fileData)
                        if let contact = contacts.first,let fileName = await groupFileManager?.storeContact(contact, folderName: shareExtensionRootDirectoryName, customFileName: contact.givenName.isEmpty && contact.familyName.isEmpty ? "Contact" : contact.familyName + contact.givenName),let fileSize = await groupFileManager?.getFileSize(fileName: fileName, in: shareExtensionRootDirectoryName) {
                            fileInfoModel.fileName = fileName
                            fileInfoModel.fileSize = fileSize
                            print("分享资源模型创建成功：\(fileInfoModel)")
                        } else {
                            fileInfoModel.fileType = .none
                            fileInfoModel.errorMessage = "通讯录写入沙盒失败：\(item) identifier：\(identifier)"
                        }
                        
                    } catch {
                        fileInfoModel.fileType = .none
                        fileInfoModel.errorMessage = "解析vCard数据为 CNContact 错误: \(error) identifier：\(identifier)"
                        print("解析vCard数据为 CNContact 错误: \(error)")
                    }
                } 
                else if fileInfoModel.fileType == .photo(.image) {
                    /// 将图片写入本地
                    if let fileName = await groupFileManager?.storeUIImage(fileData, imageFormat: "PNG", folderName: shareExtensionRootDirectoryName),
                       let fileSize = await groupFileManager?.getFileSize(fileName: fileName, in: shareExtensionRootDirectoryName) {
                        fileInfoModel.fileName = fileName
                        fileInfoModel.fileSize = fileSize
                    } else {
                        fileInfoModel.fileType = .none
                        fileInfoModel.errorMessage = "Data Image 资源写入沙盒失败：\(item) identifier：\(identifier)"
                    }
                } 
                else {
                    fileInfoModel.fileType = .none
                    fileInfoModel.errorMessage = "数据类型：Data，identifier：\(identifier) 暂不支持"
                }
            }
            else if let publicImage = item as? UIImage, let imageData = publicImage.pngData() {
                if let fileName = await groupFileManager?.storeUIImage(imageData, imageFormat: "PNG", folderName: shareExtensionRootDirectoryName),
                   let fileSize = await groupFileManager?.getFileSize(fileName: fileName, in: shareExtensionRootDirectoryName) {
                    fileInfoModel.fileName = fileName
                    fileInfoModel.fileSize = fileSize
                } else {
                    fileInfoModel.fileType = .none
                    fileInfoModel.errorMessage = "UIImage资源写入沙盒失败：\(item)"
                }
            } 
            else {
                print("数据解析失败 item 类型未知: \(item)")
                fileInfoModel.fileType = .none
                fileInfoModel.errorMessage = "数据解析失败 item 类型未知: \(item) identifier：\(identifier)"
            }
        } catch {
            fileInfoModel.fileType = .none
            fileInfoModel.errorMessage = "加载 item 失败: \(error), provider: \(provider) identifier：\(identifier)"
            print("加载 item 失败: \(error)")
        }
        
        shareInfoModel.fileInfos.append(fileInfoModel)
    }
    /// 处理分享资源 兼容13+
    func configProvider(provider: NSItemProvider, completion: @escaping (Bool) -> Void) {
        let fileInfoModel = ShareFileInfModel()
        fileInfoModel.fileType = ShareFileType.getShareFileType(provider: provider)
        guard fileInfoModel.fileType != .none else {
            fileInfoModel.errorMessage = "不支持此类型 provider：\(provider)"
            return shareInfoModel.fileInfos.append(fileInfoModel)
        }
        guard let identifier = provider.getIdentifier() else {
            fileInfoModel.fileType = .none
            fileInfoModel.errorMessage = "读取 identifiers 失败 provider: \(provider)"
            return shareInfoModel.fileInfos.append(fileInfoModel)
        }
        fileInfoModel.identifier = identifier
        // iOS 13+ 兼容版本：
        do {
            provider.loadItem(forTypeIdentifier: identifier, options: nil) { [weak self] item, error in
                guard let self = self else {
                    completion(false)
                    return
                }
                
                DispatchQueue.main.async {
                    if let error = error {
                        fileInfoModel.fileType = .none
                        fileInfoModel.errorMessage = "加载 item 失败: \(error), provider: \(provider) identifier：\(identifier)"
                        print("加载 item 失败: \(error)")
                        completion(false)
                        return
                    }
                    
                    guard let item = item else {
                        fileInfoModel.fileType = .none
                        fileInfoModel.errorMessage = "item 为空, provider: \(provider) identifier：\(identifier)"
                        print("item 为空, provider: \(provider)")
                        completion(false)
                        return
                    }
                    if let fileUrl = item as? URL {
                        self.groupFileManager?.storeMediaFile(from: fileUrl, to: shareExtensionRootDirectoryName, customFileName: fileUrl.lastPathComponent) { [weak self] result, error in
                            if error != nil {
                                fileInfoModel.fileType = .none
                                fileInfoModel.errorMessage = "图片视频资源写入沙盒失败：\(item) identifier：\(identifier)"
                                completion(false)
                            }
                            guard let self = self else {
                                completion(false)
                                return
                            }
                            DispatchQueue.main.async {
                                if let (fileName, _) = result, let fileName = fileName {
                                    self.groupFileManager?.getFileSize(fileName: fileName, in: shareExtensionRootDirectoryName) { fileSize in
                                        DispatchQueue.main.async {
                                            if let fileSize = fileSize {
                                                fileInfoModel.fileName = fileName
                                                fileInfoModel.fileSize = fileSize
                                                fileInfoModel.isImageType = self.isMediaImageType(fileName: fileName)
                                                fileInfoModel.isVideoType = self.isMediaVideoType(fileName: fileName)
                                                print("分享资源模型创建成功：\(fileInfoModel)")
                                                completion(true)
                                            } else {
                                                fileInfoModel.fileType = .none
                                                fileInfoModel.errorMessage = "获取文件大小失败"
                                                completion(false)
                                            }
                                        }
                                    }
                                } else {
                                    fileInfoModel.fileType = .none
                                    fileInfoModel.errorMessage = "图片视频资源写入沙盒失败：\(fileUrl) identifier：\(identifier)"
                                    completion(false)
                                }
                            } // ← async 闭包结束
                        }
                    } 
                    else if let fileData = item as? Data {
                        // 通讯录处理
                        if fileInfoModel.fileType == .contact {
                            do{
                                let contacts = try CNContactVCardSerialization.contacts(with: fileData)
                                if let contact = contacts.first {
                                    let contactName = contact.givenName.isEmpty && contact.familyName.isEmpty ? "Contact" : contact.familyName + contact.givenName
                                    
                                    self.groupFileManager?.storeContact(contact, folderName: shareExtensionRootDirectoryName, customFileName: contactName) { [weak self] fileName in
                                        guard let self = self else { 
                                            completion(false)
                                            return 
                                        }
                                        
                                        DispatchQueue.main.async {
                                            if let fileName = fileName {
                                                // 存储成功，继续获取文件大小
                                                self.groupFileManager?.getFileSize(fileName: fileName, in: shareExtensionRootDirectoryName) { fileSize in
                                                    DispatchQueue.main.async {
                                                        if let fileSize = fileSize {
                                                            // 两个操作都成功
                                                            fileInfoModel.fileName = fileName
                                                            fileInfoModel.fileSize = fileSize
                                                            print("分享资源模型创建成功：\(fileInfoModel)")
                                                            completion(true)
                                                        } else {
                                                            // 获取文件大小失败
                                                            fileInfoModel.fileType = .none
                                                            fileInfoModel.errorMessage = "获取通讯录文件大小失败：\(item) identifier：\(identifier)"
                                                            completion(false)
                                                        }
                                                    }
                                                }
                                            } else {
                                                // 存储通讯录失败
                                                fileInfoModel.fileType = .none
                                                fileInfoModel.errorMessage = "通讯录写入沙盒失败：\(item) identifier：\(identifier)"
                                                completion(false)
                                            }
                                        }
                                    }
                                } else {
                                    fileInfoModel.fileType = .none
                                    fileInfoModel.errorMessage = "通讯录数据为空：\(item) identifier：\(identifier)"
                                    completion(false)
                                }
                                
                            } catch {
                                fileInfoModel.fileType = .none
                                fileInfoModel.errorMessage = "解析vCard数据为 CNContact 错误: \(error) identifier：\(identifier)"
                                print("解析vCard数据为 CNContact 错误: \(error)")
                                completion(false)
                            }
                        } 
                        else if fileInfoModel.fileType == .photo(.image) {
                            /// 将图片写入本地
                            self.groupFileManager?.storeUIImage(fileData, imageFormat: "PNG", folderName: shareExtensionRootDirectoryName) { [weak self] fileName in
                                guard let self = self else {
                                    completion(false)
                                    return
                                }
                                
                                DispatchQueue.main.async {
                                    if let fileName = fileName {
                                        // 图片存储成功，继续获取文件大小
                                        self.groupFileManager?.getFileSize(fileName: fileName, in: shareExtensionRootDirectoryName) { fileSize in
                                            DispatchQueue.main.async {
                                                if let fileSize = fileSize {
                                                    // 两个操作都成功
                                                    fileInfoModel.fileName = fileName
                                                    fileInfoModel.fileSize = fileSize
                                                    completion(true)
                                                } else {
                                                    // 获取文件大小失败
                                                    fileInfoModel.fileType = .none
                                                    fileInfoModel.errorMessage = "获取图片文件大小失败：\(item) identifier：\(identifier)"
                                                    completion(false)
                                                }
                                            }
                                        }
                                    } else {
                                        // 存储图片失败
                                        fileInfoModel.fileType = .none
                                        fileInfoModel.errorMessage = "Data Image 资源写入沙盒失败：\(item) identifier：\(identifier)"
                                        completion(false)
                                    }
                                }
                            }
                        }
                        else {
                            fileInfoModel.fileType = .none
                            fileInfoModel.errorMessage = "数据类型：Data，identifier：\(identifier) 暂不支持"
                            completion(false)
                        }
                    } 
                    else if let publicImage = item as? UIImage, let imageData = publicImage.pngData() {
                        self.groupFileManager?.storeUIImage(imageData, imageFormat: "PNG", folderName: shareExtensionRootDirectoryName) { [weak self] fileName in
                            guard let self = self else {
                                completion(false)
                                return
                            }
                            
                            DispatchQueue.main.async {
                                if let fileName = fileName {
                                    // 图片存储成功，继续获取文件大小
                                    self.groupFileManager?.getFileSize(fileName: fileName, in: shareExtensionRootDirectoryName) { fileSize in
                                        DispatchQueue.main.async {
                                            if let fileSize = fileSize {
                                                // 两个操作都成功
                                                fileInfoModel.fileName = fileName
                                                fileInfoModel.fileSize = fileSize
                                                completion(true)
                                            } else {
                                                // 获取文件大小失败
                                                fileInfoModel.fileType = .none
                                                fileInfoModel.errorMessage = "UIImage资源写入沙盒失败：\(item)"
                                                completion(false)
                                            }
                                        }
                                    }
                                } else {
                                    // 存储图片失败
                                    fileInfoModel.fileType = .none
                                    fileInfoModel.errorMessage = "UIImage资源写入沙盒失败：\(item)"
                                    completion(false)
                                }
                            }
                        }
                    } 
                    else {
                        print("数据解析失败 item 类型未知: \(item)")
                        fileInfoModel.fileType = .none
                        fileInfoModel.errorMessage = "数据解析失败 item 类型未知: \(item) identifier：\(identifier)"
                        completion(false)
                    }
                }
            }
            
        } catch {
            fileInfoModel.fileType = .none
            fileInfoModel.errorMessage = "加载 item 失败: \(error), provider: \(provider) identifier：\(identifier)"
            print("加载 item 失败: \(error)")
            completion(false)
        }
        shareInfoModel.fileInfos.append(fileInfoModel)
    }
    
    
    
    
    func finishShare() {
        context.completeRequest(returningItems: nil, completionHandler: nil)
    }
    
    /// 任务完成
    func queueFinish() {
        /// 将数据保存到 group 中
     guard let userDefaults = UserDefaults(suiteName: "group.com.HarmonyOSInterconnection.app") else {
        print("无法访问 App Group 的 UserDefaults")
        return
    }
        if let sharedDefaults = UserDefaults(suiteName: groupID) {
            sharedDefaults.saveShareInfo(shareInfoModel)
            print("已保存文件信息到UserDefaults: \(shareInfoModel)")
        }
        
        /// 关闭页面
        finishShare()
        
        /// 跳转到主App
        openMainApp()
    }
    
    /// 判断文件是否为媒体图片类型
    /// - Parameter fileURL: 选中文件的本地URL
    /// - Returns: 是否为媒体图片类型
    private func isMediaImageType(fileName: String) -> Bool {
        guard let fileUrl = GroupFileManager.getFileURLInSharedContainer(fileName: fileName) else { return false }
        guard let fileUTI = try? fileUrl.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier else {
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
    private func isMediaVideoType(fileName: String) -> Bool {
        guard let fileUrl = GroupFileManager.getFileURLInSharedContainer(fileName: fileName) else { return false }
        guard let fileUTI = try? fileUrl.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier else {
            return false
        }
        let mediaTypeUTIs: [CFString] = [ kUTTypeMovie ]
        return mediaTypeUTIs.contains { mediaUTI in
            UTTypeConformsTo(fileUTI as CFString, mediaUTI)
        }
    }
    deinit {
        print("====\(self)释放")
    }
}

extension ShareExtension {
    /// 跳转主应用
    private func openMainApp() {
        var components = URLComponents()
        components.scheme = shareUrlSchemes  // 替换为你的应用Scheme
        components.host = shareHost
        guard let appURL = components.url else { 
            print("❌ appURL 不可用") 
            return
        }
        
        if let application = UIApplication.value(forKey: "sharedApplication") as? UIApplication {
            if #available(iOS 18.0, *){
                application.open(appURL, options: [:], completionHandler: nil)
            }else{
                if  #available(iOS 14.0, *) {
                    application.perform(#selector(UIApplication.open(_:options:completionHandler:)), with: appURL, with: [:])
                }else{
                    var responder:UIResponder? = self
                    while let currentResponder = responder {
                        if currentResponder is UIApplication{
                            (currentResponder as! UIApplication).openURL(appURL)
                            break
                        }
                        responder = currentResponder.next
                    }
                }
            }
        }
    }
    func openURL(_ sender: UIButton) {
        
    }
}
        
//    }
    
//        if let application = UIApplication.value(forKey: "sharedApplication") as? UIApplication {
//            if #available(iOS 18.0, *) {
//                application.open(appURL, options: [:], completionHandler: nil)
//            } else {
//                self.extensionContext?.open(appURL) { [weak self] success in
//                    DispatchQueue.main.async {
//                        if success {
//                            print("✅ 成功打开主应用")
//                            // 延迟关闭分享扩展，确保主应用已启动
//                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
////                                self?.finishShare()
//                            }
//                        } else {
//                            print("❌ 打开主应用失败")
//                        }
//                    } 
//                }
//                application.perform(#selector(UIApplication.open(_:options:completionHandler:)), with: appURL, with: [:])
//            }
//        }
//    }
//}


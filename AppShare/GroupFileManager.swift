//
//  GroupFileManager.swift
//  MutualInfection
//
//  Created by Niko on 2025/10/15.
//

import Foundation
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif
@preconcurrency import Contacts

class GroupFileManager: @unchecked Sendable {
    
    // MARK: - 属性
    
    /// 文件管理器实例，用于进行文件系统相关操作
    private let fileManager: FileManager
    /// App Group 容器的根目录 URL
    private let containerURL: URL
    
    // MARK: - 初始化方法
    
    /// 初始化方法，传入 Group 标识符以获取容器路径，并创建默认的文件夹结构
    /// - Parameter groupIdentifier: App Group 标识符
    init?(groupIdentifier: String) {
        self.fileManager = FileManager.default
        
        // 获取 App Group 容器的根目录 URL
        guard let container = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: groupIdentifier
        ) else {
            print("无法获取 Group 容器 URL")
            return nil
        }
        
        self.containerURL = container
    }
    
    // 获取共享容器中文件的完整URL
    static func getFileURLInSharedContainer(fileName: String) -> URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else { return nil }
        
        let fileURL = containerURL.appendingPathComponent(shareExtensionRootDirectoryName).appendingPathComponent(fileName)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        
        return fileURL
    }
    
    // MARK: - 清理目录相关方法
    
    /// 清理指定文件夹或文件内容的方法
    /// - Parameters:
    ///   - folderName: 目标文件夹名称，若为 nil 则默认为根目录
    ///   - fileName: 目标文件名，若为 nil 则清理整个文件夹下所有内容
    /// - Returns: 是否清理成功（true 成功，false 失败）
    @discardableResult
    func clearDirectory(folderName: String? = nil, fileName: String? = nil) async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let result = self._clearDirectory(folderName: folderName, fileName: fileName)
                continuation.resume(returning: result)
            }
        }
    }
    
    // iOS 13+ 兼容的完成处理程序版本
    func clearDirectory(folderName: String? = nil, fileName: String? = nil, completion: @escaping (Bool) -> Void) {
//        if #available(iOS 15.0, *) {
//            Task {
//                let result = await clearDirectory(folderName: folderName, fileName: fileName)
//                completion(result)
//            }
//        } else {
            DispatchQueue.global(qos: .utility).async {
                let result = self._clearDirectory(folderName: folderName, fileName: fileName)
                DispatchQueue.main.async {
                    completion(result)
                }
            }
//        }
    }
    
    /// 清理指定文件夹下所有指定扩展名的文件
    /// - Parameters:
    ///   - folderName: 目标文件夹名称
    ///   - extensions: 需要清理的文件扩展名数组（不区分大小写）
    /// - Returns: 是否清理成功（true 成功，false 失败）
    func clearFilesWithExtensions(in folderName: String, extensions: [String]) async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let result = self._clearFilesWithExtensions(in: folderName, extensions: extensions)
                continuation.resume(returning: result)
            }
        }
    }
    
    // MARK: - 文件存储相关方法
    
    /// 存储单个媒体文件（支持视频、图片、LivePhoto 等）
    /// - Parameters:
    ///   - sourceURL: 源文件的 URL 路径
    ///   - folderName: 目标文件夹名称
    ///   - customFileName: 自定义文件名（可选，若为空则自动生成唯一文件名）
    /// - Returns: 存储成功后的文件名，失败返回 nil
    func storeMediaFile(from sourceURL: URL, to folderName: String, customFileName: String? = nil) async -> (String?, String?) {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let fileInfo = self._storeMediaFile(from: sourceURL, to: folderName, customFileName: customFileName)
                continuation.resume(returning: fileInfo)
            }
        }
    }
    // iOS 13+ 兼容的完成处理程序版本
    func storeMediaFile(from sourceURL: URL, to folderName: String, customFileName: String? = nil, completion: @escaping ((String?, String?)?, Error?) -> Void) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(nil, NSError(domain: "StoreMediaError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Self was deallocated"]))
                }
                return
            }
            
            let fileInfo = self._storeMediaFile(from: sourceURL, to: folderName, customFileName: customFileName)
            DispatchQueue.main.async {
                completion(fileInfo, nil)
            }
        }
    }
    
    /// 批量存储多个媒体文件（支持视频、图片、LivePhoto 等）
    /// - Parameters:
    ///   - sourceURLs: 源文件 URL 数组
    ///   - folderName: 目标文件夹名称
    /// - Returns: 存储成功的文件名数组（失败的文件将被忽略）
    func storeMultipleMediaFiles(from sourceURLs: [URL], to folderName: String) async -> [(String, String)] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                var storedFiles: [(String, String)] = []
                
                for sourceURL in sourceURLs {
                    let fileInfo = self._storeMediaFile(from: sourceURL, to: folderName)
                    if let fileName = fileInfo.0, let filePath = fileInfo.1 {
                        storedFiles.append((fileName, filePath))
                    }
                }
                
                continuation.resume(returning: storedFiles)
            }
        }
    }
    
    // MARK: -  将 UIImage 图片写入指定文件夹
    /// - Parameters:
    ///   - image: 要存储的 UIImage 对象
    ///   - folderName: 目标文件夹名称
    ///   - imageFormat: 图片格式，默认为 PNG
    ///   - compressionQuality: 压缩质量（仅对 JPEG 格式有效），范围 0.0-1.0
    ///   - customFileName: 自定义文件名（可选，若为空则自动生成唯一文件名）
    /// - Returns: 存储成功后的图片文件路径，失败返回 nil
    func storeUIImage(_ imageData: Data,
                      imageFormat: String = "PNG",
                      folderName: String,
                      customFileName: String? = nil) async -> String? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let result = self._storeImage(imageData, imageFormat: imageFormat, folderName: folderName, customFileName: customFileName)
                continuation.resume(returning: result)
            }
        }
    }
    // 新增 iOS 13-14 兼容的 completion handler 版本
    func storeUIImage(_ imageData: Data, imageFormat: String = "PNG",folderName: String,customFileName: String? = nil,completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            let result = self._storeImage(imageData, imageFormat: imageFormat, folderName: folderName, customFileName: customFileName)
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    // MARK: - 通讯录存储相关方法
    
    /// 存储单个通讯录联系人为 vCard 文件
    /// - Parameters:
    ///   - contact: 需要存储的 CNContact 对象
    ///   - customFileName: 自定义文件名（可选，若为空则自动生成唯一文件名）
    /// - Returns: 存储成功后的文件名，失败返回 nil
    func storeContact(_ contact: CNContact, folderName: String, customFileName: String? = nil) async -> String? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let result = self._storeContact(contact, folderName: folderName, customFileName: customFileName)
                continuation.resume(returning: result)
            }
        }
    }
    // iOS 13+ 使用 completion handler
    func storeContact(_ contact: CNContact, folderName: String, customFileName: String? = nil, completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            let result = self._storeContact(contact, folderName: folderName, customFileName: customFileName)
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    /// 批量存储多个通讯录联系人为 vCard 文件
    /// - Parameter contacts: CNContact 对象数组
    /// - Returns: 存储成功的文件名数组（失败的联系人将被忽略）
    func storeMultipleContacts(_ contacts: [CNContact], folderName: String) async -> [String] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                var storedFiles: [String] = []
                
                for contact in contacts {
                    if let fileName = self._storeContact(contact, folderName: folderName) {
                        storedFiles.append(fileName)
                    }
                }
                
                continuation.resume(returning: storedFiles)
            }
        }
    }
    
    // MARK: - 文件读取相关方法
    
    /// 获取指定文件的文件 URL
    /// - Parameters:
    ///   - fileName: 目标文件名
    ///   - folderName: 所在文件夹名称
    /// - Returns: 文件 URL，若文件不存在则返回 nil
    func getFileURL(fileName: String, in folderName: String) async -> URL? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let fileURL = self.containerURL
                    .appendingPathComponent(folderName)
                    .appendingPathComponent(fileName)
                
                let exists = self.fileManager.fileExists(atPath: fileURL.path)
                continuation.resume(returning: exists ? fileURL : nil)
            }
        }
    }
    
    /// 读取指定 vCard 文件并返回 CNContact 对象
    /// - Parameter fileName: vCard 文件名
    /// - Returns: CNContact 对象，读取失败则返回 nil
    func getContact(from fileName: String) async -> CNContact? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let result = self._getContact(from: fileName)
                continuation.resume(returning: result)
            }
        }
    }
    
    /// 获取指定文件夹下所有文件名
    /// - Parameter folderName: 目标文件夹名称
    /// - Returns: 文件名数组（不包含隐藏文件）
    func getAllFileNames(in folderName: String) async -> [String] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let result = self._getAllFileNames(in: folderName)
                continuation.resume(returning: result)
            }
        }
    }
    
    // MARK: - 文件信息相关方法
    
    /// 获取指定文件的大小（单位：字节）
    /// - Parameters:
    ///   - fileName: 文件名
    ///   - folderName: 文件夹名称
    /// - Returns: 文件大小（字节），获取失败返回 nil
    func getFileSize(fileName: String, in folderName: String) async -> Int64? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let result = self._getFileSize(fileName: fileName, in: folderName)
                continuation.resume(returning: result)
            }
        }
    }
    // iOS 13+ 兼容的完成处理程序版本
    func getFileSize(fileName: String, in folderName: String, completion: @escaping (Int64?) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let result = self._getFileSize(fileName: fileName, in: folderName)
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    /// 获取指定文件夹的统计信息
    /// - Parameter folderName: 文件夹名称
    /// - Returns: (文件数量, 文件夹数量, 总大小字节)，获取失败返回 nil
    func getDirectoryInfo(for folderName: String) async -> (fileCount: Int, folderCount: Int, totalSize: Int64)? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let result = self._getDirectoryInfo(for: folderName)
                continuation.resume(returning: result)
            }
        }
    }
    
    // MARK: - 私有实现方法（具体逻辑实现，外部请勿直接调用）
    
    /// 实现：清理指定目录或文件
    private func _clearDirectory(folderName: String? = nil, fileName: String? = nil) -> Bool {
        do {
            // 确定目标目录（若未指定文件夹则为根目录）
            let targetDirectory: URL
            if let folderName = folderName {
                targetDirectory = containerURL.appendingPathComponent(folderName)
                // 检查目标文件夹是否存在
                guard fileManager.fileExists(atPath: targetDirectory.path) else {
                    print("目标文件夹不存在: \(folderName)")
                    return false
                }
            } else {
                targetDirectory = containerURL
            }
            
            // 如果指定了文件名，则仅删除该文件
            if let fileName = fileName {
                let fileURL = targetDirectory.appendingPathComponent(fileName)
                // 检查文件是否存在
                guard fileManager.fileExists(atPath: fileURL.path) else {
                    print("目标文件不存在: \(fileName)")
                    return false
                }
                
                do {
                    try fileManager.removeItem(at: fileURL)
                    print("已删除文件: \(fileName)")
                    return true
                } catch {
                    print("删除文件失败: \(fileName) - \(error.localizedDescription)")
                    return false
                }
            }
            // 未指定文件名，则删除文件夹下所有内容
            else {
                let contents = try fileManager.contentsOfDirectory(
                    at: targetDirectory,
                    includingPropertiesForKeys: nil,
                    options: []
                )
                
                var success = true
                var deletedCount = 0
                
                for itemURL in contents {
                    
                    do {
                        guard fileManager.fileExists(atPath: itemURL.path) else {
                                return true // 文件不存在，视为删除成功
                            }
                        if fileManager.isWritableFile(atPath: itemURL.path) {
                               try fileManager.removeItem(at: itemURL)
                               print("成功删除文件: \(itemURL.lastPathComponent)")
                            deletedCount += 1
                            success = true
                        }else{
                            print("文件不可写，无法删除: \(itemURL.path)")
                            // 尝试修改权限
                            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: itemURL.path)
                            
                            if fileManager.isWritableFile(atPath: itemURL.path) {
                                try fileManager.removeItem(at: itemURL)
                                print("修改权限后成功删除文件")
                                deletedCount += 1
                                success = true
                            } else {
                                print("即使修改权限后仍无法删除")
                                success = false
                            }
                        }
                    } catch {
                        print("删除失败: \(itemURL.lastPathComponent) - \(error.localizedDescription)")
                        success = false
                    }
                }
                
                print("删除完成: \(deletedCount) 个文件")
                return success
            }
            
        } catch {
            print("访问目录失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 实现：清理文件夹下所有指定扩展名的文件
    private func _clearFilesWithExtensions(in folderName: String, extensions: [String]) -> Bool {
        let targetDirectory = containerURL.appendingPathComponent(folderName)
        
        // 检查目标文件夹是否存在
        guard fileManager.fileExists(atPath: targetDirectory.path) else {
            print("目标文件夹不存在: \(folderName)")
            return false
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: targetDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            
            let targetExtensions = Set(extensions.map { $0.lowercased() })
            var success = true
            var deletedCount = 0
            
            for itemURL in contents {
                let fileExtension = itemURL.pathExtension.lowercased()
                
                if targetExtensions.contains(fileExtension) {
                    do {
                        try fileManager.removeItem(at: itemURL)
                        deletedCount += 1
                    } catch {
                        print("删除失败: \(itemURL.lastPathComponent) - \(error.localizedDescription)")
                        success = false
                    }
                }
            }
            
            print("删除完成: \(deletedCount) 个 \(extensions.joined(separator: ", ")) 文件")
            return success
            
        } catch {
            print("访问目录失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 实现：将媒体文件存储到指定文件夹
    private func _storeMediaFile(from sourceURL: URL, to folderName: String, customFileName: String? = nil) -> (String?, String?) {
        let targetDirectory = containerURL.appendingPathComponent(folderName)
        
        // 确保目标目录存在，不存在则创建
        if !fileManager.fileExists(atPath: targetDirectory.path) {
            do {
                try fileManager.createDirectory(
                    at: targetDirectory,
                    withIntermediateDirectories: true
                )
            } catch {
                print("创建目录失败: \(folderName) - \(error.localizedDescription)")
                return (nil, nil)
            }
        }
        
        // 生成文件名：自定义 > 自动生成 UUID
        let fileName: String
        if let customName = customFileName {
            fileName = customName
        } else {
            // 自动生成唯一文件名，包含扩展名
            let ext = sourceURL.pathExtension.isEmpty ? "" : ".\(sourceURL.pathExtension)"
            fileName = "\(UUID().uuidString)\(ext)"
        }
        
        let targetURL = targetDirectory.appendingPathComponent(fileName)
        
        let exists = self.fileManager.fileExists(atPath: targetURL.path)
        if exists {
            print("GroupFileManager ======== 文件 \(fileName) 已存在，直接返回文件名和路径 ")
            return (fileName, targetURL.path)
        } else {
            do {
                // 拷贝源文件到目标目录
                try fileManager.copyItem(at: sourceURL, to: targetURL)
                print("GroupFileManager ======== 文件存储成功: \(fileName)")
                return (fileName, targetURL.path)
            } catch {
                print("GroupFileManager ======== 文件存储失败: \(fileName) - \(error.localizedDescription)")
                return (nil, nil)
            }
        }
    }
    
    /// 实现：将单个联系人存储为 vCard 文件
    private func _storeImage(_ imageData: Data, imageFormat: String, folderName: String, customFileName: String? = nil) -> String? {
        let imageDirectory = containerURL.appendingPathComponent(folderName)
        
        // 确保 Contacts 目录存在，不存在则创建
        if !fileManager.fileExists(atPath: imageDirectory.path) {
            do {
                try fileManager.createDirectory(
                    at: imageDirectory,
                    withIntermediateDirectories: true
                )
            } catch {
                print("创建 Contacts 目录失败: \(error.localizedDescription)")
                return nil
            }
        }
        
        // 生成文件名：自定义 > 名字+UUID
        let fileName: String
        if let customName = customFileName {
            fileName = "\(customName).\(imageFormat)"
        } else {
            fileName = "image_\(UUID().uuidString).\(imageFormat)"
        }
        
        let targetURL = imageDirectory.appendingPathComponent(fileName)
        
        do {
            try imageData.write(to: targetURL)
            print("图片存储成功: \(fileName)")
            return fileName
        } catch {
            if (error as NSError).code == 516 {
                return fileName
            }
            print("图片存储失败: \(fileName) - \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 实现：将单个联系人存储为 vCard 文件
    private func _storeContact(_ contact: CNContact, folderName: String, customFileName: String? = nil) -> String? {
        let contactsDirectory = containerURL.appendingPathComponent(folderName)
        
        // 确保 Contacts 目录存在，不存在则创建
        if !fileManager.fileExists(atPath: contactsDirectory.path) {
            do {
                try fileManager.createDirectory(
                    at: contactsDirectory,
                    withIntermediateDirectories: true
                )
            } catch {
                print("创建 Contacts 目录失败: \(error.localizedDescription)")
                return nil
            }
        }
        
        // 生成文件名：自定义 > 名字+UUID
        let fileName: String
        if let customName = customFileName {
            fileName = "\(customName).vcf"
        } else {
            let contactName = contact.givenName.isEmpty && contact.familyName.isEmpty ? "Contact" : contact.familyName + contact.givenName
            fileName = "\(contactName)_\(UUID().uuidString).vcf"
        }
        
        let targetURL = contactsDirectory.appendingPathComponent(fileName)
        
        do {
            // 将 CNContact 转换为 vCard 数据并写入文件
            let vCardData = try CNContactVCardSerialization.data(with: [contact])
            try vCardData.write(to: targetURL)
            print("联系人存储成功: \(fileName)")
            return fileName
        } catch {
            if (error as NSError).code == 516 {
                return fileName
            }
            print("联系人存储失败: \(fileName) - \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 实现：读取 vCard 文件为 CNContact 对象
    private func _getContact(from fileName: String) -> CNContact? {
        let contactURL = containerURL
            .appendingPathComponent("Contacts")
            .appendingPathComponent(fileName)
        
        guard fileManager.fileExists(atPath: contactURL.path) else {
            print("联系人文件不存在: \(fileName)")
            return nil
        }
        
        do {
            let vCardData = try Data(contentsOf: contactURL)
            let contacts = try CNContactVCardSerialization.contacts(with: vCardData)
            return contacts.first
        } catch {
            print("读取联系人失败: \(fileName) - \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 实现：获取指定文件夹下所有文件名
    private func _getAllFileNames(in folderName: String) -> [String] {
        let targetDirectory = containerURL.appendingPathComponent(folderName)
        
        guard fileManager.fileExists(atPath: targetDirectory.path) else {
            print("文件夹不存在: \(folderName)")
            return []
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: targetDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            
            return contents.map { $0.lastPathComponent }
        } catch {
            print("获取文件列表失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 实现：获取指定文件的大小（字节）
    private func _getFileSize(fileName: String, in folderName: String) -> Int64? {
        let fileURL = containerURL
            .appendingPathComponent(folderName)
            .appendingPathComponent(fileName)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            return attributes[.size] as? Int64
        } catch {
            print("获取文件大小失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 实现：获取指定目录的文件数量、文件夹数量和总大小
    private func _getDirectoryInfo(for folderName: String) -> (fileCount: Int, folderCount: Int, totalSize: Int64)? {
        let targetDirectory = containerURL.appendingPathComponent(folderName)
        
        guard fileManager.fileExists(atPath: targetDirectory.path) else {
            return nil
        }
        
        var fileCount = 0
        var folderCount = 0
        var totalSize: Int64 = 0
        
        if let enumerator = fileManager.enumerator(
            at: targetDirectory,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                    
                    if let isDirectory = resourceValues.isDirectory {
                        if isDirectory {
                            folderCount += 1
                        } else {
                            fileCount += 1
                            totalSize += Int64(resourceValues.fileSize ?? 0)
                        }
                    }
                } catch {
                    print("获取文件信息失败: \(fileURL.lastPathComponent)")
                }
            }
        }
        
        return (fileCount, folderCount, totalSize)
    }
}


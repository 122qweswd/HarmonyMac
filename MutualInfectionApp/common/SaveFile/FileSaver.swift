//
//  FileSaver.swift
//  MutualInfectionApp
//
//  Created by mac on 2025/8/25.
//
import Photos

class FileSaver {
    
    static var docPath: String?
    
    // 获取文档文件路径
    static func getFileURL(fileName: String, at directory: String) -> String? {
        let fileManager = FileManager.default
        let fileExtension = (fileName as NSString).pathExtension
        let originalName = (fileName as NSString).deletingPathExtension
        
        // 生成唯一文件名
        var targetPath = "\(directory)/\(fileName)"
        var counter = fileSameNameSuffix
        
        while fileManager.fileExists(atPath: targetPath) {
            let newName = "\(originalName)(\(counter))"
            if fileExtension.count > 0 {
                targetPath = "\(directory)/\(newName).\(fileExtension)"
            } else {
                targetPath = "\(directory)/\(newName)"
            }
            counter += fileSameNameInterval
        }
        
        return targetPath
    }
    
    // 获取临时文件路径
    static func getTempFileURL(fileName: String) -> String? {
        if self.docPath == nil {
            self.docPath = FileManager.default.urls(for: .documentDirectory,
                                                    in: .userDomainMask).first?.path ?? ""
        }
        let tempPath = "\(self.docPath ?? "")/temp/\(SaveFileHandler.shared.tempSubDir ?? "sub")"
        let fileManager = FileManager.default
        let fileExtension = (fileName as NSString).pathExtension
        let originalName = (fileName as NSString).deletingPathExtension
        // 生成唯一文件名
        var targetPath = "\(tempPath)/\(fileName)"
        var counter = fileSameNameSuffix
        
        while fileManager.fileExists(atPath: targetPath) {
            let newName = "\(originalName)(\(counter))"
            targetPath = "\(tempPath)/\(newName).\(fileExtension)"
            counter += fileSameNameInterval
        }
        
        return targetPath
    }
    
    //取最后两级目录
    static func getListTwoComponents(from path: String) -> String? {
        let nsPath = path as NSString
        let components = nsPath.pathComponents
        
        //确保有两级目录
        guard components.count >= 2 else {
            return nil
        }
        
        //获取最后两级目录
        let lastTwo = Array(components.suffix(2))
        
        //组装成一个地址
        let result = NSString.path(withComponents: lastTwo)
        return result
    }
    
    //删除文件夹
    static func removeFolder(atPath folderPath: String, notEmpty: Bool) {
        //不能删除根目录temp
        if (folderPath as NSString).lastPathComponent == "temp" {
            return
        }
        let fileManager = FileManager.default
        var isDri: ObjCBool = false
        let pathExists = fileManager.fileExists(atPath: folderPath, isDirectory: &isDri)
        
        guard pathExists, isDri.boolValue else {
            ShareAPI.shared().log(3, "[SaveFile] [FileSaver] 路径不存在或不是一个文件夹")
            return
        }
        
        do {
            //必须保证文件夹下不能为空才能删除
            if notEmpty {
                let contents = try fileManager.contentsOfDirectory(atPath: folderPath)
                if contents.isEmpty {
                    try fileManager.removeItem(atPath: folderPath)
                    ShareAPI.shared().log(3, "[SaveFile] [FileSaver] 删除文件夹成功.\(folderPath)")
                } else {
                    ShareAPI.shared().log(3, "[SaveFile] [FileSaver] 删除文件夹失败, 存在未落盘内容。")
                }
            } else {
                try fileManager.removeItem(atPath: folderPath)
                ShareAPI.shared().log(3, "[SaveFile] [FileSaver] 删除文件夹成功.\(folderPath)")
            }
        } catch {
            ShareAPI.shared().log(3, "[SaveFile] [FileSaver] 删除文件夹失败\(error.localizedDescription)")
        }
    }
    
    //临时文件清理 默认为24小时
    static func cleanupSimulatedTempDirectory(maxAge: TimeInterval = 86400) {
        if self.docPath == nil {
            self.docPath = FileManager.default.urls(for: .documentDirectory,
                                                    in: .userDomainMask).first?.path
        }
        let tempDir = URL(fileURLWithPath: self.docPath ?? "").appendingPathComponent("temp", isDirectory: true)
        do {
            let directoryContents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: [.contentModificationDateKey], options: [])
            let now = Date()
            
            for fileURL in directoryContents {
                let resourceValues = try fileURL.resourceValues(forKeys: [.contentModificationDateKey])
                if let modData = resourceValues.contentModificationDate {
                    //检查修改时间是否超过存活时间
                    if now.timeIntervalSince(modData) > maxAge {
                        try FileManager.default.removeItem(at: fileURL)
                        ShareAPI.shared().log(1, "[SaveFile] [FileSaver] 已删除过期文件：\(fileURL.lastPathComponent)")
                    }
                }
            }
        } catch {
            ShareAPI.shared().log(3, "[SaveFile] [FileSaver] 清理文件时出错：\(error.localizedDescription)")
        }
    }

    // MARK: 获取互传文件夹路径
    static func getFileDirectory(_ subDirectory: String) -> String? {
        let fileManager = FileManager.default
        if self.docPath == nil {
            self.docPath = fileManager.urls(for: .documentDirectory,
                                            in: .userDomainMask).first?.path
        }
        //
        let tempDirectiry = "\(self.docPath ?? "")/\(subDirectory)"
        if !fileManager.fileExists(atPath: tempDirectiry) {
            do {
                try fileManager.createDirectory(at: URL(fileURLWithPath: tempDirectiry), withIntermediateDirectories: true, attributes: nil)
                ShareAPI.shared().log(1, "[SaveFile] [FileSaver] \(subDirectory) 文件夹创建成功: \(tempDirectiry)")
            } catch {
                ShareAPI.shared().log(3, "[SaveFile] [FileSaver] 创建 \(subDirectory) 文件夹失败: \(error.localizedDescription)")
                return nil
            }
        }
        return tempDirectiry
    }
    
    //删除文件夹
    static func deleteFolder(_ path: String) {
        do {
            try FileManager.default.removeItem(atPath: path)
            ShareAPI.shared().log(1, "[SaveFile] [FileSaver] 文件夹删除成功\(path) ")
        } catch {
            ShareAPI.shared().log(3, "[SaveFile] [FileSaver] 文件夹删除失败\(error.localizedDescription)")
        }
    }
    
    //获取文件创建时间
    static func getFileCreationDate(from path: String) -> Date? {
        let fileManager = FileManager.default
        do {
            let attributes = try fileManager.attributesOfItem(atPath: path)
            return attributes[.creationDate] as? Date
        } catch {
            ShareAPI.shared().log(3, "[SaveFile] [FileSaver] 获取文件属性失败\(error.localizedDescription)")
            return nil
        }
    }
    
    //生成唯一文件路径
    static func uniqueFilePath(for path: String, fileManager: FileManager) -> String {
        let fileExtension = (path as NSString).pathExtension
        let fileName = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        
        var newPath = path
        var index = 1
        
        while fileManager.fileExists(atPath: newPath) {
            let newFileName = "\(fileName)(\(index))"
            newPath = "\((path as NSString).deletingLastPathComponent)/\(newFileName).\(fileExtension)"
            index += 1
        }
        
        return newPath
    }
    
    //获取文件大小
    static func getFileSize(atPath path: String) -> Int64 {
        guard FileManager.default.fileExists(atPath: path) else {
            return 0
        }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    /// 获取文件创建时间的毫秒值
    static func getCreationTimeMillis(atPath path: String) -> Int64? {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: path) else {
            print("文件不存在: \(path)")
            return nil
        }
        
        do {
            // 获取文件属性
            let attributes = try fileManager.attributesOfItem(atPath: path)
            
            // 获取创建日期
            guard let creationDate = attributes[.creationDate] as? Date else {
                print("无法获取创建日期")
                return nil
            }
            
            // 转换为毫秒（自1970年1月1日起）
            let milliseconds = Int64(creationDate.timeIntervalSince1970 * 1000)
            return milliseconds
            
        } catch {
            print("获取文件属性失败: \(error)")
            return nil
        }
    }
    
    /// 获取 PHAsset 创建时间的毫秒值（最直接的方法）
    static func getCreationTimeMillis(for asset: PHAsset) -> Int64? {
       // 获取 PHAsset 的创建日期
       guard let creationDate = asset.creationDate else {
           print("PHAsset 没有创建日期")
           return nil
       }
       
       // 转换为毫秒（自 1970-01-01 00:00:00 UTC 起）
       let milliseconds = Int64(creationDate.timeIntervalSince1970 * 1000)
       return milliseconds
    }
}

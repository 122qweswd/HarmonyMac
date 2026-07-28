//
//  FileSaver+Mac.swift
//  MutualInfection
//
//  Created by apple on 2025/11/25.
//

extension FileSaver {
    // MARK: 获取下载文件夹路径
    static func getMacDownloadsDirectory(_ subDirectory: String) -> String? {
        let fileManager = FileManager.default
        let docPath = fileManager.urls(for: .downloadsDirectory,
                                        in: .userDomainMask).first?.path
        var tempDirectiry = "\(docPath ?? "")"
        if subDirectory.count > 0 {
            tempDirectiry = "\(docPath ?? "")/\(subDirectory)"
        }
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
}

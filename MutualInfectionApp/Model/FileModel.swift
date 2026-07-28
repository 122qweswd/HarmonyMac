//
//  FileModel.swift
//  MutualInfection
//
//  Created by mac on 2025/9/4.
//

// MARK: 文件夹类型
enum FileDirectoryType: String {
    case image = "image"
    case music = "music"
    case doc = "doc"
    case contact = "contact"
    case calender = "calender"
    case zip = "zip"
    case others = "others"
    case mlx = "mlx"
}

struct FileModel {
    var name: String = ""        // 文件名
    var type: String = ""          // 文件类型
    var size: String = ""          // 格式化的文件大小
    var sizeInBytes: Int64 = 0    // 字节数
    var creationDate: Date = Date()    // 创建日期
    var modificationDate: Date = Date() // 修改日期
    var url: URL = URL(fileURLWithPath: "")              // 文件URL
    var systemFileNumber: Int64 = 0 //文件系统的文件编号
    var isMediaType: Bool = false //是否为媒体类型
    var isVideoType: Bool = false //是否为视频类型
    var isImageType: Bool = false //是否为图片类型
}

// 文件类型枚举
enum FileType {
    case file
    case folder
}

// 文件信息模型
struct FileItem: Equatable {
    let url: URL
    let name: String //文件名
    let type: FileType //文件还是文件夹
    let fileSize: UInt64  // 字节数
    let creationDate: Date? // 创建日期
    let modificationDate: Date? // 修改日期
    let parentPath: String  // 父路径，用于显示层级
    let systemFileNumber: Int? //文件系统的文件编号
    // 实现Equatable协议
    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        return lhs.url == rhs.url
    }
    
    // 格式化文件大小显示
    var fileSizeDescription: String {
        guard type == .file else { return "N/A" }
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileSize))
    }
    
    // 格式化日期显示
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "未知" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // 创建日期格式化
    var creationDateDescription: String {
        formatDate(creationDate)
    }
    
    // 修改日期格式化
    var modificationDateDescription: String {
        formatDate(modificationDate)
    }
}

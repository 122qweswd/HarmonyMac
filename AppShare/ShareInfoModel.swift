//
//  ShareInfoModel.swift
//  MutualInfection
//
//  Created by Niko on 2025/10/14.
//

import Foundation
#if SHARE_EXTENSION
import MobileCoreServices
#endif

enum PhtotoType: Codable {
    case image
    case movie
    case livePhoto
}

enum NoneType {
    case none
    case text
    case url
}

enum ShareFileType: Codable {
    /// 未知类型（暂不支持未知类型）
    case none
    case file
    case photo(PhtotoType)
    case contact
        
    static func getShareFileType(provider: NSItemProvider) -> ShareFileType {
        if provider.isFileType {
            return .file
        } else if provider.isLivePhoto {
            return .photo(.livePhoto)
        } else if provider.isImageType {
            return .photo(.image)
        } else if provider.isMovie {
            return .photo(.movie)
        } else if provider.isVCardType {
            return .contact
        } else {
            return .none
        }
    }
}

extension ShareFileType: Equatable  {
    // MARK: - 扩展 Equatable 协议
    static func == (lhs: ShareFileType, rhs: ShareFileType) -> Bool {
        switch (lhs, rhs) {
            case (.none, .none):
                return true
            case (.file, .file):
                return true
            case (.contact, .contact):
                return true
            case (.photo(let lhsType), .photo(let rhsType)):
                return lhsType == rhsType
            default:
                return false
        }
    }
}

class ShareInfoModel: Codable, @unchecked Sendable {
    
    /// 总数
    var totalCount: String { "\(fileInfos.count)" }
    /// 照片总数量
    var photoCount: String { "\(fileInfos.filter { $0.fileType == .photo(.image) || $0.fileType == .photo(.livePhoto) }.count)" }
    /// 视频总数量
    var videoCount: String { "\(fileInfos.filter { $0.fileType == .photo(.movie) }.count)" }
    /// 文件总数
    var fileCount: String { "\(fileInfos.filter { $0.fileType == .file }.count)" }
    /// 联系人总数
    var contactCount: String { "\(fileInfos.filter { $0.fileType == .contact }.count)" }
    /// 总大小
    var totalSize: String { "\(fileInfos.map { $0.fileSize }.reduce(0, +))" }
    /// 路径
    var fileInfos: [ShareFileInfModel] = []
}

class ShareFileInfModel: Codable, @unchecked Sendable {
    /// 文件名
    var fileName: String = ""
    /// 文件实际类型
    var fileType: ShareFileType = .none
    /// 路径
    var _filePath: String?
    var filePath: String {
        set {
            _filePath = newValue
        }
        get {
            if let newFilePath = _filePath, fileType == .photo(.livePhoto) {
                return newFilePath
            } else {
                return GroupFileManager.getFileURLInSharedContainer(fileName: fileName)?.path ?? ""
            }
        }
    }
    
    /// 文件大小
    var fileSize: Int64 = 0
    /// 类型
    var identifier: String = ""
    
    /// 错误信息，用于调试时显示错误信息
    var errorMessage: String?
    
    var isImageType: Bool = false
    var isVideoType: Bool = false
    
}

// 保存和读取的扩展
extension UserDefaults {
    private enum Keys {
        static let shareInfo = "kShareExtensionInfoModel"
    }
    
    func saveShareInfo(_ model: ShareInfoModel) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(model)
            set(data, forKey: Keys.shareInfo)
        } catch {
            print("保存失败: \(error)")
        }
    }
    
    func loadShareInfo() -> ShareInfoModel? {
        guard let data = data(forKey: Keys.shareInfo) else { return nil }
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(ShareInfoModel.self, from: data)
        } catch {
            print("读取失败: \(error)")
            return nil
        }
    }
}



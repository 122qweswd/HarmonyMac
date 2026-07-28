//
//  MITransferRecord.swift
//  MutualInfection
//
//  Created by Niko on 2025/9/23.
//

import Foundation
import WCDBSwift

// MARK: - 传输状态枚举
/// 传输（文件）当前的状态，后续可以继续扩展更多状态
enum TransferStatus: Int, Codable, WCDBSwift.ColumnCodable {
    /// 失败
    case failure = 0
    /// 成功
    case success = 1
    /// 进行中（图片未录盘）
    case inProgress = 2
    
    static var columnType: WCDBSwift.ColumnType = .integer32
    
    init?(with value: WCDBSwift.Value) {
        self.init(rawValue: value.intValue)
    }
    
    func archivedValue() -> WCDBSwift.Value {
        return Value(self.rawValue)
    }
}

// MARK: - 传输方向：发送或接收
/// 采用 Int rawValue（和数据库兼容）来存储，便于做查询/排序
enum MITransferType: Int, Codable, WCDBSwift.ColumnCodable {
    /// 全部
    case all = -1
    /// 发送
    case send = 0
    /// 接收
    case receive = 1
    static var columnType: WCDBSwift.ColumnType = .integer32
    
    init?(with value: WCDBSwift.Value) {
        self.init(rawValue: value.intValue)
    }
    
    func archivedValue() -> WCDBSwift.Value {
        return Value(self.rawValue)
    }
    
    /// 数据库查询条件
    var wcdbCondition: Condition {
        switch self {
            case .all:
                return MITransferRecord.Properties.transferType == MITransferType.send.rawValue ||
                MITransferRecord.Properties.transferType == MITransferType.receive.rawValue
            default:
                return MITransferRecord.Properties.transferType == self.rawValue
        }
    }
}

//-1 位置 0 照片/视频  3文件  8通讯录
enum MIFileType: Int, Codable, WCDBSwift.ColumnCodable {
    /// 位置
    case location = -1
    /// 照片视频
    case photoAndVideo = 0
    /// 文件
    case file = 3
    /// 通讯录
    case contacts = 8
    
    static var columnType: WCDBSwift.ColumnType = .integer32
    
    init?(with value: WCDBSwift.Value) {
        self.init(rawValue: value.intValue)
    }
    
    func archivedValue() -> WCDBSwift.Value {
        return Value(self.rawValue)
    }
}

// MARK: - 外层表：传输记录
final class MITransferRecord: TableCodable, Equatable, @unchecked Sendable {
    static func == (lhs: MITransferRecord, rhs: MITransferRecord) -> Bool {
        if let lhsId = lhs.id, let rhsId = rhs.id {
            return lhsId == rhsId
        } else if let rhsFoldName = rhs.foldName, let lhsFoldName = lhs.foldName {
            return rhsFoldName == lhsFoldName
        } else {
            return lhs.id == rhs.id
        }
    }
    
    /// 主键
    var id: Int64?
    
    /// 头像（不知道这里要存啥，先用字符串待定）
    var deviceIcon: String?
    
    /// 设备id
    var deviceId: String?
    var hwId:String?
    /// 设备型号，例如 "mate70"
    var deviceName: String?
    var deviceType: Int?
    /// 传输类型：发送或接收
    var transferType: MITransferType?
    /// 文件夹名称
    var foldName: String?
    
    /// 发送/接收时间
    var transferTime: Date?
    var transferTimeStr: String? {
        get {
            transferTime?.toString(format: .yyyyMMddHHmmss)
        }
    }
    
    /// 本条记录的总大小（字节）(数据库内部会通过子数据重新计算)
    var totalSize: Int64 { sendContent.reduce(0) { $0 + ($1.fileSize ?? 0) } }
    
    /// 关联的内层文件列表（不映射到数据库）
    var sendContent: [MITransferFile] = []

    var lastInsertedRowID: Int64 = 0
    var isAutoIncrement: Bool { true }
    
    /// 选中状态
    var isSelect: Bool = false
    
    /// 是否展开
    var isShow: Bool = true
    
    /// 导入进度
    var progress: Int {
        /// 接收
        if transferType == .receive && !sendContent.isEmpty {
            let saveList = sendContent.filter { $0.status != .inProgress }
            return saveList.count * 100 / sendContent.count
        }
        
        return 100
    }
    
    // MARK: - WCDB 映射
    enum CodingKeys: String, CodingTableKey {
        typealias Root = MITransferRecord
        static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(id, isPrimary: true)
        }

        case id //
        case deviceIcon // 头像
        case deviceId // 设备id
        case hwId // H用户id
        case deviceName // 设备型号，例如 "mate70"
        case deviceType // 设备类型
        case transferType // 传输方向：发送或接收
        case transferTime // 发送/接收时间
    }
}

// MARK: - 内层表：传输文件
final class MITransferFile: TableCodable, Equatable, @unchecked Sendable {
    
    
    /// 主键
    var id: Int64?
    
    /// 外键：关联 MITransferRecord.id
    var recordId: Int64 = -1
    
    /// 文件名
    var fileName: String?
    
    /// 文件类型(-1 位置 0 照片/视频  3文件  8通讯录)
    var fileType: MIFileType?
    
    /// 落盘文件夹
    var fileFolder: String?
    
    /// 扩展名
    var fileExtension: String?
    
    /// 文件大小（字节）
    var fileSize: Int64?
    
    /// 文件相对路径
    var fileUrl: String?
    /// 文件绝对路径
    var absoluteFileUrl: String? { (fileUrl?.isEmpty ?? true) ? nil : NSHomeDirectory() + fileUrl! }
    
    /// 标识符：PHAsset.localIdentifier / ABRecord.recordID 等
    var identifier: String?
    
    /// 传输状态
    var status: TransferStatus?

    /// 传输类型：发送或接收
    var transferType: MITransferType?
    
    /// 选中状态
    var isSelect: Bool = false
    
    /// 未落盘，禁用
    var isDisable: Bool { transferType == .receive && status != .success }
    
    var lastInsertedRowID: Int64 = 0
    var isAutoIncrement: Bool { true }
    
    /// mac 落盘是否保存到相册中
    var isSavePhotoLibraryForMac: Bool = false
    
    /// 缩略图
    var thumbnailImageData: Data?
    /// 用于缩略图判断的字符串id
    var thumbnailImageCheckId: String = ""
    /// 缩略图文件相对路径
    var thumbnailImageFilePath: String?
    /// 是否请求过缩略图
    var haveRequestThumbnailImageData: Bool = false
    
    // MARK: - WCDB 映射
    enum CodingKeys: String, CodingTableKey {
        typealias Root = MITransferFile
        static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(id, isPrimary: true)
            BindColumnConstraint(recordId, isNotNull: true)
        }

        case id
        case recordId
        case transferType
        case identifier
        case status
        case fileName
        case fileType
        case fileSize
        case fileUrl
        case fileFolder
        case fileExtension
        case isSavePhotoLibraryForMac
        case thumbnailImageData
        case thumbnailImageCheckId
        case thumbnailImageFilePath
        case haveRequestThumbnailImageData
    }
    
    static func == (lhs: MITransferFile, rhs: MITransferFile) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - 扩展：格式化工具
extension Int64 {
    func formattedFileSize() -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: self)
    }
}

//
//  MIWCDBManager.swift
//  MutualInfection
//
//  Created by Niko on 2025/9/23.
//

import Foundation
import WCDBSwift
#if MAIN_APP
import XXPhotoPicker
#endif

// MARK: - WCDB Repository 单例封装
// MARK: - 数据库变化通知
extension Notification.Name {
    /// 互传记录已更改通知
    static let MIWCDBRecordsInsert = Notification.Name("MIWCDBRecordsInsert")
    /// 数据库删除某数据
    static let MIWCDBRecordsDelete = Notification.Name("MIWCDBRecordsDelete")
    /// 状态更新
    static let MIWCDBRecordsUpdate = Notification.Name("MIWCDBRecordsUpdate")
}

struct NotificationParamKey {
    static let deleteIds = "deleteIds"
    static let deleteRecordList = "deleteRecordList"
    static let updateRecordList = "updateRecordList"
    static let updateFildId = "updateFildId"
    static let identifier = "identifier"
    static let status = "status"
    static let fileType = "fileType"
    static let fileUrl = "fileUrl"
    
}

// MARK: - WCDB Repository 单例封装
final class MIWCDBManager: @unchecked Sendable {
    
    // 单例实例
    static let shared = MIWCDBManager()
    
    // WCDB 数据库对象
    private let database: Database
    
    // 第一层表名（常量）
    private let recordTable = "NewMITransferRecord"
    // 第二层表名（常量）
    private let fileTable   = "NewMITransferFile"
    
    // 私有初始化：创建数据库连接并建立表
    private init() {
#if DEBUG
        let documents = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? NSTemporaryDirectory()
#else
        let documents = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first ?? NSTemporaryDirectory()
#endif
        let dbPath = (documents as NSString).appendingPathComponent("鸿蒙星河互联.db")
        
        self.database = Database(at: dbPath)
        
        do {
            try database.create(table: recordTable, of: MITransferRecord.self)
            try database.create(table: fileTable, of: MITransferFile.self)
        } catch {
            ShareAPI.shared().startLogging("WCDB: create tables error -> \(error)")
            print("WCDB: create tables error -> \(error)")
        }
    }
    
    /// 数据库有新增数据，通知外部获取最新数据。
    private func postRecordsInsertNotification() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .MIWCDBRecordsInsert, object: nil)
        }
    }
}


// MARK: - 查（按时间分组查）
extension MIWCDBManager {
    
    /// 通过主键查询互传记录
    /// - Parameters:
    ///   - id: 主键id
    /// - Returns: 互换记录
    func getRecord(byId id: Int64) throws -> MITransferRecord? {
        return try database.getObject(
            fromTable: recordTable,
            where: MITransferRecord.Properties.id == id)
    }
    
    /// 通过主键查询互传记录和对应文件
    /// - Parameters:
    ///   - id: 主键id
    ///   - sortType: 排序类型，默认降序
    /// - Returns: 互换记录
    func getRecord(byId id: Int64, sortType: ConfigSortType = .descending, isShowLoading: Bool = false) throws -> MITransferRecord? {
        let records: [MITransferRecord] = try database.getObjects(
            fromTable: recordTable,
            where: MITransferRecord.Properties.id == id
        )
        guard let record = records.first else { return nil }
        
        isShowLoading ? MIWCDBManager.showLoading() : nil
        
        // 查询关联的文件，按id降序排列（最近的文件在前）
        let files: [MITransferFile] = try database.getObjects(
            fromTable: fileTable,
            where: MITransferFile.Properties.recordId == id,
            orderBy: [MITransferFile.Properties.id.order(sortType.wcdbOrder)]
        )
        record.sendContent = files
        
        isShowLoading ? MIWCDBManager.dismissLoading() : nil
        
        return record
    }
    
    
    
    /// 按时间排序查询所有互传记录及其文件
    /// - Parameters:
    ///   - transferType: 传输类型
    ///   - sortType: 排序 默认降序
    /// - Returns: 互传记录及其文件
    func getAllRecords(transferType: MITransferType, sortByTime: ConfigSortType = .descending, includeFiles: Bool = true, isShowLoading: Bool = false) throws -> [MITransferRecord] {
        /// 查出所有第一层，按id降序排列
        
        isShowLoading ? MIWCDBManager.showLoading() : nil
        
        let records: [MITransferRecord] = try database.getObjects(
            fromTable: recordTable,
            where: transferType.wcdbCondition,
            orderBy: [MITransferRecord.Properties.id.order(sortByTime.wcdbOrder)]
        )
        
        if records.isEmpty { return [] }
        
        /// 是否查询包含的子文件
        if includeFiles {
            /// 获取当前页记录的所有id
            let recordIds = records.compactMap { $0.id }
            
            /// 查出所有第二层，按id降序排列
            let allFiles: [MITransferFile] = try database.getObjects(
                fromTable: fileTable,
                where: MITransferFile.Properties.recordId.in(recordIds),
                orderBy: [MITransferFile.Properties.id.order(sortByTime.wcdbOrder)]
            )
            
            /// 组装成Map
            var map = [Int64: [MITransferFile]]()
            for file in allFiles {
                var arr = map[file.recordId] ?? []
                arr.append(file)
                map[file.recordId] = arr
            }
            
            for i in 0..<records.count {
                let recordId = records[i].id
                // 每个记录的文件列表也保持降序排列
                records[i].sendContent = map[recordId ?? -1] ?? []
            }
        }
        
        isShowLoading ? MIWCDBManager.dismissLoading() : nil
        return records
    }
    
    /// 分页查询第一层记录（按存储顺序由近到远）
    /// - Parameters:
    ///   - page: 页码（从1开始）
    ///   - pageSize: 每页记录数
    /// - Returns: 当前页的记录数组
    func getRecords(page: Int, pageSize: Int = 10, transferType: MITransferType, sortType: ConfigSortType = .descending) throws -> [MITransferRecord] {
        let offset = (page - 1) * pageSize
        
        /// 分页查询第一层记录，按id降序排列
        let records: [MITransferRecord] = try database.getObjects(
            fromTable: recordTable,
            where: transferType.wcdbCondition,
            orderBy: [MITransferRecord.Properties.id.order(sortType.wcdbOrder)],
            limit: pageSize,
            offset: offset
        )
        
        if records.isEmpty { return [] }
        
        /// 获取当前页记录的所有id
        let recordIds = records.compactMap { $0.id }
        
        /// 查询这些记录对应的所有文件，按id降序排列
        let allFiles: [MITransferFile] = try database.getObjects(fromTable: fileTable,
                                                                 where: MITransferFile.Properties.recordId.in(recordIds),
                                                                 orderBy: [MITransferFile.Properties.id.order(sortType.wcdbOrder)])
        
        /// 组装成Map
        var map = [Int64: [MITransferFile]]()
        for file in allFiles {
            var arr = map[file.recordId] ?? []
            arr.append(file)
            map[file.recordId] = arr
        }
        
        for i in 0..<records.count {
            let recordId = records[i].id
            // 每个记录的文件列表也保持降序排列
            records[i].sendContent = map[recordId ?? -1] ?? []
        }
        
        return records
    }
    
    /// 查询某个文件
    func getFile(byId fileId: Int64) throws -> MITransferFile? {
        let file: MITransferFile? = try database.getObject(
            fromTable: fileTable,
            where: MITransferFile.Properties.id == fileId,
            orderBy: [MITransferFile.Properties.id.order(.descending)]
        )
        return file
    }
    
    /// 查询某个一层下包含的所有二层文件（按存储顺序由近到远）
    func getFiles(forRecordId recordId: Int64, isShowLoading: Bool = false) throws -> [MITransferFile] {
        
        isShowLoading ? MIWCDBManager.showLoading() : nil
        
        let files: [MITransferFile] = try database.getObjects(
            fromTable: fileTable,
            where: MITransferFile.Properties.recordId == recordId,
            orderBy: [MITransferFile.Properties.id.order(.descending)]
        )
        isShowLoading ? MIWCDBManager.dismissLoading() : nil
        
        return files
    }
    
    /// 查询某个一层下的文件数量(如果不传，查全部)
    func getFileCount(forRecordId recordId: Int? = nil, transferType: MITransferType = .all) throws -> Int {
        if let recordId = recordId {
            let count = try database.getValue(on: MITransferFile.Properties.id.count(),
                                              fromTable: fileTable,
                                              where: MITransferFile.Properties.recordId == recordId)
            return Int(count.int32Value)
        } else {
            /// 查询全部
            let count = try database.getValue(on: MITransferFile.Properties.id.count(),
                                              fromTable: fileTable,
                                              where: transferType.wcdbCondition)
            return Int(count.int32Value)
        }
    }
}

// MARK: - 查（按类型排序查）
extension MIWCDBManager {
    
    /// 查询所有文件夹（去重）
    /// - Parameters:
    ///   - transferType: 传输类型
    ///   - isShowLoading: 是否显示loading
    /// - Returns: 包含文件夹名称的MITransferRecord数组
    func getAllFolders(transferType: MITransferType, sortType: ConfigSortType = .descending, isShowLoading: Bool = false) throws -> [MITransferRecord] {
        isShowLoading ? MIWCDBManager.showLoading() : nil
        
        // 使用 DISTINCT 查询去重的文件夹名称
        let distinctFolders = try database.getDistinctColumn(
            on: MITransferFile.Properties.fileFolder,
            fromTable: fileTable,
            where: MITransferFile.Properties.fileFolder.isNotNull() && transferType.wcdbCondition,
            orderBy: [MITransferFile.Properties.fileFolder.order(sortType.wcdbOrder)])//  as? [MITransferRecord]
        
        var folders: [MITransferRecord] = []
        // 构建MITransferRecord对象数组
        for value in distinctFolders {
            let record = MITransferRecord()
            record.foldName = value.stringValue
            folders.append(record)
        }
        
        isShowLoading ? MIWCDBManager.dismissLoading() : nil
        return folders
    }
    
    /// 查询指定文件夹下的所有文件，按扩展名排序
    /// - Parameters:
    ///   - folderName: 文件夹名称
    ///   - transferType: 传输类型
    ///   - extensionSort: 扩展名排序方式，默认升序
    ///   - isShowLoading: 是否显示loading
    /// - Returns: 指定文件夹下的文件数组
    func getFilesInFolder(_ folderName: String, transferType: MITransferType, extensionSort: ConfigSortType = .ascending, isShowLoading: Bool = false) throws -> [MITransferFile] {
        guard !folderName.isEmpty else { return [] }
        
        isShowLoading ? MIWCDBManager.showLoading() : nil
        
        let files: [MITransferFile] = try database.getObjects(
            fromTable: fileTable,
            where: MITransferFile.Properties.fileFolder == folderName && transferType.wcdbCondition,
            orderBy: [MITransferFile.Properties.fileExtension.order(extensionSort.wcdbOrder)]
        )
        
        isShowLoading ? MIWCDBManager.dismissLoading() : nil
        return files
    }
    
    /// 查询所有文件夹及其包含的文件
    /// - Parameters:
    ///   - transferType: 传输类型
    ///   - sortType: 扩展名排序方式，默认升序
    ///   - isShowLoading: 是否显示loading
    /// - Returns: 包含文件夹和文件的MITransferRecord数组
    func getAllFoldersWithFiles(transferType: MITransferType, sortType: ConfigSortType = .ascending, isShowLoading: Bool = false) throws -> [MITransferRecord] {
        isShowLoading ? MIWCDBManager.showLoading() : nil
        
        // 首先获取所有文件夹
        let folders = try getAllFolders(transferType: transferType, sortType: sortType)
        
        if folders.isEmpty {
            isShowLoading ? MIWCDBManager.dismissLoading() : nil
            return []
        }
        
        // 批量查询每个文件夹的文件
        var folderMap = [String: MITransferRecord]()
        for folder in folders {
            folderMap[folder.foldName ?? ""] = folder
        }
        
        // 查询所有有文件夹的文件，按文件夹和扩展名排序
        let allFiles: [MITransferFile] = try database.getObjects(
            fromTable: fileTable,
            where: MITransferFile.Properties.fileFolder.isNotNull() && transferType.wcdbCondition,
            orderBy: [
                MITransferFile.Properties.fileExtension.order(sortType.wcdbOrder),
                MITransferFile.Properties.fileFolder.order(.ascending)
            ]
        )
        
        // 按文件夹分组文件
        for file in allFiles {
            guard let folderName = file.fileFolder,
                  let folder = folderMap[folderName] else { continue }
            folder.sendContent.append(file)
        }
        
        isShowLoading ? MIWCDBManager.dismissLoading() : nil
        return folders
    }
    
    /// 按类型排序查询所有文件
    /// - Parameters:
    ///   - transferType: 传输类型
    ///   - sortType: 排序 默认降序
    /// - Returns: 互传记录及其文件
    func getAllFilesOrderedByType(transferType: MITransferType, sortByType: ConfigSortType = .descending, isShowLoading: Bool = false) throws -> [MITransferFile] {
        
        isShowLoading ? MIWCDBManager.showLoading() : nil
        
        let files: [MITransferFile] = try database.getObjects(
            fromTable: fileTable,
            where: transferType.wcdbCondition,
            orderBy: [MITransferFile.Properties.fileType.order(sortByType.wcdbOrder)]
        )
        
        isShowLoading ? MIWCDBManager.dismissLoading() : nil
        
        return files
    }
    
    /// 查询特定类型的文件，按文件类型排序
    /// - Parameters:
    ///   - transferType: 传输类型，默认查询所有类型
    ///   - fileTypes: 要查询的文件类型数组
    ///   - sortByType: 排序方式，默认降序
    /// - Returns: 特定类型的文件数组
    func getFilesByTypes(transferType: MITransferType, fileTypes: [MIFileType], sortByType: ConfigSortType = .descending, isShowLoading: Bool = false) throws -> [MITransferFile] {
        guard !fileTypes.isEmpty else {
            return try getAllFilesOrderedByType(transferType: transferType, sortByType: sortByType)
        }
        
        isShowLoading ? MIWCDBManager.showLoading() : nil
        // 执行查询
        let files: [MITransferFile] = try database.getObjects(
            fromTable: fileTable,
            where: MITransferFile.Properties.fileType.in(fileTypes.map { $0.rawValue }) && transferType.wcdbCondition,
            orderBy: [MITransferFile.Properties.fileType.order(sortByType.wcdbOrder)]
        )
        
        isShowLoading ? MIWCDBManager.dismissLoading() : nil
        
        return files
    }
    
    
    /// 查询所有文件，先按类型排序，再按文件大小排序
    /// - Parameters:
    ///   - transferType: 传输类型，默认查询所有类型
    ///   - sortByType: 按类型排序
    ///   - sizeOrder: 按大小排序
    /// - Returns: 多重排序的文件数组
    func getAllFilesOrderedByTypeAndSize(transferType: MITransferType, sortByType: ConfigSortType = .descending, sizeOrder: Order = .descending, isShowLoading: Bool = false) throws -> [MITransferFile] {
        isShowLoading ? MIWCDBManager.showLoading() : nil
        let files: [MITransferFile] = try database.getObjects(
            fromTable: fileTable,
            where: transferType.wcdbCondition,
            orderBy: [
                MITransferFile.Properties.fileType.order(sortByType.wcdbOrder),
                MITransferFile.Properties.fileSize.order(sizeOrder)
            ]
        )
        isShowLoading ? MIWCDBManager.dismissLoading() : nil
        return files
    }
    
    /// 查询所有文件，先按类型排序，再按创建时间排序
    /// - Parameters:
    ///   - transferType: 传输类型，默认查询所有类型
    ///   - sortByType: 类型排序方式
    ///   - sortByTime: 时间排序方式
    /// - Returns: 多重排序的文件数组
    func getAllFilesOrderedByTypeAndTime(transferType: MITransferType, sortByType: ConfigSortType = .descending, sortByTime: ConfigSortType = .descending, isShowLoading: Bool = false) throws -> [MITransferFile] {
        isShowLoading ? MIWCDBManager.showLoading() : nil
        let files: [MITransferFile] = try database.getObjects(
            fromTable: fileTable,
            where: transferType.wcdbCondition,
            orderBy: [
                MITransferFile.Properties.fileType.order(sortByType.wcdbOrder),
                MITransferFile.Properties.id.order(sortByTime.wcdbOrder)
            ]
        )
        isShowLoading ? MIWCDBManager.dismissLoading() : nil
        return files
    }
    
    // MARK: -  分页查询文件，按类型排序
    /// 分页查询文件，按类型排序
    /// - Parameters:
    ///   - page: 页码（从1开始）
    ///   - pageSize: 每页数量
    ///   - ascending: 是否升序排列
    /// - Returns: 当前页的文件数组
    func getFilesOrderedByType(page: Int, pageSize: Int = 10, transferType: MITransferType, sortByType: ConfigSortType = .descending) throws -> [MITransferFile] {
        let offset = (page - 1) * pageSize
        let files: [MITransferFile] = try database.getObjects(
            fromTable: fileTable,
            where: transferType.wcdbCondition,
            orderBy: [MITransferFile.Properties.fileType.order(sortByType.wcdbOrder)],
            limit: pageSize,
            offset: offset
        )
        
        return files
    }
    
    // MARK: -  模糊搜索分页查询文件，按时间排序
    /// 模糊搜索分页查询文件，按时间排序
    /// - Parameters:
    ///   - keyword: 关键字（可选，用于按文件名模糊搜索）
    ///   - page: 页码（从1开始）
    ///   - pageSize: 每页数量
    ///   - transferType: 传输类型
    ///   - sortByTime: 时间排序方式，默认降序
    /// - Returns: 当前页的文件数组
    func searchFiles(keyword: String? = nil, foldName: String? = nil, page: Int, pageSize: Int = 10, transferType: MITransferType, sortByTime: ConfigSortType = .descending) throws -> [MITransferFile] {
        
        guard let keyword = keyword, !keyword.isEmpty else { return [] }
        
        // 1. 转义用户输入，避免 % 和 _ 误匹配
        let escapedKeyword = wcdbEscapeKeyword(keyword)
        let likePattern = "%\(escapedKeyword)%"
        
        // 2. 构建 where 条件
        var whereCondition = MITransferFile.Properties.fileName.like(likePattern).escape("\\") && transferType.wcdbCondition
        
        if let foldName = foldName {
            whereCondition = MITransferFile.Properties.fileName.like("%\(keyword)%") && MITransferFile.Properties.fileFolder == foldName && transferType.wcdbCondition
        }
        
        let offset = (page - 1) * pageSize
        let files: [MITransferFile] = try database.getObjects(
            fromTable: fileTable,
            where: whereCondition,
            orderBy: [MITransferFile.Properties.id.order(sortByTime.wcdbOrder)],
            limit: pageSize,
            offset: offset
        )
        return files
    }
    
    /// 处理 LIKE 查询的关键字转义
    func wcdbEscapeKeyword(_ keyword: String) -> String {
        var escaped = keyword
        escaped = escaped.replacingOccurrences(of: "\\", with: "\\\\") // 转义反斜线
        escaped = escaped.replacingOccurrences(of: "%", with: "\\%")   // 转义 %
        escaped = escaped.replacingOccurrences(of: "_", with: "\\_")   // 转义 _
        return escaped
    }
    
    // MARK: -  查询所有未落盘文件
    /// 查询所有未落盘文件
    /// - Parameters:
    /// - Returns: 当前页的文件数组
    func getUnstoredDataFiles() -> [MITransferFile] {
        do {
            let files: [MITransferFile] = try database.getObjects(
                fromTable: fileTable,
                where: MITransferFile.Properties.status == 2 && MITransferType.receive.wcdbCondition && MITransferFile.Properties.fileType == MIFileType.photoAndVideo.rawValue
            )
            return files
        } catch {
            ShareAPI.shared().log(1, "\(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - 缩略图
    /// 查询所有未获取缩略图文件
    /// - Parameters:
    /// - Returns: 当前页的文件数组
    func getUnrequestThumbImageDataFiles() -> [MITransferFile] {
        do {
            let files: [MITransferFile] = try database.getObjects(
                fromTable: fileTable,
                where: MITransferFile.Properties.haveRequestThumbnailImageData == false
            )
            return files
        } catch {
            ShareAPI.shared().log(1, "getUnrequestThumbImageDataFiles: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 更新缩略图
    func updateFileThumbImageData(files: [MITransferFile]) {
        if files.count == 0 {
            return
        }
        
        do {
            try database.run(transaction: { [weak self] _ in
                guard let self = self else { return }

                for file in files {
                    try self.database.update(table: self.fileTable,
                                        on: [MITransferFile.Properties.thumbnailImageData, MITransferFile.Properties.haveRequestThumbnailImageData],
                                        with: [file.thumbnailImageData, file.haveRequestThumbnailImageData],
                                        where: MITransferFile.Properties.id == file.id ?? -1)
                }
            })
        } catch {
            ShareAPI.shared().log(1, "updateFileThumbImageData: \(error.localizedDescription)")
        }
    }
}


// MARK: - 增
extension MIWCDBManager {
    
    /// 插入第一层记录，可选地同时插入关联的第二层文件
    /// - Parameters:
    ///   - record: 互传记录存储模型
    ///   - includeFiles: 是否需要保存子文件，默认保存(暂时弃用)
    /// - Returns: 主键Id
    func insertRecord(_ record: MITransferRecord, includeFiles: Bool = true, isShowLoading: Bool = false) throws -> Int64 {
        
        assert(record.transferType == .send || record.transferType == .receive, "保存时的传输类型必须是发送或者接收")
        //assert(!record.sendContent.isEmpty, "互传记录缺少子文件")
        assert(includeFiles == true, "现在需求不支持只保存记录不保存文件")
        
        isShowLoading ? MIWCDBManager.showLoading() : nil
        
        try database.run(transaction: { [weak self] _ in
            guard let self = self else { return }
            
            try database.insert([record], intoTable: recordTable)
            
            if includeFiles, !record.sendContent.isEmpty {
                let filesToInsert = record.sendContent
                for i in 0..<filesToInsert.count {
                    filesToInsert[i].recordId = record.lastInsertedRowID
                    filesToInsert[i].transferType = record.transferType
                }
                try database.insert(filesToInsert, intoTable: fileTable)
            }
        })
        
        isShowLoading ? MIWCDBManager.dismissLoading() : nil
        
        postRecordsInsertNotification()
        
        return record.lastInsertedRowID
    }
    
    // MARK: - 第二层表 (MITransferFile)
    
    /// 插入单个文件
    /// - Parameter file: 需要插入的文件模型
    /// - Returns: 主键
    func insertFile(_ file: MITransferFile) throws -> Int64 {
        
        assert((file.recordId) > 0, "缺少互传记录Id，找不到是属于哪一条的文件")
        assert(file.transferType == .send || file.transferType == .receive, "保存时的传输类型必须是发送或者接收")
        
        try database.run(transaction: { [weak self] _ in
            guard let self = self else { return }
            
            try database.insert([file], intoTable: fileTable)
            
        })
        
        postRecordsInsertNotification()
        
        return file.lastInsertedRowID
    }
    
    
    /// 批量插入文件
    /// - Parameter files: 需要插入的文件数组
    func insertFiles(_ files: [MITransferFile], isShowLoading: Bool = false) throws {
        
        isShowLoading ? MIWCDBManager.showLoading() : nil
        
        if let file = files.first(where: { !($0.transferType == .send || $0.transferType == .receive) || $0.recordId <= 0 }) {
            assert(file.recordId > 0, "缺少互传记录Id，找不到是属于哪一条的文件")
            assert(file.transferType == .send || file.transferType == .receive, "保存时的传输类型必须是发送或者接收")
        }
        
        try database.insert(files, intoTable: fileTable)
        
        isShowLoading ? MIWCDBManager.dismissLoading() : nil
        
        postRecordsInsertNotification()
    }
}

// MARK: - 改
extension MIWCDBManager {
    // MARK: -  查询所有未落盘文件
    /// 更改落盘状态, 传输状态
    func updateFileStoredDataStatus(file: MITransferFile) {
        do {
            try database.update(table: fileTable,
                                on: [MITransferFile.Properties.identifier, MITransferFile.Properties.status],
                                with: [file.identifier, file.status],
                                where: MITransferFile.Properties.id == file.id ?? -1)
            NotificationCenter.default.post(name: .MIWCDBRecordsUpdate, object: nil, userInfo: [
                NotificationParamKey.updateFildId: file.id ?? -1,
                NotificationParamKey.status: file.status ?? TransferStatus.failure,
                NotificationParamKey.identifier: file.identifier ?? "-1"])
        } catch {
            
        }
    }
    
    func updateFileStoredDateFileUrl(file: MITransferFile) {
        do {
            try database.update(table: fileTable,
                                on: [MITransferFile.Properties.fileType, MITransferFile.Properties.status, MITransferFile.Properties.fileUrl, MITransferFile.Properties.fileFolder],
                                with: [file.fileType, file.status, file.fileUrl, file.fileFolder],
                                where: MITransferFile.Properties.id == file.id ?? -1)
            NotificationCenter.default.post(name: .MIWCDBRecordsUpdate, object: nil, userInfo: [
                NotificationParamKey.updateFildId: file.id ?? -1,
                NotificationParamKey.status: file.status ?? TransferStatus.success,
                NotificationParamKey.identifier: file.identifier ?? "-1",
                NotificationParamKey.fileType: file.fileType ?? .file,
                NotificationParamKey.fileUrl: file.fileUrl ?? ""
            ])
            
            /// 更新的数据有文件夹，直接刷新数据
            if !(file.fileFolder?.isEmpty ?? true) {
                postRecordsInsertNotification()
            }
            
        } catch {
            
        }
    }
}

// MARK: - 删
extension MIWCDBManager {
    
    /// 删除单个文件，并自动检查是否需要删除对应的第一层记录
    @discardableResult
    func deleteFile(byId id: Int64, isShowLoading: Bool = false) throws -> MITransferRecord? {
        var recordId: Int64 = 0
        
        isShowLoading ? MIWCDBManager.showLoading() : nil
        
        guard let file = try self.getFile(byId: id) else {
            throw NSError(domain: "Database", code: 404, userInfo: [NSLocalizedDescriptionKey: "文件不存在"])
        }
        
        recordId = file.recordId
        
        try database.delete(fromTable: fileTable, where: MITransferFile.Properties.id == id)
        
        /// 查询互传记录子文件
        let remainingFiles = try self.getFiles(forRecordId: recordId)
        
        /// 子文件为空
        if remainingFiles.isEmpty {
            /// 删除记录数据
            try database.delete(fromTable: recordTable, where: MITransferRecord.Properties.id == recordId)

            ShareAPI.shared().log(1, "✅ 自动删除空记录: recordId=\(recordId)")

        }
        
        isShowLoading ? MIWCDBManager.dismissLoading() : nil
        
        //postRecordsChangedNotification()
        
        return nil
    }
    
    /// 批量删除文件，并自动检查是否需要删除对应的第一层记录
    /// - Parameters:
    ///   - ids: 需要删除的文件id
    ///   - isShowLoading: 是否展示loading
    /// - Returns: (删除的记录，需要更新的记录)
    @discardableResult
    func deleteFiles(byIds ids: [Int64], isShowLoading: Bool = false) throws -> ([MITransferRecord], [MITransferRecord]) {
        guard !ids.isEmpty else { return ([], []) }
        
        isShowLoading ? MIWCDBManager.showLoading() : nil
        
        /// 保存所有文件对应的记录id
        var affectedRecordIds = Set<Int64>()
        
        /// (删除的记录，更新的记录)
        var resultRecords: ([MITransferRecord], [MITransferRecord]) = ([], [])
        
        for fileId in ids {
            if let file = try self.getFile(byId: fileId) {
                affectedRecordIds.insert(file.recordId)
            }
        }
        
        for fileId in ids {
            try database.delete(fromTable: fileTable, where: MITransferFile.Properties.id == fileId)
        }
        
        for recordId in affectedRecordIds {
            let remainingFiles = try self.getFiles(forRecordId: recordId)
            
            if remainingFiles.isEmpty {
                // 如果没有文件了，删除对应的第一层记录
                try database.delete(fromTable: recordTable, where: MITransferRecord.Properties.id == recordId)
                
                /// 将删除的第一层也返回
                let model = MITransferRecord()
                model.id = recordId
                resultRecords.0.append(model)
                ShareAPI.shared().log(1, "✅ 自动删除空记录: id = \(recordId)")
            } else {
                let model = MITransferRecord()
                model.id = recordId
                resultRecords.1.append(model)
            }
        }
        
        isShowLoading ? MIWCDBManager.dismissLoading() : nil
        
        NotificationCenter.default.post(name: .MIWCDBRecordsDelete, object: nil, userInfo: [
            NotificationParamKey.deleteIds: ids,
            NotificationParamKey.deleteRecordList: resultRecords.0,
            NotificationParamKey.updateRecordList: resultRecords.1
        ])
        
        return resultRecords
    }
    
    
    /// 清空数据
    /// - Parameter transferType: 传输类型，这里可以理解为删除类型，默认删除所有类型
    func deleteAllRecordsCascade(_ transferType: MITransferType = .all) throws {
        
        MIWCDBManager.showLoading()
        
        try database.delete(fromTable: fileTable,
                            where: transferType.wcdbCondition)
        try database.delete(fromTable: recordTable,
                            where: transferType.wcdbCondition)
        
        MIWCDBManager.dismissLoading()
        // 发送全部变化通知
        //postRecordsChangedNotification()
    }
}

// MARK: - Async/Await 封装
extension MIWCDBManager {
    /**
     异步获取指定主键ID的互传记录。
     - Parameter id: 互传记录的主键ID。
     - Returns: 匹配的 `MITransferRecord` 或 nil。
     - Throws: 数据库操作异常。
     */
    @discardableResult
    func getRecordAsync(byId id: Int64) async throws -> MITransferRecord? {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async { [weak self] in
                guard let self = self else { return }
                do {
                    let result = try self.getRecord(byId: id)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /**
     异步获取指定主键ID的互传记录及其文件，支持排序和loading。
     - Parameters:
     - id: 互传记录的主键ID。
     - sortType: 排序方式，默认降序。
     - isShowLoading: 是否显示loading。
     - Returns: 匹配的 `MITransferRecord` 或 nil。
     - Throws: 数据库操作异常。
     */
    @discardableResult
    func getRecordAsync(byId id: Int64, sortType: ConfigSortType = .descending, isShowLoading: Bool = false) async throws -> MITransferRecord? {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async { [weak self] in
                guard let self = self else { return }
                do {
                    let result = try self.getRecord(byId: id, sortType: sortType, isShowLoading: isShowLoading)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /**
     异步获取所有互传记录及其文件，按时间排序。
     - Parameters:
     - transferType: 传输类型。
     - sortByTime: 时间排序方式，默认降序。
     - isShowLoading: 是否显示loading。
     - Returns: 互传记录数组。
     - Throws: 数据库操作异常。
     */
    @discardableResult
    func getAllRecordsAsync(transferType: MITransferType, sortByTime: ConfigSortType = .descending, includeFiles: Bool = true, isShowLoading: Bool = false) async throws -> [MITransferRecord] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async { [weak self] in
                guard let self = self else { return }
                do {
                    let result = try self.getAllRecords(transferType: transferType, sortByTime: sortByTime, includeFiles: includeFiles, isShowLoading: isShowLoading)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /**
     异步分页查询互传记录。
     - Parameters:
     - page: 页码（从1开始）。
     - pageSize: 每页数量，默认10。
     - transferType: 传输类型。
     - sortType: 排序方式，默认降序。
     - Returns: 当前页的互传记录数组。
     - Throws: 数据库操作异常。
     */
    @discardableResult
    func getRecordsAsync(page: Int, pageSize: Int = 10, transferType: MITransferType, sortType: ConfigSortType = .descending) async throws -> [MITransferRecord] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async { [weak self] in
                guard let self = self else { return }
                do {
                    let result = try self.getRecords(page: page, pageSize: pageSize, transferType: transferType, sortType: sortType)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /**
     异步获取指定文件ID的文件信息。
     - Parameter fileId: 文件主键ID。
     - Returns: 匹配的 `MITransferFile` 或 nil。
     - Throws: 数据库操作异常。
     */
    @discardableResult
    func getFileAsync(byId fileId: Int64) async throws -> MITransferFile? {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async { [weak self] in
                guard let self = self else { return }
                do {
                    let result = try self.getFile(byId: fileId)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /**
     异步获取指定互传记录下的所有文件，按存储顺序排序。
     - Parameters:
     - recordId: 互传记录主键ID。
     - isShowLoading: 是否显示loading。
     - Returns: 文件数组。
     - Throws: 数据库操作异常。
     */
    @discardableResult
    func getFilesAsync(forRecordId recordId: Int64, isShowLoading: Bool = false) async throws -> [MITransferFile] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async { [weak self] in
                guard let self = self else { return }
                do {
                    let result = try self.getFiles(forRecordId: recordId, isShowLoading: isShowLoading)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /**
     异步获取指定互传记录下的文件数量。
     - Parameter recordId: 互传记录主键ID。
     - Returns: 文件数量。
     - Throws: 数据库操作异常。
     */
    @discardableResult
    func getFileCountAsync(forRecordId recordId: Int?) async throws -> Int {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async { [weak self] in
                guard let self = self else { return }
                do {
                    let result = try self.getFileCount(forRecordId: recordId)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 分页查询文件，按类型排序
    /// - Parameters:
    ///   - page: 页码（从1开始）
    ///   - pageSize: 每页数量
    ///   - ascending: 是否升序排列
    /// - Returns: 当前页的文件数组
    @discardableResult
    func getFilesOrderedByTypeAsync(page: Int, pageSize: Int = 10, transferType: MITransferType, sortByType: ConfigSortType = .descending) async throws -> [MITransferFile] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async { [weak self] in
                guard let self = self else { return }
                do {
                    let result = try self.getFilesOrderedByType(page: page, pageSize: pageSize, transferType: transferType, sortByType: sortByType)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /**
     异步插入互传记录及其文件。
     - Parameters:
     - record: 互传记录。
     - includeFiles: 是否包含文件，默认true。
     - isShowLoading: 是否显示loading。
     - Returns: 插入的记录主键ID。
     - Throws: 数据库操作异常。
     */
    @discardableResult
    func insertRecordAsync(_ record: MITransferRecord, includeFiles: Bool = true, isShowLoading: Bool = false) async throws -> Int64 {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async { [weak self] in
                guard let self = self else { return }
                do {
                    let result = try self.insertRecord(record, includeFiles: includeFiles, isShowLoading: isShowLoading)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /**
     异步插入单个文件。
     - Parameter file: 文件对象。
     - Returns: 插入的文件主键ID。
     - Throws: 数据库操作异常。
     */
    @discardableResult
    func insertFileAsync(_ file: MITransferFile) async throws -> Int64 {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async { [weak self] in
                guard let self = self else { return }
                do {
                    let result = try self.insertFile(file)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /**
     异步批量插入文件。
     - Parameters:
     - files: 文件数组。
     - isShowLoading: 是否显示loading。
     - Throws: 数据库操作异常。
     */
    func insertFilesAsync(_ files: [MITransferFile], isShowLoading: Bool = false) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async { [weak self] in
                guard let self = self else { return }
                do {
                    try self.insertFiles(files, isShowLoading: isShowLoading)
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /**
     异步更新文件的传输状态。
     - Parameters:
     - fileId: 文件主键ID。
     - newStatus: 新的传输状态。
     - Throws: 数据库操作异常。
     */
    func updateFileStatusAsync(file: MITransferFile) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async { [weak self] in
                guard let self = self else { return }
                self.updateFileStoredDataStatus(file: file)
                continuation.resume(returning: ())
            }
        }
    }
    
    /**
     异步删除单个文件，如有需要自动删除空记录。
     - Parameters:
     - id: 文件主键ID。
     - isShowLoading: 是否显示loading。
     - Returns: 可能需要更新的互传记录。
     - Throws: 数据库操作异常。
     */
    @discardableResult
    func deleteFileAsync(byId id: Int64, isShowLoading: Bool = false) async throws -> MITransferRecord? {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async { [weak self] in
                guard let self = self else { return }
                do {
                    let result = try self.deleteFile(byId: id, isShowLoading: isShowLoading)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /**
     异步批量删除文件，并自动处理相关互传记录。
     - Parameters:
     - ids: 文件主键ID数组。
     - isShowLoading: 是否显示loading。
     - Returns: (删除的记录数组, 需要更新的记录数组)。
     - Throws: 数据库操作异常。
     */
    @discardableResult
    func deleteFilesAsync(byIds ids: [Int64], isShowLoading: Bool = false) async throws -> ([MITransferRecord], [MITransferRecord]) {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async { [weak self] in
                guard let self = self else { return }
                do {
                    let result = try self.deleteFiles(byIds: ids, isShowLoading: isShowLoading)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /**
     异步清空指定类型的所有互传记录及文件。
     - Parameter transferType: 传输类型，默认全部。
     - Throws: 数据库操作异常。
     */
    func deleteAllRecordsCascadeAsync(_ transferType: MITransferType = .all) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async { [weak self] in
                guard let self = self else { return }
                do {
                    try self.deleteAllRecordsCascade(transferType)
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    
    /// 模糊搜索分页查询文件，按时间排序
    /// - Parameters:
    ///   - keyword: 关键字（可选，用于按文件名模糊搜索）
    ///   - page: 页码（从1开始）
    ///   - pageSize: 每页数量
    ///   - transferType: 传输类型
    ///   - sortByTime: 时间排序方式，默认降序
    /// - Returns: 当前页的文件数组
    func searchFilesAsync(keyword: String? = nil, foldName: String? = nil, page: Int, pageSize: Int = 20, transferType: MITransferType, sortByTime: ConfigSortType = .descending) async throws -> [MITransferFile] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async { [weak self] in
                guard let self = self else { return }
                do {
//                    let result = try searchFiles(keyword: keyword, foldName: foldName, page: page, transferType: transferType)
#if MAIN_APP
                    let result = try searchFiles(keyword: keyword, foldName: foldName, page: page, transferType: transferType)
                
#elseif MAIN_MAC
                    let result = try searchFiles(keyword: keyword, foldName: foldName, page: page, pageSize: pageSize, transferType: transferType, sortByTime: sortByTime)
#endif
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 异步查询所有文件夹（去重）
    /// - Parameters:
    ///   - transferType: 传输类型
    ///   - isShowLoading: 是否显示loading
    /// - Returns: 包含文件夹名称的MITransferRecord数组
    @discardableResult
    func getAllFoldersAsync(transferType: MITransferType, isShowLoading: Bool = false) async throws -> [MITransferRecord] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async { [weak self] in
                guard let self = self else { return }
                do {
                    let result = try self.getAllFolders(transferType: transferType, isShowLoading: isShowLoading)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 异步查询指定文件夹下的所有文件，按扩展名排序
    /// - Parameters:
    ///   - folderName: 文件夹名称
    ///   - transferType: 传输类型
    ///   - extensionSort: 扩展名排序方式，默认升序
    ///   - isShowLoading: 是否显示loading
    /// - Returns: 指定文件夹下的文件数组
    @discardableResult
    func getFilesInFolderAsync(_ folderName: String, transferType: MITransferType, extensionSort: ConfigSortType = .ascending, isShowLoading: Bool = false) async throws -> [MITransferFile] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async { [weak self] in
                guard let self = self else { return }
                do {
                    let result = try self.getFilesInFolder(folderName, transferType: transferType, extensionSort: extensionSort, isShowLoading: isShowLoading)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 异步查询所有文件夹及其包含的文件
    /// - Parameters:
    ///   - transferType: 传输类型
    ///   - extensionSort: 扩展名排序方式，默认升序
    ///   - isShowLoading: 是否显示loading
    /// - Returns: 包含文件夹和文件的MITransferRecord数组
    @discardableResult
    func getAllFoldersWithFilesAsync(transferType: MITransferType, sortType: ConfigSortType = .ascending, isShowLoading: Bool = false) async throws -> [MITransferRecord] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async { [weak self] in
                guard let self = self else { return }
                do {
                    let result = try self.getAllFoldersWithFiles(transferType: transferType, sortType: sortType, isShowLoading: isShowLoading)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
}

extension MIWCDBManager {
    
    static func showLoading() {
#if MAIN_APP
        DispatchQueue.main.async {
            PhotoManager.HUDView.show(with: nil, delay: 0, animated: true, addedTo: MIKeyWindow)
        }
#endif
        
    }
    
    static func dismissLoading() {
#if MAIN_APP
        DispatchQueue.main.async {
            PhotoManager.HUDView.dismiss(delay: 0, animated: true, for: MIKeyWindow)
        }
#endif
    }
}

//
//  MIHistoryViewModel.swift
//  MutualInfection
//
//  Created by Niko on 2025/10/17.
//

import Foundation
#if MAIN_APP
import UIKit
#elseif MAIN_MAC

#endif

/// 跳转互传记录
func routeTransferHistoryListController() {
#if MAIN_APP
    if NKDevice.isPhone {
        let controller = MITransferHistoryContenrController()
        MIGetTopViewController()?.navigationController?.pushViewController(controller, animated: true)
    }
    
    if NKDevice.isPad {
        let controller = MIIPadTransferHisortyContentController()
        MIGetTopViewController()?.navigationController?.pushViewController(controller, animated: true)
    }
#elseif MAIN_MAC
    
#endif
}

enum HistoryPageType {
    case history
    case subFolder
    case search
}

class MITransferHistoryViewModel {
    
    /// 互传记录类型
    var transferType: MITransferType!
    
    var historyPageType: HistoryPageType!
    
    /// 自动区分类型后的数据
    var transferData: [MITransferRecord] {
        if menuType.isSortByTime {
            return transferRecordsSortByTime
        } else {
            return transferRecordsSortByType
        }
    }
    
    /// 当前选中文件夹/当前选中发送与接收条目(iPad默认选中第一条)
    var currentFolder: MITransferRecord? {
        didSet {
            guard let _ = currentFolder else { return }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                tableViewReloadData()
            }
        }
    }
    
    /// 按时间排序数据
    var transferRecordsSortByTime: [MITransferRecord] = [] {
        didSet {
            if NKDevice.isPad {
                if currentFolder == nil {
                    currentFolder = transferData.first
                }
            }
        }
    }
    
    /// 按类型排序，按文件夹分类(搜索，按类型)
    var transferRecordsSortByType: [MITransferRecord] = [] {
        didSet {
            if NKDevice.isPad {
                if currentFolder == nil {
                    currentFolder = transferData.first
                }
            }
        }
    }
    
    /// 获取文件总数
    var allFileCount: Int {
        if NKDevice.isPhone {
            if historyPageType == .history {
                if menuType.isSortByTime {
                    return (try? MIWCDBManager.shared.getFileCount(transferType: transferType)) ?? 0
                } else {
                    return (try? MIWCDBManager.shared.getAllFolders(transferType: transferType).count) ?? 0
                }
            } else {
                return transferRecordsSortByType.first?.sendContent.count ?? 0
            }
        } else {
            
            return (try? MIWCDBManager.shared.getFileCount(transferType: transferType)) ?? 0
        }
    }
    
    /// 选中文件数量
    var selectFileCount: Int = 0
    
    
    /// 当前页面排序状态 默认为按时间降序
    var menuType: ConfigSortState! {
        didSet {
            currentFolder = nil
            page = 1
            getCurrentSortData()
        }
    }
    /// 分页页码
    var page: Int = 1
    
#if MAIN_APP
    var pageSize: Int {
        if NKDevice.isPhone {
            menuType.isSortByTime ? 10 : 20
        } else {
            menuType.isSortByTime ? 20 : 20
        }
    }
#elseif MAIN_MAC
    /// MAC初始加载5条太少了，分为
    var pageSize: Int { menuType.isSortByTime ? 20 : 20 }
#endif
    
    /// 是否全选
    var isSelectAll: Bool { selectFileCount == allFileCount }
    
    /// 选中回调 bool - 是否全选
    var didSelectAction: ClickBlockVoid?
    
    /// 是否隐藏上拉加载
    var hiddenMJFoot: ((Bool)->Void)?
    
    
    /// 通知外部刷新TableView
    var refreshTableView: ClickBlockVoid? {
        didSet {
            refreshTableViewCallBackList.append(refreshTableView)
        }
    }
    var refreshTableViewCallBackList: [ClickBlockVoid?] = []
    
    /// 初始化
    init(transferType: MITransferType = .receive, historyPageType: HistoryPageType = .history, menuType: ConfigSortState = .sortByTime(.descending)) {
        self.transferType = transferType
        self.historyPageType = historyPageType
        self.menuType = menuType
        
        setupNotificationObservers()
        getCurrentSortData()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 通知
    func setupNotificationObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleDatabaseChange(_:)), name: .MIWCDBRecordsInsert, object: nil)
        
        NotificationCenter.default.addObserver(forName: .MIWCDBRecordsDelete, object: nil, queue: .main) { [weak self] notification in
            guard let self = self else { return }
            
            guard let fileIds = notification.userInfo?[NotificationParamKey.deleteIds] as? [Int64] else { return }
            guard let deleteRecordList = notification.userInfo?[NotificationParamKey.deleteRecordList] as? [MITransferRecord] else { return }
            
            for record in transferRecordsSortByTime {
                for deleteRecord in deleteRecordList {
                    if deleteRecord == record {
                        transferRecordsSortByTime.safeRemove(record)
                    }
                }
                
                for file in record.sendContent {
                    if fileIds.contains(file.id ?? 0) {
                        record.sendContent.safeRemove(file)
                    }
                }
            }
            
            for record in transferRecordsSortByType {
                for file in record.sendContent {
                    if fileIds.contains(file.id ?? 0) {
                        record.sendContent.safeRemove(file)
                    }
                }
                
                if record.sendContent.isEmpty {
                    transferRecordsSortByType.safeRemove(record)
                }
            }
            
            tableViewReloadData()
        }
        
        NotificationCenter.default.addObserver(forName: .MIWCDBRecordsUpdate, object: nil, queue: .main) {  [weak self] notification in
            guard let self = self else { return }
            
            guard let fileId = notification.userInfo?[NotificationParamKey.updateFildId] as? Int64,
                  let identifier = notification.userInfo?[NotificationParamKey.identifier] as? String,
                  let status = notification.userInfo?[NotificationParamKey.status] as? TransferStatus else { return }
            
            if historyPageType == .history && menuType.isSortByTime {
                transferRecordsSortByTime.forEach { [weak self] in
                    guard let self = self else { return }
                    if let file = $0.sendContent.first(where: { $0.id == fileId }) {
                        file.identifier = identifier
                        file.status = status
                        return tableViewReloadData()
                    }
                }
            } else {
                transferRecordsSortByType.forEach { [weak self] in
                    guard let self = self else { return }
                    if let file = $0.sendContent.first(where: { $0.id == fileId }) {
                        file.identifier = identifier
                        file.status = status
                        return tableViewReloadData()
                    }
                }
            }
        }
    }
    
    // MARK: - 通知处理方法
    @objc func handleDatabaseChange(_ notification: Notification) {
        print("📊 数据库发生变化，重新加载所有数据")
        page = 1
        getCurrentSortData()
    }
}

// MARK: -  数据
extension MITransferHistoryViewModel {
    // MARK: -  全选与取消全选
    func selectAll(isSelect: Bool) {
        
        if isSelect {
            selectFileCount = allFileCount
        } else {
            selectFileCount = 0
        }
        
        if historyPageType == .history {
            if menuType.isSortByTime {
                /// 按时间排序
                transferRecordsSortByTime.forEach {
                    $0.isSelect = isSelect
                    $0.sendContent.forEach { $0.isSelect = isSelect }
                }
            } else {
                /// 按类型排序
                transferRecordsSortByType.forEach {
                    $0.isSelect = isSelect
                    $0.sendContent.forEach { $0.isSelect = isSelect }
                }
            }
        } else if historyPageType == .subFolder {
            /// 按类型排序
            transferRecordsSortByType.forEach {
                $0.sendContent.forEach { $0.isSelect = isSelect }
            }
        }
        tableViewReloadData()
    }
    
    /// 获取数据
    func getCurrentSortData() {
        /// 搜索没有排序
        if historyPageType == .search { return }
        
        /// 历史记录排序
        if historyPageType == .history {
            switch menuType {
                case .sortByTime(let configSortType):
                    Task { [weak self] in
                        guard let self = self else { return }
                        do {
                            let records = try await MIWCDBManager.shared.getRecordsAsync(page: page, pageSize: pageSize, transferType: transferType, sortType: configSortType)
                            
                            
                            page == 1 ? transferRecordsSortByTime = records : transferRecordsSortByTime.append(contentsOf: records)
                            
                            if isSelectAll {
                                for record in transferRecordsSortByTime {
                                    record.isSelect = true
                                    for file in record.sendContent {
                                        file.isSelect = true
                                    }
                                }
                            }
                            
                            page += 1;
                            await MainActor.run { [weak self] in
                                guard let self = self else { return }
                                hiddenMJFoot?(records.count < (pageSize))
                                /// 刷新数据
                                tableViewReloadData()
                            }
                        } catch {
#if MAIN_APP
                            ShareAPI.shared().log(1, "❌ 按时间排序 分页查询记录失败: \(error)")
#endif
                        }
                    }
                case .sortByType(let configSortType):
                    Task { [weak self] in
                        guard let self = self else { return }
                        do {
                            
                            transferRecordsSortByType = try await MIWCDBManager.shared.getAllFoldersWithFilesAsync(transferType: transferType, sortType: configSortType, isShowLoading: true)
                            
                            if isSelectAll {
                                for record in transferRecordsSortByType {
                                    record.isSelect = true
                                    for file in record.sendContent {
                                        file.isSelect = true
                                    }
                                }
                            }
                            
                            page += 1;
                            await MainActor.run { [weak self] in
                                guard let self = self else { return }
                                hiddenMJFoot?(true)
                                /// 刷新数据
                                tableViewReloadData()
                            }
                        } catch {
#if MAIN_APP
                            ShareAPI.shared().log(1, "❌ 按类型排序 分页查询记录失败: \(error)")
#endif
                        }
                    }
                default: break
            }
        }
    }
    
    
    /// 搜索
    func searchTransferData(keyword: String, sortByTime: ConfigSortType = .descending) {
        Task { [weak self] in
            guard let self = self else { return }
            do {
#if MAIN_APP
                let files = try await MIWCDBManager.shared.searchFilesAsync(keyword: keyword, foldName: currentFolder?.foldName, page: page, transferType: transferType)
                
#elseif MAIN_MAC
                let files = try await MIWCDBManager.shared.searchFilesAsync(keyword: keyword, foldName: currentFolder?.foldName, page: page, pageSize: pageSize, transferType: transferType, sortByTime: sortByTime)
#endif
                print("sortByTime:\(sortByTime)")
                let model: MITransferRecord = page == 1 ? MITransferRecord() : transferRecordsSortByType.first!
                model.foldName = "Search"
                transferRecordsSortByType = [model]
                page == 1 ? model.sendContent = files : model.sendContent.append(contentsOf: files)
                
                page += 1;
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    hiddenMJFoot?(files.count < (pageSize))
                    /// 刷新数据
                    tableViewReloadData()
                }
            } catch {
#if MAIN_APP
                ShareAPI.shared().log(1, "❌ 按类型排序 分页查询记录失败: \(error)")
#endif
            }
        }
    }
    
    
    /// 多选点击删除
    //    func multipleDelete() {
    //        AlertManager.showAlertSheet(title: nil, operationOptionList: [.deleteRecordAndFile, .deleteRecord]) { [weak self] index, option in
    //            guard let self = self else { return }
    //
    //            switch option {
    //                case .deleteRecordAndFile:
    //                    deleteResource(delete: file) { [weak self] isSuccess in
    //                        guard let self = self else { return }
    //                        if isSuccess {
    //                            ShareAPI.shared().log(1, "\(file) 删除成功")
    //                            performDeletion(by: [file])
    //                        } else {
    //                            ShareAPI.shared().log(1, "\(file) 删除失败")
    //                        }
    //                    }
    //
    //                case .deleteRecord:
    //                    performDeletion(by: [file])
    //            }
    //        }
    //    }
    
    /// 获取所有选中文件
    func getSelectFiles() -> [MITransferFile] {
        var files: [MITransferFile] = []
        if historyPageType == .history {
            if menuType.isSortByTime {
                files = transferRecordsSortByTime.map { $0.sendContent.filter { $0.isSelect } }.flatMap { $0 }
            } else {
                files = transferRecordsSortByType.map { $0.sendContent.filter { $0.isSelect } }.flatMap { $0 }
            }
        } else if historyPageType == .subFolder {
            files = transferRecordsSortByType.map { $0.sendContent.filter { $0.isSelect } }.flatMap { $0 }
        }
        
        return files
    }
    
    // MARK: -  删除选中文件
    func deleteSelectedFiles() {
        
        var files: [MITransferFile] = []
#if MAIN_APP
        if historyPageType == .history {
            if menuType.isSortByTime {
                /// 如果是全选，直接删除全部
                if isSelectAll { return deleteAllRecords() }
                files = transferRecordsSortByTime.map { $0.sendContent.filter { $0.isSelect } }.flatMap { $0 }
            } else {
                /// 如果是全选，直接删除全部
                if isSelectAll { return deleteAllRecords() }
                files = transferRecordsSortByType.map { $0.sendContent.filter { $0.isSelect } }.flatMap { $0 }
            }
        } else if historyPageType == .subFolder {
            files = transferRecordsSortByType.map { $0.sendContent.filter { $0.isSelect } }.flatMap { $0 }
        }
#elseif MAIN_MAC
        if historyPageType == .history {
            if menuType.isSortByTime {
                /// 如果是全选，直接删除全部
                if isSelectAll { return deleteAllRecords() }
                files = transferRecordsSortByTime.map { $0.sendContent.filter { $0.isSelect } }.flatMap { $0 }
            } else {
                /// 如果是全选，直接删除全部
                if isSelectAll { return deleteAllRecords() }
                files = transferRecordsSortByType.map { $0.sendContent.filter { $0.isSelect } }.flatMap { $0 }
            }
        } else if historyPageType == .subFolder {
            files = transferRecordsSortByType.map { $0.sendContent.filter { $0.isSelect } }.flatMap { $0 }
        } else if historyPageType == .search {
            files = transferRecordsSortByType.map { $0.sendContent.filter { $0.isSelect } }.flatMap { $0 }
        }
#endif
        performDeletion(by: files)
    }
    
    /// 删除全部，清空数据库
    func deleteAllRecords() {
        Task { [weak self] in
            guard let self = self else { return }
            /// 全选 删除全部数据
            do {
                
                try await MIWCDBManager.shared.deleteAllRecordsCascadeAsync(transferType)
                
                /// 刷新第一页数据
                page = 1
                
                /// 刷新数据
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    
                    /// 刷新数据
                    getCurrentSortData()
                }
            } catch {
#if MAIN_APP
                ShareAPI.shared().log(1, "❌ 删除所有文件失败: \(error)")
#endif
            }
        }
    }
    
    // MARK: -  批量删除记录
    func performDeletion(by files: [MITransferFile]) {
        
        var varFiles = files
        
        /// 按时间排序
        Task { [weak self] in
            guard let self = self else { return }
            do {
                /// 批量删除
                try await MIWCDBManager.shared.deleteFilesAsync(byIds: files.map { $0.id ?? -1 }, isShowLoading: true)
                
                /// 更新本地数据
                if menuType.isSortByTime && historyPageType == .history {
                    for transferRecord in transferRecordsSortByTime {
                        for file in files {
                            if transferRecord.sendContent.remove(file) {
                                varFiles.remove(file)
                            }
                        }
                        
                        if transferRecord.sendContent.isEmpty {
                            transferRecordsSortByTime.remove(transferRecord)
                        }
                    }
                    
                    if NKDevice.isPad {
                        
                        if let currentFolder = currentFolder, transferRecordsSortByTime.contains(currentFolder) == true {
                            /// 存在并且包含...不做处理
                        } else {
                            currentFolder = nil
                            transferRecordsSortByTime = transferRecordsSortByTime
                        }
                    }
                } else {
                    for transferRecord in transferRecordsSortByType {
                        for file in files {
                            if transferRecord.sendContent.remove(file) {
                                varFiles.remove(file)
                            }
                        }
                    }
                    
                    transferRecordsSortByType.removeAll(where: { $0.sendContent.isEmpty })
                    
                    if NKDevice.isPad {
                        if let currentFolder = currentFolder, transferRecordsSortByType.contains(currentFolder) == true {
                            /// 存在并且包含...不做处理
                        } else {
                            currentFolder = nil
                            transferRecordsSortByType = transferRecordsSortByType
                        }
                    }
                }
                
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    /// 刷新数据
                    tableViewReloadData()
                }
            } catch {
                ShareAPI.shared().log(1, "❌ 批量删除文件失败: \(error)")
            }
        }
    }
    
    // MARK: -  删除资源，闭包返回资源删除结果
    func deleteResource(delete file: MITransferFile, completion: @escaping (Bool) -> Void) {
        switch file.fileType {
            case .photoAndVideo:
                /// 删除相册中的照片
#if MAIN_APP
                if file.identifier?.isEmpty ?? true {
                    /// 删除文管中的图片资源
                    if let absoluteFileUrl = file.absoluteFileUrl {
                        completion(deleteVCDCardsToFile(filePath: absoluteFileUrl))
                    }
                } else {
                    PhotoLibraryManager.shared.deleteAssets(localIdentifiers: [file.identifier].compactMap { $0 }, completion:  { isSuccess, error  in
                        if !isSuccess {
                            ShareAPI.shared().log(1, "图片删除失败")
                        }
                        completion(isSuccess)
                    })
                }
#elseif MAIN_MAC
                break
#endif
                
            case .contacts, .file, .location, .none:
#if MAIN_APP
                /// 删除文件
                if let absoluteFileUrl = file.absoluteFileUrl {
                    completion(deleteVCDCardsToFile(filePath: absoluteFileUrl))
                }
#elseif MAIN_MAC
                break
#endif
                
        }
    }
    
    /// 更新选中数量
    func updateSelectFileCount(count: Int) {
        selectFileCount += count
        didSelectAction?()
    }
    
    func tableViewReloadData() {
        for callBack in refreshTableViewCallBackList {
            callBack?()
        }
    }
}


// MARK: - TableView
extension MITransferHistoryViewModel {
    func numberOfSections() -> Int {
        if NKDevice.isPhone {
            if historyPageType == .history && menuType.isSortByTime {
                return transferRecordsSortByTime.count
            } else {
                return 1
            }
        } else if NKDevice.isPad {
            return 1
        } else {
            return 1
        }
    }
    
    func numberOfRowsInSection(section: Int, isLeftList: Bool = false, isRightList: Bool = false) -> Int {
        if NKDevice.isPhone {
            if historyPageType == .history {
                if menuType.isSortByTime {
                    let record = transferRecordsSortByTime[section]
                    return record.isShow ? record.sendContent.count : 0
                } else {
                    return transferRecordsSortByType.count
                }
            } else {
                return transferRecordsSortByType.first?.sendContent.count ?? 0
            }
        } else if NKDevice.isPad {
            if isLeftList {
                return transferData.count
            } else if isRightList {
                return currentFolder?.sendContent.count ?? 0
            } else if historyPageType == .search {
                let record = transferRecordsSortByType[safe: section]
                return record?.sendContent.count ?? 0
            } else {
                return 0
            }
        } else {
            return 0
        }
    }
    
#if MAIN_APP
    func getRowData(indexPath: IndexPath) -> (MITransferRecord?, MITransferFile?) {
        
        var sectionRecord: MITransferRecord?
        var file: MITransferFile?
        
        if UIDevice.isPhone {
            if historyPageType == .history {
                if menuType.isSortByTime {
                    sectionRecord = transferRecordsSortByTime[indexPath.section]
                    file = sectionRecord?.sendContent[indexPath.row]
                } else {
                    sectionRecord = transferRecordsSortByType[indexPath.row]
                }
                
            } else if historyPageType == .subFolder {
                sectionRecord = transferRecordsSortByType[indexPath.section]
                file = sectionRecord?.sendContent[indexPath.row]
                
                
            } else if historyPageType == .search {
                sectionRecord = transferRecordsSortByType[indexPath.section]
                file = sectionRecord?.sendContent[indexPath.row]
                
            }
        } else {
            if historyPageType == .history {
                sectionRecord = currentFolder
                file = currentFolder?.sendContent[indexPath.row]
            } else if historyPageType == .search {
                sectionRecord = transferRecordsSortByType[indexPath.section]
                file = sectionRecord?.sendContent[indexPath.row]
            }
        }
        
        return (sectionRecord, file)
    }
#else
    
#endif
#if MAIN_APP
    func getSectionHeaderData(section: Int) -> MITransferRecord? {
        if UIDevice.isPhone {
            if historyPageType == .history && menuType.isSortByTime {
                return transferRecordsSortByTime[safe: section]
            } else {
                return nil
            }
        }
        
        if UIDevice.isPad {
            if historyPageType == .history {
                if menuType.isSortByTime {
                    return transferRecordsSortByTime[safe: section]
                } else {
                    return transferRecordsSortByType[safe: section]
                }
            } else {
                return nil
            }
        }
        
        return nil
    }
#else
    
#endif
}



// MARK: -  Action
extension MITransferHistoryViewModel {
    
#if MAIN_APP
    /// 选中
    func selectRowAction(indexPath: IndexPath) {
        let (sectionRecord, file) = getRowData(indexPath: indexPath)
        
        if UIDevice.isPhone {
            if historyPageType == .history {
                if menuType.isSortByTime {
                    // 编辑模式下处理选中状态
                    file?.isSelect.toggle()
                    
                    if let _ = sectionRecord?.sendContent.first(where: { !$0.isSelect }) {
                        sectionRecord?.isSelect = false
                    } else {
                        sectionRecord?.isSelect = true
                    }
                    /// 更新选中总数
                    updateSelectFileCount(count: (file?.isSelect ?? false) ? 1 : -1)
                } else {
                    // 编辑模式下处理选中状态
                    sectionRecord?.isSelect.toggle()
                    sectionRecord?.sendContent.forEach { $0.isSelect = sectionRecord?.isSelect ?? false }
                    updateSelectFileCount(count: (sectionRecord?.isSelect ?? false) ? 1 : -1)
                }
            } else {
                file?.isSelect.toggle()
                updateSelectFileCount(count: (file?.isSelect ?? false) ? 1 : -1)
            }
        } else {
            
            if historyPageType == .history {
                file?.isSelect.toggle()
                
                if let _ = sectionRecord?.sendContent.first(where: { !$0.isSelect }) {
                    sectionRecord?.isSelect = false
                } else {
                    sectionRecord?.isSelect = true
                }
                /// 更新选中总数
                updateSelectFileCount(count: (file?.isSelect ?? false) ? 1 : -1)
            } else {
                file?.isSelect.toggle()
                updateSelectFileCount(count: (file?.isSelect ?? false) ? 1 : -1)
            }
        }
    }
    
    /// cell 点击
    func cellDidselectAction(indexPath: IndexPath) {
        
        var record: MITransferRecord?
        var file: MITransferFile?
        
        if historyPageType == .history {
            if UIDevice.isPhone {
                if menuType.isSortByTime {
                    record = transferRecordsSortByTime[indexPath.section]
                    file = record?.sendContent[indexPath.row]
                } else {
                    record = transferRecordsSortByType[indexPath.row]
                }
                
            } else {
                record = currentFolder
                file = record?.sendContent[indexPath.row]
            }
        } else if historyPageType == .subFolder {
            record = transferRecordsSortByType[indexPath.section]
            file = record?.sendContent[indexPath.row]
            
        } else if historyPageType == .search {
            record = transferRecordsSortByType[indexPath.section]
            if (record?.sendContent.count ?? 0) > indexPath.row {
                file = record?.sendContent[indexPath.row]
            }
        }
        
        guard let file = file, !file.isDisable else {
            if file?.status == .failure {
                AlertManager.showAlert(title: LocalizedStrings.sourceFileCorrupted, cancelTitle: nil, confirmTitle: LocalizedStrings.iKnow)
            }
            return
        }
        
        // 非编辑模式下处理点击操作
        if transferType == .send {
            AlertManager.showAlertSheet(title: file.fileName, operationOptionList: [.deleteRecord]) {  [weak self] index, option in
                guard let self = self else { return }
                performDeletion(by: [file])
            }
        } else {
            AlertManager.showAlertSheet(title: file.fileName, operationOptionList: [.view, .openWith, .deleteRecordAndFile, .deleteRecord]) { [weak self] index, option in
                guard let self = self else { return }
                
                switch option {
                    case .view:
                        /// 查看
                        ShareManager.open(file: file) { [weak self] isSuccess, message in
                            guard let self = self else { return }
                            if !isSuccess {
                                showDeleteAlert(by: [file])
                            }
                        }
                        
                    case .openWith:
                        /// 打开方式
                        ShareManager.share(file: file, from: MIGetTopViewController()!) { [weak self] isSuccess, message in
                            guard let self = self else { return }
                            if !isSuccess {
                                showDeleteAlert(by: [file])
                            }
                        }
                        break
                    case .deleteRecordAndFile:
                        deleteResource(delete: file) { [weak self] isSuccess in
                            guard let self = self else { return }
                            if isSuccess {
                                ShareAPI.shared().log(1, "\(file) 删除成功")
                                performDeletion(by: [file])
                            } else {
                                ShareAPI.shared().log(1, "\(file) 删除失败")
                            }
                        }
                        
                    case .deleteRecord:
                        performDeletion(by: [file])
                }
            }
        }
        
    }
    
    /// 查看
    func openViewAction(indexPath: IndexPath) {
        var record: MITransferRecord?
        var file: MITransferFile?
        
        if historyPageType == .history {
            if UIDevice.isPhone {
                if menuType.isSortByTime {
                    record = transferRecordsSortByTime[indexPath.section]
                    file = record?.sendContent[indexPath.row]
                } else {
                    record = transferRecordsSortByType[indexPath.row]
                }
                
            } else {
                record = currentFolder
                file = record?.sendContent[indexPath.row]
            }
        } else if historyPageType == .subFolder {
            record = transferRecordsSortByType[indexPath.section]
            file = record?.sendContent[indexPath.row]
            
        } else if historyPageType == .search {
            record = transferRecordsSortByType[indexPath.section]
            if (record?.sendContent.count ?? 0) > indexPath.row {
                file = record?.sendContent[indexPath.row]
            }
        }
        
        if historyPageType == .history && menuType.isSortByType && UIDevice.isPhone {
            /// 跳转子文件
            let historyVC = MITransferHistoryListController()
            historyVC.title = record?.foldName
            historyVC.historyPageType = .subFolder
            historyVC.transferType = transferType
            historyVC.transferRecordsSortByType = record
            MIGetTopViewController()?.navigationController?.pushViewController(historyVC, animated: true)
            
        } else {
            /// 跳转查看
            guard let file = file, !file.isDisable else {
                if file?.status == .failure {
                    AlertManager.showAlert(title: LocalizedStrings.sourceFileCorrupted, cancelTitle: nil, confirmTitle: LocalizedStrings.iKnow)
                }
                return
            }
            
            ShareManager.open(file: file) { [weak self] isSuccess, message in
                guard let self = self else { return }
                if !isSuccess {
                    showDeleteAlert(by: [file])
                }
            }
        }
    }
    
    func showDeleteAlert(by files: [MITransferFile]) {
        AlertManager.showAlert(message: LocalizedStrings.fileMovedOrDeletedConfirmDeleteRecord, cancelTitle: LocalizedStrings.ignore, confirmTitle: LocalizedStrings.delete) { [weak self] in
            guard let self = self else { return }
            performDeletion(by: files)
        }
    }
    
#else
    
#endif
}

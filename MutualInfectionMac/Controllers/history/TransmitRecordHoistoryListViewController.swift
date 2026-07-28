//
//  TransmitRecordHoistoryListViewController.swift
//  MutualInfectionMac
//
//  Created by TS on 2025/10/30.
//

import Foundation
import AppKit


class TransmitRecordHoistoryListViewController: NSViewController {
    
    /// 左侧列表点击事件回调
    var listSelectClickHandler: ((Bool) -> Void)?
    
    /// 删除操作后，是否还可以全选
    var deleteItemUpdateAllSelectHandler: ((Bool) -> Void)?
    
    /// 传输类型
    var transferType: MITransferType = .all
    
    /// 页面类型
    var historyPageType: HistoryPageType = .history {
        didSet {
            
        }
    }
    
    /// 当前列表的排序类型
    var currentSortType: MACHeaderSortState = .sortList {
        didSet {
            sidebarViewController.currentSortType = currentSortType
            if currentSortType == .sortList {
                viewModel.menuType = .sortByTime(currentSort)
            } else {
                viewModel.menuType = .sortByType(currentSort)
            }
            /// 右侧的详情需要置空
            contentViewController.updateContent(with: [], title: "")
        }
    }
    
    /// 当前排序类型(升序/降序)
    var currentSort: ConfigSortType = .descending
    
    /// 编辑模式
    var editMode: Bool = false {
        didSet {
            /// 退出编辑需要把数组元素都置为未选中
            if editMode == false {
                for item in sidebarViewController.menuItems {
                    item.isSelect = false
                    for subItem in item.sendContent {
                        subItem.isSelect = false
                    }
                }
            }
            
            sidebarViewController.editMode = editMode
            contentViewController.editMode = editMode
        }
    }
    
    var viewModel: MITransferHistoryViewModel!
    
    /// 当前详情的资源数组
    private var currentContentItems: [MITransferFile] = []
    /// 更多按钮的资源(左侧传输设备的item)
    private var selectedMenuItem: MITransferRecord?
    /// 更多按钮的资源数组(右侧详情的)
    private var currentItem: MITransferFile?
    /// 搜索框的值
    private var searchText: String?
    /// 更多按钮点击后展示的弹窗
    private var popupView: MIMACCustomPopupView?
    
    /// 是否进行了删除操作
    private var deleteing: Bool = false
    
    
    // MARK: - 子控制器
    private lazy var sidebarViewController: TransmitRecordSidebarViewController = {
        let controller = TransmitRecordSidebarViewController()
        controller.setHeaderSort(transferType == .receive)
        /// 左侧选择哪个item的点击回调
        controller.selectionHandler = { [weak self] index in
            guard let self = self else { return }
            self.handleSidebarSelection(index)
            self.touchViewFirstResponder()
        }
        /// 单选按钮点击回调
        controller.sideBarSelectClickHandler = { [weak self] testModel in
            guard let self = self else { return }
            if testModel.id == self.selectedMenuItem?.id {
                self.contentViewController.updateContent(with: testModel.sendContent, title: "")
            }
            self.listSelectClickHandler?(self.getCurrentAllSelectState())
        }
        /// 列表滑动
        controller.scrollViewDidChange = { [weak self] in
            guard let self = self else { return }
            if self.popupView != nil {
                self.popupView?.hide()
            }
        }
        /// 排序风格改变点击回调
        controller.sideBarSortTouchHandler = { [weak self] state in
            guard let self = self else { return }
            self.currentSortType = state
            self.touchViewFirstResponder()
            
        }
        /// 加载更多数据回调，viewModel目前是分页加载的
        controller.onLoadMore = { [weak self] in
            guard let self = self else { return }
            /// 编辑模式不进行分页请求数据
//            if editMode {
//                return
//            }
//            print("当前的页码：\(self.viewModel.page)")
//            self.viewModel.getCurrentSortData()
//            print("当前的数据数量：\(self.sidebarViewController.menuItems.count)")
            if self.sidebarViewController.menuItems.count >= (self.viewModel.pageSize * (self.viewModel.page-1)) {
                self.viewModel.getCurrentSortData()
                print("当前的页码：\(self.viewModel.page)")
                print("记载更多触发分页请求当前的数据数量：\(self.sidebarViewController.menuItems.count)")
            }
            
        }
        return controller
    }()
    
    private lazy var contentViewController: TransmitRecordContentViewController = {
        let controller = TransmitRecordContentViewController()
        controller.contentMoreClickHandler = { [weak self] testModel, sender in
            guard let self = self else { return }
            self.touchViewFirstResponder()
            self.currentItem = testModel
            
            self.showContextMenu(sender, model: testModel)
            
        }
        controller.scrollViewDidChange = { [weak self] in
            guard let self = self else { return }
            if self.popupView != nil {
                self.popupView?.hide()
            }
        }
        //        /// 全选点击回调
        //        controller.contentAllSelectHandler = { [weak self] isAll in
        //            guard let self = self else { return }
        //            self.contentAllSelectToSidebar(isAll)
        //        }
        /// 编辑模式选中按钮点击回调
        controller.contentSelectHandler = { [weak self] in
            guard let self = self else { return }
            var select = false
            for item in currentContentItems {
                if item.isSelect {
                    select = true
                    break
                }
            }
            self.contentSelectToSidebar(select)
            
        }
        /// 非编辑模式下点击了哪个item
        controller.contentItemClickHandler = { [weak self] item in
            guard let self = self else { return }
            self.contentLookFile(item)
        }
        return controller
    }()
    
    private lazy var notDataView: MACNotDataView = {
        let view = MACNotDataView()
        //        view.isHidden = true
        return view
    }()
    
    private let stackView: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.distribution = .fill
        stack.spacing = 1
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    override func loadView() {
        
        view=NSView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCustomLayout()
        viewModel = MITransferHistoryViewModel(transferType: transferType, historyPageType: historyPageType)
        
        /// 刷新数据
        viewModel.refreshTableView = { [weak self] in
            guard let self = self else { return }
            
            tableViewReloadData()
        }
        
        setupInitialSelection()
        
    }
    
    private func setupCustomLayout() {
        view.addSubview(stackView)
        view.addSubview(notDataView)
        
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        notDataView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 添加子控制器
        addChild(sidebarViewController)
        addChild(contentViewController)
        
        // 设置左侧视图
        sidebarViewController.view.translatesAutoresizingMaskIntoConstraints = false
        sidebarViewController.view.wantsLayer = true
        sidebarViewController.view.layer?.cornerRadius = 0
        sidebarViewController.view.layer?.backgroundColor = NSColor.white.cgColor
        
        // 设置右侧视图
        contentViewController.view.translatesAutoresizingMaskIntoConstraints = false
        contentViewController.view.wantsLayer = true
        contentViewController.view.layer?.cornerRadius = 0
        contentViewController.view.layer?.backgroundColor = NSColor.white.cgColor
        
        stackView.addArrangedSubview(sidebarViewController.view)
        stackView.addArrangedSubview(contentViewController.view)
        
        sidebarViewController.view.snp.makeConstraints { make in
            make.width.equalTo(stackView).multipliedBy(0.4)
        }
        
        //        contentViewController.view.snp.makeConstraints { make in
        //            make.width.equalTo(stackView).multipliedBy(0.7)
        //        }
        
        //        addCustomDivider()
    }
    
    /// 添加分隔条
    private func addCustomDivider() {
        let divider = NSView()
        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor(hex: "#EBEDEF").cgColor
        divider.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(divider)
        
        divider.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.width.equalTo(1)
            make.centerX.equalToSuperview()
        }
        
    }
    
    private func setupInitialSelection() {
        // 默认选中第一项
        if !sidebarViewController.menuItems.isEmpty {
            sidebarViewController.selectItem(at: 0)
            handleSidebarSelection(0)
        } else {
            sidebarViewController.menuItems = []
            contentViewController.updateContent(with: [], title: "")
        }
        
    }
    
    private func handleSidebarSelection(_ index: Int) {
        guard index >= 0 && index < sidebarViewController.menuItems.count else { return }
        
        selectedMenuItem = sidebarViewController.menuItems[index]
        if let selectedMenuItem = selectedMenuItem {
            if deleteing {
                deleteing = false
                selectedMenuItem.isSelect = false
            }
            /// 当前被选中，并且是编辑模式，需要让下面的都变成
            if selectedMenuItem.isSelect, editMode {
                for item in selectedMenuItem.sendContent {
                    item.isSelect = true
                }
                currentContentItems = selectedMenuItem.sendContent
            } else {
                currentContentItems = selectedMenuItem.sendContent
            }
            
            if let foldName = selectedMenuItem.foldName {
                if foldName == "image" {
                    contentViewController.typeImage = true
                } else {
                    contentViewController.typeImage = false
                }
            }
            
        }
        
        
        contentViewController.updateContent(with: currentContentItems, title: "")
    }
    
    /// 关闭弹窗
    func closePopover() {
        if popupView != nil {
            popupView?.hide()
        }
    }
    
    /// 更新搜索数据
    func updateSearchData(_ text: String) {
        print("输入框搜索的数据：\(text)")
        searchText = text
        contentViewController.updateContent(with: [], title: "")
        if !text.isEmpty {
            sidebarViewController.searchShow = true
            viewModel.page = 1
            viewModel.searchTransferData(keyword: text)
        } else {
            sidebarViewController.searchShow = false
            tableViewReloadData()
        }
        
    }
    
    /// 是否全选
    func allSelectItems(isAll: Bool) {
        
        for item in sidebarViewController.menuItems {
            item.isSelect = isAll
            for subItem in item.sendContent {
                subItem.isSelect = isAll
            }
        }
        sidebarViewController.tableViewReload()
        if let selectedMenuItem = selectedMenuItem {
            /// 当前被选中，并且是编辑模式，需要让下面的都变成
            if selectedMenuItem.isSelect, editMode {
                for item in selectedMenuItem.sendContent {
                    item.isSelect = true
                }
                currentContentItems = selectedMenuItem.sendContent
            } else {
                currentContentItems = selectedMenuItem.sendContent
            }
        }
        
        contentViewController.updateContent(with: currentContentItems, title: "")
    }
    
    /// 获取列表是否被全部选中
    func getCurrentAllSelectState() -> Bool {
        
        var allSelect = false
        for item in sidebarViewController.menuItems {
            if item.isSelect == false {
                allSelect = false
                break
            } else {
                allSelect = true
            }
        }
        return allSelect
    }
    
    /// 刷新tableView并更新空数据状态
    func tableViewReloadData() {
        /// 如果有搜索文本，需要进行展示数据的处理。
        if let searchText = searchText {
            if !searchText.isEmpty {
                //MARK: 询问iOS侧逻辑，搜索数据是从分类数组搜索的
                sidebarViewController.menuItems = viewModel.transferRecordsSortByType
                if let transfer = sidebarViewController.menuItems.first {
                    notDataView.isHidden = true
                    contentViewController.updateContent(with: transfer.sendContent, title: "")
                } else {
                    contentViewController.updateContent(with: [], title: "")
                    notDataView.isHidden = false
                }
                
                return
            }
        }
        
        if currentSortType == .sortList {
            
            //MARK: 为什么要写过滤？！因为数据库返回的id竟然有重复的，你敢信，还是偶现
            var testIds: [Int64] = []
            var testItems: [MITransferRecord] = []
            for item in viewModel.transferRecordsSortByTime {
                if let testId = item.id {
                    ShareAPI.shared().log(2, "过滤前拿到到数组中的id：\(testId)")
                    if !testIds.contains(testId) {
                        testIds.append(testId)
                        ShareAPI.shared().log(2, "过滤后添加到数组中的id：\(testId)")
                        testItems.append(item)
                    }
                }
            }
            ShareAPI.shared().log(2, "过滤后添加到数组中的元素数量：\(testItems.count)")
            ShareAPI.shared().log(2, "当前页码为：\(viewModel.page)")
            if deleteing {
                deleteing = false
                deleteItemUpdateAllSelectHandler?(testItems.isEmpty)
            }
            sidebarViewController.menuItems = testItems
            if let transfer = sidebarViewController.menuItems.first {
                listSelectClickHandler?(getCurrentAllSelectState())
                notDataView.isHidden = true
                contentViewController.updateContent(with: transfer.sendContent, title: "")
            } else {
                contentViewController.updateContent(with: [], title: "")
                notDataView.isHidden = false
            }
        } else {
            sidebarViewController.menuItems = viewModel.transferRecordsSortByType
            if let transfer = sidebarViewController.menuItems.first {
                notDataView.isHidden = true
                contentViewController.updateContent(with: transfer.sendContent, title: "")
            } else {
                contentViewController.updateContent(with: [], title: "")
                notDataView.isHidden = false
            }
        }
        // 如果有数据，默认选中第一行
        if !sidebarViewController.menuItems.isEmpty {
            // 使用异步确保在UI更新完成后选中第一行
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.sidebarViewController.selectItem(at: sidebarViewController.selectedRow)
            }
        }
        
    }
    
    /// 详情页面点击全选后，要同步给列表页面
    func contentAllSelectToSidebar(_ isAll: Bool) {
        
        if isAll {
            if let selectedMenuItem = selectedMenuItem {
                selectedMenuItem.isSelect = true
                for item in selectedMenuItem.sendContent {
                    item.isSelect = true
                }
                guard let targetIndex = sidebarViewController.menuItems.firstIndex(where: { $0.id == selectedMenuItem.id }) else {
                    // 未找到元素，处理错误（如打印提示）
                    print("未找到目标元素")
                    return
                }
                sidebarViewController.menuItems[targetIndex] = selectedMenuItem
                
            }
        } else {
            if let selectedMenuItem = selectedMenuItem {
                selectedMenuItem.isSelect = false
                for item in selectedMenuItem.sendContent {
                    item.isSelect = false
                }
                
                guard let targetIndex = sidebarViewController.menuItems.firstIndex(where: { $0.id == selectedMenuItem.id }) else {
                    // 未找到元素，处理错误（如打印提示）
                    print("未找到目标元素")
                    return
                }
                sidebarViewController.menuItems[targetIndex] = selectedMenuItem
                
            }
        }
        
    }
    
    /// 详情页面选择发生变化后同步左侧列表的cell状态
    func contentSelectToSidebar(_ isAll: Bool) {
        
        if isAll {
            if let selectedMenuItem = selectedMenuItem {
                selectedMenuItem.isSelect = true
                guard let targetIndex = sidebarViewController.menuItems.firstIndex(where: { $0.id == selectedMenuItem.id }) else {
                    // 未找到元素，处理错误（如打印提示）
                    print("未找到目标元素")
                    return
                }
                sidebarViewController.menuItems[targetIndex] = selectedMenuItem
                var allSelect = false
                for item in selectedMenuItem.sendContent {
                    if item.isSelect == false {
                        allSelect = false
                        break
                    } else {
                        allSelect = true
                    }
                }
                /// 回调给chaung
                listSelectClickHandler?(allSelect)
            }
        } else {
            if let selectedMenuItem = selectedMenuItem {
                selectedMenuItem.isSelect = false
                guard let targetIndex = sidebarViewController.menuItems.firstIndex(where: { $0.id == selectedMenuItem.id }) else {
                    // 未找到元素，处理错误（如打印提示）
                    print("未找到目标元素")
                    return
                }
                sidebarViewController.menuItems[targetIndex] = selectedMenuItem
                /// 回调给窗口顶部的全选按钮更新文案
                listSelectClickHandler?(false)
            }
        }
        
    }
    
    /// 让搜索框失去焦点
    func touchViewFirstResponder() {
        DispatchQueue.main.async {
            self.view.window?.makeFirstResponder(self.view)
        }
    }
    
    /// 删除操作
    func deleteItems() {
        var delete = false
        for item in sidebarViewController.menuItems {
            if item.isSelect {
                delete = true
                break
            }
            for subItem in item.sendContent {
                if subItem.isSelect {
                    delete = true
                    break
                }
            }
        }
        
        /// 判断是否执行删除操作
        if delete {
            MIMACDownloadFolderManager().deleteRecordTipAlert(message: "请确认是否删除记录。".localized) { [weak self] shouldDelete in
                guard let self = self else { return }
                if shouldDelete {
                    print("点击了确定")
                    self.deleteing = true
                    self.viewModel.deleteSelectedFiles()
                } else {
                    print("点击了取消")
                }
            }
        } else {
            print("没有选中要删除的记录")
        }
    }
    
    /// 返回当前列表是否有数据
    func getItemsEmpty() -> Bool {
        return sidebarViewController.menuItems.isEmpty
    }
    
    /// 查看详情列表对应的item的文件
    func contentLookFile(_ item: MITransferFile) {
        let filePath = item.fileUrl ?? ""
        print("文件相对路径：\(filePath)")
        if item.isSavePhotoLibraryForMac == true {
            if let photosURL = URL(string: "photos://") {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true  // 默认激活应用
                configuration.hides = false  // 不隐藏应用
                NSWorkspace.shared.open(photosURL, configuration: configuration)
            }
            return
        }
        
        if MIMACDownloadFolderManager().checkSystemPathExists(filePath) {
            if transferType == .receive {
                if MIMACDownloadFolderManager().checkDownloadsFolderPermission() {
                    MIMACDownloadFolderManager().openFileFolder(filePath)
                } else {
                    print("没有权限访问下载文件夹")
                    MIMACDownloadFolderManager().showErrorAlert(type: "下载")
                }
            } else {
                if MIMACDownloadFolderManager().checkDocumentsFolderPermission() {
                    MIMACDownloadFolderManager().openFileFolder(filePath)
                } else {
                    print("没有权限访问文档文件夹")
                    MIMACDownloadFolderManager().showErrorAlert(type: "文档")
                }
                
            }
        } else {
            MIMACDownloadFolderManager().showFileNoFindAlert { [weak self] shouldDelete in
                guard let self = self else { return }
                if shouldDelete {
                    print("用户点击了删除，执行删除操作")
                    // 执行删除记录的逻辑
                    item.isSelect = true
                    if let searchText = self.searchText {
                        if !searchText.isEmpty {
                            self.viewModel.historyPageType = .search
                        } else {
                            self.viewModel.historyPageType = .history
                        }
                    }
                    self.viewModel.deleteSelectedFiles()
                    
                } else {
                    print("用户点击了忽略，不执行删除")
                    // 继续执行其他逻辑
                }
            }
        }
    }
    
    /// 是否启动右侧的悬浮效果
    func contentHoverStyle(show: Bool) {
        ContentGraySelectionRowView.allowHoverEffect = !show
        
        if !show {
            contentViewController.tableViwDeselectAll()
        }
    }
    
    
    func showContextMenu(_ sender: NSButton, model: MITransferFile) {
        let menu = NSMenu()
        menu.delegate = self
        if model.transferType == .receive {
            // 添加菜单项并明确设置target
            let lookItem = NSMenuItem(title: "view".localized, action: #selector(openFile), keyEquivalent: "")
            lookItem.target = self
            lookItem.isEnabled = true
            menu.addItem(lookItem)
            let deleteFileItem = NSMenuItem(title: "删除记录和文件".localized, action: #selector(deleteFileAndRecord), keyEquivalent: "")
            deleteFileItem.target = self
            deleteFileItem.isEnabled = true
            menu.addItem(deleteFileItem)
        }
        let deleteItem = NSMenuItem(title: "delete_record".localized, action: #selector(deleteRecord), keyEquivalent: "")
        deleteItem.target = self
        deleteItem.isEnabled = true
        menu.addItem(deleteItem)
        
        menu.minimumWidth = 150
        let changeXValue: CGFloat = AppLanguage.isRTL ? 150 : -150
        // 在按钮位置弹出菜单
        let point = NSPoint(x: sender.bounds.maxX + changeXValue, y: sender.bounds.maxY+10)
        menu.popUp(positioning: nil, at: point, in: sender)
    }
    
    /// 查看
    @objc func openFile() {
        print("查看")
        let filePath = currentItem?.fileUrl ?? ""
        print("文件相对路径：\(filePath)")
        if let isSavePhotoLibraryForMac = currentItem?.isSavePhotoLibraryForMac,
           isSavePhotoLibraryForMac == true {
            if let photosURL = URL(string: "photos://") {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true  // 默认激活应用
                configuration.hides = false  // 不隐藏应用
                NSWorkspace.shared.open(photosURL, configuration: configuration)
            }
            return
        }
        
        if MIMACDownloadFolderManager().checkSystemPathExists(filePath) {
            if transferType == .receive {
                if MIMACDownloadFolderManager().checkDownloadsFolderPermission() {
                    MIMACDownloadFolderManager().openFileFolder(filePath)
                } else {
                    print("没有权限访问下载文件夹")
                    MIMACDownloadFolderManager().showErrorAlert(type: "下载")
                }
            } else {
                if MIMACDownloadFolderManager().checkDocumentsFolderPermission() {
                    MIMACDownloadFolderManager().openFileFolder(filePath)
                } else {
                    print("没有权限访问文档文件夹")
                    MIMACDownloadFolderManager().showErrorAlert(type: "文档")
                }
                
            }
        } else {
            MIMACDownloadFolderManager().showFileNoFindAlert { [weak self] shouldDelete in
                guard let self = self else { return }
                if shouldDelete {
                    print("用户点击了删除，执行删除操作")
                    // 执行删除记录的逻辑
                    if let currentItem = self.currentItem {
                        currentItem.isSelect = true
                        if let searchText = self.searchText {
                            if !searchText.isEmpty {
                                self.viewModel.historyPageType = .search
                            } else {
                                self.viewModel.historyPageType = .history
                            }
                        }
                        self.viewModel.deleteSelectedFiles()
                    }
                    
                } else {
                    print("用户点击了忽略，不执行删除")
                    // 继续执行其他逻辑
                }
            }
        }
    }
    
    @objc func deleteFileAndRecord() {
        print("删除记录和文件")
        
        MIMACDownloadFolderManager().deleteRecordTipAlert(message: "确定要删除记录和文件吗？".localized) { [weak self] delete in
            guard let self = self else { return }
            if delete {
                /// 删除记录和文件(数据库记录删除操作以及删除下载文件夹内的资源文件)
                if let currentItem = self.currentItem {
                    /// 数据库的删除操作
                    currentItem.isSelect = true
                    /// 删除选中的文件
                    self.viewModel.deleteSelectedFiles()
                    
                    /// 这是删除原始文件的操作
                    let filePath = currentItem.fileUrl ?? ""
                    print("文件相对路径：\(filePath)")
                    if MIMACDownloadFolderManager().checkSystemPathExists(filePath) {
                        let (success, error) = MIMACDownloadFolderManager().deleteFile(at: filePath)
                        if success {
                            print("文件已成功删除")
                            if self.currentContentItems.contains(currentItem) {
                                let succ = self.currentContentItems.remove(currentItem)
                                if succ {
                                    self.contentViewController.updateContent(with: self.currentContentItems, title: "")
                                }
                            }
                        } else {
                            print("删除失败：\(error?.localizedDescription ?? "未知错误")")
                        }
                    }
                }
            }
        }
        
    }
    
    @objc func deleteRecord() {
        print("删除文件")
        MIMACDownloadFolderManager().deleteRecordTipAlert(message: "确定要删除记录吗？".localized) { [weak self] delete in
            guard let self = self else { return }
            if delete {
                /// 删除记录(数据库记录删除操作)
                if let currentItem = self.currentItem {
                    /// 数据库的删除操作
                    currentItem.isSelect = true
                    /// 删除选中的文件
                    self.viewModel.deleteSelectedFiles()
                }
            }
        }
    }
    
    
}


extension TransmitRecordHoistoryListViewController: NSMenuDelegate {
    
    func menuDidClose(_ menu: NSMenu) {
        contentHoverStyle(show: false)
    }
    
}



// MARK: - 侧边栏控制器
class TransmitRecordSidebarViewController: NSViewController {
    
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// 加载更多回调
    var onLoadMore: (() -> Void)?
    
    /// 当前排序类型
    var currentSortType: MACHeaderSortState = .sortList
    
    /// 当前是在搜索
    var searchShow: Bool = false
    /// 编辑模式
    var editMode: Bool = false {
        didSet {
            tableView.reloadData()
        }
    }
    
    
    
    // MARK: - UI 组件
    private lazy var tableView: NSTableView = {
        let tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.rowHeight = 54
        tableView.wantsLayer = false
        // 设置选择样式
        tableView.selectionHighlightStyle = .regular
        if #available(macOS 11.0, *) {
            // 使用传统样式
            tableView.style = .plain
        }
        // 添加列
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SidebarColumn"))
        column.width = 254
        tableView.addTableColumn(column)
        
        return tableView
    }()
    
    private lazy var scrollView: NSScrollView = {
        let scrollView = NSScrollView()
        scrollView.contentView.drawsBackground = false
        scrollView.backgroundColor = NSColor.white
        scrollView.hasVerticalScroller = true
        scrollView.documentView = tableView
        // 使用自定义的滑动条类
        let customScroller = MICustomScroller()
        // 设置自定义颜色
        customScroller.knobColor = NSColor(hex: "#000000", alpha: 0.1) // 滑块颜色
        customScroller.trackColor = NSColor.clear   // 轨道颜色
        scrollView.verticalScroller = customScroller
        // 移除自动调整的 insets
        if #available(macOS 11.0, *) {
            scrollView.contentInsets = NSEdgeInsetsZero
        }
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.autohidesScrollers = true
        
        return scrollView
    }()
    
    lazy var bottomLineView: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.mi.hex("#000000", alpha:0.1).cgColor
        return view
    }()
    
    // MARK: - 属性
    var menuItems: [MITransferRecord] = [] {
        didSet {
            ShareAPI.shared().log(2, "当前的数据数量：\(menuItems.count)")
            tableView.reloadData()
            isLoading = false
        }
    }
    /// 选择顶部的排序按钮点击回调
    var selectionHandler: ((Int) -> Void)?
    /// 选择更多按钮的点击回调
    var sideBarMoreClickHandler: ((MITransferRecord, NSButton) -> Void)?
    /// 单选按钮的点击回调
    var sideBarSelectClickHandler: ((MITransferRecord) -> Void)?
    /// scrollView滑动回调
    var scrollViewDidChange: (() -> Void)?
    /// head右侧按钮点击回调
    var sideBarSortTouchHandler: ((MACHeaderSortState) -> Void)?
    
    private var isLoading = false
    
    var selectedRow: Int = 0
    
    override func loadView() {
        view = NSView()
        setupUI()
        
        /// 监听滚动事件
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(scrollViewDidScroll),
                                               name: NSView.boundsDidChangeNotification,
                                               object: scrollView.contentView)
        
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 6
        shadow.shadowOffset = NSSize.init(width: 5, height: 0)
        shadow.shadowColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.3)
        
//        view.shadow = shadow
//        view.wantsLayer = true
        
//        // 兼容处理：如果系统版本 < 10.14，使用自定义转换方法
//        if #available(macOS 14.0, *) {
//            view.layer?.shadowPath = NSBezierPath(rect: view.bounds).cgPath
//        } else {
//            let bezierPath = NSBezierPath(rect: view.bounds)
//            view.layer?.shadowPath = cgPath(from: bezierPath)
//        }
        
    }
    
    private func setupUI() {
        view.addSubview(scrollView)
        view.addSubview(bottomLineView)
        
        scrollView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.bottom.trailing.equalToSuperview()
        }
        
        bottomLineView.snp.makeConstraints { make in
            make.top.bottom.trailing.equalTo(0)
            make.width.equalTo(1)
        }
    }
    
    func selectItem(at index: Int) {
        guard index >= 0 && index < menuItems.count else { return }
        
        selectedRow = index
        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        selectionHandler?(index)
    }
    
    func updateHeader(title: String) {
        //        headerView.updateTitle(title)
    }
    
    func setHeaderSort(_ enabled: Bool) {
        //        headerView.sortIsEnabled = enabled
    }
    
    @objc private func scrollViewDidScroll(_ notification: Notification) {
        guard let scrollView = tableView.enclosingScrollView, let contentView = notification.object as? NSClipView else { return }
        /// 滑动回调
        self.scrollViewDidChange?()
        
        /// 计算当前滚动位置与底部的距离
        let contentHeight = contentView.documentView?.bounds.height ?? 0
        let visibleHeight = scrollView.bounds.height
        let scrollOffset = contentView.bounds.origin.y
        
        /// 当滚动到距离底部小于 100 像素，且不在加载中时，触发加载更多
        let bottomOffset: CGFloat = 100
        if (scrollOffset + visibleHeight + bottomOffset) >= contentHeight, !isLoading {
            isLoading = true
            /// 加载更多回调
            onLoadMore?()
            
            print("加载更多回调")
        }
        
    }
    
    func tableViewReload() {
        tableView.reloadData()
    }
    
}

// MARK: - NSTableView 数据源和代理
extension  TransmitRecordSidebarViewController: NSTableViewDataSource, NSTableViewDelegate {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return menuItems.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let menuItem = menuItems[row]
        
        let identifier = NSUserInterfaceItemIdentifier("TransmitRecordSidebarCell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? TransmitRecordSidebarCell ?? {
            let newCell = TransmitRecordSidebarCell()
            
            newCell.isEdit = editMode
            newCell.searchShow = searchShow
            newCell.sortType = currentSortType
            newCell.model = menuItem
            
            return newCell
        }()
        cell.isEdit = editMode
        cell.model = menuItem
        cell.moreClickHandler = { [weak self] testModel, sender in
            guard let self = self else { return }
            self.sideBarMoreClickHandler?(testModel, sender)
        }
        
        cell.selectClickHandler = { [weak self] testModel in
            guard let self = self else { return }
            self.sideBarSelectClickHandler?(testModel)
        }
        
        return cell
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return true
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        if selectedRow >= 0 && selectedRow < menuItems.count {
            self.selectedRow = selectedRow
            selectionHandler?(selectedRow)
        }
    }
    
    // 使用自定义行视图实现灰色选中
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        guard let rowView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("GraySelectionRowView"), owner: nil) as? GraySelectionRowView else {
            return GraySelectionRowView()
        }
        
        // 可以根据行的状态自定义外观
        rowView.cornerRadius = 8.0
        rowView.horizontalPadding = 12.0
        
        return rowView
    }
}



// MARK: - 右侧 内容区域控制器
class TransmitRecordContentViewController: NSViewController {
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// 更多按钮的点击事件回调
    var contentMoreClickHandler: ((MITransferFile, NSButton) -> Void)?
    
    /// scrollView滑动回调
    var scrollViewDidChange: (() -> Void)?
    
    /// 详情页面全选点击回调
    var contentAllSelectHandler: ((Bool) -> Void)?
    
    /// 编辑模式下单选按钮点击回调
    var contentSelectHandler: (() -> Void)?
    
    /// 编辑模式
    var editMode: Bool = false {
        didSet {
            tableViewReload()
        }
    }
    /// 当前点击了哪一行的回调，非编辑模式下才生效
    var contentItemClickHandler: ((MITransferFile) -> Void)?
    
    /// 是否是类型排序，并且是image文件夹
    var typeImage: Bool = false {
        didSet {
            imageTipsView.isHidden = !typeImage
            scrollView.isHidden = typeImage
        }
    }
    
    
    private lazy var tableView: NSTableView = {
        let tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.rowHeight = 40
        tableView.wantsLayer = false
        // 设置选择样式
        tableView.selectionHighlightStyle = .none
        
        if #available(macOS 11.0, *) {
            // 使用传统样式
            tableView.style = .plain
        }
        
        // 添加列
        let titleColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SourceColumn"))
        titleColumn.width = 350
        tableView.addTableColumn(titleColumn)
        
        return tableView
    }()
    
    private lazy var scrollView: NSScrollView = {
        let scrollView = NSScrollView()
        scrollView.contentView.drawsBackground = false
        scrollView.backgroundColor = NSColor.white
        scrollView.hasVerticalScroller = false
        scrollView.documentView = tableView
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.autohidesScrollers = true
        return scrollView
    }()
    
    private lazy var imageTipsView: MACImageTypeTipsView = {
        let view = MACImageTypeTipsView()
        view.onDownloadButtonClicked = {
            MIMACDownloadFolderManager().openDownloadsFolder()
        }
        view.isHidden = true
        return view
    }()
    
    
    // MARK: - 属性
    private var contentItems: [MITransferFile] = []
    
    override func loadView() {
        view = NSView()
        setupUI()
        
        /// 监听滚动事件
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(scrollViewDidScroll),
                                               name: NSView.boundsDidChangeNotification,
                                               object: scrollView.contentView)
        
    }
    
    
    private func setupUI() {
        
        view.addSubview(scrollView)
        view.addSubview(imageTipsView)
        
        scrollView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.bottom.leading.trailing.equalToSuperview()
        }
        
        imageTipsView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
    }
    
    func updateContent(with items: [MITransferFile], title: String) {
        contentItems.removeAll()
        contentItems = items
        tableView.reloadData()
        
        tableView.scrollRowToVisible(0)
//        /// 滚动到顶部
//        if let enclosingScrollView = tableView.enclosingScrollView {
//            enclosingScrollView.contentView.scroll(to: NSPoint(x: 0, y: -scrollView.contentInsets.top))
//            enclosingScrollView.reflectScrolledClipView(enclosingScrollView.contentView)
//        }
    }
    
    @objc func sortViewTouch() {
        print("排序按钮点击")
    }
    
    @objc private func scrollViewDidScroll(_ notification: Notification) {
        guard let _ = notification.object as? NSClipView else { return }
        self.scrollViewDidChange?()
    }
    
    /// 表格刷新
    func tableViewReload() {
        tableView.reloadData()
    }
    
    /// 检测当前页面的所有元素是否被选中
    func checkItems() {
        if editMode {
            var allSelect = false
            for item in contentItems {
                if item.isSelect {
                    allSelect = true
                } else {
                    allSelect = false
                    break
                }
            }
            print("当前是否全选了：\(allSelect)")
//            headerView.updateSelectTitle(allSelect)
        }
    }
    
    /// 弹窗隐藏时需要刷新一下列表，防止列表还有悬浮效果存在
    func tableViwDeselectAll() {
        tableView.deselectAll(self)
        tableView.reloadData()
    }
    
}

// MARK: - 右侧 内容表格数据源和代理
extension TransmitRecordContentViewController: NSTableViewDataSource, NSTableViewDelegate {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return contentItems.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let contentItem = contentItems[row]
        
        var bgColor: NSColor
        if row % 2 == 1 {
            bgColor = NSColor.clear
        } else {
            bgColor = NSColor.init(hex: "#000000", alpha: 0.02)
        }
        
        let identifier = NSUserInterfaceItemIdentifier("TransmitRecordContentCell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? TransmitRecordContentCell ?? {
            let newCell = TransmitRecordContentCell()
            newCell.identifier = identifier
            newCell.isEdit = editMode
            newCell.model = contentItem
            newCell.moreClickHandler = { [weak self] testModel, moreBtn, testCell in
                guard let self = self else { return }
                self.contentMoreClickHandler?(testModel, moreBtn)
            }
            
            newCell.allSelectClickHandler = { [weak self] testModel in
                guard let self = self else { return }
                
                self.contentSelectHandler?()
            }
            
            newCell.bgView.layer?.backgroundColor = bgColor.cgColor
            
            return newCell
        }()
        
        cell.bgView.layer?.backgroundColor = bgColor.cgColor

        cell.isEdit = editMode
        cell.model = contentItem
        return cell
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }
        let selectedRow = tableView.selectedRow
        
        // 保存选中项引用
        var selectedItem: MITransferFile?
        if selectedRow >= 0 && selectedRow < contentItems.count {
            selectedItem = contentItems[selectedRow]
        }
        
        // 立即清除选择状态，防止在弹出NSAlert时保持选中效果
        tableView.deselectAll(self)
        
        // 在清除选择状态后再处理点击事件
        if let item = selectedItem {
            print("选择了内容项: \(item.fileName)")
            if !editMode {
                contentItemClickHandler?(item)
            }
        }
    }
    
    // 使用自定义行视图实现灰色选中
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return ContentGraySelectionRowView()
    }
    
    
}



enum MACHeaderSortState: String, CaseIterable {
    case sortList = "时间排序"
    case typeList = "类型排序"
}








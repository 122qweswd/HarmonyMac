//
//  TransmitRecordSearchViewController.swift
//  MutualInfectionMac
//
//  Created by TS on 2025/11/6.
//

import Foundation
import AppKit


class TransmitRecordSearchViewController: NSViewController {
    
    var transferType: MITransferType = .receive
    
    private var currentItem: MITransferFile?
    
    lazy var headerView: TransmitRecordHeaderView = {
        let headerView = TransmitRecordHeaderView()
        headerView.searchView.isEdit = true
        headerView.needHiddenReceiveSendTab = true
        headerView.categoryView.isHidden = true
        
        /// 关闭按钮点击回调
        headerView.closeHandler = { [weak self] in
            guard let self = self else { return }
            self.touchViewFirstResponder()
            self.closeViewTouch()
        }
        /// 全选按钮点击回调
        headerView.allSelectHandler = { [weak self] isAll in
            guard let self = self else { return }
            splitViewController.allSelectItems(isAll: isAll)
        }
        
        /// 搜索框文本变动回调
        headerView.searchTextHandler = { [weak self] text in
            guard let self = self else { return }
            // 执行搜索
            self.performSearch(with: text)
        }
        /// 编辑按钮的点击事件
        headerView.editHandler = { [weak self] edit, btn in
            guard let self = self else { return }
            self.touchViewFirstResponder()
            self.closePopover()
            
            if edit {
                self.showPopCellDeselectAll(show: true)
                self.showMoreMenu(btn)
            } else {
                self.editMode(edit: edit)
            }
            
        }
        /// 点击headview的回调
        headerView.touchViewHandler = { [weak self] in
            guard let self = self else { return }
            self.touchViewFirstResponder()
            self.closePopover()
        }
        /// 搜索框成为第一响应者
        headerView.onDidBecomeFirstResponderHandler = { [weak self] in
            guard let self = self else { return }
            self.closePopover()
        }
        /// 删除点击回调
        headerView.deleteHandler = { [weak self] in
            guard let self = self else { return }
            splitViewController.deleteItems()
        }
        headerView.wantsLayer = true
        headerView.layer?.backgroundColor = NSColor.init(hex: "#FFFFFF").cgColor
        return headerView
    }()
    
    private lazy var searchView: MACCoutomSearchView = {
        let view = MACCoutomSearchView()
        view.isHidden = true
        view.isEdit = true
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(hex: "#F0F0F0").cgColor
        view.layer?.cornerRadius = 15
        view.layer?.masksToBounds = true
        // 可以设置搜索图标点击回调
        view.onSearchIconClicked = { [weak self] in
            guard let self = self else { return }
            print("搜索图标被点击")
            // 在这里处理搜索逻辑
            self.performSearch()
        }
        
        // 设置文本变化回调
        view.onTextChanged = { [weak self] text in
            guard let self = self else { return }
//            print("搜索文本变化: \(text)")
            // 执行搜索
            self.performSearch(with: text)
        }
        
        return view
    }()
    
    private lazy var closeView: NSButton = {
        let view = NSButton(image: NSImage(named: "close_card")!, target: self, action: #selector(closeViewTouch))
        view.isHidden = true
        view.isBordered = false
        view.wantsLayer = true
        view.layer?.cornerRadius = 17
        view.layer?.masksToBounds = true
        return view
    }()
    
    private lazy var splitViewController: TransmitRecordSearchContentViewController = {
        let controller = TransmitRecordSearchContentViewController()
        controller.transferType = transferType
        
        /// 编辑模式选中按钮点击回调
        controller.contentSelectHandler = { [weak self] isAll in
            guard let self = self else { return }
            self.headerView.updateAllSelect(state: isAll)
        }
        
        controller.contentMoreClickHandler = { [weak self] testModel, sender in
            guard let self = self else { return }
            self.touchViewFirstResponder()
            self.currentItem = testModel
            self.contentHoverStyle(show: true)
            self.showContextMenu(sender, model: testModel)
//            var items: [String] = []
//            if testModel.transferType == .receive {
//                items = ["查看".localized, "删除记录和文件".localized, "删除记录".localized]
//            } else {
//                items = ["delete_record".localized]
//            }
//            
//            // 显示弹窗
//            let popupView = MIMACCustomPopupView(items: items)
//            popupView.index = 1
//            popupView.delegate = self
//            popupView.currentItem = self.currentItem
//            // 传入单元格中的按钮和当前视图
//            // 弹窗显示前禁用表格行的悬浮效果
////            ContentGraySelectionRowView.allowHoverEffect = false
//            self.contentHoverStyle(show: true)
//            popupView.show(relativeTo: sender, in: self.view)
            
            
        }
        return controller
    }()
    
    override func loadView() {
        
        view=NSView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(headerView)
        
//        view.addSubview(searchView)
//        view.addSubview(closeView)
        
        addChild(splitViewController)
        
        view.addSubview(splitViewController.view)
        
//        closeView.snp.makeConstraints { make in
//            make.trailing.equalTo(-16)
//            make.top.equalTo(10)
//            make.width.height.equalTo(35)
//        }
//        searchView.snp.makeConstraints { make in
//            make.leading.equalToSuperview().offset(16)
//            make.top.equalToSuperview().offset(10)
//            make.trailing.equalTo(closeView.snp.leading).offset(-8)
//            make.height.equalTo(35)
//        }
        
        headerView.snp.makeConstraints {
            make in
            make.top.equalTo(view.snp.top).offset(0)
            make.centerX.equalToSuperview()
            make.width.equalToSuperview()
            make.height.equalTo(50)
        }
        
        splitViewController.view.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom)
            make.width.bottom.equalTo(self.view)
            make.leading.equalTo(0)
        }
        
        
    }
    
    @objc func closeViewTouch() {
        
        
        MACNavigationManager.shared.popViewController(animated: true)
        
        
    }
    
    // 执行搜索的方法
    private func performSearch(with text: String? = nil) {
        let searchText = text ?? ""
        print("执行搜索: \(searchText)")
        
        splitViewController.updateSearchData(searchText)
        
    }
    
    /// 让搜索框失去焦点
    func touchViewFirstResponder() {
        DispatchQueue.main.async {
            self.view.window?.makeFirstResponder(self.view)
        }
    }
    
    /// 移除弹窗
    func closePopover() {
        self.splitViewController.closePopover()
    }
    
    /// 编辑模式
    func editMode(edit: Bool) {
        self.splitViewController.editMode = edit
    }
    
    /// 判断需要处理我发送的还是我接收的悬停效果控制
    func showPopCellDeselectAll(show: Bool) {
        
    }
    
    /// 点击编辑时显示弹窗
    func showMoreMenu(_ sender: NSButton) {
        let menu = NSMenu()
        menu.delegate = self
        // 添加菜单项
        menu.addItem(NSMenuItem(title: "编辑".localized, action: #selector(editTouch), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        let customItem = NSMenuItem()
        customItem.target = self
        customItem.action = #selector(sortOrderTouch)
        let customView = CustomMenuItemView(frame: NSRect(x: 0, y: 0, width: 200, height: 40))
        customView.titleText = "sort_by_time".localized
        customView.subtitleText = popShowSortStr()
        customItem.view = customView
        
        menu.addItem(customItem)
        
        menu.minimumWidth = 150
        // 在按钮位置弹出菜单
        let point = NSPoint(x: sender.bounds.minX-170, y: sender.bounds.maxY+15)
        menu.popUp(positioning: nil, at: point, in: sender)
    }
    
    /// 编辑
    @objc func editTouch() {
        
        print("编辑操作")
        
        headerView.btnState(edit: true)
        editMode(edit: true)
        headerView.selectEnable = !splitViewController.getItemsEmpty()
    }
    
    /// 排序操作
    @objc func sortOrderTouch() {
        
        print("按照时间排序")
        if splitViewController.currentSortType == .sortList {
            if splitViewController.currentSort == .descending {
                splitViewController.currentSort = .ascending
            } else {
                splitViewController.currentSort = .descending
            }
        }
        splitViewController.currentSortType = .sortList
    }
    
    
    /// 弹窗显示的数据源
    func popShowSortStr() -> String {
        var timeSub = "ascending_order".localized
        if splitViewController.currentSort == .descending {
            timeSub = "descending_order".localized
        }
        
        return timeSub
    }
    
    /// 是否启动右侧的悬浮效果
    func contentHoverStyle(show: Bool) {
        ContentGraySelectionRowView.allowHoverEffect = !show
        
        if !show {
            splitViewController.tableViwDeselectAll()
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
        
        if let searchItem = currentItem {
            let filePath = searchItem.fileUrl ?? ""
            print("文件相对路径：\(filePath)")
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
                        searchItem.isSelect = true
                        self.splitViewController.viewModel.deleteSelectedFiles()
                        
                    } else {
                        print("用户点击了忽略，不执行删除")
                        // 继续执行其他逻辑
                    }
                }
            }
        }
        
    }
    
    @objc func deleteFileAndRecord() {
        print("删除记录和文件")
        
        if let searchItem = currentItem {
            MIMACDownloadFolderManager().deleteRecordTipAlert(message: "确定要删除记录和文件吗？".localized) { [weak self] delete in
                guard let self = self else { return }
                if delete {
                    /// 数据库的删除操作
                    searchItem.isSelect = true
                    /// 删除选中的文件
                    self.splitViewController.viewModel.deleteSelectedFiles()
                    
                    /// 这是删除原始文件的操作
                    let filePath = searchItem.fileUrl ?? ""
                    print("文件相对路径：\(filePath)")
                    if MIMACDownloadFolderManager().checkSystemPathExists(filePath) {
                        let (success, error) = MIMACDownloadFolderManager().deleteFile(at: filePath)
                        if success {
                            print("文件已成功删除")
                            if self.splitViewController.contentItems.contains(searchItem) {
                                let succ = self.splitViewController.contentItems.remove(searchItem)
                                if succ {
                                    self.splitViewController.updateContent(with: self.splitViewController.contentItems, title: "")
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
        
        if let searchItem = currentItem {
            MIMACDownloadFolderManager().deleteRecordTipAlert(message: "确定要删除记录吗？".localized) { [weak self] delete in
                guard let self = self else { return }
                if delete {
                    /// 数据库的删除操作
                    searchItem.isSelect = true
                    /// 删除选中的文件
                    self.splitViewController.viewModel.deleteSelectedFiles()
                }
            }
            
        }
        
    }
    
    
}

extension TransmitRecordSearchViewController: NSMenuDelegate {
    
    func menuDidClose(_ menu: NSMenu) {
        contentHoverStyle(show: false)
    }
    
}


class TransmitRecordSearchContentViewController: NSViewController {
    
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
    var contentSelectHandler: ((Bool) -> Void)?
    
    /// 当前点击了哪一行的回调，非编辑模式下才生效
    var contentItemClickHandler: ((MITransferFile) -> Void)?
    
    private var searchText: String = ""
    
    /// 接收还是发送
    var transferType: MITransferType = .receive
    
    
    private var isLoading = false
    
    lazy var viewModel: MITransferHistoryViewModel = MITransferHistoryViewModel(transferType: transferType, historyPageType: .search)
    
    /// 当前列表的排序类型
    var currentSortType: MACHeaderSortState = .sortList {
        didSet {
            if currentSortType == .sortList {
                viewModel.menuType = .sortByTime(currentSort)
            } else {
                viewModel.menuType = .sortByType(currentSort)
            }
            
            /// 刷新数据
            updateSearchData(searchText)
            
            /// 详情需要置空
//            updateContent(with: [], title: "")
        }
    }
    
    /// 当前排序类型(升序/降序)
    var currentSort: ConfigSortType = .descending
    
    /// 编辑模式
    var editMode: Bool = false {
        didSet {
            if editMode == false {
                for item in contentItems {
                    item.isSelect = false
                }
            }
            tableViewReload()
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
        scrollView.hasVerticalScroller = true
        scrollView.documentView = tableView
        // 使用自定义的滑动条类
        let customScroller = MICustomScroller()
        // 设置自定义颜色
        customScroller.knobColor = NSColor(hex: "#000000", alpha: 0.1) // 滑块颜色
        customScroller.trackColor = NSColor.clear   // 轨道颜色
        scrollView.verticalScroller = customScroller
        
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.autohidesScrollers = true
        return scrollView
    }()
    
    private lazy var notDataView: MACNotDataView = {
        let view = MACNotDataView()
        view.descriptionView.stringValue = "file_cannot_found".localized
        view.iconView.image = NSImage(named: "icon_empty_search_result")
        view.isHidden = true
        return view
    }()
    
    // MARK: - 属性
    var contentItems: [MITransferFile] = [] {
        didSet {
            if contentItems.isEmpty {
                tableView.isHidden = true
                notDataView.isHidden = searchText.count == 0 ? true : false
                viewModel.page = 1
            } else {
                tableView.isHidden = false
                notDataView.isHidden = true
                tableView.reloadData()
                isLoading = false
            }
            
        }
    }
    
    override func loadView() {
        view = NSView()
        setupUI()
        
        /// 刷新数据
        viewModel.refreshTableView = { [weak self] in
            guard let self = self else { return }
            print("刷新数据")
            tableViewReloadData()
        }
        
        /// 监听滚动事件
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(scrollViewDidScroll),
                                               name: NSView.boundsDidChangeNotification,
                                               object: scrollView.contentView)
        
    }
    
    
    private func setupUI() {
        
        view.addSubview(scrollView)
        view.addSubview(notDataView)
        
        scrollView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.bottom.leading.trailing.equalToSuperview()
        }
        
        notDataView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
    }
    
    /// 关闭弹窗
    func closePopover() {
//        if popupView != nil {
//            popupView?.hide()
//        }
    }
    
    func updateContent(with items: [MITransferFile], title: String) {
        contentItems.removeAll()
        contentItems = items
        tableView.reloadData()
        tableView.scrollRowToVisible(0)
//        /// 滚动到顶部
//        if let enclosingScrollView = tableView.enclosingScrollView {
//            enclosingScrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))
//            enclosingScrollView.reflectScrolledClipView(enclosingScrollView.contentView)
//        }
    }
    
    func updateSearchData(_ search: String) {
        searchText = search
        if !search.isEmpty {
            viewModel.page = 1
            viewModel.searchTransferData(keyword: search, sortByTime: currentSort)
        } else {
            contentItems.removeAll()
            contentItems = []
            tableViewReload()
        }
        
    }
    
    /// 是否全选
    func allSelectItems(isAll: Bool) {
        for item in contentItems {
            item.isSelect = isAll
        }
        tableViewReload()
    }
    
    /// 获取列表是否被全部选中
    func getCurrentAllSelectState() -> Bool {
        var allSelect = true
        for item in contentItems {
            if item.isSelect == false {
                allSelect = false
                break
            }        }
        return allSelect
    }
    
    /// 表格刷新
    func tableViewReload() {
        tableView.reloadData()
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
            print("当前列表数量：\(contentItems.count)")
            print("当前页码：\(viewModel.page), 每页大小：\(viewModel.pageSize)")
            /// 加载更多回调
            if contentItems.count >= (viewModel.pageSize * (viewModel.page-1)) && isLoading == false {
                viewModel.searchTransferData(keyword: searchText, sortByTime: currentSort)
                print("当前的页码：\(self.viewModel.page)")
                print("当前的数据数量：\(self.contentItems.count)")
            }
            isLoading = true
            print("加载更多回调")
        }
        
    }
    
    private func tableViewReloadData() {
        print("tableViewReloadData")
        if let items = viewModel.transferRecordsSortByType.first {
            print("sendContent的数量：\(items.sendContent.count)")
            contentItems = items.sendContent
        } else {
            print("viewModel.transferRecordsSortByType的数量为0")
            contentItems = []
        }
        
        
    }
    
    /// 弹窗隐藏时需要刷新一下列表，防止列表还有悬浮效果存在
    func tableViwDeselectAll() {
        tableView.deselectAll(self)
        tableView.reloadData()
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
                    self.viewModel.deleteSelectedFiles()
                    
                } else {
                    print("用户点击了忽略，不执行删除")
                    // 继续执行其他逻辑
                }
            }
        }
    }
    
    /// 删除操作
    func deleteItems() {
        var delete = false
        for item in contentItems {
            if item.isSelect {
                delete = true
                break
            }
        }
        
        /// 判断是否执行删除操作
        if delete {
            MIMACDownloadFolderManager().deleteRecordTipAlert(message: "请确认是否删除记录。".localized) { [weak self] shouldDelete in
                guard let self = self else { return }
                if shouldDelete {
                    print("点击了确定")
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
        return contentItems.isEmpty
    }
}


extension TransmitRecordSearchContentViewController: NSTableViewDelegate, NSTableViewDataSource {
    
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
                let isAll = getCurrentAllSelectState()
                self.contentSelectHandler?(isAll)
            }
            newCell.bgView.layer?.backgroundColor = bgColor.cgColor
            return newCell
        }()
        cell.isEdit = editMode
        cell.model = contentItem
        cell.bgView.layer?.backgroundColor = bgColor.cgColor
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
                contentLookFile(item)
            }
        }
    }
    
    
    // 使用自定义行视图实现灰色选中
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return ContentGraySelectionRowView()
    }
    
}



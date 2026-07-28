//
//  TransmitRecordController.swift
//  MutualInfection
//
//  Created by 1234 on 2025/9/25.
//

import Cocoa
import AppKit
import Combine

class TransmitRecordController: NSViewController {
    /// 搜索文本
    private var searchText: String?
    
    /// 窗口的宽度
    private let pageWidth: CGFloat = 752
    
    lazy var headerView: TransmitRecordHeaderView = {
        let headerView = TransmitRecordHeaderView()
        /// 关闭按钮点击回调
        headerView.closeHandler = { [weak self] in
            guard let self = self else { return }
            self.touchViewFirstResponder()
            self.closeButtonClicked()
        }
        /// 全选按钮点击回调
        headerView.allSelectHandler = { [weak self] isAll in
            guard let self = self else { return }
            if self.headerView.categoryView.selectedCategory == .receive {
                receiveSplitViewController.allSelectItems(isAll: isAll)
            } else {
                sendSplitViewController.allSelectItems(isAll: isAll)
            }
        }
        /// 发送/接收点击回调
        headerView.currentCategroyHandler = { [weak self] categroy in
            guard let self = self else { return }
            print("当前选择的是\(categroy.rawValue)")
            self.touchViewFirstResponder()
            self.closePopover()
            if categroy == .receive {
                self.receiveSplitViewController.view.snp.updateConstraints { make in
                    make.leading.equalTo(0)
                }
                /// 有搜索内容，需要更新搜索数据
                if let search = self.searchText {
                    self.receiveSplitViewController.updateSearchData(search)
                }
            } else {
                self.receiveSplitViewController.view.snp.updateConstraints { make in
                    make.leading.equalTo(-self.pageWidth)
                }
                /// 有搜索内容，需要更新搜索数据
                if let search = self.searchText {
                    self.sendSplitViewController.updateSearchData(search)
                }
            }
        }
        /// 搜索框文本变动回调
        headerView.searchTextHandler = { [weak self] text in
            guard let self = self else { return }
            self.searchText = text
            self.searchTextChange(text)
        }
        /// 编辑按钮的点击事件
        headerView.editHandler = { [weak self] edit, btn in
            guard let self = self else { return }
            self.touchViewFirstResponder()
            self.closePopover()
            
            if edit {
                self.showPopCellDeselectAll(show: true)
                self.showMoreMenu(btn)
//                let pop = MACTransmitRecordMoreMeumView(items: self.popShowItems())
//                pop.delegate = self
//                pop.selectIndex = self.popSelectIndex()
//                self.showPopCellDeselectAll(show: true)
//                pop.show(relativeTo: btn, in: self.view)
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
            if self.headerView.categoryView.selectedCategory == .receive {
                receiveSplitViewController.deleteItems()
            } else {
                sendSplitViewController.deleteItems()
            }
            
        }
        headerView.wantsLayer = true
        headerView.layer?.backgroundColor = NSColor.init(hex: "#FFFFFF").cgColor
        return headerView
    }()
    
    /// 我接收的
    private lazy var receiveSplitViewController: TransmitRecordHoistoryListViewController = {
        let controller = TransmitRecordHoistoryListViewController()
        controller.transferType = .receive
        controller.listSelectClickHandler = { [weak self] isAll in
            guard let self = self else { return }
            self.headerView.updateAllSelect(state: isAll)
        }
        controller.deleteItemUpdateAllSelectHandler = { [weak self] isEmpty in
            guard let self = self else { return }
            self.headerView.selectEnable = !isEmpty
        }
        return controller
    }()
    
    /// 我发送的
    private lazy var sendSplitViewController: TransmitRecordHoistoryListViewController = {
        let controller = TransmitRecordHoistoryListViewController()
        controller.transferType = .send
        controller.listSelectClickHandler = { [weak self] isAll in
            guard let self = self else { return }
            self.headerView.updateAllSelect(state: isAll)
        }
        controller.deleteItemUpdateAllSelectHandler = { [weak self] isEmpty in
            guard let self = self else { return }
            self.headerView.selectEnable = !isEmpty
        }
        return controller
    }()
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: pageWidth, height: 526))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //        self.view=NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 416))
        //self.view=NSView(frame: NSRect(x: 0, y: 0, width: pageWidth, height: 416))
        
        view.addSubview(headerView)
        
        addChild(receiveSplitViewController)
        addChild(sendSplitViewController)
        view.addSubview(receiveSplitViewController.view)
        view.addSubview(sendSplitViewController.view)
        receiveSplitViewController.view.translatesAutoresizingMaskIntoConstraints = false
        sendSplitViewController.view.translatesAutoresizingMaskIntoConstraints = false
        
        headerView.snp.makeConstraints {
            make in
            make.top.equalTo(view.snp.top).offset(0)
            make.centerX.equalToSuperview()
            make.width.equalToSuperview()
            make.height.equalTo(50)
        }
        
        receiveSplitViewController.view.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom)
            make.width.bottom.equalTo(self.view)
            make.leading.equalTo(0)
            
        }
        
        sendSplitViewController.view.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom)
            make.leading.equalTo(receiveSplitViewController.view.snp.trailing)
            make.width.equalTo(self.view)
            make.bottom.equalTo(self.view)
        }
        
        touchViewFirstResponder()
        
    }
    @objc func closeButtonClicked() {
        self.view.window?.close()
        Gloable.transmitRecordWindow = nil
    }
    
    /// 搜索框内容发送改变，需要传递给当前的列表视图
    func searchTextChange(_ text: String) {
        if headerView.categoryView.selectedCategory == .receive {
            receiveSplitViewController.updateSearchData(text)
        } else {
            sendSplitViewController.updateSearchData(text)
        }
    }
    
    func touchViewFirstResponder() {
        DispatchQueue.main.async {
            self.view.window?.makeFirstResponder(self.view)
        }
    }
    
    /// 移除弹窗
    func closePopover() {
        if headerView.categoryView.selectedCategory == .receive {
            self.receiveSplitViewController.closePopover()
        } else {
            self.sendSplitViewController.closePopover()
        }
    }
    
    /// 编辑模式
    func editMode(edit: Bool) {
        if headerView.categoryView.selectedCategory == .receive {
            self.receiveSplitViewController.editMode = edit
        } else {
            self.sendSplitViewController.editMode = edit
        }
    }
    
    /// 弹窗显示的数据源
    func popShowItems() -> [MACSortMeumItem] {
        
        var timeSub = "ascending_order".localized
        var timeSelect = true
        
        var items: [MACSortMeumItem] = []
        
        if headerView.categoryView.selectedCategory == .receive {
            if receiveSplitViewController.currentSort == .descending {
                timeSub = "descending_order".localized
            }
            if receiveSplitViewController.currentSortType == .sortList {
                timeSelect = true
            } else {
                timeSelect = false
            }
            items = [
                MACSortMeumItem.init(title: "编辑".localized, subTitle: "", isSelect: false, style: 0),
                MACSortMeumItem.init(title: "sort_by_time".localized, subTitle: timeSub, isSelect: timeSelect, style: 1),
//                MACSortMeumItem.init(title: "按类型排序".localized, subTitle: typeSub, isSelect: typeSelect, style: 1)
            ]
        } else {
            if sendSplitViewController.currentSort == .descending {
                timeSub = "descending_order".localized
            }
            
            items = [
                MACSortMeumItem.init(title: "编辑".localized, subTitle: "", isSelect: false, style: 0),
                MACSortMeumItem.init(title: "sort_by_time".localized, subTitle: timeSub, isSelect: true, style: 1)
            ]
        }
        
        return items
    }
    
    
    /// 返回当前pop选中的是第几个
    func popSelectIndex() -> Int{
        /// 默认从1开始，编辑不需要进行有选中标识
        var index = 1
        if headerView.categoryView.selectedCategory == .receive {
            
            if receiveSplitViewController.currentSortType == .sortList {
                index = 1
            } else {
                index = 2
            }
            
        }
        print("当前选中的是：\(index)")
        return index
    }
    
    /// 判断需要处理我发送的还是我接收的悬停效果控制
    func showPopCellDeselectAll(show: Bool) {
        
        if headerView.categoryView.selectedCategory == .receive {
            
            receiveSplitViewController.contentHoverStyle(show: show)
            
        } else {
            sendSplitViewController.contentHoverStyle(show: show)
        }
        
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
        if headerView.categoryView.selectedCategory == .receive {
            headerView.selectEnable = !receiveSplitViewController.getItemsEmpty()
        } else {
            headerView.selectEnable = !sendSplitViewController.getItemsEmpty()
        }
        
    }
    
    /// 排序操作
    @objc func sortOrderTouch() {
        
        print("按照时间排序")
        if headerView.categoryView.selectedCategory == .receive {
            if receiveSplitViewController.currentSortType == .sortList {
                if receiveSplitViewController.currentSort == .descending {
                    receiveSplitViewController.currentSort = .ascending
                } else {
                    receiveSplitViewController.currentSort = .descending
                }
            }
            receiveSplitViewController.currentSortType = .sortList
        } else {
            if sendSplitViewController.currentSortType == .sortList {
                if sendSplitViewController.currentSort == .descending {
                    sendSplitViewController.currentSort = .ascending
                } else {
                    sendSplitViewController.currentSort = .descending
                }
            }
            sendSplitViewController.currentSortType = .sortList
        }
        
    }
    
    
    /// 弹窗显示的数据源
    func popShowSortStr() -> String {
        
        var timeSub = "ascending_order".localized
        
        if headerView.categoryView.selectedCategory == .receive {
            if receiveSplitViewController.currentSort == .descending {
                timeSub = "descending_order".localized
            }
        } else {
            if sendSplitViewController.currentSort == .descending {
                timeSub = "descending_order".localized
            }
            
        }
        
        return timeSub
    }
    
    
}


extension TransmitRecordController: NSMenuDelegate {
    
    func menuDidClose(_ menu: NSMenu) {
        showPopCellDeselectAll(show: false)
    }
    
}


/// 顶部的导航栏
class TransmitRecordHeaderView: NSView {
    
    /// 全选按钮是否响应用户交互
    var selectEnable: Bool = true {
        didSet {
            if selectEnable == false {
                updateAllSelect(state: false)
            }
            allSelectButton.isEnabled = selectEnable
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    /// 关闭按钮回调
    var closeHandler: (() -> Void)?
    
    /// 全选按钮回调
    var allSelectHandler: ((Bool) -> Void)?
    
    /// 删除回调
    var deleteHandler: (() -> Void)?
    
    /// 搜索文本框输入回调
    var searchTextHandler: ((String) -> Void)?
    
    var currentCategroyHandler: ((CategoryType) -> Void)?
    /// 编辑按钮点击事件
    var editHandler: ((Bool, NSButton) -> Void)?
    
    /// 需要隐藏接收、发送tab
    var needHiddenReceiveSendTab: Bool = false
    
    /// 点击空白区域回调
    var touchViewHandler: (() -> Void)?
    /// 输入框成为第一响应者
    var onDidBecomeFirstResponderHandler: (() -> Void)?
    
    /// 内部使用是否是编辑
    private var isEdit: Bool = false
    
    private lazy var closeButton: NSButton = {
        let closeButton = NSButton(title: "关闭", target: self, action:#selector(closeButtonClicked))
        closeButton.setButtonType(.momentaryPushIn)
        closeButton.isBordered = false // 关键属性，禁用系统边框样式
        closeButton.wantsLayer = true // 启用图层支持
        closeButton.image = NSImage(named: "icon_recordClose")
//        closeButton.image = NSImage(named: "chevron_backward")
        closeButton.layer?.cornerRadius = 15
        closeButton.imageScaling = .scaleProportionallyUpOrDown
        return closeButton
    }()
    
    private lazy var allSelectButton: MACPaddingButtonView = {
        let allSelectButton = MACPaddingButtonView(title: "全选".localized, target: self, action:#selector(allSelectButtonClicked))
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.mi.hex("#000000", alpha:0.9), // 字体颜色
            .font: NSFont.mi.pingFangSCRegular(size: 12) // 字体样式
        ]
        allSelectButton.attributedTitle = NSAttributedString(string: "全选".localized, attributes: attributes)
        allSelectButton.setButtonType(.onOff)
        allSelectButton.isBordered = false
        allSelectButton.wantsLayer = true
        allSelectButton.layer?.backgroundColor = NSColor.mi.hex("#000000", alpha:0.05).cgColor
        allSelectButton.layer?.cornerRadius = 16
        allSelectButton.contentTintColor = NSColor.mi.hex("#000000", alpha:0.9)
        allSelectButton.font = NSFont.mi.pingFangSCRegular(size: 12)
        allSelectButton.layer?.masksToBounds = true
//        allSelectButton.cell = PaddingButtonCell()
        allSelectButton.isHidden = true
        return allSelectButton
    }()
    
    private lazy var moreButton: NSButton = {
        let button = NSButton(title: "更多", target: self, action: #selector(moreButtonClicked))
        button.image = NSImage(named: "icon_recordMore")
        button.wantsLayer = true
        button.imageScaling = .scaleProportionallyUpOrDown
        button.isBordered = false
        button.setButtonType(.toggle)
        button.contentTintColor = .black
        return button
    }()
    
    private lazy var deleteButton: NSView = {
        let deleteButton = NSView()
        if #available(macOS 11.0, *) {
            let imageView = NSImageView()
            imageView.image = NSImage(named: "icon_trash")
            imageView.imageScaling = .scaleNone
            deleteButton.addSubview(imageView)
            
            imageView.snp.makeConstraints { make in
                make.width.equalTo(16)
                make.height.equalTo(16)
                make.centerX.equalToSuperview()
                make.centerY.equalToSuperview()
            }
        } else {
            // Fallback on earlier versions
        }
        let tap = NSClickGestureRecognizer(target: self, action: #selector(deleteButtonClicked))
        deleteButton.addGestureRecognizer(tap)
        // 控制按钮图片大小
        deleteButton.wantsLayer = true
        deleteButton.layer?.backgroundColor = NSColor.mi.hex("#000000", alpha:0.05).cgColor
        deleteButton.layer?.cornerRadius = 16
        deleteButton.layer?.masksToBounds = true
        deleteButton.isHidden = true
        
        return deleteButton
    }()
    
    private lazy var cancelButton: MACPaddingButtonView = {
        let cancelButton = MACPaddingButtonView(title: "取消".localized, target: self, action: #selector(cancelButtonClicked))
        cancelButton.imageScaling = .scaleNone
        cancelButton.isBordered = false
        cancelButton.wantsLayer = true
        cancelButton.layer?.backgroundColor = NSColor.mi.hex("#000000", alpha:0.05).cgColor
        cancelButton.layer?.cornerRadius = 16
        cancelButton.layer?.masksToBounds = true
        cancelButton.contentTintColor = NSColor.mi.hex("#000000", alpha:0.9)
        cancelButton.font = NSFont.mi.pingFangSCRegular(size: 12)
        cancelButton.isHidden = true
        return cancelButton
    }()
    
    lazy var searchView: MACCoutomSearchView = {
        let searchView = MACCoutomSearchView()
        searchView.wantsLayer = true
        searchView.layer?.cornerRadius = 15
        searchView.layer?.masksToBounds = true
        searchView.layer?.backgroundColor = NSColor.mi.hex("#000000", alpha:0.05).cgColor
        searchView.onSearchViewClicked = { [weak self] in
            guard let self = self else { return }
            self.onDidBecomeFirstResponderHandler?()
            let searchVC = TransmitRecordSearchViewController()
            if self.categoryView.selectedCategory == .receive {
                searchVC.transferType = .receive
            } else {
                searchVC.transferType = .send
            }
            MACNavigationManager.shared.pushFromAnchor(searchVC, anchorView: self.searchView, animated: true)
            
        }
        
        searchView.onTextChanged = { [weak self] text in
            guard let self = self else { return }
            self.searchTextHandler?(text)
        }
        
        return searchView
    }()
    
    lazy var categoryView: CategorySelectionView = {
        let categoryView = CategorySelectionView()
        categoryView.selectionHandler = { [weak self] cate in
            guard let self = self else { return }
            self.currentCategroyHandler?(cate)
            
        }
        categoryView.selectedCategory = .receive
        categoryView.wantsLayer = true
        categoryView.layer?.backgroundColor = NSColor.mi.hex("#000000", alpha:0.05).cgColor
        categoryView.layer?.cornerRadius = 16
        return categoryView
    }()
    
    lazy var titleView: NSTextField = {
        let view = NSTextField(labelWithString: "")
        view.translatesAutoresizingMaskIntoConstraints = false
        view.stringValue = "互传记录".localized
        view.font = .mi.pingFangSCRegular(size: 13)
        view.textColor = .black
        view.alignment = .center
        return view
    }()
    
    lazy var bottomLineView: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.mi.hex("#000000", alpha:0.1).cgColor
        return view
    }()
    
    func setupShadow(for view: NSView, shadowOffset: NSSize = NSSize(width: 0.0, height: 0.0), shadowBlurRadius: CGFloat = 15) {
        let shadow = NSShadow()
        shadow.shadowBlurRadius = shadowBlurRadius
        shadow.shadowOffset = shadowOffset
        shadow.shadowColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.15)
        
        view.shadow = shadow
        view.wantsLayer = true
        
        // 兼容处理：如果系统版本 < 10.14，使用自定义转换方法
        if #available(macOS 14.0, *) {
            view.layer?.shadowPath = NSBezierPath(rect: view.bounds).cgPath
        } else {
            let bezierPath = NSBezierPath(rect: view.bounds)
            view.layer?.shadowPath = cgPath(from: bezierPath)
        }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        addSubview(closeButton)
        addSubview(allSelectButton)
        addSubview(moreButton)
        addSubview(searchView)
        addSubview(categoryView)
        addSubview(deleteButton)
        addSubview(cancelButton)
        addSubview(titleView)
        addSubview(bottomLineView)
        
        closeButton.snp.makeConstraints {
            make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(self.snp.leading).offset(8)
            make.width.equalTo(32)
            make.height.equalTo(32)
        }
        
        allSelectButton.snp.makeConstraints {
            make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(self.snp.leading).offset(8)
            make.height.equalTo(32)
        }
        
        moreButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(self.snp.trailing).offset(-8)
            make.width.height.equalTo(32)
        }
        
        cancelButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(self.snp.trailing).offset(-8)
            make.height.equalTo(32)
        }
        
        deleteButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(cancelButton.snp.leading).offset(-16)
            make.width.height.equalTo(32)
        }
        
        searchView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(moreButton.snp.leading).offset(-16)
            make.width.equalTo(134)
            make.height.equalTo(32)
        }
        
        categoryView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(closeButton.snp.trailing).offset(16)
            make.height.equalTo(32)
        }
        
        titleView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalTo(200)
            make.centerY.equalToSuperview()
            make.height.equalTo(20)
        }
        
        bottomLineView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalTo(0)
            make.height.equalTo(1)
        }
        
        // 绑定搜索框文本变化
        NotificationCenter.default.publisher(
            for: NSTextField.textDidChangeNotification,
            object: searchView
        )
        .compactMap { $0.object as? NSSearchField }
        .map { $0.stringValue }
        .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main) // 防抖：输入停止300ms后触发
        .sink { [weak self] text in
            guard let self = self else { return }
            print("Combine 实时输入：\(text)")
            self.searchTextHandler?(text)
        }
        .store(in: &cancellables)
        
//        // 绑定搜索框文本结束编辑
//        NotificationCenter.default.publisher(
//            for: NSTextField.textDidEndEditingNotification,
//            object: searchView
//        )
//        .compactMap { $0.object as? NSSearchField }
//        .map { $0.stringValue }
//        .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main) // 防抖：输入停止300ms后触发
//        .sink { [weak self] text in
//            guard let self = self else { return }
//            print("Combine 结束编辑：\(text)")
//            
////            self.searchTextHandler?(text)
//        }
//        .store(in: &cancellables)
        
        
    }
    
    override func layout() {
        super.layout()
        
//        setupShadow(for: categoryView)
//        setupShadow(for: allSelectButton)
//        setupShadow(for: cancelButton)
//        setupShadow(for: deleteButton)
        
    }
    

    // 搜索框被选中（获得焦点）时调用
    @objc func searchFieldDidBecomeFirstResponder(_ notification: Notification) {
        print("NSSearchField 被选中了（获得焦点）")
        // 在这里处理选中后的逻辑（如改变样式、加载数据等）
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func closeButtonClicked() {
        closeHandler?()
    }
    
    @objc private func allSelectButtonClicked() {
        if allSelectButton.state == .on {
            
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.mi.hex("#000000", alpha:0.9), // 字体颜色
                .font: NSFont.mi.pingFangSCRegular(size: 12) // 字体样式
            ]
            allSelectButton.attributedTitle = NSAttributedString(string: "取消全选".localized, attributes: attributes)
            allSelectHandler?(true)
        } else {
            allSelectHandler?(false)
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.mi.hex("#000000", alpha:0.9), // 字体颜色
                .font: NSFont.mi.pingFangSCRegular(size: 12) // 字体样式
            ]
            allSelectButton.attributedTitle = NSAttributedString(string: "全选".localized, attributes: attributes)
            
        }
    }
    
    @objc private func editButtonClicked() {
        
        closeButton.isHidden = true
        searchView.isHidden = true
        categoryView.isHidden = true
        moreButton.isHidden = true
        editHandler?(true, moreButton)
        allSelectButton.isHidden = false
        cancelButton.isHidden = false
        deleteButton.isHidden = false
    }
    
    @objc private func moreButtonClicked() {
        
        editHandler?(true, moreButton)
        
    }
    
    
    @objc private func deleteButtonClicked() {
        deleteHandler?()
    }
    
    @objc private func cancelButtonClicked() {
        
        editHandler?(false, cancelButton)
        btnState(edit: false)
        
    }
    
    /// 按钮的状态
    func btnState(edit: Bool) {
        if edit {
            isEdit = true
            closeButton.isHidden = true
            searchView.isHidden = true
            categoryView.isHidden = true
            moreButton.isHidden = true
            allSelectButton.isHidden = false
            cancelButton.isHidden = false
            deleteButton.isHidden = false
        } else {
            isEdit = false
            allSelectButton.title = "全选".localized
            allSelectButton.state = .off
            allSelectButton.isHidden = true
            cancelButton.isHidden = true
            deleteButton.isHidden = true
            searchView.isHidden = false
            categoryView.isHidden = false
            if needHiddenReceiveSendTab {
                categoryView.isHidden = true
            }
            moreButton.isHidden = false
            closeButton.isHidden = false
        }
    }
    
    /// 更新全选按钮的文案
    func updateAllSelect(state: Bool) {
        if isEdit {
            if state {
                allSelectButton.title = "取消全选".localized
                allSelectButton.state = .on
            } else {
                allSelectButton.title = "全选".localized
                allSelectButton.state = .off
            }
        }
        
    }
    
    
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        
        touchViewHandler?()
    }
    
}

/// 按钮的分类
enum CategoryType: String, CaseIterable {
    case receive = "我接收的"
    case send = "我发送的"
    
    
    var localizedStr: String {
        switch self {
        case .receive:
            return "i_received".localized
        case .send:
            return "i_sent".localized
        }
    }
}

/// 分类选择控件
class CategorySelectionView: NSView {
    
    
    
    /// 选择的分类
    var selectedCategory: CategoryType = .receive {
        didSet {
            selectionHandler?(selectedCategory)
        }
    }
    
    /// 选择的block回调
    var selectionHandler: ((CategoryType) -> Void)?
    
    /// 我接收的
    private lazy var receiveButton: MACConfigurableToggleButton = {
        let buttonStyle = MACConfigurableToggleButton.Style(
            normalColor: .black,
            selectedColor: .mi.hex("#0a59f7"),
            normalBackgroundColor: .clear,
            selectedBackgroundColor: .white,
            fontSize: 12,
            title: CategoryType.receive.localizedStr,
            initialState: .on,
            cornerRadius: 13
        )

        let btn = MACConfigurableToggleButton(style: buttonStyle)
        btn.target = self
        btn.action = #selector(categoryButtonTapped(_:))
        btn.state = .on
        btn.tag = 0
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.snp.makeConstraints { make in
            make.height.equalTo(26)
            make.width.lessThanOrEqualTo(100)
        }
        return btn
    }()
    
    /// 我发送的
    private lazy var sendButton: MACConfigurableToggleButton = {
        let buttonStyle = MACConfigurableToggleButton.Style(
            normalColor: .black,
            selectedColor: .mi.hex("#0a59f7"),
            normalBackgroundColor: .clear,
            selectedBackgroundColor: .white,
            fontSize: 12,
            title: CategoryType.send.localizedStr,
            initialState: .off,
            cornerRadius: 13
        )

        let btn = MACConfigurableToggleButton(style: buttonStyle)
        btn.target = self
        btn.action = #selector(categoryButtonTapped(_:))
        btn.tag = 1
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.snp.makeConstraints { make in
            make.height.equalTo(26)
            make.width.lessThanOrEqualTo(100)
        }
        return btn
    }()
    
    private lazy var stackView: NSStackView = {
        let stack = NSStackView(views: [receiveButton, sendButton])
        stack.orientation = .horizontal
        stack.spacing = 0
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.edgeInsets = NSEdgeInsets(top: 0.0, left: 3.0, bottom: 0.0, right: 3.0)
        return stack
    }()
    
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        addSubview(stackView)
        
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
        
    }
    
    
    @objc private func categoryButtonTapped(_ sender: NSButton) {
        switch sender.tag {
        case 0:
            selectedCategory = .receive
            receiveButton.state = .on
            sendButton.state = .off
        case 1:
            selectedCategory = .send
            receiveButton.state = .off
            sendButton.state = .on
        default:
            break
        }
    }
    
    
}




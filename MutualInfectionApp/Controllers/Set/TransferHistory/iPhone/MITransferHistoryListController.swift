//
//  MITransferHistoryViewController.swift
//  MutualInfectionApp
//
//  Created by Niko on 2025/9/11.
//

import UIKit
import SnapKit
import Hero
import MJRefresh

class MITransferHistoryListController: MIBaseHistoryViewController {
    
    /// 当前控制器
    override var currentController: MITransferHistoryListController? { self }
    
    /// 传输类型
    var transferType: MITransferType = .all
    
    /// 页面类型
    var historyPageType: HistoryPageType = .history {
        didSet {
            if historyPageType == .subFolder {
                menuConfigByReceive = MIMenuConfig.defaultConfig(historyPageType: .subFolder)
            }
        }
    }
    
    lazy var viewModel: MITransferHistoryViewModel = {
        let viewModel = MITransferHistoryViewModel(transferType: transferType, historyPageType: historyPageType, menuType: historyPageType == .search ? .sortByType(.descending) : .sortByTime(.descending))
        /// 刷新数据
        viewModel.refreshTableView = { [weak self] in
            guard let self = self else { return }
            
            tableViewReloadData()
        }
        
        viewModel.hiddenMJFoot = { [weak self] isHidden in
            guard let self = self else { return }
            tableView.mj_footer?.isHidden = isHidden
            
            tableView.mj_footer?.endRefreshing()
        }
        
        if viewModel.historyPageType == .subFolder {
            viewModel.didSelectAction = { [weak self] in
                guard let self = self else { return }
                
                updateSelectAllBtn(isSelectAll: viewModel.isSelectAll)
            }
        }
        return viewModel
    }()
    
    /// 文件夹及其子文件
    var transferRecordsSortByType: MITransferRecord? {
        didSet {
            if let transferRecordsSortByType = transferRecordsSortByType {
                
                /// 图片子文件夹
                if transferRecordsSortByType.foldName == "image" {
                    /// 获取到存储成功但没有identifier的数据
                    let notIdentifierList = transferRecordsSortByType.sendContent.filter { $0.status == .success && ($0.identifier?.isEmpty ?? true) }
                    if notIdentifierList.isEmpty {
                        /// 显示空页面去相册
                        imageDesLabel.isHidden = false
                        searchView.isHidden = true
                        return
                    } else {
                        transferRecordsSortByType.sendContent = notIdentifierList
                    }
                }
                
                viewModel.currentFolder = transferRecordsSortByType
                viewModel.transferRecordsSortByType = [transferRecordsSortByType]
            }
        }
    }
    
    lazy var imageDesLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0 // 允许多行显示
        label.isHidden = true
        
        let text = LocalizedStrings.imageImportedToAlbum
        
        let attributedString = NSMutableAttributedString(string: text)
        let font = UIFont.systemFont(ofSize: 15, weight: .medium)
        
        let blackColor = "#000000".color.withAlpha(0.9)
        let blueColor = "#007AFF".color
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 10 // 设置最小行高为17
        
        let entireRange = NSRange(location: 0, length: attributedString.length)
        attributedString.addAttribute(.font, value: font, range: entireRange)
        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: entireRange)
        attributedString.addAttribute(.foregroundColor, value: blackColor, range: entireRange)
        
        if let range = text.range(of: LocalizedStrings.importedToSystemAlbum) {
            let nsRange = NSRange(range, in: text)
            attributedString.addAttribute(.foregroundColor, value: blueColor, range: nsRange)
        }
        
        label.attributedText = attributedString
        return label
    }()

    
    /// 编辑状态
    var isEdit: Bool = false {
        didSet {
            deleteButton.isHidden = !isEdit
            tableViewReloadData()
        }
    }
    
    /// 删除按钮
    var deleteButton: NotHighlightButton = NotHighlightButton()
    
    /// 搜索页面
    let searchView = MISearchView(frame: .zero)
    
    /// TableView
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .white
        tableView.separatorStyle = .none
        tableView.separatorColor = "#000000".color.withAlpha(0.2)
        
        tableView.showsVerticalScrollIndicator = false
        
        tableView.register(MITransferHistoryTableViewCell.self, forCellReuseIdentifier: MITransferHistoryTableViewCell.className)
        tableView.register(MITransferHistorySectionHeaderView.self, forHeaderFooterViewReuseIdentifier: MITransferHistorySectionHeaderView.className)
        
        tableView.estimatedRowHeight = 47
        tableView.rowHeight = UITableView.automaticDimension
        
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        
        tableView.keyboardDismissMode = .onDrag
        
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: MISafeAreaBottom + 50 + 40, right: 0)
        
        return tableView
    }()
    
    /// 空状态视图
    lazy var emptyStateView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        if NKDevice.isPad {
            view.isHidden = false
        } else {
            view.isHidden = true
        }
        view.isUserInteractionEnabled = false
        
        let imageView = UIImageView()
        imageView.image = UIImage.iconEmptyDocument
        imageView.contentMode = .scaleAspectFit
        
        let titleLabel = UILabel()
        titleLabel.text = LocalizedStrings.noDataAvailable
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = "#A7AAB3".color
        titleLabel.textAlignment = .center
        
    
        view.addSubview(imageView)
        view.addSubview(titleLabel)

        
        imageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-40)
            make.width.height.equalTo(60)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(imageView.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(20)
        }
    
        return view
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initViews()
        configTableViewDelegete()
        

        /// 首次数据加载
        //refreshData()
        /// 添加上拉加载
        addRefreshFooter()
    }
    
    override func mi_preferredNavigationBarHidden() -> Bool {
        if historyPageType == .subFolder {
            return false
        }
        return true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.hero.isEnabled = false
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: - Setup Methods
    func initViews() {
        title = self.title ?? LocalizedStrings.transferRecords
        
        /// 跳转搜索
        hero.isEnabled = true
        searchView.clickClosure = { [weak self] in
            guard let self = self else { return }
            
            let controller = MITransferHistoryListController()
            controller.modalPresentationStyle = .fullScreen
            controller.historyPageType = .search
            controller.transferType = transferType
            controller.searchView.isEdit = true
            
            /// 子文件夹搜索
            if let transferRecordsSortByType = viewModel.currentFolder {
                let record = MITransferRecord()
                record.foldName = transferRecordsSortByType.foldName
                controller.transferRecordsSortByType = record
            }
            
            navigationController?.hero.isEnabled = true
            navigationController?.hero.navigationAnimationType = .fade
            navigationController?.pushViewController(controller, animated: true)
        }
        
        searchView.closeCallBack = { [weak self] in
            guard let self = self else { return }
            navigationController?.hero.isEnabled = true
            navigationController?.hero.navigationAnimationType = .fade
            navigationController?.popViewController(animated: true)
        }
        
        searchView.textDidChange = { [weak self] text in
            guard let self = self else { return }
            viewModel.page = 1
            viewModel.searchTransferData(keyword: text)
        }
        
        // 添加子视图
        view.addSubview(searchView)
        view.addSubview(tableView)
        view.addSubview(emptyStateView)
        view.addSubview(imageDesLabel)
        
        deleteButton.isHidden = true
        deleteButton.setImage(UIImage(systemName: "trash")?.withTintColor("#000000".color.withAlpha(0.85), renderingMode: .alwaysOriginal), for: .normal)
        deleteButton.backgroundColor = .white
        deleteButton.layer.cornerRadius = 20
        configShadow(views: [deleteButton], shadowRadius: 10)
        deleteButton.addClickClosure { [weak self] sender in
            guard let self = self else { return }
            
            if viewModel.selectFileCount > 0 {
                AlertManager.showAlert(title: LocalizedStrings.confirmDeleteRecord, cancelTitle: LocalizedStrings.cancel, confirmTitle: LocalizedStrings.confirm) { [weak self] in
                    guard let self = self else { return }
                    
                    viewModel.deleteSelectedFiles()
                }
            } else {
                
            }
        }
        
        view.addSubview(deleteButton)
        
        searchView.snp.makeConstraints {
            $0.leading.equalToSuperview()
            $0.trailing.equalToSuperview()
            var topOffer: CGFloat = 0
            if viewModel.historyPageType == .search {
                topOffer = MISafeAreaTop + 10
            } else if viewModel.historyPageType == .history {
                topOffer = 0
            } else {
                topOffer = MINavigationView.contentHeight() + MISafeAreaTop
            }
            
            $0.top.equalToSuperview().offset(topOffer)
            $0.height.equalTo(44)
        }
        
        // 设置约束
        tableView.snp.makeConstraints { make in
            make.top.equalTo(searchView.snp.bottom).offset(5)
            make.leading.trailing.bottom.equalToSuperview()
        }
        
        deleteButton.snp.makeConstraints {
            $0.bottom.equalToSuperview().offset(-MISafeAreaBottom - 20)
            $0.centerX.equalToSuperview()
            $0.size.equalTo(CGSize(width: 40, height: 40))
        }
        
        emptyStateView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        imageDesLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(MISafeAreaTop + 150)
            $0.centerX.equalToSuperview()
        }
        
    }
    
    /// 刷新Edit状态UI展示
    override func configEditStatusUI(isEdit: Bool) {
        
        super.configEditStatusUI(isEdit: isEdit)
        
        currentController?.viewModel.transferRecordsSortByTime.forEach {
            $0.isSelect = false
            $0.sendContent.forEach { $0.isSelect = false }
        }
        
        currentController?.viewModel.transferRecordsSortByType.forEach {
            $0.isSelect = false
            $0.sendContent.forEach { $0.isSelect = false }
        }
        
    }
    
    /// 刷新tableView并更新空数据状态
    func tableViewReloadData() {
        if viewModel.historyPageType == .history {
            emptyStateView.isHidden = viewModel.menuType.isSortByTime ? !viewModel.transferRecordsSortByTime.isEmpty : !viewModel.transferRecordsSortByType.isEmpty
        } else if viewModel.historyPageType == .subFolder {
            emptyStateView.isHidden = !viewModel.transferRecordsSortByType.isEmpty
        } else if viewModel.historyPageType == .search {
            emptyStateView.isHidden = !viewModel.transferRecordsSortByType.isEmpty
        }
        
        tableView.reloadData()
    }
}




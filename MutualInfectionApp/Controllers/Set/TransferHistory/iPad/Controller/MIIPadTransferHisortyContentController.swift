//
//  MIIPadTransferHisortyContentController.swift
//  MutualInfectionApp
//
//  Created by Niko on 2025/10/30.
//

import UIKit
import SnapKit
import Hero

class MIIPadTransferHisortyContentController: MIBaseViewController {
    
    /// 返回按钮
    var backItemButton: UIButton?
    /// 左侧按钮
    var leftItemButton: UIButton?
    /// 右侧按钮
    var rightMoreItemButton: UIButton?
    var rightCancelItemButton: UIButton?
    var rightDeleteItemButton: UIButton?
    
    var viewModel: MITransferHistoryViewModel! {
        didSet {
            viewModel.didSelectAction = { [weak self] in
                guard let self = self else { return }
                
                updateSelectAllBtn(isSelectAll: viewModel.isSelectAll)
                
                leftListView.tableViewReloadData()
                rightListView.tableViewReloadData()
            }
            
            viewModel.refreshTableView = { [weak self] in
                guard let self = self else { return }
                emptyStateView.isHidden = !viewModel.transferData.isEmpty
            }
        }
    }
    
    /// 我发送，我接受
    lazy var transferTypeView: MITransferHistoryTransferTypeView = {
        let transferTypeView = MITransferHistoryTransferTypeView()
        
        /// 切换发送和接收
        transferTypeView.receiveCallBack = { [weak self] in
            guard let self = self else { return }
            
            viewModel = MITransferHistoryViewModel(transferType: .receive, historyPageType: .history, menuType: menuConfigByReceive.getCurrentMenuType() ?? .sortByTime(.descending))
            configViewModel()
        }
        
        transferTypeView.sendCallBack = { [weak self] in
            guard let self = self else { return }
            
            viewModel = MITransferHistoryViewModel(transferType: .send, historyPageType: .history, menuType: menuConfigBySend.getCurrentMenuType() ?? .sortByTime(.descending))
            configViewModel()
        }
        return transferTypeView
    }()
    
    /// 搜索页面
    let searchView = MISearchView(frame: .zero)
    
    /// 菜单配置
    var menuConfigByReceive: MIMenuConfig = MIMenuConfig.defaultConfig(historyPageType: .history, transferType: .receive)
    var menuConfigBySend: MIMenuConfig = MIMenuConfig.defaultConfig(historyPageType: .history, transferType: .send)
    
    
    let leftListView = MIIPadTransferHisortyLeftController()
    let rightListView = MIIPadTransferHisortyRightController()
    
    /// 空状态视图
    lazy var emptyStateView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.isHidden = true
        view.isUserInteractionEnabled = true
        
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        viewModel = MITransferHistoryViewModel(transferType: .receive, historyPageType: .history)
        
        setupNaviView()
        setupSubControllers()
        configViewModel()
        searchAction()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.hero.isEnabled = false
    }
}

// MARK: -  Navi
extension MIIPadTransferHisortyContentController {
    
    /// 配置导航
    func setupNaviView() {
        title = title ?? LocalizedStrings.transferRecords
        backItemButton = self.navigationView?.backButton
        
        navigationView?.lineView.isHidden = true
        
#if DEBUG
        let tap = UITapGestureRecognizer(target: self, action: #selector(configTestData))
        self.navigationView?.titleLabel.isUserInteractionEnabled = true
        self.navigationView?.titleLabel.addGestureRecognizer(tap)
#endif
        
        /// 发送接收
        navigationView?.addSubview(transferTypeView)
        transferTypeView.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(82)
            $0.centerY.equalTo((self.navigationView?.backButton)!)
            $0.size.equalTo(CGSize(width: 176, height: 44))
        }
        
        /// 搜索框
        navigationView?.addSubview(searchView)
        searchView.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-82)
            $0.centerY.equalTo((self.navigationView?.backButton)!)
            $0.size.equalTo(CGSize(width: 200, height: 44))
        }
        
        do {
            leftItemButton = self.navigationView?.addLeftBarButtonItemWithTitle(LocalizedStrings.selectAll) { [weak self] sender in
                guard let self = self else { return }
                updateSelectAllBtn(isSelectAll: !sender.isSelected)
                viewModel.selectAll(isSelect: sender.isSelected)
            }
            leftItemButton?.isHidden = true
            leftItemButton?.setTitle(LocalizedStrings.deselectAll, for: .selected)
            leftItemButton?.setTitleColor("#000000".color.withAlpha(0.9), for: .normal)
            leftItemButton?.setBackgroundImage(UIImage.iconHistoryBtnBg, for: .normal)
            leftItemButton?.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
            leftItemButton?.snp.makeConstraints {
                $0.width.equalTo((self.leftItemButton?.textWidth ?? 0) + 20)
            }
        }
        
        do {
            /// 删除
            let deleteImage = UIImage(systemName: "trash")?.withTintColor("#000000".color.withAlpha(0.85), renderingMode: .alwaysOriginal)
            rightDeleteItemButton = self.navigationView?.addRightBarButtonItemWithTitle("") { [weak self] sender in
                guard let self = self else { return }
                
                // TODO: 删除
                AlertManager.showAlert(title: LocalizedStrings.confirmDeleteRecord, cancelTitle: LocalizedStrings.cancel, confirmTitle: LocalizedStrings.confirm) { [weak self] in
                    guard let self = self else { return }
                    
                    viewModel.deleteSelectedFiles()
                }
                
            }
            rightDeleteItemButton?.isHidden = true
            rightDeleteItemButton?.setImage(deleteImage, for: .normal)
            rightDeleteItemButton?.setBackgroundImage(UIImage.iconHistoryBtnBg, for: .normal)
            
            
            /// 取消
            rightCancelItemButton = self.navigationView?.addRightBarButtonItemWithTitle(LocalizedStrings.cancel) { [weak self] sender in
                guard let self = self else { return }
                
                /// 取消全选 结束编辑状态
                updateSelectAllBtn(isSelectAll: false)
                viewModel.selectAll(isSelect: false)
                configEditStatusUI(isEdit: false)
            }
            rightCancelItemButton?.isHidden = true
            rightCancelItemButton?.setTitleColor("#000000".color.withAlpha(0.9), for: .normal)
            rightCancelItemButton?.setBackgroundImage(UIImage.iconHistoryBtnBg, for: .normal)
            rightCancelItemButton?.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
            rightCancelItemButton?.hero.id = "close"
            rightCancelItemButton?.snp.makeConstraints {
                $0.width.equalTo((rightCancelItemButton?.textWidth ?? 0) + 20)
            }
            
            /// 更多
            rightMoreItemButton = self.navigationView?.addRightBarButtonItemWithImage(UIImage.setBtn, UIImage.setBtnPress) { [weak self] sender in
                guard let self = self else { return }
                
                showMoreMenuView()
            }
            
            navigationView?.rightButtonView?.spacing = 24
        }
        
        configShadow(views: [backItemButton, rightMoreItemButton], shadowRadius: 0)
        configShadow(views: [leftItemButton, rightCancelItemButton, rightDeleteItemButton], shadowRadius: 10)
    }
     
    @objc func configTestData() {
        Task {
            await WCDBTestManager.shared.runCompleteTestSuite()
        }
    }
    
    /// 刷新Edit状态UI展示
    func configEditStatusUI(isEdit: Bool) {
        
        transferTypeView.isHidden = isEdit
        searchView.isHidden = isEdit
        
        rightMoreItemButton?.isHidden = isEdit
        backItemButton?.isHidden = isEdit
        
        ///
        leftItemButton?.isSelected = !isEdit
        leftItemButton?.isHidden = !isEdit
        rightCancelItemButton?.isHidden = !isEdit
        rightDeleteItemButton?.isHidden = !isEdit
        
        searchView.isEnable = !isEdit
        leftListView.isEdit = isEdit
        rightListView.isEdit = isEdit
    }
    
    func searchAction() {
        /// 跳转搜索
        hero.isEnabled = true
        searchView.clickClosure = { [weak self] in
            guard let self = self else { return }
            
            let controller = MITransferHistoryListController()
            controller.modalPresentationStyle = .fullScreen
            controller.historyPageType = .search
            controller.transferType = viewModel.transferType
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
    }
}

// MARK: -  Sub Controller
extension MIIPadTransferHisortyContentController {
    
    func configViewModel() {
        leftListView.viewModel = viewModel
        rightListView.viewModel = viewModel
    }
    
    /// 添加子控制器
    private func setupSubControllers() {

        // 添加右侧控制器
        addChild(rightListView)
        contentView.addSubview(rightListView.view)
        rightListView.didMove(toParent: self)

        // 添加左侧控制器
        addChild(leftListView)
        contentView.addSubview(leftListView.view)
        leftListView.didMove(toParent: self)
            
        
        // 布局约束
        leftListView.view.snp.makeConstraints {
            $0.leading.equalToSuperview()
            $0.top.equalToSuperview()
            $0.bottom.equalToSuperview()
            $0.width.equalTo(340)
        }
        
        rightListView.view.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(340)
            $0.trailing.equalToSuperview()
            $0.top.equalToSuperview()
            $0.bottom.equalToSuperview()
        }
        
        view.addSubview(emptyStateView)
        emptyStateView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
}


extension MIIPadTransferHisortyContentController {
    func updateSelectAllBtn(isSelectAll: Bool) {
        leftItemButton?.isSelected = isSelectAll
        leftItemButton?.snp.updateConstraints {
            $0.width.equalTo((self.leftItemButton?.textWidth ?? 0) + 20)
        }
    }
}

extension MIIPadTransferHisortyContentController: MIMenuViewDelegate {
    
    
    private func showMoreMenuView() {
        let menuView = MIMenuView()
        menuView.delegate = self
        
        if viewModel.transferType == .receive {
            menuView.show(config: menuConfigByReceive)
        } else {
            menuView.show(config: menuConfigBySend)
        }
    }
    
    func menuView(_ menuView: MIMenuView, didSelectItem item: MIMenuItemConfig, at index: Int) {
        /// 编辑的时候，改变页面样式
        switch item.menuType {
        case .edit:
            configEditStatusUI(isEdit: true)
            break
        default:
                viewModel.menuType = item.menuType
            break
        }
    }
    
    func menuViewDidDismiss(_ menuView: MIMenuView) {
        
    }
}




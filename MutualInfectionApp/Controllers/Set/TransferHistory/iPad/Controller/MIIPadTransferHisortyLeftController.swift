//
//  MIIPadTransferHisortyLeftController.swift
//  MutualInfectionApp
//
//  Created by Niko on 2025/10/31.
//

import UIKit
import MJRefresh

/// iPad 互传记录左侧列表（分组列表）
class MIIPadTransferHisortyLeftController: UIViewController, MIIPadTransferHistoryUIProtocol {
    
    var viewModel: MITransferHistoryViewModel = MITransferHistoryViewModel(transferType: .receive) {
        didSet {
            viewModel.refreshTableView = { [weak self] in
                guard let self = self else { return }
                
                tableViewReloadData()
            }
            
            viewModel.hiddenMJFoot = { [weak self] isHidden in
                guard let self = self else { return }
                tableView.mj_footer?.isHidden = isHidden
                
                tableView.mj_footer?.endRefreshing()
            }
        }
    }
    
    /// 编辑状态
    var isEdit: Bool = false {
        didSet {
            tableViewReloadData()
        }
    }
    
    lazy var tableView: UITableView = {
        let tableView = createTableView()
        tableView.delegate = self
        tableView.dataSource = self
        return tableView
    }()
    
    lazy var emptyView: UIView = {
        createEmptyView()
    }()
    
    var dataCount: Int {
        return viewModel.transferData.count
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        
        view.layer.shadowColor = "#000000".color.withAlpha(0.15).cgColor
        view.layer.shadowOpacity = 1
        view.layer.shadowOffset = CGSize(width: 6, height: 10)
        view.layer.shadowRadius = 12
        
        /// 添加上拉加载
        addRefreshFooter()
    }
    
    func addRefreshFooter() {
        MJRefreshAutoFooter { [weak self] in
            guard let self = self else { return }
            
            viewModel.getCurrentSortData()
        }
        .autoChangeTransparency(true)
        .link(to: tableView)
    }
    
    /// 刷新tableView并更新空数据状态
    func tableViewReloadData() {
        tableView.reloadData()
    }
}

// MARK: - MIIPadTransferHistoryTableViewProtocol
extension MIIPadTransferHisortyLeftController: MIIPadTransferHistoryTableViewProtocol {
    /// 注册Cell
    func registerCells() {
        tableView.register(MITransferHistorySectionCellView.self, forCellReuseIdentifier: MITransferHistorySectionCellView.className)
        tableView.register(MITransferHistoryTableViewCell.self, forCellReuseIdentifier: MITransferHistoryTableViewCell.className)
    }
}

// MARK: - UITableViewDataSource
extension MIIPadTransferHisortyLeftController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfRowsInSection(section: section, isLeftList: true)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if viewModel.menuType.isSortByTime {
            let cell = tableView.dequeueReusableCell(withIdentifier: MITransferHistorySectionCellView.className, for: indexPath) as? MITransferHistorySectionCellView
            
            guard let cell = cell, let sectionRecord = viewModel.getSectionHeaderData(section: indexPath.row) else { return UITableViewCell() }
            
            cell.sectionView.actionCallBack = {
                sectionRecord.isShow.toggle()
                tableView.reloadData()
            }
            
            cell.sectionView.isEdit = isEdit
            cell.sectionView.arrowButton.isHidden = true
            cell.sectionView.transferRecord = sectionRecord
            
            cell.sectionView.selectActionCallBack = { [weak self] in
                guard let self = self else { return }
                updateSelectSectionData(sectionRecord: sectionRecord)
            }
            
            cell.sectionView.isSelectCell = sectionRecord == viewModel.currentFolder
            
            return cell
        } else {
            
            let cell = tableView.dequeueReusableCell(withIdentifier: MITransferHistoryTableViewCell.className, for: indexPath) as? MITransferHistoryTableViewCell
            
            guard let cell = cell, let sectionRecord = viewModel.getSectionHeaderData(section: indexPath.row) else { return UITableViewCell() }
            cell.isEdit = isEdit
            cell.model = (sectionRecord, nil)
            cell.selectActionCallBack = { [weak self] in
                guard let self = self else { return }
                updateSelectSectionData(sectionRecord: sectionRecord)
            }
            
            cell.isSelectCell = sectionRecord.foldName == viewModel.currentFolder?.foldName
            
            return cell
        }
    }
    
    /// 更新选中状态
    func updateSelectSectionData(sectionRecord: MITransferRecord) {
        sectionRecord.isSelect.toggle()
        
        /// 获取未选中文件数量
        let notSelectCount = sectionRecord.sendContent.count { !$0.isSelect }
        
        if notSelectCount > 0 {
            /// > 0 说明点击的是分区全选
            /// + 未选中
            viewModel.updateSelectFileCount(count: notSelectCount)
        } else {
            /// 说明点击了取消分区全选
            /// - 分区文件总数量
            viewModel.updateSelectFileCount(count: -sectionRecord.sendContent.count)
        }
        
        sectionRecord.sendContent.forEach { $0.isSelect = sectionRecord.isSelect }
    }
}

// MARK: - UITableViewDelegate
extension MIIPadTransferHisortyLeftController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        return viewModel.menuType.isSortByTime ? 70 : UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let sectionRecord = viewModel.getSectionHeaderData(section: indexPath.row) else { return }
        viewModel.currentFolder = sectionRecord
    }
}

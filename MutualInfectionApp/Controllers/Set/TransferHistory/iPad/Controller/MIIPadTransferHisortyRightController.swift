//
//  MIIPadTransferHisortyRightController.swift
//  MutualInfectionApp
//
//  Created by Niko on 2025/10/31.
//

import UIKit

/// iPad 互传记录右侧列表（文件详情列表）
class MIIPadTransferHisortyRightController: UIViewController, MIIPadTransferHistoryUIProtocol {
    
    var viewModel: MITransferHistoryViewModel = MITransferHistoryViewModel(transferType: .receive) {
        didSet {
            viewModel.refreshTableView = { [weak self] in
                guard let self = self else { return }
                
                tableViewReloadData()
            }
        }
    }
    
    // MARK: - Properties

    /// 编辑状态
    var isEdit: Bool = false {
        didSet {
            tableViewReloadData()
        }
    }
           
    /// 文件选中回调
    var didSelectFile: ((MITransferFile) -> Void)?
    
    // MARK: - UI Elements
    
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
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white
        setupTableView()
        
        view.layer.shadowColor = "#000000".color.withAlpha(0.15).cgColor
        view.layer.shadowOpacity = 1
        view.layer.shadowOffset = CGSize(width: 0, height: 10)
        view.layer.shadowRadius = 12
    }
    
    /// 刷新tableView并更新空数据状态
    func tableViewReloadData() {
        emptyView.isHidden = !viewModel.transferData.isEmpty
        tableView.reloadData()
    }
}


// MARK: - MIIPadTransferHistoryTableViewProtocol
extension MIIPadTransferHisortyRightController: MIIPadTransferHistoryTableViewProtocol { 
    func registerCells() {
        tableView.register(MITransferHistoryTableViewCell.self, forCellReuseIdentifier: MITransferHistoryTableViewCell.className)
    }
}

// MARK: - UITableViewDataSource
extension MIIPadTransferHisortyRightController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfRowsInSection(section: section, isRightList: true)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: MITransferHistoryTableViewCell.className, for: indexPath) as? MITransferHistoryTableViewCell else {
            return UITableViewCell()
        }
        
        cell.isEdit = isEdit
        
        let (sectionRecord, file) = viewModel.getRowData(indexPath: indexPath)
        cell.model = (sectionRecord, file)
        cell.selectActionCallBack = { [weak self] in
            guard let self = self else { return }
            viewModel.selectRowAction(indexPath: indexPath)
            tableView.reloadSections([indexPath.section], with: .none)
        }
        
        cell.moreActionCallBack = { [weak self] _ in
            guard let self = self else { return }
            viewModel.cellDidselectAction(indexPath: indexPath)
        }
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension MIIPadTransferHisortyRightController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isEdit || viewModel.transferType == .send { return }
        viewModel.openViewAction(indexPath: indexPath)
    }
}

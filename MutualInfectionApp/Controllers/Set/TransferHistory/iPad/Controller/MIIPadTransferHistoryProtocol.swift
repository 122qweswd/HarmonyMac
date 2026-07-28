//
//  MIIPadTransferHistoryPro.swift
//  MutualInfectionApp
//
//  Created by Niko on 2025/11/3.
//

import UIKit
import SnapKit

// MARK: - MIIPadTransferHistoryUIProtocol
protocol MIIPadTransferHistoryUIProtocol {
    /// 编辑状态
    var isEdit: Bool { get set }
    
    var viewModel: MITransferHistoryViewModel { get set }
}

// MARK: - MIIPadTransferHistoryTableViewProtocol
protocol MIIPadTransferHistoryTableViewProtocol {
    
    /// TableView 实例
    var tableView: UITableView { get }
    
    /// 空状态视图
    var emptyView: UIView { get }
    
    /// 数据源数量
    var dataCount: Int { get }
    
    /// 配置 TableView
    func setupTableView()
    
    /// 注册 Cells
    func registerCells()
    
    /// 更新空状态
    func updateEmptyState()
}

// MARK: - MIIPadTransferHistoryTableViewProtocol 实现
extension MIIPadTransferHistoryTableViewProtocol where Self: UIViewController {
    
    /// 创建 TableView
    func createTableView() -> UITableView {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.separatorStyle = .none
        tableView.backgroundColor = .white
        tableView.showsVerticalScrollIndicator = false
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: MISafeAreaBottom, right: 0)
        
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        
        return tableView
    }
    
    /// 创建空状态视图
    func createEmptyView() -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isHidden = true
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
    }
    
    /// 默认的 setupTableView 实现
    func setupTableView() {
        view.addSubview(tableView)
        view.addSubview(emptyView)
        
        tableView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        
        emptyView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        
        registerCells()
    }
    
    /// 更新空状态
    func updateEmptyState() {
        emptyView.isHidden = dataCount > 0
    }
}

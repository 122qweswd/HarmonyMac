//
//  MITransferHistoryListController+TableView.swift
//  MutualInfectionApp
//
//  Created by Niko on 2025/9/25.
//

import UIKit
import Foundation
import MJRefresh

// MARK: - UITableViewDataSource & UITableViewDelegate

extension MITransferHistoryListController: UITableViewDataSource, UITableViewDelegate {
    
    func addRefreshFooter() {
        MJRefreshAutoFooter { [weak self] in
            guard let self = self else { return }
            
            if viewModel.historyPageType == .search {
                viewModel.searchTransferData(keyword: searchView.searchTextField.text ?? "")
            } else {
                viewModel.getCurrentSortData()
            }
        }
        .autoChangeTransparency(true)
        .link(to: tableView)
    }
    
    func configTableViewDelegete() {
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfRowsInSection(section: section)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: MITransferHistoryTableViewCell.className, for: indexPath) as? MITransferHistoryTableViewCell else {
            return UITableViewCell()
        }
        
        cell.isEdit = isEdit
        
        let (sectionRecord, file) = viewModel.getRowData(indexPath: indexPath)
        cell.model = (sectionRecord, file)
        viewModel.historyPageType == .history ? cell.menuType = viewModel.menuType : nil
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
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let sectionRecord = viewModel.getSectionHeaderData(section: section) else { return nil }
        
        guard let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: MITransferHistorySectionHeaderView.className) as? MITransferHistorySectionHeaderView, viewModel.menuType.isSortByTime, viewModel.historyPageType == .history else {
            return nil
        }
        
        headerView.sectionView.actionCallBack = {
            sectionRecord.isShow.toggle()
            tableView.reloadData()
        }
        
        headerView.sectionView.isEdit = isEdit
        headerView.sectionView.arrowButton.isSelected = sectionRecord.isShow
        headerView.sectionView.transferRecord = sectionRecord
        
        headerView.sectionView.selectActionCallBack = { [weak self] in
            guard let self = self else { return }
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
            
            tableView.reloadSections([section], with: .none)
        }
        
        return headerView
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return viewModel.historyPageType == .history && viewModel.menuType.isSortByTime ? 70 : .zero
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return .zero
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if isEdit || viewModel.transferType == .send { return }
        viewModel.openViewAction(indexPath: indexPath)
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 47
    }
    
    func showDeleteAlert(by files: [MITransferFile]) {
        AlertManager.showAlert(message: LocalizedStrings.fileMovedOrDeleted, cancelTitle: LocalizedStrings.ignore, confirmTitle: LocalizedStrings.delete) { [weak self] in
            guard let self = self else { return }
            viewModel.performDeletion(by: files)
        }
    }
}

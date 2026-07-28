//
//  MIBaseHistoryViewController.swift
//  MutualInfectionApp
//
//  Created by Niko on 2025/10/24.
//

import UIKit

class MIBaseHistoryViewController: MIBaseViewController {

    /// 返回按钮
    var backItemButton: UIButton?
    /// 左侧按钮
    var leftItemButton: UIButton?
    /// 右侧按钮
    var rightMoreItemButton: UIButton?
    var rightCancelItemButton: UIButton?
    
    /// 菜单配置
    var menuConfigByReceive: MIMenuConfig = MIMenuConfig.defaultConfig(historyPageType: .history)
    var menuConfigBySend: MIMenuConfig = MIMenuConfig.defaultConfig(historyPageType: .history, transferType: .send)
    
    /// 当前控制器
    var currentController: MITransferHistoryListController? { nil }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupNaviView()
    }
    
    func setupNaviView() {
        title = title ?? LocalizedStrings.transferRecords
        backItemButton = self.navigationView?.backButton
        
        do {
            leftItemButton = self.navigationView?.addLeftBarButtonItemWithTitle(LocalizedStrings.selectAll) { [weak self] sender in
                guard let self = self else { return }
                updateSelectAllBtn(isSelectAll: !sender.isSelected)
                currentController?.viewModel.selectAll(isSelect: sender.isSelected)
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
            rightCancelItemButton = self.navigationView?.addRightBarButtonItemWithTitle(LocalizedStrings.cancel) { [weak self] sender in
                guard let self = self else { return }
                
                /// 取消全选 结束编辑状态
                updateSelectAllBtn(isSelectAll: false)
                currentController?.viewModel.selectAll(isSelect: false)
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
            
            rightMoreItemButton = self.navigationView?.addRightBarButtonItemWithImage(UIImage.setBtn, UIImage.setBtnPress) { [weak self] sender in
                guard let self = self else { return }
                
                showMoreMenuView()
            }
        }
        
        configShadow(views: [backItemButton, rightMoreItemButton], shadowRadius: 0)
        configShadow(views: [leftItemButton, rightCancelItemButton], shadowRadius: 10)
    }
    
    /// 刷新Edit状态UI展示
    func configEditStatusUI(isEdit: Bool) {
        
        rightMoreItemButton?.isHidden = isEdit
        backItemButton?.isHidden = isEdit
        
        ///
        leftItemButton?.isSelected = !isEdit
        leftItemButton?.isHidden = !isEdit
        rightCancelItemButton?.isHidden = !isEdit
        
        currentController?.searchView.isEnable = !isEdit
        currentController?.isEdit = isEdit
    }
    
}

extension MIBaseHistoryViewController {
    func updateSelectAllBtn(isSelectAll: Bool) {
        leftItemButton?.isSelected = isSelectAll
        leftItemButton?.snp.updateConstraints {
            $0.width.equalTo((self.leftItemButton?.textWidth ?? 0) + 20)
        }
    }
}

extension MIBaseHistoryViewController: MIMenuViewDelegate {
    
    
    private func showMoreMenuView() {
        let menuView = MIMenuView()
        menuView.delegate = self
        if currentController?.viewModel.transferType == .receive {
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
                currentController?.viewModel.menuType = item.menuType
            break
        }
    }
    
    func menuViewDidDismiss(_ menuView: MIMenuView) {
        
    }
}

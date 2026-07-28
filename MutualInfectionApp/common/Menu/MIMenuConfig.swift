//
//  MIMenuConfig.swift
//  MutualInfectionApp
//
//  Created by Niko on 2025/9/15.
//

import Foundation
import UIKit

var selectRowHeight: CGFloat = 45
var normalRowHeight: CGFloat = 35

/// 弹窗配置模型
struct MIMenuConfig {
    /// 弹窗宽度
    var width: CGFloat = 160
    
    /// 每行高度
    var rowHeight: CGFloat = 45
    
    /// 最大显示行数（超出后滚动）
    var maxRows: Int = 5
    
    /// 圆角半径
    var cornerRadius: CGFloat = 8
    
    /// 阴影配置
    var shadowConfig: MIMenuShadowConfig = MIMenuShadowConfig()
    
    /// 背景颜色
    var backgroundColor: UIColor = .white
    
    /// 分割线配置
    var separatorConfig: MIMenuSeparatorConfig = MIMenuSeparatorConfig()
    
    /// 内边距
    var contentInsets: UIEdgeInsets = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)

    /// 列表数据
    var listData: [MIMenuItemConfig] = []
    
    /// 获取当前排序方式
    func getCurrentMenuType() -> ConfigSortState? {
        for itemConfig in listData {
            if itemConfig.isSelectedRow {
                return itemConfig.menuType
            }
        }
        
        return nil
    }
    
    static func defaultConfig(historyPageType: HistoryPageType, transferType: MITransferType = .receive) -> MIMenuConfig {
        // 创建配置
        var config = MIMenuConfig()
        config.width = 160
        config.maxRows = 5
        config.cornerRadius = 8
        config.backgroundColor = .white
        
        // 阴影配置
        config.shadowConfig = MIMenuShadowConfig(
            color: UIColor.black.withAlphaComponent(0.15),
            offset: CGSize(width: 0, height: 2),
            radius: 8,
            opacity: 1.0
        )
        
        // 分割线配置
        config.separatorConfig = MIMenuSeparatorConfig(
            color: UIColor.black.withAlphaComponent(0.1),
            height: 0.5,
            horizontalInset: 16,
            showLastSeparator: false
        )
        
        if historyPageType == .history {
            // 创建菜单项
            var items = [
                configEditModel(),
                configTimeSortModel(),
            ]
            
            /// 接收记录才有按类型排序
            if transferType == .receive {
                items.append(configTypeSortModel())
            }
            
            config.listData = items
        } else if historyPageType == .subFolder {
            // 创建菜单项
            let items = [
                configEditModel(),
                //configTimeSortModel(),
                //configTypeSortModel(),
            ]
            
            config.listData = items
        }
        
        return config
    }
    
    /// 编辑
    static func configEditModel() -> MIMenuItemConfig {
        let config = MIMenuItemConfig(title: LocalizedStrings.edit)
        config.menuType = .edit
        config.rowHeight = normalRowHeight
        
        config.font = .systemFont(ofSize: 17)
        config.titleColor = "#000000".color.withAlpha(0.9)
        
        config.desText = ""
        config.desTitleColor = nil
        
        config.icon = nil
        config.selectIcon = nil
        config.showSeparator = true
        
        return config
    }
    
    /// 时间排序
    static func configTimeSortModel() -> MIMenuItemConfig {
        let config = MIMenuItemConfig(title: LocalizedStrings.sortByTime)
        
        config.selectIcon = UIImage(systemName: "checkmark")?.withTintColor("#000000".color, renderingMode: .alwaysOriginal)
        
        config.font = .systemFont(ofSize: 17)
        config.titleColor = "#000000".color.withAlpha(0.9)
        
        config.desFont = .systemFont(ofSize: 14)
        config.desTitleColor = "#000000".color.withAlpha(0.6)
        
        config.showSeparator = false
        
        /// 默认选中按时间排序降序
        config.isSelectedRow = true
        config.rowHeight = selectRowHeight
        config.menuType = .sortByTime(.descending)
        config.desText = ConfigSortState.sortByTime(.descending).currentSortType?.rawValue
        
        return config
    }
    
    /// 类型排序
    static func configTypeSortModel() -> MIMenuItemConfig {
        let config = MIMenuItemConfig(title: LocalizedStrings.sortByType)
        config.menuType = .sortByType(.none)
        config.rowHeight = normalRowHeight
        config.selectIcon = UIImage(systemName: "checkmark")?.withTintColor("#000000".color, renderingMode: .alwaysOriginal)
        
        config.font = .systemFont(ofSize: 17)
        config.titleColor = "#000000".color.withAlpha(0.9)
        
        config.desText = nil
        config.desFont = .systemFont(ofSize: 14)
        config.desTitleColor = "#000000".color.withAlpha(0.6)
        
        config.showSeparator = false
          
        return config
    }
    
    static func updateSelectConfig(selectConfig: MIMenuItemConfig, menuConig: MIMenuConfig) {
        /// 如果选中的是编辑，所有内容保持不变
        if selectConfig.menuType == .edit { return }
        
        for item in menuConig.listData {
            item.isSelectedRow = false
            if selectConfig === item  {
                item.isSelectedRow = true
                item.menuType = item.menuType.toggleSortDirection()
                item.desText = item.menuType.currentSortType?.rawValue
                item.rowHeight = selectRowHeight
            } else {
                item.menuType = item.menuType.setupDefault()
                item.desText = item.menuType.currentSortType?.rawValue
                item.rowHeight = normalRowHeight
            }
        }
    }
}

/// 阴影配置
struct MIMenuShadowConfig {
    /// 阴影颜色
    var color: UIColor = UIColor.black.withAlphaComponent(0.15)
    
    /// 阴影偏移
    var offset: CGSize = CGSize(width: 0, height: 2)
    
    /// 阴影半径
    var radius: CGFloat = 8
    
    /// 阴影透明度
    var opacity: Float = 1.0
}

/// 分割线配置
struct MIMenuSeparatorConfig {
    /// 分割线颜色
    var color: UIColor = UIColor.black.withAlpha(0.2)
    
    /// 分割线高度
    var height: CGFloat = 0.5
    
    /// 分割线距离弹窗左右的间距
    var horizontalInset: CGFloat = 16
    
    /// 是否显示最后一条分割线
    var showLastSeparator: Bool = false
}

//
//  MIMenuItem.swift
//  MutualInfectionApp
//
//  Created by Niko on 2025/9/15.
//

import Foundation
import UIKit
import WCDBSwift

/// 菜单项模型
class MIMenuItemConfig {
  
    var menuType: ConfigSortState = .none
    
    /// 文本内容
    let title: String
    /// 文本颜色
    var titleColor: UIColor = .black
    /// 选中时的文本颜色
    var selectedTitleColor: UIColor?
    /// 字体
    var font: UIFont = .systemFont(ofSize: 17)
    /// 选中时的字体
    var selectedFont: UIFont?
    
    /// 详情文本
    var desText: String?
    /// 文本颜色
    var desTitleColor: UIColor? = .black
    /// 选中时的文本颜色
    var desSelectedTitleColor: UIColor?
    /// 字体
    var desFont: UIFont = .systemFont(ofSize: 17)
    /// 选中时的字体
    var desSelectedFont: UIFont?
    
    
    /// 左侧图标
    var icon: UIImage?

    /// 左侧选中图标
    var selectIcon: UIImage?
    
    /// 行 选中状态
    var isSelectedRow: Bool = false
    
    /// 是否显示分割线
    var showSeparator: Bool = true
    
    /// 背景颜色
    var backgroundColor: UIColor = .white
    
    /// 选中时的背景颜色
    var selectedBackgroundColor: UIColor?
    
    /// 事件回调
    typealias FormActionBlock = (_ item: MIMenuItemConfig) -> Void
    var rowActionCallBack: FormActionBlock?
    
    
    /// 行高
    var rowHeight: CGFloat?

    /// 额外数据
    var extraData: Any?
    
    init(title: String, icon: UIImage? = nil, isSelected: Bool = false, showSeparator: Bool = true) {
        self.title = title
        self.icon = icon
        self.isSelectedRow = isSelected
        self.showSeparator = showSeparator
    }
    
    func updateRowHeight() {
        //rowHeight = title.heightWithConstrainedWidth(width: 999, font: font) + (desText ?? "").heightWithConstrainedWidth(width: CGFloat.greatestFiniteMagnitude, font: desFont) + 24
    }
    
}

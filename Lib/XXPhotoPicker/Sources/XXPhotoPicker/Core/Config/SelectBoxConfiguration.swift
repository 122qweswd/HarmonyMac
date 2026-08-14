//
//  SelectBoxConfiguration.swift
//  HXPhotoPicker
//
//  Created by Slience on 2020/12/29.
//  Copyright © 2020 Silence. All rights reserved.
//

import UIKit

// MARK: 选择框配置类
public struct SelectBoxConfiguration {
    
    /// 选择框的大小
    public var size: CGSize = CGSize(width: 24, height: 24)
    
    /// 选择框的样式
    public var style: SelectBoxView.Style = .tick
    
    /// 标题的文字大小
    public var titleFontSize: CGFloat = 16
    
    /// 选中之后的 标题 颜色
    public var titleColor: UIColor = .white
    
    /// 暗黑风格下选中之后的 标题 颜色
    public var titleDarkColor: UIColor = .white
    
    /// 选中状态下勾勾的宽度
    public var tickWidth: CGFloat = 1.5
    
    /// 选中之后的 勾勾 颜色
    public var tickColor: UIColor = .white
    
    /// 暗黑风格下选中之后的 勾勾 颜色
    public var tickDarkColor: UIColor = .white
    
    /// 未选中时框框中间的颜色
    public var backgroundColor: UIColor = .clear
    
    /// 暗黑风格下未选中时框框中间的颜色
    public var darkBackgroundColor: UIColor = .clear
    
    /// 选中之后的背景颜色
    public var selectedBackgroundColor: UIColor = "007AFF".color
    
    /// 暗黑风格下选中之后的背景颜色
    public var selectedBackgroudDarkColor: UIColor = "007AFF".color
    
    /// 未选中时的边框宽度
    public var borderWidth: CGFloat = 0
    
    /// 选中时的边框宽度
    public var selectBorderWidth: CGFloat = 0
    
    /// 未选中时的边框颜色
    public var borderColor: UIColor = .white
    
    /// 选中时的边框颜色
    public var selectBorderColor: UIColor = .white
    
    /// 暗黑风格下未选中时的边框颜色
    public var borderDarkColor: UIColor = .white
    
    /// 暗黑风格下选中时的边框颜色
    public var selectBorderDarkColor: UIColor = .white
    
    public init() { }
    
    public mutating func setThemeColor(_ color: UIColor) {
        selectedBackgroundColor = color
        selectedBackgroudDarkColor = color
    }
}

//
//  UIButton+Extension.swift
//  MutualInfectionApp
//
//  Created by Niko on 2025/8/31.
//

import Foundation
import UIKit

// 定义点击事件回调类型
public typealias UIButtonClickClosure = (_ sender: UIButton) -> Void

// 使用关联对象存储闭包
private var buttonClickClosureKey: UInt8 = 0

extension UIButton {
    
    /// 添加点击事件回调（替代 addTarget 方法）
    /// - Parameter closure: 点击事件回调闭包
    func addClickClosure(_ closure: @escaping UIButtonClickClosure) {
        // 存储闭包到关联对象
        objc_setAssociatedObject(self, &buttonClickClosureKey, closure, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // 添加目标-动作
        self.addTarget(self, action: #selector(buttonClickAction(_:)), for: .touchUpInside)
    }
    
    /// 按钮点击事件处理
    /// - Parameter sender: 触发事件的按钮
    @objc private func buttonClickAction(_ sender: UIButton) {
        // 从关联对象中获取闭包并执行
        if let closure = objc_getAssociatedObject(self, &buttonClickClosureKey) as? UIButtonClickClosure {
            closure(sender)
        }
    }
    
    /// 移除点击事件回调
    func removeClickClosure() {
        // 移除关联对象
        objc_setAssociatedObject(self, &buttonClickClosureKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // 移除目标-动作
        self.removeTarget(self, action: #selector(buttonClickAction(_:)), for: .touchUpInside)
    }
}

extension UIButton {
    /// 获取按钮上当前显示的文本宽度
    var textWidth: CGFloat {
        let size = self.title(for: isSelected ? .selected : .normal)?.widthWithConstrainedHeight(height: self.bounds.height, font: self.titleLabel?.font ?? UIFont())
        return size ?? 0
    }
}

public class NotHighlightButton: UIButton {
    public override var isHighlighted: Bool {
        get {
            return false
        }
        set {
            super.isHighlighted = false
        }
    }
}


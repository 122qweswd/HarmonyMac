//
//  UILabel+Extension.swift
//  MutualInfectionApp
//
//  Created by Niko on 2025/9/1.
//
import Foundation
import UIKit

import UIKit

extension UILabel {
    private struct AssociatedKeys {
        static var debugTextKey = "debugTextKey"
    }
    
    
    /// 调试模式下显示的文本内容
    /// 仅在 DEBUG 模式下生效，RELEASE 模式下会被忽略
    var debugText: String? {
        get {
#if DEBUG
            return objc_getAssociatedObject(self, AssociatedKeys.debugTextKey) as? String
#else
            return nil
#endif
        }
        set {
#if DEBUG
            objc_setAssociatedObject(
                self,
                AssociatedKeys.debugTextKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            
            // 设置调试文本
            if let debugText = newValue {
                if self.text?.isEmpty ?? true {
                    self.text = debugText
                    self.accessibilityIdentifier = "DEBUG_LABEL_\(debugText)"
                }
            }
#endif
        }
    }
    
    /// 便捷方法：设置调试文本并返回自身，支持链式调用
    @discardableResult
    func withDebugText(_ text: String) -> UILabel {
        self.debugText = text
        return self
    }
}

// 辅助扩展：添加一些常用的链式方法
extension UILabel {
    @discardableResult
    func withFont(_ font: UIFont) -> UILabel {
        self.font = font
        return self
    }
    
    @discardableResult
    func withText(_ text: String) -> UILabel {
        self.text = text
        return self
    }
    
    @discardableResult
    func withTextColor(_ color: UIColor) -> UILabel {
        self.textColor = color
        return self
    }
    
    @discardableResult
    func withColorText(_ colorText: String) -> UILabel {
        self.textColor = colorText.color
        return self
    }
    
    @discardableResult
    func withTextAlignment(_ alignment: NSTextAlignment) -> UILabel {
        self.textAlignment = alignment
        return self
    }
    
    @discardableResult
    func withNumberOfLines(_ lines: Int) -> UILabel {
        self.numberOfLines = lines
        return self
    }
}

extension UILabel {
    /// 获取UILabel上当前显示的文本宽度
    var textWidth: CGFloat {
        let size = self.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: self.frame.size.height))
        return size.width
    }
    
    /// 获取UILabel上当前显示的文本高度
    var textHeight: CGFloat {
        let size = self.sizeThatFits(CGSize(width: self.frame.size.width, height: CGFloat.greatestFiniteMagnitude))
        return size.height
    }
}


private var monospacedTimerKey: UInt8 = 0
private var originalFontKey: UInt8 = 0
extension UILabel {
    
    /// 使用等宽字体开始点动画（不会跳动）
    /// - Parameters:
    ///   - baseText: 基础文本
    ///   - interval: 动画间隔时间，默认0.5秒
    func startAnimation(baseText: String = "正在连接对方热点", interval: TimeInterval = 0.5) {
        stopAnimation()
        
        // 设置为等宽字体
        let originalFont = self.font
        let monospacedFont = UIFont.monospacedSystemFont(ofSize: self.font?.pointSize ?? 17, weight: .regular)
        
        self.font = monospacedFont
        objc_setAssociatedObject(self, &originalFontKey, originalFont, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        var dotCount = 0
        
        // 动画序列：确保每个状态都是3个字符宽度
        let animationStates = [
            ".  ",  // 1个点 + 2个空格
            ".. ",  // 2个点 + 1个空格
            "..."   // 3个点
        ]
        
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            dotCount = (dotCount + 1) % animationStates.count
            let dots = animationStates[dotCount]
            self.text = baseText + dots
        }
        
        objc_setAssociatedObject(self, &monospacedTimerKey, timer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // 立即显示初始状态
        self.text = baseText + animationStates[0]
    }
    
    /// 停止等宽字体点动画
    func stopAnimation() {
        if let timer = objc_getAssociatedObject(self, &monospacedTimerKey) as? Timer {
            timer.invalidate()
            objc_setAssociatedObject(self, &monospacedTimerKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        
        // 恢复原始字体
        if let originalFont = objc_getAssociatedObject(self, &originalFontKey) as? UIFont {
            self.font = originalFont
            objc_setAssociatedObject(self, &originalFontKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}




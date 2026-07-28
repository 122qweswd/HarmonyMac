//
//  GraySelectionRowView.swift
//  MutualInfectionMac
//
//  Created by apple on 2026/1/14.
//

import Foundation
import AppKit

//MARK: 选中的cell的背景颜色
class GraySelectionRowView: NSTableRowView {
    
    // MARK: - 颜色定义
    private var selectionGrayColor: NSColor {
        return NSColor(hex: "#0a59f7", alpha: 0.1)
    }
    
    // MARK: - 外观属性
    var cornerRadius: CGFloat = 8.0
    var horizontalPadding: CGFloat = 8.0
    var verticalPadding: CGFloat = 2.0
    
    // MARK: - 绘制选中状态
    override func drawSelection(in dirtyRect: NSRect) {
        guard isSelected, selectionHighlightStyle != .none else {
            return
        }
        
        // 使用行的整个 bounds而不是 dirtyRect
        let rowBounds = self.bounds
        
        // 创建带间距的选中区域
        let selectionRect = NSRect(
            x: rowBounds.origin.x + horizontalPadding,
            y: rowBounds.origin.y + verticalPadding,
            width: rowBounds.width - (horizontalPadding * 2),
            height: rowBounds.height - (verticalPadding * 2)
        )
        
        // 绘制圆角矩形
        selectionGrayColor.setFill()
        let selectionPath = NSBezierPath(roundedRect: selectionRect, xRadius: cornerRadius, yRadius: cornerRadius)
        selectionPath.fill()
    }
    
    // MARK: - 确保选中状态正确显示
    override func layout() {
        super.layout()
        // 强制重绘以确保选中状态正确显示
        self.setNeedsDisplay(self.bounds)
    }
    
    // MARK: - 处理鼠标悬停效果（可选）
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if !isSelected {
            self.setNeedsDisplay(self.bounds)
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if !isSelected {
            self.setNeedsDisplay(self.bounds)
        }
    }
    
}

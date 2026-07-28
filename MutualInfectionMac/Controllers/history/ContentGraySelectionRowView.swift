//
//  ContentGraySelectionRowView.swift
//  MutualInfectionMac
//
//  Created by apple on 2026/1/14.
//

import Foundation
import AppKit

/// 悬停hover效果rowView
class ContentGraySelectionRowView: NSTableRowView {
    
    // MARK: - 静态属性
    // 全局标志，用于控制是否允许悬浮效果（当弹窗显示时禁用）
    static var allowHoverEffect: Bool = true
    
    // MARK: - 颜色定义
    
    // 添加选中状态颜色，使用更明显的灰色以示区分
    private var selectionGrayColor: NSColor {
        return NSColor.init(hex: "#C7C7CC")
    }
    
    // 悬停状态颜色
    private var mouseHoverColor: NSColor {
        return NSColor(hex: "#0a59f5", alpha: 0.1)
    }
    
    // MARK: - 外观属性
    var cornerRadius: CGFloat = 4.0
    var horizontalPadding: CGFloat = 8.0
    var verticalPadding: CGFloat = 2.0
    
    // 添加鼠标悬停状态标志
    private var isMouseHovering: Bool = false
    
    // MARK: - 初始化
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTrackingArea()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTrackingArea()
    }
    
    // 设置鼠标跟踪区域以接收鼠标事件
    private func setupTrackingArea() {
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect, .mouseMoved],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    // 当 bounds 改变时更新跟踪区域
    override func layout() {
        super.layout()
        
        // 只有当bounds发生变化时才更新跟踪区域
        guard !self.bounds.isEmpty else { return }
        
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        setupTrackingArea()
        
        // 只在状态改变时才调用setNeedsDisplay
        if isMouseHovering || isSelected {
            self.setNeedsDisplay(self.bounds)
        }
    }
    
    // MARK: - 绘制选中和悬停状态
    override func drawSelection(in dirtyRect: NSRect) {
        isSelected = false
        //        guard isSelected, selectionHighlightStyle != .none else {
        //            return
        //        }
        //        drawBackground(in: dirtyRect, with: selectionGrayColor)
        return
    }
    
    // 重写drawBackground来绘制悬停效果，这样不会影响选中效果的绘制
    private func drawBackground(in rect: NSRect, with color: NSColor) {
        let backgroundRect = createBackgroundRect()
        color.setFill()
        let path = NSBezierPath(roundedRect: backgroundRect, xRadius: cornerRadius, yRadius: cornerRadius)
        path.fill()
    }
    
    override func drawBackground(in dirtyRect: NSRect) {
        super.drawBackground(in: dirtyRect)
        
        // 只有在允许悬浮效果且鼠标确实悬停且未选中时才绘制悬浮背景
        if ContentGraySelectionRowView.allowHoverEffect && isMouseHovering && !isSelected {
            drawBackground(in: dirtyRect, with: mouseHoverColor)
        }
    }
    
    // 辅助方法：创建带间距的选择区域
    private func createBackgroundRect() -> NSRect {
        let rowBounds = self.bounds
        return NSRect(
            x: rowBounds.origin.x + horizontalPadding,
            y: rowBounds.origin.y + verticalPadding,
            width: rowBounds.width - (horizontalPadding * 2),
            height: rowBounds.height - (verticalPadding * 2)
        )
    }
    
    // MARK: - 处理鼠标悬停效果
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isMouseHovering = true
        // 只有在允许悬浮效果时才触发重绘
        if ContentGraySelectionRowView.allowHoverEffect {
            self.setNeedsDisplay(self.createBackgroundRect()) // 只重绘需要的区域
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isMouseHovering = false
        // 只有在允许悬浮效果时才触发重绘
        if ContentGraySelectionRowView.allowHoverEffect {
            self.setNeedsDisplay(self.createBackgroundRect()) // 只重绘需要的区域
        }
    }
}

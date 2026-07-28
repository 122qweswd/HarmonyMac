//
//  MISingleLineTextView.swift
//  MutualInfectionMac
//
//  Created by delegate on 2025/9/29.
//

import AppKit

class MISingleLineTextView: NSTextView, NSTextViewDelegate {
    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        setupTextView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTextView()
    }
    
    private func setupTextView() {
        // 基本配置
        self.delegate = self
        self.isEditable = true  // 确保可编辑
        self.isSelectable = true  // 确保可选择
        self.autoresizingMask = [.width]  // 自动适应宽度
        
        // 配置文本容器
        textContainer?.maximumNumberOfLines = 1
        textContainer?.lineBreakMode = .byTruncatingTail
        textContainer?.widthTracksTextView = true  // 宽度跟踪文本视图
        textContainer?.heightTracksTextView = true  // 高度跟踪文本视图
        
        // 禁用滚动和边框
        enclosingScrollView?.hasVerticalScroller = false
        enclosingScrollView?.hasHorizontalScroller = false
        enclosingScrollView?.borderType = .noBorder
        enclosingScrollView?.autoresizingMask = [.width, .height]
        
        // 禁用自动调整大小
        isVerticallyResizable = false
        isHorizontallyResizable = false
        setContentHuggingPriority(.required, for: .vertical)
        
        // 计算行高并设置约束
        if let font = font {
            let layoutManager = NSLayoutManager()
            let lineHeight = layoutManager.defaultLineHeight(for: font)
            // 设置高度约束，添加较低优先级避免冲突
            let heightConstraint = self.heightAnchor.constraint(equalToConstant: lineHeight + 6)
            heightConstraint.priority = .defaultHigh
            heightConstraint.isActive = true
        }
        
        // 确保文本视图可以成为第一响应者（接收输入焦点）
        self.becomeFirstResponder()
    }
    
    // 处理文本输入
    func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString text: String?) -> Bool {
        // 允许空替换（删除操作）
        guard let text = text else { return true }
        
        // 禁止换行符，但允许所有其他字符
        if text.contains("\n") || text.contains("\r") {
            return false
        }
        
        return true
    }
    
    // 确保可以获得焦点
    override func becomeFirstResponder() -> Bool {
        return true
    }
}

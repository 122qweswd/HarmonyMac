//
//  MIMACCustomPopupView.swift
//  MutualInfectionMac
//
//  Created by TS on 2025/10/30.
//

import Cocoa

// 弹窗箭头位置枚举
enum MIMACArrowPosition {
    case top
    case middle
    case bottom
}

// 弹窗内容点击回调协议
protocol MIMACCustomPopupViewDelegate: AnyObject {
    func popupView(_ popupView: MIMACCustomPopupView, didSelectItemAt index: Int)
    func popupViewDidDismiss(_ popupView: MIMACCustomPopupView)
}

class MIMACCustomPopupView: NSView {
    
    /// 搜索状态下，需要进行数据携带，非搜索状态目前不使用。
    var currentItem: MITransferFile?
    
    /// 弹窗索引(用来区分哪边展示的弹窗)
    var index: Int = 0
    
    //MARK: 配置属性
    /// 圆角
    var cornerRadius: CGFloat = 8.0
    /// 阴影圆角
    var shadowRadius: CGFloat = 8.0
    /// 阴影
    var shadowOpacity: Float = 0.5
    /// 阴影偏移量
    var shadowOffset: NSSize = .init(width: -2, height: 2)
    /// 箭头宽度
    var arrowWidth: CGFloat = 12.0
    /// 箭头高度
    var arrowHeight: CGFloat = 20.0
    /// 展示内容的内边距
    var contentInsets: NSEdgeInsets = .init(top: 0, left: 12, bottom: 0, right: 12)
    /// 弹窗的背景颜色
    var backgroundColor: NSColor = NSColor.init(hex: "#F3F3F5")
    
    // 数据与回调
    weak var delegate: MIMACCustomPopupViewDelegate?
    private var items: [String] = []
    
    //MARK: 状态属性
    /// 箭头在右侧的位置
    private var arrowPosition: MIMACArrowPosition = .middle
    /// 是否展示
    private var isShowing: Bool = false
    private var globalMonitor: Any?
    private weak var parentView: NSView?
    private let contentView = NSView()
    
    /// 箭头绘制层
    private let arrowLayer = CAShapeLayer()
    
    // 初始化
    init(items: [String]) {
        self.items = items
        super.init(frame: .zero)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    // 视图设置
    private func setupView() {
        wantsLayer = true
        layer?.masksToBounds = false
        layer?.backgroundColor = NSColor.clear.cgColor
        
        // 添加半透明遮罩层
        let maskLayer = NSView(frame: .zero)
        maskLayer.wantsLayer = true
        maskLayer.layer?.backgroundColor = NSColor.clear.cgColor
        maskLayer.translatesAutoresizingMaskIntoConstraints = false
        maskLayer.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(maskTapped)))
        addSubview(maskLayer)
        
        /// 内容视图（带箭头的主体部分）
        contentView.wantsLayer = true
        contentView.layer?.masksToBounds = false
        contentView.layer?.backgroundColor = backgroundColor.cgColor
        contentView.layer?.cornerRadius = cornerRadius
        contentView.layer?.shadowColor = NSColor.red.cgColor
        contentView.layer?.shadowRadius = shadowRadius
        contentView.layer?.shadowOpacity = shadowOpacity
        contentView.layer?.shadowOffset = shadowOffset
        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)
        
        /// 添加内容
        let stackView = NSStackView()
        stackView.wantsLayer = true
        stackView.orientation = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.layer?.backgroundColor = NSColor.clear.cgColor
        contentView.addSubview(stackView)
        
        maskLayer.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        stackView.snp.makeConstraints { make in
            // 修正约束，确保内容完全在contentView内部
            make.top.equalTo(contentView.snp.top).offset(contentInsets.top)
            make.bottom.equalTo(contentView.snp.bottom).offset(-contentInsets.bottom)
            make.leading.equalTo(contentView.snp.leading).offset(contentInsets.left)
            make.trailing.equalTo(contentView.snp.trailing).offset(-contentInsets.right)
        }
        // 直接在stackView上设置内容压缩阻力优先级
        stackView.setContentCompressionResistancePriority(.required, for: .vertical)
        stackView.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        /// 添加展示的文案
        items.enumerated().forEach { index, title in
            let button = NSButton(title: title, target: self, action: #selector(itemTapped(_:)))
            button.tag = index
            button.bezelStyle = .texturedRounded
            button.wantsLayer = true
            button.isBordered = false
            button.alignment = .left
            button.setButtonType(.momentaryLight)
            button.layer?.backgroundColor = .clear
            // 设置较高的优先级，确保按钮能够响应点击事件
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
            button.setContentCompressionResistancePriority(.required, for: .vertical)
            button.translatesAutoresizingMaskIntoConstraints = false
            // 移除固定宽度约束，让按钮根据内容自适应
            // 但保留最小宽度确保可点击区域足够大
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
            button.heightAnchor.constraint(equalToConstant: 30).isActive = true
            stackView.addArrangedSubview(button)
        }
        
        /// 配置箭头图层
        arrowLayer.fillColor = backgroundColor.cgColor
        /// 确保在内容视图下方/
        layer?.addSublayer(arrowLayer)
    }
    
    /// 替换原有的draw方法，使用图层绘制箭头
    private func updateArrowPosition() {
        let path = NSBezierPath()
        let contentFrame = contentView.frame
        
        /// 计算箭头位置（右侧）
        let arrowX = contentFrame.maxX
        var arrowY: CGFloat = 0
        
        switch arrowPosition {
        case .top:
            arrowY = contentFrame.minY + 15
        case .middle:
            arrowY = contentFrame.midY
        case .bottom:
            arrowY = contentFrame.maxY - 15
        }
        
        /// 绘制箭头（指向右侧）
        path.move(to: NSPoint(x: arrowX, y: arrowY - arrowHeight/2))
        path.line(to: NSPoint(x: arrowX + arrowWidth, y: arrowY))
        path.line(to: NSPoint(x: arrowX, y: arrowY + arrowHeight/2))
        path.close()
        
        /// 转换为CGPath并设置到图层
        if #available(macOS 14.0, *) {
            arrowLayer.path = path.cgPath
        }
    }
    
    /// 计算弹窗位置和箭头位置
    private func calculatePosition(for button: NSButton, in view: NSView) -> NSRect {
        /// 转换按钮坐标到父视图坐标系
        let buttonRect = button.convert(button.bounds, to: view)
        let parentFrame = view.bounds
        
        /// 计算内容大小
        let contentWidth: CGFloat = 120
        let contentHeight: CGFloat = CGFloat(items.count) * 30 + contentInsets.top + contentInsets.bottom
        
        /// 计算内容位置（按钮左侧）
        var contentFrame = NSRect(
            /// 按钮左侧，预留箭头宽度/
            x: buttonRect.minX - contentWidth - arrowWidth,
            y: buttonRect.minY + buttonRect.height/2 - contentHeight/2,
            width: contentWidth,
            height: contentHeight
        )
        
        /// 确保内容在父视图内，添加安全边距避免超出可视区域
        let safeMargin: CGFloat = 10 // 添加小的安全边距
        
        // 优先检查顶部边界
        if contentFrame.minY < parentFrame.minY + safeMargin {
            // 确保内容完全在父视图顶部边界内
            contentFrame.origin.y = parentFrame.minY + safeMargin
            arrowPosition = .top
        } 
        // 然后检查底部边界
        else if contentFrame.maxY > parentFrame.maxY - safeMargin {
            // 确保内容完全在父视图底部边界内
            contentFrame.origin.y = parentFrame.maxY - contentFrame.height - safeMargin
            arrowPosition = .bottom
        } 
        else {
            arrowPosition = .middle
        }
        
        /// 额外检查左侧边界，确保弹窗不会超出左侧
        if contentFrame.minX < parentFrame.minX + safeMargin {
            contentFrame.origin.x = parentFrame.minX + safeMargin
        }
        
        /// 更新内容视图的frame
        contentView.frame = contentFrame
        
        return parentFrame
    }
    
    /// 显示弹窗
    func show(relativeTo button: NSButton, in view: NSView) {
        parentView = view
        let popupFrame = calculatePosition(for: button, in: view)
        
        /// 设置自身frame并添加到父视图
        self.frame = popupFrame
        view.addSubview(self)
        
        /// 添加全局点击监测
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self = self, let parentView = self.parentView else { return }
            
            /// 转换点击位置到弹窗坐标系
            let window = parentView.window
            let mouseLocation = window?.convertPoint(fromScreen: event.locationInWindow) ?? .zero
            let localPoint = self.convert(mouseLocation, from: parentView)
            
            /// 检查点击是否在内容视图外部
            let contentPoint = self.contentView.convert(localPoint, from: self)
            if !self.contentView.bounds.contains(contentPoint) {
                self.hide()
            }
        }
        
        isShowing = true
        needsDisplay = true
        
        updateArrowPosition()
    }
    
    /// 隐藏弹窗
    func hide() {
        removeFromSuperview()
        isShowing = false
        
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        
        delegate?.popupViewDidDismiss(self)
    }
    
    /// 项目点击事件
    @objc private func itemTapped(_ sender: NSButton) {
        // 先调用代理方法，确保事件处理完成后再关闭弹窗
        delegate?.popupView(self, didSelectItemAt: sender.tag)
        // 延迟关闭，确保事件处理完全完成
        DispatchQueue.main.async {
            self.hide()
        }
    }
    
    /// 遮罩点击事件
    @objc private func maskTapped() {
        hide()
    }
}






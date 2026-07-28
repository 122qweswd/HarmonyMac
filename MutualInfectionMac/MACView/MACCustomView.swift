//
//  MACCustomView.swift
//  MutualInfectionMac
//
//  Created by TS on 2025/11/5.
//

import Foundation
import Cocoa

/// 弹窗内容点击回调协议
protocol MACTransmitRecordMoreMeumViewDelegate: AnyObject {
    func popupView(_ popupView: MACTransmitRecordMoreMeumView, didSelectItemAt index: Int)
    func popupViewDidDismiss(_ popupView: MACTransmitRecordMoreMeumView)
}

/// 自定义弹窗按钮，支持悬停和点击效果
class PopupMenuItemButton: NSButton {
    override func awakeFromNib() {
        super.awakeFromNib()
        setupButton()
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }
    
    private func setupButton() {
        wantsLayer = true
        isBordered = false
        alignment = .left
        bezelStyle = .texturedRounded
        setButtonType(.momentaryLight)
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.cornerRadius = 4.0  // 添加圆角
        
        // 设置键盘焦点环样式
        focusRingType = .none
        
        // 启用键盘事件
        allowsMixedState = false
        
        // 添加鼠标跟踪器以支持悬停效果
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .enabledDuringMouseDrag],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    override func drawFocusRingMask() {
        // 自定义焦点环
        NSBezierPath(roundedRect: bounds, xRadius: 4.0, yRadius: 4.0).fill()
    }
    
    override var focusRingMaskBounds: NSRect {
        return bounds
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        // 悬停时的背景色，添加淡入动画
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            self.layer?.backgroundColor = NSColor(hex: "#E5E5E5").cgColor
        }, completionHandler: nil)
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        // 恢复默认背景色，添加淡出动画
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            self.layer?.backgroundColor = NSColor.clear.cgColor
        }, completionHandler: nil)
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        // 点击时的背景色，添加淡入动画
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            self.layer?.backgroundColor = NSColor(hex: "#D0D0D0").cgColor
        }, completionHandler: nil)
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        // 恢复悬停背景色，添加淡入动画
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            self.layer?.backgroundColor = NSColor(hex: "#E5E5E5").cgColor
        }, completionHandler: nil)
    }
    
    // 键盘焦点支持
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            // 获得焦点时的样式
            layer?.backgroundColor = NSColor(hex: "#E0E0E0").cgColor
        }
        return result
    }
    
    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result {
            // 失去焦点时恢复默认样式
            layer?.backgroundColor = NSColor.clear.cgColor
        }
        return result
    }
    
    override var intrinsicContentSize: NSSize {
        var size = super.intrinsicContentSize
        // 添加水平内边距 (左右各10点)
        size.width += 20
        // 确保最小高度
        size.height = max(size.height, 30)
        return size
    }
}

/// 自定义设置背景颜色选中/未选中的Button
class MACConfigurableToggleButton: NSButton {
    struct Style {
        let normalColor: NSColor
        let selectedColor: NSColor
        let normalBackgroundColor: NSColor
        let selectedBackgroundColor: NSColor
        let fontSize: CGFloat
        let title: String
        let initialState: NSControl.StateValue
        let cornerRadius: CGFloat
    }
    
    private var style: Style!
    
    override var state: NSControl.StateValue {
        didSet {
            updateTitleColor()
            self.needsDisplay = true
        }
    }
    
    init(style: Style) {
        super.init(frame: .zero)
        self.style = style
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func commonInit() {
        guard let style = style else { return }
        setButtonType(.toggle)
        state = style.initialState
        title = style.title
        isBordered = false
        bezelStyle = .inline
        
        let customCell = ToggleButtonCell()
        self.cell = customCell
        customCell.normalBackgroundColor = style.normalBackgroundColor
        customCell.selectedBackgroundColor = style.selectedBackgroundColor
        customCell.cornerRadius = style.cornerRadius
        
        addCustomMarqueeLabel()
        updateMarqueeTextFieldConstraints(NSEdgeInsets(top: 3, left: 8, bottom: 3, right: 8))
        
        updateTitleColor()
    }
    
    private func updateTitleColor() {
        guard let style = style, let cell = self.cell as? ToggleButtonCell else { return }
        let color = state == .on ? style.selectedColor : style.normalColor
        let font = NSFont.mi.pingFangSCRegular(size: style.fontSize)
        // 创建段落样式，设置文本居中
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        cell.attributedTitle = NSAttributedString(
            string: style.title,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraphStyle
            ]
        )
        
        setMarqueeAttributedTitle(cell.attributedTitle)
        let bgColor = state == .on ? style.selectedBackgroundColor : style.normalBackgroundColor
        setMarqueeFadeMaskColor(bgColor)
    }
}

class ToggleButtonCell: NSButtonCell {
    var normalBackgroundColor: NSColor = .clear
    var selectedBackgroundColor: NSColor = .clear
    var cornerRadius: CGFloat = 0
    
    var contentInsets = NSEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
    
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        drawBezel(withFrame: cellFrame, in: controlView)
        let titleFrame = titleRect(forBounds: cellFrame)
        drawTitle(attributedTitle, withFrame: titleFrame, in: controlView)
    }
    
    override func drawBezel(withFrame frame: NSRect, in controlView: NSView) {
        let bgColor = state == .on ? selectedBackgroundColor : normalBackgroundColor
        bgColor.setFill()
        NSBezierPath(roundedRect: frame, xRadius: cornerRadius, yRadius: cornerRadius).fill()
    }
    
    override func drawTitle(_ title: NSAttributedString, withFrame frame: NSRect, in controlView: NSView) -> NSRect {
        super.drawTitle(title, withFrame: frame, in: controlView)
        return frame
    }
    
    // 重写标题区域计算，确保标题在按钮内居中
    override func titleRect(forBounds bounds: NSRect) -> NSRect {
        // 增加安全边际，确保标题区域足够大
        let titleSize = attributedTitle.size()
        let safeWidth = titleSize.width * 1.1 // 增加10%的安全宽度
        
        let x = bounds.midX - safeWidth / 2
        let y = bounds.midY - titleSize.height / 2
        let titleRect = NSRect(x: x, y: y, width: safeWidth, height: titleSize.height)
        
        return titleRect
    }
    
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        // 缩减绘制区域，实现内边距效果
        let insetRect = NSRect(
            x: rect.origin.x + contentInsets.left,
            y: rect.origin.y + contentInsets.bottom, // macOS 中 y 轴向下增长，注意底部缩进是加
            width: rect.width - contentInsets.left - contentInsets.right,
            height: rect.height - contentInsets.top - contentInsets.bottom
        )
        return super.drawingRect(forBounds: insetRect)
    }
    
}


/// 自定义带内边距的button
class MACPaddingButtonView: NSButton {
    /// 设置内边距
    var contentInsets = NSEdgeInsets(top: 0, left: 15, bottom: 0, right: 15)
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        commonInit()
        
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    
    private func commonInit() {
        setButtonType(.toggle)
        isBordered = false
        bezelStyle = .inline
        
        let customCell = MACPaddingButtonCell()
        customCell.contentInsets = contentInsets
        self.cell = customCell
        
        
    }
    
}

/// 自定义 cell 以调整内边距
class MACPaddingButtonCell: NSButtonCell {
    var contentInsets = NSEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
    
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        // 缩减绘制区域，实现内边距效果
        let insetRect = NSRect(
            x: rect.origin.x + contentInsets.left,
            y: rect.origin.y + contentInsets.bottom, // macOS 中 y 轴向下增长，注意底部缩进是加
            width: CGRectGetWidth(rect) - contentInsets.left - contentInsets.right,
            height: CGRectGetHeight(rect) - contentInsets.top - contentInsets.bottom
        )
        return super.drawingRect(forBounds: insetRect)
    }
}





// 自定义方法：将 NSBezierPath 转换为 CGPath（兼容 10.14 之前系统）
func cgPath(from bezierPath: NSBezierPath) -> CGPath {
    let path = CGMutablePath()
    var points = [CGPoint](repeating: .zero, count: 3)  // 存储路径元素的点（最多3个，对应曲线）
    
    for i in 0..<bezierPath.elementCount {
        let type = bezierPath.element(at: i, associatedPoints: &points)
        switch type {
        case .moveTo:
            path.move(to: points[0])
        case .lineTo:
            path.addLine(to: points[0])
        case .curveTo:
            path.addCurve(to: points[2], control1: points[0], control2: points[1])
        case .closePath:
            path.closeSubpath()
        @unknown default:
            continue
        }
    }
    return path
}


/// 自定义按钮类，支持设置背景图片和控制图片大小
class MACCustomBackgroundButton: NSButton {
    
    /// 背景图片
    var backgroundImage: NSImage? {
        didSet {
            needsDisplay = true
        }
    }
    
    /// 背景图片的绘制大小，默认为nil表示使用图片原始大小
    var backgroundImageSize: NSSize? {
        didSet {
            needsDisplay = true
        }
    }
    
    /// 按钮图片的绘制大小，默认为nil表示使用图片原始大小
    var imageDrawSize: NSSize? {
        didSet {
            if imageDrawSize != nil {
                // 设置图片绘制大小时，调整按钮的imageScaling属性
                self.imageScaling = .scaleNone
            }
            needsDisplay = true
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        // 如果有背景图片，则绘制背景图片
        if let backgroundImage = backgroundImage {
            // 使用指定大小或默认大小绘制背景图片
            let drawSize = backgroundImageSize ?? backgroundImage.size
            let drawRect = NSRect(
                x: (bounds.width - drawSize.width) / 2,
                y: (bounds.height - drawSize.height) / 2,
                width: drawSize.width,
                height: drawSize.height
            )
            backgroundImage.draw(in: drawRect, from: NSRect(origin: .zero, size: backgroundImage.size), operation: .sourceOver, fraction: 1.0)
        }
        
        // 调用父类的绘制方法来绘制按钮的其他元素（如标题、图像等）
        super.draw(dirtyRect)
    }
    
    // 重写setImage方法，支持设置图片绘制大小
    override var image: NSImage? {
        didSet {
            if let imageSize = imageDrawSize, let img = image {
                // 如果设置了图片绘制大小，则创建调整大小后的图片
                let newImage = NSImage(size: imageSize)
                newImage.lockFocus()
                img.draw(in: NSRect(origin: .zero, size: imageSize))
                newImage.unlockFocus()
                super.image = newImage
            } else {
                super.image = image
            }
        }
    }
}




/// 下拉选择弹窗
class MACTransmitRecordMoreMeumView: NSView {
    /// 展示内容的内边距
    var contentInsets: NSEdgeInsets = .init(top: 10, left: 12, bottom: 6, right: 12)
    
    /// 弹窗的背景颜色
    var backgroundColor: NSColor = NSColor.init(hex: "#FFFFFF")
    
    /// 弹窗圆角半径
    var cornerRadius: CGFloat = 6.0
    
    /// 弹窗阴影半径
    var shadowRadius: CGFloat = 4.0
    
    /// 弹窗阴影透明度
    var shadowOpacity: CGFloat = 0.2
    
    var shadowColor: NSColor = NSColor(hex: "#000000")
    
    /// 弹窗阴影偏移
    var shadowOffset: CGSize = CGSize(width: 0, height: 2)
    
    /// 当前选中的是哪一个
    var selectIndex: Int = 1
    
    /// 是否展示
    private var isShowing: Bool = false
    private var globalMonitor: Any?
    private weak var parentView: NSView?
    private let contentView = NSView()
    
    private var items: [MACSortMeumItem] = []
    
    // 弹窗点击回调协议
    weak var delegate: MACTransmitRecordMoreMeumViewDelegate?
    
    init(items: [MACSortMeumItem]) {
        self.items = items
        super.init(frame: .zero)
        
        let click = NSClickGestureRecognizer(target: self, action: #selector(bgTouch))
        addGestureRecognizer(click)
        
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
    
    @objc func bgTouch() {
        
        print("背景点击, 防止事件透传")
    }
    
    func setupView() {
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
        
        /// 内容视图（主体部分，无箭头）
        contentView.wantsLayer = true
        contentView.layer?.masksToBounds = false
        contentView.layer?.backgroundColor = backgroundColor.cgColor
        contentView.layer?.cornerRadius = cornerRadius
        let shadow = NSShadow()
        shadow.shadowBlurRadius = shadowRadius
        shadow.shadowOffset = shadowOffset
        shadow.shadowColor = shadowColor.withAlphaComponent(shadowOpacity)
        contentView.shadow = shadow
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)
        
        /// 添加内容
        let stackView = NSStackView()
        stackView.wantsLayer = true
        stackView.distribution = .fill
        stackView.orientation = .vertical
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.layer?.backgroundColor = NSColor.clear.cgColor
        contentView.addSubview(stackView)
        
        maskLayer.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        stackView.snp.makeConstraints { make in
            make.top.equalTo(contentView.snp.top)
            make.bottom.equalTo(contentView.snp.bottom)
            make.leading.equalTo(contentView.snp.leading)
            make.trailing.equalTo(contentView.snp.trailing)
        }
        
        /// 添加展示的文案
        items.enumerated().forEach { index, item in
            let button = MACSortMeumItemView()
            button.title = item.title
            button.subTitle = item.subTitle ?? ""
            button.isSelect = item.isSelect
            button.widthAnchor.constraint(equalToConstant: 150+contentInsets.left+contentInsets.right).isActive = true
            if item.isSelect {
                button.heightAnchor.constraint(equalToConstant: 50+contentInsets.top).isActive = true
            } else {
                button.heightAnchor.constraint(equalToConstant: 24+contentInsets.top+contentInsets.bottom).isActive = true
            }
            button.onTouch = { [weak self] in
                guard let self = self else { return }
                
                self.delegate?.popupView(self, didSelectItemAt: index)
                self.hide()
            }
            stackView.addArrangedSubview(button)
            if index == 0 {
                let lineView = NSView()
                lineView.wantsLayer = true
                lineView.layer?.backgroundColor = NSColor(hex: "#E0E0E0").cgColor  // 使用浅灰色分隔线
                lineView.heightAnchor.constraint(equalToConstant: 1).isActive = true
                stackView.addArrangedSubview(lineView)
                
            }
            
        }
    }
    
    /// 计算弹窗位置（显示在按钮下方）
    private func calculatePosition(for button: NSButton, in view: NSView) -> NSRect {
        /// 转换按钮坐标到父视图坐标系
        let buttonRect = button.convert(button.bounds, to: view)
        let parentFrame = view.bounds
        
        /// 计算内容大小
        let contentWidth: CGFloat = 150
        let contentHeight: CGFloat = CGFloat(items.count) * 24 + 20
        
        /// 计算内容位置（按钮下方）
        var contentX = buttonRect.minX - contentWidth
        var contentY = buttonRect.minY - contentHeight - CGRectGetHeight(button.frame) - 5  // 在按钮下方，留5个点的间距
        
        /// 边界检查和调整
        /// 如果弹窗左侧超出父视图边界，则调整到边界位置
        if contentX < 0 {
            contentX = 0
        }
        /// 如果弹窗右侧超出父视图边界，则调整到边界位置
        else if contentX + contentWidth > parentFrame.width {
            contentX = parentFrame.width - contentWidth
        }
        
        /// 如果弹窗顶部超出父视图顶部边界，则显示在按钮上方
        if contentY < 0 {
            contentY = buttonRect.maxY + CGRectGetHeight(button.frame) + 5  // 在按钮上方，留5个点的间距
        }
        
        let contentFrame = NSRect(
            x: contentX,
            y: contentY,
            width: contentWidth,
            height: contentHeight
        )
        
        /// 更新内容视图的frame
        contentView.frame = contentFrame
        
        /// 设置弹窗自身的frame
        self.frame = NSRect(
            x: 0,
            y: 0,
            width: parentFrame.width,
            height: parentFrame.height
        )
        
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
        delegate?.popupView(self, didSelectItemAt: sender.tag)
        hide()
    }
    
    /// 遮罩点击事件
    @objc private func maskTapped() {
        hide()
    }
    
}

struct MACSortMeumItem {
    var title: String = ""
    
    var subTitle: String?
    
    var isSelect: Bool = false
    /// 0 表示只有标题，1表示标题和副标题都有
    var style: Int = 0
    
    init(title: String, subTitle: String? = "", isSelect: Bool, style: Int) {
        self.title = title
        self.subTitle = subTitle
        self.isSelect = isSelect
        self.style = style
    }
    
}


/// 排序的item
class MACSortMeumItemView: NSView {
    
    var title: String = "" {
        didSet {
            titleView.stringValue = title
        }
    }
    
    var subTitle: String = "" {
        didSet {
            subTitleView.stringValue = subTitle
        }
    }
    
    var isSelect: Bool = false {
        didSet {
            iconView.isHidden = !isSelect
            subTitleView.isHidden = !isSelect
        }
    }
    
    var onTouch: (() -> Void)?
    
    var contentInsets: NSEdgeInsets = .init(top: 10, left: 12, bottom: 0, right: 12)
    
    
    lazy var iconView: NSTextField = {
        let textField = NSTextField(labelWithString: "✔️")
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = NSFont.systemFont(ofSize: 15, weight: .regular)
        textField.textColor = NSColor.init(hex: "#000000")
        textField.alignment = .center
        textField.isHidden = true
        return textField
    }()
    
    lazy var titleView: NSTextField = {
        let textField = NSTextField(labelWithString: "")
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = NSFont.systemFont(ofSize: 16, weight: .regular)
        textField.textColor = NSColor.init(hex: "#000000")
        return textField
    }()
    
    lazy var subTitleView: NSTextField = {
        let textField = NSTextField(labelWithString: "")
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        textField.textColor = NSColor.init(hex: "#000000").withAlphaComponent(0.5)
        return textField
    }()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        addSubview(iconView)
        addSubview(titleView)
        addSubview(subTitleView)
        
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(contentInsets.left)
            make.width.height.equalTo(20)
            make.centerY.equalToSuperview()
        }
        
        titleView.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing)
            make.top.equalToSuperview().offset(contentInsets.top)
            make.height.equalTo(24)
            make.trailing.equalToSuperview()
        }
        
        subTitleView.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing)
            make.top.equalTo(titleView.snp.bottom)
            make.height.equalTo(20)
            make.trailing.equalToSuperview()
        }
        
        let tap = NSClickGestureRecognizer(target: self, action: #selector(onClickTouch))
        addGestureRecognizer(tap)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    @objc private func onClickTouch() {
        onTouch?()
    }
    
}


/// 自定义搜索框类
class MACCustomSearchField: NSSearchField {
    /// 定义获得焦点的回调
    var onDidBecomeFirstResponder: (() -> Void)?
    
    var onMouseDown: (() -> Void)?
    
    /// 当控件获得焦点时，系统会调用此方法
    override func becomeFirstResponder() -> Bool {
        /// 先调用父类方法，确保正常获得焦点
        let success = super.becomeFirstResponder()
        if success {
            /// 获得焦点成功，触发回调
            onDidBecomeFirstResponder?()
        }
        return success
    }
    
    /// 确保正确处理鼠标事件
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        onMouseDown?()
    }
    
    /// 确保正确处理成为第一响应者
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    /// 确保正确处理事件
    override func hitTest(_ point: NSPoint) -> NSView? {
        return super.hitTest(point)
    }
}


class MACNotDataView: NSView {
    
    
    lazy var iconView: NSImageView = {
        let view = NSImageView()
        view.image = NSImage(named: "icon_empty_document")
        view.imageScaling = .scaleProportionallyUpOrDown
        
        return view
    }()
    
    lazy var descriptionView: NSTextField = {
        let view = NSTextField()
        view.stringValue = "暂无数据".localized
        view.alignment = .center
        view.font = .mi.pingFangSCRegular(size: 12)
        view.textColor = NSColor.init(hex: "#000000", alpha: 0.6)
        view.wantsLayer = true
        view.isBordered = false
        view.isEditable = false
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        wantsLayer = true
        layer?.backgroundColor = NSColor(hex: "#FFFFFF").cgColor
        
        addSubview(iconView)
        addSubview(descriptionView)
        
        iconView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-20)
            make.width.equalTo(80)
            make.height.equalTo(80)
        }
        
        descriptionView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(iconView.snp.bottom).offset(5)
            make.width.equalTo(200)
            make.height.equalTo(30)
        }
        
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}


/// 类型展示时图片类型的文件夹需要展示的提示视图
class MACImageTypeTipsView: NSView {
    
    // 点击下载按钮的回调
    var onDownloadButtonClicked: (() -> Void)?
    
    // 左侧文本
    private lazy var leftLabel: NSTextField = {
        let label = NSTextField(labelWithString: "请到".localized)
        label.font = NSFont.systemFont(ofSize: 14)
        label.textColor = NSColor.gray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 下载按钮
    private lazy var downloadButton: NSButton = {
        let button = NSButton(title: "“下载”".localized, target: self, action: #selector(downloadButtonClicked))
        // 设置按钮样式使其看起来像链接文本
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.clear.cgColor
        button.contentTintColor = NSColor.systemBlue
        button.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        // 开启按钮的鼠标悬停效果
        button.highlight(true)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // 右侧文本
    private lazy var rightLabel: NSTextField = {
        let label = NSTextField(labelWithString: "中查看".localized)
        label.font = NSFont.systemFont(ofSize: 14)
        label.textColor = NSColor.gray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    lazy var stackView: NSStackView = {
        let view = NSStackView(views: [leftLabel, downloadButton, rightLabel])
        view.orientation = .horizontal
        view.distribution = .fillProportionally
        view.alignment = .centerY
        view.spacing = 4
        return view
    }()
    
    @objc private func downloadButtonClicked() {
        onDownloadButtonClicked?()
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        addSubview(stackView)
        
        stackView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(100)
            make.height.equalTo(100)
        }
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}


/// 自定义搜索输入框（继承于NSView）
class MACCoutomSearchView: NSView {
    
    var isEdit: Bool = false {
        didSet {
            noView.isHidden = isEdit
            textField.isHidden = !isEdit
            clearButton.isHidden = !isEdit
            if isEdit {
                textField.becomeFirstResponder()
            } else {
                textField.resignFirstResponder()
            }
        }
    }
    
    /// 非编辑模式时的点击事件
    private lazy var noView: NSView = {
        let view = NSView()
        
        return view
    }()
    
    private lazy var placeholderLabel: NSTextField = {
        let label = NSTextField(labelWithString: "搜索".localized)
        label.font = .mi.pingFangSCRegular(size: 12)
        label.textColor = .mi.hex("#000000", alpha: 0.5)
        return label
    }()
    
    /// 搜索图标
    private lazy var searchIcon: NSImageView = {
        let imageView = NSImageView()
        imageView.image = NSImage(named: "icon_search")
//        if #available(macOS 11.0, *) {
//            imageView.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "搜索图标")
//        } else {
//            // Fallback on earlier versions
//            if let image = NSImage(named: "magnifyingglass") {
//                imageView.image = image
//            }
//        }
//        imageView.imageScaling = .scaleProportionallyDown
        return imageView
    }()
    
    /// 输入框
    private lazy var textField: NSTextField = {
        let field = NSTextField()
        field.isBordered = false
        field.isBezeled = false
        field.focusRingType = .none
        field.backgroundColor = NSColor.clear
        field.placeholderString = ""
        field.font = .mi.pingFangSCRegular(size: 13)
        field.textColor = .mi.hex("#000000", alpha: 0.9)
        field.layer?.backgroundColor = NSColor.clear.cgColor
        field.maximumNumberOfLines = 1
        field.isEditable = true
        /// 禁止换行（即使粘贴包含换行的内容，也会被自动忽略或替换）
        field.cell?.usesSingleLineMode = true
        /// 当内容过长时允许横向滚动
        field.cell?.isScrollable = true
        field.isHidden = true
        
        fixTextFieldVerticalShift(field)
        
        return field
    }()
    
    /// 修复结束编辑时文本向上偏移问题
    func fixTextFieldVerticalShift(_ textField: NSTextField) {
        // 1. 关键设置：使用单行模式
        textField.cell?.usesSingleLineMode = true
        
        // 2. 禁用换行
        textField.cell?.wraps = false
        textField.cell?.isScrollable = true
        
        // 3. 统一行高计算
        if let cell = textField.cell {
            // 修复编辑状态的行高
            cell.allowsEditingTextAttributes = false
            cell.truncatesLastVisibleLine = true
        }
        
        // 4. 固定字体属性
        let fontSize = textField.font?.pointSize ?? 13
        textField.font = NSFont.systemFont(ofSize: fontSize, weight: .regular)

        // 5. 应用基线偏移（关键！）
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = fontSize
        paragraphStyle.maximumLineHeight = fontSize
        paragraphStyle.lineHeightMultiple = 1.0
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: textField.font!,
            .paragraphStyle: paragraphStyle,
            .baselineOffset: 0  // 明确设置基线偏移为0
        ]
        
        textField.attributedStringValue = NSAttributedString(
            string: textField.stringValue,
            attributes: attributes
        )
    }
    
    /// 清除图标
    private lazy var clearButton: NSButton = {
        let button = NSButton(title: "", target: self, action:#selector(clearButtonClick))
        button.setButtonType(.momentaryPushIn)
        button.isBordered = false // 关键属性，禁用系统边框样式
        button.wantsLayer = true // 启用图层支持
        button.image = NSImage(named: "icon_close_gray")
        button.imageScaling = .scaleNone
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()
    
    /// 搜索图标点击回调
    var onSearchIconClicked: (() -> Void)?
    
    /// 非编辑模式下的输入框点击回调
    var onSearchViewClicked: (() -> Void)?
    
    
    /// 文本变化回调
    var onTextChanged: ((String) -> Void)?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(hex: "#F0F0F0").cgColor
        layer?.cornerRadius = 15
        layer?.masksToBounds = true
        
        /// 添加子视图
        addSubview(searchIcon)
        addSubview(textField)
        addSubview(noView)
        noView.addSubview(placeholderLabel)
        addSubview(clearButton)
        
        /// 设置约束
        searchIcon.snp.makeConstraints { make in
            make.leading.equalTo(5)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }
        
        textField.snp.makeConstraints { make in
            make.leading.equalTo(searchIcon.snp.trailing).offset(8)
            make.trailing.equalTo(-25)
            make.centerY.equalToSuperview()
//            make.height.equalTo(20)
        }
        
        clearButton.snp.makeConstraints { make in
            make.trailing.equalTo(-6)
            make.centerY.equalTo(0)
            make.width.height.equalTo(16)
        }
        
        noView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        placeholderLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(26)
        }
        
        /// 添加搜索图标点击手势
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(searchIconClicked))
        searchIcon.addGestureRecognizer(clickGesture)
        
        /// 监听文本变化
        NotificationCenter.default.addObserver(
            forName: NSTextField.textDidChangeNotification,
            object: textField,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.onTextChanged?(self.textField.stringValue)
        }
        
        let tapGesture = NSClickGestureRecognizer(target: self, action: #selector(viewClicked))
        noView.addGestureRecognizer(tapGesture)
        
    }
    
    /// 在视图被移除时移除通知监听
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            NotificationCenter.default.removeObserver(self, name: NSTextField.textDidChangeNotification, object: textField)
        }
    }
    
    @objc private func searchIconClicked() {
        onSearchIconClicked?()
    }
    
    @objc private func viewClicked() {
        onSearchViewClicked?()
    }
    
    @objc private func clearButtonClick() {
        textField.stringValue = ""
        self.onTextChanged?(self.textField.stringValue)
    }
    
    /// 获取输入框文本
    var searchText: String {
        return textField.stringValue
    }
    
    /// 设置输入框文本
    func setSearchText(_ text: String) {
        textField.stringValue = text
    }
}


/// 自定义菜单项视图类
class CustomMenuItemView: NSView {
    var titleText: String = ""
    var subtitleText: String = ""
    var isHighlighted: Bool = false {
        didSet {
            updateAppearance()
        }
    }
    
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    override init(frame: NSRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        // 设置标题标签
        titleLabel.alignment = .left
        titleLabel.frame = NSRect(x: 12, y: 17, width: 180, height: 20)
        titleLabel.font = NSFont.systemFont(ofSize: 14)
        titleLabel.textColor = .controlTextColor
        titleLabel.wantsLayer = true
        titleLabel.backgroundColor = .orange
        addSubview(titleLabel)
        
        // 设置副标题标签
        subtitleLabel.alignment = .left
        subtitleLabel.frame = NSRect(x: 12, y: 0, width: 180, height: 20)
        subtitleLabel.font = NSFont.systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.wantsLayer = true
        subtitleLabel.backgroundColor = .red
        addSubview(subtitleLabel)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // 根据高亮状态绘制背景
        if isHighlighted {
            // 使用系统选择颜色
            let highlightColor = NSColor(hex: "#3F99FB")
            highlightColor.setFill()
            
            // 创建高亮区域，通常系统菜单项的高亮区域有圆角，且不占满整个宽度
            let highlightRect = bounds.insetBy(dx: 6, dy: 0) // 横向插入4点，不贴边
            let highlightPath = NSBezierPath(roundedRect: highlightRect, xRadius: 8, yRadius: 8)
            highlightPath.fill()
        }
    }
    
    // 鼠标进入时高亮
    override func mouseEntered(with event: NSEvent) {
        isHighlighted = true
    }
    
    // 鼠标离开时取消高亮
    override func mouseExited(with event: NSEvent) {
        isHighlighted = false
    }
    
    // 鼠标点击时触发动作
    override func mouseDown(with event: NSEvent) {
        isHighlighted = true
    }
    
    override func mouseUp(with event: NSEvent) {
        isHighlighted = false
        
        // 触发菜单项动作
        if let menuItem = enclosingMenuItem {
            if let action = menuItem.action {
                NSApp.sendAction(action, to: menuItem.target, from: menuItem)
            }
            menuItem.menu?.cancelTracking()
        }
    }
    
    // 设置跟踪区域
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }
        
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    // 更新内容
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        titleLabel.stringValue = titleText
        subtitleLabel.stringValue = subtitleText
    }
    
    private func updateAppearance() {
        // 需要更新显示
        needsDisplay = true
        
        // 根据高亮状态更新标签颜色
        if isHighlighted {
            titleLabel.textColor = .selectedMenuItemTextColor
            subtitleLabel.textColor = .selectedMenuItemTextColor
        } else {
            titleLabel.textColor = .controlTextColor
            subtitleLabel.textColor = .secondaryLabelColor
        }
    }
    
    // MARK: - 适配系统外观 (浅色/深色模式)
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        // 当系统外观改变时（例如浅色/深色模式切换），更新颜色
        updateAppearance()
    }
    
}

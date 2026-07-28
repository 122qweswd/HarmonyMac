
import Foundation
import Cocoa

// MARK: - NSButton 跑马灯扩展
extension NSButton {
    // MARK: - 关联对象键定义
    private enum MarqueeAssociatedKeys {
        static var marqueeTextField = "com.app.marqueeTextField"
        static var isMarqueeEnabled = "com.app.isMarqueeEnabled"
        static var originalTitle = "com.app.originalTitle"
        static var originalAttributedTitle = "com.app.originalAttributedTitle"
        static let originalTitleColor = "com.app.originalTitleColor"
    }
    
    /// 跑马灯文本字段（私有）
    var marqueeTextField: MIMacMarqueeTextField? {
        get {
            return objc_getAssociatedObject(self, &MarqueeAssociatedKeys.marqueeTextField) as? MIMacMarqueeTextField
        }
        set {
            objc_setAssociatedObject(self, &MarqueeAssociatedKeys.marqueeTextField, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    /// 是否启用了跑马灯效果
    public var isMarqueeEnabled: Bool {
        get {
            return objc_getAssociatedObject(self, &MarqueeAssociatedKeys.isMarqueeEnabled) as? Bool ?? false
        }
        set {
            let oldValue = isMarqueeEnabled
            objc_setAssociatedObject(self, &MarqueeAssociatedKeys.isMarqueeEnabled, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            if newValue && !oldValue {
                enableMarqueeEffect()
            }
        }
    }
    
    /// 原始标题（用于恢复）
    private var originalTitle: String? {
        get {
            return objc_getAssociatedObject(self, &MarqueeAssociatedKeys.originalTitle) as? String
        }
        set {
            objc_setAssociatedObject(self, &MarqueeAssociatedKeys.originalTitle, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    /// 原始富文本标题（用于恢复）
    private var originalAttributedTitle: NSAttributedString? {
        get {
            return objc_getAssociatedObject(self, &MarqueeAssociatedKeys.originalAttributedTitle) as? NSAttributedString
        }
        set {
            objc_setAssociatedObject(self, &MarqueeAssociatedKeys.originalAttributedTitle, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    /// 原始标题颜色（用于恢复）
    private var originalTitleColor: NSColor? {
        get {
            return objc_getAssociatedObject(self, MarqueeAssociatedKeys.originalTitleColor) as? NSColor
        }
        set {
            objc_setAssociatedObject(self, MarqueeAssociatedKeys.originalTitleColor, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
    }
    
    /// 获取按钮标题的当前颜色
    private func getCurrentTitleColor() -> NSColor {
        // 从 attributedTitle 中提取颜色
        let attributedTitle = self.attributedTitle
        if attributedTitle.length > 0 {
            var colorRange = NSRange(location: 0, length: 1)
            if let color = attributedTitle.attribute(.foregroundColor, at: 0, effectiveRange: &colorRange) as? NSColor {
                return color
            }
        }
        // 默认颜色
        return .controlTextColor
    }
    
    /// 启用跑马灯效果（通过设置字体颜色为透明）
    private func enableMarqueeEffect() {
        // 移除现有的跑马灯（如果有）
        marqueeTextField?.removeFromSuperview()
        
        // 保存原始标题和颜色
        saveOriginalTitleAndColor()
        
        // 设置按钮文本颜色为透明
        setButtonTextColorToClear()
        
        // 创建并设置跑马灯
        setupMarqueeTextField()
        
        // 监听尺寸变化
        setupFrameChangeObserver()
    }
    
    /// 保存原始标题和颜色
    private func saveOriginalTitleAndColor() {
        // 保存原始标题
        let currentTitle = self.title
        originalTitle = currentTitle
        
        // 保存原始富文本标题
        let attributedTitle = self.attributedTitle
        if attributedTitle.length > 0 {
            originalAttributedTitle = attributedTitle
        }
        
        // 保存原始颜色
        originalTitleColor = getCurrentTitleColor()
        
        print("保存的原始标题: \(currentTitle)")
        print("保存的原始富文本长度: \(attributedTitle.length)")
    }
    
    /// 设置按钮文本颜色为透明
    private func setButtonTextColorToClear() {
        let attributedTitle = self.attributedTitle
        
        // 方法1: 设置富文本标题为透明
        if attributedTitle.length > 0 {
            let transparentAttributedTitle = NSMutableAttributedString(attributedString: attributedTitle)
            transparentAttributedTitle.addAttribute(
                .foregroundColor,
                value: NSColor.clear,
                range: NSRange(location: 0, length: transparentAttributedTitle.length)
            )
            self.attributedTitle = transparentAttributedTitle
        } else {
            // 方法2: 设置普通标题为透明
            let transparentAttributedTitle = NSAttributedString(
                string: self.title,
                attributes: [
                    .foregroundColor: NSColor.clear,
                    .font: self.font ?? NSFont.systemFont(ofSize: 13)
                ]
            )
            self.attributedTitle = transparentAttributedTitle
        }
    }
    
    /// 创建并设置跑马灯文本字段
    private func setupMarqueeTextField() {
        let marquee = MIMacMarqueeTextField.getCommonMacMarqueeTextField()
        
        // 设置跑马灯文本 - 使用保存的原始文本
        if let originalAttributedTitle = originalAttributedTitle, originalAttributedTitle.length > 0 {
            print("使用富文本设置跑马灯: \(originalAttributedTitle.string)")
            marquee.attributedStringValue = originalAttributedTitle
        } else if let originalTitle = originalTitle, !originalTitle.isEmpty {
            print("使用普通文本设置跑马灯: \(originalTitle)")
            marquee.stringValue = originalTitle
        } else {
            // 如果保存的文本为空，使用当前文本
            let attributedTitle = self.attributedTitle
            if attributedTitle.length > 0 {
                marquee.attributedStringValue = attributedTitle
            } else {
                marquee.stringValue = self.title
            }
            print("使用当前文本设置跑马灯: \(self.title)")
        }

        // 同步按钮样式到跑马灯
        syncButtonStyleToMarquee(marquee)
        
        // 设置位置和约束
        setupMarqueeLayout(marquee)
        
        // 存储引用
        self.marqueeTextField = marquee
        
        // 立即开始滚动
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            marquee.isScrolling = true
        }
    }
    
    /// 同步按钮样式到跑马灯
    private func syncButtonStyleToMarquee(_ marquee: MIMacMarqueeTextField) {
        marquee.font = self.font ?? NSFont.systemFont(ofSize: 13)
        
        // 使用保存的原始颜色，如果没有则使用默认颜色
        let color = originalTitleColor ?? .controlTextColor
        marquee.textColor = color
        
        marquee.alignment = self.alignment
        marquee.isScrolling = true
        
        print("设置跑马灯颜色: \(color)")
    }
    
    /// 设置跑马灯布局
    private func setupMarqueeLayout(_ marquee: MIMacMarqueeTextField) {
        self.addSubview(marquee)
        
        // 使用 AutoLayout
        marquee.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            marquee.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            marquee.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            marquee.topAnchor.constraint(equalTo: self.topAnchor),
            marquee.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
        
        // 确保跑马灯在按钮层级的最前面
        marquee.wantsLayer = true
        marquee.layer?.zPosition = 999
    }
    
    // 辅助函数：移除视图的所有约束
    private func removeConstraintsForView(_ view: NSView) {
        // 移除view自身的约束
        view.removeConstraints(view.constraints)
        
        // 从父视图中移除与view相关的约束
        if let superview = view.superview {
            let constraintsToRemove = superview.constraints.filter { constraint in
                return constraint.firstItem === view || constraint.secondItem === view
            }
            superview.removeConstraints(constraintsToRemove)
        }
    }
    
    /// 设置帧变化监听
    private func setupFrameChangeObserver() {
        self.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(frameDidChange(_:)),
            name: NSView.frameDidChangeNotification,
            object: self
        )
    }
    
    /// 帧变化时更新跑马灯大小
    @objc private func frameDidChange(_ notification: Notification) {
        marqueeTextField?.frame = self.bounds
        marqueeTextField?.layoutSubtreeIfNeeded()
    }
}

// MARK: - 公开方法
extension NSButton {
    
    // 增加跑马灯效果
    public func addCustomMarqueeLabel() {
        isMarqueeEnabled = true
        setMarqueeAlignment(.center)
        startMarqueeScrolling()
    }
    
    /// 开始跑马灯滚动
    public func startMarqueeScrolling() {
        marqueeTextField?.isScrolling = true
    }
    
    /// 停止跑马灯滚动
    public func stopMarqueeScrolling() {
        marqueeTextField?.isScrolling = false
    }
    
    /// 重新开始跑马灯滚动
    public func restartMarqueeScrolling() {
        marqueeTextField?.isScrolling = true
        marqueeTextField?.restartScrolling()
    }
    
    // 更新跑马灯布局约束
    public func updateMarqueeTextFieldConstraints(_ labelConstraints: NSEdgeInsets) {
        if let label = marqueeTextField {
            label.translatesAutoresizingMaskIntoConstraints = false
            
            // 1. 移除label的所有现有约束（关键步骤！）
            removeConstraintsForView(label)
            
            // 2. 添加新的约束
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: topAnchor, constant: labelConstraints.top),
                label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: labelConstraints.left),
                label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -labelConstraints.right),
                label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -labelConstraints.bottom)
            ])
        }
    }
    
    /// 设置跑马灯文本（会更新跑马灯内容）
    public func setMarqueeTitle(_ title: String) {
        // 更新按钮标题
        self.title = title
        
        // 保存原始标题
        originalTitle = title
        
        // 设置按钮文本颜色为透明
        setButtonTextColorToClear()
        
        // 更新跑马灯文本
        if isMarqueeEnabled {
            marqueeTextField?.stringValue = title
        }
    }
    
    /// 设置跑马灯富文本（会更新跑马灯内容）
    public func setMarqueeAttributedTitle(_ attributedTitle: NSAttributedString) {
        // 更新按钮富文本标题
        self.attributedTitle = attributedTitle
        
        // 保存原始富文本标题
        originalAttributedTitle = attributedTitle
        
        // 保存颜色
        var colorRange = NSRange(location: 0, length: 1)
        if let color = attributedTitle.attribute(.foregroundColor, at: 0, effectiveRange: &colorRange) as? NSColor {
            originalTitleColor = color
        } else {
            originalTitleColor = .controlTextColor
        }
        
        // 设置按钮文本颜色为透明
        setButtonTextColorToClear()
        print("isMarqueeEnabled:\(isMarqueeEnabled)")
        // 更新跑马灯文本
        if isMarqueeEnabled {
            marqueeTextField?.attributedStringValue = attributedTitle
        }
    }
    
    /// 设置跑马灯字体
    public func setMarqueeFont(_ font: NSFont) {
        self.font = font
        if isMarqueeEnabled {
            marqueeTextField?.font = font
            
            // 更新按钮透明文本的字体
            updateTransparentTitleFont(font)
        }
    }
    
    /// 更新透明标题的字体
    private func updateTransparentTitleFont(_ font: NSFont) {
        let attributedTitle = self.attributedTitle
        if attributedTitle.length > 0 {
            let mutableAttributedTitle = NSMutableAttributedString(attributedString: attributedTitle)
            mutableAttributedTitle.addAttribute(
                .font,
                value: font,
                range: NSRange(location: 0, length: mutableAttributedTitle.length)
            )
            self.attributedTitle = mutableAttributedTitle
        }
    }
    
    /// 设置跑马灯文本颜色
    public func setMarqueeTextColor(_ color: NSColor) {
        // 保存颜色
        originalTitleColor = color
        
        if isMarqueeEnabled {
            marqueeTextField?.textColor = color
        }
    }
    
    /// 设置跑马灯控件背景颜色
    public func setMarqueeBackgroundColor(_ color: NSColor) {
        if isMarqueeEnabled {
            marqueeTextField?.backgroundColor = color
        }
    }
    
    /// 设置跑马灯控件遮罩颜色
    public func setMarqueeFadeMaskColor(_ color: NSColor) {
        if isMarqueeEnabled {
            marqueeTextField?.fadeMaskColor = color
        }
    }
    
    /// 设置跑马灯对齐方式
    public func setMarqueeAlignment(_ alignment: NSTextAlignment) {
        self.alignment = alignment
        if isMarqueeEnabled {
            marqueeTextField?.alignment = alignment
        }
    }
}

class CoreAnimationMarqueeButton: NSButton {
    // 双文本图层实现无缝滚动
    private let textLayer1 = CATextLayer()
    private let textLayer2 = CATextLayer()
    private let maskLayer = CALayer()
    private var isAnimating = false
    private var currentTextWidth: CGFloat = 0
    private var textLayersContainer = CALayer() // 承载两个文本图层的容器
    
    // 存储实际标题
    private var _title: String = ""
    private var _attributedTitle: NSAttributedString = NSAttributedString()
    
    // 自定义颜色属性
    var customTextColor: NSColor = .controlTextColor {
        didSet {
            updateTextColorOnly()
        }
    }
    
    // 跑马灯配置
    var marqueeSpeed: CGFloat = 50.0 // 像素/秒
    var marqueeDelay: CFTimeInterval = 1.0 // 首次启动延迟
    let marqueePadding: CGFloat = 5.0 // 左右内边距
    private let textSpacing: CGFloat = 20.0 // 两个文本之间的间距
    
    override var intrinsicContentSize: NSSize {
        if let maxWidth = maxWidth, maxWidth > 0 {
            return NSSize(width: maxWidth, height: 24)
        }
        
        let textSize = getTextSize()
        let width = min(max(textSize.width + 20, 40), 1000)
        return NSSize(width: width, height: 24)
    }
    
    var maxWidth: CGFloat? = nil {
        didSet {
            invalidateIntrinsicContentSize()
            needsLayout = true
        }
    }
    
    private func getTextSize() -> CGSize {
        let (displayText, _, font) = getTextAttributes()
        guard !displayText.isEmpty else {
            return CGSize(width: 0, height: font.pointSize + 4)
        }
        
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return (displayText as NSString).size(withAttributes: attributes)
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        self.isBordered = false
        self.bezelStyle = .rounded
        self.setButtonType(.momentaryPushIn)
        self.wantsLayer = true
        self.layerContentsRedrawPolicy = .onSetNeedsDisplay
        
        super.title = ""
        super.attributedTitle = NSAttributedString(string: "")
        
        setupLayers()
    }
    
    private func setupLayers() {
        guard let layer = self.layer else { return }
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        // 遮罩层
        maskLayer.frame = bounds
        maskLayer.masksToBounds = true
        maskLayer.backgroundColor = NSColor.white.cgColor
        layer.mask = maskLayer
        
        // 文本容器图层
        textLayersContainer.frame = bounds
        textLayersContainer.anchorPoint = CGPoint(x: 0, y: 0)
        textLayersContainer.backgroundColor = NSColor.clear.cgColor
        layer.addSublayer(textLayersContainer)
        
        // 配置两个文本图层
        [textLayer1, textLayer2].forEach { textLayer in
            textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
            textLayer.backgroundColor = NSColor.clear.cgColor
            textLayer.anchorPoint = CGPoint(x: 0, y: 0)
            textLayer.truncationMode = .none
            textLayer.alignmentMode = .left
            textLayer.contentsGravity = .left
            textLayersContainer.addSublayer(textLayer)
        }
        
        CATransaction.commit()
    }
    
    override func updateLayer() {
        super.updateLayer()
        maskLayer.frame = bounds
        textLayersContainer.frame = bounds
    }
    
    override var title: String {
        get { return _title }
        set {
            guard _title != newValue else { return }
            _title = newValue
            super.title = ""
            super.attributedTitle = NSAttributedString(string: "")
            updateContent()
        }
    }
    
    override var attributedTitle: NSAttributedString {
        get { return _attributedTitle }
        set {
            guard _attributedTitle != newValue else { return }
            _attributedTitle = newValue
            _title = newValue.string
            super.title = ""
            super.attributedTitle = NSAttributedString(string: "")
            updateContent()
        }
    }
    
    private func updateContent() {
        invalidateIntrinsicContentSize()
        needsLayout = true
        needsDisplay = true
        
        superview?.needsLayout = true
        updateDisplay()
    }
    
    private func updateDisplay() {
        guard bounds.width > 0 && bounds.height > 0 else { return }
        
        let (displayText, textColor, font) = getTextAttributes()
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        if displayText.isEmpty {
            [textLayer1, textLayer2].forEach { $0.string = "" }
            stopMarqueeAnimation()
            CATransaction.commit()
            return
        }
        
        // 计算文本尺寸
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (displayText as NSString).size(withAttributes: attributes)
        currentTextWidth = textSize.width
        
        // 配置两个文本图层
        let attributedString = NSAttributedString(
            string: displayText,
            attributes: [.font: font, .foregroundColor: textColor]
        )
        [textLayer1, textLayer2].forEach { textLayer in
            textLayer.string = attributedString
            textLayer.font = CTFontCreateWithName(font.fontName as CFString, font.pointSize, nil)
            textLayer.fontSize = font.pointSize
            textLayer.foregroundColor = textColor.cgColor
            textLayer.bounds = CGRect(x: 0, y: 0, width: currentTextWidth, height: textSize.height)
        }
        
        // 垂直居中 - 固定文本图层的Y位置
        let centerY = bounds.height / 2
        let textTopPosition = centerY - textSize.height / 2
        let availableWidth = bounds.width - 2 * marqueePadding
        
        if currentTextWidth > availableWidth+2 * marqueePadding && availableWidth > 0 {
            // 跑马灯模式：双文本拼接
            // 修复：文本图层的Y位置固定，不随容器移动
            textLayer1.position = CGPoint(x: marqueePadding, y: textTopPosition)
            textLayer2.position = CGPoint(x: marqueePadding + currentTextWidth + textSpacing, y: textTopPosition)
            
            CATransaction.commit()
            
            if !isAnimating {
                DispatchQueue.main.asyncAfter(deadline: .now() + marqueeDelay) { [weak self] in
                    self?.startMarqueeAnimation()
                }
            } else {
                // 如果已经在动画中，保持动画
                restartMarqueeAnimationFromCurrentPosition()
            }
        } else {
            stopMarqueeAnimation()
            textLayer1.position = CGPoint(x: bounds.width / 2, y: centerY)
            textLayer1.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            textLayer2.string = ""
            CATransaction.commit()
        }
    }
    
    private func getTextAttributes() -> (String, NSColor, NSFont) {
        let displayText: String
        var textColor = customTextColor
        var font = self.font ?? NSFont.systemFont(ofSize: 13)
        
        if !_attributedTitle.string.isEmpty {
            displayText = _attributedTitle.string
            if _attributedTitle.length > 0 {
                var effectiveRange = NSRange(location: 0, length: 0)
                if let color = _attributedTitle.attribute(.foregroundColor, at: 0, effectiveRange: &effectiveRange) as? NSColor {
                    textColor = color
                }
                if let titleFont = _attributedTitle.attribute(.font, at: 0, effectiveRange: &effectiveRange) as? NSFont {
                    font = titleFont
                }
            }
        } else {
            displayText = _title
        }
        return (displayText, textColor, font)
    }
    
    private func updateTextColorOnly() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let (_, textColor, _) = getTextAttributes()
        [textLayer1, textLayer2].forEach { $0.foregroundColor = textColor.cgColor }
        CATransaction.commit()
    }
    
    // 核心修复：修正动画位置计算
    private func startMarqueeAnimation() {
        guard bounds.width > 0, !isAnimating else { return }
        
        stopMarqueeAnimation()
        
        let availableWidth = bounds.width - 2 * marqueePadding
        // 滚动距离：文本宽度 + 间距
        let scrollDistance = currentTextWidth + textSpacing
        
        // 修复：计算正确的动画范围
        // 起始位置：文本可见区域的开始
        // 结束位置：向左移动一个完整循环的距离
        let startX: CGFloat = 0
        let endX = -scrollDistance
        
        // 计算动画持续时间
        let animationDuration = Double(scrollDistance) / Double(marqueeSpeed)
        
        // 创建无限循环动画
        let animation = CABasicAnimation(keyPath: "position.x")
        animation.fromValue = startX
        animation.toValue = endX
        animation.duration = animationDuration
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        
        // 设置容器初始位置
        textLayersContainer.position = CGPoint(x: startX, y: 0)
        textLayersContainer.add(animation, forKey: "marquee")
        isAnimating = true
    }
    
    private func stopMarqueeAnimation() {
        if isAnimating {
            textLayersContainer.removeAnimation(forKey: "marquee")
            // 重置容器位置到初始状态
            textLayersContainer.position = CGPoint(x: 0, y: 0)
            isAnimating = false
        }
    }
    
    // 重新开始动画（用于布局更新等情况）
    private func restartMarqueeAnimationFromCurrentPosition() {
        guard isAnimating else { return }
        
        // 获取当前显示位置
        guard let presentation = textLayersContainer.presentation() else {
            startMarqueeAnimation()
            return
        }
        
        let currentX = presentation.position.x
        let scrollDistance = currentTextWidth + textSpacing
        
        // 计算当前位置相对于总距离的偏移
        let offset = abs(currentX).truncatingRemainder(dividingBy: scrollDistance)
        
        // 移除旧动画
        textLayersContainer.removeAnimation(forKey: "marquee")
        
        // 设置新的起始位置
        let startX = -offset
        
        // 创建新的动画
        let animation = CABasicAnimation(keyPath: "position.x")
        animation.fromValue = startX
        animation.toValue = startX - scrollDistance
        animation.duration = Double(scrollDistance) / Double(marqueeSpeed)
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        
        textLayersContainer.position = CGPoint(x: startX, y: 0)
        textLayersContainer.add(animation, forKey: "marquee")
    }
    
    override func layout() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        super.layout()
        
        maskLayer.frame = bounds
        textLayersContainer.frame = bounds
        
        if bounds.width > 0 && bounds.height > 0 {
            // 布局更新时更新显示
            updateDisplay()
            
            // 如果动画丢失了，重新开始
            if isAnimating && textLayersContainer.animation(forKey: "marquee") == nil {
                restartMarqueeAnimationFromCurrentPosition()
            }
        }
        
        CATransaction.commit()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        // 不绘制原生内容
    }
    
    // MARK: - 鼠标事件
    
    override func mouseDown(with event: NSEvent) {
        // 完全不干预动画
        super.mouseDown(with: event)
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
    }
    
    // MARK: - 辅助方法
    
    override var wantsUpdateLayer: Bool {
        return true
    }
    
    func setTextColor(_ color: NSColor) {
        self.customTextColor = color
        updateContent()
    }
    
    func setFont(_ font: NSFont) {
        self.font = font
        updateContent()
    }
    
    func refresh() {
        updateContent()
    }
    
    deinit {
        stopMarqueeAnimation()
        [textLayer1, textLayer2, textLayersContainer, maskLayer].forEach { $0.removeFromSuperlayer() }
    }
}


import Foundation
import Cocoa
import QuartzCore

// MARK: - 滚动方向枚举
public enum MIMarqueeDirection {
    case left
    case right
}

// MARK: - 扩展方法
extension MIMacMarqueeTextField {
    
    /// 通用方法
    static func getCommonMacMarqueeTextField(labelWithString stringValue: String) -> MIMacMarqueeTextField {
        let marqueeLabel = MIMacMarqueeTextField.getCommonMacMarqueeTextField()
        marqueeLabel.stringValue = stringValue
        return marqueeLabel
    }
    
    /// 通用方法
    static func getCommonMacMarqueeTextField() -> MIMacMarqueeTextField {
        let marqueeLabel = MIMacMarqueeTextField()
        marqueeLabel.font = .mi.pingFangSCMedium(size: 13)
        marqueeLabel.textColor = NSColor.black
        marqueeLabel.scrollSpeed = 50
        marqueeLabel.isScrolling = true
        marqueeLabel.scrollDirection = AppLanguage.isRTL ? .right : .left
        marqueeLabel.alignment = AppLanguage.isRTL ? .right : .left
        marqueeLabel.fadeLength = 10
        marqueeLabel.textSpacing = 30
        marqueeLabel.wantsLayer = true
        marqueeLabel.resetScrollOnTextChange = true // 默认开启
        return marqueeLabel
    }
}

// MARK: - 跑马灯主类
public class MIMacMarqueeTextField: NSView {
    
    // MARK: - NSTextField 兼容属性
    
    public var stringValue: String = "" {
        didSet {
            guard stringValue != oldValue else { return }
            handleTextChangeReset()
            updateDisplayText()
        }
    }
    
    public var attributedStringValue: NSAttributedString = NSAttributedString(string: "") {
        didSet {
            guard attributedStringValue != oldValue else { return }
            handleTextChangeReset()
            updateDisplayText()
        }
    }
    
    public var font: NSFont = NSFont.systemFont(ofSize: 13) {
        didSet {
            guard font != oldValue else { return }
            updateDisplayTextWithoutRestart()
        }
    }
    
    public var textColor: NSColor = .labelColor {
        didSet {
            guard textColor != oldValue else { return }
            updateDisplayTextWithoutRestart()
        }
    }
    
    public var alignment: NSTextAlignment = .center {
        didSet {
            guard alignment != oldValue else { return }
            updateTextLayerAlignment()
            updateTextLayerFrames()
        }
    }
    
    public var backgroundColor: NSColor? {
        didSet {
            guard backgroundColor != oldValue else { return }
            layer?.backgroundColor = backgroundColor?.cgColor
        }
    }
    
    public var isEditable: Bool = false
    public var isSelectable: Bool = false
    
    // MARK: - 新增属性：文本改变时重置滚动位置
    
    /// 当文本重新赋值时，是否重置滚动位置到最前面
    /// 默认值为 true，即每次文本改变都从头开始滚动
    /// 设置为 false 时，文本改变会保持当前滚动位置继续滚动
    public var resetScrollOnTextChange: Bool = true {
        didSet {
            if resetScrollOnTextChange && !oldValue {
                resetToInitialPosition()
            }
        }
    }
    
    // MARK: - 跑马灯特有属性
    
    public var scrollDirection: MIMarqueeDirection = .left {
        didSet {
            guard scrollDirection != oldValue else { return }
            resetToInitialPosition()
            restartIfNeeded()
        }
    }
    
    public var scrollSpeed: CGFloat = 50.0 {
        didSet {
            guard scrollSpeed != oldValue else { return }
            if isAnimating {
                lastUpdateTime = CACurrentMediaTime()
            }
        }
    }
    
    public var fadeLength: CGFloat = 0.0 {
        didSet {
            guard fadeLength != oldValue else { return }
            setupFadeLayers()
        }
    }
    
    public var isScrolling: Bool = false {
        didSet {
            guard isScrolling != oldValue else { return }
            if isScrolling {
                currentCycle = 0
                startScrolling()
            } else {
                stopScrolling()
            }
        }
    }
    
    public var textSpacing: CGFloat = 20.0 {
        didSet {
            guard textSpacing != oldValue else { return }
            updateTextLayerFrames()
        }
    }
    
    // MARK: - 私有属性
    private let scrollLayer = CALayer()
    private let textLayer1 = CATextLayer()
    private let textLayer2 = CATextLayer()
    private var fadeLayerLeft: CAGradientLayer?
    private var fadeLayerRight: CAGradientLayer?

    private var displayLink: CVDisplayLink?
    private var lastUpdateTime: TimeInterval = 0
    private var scrollOffset: CGFloat = 0

    private var textWidth: CGFloat = 0
    private var textHeight: CGFloat = 0
    private var shouldScroll: Bool = false
    private var isAnimating: Bool = false
    private var isScheduledToStart: Bool = false

    // 新增：循环跟踪
    private var currentCycle: Int = 0
    
    // MARK: - 初始化
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - 清理资源
    private func cleanup() {
        stopScrolling()
        stopDisplayLink()
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        fadeLayerLeft?.removeFromSuperlayer()
        fadeLayerRight?.removeFromSuperlayer()
        textLayer1.removeFromSuperlayer()
        textLayer2.removeFromSuperlayer()
        scrollLayer.removeFromSuperlayer()
        
        fadeLayerLeft = nil
        fadeLayerRight = nil
        
        CATransaction.commit()
        
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 设置
    
    private func setup() {
        wantsLayer = true
        layer?.masksToBounds = true
        
        setupScrollLayer()
        setupTextLayers()
        setupFadeLayers()
        
        textLayer1.isHidden = false
        textLayer1.string = stringValue
        textLayer1.foregroundColor = textColor.cgColor
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.updateDisplayText()
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillResignActive),
            name: NSApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    private func setupScrollLayer() {
        scrollLayer.frame = bounds
        scrollLayer.masksToBounds = true
        layer?.addSublayer(scrollLayer)
    }
    
    private func setupTextLayers() {
        configureTextLayer(textLayer1)
        configureTextLayer(textLayer2)
        
        textLayer1.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        textLayer2.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        
        textLayer1.foregroundColor = textColor.cgColor
        textLayer2.foregroundColor = textColor.cgColor
        
        scrollLayer.addSublayer(textLayer1)
        scrollLayer.addSublayer(textLayer2)
        
        textLayer1.isHidden = false
        textLayer2.isHidden = true
    }
    
    private func configureTextLayer(_ textLayer: CATextLayer) {
        textLayer.frame = bounds
        textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        textLayer.alignmentMode = alignmentMode
        textLayer.truncationMode = .none
        
        let fontRef = CTFontCreateWithName(font.fontName as CFString, font.pointSize, nil)
        textLayer.font = fontRef
        textLayer.fontSize = font.pointSize
    }
    
    private func updateTextLayerAlignment() {
        textLayer1.alignmentMode = alignmentMode
        textLayer2.alignmentMode = alignmentMode
    }
    
    // MARK: - 布局
    
    public override func layout() {
        super.layout()
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        scrollLayer.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        
        if bounds.width > 0 && bounds.height > 0 {
            let displayString = getDisplayString()
            let textSize = displayString.size()
            textWidth = textSize.width
            textHeight = textSize.height
            
            shouldScroll = textWidth > bounds.width
            
            updateTextLayerFramesImmediately()
            
            textLayer1.string = displayString
            textLayer2.string = displayString
            
            setupFadeLayers()
            
            if shouldScroll && isScrolling {
                startScrolling()
            } else {
                stopScrolling()
            }
        }
        
        CATransaction.commit()
    }
    
    // MARK: - 属性同步
    
    private var alignmentMode: CATextLayerAlignmentMode {
        switch alignment {
        case .center: return .center
        case .right: return .right
        default: return .left
        }
    }
    
    // MARK: - 文本更新和重置处理
    
    private func handleTextChangeReset() {
        if resetScrollOnTextChange {
            resetToInitialPosition()
        }
    }
    
    private func updateDisplayText() {
        guard bounds.width > 0 else { return }
        
        let displayString = getDisplayString()
        let textSize = displayString.size()
        let newTextWidth = textSize.width
        let newTextHeight = textSize.height
        
        let textSizeChanged = (newTextWidth != textWidth) || (newTextHeight != textHeight)
        textWidth = newTextWidth
        textHeight = newTextHeight
        
        let shouldScrollNow = textWidth > bounds.width
        let shouldUpdateLayout = (shouldScroll != shouldScrollNow) || textSizeChanged
        
        textLayer1.string = displayString
        textLayer2.string = displayString
        
        let fontRef = CTFontCreateWithName(font.fontName as CFString, font.pointSize, nil)
        textLayer1.font = fontRef
        textLayer2.font = fontRef
        textLayer1.fontSize = font.pointSize
        textLayer2.fontSize = font.pointSize
        
        textLayer1.foregroundColor = textColor.cgColor
        textLayer2.foregroundColor = textColor.cgColor
        
        if shouldUpdateLayout {
            shouldScroll = shouldScrollNow
            
            if resetScrollOnTextChange || !shouldScroll {
                scrollOffset = 0
            }
            
            updateTextLayerFramesImmediately()
            
            if shouldScroll != shouldScrollNow {
                if shouldScroll && isScrolling {
                    startScrolling()
                } else {
                    stopScrolling()
                }
            }
        } else {
            updateDisplayTextWithoutRestart()
        }
        
        textLayer1.isHidden = false
    }
    
    private func updateTextLayerFramesImmediately() {
        guard bounds.width > 0 else { return }
        
        let layerHeight = bounds.height
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        let verticalCenterY = max(0, (layerHeight - textHeight) / 2)
        
        if !shouldScroll {
            var textXPosition: CGFloat = 0
            var textWidthForLayout = textWidth
            
            if textWidthForLayout > bounds.width {
                textWidthForLayout = bounds.width
            }
            
            switch alignment {
            case .center:
                textXPosition = (bounds.width - textWidthForLayout) / 2
            case .right:
                textXPosition = bounds.width - textWidthForLayout
            default:
                textXPosition = 0
            }
            
            textLayer1.frame = CGRect(
                x: textXPosition,
                y: verticalCenterY,
                width: textWidthForLayout,
                height: textHeight
            )
            
            textLayer1.isHidden = false
            textLayer1.string = getDisplayString()
            
            textLayer2.isHidden = true
            
            textLayer1.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
            
        } else {
            let layerWidth = textWidth
            
            let textXPosition: CGFloat
            switch scrollDirection {
            case .left:
                textXPosition = 0
            case .right:
                textXPosition = bounds.width - layerWidth
            }
            
            textLayer1.frame = CGRect(
                x: textXPosition,
                y: verticalCenterY,
                width: layerWidth,
                height: textHeight
            )
            textLayer1.string = getDisplayString()
            
            textLayer2.isHidden = false
            
            let secondLayerX: CGFloat
            switch scrollDirection {
            case .left:
                secondLayerX = layerWidth + textSpacing + textXPosition
            case .right:
                secondLayerX = -(layerWidth + textSpacing) + textXPosition
            }
            
            textLayer2.frame = CGRect(
                x: secondLayerX,
                y: verticalCenterY,
                width: layerWidth,
                height: textHeight
            )
            textLayer2.string = getDisplayString()
            
            updateTextLayerPositions()
        }
        
        CATransaction.commit()
    }
    
    private func updateDisplayTextWithoutRestart() {
        let displayString = getDisplayString()
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        textLayer1.string = displayString
        textLayer2.string = displayString
        
        let fontRef = CTFontCreateWithName(font.fontName as CFString, font.pointSize, nil)
        textLayer1.font = fontRef
        textLayer2.font = fontRef
        textLayer1.fontSize = font.pointSize
        textLayer2.fontSize = font.pointSize
        
        textLayer1.foregroundColor = textColor.cgColor
        textLayer2.foregroundColor = textColor.cgColor
        
        CATransaction.commit()
        
        textLayer1.isHidden = false
        
        if shouldScroll && isScrolling {
            if displayLink == nil {
                setupDisplayLink()
            }
        }
    }
    
    private func getDisplayString() -> NSAttributedString {
        if attributedStringValue.length > 0 {
            return attributedStringValue
        } else {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = alignment
            
            return NSAttributedString(
                string: stringValue,
                attributes: [
                    .font: font,
                    .foregroundColor: textColor,
                    .paragraphStyle: paragraphStyle
                ]
            )
        }
    }
    
    private func updateTextLayerFrames() {
        guard bounds.width > 0 else { return }
        
        let layerHeight = bounds.height
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        let verticalCenterY = max(0, (layerHeight - textHeight) / 2)
        
        if !shouldScroll {
            var textXPosition: CGFloat = 0
            var textWidthForLayout = min(textWidth, bounds.width)
            
            switch alignment {
            case .center:
                textXPosition = (bounds.width - textWidthForLayout) / 2
            case .right:
                textXPosition = bounds.width - textWidthForLayout
            default:
                textXPosition = 0
            }
            
            if textWidthForLayout > bounds.width {
                textWidthForLayout = bounds.width
            }
            
            textLayer1.frame = CGRect(
                x: textXPosition,
                y: verticalCenterY,
                width: textWidthForLayout,
                height: textHeight
            )
            textLayer1.string = getDisplayString()
            
            textLayer1.isHidden = false
            textLayer2.isHidden = true
            
        } else {
            let layerWidth = textWidth
            
            let textXPosition: CGFloat
            switch scrollDirection {
            case .left:
                textXPosition = 0
            case .right:
                textXPosition = bounds.width - layerWidth
            }
            
            textLayer1.frame = CGRect(
                x: textXPosition,
                y: verticalCenterY,
                width: layerWidth,
                height: textHeight
            )
            textLayer1.string = getDisplayString()
            
            textLayer2.isHidden = false
            
            let secondLayerX: CGFloat
            switch scrollDirection {
            case .left:
                secondLayerX = layerWidth + textSpacing + textXPosition
            case .right:
                secondLayerX = -(layerWidth + textSpacing) + textXPosition
            }
            
            textLayer2.frame = CGRect(
                x: secondLayerX,
                y: verticalCenterY,
                width: layerWidth,
                height: textHeight
            )
            textLayer2.string = getDisplayString()
            
            updateTextLayerPositions()
        }
        
        CATransaction.commit()
    }
    
    private func updateTextLayerPositions() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        if shouldScroll {
            let layerWidth = textWidth
            let totalWidth = layerWidth + textSpacing
            
            let verticalCenterY = max(0, (bounds.height - textHeight) / 2)
            
            var baseX: CGFloat = 0
            if scrollDirection == .right {
                baseX = bounds.width - layerWidth
            }
            
            textLayer1.frame.origin.y = verticalCenterY
            textLayer2.frame.origin.y = verticalCenterY
            
            switch scrollDirection {
            case .left:
                textLayer1.frame.origin.x = baseX + scrollOffset
                textLayer2.frame.origin.x = baseX + scrollOffset + totalWidth
                textLayer2.isHidden = false
                
                if textLayer1.frame.origin.x + layerWidth < 0 {
                    textLayer1.frame.origin.x = textLayer2.frame.origin.x + totalWidth
                }
                if textLayer2.frame.origin.x + layerWidth < 0 {
                    textLayer2.frame.origin.x = textLayer1.frame.origin.x + totalWidth
                }
                
            case .right:
                textLayer1.frame.origin.x = baseX + scrollOffset
                textLayer2.frame.origin.x = baseX + scrollOffset - totalWidth
                textLayer2.isHidden = false
                
                if textLayer1.frame.origin.x > bounds.width {
                    textLayer1.frame.origin.x = textLayer2.frame.origin.x - totalWidth
                }
                if textLayer2.frame.origin.x > bounds.width {
                    textLayer2.frame.origin.x = textLayer1.frame.origin.x - totalWidth
                }
            }
            
        } else {
            let verticalCenterY = max(0, (bounds.height - textHeight) / 2)
            
            var textXPosition: CGFloat = 0
            let textWidthForLayout = min(textWidth, bounds.width)
            
            switch alignment {
            case .center:
                textXPosition = (bounds.width - textWidthForLayout) / 2
            case .right:
                textXPosition = bounds.width - textWidthForLayout
            default:
                textXPosition = 0
            }
            
            textLayer1.frame.origin.x = textXPosition
            textLayer1.frame.origin.y = verticalCenterY
            textLayer1.frame.size.width = textWidthForLayout
            textLayer1.isHidden = false
            
            textLayer2.isHidden = true
        }
        
        CATransaction.commit()
    }
    
    // MARK: - 渐变遮罩
    
    private func setupFadeLayers() {
        removeFadeLayers()
        
        guard fadeLength > 0, shouldScroll, bounds.width > 0 else { return }
        
        createFadeLayer(isLeft: true)
        createFadeLayer(isLeft: false)
    }
    
    public var fadeMaskColor: NSColor? {
        didSet {
            setupFadeLayers()
        }
    }
    
    private func checkMaskColor() -> NSColor {
        if let customColor = fadeMaskColor {
            return customColor
        } else if let backgroundColor = backgroundColor {
            return backgroundColor
        } else {
            return NSColor.white.withAlphaComponent(1.0)
        }
    }
    
    private func removeFadeLayers() {
        fadeLayerLeft?.removeFromSuperlayer()
        fadeLayerRight?.removeFromSuperlayer()
        fadeLayerLeft = nil
        fadeLayerRight = nil
    }

    private func createFadeLayer(isLeft: Bool) {
        let gradient = CAGradientLayer()
        let fadeLayerColor = checkMaskColor()
        if isLeft {
            gradient.frame = CGRect(x: 0, y: 0, width: fadeLength, height: bounds.height)
            gradient.colors = [
                fadeLayerColor.cgColor,
                fadeLayerColor.withAlphaComponent(0.0).cgColor
            ]
            gradient.startPoint = CGPoint(x: 0.0, y: 0.5)
            gradient.endPoint = CGPoint(x: 1.0, y: 0.5)
            fadeLayerLeft = gradient
        } else {
            gradient.frame = CGRect(
                x: bounds.width - fadeLength,
                y: 0,
                width: fadeLength,
                height: bounds.height
            )
            gradient.colors = [
                fadeLayerColor.withAlphaComponent(0.0).cgColor,
                fadeLayerColor.cgColor
            ]
            gradient.startPoint = CGPoint(x: 0.0, y: 0.5)
            gradient.endPoint = CGPoint(x: 1.0, y: 0.5)
            fadeLayerRight = gradient
        }
        
        layer?.addSublayer(gradient)
    }
    
    // MARK: - 动画控制
    
    private func startScrolling() {
        guard shouldScroll, !isAnimating, displayLink == nil, !isScheduledToStart else { return }
        
        guard superview != nil, window != nil else {
            return
        }
        
        currentCycle = 0
        isScheduledToStart = true
        
        // 移除了初始延迟，直接开始滚动
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            guard self.isScrolling,
                  self.shouldScroll,
                  !self.isAnimating,
                  self.displayLink == nil,
                  self.superview != nil,
                  self.window != nil else {
                self.isScheduledToStart = false
                return
            }
            
            self.isScheduledToStart = false
            self.setupDisplayLink()
        }
    }
    
    private func setupDisplayLink() {
        var link: CVDisplayLink?
        let result = CVDisplayLinkCreateWithActiveCGDisplays(&link)
        
        guard result == kCVReturnSuccess, let displayLink = link else {
            return
        }
        
        self.displayLink = displayLink
        
        CVDisplayLinkSetOutputCallback(displayLink, { (link, inNow, inOutputTime, flagsIn, flagsOut, context) -> CVReturn in
            guard let context = context else { return kCVReturnError }
            
            let wrapper = Unmanaged<MIMacMarqueeTextField>.fromOpaque(context).takeUnretainedValue()
            
            if wrapper.superview != nil && wrapper.window != nil {
                wrapper.updateScrollPosition()
                return kCVReturnSuccess
            } else {
                wrapper.stopDisplayLink()
                return kCVReturnError
            }
        }, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        
        CVDisplayLinkStart(displayLink)
        lastUpdateTime = CACurrentMediaTime()
        isAnimating = true
    }
    
    private func stopScrolling() {
        stopDisplayLink()
        isScheduledToStart = false
    }
    
    private func stopDisplayLink() {
        guard let link = displayLink else { return }
        
        CVDisplayLinkStop(link)
        CVDisplayLinkSetOutputCallback(link, nil, nil)
        displayLink = nil
        isAnimating = false
    }
    
    private func resetToInitialPosition() {
        scrollOffset = 0
        currentCycle = 0
        updateTextLayerPositions()
    }
    
    private func restartIfNeeded() {
        let wasScrolling = isScrolling
        isScrolling = false
        stopScrolling()
        
        currentCycle = 0
        scrollOffset = 0
        
        if wasScrolling {
            isScrolling = true
            startScrolling()
        }
    }
    
    // MARK: - 滚动更新
    
    private func updateScrollPosition() {
        guard superview != nil && window != nil else {
            stopDisplayLink()
            return
        }
        
        let currentTime = CACurrentMediaTime()
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        
        let scrollDelta = CGFloat(deltaTime) * scrollSpeed
        
        DispatchQueue.main.async { [weak self] in
            self?.handleScrollUpdate(scrollDelta: scrollDelta)
        }
    }
    
    private func handleScrollUpdate(scrollDelta: CGFloat) {
        guard superview != nil && window != nil else {
            stopDisplayLink()
            return
        }
        
        guard shouldScroll else { return }
        
        // 移除了所有暂停逻辑，连续滚动
        switch scrollDirection {
        case .left:
            scrollOffset -= scrollDelta
            if scrollOffset <= -(textWidth + textSpacing) {
                scrollOffset = 0
                currentCycle += 1
            }
        case .right:
            scrollOffset += scrollDelta
            if scrollOffset >= (textWidth + textSpacing) {
                scrollOffset = 0
                currentCycle += 1
            }
        }
        
        updateTextLayerPositions()
    }
    
    // MARK: - 应用状态处理
    
    @objc private func applicationWillResignActive() {
        stopDisplayLink()
    }
    
    @objc private func applicationDidBecomeActive() {
        if isScrolling && shouldScroll && superview != nil && window != nil {
            startScrolling()
        }
    }

    /// 获取当前循环次数
    public var currentScrollCycle: Int {
        return currentCycle
    }

    /// 强制重置滚动位置到最前面
    public func resetScrollPosition() {
        resetToInitialPosition()
        if isScrolling && shouldScroll {
            if displayLink == nil && superview != nil && window != nil {
                setupDisplayLink()
            }
        }
    }
    
    /// 获取当前滚动位置（百分比）
    public var scrollProgress: CGFloat {
        guard shouldScroll, textWidth > 0 else { return 0 }
        return abs(scrollOffset) / (textWidth + textSpacing)
    }
    
    /// 继续滚动（如果之前停止了）
    public func continueScrolling() {
        if isScrolling && shouldScroll && displayLink == nil && superview != nil && window != nil {
            setupDisplayLink()
        }
    }
    
    // MARK: - 原有公开方法
    
    public func restartScrolling() {
        resetToInitialPosition()
        if isScrolling {
            stopScrolling()
            startScrolling()
        }
    }
    
    public func sizeToFit() {
        let size = attributedStringValue.size()
        var frame = self.frame
        frame.size.width = size.width
        frame.size.height = size.height
        self.frame = frame
    }
}

//
//  SelectBoxView.swift
//  HXPhotoPicker
//
//  Created by Slience on 2020/12/29.
//  Copyright © 2020 Silence. All rights reserved.
//

import UIKit

public final class SelectBoxView: UIControl {
    
    public enum Style: Int {
        /// 数字
        case number
        /// 勾勾
        case tick
    }
    
    public var text: String = "0" {
        didSet {
            if config.style == .number {
                textLayer.string = text
            }
        }
    }
    public override var isSelected: Bool {
        didSet {
            if !isSelected {
                text = "0"
            }
            updateLayers()
        }
    }
    public override var isHighlighted: Bool {
        didSet {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            updateLayers()
            CATransaction.commit()
        }
    }
    
    var textSize: CGSize = CGSize.zero
    
    private var borderLayer: CAShapeLayer! // 专门用于绘制边框
    private var fillLayer: CAShapeLayer!   // 专门用于填充颜色
    private var textLayer: CATextLayer!
    private var tickLayer: CAShapeLayer!
    
    public var config: SelectBoxConfiguration
    public init(_ config: SelectBoxConfiguration, frame: CGRect = .zero) {
        self.config = config
        super.init(frame: frame)
        initViews()
        // 注意图层顺序：先添加填充层，再添加边框层，确保边框在上方可见
        layer.addSublayer(fillLayer)
        layer.addSublayer(borderLayer)
        layer.addSublayer(textLayer)
        layer.addSublayer(tickLayer)
    }
    
    private func initViews() {
        borderLayer = CAShapeLayer()
        borderLayer.contentsScale = UIScreen._scale
        borderLayer.fillColor = UIColor.clear.cgColor // 边框层不填充
        
        fillLayer = CAShapeLayer()
        fillLayer.contentsScale = UIScreen._scale
        fillLayer.strokeColor = UIColor.clear.cgColor // 填充层不描边
        
        textLayer = CATextLayer()
        textLayer.contentsScale = UIScreen._scale
        textLayer.alignmentMode = .center
        textLayer.isWrapped = true
        
        tickLayer = CAShapeLayer()
        tickLayer.lineJoin = .round
        tickLayer.contentsScale = UIScreen._scale
    }
    
    private func borderPath() -> CGPath {
        // 边框路径使用完整尺寸
        let strokePath: UIBezierPath = .init(
            roundedRect: CGRect(
                x: 0,
                y: 0,
                width: width,
                height: height
            ),
            cornerRadius: height / 2
        )
        return strokePath.cgPath
    }
    
    private func fillPath() -> CGPath {
        // 填充路径需要缩小，为边框留出空间
        let currentBorderWidth = isSelected ? config.selectBorderWidth : config.borderWidth
        let inset = currentBorderWidth / 2.0 // 内缩量为边框宽度
        let fillRect = CGRect(
            x: inset,
            y: inset,
            width: width - inset * 2,
            height: height - inset * 2
        )
        let fillPath: UIBezierPath = .init(
            roundedRect: fillRect,
            cornerRadius: (height - inset * 2) / 2
        )
        return fillPath.cgPath
    }
    
    private func drawBorderLayer() {
        borderLayer.path = borderPath()
        
        if isSelected {
            borderLayer.lineWidth = config.selectBorderWidth
            
            let selectedBorderColor = config.selectBorderColor
            let selectedBorderDarkColor = config.selectBorderDarkColor
            
            if isHighlighted {
                borderLayer.strokeColor = PhotoManager.isDark ?
                selectedBorderDarkColor.withAlphaComponent(0.4).cgColor :
                selectedBorderColor.withAlphaComponent(0.4).cgColor
            } else {
                borderLayer.strokeColor = PhotoManager.isDark ? selectedBorderDarkColor.cgColor : selectedBorderColor.cgColor
            }
            
        } else {
            borderLayer.lineWidth = config.borderWidth
            
            let borderColor = config.borderColor
            let borderDarkColor = config.borderDarkColor
            
            if isHighlighted {
                borderLayer.strokeColor = PhotoManager.isDark ?
                borderDarkColor.withAlphaComponent(0.4).cgColor :
                borderColor.withAlphaComponent(0.4).cgColor
            } else {
                borderLayer.strokeColor = PhotoManager.isDark ? borderDarkColor.cgColor : borderColor.cgColor
            }
        }
    }
    
    private func drawFillLayer() {
        fillLayer.path = fillPath()
        
        if isSelected {
            let selectedBackgroundColor = config.selectedBackgroundColor
            let selectedBackgroudDarkColor = config.selectedBackgroudDarkColor
            
            if isHighlighted {
                fillLayer.fillColor = PhotoManager.isDark ?
                selectedBackgroudDarkColor.withAlphaComponent(0.4).cgColor :
                selectedBackgroundColor.withAlphaComponent(0.4).cgColor
            } else {
                fillLayer.fillColor = PhotoManager.isDark ?
                selectedBackgroudDarkColor.cgColor :
                selectedBackgroundColor.cgColor
            }
            
        } else {
            let backgroundColor = config.backgroundColor
            let darkBackgroundColor = config.darkBackgroundColor
            
            if isHighlighted {
                fillLayer.fillColor = PhotoManager.isDark ?
                darkBackgroundColor.withAlphaComponent(0.4).cgColor :
                backgroundColor.withAlphaComponent(0.4).cgColor
            } else {
                fillLayer.fillColor = PhotoManager.isDark ? darkBackgroundColor.cgColor : backgroundColor.cgColor
            }
        }
    }
    
    private func drawTextLayer() {
        if config.style != .number {
            textLayer.isHidden = true
            return
        }
        if !isSelected {
            textLayer.string = nil
        }
        
        let font: UIFont = .mediumPingFang(ofSize: config.titleFontSize)
        var textHeight: CGFloat
        var textWidth: CGFloat
        if textSize.equalTo(CGSize.zero) {
            textHeight = text.height(ofFont: font, maxWidth: CGFloat(MAXFLOAT))
            textWidth = text.width(ofFont: font, maxHeight: textHeight)
        }else {
            textHeight = textSize.height
            textWidth = textSize.width
        }
        textLayer.frame = CGRect(
            x: (width - textWidth) * 0.5,
            y: (height - textHeight) * 0.5,
            width: textWidth,
            height: textHeight
        )
        textLayer.font = CGFont(font.fontName as CFString)
        textLayer.fontSize = config.titleFontSize
        let color = PhotoManager.isDark ? config.titleDarkColor : config.titleColor
        textLayer.foregroundColor = isHighlighted ? color.withAlphaComponent(0.4).cgColor : color.cgColor
    }
    
    private func tickPath() -> CGPath {
        let tickPath: UIBezierPath = .init()
        tickPath.move(to: CGPoint(x: scale(8), y: height * 0.5 + scale(1)))
        tickPath.addLine(to: CGPoint(x: width * 0.5 - scale(2), y: height - scale(8)))
        tickPath.addLine(to: CGPoint(x: width - scale(7), y: scale(9)))
        return tickPath.cgPath
    }
    private func drawTickLayer() {
        if config.style != .tick {
            tickLayer.isHidden = true
            return
        }
        tickLayer.isHidden = !isSelected
        tickLayer.path = tickPath()
        tickLayer.lineWidth = config.tickWidth
        let color = PhotoManager.isDark ? config.tickDarkColor : config.tickColor
        tickLayer.strokeColor = isHighlighted ? color.withAlphaComponent(0.4).cgColor : color.cgColor
        tickLayer.fillColor = UIColor.clear.cgColor
    }
    
    public func updateLayers() {
        borderLayer.frame = bounds
        fillLayer.frame = bounds
        if config.style == .tick {
            tickLayer.frame = bounds
        }
        drawBorderLayer()
        drawFillLayer()
        drawTextLayer()
        drawTickLayer()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func scale(_ numerator: CGFloat) -> CGFloat {
        return numerator / 30 * height
    }
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if isUserInteractionEnabled && CGRect(x: -15, y: -15, width: width + 30, height: height + 30).contains(point) {
            return self
        }
        return super.hitTest(point, with: event)
    }
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                drawBorderLayer()
                drawFillLayer()
                drawTextLayer()
                drawTickLayer()
            }
        }
    }
}

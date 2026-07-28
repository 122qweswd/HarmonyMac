//
//  CircularProgressView.swift
//  MutualInfection
//
//  Created by 1234 on 2025/9/22.
//
//
//圆形进度条

import Cocoa

class CircularProgressView: NSView {
    // MARK: - 属性
    var progress: CGFloat = 0.0 {
        didSet {
            progress = max(0.0, min(1.0, progress)) // 限制范围 [0,1]
            needsDisplay = true // 触发重绘
        }
    }
    
    var lineWidth: CGFloat = 2.5
    var progressColor: NSColor = .mi.hex("#0A59F7",alpha:1)
    var trackColor: NSColor = .mi.hex("#ffffff",alpha: 0)
    
    // MARK: - 绘制方法
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // 计算圆心和半径
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - lineWidth
        
        // 绘制背景圆环
        context.setStrokeColor(trackColor.cgColor)
        context.setLineWidth(lineWidth)
        context.addArc(center: center, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        context.strokePath()
        
        // 绘制进度圆弧
        context.setStrokeColor(progressColor.cgColor)
        context.setLineCap(.round) // 圆角端点
        context.addArc(
            center: center,
            radius: radius,
            startAngle: .pi / 2, // 从12点钟方向开始 (0 = 3点钟方向)
            endAngle: .pi / 2 - 2 * .pi * progress,
            clockwise: true
        )
        context.strokePath()
    }
    
    // MARK: - 动画方法
    func setProgress(_ value: CGFloat, animated: Bool = true, duration: TimeInterval = 0.5) {
        if animated {
            let animation = CABasicAnimation(keyPath: "progress")
            animation.duration = duration
            animation.fromValue = progress
            animation.toValue = value
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer?.add(animation, forKey: "progressAnimation")
        }
        progress = value
    }
}

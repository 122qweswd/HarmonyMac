//
//  LinearProgressView.swift
//  MutualInfection
//
//
// 直线进度条

import Cocoa

class LinearProgressView: NSView {
    // MARK: - 属性
    var progress: CGFloat = 0.0 {
        didSet {
            progress = max(0.0, min(1.0, progress)) // 限制范围 [0,1]
            needsDisplay = true // 触发重绘
        }
    }
    
    var height: CGFloat = 6.0
    var progressColor: NSColor = .mi.hex("#86B6FF",alpha:0.5)
    var trackColor: NSColor = .mi.hex("#E5E5E5",alpha: 1)
    var cornerRadius: CGFloat = 3.0 // 圆角半径
    
    // MARK: - 绘制方法
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // 计算进度条区域
        let barHeight = min(height, bounds.height)
        let barY = (bounds.height - barHeight) / 2
        let barWidth = bounds.width - 2
        let barX = 1
        
        // 绘制背景条
        let trackRect = CGRect(x: CGFloat(barX), y: barY, width: barWidth, height: barHeight)
        context.setFillColor(trackColor.cgColor)
        
        // 创建圆角矩形路径
        let roundedRectPath = CGMutablePath()
        roundedRectPath.addRoundedRect(in: trackRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius)
        context.addPath(roundedRectPath)
        context.fillPath()
        
        // 绘制进度条
        let progressWidth = barWidth * progress
        let progressRect = CGRect(x: CGFloat(barX), y: barY, width: progressWidth, height: barHeight)
        context.setFillColor(progressColor.cgColor)
        
        if progressWidth <= cornerRadius {
            // 如果进度很小，只绘制一个半圆
            context.fillEllipse(in: CGRect(x: CGFloat(barX), y: barY, width: 2 * cornerRadius, height: barHeight))
        } else {
            // 绘制进度条的左半圆
            context.fillEllipse(in: CGRect(x: CGFloat(barX), y: barY, width: 2 * cornerRadius, height: barHeight))
            // 绘制进度条的中间部分
            context.fill(CGRect(x: CGFloat(barX) + cornerRadius, y: barY, width: progressWidth - cornerRadius, height: barHeight))
            
            // 绘制右半圆
            if progressWidth > cornerRadius {
                context.fillEllipse(in: CGRect(x: CGFloat(barX) + progressWidth - cornerRadius, y: barY, width: 2 * cornerRadius, height: barHeight))
            }
        }
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

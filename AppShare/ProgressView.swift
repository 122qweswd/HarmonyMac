//
//  ProgressView.swift
//  AppShare
//
//  Created by Niko on 2025/10/27.
//

import UIKit

class ProgressView: UIView {
    
    /// 进度值 (0.0 - 1.0)
    var progress: CGFloat = 0.0 {
        didSet {
            progress = min(max(progress, 0.0), 1.0)
            updateProgress()
        }
    }
    
    /// 进度条颜色
    var progressColor: UIColor = .systemBlue {
        didSet {
            progressLayer.strokeColor = progressColor.cgColor
        }
    }
    
    /// 背景颜色
    var trackColor: UIColor = UIColor.systemGray5 {
        didSet {
            trackLayer.strokeColor = trackColor.cgColor
        }
    }
    
    /// 线条宽度
    var lineWidth: CGFloat = 4 {
        didSet {
            trackLayer.lineWidth = lineWidth
            progressLayer.lineWidth = lineWidth
        }
    }
    
    // MARK: - UI Elements
    
    /// 底层轨道
    private let trackLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = UIColor.systemGray5.cgColor
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = 4
        layer.lineCap = .round
        return layer
    }()
    
    /// 进度层
    private let progressLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = UIColor.systemBlue.cgColor
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = 4
        layer.lineCap = .round
        layer.strokeEnd = 0
        return layer
    }()
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }
    
    private func setupLayers() {
        layer.addSublayer(trackLayer)
        layer.addSublayer(progressLayer)
        
        backgroundColor = .clear
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - lineWidth / 2
        
        // 创建圆形路径（从顶部开始，顺时针）
        let startAngle: CGFloat = -CGFloat.pi / 2
        let endAngle: CGFloat = startAngle + 2 * CGFloat.pi
        
        let circularPath = UIBezierPath(arcCenter: center,
                                       radius: radius,
                                       startAngle: startAngle,
                                       endAngle: endAngle,
                                       clockwise: true)
        
        trackLayer.path = circularPath.cgPath
        progressLayer.path = circularPath.cgPath
        
        updateProgress()
    }
    
    // MARK: - Private Methods
    
    private func updateProgress() {
        progressLayer.strokeEnd = progress
    }
    
    /// 设置进度（带动画）
    func setProgress(_ progress: CGFloat, animated: Bool = true) {
        let newProgress = min(max(progress, 0.0), 1.0)
        
        if animated {
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = self.progress
            animation.toValue = newProgress
            animation.duration = 0.3
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false
            
            progressLayer.add(animation, forKey: "progressAnimation")
            
            self.progress = newProgress
        } else {
            self.progress = newProgress
        }
    }
}


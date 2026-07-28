//
//  MICircleProgressView.swift
//  MutualInfectionApp
//
//  Created by tsbook on 2025/10/14.
//

import UIKit

class CircleProgressView: UIView {
    // MARK: - 可配置属性
    /// 进度值（0~1）
    var progress: CGFloat = 0 {
        didSet {
            // 限制进度在0~1范围内
            progress = max(0, min(1, progress))
            updateProgressAnimation()
        }
    }
    
    /// 圆环线宽
    var lineWidth: CGFloat = 6 {
        didSet {
            progressLayer.lineWidth = lineWidth
            layoutSubviews() // 重新布局路径
        }
    }
    
    /// 背景圆环颜色
    var bgColor: UIColor = UIColor(white: 0.9, alpha: 1) {
        didSet {
//            backgroundLayer.strokeColor = bgColor.cgColor
        }
    }
    
    /// 进度圆环颜色
    var progressColor: UIColor = UIColor(red: 134 / 255.0, green: 182 / 255.0, blue: 255 / 255.0, alpha: 1.0) {
        didSet {
            progressLayer.strokeColor = progressColor.cgColor
        }
    }
    
    // MARK: - 图层
//    private let backgroundLayer = CAShapeLayer() // 背景圆环
    private let progressLayer = CAShapeLayer()   // 进度圆环
    
    // MARK: - 初始化
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }
    
    // MARK: - 布局
    override func layoutSubviews() {
        super.layoutSubviews()
        updateCirclePath() // 更新圆环路径
    }
    
    // MARK: - 私有方法
    /// 初始化图层
    private func setupLayers() {
        // 背景圆环配置
//        backgroundLayer.fillColor = UIColor.clear.cgColor
//        backgroundLayer.strokeColor = bgColor.cgColor
//        backgroundLayer.lineWidth = lineWidth
//        backgroundLayer.lineCap = .round // 线条端点圆角
        
        // 进度圆环配置
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = progressColor.cgColor
        progressLayer.lineWidth = lineWidth
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0 // 初始进度为0
        
        // 添加图层（先添加背景，再添加进度层）
        layer.addSublayer(progressLayer)
    }
    
    /// 更新圆环路径
    private func updateCirclePath() {
        // 计算圆环中心和半径
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - lineWidth / 2
        
        // 创建圆环路径（从12点方向开始，顺时针绘制）
        let startAngle = -CGFloat.pi / 2
        let endAngle = startAngle + 2 * CGFloat.pi
        
        let path = UIBezierPath(arcCenter: center,
                                radius: radius,
                                startAngle: startAngle,
                                endAngle: endAngle,
                                clockwise: true)
        
        // 应用路径到图层
//        backgroundLayer.path = path.cgPath
        progressLayer.path = path.cgPath
    }
    
    /// 进度更新动画
    private func updateProgressAnimation() {
        // 添加动画使进度变化更平滑
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = progressLayer.strokeEnd
        animation.toValue = progress
        animation.duration = 0.3 // 动画时长
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        progressLayer.add(animation, forKey: "progressAnimation")
        
        // 更新实际值
        progressLayer.strokeEnd = progress
    }
}

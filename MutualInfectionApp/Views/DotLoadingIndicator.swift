//import UIKit
//
//class DotLoadingIndicator: UIView {
//    
//    // 配置参数
//    private let dotCount: Int = 3
//    private let dotSize: CGFloat = 10.0
//    private let dotSpacing: CGFloat = 8.0
//    private let animationDuration: TimeInterval = 1.2
//    private let animationDelay: TimeInterval = 0.2
//    private let dotColor: UIColor = .black
//    
//    // 存储圆点视图的数组
//    private var dotViews: [UIView] = []
//    
//    // 动画控制
//    private var isAnimating: Bool = false
//    
//    override init(frame: CGRect) {
//        super.init(frame: frame)
//        setupDots()
//    }
//    
//    required init?(coder: NSCoder) {
//        super.init(coder: coder)
//        setupDots()
//    }
//    
//    private func setupDots() {
//        // 清除可能存在的旧圆点
//        dotViews.forEach { $0.removeFromSuperview() }
//        dotViews.removeAll()
//        
//        // 创建指定数量的圆点
//        for i in 0..<dotCount {
//            let dotView = UIView()
//            dotView.backgroundColor = dotColor
//            dotView.layer.cornerRadius = dotSize / 2
//            dotView.translatesAutoresizingMaskIntoConstraints = false
//            addSubview(dotView)
//            dotViews.append(dotView)
//            
//            // 设置约束
//            NSLayoutConstraint.activate([
//                dotView.widthAnchor.constraint(equalToConstant: dotSize),
//                dotView.heightAnchor.constraint(equalToConstant: dotSize),
//                dotView.centerYAnchor.constraint(equalTo: centerYAnchor),
//                dotView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: CGFloat(i) * (dotSize + dotSpacing))
//            ])
//        }
//        
//        // 设置视图的intrinsicContentSize，以便在AutoLayout中正确显示
//        let totalWidth = CGFloat(dotCount - 1) * (dotSize + dotSpacing) + dotSize
//        let totalHeight = dotSize
//        intrinsicContentSize = CGSize(width: totalWidth, height: totalHeight)
//    }
//    
//    // 开始动画
//    func startAnimating() {
//        guard !isAnimating else { return }
//        isAnimating = true
//        
//        // 为每个圆点设置动画
//        for (index, dotView) in dotViews.enumerated() {
//            // 重置圆点状态
//            dotView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
//            
//            // 创建缩放动画
//            let scaleAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
//            scaleAnimation.values = [1.0, 1.5, 1.0]
//            scaleAnimation.keyTimes = [0.0, 0.5, 1.0]
//            scaleAnimation.duration = animationDuration
//            scaleAnimation.repeatCount = .infinity
//            scaleAnimation.timeOffset = TimeInterval(index) * animationDelay
//            scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
//            
//            // 应用动画
//            dotView.layer.add(scaleAnimation, forKey: "scaleAnimation")
//        }
//    }
//    
//    // 停止动画
//    func stopAnimating() {
//        guard isAnimating else { return }
//        isAnimating = false
//        
//        // 移除所有圆点的动画
//        for dotView in dotViews {
//            dotView.layer.removeAllAnimations()
//            dotView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
//        }
//    }
//    
//    // 重写intrinsicContentSize以支持AutoLayout
//    override var intrinsicContentSize: CGSize {
//        get {
//            return super.intrinsicContentSize
//        }
//        set {
//            super.intrinsicContentSize = newValue
//        }
//    }
//}
//
//// 使用示例扩展
//public extension UIViewController {
//    func showDotLoadingIndicator(in view: UIView, at center: CGPoint? = nil) -> DotLoadingIndicator {
//        let indicator = DotLoadingIndicator()
//        indicator.translatesAutoresizingMaskIntoConstraints = false
//        view.addSubview(indicator)
//        
//        // 设置约束
//        NSLayoutConstraint.activate([
//            indicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//            indicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
//        ])
//        
//        // 开始动画
//        indicator.startAnimating()
//        
//        return indicator
//    }
//}

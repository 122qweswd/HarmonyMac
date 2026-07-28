//
//  MICustomPresentationAnimator.swift
//  SearchCar-driver
//
//  Created by Niko on 2023/8/19.
//

import UIKit

/***
 
 present 示例
 let controller = ViewController()
 controller.modalPresentationStyle = .custom
 let config = MICustomPresentationAnimator()
 controller.transitioningDelegate = config
 self.present(controller, animated: true, completion: nil)

 dismiss 示例
 let config = MICustomPresentationAnimator()
 self.transitioningDelegate = config
 self.dismiss(animated: true, completion: nil)
 
***/

class MICustomPresentationAnimator: NSObject, UIViewControllerAnimatedTransitioning, UIViewControllerTransitioningDelegate {
    
    /// 后方遮罩背景颜色 默认 #000000
    var backgroundColor: UIColor = "#000000".color
    
    /// 后方遮罩透明度 默认 0.1
    var alpha: CGFloat = 0.15
    
    /// 动画时长 默认 0.3
    var duration: TimeInterval = 0.3
    
    var isTop: Bool = false
    
    private var isPresenting: Bool = false
    private var coverView: UIView?
    
    convenience init(presenting: Bool) {
        self.init()
        self.isPresenting = presenting
    }
    
    // MARK: - UIViewControllerAnimatedTransitioning
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return duration
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let fromVC = transitionContext.viewController(forKey: .from),
              let toVC = transitionContext.viewController(forKey: .to) else {
            transitionContext.completeTransition(false)
            return
        }
        
        let containerView = transitionContext.containerView
        
        if isPresenting {
            // 添加遮罩视图
            let coverView = UIView(frame: UIScreen.main.bounds)
            coverView.backgroundColor = backgroundColor
            coverView.alpha = 0
            containerView.addSubview(coverView)
            self.coverView = coverView
            
            // 添加目标视图
            containerView.addSubview(toVC.view)
            
            // 设置初始位置
            let initialY = isTop ? -containerView.frame.height : containerView.frame.height
            toVC.view.frame = CGRect(x: 0, y: initialY, width: containerView.frame.width, height: containerView.frame.height)
        } else {
            // 查找遮罩视图
            self.coverView = containerView.subviews.first(where: { $0 != fromVC.view })
        }
        
        // 获取最终frame
        let finalFrame = transitionContext.finalFrame(for: isPresenting ? toVC : fromVC)
        
        // 执行动画
        UIView.animate(withDuration: duration, animations: {
            if self.isPresenting {
                toVC.view.frame = finalFrame
                self.coverView?.alpha = self.alpha
            } else {
                self.coverView?.alpha = 0
                fromVC.view.frame = CGRect(x: 0, y: containerView.frame.height, width: containerView.frame.width, height: containerView.frame.height)
            }
        }) { _ in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
    
    // MARK: - UIViewControllerTransitioningDelegate
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        let animator = MICustomPresentationAnimator(presenting: true)
        animator.isTop = self.isTop
        return animator
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return MICustomPresentationAnimator(presenting: false)
    }
}

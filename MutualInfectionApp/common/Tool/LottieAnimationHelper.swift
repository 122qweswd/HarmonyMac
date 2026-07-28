//
//  LottieAnimationHelper.swift
//  MutualInfectionApp
//
//  Created by apple on 2025/9/2.
//

import UIKit
import Lottie // 需要导入Lottie库

/// Lottie动画帮助类
class LottieAnimationHelper {
    
    /// 创建并配置Lottie动画视图
    /// - Parameters:
    ///   - animationName: 动画JSON文件名（不包含.json后缀）
    ///   - loopMode: 动画循环模式
    ///   - contentMode: 内容显示模式
    ///   - size: 动画视图大小
    /// - Returns: 配置好的Lottie动画视图
    static func createAnimationView(animationName: String, 
                                   loopMode: LottieLoopMode = .loop, 
                                   contentMode: UIView.ContentMode = .scaleAspectFit, 
                                   size: CGSize? = nil) -> LottieAnimationView {
        // 从JSON文件创建动画视图
        let animationView = LottieAnimationView(name: animationName)
        
        // 设置动画属性
        animationView.loopMode = loopMode
        animationView.contentMode = contentMode
        animationView.translatesAutoresizingMaskIntoConstraints = false
        
        // 设置大小（如果提供）
        if let size = size {
            animationView.frame.size = size
        }
        
        return animationView
    }
    
    /// 加载并播放雷达动画
    /// - Parameters:
    ///   - containerView: 容纳动画的容器视图
    ///   - animationName: 动画JSON文件名
    ///   - autoPlay: 是否自动播放
    ///   - completion: 加载完成回调
    /// - Returns: 雷达动画视图
    static func loadRadarAnimation(in containerView: UIView, 
                                  animationName: String = "接收雷达".localized, 
                                  autoPlay: Bool = true, 
                                  completion: ((LottieAnimationView?) -> Void)? = nil) -> LottieAnimationView? {
        do {
            // 创建动画视图
            let animationView = createAnimationView(animationName: animationName)
            
            // 添加到容器视图
            containerView.addSubview(animationView)
            
            // 设置约束，使其居中并占满容器
            animationView.snp.makeConstraints {
                $0.center.equalToSuperview()
                $0.width.height.equalToSuperview()
            }
            
            // 如果需要自动播放
            if autoPlay {
                animationView.play {completed in 
                    // 动画播放完成回调
                    completion?(animationView)
                }
            } else {
                // 立即调用完成回调
                completion?(animationView)
            }
            
            return animationView
        } catch {
            print("加载Lottie动画失败: \(error)")
            completion?(nil)
            return nil
        }
    }
}

/// UIView的Lottie扩展
extension UIView {
    
    /// 添加Lottie动画到视图
    /// - Parameters:
    ///   - animationName: 动画JSON文件名
    ///   - loopMode: 动画循环模式
    ///   - autoPlay: 是否自动播放
    /// - Returns: 添加的Lottie动画视图
    func addLottieAnimation(animationName: String, 
                           loopMode: LottieLoopMode = .loop, 
                           autoPlay: Bool = true) -> LottieAnimationView? {
        let animationView = LottieAnimationHelper.createAnimationView(animationName: animationName, loopMode: loopMode)
        self.addSubview(animationView)
        
        animationView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        
        if autoPlay {
            animationView.play()
        }
        
        return animationView
    }
}

/// ViewController的Lottie扩展
extension UIViewController {
    
    /// 在视图控制器中显示Lottie加载动画
    /// - Parameters:
    ///   - animationName: 动画JSON文件名
    ///   - size: 动画大小
    ///   - centerOffset: 中心偏移量
    /// - Returns: 加载动画视图
    func showLoadingAnimation(animationName: String = "loading", 
                             size: CGSize = CGSize(width: 100, height: 100), 
                             centerOffset: CGPoint = .zero) -> LottieAnimationView {
        // 创建加载动画视图
        let loadingView = LottieAnimationView(name: animationName)
        loadingView.frame = CGRect(origin: .zero, size: size)
        loadingView.center = CGPoint(x: view.center.x + centerOffset.x, 
                                   y: view.center.y + centerOffset.y)
        loadingView.loopMode = .loop
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        
        // 添加到视图层级最上层
        view.addSubview(loadingView)
        
        // 设置约束
        loadingView.snp.makeConstraints {
            $0.centerX.equalToSuperview().offset(centerOffset.x)
            $0.centerY.equalToSuperview().offset(centerOffset.y)
            $0.width.height.equalTo(size)
        }
        
        // 开始播放动画
        loadingView.play()
        
        return loadingView
    }
    
    /// 移除加载动画
    /// - Parameter loadingView: 要移除的加载动画视图
    func hideLoadingAnimation(_ loadingView: LottieAnimationView?) {
        loadingView?.stop()
        loadingView?.removeFromSuperview()
    }
}

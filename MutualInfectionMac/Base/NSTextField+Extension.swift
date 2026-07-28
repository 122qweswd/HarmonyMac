//
//  NSTextField+Extension.swift
//  MutualInfectionMac
//
//  Created by Niko on 2025/11/8.
//

import Foundation
import Cocoa

private var dotAnimationTimerKey: UInt8 = 0
extension NSTextField {
    
    /// 开始点动画效果
    /// - Parameters:
    ///   - baseText: 基础文本
    ///   - interval: 动画间隔时间，默认0.5秒
    func startDotAnimation(baseText: String = "正在连接对方热点", interval: TimeInterval = 0.5) {
        stopDotAnimation()
        
        var dotCount = 0
        let maxDots = 3
        
        // 使用关联对象存储定时器
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            dotCount = (dotCount + 1) % (maxDots + 1)
            let dots = String(repeating: ".", count: dotCount)
            self.stringValue = baseText + dots
        }
        
        // 存储定时器引用
        objc_setAssociatedObject(self, &dotAnimationTimerKey, timer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // 立即显示初始状态
        self.stringValue = baseText
    }
    
    /// 停止点动画
    func stopDotAnimation() {
        if let timer = objc_getAssociatedObject(self, &dotAnimationTimerKey) as? Timer {
            timer.invalidate()
            objc_setAssociatedObject(self, &dotAnimationTimerKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    /// 检查是否正在播放点动画
    var isDotAnimationActive: Bool {
        return objc_getAssociatedObject(self, &dotAnimationTimerKey) as? Timer != nil
    }
}

//
//  MICustomScroller.swift
//  MutualInfection
//
//  Created by apple on 2025/11/14.
//

import Cocoa

class MICustomScroller: NSScroller {
    
    // 自定义颜色属性
    var knobColor: NSColor = .gray
    var trackColor: NSColor = .clear
    
    override func draw(_ dirtyRect: NSRect) {
        // 绘制轨道背景
        drawTrack()
        
        // 绘制滑块（如果可见）
        if !rect(for: .knob).isEmpty {
            drawKnob()
        }
    }
    
    private func drawTrack() {
        // 填充轨道背景
        trackColor.setFill()
        let trackRect = self.bounds
        NSBezierPath(rect: trackRect).fill()
    }
    
    override func drawKnob() {
        let knobRect = rect(for: .knob)
        let width = knobRect.size.width
        var margin = 0.0
        if width > 8 {
            margin = 0.5 * (width - 8)
        }
        let height = knobRect.size.height
        // 创建圆角滑块
        let knobPath = NSBezierPath(roundedRect: CGRectMake(knobRect.origin.x + margin, knobRect.origin.y, width - margin * 2, height), xRadius: 5, yRadius: 5)
        
        // 填充滑块颜色
        knobColor.setFill()
        knobPath.fill()
    }
}

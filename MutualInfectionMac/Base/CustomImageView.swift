//
//  CustomImageView.swift
//  MutualInfection
//
//  Created by 1234 on 2025/9/19.
//
//用户头像

import AppKit

/// 带默认配置的圆形图片视图
class CustomImageView: NSImageView {
    init(nsImage: NSImage? = nil, imageName: String? = nil, size: NSSize) {
        super.init(frame: NSRect(origin: .zero, size: size))
        
        // 配置默认属性
        self.imageScaling = .scaleProportionallyUpOrDown
        self.wantsLayer = true
        self.layer?.cornerRadius = bounds.width / 2
        self.layer?.masksToBounds = true
        self.translatesAutoresizingMaskIntoConstraints = false
        
        if (nsImage != nil){
            self.image = nsImage
        }else if (imageName != nil){
            self.image = NSImage(named: imageName!)
        }else{
            self.image = NSImage(named: "icon_device") // 备用图标
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

//
//  Config.swift
//  MutualInfectionApp
//
//  Created by mac on 2025/9/2.
//

import Foundation
import UIKit

public let ksUIScreen = UIScreen.main.bounds
public let ksUIScreenW = UIScreen.main.bounds.width
public let ksUIScreenH = UIScreen.main.bounds.height


// MARK: 闭包
typealias ClickBlockVoid = ()->()
// MARK: 判断是否有选择的设备
//public var deviceudidCheck: [String] = []

// MARK: 落盘文件同名添加后缀数字
public let fileSameNameSuffix = 1
public let fileSameNameInterval = 1

// MARK: 落盘文件夹名称
public let fileRootDirectoryName = "鸿蒙星河互联"

let  deviceNameKey = "deviceName_key"
let userAvatarKey = "userAvatar_key"
let  use_agree = "useagree_Key"
let cancelUseSend = "cancelSend_key"
var AppleLoginHandlerValue = false


func pingFangSC(_ size: CGFloat, weight :UIFont.Weight = .regular) -> UIFont { pingFangSC(weight: weight, size: size) }

func pingFangSC( weight :UIFont.Weight = .medium,size:CGFloat = 16) -> UIFont {
    
    let deviceType = UIDevice.current.userInterfaceIdiom
    var adjustedSize = size

    // 如果是iPad，字体大小可以适当调整
    if deviceType == .pad {
        // iPad上字体可以稍微大一些，或者保持不变
        adjustedSize = size * 1  // 可选：iPad上字体放大10%
    }
    if weight == .medium {
        return UIFont(name: "PingFangSC-Medium", size: adjustedSize) ?? UIFont()
    }else if weight == .light {
        return UIFont(name: "PingFangSC-Light", size: adjustedSize) ?? UIFont()
    }
    else if weight == .regular {
        return UIFont(name: "PingFangSC-Regular", size: adjustedSize) ?? UIFont()
    }
    else if weight == .semibold {
        return UIFont(name: "PingFangSC-Semibold", size: adjustedSize) ?? UIFont()
    }
    else if weight == .ultraLight {
        return UIFont(name: "PingFangSC-Ultralight", size: adjustedSize) ?? UIFont()
    }
    else if weight == .thin {
        return UIFont(name: "PingFangSC-Thin", size: adjustedSize) ?? UIFont()
    }else{
        return UIFont(name: "PingFangSC-Medium", size: adjustedSize) ?? UIFont()
    }
}

func SFCompact( weight :UIFont.Weight = .medium,size:CGFloat = 16) -> UIFont {
    
    let deviceType = UIDevice.current.userInterfaceIdiom
    var adjustedSize = size

    // 如果是iPad，字体大小可以适当调整
    if deviceType == .pad {
        // iPad上字体可以稍微大一些，或者保持不变
        adjustedSize = size * 1  // 可选：iPad上字体放大10%
    }
    return UIFont.systemFont(ofSize: adjustedSize, weight: weight)
}

/// 屏幕尺寸
func phoneToPad(_ value: CGFloat) -> CGFloat {
    let deviceType = UIDevice.current.userInterfaceIdiom
    if deviceType == .pad {
        return value * 1.5
    }
    return value
}
func phoneToPad(_ value: Int) -> CGFloat {
    let deviceType = UIDevice.current.userInterfaceIdiom
    if deviceType == .pad {
        return CGFloat(value) * 1.5
    }
    return CGFloat(value)
}

/// 阴影添加
func configShadow(views: [UIView?], shadowRadius: Float) {
    for view in views {
        view?.layer.shadowColor = "#000000".color.withAlpha(0.4).cgColor
        view?.layer.shadowOffset = CGSize(width: 0, height: 1)
        view?.layer.shadowOpacity = 1
        view?.layer.shadowRadius = CGFloat(shadowRadius)
    }
}

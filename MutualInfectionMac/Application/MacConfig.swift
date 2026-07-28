//
//  MacConfig.swift
//  MutualInfectionMac
//
//  Created by apple on 2025/10/9.
//

import Foundation
import AppKit


import Cocoa

typealias ClickBlockVoid = ()->()

// MARK: 落盘文件同名添加后缀数字
public let fileSameNameSuffix = 1
public let fileSameNameInterval = 1

// MARK: 落盘文件夹名称
public let fileRootDirectoryName = "鸿蒙星河互联"

func getScreenSize() -> CGSize {
    if let screen = NSScreen.main {
        let frame = screen.frame
        return CGSize(width: frame.width, height: frame.height)
    }
    return CGSize(width: 0, height: 0)
}
//func getScreenSize() -> CGSize {
//    let mouseLocation = NSEvent.mouseLocation
//    
//    print("查找鼠标所在屏幕:")
//    print("  鼠标位置: \(mouseLocation)")
//    
//    // 方法A：精确查找鼠标所在屏幕
//    for screen in NSScreen.screens {
//        let screenFrame = screen.frame
//        print("  检查屏幕 \(screen.localizedName): frame=\(screenFrame)")
//        
//        if screenFrame.contains(mouseLocation) {
//            print("  找到鼠标所在屏幕: \(screen.localizedName)")
//            print("  屏幕frame: \(screenFrame)")
//            print("  屏幕visibleFrame: \(screen.visibleFrame)")
//            return CGSize(width: screenFrame.width, height: screenFrame.height)
//        }
//    }
//    
//    // 方法B：如果没有找到，使用主窗口所在屏幕
//    print("未找到鼠标所在屏幕，尝试主窗口...")
//    if let upWindow = NSApp.mainWindow,
//       let windowScreen = upWindow.screen {
//        print("  使用主窗口屏幕: \(windowScreen.frame)")
//        return CGSize(width: windowScreen.frame.width, height: windowScreen.frame.height)
//    }
//    
//    // 方法C：最后使用主屏幕
//    if let mainScreen = NSScreen.main {
//        print("  使用主屏幕: \(mainScreen.frame)")
//        return CGSize(width: mainScreen.frame.width, height: mainScreen.frame.height)
//    }
//    
//    print("  未找到任何屏幕，使用默认尺寸")
//    return CGSize(width: 1440, height: 900)
//}


let screenWidth = getScreenSize().width*0.5
let screenHeight = getScreenSize().height*0.5

let windowWidth: CGFloat = 403
let windowHeight: CGFloat = 98
let bundleId = Bundle.main.bundleIdentifier ?? ""

//应用名称
let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Unknown"
//版本号
let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
//构建版本号
let appBuildVersion = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String ?? "Unknown"
let appID =  "6470910866"

func showSheetAlert(messageText : String, message: String, alertStyle: NSAlert.Style = .informational, window: NSWindow? = nil,confirmTitle: String = "确定".localized, completion: (() -> Void)? = nil) {
    guard let targetWindow = window ?? NSApp.mainWindow else { return }
    let alert = NSAlert()
    alert.messageText = messageText
    alert.informativeText = message
    alert.alertStyle = alertStyle
    alert.addButton(withTitle: confirmTitle)
    alert.beginSheetModal(for: targetWindow) { _ in
        completion?()
    }
}
// 显示提示弹窗
func showSheetAlert(message: String,in window: NSWindow? = nil,completion: (() -> Void)? = nil) {
    guard let targetWindow = window ?? NSApp.mainWindow else { return }
    let alert = NSAlert()
    alert.messageText = "提示".localized
    alert.informativeText = message
    alert.alertStyle = .informational
    alert.addButton(withTitle: "确定".localized)
    alert.beginSheetModal(for: targetWindow) { _ in
        completion?()
    }
}

func showSheetAlert(
    messageText: String = "提示",
    message: String,
    in window: NSWindow? = nil,
    confirmTitle: String = "确定",
    cancelTitle: String = "取消",
    confirmCompletion: (() -> Void)? = nil,
    cancelCompletion: (() -> Void)? = nil
) {
    guard let targetWindow = window ?? NSApp.mainWindow else { return }
    
    let alert = NSAlert()
    alert.messageText = messageText
    alert.informativeText = message
    alert.alertStyle = .informational
    
    // 添加按钮 - 注意顺序：第一个按钮是默认按钮，第二个是取消按钮
    alert.addButton(withTitle: confirmTitle)
    alert.addButton(withTitle: cancelTitle)
    
    alert.beginSheetModal(for: targetWindow) { response in
        switch response {
        case .alertFirstButtonReturn: // 第一个按钮（确定）
            confirmCompletion?()
        case .alertSecondButtonReturn: // 第二个按钮（取消）
            cancelCompletion?()
        default:
            break
        }
    }
}



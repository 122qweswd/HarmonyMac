//
//  Config.swift
//  MutualInfectionApp
//
//  Created by Niko on 2025/8/31.
//  全局的属性和方法，为更好的一眼进行区分，所以添加项目前缀

import Foundation
import UIKit
import SystemConfiguration.CaptiveNetwork
import MobileCoreServices
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

/// 获取KeyWindow
var MIKeyWindow: UIWindow? {
    // 首先，尝试获取所有已连接场景中的前台活动场景
    let foregroundActiveScenes = UIApplication.shared.connectedScenes
        .filter { $0.activationState == .foregroundActive }
    
    // 遍历所有活动场景，寻找 keyWindow
    for scene in foregroundActiveScenes {
        guard let windowScene = scene as? UIWindowScene else { continue }
        
        // 在 iOS 15+ 中，使用 windowScene 的 keyWindow 属性
        if #available(iOS 15.0, *) {
            if let keyWindow = windowScene.keyWindow {
                return keyWindow
            }
        } else {
            // 在 iOS 13-14 中，手动遍历查找 keyWindow
            if let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
                return keyWindow
            }
        }
        
        // 如果没有找到 keyWindow，但场景中有窗口，返回第一个窗口（降级方案）
        if let firstWindow = windowScene.windows.first {
            return firstWindow
        }
    }
    
    // 传统方案：作为无法找到场景时的备选方案
    if #available(iOS 13.0, *) {
        return UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first
    } else {
        // iOS 12 及以下版本
        return UIApplication.shared.keyWindow
    }
}

/// 获取安全区域
private var safeAreaInset: UIEdgeInsets {
    if #available(iOS 11.0, *) {
        // 安全地获取 keyWindow 并返回其 safeAreaInsets
        return MIKeyWindow?.safeAreaInsets ?? UIEdgeInsets.zero
    } else {
        // iOS 11.0 之前的版本返回零边距
        return UIEdgeInsets.zero
    }
}

/// 顶部安全区域
var MISafeAreaTop: CGFloat { safeAreaInset.top }

/// 底部安全区域
var MISafeAreaBottom: CGFloat { safeAreaInset.bottom }

/// 多语言设置
func MILocalized(_ key: String) -> String {
    return key.localized
}

/// 获取当前应用的最顶层视图控制器
/// - Returns: 最顶层的 UIViewController，如果获取失败则返回 nil
func MIGetTopViewController() -> UIViewController? {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let rootViewController = windowScene.windows.first?.rootViewController else {
        return nil
    }
    return MIFindTopViewController(from: rootViewController)
}

/// 递归查找最顶层的视图控制器
/// - Parameter viewController: 起始视图控制器
/// - Returns: 最顶层的视图控制器
func MIFindTopViewController(from viewController: UIViewController) -> UIViewController {
    if let presentedVC = viewController.presentedViewController {
        return MIFindTopViewController(from: presentedVC)
    } else if let navVC = viewController as? UINavigationController, let topVC = navVC.topViewController {
        return MIFindTopViewController(from: topVC)
    } else if let tabVC = viewController as? UITabBarController, let selectedVC = tabVC.selectedViewController {
        return MIFindTopViewController(from: selectedVC)
    }
    return viewController
}



/// 获取当前应用的最顶层导航视图控制器
/// - Returns: 最顶层的 UIViewController，如果获取失败则返回 nil
func MIGetTopNavViewController() -> UIViewController? {
//    var topController: UIViewController?
//    if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
//        topController = window.rootViewController
//    } else if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
//              let window = scene.windows.first {
//        topController = window.rootViewController
//    }
    
    let topController = MIKeyWindow?.rootViewController
    guard var topController = topController else {
        return nil
    }
    
    // 排除系统弹窗（如UIAlertController）
    while let presented = topController.presentedViewController,
          AlertManager.checkControllerIsAlertViewController(presented) == false {
        topController = presented
    }
    
    switch topController {
    case let nav as UINavigationController:
        return nav.viewControllers.last
    case let tab as UITabBarController:
        return tab.selectedViewController
    default:
        return topController
    }
}

func MIGetTopNavViewController02() -> UIViewController? {
    var topController: UIViewController?
    if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
        topController = window.rootViewController
    } else if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first {
        topController = window.rootViewController
    }
    
    guard let topController = topController else {
        return nil
    }
    
    return MIFindTopViewController(from: topController)
    
//    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
//          let rootViewController = windowScene.windows.first?.rootViewController else {
//        return nil
//    }
//    return MIFindTopNavViewController(from: rootViewController)
}

/// 递归查找最顶层的导航视图控制器
/// - Parameter viewController: 起始视图控制器
/// - Returns: 最顶层的视图控制器
func MIFindTopNavViewController(from viewController: UIViewController) -> UIViewController {
    if let presentedVC = viewController.presentedViewController {
        return MIFindTopNavViewController(from: presentedVC)
    } else if let navVC = viewController as? UINavigationController, let topVC = navVC.topViewController {
        return MIFindTopNavViewController(from: topVC)
    } else if let tabVC = viewController as? UITabBarController, let selectedVC = tabVC.selectedViewController {
        return MIFindTopNavViewController(from: selectedVC)
    }else if let presentingVC = viewController.presentingViewController as? UINavigationController, let selectedVC = presentingVC.topViewController {
        return selectedVC
    }
    
    return viewController
}




 //应用名称
let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Unknown"

//版本号
let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"

//构建版本号
let appBuildVersion = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String ?? "Unknown"

let appID =  "6470910866"
let bundleId = Bundle.main.bundleIdentifier ?? ""

 

func getUsedSSID() -> (String,String) {

    let interfaces = CNCopySupportedInterfaces()

    var ssid = ""

    var bssid = ""
    if interfaces != nil {

        guard let interfacesArray = (CFBridgingRetain(interfaces) as? [ CFString]) else{
            return (ssid,bssid)
        }


        if interfacesArray.count > 0 {

            let interfaceName = interfacesArray[0]

            let ussafeInterfaceData = CNCopyCurrentNetworkInfo(interfaceName)

            if (ussafeInterfaceData != nil) {

                let interfaceData = ussafeInterfaceData as? [String : Any]


                ssid = (interfaceData?["SSID"] as? String) ?? ""

                bssid = (interfaceData?["BSSID"] as? String) ?? ""

            }

        }

    }

    return (ssid,bssid)
}


func dictionaryToJSON(_ dictionary: [String: Any]) -> String {
    if let jsonData = try? JSONSerialization.data(withJSONObject: dictionary, options: .prettyPrinted) {
        return String(data: jsonData, encoding: .utf8) ?? ""
    }
    return ""
}


func isMediaFile(at url: URL) -> Bool {
    if #available(iOS 14.0, *) {
        let typeIdentifier = UTType(filenameExtension: url.pathExtension)?.identifier ?? "public.data"
        
        let conformsToImage = UTTypeConformsTo(typeIdentifier as CFString, kUTTypeImage)
        let conformsToMovie = UTTypeConformsTo(typeIdentifier as CFString, kUTTypeMovie)
        let conformsToAudio = UTTypeConformsTo(typeIdentifier as CFString, kUTTypeAudio)
        let conformsToLivePhoto  = UTTypeConformsTo(typeIdentifier as CFString, kUTTypeLivePhoto)
        return conformsToImage || conformsToMovie || conformsToAudio || conformsToLivePhoto
    } else {
        
        
        let fileExtension = url.pathExtension
        if let fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension as CFString, nil)?.takeRetainedValue(){
            
            
//            if let declaringBundleURL = UTTypeCopyDeclaringBundleURL(fileUTI) {
               
                // 检查 URL 是否指向已知的媒体处理应用
                let knownMediaApps = ["com.apple.mobileslideshow", "com.apple.MobileMusic", "com.apple.Photos"] // 示例列表，可以根据需要添加更多
               // let appIdentifier = declaringBundleURL as String
            return knownMediaApps.contains(fileUTI as String)
//            }
            //return false
        }
        
        return false
        // Fallback on earlier versions
    }
}



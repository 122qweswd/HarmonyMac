//
//  MIWiFiManager.swift
//  MutualInfectionApp
//
//  Created by ww on 2025/9/23.
//

import UIKit
import Foundation
import Network
import SystemConfiguration.CaptiveNetwork
import CoreTelephony

// 无线数据权限状态枚举
enum MIWiFiDataPermission {
    case disabled        // 无线数据已关闭
    case wifiOnly        // 仅无线局域网
    case wifiAndCellular // 无线局域网与蜂窝数据
    case unknown         // 未知状态
}

class MIWiFiManager: NSObject {
    var manger : ShareAPI?
    private var currentAlert: UIViewController?
    var showWiFi = false
    var sucess: (() -> ())?
    var fail: (() -> ())?
    static let shared = MIWiFiManager()
    private let networkMonitor = NWPathMonitor()
    
    func getWiFiDataPermission(sucess: @escaping (() -> ()), fail: @escaping (() -> ())) {
        self.sucess = sucess
        self.sucess?()
        /**
        manger = ShareAPI.shared()
        self.manger?.log(1, "getWiFiDataPermission In")
        self.fail = fail
        self.checkWiFiDataPermission()
         */
    }
    
    private func checkWiFiDataPermission() {
        DispatchQueue.main.async {
            self.manger?.log(1, "checkWiFiDataPermission In")
            let permission = self.checkWiFiDataPermissionStatus()
            self.handlePermissionResult(permission)
        }
    }
    
    private func checkWiFiDataPermissionStatus() -> MIWiFiDataPermission {
        // 检查无线数据权限状态
        if #available(iOS 14.0, *) {
            self.manger?.log(1, "checkWiFiDataPermissionModern In")
            return checkWiFiDataPermissionModern()
        } else {
            self.manger?.log(1, "checkWiFiDataPermissionLegacy In")
            return checkWiFiDataPermissionLegacy()
        }
    }
    
    @available(iOS 14.0, *)
    private func checkWiFiDataPermissionModern() -> MIWiFiDataPermission {
        // iOS 14+ 使用Network框架检查
        let monitor = NWPathMonitor()
        var result: MIWiFiDataPermission = .unknown
        
        let semaphore = DispatchSemaphore(value: 0)
        
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                if path.usesInterfaceType(.wifi) && path.usesInterfaceType(.cellular) {
                    result = .wifiAndCellular
                    print("wifi权限 result:\(result)")
                    self.manger?.log(1, "wifi权限 result:\(result)")
                } else if path.usesInterfaceType(.wifi) {
                    result = .wifiOnly
                    print("wifi权限 result:\(result)")
                    self.manger?.log(1, "wifi权限 result:\(result)")
                } else if path.usesInterfaceType(.cellular) {
                    result = .wifiAndCellular // 有蜂窝数据，说明权限开启
                    print("wifi权限 result:\(result)")
                    self.manger?.log(1, "wifi权限 result:\(result)")
                }
            } else {
                result = .disabled
                print("wifi权限 result:\(result)")
                self.manger?.log(1, "wifi权限 result:\(result)")
            }
            semaphore.signal()
        }
        
        monitor.start(queue: DispatchQueue.global())
        _ = semaphore.wait(timeout: .now() + 2.0)
        monitor.cancel()
        
        return result
    }
    
    private func checkWiFiDataPermissionLegacy() -> MIWiFiDataPermission {
        // iOS 14以下版本检查方法
        let reachability = SCNetworkReachabilityCreateWithName(nil, "www.apple.com")
        var flags: SCNetworkReachabilityFlags = []
        
        guard let reachability = reachability,
              SCNetworkReachabilityGetFlags(reachability, &flags) else {
            return .unknown
        }
        
        let isReachable = flags.contains(.reachable)
        let isWWAN = flags.contains(.isWWAN)
        
        if isReachable {
            if isWWAN {
                return .wifiAndCellular
            } else {
                return .wifiOnly
            }
        } else {
            return .disabled
        }
    }
    
    private func handlePermissionResult(_ permission: MIWiFiDataPermission) {
        self.manger?.log(1, "WIFI权限状态: \(permission)")
        switch permission {
        case .disabled:
            self.manger?.log(1, "WIFI权限状态: disabled")
            showWiFiDataDisabledAlert()
        case .wifiOnly,.wifiAndCellular:
            self.manger?.log(1, "WIFI权限状态: wifiOnly wifiAndCellular")
            self.currentAlert?.dismiss(animated: true, completion: nil)
            self.sucess?()
        case .unknown:
            self.manger?.log(1, "WIFI权限状态: unknown")
            showWiFiDataDisabledAlert()
        }
    }
    private func showWiFiDataDisabledAlert() {
        if !showWiFi{
            self.manger?.log(1, "showWiFiDataDisabledAlert start")
            currentAlert =  AlertManager.showAlert(
                title: "WIFI权限未打开".localized,
                message: "没有获得WIFI权限，请在设置中打开WIFI权限".localized,
                autoDismiss: true,
                cancelTitle: nil,
                confirmTitle: "去设置".localized,
                confirmAction: {
                    self.openWiFiDataSettings()
                    self.fail?()
                    self.showWiFi = false
                }
            )
            showWiFi = true
        }
    }
    
    private func openWiFiDataSettings() {
        // 跳转到APP的无线数据设置页面
        if let url = URL(string: UIApplication.openSettingsURLString + "App-Prefs:root=APP") {
            UIApplication.shared.open(url)
        }
    }
   
    deinit {
        networkMonitor.cancel()
    }
}

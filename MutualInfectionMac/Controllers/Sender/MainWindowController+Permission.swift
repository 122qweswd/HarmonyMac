//
//  MainWindowController+Permission.swift
//  MutualInfectionMac
//
//  Created by apple on 2025/11/3.
//

import Foundation
import AppKit
import Network
extension MainWindowController {
    
    func checkAndHandleBluetoothPermission() -> Bool {
//        guard #available(macOS 10.15, *) else {
//            // 旧版本系统，假设有权限
//            return true
//        }
        
        let status = CBManager.authorization
        switch status {
        case .allowedAlways:
            return true
        case .denied, .restricted:
            // 显示提示并打开设置
            showBluetoothPermissionAlert()
            return false
        case .notDetermined:
            // 还未决定，可以在这里初始化 CBCentralManager 来触发系统权限弹窗
            return false
        @unknown default:
            return false
        }
    }

    private func showBluetoothPermissionAlert() {
        
        let panel = MICustomPanel(
            title: "蓝牙权限被拒绝\n请在系统设置的\"隐私与安全性\"中启用蓝牙权限".localized,
            confirmButtonTitle: "打开设置".localized,
            cancelButtonTitle: "稍后".localized
        )
        
        panel.showModal(in: self.view.window ?? NSWindow(),
                        confirmHandler: {
            self.manger?.log(1, "打开蓝牙设置")
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth")!)
            
            })
    }
    
    
}

//class MILocalNetworkPermissionManager {
//    
//    // MARK: - 单例
//    static let shared = MILocalNetworkPermissionManager()
//    private init() {}
//    
//    // MARK: - 权限状态
//    private var _hasPermission: Bool = false
//    private var lastCheckTime: Date?
//    private let minCheckInterval: TimeInterval = 2.0 // 最小检查间隔
//    
//    // 当前权限状态
//    var hasPermission: Bool {
//        return _hasPermission
//    }
//    
//    // MARK: - 公共接口
//    
//    /// 同步检查权限状态
//    func checkPermission() -> Bool {
//        // 防止过于频繁的检查
//        if let lastCheck = lastCheckTime,
//           Date().timeIntervalSince(lastCheck) < minCheckInterval {
//            return _hasPermission
//        }
//        
//        return _hasPermission
//    }
//    
//    /// 异步检测权限状态（触发实际检测）
//    func detectPermission(completion: ((Bool) -> Void)? = nil) {
//        // 清理之前的检测
//        cleanup()
//        
//        let parameters = NWParameters()
//        parameters.includePeerToPeer = true
//        
//        // 使用常见的 Bonjour 服务类型
//        let descriptor = NWBrowser.Descriptor.bonjour(type: "_http._tcp", domain: "local.")
//        let browser = NWBrowser(for: descriptor, using: parameters)
//        
//        var hasFoundService = false
//        let startTime = Date()
//        
//        // 设置超时
//        let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
//            if !hasFoundService {
//                print("权限检测超时，未发现服务")
//                self.handleDetectionResult(success: false, completion: completion)
//            }
//        }
//        
//        // 状态处理器
//        browser.stateUpdateHandler = { state in
//            switch state {
//            case .ready:
//                print("浏览器就绪")
//            case .failed(let error):
//                print("浏览器失败: \(error)")
//                if !hasFoundService {
//                    self.handleDetectionResult(success: false, completion: completion)
//                }
//            default:
//                break
//            }
//        }
//        
//        // 结果处理器
//        browser.browseResultsChangedHandler = { results, changes in
//            if !results.isEmpty && !hasFoundService {
//                hasFoundService = true
//                let elapsedTime = Date().timeIntervalSince(startTime)
//                print("发现服务，权限已授予 (耗时: \(String(format: "%.2f", elapsedTime))s)")
//                
//                timeoutTimer.invalidate()
//                browser.cancel()
//                self.handleDetectionResult(success: true, completion: completion)
//            }
//        }
//        
//        // 开始浏览
//        browser.start(queue: .main)
//        
//        // 保存引用
//        objc_setAssociatedObject(self, "currentBrowser", browser, .OBJC_ASSOCIATION_RETAIN)
//        objc_setAssociatedObject(self, "currentTimer", timeoutTimer, .OBJC_ASSOCIATION_RETAIN)
//    }
//    
//    /// 请求权限（触发系统弹窗）
//    func requestPermission() {
//        let parameters = NWParameters()
//        parameters.includePeerToPeer = true
//        
//        let descriptor = NWBrowser.Descriptor.bonjour(type: "_http._tcp", domain: "local.")
//        let browser = NWBrowser(for: descriptor, using: parameters)
//        
//        browser.stateUpdateHandler = { state in
//            switch state {
//            case .ready:
//                print("权限请求: 浏览器就绪")
//            case .failed(let error):
//                print("权限请求: 失败 - \(error)")
//            default:
//                break
//            }
//        }
//        
//        browser.start(queue: .main)
//        
//        // 3秒后自动清理
//        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
//            browser.cancel()
//        }
//    }
//    
//    // MARK: - 用户提示
//    
//    /// 显示权限不足提示
//    func showPermissionAlert() {
//        #if os(macOS)
//        let alert = NSAlert()
//        alert.messageText = "需要本地网络权限"
//        alert.informativeText = "此操作需要访问本地网络以发现设备。请授予本地网络权限后重试。"
//        alert.addButton(withTitle: "请求权限")
//        alert.addButton(withTitle: "取消")
//        
//        let response = alert.runModal()
//        
//        if response == .alertFirstButtonReturn {
//            self.requestPermission()
//        }
//        #endif
//    }
//    
//    /// 显示详细的权限引导
//    func showPermissionGuide() {
//        #if os(macOS)
//        let alert = NSAlert()
//        alert.messageText = "需要本地网络权限"
//        alert.informativeText = """
//        为了发现和连接本地网络中的设备，需要授予本地网络权限。
//        
//        请按以下步骤操作：
//        1. 打开「系统设置」
//        2. 进入「隐私与安全性」 
//        3. 选择「本地网络」
//        4. 找到此应用并开启权限
//        5. 返回应用继续使用
//        """
//        alert.addButton(withTitle: "打开系统设置")
//        alert.addButton(withTitle: "取消")
//        
//        if alert.runModal() == .alertFirstButtonReturn {
//            self.openSystemPrivacySettings()
//        }
//        #endif
//    }
//    
//    // MARK: - 私有方法
//    
//    private func handleDetectionResult(success: Bool, completion: ((Bool) -> Void)?) {
//        DispatchQueue.main.async {
//            self._hasPermission = success
//            self.lastCheckTime = Date()
//            completion?(success)
//            self.cleanup()
//        }
//    }
//    
//    private func cleanup() {
//        if let timer = objc_getAssociatedObject(self, "currentTimer") as? Timer {
//            timer.invalidate()
//            objc_setAssociatedObject(self, "currentTimer", nil, .OBJC_ASSOCIATION_RETAIN)
//        }
//        
//        if let browser = objc_getAssociatedObject(self, "currentBrowser") as? NWBrowser {
//            browser.cancel()
//            objc_setAssociatedObject(self, "currentBrowser", nil, .OBJC_ASSOCIATION_RETAIN)
//        }
//    }
//    
//    private func openSystemPrivacySettings() {
//        #if os(macOS)
//        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork") {
//            NSWorkspace.shared.open(url)
//        }
//        #endif
//    }
//    
//    deinit {
//        cleanup()
//    }
//}

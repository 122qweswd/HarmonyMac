//
//  MIBlueToothManager.swift
//  MutualInfectionApp
//
//  Created by ww on 2025/9/23.
//

import UIKit
import Foundation
import CoreBluetooth

class MIBluetoothManager: NSObject, CBCentralManagerDelegate {
    var manger : ShareAPI?
    var success: (() -> ())?
    var fail: (() -> ())?
    var showBlueTooth = false
    var showBlueToothLimit = false
    private var currentAlert: UIViewController?
    private var currentLimitAlert: UIViewController?
    static let shared = MIBluetoothManager()
    var centralManager: CBCentralManager!
    
    func getBluetoothStatus(success: @escaping (() -> ()), fail: @escaping (() -> ())) {
        manger = ShareAPI.shared()
        self.manger?.log(1, "getBluetoothStatus In")
        self.success = success
        self.fail = fail
        self.requestBluetoothAuthorization()
    }
    
    func requestBluetoothAuthorization() {
        DispatchQueue.main.async {
            self.manger?.log(1, "requestBluetoothAuthorization In")
            self.centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: false])
        }
    }
    
    // MARK: - CBCentralManagerDelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("蓝牙权限状态: \(central.state)")
        self.manger?.log(1, "蓝牙权限状态: \(central.state)")
        switch central.state {
        case .poweredOn:
            // 蓝牙已开启且可用
            self.manger?.log(1, "蓝牙权限状态: poweredOn")
            self.success?()
            self.currentAlert?.dismiss(animated: true, completion: nil)
            self.currentLimitAlert?.dismiss(animated: true, completion: nil)
        case .poweredOff:
            // 蓝牙已关闭  - TODO 权限打开但蓝牙关闭了，如何处理
            self.manger?.log(1, "蓝牙权限状态: poweredOff")
            showBlueToothDisabledAlert()
        case .unauthorized:
            self.manger?.log(1, "蓝牙权限状态: unauthorized")
            // 蓝牙权限被拒绝
            showBlueToothDataDisabledAlert()
            
        case .unsupported:
            self.manger?.log(1, "蓝牙权限状态: unsupported")
            // 设备不支持蓝牙
            DispatchQueue.main.async {
                // 显示toast提示
                if let topVC = MIGetTopViewController() {
                    topVC.view.pickerMakeToast("设备不支持蓝牙".localized, duration: 2.0, point: topVC.view.center, title: nil, image: nil) { didTap in
                        // toast被点击时的处理
                    }
                }
            }
            self.fail?()
            
        case .resetting:
            self.manger?.log(1, "蓝牙权限状态: resetting")
            // 蓝牙正在重置
            DispatchQueue.main.async {
                // 显示toast提示
                if let topVC = MIGetTopViewController(){
                    topVC.view.pickerMakeToast("蓝牙正在重置".localized, duration: 2.0, point: topVC.view.center, title: nil, image: nil) { didTap in
                        // toast被点击时的处理
                    }
                }
            }
            self.fail?()
            
        case .unknown:
            self.manger?.log(1, "蓝牙权限状态: unknown")
            // 蓝牙状态未知
            DispatchQueue.main.async {
                // 显示toast提示
                if let topVC = MIGetTopViewController() {
                    topVC.view.pickerMakeToast("蓝牙状态未知".localized, duration: 2.0, point: topVC.view.center, title: nil, image: nil) { didTap in
                        // toast被点击时的处理
                    }
                }
            }
            self.fail?()
            
            @unknown default: break
            // 处理未来可能的新状态
            //showBlueToothDataDisabledAlert()
        }
    }
    private func showBlueToothDataDisabledAlert() {
       self.manger?.log(1, "showBlueToothDataDisabledAlert start")
        if !showBlueToothLimit{
            currentLimitAlert =  AlertManager.showAlert(
                title: "蓝牙权限未打开".localized,
                message: "没有获得蓝牙权限，请在设置中打开蓝牙权限".localized,
                autoDismiss: true,
                cancelTitle: nil,
                confirmTitle: "去设置".localized,
                confirmAction: {
                    self.showBlueToothLimit = false
                    self.openBlueTothDataSettings()
                    self.fail?()
                }
            )
            showBlueToothLimit = true
        }
    }
    
    private func showBlueToothDisabledAlert() {
       self.manger?.log(1, "showBlueToothDisabledAlert start")
        if !showBlueTooth{
            currentAlert =  AlertManager.showAlert(
                title: "提示".localized,
                message: "蓝牙已关闭，可能会影响传输和接收，请在”设置“中允许新连接".localized,
                cancelTitle: nil,
                confirmTitle: "知道了".localized,
                confirmAction: {
                    self.showBlueTooth = false
                    self.fail?()
                }
            )
            showBlueTooth = true
        }
    }
    private func openBlueTothDataSettings() {
        // 跳转到APP的无线数据设置页面
        if let url = URL(string: UIApplication.openSettingsURLString + "App-Prefs:root=APP") {
            UIApplication.shared.open(url)
        }
    }
}


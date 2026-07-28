//
//  MIPhotoPermissionManager.swift
//  MutualInfectionApp
//
//  Created by Assistant on 2025/1/15.
//

import UIKit
import Foundation
import Photos

// 照片权限状态枚举
enum MIPhotoPermissionStatus {
    case denied        // 无权限
    case limited       // 受限访问
    case authorized    // 完全访问
    case unknown       // 未知状态
}

class MIPhotoPermissionManager: NSObject {
    var manger : ShareAPI?
    private var currentAlert: UIViewController?
    var showPhoto = false
    var sucess: (() -> ())?
    var fail: (() -> ())?
    static let shared = MIPhotoPermissionManager()
    
    func getPhotoPermissionStatus(isReceive:Bool,sucess: @escaping (() -> ()), fail: @escaping (() -> ())) {
        manger = ShareAPI.shared()
        self.manger?.log(1, "getPhotoPermissionStatus In")
        self.sucess = sucess
        self.fail = fail
        self.requestPhotoPermission(isReceive:isReceive)
    }
    
    private func requestPhotoPermission(isReceive:Bool) {
        self.manger?.log(1, "requestPhotoPermission In")
        // 检查当前权限状态
        let currentStatus = PHPhotoLibrary.authorizationStatus()
        
        if currentStatus == .notDetermined {
            // 权限未确定，直接请求权限（会弹出系统弹窗）
            PHPhotoLibrary.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    self?.manger?.log(1, "handleAuthorizationResult In")
                    self?.handleAuthorizationResult(status,isReceive:isReceive)
                }
            }
        } else {
            self.manger?.log(1, "handleAuthorizationResult In")
            // 权限已确定，直接处理结果
            handleAuthorizationResult(currentStatus,isReceive:isReceive)
        }
    }

    private func handleAuthorizationResult(_ status: PHAuthorizationStatus,isReceive:Bool) {
        self.manger?.log(1, "照片权限状态: \(status)")
        switch status {
        case .notDetermined:
            // 用户未做选择，继续等待
            self.manger?.log(1, "照片权限状态: notDetermined")
            break
        case .restricted, .denied:
            // 权限被拒绝或受限，显示提示并引导到设置
            self.manger?.log(1, "照片权限状态: restricted denied")
            showPhotoDataDisabledAlert(isReceive:isReceive)
        case .limited:
            self.manger?.log(1, "照片权限状态: limited")
            // 受限访问权限
            showPhotoDataDisabledAlert(isReceive:isReceive)
        case .authorized:
            // 完全访问权限
            self.manger?.log(1, "照片权限状态: authorized")
            self.currentAlert?.dismiss(animated: true, completion: nil)
            self.sucess?()
        @unknown default:
            self.manger?.log(1, "照片权限状态: default")
            showPhotoDataDisabledAlert(isReceive:isReceive)
        }
    }
    private func showPhotoDataDisabledAlert(isReceive:Bool) {
        if !showPhoto{
            self.manger?.log(1, "showPhotoDataDisabledAlert start")
            currentAlert =  AlertManager.showAlert(
                title: "照片权限未打开".localized,
                message: "没有获得照片访问权限，请在设置中允许访问照片".localized,
                autoDismiss: true,
                cancelTitle: isReceive == true ? nil :"取消".localized,
                cancelAction: {
                    self.sucess?()
                    self.showPhoto = false
                },
                confirmTitle: "去设置".localized,
                confirmAction: {
                    self.openPhotoDataSettings()
                    self.fail?()
                    self.showPhoto = false
                }
            )
            showPhoto = true
        }
    }
    
    private func openPhotoDataSettings() {
        // 跳转到APP的无线数据设置页面
        if let url = URL(string: UIApplication.openSettingsURLString + "App-Prefs:root=APP") {
            UIApplication.shared.open(url)
        }
    }
}

//
//  MIMacPhotoPermissionManager.swift
//  MutualInfection
//
//  Created by apple on 2025/11/4.
//

import AppKit
import Foundation
import Photos

// 照片权限状态枚举
enum MIPhotoPermissionStatus {
    case denied        // 无权限
    case limited       // 受限访问
    case authorized    // 完全访问
    case unknown       // 未知状态
}

class MIMacPhotoPermissionManager: NSObject {
    var manger : ShareAPI?
    var showPhoto = false
    var sucess: (() -> ())?
    var fail: (() -> ())?
    static let shared = MIMacPhotoPermissionManager()
    
    func getPhotoPermissionStatus(isReceive:Bool,sucess: @escaping (() -> ()), fail: @escaping (() -> ())) {
        manger = ShareAPI.shared()
        self.manger?.log(1, "getPhotoPermissionStatus In")
        self.sucess = sucess
        self.fail = fail
        self.requestPhotoPermission(isReceive:isReceive)
    }
    
    private func requestPhotoPermission(isReceive: Bool) {
        self.manger?.log(1, "requestPhotoPermission In")

        let currentStatus: PHAuthorizationStatus
        if #available(macOS 11.0, *) {
            currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        } else {
            currentStatus = PHPhotoLibrary.authorizationStatus()
        }
        
        switch currentStatus {
        case .notDetermined:
            // 未授权，发起系统授权弹窗请求
            if #available(macOS 11.0, *) {
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
                    self?.dispatchHandleAuthResult(status, isReceive: isReceive)
                }
            } else {
                PHPhotoLibrary.requestAuthorization { [weak self] status in
                    self?.dispatchHandleAuthResult(status, isReceive: isReceive)
                }
            }
            
        default:
            // 已授权/拒绝/受限，直接走结果处理
            dispatchHandleAuthResult(currentStatus, isReceive: isReceive)
        }
    }

    /// 统一调度权限结果到主线程并执行处理逻辑，抽离复用
    private func dispatchHandleAuthResult(_ status: PHAuthorizationStatus, isReceive: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.manger?.log(1, "handleAuthorizationResult In")
            self.handleAuthorizationResult(status, isReceive: isReceive)
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
            self.sucess?()
            self.sucess = nil
        @unknown default:
            self.manger?.log(1, "照片权限状态: default")
            showPhotoDataDisabledAlert(isReceive:isReceive)
        }
    }
    private func showPhotoDataDisabledAlert(isReceive:Bool) {
        if !showPhoto{
            self.manger?.log(1, "showPhotoDataDisabledAlert start")
            showSheetAlert(messageText: "照片权限未打开".localized, message: "没有获得照片访问权限，请在设置中允许访问照片".localized, confirmTitle: "去设置".localized, cancelTitle: "取消".localized, confirmCompletion: {
                self.openPhotosSettings()
                self.fail?()
                self.fail = nil
                self.showPhoto = false
            }, cancelCompletion: {
                self.sucess?()
                self.sucess = nil
                self.showPhoto = false
            })
            showPhoto = true
        }
    }
    
    private func openPhotosSettings(){
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos") {
            NSWorkspace.shared.open(url)
        }
    }
}

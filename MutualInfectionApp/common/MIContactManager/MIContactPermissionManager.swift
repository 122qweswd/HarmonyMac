//
//  MIContactPermissionManager.swift
//  MutualInfectionApp
//
//  Created by Assistant on 2025/1/15.
//

import UIKit
import Foundation
import Contacts

// 通讯录权限状态枚举
enum MIContactPermissionStatus {
    case denied        // 无权限
    case authorized    // 完全访问
    case unknown       // 未知状态
}

class MIContactPermissionManager: NSObject {
    var manger : ShareAPI?
    private var currentAlert: UIViewController?
    var showContact = false
    var sucess: (() -> ())?
    var fail: (() -> ())?
    static let shared = MIContactPermissionManager()
    
    func getContactPermissionStatus(isReceive:Bool,sucess: @escaping (() -> ()), fail: @escaping (() -> ())) {
        manger = ShareAPI.shared()
        self.manger?.log(1, "getContactPermissionStatus In")
        self.sucess = sucess
        self.fail = fail
        self.requestContactPermission(isReceive:isReceive)
    }
    
    private func requestContactPermission(isReceive:Bool) {
        self.manger?.log(1, "requestContactPermission In")
        // 检查当前权限状态
        let currentStatus = CNContactStore.authorizationStatus(for: .contacts)
        
        if currentStatus == .notDetermined {
            // 权限未确定，直接请求权限（会弹出系统弹窗）
            let contactStore = CNContactStore()
            contactStore.requestAccess(for: .contacts) { [weak self] granted, error in
                DispatchQueue.main.async {
                    if granted {
                        self?.manger?.log(1, "sucess In")
                        self?.currentAlert?.dismiss(animated: true, completion: nil)
                        self?.sucess?()
                    } else {
                        self?.manger?.log(1, "showContactDataDisabledAlert In")
                        self?.showContactDataDisabledAlert(isReceive:isReceive)
                    }
                }
            }
        } else {
            self.manger?.log(1, "handleAuthorizationResult In")
            // 权限已确定，直接处理结果
            handleAuthorizationResult(isReceive:isReceive,currentStatus)
        }
    }
    
    private func handleAuthorizationResult(isReceive:Bool,_ status: CNAuthorizationStatus) {
        self.manger?.log(1, "通讯录权限状态: \(status)")
        switch status {
        case .notDetermined:
            // 用户未做选择，继续等待
            self.manger?.log(1, "通讯录权限状态: notDetermined")
            break
        case .restricted, .denied:
            self.manger?.log(1, "通讯录权限状态: restricted denied")
            // 权限被拒绝或受限，显示提示并引导到设置
            showContactDataDisabledAlert(isReceive:isReceive)
        case .authorized:
            self.manger?.log(1, "通讯录权限状态: authorized")
            // 完全访问权限
            self.currentAlert?.dismiss(animated: true, completion: nil)
            self.sucess?()
        case .limited:
            self.manger?.log(1, "通讯录权限状态: limited")
            // 完全访问权限
            self.currentAlert?.dismiss(animated: true, completion: nil)
            self.sucess?()
        @unknown default:
            self.manger?.log(1, "通讯录权限状态: default")
            showContactDataDisabledAlert(isReceive:isReceive)
        }
    }
    
    private func showContactDataDisabledAlert(isReceive:Bool) {
        if !showContact{
            self.manger?.log(1, "showContactDataDisabledAlert start")
            currentAlert =  AlertManager.showAlert(
                title: "通讯录权限未打开".localized,
                message: "没有获得通讯录访问权限，请在设置中允许访问通讯录".localized,
                autoDismiss: true,
                cancelTitle: isReceive == true ? nil :"取消".localized,
                cancelAction: {
                    self.sucess?()
                    self.showContact = false
                },
                confirmTitle: "去设置".localized,
                confirmAction: {
                    self.openContactDataSettings()
                    self.fail?()
                    self.showContact = false
                }
            )
            showContact = true
        }
    }
    
    private func openContactDataSettings() {
        // 跳转到APP的通讯录权限设置页面
        if let url = URL(string: UIApplication.openSettingsURLString + "App-Prefs:root=APP") {
            UIApplication.shared.open(url)
        }
    }
}

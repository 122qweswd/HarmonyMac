//
//  MIHostspotPermissionManager.swift
//  MutualInfectionApp
//
//  个人热点打开检查
//

import UIKit

class MIHostspotPermissionManager: NSObject {
    var manger : ShareAPI?
    private var currentAlert: UIViewController?
    static let shared = MIHostspotPermissionManager()
    
    func isOpen(isReceive:Bool) -> Bool {
        manger = ShareAPI.shared()
        let enabled = MIHotspotDetector.shared().isPersonalHotspotEnabled()
        self.manger?.log(1, "[UI] [MIHostspotPermissionManager] isOpen 热点 enabled: \(enabled)")
        if enabled {
            showAlert(isReceive: isReceive)
        }
        return enabled
    }

    private func showAlert(isReceive:Bool) {
        currentAlert =  AlertManager.showAlert(
            message: isReceive ? "接收失败，请关闭热点后再试".localized : "请关闭热点后再传输".localized,
            cancelTitle: nil,
            confirmTitle: "我知道了".localized,
            confirmAction: {
                self.currentAlert?.dismiss(animated: true)
            }
        )
    }
}

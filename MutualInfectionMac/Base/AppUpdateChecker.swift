//
//  AppUpdateChecker.swift
//  MutualInfectionMac
//
//  Created by delegate on 2025/9/30.
//

import Foundation
import Cocoa
import Foundation

class AppUpdateChecker {
    // 替换为你的应用在App Store上的Apple ID
    // 可以在App Store链接中找到，例如：https://apps.apple.com/cn/app/id1234567890 中的1234567890
    private let appAppleID = "6753906811"
    
    // 检查更新
    func checkForUpdates() {
        // 获取本地版本号
        guard let localVersion = getLocalVersion() else {
            showError(message: "无法获取本地应用版本")
            return
        }
        
        // 获取App Store版本号
        fetchAppStoreVersion { [weak self] appStoreVersion in
            guard let self = self, let appStoreVersion = appStoreVersion else {
                self?.showError(message: "无法获取App Store版本信息")
                return
            }
            
            // 比较版本号
            if self.isNewVersionAvailable(localVersion: localVersion, appStoreVersion: appStoreVersion) {
                // 有新版本，显示更新提示
                self.showUpdateAlert(localVersion: localVersion, appStoreVersion: appStoreVersion)
            } else {
                // 已是最新版本
                self.showNoUpdateAlert(currentVersion: localVersion)
            }
        }
    }
    
    // 获取本地应用版本号
    private func getLocalVersion() -> String? {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
    
    // 从App Store获取最新版本号
    private func fetchAppStoreVersion(completion: @escaping (String?) -> Void) {
        let urlString = "https://itunes.apple.com/lookup?id=\(appAppleID)"
        
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("获取App Store版本失败: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                completion(nil)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let results = json["results"] as? [[String: Any]],
                   let appInfo = results.first,
                   let version = appInfo["version"] as? String {
                    completion(version)
                } else {
                    completion(nil)
                }
            } catch {
                print("解析App Store版本信息失败: \(error.localizedDescription)")
                completion(nil)
            }
        }
        
        task.resume()
    }
    
    // 比较版本号，判断是否有新版本
    private func isNewVersionAvailable(localVersion: String, appStoreVersion: String) -> Bool {
        let localComponents = localVersion.components(separatedBy: ".").compactMap { Int($0) }
        let storeComponents = appStoreVersion.components(separatedBy: ".").compactMap { Int($0) }
        
        let maxLength = max(localComponents.count, storeComponents.count)
        
        for i in 0..<maxLength {
            let local = i < localComponents.count ? localComponents[i] : 0
            let store = i < storeComponents.count ? storeComponents[i] : 0
            
            if store > local {
                return true
            } else if store < local {
                return false
            }
        }
        
        return false
    }
    
    // 显示更新提示弹窗
    private func showUpdateAlert(localVersion: String, appStoreVersion: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            let newVersion = "检查到新版本".localized
            let currentVersion = "当前版本".localized
            alert.messageText = "\(newVersion)\(appStoreVersion)，\(currentVersion)\(localVersion)"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "立即更新".localized)
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // 打开应用在App Store的页面
                if let url = URL(string: "https://apps.apple.com/app/id\(self.appAppleID)") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
    
    // 显示无更新提示
    private func showNoUpdateAlert(currentVersion: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "已是最新版本".localized
            alert.alertStyle = .informational
            alert.addButton(withTitle: "确定".localized)
            alert.runModal()
        }
    }
    
    // 显示错误提示
    private func showError(message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "检查更新失败".localized
            alert.informativeText = message
            alert.alertStyle = .critical
            alert.addButton(withTitle: "确定".localized)
            alert.runModal()
        }
    }
}

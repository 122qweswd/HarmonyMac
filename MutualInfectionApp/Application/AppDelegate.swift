//
//  AppDelegate.swift
//  MutualInfection
//
//  Created by Niko on 2025/8/30.
//

import UIKit
import ActivityKit
import OSLog
import Bugly
import XXPhotoPicker

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var manger : ShareAPI?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        ShareAPI.shared().startLogging("")
        ShareAPI.shared().log(1, "================= App启动 ==================")
        ShareAPI.shared().log(1, "appName:\(appName)    appVersion:\(appVersion)    buildVersion:\(appBuildVersion)")
        ShareAPI.shared().log(1, "application(_ application: didFinishLaunchingWithOptions launchOptions:\(String(describing: launchOptions))")

        // 忽略 SIGPIPE 信号 解决app闪退问题
        signal(SIGPIPE, SIG_IGN)
        MILocalNetworkPermissionManager.shared.requestPermission()
        
        if #available(iOS 16.2, *) {
            LiveActivityManager.shared.getPushToStartToken()
            observeActivityPushTokenAndState()
//            let authOptions: UNAuthorizationOptions = [.alert,.badge,.sound]
//            UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { (granted, error) in
//                print(granted,error ?? "")
//            }
//            application.registerForRemoteNotifications()
        }
        
//        let hostUDID = UserDefaults.standard.string(forKey: "HOST_UDID")
//        if hostUDID == nil {
//            let udid = ShareAPI.shared().generateUDID()
//            UserDefaults.standard.set(udid, forKey: "HOST_UDID")
//        }
        //临时文件清理
//        FileSaver.cleanupSimulatedTempDirectory(maxAge: 300)
        //落盘任务重启，继续导入
        Task.detached {
            ReimportAlbum.shared.reimportAlbum()
        }
        
        Bugly.start(withAppId: "b3dbfc6470")
        Task {
            clearFileCaches()
        }
        NetworkMonitor.shared.startMonitoring()
        return true
    }
    
    // 处理 URL Scheme 唤起
       func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
           
           print("📱 主应用被 URL Scheme 唤起: \(url)")
           
           guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                 components.scheme == "yourapp",
                 components.host == "share" else {
               print("❌ 不支持的 URL Scheme")
               return false
           }
           // 处理分享扩展传来的数据
//                   handleShareExtensionOpen(from: components)
           return true
       }
    
    func clearFileCaches() {
        let fileManager = FileManager.default
        if let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            clearContentsOfDirectory(at: cachesDir)
        }
        
        let tempDir = fileManager.temporaryDirectory
        clearContentsOfDirectory(at: tempDir)
    }
    
    private func clearContentsOfDirectory(at directoryURL: URL) {
        let fileManage = FileManager.default
        do {
            let contents = try fileManage.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            for fileURL in contents {
                try fileManage.removeItem(at: fileURL)
            }
        } catch {
            
        }
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        ShareAPI.shared().log(1, "application(_ application: configurationForConnecting connectingSceneSession: options:)")

        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
        ShareAPI.shared().log(1, "application(_ application: didDiscardSceneSessions sceneSessions:)")
    }
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        ShareAPI.shared().log(1, "application(_ application: performFetchWithCompletionHandler completionHandler:)")
    }


}



extension AppDelegate {
    
    @available(iOS 16.2, *)
    func observeActivityPushTokenAndState() {
//        Task {
//            for await activity in Activity<LiveActivityAttributes>.activityUpdates {
//                Task {
//                    for await tokenData in activity.pushTokenUpdates {
//                        let token = tokenData.map {String(format: "%02x", $0)}.joined()
//                        print("Observer Activity:\(activity.id) Push token: \(token)")
//                        Logger.liveactivity.info("Observer Activity:\(activity.id, privacy: .public) Push token: \(token,privacy: .public)")
//                        //send this token to your notification server
//                    }
//                }
//
//                Task {
//                    for await state in activity.activityStateUpdates {
//                        print("Observer Activity:\(activity.id) state:\(state)")
//                        let stateLog = "Observer Activity:\(activity.id) state:\(state)"
//                        Logger.liveactivity.info("\(stateLog,privacy: .public)")
//                        if state == .stale {
//                            LiveActivityManager.endActivity(activity: activity, dismissTimeInterval: 0)
//                        }
//                    }
//                }
//
//            }
//        }
    }
}

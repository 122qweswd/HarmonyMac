//
//  SceneDelegate.swift
//  MutualInfection
//
//  Created by Niko on 2025/8/30.
//

import UIKit
import IQKeyboardManagerSwift
import Toast
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
  
    private var tempScene: UIWindowScene?
    
    var huaweiShareVC  : MIHuaweiShareViewController?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        ShareAPI.shared().log(1, "scene(_ scene: willConnectTo session: options connectionOptions:)")

        guard let tempScene = (scene as? UIWindowScene) else { return }
        //冷启动
        self.tempScene = tempScene
        
       
        if !UserDefaults.standard.bool(forKey: use_agree) {
            let naviController = MIBaseNavigationViewController(rootViewController: ViewController())
            window?.rootViewController = naviController
        } else {
            huaweiShareVC = MIHuaweiShareViewController()
            let naviController = MIBaseNavigationViewController(rootViewController: huaweiShareVC ?? MIHuaweiShareViewController())
            window?.rootViewController = naviController
        }
        
        keyboardManager()
        let urlContexts = connectionOptions.urlContexts
        for urlContext in urlContexts {
//            if urlContext.url.absoluteString == "MutualInfectionApp://shareExtension?url=MutualInfectionApp://" {
//                self.handleURL(urlContext.url)
//            } else
            if urlContext.url.scheme == shareUrlSchemes && urlContext.url.host == shareHost {
                huaweiShareVC?.contentView.isHidden = true
                print("从 Share Extension 跳转过来")
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                   // huaweiShareVC?.contentView.isHidden = true
                    self.shareExtensionTask()
                }
            }else{
                ShareExtensionInfoManager.shared.clearShareInfo()
            }
        }
        
        /// 监听网络变化
        setupNetworkMonitor()
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        ShareAPI.shared().log(1, "scene(_ scene: openURLContexts URLContexts:)")

        guard let tempScene = (scene as? UIWindowScene) else { return }
        //热启动
        self.tempScene = tempScene
        
        for urlContext in URLContexts {
            let url = urlContext.url
            print(url)
            if url.absoluteString == "apple://stopAction" {
                AlertManager.showAlert(title: "是否取消", cancelTitle: "否".localized,cancelAction: {
                    
                }, confirmTitle: "是".localized,confirmAction: {
                    
                    //TODO: 需要根据不同的。类型 触发不同的通知
                    NotificationCenter.default.post(name:NSNotification.Name(cancelUseSend) , object: self)
                })
            }
//            else if url.absoluteString == "MutualInfectionApp://shareExtension?url=MutualInfectionApp://" {
//                handleURL(urlContext.url)
//            }
            else if url.scheme == shareUrlSchemes && url.host == shareHost {
               
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    huaweiShareVC?.contentView.isHidden = true
                    
                    
                    
                    self.shareExtensionTask()
                }
            }else{
                ShareExtensionInfoManager.shared.clearShareInfo()
            }
        }
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
        
        ShareAPI.shared().log(1, "sceneDidDisconnect")
        if #available(iOS 16.2, *) {
          LiveActivityManager.shared.endActivity(dismissTimeInterval: -1)
        }
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
        
        ShareAPI.shared().log(1, "sceneDidBecomeActive")
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
        
        ShareAPI.shared().log(1, "sceneWillResignActive")
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
        
        //        let stats = asyncTimer.getStatistics()
        //        let message = """
        //                开始时间: \(stats["startTime"] ?? "N/A")
        //                当前时间: \(stats["currentTime"] ?? "N/A")
        //                运行时长: \(stats["elapsedSeconds"] ?? "0") 秒
        //                执行次数: \(stats["executionCount"] ?? 0)
        //                """
        //        print(message)
        //
        //        asyncTimer.stopAsyncPrinting()
        
        ShareAPI.shared().log(1, "sceneWillEnterForeground")
        
        // BackgroundKeepAliveManager.shared.stopKeepAlive()
        ShareAPI.shared().enterForeground()
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
        
        //        asyncTimer.startAsyncPrinting()
        // 发送任务，接收任务，落盘任务添加保活操作
        ShareAPI.shared().log(1, "sceneDidEnterBackground")
        ShareAPI.shared().log(1, "已经进入后台")
        ShareAPI.shared().enterBackground()
    }
}


extension SceneDelegate {
    // MARK: - 键盘管理
    func keyboardManager() {
        //开启键盘监听
        IQKeyboardManager.shared.isEnabled = true
        //控制点击背景是否收起键盘
        IQKeyboardManager.shared.resignOnTouchOutside = true
        //控制键盘上的工具条文字颜色是否用户自定义
        //IQKeyboardManager.shared.toolbarConfiguration.useTextInputViewTintColor = true
        //IQKeyboardManager.sharedManager().shouldToolbarUsesTextFieldTintColor = true
        //将右边Done改成完成
        //IQKeyboardManager.shared.toolbarDoneBarButtonItemText = "完成"
        // 控制是否显示键盘上的工具条
        //IQKeyboardManager.shared.enableAutoToolbar = true
        //最新版的设置键盘的returnKey的关键字 ,可以点击键盘上的next键，自动跳转到下一个输入框，最后一个输入框点击完成，自动收起键盘
        //IQKeyboardManager.shared.toolbarConfiguration.manageBehavior = .byPosition
    }
}

extension SceneDelegate {
    // MARK: -  监听网络变化
    func setupNetworkMonitor() {
//        NetworkMonitor.shared.startMonitoring()
        //        NetworkMonitorManager.setupNetworkMonitor()
    }
}

extension SceneDelegate {
    /// ShareExtension后续业务
    func shareExtensionTask() {

        ShareAPI.shared().log(1, "共享数据获取成功")
        if let sharedDefaults = UserDefaults(suiteName: groupID) {
            let shareInfoModel = sharedDefaults.loadShareInfo()
            /// 读取数据
            print("\(String(describing: shareInfoModel))")
        }
        
        /// 加载数据
        ShareExtensionInfoManager.shared.loadShareInfoModel()
        
        Task {
            guard let topVC = MIGetTopViewController() else { return }
            
            let chainGroup = TaskQueueManager.createChainGroup()
            
            if topVC is ViewController {
                let task = TaskOperation.async(identifier: "Auth") { task in
                    /// 授权页点击授权，记录处理业务
                    (topVC as? ViewController)?.waitForAuthorization { [weak task] in
                        guard let task = task else { return }
                        task.finish(true) // 继续下一步
                    }
                }
                
                chainGroup.add(task)
                
            } else {
                if isRecvTask || isSendTask{
                    await MainActor.run {
                        ShareAPI.shared().log(1, "分享任务接收\(isRecvTask)====发送\(isSendTask)")
                        //当前正在接收 不可分享
                        topVC.view.pickerMakeToast("当前正在传输,不可分享", duration: 2.0, point: topVC.view.center, title: nil, image: nil, completion: nil)
                    }
                    return
                } else {
                    
                    @MainActor func dismissViewController() {
                        if let topVC = MIGetTopViewController(), topVC.presentingViewController != nil , !topVC.isKind(of: MIHuaweiShareViewController_Modal.self), !topVC.isKind(of: MIDocumentPickerViewController.self){
                            topVC.dismiss(animated: false) {
                             
                                dismissViewController()
                            }
                        }
                    }
                     
                    dismissViewController()
                    
                    let topVC = MIGetTopViewController()
                    topVC?.navigationController?.popToRootViewController(animated: true)
                }
            }
            
            chainGroup.onAllTasksFinished = { [weak self] success in
                guard let self = self, success else { return }
                shareTaskContinue(dict:[:])
            }
            
            /// 为保证没有任务也可触发队列，
            let task = TaskOperation.async(identifier: "empty") { task in task.finish(true) }
            
            chainGroup.add(task)
            chainGroup.start()
        }
    }
    
    func shareTaskContinue(dict:[String:String]) {
        ShareAPI.shared().log(1, "共享数据获取成功")
        guard let topVC = MIGetTopViewController() else { return }
        Task {
            /// 处理分享内容
            let shouldContinue = await ShareExtensionInfoManager.shared.handleShareInfoModel()
            //let filePath = ShareExtensionInfoManager.shared.shareInfoModel?.fileInfos.first?.filePath
            let filePathList = ShareExtensionInfoManager.shared.shareInfoModel?.fileInfos.filter { !$0.filePath.isEmpty }
            
            if shouldContinue.0 {
                if let filePathList = filePathList, !filePathList.isEmpty {
                    ShareExtensionInfoManager.shared.shareInfoModel?.fileInfos = filePathList
                    if let rootNAVC = window?.rootViewController as? MIBaseNavigationViewController, let huaweiShareVC = rootNAVC.viewControllers.first as? MIHuaweiShareViewController {
                       
                        huaweiShareVC.navigationController?.popToViewController(huaweiShareVC, animated: true)
                       // DispatchQueue.main.asyncAfter(deadline: .now() + 1.0){
                            
                        huaweiShareVC.startPostShareData(dict: shouldContinue.1 )
//                        }
                    } else {
                        ShareExtensionInfoManager.shared.clearShareInfo()
                    }
                } else {
                    ShareExtensionInfoManager.shared.clearShareInfo()
                    topVC.view.pickerMakeToast("资源获取失败", duration: 2.0, point: topVC.view.center, title: nil, image: nil, completion: nil)
                }
            }
        }
    }
}

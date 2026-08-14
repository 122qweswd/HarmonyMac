//
//  AppDelegate.swift
//  MutualInfectionMac
//
//  Created by 1234 on 2025/9/24.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // 存储所有正在处理的 UDID
    private var processingUDIDs: Set<String> = []
    private var loadingWindows: [String: NSWindow] = [:]
    private let nodeRuntimeManager = NodeRuntimeManager()
    // MARK: - 单例访问
    static let shared: AppDelegate = {
        return NSApplication.shared.delegate as! AppDelegate
    }()
    
    var mainWindowCall: MainWindowCall?
    private var agreementWindowCall: AgreementWindowCall?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        ShareAPI.shared().startLogging("")
        ShareAPI.shared().log(1, "================= App启动 ==================")
        ShareAPI.shared().log(1, "appName:\(appName)    appVersion:\(appVersion)    buildVersion:\(appBuildVersion)")
        
        // 忽略 SIGPIPE 信号 解决app闪退问题
        signal(SIGPIPE, SIG_IGN)
        // 强制应用使用浅色模式
        NSApp.appearance = NSAppearance(named: .aqua)
        
        // 检查启动事件，判断是否来自 Share Extension
        checkPendingSharedFilesOnLaunch()
        
        // 初始化主窗口或协议窗口
        setupInitialWindow()

        nodeRuntimeManager.startIfNeeded()
        
        MIThumbImageDataFileManager.shared.requestThumbnailImageDataAgain()
        
        Task {
            /// 模拟测试数据
            //            await WCDBMACTestManager.shared.runCompleteTestSuite()
        }
        
        //        FloatingWindowManager.shared.createFloatingWindow()
        
        AppVersionChecker().getLatestVersionFromAppStore(appID: "6753906811") { version in
                let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            ShareAPI.shared().log(1, "获取当前版本号=====\(currentVersion)")  
            ShareAPI.shared().log(1, "获取最新版本号=====\(version ?? "")")  
            if let version = version {
                let isNew = AppVersionChecker().chechVersion(nowVer: currentVersion, newVer: version)
                if isNew {
                    let alert = NSAlert()
                    alert.messageText = "发现新版本".localized
                    alert.informativeText = "\("当前版本".localized): \(currentVersion)\n\("最新版本:".localized) \(version)\n\n\("是否前往 App Store 更新？".localized)"
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "前往更新".localized)
                    alert.addButton(withTitle: "取消".localized)
                    
                    let response = alert.runModal()
                    if response == .alertFirstButtonReturn {
                        if let url = URL(string: "https://apps.apple.com/app/id=6753906811") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
        }
    }
    
    private func checkPendingSharedFilesOnLaunch() {
        // 检查启动事件，判断是否来自 Share Extension
        if let event = NSAppleEventManager.shared().currentAppleEvent {
            let eventID = event.eventID
            if eventID == kAEOpenContents || eventID == kAEOpenDocuments {
                ShareAPI.shared().log(1, "应用通过文件共享方式启动")
                UserDefaults.standard.set(true, forKey: "hasPendingSharedFiles")
            }
        }
    }
    
    private func setupInitialWindow() {
        if UserDefaults.standard.string(forKey: "AgreementKey") == nil ||
            UserDefaults.standard.string(forKey: "AgreementKey") == "false" {
            if agreementWindowCall == nil {
                agreementWindowCall = AgreementWindowCall()
                agreementWindowCall?.showWindow()
            }
        } else {
            if mainWindowCall == nil {
                mainWindowCall = MainWindowCall()
                mainWindowCall?.showWindow()
            }
            
            
            // 如果启动时有待处理文件，检查它们
            //            if UserDefaults.standard.bool(forKey: "hasPendingSharedFiles") {
            //                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            //                    self.processPendingSharedFiles()
            //                }
            //            }
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        ShareAPI.shared().log(1, "applicationWillTerminate:aNotification \(String(describing: aNotification.description))")
        nodeRuntimeManager.stop()
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    // MARK: - URL Scheme Support
    // 处理来自 Share Extension 的 URL Scheme 调用
    func application(_ application: NSApplication, open urls: [URL]) {
        ShareAPI.shared().log(1, "收到 URL Scheme 调用: \(urls)")
        
        
        for url in urls {
            ShareAPI.shared().log(1, "处理 URL: \(url.absoluteString)")
            if url.scheme == macShareUrlSchemes && url.host == macShareHost {
                ShareAPI.shared().log(1, "检测到来自 Share Extension 的调用")
                handleShareExtensionCall()
            }
        }
    }
    
    private func handleShareExtensionCall() {
        // 标记有共享文件待处理
        UserDefaults.standard.set(true, forKey: "hasPendingSharedFiles")
        UserDefaults.standard.synchronize()
        
        // 确保应用完全激活
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            self.ensureMainWindowIsVisible()
            
            // 延迟处理以确保窗口已准备好
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.processPendingSharedFiles()
            }
        }
    }
    
    private func processPendingSharedFiles() {
        ShareAPI.shared().log(1, "开始处理待处理的共享文件...")
        //        let vc = mainWindowCall?.window?.contentViewController
        //        if vc?.isKind(of: MainWindowController.self) ?? false {
        //           let newVC =  vc as? MainWindowController
        //            newVC?.closePanel()
        //        }
        SharedFilesManager.shared.checkSharedFiles { success, files in
            if success {
                ShareAPI.shared().log(1, "✅ 成功接收 \(files.count) 个文件")
                
                // 清除标记
                UserDefaults.standard.set(false, forKey: "hasPendingSharedFiles")
                
                // 通知主窗口显示文件
                if let mainWindow = self.mainWindowCall {
                    // 这里需要根据您的实际实现来通知主窗口
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SharedFilesProcessed"),
                        object: files
                    )
                }
            } else {
                ShareAPI.shared().log(1, "❌ 没有接收到文件或处理失败")
            }
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        print("应用重新打开，有可见窗口: \(flag)")
        
        let hasPendingFiles = UserDefaults.standard.bool(forKey: "hasPendingSharedFiles")
        
        if UserDefaults.standard.string(forKey: "AgreementKey") == nil ||
            UserDefaults.standard.string(forKey: "AgreementKey") == "false" {
            if agreementWindowCall == nil {
                agreementWindowCall = AgreementWindowCall()
            }
            agreementWindowCall?.showWindow()
            
            if hasPendingFiles {
                UserDefaults.standard.set(true, forKey: "processFilesAfterAgreement")
            }
        } else {
            if !flag {
                ensureMainWindowIsVisible()
            }
            
            if hasPendingFiles {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.processPendingSharedFiles()
                }
            }
        }
        return true
    }
    
    // 确保主窗口可见的辅助方法
    func ensureMainWindowIsVisible() {
        if mainWindowCall == nil {
            mainWindowCall?.showWindow()
        }
        
        if let window = mainWindowCall?.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        
        NotificationCenter.default.post(
            name: NSNotification.Name("windowIsReopen"),
            object: nil
        )
    }
    
    @IBAction func aboutAction(_ sender: Any) {
        Gloable.showTabNSWindow?.close()
        if UserDefaults.standard.string(forKey: "AgreementKey") == nil ||
            UserDefaults.standard.string(forKey: "AgreementKey") == "false" {
            let page=PagesCall(upWindow:agreementWindowCall?.window)
            page.aboutWindowShow()
        } else {
            
            let page=PagesCall(upWindow:mainWindowCall?.window)
            page.aboutWindowShow()
        }
    }
    
    @IBAction func helpAction(_ sender: Any) {
        Gloable.showTabNSWindow?.close()
        if UserDefaults.standard.string(forKey: "AgreementKey") == nil ||
            UserDefaults.standard.string(forKey: "AgreementKey") == "false" {
            let page=PagesCall(upWindow:agreementWindowCall?.window)
            page.helpWindowShow()
        } else {
            
            let page=PagesCall(upWindow:mainWindowCall?.window)
            page.helpWindowShow()
        }
    }
    
    @IBAction func openAction(_ sender: Any) {
        if UserDefaults.standard.string(forKey: "AgreementKey") == nil ||
            UserDefaults.standard.string(forKey: "AgreementKey") == "false" {
            let agreeVisible = agreementWindowCall?.window?.isVisible
            if agreeVisible==false
            {
                agreementWindowCall?.showWindow()
            }
        } else {
            let mainVisible = mainWindowCall?.window?.isVisible
            if mainVisible==false
            {
                mainWindowCall?.showWindow()
            }
        }
    }
}

extension AppDelegate{
    func showLoadingState(for udid: String) {
        ShareAPI().log(1, "🔵 showLoadingState called for: \(udid)")
        ShareAPI().log(1, "🔵 Current loadingWindows keys: \(loadingWindows.keys)")
        ShareAPI().log(1, "🔵 Self instance: \(ObjectIdentifier(self))")
        // 获取当前的主窗口作为父窗口
        guard let parentWindow = NSApp.mainWindow ?? NSApp.keyWindow else {
            ShareAPI().log(1, "❌ 没有找到主窗口")
            return
        }
        ShareAPI().log(1, "🔵 父窗口: \(parentWindow)")

        // 添加到处理集合
        processingUDIDs.insert(udid)
        ShareAPI().log(1, "🔵 Will save with key: \(udid)")
        // 创建并显示加载窗口
        let loadingWindow = self.createLoadingWindow(for: udid)
        ShareAPI().log(1, "🔵 Created window: \(loadingWindow)")

        self.loadingWindows[udid] = loadingWindow
        ShareAPI().log(1, "🔵 After save, loadingWindows: \(self.loadingWindows)")
        ShareAPI().log(1, "🔵 Count: \(self.loadingWindows.count)")
        // 使用捕获的 parentWindow，而不是重新获取
        parentWindow.beginSheet(loadingWindow) { response in
            // 这个 completionHandler 在 Sheet 完全关闭后调用
            print("📝 Sheet 关闭完成回调，response: \(response)")
            DispatchQueue.main.async {
                ShareAPI().log(1, "✅ 开始清空数据，response: \(response.rawValue)")
//                print("✅ 开始清空数据，response: \(response.rawValue)")
//                self.loadingWindows.removeValue(forKey: udid)  
                ShareAPI().log(1, "✅ 清空数据")
//                print("✅ 清空数据")
                // 调试：检查还有没有其他未清理的
                ShareAPI().log(1, "📊 清理后 - loadingWindows: , processingUDIDs: ")
//                print("📊 清理后 - loadingWindows: , processingUDIDs: ")
//                ShareAPI().log(1, "📊 清理后 - loadingWindows: \(self.loadingWindows.count ), processingUDIDs: \(self.processingUDIDs.count)")
            }
            
        }
    }
    func hideLoadingState(for udid: String) {
        ShareAPI().log(1, "🔴 hideLoadingState called for: \(udid)")
        
        processingUDIDs.remove(udid)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 获取但不立即移除 - 保持引用
            guard let sheet = self.loadingWindows[udid] else {
                return
            }
            
            ShareAPI().log(1, "🔵 开始关闭流程，窗口可见性: \(sheet.isVisible)")
            
            // 如果是 sheet 且有父窗口
            if let parent = sheet.sheetParent, sheet.isVisible {
                // 清理文本编辑
                cleanupTextEditing(in: parent)
                
                // **关键修复：使用 orderOut 代替 endSheet**
                // 这会隐藏窗口但保持 sheet 关系
                sheet.orderOut(nil)
                
                // 延迟从字典中移除
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.loadingWindows.removeValue(forKey: udid)
                    
                    // 如果需要，可以完全关闭窗口
                    if !sheet.isVisible {
                        sheet.close()
                    }
                }
            } else {
                // 非 sheet 窗口直接处理
                sheet.orderOut(nil)
                self.loadingWindows.removeValue(forKey: udid)
            }
        }
    }//    func hideLoadingState(for udid: String) {
//        ShareAPI().log(1, "🔴 hideLoadingState called for: \(udid)")
//        // 从处理集合移除
//        processingUDIDs.remove(udid)
//                
//        // 在主线程执行关闭操作
//        DispatchQueue.main.async { [weak self] in
//            guard let self = self else {
//                ShareAPI().log(1, "❌ self 已释放")
//                return
//            }              
//            // 获取存储的 Sheet
//            guard let sheet = self.loadingWindows[udid] else {
//                ShareAPI().log(1, "❌ 未找到窗口信息")
//                // 如果没找到窗口但处理已完成，恢复UI
//                return
//            }
//            ShareAPI().log(1, "✅ 找到窗口: \(sheet)")
//            guard let parent = sheet.sheetParent else{
//                ShareAPI().log(1, "❌ 未找到窗口父视图")
//                return
//            }
//            // 安全关闭sheet
//            if parent.isVisible && sheet.isVisible {
//                ShareAPI().log(1, "✅ 执行 endSheet with .OK")
//                // **关键修复：始终指定 returnCode**
//                if let parent = sheet.sheetParent {
//                    print("✅ 找到父窗口: \(parent)")
//                    // 1. 在调用前检查 sheet 是否有效
//                    guard sheet.isKind(of: NSWindow.self) else {
//                        print("❌ sheet 类型异常，不是 NSWindow")
//                        return
//                    }
//                    
//                    // 2. 确保 sheet 仍然可见
//                    guard sheet.isVisible else {
//                        print("⚠️ sheet 已不可见，跳过 endSheet")
//                        return
//                    }
//                    
//                    // 3. 清理你的数据字典
//                    if self.loadingWindows[udid] != nil {
//                        self.loadingWindows.removeValue(forKey: udid)
//                        ShareAPI().log(1, "📊 清理后 - loadingWindows完成")
//                    }
//                    // 4. 异步执行 endSheet
//                    DispatchQueue.main.async { [weak self] in
//                        parent.endSheet(sheet, returnCode: .OK)
//                        ShareAPI().log(1, "✅ 执行 endSheet 完成")
//                    }
//                }else{
//                    // 备选方案：直接关闭窗口
//                    if sheet.isVisible {
//                        sheet.close()
//                        ShareAPI().log(1, "✅ 直接关闭 sheet 窗口")
//                    }
//                    if self.loadingWindows[udid] != nil {
//                        self.loadingWindows.removeValue(forKey: udid)
//                    }
//                }
//                ShareAPI().log(1, "✅ 全部执行 endSheet 完成")
//                
//            } else {
//                ShareAPI().log(1, "⚠️ 窗口不可见，直接清理")
//                sheet.orderOut(nil)
//                if self.loadingWindows[udid] != nil {
//                    self.loadingWindows.removeValue(forKey: udid)
//                }
//            }
//        }  
//    }
    private func createLoadingWindow(for udid: String) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 150),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "处理中".localized
        window.level = .modalPanel
        window.ignoresMouseEvents = false // 重要：需要接收鼠标事件
        window.isReleasedWhenClosed = false
        
        // 创建内容视图
        let contentView = BlockingView(frame: NSRect(x: 0, y: 0, width: 300, height: 150))
        
        // 进度指示器
        let progressIndicator = NSProgressIndicator(frame: NSRect(x: 130, y: 80, width: 40, height: 40))
        progressIndicator.style = .spinning
        progressIndicator.startAnimation(nil)
        
        // 标签
        let label = NSTextField(frame: NSRect(x: 50, y: 50, width: 200, height: 20))
        label.stringValue = "正在处理文件...".localized
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.alignment = .center
        
        contentView.addSubview(progressIndicator)
        contentView.addSubview(label)
        //        contentView.addSubview(udidLabel)
        
        window.contentView = contentView
        return window
    }
    /// 处理程序退出逻辑
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // 先安全关闭所有Window，再退出
        mainWindowCall?.safeCloseWindow()
        nodeRuntimeManager.stop()
        cleanupLogHelper()
        return .terminateNow
    }
    private func cleanupTextEditing(in window: NSWindow) {
        // 强制结束所有文本编辑
        window.makeFirstResponder(nil)
        
        // 遍历并清理所有文本控件
        if let contentView = window.contentView {
            cleanupTextEditing(in: contentView)
        }
    }
    
    private func cleanupTextEditing(in view: NSView) {
        if let textField = view as? NSTextField {
            if textField.currentEditor() != nil {
                textField.window?.makeFirstResponder(nil)
            }
        }
        
        if let textView = view as? NSTextView {
            if textView.isFieldEditor {
                textView.window?.makeFirstResponder(nil)
            }
        }
        
        for subview in view.subviews {
            cleanupTextEditing(in: subview)
        }
    }
}
class BlockingView: NSView {
    override func mouseDown(with event: NSEvent) {
        // 拦截点击，不调用super，事件就被吞噬了
        print("点击被拦截")
    }
    override func rightMouseDown(with event: NSEvent) {
        print("右键点击被拦截")
    }
    //  必须返回true才能接收事件
    override var acceptsFirstResponder: Bool {
        return true
    }
}

extension AppDelegate {
    private func cleanupLogHelper() {
        ShareAPI.shared().log(1, "================= App退出 ==================")
        ShareAPI.shared().cleanupLogging()
    }
    
}

extension NSWindow {
    private struct AssociatedKeys {
        static var disabledControls = "disabledControlsKey"
    }
    var isModal: Bool {
        NSApp.modalWindow === self
    }
    
}
extension NSWindowController {
    /// 安全关闭Window（避免释放时断言失败）
    func safeCloseWindow() {
        DispatchQueue.main.async { [weak self] in // 强制主线程操作UI
            guard let self = self, let window = self.window else { return }
            
            // 1. 移除所有子视图（清理强引用）
            window.contentView?.subviews.forEach { $0.removeFromSuperview() }
            
            // 2. 关闭模态窗口（如果有）
            if window.isModal {
                NSApp.stopModal()
            }
            
            // 3. 取消所有通知监听
            NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: window)
            
            // 4. 先隐藏再释放（避免UI状态异常）
            window.orderOut(nil)
            self.window = nil // 触发dealloc前确保状态干净
        }
    }
}



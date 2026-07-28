//
//  MIMACReceiveFilesManager.swift
//  MutualInfectionMac
//
//  Created by apple on 2025/10/24.
//

import Cocoa

// 定义视图控制器类型枚举
enum FloatingViewControllerType {
    // 接收
    case receivePop
    // 接收中
    case receivingPop
    // 加入热点
    case joinHotspotPop
    // 取消接收弹框
    case cancelPop
    // error 提示弹框
    case errorPop
}

class MIRecvPageManager: NSPanel {
    
    private var rect = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)
    private var closeBtn:NSButton?
    var bgView: NSView?
    var udid: String?
    var receptOrNotPopController: ReceptOrNotPopController?
    var stopReceptPopController: StopReceptPopController?
    var cancelPopController: CancelReceptPopController?
    var recvErrorPopController: RecvErrorPopController?
    
    // MARK: - 初始化方法
    init(rect:NSRect = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),type: FloatingViewControllerType,isShowCloseBtn:Bool = false) {
        // 设置面板样式
        super.init(
            contentRect: rect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        self.rect = rect
        
        // 设置窗口属性
        self.hasShadow = true
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.isMovableByWindowBackground = true
        // 设置窗口层级，使其显示在其他窗口之上
        self.level = NSWindow.Level.screenSaver
        // 设置窗口集合行为，使其可以在所有空间显示，包括全屏应用
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // 设置动画行为
        self.animationBehavior = .none
        
        setupUI(type: type,isShowCloseBtn:isShowCloseBtn)
    }
    
    // 重写属性，允许窗口成为关键窗口和主窗口
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    // MARK: - 界面设置
    private func setupUI(type: FloatingViewControllerType, isShowCloseBtn:Bool = false) {
        self.title = title
        self.isFloatingPanel = true
        // 接收确认浮窗需要稳定响应首击，显示后主动成为 key window，降低偶发点不动风险。
        self.becomesKeyOnlyIfNeeded = false
        self.hidesOnDeactivate = false
        
        // 创建主容器
        let containerView = NSView(frame: rect)
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.clear.cgColor
        self.contentView = containerView
        self.center()

        bgView = NSView(frame: NSRect(x: 15, y: 15, width: rect.width - 29, height: rect.height - 29))
        bgView?.wantsLayer = true
        bgView?.layer?.backgroundColor = NSColor.white.cgColor
        bgView?.layer?.cornerRadius = 10
        bgView?.layer?.masksToBounds = false // 允许阴影显示
        containerView.addSubview(bgView ?? NSView())
        
        // 添加关闭按钮
//        closeBtn = NSButton(image: NSImage.iconClose, target: self, action: #selector(closeButtonClicked))
        closeBtn = NSButton(image: NSImage.btnCloseJpg, target: self, action: #selector(closeButtonClicked))
        closeBtn?.setButtonType(.momentaryChange)
        closeBtn?.isBordered = false // 关键属性，禁用系统边框样式
        closeBtn?.bezelStyle = .circular
        closeBtn?.imageScaling = .scaleAxesIndependently
        closeBtn?.isHidden = !isShowCloseBtn
        closeBtn?.wantsLayer = true
        closeBtn?.layer?.cornerRadius = 11
        closeBtn?.layer?.backgroundColor = NSColor.white.cgColor
        containerView.addSubview(closeBtn ?? NSButton())
        
        closeBtn?.snp.makeConstraints { make in
            make.top.equalTo(bgView?.snp.top ?? 0).offset(-8)
            make.trailing.equalTo(bgView?.snp.trailing ?? 0).offset(8)
            make.width.height.equalTo(22)
        }
        
        receptOrNotPopController = ReceptOrNotPopController()
        bgView?.addSubview(receptOrNotPopController?.view ?? NSView())
        
        stopReceptPopController = StopReceptPopController()
        bgView?.addSubview(stopReceptPopController?.view ?? NSView())
        
        cancelPopController = CancelReceptPopController()
        bgView?.addSubview(cancelPopController?.view ?? NSView())
        
        recvErrorPopController = RecvErrorPopController()
        bgView?.addSubview(recvErrorPopController?.view ?? NSView())
        
        switchToViewController(ofType: type)
    }
    
    // 关闭按钮点击事件
    @objc private func closeButtonClicked() {
        showCloseBtn(isHidden: true)
        self.close()
    }
    
    // MARK: - 显示弹窗方法
    func showModal(in window: NSWindow? = nil) {
//        let screenFrame = getScreenSize()
//        let panelX = screenFrame.width - self.rect.width // 15 是距离屏幕右边缘的间距
//        let panelY = screenFrame.height - self.rect.height // 15 是距离屏幕底边缘的间距
//        self.setFrameOrigin(NSPoint(x: panelX, y: panelY))
//        self.makeKeyAndOrderFront(nil)
        
        print("=== 面板显示调试信息 ===")
        // 1. 找到鼠标所在的屏幕
        let mouseLocation = NSEvent.mouseLocation
        guard let targetScreen = NSScreen.screens.first(where: { 
            $0.frame.contains(mouseLocation) 
        }) else {
            print("未找到鼠标所在屏幕")
            return
        }
        
        print("目标屏幕: \(targetScreen.frame)")
        print("屏幕visibleFrame: \(targetScreen.visibleFrame)")
        
        // 2. 使用 visibleFrame 而不是 frame（考虑菜单栏和Dock）
        let visibleFrame = targetScreen.visibleFrame
        
        // 3. 计算在屏幕本地坐标系中的位置
        // 关键：面板位置应该是相对于屏幕原点的，不是全局坐标
        let margin: CGFloat = 20
        let panelWidth = self.rect.width
        let panelHeight = self.rect.height
        
        // 正确计算：在屏幕可见区域内右上角
        let panelX = visibleFrame.width - panelWidth - margin  // 在屏幕宽度内
        let panelY = visibleFrame.height - panelHeight - margin  // 在屏幕高度内
        
        print("屏幕本地坐标计算:")
        print("  可见区域尺寸: \(visibleFrame.size)")
        print("  面板尺寸: \(panelWidth) x \(panelHeight)")
        print("  本地计算位置: (\(panelX), \(panelY))")
        
        // 4. 转换为全局坐标
        let globalX = visibleFrame.origin.x + panelX
        let globalY = visibleFrame.origin.y + panelY
        
        print("转换为全局坐标: (\(globalX), \(globalY))")
        
        // 5. 验证位置是否在屏幕内
        let finalFrame = NSRect(x: globalX, y: globalY, width: panelWidth, height: panelHeight)
        let isInScreen = targetScreen.frame.contains(finalFrame)
        print("最终frame: \(finalFrame)")
        print("是否在屏幕内: \(isInScreen)")
        
        // 6. 设置位置
        self.setFrameOrigin(NSPoint(x: globalX, y: globalY))
        
        // 7. 确保面板属性正确
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        self.makeKeyAndOrderFront(nil)
        self.orderFrontRegardless()  // 强制显示
        
        print("========================\n")
        
        // 9. 强制面板到最前面（额外保险）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.orderFrontRegardless()
        }
    }
    
    // 切换到指定页面
    func switchToViewController(ofType type: FloatingViewControllerType, upWindow: NSWindow = NSWindow(), udid: String = "", metadata: [AnyHashable : Any] = [:]) {
        receptOrNotPopController?.view.isHidden = true
        if ((receptOrNotPopController?.recvMenu) != nil) {
            receptOrNotPopController?.recvMenu?.cancelTracking()
        }
        stopReceptPopController?.view.isHidden = true
        cancelPopController?.view.isHidden = true
        recvErrorPopController?.view.isHidden = true
        self.udid = udid
        ShareAPI.shared().log(1, "[UI] [MIMACReceiveFilesManager] switchToViewController type: \(type)")
        switch type {
        case .receivePop://接收
            ShareAPI.shared().log(1, "收到接收回调，显示是否接收")
            receptOrNotPopController?.view.isHidden = false
            receptOrNotPopController?.setData(upWindow: upWindow, udid: udid, metadata: metadata)
        case .receivingPop:
            ShareAPI.shared().log(2, "接收中。。。。")
            stopReceptPopController?.view.isHidden = false
            stopReceptPopController?.setData(upWindow: upWindow, metadata: metadata)
        case .joinHotspotPop:
            ShareAPI.shared().log(3, "提示加入热点")
            receptOrNotPopController?.view.isHidden = false
        case .cancelPop:
            ShareAPI.shared().log(4, "提示取消接收，取消接收弹框")
            cancelPopController?.view.isHidden = false
        case .errorPop: 
            ShareAPI.shared().log(5, "error提示弹框")
            recvErrorPopController?.view.isHidden = false
        }
    }
    
    // 接收中切换到取消接收页面
    func switchCancelPage(isShow: Bool) {
        ShareAPI.shared().log(1, "[UI] [MIMACReceiveFilesManager] switchCancelPage isShow: \(isShow)")
        cancelPopController?.view.isHidden = !isShow
        stopReceptPopController?.view.isHidden = isShow
    }
    
    // 显示或者隐藏关闭按钮
    func showCloseBtn(isHidden: Bool) {
        self.closeBtn?.isHidden = isHidden
    }
}

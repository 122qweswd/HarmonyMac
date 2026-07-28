//
//  MICustomPanel.swift
//  MutualInfectionMac
//
//  Created by apple on 2025/10/24.
//

import Cocoa

class MICustomPanel: NSPanel {
    
    // MARK: - 回调闭包
    private var confirmAction: (() -> Void)?
    private var cancelAction: (() -> Void)?
    private var rect = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)
    

    private var ownPhotoView:NSImageView?
    private var cancelButton: NSButton?
    private var trueButton: NSButton?
    private var closeBtn:NSButton?
    
    private lazy var nameLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .mi.pingFangSCMedium(size: 13)
        label.textColor = .mi.hex("#000000")
        label.cell?.wraps = true
        label.cell?.isScrollable = false
        if let textFieldCell = label.cell as? NSTextFieldCell {
            textFieldCell.lineBreakMode = .byWordWrapping
        }
        return label
    }()
    
    // 设置拒绝按钮样式
    let cancelAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 13, weight: .regular),
        .foregroundColor: NSColor(red: 0, green: 0, blue: 0, alpha: 0.85)
    ]
    // 设置接收按钮样式
    let trueAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 13, weight: .medium),
        .foregroundColor: NSColor(red: 0, green: 0, blue: 0, alpha: 0.85)
    ]
    
    // MARK: - 初始化方法
    init(rect:NSRect = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),title: String, confirmButtonTitle: String = "确定", cancelButtonTitle: String = "取消",isShowCloseBtn:Bool = false) {
        // 设置面板样式
        super.init(
            contentRect: rect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        self.rect = rect
        
        
//        // 设置窗口属性
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
//
//        // 在macOS 10.14及以上版本设置外观
//        if #available(macOS 10.14, *) {
//            self.appearance = NSAppearance(named: .vibrantLight)
//        }
        
        setupUI(title: title,
                confirmTitle: confirmButtonTitle, cancelTitle: cancelButtonTitle,isShowCloseBtn:isShowCloseBtn)
        
    }
    
    // 重写属性，允许窗口成为关键窗口和主窗口
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    // MARK: - 界面设置
    private func setupUI(title: String, confirmTitle: String, cancelTitle: String,isShowCloseBtn:Bool = false) {
        self.title = title
        self.isFloatingPanel = true
        self.becomesKeyOnlyIfNeeded = true
        self.hidesOnDeactivate = false
        
        // 创建主容器
        let containerView = NSView(frame: rect)
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.clear.cgColor
        self.contentView = containerView
        self.center()
        

        // 创建主容器
        let bgView = NSView(frame: NSRect(x: 15, y: 15, width: rect.width - 30, height: rect.height - 30))
        bgView.wantsLayer = true
        bgView.layer?.backgroundColor = NSColor.white.cgColor
        bgView.layer?.cornerRadius = 10
        bgView.layer?.masksToBounds = true // 确保内容不会溢出圆角
        containerView.addSubview(bgView)
        
        
   
        ownPhotoView =  NSImageView()
        // 配置默认属性
        ownPhotoView?.imageScaling = .scaleProportionallyUpOrDown
        ownPhotoView?.wantsLayer = true
        ownPhotoView?.layer?.cornerRadius = 18
        ownPhotoView?.layer?.masksToBounds = true
        ownPhotoView?.translatesAutoresizingMaskIntoConstraints = false
        ownPhotoView?.image = NSImage.device
        bgView.addSubview(ownPhotoView ?? NSImageView())
    
        nameLabel.stringValue = title.localized
        bgView.addSubview(nameLabel)
        
        
        cancelButton = NSButton(title: cancelTitle.localized, target: self, action: #selector(cancelButtonClicked(_:)))
        // cancelButton?.sendAction(on: [.leftMouseDown, .leftMouseUp])
        cancelButton?.wantsLayer = true
        cancelButton?.layer?.backgroundColor = NSColor.clear.cgColor
        cancelButton?.isBordered = false
        cancelButton?.layer?.borderWidth = 0.0
        cancelButton?.layer?.borderColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.1).cgColor
        cancelButton?.layer?.cornerRadius = 0
        cancelButton?.layer?.masksToBounds = true
        cancelButton?.attributedTitle = NSAttributedString(string: cancelTitle.localized, attributes: cancelAttributes)
        //cancelButton?.bezelStyle = .rounded
        cancelButton?.keyEquivalent = "\u{1b}" // ESC键
      //  bgView.addSubview(cancelButton ?? NSButton())
        
        
    
        trueButton = NSButton(title: confirmTitle.localized, target: self, action: #selector(trueButtonClicked(_:)))
        // trueButton?.sendAction(on: [.leftMouseDown, .leftMouseUp])
        trueButton?.wantsLayer = true
        trueButton?.layer?.backgroundColor = NSColor.clear.cgColor
        trueButton?.isBordered = false
        trueButton?.layer?.borderWidth = 0.0
        trueButton?.layer?.borderColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.1).cgColor
        trueButton?.layer?.cornerRadius = 0
        trueButton?.layer?.masksToBounds = true
        trueButton?.attributedTitle = NSAttributedString(string: confirmTitle.localized, attributes: trueAttributes)
        //trueButton?.bezelStyle = .rounded
        trueButton?.keyEquivalent = "\r" // Return键
       // bgView.addSubview(trueButton ?? NSButton())
        
        let btns = NSStackView()
        btns.orientation = .vertical
        btns.wantsLayer = true
        btns.translatesAutoresizingMaskIntoConstraints = false
        btns.distribution = .fillEqually
        addLeftBorder(to: btns, color: NSColor(red: 0, green: 0, blue: 0, alpha: 0.1), width: 0.1)
        if (!cancelTitle.localized.isEmpty){
            btns.addArrangedSubview(cancelButton ?? NSButton())
        }
        if (!cancelTitle.localized.isEmpty && !confirmTitle.localized.isEmpty){
            let separator = NSView()
            separator.wantsLayer = true
            // 设置分隔线颜色（与按钮左侧边框同色）
            separator.layer?.backgroundColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.1).cgColor
            separator.translatesAutoresizingMaskIntoConstraints = false
            btns.addSubview(separator)
            separator.snp.makeConstraints { make in
                make.leading.trailing.centerY.equalToSuperview()
                make.height.equalTo(1)
            }
        }
        if (!confirmTitle.localized.isEmpty){
            btns.addArrangedSubview(trueButton ?? NSButton())
        }
        
        bgView.addSubview(btns)
        btns.snp.makeConstraints { make in
            make.trailing.top.bottom.equalTo(0)
            make.width.equalTo(80)
        }
   
//        cancelButton?.snp.makeConstraints {
//            make in
//            make.trailing.top.equalTo(0)//.offset(0)
//            make.width.equalTo(78)
//            make.height.equalTo(cancelTitle.localized.isEmpty ? 0 : (confirmTitle.localized.isEmpty ? windowHeight:35))
//        }
//        trueButton?.snp.makeConstraints {
//            make in
//            make.trailing.bottom.equalTo(0)
//            make.width.equalTo(78)
//            make.height.equalTo(confirmTitle.localized.isEmpty ? 0: (cancelTitle.localized.isEmpty ? windowHeight:35))
//        }
        
        // 添加关闭按钮
        closeBtn = NSButton(title: "×", target: self, action: #selector(closeButtonClicked))
        closeBtn?.bezelStyle = .circular
        closeBtn?.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        closeBtn?.contentTintColor = NSColor.gray
        closeBtn?.isHidden = !isShowCloseBtn
        containerView.addSubview(closeBtn ?? NSButton())
        
        closeBtn?.snp.makeConstraints { make in
            make.centerX.equalTo(bgView.snp.trailing)
            make.centerY.equalTo(bgView.snp.top)
            make.width.height.equalTo(30)
        }
    
        
        ownPhotoView?.snp.makeConstraints {
            make in
            make.leading.equalTo(bgView.snp.leading).offset(10)
            make.centerY.equalToSuperview()
            make.width.equalTo(36)
            make.height.equalTo(36)
        }
        nameLabel.snp.makeConstraints {
            make in
            make.leading.equalTo(ownPhotoView?.snp.trailing ?? 0).offset(10)
            make.centerY.equalToSuperview()
            make.width.lessThanOrEqualTo(230)
        }
       
    }
    private func addLeftBorder(to view: NSView, color: NSColor, width: CGFloat) {
        let leftBorder = CALayer()
        leftBorder.backgroundColor = color.cgColor
        leftBorder.frame = CGRect(x: 0, y: 0, width: width, height: view.bounds.height)
        // 确保边框高度随按钮变化
        leftBorder.autoresizingMask = [.layerHeightSizable]
        view.layer?.addSublayer(leftBorder)
    }

    // 关闭按钮点击事件
    @objc private func closeButtonClicked() {
        self.close()
    }
    

    @objc func trueButtonClicked(_ sender: NSButton) {

        confirmAction?()
        self.close()
    }

    @objc func cancelButtonClicked(_ sender: NSButton) {
        cancelAction?()
        self.close()
    }
    
    
   
    
    // MARK: - 显示弹窗方法
    func showModal(in window: NSWindow? = nil,
                   confirmHandler: (() -> Void)? = nil,
                   cancelHandler: (() -> Void)? = nil) {
//        func showModal(in window: NSWindow? = nil,
//                       title:String = "" ,
//                       confirmTitle: String? = "确定".localized,
//                       confirmHandler: (() -> Void)? = nil,
//                       cancelTitle: String? = "取消".localized,
//                       cancelHandler: (() -> Void)? = nil) {
//        nameLabel.stringValue = title
//        
//        trueButton?.attributedTitle = NSAttributedString(string: confirmTitle?.localized ?? "", attributes: trueAttributes)
//        cancelButton?.attributedTitle = NSAttributedString(string: "拒绝".localized, attributes: cancelAttributes)
        
        self.confirmAction = confirmHandler
        self.cancelAction = cancelHandler
        
    
        
        //TODO:需要传进 用户id。展示不同的头像
        MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader("",false,deviceTye: 1)
//        ownPhotoView?.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader(self.userInfo?.hwId ?? "",self.userInfo?.isShowIcon ?? false)
        
       
        
//        orderBack(nil)
        let screenFrame = getScreenSize()
        let panelX = screenFrame.width - self.rect.width // 15 是距离屏幕右边缘的间距
        let panelY = screenFrame.height - self.rect.height // 15 是距离屏幕底边缘的间距
        self.setFrameOrigin(NSPoint(x: panelX, y: panelY))
        self.makeKeyAndOrderFront(nil)
//        if let parentWindow = window {
//            parentWindow.beginSheet(self) { _ in }
//        }
        //else {
//            NSApplication.shared.runModal(for: self)
//        }
    }
}


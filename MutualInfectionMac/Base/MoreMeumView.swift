//
//  MoreMeumView.swift
//  MutualInfection
//
//  Created by 1234 on 2025/9/25.
//

import AppKit

class MoreMeumView: NSView {
    var isDeviceNameChange:Bool = Gloable.isNotSendingStatus
    var deviceNameButton: NSButton?
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.black
        ]
        
        let titleLabel:NSTextField = {
            let lab = NSTextField(labelWithString: "")
            lab.attributedStringValue = NSAttributedString(string: "高速传输模式".localized, attributes: attributes)
            lab.font = .mi.pingFangSCMedium(size: 13)
            lab.alignment = AppLanguage.isRTL ? .right : .left
            lab.maximumNumberOfLines = 0
//            lab.font = NSFont.systemFont(ofSize: 13)
//            lab.preferredMaxLayoutWidth = 72
            lab.textColor = NSColor.black
            lab.wantsLayer = true
//            lab.layer?.backgroundColor = NSColor.red.cgColor
//            lab.translatesAutoresizingMaskIntoConstraints = false
            if let cell = lab.cell {
                cell.wraps = true
                cell.isScrollable = false
                cell.lineBreakMode = .byWordWrapping
            }
            return lab
        }()
        
//        self.addSubview(titleLabel)
        
        let subtitleLabel:NSTextField = {
            let lab = NSTextField(labelWithString: "开启后，每次传输都将直连华为设备 WLAN".localized)
            lab.alignment = AppLanguage.isRTL ? .right : .left
            lab.maximumNumberOfLines = 0
            lab.font = NSFont.systemFont(ofSize: 11)
//            lab.preferredMaxLayoutWidth = 72
            lab.textColor = NSColor.secondaryLabelColor
            lab.wantsLayer = true
//            lab.layer?.backgroundColor = NSColor.red.cgColor
//            lab.translatesAutoresizingMaskIntoConstraints = false
            if let cell = lab.cell {
                cell.wraps = true
                cell.isScrollable = false
                cell.lineBreakMode = .byCharWrapping
            }
            return lab
        }()
        
//        self.addSubview(subtitleLabel)
        // 创建开关
        let switchButton:NSSwitch = {
            let switchbtn = NSSwitch()
            switchbtn.target = self
            switchbtn.action = #selector(switchChanged(_:))
            switchbtn.state = UserDefaults.standard.bool(forKey: speedMode) ? .on : .off
            
//            let scaleFactor: CGFloat = 0.6
//            switchbtn.wantsLayer = true
//            switchbtn.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
//            switchbtn.layer?.transform = CATransform3DMakeScale(scaleFactor, scaleFactor, 1.0)
            
            return switchbtn
        }()
        
        let bgV:NSView = {
            let v = NSView()
            v.wantsLayer = true
//            v.layer?.backgroundColor = NSColor.green.cgColor
            return v
        }() 
        bgV.addSubview(titleLabel)
        bgV.addSubview(subtitleLabel)
        bgV.addSubview(switchButton)
        
        self.addSubview(bgV)
        
        let highSpeedLine:NSView = {
           let v = NSView()
            v.wantsLayer = true
            v.layer?.backgroundColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.08).cgColor
            return v
        }()
        
        bgV.addSubview(highSpeedLine)
        
        deviceNameButton = {
           let btn = NSButton(title: "设备名称".localized, target: self, action:#selector(deviceNameClicked))
            btn.wantsLayer = true
            if(isDeviceNameChange) {
                btn.alphaValue = 1
            } else {
                btn.alphaValue = 0.3
            }
            btn.alignment = AppLanguage.isRTL ? .right : .left
            btn.cell?.wraps = true// 设置换行模式
//            btn.cell?.lineBreakMode = .byWordWrapping
            btn.layer?.backgroundColor = NSColor.clear.cgColor
            btn.isBordered = false // 去除默认边框
            btn.attributedTitle = NSAttributedString(string: "设备名称".localized, attributes: attributes)
            return btn
        }()
        self.addSubview(deviceNameButton!)
        
        let deviceNameLine:NSView = {
            let v = NSView()
            v.wantsLayer = true
            v.layer?.backgroundColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.08).cgColor
            return v
        }()
        self.addSubview(deviceNameLine)
        
        let recordButton:NSButton = {
           let btn = NSButton(title: "互传记录".localized, target: self, action:#selector(recordButtonClicked))
            btn.alignment = AppLanguage.isRTL ? .right : .left
            btn.cell?.wraps = true// 设置换行模式
//            btn.cell?.lineBreakMode = .byWordWrapping
            btn.wantsLayer = true
            btn.layer?.backgroundColor = NSColor.clear.cgColor
            btn.isBordered = false // 去除默认边框
            btn.attributedTitle = NSAttributedString(string: "互传记录".localized, attributes: attributes)
            return btn
        }() 
        self.addSubview(recordButton)
        
        let recordLine:NSView = {
           let v = NSView()
            v.wantsLayer = true
            v.layer?.backgroundColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.08).cgColor
            return v
        }()
        self.addSubview(recordLine)
        
        let helpButton:NSButton = {
           let btn = NSButton(title: "帮助与反馈".localized, target: self, action:#selector(helpButtonClicked))
            btn.wantsLayer = true
            btn.alignment = AppLanguage.isRTL ? .right : .left
            btn.cell?.wraps = true// 设置换行模式
//            btn.cell?.lineBreakMode = .byWordWrapping
            btn.layer?.backgroundColor = NSColor.clear.cgColor
            btn.isBordered = false // 去除默认边框
            btn.attributedTitle = NSAttributedString(string: "帮助与反馈".localized, attributes: attributes)
            return btn
        }()
        self.addSubview(helpButton)
        
        let heltLine:NSView = {
            let v = NSView()
            v.wantsLayer = true
            v.layer?.backgroundColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.08).cgColor
            return v
        }()
        self.addSubview(heltLine)
        
        let permissionButton:NSButton = {
           let btn = NSButton(title: "系统权限管理".localized, target: self, action:#selector(permissionButtonClicked))
            btn.wantsLayer = true
            btn.alignment = AppLanguage.isRTL ? .right : .left
            btn.cell?.wraps = true// 设置换行模式
//            btn.cell?.lineBreakMode = .byWordWrapping
            btn.layer?.backgroundColor = NSColor.clear.cgColor
            btn.isBordered = false // 去除默认边框
            btn.attributedTitle = NSAttributedString(string: "系统权限管理".localized, attributes: attributes)
            return btn
        }() 
        self.addSubview(permissionButton)
        
        let permissionLine:NSView = {
            let v = NSView()
            v.wantsLayer = true
            v.layer?.backgroundColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.08).cgColor
            return v
        }()
        self.addSubview(permissionLine)
        
        let aboutButton:NSButton = {
           let btn = NSButton(title: "关于".localized, target: self, action:#selector(aboutButtonClicked))
            btn.wantsLayer = true
            btn.alignment = AppLanguage.isRTL ? .right : .left
            btn.cell?.wraps = true// 设置换行模式
//            btn.cell?.lineBreakMode = .byWordWrapping
            btn.layer?.backgroundColor = NSColor.clear.cgColor
            btn.isBordered = false // 去除默认边框
            btn.attributedTitle = NSAttributedString(string: "关于".localized, attributes: attributes)
            return btn
        }()
        self.addSubview(aboutButton)
        
        // 创建一个类似 UILabel 的标签
        let badge:NSView = {
            let v = NSView()
            v.wantsLayer = true
            // 设置图层
            v.layer?.cornerRadius = 5
            v.layer?.backgroundColor = NSColor.red.cgColor
            v.isHidden = true
            return v
        }()
        
        self.addSubview(badge)
        AppVersionChecker().getLatestVersionFromAppStore(appID: "6753906811") { version in
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            ShareAPI.shared().log(1, "获取当前版本号=====\(currentVersion)")  
            ShareAPI.shared().log(1, "获取最新版本号=====\(version ?? "")")  
            if let version = version {
                let isUpNew = AppVersionChecker().chechVersion(nowVer: currentVersion, newVer: version)
                if isUpNew {
                    badge.isHidden = false
                }else{
                    badge.isHidden = true
                }
            }
        }
        
        let topBottomMargin = 12
        bgV.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview()
        }
        titleLabel.snp.makeConstraints {
            make in
            make.top.equalTo(topBottomMargin + 2)
            make.leading.equalTo(16)
//            make.height.equalTo(88)
            make.trailing.equalTo(-60)
        }
        
        subtitleLabel.snp.makeConstraints {
            make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.leading.equalToSuperview().offset(16)
//            make.width.equalTo(100)
            make.trailing.equalToSuperview().offset(-60)
        }
        
        switchButton.snp.makeConstraints {
            make in
            make.centerY.equalToSuperview().offset(-4.6)
            make.trailing.equalToSuperview().offset(10)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let scaleFactor: CGFloat = 0.7
            switchButton.wantsLayer = true
            switchButton.layer?.anchorPoint = CGPoint(x: 0.3, y: 0.1)
            switchButton.layer?.transform = CATransform3DMakeScale(scaleFactor, scaleFactor, 1.0)
        }
        
        highSpeedLine.snp.makeConstraints {
            make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(topBottomMargin)
            make.leading.equalTo(self.snp.leading).offset(16)
//            make.width.equalTo(168)
            make.trailing.equalToSuperview().offset(-17)
            make.height.equalTo(1)
            make.bottom.equalToSuperview()
        }
        
        deviceNameButton?.snp.makeConstraints {
            make in
            make.top.equalTo(highSpeedLine.snp.bottom).offset(topBottomMargin)
            make.leading.equalTo(self.snp.leading).offset(16)
            make.trailing.equalToSuperview().offset(-17)
//            make.width.equalTo(168)
//            make.height.equalTo(36)
        }
        
        deviceNameLine.snp.makeConstraints {
            make in
            make.top.equalTo((deviceNameButton?.snp.bottom)!).offset(topBottomMargin)
            make.leading.equalTo(self.snp.leading).offset(16)
//            make.width.equalTo(168)
            make.trailing.equalToSuperview().offset(-17)
            make.height.equalTo(1)
        }

        recordButton.snp.makeConstraints {
            make in
            make.top.equalTo(deviceNameLine.snp.bottom).offset(topBottomMargin)
            make.leading.equalTo(self.snp.leading).offset(16)
            make.trailing.equalToSuperview().offset(-17)
//            make.width.equalTo(168)
//            make.height.equalTo(36)
        }
        recordLine.snp.makeConstraints {
            make in
            make.top.equalTo(recordButton.snp.bottom).offset(topBottomMargin)
            make.leading.equalTo(self.snp.leading).offset(16)
//            make.width.equalTo(168)
            make.trailing.equalToSuperview().offset(-17)
            make.height.equalTo(1)
        }
        helpButton.snp.makeConstraints {
            make in
            make.top.equalTo(recordLine.snp.bottom).offset(topBottomMargin)
            make.leading.equalTo(self.snp.leading).offset(16)
            make.trailing.equalToSuperview().offset(-17)
//            make.width.equalTo(168)
//            make.height.equalTo(36)
        }
        heltLine.snp.makeConstraints {
            make in
            make.top.equalTo(helpButton.snp.bottom).offset(topBottomMargin)
            make.leading.equalTo(self.snp.leading).offset(16)
//            make.width.equalTo(168)
            make.trailing.equalToSuperview().offset(-17)
            make.height.equalTo(1)
        }
        permissionButton.snp.makeConstraints {
            make in
            make.top.equalTo(heltLine.snp.bottom).offset(topBottomMargin)
            make.leading.equalTo(self.snp.leading).offset(16)
            make.trailing.equalToSuperview().offset(-17)
//            make.width.equalTo(168)
//            make.height.equalTo(36)
        }
        permissionLine.snp.makeConstraints {
            make in
            make.top.equalTo(permissionButton.snp.bottom).offset(topBottomMargin)
            make.leading.equalTo(self.snp.leading).offset(16)
//            make.width.equalTo(168)
            make.trailing.equalToSuperview().offset(-17)
            make.height.equalTo(1)
        }
        aboutButton.snp.makeConstraints {
            make in
            make.top.equalTo(permissionLine.snp.bottom).offset(topBottomMargin)
            make.leading.equalTo(self.snp.leading).offset(16)
            make.trailing.equalToSuperview().offset(-17)
//            make.width.equalTo(168)
//            make.height.equalTo(36)
            make.bottom.equalTo(-1 * topBottomMargin - 2)
        }
        badge.snp.makeConstraints { make in
            make.centerY.equalTo(aboutButton)
            make.trailing.equalTo(aboutButton)
            make.width.height.equalTo(10)
        }
        
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGetStatus(_:)),
            name: Notification.Name("GetIsSendingStatus"),
            object: nil
        )
    }
    @objc func handleGetStatus(_ notification: Notification) {
        isDeviceNameChange = Gloable.isNotSendingStatus
        if(isDeviceNameChange) {
            deviceNameButton?.alphaValue = 1
        } else {
            deviceNameButton?.alphaValue = 0.3
        }
    }
    @objc func switchChanged(_ sender: NSSwitch) {
        print("开关状态: \(sender.state == .on ? "开" : "关")")
        if sender.state == .on {
            UserDefaults.standard.set(true, forKey: speedMode)
            ShareAPI.shared().setSpeedMode(true)
        }else{
            UserDefaults.standard.set(false, forKey: speedMode)
            ShareAPI.shared().setSpeedMode(false)
        }
    }
    @objc func switchOpenChanged(_ sender: NSSwitch) {
        print("开关状态: \(sender.state == .on ? "开" : "关")")
        if sender.state == .on {
            UserDefaults.standard.set(true, forKey: openDevice)
        }else{
            UserDefaults.standard.set(false, forKey: openDevice)
        }
    }
    //点击名称不关窗口
    @objc func openClicked() {
        Gloable.isMoreMeumShow=true
        self.isHidden=false
    }
    //设备名称
    @objc func deviceNameClicked() {
        if(!isDeviceNameChange) {
            return
        }
        Gloable.isMoreMeumShow=false
        self.isHidden=true
        let page=PagesCall(upWindow:self.findUpperController()?.view.window)
        page.deviceNameWindowShow()
    }
    //互传记录
    @objc func recordButtonClicked() {
        Gloable.isMoreMeumShow=false
        self.isHidden=true
        let page=PagesCall(upWindow:self.findUpperController()?.view.window)
        page.transmitRecordWindowShow()
    }
    //帮助与反馈页面
    @objc func helpButtonClicked() {
        Gloable.isMoreMeumShow=false
        self.isHidden=true
        let page=PagesCall(upWindow:self.findUpperController()?.view.window)
        page.helpWindowShow()
    }
    //系统权限管理页面
    @objc func permissionButtonClicked() {
        Gloable.isMoreMeumShow=false
        self.isHidden=true
        let page=PagesCall(upWindow:self.findUpperController()?.view.window)
        page.permissionWindowShow()
    }
    //关于页面
    @objc func aboutButtonClicked() {
        Gloable.isMoreMeumShow=false
        self.isHidden=true
        let page=PagesCall(upWindow:self.findUpperController()?.view.window)
        page.aboutWindowShow()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    deinit{
        NotificationCenter.default.removeObserver(self)
    }
    
}
//寻找上层调用
extension NSView {
    func findUpperController() -> NSViewController? {
        var responder: NSResponder? = self.nextResponder
        while responder != nil {
            if let vc = responder as? NSViewController {
                return vc
            }
            responder = responder?.nextResponder
        }
        return nil
    }
}


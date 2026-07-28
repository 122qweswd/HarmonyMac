//
//  AgreementWindowController.swift
//  MutualInfection
//
//  Created by 1234 on 2025/9/29.
//

import Cocoa
import AppKit

class AgreementWindowController: NSViewController, NSTextViewDelegate {
    private var mainWindowCall: MainWindowCall?
    var cancelButton :NSButton!
    var trueButton :NSButton!
    
    let userAgreement: String = "鸿蒙星河互联用户协议".localized
    let permissionUsageInstructions: String = "权限使用说明".localized
    let permissionUsageInstructionsLinkUrl: String = "permissionUsageInstructionsLinkUrl"
    let privacyStatement: String = "关于鸿蒙星河互联与隐私的声明".localized
    let permissionUsageInstructionsViewController: MIPermissionUsageInstructionsViewController = MIPermissionUsageInstructionsViewController()

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 705, height: 499))
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        //self.view=NSView(frame: NSRect(x: 0, y: 0, width: 705, height: 499))
        
        let imageView = NSImageView()
        imageView.image = NSImage(named: "darkIcon")
        // 启用图层支持
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 8.0
        imageView.layer?.masksToBounds = true
        view.addSubview(imageView)
        
        let declarationLabel = NSTextField(labelWithString: "协议与声明".localized)
        declarationLabel.font = .mi.pingFangSCSemibold(size: 30)
        declarationLabel.textColor = .mi.hex("#000000")
        declarationLabel.alignment = .center
        view.addSubview(declarationLabel)
        
        let agreementView = NSView()
        agreementView.wantsLayer = true  // 必须启用图层
        agreementView.layer?.backgroundColor = NSColor(red: 255/255.0, green: 255/255.0, blue: 255/255.0, alpha: 1.0).cgColor
        agreementView.layer?.cornerRadius = 10
        view.addSubview(agreementView)
        
        let agreementLabel = createClickableTextView()
        agreementLabel.alignment = .left
        agreementLabel.font = .mi.pingFangSCRegular(size: 16)
        agreementLabel.textColor = .mi.hex("#000000",alpha: 0.6)
        agreementView.addSubview(agreementLabel)
        
        let cancelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor(red: 0/255.0, green: 0/255.0, blue: 0/255.0, alpha: 0.5)
        ]
        cancelButton = NSButton(title: "取消".localized, target: self, action:#selector(cancelButtonClicked(_:)))
        cancelButton.sendAction(on: [.leftMouseDown, .leftMouseUp])
        cancelButton.wantsLayer = true
        cancelButton.layer?.backgroundColor = NSColor(red: 0/255.0, green: 0/255.0, blue: 0/255.0, alpha: 0.1).cgColor
        cancelButton.isBordered = false // 去除默认边框
        cancelButton.layer?.cornerRadius = 8  // 圆角半径值
        cancelButton.layer?.masksToBounds = true
        cancelButton.attributedTitle = NSAttributedString(string: "取消".localized, attributes: cancelAttributes)
        view.addSubview(cancelButton)
        
        let trueAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor(red: 255/255.0, green: 255/255.0, blue: 255/255.0, alpha: 1.0)
        ]
        trueButton = NSButton(title: "加入".localized, target: self, action:#selector(trueButtonClicked(_:)))
        trueButton.sendAction(on: [.leftMouseDown, .leftMouseUp])
        trueButton.wantsLayer = true
        trueButton.layer?.backgroundColor = NSColor(red: 0/255.0, green: 122/255.0, blue: 255/255.0, alpha: 1.0).cgColor
        trueButton.isBordered = false // 去除默认边框
        trueButton.layer?.cornerRadius = 8  // 圆角半径值
        trueButton.layer?.masksToBounds = true
        trueButton.attributedTitle = NSAttributedString(string: "同意".localized, attributes: trueAttributes)
        view.addSubview(trueButton)
        
        imageView.snp.makeConstraints {
            make in
            make.top.equalTo(view.snp.top).offset(34)
            make.centerX.equalToSuperview()
            make.width.equalTo(45)
            make.height.equalTo(45)
        }
        declarationLabel.snp.makeConstraints {
            $0.leading.equalTo(15)
            $0.trailing.equalTo(-15)
            $0.top.equalTo(imageView.snp.bottom).offset(16)
        }
        agreementView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(declarationLabel.snp.bottom).offset(24)
            make.width.equalTo(645)
            make.height.equalTo(262)
        }
        agreementLabel.snp.makeConstraints {
            make in
            make.top.equalTo(24)
            make.bottom.equalTo(-24)
            make.leading.equalTo(20)
            make.trailing.equalTo(-20)
        }
        cancelButton.snp.makeConstraints {
            make in
            make.width.equalTo(110)
            make.height.equalTo(28)
            make.bottom.equalToSuperview().offset(-24)
            make.leading.equalToSuperview().offset(238)
        }
        trueButton.snp.makeConstraints {
            make in
            make.bottom.equalToSuperview().offset(-24)
            make.leading.equalTo(view.snp.leading).offset(356)
            make.width.equalTo(110)
            make.height.equalTo(28)
        }
    }
    @objc func trueButtonClicked(_ sender: NSButton) {
        guard let event = NSApp.currentEvent else { return }
        switch event.type {
            case .leftMouseDown:
                trueButton.layer?.backgroundColor = NSColor(red: 65/255.0, green: 105/255.0, blue: 225/255.0, alpha: 1.0).cgColor
                UserDefaults.standard.set("true", forKey: "AgreementKey")
                if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                    if appDelegate.mainWindowCall == nil {
                        mainWindowCall = MainWindowCall()
                        mainWindowCall?.showWindow()
                        appDelegate.mainWindowCall = mainWindowCall;
                    }else {
                        appDelegate.mainWindowCall?.showWindow()
                    }
                }
                self.view.window?.close()
            case .leftMouseUp:
                trueButton.layer?.backgroundColor = NSColor(red: 0/255.0, green: 122/255.0, blue: 255/255.0, alpha: 1.0).cgColor
            default: break
        }
        
    }
    @objc func cancelButtonClicked(_ sender: NSButton) {
        guard let event = NSApp.currentEvent else { return }
        switch event.type {
            case .leftMouseDown:
                cancelButton.layer?.backgroundColor = NSColor(red: 0/255.0, green: 0/255.0, blue: 0/255.0, alpha: 0.3).cgColor
                UserDefaults.standard.set("false", forKey: "AgreementKey")
                self.view.window?.close()
            case .leftMouseUp:
                cancelButton.layer?.backgroundColor = NSColor(red: 0/255.0, green: 0/255.0, blue: 0/255.0, alpha: 0.1).cgColor
            default: break
        }
    }
    
    func createClickableTextView() -> NSTextView {
        let textView = NSTextView(frame: .zero)
        
        textView.isEditable = false
        textView.isSelectable = true
        
        let preFullText = "本服务需使用蓝牙、WLAN连接并收发数据，读取图片、视频、联系人和文件等信息，获取网络信息，我们仅在使用具体业务功能时才触发上述行为收集使用相关的个人信息。本服务为您提供鸿蒙星河互联的基本业务功能。点击“同意”，即表示您同意".localized
        let fullText = "\(preFullText)\(userAgreement)、\(privacyStatement)。"

        let attributedString = NSMutableAttributedString(string: fullText)
        
        let language = getCurrentLanguage()
        
        let userAgreementRange = (fullText as NSString).range(of: userAgreement)
        var userAgreementLinkUrl: String? = MIAppUrlLink.getUserAgreementLink() .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        if let userAgreementLink = URL(string: userAgreementLinkUrl ?? "") {
            attributedString.addAttribute(.link, value: userAgreementLink, range: userAgreementRange)
        }
        
//        let permissionUsageInstructionsRange = (fullText as NSString).range(of: permissionUsageInstructions)
//        if let permissionUsageInstructionsLink = URL(string: permissionUsageInstructionsLinkUrl) {
//            attributedString.addAttribute(.link, value: permissionUsageInstructionsLink, range: permissionUsageInstructionsRange)
//        }
        
        let privacyStatementRange = (fullText as NSString).range(of: privacyStatement)
        var privacyStatementLinkUrl: String? = MIAppUrlLink.getStatementHarmonyOSInterconnectPrivacyLink().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        if let privacyStatementLink = URL(string: privacyStatementLinkUrl ?? "") {
            attributedString.addAttribute(.link, value: privacyStatementLink, range: privacyStatementRange)
        }
        
        // 设置所有链接的统一样式
        textView.linkTextAttributes = [
            .foregroundColor: NSColor.mi.hex("#0a59f7"), // 修改链接颜色
            .underlineStyle: 0 // 去除下划线
        ]
        
        textView.textStorage?.setAttributedString(attributedString)
        textView.delegate = self
        
        return textView
    }
    
    // MARK: - NSTextViewDelegate
    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard let url = link as? URL else {
            return false
        }
        print("点击了链接: \(url.absoluteString)")

        if url.absoluteString == permissionUsageInstructionsLinkUrl {
            showPermissionUsageInstructionsViewController()
            return true
        }
        
        NSWorkspace.shared.open(url)
        return true
    }
    
    func getCurrentLanguage() -> String {
        return Locale.preferredLanguages.first ?? "en"
    }
    
    func showPermissionUsageInstructionsViewController() {
        addChild(permissionUsageInstructionsViewController)
        view.addSubview(permissionUsageInstructionsViewController.view)
        permissionUsageInstructionsViewController.view.isHidden = false
    }
}

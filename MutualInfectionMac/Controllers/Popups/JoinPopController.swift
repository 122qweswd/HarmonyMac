//
//  Join.swift
//  MutualInfection
//
//  Created by 1234 on 2025/9/26.
//

import Cocoa
import AppKit

class JoinPopController: NSViewController {
    var cancelButton :NSButton!
    var trueButton :NSButton!
    var userName:String!//用户名
    var fileCount:String!//文件数
    var fileSize:String!//文件大小
    init(userName: String = "",fileCount: String = "",fileSize: String = "") {
        self.userName=userName
        self.fileCount=fileCount
        self.fileSize=fileSize
        super.init(nibName: nil, bundle: nil)
    }
    override func loadView() {
        self.view=NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 199))
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        //self.view=NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 199))
        
        let iconImageView = NSImageView()
        iconImageView.image = NSImage(named: "img_logo")
        view.addSubview(iconImageView)
        
        let joinLabel = NSTextField(labelWithString: "鸿蒙互传“想要加入无线局域")
        joinLabel.font = .mi.pingFangSCMedium(size: 13)
        joinLabel.textColor = .mi.hex("#000000")
        view.addSubview(joinLabel)
        
        let nameLabel = NSTextField(labelWithString: "网”xxxxx“吗？")
        nameLabel.font = .mi.pingFangSCMedium(size: 13)
        nameLabel.textColor = .mi.hex("#000000")
        view.addSubview(nameLabel)
        
        let cancelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor(red: 0/255.0, green: 0/255.0, blue: 0/255.0, alpha: 0.5)
        ]
        cancelButton = NSButton(title: "取消", target: self, action:#selector(cancelButtonClicked(_:)))
        cancelButton.sendAction(on: [.leftMouseDown, .leftMouseUp])
        cancelButton.wantsLayer = true
        cancelButton.layer?.backgroundColor = NSColor(red: 0/255.0, green: 0/255.0, blue: 0/255.0, alpha: 0.1).cgColor
        cancelButton.isBordered = false // 去除默认边框
        cancelButton.layer?.cornerRadius = 8  // 圆角半径值
        cancelButton.layer?.masksToBounds = true
        cancelButton.attributedTitle = NSAttributedString(string: "取消", attributes: cancelAttributes)
        view.addSubview(cancelButton)
        
        let trueAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor(red: 255/255.0, green: 255/255.0, blue: 255/255.0, alpha: 1.0)
        ]
        trueButton = NSButton(title: "加入", target: self, action:#selector(trueButtonClicked(_:)))
        trueButton.sendAction(on: [.leftMouseDown, .leftMouseUp])
        trueButton.wantsLayer = true
        trueButton.layer?.backgroundColor = NSColor(red: 0/255.0, green: 122/255.0, blue: 255/255.0, alpha: 1.0).cgColor
        trueButton.isBordered = false // 去除默认边框
        trueButton.layer?.cornerRadius = 8  // 圆角半径值
        trueButton.layer?.masksToBounds = true
        trueButton.attributedTitle = NSAttributedString(string: "加入", attributes: trueAttributes)
        view.addSubview(trueButton)
        
        iconImageView.snp.makeConstraints {
            make in
            make.top.equalTo(view.snp.top).offset(28)
            make.centerX.equalToSuperview()
            make.width.equalTo(52)
            make.height.equalTo(52)
        }
        joinLabel.snp.makeConstraints {
            make in
            make.top.equalTo(view.snp.top).offset(107)
            make.centerX.equalToSuperview()
        }
        nameLabel.snp.makeConstraints {
            make in
            make.top.equalTo(view.snp.top).offset(122)
            make.centerX.equalToSuperview()
        }
        cancelButton.snp.makeConstraints {
            make in
            make.top.equalTo(view.snp.top).offset(150)
            make.leading.equalTo(view.snp.leading).offset(16)
            make.width.equalTo(110)
            make.height.equalTo(28)
        }
        trueButton.snp.makeConstraints {
            make in
            make.top.equalTo(view.snp.top).offset(150)
            make.leading.equalTo(view.snp.leading).offset(130)
            make.width.equalTo(110)
            make.height.equalTo(28)
        }
    }
    @objc func trueButtonClicked(_ sender: NSButton) {
        guard let event = NSApp.currentEvent else { return }
        switch event.type {
            case .leftMouseDown:
                trueButton.layer?.backgroundColor = NSColor(red: 65/255.0, green: 105/255.0, blue: 225/255.0, alpha: 1.0).cgColor
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
            case .leftMouseUp:
                cancelButton.layer?.backgroundColor = NSColor(red: 0/255.0, green: 0/255.0, blue: 0/255.0, alpha: 0.1).cgColor
            default: break
        }
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

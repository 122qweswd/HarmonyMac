//
//  CompleteReceptcontroller.swift
//  MutualInfection
//
//  Created by 1234 on 2025/9/26.
//

import Cocoa
import AppKit

class CompleteReceptPopController: NSViewController {
    var recordButton :NSButton!
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
        self.view=NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 241))
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        //self.view=NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 241))
        
        let ownPhotoView = CustomImageView(imageName: "profile", size: NSSize(width: 52, height: 52))
        view.addSubview(ownPhotoView)
        
        let completeLabel = NSTextField(labelWithString: "接收完成")
        completeLabel.font = .mi.pingFangSCMedium(size: 13)
        completeLabel.textColor = .mi.hex("#000000")
        view.addSubview(completeLabel)
        
        let nameLabel = NSTextField(labelWithString: "来自xxx的")
        nameLabel.font = .mi.pingFangSCRegular(size: 11)
        nameLabel.textColor = .mi.hex("#000000")
        view.addSubview(nameLabel)
        
        let filesLabel = NSTextField(labelWithString: "100个文件（3.6G）")
        filesLabel.font = .mi.pingFangSCRegular(size: 11)
        filesLabel.textColor = .mi.hex("#000000")
        view.addSubview(filesLabel)
        
        let recordAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor(red: 255/255.0, green: 255/255.0, blue: 255/255.0, alpha: 1.0)
        ]
        recordButton = NSButton(title: "接收记录".localized, target: self, action:#selector(recordButtonClicked(_:)))
        recordButton.sendAction(on: [.leftMouseDown, .leftMouseUp])
        recordButton.wantsLayer = true
        recordButton.layer?.backgroundColor = NSColor(red: 0/255.0, green: 122/255.0, blue: 255/255.0, alpha: 1.0).cgColor
        recordButton.isBordered = false // 去除默认边框
        recordButton.layer?.cornerRadius = 8  // 圆角半径值
        recordButton.layer?.masksToBounds = true
        recordButton.attributedTitle = NSAttributedString(string: "接收记录".localized, attributes: recordAttributes)
        view.addSubview(recordButton)
        
        ownPhotoView.snp.makeConstraints {
            make in
            make.top.equalTo(view.snp.top).offset(28)
            make.centerX.equalToSuperview()
            make.width.equalTo(52)
            make.height.equalTo(52)
        }
        completeLabel.snp.makeConstraints {
            make in
            make.top.equalTo(view.snp.top).offset(107)
            make.centerX.equalToSuperview()
        }
        nameLabel.snp.makeConstraints {
            make in
            make.top.equalTo(view.snp.top).offset(140)
            make.centerX.equalToSuperview()
        }
        filesLabel.snp.makeConstraints {
            make in
            make.top.equalTo(view.snp.top).offset(155)
            make.centerX.equalToSuperview()
        }
        recordButton.snp.makeConstraints {
            make in
            make.top.equalTo(view.snp.top).offset(190)
            make.centerX.equalToSuperview()
            make.width.equalTo(228)
            make.height.equalTo(28)
        }
    }
    @objc func recordButtonClicked(_ sender: NSButton) {
        guard let event = NSApp.currentEvent else { return }
        switch event.type {
            case .leftMouseDown:
                recordButton.layer?.backgroundColor = NSColor(red: 65/255.0, green: 105/255.0, blue: 225/255.0, alpha: 1.0).cgColor
            case .leftMouseUp:
                recordButton.layer?.backgroundColor = NSColor(red: 0/255.0, green: 122/255.0, blue: 255/255.0, alpha: 1.0).cgColor
            default: break
        }
        
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

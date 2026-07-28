//
//  UpdatePopController.swift
//  MutualInfection
//
//  Created by 1234 on 2025/9/29.
//

import Cocoa
import AppKit
class UpdatePopController: NSViewController {
    var trueButton :NSButton!
    var lable:String!//更新弹窗内容
    var buttonLable:String!//更新弹窗按钮文字
    init(lable: String = "",buttonLable: String = "") {
        self.lable=lable
        self.buttonLable=buttonLable
        super.init(nibName: nil, bundle: nil)
    }
    override func loadView() {
        self.view=NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 97))
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        //self.view=NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 97))
        
        let Label = NSTextField(labelWithString: "已是最新版本")
        Label.font = .mi.pingFangSCMedium(size: 13)
        Label.textColor = .mi.hex("#000000")
        view.addSubview(Label)
        
        let trueAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor(red: 255/255.0, green: 255/255.0, blue: 255/255.0, alpha: 1.0)
        ]
        trueButton = NSButton(title: "确定", target: self, action:#selector(trueButtonClicked(_:)))
        trueButton.sendAction(on: [.leftMouseDown, .leftMouseUp])
        trueButton.wantsLayer = true
        trueButton.layer?.backgroundColor = NSColor(red: 0/255.0, green: 122/255.0, blue: 255/255.0, alpha: 1.0).cgColor
        trueButton.isBordered = false // 去除默认边框
        trueButton.layer?.cornerRadius = 8  // 圆角半径值
        trueButton.layer?.masksToBounds = true
        trueButton.attributedTitle = NSAttributedString(string: "确定", attributes: trueAttributes)
        view.addSubview(trueButton)
        
        Label.snp.makeConstraints {
            make in
            make.top.equalTo(view.snp.top).offset(22)
            make.centerX.equalToSuperview()
        }
        trueButton.snp.makeConstraints {
            make in
            make.top.equalTo(view.snp.top).offset(48)
            make.centerX.equalToSuperview()
            make.width.equalTo(228)
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
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

//
//  CancelReceptController.swift
//  MutualInfection
//
//  Created by 1234 on 2025/9/25.
//

import Cocoa
import AppKit

class CancelReceptPopController: NSViewController {

    var cancelPageOkBtn: NSButton!
    var cancelPageCancelBtn: NSButton!
    var cancelPageImageView: NSImageView!
    var cancelPageLabel: NSTextField!
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 375, height: 69))
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        //view = NSView(frame: NSRect(x: 0, y: 0, width: 375, height: 69))
        
        cancelPageImageView = NSImageView()
        cancelPageImageView.image = NSImage.imgCritical
        cancelPageImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancelPageImageView)
        
        cancelPageLabel = NSTextField(labelWithString: "确认要取消接收吗？".localized)
        cancelPageLabel.font = .mi.pingFangSCMedium(size: 13)
        cancelPageLabel.textColor = .mi.hex("#000000")
        if let textFieldCell = cancelPageLabel.cell as? NSTextFieldCell {
            textFieldCell.lineBreakMode = .byWordWrapping
        }
        view.addSubview(cancelPageLabel)
        
        let cancelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor(red: 0, green: 0, blue: 0, alpha: 0.85)
        ]
        cancelPageCancelBtn = NSButton(title: "cancelReceivingAlertBtn".localized, target: self, action:#selector(cancelPageCancelBtnClicked(_:)))
        // cancelPageCancelBtn.sendAction(on: [.leftMouseDown, .leftMouseUp])
        cancelPageCancelBtn.wantsLayer = true
        cancelPageCancelBtn.layer?.backgroundColor = NSColor.clear.cgColor
        cancelPageCancelBtn.isBordered = false
        cancelPageCancelBtn.layer?.borderWidth = 1.0
        cancelPageCancelBtn.layer?.borderColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.1).cgColor
        cancelPageCancelBtn.layer?.cornerRadius = 0
        cancelPageCancelBtn.layer?.masksToBounds = true
        cancelPageCancelBtn.layer?.cornerRadius = 10
        cancelPageCancelBtn.layer?.maskedCorners = [.layerMaxXMinYCorner]
        cancelPageCancelBtn.attributedTitle = NSAttributedString(string: "cancelReceivingAlertBtn".localized, attributes: cancelAttributes)
        view.addSubview(cancelPageCancelBtn)
        
        let trueAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor(red: 0, green: 0, blue: 0, alpha: 0.85)
        ]
        cancelPageOkBtn = NSButton(title: "继续接收".localized, target: self, action:#selector(cancelPageOkBtnClicked(_:)))
        // cancelPageOkBtn.sendAction(on: [.leftMouseDown, .leftMouseUp])
        cancelPageOkBtn.wantsLayer = true
        cancelPageOkBtn.layer?.backgroundColor = NSColor.clear.cgColor
        cancelPageOkBtn.isBordered = false
        cancelPageOkBtn.layer?.borderWidth = 1.0
        cancelPageOkBtn.layer?.borderColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.1).cgColor
        cancelPageOkBtn.layer?.cornerRadius = 0
        cancelPageOkBtn.layer?.masksToBounds = true
        cancelPageOkBtn.layer?.cornerRadius = 10
        cancelPageOkBtn.layer?.maskedCorners = [.layerMaxXMaxYCorner]
        cancelPageOkBtn.attributedTitle = NSAttributedString(string: "继续接收".localized, attributes: trueAttributes)
        view.addSubview(cancelPageOkBtn)
     
        cancelPageImageView.snp.makeConstraints {
            make in
            make.leading.equalTo(view.snp.leading).offset(10)
            make.centerY.equalToSuperview()
            make.width.equalTo(36)
            make.height.equalTo(36)
        }
        cancelPageLabel.snp.makeConstraints {
            make in
            make.leading.equalTo(view.snp.leading).offset(56)
            make.centerY.equalToSuperview()
            make.width.lessThanOrEqualTo(230)
        }
        cancelPageCancelBtn.snp.makeConstraints {
            make in
            make.trailing.equalTo(view.snp.trailing).offset(0)
            make.top.equalTo(view.snp.top).offset(0)
            make.width.equalTo(78)
            make.height.equalTo(35)
        }
        cancelPageOkBtn.snp.makeConstraints {
            make in
            make.trailing.equalTo(view.snp.trailing).offset(0)
            make.bottom.equalTo(view.snp.bottom).offset(0)
            make.width.equalTo(78)
            make.height.equalTo(35)
        }
    }
    
    // 继续接收点击事件
    @objc func cancelPageOkBtnClicked(_ sender: NSButton) {
        receivePageManger?.switchCancelPage(isShow: false)
    }
    
    // 取消接收弹框---取消点击事件
    @objc func cancelPageCancelBtnClicked(_ sender: NSButton) {
        receivePageManger?.stopReceptPopController?.cancelReceiveShare()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

//
//  RecvErrorPopController.swift
//  MutualInfection
//
//  接收 error 提示
//

import Cocoa
import AppKit

class RecvErrorPopController: NSViewController {

    var okBtn: NSButton!
    var image: NSImageView!
    var messageLabel: NSTextField!
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    func setMessage(message: String) {
        messageLabel.stringValue = message
        receivePageManger?.stopReceptPopController?.cancelRecv()
        receivePageManger?.switchToViewController(ofType: .errorPop)
    }
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 373, height: 68))
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        //view = NSView(frame: NSRect(x: 0, y: 0, width: 373, height: 68))
        
        image = NSImageView()
        image.image = NSImage.imgCritical
        image.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(image)
        
        messageLabel = NSTextField(labelWithString: "")
        messageLabel.font = .mi.pingFangSCMedium(size: 13)
        messageLabel.textColor = .mi.hex("#000000")
        if let textFieldCell = messageLabel.cell as? NSTextFieldCell {
            textFieldCell.lineBreakMode = .byWordWrapping
        }
        view.addSubview(messageLabel)
        
        let trueAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor(red: 0, green: 0, blue: 0, alpha: 0.85)
        ]
        okBtn = NSButton(title: "知道了".localized, target: self, action:#selector(okBtnClicked(_:)))
        // okBtn.sendAction(on: [.leftMouseDown, .leftMouseUp])
        okBtn.wantsLayer = true
        okBtn.layer?.backgroundColor = NSColor.clear.cgColor
        okBtn.isBordered = false
        okBtn.layer?.borderWidth = 1.0
        okBtn.layer?.borderColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.1).cgColor
        okBtn.layer?.cornerRadius = 10
        okBtn.layer?.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        okBtn.layer?.masksToBounds = true
        okBtn.attributedTitle = NSAttributedString(string: "知道了".localized, attributes: trueAttributes)
        view.addSubview(okBtn)
     
        image.snp.makeConstraints {
            make in
            make.leading.equalTo(view.snp.leading).offset(10)
            make.centerY.equalToSuperview()
            make.width.equalTo(36)
            make.height.equalTo(36)
        }
        messageLabel.snp.makeConstraints {
            make in
            make.leading.equalTo(view.snp.leading).offset(56)
            make.centerY.equalToSuperview()
            make.width.lessThanOrEqualTo(230)
        }
        okBtn.snp.makeConstraints {
            make in
            make.trailing.equalTo(view.snp.trailing).offset(1)
            make.centerY.equalToSuperview()
            make.width.equalTo(78)
            make.height.equalTo(70)
        }
    }
    
    @objc func okBtnClicked(_ sender: NSButton) {
        receivePageManger?.close()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

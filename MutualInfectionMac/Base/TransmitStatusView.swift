//
//  TransmitStatusView.swift
//  MutualInfection
//
//  Created by 1234 on 2025/9/28.
//

import AppKit

class TransmitStatusView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        let consumerPhotoView = CustomImageView(size: NSSize(width: 52, height:52))
        self.addSubview(consumerPhotoView)
        
        let circularProgress=CircularProgressView()
        circularProgress.setProgress(0.7, animated: true, duration: 1.0)
        circularProgress.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(circularProgress)

        let textField=NSTextField(labelWithString: "Iphone16手机都放好地方")
        textField.alignment = .center
        textField.maximumNumberOfLines = 2
        textField.font = .mi.pingFangSCMedium(size: 11)
        textField.preferredMaxLayoutWidth = 72
        textField.cell?.wraps = true
        textField.cell?.lineBreakMode = .byWordWrapping
        textField.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(textField)
        
        let cancelStateLabel = NSTextField(labelWithString: "已取消")
        cancelStateLabel.font = .mi.pingFangSCRegular(size: 11)
        cancelStateLabel.textColor = .mi.hex("#E02020")
        cancelStateLabel.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(cancelStateLabel)
        cancelStateLabel.topAnchor.constraint(equalTo: self.topAnchor, constant: 92).isActive = true
        cancelStateLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        
//        let successStateLabel = NSTextField(labelWithString: "发送成功")
//        successStateLabel.font = .mi.pingFangSCRegular(size: 11)
//        successStateLabel.textColor = .mi.hex("#0A59F7")
//        successStateLabel.translatesAutoresizingMaskIntoConstraints = false
//        self.addSubview(successStateLabel)
//        successStateLabel.topAnchor.constraint(equalTo: self.topAnchor, constant: 92).isActive = true
//        successStateLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
//
//        let sendStateLabel = NSTextField(labelWithString: "发送中...")
//        sendStateLabel.font = .mi.pingFangSCRegular(size: 11)
//        sendStateLabel.textColor = .mi.hex("#0A59F7")
//        sendStateLabel.translatesAutoresizingMaskIntoConstraints = false
//        self.addSubview(sendStateLabel)
//        sendStateLabel.topAnchor.constraint(equalTo: self.topAnchor, constant: 92).isActive = true
//        sendStateLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
//        
//        let connectStateLabel = NSTextField(labelWithString: "发送中...")
//        connectStateLabel.font = .mi.pingFangSCRegular(size: 11)
//        connectStateLabel.textColor = .mi.hex("#0A59F7")
//        connectStateLabel.translatesAutoresizingMaskIntoConstraints = false
//        self.addSubview(connectStateLabel)
//        connectStateLabel.topAnchor.constraint(equalTo: self.topAnchor, constant: 92).isActive = true
//        connectStateLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        
        
        NSLayoutConstraint.activate([
            consumerPhotoView.widthAnchor.constraint(equalToConstant: 52),
            consumerPhotoView.heightAnchor.constraint(equalToConstant: 52),
            consumerPhotoView.topAnchor.constraint(equalTo: self.topAnchor, constant: 8),
            consumerPhotoView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            textField.widthAnchor.constraint(equalToConstant: 72),
            textField.heightAnchor.constraint(equalToConstant: 32),
            textField.topAnchor.constraint(equalTo: self.topAnchor, constant: 62),
            textField.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            circularProgress.widthAnchor.constraint(equalToConstant: 65),
            circularProgress.heightAnchor.constraint(equalToConstant: 65),
            circularProgress.topAnchor.constraint(equalTo: self.topAnchor, constant: 0),
            circularProgress.centerXAnchor.constraint(equalTo: self.centerXAnchor),
        ])
        
    }
//    override func mouseDown(with event: NSEvent) {
//        print("Mouse down at \(event.locationInWindow)")
//        if(!Gloable.isMoreMeumShow){
//            let sender = FileSender()
//            sender.selectAndSendFile()
//        }
//    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

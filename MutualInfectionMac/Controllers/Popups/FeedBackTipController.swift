//
//  FeedBackTipController.swift
//  MutualInfection
//
//  Created by 1234 on 2025/11/8.
//

//import Cocoa
//import AppKit
//
//class FeedBackTipController: NSViewController {
//    
//    var tipLabel : String //提示
//    var imageName : String //图片名
//    init(tipLabel: String = "",imageName: String = "") {
//        self.tipLabel=tipLabel
//        self.imageName=imageName
//        super.init(nibName: nil, bundle: nil)
//    }
//    
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        self.view=NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 181))
//        let imageView = NSImageView()
//        imageView.image = NSImage(named: imageName)
//        imageView.translatesAutoresizingMaskIntoConstraints = false
//        view.addSubview(imageView)
//        
//        let Label = NSTextField(labelWithString: tipLabel)
//        Label.font = .mi.pingFangSCMedium(size: 13)
//        Label.textColor = .mi.hex("#000000")
//        Label.translatesAutoresizingMaskIntoConstraints = false
//        view.addSubview(Label)
//        
//        imageView.snp.makeConstraints {
//            make in
//            make.leading.equalTo(view.snp.leading).offset(10)
//            make.centerX.equalToSuperview()
//            make.width.equalTo(36)
//            make.height.equalTo(36)
//        }
//        Label.snp.makeConstraints {
//            make in
//            make.leading.equalTo(view.snp.leading).offset(56)
//            make.centerX.equalToSuperview()
//            make.width.lessThanOrEqualTo(230)
//        }
//    }
//}


import Cocoa
import AppKit

class FeedBackTipController: NSViewController {
    var tipLabel : String //提示
    var imageName : String //图片名
    init(tipLabel: String = "",imageName: String = "") {
        self.tipLabel=tipLabel
        self.imageName=imageName
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func loadView() {
        self.view=NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 160))
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        //self.view=NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 160))
        let imageView = NSImageView()
        imageView.image = NSImage(named: self.imageName)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        
        let Label = NSTextField(labelWithString: self.tipLabel)
        Label.font = .mi.pingFangSCMedium(size: 13)
        Label.textColor = .mi.hex("#000000")
        Label.translatesAutoresizingMaskIntoConstraints = false
        Label.alignment = .center
        Label.maximumNumberOfLines = 0
        view.addSubview(Label)
        
        imageView.snp.makeConstraints {
            make in
            make.top.equalTo(view.snp.top).offset(22)
            make.centerX.equalToSuperview()
            make.width.equalTo(64)
            make.height.equalTo(64)
        }
        Label.snp.makeConstraints {
            make in
            make.top.equalTo(view.snp.top).offset(107)
            make.leading.equalTo(15)
            make.trailing.equalTo(-15)
        }
    }
}

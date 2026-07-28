//
//  PermissionController.swift
//  MutualInfection
//
//  Created by 1234 on 2025/9/25.
//

import Cocoa
import AppKit
import Photos
import Contacts
import CoreLocation

class PermissionController: NSViewController {
    private let locationManager = CLLocationManager()
    private let headView = NSView()
    private let closeButton = NSButton(title: "关闭", target: nil, action:#selector(closeButtonClicked))
    private let headLabel = NSTextField(labelWithString: "系统权限管理".localized)
    
    private let dataSourseArr: [[String: String]] = {
        let arr = [
            ["title": "访问位置".localized, "subTitle": "用于判断是否处于同一局域网".localized, "type": "1"],
            ["title": "访问照片".localized, "subTitle": "用于互传时读取照片、视频等文件".localized, "type": "2"],
            ["title": "蓝牙".localized, "subTitle": "用于使用蓝牙搜索附近的设备".localized, "type": "4"],
        ]
        
        return arr
    }()
    private let borderBgView: NSView = {
        let view = NSView(frame: .zero)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.mi.hex("#FFFFFF", alpha: 1).cgColor
        //NSColor.red.cgColor
        //NSColor.mi.hex("#FFFFFF", alpha: 1).cgColor
//        view.layer?.cornerRadius = 4
//        view.layer?.masksToBounds = true
//        view.layer?.borderColor = NSColor.mi.hex("#000000", alpha: 0.2).cgColor
//        view.layer?.borderWidth = 1
        return view
    }()
    override func loadView() {
        self.view=NSView(frame: NSRect(x: 0, y: 0, width: 367, height: 416))
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavi()
        setupUI()
    }
    private func setupNavi() {
        //self.view=NSView(frame: NSRect(x: 0, y: 0, width: 367, height: 416))
        headView.wantsLayer = true  // 必须启用图层
        headView.layer?.backgroundColor = NSColor(red: 245/255.0, green: 245/255.0, blue: 245/255.0, alpha: 0.8).cgColor
        headView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headView)
        closeButton.setButtonType(.momentaryPushIn)
        closeButton.isBordered = false // 关键属性，禁用系统边框样式
        closeButton.wantsLayer = true // 启用图层支持
        closeButton.image = NSImage(named: "icon_close")
        closeButton.layer?.cornerRadius = 8
        closeButton.imageScaling = .scaleNone
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        headView.addSubview(closeButton)
        headLabel.font = .mi.pingFangSCRegular(size: 13)
        headLabel.textColor = .mi.hex("#000000")
        headLabel.translatesAutoresizingMaskIntoConstraints = false
        headView.addSubview(headLabel)
        
        // 使用SnapKit设置约束
        headView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.width.equalTo(367)
            make.height.equalTo(40)
        }
        
        headLabel.snp.makeConstraints { make in
            make.top.equalTo(headView).offset(12)
            make.centerX.equalTo(headView)
        }
        
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(headView).offset(12)
            make.leading.equalTo(headView).offset(17)
            make.width.height.equalTo(18)
        }
    }
    private func setupUI() {
        
        view.addSubview(borderBgView)
        borderBgView.snp.makeConstraints { make in
            make.top.equalTo(headView.snp.bottom).offset(4)
            make.leading.equalTo(4)
            make.trailing.equalTo(-4)
        }
        
        var tempPermissionSubView: PermissionSubView?
        for (index, dict) in dataSourseArr.enumerated() {
            let subView = PermissionSubView(frame: .zero)
            subView.valueDict = dict
            // 判断是否是最后一行
            subView.isLastRow = (index == dataSourseArr.count - 1)
            subView.onClick = { [weak self] valueDict in
                switch valueDict["type"] {
                case "1":
                    self?.openLocationSettings()
                case "2":
                    self?.openPhotosSettings()
                case "4":
                    self?.openBluetoothSettings()
                
                default:
                    self?.openSettings()
                }
            }
            borderBgView.addSubview(subView)
            subView.snp.makeConstraints { make in
                if let tempPermissionSubView = tempPermissionSubView {
                    make.top.equalTo(tempPermissionSubView.snp.bottom)
                }else {
                    make.top.equalToSuperview()
                }
                make.leading.trailing.equalToSuperview()
                if dataSourseArr.count - 1 == index {
                    make.bottom.equalToSuperview()
                }
            }
            tempPermissionSubView = subView
        }
    }
    @objc func closeButtonClicked() {
        self.view.window?.close()
    }
    private func openLocationSettings(){
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
            NSWorkspace.shared.open(url)
        }
    }
    private func openPhotosSettings(){
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos") {
            NSWorkspace.shared.open(url)
        }
    }
    private func openContactsSettings(){
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts") {
            NSWorkspace.shared.open(url)
        }
    }
    private func openWiFiSettings(){
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.network?Wi-Fi") {
            NSWorkspace.shared.open(url)
        }
    }
    private func openSettings(){
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(url)
        }
    }
    private func openBluetoothSettings(){
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth") {
            NSWorkspace.shared.open(url)
        }
    }
    private func openStorageSettings(){
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders") {
            NSWorkspace.shared.open(url)
        }
    }
    /// 位置权限
    private func locationPermission() {
        
        // 请求权限
        if CLLocationManager.locationServicesEnabled() {
            switch CLLocationManager.authorizationStatus() {
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization() // 或 requestAlwaysAuthorization()
//            case .authorizedWhenInUse, .authorizedAlways:// 已授权
                
            case .denied, .restricted:// 引导用户到设置
                showPermissionAlert()
            default:
                showPermissionAlert()
            }
        }
    }
    /// 照片权限
    private func photoPermission() {

        // 检查权限状态
        if #available(macOS 11, *) {
            let photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            
            switch photoStatus {
                //        case .authorized:// 已授权，执行操作
                
                
            case .notDetermined:// 请求授权
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                    DispatchQueue.main.async {
                        if status == .authorized {// 用户授权
                            
                            
                        } else {// 用户拒绝
                            
                            self.showPermissionAlert()
                        }
                    }
                }
            case .denied, .restricted:// 引导用户到设置
                showPermissionAlert()
            default:
                showPermissionAlert()
            }
        } else {
            // Fallback on earlier versions
        }
        
    }
    /// 通讯录权限
    private func contactListPermission() {

        let contactStore = CNContactStore()

        // 请求权限
        switch CNContactStore.authorizationStatus(for: .contacts) {
//        case .authorized:// 已授权
            
        case .notDetermined:// 未授权
            contactStore.requestAccess(for: .contacts) { granted, error in
                DispatchQueue.main.async {
                    if granted {// 用户授权
                        
                    } else {// 用户拒绝
                        
                    }
                }
            }
        case .denied, .restricted:// 引导用户到设置
            showPermissionAlert()
        default:
            showPermissionAlert()
        }
    }
    func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "需要访问权限".localized
        alert.informativeText = "请在系统设置中授予权限。".localized
        alert.addButton(withTitle: "打开设置".localized)
        alert.addButton(withTitle: "取消".localized)
        
        if alert.runModal() == .alertFirstButtonReturn {
            // 打开系统设置
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!)
        }
    }
}

class PermissionSubView: NSView {
    var onClick: (([String: String]) -> Void)?
    var isLastRow: Bool = false {
        didSet {
            // 当 isLastRow 被设置时，更新 lineView 的可见性
            lineView.isHidden = isLastRow
        }
    }
    var valueDict: [String: String] = [:] {
        didSet {
            titleLabel.stringValue = valueDict["title"] ?? ""
            subTitleLabel.stringValue = valueDict["subTitle"] ?? ""
        }
    }
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        setupUI()
        
    }
    private func setupUI() {
        // 添加所有子视图
        [titleLabel, subTitleLabel, rightArrowView, lineView].forEach {
            addSubview($0)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(9)
            make.leading.equalToSuperview().offset(13)
            make.height.equalTo(20)
            make.trailing.lessThanOrEqualTo(rightArrowView.snp.leading).offset(-8)
        }
        subTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom)
            make.leading.equalTo(titleLabel)
            make.trailing.equalTo(-25)
//            make.width.equalTo(320)
            make.height.equalTo(20)
        }
        // 向右箭头约束：距离最右边12，上下居中
        rightArrowView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(10)
        }
        lineView.snp.makeConstraints { make in
            make.top.equalTo(subTitleLabel.snp.bottom).offset(9)
            make.leading.equalTo(12)
            make.trailing.equalTo(-12)
            make.bottom.equalToSuperview()
            make.height.equalTo(1)
        }
        
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        clickGesture.numberOfClicksRequired = 1
        self.addGestureRecognizer(clickGesture)
        
    }
    @objc private func handleClick(_ gesture: NSClickGestureRecognizer) {// 确保手势状态是结束状态
        if gesture.state == .ended {
            onClick?(valueDict)
        }
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //=================================================================
    //                            lazy
    //=================================================================
    // MARK: - lazy
    private lazy var titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "访问位置")
        label.textColor = NSColor.mi.hex("#000000", alpha: 0.9)
        label.font = NSFont.mi.pingFangSCMedium(size: 13)
        label.isEditable = false
        label.isSelectable = false
        return label
    }()
    private lazy var subTitleLabel: MIMacMarqueeTextField = {
//        let label = NSTextField(labelWithString: "用于判断是否处一同一局域网")
        let label = MIMacMarqueeTextField.getCommonMacMarqueeTextField(labelWithString: "用于判断是否处一同一局域网")
        label.textColor = NSColor.mi.hex("#000000", alpha: 0.6)
        label.font = NSFont.mi.pingFangSCRegular(size: 11)
        label.isEditable = false
        label.isSelectable = false
        // 设置省略号和固定宽度
//        label.lineBreakMode = .byTruncatingTail
//        label.maximumNumberOfLines = 1
//        label.preferredMaxLayoutWidth = 280
        return label
    }()
    
    // 向右箭头视图
    private lazy var rightArrowView: NSImageView = {
        let imageView = NSImageView(frame: .zero)
        
        // 在macOS中使用系统图标
       
            // macOS 11+ 可以使用SF Symbols
        if #available(macOS 11.0, *) {
            if let symbolImage = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "") {
                imageView.image = symbolImage
                imageView.contentTintColor = NSColor.mi.hex("#000000", alpha: 0.6)
            }
        } else {
            if let symbolImage = NSImage(named: "chevron.right"){
                imageView.image = symbolImage
                imageView.contentTintColor = NSColor.mi.hex("#000000", alpha: 0.6)
            }
        }
       
        
        // 设置内容模式
        imageView.imageScaling = .scaleProportionallyUpOrDown
        
        return imageView
    }()
    
    private lazy var lineView: NSView = {
        let lineView = NSView(frame: .zero)
        lineView.wantsLayer = true
        lineView.layer?.backgroundColor = NSColor.mi.hex("#000000", alpha: 0.2).cgColor
        return lineView
    }()
}

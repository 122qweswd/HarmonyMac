//
//  Stop.swift
//  MutualInfection
//
//  MAC 接收页面
//

import AppKit
import Cocoa

class StopReceptPopController: NSViewController {
    
    // 本地记录是否触发自己取消接收
    var localIsCancel = false
    var imageCount = 0
    var videoCount = 0
    var fileCount = 0
    // 缩略图接收是否成功
    var recvBase64IsScuccess = false
    // 接收文件总大小
    var totalBytes: Int?
    var upWindow:NSWindow!
    // 文件是否接收完毕
    var isFinish: Bool = false
    // 文件接收类型：0-媒体 3-文件  4-文件夹
    var senderType: String = ""
    // 记录大文件
    var allFilesList: [AnyHashable: Any] = [:]
    // 记录小文件
    var allSmallFIlesList: [String] = []
    var manger: ShareAPI? = ShareAPI.shared()
    var udid: String?
    var hwid: String?
    var metadata: [AnyHashable: Any]? = [:] {
        didSet {
            if let senderName = metadata?["senderName"] as? String {
                self.senderInfoLabel.stringValue = "来自".localized + senderName
            }
        }
    }
    
    // 落盘
    var directoryType: String?
    var lastFileUrl: String?
    
    // 多文件堆叠图标
    private lazy var filesImageView: NSImageView = {
        let imageView = NSImageView()
        imageView.wantsLayer = true
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.image = NSImage.iconOverlap
        imageView.layer?.masksToBounds = true
        imageView.layer?.cornerRadius = 20
        imageView.isHidden = true
        return imageView
    }()

    // 多图片堆叠图标
    private lazy var mediaImageView: NSImageView = {
        let imageView = NSImageView()
        imageView.wantsLayer = true
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.image = NSImage.bgImages
        imageView.layer?.masksToBounds = true
        imageView.layer?.cornerRadius = 20
        imageView.isHidden = true
        return imageView
    }()

    // 文件图标缩略图
    private lazy var thumbnailImageView: NSImageView = {
//        let imageView = NSImageView()
        let imageView = ScaleAspectFillImageView()
        imageView.wantsLayer = true
        imageView.image = NSImage(named: "icon_device")
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.layer?.masksToBounds = true
        imageView.layer?.cornerRadius = 5
        return imageView
    }()
    
    // 导入中进度
    private lazy var importingLabel: MIMacMarqueeTextField = {
        let label = MIMacMarqueeTextField.getCommonMacMarqueeTextField()
        label.backgroundColor = NSColor.white
        label.font = .mi.pingFangSCRegular(size: 13)
        label.textColor = .mi.hex("＃336FFF")
        label.stringValue = "请不要退出当前页面".localized
        label.alignment = .center
        label.resetScrollOnTextChange = false
        label.isHidden = true
        return label
    }()
    
    // 发送者信息标签
    private lazy var senderInfoLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .mi.pingFangSCMedium(size: 13)
        label.textColor = .mi.hex("#000000")
        label.isHidden = true
        return label
    }()
    
    // 文件信息标签
    private lazy var fileInfoLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .mi.pingFangSCMedium(size: 11)
        label.textColor = .mi.hex("#000000")
        label.isHidden = true
        return label
    }()
    
    // 接收 error 展示
    private lazy var errorMessageLabel: NSTextField = {
        let label = NSTextField(labelWithString: "接收取消".localized)
        label.font = .mi.pingFangSCMedium(size: 13)
        label.textColor = .red
        label.isHidden = true
        return label
    }()
    
    // 连接提示
    private lazy var connectLabel: NSTextField = {
        let label = NSTextField(labelWithString: "正在连接对方热点".localized)
        label.font = .mi.pingFangSCMedium(size: 13)
        label.alignment = .left
	    label.textColor = .black
        label.alphaValue = 0.65
        if let cell = label.cell {
            cell.wraps = true
            cell.isScrollable = false
            cell.lineBreakMode = .byWordWrapping
        }
        return label
    }()
    
    // 取消接收按钮
    private lazy var cancelButton: NSButton = {
        let button = NSButton(title: "取消".localized, target: self, action: #selector(cancelButtonClicked(_:)))
        // button.sendAction(on: [.leftMouseDown, .leftMouseUp])
        button.wantsLayer = true
        button.isBordered = false // 去除默认边框
        button.layer?.borderWidth = 1.0
        button.layer?.borderColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.1).cgColor
        button.layer?.cornerRadius = 10 // 圆角半径值
        button.layer?.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        button.layer?.masksToBounds = true
        button.layer?.backgroundColor = NSColor.clear.cgColor
        let cancelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor(red: 0, green: 0, blue: 0, alpha: 0.85)
        ]
        button.attributedTitle = NSAttributedString(string: "取消".localized, attributes: cancelAttributes)
        return button
    }()
    
    // 查看历史记录按钮
    private lazy var histroyButton: NSButton = {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor(red: 0, green: 0, blue: 0, alpha: 0.85)
        ]
        let button = NSButton(title: "接收记录".localized, target: self, action: #selector(histroyButtonClicked(_:)))
        // button.sendAction(on: [.leftMouseDown, .leftMouseUp])
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.clear.cgColor
        button.isBordered = false
        button.layer?.borderWidth = 1.0
        button.layer?.borderColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.1).cgColor
        button.layer?.cornerRadius = 10
        button.layer?.maskedCorners = [.layerMaxXMaxYCorner]
        button.layer?.masksToBounds = true
        button.attributedTitle = NSAttributedString(string: "接收记录".localized, attributes: attributes)
        button.isHidden = true
        button.addCustomMarqueeLabel()
        button.stopMarqueeScrolling()
        
        return button
    }()
    
    // 文件跳转按钮
    private lazy var jumpDetailsBtn: NSButton = {
        let trueAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor(red: 0, green: 0, blue: 0, alpha: 0.65)
        ]
        let button = NSButton(title: "".localized, target: self, action: #selector(jumpDetailsClicked(_:)))
        // button.sendAction(on: [.leftMouseDown, .leftMouseUp])
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.clear.cgColor
        button.isBordered = false
        button.layer?.borderWidth = 1.0
        button.layer?.borderColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.1).cgColor
        button.layer?.cornerRadius = 10
        button.layer?.maskedCorners = [.layerMaxXMinYCorner]
        button.layer?.masksToBounds = true
        button.attributedTitle = NSAttributedString(string: "前往\"下载\"查看".localized, attributes: trueAttributes)
        button.isHidden = true
        button.addCustomMarqueeLabel()
        button.stopMarqueeScrolling()
        
        return button
    }()
    
    // 接收中页面相关
    var progressCircleView: LinearProgressView = {
        let view = LinearProgressView()
        view.isHidden = true
        view.wantsLayer = true
        view.progressColor = NSColor.systemBlue
        view.height = 6.0
        view.cornerRadius = 3.0
        return view
    }()
    private lazy var progressLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = NSColor(red: 0/255.0, green: 0/255.0, blue: 0/255.0, alpha: 0.6)
        return label
    }()
    
    init() {
        print("[StopReceptPopController] init")
        super.init(nibName: nil, bundle: nil)
    }

    func setData(upWindow:NSWindow, metadata: [AnyHashable : Any] = [:]) {
        print("[StopReceptPopController] setData")
        self.upWindow = upWindow
        self.metadata = metadata
        self.senderType = (metadata["sendType"] as? String) ?? "0"
        self.normalPage()
        
        // TODO 测试代码
//        Thread {
//            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0){
//                var test = 0.0
//                sleep(UInt32(1))
//                test += 1
//                
//                let stat: [AnyHashable : Any] = [
//                    "totalBytes": 200000,
//                    "totalTransfer": 199900 + test * 100,
//                    "fileList": "[ {\"filename\": \"test.png\", \"status\": \"completed\"},{\"filename\": \"test2.ppt\", \"status\": \"inprogress\"},{\"filename\": \"xxxx.abc\", \"status\": \"notstart\"}]"
//                ]
//                DispatchQueue.main.async {
//                    self.progressCircleView.isHidden = false
//                    self.thumbnailImageView.imageScaling = self.senderType == "3" ? .scaleProportionallyDown : .scaleNone
//                    self.senderInfoLabel.stringValue = "来自xxxx"
//                    self.connectLabel.isHidden = true
//                    let files = stat["fileList"] as? String ?? ""
//                    let fileList = self.getArrayFromJSONString(jsonString: files)
//                    if self.senderType == "3" {
//                        self.filesImageView.isHidden = fileList.count <= 1
//                    } else if self.senderType == "0" {
//                        self.mediaImageView.isHidden = fileList.count <= 1
//                        self.thumbnailImageView.image = NSImage.imgLogo
//                    }
//                    self.showFileInfo(stat: stat)
//                    self.senderInfoLabel.isHidden = false
//
//                    let values = stride(from: 0.1, through: 1.0, by: 0.1).map { $0 }
//                    for (index, value) in values.enumerated() {
//                        // 计算延迟时间，每个任务间隔1秒
//                        let delaySeconds = Double(index)
//                        
//                        DispatchQueue.main.asyncAfter(deadline: .now() + delaySeconds) {
//                            self.startProgressAnimation(progress: value)
//                        }
//                    }
//                }
//            }
//        }.start()
    }
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 375, height: 69))
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        print("[StopReceptPopController] viewDidLoad")
        //view = NSView(frame: NSRect(x: 0, y: 0, width: 373, height: 68))
        
        initRecvPageView()
    }

    // 初始化接收中页面
    private func initRecvPageView() {
        view.addSubview(progressCircleView)
        view.addSubview(progressLabel)
        view.addSubview(senderInfoLabel)
        view.addSubview(fileInfoLabel)
        view.addSubview(importingLabel)
        view.addSubview(cancelButton)
        view.addSubview(histroyButton)
        view.addSubview(jumpDetailsBtn)
        view.addSubview(filesImageView)
        view.addSubview(mediaImageView)
        view.addSubview(thumbnailImageView)
        view.addSubview(connectLabel)
        // 缩略图约束
        thumbnailImageView.snp.makeConstraints {
            make in
            make.leading.equalTo(view.snp.leading).offset(10)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(36)
        }
        // 发送者信息约束
        senderInfoLabel.snp.makeConstraints {
            make in
            make.leading.equalTo(view.snp.leading).offset(56)
            make.top.equalToSuperview().offset(15)
            make.width.lessThanOrEqualTo(230)
        }
        
        // 文件信息约束
        fileInfoLabel.snp.makeConstraints {
            make in
            make.top.equalTo(senderInfoLabel.snp.bottom).offset(5)
            make.leading.equalTo(senderInfoLabel.snp.leading).offset(0)
            make.trailing.equalTo(-110)
        }
        
        importingLabel.snp.makeConstraints { make in
            make.edges.equalTo(fileInfoLabel)
        }
        
        // 进度条约束
        progressCircleView.snp.makeConstraints {
            make in
            make.top.equalTo(senderInfoLabel.snp.bottom).offset(10)
            make.leading.equalTo(senderInfoLabel.snp.leading).offset(0)
            make.width.equalTo(191)
            make.height.equalTo(6)
        }
        // 进度文案约束
        progressLabel.snp.makeConstraints {
            make in
            make.leading.equalTo(progressCircleView.snp.trailing).offset(10)
            make.centerY.equalTo(progressCircleView)
        }
        // 取消接收按钮约束
        cancelButton.snp.makeConstraints {
            make in
            make.trailing.equalTo(view.snp.trailing).offset(0)
            make.centerY.equalToSuperview()
            make.width.equalTo(78)
            make.height.equalTo(70)
        }
        // 正在连接热点约束
        connectLabel.snp.makeConstraints { make in
            make.leading.equalTo(senderInfoLabel.snp.leading).offset(0)
            make.centerY.equalToSuperview()
            make.width.lessThanOrEqualTo(230)
        }
        // 接收记录按钮约束
        jumpDetailsBtn.snp.makeConstraints {
            make in
            make.trailing.equalTo(view.snp.trailing).offset(0)
            make.top.equalTo(view.snp.top).offset(0)
            make.width.equalTo(100)
            make.height.equalTo(35)
        }
        // 前往“xxx”查看按钮约束
        histroyButton.snp.makeConstraints {
            make in
            make.trailing.equalTo(view.snp.trailing).offset(0)
            make.bottom.equalTo(view.snp.bottom).offset(0)
            make.width.equalTo(100)
            make.height.equalTo(35)
        }
        // 多文件堆叠图标约束
        filesImageView.snp.makeConstraints {
            make in
            make.center.equalTo(self.thumbnailImageView)
            make.width.height.equalTo(42)
        }
        // 多图片堆叠图标约束
        mediaImageView.snp.makeConstraints {
            make in
            make.centerX.equalTo(self.thumbnailImageView)
            make.centerY.equalTo(self.thumbnailImageView.snp.centerY).offset(-8)
            make.width.height.equalTo(26)
        }
    }
    
    // 关闭按钮点击事件
    @objc private func closeButtonClicked() {
        receivePageManger?.close()
    }
    
    // 接收中界面显示或者隐藏
    private func showRecvPage(isHidden: Bool) {
        thumbnailImageView.isHidden = isHidden
        progressCircleView.isHidden = isHidden
        progressLabel.isHidden = isHidden
        senderInfoLabel.isHidden = isHidden
        fileInfoLabel.isHidden = isHidden
        cancelButton.isHidden = isHidden
        if !isHidden, !isFinish {
            fileInfoLabel.isHidden = true
        }
    }
    
    // 跳转图库、文管按钮点击事件
    @objc func jumpDetailsClicked(_ sender: NSButton) {
        receivePageManger?.showCloseBtn(isHidden: true)
        openImagePhotosOrFileFolder(isImagePhotos: SaveFileHandler.shared.isSavePhotoLibraryForMac)
    }
    
    func openImagePhotosOrFileFolder(isImagePhotos: Bool) {
        receivePageManger?.close()
        if isImagePhotos {
            if let photosURL = URL(string: "photos://") {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true  // 默认激活应用
                configuration.hides = false  // 不隐藏应用
                NSWorkspace.shared.open(photosURL, configuration: configuration)
            }
            return
        }
        
        if checkDownloadsAccessDirectly() {
            let paths = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)
            if let url = paths.first {
                NSWorkspace.shared.open(url)
            }
        } else {
            self.manger?.log(1, "[SaveFile] [StopReceptPopController] 没有权限访问下载文件夹")
            MIMACDownloadFolderManager().showErrorAlert(type: "下载")
        }
    }
    
    func checkDownloadsAccessDirectly() -> Bool {
        guard let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            return false
        }
        
        do {
            let _ = try FileManager.default.contentsOfDirectory(atPath: downloadsURL.path)
            return true
        } catch {
            return false
        }
    }

    func removeAllFiles() {
        // 删除落盘数据
        SaveFileHandler.shared.removeAllFiles()
    }
    
    // 查看历史记录按钮点击事件
    @objc func histroyButtonClicked(_ sender: NSButton) {
        receivePageManger?.close()
        receivePageManger?.showCloseBtn(isHidden: true)
        NotificationCenter.default.post(
            name: Notification.Name("MainWindowControllerShowTransmitRecord"),
            object: nil,
            userInfo: nil
        )
    }
    
    // 取消接收按钮点击事件
    @objc func cancelButtonClicked(_ sender: NSButton) {
        guard let event = NSApp.currentEvent else { return }
        switch event.type {
        case .leftMouseDown: break
//                cancelButton.layer?.backgroundColor = NSColor(red: 0/255.0, green: 0/255.0, blue: 0/255.0, alpha: 0.3).cgColor
        case .leftMouseUp: break
//                cancelButton.layer?.backgroundColor = NSColor(red: 0/255.0, green: 0/255.0, blue: 0/255.0, alpha: 0.1).cgColor
            default: break
        }
        self.showIsCancelAlert()
    }

    // 取消二次确认弹窗
    private func showIsCancelAlert() {
        if self.isFinish {
            return
        }
        receivePageManger?.switchCancelPage(isShow: true)
    }
    
    // 取消接收
    func cancelReceiveShare() {
        localIsCancel = true
        self.manger?.cancelReceiveShare(self.udid ?? "")
    }
                  
    func cancelRecv() {
        showRecvPage(isHidden: false)
        isRecvTask = false
        Gloable.isNotSendingStatus = true
        NotificationCenter.default.post(name: NSNotification.Name("GetIsSendingStatus"), object: nil)
        self.cancelRecvPage()
        // 取消删除落盘数据
        SaveFileHandler.shared.removeAllFiles()
    }
    
    // 取消接收页面
    func cancelRecvPage() {
        self.normalPage()
        self.errorMessageLabel.isHidden = false
        self.cancelButton.isHidden = true
        self.connectLabel.isHidden = true
        self.connectLabel.stopDotAnimation()
    }
    
    // 恢复初始页面
    func normalPage() {
        self.manger?.log(1, "[UI] [StopReceptPopController] normalPage")
        self.imageCount = 0
        self.videoCount = 0
        self.fileCount = 0
        self.isFinish = false
        self.fileInfoLabel.stringValue = ""
        self.fileInfoLabel.isHidden = true
        self.thumbnailImageView.image = NSImage(named: "icon_device")
        self.thumbnailImageView.layer?.cornerRadius = 5
        self.senderInfoLabel.isHidden = true
        self.progressCircleView.isHidden = true
        self.progressCircleView.progress = 0.0
        self.progressLabel.stringValue = ""
        self.progressLabel.isHidden = true
        self.filesImageView.isHidden = true
        self.mediaImageView.isHidden = true
        self.errorMessageLabel.isHidden = true
        self.connectLabel.isHidden = false
        self.cancelButton.isHidden = false
        
        self.importingLabel.isHidden = true
        self.importingLabel.stringValue = "请不要退出当前页面".localized
        self.histroyButton.isHidden = true
        self.histroyButton.stopMarqueeScrolling()
        self.jumpDetailsBtn.isHidden = true
        self.jumpDetailsBtn.stopMarqueeScrolling()
        
        receivePageManger?.showCloseBtn(isHidden: true)
    }
    
    // 文件接收完成页面
    private func finishPage() {
        self.isFinish = true
        if let isHidden = receivePageManger?.receptOrNotPopController?.view.isHidden {
            if !isHidden {
                return
            }
        }
        receivePageManger?.switchCancelPage(isShow: false)
        self.progressCircleView.isHidden = true
        self.errorMessageLabel.isHidden = true
        self.progressLabel.stringValue = ""
        self.progressLabel.isHidden = true
        self.senderInfoLabel.isHidden = false
        self.thumbnailImageView.isHidden = false
        self.cancelButton.isHidden = true
        
        self.histroyButton.isHidden = false
        self.histroyButton.restartMarqueeScrolling()
        getRecvFileTypeText()
        self.jumpDetailsBtn.isHidden = false
        self.jumpDetailsBtn.restartMarqueeScrolling()
        
        self.fileInfoLabel.isHidden = false
        
        // 使用NSAttributedString实现不同部分文本颜色差异化
        let itemCount =  (self.metadata?["itemCount"] as? String) ?? "0"
        let fileCount = (self.metadata?["fileCount"] as? String) ?? "0"
        let completed = "\(self.senderType == "4" ? fileCount : itemCount) " + "个文件接收完成".localized
        self.senderInfoLabel.stringValue = "接收完成".localized
        receivePageManger?.showCloseBtn(isHidden: false)
    }
    
    // 获取接收文件类型名称
    func getRecvFileTypeText() {
        let typeText = SaveFileHandler.shared.isSavePhotoLibraryForMac ? "照片" : "下载"
        let trueAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor(red: 0, green: 0, blue: 0, alpha: 0.65)
        ]
        self.jumpDetailsBtn.setMarqueeAttributedTitle(NSAttributedString(string: "前往\"\(typeText)\"查看".localized, attributes: trueAttributes))
    }
    
    // 开始进度动画
    private func startProgressAnimation(progress: CGFloat = 0) {
        DispatchQueue.main.async {
            print("[UI] [StopReceptPopController] startProgressAnimation progress: \(Int(100 * progress))")
            self.progressCircleView.progress = progress
            self.progressLabel.stringValue = "\(Int(100 * progress))%"
            if progress >= 1.0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2){
                    self.finishPage()
                }
            }
        }
    }
    
    func setConnectMessage(message: String) {
        connectLabel.startDotAnimation(baseText: message.localized)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// 落盘逻辑
extension StopReceptPopController {
    
    // 开始落盘创建空文件和句柄
    func startSaveFile(_ fileName: String) -> String? {
        if SaveFileHandler.shared.isSavePhotoLibraryForMac == false {
            return SaveFileHandler.shared.saveMacFileStart(fileName, "")
        }
        
        //媒体文件（存图库）
        if self.senderType == "0", SaveFileHandler.shared.allFilesPosition == "library" {
            self.directoryType = SaveFileHandler.shared.getFileTypeByFileName(fileName)
            if self.directoryType == "library_image" || self.directoryType == "library_video" {
                self.lastFileUrl = SaveFileHandler.shared.saveTempFileStart(fileName, self.directoryType!)
            } else if self.directoryType == "library_live_photo" {
                self.lastFileUrl = SaveFileHandler.shared.saveTempFileStart(fileName, "library_live_photo")
            } else if self.directoryType == "is_live_or_image" {
                self.lastFileUrl = SaveFileHandler.shared.saveTempFileStart(fileName, "is_live_or_image")
            } else {
                // 过滤其他匹配的媒体文件
                self.directoryType = "image"
                SaveFileHandler.shared.allFilesPosition = "file"
                self.lastFileUrl = SaveFileHandler.shared.saveMacFileStart(fileName, "")
            }
        } else if self.senderType == "0" {
            //媒体文件（存文管）
            self.directoryType = "image"
            self.lastFileUrl = SaveFileHandler.shared.saveMacFileStart(fileName, "")
        } else if self.senderType == "3" || self.senderType == "4" {
            //文件夹和文件（文管下，需要区分混合模式，图片文件夹，音乐文件夹，通讯录文件夹，文件夹（普通文件）存在在ohters中）
            self.directoryType = SaveFileHandler.shared.getFileTypeByFileName(fileName)
            if let allType = SaveFileHandler.shared.allFilesType {
                self.lastFileUrl = SaveFileHandler.shared.saveMacFileStart(fileName, "")
            } else {
                self.lastFileUrl = SaveFileHandler.shared.saveMacFileStart(fileName, "")
            }
        } else {
            self.directoryType = SaveFileHandler.shared.getFileTypeByFileName(fileName)
            self.lastFileUrl = SaveFileHandler.shared.saveMacFileStart(fileName, "")
        }
        return self.lastFileUrl
    }
    
    // 落盘结束
    func saveFileEnd(_ fileName: String, _ fileSize: Int64) {
        if SaveFileHandler.shared.isSavePhotoLibraryForMac,
           self.directoryType == "is_live_or_image" {
            guard let manger = self.manger else { return }
            guard let lastFileUrl = self.lastFileUrl else { return }
            // jpg动态图片需要返回给底层拆分
            if manger.isLivePhoto(lastFileUrl) {
                self.directoryType = "library_live_photo"
                SaveFileHandler.shared.imageType = "library_live_photo"
                SaveFileHandler.shared.clearFileParamCache(fileName, fileSize)
            } else {
                // 保存到图库
                self.directoryType = "library_image"
                SaveFileHandler.shared.imageType = "library_image"
                SaveFileHandler.shared.clearFileParamCache(fileName, fileSize)
            }
        } else {
            SaveFileHandler.shared.clearMacFileParamCache(fileName, fileSize)
        }
        self.directoryType = nil
        self.lastFileUrl = nil
    }
    
    func setProgress(_ progressValue: Float) {
        DispatchQueue.main.async {
            let progressValueStr = String(Int(progressValue * 100))
            self.importingLabel.stringValue = "正在导入至“照片”，请不要退出当前页面".localized + "(\(progressValueStr)%)"
        }
    }
    
    func performAsyncTask(_ file: String) async {
        self.manger?.log(1, "[SaveFile] [MIReceiveFilesView] 异步任务执行：\(Thread.current)")
        self.manger?.log(1, "[SaveFile] [MIReceiveFilesView] 接收结束开始落盘：\(file)")
        let freeSpace = StorageChecker.getFreeSpace()
        self.manger?.log(1, "[SaveFile] [MIReceiveFilesView] 剩余硬盘空间：\(StorageChecker.formattedFreeSpace(freeSpace))")
//        let totalSize = Int64(self.meta?["totalSize"] as! String) ?? 0
        // 媒体文件保存到图库落盘需要确保充足空间
        var isFreeSpace = true
        if self.senderType == "0" && SaveFileHandler.shared.allFilesPosition == "library" {
            //磁盘空间不足不能落盘
            isFreeSpace = SaveFileHandler.shared.checkSpace(freeSpace)
        }
        
        // 页面部分
        DispatchQueue.main.async {
            if self.senderType == "0", SaveFileHandler.shared.allFilesPosition == "library" {
                self.importingLabel.stringValue = "正在导入至“照片”，请不要退出当前页面".localized + "(0%)"
                self.importingLabel.isHidden = false
                self.jumpDetailsBtn.isHidden = true
            } else {
                self.importingLabel.isHidden = true
                self.jumpDetailsBtn.isHidden = false
            }
            self.cancelButton.isHidden = true
            self.histroyButton.isHidden = false
        }
        
        // 图库落盘前先保存未导入的记录
        if self.senderType == "0", SaveFileHandler.shared.allFilesPosition == "library" {
            do {
                try self.saveRecordNoImporting(SaveFileHandler.shared.tempFilePaths, SaveFileHandler.shared.tempFileSizeDict ?? [String: Int64]())
                self.manger?.log(1, "[SaveFile] [MIReceiveFilesView] 未导入接收记录结束写入")
            } catch {
                self.manger?.log(3, "[SaveFile] [MIReceiveFilesView] 未导入接收记录出错：\(error)")
            }
        }
        
        //异步线程中使用全局的延迟
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5){
            // 落盘结束
            SaveFileHandler.shared.saveFileTaskEnd(customprogress: {[weak self] progress in
                self?.setProgress(progress)
            }) {[weak self] allFileList, fileList, params, tempFileSizeDict in
                do {
                    guard let self = self else { return }
                    self.manger?.log(1, "[SaveFile] [MIReceiveFilesView] 接收记录开始写入")
                    SaveFileHandler.shared.isSaveFileing = false
                    DispatchQueue.main.async {
                        //延迟退出，防止结束太快，接收接收流程未走完
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2){
                            self.importingLabel.isHidden = true
                            self.importingLabel.stringValue = "正在导入至“照片”，请不要退出当前页面".localized + "(0%)"
                            self.cancelButton.isHidden = true
                            self.histroyButton.isHidden = false
                            self.jumpDetailsBtn.isHidden = false
                        }
                    }
                    // 非图库
                    if (fileList?.count ?? 0) > 0 {
                        // 存储日志
                        try self.saveRecord(allFileList, fileList, [:], tempFileSizeDict)
                    } else {
                        if !isFreeSpace {
//                            AlertManager.showAlert(title: "存储空间不足，导入失败，请清理空间后在接收记录中重新导入".localized, cancelTitle: nil, confirmTitle: "知道了".localized) {
//                            }
                        }
                    }
                    self.manger?.log(1, "[SaveFile] [MIReceiveFilesView] 接收记录结束写入")
                } catch {
                    self?.manger?.log(3, "[SaveFile] [MIReceiveFilesView] 接收记录出错：\(error)")
                }
                self?.manger?.log(1, "[SaveFile] [MIReceiveFilesView] 落盘结束：\(file)")
            }
        }
    }
    
    
}

extension StopReceptPopController {
    // 更新进度
    func updateProgress(stat: [AnyHashable: Any]) {
        let totalTransfer = (stat["totalTransfer"] as? Double) ?? 0.0
        let totalBytes = Double(self.metadata?["totalSize"] as? String ?? "0") ?? 1.0
        let fileListStr = stat["fileList"] as? String ?? ""
        self.manger?.log(1, "[UI] [StopReceptPopController] updateProgress totalTransfer: \(totalTransfer) totalBytes: \(totalBytes)")
        if totalBytes == 0 {
            return
        }
        let progress = totalTransfer / totalBytes
       
        self.startProgressAnimation(progress: progress)
        self.showFileInfo(stat: stat)
    }
    
    func showFileIcon(fileExtension: String) {
        if self.senderType == "0" || self.senderType == "4" || (self.senderType == "8" && self.recvBase64IsScuccess) {
            return
        }
        var image: String = ""
        switch fileExtension {
        case "7z":
            image = "icon_7z"
        case "amr":
            image = "icon_amr"
        case "ape":
            image = "icon_ape"
        case "bag":
            image = "icon_bag"
        case "caj":
            image = "icon_caj"
        case "chm":
            image = "icon_chm"
        case "flac":
            image = "icon_flac"
        case "fold":
            image = "icon_fold"
        case "html":
            image = "icon_html"
        case "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp", "svg", "heic", "heif", "ico", "psd", "jpg":
            image = "icon_img"
        case "kdh":
            image = "icon_kdh"
        case "link":
            image = "icon_link"
        case "log":
            image = "icon_log"
        case "m4a":
            image = "icon_m4a"
        case "mp3":
            image = "icon_mp3"
        case "nh":
            image = "icon_nh"
        case "overlap":
            image = "icon_overlap"
        case "pdf":
            image = "icon_pdf"
        case "ppt":
            image = "icon_ppt"
        case "rar":
            image = "icon_rar"
        case "teb":
            image = "icon_teb"
        case "vcf", "zcf", "text":
            image = "icon_text"
        case "txt":
            image = "icon_txt"
        case "wav":
            image = "icon_wav"
        case "wma":
            image = "icon_wma"
        case "doc", "docx", "docm", "dot", "dotx", "dotm", "rtf":
            image = "icon_word"
        case "xml":
            image = "icon_xml"
        case "zip":
            image = "icon_zip"
        default:
            image = "icon_unknown"
        }
        self.manger?.log(1, "[UI] [StopReceptPopController] showFileIcon image: \(image)")
        self.thumbnailImageView.image = NSImage(named: image)
    }
    
    func getArrayFromJSONString(jsonString:String) ->NSArray{
        let jsonData:Data = jsonString.data(using: .utf8)!
        let array = try? JSONSerialization.jsonObject(with: jsonData, options: .mutableContainers)
        if array != nil {
            return array as! NSArray
        }
        return array as! NSArray
    }
    
    func showFileInfo(stat: [AnyHashable: Any]) {
        let files = stat["fileList"] as? String ?? ""
        let fileList = getArrayFromJSONString(jsonString: files)
        let totalTransfer = stat["totalTransfer"] as? Int ?? 0

        self.manger?.log(1, "[UI] [StopReceptPopController] showFileInfo fileList: \(fileList.count)")
        for item in fileList {
            if let fileDict = item as? [String: Any]
            {
                let status = fileDict["status"] as! String
                let filename = fileDict["filename"] as! String
                let fileURL = URL(fileURLWithPath: filename)
                let fileExtension = "\(fileURL.pathExtension)".lowercased()
                
                if status == "inprogress" || status == "completed" {
                    self.showFileIcon(fileExtension: fileExtension)
                }
                switch fileExtension {
                case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "raw", "psd", "webp", "heic", "heif", "avif", "dng", "svg":
                    imageCount += 1
                case "mp4", "mov", "avi", "mkv", "wmv", "webm", "flv", "mpeg", "mpg", "mts", "m2ts", "ts", "rmvb":
                    videoCount += 1
                default:
                    fileCount += 1
                }
            }
        }
        let fileSize = formatFileSize(byteSize: Int64(totalTransfer))
        var fileInfoText = ""
        if imageCount > 0 {
            let pictureText = imageCount == 1 ? "pictureAdd".localized : "picturesAdd".localized
            fileInfoText = fileInfoText + "\(imageCount)\(pictureText)"
        }
        if videoCount > 0 {
            let videoText = videoCount == 1 ? "videoAdd".localized : "videosAdd".localized
            fileInfoText = fileInfoText + "\(videoCount)\(videoText)"
        }
        if fileCount > 0 {
            let fileText = fileCount == 1 ? "fileAdd".localized : "filesAdd".localized
            fileInfoText = fileInfoText + "\(fileCount)\(fileText)"
        }
        self.fileInfoLabel.stringValue = "\(fileInfoText)" + fileSize
    }
}

extension StopReceptPopController: TransDelegate {
    
    func didIsCancel(_ isCancel: Bool) {
        self.manger?.log(1, "[UI] [StopReceptPopController] isCancel: \(isCancel) localIsCancel: \(self.localIsCancel)")
        if isCancel && self.localIsCancel {
            self.localIsCancel = false
            self.cancelRecv()
            receivePageManger?.close()
        }  
    }
    
    func didRecvStart(_ udid: String, file: String) -> String {
        var path = ""
        // 落盘逻辑开始
        if udid == self.udid {
            path = self.startSaveFile(file) ?? ""
        }
        return path
    }
    
    func imageFromBase64(base64: String) -> NSImage? {
        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else {
            self.manger?.log(1, "[UI] [StopReceptPopController] Error: Invalid base64 string.")
            return nil
        }
        
        if let image = NSImage(data: data) {
            recvBase64IsScuccess = true
            return image
        }
        
        recvBase64IsScuccess = false
        self.manger?.log(1, "[UI] [StopReceptPopController] Failed to create image from data on all attempts")
        return nil
    }
    
    func didRecvThumb(_ data: String) {
        if let image = imageFromBase64(base64: data) {
            DispatchQueue.main.async {
                self.connectLabel.isHidden = true
                self.connectLabel.stopDotAnimation()
                self.thumbnailImageView.image = image
            }
            self.manger?.log(1, "[UI] [StopReceptPopController] 图像加载成功")
        } else {
            self.manger?.log(1, "[UI] [StopReceptPopController] 图像加载失败")
        }
    }
    
    // 获取文件的时间信息
    func didRecvTime(_ timeInfo: String) {
        SaveFileHandler.shared.saveTimeInfo(timeInfo: timeInfo)
    }
    
    //注意：小文件传输不会触发 didUpdateProgress
    func didUpdateProgress(_ udid: String, percent: Double, stat: [AnyHashable: Any]) {
        DispatchQueue.main.async {
            let fileListStr = stat["fileList"] as? String ?? ""
            if fileListStr != "[]" && fileListStr != "" {
                self.allFilesList = stat
            }
            self.updateProgress(stat: stat)
        }
    }

    func didRecvAllFiles(_ udid: String, files: [String], totalBytes: NSNumber) {
        DispatchQueue.main.async {
            self.manger?.log(1, "[UI] [StopReceptPopController] didRecvAllFiles")
            self.connectLabel.isHidden = true
            self.connectLabel.stopDotAnimation()
            self.progressCircleView.isHidden = false
            self.progressLabel.isHidden = false
            self.fileInfoLabel.isHidden = true
            self.thumbnailImageView.imageScaling = self.senderType == "3" ? .scaleProportionallyDown : .scaleNone
            if self.senderType == "3" {
                self.filesImageView.isHidden = files.count <= 1
            } else if self.senderType == "0" {
                self.mediaImageView.isHidden = files.count <= 1
            }
            self.senderInfoLabel.isHidden = false
        }
    
        self.udid = udid
        self.totalBytes = Int(self.metadata?["totalSize"] as? String ?? "0")
    }

    func didRecvEnd(_ udid: String, file: String, isFinished: Bool, fileSize: CLongLong) {
        // 全部结束
        if isFinished {
            self.getRecvFileTypeText()
            self.manger?.log(1, "[UI] [StopReceptPopController] didRecvEnd")
            isRecvTask = false
            Gloable.isNotSendingStatus = true
            NotificationCenter.default.post(name: NSNotification.Name("GetIsSendingStatus"), object: nil)
            DispatchQueue.main.async {
                self.startProgressAnimation(progress: 1)
            }
        }
        self.manger?.log(1, "文件接收结束：\(file),是否全部结束\(isFinished)")
        // 落盘结束
        if file != "" {
            self.saveFileEnd(file, fileSize)
        }
        
        if isFinished {
            Task {
                if SaveFileHandler.shared.isSavePhotoLibraryForMac {
                    await self.performAsyncTask(file)
                } else {
                    // 存储日志
                    try self.downloadFolderSaveRecord(SaveFileHandler.shared.allFilePaths, SaveFileHandler.shared.filePaths, SaveFileHandler.shared.tempFileSizeDict ?? [String: Int64]())
                }
            }
        }
    }
    
    func didConnect(_ udid: String, status: String) {
        if status == "joinwifi" {
            setConnectMessage(message: "局域网连接中")
        }
    }
    
    func didSendProgress(_ udid: String, percent: Double) {}
    
    func didSendStart(_ udid: String, file: String) {}
    
    func didSendData(_ udid: String, data: Data, file: String) {}
    
    func didSendEnd(_ udid: String, file: String, isFinished: Bool) {}
    
    func didLivePhotoReady(_ imagePath: String, videoPath: String) {}
    
}

extension StopReceptPopController {
    func getFileSize(atPath path: String) -> Int64 {
        guard FileManager.default.fileExists(atPath: path) else {
            self.manger?.log(3, "[SaveFile] [StopReceptPopController] 文件不存在\(path)")
            return 0
        }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            self.manger?.log(3, "[SaveFile] [StopReceptPopController] 获取文件大小失败：\(path)：\(error)")
            return 0
        }
    }
    
    func getFileName(_ path: String) -> String {
        let fileName = (path as NSString).lastPathComponent
        return fileName
    }
    
    // 插入未导入的记录
    func saveRecordNoImporting(_ tempFiles: [(String, String, String)]?, _ tempFileSizeDict: [String: Int64]) throws {
        var thumbImageItems: [MIThumbImageOperation] = []
        
        // 保存记录
        let record = MITransferRecord()
        if let hwid = self.hwid {
            record.hwId = hwid
        } else {
            record.deviceIcon = "device_icon_\(Int.random(in: 1 ... 5))"
        }
        record.deviceId = self.udid
        record.deviceType = self.metadata?["deviceType"] as? Int
        record.deviceName = self.metadata?["senderName"] as? String
        record.transferType = .receive
        record.transferTime = Date()
        var files: [MITransferFile] = []
        for (_, _, path) in tempFiles ?? [] {
            let model = MITransferFile()
            model.fileSize = tempFileSizeDict[path]
            model.fileName = self.getFileName(path)
            var tempPath = path
            let tiemInfo = SaveFileHandler.shared.getTimeinfo(path)
            if path.contains("/temp/") {
               tempPath = (path.components(separatedBy: "/temp/")[1])
            }
            //时间信息临时保存到路径记录中（临时处理）
            model.fileUrl = "\(tiemInfo.0)|\(tiemInfo.1)|\(tiemInfo.2)/temp/\(tempPath)"
            model.isSavePhotoLibraryForMac = true
            model.fileFolder = "image"
            model.fileExtension = (path as NSString).pathExtension
            model.status = .inProgress
            model.fileType = .photoAndVideo
            files.append(model)
            
            let item = MIThumbImageOperation(file: model, filePath: path, fileName: model.fileName)
            thumbImageItems.append(item)
        }
        
        record.sendContent = files
        if !record.sendContent.isEmpty {
            Task {
                do {
                    try await MIWCDBManager.shared.insertRecordAsync(record)
                } catch {}
            }
        }
        
        if thumbImageItems.count > 0 {
            let batchProcessor = MIBatchProcessor()
            batchProcessor.processBatchWithOperationQueue(items: thumbImageItems) {
                
            }
        }
    }
    
    func saveRecord(_ allFilePaths: [String]?, _ filePaths: [String]?, _ localIdentifiers: [String: String], _ tempFileSizeDict: [String: Int64]) throws {
        var thumbImageItems: [MIThumbImageOperation] = []
        
        // 保存记录
        let record = MITransferRecord()
        if let hwid = self.hwid {
            record.hwId = hwid
        } else {
            record.deviceIcon = "device_icon_\(Int.random(in: 1 ... 5))"
        }
        record.deviceId = self.udid
        record.deviceName = self.metadata?["senderName"] as? String
        record.transferType = .receive
        record.deviceType = self.metadata?["deviceType"] as? Int
        record.transferTime = Date()
      
        var files: [MITransferFile] = []
      
        //媒体场景，文件场景，文件夹场景通用一个逻辑（都有可能存在媒体文件落盘和文管文件落盘）
        if self.senderType == "0" || self.senderType == "3" || self.senderType == "4"  {
            //文管场景下可能存在媒体文件、媒体场景下可能存在文管文件（逻辑同样处理）
            for path in allFilePaths ?? [] {
                if let paths = filePaths, paths.contains(path) {
                    let model = MITransferFile()
                    model.fileSize = self.getFileSize(atPath: path)
                    model.fileName = self.getFileName(path)
                    let tempPath = (path.components(separatedBy: "Documents")[1])
                    model.fileUrl = "/Documents" + tempPath
                    //文件夹适配只保存others
                    if tempPath.contains("/others/") {
                        model.fileFolder = "others"
                    } else {
                        let url = URL(fileURLWithPath: path)
                        let preDirectory = url.deletingLastPathComponent()
                        let fileFolder = preDirectory.lastPathComponent
                        model.fileFolder = fileFolder
                    }
                    model.fileExtension = (path as NSString).pathExtension
                    model.fileType = .file
                    model.status = .success
                    files.append(model)
                    
                    let item = MIThumbImageOperation(file: model, filePath: path, fileName: model.fileName)
                    thumbImageItems.append(item)
                }
                else if let localIdentifier = localIdentifiers[path], localIdentifier != "" {
                    let model = MITransferFile()
                    model.fileSize = tempFileSizeDict[path]
                    model.fileName = self.getFileName(path)
                    model.fileUrl = path
                    model.fileFolder = "image"
                    model.fileExtension = (path as NSString).pathExtension
                    model.identifier = localIdentifier
                    model.fileType = .photoAndVideo
                    model.status = .success
                    files.append(model)
                    
                    let item = MIThumbImageOperation(file: model, filePath: path, fileName: model.fileName)
                    thumbImageItems.append(item)
                }
            }
        } else {
            // 通讯录数据组装
            let model = MITransferFile()
            for path in filePaths ?? [] {
                model.fileSize = self.getFileSize(atPath: path)
                model.fileName = self.getFileName(path)
                let tempPath = (path.components(separatedBy: "Documents")[1])
                model.fileUrl = "/Documents" + tempPath
                let url = URL(fileURLWithPath: path)
                let preDirectory = url.deletingLastPathComponent()
                let fileFolder = preDirectory.lastPathComponent
                model.fileFolder = fileFolder
                model.fileExtension = (path as NSString).pathExtension
                model.fileType = .contacts
                model.status = .success
                files.append(model)
                
                let item = MIThumbImageOperation(file: model, filePath: path, fileName: model.fileName)
                thumbImageItems.append(item)
            }
        }

        record.sendContent = files
        if !record.sendContent.isEmpty {
            Task {
                do {
                    try await MIWCDBManager.shared.insertRecordAsync(record)
                } catch {}
            }
        }
        
        if thumbImageItems.count > 0 {
            let batchProcessor = MIBatchProcessor()
            batchProcessor.processBatchWithOperationQueue(items: thumbImageItems) {
                
            }
        }
    }
    
    func downloadFolderSaveRecord(_ allFilePaths: [String]?, _ filePaths: [String]?, _ tempFileSizeDict: [String: Int64]) throws {
        var thumbImageItems: [MIThumbImageOperation] = []
        
        // 保存记录
        let record = MITransferRecord()
        if let hwid = self.hwid {
            record.hwId = hwid
        } else {
            record.deviceIcon = "device_icon_\(Int.random(in: 1 ... 5))"
        }
        record.deviceId = self.udid
        //TODO:
        record.deviceType = self.metadata?["deviceType"] as? Int
        record.deviceName = self.metadata?["senderName"] as? String
        record.transferType = .receive
        record.transferTime = Date()
      
        var files: [MITransferFile] = []
        //媒体场景，文件场景，文件夹场景通用一个逻辑（都有可能存在媒体文件落盘和文管文件落盘）
        if self.senderType == "0" || self.senderType == "3" || self.senderType == "4"  {
            //文管场景下可能存在媒体文件、媒体场景下可能存在文管文件（逻辑同样处理）
            for path in allFilePaths ?? [] {
                if let paths = filePaths, paths.contains(path) {
                    let model = MITransferFile()
                    model.fileSize = self.getFileSize(atPath: path)
                    model.fileName = self.getFileName(path)
                    var tempPath = ""
                    if path.contains("Downloads") {
                        tempPath = (path.components(separatedBy: "Downloads")[1])
                    } else if path.contains("Documents") {
                        tempPath = (path.components(separatedBy: "Documents")[1])
                    }
                    model.fileUrl = "/Downloads" + tempPath
                    //文件夹适配只保存others
                    if tempPath.contains("/others/") {
                        model.fileFolder = "others"
                    } else {
                        let url = URL(fileURLWithPath: path)
                        let preDirectory = url.deletingLastPathComponent()
                        let fileFolder = preDirectory.lastPathComponent
                        model.fileFolder = fileFolder
                    }
                    model.fileExtension = (path as NSString).pathExtension
                    if self.senderType == "0" {
                        model.fileType = .photoAndVideo
                    } else if self.senderType == "3" {
                        model.fileType = .file
                    } else if self.senderType == "4" {
                        model.fileType = .file
                    }
                    model.status = .success
                    files.append(model)
                    
                    let item = MIThumbImageOperation(file: model, filePath: path, fileName: model.fileName)
                    thumbImageItems.append(item)
                } else {
                    let model = MITransferFile()
                    model.fileSize = tempFileSizeDict[path] ?? 0
                    model.fileName = self.getFileName(path)
                    model.fileUrl = path
                    model.fileFolder = "image"
                    model.fileExtension = (path as NSString).pathExtension
                    model.identifier = ""
                    model.fileType = .photoAndVideo
                    model.status = .success
                    files.append(model)
                    
                    let item = MIThumbImageOperation(file: model, filePath: path, fileName: model.fileName)
                    thumbImageItems.append(item)
                }
            }
        } else {
            // 通讯录数据组装
            let model = MITransferFile()
            for path in filePaths ?? [] {
                model.fileSize = self.getFileSize(atPath: path)
                model.fileName = self.getFileName(path)
                var tempPath = ""
                if path.contains("Downloads") {
                    tempPath = (path.components(separatedBy: "Downloads")[1])
                } else if path.contains("Documents") {
                    tempPath = (path.components(separatedBy: "Documents")[1])
                }
                model.fileUrl = "/Downloads" + tempPath
                let url = URL(fileURLWithPath: path)
                let preDirectory = url.deletingLastPathComponent()
                let fileFolder = preDirectory.lastPathComponent
                model.fileFolder = fileFolder
                model.fileExtension = (path as NSString).pathExtension
                model.fileType = .contacts
                model.status = .success
                files.append(model)
                
                let item = MIThumbImageOperation(file: model, filePath: path, fileName: model.fileName)
                thumbImageItems.append(item)
            }
        }

        record.sendContent = files
        Task {
            do {
                try await MIWCDBManager.shared.insertRecordAsync(record)
            } catch {}
        }
        
        if thumbImageItems.count > 0 {
            let batchProcessor = MIBatchProcessor()
            batchProcessor.processBatchWithOperationQueue(items: thumbImageItems) {
                
            }
        }
    }
}


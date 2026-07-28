//
//  Untitled.swift
//  MutualInfection
//
//  Created by 1234 on 2025/9/26.
//

import AppKit
import Cocoa

class ReceptOrNotPopController: NSViewController {
    
    var udid: String?
    var metadata: [AnyHashable : Any]?
    var upWindow:NSWindow!
    var cancelButton: NSButton!
    var trueButton: NSButton!
    var userName: String! // 用户名
    var fileCount: String! // 文件数
    var fileSize: String! // 文件大小
    
    var recvMenu: NSMenu?

    
    private lazy var nameLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .mi.pingFangSCMedium(size: 13)
        label.textColor = .mi.hex("#000000")
        label.cell?.wraps = true
        label.cell?.isScrollable = false
        if let textFieldCell = label.cell as? NSTextFieldCell {
            textFieldCell.lineBreakMode = .byWordWrapping
        }
        return label
    }()
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    func setData(upWindow:NSWindow, udid: String = "", metadata: [AnyHashable: Any] = [:]) {
        receivePageManger?.showCloseBtn(isHidden: true)
        self.upWindow = upWindow
        self.udid = udid
        self.metadata = metadata
        self.initData(udid: udid, metadata: metadata)
    }
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 375, height: 69))
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        //view = NSView(frame: NSRect(x: 0, y: 0, width: 375, height: 69))
        
        let ownPhotoView = CustomImageView(size: NSSize(width: 36, height: 36))
        view.addSubview(ownPhotoView)
        view.addSubview(nameLabel)
        
        // 设置拒绝按钮样式
        let cancelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor(red: 0, green: 0, blue: 0, alpha: 0.85)
        ]
        // 使用默认按钮点击事件，避免 mouseDown 触发 action 但业务只处理 mouseUp 导致偶现无响应。
        cancelButton = NSButton(title: "拒绝".localized, target: self, action: #selector(cancelButtonClicked(_:)))
        cancelButton.wantsLayer = true
        cancelButton.layer?.backgroundColor = NSColor.clear.cgColor
        cancelButton.isBordered = false
        cancelButton.layer?.borderWidth = 1.0
        cancelButton.layer?.borderColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.1).cgColor
        cancelButton.layer?.masksToBounds = true
        cancelButton.layer?.cornerRadius = 10
        cancelButton.layer?.maskedCorners = [.layerMaxXMinYCorner]
        cancelButton.attributedTitle = NSAttributedString(string: "拒绝".localized, attributes: cancelAttributes)
        view.addSubview(cancelButton)
        
        // 设置接收按钮样式
        let trueAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor(red: 0, green: 0, blue: 0, alpha: 0.85)
        ]
        // 使用默认按钮点击事件，避免 mouseDown 触发 action 但业务只处理 mouseUp 导致偶现无响应。
        trueButton = NSButton(title: "接收".localized, target: self, action: #selector(trueButtonClicked(_:)))
        trueButton.wantsLayer = true
        trueButton.layer?.backgroundColor = NSColor.clear.cgColor
        trueButton.isBordered = false
        trueButton.layer?.borderWidth = 1.0
        trueButton.layer?.borderColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.1).cgColor
        trueButton.layer?.masksToBounds = true
        trueButton.layer?.cornerRadius = 10
        trueButton.layer?.maskedCorners = [.layerMaxXMaxYCorner]
        trueButton.attributedTitle = NSAttributedString(string: "接收".localized, attributes: trueAttributes)
        view.addSubview(trueButton)
        
        ownPhotoView.snp.makeConstraints {
            make in
            make.leading.equalTo(view.snp.leading).offset(10)
            make.centerY.equalToSuperview()
            make.width.equalTo(36)
            make.height.equalTo(36)
        }
        nameLabel.snp.makeConstraints {
            make in
            make.leading.equalTo(view.snp.leading).offset(56)
            make.centerY.equalToSuperview()
            make.width.lessThanOrEqualTo(230)
        }
        cancelButton.snp.makeConstraints {
            make in
            make.trailing.equalTo(view.snp.trailing).offset(0)
            make.top.equalTo(view.snp.top).offset(0)
            make.width.equalTo(78)
            make.height.equalTo(35)
        }
        trueButton.snp.makeConstraints {
            make in
            make.trailing.equalTo(view.snp.trailing).offset(0)
            make.bottom.equalTo(view.snp.bottom).offset(0)
            make.width.equalTo(78)
            make.height.equalTo(35)
        }
    }

    private func initData(udid: String, metadata: [AnyHashable : Any]) {
        let name =  (metadata["senderName"] as? String) ?? ""
        let itemCount =  (metadata["itemCount"] as? String) ?? "0"
        let fileCount = (metadata["fileCount"] as? String) ?? "0"
        let senderType = (metadata["sendType"] as? String) ?? ""
        let totalSize = (metadata["totalSize"] as? String) ?? ""
        let fileSize = formatFileSize(byteSize: Int64(totalSize) ?? 0)

        self.userName = name
        self.fileCount = senderType == "4" ? fileCount : itemCount
        self.fileSize = fileSize
        let contText = "想向您发送".localized + (senderType == "4" ? fileCount : itemCount)
        let filesText = self.fileCount == "1" ? "file".localized : "files".localized
        let sizeText = "（".localized + fileSize + "）".localized
         nameLabel.stringValue = self.userName + contText + filesText + sizeText
//        nameLabel.stringValue = self.userName + "想向您发送".localized + (senderType == "4" ? fileCount : itemCount) + filesText + "（".localized + fileSize + "）".localized
    }
    
    @objc func trueButtonClicked(_ sender: NSButton) {
        // 非媒体内容没有保存位置菜单，直接按下载目录接收。
        let metadata = self.metadata
        let senderType = (metadata?["sendType"] as? String) ?? ""
        if senderType != "0" {
            checkUserSaveDataToPhotoLibraryDownloadFolder(false)
            return
        }
        
        let photosItem = NSMenuItem(title: "在“照片”中打开".localized, action: #selector(handlePhotos), keyEquivalent: "")
        photosItem.target = self

        let filesItem = NSMenuItem(title: "保存到“下载”".localized, action: #selector(handleDownloader), keyEquivalent: "")
        filesItem.target = self

        self.recvMenu = NSMenu()
        self.recvMenu?.addItem(photosItem)
        self.recvMenu?.addItem(filesItem)
        // 菜单挂到按钮上，避免使用屏幕硬编码坐标时在多屏/缩放场景弹到不可见位置。
        self.recvMenu?.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.minY), in: sender)
    }
    
    @objc func handlePhotos() {
        print("图库")
        checkUserSaveDataToPhotoLibraryDownloadFolder(true)
    }
    
    @objc func handleDownloader(){
        print("下载")
        checkUserSaveDataToPhotoLibraryDownloadFolder(false)
    }
    
    /// 用户保存到相册、下载文件夹
    func checkUserSaveDataToPhotoLibraryDownloadFolder(_ isSavePhotoLibrary: Bool) {
        SaveFileHandler.shared.isSavePhotoLibraryForMac = isSavePhotoLibrary
        if SaveFileHandler.shared.isSavePhotoLibraryForMac {
            checkPhotoPermissionStatus()
        } else {
            checkDownloadFolderStatus()
        }
    }
    
    /// 没有下载文件夹权限时的提示弹窗
    func showErrorAlert() {
        let alert = NSAlert()
        alert.messageText = "无法使用下载文件夹".localized
        alert.informativeText = "请检查应用的权限设置".localized
        alert.addButton(withTitle: "确定".localized)
        alert.beginSheetModal(for: NSApp.mainWindow ?? NSWindow()) { _ in
            self.openStorageSettings()
        }
    }
    
    private func openStorageSettings(){
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func checkDownloadFolderStatus() {
        if MIMACDownloadFolderManager().checkDownloadsFolderPermission() {
            self.next_trueButtonClicked()
        } else {
            ShareAPI.shared().rejectRequest(self.udid ?? "")
            self.view.window?.close()
            
            showErrorAlert()
        }
        return
    }
    
    func checkPhotoPermissionStatus() {
        let metadata = self.metadata
        let senderType = (metadata?["sendType"] as? String) ?? ""
        if senderType == "0"{
            MIMacPhotoPermissionManager.shared.getPhotoPermissionStatus(isReceive: true) {
                DispatchQueue.main.async {
                    self.next_trueButtonClicked()
                }
            } fail: {
                DispatchQueue.main.async {
                    self.next_trueButtonClicked()
                }
            }
        } else {
            self.next_trueButtonClicked()
        }
    }
    
    func next_trueButtonClicked() {
//        print("next_trueButtonClicked")
        let metadata = self.metadata
        let senderType = (metadata?["sendType"] as? String) ?? ""
        let previewSummary = (metadata?["previewSummary"] as? String) ?? ""
        
        if SaveFileHandler.shared.isSavePhotoLibraryForMac {
            //没有照片权限不进入接收路径
            if senderType == "0" && !SaveFileHandler.shared.photoLibraryAuthorized() {
                ShareAPI.shared().rejectRequest(self.udid ?? "")
                self.view.window?.close()
                return
            }
        }
        
        //落盘初始化
        SaveFileHandler.shared.saveFileInit(senderType, previewSummary)
            
        let popupsCall = PagesCall(upWindow: upWindow)
        popupsCall.stopReceptPopShow(upWindow: upWindow, udid: self.udid ?? "", metadata: self.metadata ?? [:])
    }

    @objc func cancelButtonClicked(_ sender: NSButton) {
        // 标准按钮 action 已保证是有效点击，这里直接执行拒绝流程。
        isRecvTask = false
        Gloable.isNotSendingStatus = true
        NotificationCenter.default.post(name: NSNotification.Name("GetIsSendingStatus"), object: nil)
        ShareAPI.shared().rejectRequest(udid ?? "")
        view.window?.close()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

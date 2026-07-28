//
//  FeedbackController.swift
//  MutualInfection
//
//  Created by 1234 on 2025/9/29.
//

import Cocoa
import AppKit
import Network

class FeedbackController: NSViewController, NSTextFieldDelegate {
    var cancelButton :NSButton!
    var trueButton :NSButton!
    var tipCountLb = NSTextField(labelWithString: "0/300")
    var textView = NSTextField()
    var connetTextView = NSTextField()
    
    lazy var cotentMainView: NSView = {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
//        view.wantsLayer = true
//        view.layer?.backgroundColor = NSColor.red.cgColor
        return view
    }()
    lazy var cotentScrollView: NSScrollView = {
        let sv = NSScrollView()
        sv.hasHorizontalScroller = false
        sv.hasVerticalScroller = false
        sv.autohidesScrollers = true
        sv.borderType = .noBorder
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.autoresizingMask = [.width, .height]
        sv.verticalScrollElasticity = .automatic
        sv.documentView = cotentMainView
        return sv
    }()
    
    // 图片上传相关
    var uploadStackView: NSStackView!
    var uploadScrollView: NSScrollView!
    var selectedImages: [NSImage] = []  // 存储已选择的图片
    let maxImageCount = 3  // 最多上传3张图片
    var timeLabel = NSTextField(labelWithString: "")
    var isUpdate : Bool = true
    var switchControl = NSSwitch()
    var manger : ShareAPI?
    override func loadView() {
        self.view=NSView(frame: NSRect(x: 0, y: 0, width: 367, height: 430))
    }
    deinit{
        NotificationCenter.default.removeObserver(self)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        //self.view=NSView(frame: NSRect(x: 0, y: 0, width: 367, height: 430))
        let headView = NSView()
        headView.wantsLayer = true  // 必须启用图层
        headView.layer?.backgroundColor = NSColor(red: 245/255.0, green: 245/255.0, blue: 245/255.0, alpha: 0.8).cgColor
        headView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headView)
        let closeButton = NSButton(title: "关闭".localized, target: nil, action:#selector(closeButtonClicked))
        closeButton.setButtonType(.momentaryPushIn)
        closeButton.isBordered = false // 关键属性，禁用系统边框样式
        closeButton.wantsLayer = true // 启用图层支持
        closeButton.image = NSImage(named: "icon_close")
        closeButton.layer?.cornerRadius = 8
        closeButton.imageScaling = .scaleNone
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        headView.addSubview(closeButton)
        let headLabel = NSTextField(labelWithString: "意见反馈".localized)
        headLabel.font = .mi.pingFangSCRegular(size: 13)
        headLabel.textColor = .mi.hex("#000000")
        headLabel.translatesAutoresizingMaskIntoConstraints = false
        headView.addSubview(headLabel)
        
        view.addSubview(cotentScrollView)
        
        let desLabel = NSTextField()
        // 创建带红色星号的文本
        let desText = "问题描述".localized
        let desAttributedString = NSMutableAttributedString(string: desText + "*")
        
        // 设置整体文本样式
        desAttributedString.addAttributes([
            .font: NSFont.mi.pingFangSCMedium(size: 11),
            .foregroundColor: NSColor.mi.hex("#000000")
        ], range: NSRange(location: 0, length: desAttributedString.length))
        
        // 设置星号为红色，并加大字号
        desAttributedString.addAttributes([
            .foregroundColor: NSColor.red,
            .font: NSFont.mi.pingFangSCMedium(size: 14)
        ], range: NSRange(location: desText.count, length: 1))
        
        desLabel.attributedStringValue = desAttributedString
        desLabel.isBordered = false
        desLabel.isEditable = false
        desLabel.backgroundColor = .clear
        desLabel.translatesAutoresizingMaskIntoConstraints = false
        cotentMainView.addSubview(desLabel)
        
        
        textView.focusRingType = .none
        textView.font = .mi.pingFangSCRegular(size: 12)
        textView.delegate = self
        textView.placeholderString = "请尽量详细描述您的问题（不少于10字）".localized
        textView.translatesAutoresizingMaskIntoConstraints = false
        cotentMainView.addSubview(textView)
        
        tipCountLb.font = .mi.pingFangSCMedium(size: 11)
        tipCountLb.textColor = .mi.hex("#000000").withAlphaComponent(0.3)
        tipCountLb.translatesAutoresizingMaskIntoConstraints = false
        cotentMainView.addSubview(tipCountLb)
        
        let postLabel = NSTextField(labelWithString: "上传图片".localized)
        postLabel.font = .mi.pingFangSCMedium(size: 11)
        postLabel.textColor = .mi.hex("#000000")
        postLabel.backgroundColor = .clear
        postLabel.translatesAutoresizingMaskIntoConstraints = false
        postLabel.drawsBackground = true
        cotentMainView.addSubview(postLabel)
        
        
        let uploadAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor(red: 0/255.0, green: 0/255.0, blue: 0/255.0, alpha: 1)
        ]
        let uploadButton = NSButton(title: "点击上传".localized, target: self, action:#selector(uploadButtonClicked))
        uploadButton.sendAction(on: [.leftMouseDown])
        uploadButton.wantsLayer = true
        uploadButton.layer?.backgroundColor = NSColor(red: 255/255.0, green: 255/255.0, blue: 255/255.0, alpha: 1).cgColor
        uploadButton.layer?.cornerRadius = 0 // 圆角半径值
        uploadButton.image = NSImage(named: "icon_upload")
        uploadButton.imagePosition = .imageLeft
        uploadButton.layer?.masksToBounds = true
        uploadButton.attributedTitle = NSAttributedString(string: "点击上传".localized, attributes: uploadAttributes)
        uploadButton.translatesAutoresizingMaskIntoConstraints = false
        cotentMainView.addSubview(uploadButton)
        
        // 创建横向滚动的图片展示区域
        uploadScrollView = NSScrollView()
        uploadScrollView.hasHorizontalScroller = false  // 禁用横向滚动条
        uploadScrollView.hasVerticalScroller = false
        uploadScrollView.autohidesScrollers = true
        uploadScrollView.borderType = .noBorder
        uploadScrollView.translatesAutoresizingMaskIntoConstraints = false
        cotentMainView.addSubview(uploadScrollView)
        
        uploadStackView = NSStackView()
        uploadStackView.orientation = .horizontal
        uploadStackView.alignment = .top
        uploadStackView.distribution = .fillEqually
        uploadStackView.spacing = 10  // 减小间距
        uploadStackView.translatesAutoresizingMaskIntoConstraints = false
        uploadScrollView.documentView = uploadStackView
        
        let connetLabel = NSTextField()
        // 创建带红色星号的文本
        let connetText = "联系方式".localized
        let connetAttributedString = NSMutableAttributedString(string: connetText + "*")
        
        // 设置整体文本样式
        connetAttributedString.addAttributes([
            .font: NSFont.mi.pingFangSCMedium(size: 11),
            .foregroundColor: NSColor.mi.hex("#000000")
        ], range: NSRange(location: 0, length: connetAttributedString.length))
        
        // 设置星号为红色，并加大字号
        connetAttributedString.addAttributes([
            .foregroundColor: NSColor.red,
            .font: NSFont.mi.pingFangSCMedium(size: 14)
        ], range: NSRange(location: connetText.count, length: 1))
        
        connetLabel.attributedStringValue = connetAttributedString
        connetLabel.isBordered = false
        connetLabel.isEditable = false
        connetLabel.backgroundColor = .clear
        connetLabel.translatesAutoresizingMaskIntoConstraints = false
        cotentMainView.addSubview(connetLabel)
        
        
        connetTextView.isBezeled = true
        connetTextView.placeholderString = "请输入您的联系方式".localized
        connetTextView.focusRingType = .none
        connetTextView.font = .mi.pingFangSCRegular(size: 12)
        connetTextView.cell?.wraps = false
        connetTextView.cell?.isScrollable = true
        connetTextView.cell?.lineBreakMode = .byTruncatingTail
        connetTextView.cell?.truncatesLastVisibleLine = true
        connetTextView.translatesAutoresizingMaskIntoConstraints = false
        cotentMainView.addSubview(connetTextView)
        
        let errorLabel = NSTextField(labelWithString: "发送错误报告".localized)
        errorLabel.font = .mi.pingFangSCMedium(size: 11)
        errorLabel.textColor = .mi.hex("#000000")
        errorLabel.backgroundColor = .clear
        errorLabel.lineBreakMode = .byWordWrapping
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.drawsBackground = true
        cotentMainView.addSubview(errorLabel)
        
        switchControl = NSSwitch()
        switchControl.state = .on  // 默认开启状态
        // 添加状态变化回调
        switchControl.target = self
        switchControl.action = #selector(handleSwitchChange(_:))
        // 启用拖拽连续触发事件
        switchControl.isContinuous = true
        switchControl.translatesAutoresizingMaskIntoConstraints = false
        cotentMainView.addSubview(switchControl)
        
        let timeAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor(white: 1, alpha: 1)
        ]
        let timeButton = NSButton(title: "发生时间*".localized, target: self, action:#selector(timeButtonClicked))
        timeButton.sendAction(on: [.leftMouseDown])
        timeButton.wantsLayer = true
        timeButton.layer?.backgroundColor = NSColor(red: 0/255.0, green: 122/255.0, blue: 255/255.0, alpha: 1.0).cgColor
        timeButton.isBordered = false // 去除默认边框
        timeButton.layer?.cornerRadius = 8  // 圆角半径值
        timeButton.layer?.masksToBounds = true
        timeButton.attributedTitle = NSAttributedString(string: "发生时间*".localized, attributes: timeAttributes)
        timeButton.translatesAutoresizingMaskIntoConstraints = false
        cotentMainView.addSubview(timeButton)
        
        
        timeLabel.font = .mi.pingFangSCMedium(size: 12)
        timeLabel.textColor = .mi.hex("#000000")
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        cotentMainView.addSubview(timeLabel)
        
        
        let cancelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor(red: 0/255.0, green: 0/255.0, blue: 0/255.0, alpha: 0.5)
        ]
        cancelButton = NSButton(title: "取消".localized, target: self, action:#selector(cancelButtonClicked(_:)))
        cancelButton.sendAction(on: [.leftMouseDown])
        cancelButton.wantsLayer = true
        cancelButton.layer?.backgroundColor = NSColor(red: 0/255.0, green: 0/255.0, blue: 0/255.0, alpha: 0.1).cgColor
        cancelButton.isBordered = false // 去除默认边框
        cancelButton.layer?.cornerRadius = 8  // 圆角半径值
        cancelButton.layer?.masksToBounds = true
        cancelButton.attributedTitle = NSAttributedString(string: "取消".localized, attributes: cancelAttributes)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancelButton)
        
        let trueAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor(white: 1, alpha: 1)
        ]
        trueButton = NSButton(title: "提交".localized, target: self, action:#selector(submitAction))
        trueButton.sendAction(on: [.leftMouseDown])
        trueButton.wantsLayer = true
        trueButton.layer?.backgroundColor = NSColor(red: 0/255.0, green: 122/255.0, blue: 255/255.0, alpha: 1.0).cgColor
        trueButton.isBordered = false // 去除默认边框
        trueButton.layer?.cornerRadius = 8  // 圆角半径值
        trueButton.layer?.masksToBounds = true
        trueButton.attributedTitle = NSAttributedString(string: "提交".localized, attributes: trueAttributes)
        trueButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(trueButton)
        
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
        
        cotentScrollView.snp.makeConstraints { make in
            make.top.equalTo(headView.snp.bottom)
            make.leading.trailing.equalTo(0)
            make.bottom.equalTo(-50)
            make.height.equalTo(self.view.bounds.size.height - 40 - 48)
        }
        
        cotentMainView.snp.makeConstraints { make in
            make.top.leading.trailing.equalTo(0)
            make.height.equalTo(cotentScrollView.contentView).priority(.high)
            // 关键：允许内容宽度超出
            make.height.greaterThanOrEqualTo(cotentScrollView.contentView)
        }
        
        desLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(15)
            make.leading.equalToSuperview().offset(12)
            make.width.equalTo(80)
        }
        
        textView.snp.makeConstraints { make in
            make.top.equalTo(desLabel)
            make.leading.equalTo(desLabel.snp.trailing).offset(12)  // 相对于desLabel的右边，偏移12像素
            make.trailing.equalTo(-12)
            make.height.equalTo(80)
        }
        
        tipCountLb.snp.makeConstraints { make in
            make.bottom.equalTo(textView).offset(15)
            make.trailing.equalTo(textView).offset(-3)
        }
        
        postLabel.snp.makeConstraints { make in
            make.top.equalTo(desLabel.snp.top).offset(100)  // 相对于desLabel的底部，偏移115像素
            make.leading.equalToSuperview().offset(12)
            make.width.equalTo(80)
        }
        
        uploadButton.snp.makeConstraints { make in
            make.height.equalTo(28)
            make.top.equalTo(desLabel.snp.top).offset(93)  // 相对于desLabel的底部，偏移115像素
            make.leading.equalTo(postLabel.snp.trailing).offset(12)  // 相对于postLabel的右边，偏移12像素
            make.trailing.equalTo(-100)
        }
        
        uploadScrollView.snp.makeConstraints { make in
            make.top.equalTo(uploadButton.snp.bottom).offset(8)
            make.leading.equalToSuperview().offset(100)
            make.trailing.equalToSuperview().offset(-22)
            make.height.equalTo(0)  // 初始高度为0，有图片时会调整
        }
        
        // 联系方式改为相对于uploadScrollView定位
        connetLabel.snp.makeConstraints { make in
            make.top.equalTo(uploadScrollView.snp.bottom).offset(10)
            make.leading.equalToSuperview().offset(12)
            make.width.equalTo(80)
        }
        
        connetTextView.snp.makeConstraints { make in
            make.top.equalTo(uploadScrollView.snp.bottom).offset(9)
            make.leading.equalToSuperview().offset(100)
            make.trailing.equalTo(-12)
            make.height.equalTo(28)
        }
        
        // 错误报告开关保持原有定位方式
        errorLabel.snp.makeConstraints { make in
            make.top.equalTo(connetTextView.snp.bottom).offset(20)
            make.leading.equalTo(12)
            make.width.equalTo(80)
            make.height.equalTo(20)
        }
        
        switchControl.snp.makeConstraints { make in
            make.top.equalTo(connetTextView.snp.bottom).offset(16)
            make.leading.equalToSuperview().offset(100)
        }
        
        timeButton.snp.makeConstraints { make in
            make.top.equalTo(errorLabel.snp.bottom).offset(20)
            make.leading.equalToSuperview().offset(12)
            make.trailing.equalTo(-120)
            make.height.equalTo(28)
            make.bottom.lessThanOrEqualTo(-20)
        }
        
        timeLabel.snp.makeConstraints { make in
            make.top.equalTo(errorLabel.snp.bottom).offset(25)
            make.trailing.equalToSuperview().offset(-12)
        }
        
        // 按钮改为相对于view底部定位，始终保持距离底部20像素
        cancelButton.snp.makeConstraints { make in
            make.width.equalTo(110)
            make.height.equalTo(28)
            make.bottom.equalToSuperview().offset(-20)
            make.leading.equalToSuperview().offset(69)
        }
        
        trueButton.snp.makeConstraints { make in
            make.width.equalTo(110)
            make.height.equalTo(28)
            make.bottom.equalToSuperview().offset(-20)
            make.leading.equalToSuperview().offset(187)
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange(_:)),
            name: NSControl.textDidChangeNotification,
            object: connetTextView
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textProblemDidChange(_:)),
            name: NSControl.textDidChangeNotification,
            object: textView
        )
        
        // 手动触发布局计算
//        view.layoutSubtreeIfNeeded()
//        // 根据约束计算结果设置 contentView 的 frame
//        let contentSize = cotentMainView.fittingSize
//        cotentMainView.frame = CGRect(origin: .zero, size: contentSize)
    }
    
    @objc func closeButtonClicked() {
        self.view.window?.close()
    }
    @objc func textProblemDidChange(_ notification: Notification) {
        guard let textField = notification.object as? NSTextField else { return }

        tipCountLb.stringValue = "\(textField.stringValue.count ?? 0)/300"
        if (textField.stringValue.count ?? 0) > 300 {
            textField.stringValue = String(textField.stringValue.prefix(300) ?? "")
            tipCountLb.stringValue = "300/300"
            showSheetAlert(messageText: "提示".localized, message: "maxWordCountTips".localized,window:self.view.window) {
                
            }
        }
        
    }
    @objc func textDidChange(_ notification: Notification) {
        guard let textField = notification.object as? NSTextField else { return }
        print("当前文本: \(textField.stringValue)")
    }
    @objc func handleSwitchChange(_ sender: NSSwitch) {
            let state = sender.state == .on ? "ON" : "OFF"
            print("Switch state changed to: \(state)")
    }
    @objc func uploadButtonClicked() {
        // 检查是否已达到最大图片数量
        if selectedImages.count >= maxImageCount {
            showSheetAlert(message: "maxUploadTips".localized,in: self.view.window!)
            return
        }
        
        // 创建文件选择器
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        if #available(macOS 11.0, *) {
            openPanel.allowedContentTypes = [.image]
        } else {
            // Fallback on earlier versions
        }  // 只允许选择图片
        
        openPanel.begin { [weak self] response in
            guard let self = self else { return }
            
            if response == .OK, let url = openPanel.url {
                // 加载选中的图片
                if let image = NSImage(contentsOf: url) {
                    self.addImageToStackView(image)
                }
            }
        }
    }
    
    // 添加图片到StackView
    func addImageToStackView(_ image: NSImage) {
        selectedImages.append(image)
        
        // 创建容器视图
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // 创建图片视图
        let imageView = NSImageView()
        imageView.image = image
        // 使用scaleProportionallyUpOrDown确保图片按比例缩放
        imageView.imageScaling = .scaleProportionallyUpOrDown
//      imageView.imageAlignment = .alignCenter
     
        // 启用图层支持并设置圆角和裁剪
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 8
        imageView.layer?.masksToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(imageView)
        
        // 创建删除按钮
        let deleteButton = NSButton()
        if #available(macOS 11.0, *) {
            deleteButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "删除".localized)
        } else {
            // Fallback on earlier versions
        }
        deleteButton.isBordered = false
      
        deleteButton.contentTintColor = .red
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        
        // 删除按钮点击事件
        deleteButton.target = self
        deleteButton.action = #selector(deleteImage(_:))
        deleteButton.tag = selectedImages.count - 1  // 使用tag记录图片索引
        
        containerView.addSubview(deleteButton)
        
        // 添加到StackView
        uploadStackView.addArrangedSubview(containerView)
        
        // 使用SnapKit设置约束 - 减小图片尺寸
        containerView.snp.makeConstraints { make in
            make.width.height.equalTo(65)  // 从82减小到65
        }
        
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        deleteButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(0)
            make.trailing.equalToSuperview().offset(-3)
            make.width.height.equalTo(18)  // 从20减小到18
        }
        
        // 更新scrollView高度
        updateScrollViewHeight()
    }
    
    // 删除图片
    @objc func deleteImage(_ sender: NSButton) {
        let index = sender.tag
        
        // 找到对应的容器视图并移除
        if index < uploadStackView.arrangedSubviews.count {
            let viewToRemove = uploadStackView.arrangedSubviews[index]
            uploadStackView.removeArrangedSubview(viewToRemove)
            viewToRemove.removeFromSuperview()
            
            // 从数组中移除
            if index < selectedImages.count {
                selectedImages.remove(at: index)
            }
            
            // 更新所有按钮的tag
            for (idx, view) in uploadStackView.arrangedSubviews.enumerated() {
                if let deleteBtn = view.subviews.compactMap({ $0 as? NSButton }).first {
                    deleteBtn.tag = idx
                }
            }
            
            // 更新scrollView高度
            updateScrollViewHeight()
        }
    }
    
    // 更新scrollView高度
    func updateScrollViewHeight() {
        let newHeight: CGFloat = selectedImages.isEmpty ? 0 : 65  // 从82改为65
        
        // 使用SnapKit更新高度约束
        uploadScrollView.snp.updateConstraints { make in
            make.height.equalTo(newHeight)
        }
        
        view.layoutSubtreeIfNeeded()
    }
   
    @objc func timeButtonClicked(){
        let dateTimePicker = MacDateTimePicker()
        dateTimePicker.delegate = self
        dateTimePicker.show(in: view)
    }
    @objc func submitAction(){
        let page=PagesCall(upWindow:self.view.window)
        var tipPost: NSWindow?
        if !NetworkMonitorConnectMac.shared.isReachable {
            showSheetAlert(message: "请检查网络连接".localized, in: self.view.window!)
            return
        }
        if textView.stringValue.count ?? 0 < 10 {
            showSheetAlert(message: "请填写10字以上的问题描述".localized, in: self.view.window!)
            return
        }
        if connetTextView.stringValue.count == 0 {
            showSheetAlert(message: "请填写联系方式".localized, in: self.view.window!)
            return
        }
        if timeLabel.stringValue.count == 0 {
            showSheetAlert(message: "请选择发生时间".localized, in: self.view.window!)
            return
        }
        if(isUpdate){
            isUpdate=false
            var picSpi: String=""
            var logSpi: String=""
            var reportVal: String=""
            let allImages = selectedImages
            let upLoader = OBSUploaderMac()
            if(switchControl.state == .on)
            {
                reportVal="true"
            }else{
                reportVal="false"
            }
            Task {
                do {
                    tipPost=page.feedBackTipControllerShow(tipLabel:"commitTips".localized,imageName:"img_Critical")
                    let dateStr = timeLabel.stringValue ?? ""
                    manger = ShareAPI.shared()
                    let filePath=self.manger?.getUploadLogFile("",ts: dateStr)
                    if((filePath?.isEmpty) != nil)
                    {
                        var uuid=UUID().uuidString
                        let response = try await upLoader.uploadFile(
                            objectKey: uuid+".zip",
                            filePath: String(filePath!)
                        )
                        if(response == 200)
                        {
                            logSpi="https://"+upLoader.bucketName+"."+upLoader.endpoint+"/"+uuid+".zip"
                        }
                    }
                    for item in allImages
                    {
                        var uuid=UUID().uuidString
                        let response = try await upLoader.uploadFile(
                            objectKey: uuid+".jpg",
                            uiImageData: item
                        )
                        if(response == 200)
                        {
                            picSpi=picSpi+"[https://"+upLoader.bucketName+"."+upLoader.endpoint+"/"+uuid+".jpg],"
                        }
                    }
                    
                    var picStr: String=""
                    if(picSpi.count>0)
                    {
                        picStr=String(picSpi.prefix(picSpi.count-1))
                    }else{
                        picStr="[],[],[]"
                    }
                    let feedbackUploader=FeedbackUploaderMac()
                    try await feedbackUploader.sendPostRequest(contact: connetTextView.stringValue ?? "",des: textView.stringValue ?? "",pic: picStr,report: reportVal,time: timeLabel.stringValue ?? "/",log: logSpi,appleUserID:"")
                    tipPost?.close()
                    let tipSuccess=page.feedBackTipControllerShow(tipLabel:"提交成功".localized,imageName:"icon_finish")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0){
                        tipSuccess.close()
                        self.view.window?.close()
                    }
                } catch {
                    tipPost?.close()
                    let tipFail=page.feedBackTipControllerShow(tipLabel:"提交失败请重试".localized,imageName:"img_Critical")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        tipFail.close()
                    }
                }
                isUpdate=true
            }
        }
    }
    func isNumber(_ text: String) -> Bool{
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = "^[0-9]+$"
            return trimmedText.range(of: pattern, options: .regularExpression) != nil
    }
    @objc func cancelButtonClicked(_ sender: NSButton) {
        guard let event = NSApp.currentEvent else { return }
        cancelButton.layer?.backgroundColor = NSColor(red: 0/255.0, green: 0/255.0, blue: 0/255.0, alpha: 0.3).cgColor
        self.view.window?.close()
        
    }
}
extension FeedbackController: MacDateTimePickerDelegate {
    func dateTimePicker(_ picker: MacDateTimePicker, didSelectDate date: Date) {
        // 格式化显示
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.locale = Locale(identifier: "zh_CN")
        let dateString = formatter.string(from: date)
        timeLabel.stringValue = dateString
    }
    func dateTimePickerDidCancel(_ picker: MacDateTimePicker) {
    }
}


//
//  DeviceNameController.swift
//  MutualInfection
//
//  Created by 1234 on 2025/9/25.
//

import Cocoa
import AppKit
import SnapKit
class DeviceNameController: NSViewController {
    var chageNameClick: ((String) -> Void)?
    var chageAvatarClick: ((_ image: NSImage) -> Void)?
    var userName: String? //用户名
    var userAvatar : NSImage?
    let minTextLength = 2
    let maxTextLength = 12
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 367, height: 416))
    }
    deinit{
        NotificationCenter.default.removeObserver(self)
        print("释放===========================================\(String(describing: type(of: self)))")
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        //self.view = NSView(frame: NSRect(x: 0, y: 0, width: 367, height: 416))
        view.layer?.backgroundColor = NSColor.mi.hex("#FFFFFF").cgColor
        setupViews()
        
        nameTextView.stringValue = Gloable.userName
        nameTextView.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(textFieldDidChange(_:)), name: NSTextField.textDidChangeNotification, object: nameTextView)
    }
    
    // MARK: - 布局 UI 元素
    private func setupViews() {
        [naviView, iconImageView, currentNameLabel, nameTextView, bottomLineView, descriptionLabel, cancelButton, submitButton, getDefaultNameButton].forEach {
            view.addSubview($0)
        }
        [closeButton, titleLabel].forEach {
            naviView.addSubview($0)
        }
        naviView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(40)
        }
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(12)
            make.leading.equalTo(12)
            make.width.height.equalTo(18)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(10)
            make.height.equalTo(40)
            make.centerX.equalToSuperview()
        }
        iconImageView.snp.makeConstraints { make in
            make.top.equalTo(naviView.snp.bottom).offset(10)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(80)
        }
        currentNameLabel.snp.makeConstraints { make in
            make.top.equalTo(iconImageView.snp.bottom).offset(8)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.height.equalTo(36)
        }
//        nameLabel.snp.makeConstraints { make in
//            make.top.equalTo(currentNameLabel.snp.bottom).offset(14)
//            make.leading.equalTo(32)
//            make.height.equalTo(26)
//            make.width.equalTo(50)
//        }
        nameTextView.snp.makeConstraints { make in
            make.top.equalTo(currentNameLabel.snp.bottom).offset(14)
            make.leading.equalTo(30)
            make.trailing.equalToSuperview().offset(-120)
        }
        getDefaultNameButton.snp.makeConstraints { make in
            make.centerY.equalTo(nameTextView.snp.centerY)
            make.trailing.equalToSuperview().offset(-30)
            make.width.lessThanOrEqualTo(80)
        }
        bottomLineView.snp.makeConstraints { make in
            make.top.equalTo(nameTextView.snp.bottom).offset(10)
            make.leading.equalTo(nameTextView.snp.leading).offset(0)
            make.trailing.equalToSuperview().offset(-30)
            make.height.equalTo(0.6)
        }
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(bottomLineView.snp.bottom).offset(12)
            make.leading.equalToSuperview().offset(28)
            make.trailing.equalToSuperview().offset(-28)
            make.width.equalTo(311)
        }
        cancelButton.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-20)
            make.trailing.equalTo(view.snp.centerX).offset(-10)
            make.height.equalTo(28)
            make.width.equalTo(80)
        }
        submitButton.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-20)
            make.leading.equalTo(view.snp.centerX).offset(10)
            make.height.equalTo(28)
            make.width.equalTo(80)
        }
    }
    
    // MARK: - 按钮交互逻辑
    @objc private func closeButtonAction() {
        self.view.window?.close()
    }
    
    // 处理iconImageView的点击事件
    @objc private func iconImageViewClicked() {
        // 创建文件选择器
        let openPanel = NSOpenPanel()

        // 设置文件选择器属性
        openPanel.title = "选择新图片".localized
//        openPanel.showsResizeIndicator = true
        openPanel.showsHiddenFiles = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.allowsMultipleSelection = false

        // 设置文件类型过滤（只允许图片文件）
        if #available(macOS 11.0, *) {
            openPanel.allowedContentTypes = [.image]
        } else {
            // Fallback on earlier versions
        }

        // 显示文件选择器
        openPanel.beginSheetModal(for: self.view.window!) { (response) in
            if response == .OK, let url = openPanel.url {
                // 读取选择的图片并设置到imageView
                if let image = NSImage(contentsOf: url) {
                    self.iconImageView.image = image
                    self.chageAvatarClick?(image)
                    NotificationCenter.default.post(
                        name: Notification.Name("AvatarDidChange"),
                        object: nil,
                        userInfo: ["newAvatar": image]
                    )
                    // 显示修改成功提示
                    showSheetAlert(message: "头像修改成功".localized, in: self.view.window!)
                }
            }
        }
    }
    
    @objc private func cancelAction(_ button: NSButton) {
        guard let event = NSApp.currentEvent else { return }
        switch event.type {
            case .leftMouseDown:
            button.layer?.backgroundColor = NSColor.mi.hex("#ffffff", alpha: 1).cgColor
                self.view.window?.close()
            case .leftMouseUp:
            button.layer?.backgroundColor = NSColor.mi.hex("#ffffff", alpha: 1).cgColor
            default: break
        }
        self.view.window?.close()
    }
    
    @objc private func submitAction(_ button: NSButton) {
        nameTextView.resignFirstResponder()
        let newName = nameTextView.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) // 获取输入的新名称
        if (newName.count) > 0  {

            //判断是否为空
            let isEmptyNameText = newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if isEmptyNameText {
                showSheetAlert(message: "设备名称不能为空".localized, in: self.view.window!)
                return
            }
            //判断是否符合字节长度
            let isValid = validateInput(newName)
            if(isValid == false && nameTextView.stringValue != Host.current().localizedName){
                showSheetAlert(message: "无法保存，需要12个字符以内".localized, in: self.view.window!)
                return
            }else {
                // 符合就去修改设备名称
                self.chageNameClick?(newName)
                //修改完成 执行
                NotificationCenter.default.post(
                    name: Notification.Name("NameDidChange"),
                    object: nil,
                    userInfo: ["newName": newName]
                )
                self.dismiss(true)
            }
        }else{
            showSheetAlert(message: "请输入设备名称".localized, in: self.view.window!)
            return
        }
        guard let event = NSApp.currentEvent else { return }
        switch event.type {
            case .leftMouseDown:
            button.layer?.backgroundColor = NSColor.mi.hex("#007AFF", alpha: 0.8).cgColor
                self.view.window?.close()
            case .leftMouseUp:
            button.layer?.backgroundColor = NSColor.mi.hex("#007AFF", alpha: 1).cgColor
            default: break
        }
        self.view.window?.close()
    }
    
    // 文本变化时的处理
    @objc private func textFieldDidChange(_ notification: Notification) {
        guard let textField = notification.object as? NSTextField else { return }

        // 获取当前文本
        let text = textField.stringValue

        // 过滤不允许的字符
        let filteredText = filterInvalidCharacters(text)

        // 如果文本被过滤，更新输入框
        if filteredText != text {
            textField.stringValue = filteredText
            return
        }

//        // 检查字符长度
        if text.count <= maxTextLength {
            descriptionLabel.stringValue = "2-12位字符，可包含英文字母、数字、汉字，该名称将在对方的搜索页面展示。".localized
            descriptionLabel.textColor = .mi.hex("#000000", alpha: 0.65)
            submitButton.alphaValue = 1.0
        }else{
            submitButton.alphaValue = 0.4
            descriptionLabel.stringValue = "账号名称最多输入 12 个字符".localized
            descriptionLabel.textColor = .mi.hex("#E84026", alpha: 0.65)
        }

    }

    // 过滤不允许的字符（只保留中文、英文、数字和空格）
    private func filterInvalidCharacters(_ text: String) -> String {
        let allowedPattern = "[\\u4e00-\\u9fa5a-zA-Z0-9 ]"
        let regex = try? NSRegularExpression(pattern: allowedPattern, options: [])
        var filteredText = ""

        for scalar in text.unicodeScalars {
            let char = String(scalar)
            let matches = regex?.matches(in: char, options: [], range: NSRange(location: 0, length: char.utf16.count))
            if matches?.count ?? 0 > 0 {
                filteredText.append(char)
            }
        }

        return filteredText
    }

    // 验证输入是否有效
    private func validateInput(_ text: String) -> Bool {
        
        // 检查长度是否在2-12个字符之间
        if text.count < minTextLength || text.count > maxTextLength {
            return false
        }

        // 检查是否只包含允许的字符
        let filteredText = filterInvalidCharacters(text)
        return filteredText == text
    }
    
    @objc private func getDefaultNameButtonAction(_ button: NSButton) {
        nameTextView.stringValue = Host.current().localizedName ?? "Mac"
        descriptionLabel.stringValue = "2-12位字符，可包含英文字母、数字、汉字，该名称将在对方的搜索页面展示。".localized
        descriptionLabel.textColor = .mi.hex("#000000", alpha: 0.65)
        submitButton.alphaValue = 1.0
    }

    //=================================================================
    //                            lazy
    //=================================================================
    // MARK: - lazy
    
    private lazy var naviView: NSView = {
        let headView = NSView()
        headView.wantsLayer = true
        headView.layer?.backgroundColor = NSColor.mi.hex("#F5F5F5", alpha: 0.8).cgColor
        return headView
    }()
    private lazy var closeButton: NSButton = {
        let closeButton = NSButton(title: "关闭".localized, target: nil, action:#selector(closeButtonAction))
        closeButton.setButtonType(.momentaryPushIn)
        closeButton.isBordered = false // 关键属性，禁用系统边框样式
        closeButton.wantsLayer = true // 启用图层支持
        closeButton.image = NSImage(named: "icon_close")
        closeButton.layer?.cornerRadius = 9
        closeButton.imageScaling = .scaleNone
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        return closeButton
    }()
    private lazy var titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "修改名称".localized)
        label.font = .mi.pingFangSCSemibold(size: 13)
        label.textColor = .mi.hex("#000000")
        label.alignment = .center
        label.isEditable = false
        label.isSelectable = false
        return label
    }()
    private lazy var iconImageView: NSImageView = {
        let imageView = NSImageView()
        imageView.image = Gloable.userAvatar
        imageView.imageScaling = .scaleAxesIndependently
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 40.0
        imageView.layer?.masksToBounds = true
        return imageView
    }()
    
    private lazy var currentNameLabel: NSTextField = {
        let label = NSTextField(labelWithString: Gloable.userName)
        label.textColor = .mi.hex("#000000")
        label.font = .mi.pingFangSCMedium(size: 17)
        label.isEditable = false
        label.isSelectable = false
        label.alignment = .center
        return label
    }()
    
    private lazy var nameLabel: NSTextField = {
        let label = NSTextField(labelWithString: "名称".localized)
        label.textColor = .mi.hex("#000000")
        label.font = .mi.pingFangSCMedium(size: 17)
        label.isEditable = false
        label.isSelectable = false
        label.backgroundColor = .red
        return label
    }()
    
    private lazy var nameTextView: NSTextField = {
        let connetTextView = NSTextField()
        connetTextView.placeholderString = "输入要修改的名称".localized
        connetTextView.isBezeled = true
        connetTextView.isBezeled = false
        connetTextView.focusRingType = .none
        connetTextView.font = .mi.pingFangSCRegular(size: 17)
        connetTextView.cell?.wraps = false
        connetTextView.cell?.isScrollable = true
        connetTextView.delegate = self
        return connetTextView
    }()
    private lazy var bottomLineView: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.mi.hex("#000000", alpha: 0.2).cgColor
        return view
    }()
    private lazy var descriptionLabel: NSTextField = {
        let label = NSTextField(labelWithString: "2-12位字符，可包含英文字母、数字、汉字，该名称将在对方的搜索页面展示。".localized)
        label.textColor = .mi.hex("#000000", alpha: 0.65)
        label.font = .mi.pingFangSCRegular(size: 13)
        label.alignment = .left
        label.isEditable = false
        label.isSelectable = false
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        return label
    }()
    
    private lazy var cancelButton: NSButton = {
        let button = NSButton(title: "取消".localized, target: self, action: #selector(cancelAction(_:)))
        button.font = .mi.pingFangSCMedium(size: 13)
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.mi.hex("#ffffff", alpha: 1).cgColor
        button.layer?.cornerRadius = 5
        button.layer?.masksToBounds = true
        button.layer?.borderWidth = 1
        button.layer?.borderColor = NSColor.mi.hex("#000000", alpha: 0.2).cgColor
        button.isBordered = false
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.mi.pingFangSCMedium(size: 13),
            .foregroundColor: NSColor.mi.hex("#000000", alpha: 1)
        ]
        button.attributedTitle = NSAttributedString(string: "取消".localized, attributes: attributes)
        return button
    }()
    
    private lazy var submitButton: NSButton = {
        let button = NSButton(title: "deviceNameComfirmBtn".localized, target: self, action: #selector(submitAction(_:)))
        button.font = .mi.pingFangSCMedium(size: 13)
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.mi.hex("#007AFF").cgColor
        button.layer?.cornerRadius = 6
        button.layer?.masksToBounds = true
        button.isBordered = false
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.mi.pingFangSCMedium(size: 13),
            .foregroundColor: NSColor.mi.hex("#FFFFFF", alpha: 1)
        ]
        button.attributedTitle = NSAttributedString(string: "deviceNameComfirmBtn".localized, attributes: attributes)
        return button
    }()
    
    private lazy var getDefaultNameButton: NSButton = {
        let button = NSButton(title: "恢复默认".localized, target: nil, action:#selector(getDefaultNameButtonAction(_:)))
        button.font = .mi.pingFangSCMedium(size: 13)
        button.wantsLayer = true
        button.isBordered = false
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.mi.hex("#336FFF", alpha: 1)
        ]
        button.attributedTitle = NSAttributedString(string: "恢复默认".localized, attributes: attributes)
        button.addCustomMarqueeLabel()
        
        return button
    }()
}

extension DeviceNameController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        let maxLength = 12 // 设置最大长度
//        if textField.stringValue.count > maxLength {
//            textField.stringValue = String(textField.stringValue.prefix(maxLength))
//        }
        // 未超出限制：正常允许
        if textField.stringValue.count <= maxTextLength {
            descriptionLabel.stringValue = "2-12位字符，可包含英文字母、数字、汉字，该名称将在对方的搜索页面展示。".localized
            descriptionLabel.textColor = .mi.hex("#000000", alpha: 0.65)
            submitButton.alphaValue = 1.0
        }else{
            submitButton.alphaValue = 0.4
            descriptionLabel.stringValue = "账号名称最多输入 12 个字符".localized
            descriptionLabel.textColor = .mi.hex("#E84026")
        }
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            // 检查是否按下组合键
            if let event = NSApp.currentEvent,
               event.modifierFlags.contains(.shift) {
                // Shift+回车：插入换行
                return false
            } else {
                // 纯回车：提交
                submitAction(submitButton)
                return true
            }
        }
        return false
    }
}

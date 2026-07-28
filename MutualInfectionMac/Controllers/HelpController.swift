//
//  HelpController.swift
//  MutualInfection
//
//  Created by 1234 on 2025/9/25.
//


import Cocoa
import AppKit
import SnapKit


let HelpControllerWidth: CGFloat = 367

class HelpController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    var upWindow:NSWindow!
    init(upWindow:NSWindow) {
        self.upWindow=upWindow
        super.init(nibName: nil, bundle: nil)
    }

    typealias HelpContentItem = [Any]
    typealias HelpSection = [HelpContentItem]
    typealias HelpItem = [Any]
    typealias HelpData = [HelpItem]

    // 帮助内容列表
    private var helpItems: HelpData = [
        ["文件互传设备条件".localized,
         [["对端设备：HarmonyOS软件版本6.0.0.112及以上的手机、平板、电脑。".localized, "本端设备：iOS 13及以上、iPad OS 13及以上、Mac OS 10.15及以上。".localized
//           ,"注：如已和华为设备配对，和该华为设备传输时，请在双端设备“设置-蓝牙”中，取消配对连接。避免传输失败".localized
          ],
          ["如无法发现对方设备，请完成以下操作后再试：".localized,
           ["1.如已和华为设备配对，和该华为设备传输时，请在双端设备“设置-蓝牙”中，取消配对连接。避免传输失败".localized,
            "2.如已打开其他互传文件的应用，请关闭其他互传应用".localized,
            "3.两端设备连接同一局域网，华为设备在控制中心将华为分享设为“所有人可见”。".localized]],
          ["如上述操作依旧无法发现对方设备：".localized,["建议一端设备开启热点，另一端设备手动连接热点后再试。".localized]]]
        ],
        ["发送与接收文件".localized,
         [["接收文件".localized,
           ["1.本设备打开“鸿蒙星河互联”app，并保持亮屏。".localized,
            "2.对方选择要发送的文件，在华为分享界面选择本设备。".localized,
            "3.与对方处于同一WLAN或连接对方热点，开始传输。".localized,
            ""
              ]
           ],
          ["发送文件".localized,
           ["方式一：鸿蒙星河互联app内发送".localized,
            "﻿1.对方开启华为分享，并保持亮屏。首次使用需设为“所有人可见”。".localized,
            "sendMethodsOneStepTwo".localized,
            "3.与对方处于同一WLAN或连接对方热点，开始传输。".localized,
              "@image",
            "",
            "方式二：通过“共享”选择鸿蒙星河互联app发送".localized,
            "1.对方开启华为分享，并保持亮屏。".localized,
            "sendMethodsTwoStepTwo".localized,
            "3.与对方处于同一WLAN或连接对方热点，开始传输。".localized,
              "@image"
             ]
           ]]
        ],
        ["commonQuestions".localized,
         ["问题1：Mac端打开鸿蒙星河APP后无法发现设备？".localized,
          "answerOne".localized,
          "",
          "问题2：Mac端总是提示连接失败/发送或接收不成功？".localized,
          "answerTwo".localized
          ]
        ]
     ]

    private lazy var tableView: NSTableView = {
        let tableView = NSTableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.headerView = nil

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "helpItem"))
        tableView.addTableColumn(column)

        return tableView
    }()
    override func loadView() {
        self.view=NSView(frame: NSRect(x: 0, y: 0, width: HelpControllerWidth, height: 416))
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        //self.view=NSView(frame: NSRect(x: 0, y: 0, width: 367, height: 416))
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
        let headLabel = NSTextField(labelWithString: "帮助与反馈".localized)
        headLabel.font = .mi.pingFangSCRegular(size: 13)
        headLabel.textColor = .mi.hex("#000000")
        headLabel.translatesAutoresizingMaskIntoConstraints = false
        headView.addSubview(headLabel)


        // 添加表格视图到滚动视图
        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        tableView.rowHeight = 0
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.backgroundColor = NSColor.clear
        tableView.usesAutomaticRowHeights = true

        // 创建右下角编辑按钮
        let editButton = NSButton(title: "意见反馈".localized, target: self, action: #selector(editButtonClicked))
        editButton.bezelStyle = .texturedRounded
        editButton.wantsLayer = true
        editButton.layer?.backgroundColor = NSColor(hex: "#0a59f7").cgColor
        editButton.layer?.cornerRadius = 20
        editButton.isBordered = false // 关键属性，禁用系统边框样式
        editButton.wantsLayer = true // 启用图层支持
        editButton.translatesAutoresizingMaskIntoConstraints = false
        if let image = NSImage(named: "icon_edit") {
            let resizedImage = NSImage(size: NSSize(width: 19, height: 19), flipped: false) { (dstRect) -> Bool in
                image.draw(in: dstRect, from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1.0)
                return true
            }
            editButton.image = resizedImage
        }
        editButton.imagePosition = .imageOnly
        editButton.contentTintColor = NSColor.white
        view.addSubview(editButton)
        
        headView.snp.makeConstraints {
            make in
            make.top.equalToSuperview().offset(0)
            make.centerX.equalToSuperview()
            make.width.equalTo(367)
            make.height.equalTo(40)
        }

        headLabel.snp.makeConstraints {
            make in
            make.top.equalTo(headView.snp.top).offset(12)
            make.centerX.equalTo(headView.snp.centerX)
        }

        closeButton.snp.makeConstraints {
            make in
            make.top.equalTo(headView.snp.top).offset(12)
            make.leading.equalTo(headView.snp.leading).offset(17)
            make.width.equalTo(18)
            make.height.equalTo(18)
        }

        scrollView.snp.makeConstraints {
            make in
            make.top.equalTo(headLabel.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(0)
            make.bottom.equalToSuperview().offset(-10)
        }

        editButton.snp.makeConstraints {
            make in
            make.leading.equalToSuperview().offset(313)
            make.trailing.equalToSuperview().offset(-12)
            make.top.equalToSuperview().offset(362)
            make.bottom.equalToSuperview().offset(-12)
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return helpItems.count
    }

    // 处理鼠标事件，防止选中效果
    private func tableView(_ tableView: NSTableView, shouldTrackCell cell: NSView, for tableColumn: NSTableColumn?, row: Int) -> Bool {
        return false
    }


    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return false
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let helpItem = helpItems[row]
        
        let identifier = NSUserInterfaceItemIdentifier("HelpControllerContentTableCellView")
        if let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? HelpControllerContentTableCellView {
            cell.setupUI(helpItem: helpItem)
            return cell
        }
        let newCell = HelpControllerContentTableCellView(identifier: identifier)
        newCell.setupUI(helpItem: helpItem)
        return newCell
    }

   func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        // 实现动态行高计算
       return -1
    }

    @objc func closeButtonClicked() {
        self.view.window?.close()
    }
    @objc func editButtonClicked() {
        self.view.window?.close()
        let page=PagesCall(upWindow: self.upWindow)
        page.feedbackWindowShow()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


//MARK: cell
class HelpControllerContentTableCellView: NSTableCellView {
    // 初始化
    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        self.identifier = identifier
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - lazy
    private lazy var cellView: NSView = {
        let view = NSView(frame: .zero)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false // 关键：启用自动布局
        self.addSubview(view)
        
        view.snp.makeConstraints { make in
            make.centerX.top.bottom.equalTo(0)
            make.width.equalTo(HelpControllerWidth - 15 * 2)//不知道为什么 HelpControllerContentTableCellView 无法跟随 talbview自适应宽度，只好暂时写死宽度
        }
        return view
    }()
    
    func setupUI(helpItem: [Any]) {
        for subview in cellView.subviews.reversed() {
            subview.removeFromSuperview()
        }

        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 2
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // 先添加到父视图，再设置约束
        cellView.addSubview(stackView)

        // 获取标题
        if let title = helpItem.first as? String {
            // 创建标题标签
            let titleLabel = NSTextField(labelWithString: title)
            titleLabel.font = NSFont.mi.pingFangSCMedium(size: 13)
            titleLabel.textColor = NSColor.black
            titleLabel.alphaValue = 0.9
            titleLabel.alignment = .left
            titleLabel.isEditable = false
            titleLabel.isSelectable = false
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            
            stackView.addArrangedSubview(titleLabel)
            titleLabel.snp.makeConstraints {
                make in
                make.leading.equalToSuperview().offset(0)
                make.trailing.equalToSuperview().offset(0)
            }
        }

        // 获取内容部分
        if helpItem.count > 1 {
            if let content = helpItem[1] as? [Any] {
                // 递归渲染内容
                renderContent(content, into: stackView, indentLevel: 1)
            }
        }

        // 设置栈视图约束
        stackView.snp.makeConstraints {
            make in
            make.top.equalToSuperview().inset(0)
            make.bottom.equalToSuperview().inset(20)
            make.leading.equalToSuperview().offset(15)
            make.trailing.equalToSuperview().offset(-15)
        }
   }

    // 递归渲染内容
    private func renderContent(_ content: [Any], into stackView: NSStackView, indentLevel: Int) {
        var imageCounter = 0
        let indentation = CGFloat(15 * indentLevel)

        for item in content {
            // 处理嵌套结构
            if let subContent = item as? [Any], subContent.count > 0 {
                if let subTitle = subContent[0] as? String, let _ = subContent[1] as? [String] {
                    // 创建子标题标签
                    let subTitleLabel = NSTextField(labelWithString: subTitle)
                    subTitleLabel.font = NSFont.mi.pingFangSCMedium(size: 11)
                    subTitleLabel.textColor = NSColor.black
                    subTitleLabel.alphaValue = 0.6
                    subTitleLabel.alignment = .left
                    subTitleLabel.isEditable = false
                    subTitleLabel.isSelectable = false
                    subTitleLabel.lineBreakMode = .byWordWrapping
                    subTitleLabel.maximumNumberOfLines = 0
                    subTitleLabel.translatesAutoresizingMaskIntoConstraints = false

                    // 先添加到父视图，再设置约束
                    stackView.addArrangedSubview(subTitleLabel)
                    
                    // 添加缩进
                    subTitleLabel.snp.makeConstraints {
                        make in
                        make.leading.equalToSuperview().offset(0)
                        make.trailing.equalToSuperview().offset(0)
                    }

                    // 递归渲染子内容
                    if subContent.count > 1 {
                        if let subSubContent = subContent[1] as? [Any] {
                            renderContent(subSubContent, into: stackView, indentLevel: indentLevel + 1)
                        }
                    }
                } else {
                    // 继续递归处理其他嵌套结构
                    renderContent(subContent, into: stackView, indentLevel: indentLevel)
                }
            } else if let text = item as? String {
                // 处理文本内容
                if text == "@image" {
                    // 处理图片标记，创建一个居中的图片占位符
                    let imageContainer = NSView()
                    imageContainer.wantsLayer = true
                    imageContainer.layer?.backgroundColor = .clear
                    imageContainer.layer?.cornerRadius = 8
                    imageContainer.translatesAutoresizingMaskIntoConstraints = false

                    // 创建居中的图片
                    let imageView = NSImageView()
                    let imageName = imageCounter == 0 ? "illustration_Onemac" : "illustration_Twomac"
                    imageView.image = NSImage(named: imageName)
                    imageCounter += 1
                    imageView.translatesAutoresizingMaskIntoConstraints = false
                    
                    // 先添加到父视图，再设置约束
                    imageContainer.addSubview(imageView)

                    // 图片居中约束
                    imageView.snp.makeConstraints {
                        make in
                        make.center.equalToSuperview()
//                        make.width.equalTo(343)
                        make.leading.trailing.equalToSuperview()
                        make.height.equalTo(206)
                    }
                    
                    // 先添加到stackView，再设置相对于stackView的约束
                    stackView.addArrangedSubview(imageContainer)

                    // 图片容器宽度约束
                    imageContainer.snp.makeConstraints {
                        make in
                        make.leading.trailing.equalToSuperview()
                        make.height.equalTo(206)
                        make.centerX.equalTo(stackView)
                    }
                } else {
                    // 创建文本标签
                    let textLabel = NSTextField(wrappingLabelWithString: text)
                    if (text == "问题1：Mac端打开鸿蒙星河APP后无法发现设备？".localized || text == "问题2：Mac端总是提示连接失败/发送或接收不成功？".localized) {
                        let attributedString = NSMutableAttributedString(string: text)
                        let firstPart = text.localized
                        if let firstRange = text.range(of: firstPart) {
                            let firstNSRange = NSRange(firstRange, in: text)
                            attributedString.addAttribute(.font,
                                                        value: NSFont.mi.pingFangSCMedium(size: 11),
                                                        range: firstNSRange)
                        }
                        textLabel.attributedStringValue = attributedString
                    }
                    if (text == "﻿1.对方开启华为分享，并保持亮屏。首次使用需设为“所有人可见”。".localized) {
                        let attributedString = NSMutableAttributedString(string: text)
                        let firstPart = "1.对方开启华为分享，".localized
                        if let firstRange = text.range(of: firstPart) {
                            let firstNSRange = NSRange(firstRange, in: text)
                            attributedString.addAttribute(.foregroundColor,
                                                        value: NSColor.black.withAlphaComponent(0.6),
                                                        range: firstNSRange)
                        }
                        let secondPart = "并保持亮屏。".localized
                        if let secondRange = text.range(of: secondPart) {
                            let secondNSRange = NSRange(secondRange, in: text)
                            attributedString.addAttribute(.foregroundColor,
                                                        value: NSColor.blue,
                                                        range: secondNSRange)
                        }
                        let targetText = "首次使用需设为“所有人可见”。".localized
                        if let range = text.range(of: targetText) {
                            let nsRange = NSRange(range, in: text)
                            attributedString.addAttribute(.foregroundColor,
                                                         value: NSColor.blue,
                                                         range: nsRange)
                        }
                        textLabel.attributedStringValue = attributedString
                    } else {
                        textLabel.textColor = NSColor.black
                        textLabel.alphaValue = 0.6
                    }
                    if (text == "1.本设备打开“鸿蒙星河互联”app，并保持亮屏。".localized || text == "1.对方开启华为分享，并保持亮屏。".localized) {
                        let attributedString = NSMutableAttributedString(string: text)
                        textLabel.alphaValue = 1
                        let firstPart = "1.本设备打开“鸿蒙星河互联”app，".localized
                        if let firstRange = text.range(of: firstPart) {
                            let firstNSRange = NSRange(firstRange, in: text)
                            attributedString.addAttribute(.foregroundColor,
                                                        value: NSColor.black.withAlphaComponent(0.6),
                                                        range: firstNSRange)
                        }
                        let secondPart = "1.对方开启华为分享，".localized
                        if let secondRange = text.range(of: secondPart) {
                            let secondNSRange = NSRange(secondRange, in: text)
                            attributedString.addAttribute(.foregroundColor,
                                                        value: NSColor.black.withAlphaComponent(0.6),
                                                        range: secondNSRange)
                        }
                        let targetPart = "并保持亮屏。".localized
                        if let targetRange = text.range(of: targetPart) {
                            let targetNSRange = NSRange(targetRange, in: text)
                            attributedString.addAttribute(.foregroundColor,
                                                          value: NSColor.blue,
                                                          range: targetNSRange)
                        }
                        textLabel.attributedStringValue = attributedString
                    }
                    if (text == "1.如已和华为设备配对，和该华为设备传输时，请在双端设备“设置-蓝牙”中，取消配对连接。避免传输失败".localized || text == "2.如已打开其他互传文件的应用，请关闭其他互传应用".localized || text == "3.两端设备连接同一局域网，华为设备在控制中心将华为分享设为“所有人可见”。".localized || text == "建议一端设备开启热点，另一端设备手动连接热点后再试。".localized) {
                        let attributedString = NSMutableAttributedString(string: text)
                        let targetPart1 = "1.如已和华为设备配对，和该华为设备传输时，请在双端设备“设置-蓝牙”中，取消配对连接。避免传输失败".localized
                        if let targetRange = text.range(of: targetPart1) {
                            let targetNSRange = NSRange(targetRange, in: text)
                            attributedString.addAttribute(.foregroundColor,
                                                          value: NSColor.blue,
                                                          range: targetNSRange)
                        }
                        let targetPart2 = "2.如已打开其他互传文件的应用，请关闭其他互传应用".localized
                        if let targetRange = text.range(of: targetPart2) {
                            let targetNSRange = NSRange(targetRange, in: text)
                            attributedString.addAttribute(.foregroundColor,
                                                          value: NSColor.blue,
                                                          range: targetNSRange)
                        }
                        let targetPart3 = "3.两端设备连接同一局域网，华为设备在控制中心将华为分享设为“所有人可见”。".localized
                        if let targetRange = text.range(of: targetPart3) {
                            let targetNSRange = NSRange(targetRange, in: text)
                            attributedString.addAttribute(.foregroundColor,
                                                          value: NSColor.blue,
                                                          range: targetNSRange)
                        }
                        let targetPart4 = "建议一端设备开启热点，另一端设备手动连接热点后再试。".localized
                        if let targetRange = text.range(of: targetPart4) {
                            let targetNSRange = NSRange(targetRange, in: text)
                            attributedString.addAttribute(.foregroundColor,
                                                          value: NSColor.blue,
                                                          range: targetNSRange)
                        }
                        textLabel.attributedStringValue = attributedString
                    }
                    
                    
                    textLabel.font = NSFont.mi.pingFangSCRegular(size: 11)
                    textLabel.alignment = .left
                    textLabel.isEditable = false
                    textLabel.isSelectable = false
                    textLabel.lineBreakMode = .byWordWrapping
                    textLabel.maximumNumberOfLines = 0
                    textLabel.translatesAutoresizingMaskIntoConstraints = false

                    // 先添加到父视图，再设置约束
                    stackView.addArrangedSubview(textLabel)
                    
                    // 添加缩进
                    textLabel.snp.makeConstraints {
                        make in
                        make.leading.equalToSuperview().offset(0)
                        make.trailing.equalToSuperview().offset(0)
                    }
                }
            }
        }
    }
}

//
//  MainWindowController+Nav.swift
//  MutualInfection
//
//  Created by 1234 on 2025/10/17.
//

import Foundation
import AppKit

extension MainWindowController
{
    func setCustomImage(){
        ownPhotoView = CustomImageView(nsImage:Gloable.userAvatar,size: NSSize(width: 40, height: 40))
        self.view.addSubview(ownPhotoView)
        ownPhotoView.snp.makeConstraints {
            make in
            make.top.equalTo(self.view.snp.top).offset(16)
            make.leading.equalTo(self.view.snp.leading).offset(kOriMainWindowMargin+12)
            make.width.equalTo(48)
            make.height.equalTo(48)
        }
    }
    func setTipLabel(){
        let bgView = NSView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height))
        view.addSubview(bgView)
        bgView.snp.makeConstraints { make in
            make.leading.equalTo(self.ownPhotoView.snp.trailing).offset(16)
            make.centerY.equalTo(ownPhotoView)
        }
        let tipLabel = NSTextField(labelWithString: "以此身份使用鸿蒙星河互联".localized)

        tipLabel.font = .mi.pingFangSCRegular(size: 11)
        tipLabel.textColor = NSColor.mi.hex("#3C3C43",alpha: 0.4)
//        tipLabel.alphaValue = 0.45
        tipLabel.translatesAutoresizingMaskIntoConstraints = false
        bgView.addSubview(tipLabel)
        ownNameLabel = NSTextField(labelWithString: Gloable.userName)
        ownNameLabel.font = .mi.pingFangSCSemibold(size: 16)
        ownNameLabel.textColor = .mi.hex("#000000")
        ownNameLabel.translatesAutoresizingMaskIntoConstraints = false
        bgView.addSubview(ownNameLabel)
        let line = NSView(frame: CGRect(x: 0, y: 0, width: 500, height: 1))
        line.wantsLayer = true
        line.layer?.backgroundColor = NSColor.mi.hex("#000000", alpha:0.1).cgColor
        line.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(line)
        line.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(0)
            make.top.equalTo(ownPhotoView.snp.bottom).offset(16)
            make.height.equalTo(0.5)
            make.trailing.equalToSuperview().offset(0)
        }
        
        tipLabel.snp.makeConstraints {
            make in
//            make.top.equalTo(ownPhotoView.snp.top).offset((84-58)/2.0)
            make.top.equalToSuperview()
            make.leading.equalToSuperview()
        }
        ownNameLabel.snp.makeConstraints {
            make in
            make.top.equalTo(tipLabel.snp.bottom).offset(0)
            make.leading.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }
    func setMoreMeum(){
        moreMeumView = MoreMeumView(frame: .zero)
        guard let moreMeumView = moreMeumView else { return }
        moreMeumView.wantsLayer = true
        moreMeumView.layer?.backgroundColor = NSColor.white.cgColor
        moreMeumView.isHidden=true
        moreMeumView.layer?.cornerRadius = 10
        self.view.addSubview(moreMeumView,positioned: .above,  relativeTo: nil)
        
        moreMeumView.snp.makeConstraints {
            make in
            if let topRightButton = topRightButton {
                make.top.equalTo(topRightButton.snp.bottom).offset(8)
            } else {
                make.top.equalTo(self.view.snp.top).offset(64)
            }
            make.leading.equalTo(self.view.snp.trailing).offset(-kOriMainWindowMargin-82-68)
            make.width.equalTo(226)
//            make.height.equalTo(243)
        }
    }
    func setTopButton(){
        let topButton = NSButton(title: "显示菜单".localized, target: nil, action:#selector(topButtonClicked))
        topButton.setButtonType(.momentaryChange)
        topButton.isBordered = false // 关键属性，禁用系统边框样式
        topButton.wantsLayer = true // 启用图层支持
        topButton.image = NSImage(named: "button_more_1122")
        topButton.imageScaling = .scaleAxesIndependently
        topButton.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(topButton)
        topButton.snp.makeConstraints {
            make in
            make.centerY.equalTo(self.ownPhotoView.snp.centerY)
            make.trailing.equalTo(self.view.snp.trailing).offset(-kOriMainWindowMargin)
            make.width.equalTo(32)
            make.height.equalTo(32)
        }
        
        topRightButton = topButton
    }
    func setUpBottomView(){
        bottomView = NSView()
        
        guard let bottomView = bottomView else { return }
        view.addSubview(bottomView)
        bottomView.snp.makeConstraints { make in
            make.leading.equalTo(kOriMainWindowMargin)
            make.trailing.equalTo(-kOriMainWindowMargin)
            make.bottom.equalToSuperview().offset(-16)
            
//            make.width.lessThanOrEqualTo(kOriMainWindowWidth-2*kOriMainWindowMargin).priority(.required)
        }
        let leftTitleLb = NSTextField(labelWithString: "device_not_found".localized)
        leftTitleLb.textColor = .mi.hex("#3c3c43", alpha: 0.6)
        leftTitleLb.font = .mi.pingFangSCRegular(size: 12)
        bottomView.addSubview(leftTitleLb)
        leftTitleLb.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.top.equalToSuperview()
        }
        
        let rightButtonAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.mi.pingFangSCRegular(size: 12),
            .foregroundColor: NSColor.mi.hex("#0a59f7")
        ]

        let rightBtn:NSButton = {
           let btn = NSButton(title: "learn_more".localized, target: self, action: #selector(knowDetail))
            btn.wantsLayer = true
            btn.isBordered = false
            btn.setButtonType(.momentaryPushIn)
            
            btn.attributedTitle = NSAttributedString(string: "learn_more".localized, attributes: rightButtonAttributes)
            return btn
        }()
        bottomView.addSubview(rightBtn)
        rightBtn.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-8)
//            make.centerY.equalTo(leftTitleLb)
            make.top.equalToSuperview()
        }
        
        let rightContView:NSView = {
            let v = NSView()
            v.wantsLayer = true
            v.layer?.backgroundColor = NSColor.mi.hex("#000000", alpha: 0.02).cgColor
            v.layer?.borderColor = NSColor.mi.hex("#000000", alpha: 0.05).cgColor
            v.layer?.cornerRadius = 12
            v.layer?.borderWidth = 1
            v.wantsLayer = true
            return v
        }()
        bottomView.addSubview(rightContView)
        rightContView.snp.makeConstraints { make in
            make.top.equalTo(rightBtn.snp.bottom).offset(6)
            make.leading.equalTo(bottomView.snp.centerX).offset(6)
            make.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
//            make.height.greaterThanOrEqualTo(90)
        }
        
        let leftContView:NSView = {
            let v = NSView()
            v.wantsLayer = true
            v.layer?.backgroundColor = NSColor.mi.hex("#000000", alpha: 0.02).cgColor
            v.layer?.borderColor = NSColor.mi.hex("#000000", alpha: 0.05).cgColor
            v.layer?.cornerRadius = 12
            v.layer?.borderWidth = 1
            return v
        }()
        bottomView.addSubview(leftContView)
        leftContView.snp.makeConstraints { make in
            make.top.equalTo(leftTitleLb.snp.bottom).offset(6)
            make.leading.equalToSuperview()
            make.trailing.equalTo(bottomView.snp.centerX).offset(-6)
            make.height.equalTo(rightContView)
            make.bottom.equalToSuperview()
        }
        
        let leftCenterView:NSView = {
            let v = NSView()
            v.wantsLayer = true
            return v
        }()
        leftContView.addSubview(leftCenterView)
        leftCenterView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        
        let leftDesTitleLb:NSTextField = {
            let textf = NSTextField(labelWithString: "version_requirements".localized)
            textf.textColor = .mi.hex("#000000", alpha: 0.9)
            textf.font = .mi.pingFangSCRegular(size: 12)
            return textf
        }()
        leftCenterView.addSubview(leftDesTitleLb)
        leftDesTitleLb.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalToSuperview()
            make.trailing.equalToSuperview().offset(-16)
//            make.height.equalTo(18)
        }
        
//        // 创建基础属性
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.mi.pingFangSCRegular(size: 11),
            .foregroundColor: NSColor.mi.hex("#000000", alpha: 0.4)]
//
        let leftAttributedString = NSMutableAttributedString(string: "version_requirements_content".localized, attributes: baseAttributes)
        let leftDesLb:NSTextField = {
           let textf = NSTextField(labelWithAttributedString: leftAttributedString)
            textf.textColor = .mi.hex("#000000", alpha: 0.4)
            textf.font = .mi.pingFangSCRegular(size: 11)
            textf.wantsLayer = true
            textf.isBezeled = false
            textf.isEditable = false       // 只读（模拟label行为）
            textf.isSelectable = false     // 不可选中
            textf.backgroundColor = .clear // 透明背景（和label一致）
            textf.isBordered = false
            textf.maximumNumberOfLines = 0
            textf.lineBreakMode = .byCharWrapping
            textf.layer?.backgroundColor = NSColor.clear.cgColor
            if let textFieldCell = textf.cell as? NSTextFieldCell {
                textFieldCell.drawsBackground = false // 禁用Cell背景绘制（核心）
                textFieldCell.backgroundColor = .clear // 兜底：Cell背景透明
                textFieldCell.wraps = true               // 允许换行
                textFieldCell.isScrollable = false       // 禁用滚动
                textFieldCell.usesSingleLineMode = false // 禁用单行模式（核心中的核心）
                textFieldCell.truncatesLastVisibleLine = false // 禁用截断，强制换行
            }
            return textf
        }()
        
        leftCenterView.addSubview(leftDesLb)
        leftDesLb.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalTo(leftDesTitleLb.snp.bottom).offset(2)
            make.trailing.equalToSuperview().offset(-16).priority(.low)
            make.bottom.equalToSuperview()

//            make.width.lessThanOrEqualTo((kOriMainWindowWidth-2*kOriMainWindowMargin-12-16*4)/2)
        }
        
        let rightCenterView:NSView = {
            let v = NSView()
            v.wantsLayer = true
            return v
        }()
        rightContView.addSubview(rightCenterView)
        rightCenterView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
            make.top.equalToSuperview().offset(10)
            make.bottom.equalToSuperview().offset(-10)
        }
        let rightDesTitleLb:NSTextField = {
           let textf = NSTextField(labelWithString: "found_huawei_devices".localized)
            textf.textColor = .mi.hex("#000000", alpha: 0.9)
            textf.font = .mi.pingFangSCRegular(size: 12)
            return textf
        }()
        rightCenterView.addSubview(rightDesTitleLb)
        rightDesTitleLb.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalToSuperview()
            make.trailing.equalToSuperview().offset(-16)
            make.height.equalTo(18)
        }
        let rightDesStr = "对方需在控制中心将华为分享设置成“所有人可见”，本端需在app右上角的“设置-系统管理权限”中打开位置和蓝牙".localized
        
        // 创建特殊样式属性
        let specialAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.mi.pingFangSCMedium(size: 11),
            .foregroundColor: NSColor.mi.hex("#000000", alpha: 0.6)]

        // 创建可变的属性字符串
        let attributedString = NSMutableAttributedString(string: rightDesStr, attributes: baseAttributes)
        // 查找需要特殊样式的文字范围
        let specialTexts = ["所有人可见".localized, "位置".localized, "蓝牙".localized]
        for text in specialTexts {
            let range = (rightDesStr as NSString).range(of: text)
            if range.location != NSNotFound {
                attributedString.addAttributes(specialAttributes, range: range)
            }
        }
        let rightDesLb:NSTextField = {
            let textf = NSTextField(labelWithAttributedString: attributedString)
            textf.maximumNumberOfLines = 0
            textf.isSelectable = false
            textf.isEditable = false
            textf.cell?.wraps = true  // 启用自动换行
            textf.cell?.isScrollable = false  // 必须设为false才能自动换行
            textf.cell?.usesSingleLineMode = false
            textf.lineBreakMode = .byCharWrapping  // 按单词换行
            return textf
        }()
        rightCenterView.addSubview(rightDesLb)
        rightDesLb.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalTo(rightDesTitleLb.snp.bottom).offset(4)
            make.bottom.equalToSuperview()
            make.trailing.equalToSuperview().offset(-16).priority(.low)
        }
    }
    
    @objc func knowDetail(){
        
        let page=PagesCall(upWindow:view.window)
        page.helpWindowShow()
    }
    func setBottomLabel(){
        bottomLabel = NSTextField(labelWithString: "支持与HarmonyOS 6 及以上版本华为设备互传，\n对方需在控制中心将华为分享设为“所有人可见”，\n本端需在app右上角的“设置-系统权限管理”中打开位置和蓝牙".localized)
        guard let bottomLabel = bottomLabel else { return }
        bottomLabel.font = .mi.pingFangSCRegular(size: 11)
        bottomLabel.textColor = .mi.hex("#3C3C43",alpha:0.4)
        bottomLabel.alignment = .center
        bottomLabel.maximumNumberOfLines = 0
        bottomLabel.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(bottomLabel)

        bottomLabel.snp.makeConstraints {
            make in
            make.bottom.equalTo(self.view.snp.bottom).offset(-24)
//            make.centerX.equalToSuperview()
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalToSuperview().offset(-24)
        }
        
        // 添加内容压缩阻力优先级
        bottomLabel.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        bottomLabel.setContentHuggingPriority(.defaultLow, for: .vertical)
    }
    @objc func topButtonClicked() {
        
        guard let moreMeumView = moreMeumView else { return }
        if(moreMeumView.isHidden)
        {
            Gloable.isMoreMeumShow=true
            moreMeumView.isHidden=false
        }else{
            Gloable.isMoreMeumShow=false
            moreMeumView.isHidden=true
        }
        //TODO 测试代码，接收页面入口
//        let popupsCall=PagesCall(upWindow:self.view.window!)
//        popupsCall.receptOrNotPopShow("", metadata: [:])

//        TODO 测试代码
//        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
//        if let url = paths.first {
//            NSWorkspace.shared.open(url)
//        }
    }
    override func mouseDown(with event: NSEvent) {
        
        guard let moreMeumView = moreMeumView else { return }
//        Gloable.isMoreMeumShow=false
//        moreMeumView.isHidden = true
        // 检查moreMenuView是否可见
        if !moreMeumView.isHidden {
            // 获取鼠标在当前视图中的位置
            let mouseLocation = event.locationInWindow
            // 或者 2. 使用moreMenuView自己的坐标系统
            let pointInMenuView = moreMeumView.convert(mouseLocation, from: nil)
            let isPointInMenu = moreMeumView.bounds.contains(pointInMenuView)
            
            //            if !isPointInMenu {
            //                Gloable.isMoreMeumShow = false
            //                moreMeumView.isHidden = true
            //            }
            // 检查点击是否在窗口边缘区域
            var isPointInMenuEdgeArea = false
            
            // 使用contentView的superview来获取窗口尺寸
            if isPointInMenu {
                let menuSize = moreMeumView.bounds.size
                
                // moreMeumView的边缘区域定义
                let edgeInsets = NSEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
                
                // 最左边16像素
                if pointInMenuView.x <= edgeInsets.left {
                    isPointInMenuEdgeArea = true
                }
                // 最右边16像素
                else if pointInMenuView.x >= menuSize.width - edgeInsets.right {
                    isPointInMenuEdgeArea = true
                }
                // 最上边10像素
                else if pointInMenuView.y >= menuSize.height - edgeInsets.top {
                    isPointInMenuEdgeArea = true
                }
                // 最下边10像素
                else if pointInMenuView.y <= edgeInsets.bottom {
                    isPointInMenuEdgeArea = true
                }
            }
            // 如果点击在外部 或者 在边缘区域，都隐藏菜单
            if !isPointInMenu || isPointInMenuEdgeArea {
                Gloable.isMoreMeumShow = false
                moreMeumView.isHidden = true
            }
        }
    }
}

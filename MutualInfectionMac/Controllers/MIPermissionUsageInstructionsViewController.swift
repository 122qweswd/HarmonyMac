//
//  MIPermissionUsageInstructionsViewController.swift
//  MutualInfection
//
//  Created by apple on 2025/12/3.
//

import Cocoa
import AppKit
import SnapKit

class MIPermissionUsageInstructionsViewController: NSViewController {
    
    var itemArr: [MIPermissionUsageInstructionsItem] = {
        let item01 = MIPermissionUsageInstructionsItem()
        item01.content = "使用过程中申请".localized
        let item02 = MIPermissionUsageInstructionsItem()
        item02.title = "无线局域网".localized
        item02.content = "用于在相同局域网下连接设备，传输文件".localized
        let item03 = MIPermissionUsageInstructionsItem()
        item03.title = "蓝牙".localized
        item03.content = "用于使用蓝牙搜索附近的设备".localized
        let item04 = MIPermissionUsageInstructionsItem()
        item04.title = "位置".localized
        item04.content = "用于判断是否处于同一局域网".localized
        let item05 = MIPermissionUsageInstructionsItem()
        item05.title = "照片".localized
        item05.content = "用于互传时读取照片，视频等文件".localized
        let item06 = MIPermissionUsageInstructionsItem()
        item06.title = "通讯录".localized
        item06.content = "用于互传时读取通讯录".localized
        let item07 = MIPermissionUsageInstructionsItem()
        item07.title = "存储权限".localized
        item07.content = "用于存储传输记录".localized
        return [item01,
                item02,
                item03,
                item04,
                item05,
                item06,
                item07]
    }()
    
    private lazy var closeButton: NSButton = {
        let button = NSButton(title: "", target: self, action:#selector(closeButtonClicked))
        button.setButtonType(.momentaryPushIn)
        button.isBordered = false // 关键属性，禁用系统边框样式
        button.wantsLayer = true // 启用图层支持
        button.image = NSImage(named: "icon_recordClose")
        button.layer?.cornerRadius = 15
        button.imageScaling = .scaleProportionallyUpOrDown
        button.isEnabled = true
        return button
    }()
    
    private lazy var titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "权限使用说明".localized)
        label.font = .mi.pingFangSCMedium(size: 24)
        label.textColor = .mi.hex("#000000", alpha: 0.9)
            .withAlphaComponent(0.9)
        label.alignment = .center
        return label
    }()
    
    // MARK: - UI 组件
    private lazy var tableView: NSTableView = {
        let tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.wantsLayer = false
        tableView.usesAutomaticRowHeights = true
        // 设置选择样式
        tableView.selectionHighlightStyle = .none
        if #available(macOS 11.0, *) {
            // 使用传统样式
            tableView.style = .plain
        }
        
        // 添加列
        let titleColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SourceColumn"))
        titleColumn.width = 350
        tableView.addTableColumn(titleColumn)
        
        return tableView
    }()
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 705, height: 499))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.white.cgColor
        setupCustomLayout()
        
        tableView.reloadData()
    }
    
    private func setupCustomLayout() {
        view.addSubview(titleLabel)
        view.addSubview(tableView)
        view.addSubview(closeButton)
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(10)
            make.leading.trailing.equalTo(0)
            make.height.equalTo(30)
        }
        
        closeButton.snp.makeConstraints {  make in
            make.centerY.equalTo(titleLabel)
            make.leading.equalTo(20)
            make.width.equalTo(30)
            make.height.equalTo(30)
        }
        
        tableView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom)
            make.bottom.equalTo(-30)
            make.leading.trailing.equalTo(0)
        }
    }
    
    @objc private func closeButtonClicked() {
        view.isHidden = true
        view.removeFromSuperview()
        self.removeFromParent()
    }
}


// MARK: - NSTableView 数据源和代理
extension  MIPermissionUsageInstructionsViewController: NSTableViewDataSource, NSTableViewDelegate {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return itemArr.count
    }
    
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = itemArr[row]
        
        let identifier = NSUserInterfaceItemIdentifier("MIPermissionUsageInstructionsCell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? MIPermissionUsageInstructionsCell ?? {
            let newCell = MIPermissionUsageInstructionsCell()
            return newCell
        }()

        cell.configure(item)
        return cell
    }
}

class MIPermissionUsageInstructionsItem: NSObject {
    var title: String = ""
    var content: String = ""
}

class MIPermissionUsageInstructionsCell: NSTableCellView {
    
    
    private lazy var stack: NSStackView = {
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 2
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private lazy var titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .mi.pingFangSCMedium(size: 14)
        label.textColor = .mi.hex("#000000")
        label.alignment = .left
        return label
    }()
    
    private lazy var contentLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .mi.pingFangSCRegular(size: 14)
        label.textColor = .mi.hex("#000000", alpha: 0.6)
        label.alignment = .left
        return label
    }()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupUI() {
        addSubview(stack)
        
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(contentLabel)
        
        // 设置栈视图约束
        stack.snp.makeConstraints { make in
            make.top.equalTo(10)
            make.bottom.equalTo(-10)
            make.leading.equalTo(20)
            make.trailing.equalTo(-20)
        }
    }
    
    func configure(_ item: MIPermissionUsageInstructionsItem) {
        titleLabel.stringValue = item.title
        titleLabel.isHidden = item.content.count > 0 ? false : true
        contentLabel.stringValue = item.content
    }
}

//
//  MIAboutTableCellView.swift
//  MutualInfectionMac
//
//  Created by delegate on 2025/9/29.
//

import AppKit

class MIAboutTableCellView: NSTableCellView {
    var leftAboutModel: MILeftAboutModel = MILeftAboutModel(title: "", isSelected: false) {
        didSet {
            if leftAboutModel.isSelected {
                bgView.layer?.backgroundColor = NSColor.mi.hex("#D8D8DC", alpha: 1).cgColor
            }else {
                bgView.layer?.backgroundColor = NSColor.mi.hex("#F5F5F5", alpha: 1).cgColor
            }
            contentTextField.stringValue = leftAboutModel.title
        }
    }
    // 初始化
    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        self.identifier = identifier
        setupUI()
    }
    private func setupUI() {
        
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor // 父视图透明，避免遮挡 bgView
        addSubview(bgView)
        bgView.addSubview(contentTextField)
        bgView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
        }
        contentTextField.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(5)
            make.trailing.equalToSuperview().offset(-5)
            make.centerY.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //=================================================================
    //                            lazy
    //=================================================================
    // MARK: - lazy
    private lazy var bgView: NSView = {
        let view = NSView(frame: .zero)
        view.wantsLayer = true
        view.layer?.masksToBounds = true
        view.layer?.cornerRadius = 10
        return view
    }()
    private lazy var contentTextField: NSTextField = {
        let label = NSTextField(labelWithString: "网小鱼超大只")
        label.textColor = .mi.hex("#000000", alpha: 0.9)
        label.font = .mi.pingFangSCMedium(size: 13)
        label.isEditable = false
        label.isSelectable = false
        label.alignment = .left
        // 设置截断模式为尾部省略号
        label.cell?.lineBreakMode = .byTruncatingTail
        label.cell?.wraps = false  // 确保不换行
        return label
    }()
}

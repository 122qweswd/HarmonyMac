//
//  TransmitRecordContentCell.swift
//  MutualInfectionMac
//
//  Created by apple on 2026/1/14.
//

import Foundation
import AppKit

//MARK: 右侧的cell
class TransmitRecordContentCell: NSTableCellView {
    
    /// 更多按钮点击回调
    var moreClickHandler: ((MITransferFile, NSButton, NSTableCellView) -> Void)?
    /// 单选按钮点击回调
    var allSelectClickHandler: ((MITransferFile) -> Void)?
    
    /// 是否是编辑
    var isEdit: Bool = false {
        didSet {
            if isEdit {
                moreBtn.isHidden = true
                selectBtn.isHidden = false
                selectBtn.snp.updateConstraints { make in
                    make.width.equalTo(20)
                }
                iconView.snp.updateConstraints { make in
                    make.leading.equalTo(selectBtn.snp.trailing).offset(10)
                }
            } else {
                moreBtn.isHidden = false
                selectBtn.isHidden = true
                selectBtn.snp.updateConstraints { make in
                    make.width.equalTo(0)
                }
                iconView.snp.updateConstraints { make in
                    make.leading.equalTo(selectBtn.snp.trailing).offset(0)
                }
            }
        }
    }
    
    var model: MITransferFile? {
        didSet {
            guard let model = model else { return }
            titleView.stringValue = model.fileName ?? ""
            descriptionView.stringValue = formatFileSize(byteSize: model.fileSize ?? 0)
            setFileIcon(for: model)
            
            titleView.textColor = model.status == .failure ? NSColor(hex: "#A0A2A3") : NSColor.init(hex: "#000000", alpha: 0.9)
            
            if model.isSelect {
                selectBtn.image = NSImage(named: "icon_select")
                selectBtn.state = .on
            } else {
                selectBtn.image = NSImage(named: "check_off")
                selectBtn.state = .off
            }
        }
    }
    
    private func setFileIcon(for fileModel: MITransferFile) {
        if let fileType: MIFileType = fileModel.fileType,
           fileType == .photoAndVideo {
            iconView.image = NSImage(named: "icon_image_mac")
        } else {
            iconView.image = NSImage(named: "icon_document_mac")
            
            var fileExtension = fileModel.fileExtension
            if fileExtension == nil || fileExtension?.count == 0 {
                if let fileUrl = fileModel.fileUrl {
                    fileExtension = (fileUrl as NSString).pathExtension
                }
            }
            if let icon = MIThumbImageSaver.shared.getFileIcon(fileExtension: fileExtension ?? "") {
                iconView.image = icon
            }
        }
        
        checkShowThumbnailImage(fileModel.thumbnailImageData)
    }
    
    /// 判断是否展示缩略图
    private func checkShowThumbnailImage(_ thumbnailImageData: Data?) {
        thumbnailImageView.isHidden = true
        thumbnailImageView.image = nil
        guard let imageData = thumbnailImageData else {
            return
        }
        
        guard let image = NSImage(data: imageData) else {
            return
        }
        
        thumbnailImageView.isHidden = false
        thumbnailImageView.image = image
    }
    
    lazy var bgView: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 8
        view.layer?.masksToBounds = true
        return view
    }()
    
    lazy var iconView: NSImageView = {
        let imageView = NSImageView()
        imageView.wantsLayer = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.needsDisplay = false
        imageView.contentTintColor = NSColor.gray
        imageView.image = NSImage(named: "icon_document_mac")
        imageView.layer?.cornerRadius = 4
        imageView.layer?.masksToBounds = true
        //        if #available(macOS 11.0, *) {
        //            imageView.image = createColoredSystemImage(symbolName: "folder", color: .gray, size: NSSize(width: 30, height: 24))
        //        } else {
        //            // Fallback on earlier versions
        //        }
        return imageView
    }()
    
    lazy var thumbnailImageView: ScaleAspectFillImageView = {
        let imageView = ScaleAspectFillImageView()
        imageView.wantsLayer = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.needsDisplay = false
        imageView.layer?.cornerRadius = 4
        imageView.layer?.masksToBounds = true
        return imageView
    }()
    
    lazy var titleView: NSTextField = {
        let textField = NSTextField(labelWithString: "")
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = .mi.pingFangSCMedium(size: 12)
        textField.textColor = NSColor.init(hex: "#000000", alpha: 0.9)
        textField.lineBreakMode = .byTruncatingMiddle
        return textField
    }()
    
    lazy var descriptionView: NSTextField = {
        let textField = NSTextField(labelWithString: "")
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = .mi.pingFangSCRegular(size: 11)
        textField.textColor = NSColor.init(hex: "#000000", alpha: 0.6)
        textField.alignment = .right
        return textField
    }()
    
    lazy var moreBtn: NSButton = {
        let btn = NSButton(title: "更多", target: self, action: #selector(moreBtnTouch))
        btn.wantsLayer = true
        btn.isBordered = false
        btn.image = NSImage(named: "icon_more_only_point")
        btn.imageScaling = .scaleProportionallyUpOrDown
        btn.alphaValue = 0.6
        //        if #available(macOS 11.0, *) {
        //            btn.image = createColoredSystemImage(symbolName: "ellipsis", color: .gray, size: NSSize(width: 15, height: 8))
        //        } else {
        //            // Fallback on earlier versions
        //        }
        //        btn.imageScaling = .scaleNone
        return btn
    }()
    
    lazy var selectBtn: NSButton = {
        let btn = NSButton(title: "多选", target: self, action: #selector(selectBtnTouch))
        btn.wantsLayer = true
        btn.isBordered = false
        btn.setButtonType(.onOff)
        btn.image = NSImage(named: "check_off")
        btn.imageScaling = .scaleProportionallyUpOrDown
        btn.isHidden = true
        return btn
    }()
    
    @available(macOS 11.0, *)
    private func createColoredSystemImage(symbolName: String, color: NSColor, size: NSSize = NSSize(width: 16, height: 16)) -> NSImage? {
        guard var systemImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
            return nil
        }
        
        // 使用 NSImageSymbolConfiguration 设置颜色
        if #available(macOS 12.0, *) {
            let configuration = NSImage.SymbolConfiguration(paletteColors: [color])
            if let configuredImage = systemImage.withSymbolConfiguration(configuration) {
                systemImage = configuredImage
            }
            
            // 调整大小
            systemImage.size = size
            systemImage.isTemplate = false
        }
        return systemImage
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupUI() {
        addSubview(bgView)
        
        bgView.addSubview(iconView)
        iconView.addSubview(thumbnailImageView)
        bgView.addSubview(titleView)
        bgView.addSubview(descriptionView)
        bgView.addSubview(moreBtn)
        bgView.addSubview(selectBtn)
        
        bgView.snp.makeConstraints { make in
            make.edges.equalTo(0)
        }
        
        selectBtn.snp.makeConstraints { make in
            make.leading.equalTo(8)
            make.centerY.equalToSuperview()
            make.height.equalTo(20)
            make.width.equalTo(0)
        }
        
        iconView.snp.makeConstraints { make in
            make.leading.equalTo(selectBtn.snp.trailing).offset(0)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(28)
        }
        
        thumbnailImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        moreBtn.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.equalTo(40)
            make.height.equalTo(30)
        }
        
        descriptionView.snp.makeConstraints { make in
            make.trailing.equalTo(moreBtn.snp.leading).offset(-24)
            make.centerY.equalTo(0)
            make.height.equalTo(20)
            make.width.equalTo(80)
        }
        
        titleView.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(8)
            make.centerY.equalTo(0)
            make.height.equalTo(20)
            make.trailing.equalTo(descriptionView.snp.leading).offset(-12)
        }
    }
    
    @objc func moreBtnTouch() {
        
        print("点击详情列表cell的更多")
        if let model = model {
            moreClickHandler?(model, moreBtn, self)
        }
        
        
    }
    
    
    @objc func selectBtnTouch() {
        
        if let model = model {
            if selectBtn.state == .on {
                selectBtn.image = NSImage(named: "icon_select")
                model.isSelect = true
            } else {
                selectBtn.image = NSImage(named: "check_off")
                model.isSelect = false
            }
            allSelectClickHandler?(model)
        }
        
    }
    
    
}

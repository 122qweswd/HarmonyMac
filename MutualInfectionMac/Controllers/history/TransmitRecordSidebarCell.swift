//
//  TransmitRecordSidebarCell.swift
//  MutualInfectionMac
//
//  Created by apple on 2026/1/14.
//

import Foundation
import AppKit

//MARK: 左侧的cell
class TransmitRecordSidebarCell: NSTableCellView {
    
    /// 更多按钮点击回调
    var moreClickHandler: ((MITransferRecord, NSButton) -> Void)?
    /// 单选按钮点击回调
    var selectClickHandler: ((MITransferRecord) -> Void)?
    /// 排序类型
    var sortType: MACHeaderSortState = .sortList
    /// 是否是搜索
    var searchShow: Bool = false
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
    
    var model: MITransferRecord? {
        didSet {
            guard let model = model else { return }
            if sortType == .typeList {
                iconView.image = NSImage(named: "icon_folder")
                moreBtn.isHidden = false
                
            } else {
                iconView.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader( model.hwId ?? "", true,deviceTye: model.deviceType ?? 1)
                moreBtn.isHidden = true
            }
            if sortType == .sortList {
                titleView.stringValue = (model.transferType == .receive ? LocalizedStrings.receivedFrom : "") + (model.deviceName ?? "")
            } else if sortType == .typeList {
                titleView.stringValue = (model.foldName ?? "") + (model.transferTimeStr  ?? "")
            }
            if searchShow {
                titleView.stringValue = (model.foldName ?? "") + (model.transferTimeStr  ?? "")
            }
            
            var transferTimeStr = ""
            var dateFormat = ""
            if let transferTime = model.transferTime {
                if checkDateIsThisYear(transferTime) {
                    dateFormat = "MM-dd HH:mm"
                } else {
                    dateFormat = "yyyy-MM-dd HH:mm"
                }
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = dateFormat
                transferTimeStr = dateFormatter.string(from: transferTime)
            }
            descriptionView.stringValue = transferTimeStr + " \(formatFileSize(byteSize: model.totalSize))"
            
            progressLabel.stringValue = "\(LocalizedStrings.importing) \(model.progress)%"
            
            if ReimportAlbum.shared.isReimport[model.id ?? 0] == nil,
               SaveFileHandler.shared.isSaveFileing ?? false,
               SaveFileHandler.shared.curRecordId != nil,
               SaveFileHandler.shared.curRecordId == model.id {
                progressLabel.isHidden = model.progress == 100
            } else {
                progressLabel.isHidden = !(ReimportAlbum.shared.isReimport[model.id ?? 0] ?? false) || model.progress == 100

            }
            
            if model.progress == 100 {
                let failList = model.sendContent.filter { $0.status == .failure }
                if failList.count == 0 {
                    /// 没有失败
                    reimportBtn.isHidden = true
                    reimportLab.isHidden = true
                }
                else if failList.count == model.sendContent.count {
                    /// 全部失败
                    reimportLab.isHidden = false
                    reimportBtn.isHidden = false
                    /// 全部失败
                    reimportLab.stringValue = LocalizedStrings.importFailed
                    
                }else {
                    /// 部分失败
                    reimportLab.isHidden = false
                    reimportBtn.isHidden = false
                    reimportLab.stringValue = LocalizedStrings.partialImportFailed
                }
            }else{
                if progressLabel.isHidden, !(ReimportAlbum.shared.isReimport[model.id ?? 0] ?? false) {
                    reimportBtn.isHidden = false
                    reimportLab.isHidden = false
                    reimportLab.stringValue = LocalizedStrings.partialImportFailed
                }else{
                    reimportBtn.isHidden = true
                    reimportLab.isHidden = true
                }
            }
            
            if model.isSelect {
                selectBtn.image = NSImage(named: "icon_select")
                selectBtn.state = .on
            } else {
                selectBtn.image = NSImage(named: "check_off")
                selectBtn.state = .off
            }
        }
    }
    
    lazy var iconView: NSImageView = {
        // 创建图标
        let imageView = NSImageView()
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 16
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        return imageView
    }()
    
    lazy var titleView: NSTextField = {
        let textField = NSTextField(labelWithString: "")
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = .mi.pingFangSCMedium(size: 13)
        textField.textColor = NSColor.init(hex: "#000000", alpha: 0.9)
        textField.lineBreakMode = .byTruncatingMiddle
        //        textField.wantsLayer = true
        //        textField.layer?.backgroundColor = NSColor.red.cgColor
        return textField
    }()
    
    lazy var descriptionView: NSTextField = {
        let textField = NSTextField(labelWithString: "")
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = .mi.pingFangSCRegular(size: 11)
        textField.textColor = NSColor.init(hex: "#000000", alpha: 0.6)
        return textField
    }()
    
    lazy var moreBtn: NSButton = {
        let btn = NSButton(title: "更多", target: self, action: #selector(moreBtnTouch))
        btn.wantsLayer = true
        btn.isBordered = false
        if #available(macOS 11.0, *) {
            btn.image = createColoredSystemImage(symbolName: "ellipsis", color: .gray, size: NSSize(width: 15, height: 8))
        } else {
            // Fallback on earlier versions
        }
        btn.imageScaling = .scaleNone
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
    
    lazy var reimportBtn:NSButton = {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.mi.hex("#FFFFFF", alpha:1)]
        let btn = NSButton(title: LocalizedStrings.retry, target: self, action: #selector(reimportBtnTouch))
        btn.wantsLayer = true
        btn.attributedTitle = NSAttributedString(string: LocalizedStrings.retry.localized, attributes: attributes)
        btn.layer?.backgroundColor = NSColor.mi.hex("#0a59f7", alpha:1).cgColor
        
        btn.layer?.cornerRadius = 14
        btn.isBordered = false
        btn.isHidden = false
        return btn
    }()
    
    lazy var reimportLab: NSTextField = {
        let textField = NSTextField(labelWithString: LocalizedStrings.importFailed)
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = .systemFont(ofSize: 12)
        textField.textColor = NSColor.init(hex: "#E84026", alpha: 1)
        textField.lineBreakMode = .byTruncatingMiddle
        return textField
    }()
    
    /// 进度View
    lazy var progressLabel: NSTextField = {
        let textField = NSTextField(labelWithString: LocalizedStrings.importing)
        textField.textColor = NSColor.init(hex: "#0191ff", alpha: 1)
        textField.font = .systemFont(ofSize: 12)
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    
    private lazy var lineView: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(hex: "#EBEDEF").cgColor
        view.isHidden = true
        return view
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
        
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupUI() {
        
        addSubview(iconView)
        addSubview(titleView)
        addSubview(descriptionView)
        addSubview(moreBtn)
        addSubview(selectBtn)
        addSubview(reimportBtn)
        addSubview(reimportLab)
        addSubview(lineView)
        addSubview(progressLabel)
        
        selectBtn.snp.makeConstraints { make in
            make.leading.equalTo(8)
            make.centerY.equalToSuperview()
            make.height.equalTo(20)
            make.width.equalTo(0)
        }
        
        iconView.snp.makeConstraints { make in
            make.leading.equalTo(selectBtn.snp.trailing).offset(0)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
        }
        
        titleView.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(8)
            make.top.equalTo(iconView.snp.top).offset(-1)
            make.height.equalTo(20)
            make.trailing.equalTo(-4)
        }
        
        descriptionView.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(8)
            make.bottom.equalTo(iconView.snp.bottom)
            make.height.equalTo(15)
        }
        
        moreBtn.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.equalTo(40)
            make.height.equalTo(30)
        }
        
        lineView.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.leading)
            make.bottom.equalToSuperview()
            make.trailing.equalToSuperview()
            make.height.equalTo(1)
        }
        
        reimportBtn.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview()
            make.size.equalTo(CGSize(width: 52, height: 28))
        }
        reimportLab.snp.makeConstraints { make in
            make.centerY.equalTo(descriptionView)
            make.leading.equalTo(descriptionView.snp.trailing)
            make.trailing.equalTo(reimportBtn.snp.leading)
        }
        progressLabel.snp.makeConstraints { make in
            make.centerY.equalTo(descriptionView)
            make.leading.equalTo(descriptionView.snp.trailing)
        }
        
        
    }
    
    @objc func moreBtnTouch() {
        
        print("点击列表cell的更多")
        if let model = model {
            moreClickHandler?(model, moreBtn)
        }
        
        
    }
    
    
    
    @objc func selectBtnTouch() {
        
        if selectBtn.state == .on {
            selectBtn.image = NSImage(named: "icon_select")
            if let model = model {
                model.isSelect = true
                for item in model.sendContent {
                    item.isSelect = true
                }
                selectClickHandler?(model)
            }
            
        } else {
            selectBtn.image = NSImage(named: "check_off")
            if let model = model {
                model.isSelect = false
                for item in model.sendContent {
                    item.isSelect = false
                }
                selectClickHandler?(model)
            }
        }
        //        if let model = model {
        //            selectClickHandler?(model)
        //        }
        
        
    }
    
    /// 重试 重新导入
    @objc func reimportBtnTouch() {
        /// 查询文件为失败的数据
        //        if let failList = model?.sendContent.filter({ $0.status == .failure }) {
        //            SaveFileHandler.shared.reImportImage(files: failList, id: model?.id ?? 0)
        //        }
        
        if ReimportAlbum.shared.checkHasNoImporting() {
            if let files = model?.sendContent.filter({ $0.status == .inProgress }) {
                Task.detached {
                    await ReimportAlbum.shared.reImportImage(files, id: self.model?.id ?? 0)
                }
            }
        } else {
            if let failList = model?.sendContent.filter({ $0.status == .failure }) {
                SaveFileHandler.shared.reImportImage(files: failList, id: model?.id ?? 0)
            }
        }
        
    }
    
    
    /// 返回设备传输的类型文件数量
    func fileTypeDescription(_ sendContent: [MITransferFile]) -> String {
        var unknownNumber: Int = 0
        var photoNumber: Int = 0
        var fileNumber: Int = 0
        var contactsNumber: Int = 0
        var locationNumber: Int = 0
        for content in sendContent {
            if let fileType = content.fileType {
                switch fileType {
                case .photoAndVideo: photoNumber+=1
                case .file: fileNumber+=1
                case .contacts: contactsNumber+=1
                case .location: locationNumber+=1
                }
            } else {
                unknownNumber+=1
            }
            
        }
        var descriptionStr = ""
        if unknownNumber != 0 {
            descriptionStr = "\(unknownNumber)个未知"
        }
        if photoNumber != 0 {
            descriptionStr = descriptionStr.isEmpty ? "\(photoNumber)张图片" : "\(descriptionStr)，\(photoNumber)张图片"
        }
        if fileNumber != 0 {
            descriptionStr = descriptionStr.isEmpty ? "\(fileNumber)个文件" : "\(descriptionStr)，\(fileNumber)个文件"
        }
        if contactsNumber != 0 {
            descriptionStr = descriptionStr.isEmpty ? "\(contactsNumber)条通讯录" : "\(descriptionStr)，\(contactsNumber)条通讯录"
        }
        if locationNumber != 0 {
            descriptionStr = descriptionStr.isEmpty ? "\(locationNumber)条位置" : "\(descriptionStr)，\(locationNumber)条位置"
        }
        return descriptionStr
    }
    
    /// 判断日期是否是今年的
    func checkDateIsThisYear(_ checkDate: Date?) -> Bool {
        guard let checkDate = checkDate else {
            return false
        }
        
        let calendar = Calendar.current
        let yearOfGivenDate = calendar.component(.year, from: checkDate)
        let currentYear = calendar.component(.year, from: Date())
        return yearOfGivenDate == currentYear
    }
}

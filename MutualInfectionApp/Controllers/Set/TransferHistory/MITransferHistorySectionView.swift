//
//  MITransferHistorySectionHeaderView.swift
//  MutualInfectionApp
//
//  Created by Niko on 2025/9/11.
//

import UIKit
import SnapKit

class MITransferHistorySectionHeaderView: UITableViewHeaderFooterView {
    
    var sectionView: MITransferHistorySectionView = MITransferHistorySectionView()
        
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupUI() {
        contentView.addSubview(sectionView)
        sectionView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }
    
}

class MITransferHistorySectionCellView: UITableViewCell {
    
    var sectionView: MITransferHistorySectionView = MITransferHistorySectionView(offset: 10)
        
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupUI() {
        contentView.addSubview(sectionView)
        sectionView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }
    
}

/// 互传记录每条内容View
class MITransferHistorySectionView: UIView {
    var transferRecord : MITransferRecord? {
        didSet {
            guard let transferRecord = transferRecord else { return }
            
            // TODO: 头像
            avatarImageView.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader( transferRecord.hwId ?? "", true,deviceTye: transferRecord.deviceType ?? 0)
            userNameLabel.text = (transferRecord.transferType == .receive ? LocalizedStrings.receivedFrom : "") + (transferRecord.deviceName ?? "")
            desLabel.text = (transferRecord.transferTimeStr ?? "") + " " + formatFileSize(byteSize: transferRecord.totalSize)
            selectButton.isSelected = transferRecord.isSelect
            
            progressLabel.text = "\(LocalizedStrings.importing) \(transferRecord.progress)%"
            progressLabel.isHidden = transferRecord.progress == 100
            
            var stackViewWidth = UIDevice.isPad ? 340 - 62 - 132 : ksUIScreenW - 62 - 132
            
            if transferRecord.progress == 100 {
                let failList = transferRecord.sendContent.filter { $0.status == .failure }
                
                if failList.count == 0 {
                    /// 没有失败
                    statusLabel.isHidden = true
                    retryButton.isHidden = true
                    
                    if UIDevice.isPad {
                        stackViewWidth = 340 - 32
                    }
                    
                } else if failList.count == transferRecord.sendContent.count {
                    /// 全部失败
                    statusLabel.isHidden = false
                    retryButton.isHidden = false
                    /// 全部失败
                    statusLabel.text = LocalizedStrings.importFailed
                    
                } else {
                    /// 部分失败
                    statusLabel.isHidden = false
                    retryButton.isHidden = false
                    /// 部分失败
                    statusLabel.text = LocalizedStrings.partialImportFailed
                }
            } else {
                statusLabel.isHidden = true
                retryButton.isHidden = true

            }
            
            stackView.snp.updateConstraints {
                $0.width.equalTo(stackViewWidth)
            }
        }
    }
    
    var offset: CGFloat = 0
    
    /// 编辑状态
    var isEdit: Bool = false {
        didSet {
            selectButton.isHidden = !isEdit
            editButton.isHidden = !isEdit
        }
    }
    
    /// 选中按钮点击
    var selectActionCallBack: ClickBlockVoid?
    
    /// 设置cell选中状态 iPad
    var isSelectCell: Bool = false {
        didSet {
            configCellSelect(isSelect: isSelectCell)
        }
    }
    
    // MARK: - UI Elements
    
    lazy var horizontalStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [selectButton, avatarImageView, stackView])
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    lazy var selectButton: NotHighlightButton = {
        let button = NotHighlightButton()
        button.isUserInteractionEnabled = false
        button.setImage(UIImage.checkOff, for: .normal)
        button.setImage(UIImage.select, for: .selected)
        return button
    }()
    
    /// 编辑状态下的选中按钮
    lazy var editButton: UIButton = {
        let button = NotHighlightButton()
        button.isHidden = true
        button.addClickClosure { [weak self] sender in
            guard let self = self else { return }
            selectActionCallBack?()
        }
        
        return button
    }()
    
    /// 用户头像
    private lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = UIColor.systemGray5
        imageView.layer.cornerRadius = 19
        imageView.layer.masksToBounds = true
        return imageView
    }()
    
    private lazy var stackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [userNameLabel, desLabel])
        stackView.axis = .vertical
        stackView.spacing = 2
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    /// 用户名称标签
    private lazy var userNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textColor = "#000000".color.withAlpha(0.9)
        label.text = "设备名称"
        return label
    }()
    
    /// 时间和文件总大小
    private lazy var desLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = "#000000".color.withAlpha(0.38)
        label.text = "2025-09-11 16:58:11 123KB"
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    
    var actionCallBack: ClickBlockVoid?
    
    /// 箭头
    lazy var arrowButton: NotHighlightButton = {
        let button = NotHighlightButton(type: .custom)
        
        let upImage = UIImage(systemName: "chevron.up")?.withTintColor("#000000".color.withAlpha(0.2), renderingMode: .alwaysOriginal)
        let downImage = UIImage(systemName: "chevron.down")?.withTintColor("#000000".color.withAlpha(0.2), renderingMode: .alwaysOriginal)
        
        button.setImage(downImage, for: .normal)
        button.setImage(upImage, for: .selected)
        button.contentHorizontalAlignment = .right
        
        button.addClickClosure { [weak self] sender in
            self?.actionCallBack?()
        }
        
        return button
    }()
    
    /// 分割线
    private lazy var separatorLine: UIView = {
        let view = UIView()
        view.backgroundColor = "#000000".color.withAlpha(0.08)
        return view
    }()
    
    /// 进度View
    lazy var progressLabel: UILabel = {
        let progressLabel = UILabel()
        progressLabel.text = LocalizedStrings.importing
        progressLabel.textColor = "#0191ff".color
        progressLabel.font = .systemFont(ofSize: 12)
        return progressLabel
    }()
    
    /// 导入失败/部分导入失败
    lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.textColor = .red
        label.font = .systemFont(ofSize: 12)
        label.backgroundColor = .white
        return label
    }()
    
    /// 重试按钮
    lazy var retryButton: NotHighlightButton = {
        let button = NotHighlightButton(type: .custom)
        button.titleLabel?.font = .systemFont(ofSize: 12)
        button.backgroundColor = "#0191FF".color
        button.setTitle(LocalizedStrings.retry, for: .normal)
        button.layer.cornerRadius = 10
        
        button.addClickClosure { [weak self] sender in
            guard let self = self else { return }
            
            if let failList = transferRecord?.sendContent.filter({ $0.status == .failure }) {
                SaveFileHandler.shared.reImportImage(files: failList)
            }
        }
        
        return button
    }()
    
    func configCellSelect(isSelect: Bool) {
        let color = isSelect ? "#D8D8DC".color : "#FFFFFF".color
        backgroundColor = color
        statusLabel.backgroundColor = color
    }
    
    init(offset: CGFloat = 38) {
        super.init(frame: .zero)
        self.offset = offset
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        backgroundColor = .white
        
        addSubview(horizontalStackView)
        addSubview(editButton)
        addSubview(progressLabel)
        addSubview(arrowButton)
        addSubview(separatorLine)
        addSubview(statusLabel)
        addSubview(retryButton)
        
        horizontalStackView.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(16)
            $0.centerY.equalToSuperview()
        }
        
        editButton.snp.makeConstraints {
            $0.top.leading.bottom.equalToSuperview()
            if UIDevice.isPhone {
                $0.width.equalTo(ksUIScreenW - 100)
            } else {
                $0.width.equalTo(44)
            }
        }
        
        arrowButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-16)
            $0.centerY.equalToSuperview()
            $0.size.equalTo(CGSize(width: 44, height: 44))
        }
        
        statusLabel.snp.makeConstraints {
            $0.trailing.equalTo(retryButton.snp.leading).offset(-5)
            $0.height.equalToSuperview().offset(-2)
            $0.centerY.equalToSuperview()
        }
        
        retryButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-offset)
            $0.centerY.equalToSuperview()
            $0.size.equalTo(CGSize(width: 40, height: 20))
        }
        
        progressLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-offset)
            $0.centerY.equalToSuperview()
        }
        
        avatarImageView.snp.makeConstraints { make in
            make.width.height.equalTo(38)
        }
        
        userNameLabel.snp.makeConstraints {
            $0.height.equalTo(20)
        }
        desLabel.snp.makeConstraints {
            $0.height.equalTo(14)
        }
        
        stackView.snp.makeConstraints {
            $0.leading.equalTo(avatarImageView.snp.trailing).offset(8)
            if UIDevice.isPhone {
                $0.width.equalTo(ksUIScreenW - 62 - 132)
            } else {
                $0.width.equalTo(340 - 62 - 132)
            }
        }
        
        separatorLine.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(16).priority(.high)
            $0.trailing.equalToSuperview().offset(-16)
            $0.bottom.equalToSuperview()
            $0.height.equalTo(1)
        }
    }
}

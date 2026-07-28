//
//  MITransferHistoryTableViewCell.swift
//  MutualInfectionApp
//
//  Created by Niko on 2025/9/11.
//

import UIKit
import SnapKit

class MITransferHistoryTableViewCell: UITableViewCell {
    
    var model: (MITransferRecord?, MITransferFile?) {
        didSet {
            let (sectionRecord, file) = model
            if let sectionRecord = sectionRecord {
                fileNameLabel.text = sectionRecord.foldName
                fileSizeLabel.text = formatFileSize(byteSize: sectionRecord.totalSize)
                selectButton.isSelected = sectionRecord.isSelect
                fileIconImageView.image = UIImage.iconFolder
                
                disableView(isDisable: false)
            }
            
            if let file = file {
                fileNameLabel.text = file.fileName
                fileSizeLabel.text = formatFileSize(byteSize: file.fileSize ?? 0)
                selectButton.isSelected = file.isSelect
                setFileIcon(for: file.fileType ?? .file)
                
                disableView(isDisable: file.isDisable)
            }
        }
    }
    
    /// 设置cell选中状态 iPad
    var isSelectCell: Bool = false {
        didSet {
            configCellSelect(isSelect: isSelectCell)
        }
    }
    
    var menuType: ConfigSortState! {
        didSet {
            horizontalStackView.snp.updateConstraints {
                $0.leading.equalToSuperview().offset(menuType.isSortByTime ? 60 : 16) 
            }
        }
    }
    
    /// 是否最后一行
    var isLastCell: Bool = false {
        didSet {
            separatorLine.snp.updateConstraints {
                $0.leading.equalToSuperview().offset(isLastCell ? 16 : 60)
            }
        }
    }
    
    // MARK: - UI Elements
    /// 编辑状态
    var isEdit: Bool = false {
        didSet {
            selectButton.isHidden = !isEdit
            editButton.isHidden = !isEdit
            
            moreButton.isHidden = isEdit
        }
    }
    
    /// 选中按钮点击
    var selectActionCallBack: ClickBlockVoid?
    
    /// 更多按钮点击
    var moreActionCallBack: UIButtonClickClosure?
    
    lazy var horizontalStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [selectButton, fileIconImageView])
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.distribution = .fill
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
    
    /// 文件图标
    private lazy var fileIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage.iconDocument
        return imageView
    }()
    
    
    lazy var stackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [fileNameLabel, fileSizeLabel])
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.isUserInteractionEnabled = false
        return stackView
    }()
    
    /// 文件名称标签
    private lazy var fileNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = "#000000".color.withAlpha(0.9)
        label.numberOfLines = 2
        label.text = "文件名称"
        return label
    }()
    
    /// 文件大小标签
    private lazy var fileSizeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.text = "123KB"
        label.textColor = "#000000".color.withAlpha(0.38)
        return label
    }()
    
    /// ··· 按钮
    lazy var moreButton: NotHighlightButton = {
        let button = NotHighlightButton(type: .custom)
        let ellipsisImage = UIImage(systemName: "ellipsis")?.withTintColor("#000000".color.withAlpha(0.2), renderingMode: .alwaysOriginal)
        button.setImage(ellipsisImage, for: .normal)
        
        button.addClickClosure { [weak self] sender in
            guard let self = self else { return }
            moreActionCallBack?(sender)
        }
        
        
        return button
    }()
    
    /// 分割线
    private lazy var separatorLine: UIView = {
        let view = UIView()
        view.backgroundColor = "#000000".color.withAlpha(0.08)
        return view
    }()
    
    func configCellSelect(isSelect: Bool) {
        let color = isSelect ? "#D8D8DC".color : "#FFFFFF".color
        contentView.backgroundColor = color
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
        separatorInset = UIEdgeInsets(top: 0, left: 60, bottom: 0, right: 16)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup Methods
    
    private func setupUI() {
        selectionStyle = .none
        
        contentView.backgroundColor = .white
        
        contentView.addSubview(moreButton)
                
        // 添加子视图
        contentView.addSubview(horizontalStackView)
        
        contentView.addSubview(editButton)
        
        contentView.addSubview(stackView)
        
        contentView.addSubview(separatorLine)
        
        
        moreButton.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.size.equalTo(CGSize(width: 44, height: 44))
            $0.trailing.equalToSuperview()
        }
        
        horizontalStackView.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(16)
            $0.top.equalToSuperview().offset(13)
        }
        
        stackView.snp.makeConstraints {
            $0.leading.equalTo(horizontalStackView.snp.trailing).offset(15)
            $0.trailing.lessThanOrEqualTo(-55)
            $0.top.equalToSuperview().offset(10)
            $0.bottom.equalToSuperview().offset(-10)
        }
        
        fileNameLabel.snp.makeConstraints {
            $0.height.greaterThanOrEqualTo(17)
        }
        
        fileSizeLabel.snp.makeConstraints {
            $0.height.equalTo(14)
        }
        
        editButton.snp.makeConstraints {
            $0.top.leading.bottom.equalToSuperview()
            if UIDevice.isPhone {
                $0.width.equalTo(ksUIScreenW - 100)
            } else {
                $0.width.equalTo(44)
            }
        }
        
        separatorLine.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(60)
            $0.trailing.equalToSuperview().offset(-16)
            $0.bottom.equalToSuperview()
            $0.height.equalTo(1)
        }
        
    }
    
    private func setFileIcon(for fileType: MIFileType) {
        var iconImage: UIImage
        switch fileType {
            case .photoAndVideo:
                let photoImage = UIImage(systemName: "photo")?.withTintColor("#9E9E9E".color, renderingMode: .alwaysOriginal) ?? UIImage()
                iconImage = photoImage
            default:
                iconImage = UIImage.iconDocument
        }
        
        fileIconImageView.image = iconImage
    }
    
    /// 显示置灰
    private func disableView(isDisable: Bool) {
        if isDisable {
            // 将文本颜色设置为灰色
            fileNameLabel.textColor = "#000000".color.withAlpha(0.3)
            fileSizeLabel.textColor = "#000000".color.withAlpha(0.2)
            
            // 将图标设置为灰色
            fileIconImageView.alpha = 0.3
        } else {
            // 恢复正常状态的文本颜色
            fileNameLabel.textColor = "#000000".color.withAlpha(0.9)
            fileSizeLabel.textColor = "#000000".color.withAlpha(0.38)
            
            // 恢复图标正常透明度
            fileIconImageView.alpha = 1.0
        }
    }
}

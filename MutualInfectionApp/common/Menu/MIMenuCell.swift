//
//  MIMenuCell.swift
//  MutualInfectionApp
//
//  Created by Niko on 2025/9/15.
//

import Foundation
import UIKit
import SnapKit

class MIMenuCell: UITableViewCell {
    
    
    private let stackView = UIStackView()
    
    /// 标题
    private let titleLabel = UILabel()
    /// 排序
    private let desTextLabel = UILabel()
    
    /// 选中图标
    private let iconImageView = UIImageView()
    /// 分割线
    private let separatorLine = UIView()
    
    
    private var itemConfig: MIMenuItemConfig?
    private var separatorConfig: MIMenuSeparatorConfig?
    

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    

    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        // 选中标记
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.isHidden = true
        contentView.addSubview(iconImageView)
        
        // 堆栈视图
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.alignment = .leading
        stackView.distribution = .fill
        contentView.addSubview(stackView)
        
        // 标题
        titleLabel.font = UIFont.systemFont(ofSize: 17)
        titleLabel.textColor = .black
        stackView.addArrangedSubview(titleLabel)
        
        // 详情文本
        desTextLabel.font = UIFont.systemFont(ofSize: 12)
        desTextLabel.textColor = .black
        stackView.addArrangedSubview(desTextLabel)
        
        // 分割线
        separatorLine.backgroundColor = UIColor.black.withAlphaComponent(0.1)
        contentView.addSubview(separatorLine)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
                
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }
        
        stackView.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(5)
            make.centerY.equalToSuperview()
        }
        
        separatorLine.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview()
            make.height.equalTo(0.5)
        }
    }
    
    // MARK: - Configuration
    func configure(with item: MIMenuItemConfig, separatorConfig: MIMenuSeparatorConfig, isLastItem: Bool) {
        self.itemConfig = item
        self.separatorConfig = separatorConfig
         
        // 设置选中状态
        updateSelectionState(isSelected: item.isSelectedRow)
        
        // 设置分割线
        let shouldShowSeparator = item.showSeparator && (!isLastItem || separatorConfig.showLastSeparator)
        separatorLine.isHidden = !shouldShowSeparator
        
        if shouldShowSeparator {
            separatorLine.backgroundColor = separatorConfig.color
            separatorLine.snp.updateConstraints { make in
                make.leading.equalToSuperview().offset(separatorConfig.horizontalInset)
                make.trailing.equalToSuperview().offset(-separatorConfig.horizontalInset)
                make.height.equalTo(separatorConfig.height)
            }
        }
    }
    
    private func updateSelectionState(isSelected: Bool) {
        guard let item = itemConfig else { return }
        
        iconImageView.isHidden = !isSelected
        
        titleLabel.text = item.title
        
        if !isSelected {
            iconImageView.image = item.icon
            iconImageView.isHidden = item.icon == nil 
            
            titleLabel.textColor = item.titleColor
            titleLabel.font = item.font
            
            if let desText = item.desText {
                desTextLabel.text = desText
                desTextLabel.isHidden = false
            } else {
                desTextLabel.isHidden = true
            }
            
            desTextLabel.font = item.desFont
            desTextLabel.textColor = item.desTitleColor
            
            backgroundColor = item.backgroundColor
            
        } else {
            
            iconImageView.image = item.selectIcon
            iconImageView.isHidden = item.selectIcon == nil
            
            titleLabel.textColor = item.selectedTitleColor ?? item.titleColor
            titleLabel.font = item.selectedFont ?? item.font
            
            if let desText = item.desText {
                desTextLabel.text = desText
                desTextLabel.isHidden = false
            } else {
                desTextLabel.isHidden = true
            }
            
            desTextLabel.font = item.desSelectedFont ?? item.desFont
            desTextLabel.textColor = item.desSelectedTitleColor ?? item.desTitleColor
            
            backgroundColor = item.selectedBackgroundColor ?? item.backgroundColor
        }
    }
}

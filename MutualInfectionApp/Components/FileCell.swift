//
//  FileCell.swift
//  nshareIos
//
//  Created by ww on 2025/8/29.
//

import UIKit

// MARK: - FileCell
class FileCell: UICollectionViewCell {
    private let iconImageView = UIImageView()
    private let nameLabel = UILabel()
    private let sizeLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = UIColor.systemGray6
        layer.cornerRadius = 8
        
        // 文件图标
        iconImageView.image = UIImage(systemName: "doc")
        iconImageView.tintColor = UIColor.systemBlue
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconImageView)
        
        // 文件名
        nameLabel.font = UIFont.systemFont(ofSize: 12)
        nameLabel.textAlignment = .center
        nameLabel.textColor = UIColor.black
        nameLabel.numberOfLines = 2
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)
        
        // 文件大小
        sizeLabel.font = UIFont.systemFont(ofSize: 10)
        sizeLabel.textAlignment = .center
        sizeLabel.textColor = UIColor.systemGray
        sizeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(sizeLabel)
        
        NSLayoutConstraint.activate([
            iconImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            iconImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            nameLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 4),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            
            sizeLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            sizeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            sizeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            sizeLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4)
        ])
    }
    
    func configure(with file: SelectedFile) {
        nameLabel.text = file.name
        sizeLabel.text = file.size
    }
}

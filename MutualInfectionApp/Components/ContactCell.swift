//
//  ContactCell.swift
//  nshareIos
//
//  Created by ww on 2025/8/29.
//

import UIKit

// MARK: - ContactCell
class ContactCell: UITableViewCell {
    private let nameLabel = UILabel()
    private let phoneLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = UIColor.systemGray6
        layer.cornerRadius = 8
        selectionStyle = .none
        
        // 姓名标签
        nameLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        nameLabel.textColor = UIColor.black
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)
        
        // 电话标签
        phoneLabel.font = UIFont.systemFont(ofSize: 14)
        phoneLabel.textColor = UIColor.systemGray
        phoneLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(phoneLabel)
        
        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            phoneLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            phoneLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            phoneLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            phoneLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(with contact: SelectedContact) {
        nameLabel.text = contact.name
        phoneLabel.text = contact.phone
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.text = nil
        phoneLabel.text = nil
    }
}

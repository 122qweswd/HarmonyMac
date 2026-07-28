//
//  ContactSelectionView.swift
//  nshareIos
//
//  Created by ww on 2025/8/29.
//

import UIKit

// MARK: - ContactSelectionView
class ContactSelectionView: UIView {
    
    // MARK: - UI Elements
    private let containerView = UIView()
    private let contactIconImageView = UIImageView()
    private let selectedContactsLabel = UILabel()
    private let contactCountLabel = UILabel()
    private let noContactsLabel = UILabel()
    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.rowHeight = 60
        tableView.register(ContactCell.self, forCellReuseIdentifier: "ContactCell")
        return tableView
    }()
    
    // MARK: - Properties
    weak var delegate: UITableViewDelegate?
    weak var dataSource: UITableViewDataSource?
    
    // 公共访问属性
    var contactTableView: UITableView {
        return tableView
    }
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // 设置容器视图
        containerView.backgroundColor = UIColor.systemGray6
        containerView.layer.cornerRadius = 12
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)
        
        // 联系人图标
        contactIconImageView.image = UIImage(systemName: "person.crop.circle")
        contactIconImageView.tintColor = UIColor.systemGreen
        contactIconImageView.contentMode = .scaleAspectFit
        contactIconImageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(contactIconImageView)
        
        // 选择的联系人标签
        selectedContactsLabel.text = "选择的联系人"
        selectedContactsLabel.font = UIFont.systemFont(ofSize: 16)
        selectedContactsLabel.textColor = UIColor.black
        selectedContactsLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(selectedContactsLabel)
        
        // 联系人数量标签
        contactCountLabel.text = "0个联系人"
        contactCountLabel.font = UIFont.systemFont(ofSize: 14)
        contactCountLabel.textColor = UIColor.systemGray
        contactCountLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(contactCountLabel)
        
        // 未选择联系人标签
        noContactsLabel.text = "未选择联系人"
        noContactsLabel.font = UIFont.systemFont(ofSize: 14)
        noContactsLabel.textColor = UIColor.systemGray
        noContactsLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(noContactsLabel)
        
        // 设置联系人表格视图
        tableView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tableView)
    }
    
    // MARK: - Constraints
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // 容器视图约束
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.heightAnchor.constraint(equalToConstant: 100),
            
            // 联系人图标约束
            contactIconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            contactIconImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            contactIconImageView.widthAnchor.constraint(equalToConstant: 24),
            contactIconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            // 选择的联系人标签约束
            selectedContactsLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            selectedContactsLabel.leadingAnchor.constraint(equalTo: contactIconImageView.trailingAnchor, constant: 12),
            selectedContactsLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            // 联系人数量标签约束
            contactCountLabel.topAnchor.constraint(equalTo: selectedContactsLabel.bottomAnchor, constant: 4),
            contactCountLabel.leadingAnchor.constraint(equalTo: selectedContactsLabel.leadingAnchor),
            contactCountLabel.trailingAnchor.constraint(equalTo: selectedContactsLabel.trailingAnchor),
            
            // 未选择联系人标签约束
            noContactsLabel.topAnchor.constraint(equalTo: contactCountLabel.bottomAnchor, constant: 4),
            noContactsLabel.leadingAnchor.constraint(equalTo: selectedContactsLabel.leadingAnchor),
            noContactsLabel.trailingAnchor.constraint(equalTo: selectedContactsLabel.trailingAnchor),
            noContactsLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            
            // 联系人表格视图约束
            tableView.topAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.heightAnchor.constraint(equalToConstant: 180),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    // MARK: - Public Methods
    func setupTableView(delegate: UITableViewDelegate, dataSource: UITableViewDataSource) {
        self.delegate = delegate
        self.dataSource = dataSource
        tableView.delegate = delegate
        tableView.dataSource = dataSource
    }
    
    func updateContactCount(_ count: Int) {
        contactCountLabel.text = "\(count)个联系人"
        noContactsLabel.isHidden = count > 0
        tableView.isHidden = count == 0
    }
    
    func reloadData() {
        tableView.reloadData()
    }
}

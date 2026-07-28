//
//  FileSelectionView.swift
//  nshareIos
//
//  Created by ww on 2025/8/29.
//

import UIKit

// MARK: - FileSelectionView
class FileSelectionView: UIView {
    
    // MARK: - UI Elements
    private let containerView = UIView()
    private let fileIconImageView = UIImageView()
    private let selectedFilesLabel = UILabel()
    private let fileCountLabel = UILabel()
    private let noFilesSelectedLabel = UILabel()
    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.itemSize = CGSize(width: 120, height: 80)
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        return collectionView
    }()
    
    // MARK: - Properties
    weak var delegate: UICollectionViewDelegate?
    weak var dataSource: UICollectionViewDataSource?
    
    // 公共访问属性
    var fileCollectionView: UICollectionView {
        return collectionView
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
        
        // 文件图标
        fileIconImageView.image = UIImage(systemName: "doc.text")
        fileIconImageView.tintColor = UIColor.systemBlue
        fileIconImageView.contentMode = .scaleAspectFit
        fileIconImageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(fileIconImageView)
        
        // 选择的文件标签
        selectedFilesLabel.text = "选择的文件".localized
        selectedFilesLabel.font = UIFont.systemFont(ofSize: 16)
        selectedFilesLabel.textColor = UIColor.black
        selectedFilesLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(selectedFilesLabel)
        
        // 文件数量标签
        fileCountLabel.text = "0个文件".localized
        fileCountLabel.font = UIFont.systemFont(ofSize: 14)
        fileCountLabel.textColor = UIColor.systemGray
        fileCountLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(fileCountLabel)
        
        // 未选择文件标签
        noFilesSelectedLabel.text = "未选择文件".localized
        noFilesSelectedLabel.font = UIFont.systemFont(ofSize: 14)
        noFilesSelectedLabel.textColor = UIColor.systemGray
        noFilesSelectedLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(noFilesSelectedLabel)
        
        // 设置文件集合视图
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.register(FileCell.self, forCellWithReuseIdentifier: "FileCell")
        addSubview(collectionView)
    }
    
    // MARK: - Constraints
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // 容器视图约束
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.heightAnchor.constraint(equalToConstant: 100),
            
            // 文件图标约束
            fileIconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            fileIconImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            fileIconImageView.widthAnchor.constraint(equalToConstant: 24),
            fileIconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            // 选择的文件标签约束
            selectedFilesLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            selectedFilesLabel.leadingAnchor.constraint(equalTo: fileIconImageView.trailingAnchor, constant: 12),
            selectedFilesLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            // 文件数量标签约束
            fileCountLabel.topAnchor.constraint(equalTo: selectedFilesLabel.bottomAnchor, constant: 4),
            fileCountLabel.leadingAnchor.constraint(equalTo: selectedFilesLabel.leadingAnchor),
            fileCountLabel.trailingAnchor.constraint(equalTo: selectedFilesLabel.trailingAnchor),
            
            // 未选择文件标签约束
            noFilesSelectedLabel.topAnchor.constraint(equalTo: fileCountLabel.bottomAnchor, constant: 4),
            noFilesSelectedLabel.leadingAnchor.constraint(equalTo: selectedFilesLabel.leadingAnchor),
            noFilesSelectedLabel.trailingAnchor.constraint(equalTo: selectedFilesLabel.trailingAnchor),
            noFilesSelectedLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            
            // 文件集合视图约束
            collectionView.topAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 12),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: 120),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    // MARK: - Public Methods
    func setupCollectionView(delegate: UICollectionViewDelegate, dataSource: UICollectionViewDataSource) {
        self.delegate = delegate
        self.dataSource = dataSource
        collectionView.delegate = delegate
        collectionView.dataSource = dataSource
    }
    
    func updateFileCount(_ count: Int) {
        fileCountLabel.text = "\(count)个文件"
        noFilesSelectedLabel.isHidden = count > 0
        collectionView.isHidden = count == 0
    }
    
    func reloadData() {
        collectionView.reloadData()
    }
}

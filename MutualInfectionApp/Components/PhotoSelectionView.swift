//
//  PhotoSelectionView.swift
//  nshareIos
//
//  Created by ww on 2025/8/29.
//

import UIKit

// MARK: - PhotoSelectionView
class PhotoSelectionView: UIView {
    
    // MARK: - UI Elements
    private let containerView = UIView()
    private let photoIconImageView = UIImageView()
    private let selectedPhotosLabel = UILabel()
    private let photoCountLabel = UILabel()
    private let noPhotosSelectedLabel = UILabel()
    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.itemSize = CGSize(width: 80, height: 80)
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        return collectionView
    }()
    
    // MARK: - Properties
    weak var delegate: UICollectionViewDelegate?
    weak var dataSource: UICollectionViewDataSource?
    
    // 公共访问属性
    var photoCollectionView: UICollectionView {
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
        
        // 照片图标
        photoIconImageView.image = UIImage(systemName: "photo.on.rectangle")
        photoIconImageView.tintColor = UIColor.systemGreen
        photoIconImageView.contentMode = .scaleAspectFit
        photoIconImageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(photoIconImageView)
        
        // 选择的照片标签
        selectedPhotosLabel.text = "选择的照片"
        selectedPhotosLabel.font = SFCompact(weight: .regular,size: 16)
        selectedPhotosLabel.textColor = UIColor.black
        selectedPhotosLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(selectedPhotosLabel)
        
        // 照片数量标签
        photoCountLabel.text = "0张照片"
        photoCountLabel.font = SFCompact(weight: .regular,size: 14)
        photoCountLabel.textColor = UIColor.systemGray
        photoCountLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(photoCountLabel)
        
        // 未选择照片标签
        noPhotosSelectedLabel.text = "未选择照片"
        noPhotosSelectedLabel.font = SFCompact(weight: .regular,size: 14)
        noPhotosSelectedLabel.textColor = UIColor.systemGray
        noPhotosSelectedLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(noPhotosSelectedLabel)
        
        // 设置照片集合视图
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: "PhotoCell")
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
            
            // 照片图标约束
            photoIconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            photoIconImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            photoIconImageView.widthAnchor.constraint(equalToConstant: 24),
            photoIconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            // 选择的照片标签约束
            selectedPhotosLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            selectedPhotosLabel.leadingAnchor.constraint(equalTo: photoIconImageView.trailingAnchor, constant: 12),
            selectedPhotosLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            // 照片数量标签约束
            photoCountLabel.topAnchor.constraint(equalTo: selectedPhotosLabel.bottomAnchor, constant: 4),
            photoCountLabel.leadingAnchor.constraint(equalTo: selectedPhotosLabel.leadingAnchor),
            photoCountLabel.trailingAnchor.constraint(equalTo: selectedPhotosLabel.trailingAnchor),
            
            // 未选择照片标签约束
            noPhotosSelectedLabel.topAnchor.constraint(equalTo: photoCountLabel.bottomAnchor, constant: 4),
            noPhotosSelectedLabel.leadingAnchor.constraint(equalTo: selectedPhotosLabel.leadingAnchor),
            noPhotosSelectedLabel.trailingAnchor.constraint(equalTo: selectedPhotosLabel.trailingAnchor),
            noPhotosSelectedLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            
            // 照片集合视图约束
            collectionView.topAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 12),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: 80),
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
    
    func updatePhotoCount(_ count: Int) {
        photoCountLabel.text = "\(count)张照片"
        noPhotosSelectedLabel.isHidden = count > 0
        collectionView.isHidden = count == 0
    }
    
    func reloadData() {
        collectionView.reloadData()
    }
}

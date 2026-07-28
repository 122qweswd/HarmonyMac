//
//  MIDeviceItem.swift
//  MutualInfectionApp
//
//  Created by Niko on 2025/9/1.
//

import UIKit
import SnapKit

class MIDeviceItem: UICollectionViewCell {
      
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.distribution = .fill
        return stack
    }()
    
    let deviceImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    let deviceNameLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()
    
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
        
        stackView.addArrangedSubview(deviceImageView)
        stackView.addArrangedSubview(deviceNameLabel)
        
        // 设置默认内容（可选）
        deviceNameLabel.text = "设备名称"
    }
    
    // MARK: - Constraints
    private func setupConstraints() {
        
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        deviceImageView.snp.makeConstraints { make in
            make.size.equalTo(CGSize(width: 64, height: 64))
        }
    }
    
    // MARK: - Configuration
    func configure(withDeviceName name: String, image: UIImage? = nil) {
        deviceNameLabel.text = name
        deviceImageView.image = image
        
        // 如果没有图片，设置默认占位图
        if deviceImageView.image == nil {
            if let systemImage = UIImage(systemName: "iphone") {
                deviceImageView.image = systemImage
                deviceImageView.tintColor = .systemGray
            }
        }
    }
    
    // MARK: - Cell Reuse
    override func prepareForReuse() {
        super.prepareForReuse()
        deviceImageView.image = nil
        deviceNameLabel.text = nil
    }
}

// 添加预览代码
#if canImport(SwiftUI) && DEBUG
import SwiftUI
struct MIDeviceItem_Previews: PreviewProvider {
    static var previews: some View {
        MIDeviceItem(frame: CGRect(x: 0, y: 0, width: 88, height: 114)).preview()
            .previewLayout(.sizeThatFits)
            .padding(10)
    }
}
#endif

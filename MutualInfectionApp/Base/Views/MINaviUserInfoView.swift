//
//  MINaviUserInfoView.swift
//  MutualInfectionApp
//
//  Created by Niko on 2025/9/1.
//

import UIKit
import SnapKit

class MINaviUserInfoView: UIView {
    
    /// 头像
    lazy var iconImageView: UIImageView = {
        let iconImageView = UIImageView()
        iconImageView.image = UIImage.iconDevice
        iconImageView.layer.cornerRadius = iconSize().height / 2.0
        iconImageView.clipsToBounds = true
//        iconImageView.backgroundColor = .red
        return iconImageView
    }()
    
    /// 描述
    lazy var desLabel: UILabel = {
        let label = UILabel()
        label.font = SFCompact(weight: .regular,size: 14)
            //.systemFont(ofSize: 16)
        label.textColor = "#000000".color.withAlphaComponent(0.38)
        label.text = "我是描述"
        return label
    }()
    
    /// 用户名
    lazy var userNameLabel: UILabel = {
        let label = UILabel()
        label.font = SFCompact(weight: .regular,size: 20)
            //.systemFont(ofSize: 20)
        label.textColor = "#000000".color
        label.text = "用户名"
        return label
    }()
    
    let stackView = UIStackView()
    
    func iconSize() -> CGSize{
        if UIDevice.current.userInterfaceIdiom == .pad {
            return CGSizeMake(56, 56)
        }
        else{
            return CGSizeMake(44, 44)
        }
    }
    
    /// 创建并添加到父视图的便捷方法
    class func initView(icon: UIImage? = nil, username: String? = nil, des: String? = nil) -> MINaviUserInfoView {
        
        let view = MINaviUserInfoView()
        view.iconImageView.image = icon
        view.desLabel.text = des
        view.userNameLabel.text = username
        
        return view
    }
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    
    private func setupUI() {
        
        self.addSubview(iconImageView)
        iconImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            if UIDevice.current.userInterfaceIdiom == .pad {
                make.leading.equalToSuperview().offset(32)
            }else{
                make.leading.equalToSuperview().offset(16)
            }
            make.size.equalTo(iconSize())
        }
        
        stackView.addArrangedSubview(desLabel)
        stackView.addArrangedSubview(userNameLabel)
        stackView.axis = .vertical
        stackView.spacing = 6
        self.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(8)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview()
        }
        
    }
}

// 添加预览代码
#if canImport(SwiftUI) && DEBUG
import SwiftUI
struct MyCustomView_Previews: PreviewProvider {
    static var previews: some View {
        MINaviUserInfoView(frame: CGRect(x: 0, y: 0, width: 320, height: 50)).preview()
            .previewLayout(.sizeThatFits)
            .padding(10)
    }
}
#endif

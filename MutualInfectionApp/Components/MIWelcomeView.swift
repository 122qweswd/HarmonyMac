//
//  MIWelcomeView.swift
//  MutualInfectionApp
//
//  Created by ww on 2025/9/5.
//

import UIKit
import IBAnimatable
import SnapKit

class MIWelcomeView: UIView {

    // MARK: - UI Components
    var backView: AnimatableView?
    private var appIconImageView: UIImageView!
    private var titleLabel: UILabel!
    private var subtitleLabel: UILabel!
    private var privacyIconImageView: UIImageView!
    private var privacyLabel: UILabel!
    private var privacyTapGesture: UITapGestureRecognizer!
    private var cancelButton: UIButton!
    private var acceptButton: UIButton!
    private var blurEffectView: UIVisualEffectView!
  
    
    // MARK: - Callbacks
    var onCancelTapped: (() -> Void)?
    var onAcceptTapped: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        self.backgroundColor = .white
        
        // 创建主容器视图
        backView = AnimatableView()
        backView?.backgroundColor = UIColor(hex: "e3e3e3   ")
        backView?.cornerRadius = 32
        addSubview(backView ?? UIView())
        
        // 创建毛玻璃效果视图
//        let blurEffect = UIBlurEffect(style: .light) // 使用 light 样式以获得白色模糊效果
//        blurEffectView = UIVisualEffectView(effect: blurEffect)
//        blurEffectView.alpha = 0.8 // 设置透明度：0.8 表示 80% 不透明（略带透明）
//        
//        blurEffectView.layer.shadowColor = UIColor.black.cgColor
//        blurEffectView.layer.shadowOffset = CGSize(width: 0, height: 0)
//        //blurEffectView.layer.shadowOpacity = 0.8
//        blurEffectView.layer.cornerRadius = 32
//        blurEffectView.clipsToBounds = true
//        //blurEffectView.backgroundColor = .black.withAlpha(0.85)
//        
//        backView?.addSubview(blurEffectView)

        // 创建应用图标
        appIconImageView = UIImageView()
        appIconImageView.contentMode = .scaleAspectFit
        appIconImageView.layer.cornerRadius = 22
        appIconImageView.clipsToBounds = true
        appIconImageView.image = UIImage.darkIcon
        backView?.addSubview(appIconImageView)

        // 创建主标题
        titleLabel = UILabel()
        titleLabel.text = "欢迎使用鸿蒙星河互联".localized
        titleLabel.font = SFCompact(weight: .bold,size: 24)
        titleLabel.textColor = UIColor.black.withAlphaComponent(0.9)
        titleLabel.textAlignment = .left
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center
        backView?.addSubview(titleLabel)
        
        // 创建副标题
        subtitleLabel = UILabel()
        subtitleLabel.text = "与HarmonyOS设备自由连接，高效互传".localized
        subtitleLabel.font = SFCompact(weight: .regular,size: 17)
        subtitleLabel.textColor = UIColor.black.withAlphaComponent(0.6)
        subtitleLabel.textAlignment = .left
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textAlignment = .center
        backView?.addSubview(subtitleLabel)
        
        // 创建隐私图标
        privacyIconImageView = UIImageView()
        privacyIconImageView.contentMode = .scaleAspectFit
        privacyIconImageView.tintColor = UIColor.systemBlue
        privacyIconImageView.image = UIImage.privacy
        backView?.addSubview(privacyIconImageView)
        
        // 创建隐私说明文本
        privacyLabel = UILabel()
        privacyLabel.font = SFCompact(weight: .regular,size: 12)
        privacyLabel.textColor = "#000000".color.withAlphaComponent(0.6)
        privacyLabel.numberOfLines = 0
        privacyLabel.textAlignment = .left
        privacyLabel.isUserInteractionEnabled = true
        backView?.addSubview(privacyLabel)
        
        // 设置富文本内容
        setupPrivacyText(privacyLabel: privacyLabel)
        
        // 添加点击手势
        privacyTapGesture = UITapGestureRecognizer(target: self, action: #selector(handlePrivacyTap(_:)))
        privacyLabel.addGestureRecognizer(privacyTapGesture)
        
        // 创建取消按钮
        cancelButton = UIButton(type: .system)
        cancelButton.setTitle("取消".localized, for: .normal)
        cancelButton.setTitleColor("#000000".color.withAlphaComponent(0.9), for: .normal)
        cancelButton.setBackgroundImage(UIImage.bkgBtn, for: .normal)
        cancelButton.layer.cornerRadius = 20
        cancelButton.titleLabel?.font = SFCompact(weight: .medium,size: 17)
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        backView?.addSubview(cancelButton)
        
        // 创建接受按钮
        acceptButton = UIButton(type: .system)
        acceptButton.setTitle("接受".localized, for: .normal)
        acceptButton.setTitleColor("#000000".color.withAlphaComponent(0.9), for: .normal)
        acceptButton.setBackgroundImage(UIImage.bkgBtn, for: .normal)
        acceptButton.layer.cornerRadius = 20
        acceptButton.titleLabel?.font = SFCompact(weight: .medium,size: 17)
        acceptButton.addTarget(self, action: #selector(acceptButtonTapped), for: .touchUpInside)
        backView?.addSubview(acceptButton)
    }
    
    
    
    private func setupConstraints() {
        backView?.snp.makeConstraints {
            $0.horizontalEdges.bottom.equalToSuperview()
            $0.top.equalTo(68)
        }
        
//        blurEffectView.snp.makeConstraints { make in
//            make.edges.equalTo(backView!)
//        }

        // 应用图标约束
        appIconImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(62)
            make.width.height.equalTo(76)
        }
        
        // 主标题约束
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(16)
            make.trailing.equalTo(-16)
            make.centerX.equalToSuperview()
            make.top.equalTo(appIconImageView.snp.bottom).offset(40)
        }
        
        // 副标题约束
        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(16)
            make.trailing.equalTo(-16)
            make.centerX.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
        }
        
        // 权限图标约束
        privacyIconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(30)
            make.bottom.equalTo(privacyLabel.snp.top).offset(-12)
            make.width.equalTo(22)
            make.height.equalTo(26)
        }
        
        // 隐私说明文本约束
        privacyLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(30)
            make.trailing.equalToSuperview().offset(-30)
//            make.top.equalTo(cancelButton.snp.top).offset(-16)
            make.bottom.equalTo(cancelButton.snp.top).offset(-16)
        }
        
        // 取消按钮约束
        cancelButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(30)
            make.bottom.equalToSuperview().offset(-26)
            make.width.equalTo(phoneToPad(58))
            make.height.equalTo(phoneToPad(44))
        }
        
        // 接受按钮约束
        acceptButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-30)
            make.bottom.equalToSuperview().offset(-26)
            make.width.equalTo(phoneToPad(58))
            make.height.equalTo(phoneToPad(44))
        }
    }
    
    
    
    @objc private func cancelButtonTapped() {
        handleCancelButtonTapped()
    }

    @objc private func acceptButtonTapped() {
        handleAcceptButtonTapped(
            onAcceptTapped: onAcceptTapped,
            window: window
        )
    }
    
    @objc func handlePrivacyTap(_ gesture: UITapGestureRecognizer) {
           handlePrivacyLabelTap(gesture, privacyLabel: privacyLabel)
    }
}

//
//  MIWelcomePadFile.swift
//  MutualInfectionApp
//
//  Created by mac on 2025/10/16.
//

import UIKit
import IBAnimatable
import SnapKit
class MIWelcomePadView: UIView{
    var backView: AnimatableView?
    // MARK: - Callbacks
    var onCancelTapped: (() -> Void)?
    var onAcceptTapped: (() -> Void)?
    private var appIconImageView: UIImageView!
    private var titleLabel: UILabel!
    private var subtitleLabel: UILabel!
    private var privacyIconImageView: UIImageView!
    private var privacyLabel: UILabel!
    private var cancelButton: UIButton!
    private var acceptButton: UIButton!
    private var privacyTapGesture: UITapGestureRecognizer!
    //分享
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    private func setupUI() {
        let backgroundImageView = UIImageView(image: UIImage.bkGround)
        backgroundImageView.contentMode = .scaleAspectFill
        self.addSubview(backgroundImageView)
        self.sendSubviewToBack(backgroundImageView)

        backgroundImageView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        
        // 创建主容器卡片
        let cardView = UIView()
        cardView.backgroundColor = .white
        cardView.layer.cornerRadius = 30
        self.addSubview(cardView)

        cardView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.width.equalTo(589)
            $0.height.equalTo(650)
        }

        // 创建应用图标
        appIconImageView = UIImageView()
        appIconImageView.contentMode = .scaleAspectFit
        appIconImageView.layer.cornerRadius = 22
        appIconImageView.clipsToBounds = true
        appIconImageView.image = UIImage.darkIcon
        cardView.addSubview(appIconImageView)

        appIconImageView.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalToSuperview().offset(92)
            $0.width.height.equalTo(76)
        }
         // 主标题
        titleLabel = UILabel()
        titleLabel.text = "欢迎使用鸿蒙星河互联".localized
        titleLabel.font = SFCompact(weight: .bold,size: 20)
        titleLabel.textColor = UIColor.black.withAlphaComponent(0.9)
        titleLabel.textAlignment = .left
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center
        cardView.addSubview(titleLabel)
        
        titleLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(90)
            $0.trailing.equalToSuperview().offset(-90)
            $0.centerX.equalToSuperview()
            $0.top.equalTo(appIconImageView.snp.bottom).offset(40)
        }

        subtitleLabel = UILabel()
        subtitleLabel.text = "与HarmonyOS设备自由连接，高效互传".localized
        subtitleLabel.font = SFCompact(weight: .regular,size: 17)
        subtitleLabel.textColor = UIColor.black.withAlphaComponent(0.6)
        subtitleLabel.textAlignment = .left
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textAlignment = .center
        cardView.addSubview(subtitleLabel)

        subtitleLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(90)
            $0.trailing.equalToSuperview().offset(-90)
            $0.centerX.equalToSuperview()
            $0.top.equalTo(titleLabel.snp.bottom).offset(4)
        }

        // 创建隐私图标
        privacyIconImageView = UIImageView()
        privacyIconImageView.contentMode = .scaleAspectFit
        privacyIconImageView.tintColor = UIColor.systemBlue
        privacyIconImageView.image = UIImage.privacy
        cardView.addSubview(privacyIconImageView)

       
     
        // 创建隐私说明文本
        privacyLabel = UILabel()
        privacyLabel.font = SFCompact(weight: .regular,size: 12)
        privacyLabel.textColor = "#000000".color.withAlphaComponent(0.6)
        privacyLabel.numberOfLines = 0
        privacyLabel.textAlignment = .left
        privacyLabel.isUserInteractionEnabled = true
        cardView.addSubview(privacyLabel)

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
        cardView.addSubview(cancelButton)
        
        // 创建接受按钮
        acceptButton = UIButton(type: .system)
        acceptButton.setTitle("接受".localized, for: .normal)
        acceptButton.setTitleColor("#000000".color.withAlphaComponent(0.9), for: .normal)
        acceptButton.setBackgroundImage(UIImage.bkgBtn, for: .normal)
        acceptButton.layer.cornerRadius = 20
        acceptButton.titleLabel?.font = SFCompact(weight: .medium,size: 17)
        acceptButton.addTarget(self, action: #selector(acceptButtonTapped), for: .touchUpInside)
        cardView.addSubview(acceptButton)
        
        
        
        // 权限图标约束
        privacyIconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(90)
            make.bottom.equalTo(privacyLabel.snp.top).offset(-12)
            make.width.equalTo(22)
            make.height.equalTo(26)
        }
        
        
        
        // 隐私说明文本约束
        privacyLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(90)
            make.trailing.equalToSuperview().offset(-90)
//            make.top.equalTo(cancelButton.snp.top).offset(-16)
            make.bottom.equalTo(cancelButton.snp.top).offset(-40)
        }


        // 取消按钮约束
        cancelButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(90)
            make.bottom.equalToSuperview().offset(-35)
            make.width.equalTo(phoneToPad(58))
            make.height.equalTo(phoneToPad(44))
        }
        
        // 接受按钮约束
        acceptButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-90)
            make.bottom.equalToSuperview().offset(-35)
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

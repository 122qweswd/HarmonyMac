//
//  MILivePhotoAuthorizedView.swift
//  MutualInfection
//
//  Created by Niko on 2025/10/16.
//

import SnapKit

#if os(iOS)

import UIKit
// MARK: -  iOS
class MILivePhotoAuthorizedView: UIView {

    lazy var subView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white
        view.layer.cornerRadius = 32
        return view
    }()
    
    lazy var buttonStackView: UIStackView = {
        let whiteButton = UIButton()
        whiteButton.setTitle("继续分享", for: .normal)
        whiteButton.setTitleColor("#000000".color, for: .normal)
        whiteButton.backgroundColor = "#787880".color.withAlpha(0.16)
        whiteButton.layer.cornerRadius = 24
        whiteButton.addClickClosure { [weak self] sender in
            guard let self = self else { return }
            livePhotoAuthorizedContinueCallBack?()
            removeFromSuperview()
        }
        
        let mainButton = UIButton()
        mainButton.setTitle("开启权限", for: .normal)
        mainButton.setTitleColor("#FFFFFF".color, for: .normal)
        mainButton.backgroundColor = "#0088FF".color
        mainButton.layer.cornerRadius = 24
        mainButton.addClickClosure { [weak self] sender in
            guard let self = self else { return }
            if let url = URL(string: UIApplication.openSettingsURLString + "App-Prefs:root=APP") {
                UIApplication.shared.open(url)
            }
            livePhotoAuthorizedCancelCallBack?()
            removeFromSuperview()
        }
        
        let stackView = UIStackView(arrangedSubviews: [whiteButton, mainButton])
        stackView.spacing = 16
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        return stackView
    }()
    
    var livePhotoAuthorizedContinueCallBack: (() -> Void)?
    var livePhotoAuthorizedCancelCallBack: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = "#000000".color.withAlpha(0.15)
        
        initViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func initViews() {
        self.addSubview(subView)
        subView.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.bottom.equalToSuperview().offset(-MISafeAreaBottom - 10)
            $0.width.equalTo(343)
            $0.height.equalTo(400)
        }
        
        let iamgeView = UIImageView(image: UIImage.iconPopLivePhoto)
        subView.addSubview(iamgeView)
        iamgeView.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalToSuperview().offset(55)
        }
        
        let titleLabel = UILabel()
            .withText("分享内容包含实况图，需在设\n置中开启相册权限，可保留实况效果。")
            .withColorText("#000000")
            .withFont(.systemFont(ofSize: 17, weight: .medium))
            .withTextAlignment(.center)
            .withNumberOfLines(0)
        subView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(iamgeView.snp.bottom).offset(10)
        }
        
        let desLabel = UILabel()
            .withText("若继续分享，已选实况图将转化为静态图。")
            .withFont(.systemFont(ofSize: 13, weight: .regular))
        desLabel.textColor = "#000000".color.withAlpha(0.6)
        subView.addSubview(desLabel)
        desLabel.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(titleLabel.snp.bottom).offset(10)
        }
        
        subView.addSubview(buttonStackView)
        buttonStackView.snp.makeConstraints {
            $0.height.equalTo(48)
            $0.bottom.equalToSuperview().offset(-25)
            $0.leading.equalToSuperview().offset(35)
            $0.trailing.equalToSuperview().offset(-35)
        }
        
//        let actionLabel = UILabel()
//        // 创建段落样式并设置行高
//        let paragraphStyle = NSMutableParagraphStyle()
//        paragraphStyle.minimumLineHeight = 19 // 设置最小行高为 19
//
//        // 创建属性字典，包含字体、颜色和段落样式
//        let attributes: [NSAttributedString.Key: Any] = [
//            .font: UIFont.systemFont(ofSize: 13, weight: .medium),
//            .foregroundColor: "#000000".color, // 对应 
//            .paragraphStyle: paragraphStyle
//        ]
//
//        // 创建 NSAttributedString 并应用到 UILabel
//        let attributedString = NSAttributedString(
//            string: "您也可以允许“鸿蒙星河互联”完全访问照片图库，使每次分享均为实况效果。",
//            attributes: attributes
//        )
//        actionLabel.attributedText = attributedString
//        actionLabel.numberOfLines = 2
//
//        subView.addSubview(actionLabel)
//        actionLabel.snp.makeConstraints {
//            $0.bottom.equalTo(buttonStackView.snp.top).offset(-24)
//            $0.leading.equalToSuperview().offset(24)
//            $0.trailing.equalToSuperview().offset(-24)
//        }
//        
//        let goToSetButton = UIButton()
//        goToSetButton.setTitle("去设置", for: .normal)
//        goToSetButton.setTitleColor("#336FFF".color, for: .normal)
//        goToSetButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
//        goToSetButton.addClickClosure { sender in
//            if let url = URL(string: UIApplication.openSettingsURLString + "App-Prefs:root=APP") {
//                UIApplication.shared.open(url)
//            }
//        }
//        
//        subView.addSubview(goToSetButton)
//        goToSetButton.snp.makeConstraints {
//            $0.bottom.equalToSuperview().offset(-90)
//            $0.trailing.equalToSuperview().offset(-24)
//        }
    }
    
    static func showLivePhotoAuthorizedView(onContinue: @escaping (() -> Void), onCancel: @escaping (() -> Void)) {
        let livePhotoView = MILivePhotoAuthorizedView(frame: UIScreen.main.bounds)
        livePhotoView.livePhotoAuthorizedContinueCallBack = onContinue
        livePhotoView.livePhotoAuthorizedCancelCallBack = onCancel
        MIKeyWindow?.addSubview(livePhotoView)
    }
}






#elseif os(macOS)
import AppKit
// MARK: -  MacOS
class MILivePhotoAuthorizedView: NSView {

   

}

#endif


//
//  MIEffectViewVC.swift
//  MutualInfectionApp
//
//  Created by apple on 2025/9/9.
//

import UIKit
import IBAnimatable


class MIEffectViewVC: UIViewController {
    
    var closeAction:ClickBlockVoid?
    // MARK: - UI Components
    var backView: AnimatableView?
    private var blurEffectView: UIVisualEffectView!
    lazy var titleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.text = ""
        titleLabel.textColor = UIColor(hexString: "#000000")
        titleLabel.font = pingFangSC(weight: .medium,size: 17)
        return titleLabel
    }()
    
    /// 关闭按钮
    lazy var closeButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage.chevronBackward, for: .normal)
        button.addClickClosure { [weak self] sender in
            self?.closeAction?()
            self?.dismiss(animated: true)
        }
        return button
    }()
    
    

    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = .clear
        self.navigationController?.navigationBar.isHidden = true
        
//        contentView.layer.cornerRadius = 20
//        contentView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
//
//        self.view.addSubview(contentView)
//        contentView.snp.makeConstraints { make in
//            make.edges.equalTo(UIEdgeInsets(top: MISafeAreaTop, left: 0, bottom: 0, right: 0))
//        }
        
        // 创建主容器视图
        backView = AnimatableView()
        backView?.backgroundColor = "#F9F9F9".color
        backView?.cornerRadius = 32
        self.view.addSubview(backView ?? UIView())
        
        // 创建毛玻璃效果视图
//        let blurEffect = UIBlurEffect(style: .light) // 使用 light 样式以获得白色模糊效果
//        blurEffectView = UIVisualEffectView(effect: blurEffect)
//        blurEffectView.alpha = 0.8 // 设置透明度：0.8 表示 80% 不透明（略带透明）
//        
//        blurEffectView.layer.shadowColor = UIColor.black.cgColor
//        blurEffectView.layer.shadowOffset = CGSize(width: 0, height: 0)
//        blurEffectView.layer.shadowOpacity = 0.8
//        blurEffectView.layer.cornerRadius = 32
//        blurEffectView.clipsToBounds = true
//        blurEffectView.backgroundColor = .white.withAlpha(0.3)
//        
//        backView?.addSubview(blurEffectView)
        
        
        backView?.snp.makeConstraints {
            $0.horizontalEdges.bottom.equalToSuperview()
            $0.top.equalTo(MISafeAreaTop)
        }
        
    
        
//        blurEffectView.snp.makeConstraints { make in
//            make.edges.equalTo(backView!)
//        }
        
        
        self.backView?.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.leading.equalTo(phoneToPad(16))
            make.top.equalTo(phoneToPad(14))
        }
        
        
        self.backView?.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalTo(self.closeButton)
            make.centerX.equalToSuperview()
        }
    
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
       
    }

}

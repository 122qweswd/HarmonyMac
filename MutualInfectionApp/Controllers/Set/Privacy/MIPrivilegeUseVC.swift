//
//  Untitled.swift
//  MutualInfection
//
//  Created by ww on 2025/9/10.
//

import UIKit
import SnapKit

class MIPrivilegeUseVC: MIEffectViewVC {
    private var scrollView: UIScrollView!
    private var contentView: UIView!
    private var contentLabel: UILabel!
    private var userAgreeTapGesture: UITapGestureRecognizer!
   
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        self.view.backgroundColor = .clear
        // Do any additional setup after loading the view.
    }
    private func setupUI() {
        
        self.closeButton.setImage(UIImage.btnClose, for:.normal)
        self.closeButton.snp.remakeConstraints{
            $0.trailing.equalTo(-16)
            $0.top.equalTo(14)
        }
        
        // 创建标题
        titleLabel = UILabel()
        titleLabel.text = "权限使用说明".localized
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textColor = "#000000".color.withAlpha(0.9)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        self.view?.addSubview(titleLabel)
        
        // 标题约束
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(closeButton.snp.bottom).offset(6)
            make.leading.equalToSuperview().offset(30)
            make.trailing.equalToSuperview().offset(-30)
        }
        
        // 创建滚动视图
        scrollView = UIScrollView()
//        scrollView.backgroundColor = .white
        scrollView.layer.cornerRadius = 0
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = false
        self.view?.addSubview(scrollView)
        
        // 滚动视图约束
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(14)
            make.leading.equalToSuperview().offset(30)
            make.trailing.equalToSuperview().offset(-30)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-30)
        }
        
        // 创建内容视图
        contentView = UIView()
        contentView.backgroundColor = .clear
        scrollView.addSubview(contentView)
        
        // 内容视图约束
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }
        
        // 创建内容标签
        contentLabel = UILabel()
        contentLabel.font = UIFont.systemFont(ofSize: 14)
        contentLabel.textColor = "#000000".color.withAlpha(0.6)
        contentLabel.numberOfLines = 0
        contentLabel.textAlignment = .left
//        contentLabel.text = getPrivacyText()
        contentLabel.isUserInteractionEnabled = true
        contentView.addSubview(contentLabel)
        
        // 内容标签约束
        contentLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(0)
            make.leading.equalToSuperview().offset(0)
            make.trailing.equalToSuperview().offset(-0)
            make.bottom.equalToSuperview().offset(-0)
        }
        
        // 设置富文本内容
        setupPrivacyText()
    }
   
    
    private func setupPrivacyText() {
        let fullText = getPrivacyText().localized
        
        let attributedString = NSMutableAttributedString(string: fullText)
        
        attributedString.addAttribute(.foregroundColor, value: "#000000".color.withAlpha(0.6), range: NSRange(location: 0, length: fullText.count))
        attributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 14), range: NSRange(location: 0, length: fullText.count))
        
        // 为关键词添加加粗样式
        let boldTexts = ["无线局域网".localized,"蓝牙".localized,"位置".localized,"照片".localized,"通讯录".localized,"存储权限".localized]
        for boldText in boldTexts {
            if let range = fullText.range(of: boldText) {
                let nsRange = NSRange(range, in: fullText)
                attributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 14), range: nsRange)
                attributedString.addAttribute(.foregroundColor, value: UIColor.black, range: nsRange)
            }
        }
        contentLabel.attributedText = attributedString
    }
    
    private func getPrivacyText() -> String {
            return """
            使用过程中申请

            无线局域网
            用于在相同局域网下连接设备，传输文件

            蓝牙
            用于使用蓝牙搜索附近的设备

            位置
            用于判断是否处于同一局域网

            照片
            用于互传时读取照片，视频等文件

            通讯录
            用于互传时读取通讯录

            存储权限
            用于存储传输记录
            """
        }


}

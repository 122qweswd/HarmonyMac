//
//  WelcomeText.swift
//  MutualInfectionApp
//
//  Created by mac on 2025/10/17.
//

import Foundation
import UIKit

func setupPrivacyText(privacyLabel:UILabel) {
    let fullText = "本服务需使用蓝牙、WLAN连接并收发数据，读取图片、视频、联系人和文件等信息，获取网络信息，我们仅在使用具体业务功能时才触发上述行为收集使用相关的个人信息。本服务为您提供鸿蒙星河互联的基本业务功能。点击“接受”，即表示您同意鸿蒙星河互联用户协议、权限使用说明、关于鸿蒙星河互联与隐私的声明。".localized
    
    let attributedString = NSMutableAttributedString(string: fullText)
    // 设置段落样式，包括行高
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineSpacing = 3 // 行高18 - 字号12 = 6
//        paragraphStyle.minimumLineHeight = 18
//        paragraphStyle.maximumLineHeight = 18
    
    attributedString.addAttribute(.foregroundColor, value: "#000000".color.withAlphaComponent(0.6), range: NSRange(location: 0, length: fullText.count))
    attributedString.addAttribute(.font, value: SFCompact(weight: .regular,size: 12), range: NSRange(location: 0, length: fullText.count))
    attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: fullText.count))
    // 为关键词添加加粗样式
    let boldTexts = ["蓝牙、WLAN".localized, "图片、视频、联系人".localized,"文件".localized,"网络信息".localized]
    for boldText in boldTexts {
        if let range = fullText.range(of: boldText) {
            let nsRange = NSRange(range, in: fullText)
            attributedString.addAttribute(.font, value: SFCompact(weight: .bold,size: 12), range: nsRange)
            attributedString.addAttribute(.foregroundColor, value: UIColor.black, range: nsRange)
        }
    }
    
    let linkTexts = ["鸿蒙星河互联用户协议".localized, "权限使用说明".localized,"关于鸿蒙星河互联与隐私的声明".localized]
    for linkText in linkTexts {
        if let range = fullText.range(of: linkText) {
            let nsRange = NSRange(range, in: fullText)
            attributedString.addAttribute(.font, value: SFCompact(weight: .bold,size: 12), range: nsRange)
            attributedString.addAttribute(.foregroundColor, value: UIColor.black, range: nsRange)
            attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: nsRange)
        }
    }
  
    privacyLabel.attributedText = attributedString
}

// MARK: - 隐私文本点击处理
func handlePrivacyLabelTap(_ gesture: UITapGestureRecognizer, privacyLabel: UILabel) {
    let location = gesture.location(in: privacyLabel)
    let textContainer = NSTextContainer(size: privacyLabel.bounds.size)
    let layoutManager = NSLayoutManager()
    let textStorage = NSTextStorage(attributedString: privacyLabel.attributedText ?? NSAttributedString())

    textStorage.addLayoutManager(layoutManager)
    layoutManager.addTextContainer(textContainer)

    textContainer.lineFragmentPadding = 0
    textContainer.maximumNumberOfLines = privacyLabel.numberOfLines
    textContainer.lineBreakMode = privacyLabel.lineBreakMode

    let characterIndex = layoutManager.characterIndex(for: location, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)

    // 检查点击的是否是"鸿蒙星河互联用户协议"
    let linkText1 = "鸿蒙星河互联用户协议".localized
    if let range = privacyLabel.text?.range(of: linkText1) {
        let nsRange = NSRange(range, in: privacyLabel.text!)
        if NSLocationInRange(characterIndex, nsRange) {
            print("点击了鸿蒙星河互联用户协议")
            let language = getCurrentLanguage()
            if language.hasPrefix("en") {
                UIApplication.shared.open(URL(string: "https://goenrhvr.html2web.com")!, options: [:], completionHandler: nil)
            }else{
                UIApplication.shared.open(URL(string: "https://hecu0ijg.html2web.com")!, options: [:], completionHandler: nil)
            }
            return
        }
    }

    // 检查点击的是否是"权限使用说明"
    let linkText2 = "权限使用说明".localized
    if let range = privacyLabel.text?.range(of: linkText2) {
        let nsRange = NSRange(range, in: privacyLabel.text!)
        if NSLocationInRange(characterIndex, nsRange) {
            print("点击了权限使用说明")
            let vc = MIPrivilegeUseVC()
            vc.modalPresentationStyle = .overCurrentContext

            MIGetTopViewController()?.present(vc, animated: true)
            return
        }
    }

    // 检查点击的是否是"关于鸿蒙星河互联与隐私的声明"
    let linkText3 = "关于鸿蒙星河互联与隐私的声明".localized
    if let range = privacyLabel.text?.range(of: linkText3) {
        let nsRange = NSRange(range, in: privacyLabel.text!)
        if NSLocationInRange(characterIndex, nsRange) {
            print("点击了关于鸿蒙星河互联与隐私的声明")
            let language = getCurrentLanguage()
            if language.hasPrefix("en") {
                UIApplication.shared.open(URL(string: "https://t5tzm0o7.html2web.com")!, options: [:], completionHandler: nil)
            }else{
                UIApplication.shared.open(URL(string: "https://hj3vyrsi.html2web.com")!, options: [:], completionHandler: nil)
            }
            return
        }
    }
}
func getCurrentLanguage() -> String {
    return Locale.preferredLanguages.first ?? "en"
}
func handleCancelButtonTapped() {
    var manger = ShareAPI.shared()
    manger.stopCoap()
    exit(0)
    print("点了取消")
}

func handleAcceptButtonTapped(onAcceptTapped: (() -> Void)?,
                             window: UIWindow?) {
    onAcceptTapped?()

    UserDefaults.standard.set(true, forKey: use_agree)

    let vc = MIHuaweiShareViewController()
    //接受切换根视图到首页
    let naviController = MIBaseNavigationViewController(rootViewController: vc)
    window?.rootViewController = naviController


    print("点了接受")
}



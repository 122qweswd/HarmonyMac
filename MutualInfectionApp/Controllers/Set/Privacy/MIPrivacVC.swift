//
//  MIPrivacVC.swift
//  MutualInfectionApp
//
//  Created by ww on 2025/9/9.
//

import UIKit
import SnapKit

class MIPrivacVC: MIEffectViewVC {
    
    private var privacyIconImageView: UIImageView!
    private var scrollView: UIScrollView!
    private var contentView: UIView!
    private var contentLabel: UILabel!
    private var privacyTapGesture: UITapGestureRecognizer!
    
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
        
        // 创建隐私图标
        privacyIconImageView = UIImageView()
        privacyIconImageView.image = UIImage.privacy
        privacyIconImageView.contentMode = .scaleAspectFit
        self.view?.addSubview(privacyIconImageView)
        
        // 隐私图标约束
        privacyIconImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(closeButton.snp.bottom).offset(6)
            make.width.equalTo(64)
            make.height.equalTo(76)
        }
        
        // 创建标题
        titleLabel = UILabel()
        titleLabel.text = "关于鸿蒙互传与隐私的声明".localized
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textColor = "#000000".color.withAlpha(0.9)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        self.view?.addSubview(titleLabel)
        
        // 标题约束
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(privacyIconImageView.snp.bottom).offset(40)
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
        
        //添加点击手势
        privacyTapGesture = UITapGestureRecognizer(target: self, action: #selector(privacyLabelTapped(_:)))
        contentLabel.addGestureRecognizer(privacyTapGesture)
        
    }
    @objc private func privacyLabelTapped(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: contentLabel)
        let textContainer = NSTextContainer(size: contentLabel.bounds.size)
        let layoutManager = NSLayoutManager()
        let textStorage = NSTextStorage(attributedString: contentLabel.attributedText ?? NSAttributedString())
        
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = contentLabel.numberOfLines
        textContainer.lineBreakMode = contentLabel.lineBreakMode
        
        let characterIndex = layoutManager.characterIndex(for: location, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
        
        // 定义所有链接文本
        let linkTexts = ["隐私声明摘要", "《华为消费者业务儿童隐私保护声明》","第三方共享信息清单","隐私问题页面","联系华为页面","华为消费者业务隐私声明"]

        // 遍历所有链接文本
        for linkText in linkTexts {
            if let range = contentLabel.text?.range(of: linkText) {
                let nsRange = NSRange(range, in: contentLabel.text!)
                if NSLocationInRange(characterIndex, nsRange) {
                    handleLinkTap(linkText: linkText)
                    return
                }
            }
        }
        
    }
    // MARK: - Link Tap Handler
    private func handleLinkTap(linkText: String) {
        switch linkText {
        case "隐私声明摘要":
            openUrl(linkText:"https://legal.cloud.huawei.com/terms/scope/huawei/health/privacy-statement.htm?code=cn&branchid=0&language=zh-cn&contenttag=di&version=20250820&subVersion=0&bgmode=white&trsp=false&ctype=huawei&tileExtLink=false")

        case "《华为消费者业务儿童隐私保护声明》":
            openUrl(linkText:"https://legal.cloud.huawei.com/legal/child/privacy-statement.htm?code=cn&language=zh-cn&bgmode=white&trsp=false&tileExtLink=false")
        case "第三方共享信息清单":
            openUrl(linkText:"https://legal.cloud.huawei.com/terms/scope/huawei/health/privacy-statement.htm?code=cn&branchid=0&language=zh-cn&contenttag=3rdshare&version=20250820&subVersion=0&bgmode=white&trsp=false&ctype=huawei&tileExtLink=false")
        
        case "隐私问题页面":
            openUrl(linkText:"https://consumer.huawei.com/cn/legal/privacy-questions/")
        
        case "联系华为页面":
            openUrl(linkText:"https://consumer.huawei.com/cn/support/contact-us/")
        case "华为消费者业务隐私声明":
            openUrl(linkText:"https://legal.cloud.huawei.com/legal/privacy/statement.htm?code=CN&language=zh-cn&code=cn&bgmode=white&trsp=false&tileExtLink=false")
        
        default:
            print("未知链接: \(linkText)")
        }
    }
    private func openUrl(linkText: String){
        let url = URL(string: linkText)
        if UIApplication.shared.canOpenURL(url!) {
            UIApplication.shared.open(url!) { success in
                if success {
                    print("URL opened successfully.")
                } else {
                    print("Failed to open URL.")
                }
            }
        } else {
            print("The URL scheme is not supported.")
        }
    }
    private func setupPrivacyText() {
        let fullText = getPrivacyText().localized
        
        let attributedString = NSMutableAttributedString(string: fullText)
        
        attributedString.addAttribute(.foregroundColor, value: "#000000".color.withAlpha(0.6), range: NSRange(location: 0, length: fullText.count))
        attributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 14), range: NSRange(location: 0, length: fullText.count))
        
        // 为关键词添加加粗样式
        let boldTexts = ["摘要","•为了提供更好的鸿蒙互传服务","您的互传包含您的敏感个人信息（相册，通讯录等），只有您在应用中明示同意后我们才会获取，您可以卸载本应用终止以上数据或功能的收集与处理","我们如何收集和使用您的个人信息","您的日志信息","向您收集的日志信息将仅被用于提供基本服务、分析服务使用过程中出现和可能出现的问题和错误，且不会与您的个人身份进行关联。","位置信息","位置信息仅本地缓存，不会被上传至服务器或用于其他非授权目的","用户传输数据","相关数据仅用于完成传输，我们不会进行内容识别、意图识别，更不会用于其他任何用途","我们将通过鸿蒙互传为您提供下述业务功能，在您使用相关业务功能的过程中，我们会处理下列提供功能所必需的信息，以便履行我们的合同义务。若您不提供相关信息，会影响到您使用本应用的相关功能。","1.1 文件互传","1.2 帮助与反馈","反馈","2 设备权限调用","在获取您的同意后，我们会向您提供互传服务，并处理相关的信息。","3 对未成年人的保护","4 与第三方共享","4.1 撤销同意","5 信息存储地点","5.1 存储地点","6 如何联系我们","华为将始终遵照我们的隐私政策来收集和使用您的信息。有关我们的隐私政策，可参阅"]
        for boldText in boldTexts {
            if let range = fullText.range(of: boldText) {
                let nsRange = NSRange(range, in: fullText)
                attributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 14), range: nsRange)
                attributedString.addAttribute(.foregroundColor, value: UIColor.black, range: nsRange)
            }
        }
        
        let linkTexts = ["隐私声明摘要", "《华为消费者业务儿童隐私保护声明》","第三方共享信息清单","隐私问题页面","联系华为页面","华为消费者业务隐私声明"]
        for linkText in linkTexts {
            if let range = fullText.range(of: linkText) {
                let nsRange = NSRange(range, in: fullText)
                attributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 14), range: nsRange)
                attributedString.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: nsRange)
                attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: nsRange)
            }
        }
      
        contentLabel.attributedText = attributedString
    }
    
    private func getPrivacyText() -> String {
            return """
            “鸿蒙互传”是由华为软件技术有限公司（注册地：江苏省南京市雨花台区软件大道101号）（以下简称“我们”或“华为”）为您提供运动指导和健康服务的应用。华为非常重视您的个人信息和隐私保护，我们将会按照法律要求和业界成熟的安全标准，为您的个人信息提供相应的安全保护措施。
            摘要
            您可以通过访问隐私声明摘要快速了解“华为运动健康”收集、使用个人信息的目的、方式、范围。
            •为了提供更好的鸿蒙互传服务，需要收集您的：设备标识、设备型号、设备名称、系统版本、网络信息（本地IP地址、网关IP地址）。
            •为了保护华为、您或其他华为用户的权利，我们会对上述收集信息进行风险控制，防止欺诈等违法活动并减少信用风险。
            您的互传包含您的敏感个人信息（相册，通讯录等），只有您在应用中明示同意后我们才会获取，您可以卸载本应用终止以上数据或功能的收集与处理。您的上述数据会保存在中华人民共和国境内。
            1 我们如何收集和使用您的个人信息
            您的设备信息：当您在某一设备上使用本服务时，我们会从该设备上收集特定的信息，包括设备标识、设备型号、设备名称、系统版本、网络信息（本地IP地址、网关IP地址），用于识别版本、快速判断错误情况、排查问题、并为您提供功能兼容性判断，以便及时优化产品并提供版本更新提示。
            (b) 您的日志信息：在您使用本服务的过程中，我们将收集本服务的日志信息（包括使用时长、传输数据量、数据类型、操作情况、连接状态等行为日志信息）。向您收集的日志信息将仅被用于提供基本服务、分析服务使用过程中出现和可能出现的问题和错误，且不会与您的个人身份进行关联。
            (c) 位置信息：设备进行连接时，需要根据您的位置信息进行连接、以及设备检索，以完成您所需的功能服务。位置信息仅本地缓存，不会被上传至服务器或用于其他非授权目的。
            (d) 用户传输数据：在您使用互传文件等对应功能时，需要缓存您所选择的图片、视频、文本、联系人等内容，以及您对所传输应用或服务模块的权限授权情况，以帮助您完成前述数据内容的传输。相关数据仅用于完成传输，我们不会进行内容识别、意图识别，更不会用于其他任何用途。
            我们将通过鸿蒙互传为您提供下述业务功能，在您使用相关业务功能的过程中，我们会处理下列提供功能所必需的信息，以便履行我们的合同义务。若您不提供相关信息，会影响到您使用本应用的相关功能。
            1.1 文件互传
            (1) 当您使用文件互传功能时，我们需要收集您的设备ID（UUID）、设备型号、蓝牙地址，用于与您的另一台设备进行区分和配对。
            (2) 您可以通过本功能建立与另一台设备的连接从而接收另一台设备上的联系人，文件，图片视频等支持传输的内容，为实现前述目的，我们需要读取您所选择的上述用户内容，前述内容将在您使用文件互传功能时，经您同意后由我们自动采集进行处理。
            1.2 帮助与反馈
            “帮助与反馈”功能为您提供常见问题的解决方案，在您使用“帮助与反馈”功能时，我们会收集您的设备的硬件信息（设备型号、设备类型）、问题描述为您提供相应的结果，解答您的问题。
            2 设备权限调用
            存储（或“媒体和文件”）权限：当您使用互传功能时，您可以选择开启该权限，以便读取或写入应用使用图片、视频、文件信息。如您不需要此类服务，可以随时关闭该权限。
            位置权限：当您使用互传功能时，您可以选择开启该权限，用于判断是否处于同一局域网。如您不需要此类服务，可以随时关闭该权限。
            无线局域网：当您使用互传功能时，您可以选择开启该权限，用于在相同局域网下连接设备，传输文件。
            蓝牙：当您使用互传功能时，您可以选择开启该权限，用于使用蓝牙搜索附近的设备。
            通讯录权限：当您使用互传功能时，您可以选择开启该权限，以便读取或写入联系人信息。如您不需要此类服务，可以随时关闭该权限。
            在获取您的同意后，我们会向您提供互传服务，并处理相关的信息。
            3 对未成年人的保护
            我们非常重视对未成年人个人信息的保护，华为将严格按照国家法律法规要求对未成年人提供服务并对未成年人提供保护。如果您是未成年人，需要您的父母或其他监护人同意您使用本应用并同意相关应用的服务条款。父母或其他监护人也应采取适当的预防措施来保护未成年人，包括监督其对本应用的使用。
            特别地，如果您是儿童（不满十四周岁的未成年人），在您使用我们的服务前，请务必通知您的父母或其他监护人一起仔细阅读本声明以及我们专门制定的《华为消费者业务儿童隐私保护声明》，并在您的父母或其他监护人同意或指导后，使用我们的服务或向我们提供信息。如果您是儿童的父母或其他监护人，请确保您监护的儿童在您的同意或指导下使用我们的服务和向我们提供信息。
            为了对儿童进行保护，儿童用户仅可以使用儿童帐号，父母或监护人应当确保您的孩子使用的是儿童帐号。儿童帐号登录以后，本应用不会进行个性化推荐和广告推送；运营相关的活动、抽奖、资讯、数据分享等内容将被隐藏；会员服务的内容将被隐藏；商城、表盘主题等未经您的授权不允许购买等。
            4 与第三方共享
            为了向您提供部分功能/服务，例如用于在微信运动中显示步数、热量等对应信息、在 QQ 运动中显示步数、在支付宝运动中显示步数等，我们需要将您的个人信息提供给第三方。为了保障您的数据安全和隐私，我们与合作伙伴签订了数据安全保护协议，明确了合作伙伴对您的数据的保护责任、义务和要求。详情请查阅第三方共享信息清单。
            4.1 撤销同意
            如果您需撤销授权，您可以前往“设置”>“权限管理”，关闭对应开关来撤销您的同意。
            5 信息存储地点
            5.1 存储地点
            上述信息将会保存至设备本地。
            6 如何联系我们
            我们设立了个人信息保护专职部门和个人信息保护负责人。如果您有任何疑问、意见或建议，请通过在线客服、访问隐私问题页面与我们联系，或者将其提交至我们的全球办事处。如需获取办事处的完整列表，请访问联系华为页面。您也可以通过客服热线（950800）联系我们。
            如果您对我们的回复不满意，特别是当我们的个人信息处理行为损害了您的合法权益时，您还可以通过向有管辖权的人民法院提起诉讼、向行业自律协会或政府相关管理机构投诉等外部途径进行解决。您也可以向我们了解可能适用的相关投诉途径的信息。
            华为将始终遵照我们的隐私政策来收集和使用您的信息。有关我们的隐私政策，可参阅华为消费者业务隐私声明。
            """
        }


}

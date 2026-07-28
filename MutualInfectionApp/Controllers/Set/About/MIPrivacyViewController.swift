//
//  MIPrivacyViewController.swift
//  MutualInfection
//
//  Created by ww on 2025/9/9.
//

import UIKit
import SnapKit

class MIPrivacyViewController: MIEffectViewVC {
    private var scrollView: UIScrollView!
    private var contentView: UIView!
    private var contentLabel: UILabel!
    private var privacyTapGesture: UITapGestureRecognizer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        self.titleLabel.text = "鸿蒙互传隐私政策".localized
        
        // 创建滚动视图
        scrollView = UIScrollView()
//        scrollView.backgroundColor = .white
        scrollView.layer.cornerRadius = 0
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = false
        backView?.addSubview(scrollView)
        
        // 滚动视图约束
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(28)
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
        contentLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        contentLabel.textColor = "#000000".color.withAlpha(0.6)
        contentLabel.numberOfLines = 0
        contentLabel.textAlignment = .left
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
        setupPrivacyTextFirst()
        
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
        let linkTexts = ["隐私问题", "联系华为","https://consumer.huawei.com/cn/support/service-privacy-notice/"]

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
        case "隐私问题":
            openUrl(linkText:"https://consumer.huawei.com/cn/legal/privacy-questions/")

        case "联系华为":
            openUrl(linkText:"https://consumer.huawei.com/cn/support/contact-us/")
        case "https://consumer.huawei.com/cn/support/service-privacy-notice/":
            openUrl(linkText:"https://consumer.huawei.com/cn/support/service-privacy-notice/")
        
        
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
    
    private func setupPrivacyTextFirst() {
        let fullText = getPrivacyText().localized
        
        let attributedString = NSMutableAttributedString(string: fullText)
        
        attributedString.addAttribute(.foregroundColor, value: "#000000".color.withAlpha(0.6), range: NSRange(location: 0, length: fullText.count))
        attributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 14), range: NSRange(location: 0, length: fullText.count))
        
        // 为关键词添加加粗样式
//        let boldTexts = ["请在使用本服务之前，阅读并确保您已理解和同意本政策，特别提示您查看加粗字体的重要内容。","您需要承诺在您开始使用本产品时已经是成年人，如果您是未成年人，需要您的监护人同意您使用本产品并接受该隐私政策及相关的服务条款。如您使用本服务，即表示您已阅读、认可并接受本隐私政策中的条款","1. 用户内容的传输","对于任何用户内容，我们仅提供帮助从一台设备向另一台设备进行传输的服务，而不会向您收集，亦不会通过任何形式获取、处理或使用","2. 我们收集的信息","您的设备信息","您的日志信息"]
//        for boldText in boldTexts {
//            if let range = fullText.range(of: boldText) {
//                let nsRange = NSRange(range, in: fullText)
//                attributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 14), range: nsRange)
//                attributedString.addAttribute(.foregroundColor, value: UIColor.black, range: nsRange)
//            }
//        }
    }
    
    private func setupPrivacyText() {
        let fullText = getPrivacyText().localized
        
        let attributedString = NSMutableAttributedString(string: fullText)
        
        attributedString.addAttribute(.foregroundColor, value: "#000000".color.withAlpha(0.6), range: NSRange(location: 0, length: fullText.count))
        attributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 14), range: NSRange(location: 0, length: fullText.count))
        
//        // 为关键词添加加粗样式
//        let boldTexts = ["请在使用本服务之前，阅读并确保您已理解和同意本政策，特别提示您查看加粗字体的重要内容。","您需要承诺在您开始使用本产品时已经是成年人，如果您是未成年人，需要您的监护人同意您使用本产品并接受该隐私政策及相关的服务条款。如您使用本服务，即表示您已阅读、认可并接受本隐私政策中的条款","1. 用户内容的传输","对于任何用户内容，我们仅提供帮助从一台设备向另一台设备进行传输的服务，而不会向您收集，亦不会通过任何形式获取、处理或使用","2. 我们收集的信息","您的设备信息","您的日志信息","向您收集的日志信息将仅被用于提供基本服务、分析服务使用过程中出现和可能出现的问题和错误，且不会与您的个人身份进行关联","位置信息","位置信息仅本地缓存，不会被上传至服务器或用于其他非授权目的","用户传输数据","相关数据仅用于完成传输，我们不会进行内容识别、意图识别，更不会用于其他任何用途。","3. 文件互传","4. 权限需求","上述权限仅会在实现本服务所对应功能时开启。请您放心，在您未使用本服务功能时，本服务不会任意调用您的权限。","5. 我们如何共享、转移、公开披露您的个人信息","6. 跨境传输","7. 个人信息存储与保护","8. 个人信息管理","当您撤回同意或授权后，我们无法继续为您提供撤回同意或授权所对应的服务，也不再处理您相应的个人信息。","9. 免责声明","本《隐私政策》仅适用于华为信息收集、使用与共享的规则，并不适用于任何第三方提供的服务或第三方的信息收集、使用与共享规则。","10. 关于本政策","您对本服务的使用以及继续使用，表示您已同意本政策及其更新。若您不同意本政策，请勿使用本服务或在您的设备上停用本服务。您可以在设置页面内找到本政策的最新版本。","11. 联系我们","12. 其他","本协议未列明的具体隐私政策事宜（包括但不限于“未成年人数据的处理”、“如何、转让、公开披露您的个人信息”、“信息和数据的安全性及措施”、“个人信息管理”、“信息和数据完整性”等），请参照并以华为隐私政策为准，详见：","重要提示："]
//        for boldText in boldTexts {
//            if let range = fullText.range(of: boldText) {
//                let nsRange = NSRange(range, in: fullText)
//                attributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 14), range: nsRange)
//                attributedString.addAttribute(.foregroundColor, value: UIColor.black, range: nsRange)
//            }
//        }
//
        let linkTexts = ["隐私问题", "联系华为","https://consumer.huawei.com/cn/support/service-privacy-notice/"]
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
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
//        let text = getPrivacyText().localized
//        
//        
        DispatchQueue.main.async {
            
            // 设置富文本内容
            self.setupPrivacyText()
            
            //添加点击手势
            self.privacyTapGesture = UITapGestureRecognizer(target: self, action: #selector(self.privacyLabelTapped(_:)))
            self.contentLabel.addGestureRecognizer(self.privacyTapGesture)
        }
        
//        var index = 0
//        Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { timer in
//            if index < text.count  {
//                let startIndex = text.startIndex
//                let endIndex = text.index(startIndex , offsetBy: index)
//              
//                let currentText = String((text[startIndex...endIndex]))
//                self.contentLabel.text = currentText
//                
//                index += 1
//            } else {
//                timer.invalidate()
//            }
//        }
    }
    private func getPrivacyTextFirst() -> String {
        return """
        尊敬的用户：
        华为终端有限公司（以下简称“华为”或“我们”），十分尊重您的隐私，并会尽全力保护您的个人信息。本《鸿蒙互传隐私政策》（“本政策”）适用于鸿蒙互传应用（与所有相关内容一并称作“本服务”）使用中用户信息的收集、处理、存储、传输、保护。请在使用本服务之前，阅读并确保您已理解和同意本政策，特别提示您查看加粗字体的重要内容。
        您需要承诺在您开始使用本产品时已经是成年人，如果您是未成年人，需要您的监护人同意您使用本产品并接受该隐私政策及相关的服务条款。如您使用本服务，即表示您已阅读、认可并接受本隐私政策中的条款，我们将基于提供服务的必要性和高效性，严格遵守本隐私政策的要求，使用和保护您的信息。
        1. 用户内容的传输
        (1) 您确认，本服务用于将设备上联系人、图片、音乐、视频及其他本服务已支持互传的内容（合称“用户内容”）传输至另一台受许可的设备中。
        (2) 当您首次传输某一类型的用户内容时（例如，当您首次传输您设备上的照片），我们将会征得您对于获取该内容的预先授权。
        (3) 部分用户内容会以图像、摘要或者其他有形的形式展示在本服务的界面上。具体展示情况将会根据您设备上存储的用户内容随机生成和更新。
        (4) 用户内容仅能被传输至被授权在单次传输中接收用户内容的特定设备。对于任何用户内容，我们仅提供帮助从一台设备向另一台设备进行传输的服务，而不会向您收集，亦不会通过任何形式获取、处理或使用。


        2. 我们收集的信息
        (a) 您的设备信息：当您在某一设备上使用本服务时，我们会从该设备上收集特定的信息，包括设备标识、设备型号、设备名称、系统版本、网络信息（本地IP地址、网关IP地址），用于识别版本、快速判断错误情况、排查问题、并为您提供功能兼容性判断，以便及时优化产品并提供版本更新提示。
        (b) 您的日志信息：在您使用本服务的过程中，我们将收集本服务的日志信息（包括使用时长、传输数据量、数据类型、操作情况、连接状态等行为日志信息）。向您收集的日志信息将仅被用于提供基本服务、分析服务使用过程中出现和可能出现的问题和错误，且不会与您的个人身份进行关联。
        """
    }
    
    private func getPrivacyText() -> String {
            return """
            尊敬的用户：
            华为终端有限公司（以下简称“华为”或“我们”），十分尊重您的隐私，并会尽全力保护您的个人信息。本《鸿蒙互传隐私政策》（“本政策”）适用于鸿蒙互传应用（与所有相关内容一并称作“本服务”）使用中用户信息的收集、处理、存储、传输、保护。请在使用本服务之前，阅读并确保您已理解和同意本政策，特别提示您查看加粗字体的重要内容。
            您需要承诺在您开始使用本产品时已经是成年人，如果您是未成年人，需要您的监护人同意您使用本产品并接受该隐私政策及相关的服务条款。如您使用本服务，即表示您已阅读、认可并接受本隐私政策中的条款，我们将基于提供服务的必要性和高效性，严格遵守本隐私政策的要求，使用和保护您的信息。
            
            1. 用户内容的传输
            (1) 您确认，本服务用于将设备上联系人、图片、音乐、视频及其他本服务已支持互传的内容（合称“用户内容”）传输至另一台受许可的设备中。
            (2) 当您首次传输某一类型的用户内容时（例如，当您首次传输您设备上的照片），我们将会征得您对于获取该内容的预先授权。
            (3) 部分用户内容会以图像、摘要或者其他有形的形式展示在本服务的界面上。具体展示情况将会根据您设备上存储的用户内容随机生成和更新。
            (4) 用户内容仅能被传输至被授权在单次传输中接收用户内容的特定设备。对于任何用户内容，我们仅提供帮助从一台设备向另一台设备进行传输的服务，而不会向您收集，亦不会通过任何形式获取、处理或使用。

            2. 我们收集的信息
            (a) 您的设备信息：当您在某一设备上使用本服务时，我们会从该设备上收集特定的信息，包括设备标识、设备型号、设备名称、系统版本、网络信息（本地IP地址、网关IP地址），用于识别版本、快速判断错误情况、排查问题、并为您提供功能兼容性判断，以便及时优化产品并提供版本更新提示。
            (b) 您的日志信息：在您使用本服务的过程中，我们将收集本服务的日志信息（包括使用时长、传输数据量、数据类型、操作情况、连接状态等行为日志信息）。向您收集的日志信息将仅被用于提供基本服务、分析服务使用过程中出现和可能出现的问题和错误，且不会与您的个人身份进行关联。
            (c) 位置信息：设备进行连接时，需要根据您的位置信息进行连接、以及设备检索，以完成您所需的功能服务。位置信息仅本地缓存，不会被上传至服务器或用于其他非授权目的。
            (d) 用户传输数据：在您使用互传文件等对应功能时，需要缓存您所选择的图片、视频、文本、联系人等内容，以及您对所传输应用或服务模块的权限授权情况，以帮助您完成前述数据内容的传输。相关数据仅用于完成传输，我们不会进行内容识别、意图识别，更不会用于其他任何用途。
            
            3. 文件互传
            (1) 当您使用文件互传功能时，我们需要收集您的设备ID（UUID）、设备型号、蓝牙地址，用于与您的另一台设备进行区分和配对。
            (2) 您可以通过本功能建立与另一台设备的连接从而接收另一台设备上的联系人，文件，图片视频等支持传输的内容，为实现前述目的，我们需要读取您所选择的上述用户内容，前述内容将在您使用文件互传功能时，经您同意后由我们自动采集进行处理。
            
            4. 权限需求
            本服务的功能实现需要启用部分设备权限，具体权限及授权目的如下：
            (1) 通讯录权限：用于互传时读取通讯录。
            (2) 照片权限：用于互传时读取照片，视频等文件。
            (3) 存储权限：用于存储传输记录。
            (4) 无线数据权限：用于在相同局域网下连接设备，传输文件。
            (5) 定位：用于判断是否处于同一局域网。
            (6) 蓝牙权限：用于使用蓝牙搜索附近的设备。
            上述权限仅会在实现本服务所对应功能时开启。请您放心，在您未使用本服务功能时，本服务不会任意调用您的权限。

            5. 我们如何共享、转移、公开披露您的个人信息
            (1)共享：共享是指华为向其他个人信息处理者提供个人信息，且双方分别在个人信息处理活动中自主决定处理目的、处理方式。通常华为不会对外共享您的个人信息，但以下情况除外：
            1. 在获取同意情况下的共享：获得您的同意后，华为会向您指定的第三方共享您授权范围内的信息；
            2. 在法定情形下的共享：华为可能会根据法律法规规定、诉讼争议解决需要，或按行政、司法机关依法提出的要求，对外共享您的个人信息；
            3. 共享给华为的关联公司：您的信息可能会在华为的关联公司内共享。我们仅会出于特定、明确而合法的目的在华为的关联公司内共享您的信息，并且只会共享提供服务所必要的信息。例如，在注册华为账号时为了避免重复注册，我们需要对拟注册的帐号进行全球唯一性校验；
            4. 共享给业务合作伙伴：华为可能会向合作伙伴等第三方共享您的订单信息、账户信息、设备信息以及位置信息，以保障为您提供的服务顺利完成。但我们仅会出于合法、正当、必要、特定、明确的目的共享您的个人信息，并且只会共享提供服务所必要的个人信息。我们的合作伙伴包括：
            1) 第三方卖家和第三方开发者：某些产品或服务由第三方直接向您提供，华为须将交易相关信息共享给第三方来实现您向其购买商品或服务的需求。例如，您在应用市场内购买其他开发者的商品时，我们须与开发者共享必要的您的信息，交易才能完成。
            2) 商品或技术服务的供应商。华为可能会将您的个人信息共享给支持我们功能的第三方，包括为我们供货或提供基础设施技术服务、物流配送服务、支付服务、数据处理服务的第三方等。我们共享这些信息的目的是为实现产品及服务的功能，比如我们必须与物流服务提供商共享您的订单信息以安排送货；或者我们需要将您的订单号和订单金额与第三方支付机构共享以实现其确认您的支付指令并完成支付等。
            华为会对共享行为和个人信息接收方进行安全评估，并与接收方签署数据保护协议或严格的保密协议，要求他们按照本声明以及采取相关的保密和安全措施来处理个人信息
            (2) 转移：在涉及合并、分立、解散、收购或被宣告破产时，如涉及到个人信息转移，我们会提前向您告知接收方的名称和联系方式，要求接收方继续按照本声明处理您的个人信息。接收方变更原先的处理目的、处理方式的，应当重新取得您的同意。。
            (3) 披露：华为仅会在以下情况下，公开披露您的个人信息：
            1. 获得您的同意后；
            2. 基于法律或合理依据的公开披露：在法律、法律程序、诉讼或公共和政府主管部门有要求的情况下，华为可能会公开披露您的信息。

            6. 跨境传输
            华为是一家跨国公司，这意味着，华为收集的您的个人信息可能会在您使用产品或服务所在国家/地区、在华为或其关联公司、子公司或服务提供商、业务合作伙伴设有机构的其他国家/地区进行处理，或者受到来自这些国家/地区的访问。这些国家/地区的数据保护法可能不同。在此类情况下，华为会采取措施确保我们收集的数据依据本声明和适用法律的要求进行处理。
            我们在中华人民共和国境内运营中收集和处理的个人信息，将存储在中华人民共和国境内。如果特定产品/服务存在跨境转移个人信息的情形，我们会在履行了法律规定的义务后（如通过监管的安全评估）向境外的接收方提供个人信息。
            
            7. 个人信息存储与保护
            (1) 存储期限与超期处理：除非法律法规另有规定，我们将在实现本政策所述目的的最短必要期限内保留您的个人信息。当您的个人信息超出我们所保存的期限后，我们会对您的个人信息进行删除或匿名化处理。
            (2) 信息安全与保护措施：我们将采取包括但不限于安全检查、使用加密工具和软件、以及其他合理的安全措施和程序保护您的个人信息，竭尽全力保护您的信息安全。当我们停止运营本服务或您停止使用本服务时，我们将不再收集和使用您的任何信息，并对所存储的信息进行匿名化或删除处理。

            8. 个人信息管理
            (1) 您可以通过关闭设备相关功能或与我们取得联系等方式改变您授权我们继续收集您个人信息的范围或撤回您的授权。请您理解，部分业务功能需要一些基本的个人信息才能得以完成，当您撤回同意或授权后，我们无法继续为您提供撤回同意或授权所对应的服务，也不再处理您相应的个人信息。但您撤回同意或授权的决定，不会影响此前基于您的授权开展的个人信息处理活动。

            9. 免责声明
            虽然本隐私政策说明了华为在维护隐私资料方面所遵循的标准，华为将严格遵循此标准，采取一切合理可行的措施尽力保护您个人信息和数据的安全。但请您知悉并理解，华为无法控制所有因素或第三方如何收集、使用您的信息和数据，任何措施也无法完全做到无懈可击，我们无法向您保证您的数据与信息在任何情况下都不会被泄露。本《隐私政策》仅适用于华为信息收集、使用与共享的规则，并不适用于任何第三方提供的服务或第三方的信息收集、使用与共享规则。

            10. 关于本政策
            华为保留不时更新或修改本政策的权利，一旦隐私政策条款发生修改，华为将在相关页面进行更新展示；如条款的更改涉及到对您权益的实质性影响，则将以显著的方式提示您或重新获取您的授权。您对本服务的使用以及继续使用，表示您已同意本政策及其更新。若您不同意本政策，请勿使用本服务或在您的设备上停用本服务。您可以在设置页面内找到本政策的最新版本。

            11. 联系我们
            我们设立了个人信息保护专职部门（或个人信息保护专员）。如果您有任何疑问、意见或建议，请通过在线客服、访问隐私问题页面与我们联系，或者将其提交至我们的全球办事处。如需获取办事处的完整列表，请访问联系华为页面。
            一般情况下，我们将在三个工作日内初步回复，并在法律法规定的时间内解答您的疑问。如果您对我们的回复不满意，特别是我们的个人信息处理行为损害了您的合法权益，您还可以向当地的隐私保护监管部门进行投诉或举报。

            12. 其他
            本协议未列明的具体隐私政策事宜（包括但不限于“未成年人数据的处理”、“如何、转让、公开披露您的个人信息”、“信息和数据的安全性及措施”、“个人信息管理”、“信息和数据完整性”等），请参照并以华为隐私政策为准，详见：
            https://consumer.huawei.com/cn/support/service-privacy-notice/


            重要提示：鉴于当地法律和语言的差异，当地语言版本的《华为消费者业务隐私声明》可能与本版本有所不同。如果出现任何冲突，请以当地语言版本为准。
            """
        }
}

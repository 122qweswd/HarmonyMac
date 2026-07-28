//
//  Untitled.swift
//  MutualInfection
//
//  Created by ww on 2025/9/9.
//

import UIKit
import SnapKit

class MIUserAgreeVC: MIEffectViewVC {
    var isLeft : Bool = true
    private var userAgreeIconImageView: UIImageView!
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
        if !isLeft {
            self.closeButton.setImage(UIImage.btnClose, for:.normal)
            self.closeButton.snp.remakeConstraints{
                $0.trailing.equalTo(-16)
                $0.top.equalTo(14)
            }
        }
        
        // 创建隐私图标
        userAgreeIconImageView = UIImageView()
        userAgreeIconImageView.image = UIImage.privacy
        userAgreeIconImageView.contentMode = .scaleAspectFit
        self.view?.addSubview(userAgreeIconImageView)
        
        // 隐私图标约束
        userAgreeIconImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(closeButton.snp.bottom).offset(6)
            make.width.equalTo(64)
            make.height.equalTo(76)
        }
        
        // 创建标题
        titleLabel = UILabel()
        titleLabel.text = "鸿蒙互传用户服务协议".localized
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textColor = "#000000".color.withAlpha(0.9)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        self.view?.addSubview(titleLabel)
        
        // 标题约束
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(userAgreeIconImageView.snp.bottom).offset(40)
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
        userAgreeTapGesture = UITapGestureRecognizer(target: self, action: #selector(userAgreeLabelTapped(_:)))
        contentLabel.addGestureRecognizer(userAgreeTapGesture)
    }
    @objc private func userAgreeLabelTapped(_ gesture: UITapGestureRecognizer) {
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
        let linkTexts = ["隐私问题", "联系华为"]

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
            print("隐私问题")

        case "联系华为":
            openUrl(linkText:"https://consumer.huawei.com/cn/support/contact-us/")
            print("联系华为")
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
        let boldTexts = ["特别提示有关约定争议管辖、免责声明以及信息收集的条款","如您选择下载、安装软件并使用本服务，即视为您已接受本协议的全部条款，并与华为达成具有法律约束力的协议。","关于本服务","注：不同系统、不同机型上所适配的功能可能略有差异，具体支持或新增的功能以您实际所使用的软件版本为准。","如您通过本服务选择使用第三方服务，则请您自行查看三方服务提供方所出示的相关协议内容，您使用三方服务过程中所产生的纠纷，由您自行联系三方处理。","关于软件授权许可","关于知识产权声明","关于软件的安装与升级","软件的下载与更新过程中可能产生数据流量或资讯费用（相关费用由运营商收取），均由您自行承担。","使用承诺与保证","免责声明及责任限制","适用法律及管辖条款","协议更新","华为有权基于自身运营情况及市场环境等因素，随时对服务条款进行修改（修改包含变更、增加、减少相应的条款内容），一旦服务条款发生修改，华为将在相关页面进行更新展示。如果您不同意本条款的修改，可以停止对本服务的使用。如您继续使用华为提供的服务，则视为您已经接受本条款的全部修改。","如何联系我们","一般条款"]
        for boldText in boldTexts {
            if let range = fullText.range(of: boldText) {
                let nsRange = NSRange(range, in: fullText)
                attributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 14), range: nsRange)
                attributedString.addAttribute(.foregroundColor, value: UIColor.black, range: nsRange)
            }
        }
        
        let linkTexts = ["隐私问题", "联系华为"]
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
            尊敬的用户：
            鸿蒙互传服务（以下简称“本服务”）是由华为终端有限公司（以下简称“我们”或“华为”）运营的，本用户服务协议是您（用户）与华为终端有限公司及其许可方所达成的有效法律协议。
            通过本协议，您将了解华为向您提供本服务的方式、您在使用本服务时所应遵循的规则、华为提供本服务及其相关服务的声明等其他重要信息。请您仔细阅读本协议，特别提示有关约定争议管辖、免责声明以及信息收集的条款。您需年满18周岁，或达到您所在地区的法定成年年龄，方可访问并使用本服务。若您未满18周岁，则需您的父母或法定监护人同意后方可使用本服务。未成年人在阅读本协议时应由其法定监护人陪同。如您选择下载、安装软件并使用本服务，即视为您已接受本协议的全部条款，并与华为达成具有法律约束力的协议。
             
            1. 关于本服务
            本服务旨在为您提供设备文件传输功能，帮助您快速实现内容传输等需求。注：不同系统、不同机型上所适配的功能可能略有差异，具体支持或新增的功能以您实际所使用的软件版本为准。
            本服务的主要功能为：
            （1）个人信息设置：您可以自行设置使用本服务时的名称。
            （2）互传文件：您可以通过本服务建立与另一台受信任设备（如手机/电脑）的连接，向对方传送/或从对方处接收设备上的联系人、文件、图片视频及其他本服务已支持互传的内容（合称“用户内容”）。
            （3）如您通过本服务选择使用第三方服务，则请您自行查看三方服务提供方所出示的相关协议内容，您使用三方服务过程中所产生的纠纷，由您自行联系三方处理。
             
            2. 关于软件授权许可
            1）许可授予。华为根据下列条款，授予您非专属及不可转让的有限许可。允许您使用本软件及相关文档，但您没有再授权许可的权利。
            2）许可限制
            a）您可以在单一移动终端设备中以非商业用途下载、安装使用本软件，除非华为另外明确授权或相关法律明令禁止本协议中的限制，否则您不得：（i）允许其他个人使用本软件；（ii）对本软件或文档进行修改、翻译、反向工程、反向编译、反汇编，或根据本软件或文档创建衍生产品；（iii）复制本软件或文档（用于维修/更换的备份除外，但前提是备份不在任何计算机上安装或使用，且维修/更换后应立即删除/销毁。您对本软件所作的任何其他备份均视为违反本协议）；（iv）对本软件或文档进行出租、转让、再许可，或向他人转让对本软件或文档的权利；（v）去除本软件或文档上的任何所有权声明或标签；（vi）在本软件中添加其他软件或将其他软件与本操作系统、软件合并用。
            b）您同意只按符合所有相关法律的方式使用本软件和文档。
            c）您不得使用本服务从事任何违法活动，或未经授权而试图扫描本服务的弱点或干扰本服务的正常运行、恶意传播病毒等其他干扰正常网络信息服务的行为。
             
            3. 关于知识产权声明
            本软件和文档的所有权和知识产权属华为所有（包括所有相关供应商/许可方）。通过本软件所访问内容（包括本软件媒体演示文件中包含的内容）的所有权和知识产权仍归属相应内容所有者，可受相关版权或其他法律保护。本许可未授予您对于该类内容的任何权利。
             
            4. 关于软件的安装与升级
            您应在官方下载渠道选择下载安装本软件，请勿在非官方网站进行下载，以免遭受病毒或恶意软件的侵扰。同时，您应选择与终端装置型号或设备相符的软件版本，或自行进行版本升级，否则，因软件版本与装置型号不符而产生的软件使用问题、功能不支持问题、装置绑定问题等，由您自行承担。
            软件的下载与更新过程中可能产生数据流量或资讯费用（相关费用由运营商收取），均由您自行承担。
             
            5. 使用承诺与保证
            在符合本协议约定的前提下，您可以通过本服务设置您的名称，并进行文件资料的传输等。但您需承诺，您将以合法合规的方式使用本服务，同时，您需保证不会通过本服务（自定义设置、互传等方式），宣扬含有任何违反国家法律法规政策的信息，包括但不限于下列信息：
            （a）反对宪法所确定的基本原则的；
            （b）危害国家安全，泄露国家秘密，颠覆国家政权，破坏国家统一的；
            （c）损害国家荣誉和利益的；
            （d）煽动民族仇恨、民族歧视，破坏民族团结的；
            （e）破坏国家宗教政策，宣扬邪教和封建迷信的；
            （f）散布谣言，扰乱社会秩序，破坏社会稳定的；
            （g）散布淫秽、色情、赌博、暴力、凶杀、恐怖或者教唆犯罪的；
            （h）侮辱或者诽谤他人，侵害他人合法权益的；
            （i）侵害他人知识产权、商业秘密等合法权利的；
            （j）任何可能违反诚实信用、公序良俗、公共道德的行为或其他法律法规禁止的。
            因您违反本条约定而造成的任何后果，包括但不限于承担法律责任并赔偿受损主体的损失，均由您自行承担。
             
            6. 免责声明及责任限制
            本服务仅供您个人使用，不得提供给任何第三方使用。且本软件、文档及内容按现状提供，华为对以下方面不提供任何明示和暗示的陈述和保证，包括但不限于产品的适销性、特殊目的之适用性、以及：
            （1）本服务将满足您的特定需求;（2）本服务将不间断的，及时的，安全的或在没有缺陷的情况下提供;（3）您使用服务过程中获取的任何信息是准确或可靠的;或（4）作为服务的一部分的任何缺陷或错误都将得到更正。
            华为不会对用户的任何错误、非法或违反本协议约定而使用华为提供的任何服务、性能或功能的行为承担任何责任。您使用任何华为提供的性能、功能或服务的同时应当遵守所有生效的法律。
             
            7. 本协议的中止或终止
            本服务中止或终止包括以下情形：
            （a）您主动要求终止服务，并卸载软件；
            （b）您违反或华为基于判断有理由认为您违反或涉嫌违反法律法规要求，或违反本协议所约定的任何内容，包括许可限制、您的保证和承诺等；
            （c）根据法律法规或国家相关部门的要求，华为中止或终止服务；
            （d）发生不可抗力事件或出现无法预料的技术问题（包括但不限于黑客攻击、网络崩溃、病毒侵扰等影响互联网正常运行的情形）；
            （e）其他根据法律法规或基于华为自身无法抗拒事由、业务调整等应当中止或终止服务的情形。
            如发生上述中止或终止情形：
            （a）华为有权暂停或终止向您授予使用许可，或根据本协议采取其他限制措施；
            （b）任何本协议中明示或依其性质应当在协议终止后继续有效的条款，将在本协议终止后继续有效，直至约定的条件到期或依其性质终止为止。
             
            8. 适用法律及管辖条款
            除非您住所地的法律有相反的规定，本许可协议受中华人民共和国法律管辖，并依据中华人民共和国法律进行解释，且不适用其冲突法规范。您同意，东莞市第二人民法院有管辖权且在该等法院审判，且您同意放弃对该等司法管辖权或审判地的任何异议。如果基于任何原因，具有合法管辖权的法院裁定本许可证的任何条款或其任何部分不可被强制执行，则本许可协议剩余部分仍应保持全部的效力。
             
            9. 协议更新
            本协议自发布或更新之日起正式生效，华为与所有开通并使用本服务的用户均应受前述协议的约束。
            华为有权基于自身运营情况及市场环境等因素，随时对服务条款进行修改（修改包含变更、增加、减少相应的条款内容），一旦服务条款发生修改，华为将在相关页面进行更新展示。如果您不同意本条款的修改，可以停止对本服务的使用。如您继续使用华为提供的服务，则视为您已经接受本条款的全部修改。
             
            10. 如何联系我们
            我们设立了个人信息保护专职部门（或个人信息保护专员）。如果您有任何疑问、意见或建议，请通过在线客服、访问隐私问题页面与我们联系，或者将其提交至我们的全球办事处。如需获取办事处的完整列表，请访问联系华为页面。
            一般情况下，我们将在三个工作日内初步回复，并在法律法规定的时间内解答您的疑问。如果您对我们的回复不满意，特别是我们的个人信息处理行为损害了您的合法权益，您还可以向当地的隐私保护监管部门进行投诉或举报。 
            11. 一般条款
            （1）本协议的标题仅为阅读的便利性而设置，不影响正文中条款的含义解释。
            （2）本协议中的任何条款无论因何种原因被认定为完全无效、部分无效或不具有执行力，本协议的其余条款仍应有效并且有约束力。
            （3）本协议中的任何内容均不得视为在您与华为之间建立了任何商业合作或代理关系。
            （4）在法律法规允许的范围内，华为有权对本协议的条款作出解释。
            """
        }


}

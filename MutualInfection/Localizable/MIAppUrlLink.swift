//
//  MIAppUrlLink.swift
//  MutualInfection
//
//  Created by apple on 2026/1/6.
//

class MIAppUrlLink: NSObject {

    /// 鸿蒙星河互联用户协议
    static func getUserAgreementLink() -> String {
        var link = ""
        switch AppLanguage.current {
        case .simplifiedChinese:
            link = "https://hecu0ijg.html2web.com"
        case .traditionalChineseTaiwan:
            link = "https://kles2ts9.html2web.com"
        case .traditionalChineseHongkong:
            link = "https://4eo9cj5x.html2web.com"
        case .malay:
            link = "https://tlb3yo16.html2web.com"
        default:
            link = "https://goenrhvr.html2web.com"
        }
        return link
    }
    
    /// 鸿蒙星河互联隐私政策
    static func getPrivacyPolicyLink() -> String {
        var link = ""
        switch AppLanguage.current {
        case .simplifiedChinese:
            link = "https://5kbpubrc.html2web.com"
        case .traditionalChineseTaiwan:
            link = "https://nlu2pf5n.html2web.com"
        case .traditionalChineseHongkong:
            link = "https://ejqn4olx.html2web.com"
        case .malay:
            link = "https://ma3lq4fw.html2web.com"
        default:
            link = "https://ma3lq4fw.html2web.com"
        }
        return link
    }
    
    /// 关于鸿蒙星河互联与隐私的声明
    static func getStatementHarmonyOSInterconnectPrivacyLink() -> String {
        var link = ""
        switch AppLanguage.current {
        case .simplifiedChinese:
            link = "https://hj3vyrsi.html2web.com"
        case .traditionalChineseTaiwan:
            link = "https://hpgxxp6h.html2web.com"
        case .traditionalChineseHongkong:
            link = "https://gdpmoeje.html2web.com"
        case .malay:
            link = "https://usf471gt.html2web.com"
        default:
            link = "https://t5tzm0o7.html2web.com"
        }
        return link
    }
    
    /// 个人信息收集清单
    static func getUserInfoCollectLink() -> String {
        var link = ""
        switch AppLanguage.current {
        case .simplifiedChinese:
            link = "https://t6k99cki.html2web.com"
        case .traditionalChineseTaiwan:
            link = "https://rlzjfkb7.html2web.com"
        case .traditionalChineseHongkong:
            link = "https://vatopkvd.html2web.com"
        case .malay:
            link = "https://6samsrfh.html2web.com"
        default:
            link = "https://6samsrfh.html2web.com"
        }
        return link
    }
    
    /// 个人信息共享清单
    static func getPersonalInformationSharingListLink() -> String {
        var link = ""
        switch AppLanguage.current {
        case .simplifiedChinese:
            link = "https://o3s0uolj.html2web.com"
        case .traditionalChineseTaiwan:
            link = "https://pkp8ja7g.html2web.com"
        case .traditionalChineseHongkong:
            link = "https://11vt04d6.html2web.com"
        case .malay:
            link = "https://a32eqdmd.html2web.com"
        default:
            link = "https://5eqs2iqy.html2web.com"
        }
        return link
    }
    
    ///
    static func getLink_2() -> String {
        var link = ""
        switch AppLanguage.current {
        case .simplifiedChinese:
            link = ""
        default:
            link = ""
        }
        return link
    }
}



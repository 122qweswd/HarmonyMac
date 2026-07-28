//
//  MILeftAboutModel.swift
//  MutualInfectionMac
//
//  Created by delegate on 2025/9/30.
//

import Cocoa

struct MILeftAboutModel {
    var title: String = ""
    var isSelected: Bool = false
    var agreement: String = ""
    
    var agreementURL: String {
        if title == "个人信息收集清单".localized{
            return MIAppUrlLink.getUserInfoCollectLink()
        }else if title == "个人信息共享清单".localized{
            return MIAppUrlLink.getPersonalInformationSharingListLink()
        }else if title == "鸿蒙星河互联隐私政策".localized{
            return MIAppUrlLink.getPrivacyPolicyLink()
        }else if title == "鸿蒙星河互联用户服务协议".localized{
            return MIAppUrlLink.getUserAgreementLink()
        }
        return ""
    }
}

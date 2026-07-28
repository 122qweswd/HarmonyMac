//
//  MISharedListViewController.swift
//  MutualInfectionApp
//
//  Created by apple on 2025/9/9.
//

import UIKit

class MISharedListViewController: MIEffectViewVC {
    
    private lazy var spreadsheetView: SpreadSheetView = {
        let viewModel: [[String]] = [
            ["第三方名称", "处理项目的方式", "涉及个人信息种类","第三方官网链接和隐私声明连接"],
            ["华为分享", "文件互传", "设备信息，文件信息，联系人信息","第三方官网链接:https://consumer.huawei.com/cn/support/huaweishareonehop/\n隐私申明链接:https://consumer.huawei.com/cn/support/service-privacy-notice/"]
        ]
        
        let view = SpreadSheetView(viewModel: viewModel)
        //view.translatesAutoresizingMaskIntoConstraints = false
        
        return view
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        self.titleLabel.text = "个人信息共享清单".localized
        
        let desLB = UILabel()
        desLB.text = "为了向您提供部分服务，我们需要将您的个人信息提供给第三方。为了保障您的数据安全和隐私，我们与合作伙伴签订了数据安全保护协议，明确了合作伙伴对您的数据的保护责任、义务和要求。详情请查阅以下第三方共享信息清单。".localized
        desLB.textColor = UIColor(hexString: "#000000").withAlphaComponent(0.6)
        desLB.font = SFCompact(weight: .regular,size: 14)
        //UIFont.systemFont(ofSize: 14, weight: .regular)
        desLB.numberOfLines = 0
        
        
        backView?.addSubview(desLB)
        
        desLB.snp.makeConstraints {
            $0.leading.equalTo(30)
            $0.trailing.equalTo(-30)
            $0.top.equalTo(titleLabel.snp.bottom).offset(28)
        }
    
        backView?.addSubview(spreadsheetView)
      
        spreadsheetView.snp.makeConstraints {
            $0.leading.equalTo(16)
            $0.trailing.equalTo(-16)
            $0.bottom.equalTo(-MISafeAreaBottom)
            $0.top.equalTo(desLB.snp.bottom).offset(16)
        }
    
    }


}

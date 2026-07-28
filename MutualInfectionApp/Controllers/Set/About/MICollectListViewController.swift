//
//  MICollectListViewController.swift
//  MutualInfection
//
//  Created by ww on 2025/9/9.
//

import UIKit

class MICollectListViewController: MIEffectViewVC {
    
    private lazy var spreadsheetView: SpreadSheetView = {
        let viewModel: [[String]] = [
            ["业务场景", "收集目的", "个人信息类型","收集的方式","个人信息字段"],
            ["设备发现及连接", "为了让您的设备之间可以实现互联，我们可能会收集您的设备唯一标识符、设备类型、设备型号、设备名称、蓝牙地址、Wi-Fi 地址、Wi-Fi SSID 以及 IP 地址来发现您身边可供配对连接的设备，建立设备间的通信链接，以为您实现设备间内容的流转和功能的协同", "设备信息","系统收集","设备唯一标识符、设备类型、设备型号、设备名称、蓝牙地址、Wi-Fi 地址、Wi-Fi SSID 以及 IP 地址"],
            ["文件互传", "为您提供“文件互传”，通过该功能您可以实现文件的跨设备传输流转，，为此我们会收集您的设备标识符（设备ID）、设备名称、设备类型、文件信息（文件名称以及文件内容）、文件中包含的联系人信息（包括姓名、生日、个人电话号码、电子邮件地址、地址、职位以及工作单位）、Wi-Fi 名称等内容", "设备信息，文件信息，联系人信息","系统收集","设备标识符（设备ID）、设备名称、设备类型、文件信息（文件名称以及文件内容）、文件中包含的联系人信息（包括姓名、生日、个人电话号码、电子邮件地址、地址、职位以及工作单位）、Wi-Fi 名称"]
        ]
        
        let view = SpreadSheetView(viewModel: viewModel)
        //view.translatesAutoresizingMaskIntoConstraints = false
        
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.titleLabel.text = "收集个人信息清单".localized
        
        backView?.addSubview(spreadsheetView)
      
        spreadsheetView.snp.makeConstraints {
            $0.leading.equalTo(16)
            $0.trailing.equalTo(-16)
            $0.bottom.equalTo(-MISafeAreaBottom)
            $0.top.equalTo(self.titleLabel.snp.bottom).offset(16)
        }
    }
}

//
//  MISystemPermissionsViewController.swift
//  MutualInfection
//
//  Created by apple on 2025/9/2.
//

import UIKit
import IBAnimatable

class MISystemPermissionsViewController: MIBaseViewController {
    
    var backView: AnimatableView?
    
    var closeAction:ClickBlockVoid?
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.estimatedRowHeight = phoneToPad(50)
        tableView.separatorStyle = .none
        tableView.register(MIPermissionsCell.self, forCellReuseIdentifier: "MIPermissionsCell")
       
        return tableView
    }()
    
    var data = [[["title":"访问位置".localized,"desTitle":"用于判断是否处于同一局域网".localized],["title":"访问照片".localized,"desTitle":"用于互传时读取照片、视频等文件".localized],["title":"访问通讯录".localized,"desTitle":"用于互传时读通讯录".localized],
        ["title":"无线局域网".localized,"desTitle":"用于在相同局域网下连接设备，传输文件".localized],
        ["title":"蓝牙".localized,"desTitle":"用于使用蓝牙搜索附近的设备".localized],
        ["title":"实时活动权限".localized,"desTitle":"用于后台时通过灵动岛显示传输进度".localized],
    ]]
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIDevice.current.userInterfaceIdiom == .pad ? .white : .clear
        self.navigationController?.navigationBar.isHidden = true
        self.title = "系统权限管理".localized
        
        // 创建主容器视图
        backView = AnimatableView()
        backView?.backgroundColor = "#F9F9F9".color
        backView?.cornerRadius = 32
        self.view.addSubview(backView ?? UIView())
        backView?.snp.makeConstraints {
            $0.horizontalEdges.bottom.equalToSuperview()
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                $0.top.equalTo(0)
            } else {
                $0.top.equalTo(MISafeAreaTop)
            }
        }
        
        
        initViews()
        
       
    }
    
    func initViews(){
        self.view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            if UIDevice.current.userInterfaceIdiom == .pad {
                make.top.equalTo(phoneToPad(44 + 10))
                make.width.equalTo(648)
                make.centerX.equalToSuperview()
            }else{
                make.top.equalTo(MISafeAreaTop + 44)
                make.leading.equalTo(16)
                make.trailing.equalTo(-16)
            }
            make.bottom.equalToSuperview()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if UIDevice.current.userInterfaceIdiom == .pad {
            self.navigationView?.backButton?.setBackgroundImage(nil, for: .normal)
          
        } else {
            self.navigationView?.backButton?.isHidden = true
            if self.navigationView?.rightBarButtons()?.isEmpty ?? true {
                self.navigationView?.addRightBarButtonItemWithImage(UIImage.btnClose , UIImage.btnClose, target: self, action: #selector(naviRightItemClickAction(_:)))
            }
        }
        self.navigationView?.lineView.backgroundColor = .clear
    }
    @objc func naviRightItemClickAction(_ sender: UIButton) {
        self.closeAction?()
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            self.navigationController?.popViewController(animated: true)
        } else {
            self.dismiss(animated: true)
        }
    }
}

extension MISystemPermissionsViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return  data.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    
        return  data[section].count
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "MIPermissionsCell", for: indexPath) as? MIPermissionsCell else { return UITableViewCell() }
        let arr =  data[indexPath.section]
        cell.titleLabel.text = arr[indexPath.row]["title"]
        cell.titleLabel.font = pingFangSC(weight: .medium,size: 16)
        cell.descLabel.text = arr[indexPath.row]["desTitle"]
        cell.descLabel.font = pingFangSC(weight: .regular,size: 12)
        
        cell.lineView.isHidden = true ? indexPath.row == 0 : indexPath.row != 0
        cell.cornerType =  indexPath.row == 0 ? .top :(indexPath.row == arr.count - 1 ? .bottom : .center)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        return 60
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if indexPath.section == 0 {
            if indexPath.row == 0 {
                openLocationSettings()
            }
            else if indexPath.row == 1 {
                openPhotosSettings()
            }
            else if indexPath.row == 2 {
                openContactsSettings()
            }
            else if indexPath.row == 3 {
                openWiFiSettings()
            }
            else if indexPath.row == 4 {
                openBluetoothSettings()
            }
            else if indexPath.row == 5 {
                openLiveActivitySettings()
            }
        }
        
    }

    // 跳转到蓝牙设置
    func openBluetoothSettings() {
        openAppSettings();
    }
    // 跳转到位置设置
    func openLocationSettings() {
        openAppSettings();
    }

    // 无线局域网权限
    func openWiFiSettings() {
        openAppSettings();
    }
    // 跳转到通讯录设置
    func openContactsSettings() {
        openAppSettings();
    }
    // 跳转到相册设置
    func openPhotosSettings() {
        openAppSettings();
    }
    // 跳转到实时活动设置
    func openLiveActivitySettings() {
        openAppSettings();
    }

    func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString + "App-Prefs:root=APP") {
            UIApplication.shared.open(url)
        }
    }
}

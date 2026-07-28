//
//  AboutViewController.swift
//  MutualInfectionApp
//
//  Created by ww on 2025/9/11.
//

import UIKit
import IBAnimatable

class AboutViewController: MIBaseViewController {

    var isCheckingVersion = false
    
    // MARK: - UI Components
    var backView: AnimatableView?
    
    var closeAction:ClickBlockVoid?
    
    let scView = UIScrollView()
    // 内容容器
    var contentContainer = UIView()
    var appIcon = UIImageView()
    // 设备当前名称
    var appNameLB = UILabel()
    // 当前设备版本号
    var appVersionLB = UILabel()
    var checkView = AnimatableView()
    var checkVersionButton = UIButton()
    var arrowImageView = UIImageView()
    
    var userInfoView = AnimatableView()
    var userInfoCollectButton = UIButton()
    var collectarrowImageView = UIImageView()
    var userInfoShareButton = UIButton()
    var sharearrowImageView = UIImageView()
    
    var privacyView = AnimatableView()
    var sharePrivacyButton = UIButton()
    var sharePrivacyarrowImageView = UIImageView()
    var userPrivacyButton = UIButton()
    var userPrivacyarrowImageView = UIImageView()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = UIDevice.current.userInterfaceIdiom == .pad ? .white : .clear
        self.navigationController?.navigationBar.isHidden = true
        
        self.title = "关于".localized
        
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
        
        self.backView?.addSubview(scView)
        scView.snp.makeConstraints {
            $0.horizontalEdges.equalToSuperview()
            $0.top.equalTo(phoneToPad(44 + 30))
            $0.bottom.equalToSuperview()

        }
        let newView = UIView()
        scView.addSubview(newView)
        // 设置初始约束
        newView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.bottom.equalToSuperview()
            make.width.equalTo(self.view)
        }
        
        contentContainer.backgroundColor = .white
        contentContainer.layer.cornerRadius = phoneToPad(32)
        // 添加容器
        newView.addSubview(contentContainer)
        
        contentContainer.snp.makeConstraints { make in
            if UIDevice.current.userInterfaceIdiom == .pad {
                make.width.equalTo(648)
                make.centerX.equalToSuperview()
            }else{
                make.leading.equalTo(16)
                make.trailing.equalTo(-16)
            }
            make.top.equalToSuperview()
            make.height.equalTo(182)
        }
        
        appIcon.image = UIImage.darkIcon
        appIcon.contentMode = .scaleAspectFit
        contentContainer.addSubview(appIcon)
        
        appIcon.snp.makeConstraints{ make in
            make.centerX.equalToSuperview()
            make.top.equalTo(30)
            make.width.height.equalTo(56)
        }
        // 添加圆角
        appIcon.layer.cornerRadius = 12  // 根据你的设计调整圆角大小
        appIcon.layer.masksToBounds = true
        // 添加设备名称
        appNameLB.text = appName
        appNameLB.textColor = "#000000".color.withAlphaComponent(0.9)
        appNameLB.font = pingFangSC(weight: .medium, size: 24)
        contentContainer.addSubview(appNameLB)
        
        appNameLB.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(appIcon.snp.bottom).offset(24)
        }
        
        // 添加设备名称
        appVersionLB.text = "版本号".localized + ":" + appVersion
        //"版本号".localized + ": XXX"
        appVersionLB.textColor = "#000000".color.withAlphaComponent(0.6)
        appVersionLB.font = pingFangSC(weight: .medium, size: 12)
        contentContainer.addSubview(appVersionLB)
        
        appVersionLB.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(appNameLB.snp.bottom).offset(4)
        }
        
        checkView.backgroundColor = .white
        checkView.cornerRadius = 22
        
        newView.addSubview(checkView)
        
        checkView.snp.makeConstraints {
            if UIDevice.current.userInterfaceIdiom == .pad {
                $0.width.equalTo(648)
                $0.centerX.equalToSuperview()
            }else{
                $0.leading.equalTo(16)
                $0.trailing.equalTo(-16)
            }
            $0.top.equalTo(contentContainer.snp.bottom).offset(32)
            $0.height.equalTo(60)
            
        }
        
        
        checkVersionButton.setTitle("检查更新".localized, for: .normal)
        checkVersionButton.setTitleColor("#000000".color.withAlphaComponent(0.9), for: .normal)
        checkVersionButton.titleLabel?.font = pingFangSC(weight: .medium, size: 16)
        checkVersionButton.contentHorizontalAlignment = .left
        checkVersionButton.addTarget(self, action: #selector(checkVersionButtonTapped), for: .touchUpInside)
        checkView.addSubview(checkVersionButton)
        
        checkVersionButton.snp.makeConstraints {
            $0.leading.equalTo(phoneToPad(14))
            $0.trailing.equalTo(phoneToPad(-40))  // 为箭头留出空间
            $0.height.equalTo(60)
            $0.centerY.equalToSuperview()

        }
        // 添加向右箭头图标
        arrowImageView.image = UIImage(systemName: "chevron.right")
        arrowImageView.tintColor = UIColor.black.withAlphaComponent(0.3)
        arrowImageView.contentMode = .scaleAspectFit
        checkView.addSubview(arrowImageView)
        
        arrowImageView.snp.makeConstraints {
            $0.trailing.equalTo(phoneToPad(-16))
            $0.centerY.equalToSuperview()
            $0.width.equalTo(16)
            $0.height.equalTo(20)
        }
        
        // 为箭头添加点击手势
        let arrowTapGesture = UITapGestureRecognizer(target: self, action: #selector(checkVersionButtonTapped))
        arrowImageView.addGestureRecognizer(arrowTapGesture)
        arrowImageView.isUserInteractionEnabled = true
        
        // 用户信息这块
        userInfoView.backgroundColor = .white
        userInfoView.cornerRadius = 22
        
        newView.addSubview(userInfoView)
        
        userInfoView.snp.makeConstraints {
            if UIDevice.current.userInterfaceIdiom == .pad {
                $0.width.equalTo(648)
                $0.centerX.equalToSuperview()
            }else{
                $0.leading.equalTo(16)
                $0.trailing.equalTo(-16)
            }
            $0.top.equalTo(checkView.snp.bottom).offset(32)
            $0.height.equalTo(120)
        }
        
        userInfoCollectButton.setTitle("个人信息收集清单".localized, for: .normal)
        userInfoCollectButton.setTitleColor("#000000".color.withAlphaComponent(0.9), for: .normal)
        userInfoCollectButton.titleLabel?.font = pingFangSC(weight: .medium, size: 16)
        userInfoCollectButton.contentHorizontalAlignment = .left
        userInfoCollectButton.addTarget(self, action: #selector(userInfoCollectButtonTapped), for: .touchUpInside)
        userInfoView.addSubview(userInfoCollectButton)
        
        userInfoCollectButton.snp.makeConstraints {
            $0.leading.equalTo(phoneToPad(15))
            $0.trailing.equalTo(phoneToPad(-40))  // 为箭头留出空间
            $0.top.equalTo(0)
            $0.height.equalTo(60)
        }
        // 添加向右箭头图标
        collectarrowImageView.image = UIImage(systemName: "chevron.right")
        collectarrowImageView.tintColor = UIColor.black.withAlphaComponent(0.3)
        collectarrowImageView.contentMode = .scaleAspectFit
        userInfoView.addSubview(collectarrowImageView)
        
        collectarrowImageView.snp.makeConstraints {
            $0.trailing.equalTo(phoneToPad(-16))
            $0.top.equalTo(20)
            $0.width.equalTo(16)
            $0.height.equalTo(20)
        }
//        
        // 为箭头添加点击手势
        let collectarrowTapGesture = UITapGestureRecognizer(target: self, action: #selector(userInfoCollectButtonTapped))
        collectarrowImageView.addGestureRecognizer(collectarrowTapGesture)
        collectarrowImageView.isUserInteractionEnabled = true
        
        
        let  line  = UIView()
        line.backgroundColor = .black.withAlphaComponent(0.2)
        userInfoView.addSubview(line)
        line.snp.makeConstraints { make in
            make.leading.equalTo(phoneToPad(8))
            make.trailing.equalTo(phoneToPad(-8))
            make.height.equalTo(0.5)
            make.top.equalTo(userInfoCollectButton.snp.bottom)
        }
       
        userInfoShareButton.setTitle("个人信息共享清单".localized, for: .normal)
        userInfoShareButton.setTitleColor("#000000".color.withAlphaComponent(0.9), for: .normal)
        userInfoShareButton.titleLabel?.font = pingFangSC(weight: .medium, size: 16)
        userInfoShareButton.contentHorizontalAlignment = .left
        userInfoShareButton.addTarget(self, action: #selector(userInfoShareButtonTapped), for: .touchUpInside)
        userInfoView.addSubview(userInfoShareButton)
        
        userInfoShareButton.snp.makeConstraints {
            $0.leading.equalTo(phoneToPad(14))
            $0.trailing.equalTo(phoneToPad(-40))  // 为箭头留出空间
            $0.top.equalTo(line.snp.bottom)
            $0.bottom.equalToSuperview()
        }
        // 添加向右箭头图标
        sharearrowImageView.image = UIImage(systemName: "chevron.right")
        sharearrowImageView.tintColor = UIColor.black.withAlphaComponent(0.3)
        sharearrowImageView.contentMode = .scaleAspectFit
        userInfoView.addSubview(sharearrowImageView)
        
        sharearrowImageView.snp.makeConstraints {
            $0.trailing.equalTo(phoneToPad(-16))
            $0.width.equalTo(16)
            $0.top.equalTo(line.snp.bottom).offset(20)
            $0.bottom.equalToSuperview().offset(-20)
            $0.height.equalTo(20)
        }
        
        // 为箭头添加点击手势
        let sharearrowTapGesture = UITapGestureRecognizer(target: self, action: #selector(userInfoShareButtonTapped))
        sharearrowImageView.addGestureRecognizer(sharearrowTapGesture)
        sharearrowImageView.isUserInteractionEnabled = true
        
        
        // 鸿蒙星河互联隐私这块
        privacyView.backgroundColor = .white
        privacyView.cornerRadius = 22
        
        newView.addSubview(privacyView)
        
        privacyView.snp.makeConstraints {
            if UIDevice.current.userInterfaceIdiom == .pad {
                $0.width.equalTo(648)
                $0.centerX.equalToSuperview()
            }else{
                $0.leading.equalTo(16)
                $0.trailing.equalTo(-16)
            }
            $0.top.equalTo(userInfoView.snp.bottom).offset(32)
            $0.height.equalTo(120)
            $0.bottom.equalToSuperview().offset(-30)
        }
        
        sharePrivacyButton.setTitle("鸿蒙星河互联隐私政策".localized, for: .normal)
        sharePrivacyButton.setTitleColor("#000000".color.withAlphaComponent(0.9), for: .normal)
        sharePrivacyButton.titleLabel?.font = pingFangSC(weight: .medium, size: 16)
        sharePrivacyButton.contentHorizontalAlignment = .left
        sharePrivacyButton.addTarget(self, action: #selector(sharePrivacyButtonTapped), for: .touchUpInside)
        privacyView.addSubview(sharePrivacyButton)
        
        sharePrivacyButton.snp.makeConstraints {
            $0.leading.equalTo(phoneToPad(15))
            $0.trailing.equalTo(phoneToPad(-40))  // 为箭头留出空间
            $0.top.equalTo(0)
            $0.height.equalTo(60)
        }
        // 添加向右箭头图标
        sharePrivacyarrowImageView.image = UIImage(systemName: "chevron.right")
        sharePrivacyarrowImageView.tintColor = UIColor.black.withAlphaComponent(0.3)
        sharePrivacyarrowImageView.contentMode = .scaleAspectFit
        privacyView.addSubview(sharePrivacyarrowImageView)
        
        sharePrivacyarrowImageView.snp.makeConstraints {
            $0.trailing.equalTo(phoneToPad(-16))
            $0.top.equalTo(20)
            $0.width.equalTo(16)
            $0.height.equalTo(20)
        }
//
        // 为箭头添加点击手势
        let sharePrivacyTapGesture = UITapGestureRecognizer(target: self, action: #selector(sharePrivacyButtonTapped))
        sharePrivacyarrowImageView.addGestureRecognizer(sharePrivacyTapGesture)
        sharePrivacyarrowImageView.isUserInteractionEnabled = true
        
        
        let  lineNext  = UIView()
        lineNext.backgroundColor = .black.withAlphaComponent(0.2)
        privacyView.addSubview(lineNext)
        lineNext.snp.makeConstraints { make in
            make.leading.equalTo(phoneToPad(8))
            make.trailing.equalTo(phoneToPad(-8))
            make.height.equalTo(0.5)
            make.top.equalTo(sharePrivacyButton.snp.bottom)
        }
       
        userPrivacyButton.setTitle("鸿蒙星河互联用户服务协议".localized, for: .normal)
        userPrivacyButton.setTitleColor("#000000".color.withAlphaComponent(0.9), for: .normal)
        userPrivacyButton.titleLabel?.font = pingFangSC(weight: .medium, size: 16)
        userPrivacyButton.contentHorizontalAlignment = .left
        userPrivacyButton.addTarget(self, action: #selector(userPrivacyButtonTapped), for: .touchUpInside)
        privacyView.addSubview(userPrivacyButton)
        
        userPrivacyButton.snp.makeConstraints {
            $0.leading.equalTo(phoneToPad(14))
            $0.trailing.equalTo(phoneToPad(-40))  // 为箭头留出空间
            $0.top.equalTo(lineNext.snp.bottom)
            $0.bottom.equalToSuperview()
        }
        // 添加向右箭头图标
        userPrivacyarrowImageView.image = UIImage(systemName: "chevron.right")
        userPrivacyarrowImageView.tintColor = UIColor.black.withAlphaComponent(0.3)
        userPrivacyarrowImageView.contentMode = .scaleAspectFit
        privacyView.addSubview(userPrivacyarrowImageView)
        
        userPrivacyarrowImageView.snp.makeConstraints {
            $0.trailing.equalTo(phoneToPad(-16))
            $0.width.equalTo(16)
            $0.top.equalTo(lineNext.snp.bottom).offset(20)
            $0.bottom.equalToSuperview().offset(-20)
            $0.height.equalTo(20)
        }
        
        // 为箭头添加点击手势
        let userPrivacyarrowTapGesture = UITapGestureRecognizer(target: self, action: #selector(userPrivacyButtonTapped))
        userPrivacyarrowImageView.addGestureRecognizer(userPrivacyarrowTapGesture)
        userPrivacyarrowImageView.isUserInteractionEnabled = true
//        
        
        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            self.navigationView?.backButton?.setBackgroundImage(nil, for: .normal)
          
        } else {
            self.navigationView?.backButton?.isHidden = true
            // 判断右侧按钮是否已存在，避免重复添加
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
    
    // MARK: - Button Actions
    @objc func checkVersionButtonTapped(_ sender: UIButton) {
        
        guard !isCheckingVersion else {
            print("正在检查中，请稍候...")
            return
        }
                
        isCheckingVersion = true
        
        print("检查更新按钮被点击")
        fetchAppStoreVersion(bundleId: bundleId) { version in
            
            
            if let version = version {
                DispatchQueue.main.async {
                    self.isCheckingVersion = false
                    self.compareVersion(appStoreVersion: version)
                }
            }else{
                DispatchQueue.main.async {
                    self.isCheckingVersion = false
                    AlertManager.showAlert(title: "已是最新版本".localized,cancelTitle:nil,confirmTitle: "确定".localized,confirmAction:{
                        
                    })
                }
                
            }
            
        }
    }
    func getCurrentLanguage() -> String {
        return Locale.preferredLanguages.first ?? "en"
    }
    @objc func userInfoCollectButtonTapped() {
        let language = getCurrentLanguage()
        let webVC = WebVC()
        if language.hasPrefix("en") {
            webVC.urlStr = "https://e2tmhnv0.html2web.com".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        }else{
            webVC.urlStr = "https://t6k99cki.html2web.com".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        }
        self.navigationController?.pushViewController(webVC, animated: true)
        
//        print("个人信息收集清单按钮被点击")
//        UIApplication.shared.open(URL(string: "https://t6k99cki.html2web.com")!, options: [:], completionHandler: nil)
    }
    @objc func userInfoShareButtonTapped() {
        let language = getCurrentLanguage()
        let webVC = WebVC()
        if language.hasPrefix("en") {
            webVC.urlStr = "https://5eqs2iqy.html2web.com".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        }else{
            webVC.urlStr = "https://o3s0uolj.html2web.com".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        }
        self.navigationController?.pushViewController(webVC, animated: true)
        
//        print("个人信息共享清单按钮被点击")
//        UIApplication.shared.open(URL(string: "https://o3s0uolj.html2web.com")!, options: [:], completionHandler: nil)
    }
    @objc func sharePrivacyButtonTapped() {
        print("鸿蒙星河互联隐私政策按钮被点击")
        let language = getCurrentLanguage()
        let webVC = WebVC()
        if language.hasPrefix("en") {
            webVC.urlStr = "https://328jdrqw.html2web.com".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        }else{
            webVC.urlStr = "https://5kbpubrc.html2web.com".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        }
        self.navigationController?.pushViewController(webVC, animated: true)
       // UIApplication.shared.open(URL(string: "https://5kbpubrc.html2web.com")!, options: [:], completionHandler: nil)
    }
    @objc func userPrivacyButtonTapped() {
        print("鸿蒙星河互联用户服务协议按钮被点击")
        let language = getCurrentLanguage()
        let webVC = WebVC()
        if language.hasPrefix("en") {
            webVC.urlStr = "https://goenrhvr.html2web.com".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        }else{
            webVC.urlStr = "https://hecu0ijg.html2web.com".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        }
        self.navigationController?.pushViewController(webVC, animated: true)
        //UIApplication.shared.open(URL(string: "https://hecu0ijg.html2web.com")!, options: [:], completionHandler: nil)
    }
    func fetchAppStoreVersion(bundleId: String, completion: @escaping (String?) -> Void) {
        
        let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleId)")!

        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let results = json["results"] as? [[String: Any]],
                   let appStoreVersion = results.first?["version"] as? String {
                    completion(appStoreVersion)
                } else {
                    completion(nil)
                }
            } catch {
                completion(nil)
            }
        }
        task.resume()
    }
    
    func compareVersion(appStoreVersion: String) {
      
        
        if appStoreVersion == appVersion {
            
            AlertManager.showAlert(title:"已是最新版本".localized,cancelTitle:nil,confirmTitle: "确定".localized,confirmAction:{
          
            })
            

        }else{
            
            
            AlertManager.showAlert(title: "当前最新版本是:\(appStoreVersion)".localized,cancelTitle: "取消".localized,cancelAction: {
                
            },confirmTitle: "更新".localized,confirmAction:{
                
                let urlString = "itms-apps://itunes.apple.com/app/id\(appID)"
                if let url = URL(string: urlString) {
                    //根据iOS系统版本，分别处理
                    if #available(iOS 10, *) {
                        UIApplication.shared.open(url, options: [:],
                                                  completionHandler: {
                            (success) in
                        })
                    } else {
                        UIApplication.shared.openURL(url)
                    }
                }
            })
            
     
        }
    }
    
      
}

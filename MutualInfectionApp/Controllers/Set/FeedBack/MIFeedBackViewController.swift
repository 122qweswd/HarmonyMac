//
//  MIFeedBackViewController.swift
//  MutualInfection
//
//  Created by apple on 2025/9/2.
//

import UIKit
import IBAnimatable
import SnapKit
import ImageIO
// TODO: 先这么写了，收起展开和箭头效果，还有图片，等具体数据有了再弄...
class MIFeedBackViewController: MIBaseViewController {
    var backView: AnimatableView?
    
    var closeAction:ClickBlockVoid?
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.estimatedRowHeight = 50
        tableView.separatorStyle = .none
        tableView.register(MIFeedBackTableViewCell.self, forCellReuseIdentifier: "MIFeedBackTableViewCell")
        tableView.register(MIFeedBackTableViewSectionHeaderView.self, forHeaderFooterViewReuseIdentifier: "MIFeedBackTableViewSectionHeaderView")
        tableView.register(MIFeedBackTableViewSectionFooterView.self, forHeaderFooterViewReuseIdentifier: "MIFeedBackTableViewSectionFooterView")
        return tableView
    }()

    lazy var feedbackButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle("意见反馈".localized, for: .normal)
        button.titleLabel?.font = SFCompact(weight: .medium,size: 17)
        button.setBackgroundImage(UIImage.bkgBtn, for: .normal)
        button.setTitleColor(.black, for: .normal)
        
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.3
        button.layer.shadowOffset = CGSizeMake(0, 0)
        
        button.addClickClosure { sender in
            AppleLoginHandlerValue = true
            AppleLoginHandler.shared.requestAppleIDLogin { userID, error in
                if let userID = userID {
                    UserDefaults.standard.set(userID, forKey: "appleUserIDKey")
                }else if let error = error{
                    UserDefaults.standard.set("", forKey: "appleUserIDKey")
                }
                
            }
            let feedBack = MIFeedBackView()
            if UIDevice.current.userInterfaceIdiom == .pad {
                self.navigationController?.pushViewController(feedBack, animated: true)
                return
            }
            let naviController = MIBaseNavigationViewController(rootViewController: feedBack)
            
            naviController.modalPresentationStyle = .overCurrentContext
            naviController.view.backgroundColor = .clear;
            self.present(naviController, animated: true)
        }
        return button
    }()
    
    private var datas=[
        ["文件互传设备条件".localized,
         ["对端设备：HarmonyOS 6及以上的华为手机、平板和电脑。".localized, "本端设备：iOS 13及以上、iPad OS 13及以上、Mac OS 10.15及以上。".localized]
        ],
        ["文件传输方式".localized,
         [["方式一：同WLAN传输".localized,
           ["当两台设备连接同一可用WLAN时，确认接收后将直接进行文件互传。".localized],
          ],
          ["方式二：热点传输".localized,
           ["当两台设备未连接同一可用WLAN时，确认接收后需连接对方设备热点以进行免流量文件互传。".localized,
            "注：大文件互传时，建议使用热点传输(速度较快)以快速完成传输任务。".localized]
          ]]
        ],
        ["发送与接收文件".localized,
         [["接收文件".localized,
           ["1.本设备打开“鸿蒙星河互联”app。".localized,
            "2.对方选择要发送的文件，在华为分享界面选择本设备。".localized,
            "3.与对方处于同一WLAN或连接对方热点，开始传输。".localized
              ]
           ],
          ["发送文件".localized,
           ["方式一：鸿蒙星河互联app内发送".localized,
            "﻿1.对方开启华为分享。首次使用需设为“所有人可见”。".localized,
            "2.本设备选择要发送的文件，点击对方设备头像。或先点击对方设备头像，再选择要发送的文件。".localized,
            "3.与对方处于同一WLAN或连接对方热点，开始传输。".localized,
              "@image",
            "方式二：通过“共享”选择鸿蒙星河互联app发送".localized,
            "1.对方开启华为分享。".localized,
            "2.本设备选择要发送的文件，点击“共享按钮”选择鸿蒙星河互联app。".localized,
            "3.与对方处于同一WLAN或连接对方热点，开始传输。".localized,
              "@image"
             ]
           ]]
        ]
     ]
    
    var isShows : [Bool] = [true,true,true]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIDevice.current.userInterfaceIdiom == .pad ? .white : .clear
        self.navigationController?.navigationBar.isHidden = true
        self.title = "帮助与反馈".localized
        
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

    func initViews() {

        self.view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            if UIDevice.current.userInterfaceIdiom == .pad {
                make.top.equalTo(phoneToPad(56 + 10))
                make.width.equalTo(648)
                make.centerX.equalToSuperview()
            }else{
                make.top.equalTo(MISafeAreaTop + 75)
                make.leading.equalTo(16)
                make.trailing.equalTo(-16)
            }
            make.bottom.equalToSuperview()
        }
        
        self.view.addSubview(feedbackButton)
        feedbackButton.snp.makeConstraints { make in
            if UIDevice.current.userInterfaceIdiom == .pad {
                make.trailing.equalTo(tableView.snp.trailing).offset(phoneToPad(-16))
            }else{
                make.trailing.equalTo(phoneToPad(-31))
            }
            make.size.equalTo(CGSize(width: phoneToPad(92), height: phoneToPad(44)))
            make.bottom.equalTo(-MISafeAreaBottom - phoneToPad(5))
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

extension MIFeedBackViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int { datas.count }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if isShows[section] {
            return 1
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "MIFeedBackTableViewCell", for: indexPath) as? MIFeedBackTableViewCell else { return UITableViewCell() }
        
        cell.ishsow = isShows[indexPath.section]
        cell.updateCell(datas[indexPath.section])
        
        cell.isLast = true
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "MIFeedBackTableViewSectionHeaderView") as? MIFeedBackTableViewSectionHeaderView
        
        if !isShows[section] {
            headerView?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            headerView?.arrowButton.isSelected = true
        } else {
            headerView?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            headerView?.arrowButton.isSelected = false
        }
   
        headerView?.showClick = {[weak self] in
            //刷新指定的cell
            guard let weakSelf = self else { return  }
            weakSelf.isShows[section] =  !weakSelf.isShows[section]
            
            
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.001, animations: {
                    tableView.beginUpdates()
                    
                    tableView.reloadSections([section], with: .none)
                    tableView.endUpdates()
                })
            }
            
        }
        
        if let title = datas[section][0] as? String {
            headerView?.titleLabel.text = title
        }
        return headerView
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 60 }
        
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { phoneToPad(20) }
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }
}

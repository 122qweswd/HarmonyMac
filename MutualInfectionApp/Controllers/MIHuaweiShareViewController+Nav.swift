//
//  MIHuaweiShareViewController+NaviRightItem.swift
//  MutualInfectionApp
//
//  Created by apple on 2025/9/30.
//

import Foundation
import UIKit

// MARK: -  事件
extension MIHuaweiShareViewController {
    
    func setupNaviView() {
        self.navigationView?.contentView.addSubview(userInfoView)
        userInfoView.snp.makeConstraints { make in
            if UIDevice.current.userInterfaceIdiom == .pad {
                make.top.equalToSuperview().offset(12)
                make.height.equalTo(60)
            }
            else{
                make.top.equalToSuperview().offset(10)
                make.height.equalTo(44)
            }
            
            make.leading.equalToSuperview()
        }
        
        naviRightItem = self.navigationView?.addRightBarButtonItemWithImage(UIImage.setBtn , UIImage.setBtnPress,
                                                                            target: self,action: #selector(naviRightItemClickAction(_:)))
    }
    
    @objc func naviRightItemClickAction(_ sender: UIButton) {
        print("。。。被点击")
        
        sender.isSelected = !sender.isSelected
        
        let window =  (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first
        
        let menu = MenuCardView.defaultMenu(isAllowChange: true)
        menu.closeAction = {[weak self] in
            guard let _ = self else { return  }
            sender.isSelected = !sender.isSelected
            
        }
        window?.addSubview(menu)
        menu.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        menu.stackView.snp.makeConstraints { make in
            if UIDevice.current.userInterfaceIdiom == .pad {
                make.width.equalTo(179)
            }else {
                make.width.equalTo(190)
            }
            make.height.equalTo(304)
            make.top.equalTo(sender.snp.bottom).offset(phoneToPad(8))
            make.trailing.equalTo(sender.snp.trailing)
        }
        
        
        menu.onSelectItem = {[weak self] item, index in
            guard let weakSelf = self else { return  }
            let deviceType = UIDevice.current.userInterfaceIdiom
            sender.isSelected = !sender.isSelected
            
            switch index {
                
            case 0:
                if deviceType == .pad {
                    let deviceName = MIPadDeviceNameViewController()
                    deviceName.modalPresentationStyle = .overCurrentContext
                    deviceName.deviceName = weakSelf.deviceName
                    deviceName.userAvatar = weakSelf.userAvatar
                    deviceName.chageNameClick = { [weak self] chageName in
                        guard let weakSelf = self else { return  }
                        weakSelf.deviceName = chageName
                        
                        UserDefaults.standard.set(chageName, forKey: deviceNameKey)
                        weakSelf.manger?.log(1, "修改名称之后：\(chageName)")
                        weakSelf.manger?.changeBtName(NSString(string: chageName) as String)
                        weakSelf.userInfoView.userNameLabel.text = chageName
                        
                    }
                    deviceName.chageAvatarClick = { [weak self] chageAvatar in
                        guard let weakSelf = self else { return  }
                        guard let imageData = chageAvatar.jpegData(compressionQuality: 0.5) else {
                            return
                        }
                        weakSelf.userAvatar = chageAvatar
                        
                        UserDefaults.standard.set(imageData, forKey: userAvatarKey)
                        weakSelf.userInfoView.iconImageView.image = chageAvatar
                        
                    }
                    let naviController = MIBaseNavigationViewController(rootViewController: deviceName)
                    
                    naviController.modalPresentationStyle = .overCurrentContext
                    weakSelf.present(naviController, animated: true)
                }else {
                    let deviceName = MIDeviceNameViewController()
                    deviceName.modalPresentationStyle = .overCurrentContext
                    deviceName.deviceName = weakSelf.deviceName
                    deviceName.userAvatar = weakSelf.userAvatar
                    deviceName.chageNameClick = { [weak self] chageName in
                        guard let weakSelf = self else { return  }
                        weakSelf.deviceName = chageName
                        
                        UserDefaults.standard.set(chageName, forKey: deviceNameKey)
                        weakSelf.manger?.log(1, "修改名称之后：\(chageName)")
                        weakSelf.manger?.changeBtName(NSString(string: chageName) as String)
                        weakSelf.userInfoView.userNameLabel.text = chageName
                        
                    }
                    deviceName.chageAvatarClick = { [weak self] chageAvatar in
                        guard let weakSelf = self else { return  }
                        guard let imageData = chageAvatar.jpegData(compressionQuality: 0.5) else {
                            return
                        }
                        weakSelf.userAvatar = chageAvatar
                        
                        UserDefaults.standard.set(imageData, forKey: userAvatarKey)
                        weakSelf.userInfoView.iconImageView.image = chageAvatar
                        
                    }
                    let naviController = MIBaseNavigationViewController(rootViewController: deviceName)
                    
                    naviController.modalPresentationStyle = .overCurrentContext
                    weakSelf.present(naviController, animated: true)
                }
                
                break
            case 1:
                    routeTransferHistoryListController()
                break
            case 2:
                
                let feedBack = MIFeedBackViewController()
                if UIDevice.current.userInterfaceIdiom == .pad {
                    weakSelf.navigationController?.pushViewController(feedBack, animated: true)
                    return
               }
                let naviController = MIBaseNavigationViewController(rootViewController: feedBack)
                
                naviController.modalPresentationStyle = .overCurrentContext
                naviController.view.backgroundColor = .clear;
                weakSelf.present(naviController, animated: true)
                break
            case 3:
                let systemPermissions = MISystemPermissionsViewController()
                if UIDevice.current.userInterfaceIdiom == .pad {
                    weakSelf.navigationController?.pushViewController(systemPermissions, animated: true)
                    return
                }
                let naviController = MIBaseNavigationViewController(rootViewController: systemPermissions)
                
                naviController.modalPresentationStyle = .overCurrentContext
                naviController.view.backgroundColor = .clear;
                weakSelf.present(naviController, animated: true)
                
                break
            case 4:
                let about = AboutViewController()
                if UIDevice.current.userInterfaceIdiom == .pad {
                    weakSelf.navigationController?.pushViewController(about, animated: true)
                    return
               }
                    
                let naviController = MIBaseNavigationViewController(rootViewController: about)
                naviController.modalPresentationStyle = .overCurrentContext
                naviController.view.backgroundColor = .clear;
                weakSelf.present(naviController, animated: true)
                break
            default:
                
                weakSelf.navigationController?.pushViewController(AboutViewController(), animated: true)
            }
        }
    }
}

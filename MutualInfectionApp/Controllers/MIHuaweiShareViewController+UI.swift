//
//  MIHuaweiShareViewController+UI.swift
//  MutualInfectionApp
//
//  Created by apple on 2025/10/10.
//

import Foundation
import UIKit

extension MIHuaweiShareViewController {
    
    func initBkg(){
        // 设置全局背景图
        let backgroundImage = UIImageView(frame: UIScreen.main.bounds)
        backgroundImage.image = UIImage.bkGround // 替换为你的图片名
        backgroundImage.contentMode = .scaleAspectFill
        view.insertSubview(backgroundImage, at: 0)
        backgroundImage.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        
    }
    
    func initViews() {
        sendButton.titleLabel?.font = SFCompact(weight: .regular,size: 16)
        sendButton.setTitle("我要发送".localized, for: .normal)
        sendButton.setTitleColor("#336FFF".color, for: .normal)
        sendButton.addClickClosure { sender in
            
            //self.startActivity()
            self.showActionAlertSheet(sender: sender)
        }
        sendButton.setBackgroundImage(UIImage.bgButton, for: .normal)
        
        sendButton.layer.cornerRadius = 42.0 / 2.0
        sendButton.snp.makeConstraints { make in
            if UIDevice.current.userInterfaceIdiom == .pad {
                make.size.equalTo(CGSizeMake(334, 46))
            }else {
                make.size.equalTo(CGSizeMake(186, 46))
            }
        }
        
        contentView.addSubview(bottonView)
        bottonView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.trailing.equalToSuperview().offset(-12)
            make.bottom.equalToSuperview().offset(-MISafeAreaBottom)
        }
        
        contentView.addSubview(nearbyUsersView)
        nearbyUsersView.isHidden = true
        nearbyUsersView.snp.makeConstraints {
            $0.leading.trailing.top.equalToSuperview()
            $0.bottom.equalTo(bottonView.snp.top).offset(-10)
        }
  
        self.nearbyUsersView.selectDeviceTapped = {[weak self] userInfo in
            
            if let shareFileInfoModel = ShareExtensionInfoManager.shared.shareInfoModel  {
                return
            }
            guard let weakSelf = self else { return  }
            
            weakSelf.selectDevice = userInfo
            
            weakSelf.showActionAlertSheet(sender: weakSelf.sendButton)
        }
    }
}

extension MIHuaweiShareViewController{
    func getOwnDeviceInfo() {
        //持久化。获取设备名称
        if UserDefaults.standard.string(forKey: deviceNameKey) == nil || UserDefaults.standard.string(forKey: deviceNameKey) == "" {
            deviceName = UIDevice.current.deviceName
            self.userInfoView.userNameLabel.text = deviceName
        } else {
            deviceName = UserDefaults.standard.string(forKey: deviceNameKey)
            self.userInfoView.userNameLabel.text = deviceName
        }
        self.manger?.log(1, "getDeviceName:deviceName:\(UIDevice.current.deviceName)\(deviceName ?? "deviceName is nil")")
        
        if UserDefaults.standard.data(forKey: userAvatarKey) == nil {
            userAvatar = UIImage.iconDevice
        }else{
            userAvatar = UIImage(data: UserDefaults.standard.data(forKey: userAvatarKey)!)
        }
        
        self.userInfoView.iconImageView.image = userAvatar
    }
}

extension MIHuaweiShareViewController {
    func showActionAlertSheet(sender:UIView = UIView()) {
        let alert = UIAlertController(title: "选择要发送的文件".localized,message: nil, preferredStyle: .actionSheet)
        // 强制使用亮色模式
        if #available(iOS 13.0, *) {
            
            DispatchQueue.main.async {
                alert.overrideUserInterfaceStyle = .light
            }
        }
        if UIDevice.current.userInterfaceIdiom == .pad {
            if let popoverController = alert.popoverPresentationController {
                popoverController.sourceView = sender
                popoverController.sourceRect = sender.bounds
            }
        }
        
        let cancelAction = UIAlertAction(title: "取消".localized, style: .cancel) { [weak self] _ in
            
            guard let weakSelf = self else { return }
            weakSelf.selectDevice = nil
        }
        
        alert.addAction(cancelAction)
  
        let assetsLibraryAction = UIAlertAction(title: "照片或视频".localized, style: .default) { [weak self] _ in
           
            guard let weakSelf = self else{ return}
            MIImagePickerManager.shared.openPhotoLibrary(autoDismiss: false) {  result, pickerController in
                let count = result?.photoAssets.count ?? 0
                if (count > 0) {
//                    weakSelf.picker = result
                    weakSelf.sendContentToDevice(fileType: 0,picker: result,fileArr: nil,contacts: nil)
                } else{
                    weakSelf.selectDevice = nil
                }
            }
        }
        
        let filesAction = UIAlertAction(title: MILocalized("文件".localized), style: .default) { [weak self] _ in
            
            guard let weakSelf = self else { return  }
            MIDocumentPickerManager.share.openDocumentPicker { result, documentVC in
                
//                weakSelf.nav = weakSelf.navigationController
                if let arr = result {
                    weakSelf.sendContentToDevice(fileType: 3,picker: nil,fileArr: arr,contacts: nil)
                    
                }else{
                    weakSelf.selectDevice = nil
                }

                //print("result - \(String(describing: result)) - documentVC - \(String(describing: documentVC))")
            }
        }
        //getContatList
        let contactsAction = UIAlertAction(title: MILocalized("通讯录".localized), style: .default) { [weak self] _ in
            guard let weakSelf = self else { return  }
            AddressBook().selectContactsAction(autoDismiss:  false) { contacts,contactController in
                weakSelf.sendContentToDevice(fileType: 8, picker: nil,fileArr: nil,contacts: contacts)
                
            } fail: {
                weakSelf.selectDevice = nil
            }
        }
        
        alert.addAction(assetsLibraryAction)
        
        alert.addAction(filesAction)
        
        alert.addAction(contactsAction)
        
        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: nil)
        }
    }
}

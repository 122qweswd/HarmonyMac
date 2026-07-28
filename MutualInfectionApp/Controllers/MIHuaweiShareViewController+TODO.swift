//
//  HuaweiShareViewControllerTODO.swift
//  MutualInfectionApp
//
//  Created by apple on 2025/9/25.
//

import Foundation
import UIKit


extension MIHuaweiShareViewController{
    func setToData() {
        let userInfos = [
            MIDevice(name: "P60", uuid:"001", hwId: "001",devicetype: 1,deviceStatus: .completed),
            MIDevice(name: "Mate 60 Pro", uuid:  "002", hwId: "002",devicetype: 5),
            MIDevice(name: "Mate 60 Pro", uuid:  "003", hwId: "003",devicetype: 1),
            MIDevice(name: "Mate 60 Pro", uuid:"004", hwId: "004",devicetype: 6),
            MIDevice(name: "Mate 60 Pro", uuid:"005", hwId: "005",devicetype: 1),
            MIDevice(name: "Mate 60 Pro", uuid:"006", hwId: "006",devicetype: 6)
        ]
        self.deviceInfos = userInfos
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0){
         
            self.showScanView(isShow: false)
            // 调用更新方法
            self.nearbyUsersView.updateUserInfos(userInfos)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0){
//            self.showScanView(isShow: true)
//            self.wavePostFileView?.currentDeviceStatus = .didReject
//            self.wavePostFileView?.onDeviceStatusChanged?(.didReject)
        }
    }
    
    func recvAction() {
        desLabel.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(desLabelTapped))
        desLabel.addGestureRecognizer(tapGesture)
    }
    
    @objc func desLabelTapped() {
        recvAlert = AlertManager.showAlert(title: "name", autoDismiss: false, cancelTitle: "拒绝".localized,cancelAction: {  [weak self] in
            self?.manger?.rejectRequest("udid")
        },confirmTitle: "接收".localized) { [weak self] in
            guard let self = self else { return }
            
            if self.receivePage == nil {
                self.receivePage = MIReceiveFilesView()
                self.receivePage?.manger = self.manger
                self.receivePage?.backAction = {[weak self] in
                    guard let _ = self else { return  }
//                    self?.receivePage?.view.removeFromSuperview()
                    self?.receivePage = nil
                }
                
                self.receivePage?.dissClick = {[weak self] in
                    self?.manger?.setDeviceDelegate(self)
                    self?.manger?.setConnectDelegate(self)
                    self?.manger?.setTransDelegate(self)
                }
    
//                self.navigationController?.pushViewController(self.receivePage!, animated: true)
                recvAlert?.dismiss(animated: true) {
                    MIGetTopNavViewController()?.navigationController?.pushViewController(self.receivePage!, animated: true)
                }
            } else {
                self.receivePage?.normalPage()
            }
        }
    }
}

//TODO:测试异常场景代码
//        DispatchQueue.main.asyncAfter(deadline: .now() + 5){
//            self.manger?.sendSDKEvent(13)
//            self.didConnect("001", status: "connected")
    
    
    //0 SHARE_SUCCESS,
    //1 SHARE_REJECT_SELF, //自己拒绝
    //2 SHARE_REJECT_PEER, 对方拒绝
    //3 SHARE_CANCEL_SELF, //自己取消
    //4 SHARE_CANCEL_PEER, //对方取消
    //5 SHARE_CANCEL_PEER_BUSY,对方忙
    //6 SHARE_ERROR_TIMEOUT,//请求超时
    //7 SHARE_ERROR_TRANS_SELF,//已失败 --自己
    //8 SHARE_ERROR_TRANS_PEER,//已失败 -- 对方
    //9 SHARE_ERROR_BYTE_CAHNEL,//已失败
    //10 SHARE_ERROR_WIFI,//已失败
    //11 SHARE_ERROR_BLE,//已失败
    //12 SHARE_ERROR_BLE_DEVICE,//已失败
    //13 SHARE_COMPLETED_FORCE,//完成
    //14 SHARE_RESULT_BUTT,//已失败
//        }

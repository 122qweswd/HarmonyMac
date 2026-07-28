//
//  MIHuaweiShareViewController+ModalDelegate.swift
//  MutualInfectionApp
//
//  Created by apple on 2025/10/29.
//

import Foundation
import UIKit


extension MIHuaweiShareViewController_Modal{
    //Mark: 发现新的设备
    func didDeviceFound(_ udid: String, device: [AnyHashable : Any]) {
        
        ShareAPI.shared().log(1, "发现新的设备:didDeviceFound:udid:\(udid)")
        DispatchQueue.main.async {
            self.showScanView(isShow: false)
            let name =  (device["name"] as? String) ?? "";
            let udid = (device["udid"] as? String) ?? "";
            let hwId: String = (device["hwid"] as? String) ?? "";
            let isShowIcon = device["icon"] as? Bool ?? false
            let deviceType =  (device["deviceType"] as? Int) ?? 1;
            ShareAPI.shared().log(1, "首页收到设备\(name):\(udid)")
            
            guard let _ = self.deviceInfos.first(where: { $0.uuid == udid}) else {
                self.deviceInfos.append( MIDevice(name: name, uuid:udid,hwId:hwId,devicetype:deviceType,isShowIcon: isShowIcon))
                self.nearbyUsersView.updateUserInfos(self.deviceInfos)
                return
            }
        }
    }
    
    //Mark: 设备信息更新
    func didDeviceUpdate(_ udid: String, device: [AnyHashable : Any]) {
        let name =  (device["name"] as? String) ?? "";
        let udid = (device["udid"] as? String) ?? "";
        let isShowIcon = device["icon"] as? Bool ?? false
        let hwId: String = (device["hwid"] as? String) ?? "";
        
        if let deviceInfo = self.deviceInfos.first(where: { $0.uuid == udid }){
            if deviceInfo.name.precomposedStringWithCanonicalMapping == name.precomposedStringWithCanonicalMapping &&  deviceInfo.isShowIcon == isShowIcon && deviceInfo.hwId == hwId{
                return
            }
            
            ShareAPI.shared().log(1, "设备信息更新:didDeviceUpdate:udid:\(udid)---old Name:\(deviceInfo.name)===new Name:\(name) ----hewid:\(deviceInfo.hwId)===new hewid:\(hwId)")
            
            if let deviceInfo =  self.deviceInfos.first(where: {$0.uuid == udid}) {
                deviceInfo.name = name
                deviceInfo.isShowIcon = isShowIcon
                deviceInfo.hwId = hwId
                self.nearbyUsersView.updateDeviceStatus(deviceInfo)
            }
        }
    }
    
    
    //Mark: 设备 掉线
    func didDeviceLost(_ udid: String) {
        ShareAPI.shared().log(1, "丢失设备:didDeviceLost:udid:\(udid)")
        DispatchQueue.main.async {
            
            //设备丢失：包含异常。如果是发送的设备 停止发送   其他设备正常移除
            if let lostDevice =  self.selectUsers.first(where: {$0.uuid == udid }),(lostDevice.deviceStatus == .sending || lostDevice.deviceStatus == .connecting || lostDevice.deviceStatus == .connected || lostDevice.deviceStatus == .needreceive){
//                let _ = AlertManager.showAlert(title: "对方掉线,发送失败".localized,cancelTitle: nil, confirmTitle: "知道了".localized) {
                    self.deviceInfos.removeAll {$0.uuid == udid}
                    self.nearbyUsersView.updateUserInfos(self.deviceInfos)
                    
                self.selectUsers.removeAll(where: {$0.uuid == udid})
                self.shareFilesSessionId = nil
                self.importingLabel.isHidden = true
                    //设备移除后。是否存在等待发送的设备。如果存在继续发送
                    if self.selectUsers.count > 0 {
                        //继续发送
                        self.sendSelectFile()
                        return
                    }
                    //不存在需要发送的设备 停止保活 停止灵动岛
                    isSendTask = false
                    if #available(iOS 16.2, *) {
                        ShareAPI.shared().log(1,"didCancel 对方取消 停止灵动岛")
                        LiveActivityManager.shared.updateActivity(delay: 0, alert: false, progressValue: 0,status: StatusLive.cancelReceive, stateInfo: "对方已取消接收".localized,statusInfo: "")
                        LiveActivityManager.shared.endActivity(dismissTimeInterval: 2)
                    }
//                }
            }else{
                let count = self.deviceInfos.count
                self.deviceInfos.removeAll {$0.uuid == udid}
                self.selectUsers.removeAll(where: {$0.uuid == udid})
                //如果设备有消失 刷新 没有不需要刷新 防止重复调用 刷新
                if count > self.deviceInfos.count {
                    self.nearbyUsersView.updateUserInfos(self.deviceInfos)
                    if self.deviceInfos.count  == 0{
                        self.showScanView(isShow: true)
                    }
                }
            }
            //TODO：接收的时候设备丢失。需要另行处理  停止接收逻辑。停止接收保活
        }
    }
    
    //Mark: 设备头像存储
    func didRecvAvatar(_ udid: String, hwid:String, avatar: String) {
        ShareAPI.shared().log(1, "设备头像存储:didRecvAvatar:udid:\(udid)_hwid:\(hwid)")
        if hwid == "" {
            return
        }
        var imageModel = DeviceHeaderImage()
        imageModel.hwId = hwid
        imageModel.headerImage =  avatar//UIImage.icon.pngData()?.base64EncodedString()
        MIDeviceHeaderWCDBManager.sharedManager().insertOrReplaceHeader(imageModel)
    }
    //Mark: 对方 取消发送/接收
    func didCancel(_ udid: String) {
        ShareAPI.shared().log(1, " 对方取消发送:didCancel:udid:\(udid)")
        
        if let userDeviceInfo = self.selectUsers.first(where: {$0.uuid == udid}){
            
            //防止完成时 显示取消 并调用下一个发送
            if userDeviceInfo.deviceStatus != .completed  {
                
                userDeviceInfo.deviceStatus = .cancelled
                userDeviceInfo.progress = 0
                self.nearbyUsersView.updateDeviceStatus(userDeviceInfo)
                self.selectUsers.removeAll { $0.uuid == udid}
                self.shareFilesSessionId = nil
                self.importingLabel.isHidden = true
                //设备移除后。是否存在等待发送的设备。如果存在继续发送
                if self.selectUsers.count > 0 {
                    //继续发送
                    self.sendSelectFile()
                    return
                }
                //不存在需要发送的设备 停止保活 停止灵动岛
                isSendTask = false
                if #available(iOS 16.2, *) {
                    ShareAPI.shared().log(1,"didCancel 对方取消 停止灵动岛")
                    LiveActivityManager.shared.updateActivity(delay: 0, alert: false, progressValue: 0,status: StatusLive.cancelReceive, stateInfo: "对方已取消接收".localized,statusInfo: "")
                    LiveActivityManager.shared.endActivity(dismissTimeInterval: 2)
                }
            }
        }
    }
               
                
    
    //Mark: 自己弹出加入热点。取消
    func didSelfCancel(_ udid: String) {
        
        if let deviceInfo = self.selectUsers.first(where: {$0.uuid == udid}){
            deviceInfo.deviceStatus = .cancelled
            deviceInfo.progress = 0
            self.nearbyUsersView.updateDeviceStatus(deviceInfo)
            isSendTask = false
            
            self.selectUsers.removeAll(where: {$0.uuid == udid})
            self.shareFilesSessionId = nil
            if self.selectUsers.count > 0 {
                self.sendSelectFile()
                
            }else{
                self.importingLabel.isHidden = true
                if #available(iOS 16.2, *) {
                    ShareAPI.shared().log(1,"MIHuaweiShareViewController didSelfCancel 自己取消热点 结束灵动岛")
                    LiveActivityManager.shared.endActivity(dismissTimeInterval: 0)
                }
            }
        }
    }
    //Mark: 设备连接状态返回。连接中 和已经连接  已连接 时可进行数据发送处理
    func didConnect(_ udid: String, status: String) {
        
        ShareAPI.shared().log(1, " 设备连接状态:didConnect:udid:\(udid)")
        
        if let userDeviceInfo = self.selectUsers.first(where: {$0.uuid == udid}){
            if status == "connecting" || status == "joinwifi"{
                userDeviceInfo.deviceStatus = .connecting
                userDeviceInfo.progress = 0
              
            } else if status == "connected" {
                userDeviceInfo.deviceStatus = .connected
                userDeviceInfo.progress = 0
            }else if status == "joinwififailed" {
                AlertManager.showAlert(message: ("请断开已连接的WIFI后重试").localized, autoDismiss: true, cancelTitle:"取消".localized,
                                       cancelAction: {
                    self.endSendAction()
                },confirmTitle:"去设置".localized,
                                       confirmAction: {
                    self.endSendAction()
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                })
            }
            self.nearbyUsersView.updateDeviceStatus(userDeviceInfo)
            if (status == "connected") {
                var files : [[AnyHashable:Any]] = []
                
                if let shareInfoList = ShareExtensionInfoManager.shared.shareInfoModel?.fileInfos {
                    for shareInfo in shareInfoList {
                        files.append(["fileSize": "\(shareInfo.fileSize)",
                                      "fileName": shareInfo.fileName,
                                      "fileUrl": shareInfo.filePath,
                                      "date_added":"-1",
                                      "date_taken":"-1",
                                      "detail_time":""])
                        
                       // ShareAPI.shared().log(1, "发送:\(shareInfo.fileName)")
                    }
                } else {
                    let sendType = self.dict["sendType"] as? String
                    let sendTypeInt = Int(sendType ?? "-1")
                   let fileType =  SendFileType(rawValue:sendTypeInt ?? -1 )
                    
                    if fileType == .photo_asset {
                      
                        for asset in picker?.photoAssets ?? [] {
                            files.append(["fileSize": "\(asset.fileSize)",
                                          "fileName": asset.fileName,
                                          "fileUrl": asset.filePath,
                                          //"fileType": "0",
                                          "date_added":asset.phAsset?.creationDate?.getPHAssetDateStr() ?? "",
                                          "date_taken":asset.phAsset?.modificationDate?.getPHAssetDateStr() ?? "",
                                          "detail_time":""])
                            //ShareAPI.shared().log(1, "发送:\(asset.fileName)")
                        }
                        for fileModel in fileArr {
                            files.append(["fileSize":"\(fileModel.sizeInBytes)",
                                          "fileName" :fileModel.name,
                                          "fileUrl":fileModel.url.path,
                                          "date_added":fileModel.modificationDate.getPHAssetDateStr(),
                                          "date_taken":fileModel.modificationDate.getPHAssetDateStr(),
                                          "detail_time":""] )
                            //ShareAPI.shared().log(1, "发送:\(fileModel.name)")
                            
                        }
                    } else if fileType == .file_manager_file {
                        for fileModel in fileArr {
                            files.append(["fileSize":"\(fileModel.sizeInBytes)",
                                          "fileName" :fileModel.name,
                                          "fileUrl":fileModel.url.path,
                                          "fileType":fileModel.type,
                                          "date_added":fileModel.modificationDate.getPHAssetDateStr(),
                                          "date_taken":fileModel.modificationDate.getPHAssetDateStr(),
                                          "detail_time":""] )
                            //ShareAPI.shared().log(1, "发送:\(fileModel.name)")
                            
                        }
                    } else {
                        files.append(["fileSize":"\(contacts?["fileSize"] ?? "")",
                                      "fileName" :contacts?["fileName"] ?? "",
                                      "fileUrl":contacts?["fileUrl"] ?? "",
                                      "date_added":"-1",
                                      "date_taken":"-1",
                                      //"fileType": "8",
                                      "detail_time":""])
                       // ShareAPI.shared().log(1, "发送:\(contacts?["fileName"] ?? "无文件名")")
                    }
                }
                
                if #available(iOS 16.2, *) {
                    ShareAPI.shared().log(1,"MIHuaweiShareViewController updateActivity didConnect 连接中...")
                    LiveActivityManager.shared.updateActivity(delay: 0, alert: false, progressValue: 0,status: StatusLive.connecting, stateInfo: "连接中...".localized,statusInfo: "")
                }
                isSendTask = true
                
                
                
                ShareAPI.shared().sendFiles(udid, files: files)
            }
        }
    }
    
    //Mark: 设备 连接丢失  接收界面需要单独处理  首页 根据传回的 udid  要做判断 是否显示状态
    func didDisconnect(_ udid: String, reason: String, errorCode: Int32) {

        var deviceStatus : DeviceStatus? = nil
        var newTitle = ""
        ShareAPI.shared().log(1, "didDisconnect:\(reason)")
        if reason == "peer_disconnected" || reason == "self_disconnected" {
            deviceStatus = .disconnected
            newTitle = ""
        } else if reason == "peer_busy" {
            deviceStatus = .peerBusy
            newTitle = "对方忙".localized
            isSendTask = false
       } else if reason == "trans_error" {
           deviceStatus = .error
           newTitle = "分享失败".localized
           isSendTask = false
           //showRecvErrorAlert(title: "接收失败")
           
       } else if reason == "timeout"{
           deviceStatus = .timeout
           isSendTask = false
           newTitle = "连接已超时，请重新点击对方设备后再连接".localized
           //showRecvErrorAlert(title: "连接已超时，请对端重新点击设备发起连接")
       }else if reason == "nospace" {
           deviceStatus = .nospace
           isSendTask = false
           newTitle = "内存不足,分享失败".localized
           //showRecvErrorAlert(title: "内存不足，接收失败")
       }else if reason == "hotspotOn"{

           isSendTask = false
           
           AlertManager.showAlert(title: (self.selectUsers.count > 0 ? "发送失败" : "接收失败").localized,message: "请关闭热点后重试".localized,autoDismiss: true,cancelTitle:"取消".localized,
            cancelAction: {
               self.endSendAction()
           },confirmTitle:"去设置".localized,
            confirmAction: {
               self.endSendAction()
               if let url = URL(string: UIApplication.openSettingsURLString) {
                   UIApplication.shared.open(url)
               }
           })
           if #available(iOS 16.2, *) {
               ShareAPI.shared().log(1,"didDisconnect 异常情况 停止灵动岛")
               LiveActivityManager.shared.endActivity(dismissTimeInterval: 2)
           }
           return

       }
 
        ShareAPI.shared().log(1,"didDisconnect:udid \(newTitle)")
        //弹窗后。后台无法操作
        //        let _ = AlertManager.showAlert(title: newTitle,cancelTitle: nil, confirmTitle: "知道了".localized) {
        ShareAPI.shared().log(1,"didDisconnect:udid 知道了\(newTitle)")
        if let selectDevice = self.selectUsers.first(where: {$0.uuid == udid}),let deviceStatus = deviceStatus {
            selectDevice.deviceStatus = deviceStatus
            selectDevice.progress = 0
            self.nearbyUsersView.updateDeviceStatus(selectDevice)
            self.selectUsers.removeAll {$0.uuid == selectDevice.uuid}
            //发送完成清空发送sessionId
            self.shareFilesSessionId = nil
            
            if self.selectUsers.count > 0 {
                self.sendSelectFile()
            }
            else{
                self.importingLabel.isHidden = true
                // TODO 停止activity
                if #available(iOS 16.2, *) {
                    ShareAPI.shared().log(1,"didDisconnect 异常情况 停止灵动岛")
                    LiveActivityManager.shared.endActivity(dismissTimeInterval: 2)
                }
            }
            
        }
        //        }
    }
    
    //Mark:  代理作用不清楚
    func didAccept(_ udid: String) {
        ShareAPI.shared().log(1, " 设备连接状态:didAccept:udid:\(udid)")
        if let userDeviceInfo = self.selectUsers.first(where: {$0.uuid == udid}){
            
            userDeviceInfo.deviceStatus = .connecting
            userDeviceInfo.progress = 0
            self.nearbyUsersView.updateDeviceStatus(userDeviceInfo)
            
            if #available(iOS 16.2, *) {
                ShareAPI.shared().log(1,"灵动岛 updateActivity didAccept 连接中...")
                LiveActivityManager.shared.updateActivity(delay: 0, alert: false, progressValue: 0,status: StatusLive.connecting, stateInfo: "连接中...".localized,statusInfo: "")
            }
        }
    }
    //Mark: 对方拒绝接收
    func didReject(_ udid: String) {
        print("========11")
        ShareAPI.shared().log(1, "didReject:udid:\(udid)")
        isSendTask = false
        
        if let selectDevice = selectUsers.first(where: { $0.uuid == udid}),selectDevice.uuid == udid {
            selectDevice.deviceStatus = .didReject
            selectDevice.progress = 0
            self.nearbyUsersView.updateDeviceStatus(selectDevice)
            self.selectUsers.removeAll { $0.uuid == selectDevice.uuid}
            //清空这一次请求sessionId
            self.shareFilesSessionId = nil
            
            if self.selectUsers.count > 0 {
                self.sendSelectFile()
            }else{
                self.importingLabel.isHidden = true
                if #available(iOS 16.2, *) {
                    ShareAPI.shared().log(1,"对方拒绝接收：停止灵动岛")
                    LiveActivityManager.shared.updateActivity(delay: 0, alert: false, progressValue: 0,status: StatusLive.cancelReceive, stateInfo: "对方已取消接收".localized,statusInfo: "")
                    LiveActivityManager.shared.endActivity(dismissTimeInterval: 2)
                }
            }
        }
    }
    
    //Mark: 发送中  进度 按照100.0 返回的数据  需要自行转化
    //    func didSendProgress(_ udid: String, percent: Double) {
    func didUpdateProgress(_ udid: String, percent: Double, stat: [AnyHashable : Any]) {
        //TODO 进度需要根据底层修改后。转化为 0 - 1的小数
        
        let percent = percent/100.0
        ShareAPI.shared().log(1, "发送中的进度: didUpdateProgress:udid:\(udid)--\(percent)")
        print("测试：进度\(percent)")
        
        //TODO 设备id 回传后  要增加过滤条件
        if let selectDevice = selectUsers.first(where: {$0.uuid == udid}){
            selectDevice.deviceStatus = .sending
            selectDevice.progress = percent
            self.nearbyUsersView.updateDeviceStatus(selectDevice)
            //TODO Activity刷新进度
            if #available(iOS 16.2, *) {
                ShareAPI.shared().log(1,"灵动岛 didUpdateProgress 发送中...")
                LiveActivityManager.shared.updateActivity(delay: 0, alert: false, progressValue: percent,status: StatusLive.send, stateInfo: percent < 1 ? "发送中...".localized: "已发送".localized,statusInfo: showFileInfo(stat: stat))
            }
        }
    }
    
    //Mark: 发送结束后。执行的操作
    func didSendEnd(_ udid: String, file: String, isFinished: Bool) {
        isSendTask = false
        ShareAPI.shared().log(1, "发送完成:didSendEnd:udid:\(udid)--\(file)")
   
        cancelAlertDismiss()
        if let selectDevice = selectUsers.first(where: { $0.uuid == udid}){
            if (isFinished) {
                print("测试：结束")
                selectDevice.deviceStatus = .completed
                selectDevice.progress = 1
                self.nearbyUsersView.updateDeviceStatus(selectDevice)
                
                self.saveSendContent(selectUser: selectDevice)
                
                self.selectUsers.removeAll {$0.uuid == selectDevice.uuid}
                //发送完成清空发送sessionId
                self.shareFilesSessionId = nil
                
                if #available(iOS 16.2, *) {
                    LiveActivityManager.shared.updateActivity(delay: 0, alert: false, progressValue: 1, status: StatusLive.receive, stateInfo: "发送完成", statusInfo: "")
                }
                if self.selectUsers.count > 0 {
                    self.sendSelectFile()
                }
                else{
                    self.importingLabel.isHidden = true
                    DispatchQueue.main.asyncAfter(deadline: .now()){
                        // TODO 停止activity
                        if #available(iOS 16.2, *) {
                            ShareAPI.shared().log(1,"发送完成 didSendEnd 停止灵动岛")
                            LiveActivityManager.shared.endActivity(dismissTimeInterval: 2)
                        }
                    }
                }
            }
            else {
                //self.nearbyUsersView.updateDeviceStatus(selectDevice, status: .sending, getShareProgress("end") ?? 0)
            }
        }
    }
    
    func didLivePhotoReady(_ imagePath: String, videoPath: String) {
        ShareAPI.shared().log(1, "didLivePhotoReady:\(imagePath)--videoPath:\(videoPath)")
    }
    
}


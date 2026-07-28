//
//  HuaweiShareViewController.swift
//  nshareIos
//
//  Created by ww on 2025/8/29.
//

import UIKit
import SnapKit
import XXPhotoPicker
import MobileCoreServices
import Lottie
import CoreLocation
import Photos

// MARK: - HuaweiShareViewController
class MIHuaweiShareViewController: MIBaseViewController {
    // 取消弹框
    var cancelAlert: UIViewController?
    var recvAlert: UIViewController?
    var manger : ShareAPI?
    ///设备信息数组
    var deviceInfos : [MIDevice] = []
    var selectDevice: MIDevice?
    var deviceName : String?
    var userAvatar : UIImage?
    var dict : [AnyHashable : Any] = [:]
    var modalVC : MIHuaweiShareViewController_Modal?
    
    var receivePage : MIReceiveFilesView?
    let userInfoView = MINaviUserInfoView.initView(icon: UIImage.avatarInfo, username: UIDevice.current.name, des: "以此身份使用鸿蒙星河互联".localized)
    
    /// 导航右侧按钮
    var naviRightItem: UIButton?
    lazy var bottonView: UIStackView = {
        let view = UIStackView(arrangedSubviews: [sendButton, desLabel])
        view.axis = .vertical
        view.spacing = 8
        view.alignment = .center
        return view
    }()

    let sendButton = UIButton()
    let desLabel: UILabel = {
        let label = UILabel()
            .withText("支持与HarmonyOS 6 及以上版本华为设备互传，\n对方需在控制中心将华为分享设为“所有人可见”".localized)
            .withFont(SFCompact(weight: .regular,size: 13))
            .withColorText("#3C3C43")
            .withNumberOfLines(0)
            .withTextAlignment(.center)
        label.textColor = label.textColor.withAlpha(0.6)
        return label
    }()
    var scanView:MIScanView?
    let nearbyUsersView = MINearbyUsersView(frame: .zero, userInfos: [])
    
    //分享sessionId
    var shareFilesSessionId: String?
    //发送文件数量（当前）
    var curFileIndex: Int?
    var isShowLocalAlter = false
    var isShowWifiAlter = false
    var isShowBluetoothAlter = false
    var isShowPhotoAlter = false
    var isShowAlbumAlter = false
    var isShowed = false//用于是否请求权限。防止多次请求
    deinit {
        print("deinit:释放============\(self)")
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationView?.leftButtonView?.isHidden = true
        initBkg()
        setupNaviView()
        setScanView()
        initViews()
       
        //开启扫描动画
        self.showScanView(isShow: true)

        //获取自己的设备名称以及头像
        getOwnDeviceInfo()
        
        //创建代理
        setNewDelegate()
        
        manger?.changeBtName(NSString(string: deviceName ?? "iPhone") as String)
        
        //接收通知 处理界面
        notificationAction()
        
        ///TODO： 假数据 测试使用
//        setToData()
//        recvAction()
        //开启代理 日志 后期可能需要删除
//        manger?.startLogging("")
        //写入代理日志
        manger?.log(1, "首页单利初始化 开启设备扫描 deviceName:\(deviceName ?? "iPhone")")
        
//        //在其他界面时 重设根视图 viewDidLoad  在updateWithObjectParams 之后
//        if let _ = ShareExtensionInfoManager.shared.shareInfoModel {
//
//            showModalVC()
//            self.cardInfoView?.isHidden = false
//            self.updateCardInfoView(self.dict)
//
//        }
        
    }
    
  
    //SDK 代理
    func setNewDelegate(){
        manger = ShareAPI.shared()
        manger?.setDeviceDelegate(self)
        manger?.setConnectDelegate(self)
        manger?.setTransDelegate(self)
        manger?.start()
    }
    

    
    /// 开始发送共享数据
    func startPostShareData(dict:[String:String]?) {
        print("共享数据获取成功")

//        guard let shareFileInfoModel = ShareExtensionInfoManager.shared.shareInfoModel else { return }
//        ShareAPI.shared().log(1, "共享数据获取成功----1")
//        
//        setNewDelegate()
//        self.manger?.log(1, "共享")
//        
//        var dict : [String:String] = [:]
//        var previewSummary : [String:Int] = [:]
//        
//        dict["itemCount"] = shareFileInfoModel.totalCount
//        if shareFileInfoModel.fileInfos.first?.fileType == .file {
//            dict["sendType"] = "3"
//            dict["fileCount"] = shareFileInfoModel.fileCount
//            var imageCount = 0
//            var mediaVideoCount = 0
//            var otherTypeCount = 0
//            if let shareInfoList =  ShareExtensionInfoManager.shared.shareInfoModel?.fileInfos {
//                for shareInfo in shareInfoList {
//                    if shareInfo.isImageType {
//                        imageCount += 1
//                    }
//                    if shareInfo.isVideoType {
//                        mediaVideoCount += 1
//                    }
//                    if !shareInfo.isImageType && !shareInfo.isVideoType {
//                        otherTypeCount += 1
//                    }
//                }
//                if otherTypeCount == 0 && (imageCount + mediaVideoCount) > 0 {
//                    dict["sendType"] = "0"
//                    dict["photoCount"] = "\(imageCount)"
//                    dict["videoCount"] = "\(mediaVideoCount)"
//                }
//            }
//            
//        } else if shareFileInfoModel.fileInfos.first?.fileType == .contact {
//            
//            dict["sendType"] = "8"
//            dict["itemCount"] = "1"
//            dict["fileCount"] = "1"
//            dict["contactsCount"] = shareFileInfoModel.contactCount
//            
//        } else {
//            dict["sendType"] = "0"
//            if Int(shareFileInfoModel.photoCount) ?? 0 > 0 {
//                dict["photoCount"] = shareFileInfoModel.photoCount
//            }
//            
//            if Int(shareFileInfoModel.videoCount) ?? 0 > 0 {
//                dict["videoCount"] = shareFileInfoModel.videoCount
//            }
//        }
//        
//        for fileInfoModel in shareFileInfoModel.fileInfos {
//            if let fileType = fileInfoModel.fileName.components(separatedBy: ".").last{
//                if let filetypeNum = previewSummary[".\(fileType)"]  {
//                    previewSummary[".\(fileType)"] = filetypeNum + 1
//                }else{
//                    previewSummary[".\(fileType)"] = 1
//                }
//            }
//        }
//        
//        
//        let previewSummaryStr = dictionaryToJSON(previewSummary).replacingOccurrences(of: "\n", with: "")
//        dict["previewSummary"] = previewSummaryStr
//        
//        dict["totalSize"] = shareFileInfoModel.totalSize
//
//        dict["senderName"] = self.deviceName
//     
//        dict["folderCount"] = "0" //文件总数
        
        self.dict = dict ?? [:]
        self.dict["senderName"] = self.deviceName
        
        self.contentView.isHidden = true
        setNewDelegate()
        if self.modalVC == nil{
            
            if let topVC = MIGetTopViewController(), topVC.isKind(of: MIDocumentPickerViewController.self){
                topVC.dismiss(animated: false) {
                 
                    self.showModalVC(fileType: -1, picker: nil, fileArr: nil, contacts: nil,animated: false)
                }
            }else{
                showModalVC(fileType: -1, picker: nil, fileArr: nil, contacts: nil,animated: false)
            }
            
            
        }else{
            modalVC?.selectFilePlace = -1
      
             modalVC?.dict = self.dict
            let devices = self.deviceInfos.map{
                let dev = MIDevice(name: $0.name, uuid: $0.uuid, hwId: $0.hwId,devicetype: $0.deviceType, deviceStatus:$0.deviceStatus,isShowIcon: $0.isShowIcon)
                return dev
            }
             
            self.modalVC?.deviceInfos = devices
            
            self.modalVC?.updatopInfoView(self.dict)
            self.modalVC?.showScanView(isShow: devices.count == 0)
            self.modalVC?.showScanView(isShow: false)

        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        getPermissionState()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isShowed = false
    }
}

extension MIHuaweiShareViewController:DeviceDelegate{
    //Mark: 发现新的设备
    func didDeviceFound(_ udid: String, device: [AnyHashable : Any]) {
        manger?.log(1, "发现新的设备:didDeviceFound:udid:\(udid)")
        modalVC?.didDeviceFound(udid, device: device)
        DispatchQueue.main.async {
            self.showScanView(isShow: false)
            let name =  (device["name"] as? String) ?? "";
            let udid = (device["udid"] as? String) ?? "";
            let hwId: String = (device["hwid"] as? String) ?? "";
            let isShowIcon = device["icon"] as? Bool ?? false
            let deviceType =  (device["deviceType"] as? Int) ?? 1;
            self.manger?.log(1, "首页收到设备\(name):\(udid)")

            guard let _ = self.deviceInfos.first(where: { $0.uuid == udid}) else {
                self.deviceInfos.append( MIDevice(name: name, uuid:udid,hwId:hwId,devicetype:deviceType,isShowIcon: isShowIcon))
                self.nearbyUsersView.updateUserInfos(self.deviceInfos)
                return
            }
        }
    }
    
    //Mark: 设备信息更新
    func didDeviceUpdate(_ udid: String, device: [AnyHashable : Any]) {
        modalVC?.didDeviceUpdate(udid, device: device)
        let name =  (device["name"] as? String) ?? "";
        let udid = (device["udid"] as? String) ?? "";
        let isShowIcon = device["icon"] as? Bool ?? false
        let hwId: String = (device["hwid"] as? String) ?? "";
        
        if let deviceInfo = self.deviceInfos.first(where: { $0.uuid == udid }){
            if deviceInfo.name.precomposedStringWithCanonicalMapping == name.precomposedStringWithCanonicalMapping &&  deviceInfo.isShowIcon == isShowIcon && deviceInfo.hwId == hwId{
                return
            }
            
            manger?.log(1, "设备信息更新:didDeviceUpdate:udid:\(udid)---old Name:\(deviceInfo.name)===new Name:\(name) ----hewid:\(deviceInfo.hwId)===new hewid:\(hwId)")
           
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
        manger?.log(1, "丢失设备:didDeviceLost:udid:\(udid)")
        
        modalVC?.didDeviceLost(udid)
        
        DispatchQueue.main.async {
            //设备丢失：包含异常。如果是发送的设备 停止发送   其他设备正常移除
//            if let lostDevice =  self.selectUsers.first(where: {$0.uuid == udid }),(lostDevice.deviceStatus == .sending || lostDevice.deviceStatus == .connecting || lostDevice.deviceStatus == .connected){
//                let _ = AlertManager.showAlert(title: "对方掉线,发送失败".localized,cancelTitle: nil, confirmTitle: "知道了".localized) {
//                    self.deviceInfos.removeAll {$0.uuid == udid}
//                    self.nearbyUsersView.updateUserInfos(self.deviceInfos)
//
//                    self.selectUsers.removeAll(where: {$0.uuid == udid})
//                    self.shareFilesSessionId = nil
//                    //设备移除后。是否存在等待发送的设备。如果存在继续发送
//                    if self.selectUsers.count > 0 {
//                       //继续发送
//                        self.sendSelectFile()
//                        return
//                    }
//                    //不存在需要发送的设备 停止保活 停止灵动岛
//                    isSendTask = false
//                    if #available(iOS 16.2, *) {
//                        self.manger?.log(1,"didCancel 对方取消 停止灵动岛")
//                        LiveActivityManager.shared.updateActivity(delay: 0, alert: false, progressValue: 0,status: StatusLive.cancelReceive, stateInfo: "对方已取消接收".localized,statusInfo: "")
//                        LiveActivityManager.shared.endActivity(dismissTimeInterval: 2)
//                    }
//
//                    //是否还有其他设备在线  没有设备开启扫描 停止灵动岛
//                    if self.deviceInfos.count  == 0{
//                        self.showScanView(isShow: true)
//                        if !(SaveFileHandler.isSaveFileing ?? false) && self.receivePage == nil {
//                            if #available(iOS 16.2, *) {
//                                LiveActivityManager.shared.endActivity(dismissTimeInterval: 2)
//                            }
//                        }
//                    }
//                }
//            }else{
                let count = self.deviceInfos.count
                self.deviceInfos.removeAll {$0.uuid == udid}
                //self.selectUsers.removeAll(where: {$0.uuid == udid})
                //如果设备有消失 刷新 没有不需要刷新 防止重复调用 刷新
                if count > self.deviceInfos.count {
                    self.nearbyUsersView.updateUserInfos(self.deviceInfos)
                    if self.deviceInfos.count  == 0{
                        self.showScanView(isShow: true)
                        if !(SaveFileHandler.shared.isSaveFileing ?? false) && self.receivePage == nil {
                            if #available(iOS 16.2, *) {
                                LiveActivityManager.shared.endActivity(dismissTimeInterval: 2)
                            }
                        }
                    }
                }
//            }
            //TODO：接收的时候设备丢失。需要另行处理  停止接收逻辑。停止接收保活
        }
    }
    
    //Mark: 设备头像存储
    func didRecvAvatar(_ udid: String, hwid:String, avatar: String) {
        manger?.log(1, "设备头像存储:didRecvAvatar:udid:\(udid)_hwid:\(hwid)")
        if hwid == "" {
            return
        }
        var imageModel = DeviceHeaderImage()
        imageModel.hwId = hwid
        imageModel.headerImage =  avatar//UIImage.icon.pngData()?.base64EncodedString()
        MIDeviceHeaderWCDBManager.sharedManager().insertOrReplaceHeader(imageModel)
    }
}

extension MIHuaweiShareViewController:ConnectDelegate {
   
    //Mark: 对方 取消发送/接收
    func didCancel(_ udid: String) {
        manger?.log(1, " 对方取消发送:didCancel:udid:\(udid)")
        
        if let modalVC = modalVC {
            
            modalVC.didCancel(udid)
        }
        if recvAlert != nil{
            isRecvTask = false
            recvAlert?.dismiss(animated: true) {
                self.recvAlert = nil
                self.receivePage?.exitRecvPage(title: "对方取消发送，接收失败".localized)
            }
        }
    }

    //Mark: 自己弹出加入热点。取消
    func didSelfCancel(_ udid: String) {
        
        isRecvTask = false
        isSendTask = false
        if let modalVC = modalVC {
            
            modalVC.didSelfCancel(udid)
        }
    
        if recvAlert != nil {
            receivePage?.cancelRecv()
            if #available(iOS 16.2, *) {
                self.manger?.log(1,"MIHuaweiShareViewController endActivity")
                LiveActivityManager.shared.endActivity(dismissTimeInterval: 0)
            }
        }
       
    }
    //Mark: 设备连接状态返回。连接中 和已经连接  已连接 时可进行数据发送处理
    func didConnect(_ udid: String, status: String) {
        
        manger?.log(1, " 设备连接状态:didConnect:udid:\(udid)")
        self.receivePage?.didConnect(udid, status: status)
        
        modalVC?.didConnect(udid, status: status)
        
    }
   
    //Mark: 设备 连接丢失  接收界面需要单独处理  首页 根据传回的 udid  要做判断 是否显示状态
    func didDisconnect(_ udid: String, reason: String, errorCode: Int32) {

       
        if reason == "peer_disconnected" || reason == "self_disconnected" {
            
       
        } else if reason == "peer_busy" {
            
          
            isRecvTask = false
            isSendTask = false
        } else if reason == "trans_error" {
            
      
            isRecvTask = false
            isSendTask = false
            showRecvErrorAlert(title: "接收失败".localized)
            
        } else if reason == "timeout"{
            
            isRecvTask = false
            isSendTask = false
            
            showRecvErrorAlert(title: "连接已超时，请对端重新点击设备发起连接".localized)
        }else if reason == "nospace" {
            
            isRecvTask = false
            isSendTask = false
           
            showRecvErrorAlert(title: "内存不足，接收失败".localized)
        }else if reason == "hotspotOn".localized{
            isRecvTask = false
            isSendTask = false
            return
        }
        if recvAlert != nil ||  self.receivePage != nil {
            return
        }
      
        modalVC?.didDisconnect(udid, reason: reason, errorCode: errorCode)
    }
    
    func didMetaRecv(_ udid: String, hwid: String, metadata: [AnyHashable : Any]) {
        // 个人热点是否打开判断（判断不准，先注释）
//        if MIHostspotPermissionManager.shared.isOpen(isReceive: true) {
//            isRecvTask = false
//            self.manger?.rejectRequest(udid)
//            return
//        }
        
        var name =  (metadata["senderName"] as? String) ?? ""
        let itemCount =  (metadata["itemCount"] as? String) ?? "0"
        let fileCount = (metadata["fileCount"] as? String) ?? "0"
        let senderType = (metadata["sendType"] as? String) ?? ""
        let previewSummary = (metadata["previewSummary"] as? String) ?? ""
        //文件夹适配
        name = "\(name)想要分享\(senderType == "4" ? fileCount : itemCount)个文件，是否接收？"
        
        self.receivePage?.senderType = senderType
        
        recvAlert = AlertManager.showAlert(title: name, cancelTitle: "拒绝".localized,cancelAction: {
            isRecvTask = false
            self.manger?.rejectRequest(udid)
            self.recvAlert = nil
        },confirmTitle: "接收".localized) {
            if senderType == "0"{
                self.getPhotoStatus(isReceive:true)
            }
            //没有照片权限不进入接收路径
            if senderType == "0" && !SaveFileHandler.shared.photoLibraryAuthorized() {
          
                self.manger?.rejectRequest(udid)
                return
            }
            MenuCardView.dismissMenuCardView()
            AlertManager.dismissAllAlertView()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.manger?.log(1,"didMetaRecv push receivePage ===1")
            
                    
                if self.receivePage == nil {
                    self.receivePage = MIReceiveFilesView()
                    self.receivePage?.manger = self.manger
                    self.receivePage?.backAction = {[weak self] in
                        guard let _ = self else { return  }
                        // self?.receivePage?.view.removeFromSuperview()
                        self?.receivePage = nil
                    }
                    
                    self.receivePage?.dissClick = {[weak self] in
                        self?.manger?.setDeviceDelegate(self)
                        self?.manger?.setConnectDelegate(self)
                        self?.manger?.setTransDelegate(self)
                    }
                    self.manger?.log(1,"didMetaRecv push receivePage ===2")
                    if self.recvAlert != nil {
                        self.manger?.log(1,"didMetaRecv push receivePage ===3")
                        self.recvAlert?.dismiss(animated: true) {
                            self.manger?.log(1,"didMetaRecv push receivePage ===4")
                            //                            self.manger?.log(1,"点击接收按钮 self.recvAlert:\(String(describing: self.recvAlert))    navigationController:\(String(describing: navC))")
                            self.pushMIReceiveFilesView()
                          
                        }
                    }
                    else {
                        self.pushMIReceiveFilesView()
                       
                    }
                } else {
                    self.manger?.log(1,"didMetaRecv push receivePage ===7")
                    
                    if self.recvAlert != nil {
                        self.manger?.log(1,"didMetaRecv push receivePage ===8")
                        self.recvAlert?.dismiss(animated: true) {
                            
                            self.pushMIReceiveFilesView()
                            
                        
                        }
                    } else {
                        
                        self.pushMIReceiveFilesView()
                        
                    }
                    self.receivePage?.normalPage()
                }
                isRecvTask = true
                //落盘初始化
                SaveFileHandler.shared.saveFileInit(senderType, previewSummary)
                if #available(iOS 16.2, *) {
                    self.manger?.log(1,"MIHuaweiShareViewController didMetaRecv 接收灵动岛初始化")
                    LiveActivityManager.shared.startLiveActivityWithToken()
                    LiveActivityManager.shared.updateActivity(delay: 0, alert: false, progressValue: 0, status: StatusLive.receive, stateInfo: "连接中...".localized, statusInfo: "")
                }
                self.receivePage?.udid = udid
                self.receivePage?.isFinish = false
                self.receivePage?.meta = metadata
                self.receivePage?.hwid = hwid
                self.receivePage?.senderType = (metadata["sendType"] as? String) ?? ""
                self.manger?.acceptRequest(udid)
                self.receivePage?.manger?.setTransDelegate(self.receivePage)
            }
        }
    }
    
    //Mark:  同意接收
    func didAccept(_ udid: String) {
        manger?.log(1, " 设备连接状态:didAccept:udid:\(udid)")
        modalVC?.didAccept(udid)

    }
        //Mark: 对方拒绝接收
    func didReject(_ udid: String) {
        
        modalVC?.didReject(udid)
    }
}
extension MIHuaweiShareViewController{
    
    func pushMIReceiveFilesView() {
        
        self.modalVC = nil
        self.selectDevice = nil
        self.contentView.isHidden = false
        DispatchQueue.main.async {
            if let topVC = UIViewController.topViewController{
                self.manger?.log(1,"didMetaRecv push receivePage ===5topVC:\(topVC)")
                if topVC . isKind(of: XXPhotoPicker.PhotoPickerViewController.self) || topVC .isKind(of: MIDocumentPickerViewController.self) || topVC .isKind(of: MIContactViewController.self) ||  topVC.isKind(of: XXPhotoPicker.PhotoPreviewViewController.self){
                    topVC.dismiss(animated: true) {
                        self.manger?.log(1,"didMetaRecv push receivePage ===5dismiss to Push")
                        let navC = MIGetTopNavViewController()?.navigationController
                        navC?.pushViewController(self.receivePage!, animated: true)
                    }
                    return
                }
                else  if topVC.isKind(of: MIHuaweiShareViewController_Modal.self){
                    let tempVc = topVC as? MIHuaweiShareViewController_Modal
                    let fileType = tempVc?.selectFilePlace
                    
                    if fileType == 0 || fileType == 8 {
                        topVC.presentingViewController?.presentingViewController?.dismiss(animated: true){
                            let navC = MIGetTopNavViewController()?.navigationController
                            navC?.pushViewController(self.receivePage!, animated: true)
                           
                        }
                    }else{
                        
                        topVC.dismiss(animated: true){
                           
                            let navC = MIGetTopNavViewController()?.navigationController
                            navC?.pushViewController(self.receivePage!, animated: true)
                        }
                    }
                    return
                }
                else if topVC.isKind(of: MITransferHistoryListController.self) || topVC.isKind(of: MITransferHistoryContenrController.self) || topVC.isKind(of: MIBaseHistoryViewController.self){
                    
                    for tempView in MIKeyWindow?.subviews ?? []{
                        if tempView.isKind(of: MIMenuView.self) {
                            tempView.removeFromSuperview()
                        }
                    }
                    
                    let navC = MIGetTopNavViewController()?.navigationController
                    self.manger?.log(1,"didMetaRecv push receivePage ===navC:\(topVC)")
                    
                    for tempVc in navC?.viewControllers ?? [] {
                        if tempVc.isKind(of: MIReceiveFilesView.self) {
                            
                            navC?.popToViewController(tempVc, animated: true)
                            return
                        }
                    }
                    topVC.navigationController?.pushViewController(self.receivePage!, animated: true)
                    return
                }
                else {
                    let navC = MIGetTopNavViewController()?.navigationController
                    self.manger?.log(1,"didMetaRecv push receivePage ===navC:\(topVC)")
                    
                    for tempVc in navC?.viewControllers ?? [] {
                        if tempVc.isKind(of: MIReceiveFilesView.self) {
                            
                            navC?.popToViewController(tempVc, animated: true)
                            return
                        }
                    }
                    
                    //self.navigationController?.pushViewController(self.receivePage!, animated: true)
                }
        
            }
            let navC = MIGetTopNavViewController()?.navigationController
            self.manger?.log(1,"didMetaRecv push receivePage ===navC return:\(navC)")
            navC?.pushViewController(self.receivePage!, animated: true)
        }
        
       
        
    }
    
}

extension MIHuaweiShareViewController:TransDelegate {
    //Mark:
    func didRecvAllFiles(_ udid: String, files: [String], totalBytes: NSNumber) {
        self.manger?.log(1, "didAccept:udid:\(udid)")
    }
    //Mark:
    func didRecvEnd(_ udid: String, file: String, isFinished: Bool, fileSize: CLongLong) {
        self.manger?.log(1, "didAccept:udid:\(udid)")
    }
    //Mark:
    func didRecvStart(_ udid: String, file: String) -> String {
        self.manger?.log(1, "didAccept:udid:\(udid)")
        return ""
    }
    
    //Mark:
    func didRecvData(_ udid: String, data: Data, file: String) {
        self.manger?.log(1, "didAccept:udid:\(udid)")
        print("========13")
    }

    //Mark:
    func didRecvEnd(_ udid: String, isFinished: Bool) {
        self.manger?.log(1, "didAccept:udid:\(udid)")
        print("========7")
    }
    
    //Mark:
    func didSendStart(_ udid: String, file: String) {
        self.manger?.log(1, "didAccept:udid:\(udid)")
        print("========8")
    }
    //Mark:
    func didSendData(_ udid: String, data: Data, file: String) {
        self.manger?.log(1, "didAccept:udid:\(udid)")
        print("========3")
    }
    
    //Mark: 发送中  进度 按照100.0 返回的数据  需要自行转化
//    func didSendProgress(_ udid: String, percent: Double) {
    func didUpdateProgress(_ udid: String, percent: Double, stat: [AnyHashable : Any]) {
            //TODO 进度需要根据底层修改后。转化为 0 - 1的小数

        modalVC?.didUpdateProgress(udid, percent: percent, stat: stat)
    }
    
    //Mark: 发送结束后。执行的操作
    func didSendEnd(_ udid: String, file: String, isFinished: Bool) {
        DispatchQueue.main.async {
            self.nearbyUsersView.updateUserInfos(self.deviceInfos)
        }
        isSendTask = false
        self.manger?.log(1, "发送完成:didSendEnd:udid:\(udid)--\(file)")
        modalVC?.didSendEnd(udid, file: file, isFinished: isFinished)
   
    }
    
}

extension MIHuaweiShareViewController {
    func showRecvErrorAlert(title: String) {
        isRecvTask = false
        if self.modalVC  != nil {
            return
        }
        if recvAlert != nil {
            recvAlert?.dismiss(animated: true) {
                self.recvAlert = nil
                if self.receivePage == nil {
                    AlertManager.showAlert(title: title, cancelTitle: nil, confirmTitle: "知道了".localized) {
                    }
                } else {
                    self.receivePage?.exitRecvPage(title: title.localized)
                }
            }
        } else {
            self.receivePage?.exitRecvPage(title: title.localized)
        }
    }
}

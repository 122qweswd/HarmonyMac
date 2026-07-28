//
//  MIHuaweiShareViewController+Modal.swift
//  MutualInfectionApp
//
//  Created by apple on 2025/10/26.
//

import UIKit
import XXPhotoPicker

enum SendFileType: Int {
    case invalid = -1
    case photo_asset = 0 //媒体
    case album = 2
    case file_manager_file = 3 //文管  选择
    case folder = 4
    case atomic_service = 5
    case atomic_card = 6
    case hap = 7
    case sand_box_file = 8 //通讯录文件
    case text = 9
    case link = 10
    case legacy_photo_asset = 11
    case legacy_sand_box_file = 12
    
    //-1:invalid，0:photo_asset,2:album,3:file_manager_file,4:folder,5:atomic_service,6:atomic_card,7:hap,8:sand_box_file,9:text,10:link,11:legacy_photo_asset,12:legacy_sand_box_file
}


//print(SendFileType.invalid.rawValue) // 输出：0


class MIHuaweiShareViewController_Modal: UIViewController {

    var closeClick:ClickBlockVoid?
    var backClick:ClickBlockVoid?
    var deviceInfos : [MIDevice] = []
    var selectUsers = [MIDevice]()
   
    var shareFilesSessionId: String?
    
    var dict : [AnyHashable : Any] = [:]
    var selectFilePlace:Int = 0  //0图库  3 文件管理 8 通讯录  -1 分享
    var fileArr:[FileModel] = []
    var picker: PickerResult?
    var contacts: [String:String]? = [:]
    var cancelAlert: UIViewController?
    
    lazy var backBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.addTarget(self, action: #selector(backAction(_:)), for: .touchUpInside)
        btn.setImage(UIImage.chevronBackward, for: .normal)
        return btn
    }()
    lazy var closeBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.addTarget(self, action: #selector(closeAction(_:)), for: .touchUpInside)
        btn.setImage(UIImage.closeCard, for: .normal)
        return btn
    }()
    
    lazy var sendInfoLabel : UILabel = {
        let label = UILabel()
            .withFont(SFCompact(weight: .regular,size: 12))
            .withColorText("#000000")
            .withTextAlignment(.leading)
            .withNumberOfLines(1)
        label.textColor = label.textColor.withAlpha(0.6)
        return label
    }()
    
    lazy var lineView : UIView = {
        let line = UIView()
        line.backgroundColor = UIColor(hexString:"E3E3E3")
        return line
    }()
    
    var scanView:MIScanView?
    let nearbyUsersView = MINearbyUsersView(frame: .zero, userInfos: [])
    
    
    let desLabel: UILabel = {
        let label = UILabel()
            .withText("支持与HarmonyOS 6 及以上版本华为设备互传，\n对方需在控制中心将华为分享设为“所有人可见”".localized)
            .withFont(SFCompact(weight: .regular,size: 13))
            .withColorText("#3C3C43")
            .withNumberOfLines(0)
            .withTextAlignment(.center)
        label.textColor = label.textColor.withAlpha(0.6)
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        return label
    }()
    
     lazy var importingLabel: UILabel = {
        let label = UILabel()
        label.font = SFCompact(weight: .regular, size: 13)
        label.textColor = "#336FFF".color
        label.text = "发送中，请不要退出当前页面".localized
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()
    
    deinit{
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(cancelUseSend), object: nil)
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor(hexString: "#E9E9E9")
        initTopInfo()
        initScanView()
        initDeviceViews()
        initBottomView()
        deviceTapAction()
        //灵动岛 取消发送
        NotificationCenter.default.addObserver(self, selector: #selector(cancelAction(_ : )), name: NSNotification.Name(cancelUseSend), object: nil)

    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
    }
    @objc private func backAction(_ sender: UIButton) {
        closePage(isClose: false)
        
    }
    @objc private func closeAction(_ sender: UIButton) {
        closePage(isClose: true)
        
    }
    
    func closePage(isClose:Bool = true){
        
        var showMessage = false;
        for device in self.selectUsers {
            if device.deviceStatus == .connecting ||
                device.deviceStatus == .waiting ||
                device.deviceStatus == .sending ||
                device.deviceStatus == .needreceive ||
                device.deviceStatus == .connected {
                showMessage = true
                break
            }
        }
        
        if showMessage {
            
            AlertManager.showAlert(title: "文件还在发送中，是否终止发送？".localized,message: nil,autoDismiss: true,cancelTitle:"终止发送".localized,
                                   cancelAction: {
                self.endSendAction()
                if isClose {
                    self.closeClick?()
                }else{
                    self.backClick?()
                }
            },confirmTitle:"继续发送".localized,
                                   confirmAction: {
                
            })
        }else{
            self.endSendAction()
            if isClose {
                self.closeClick?()
            }else{
                self.backClick?()
            }
        }
    }
}

//MARK:SetUI
extension MIHuaweiShareViewController_Modal{
    
    func initTopInfo() {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 10
        stackView.distribution = .fill
        self.view.addSubview(stackView)
        
        stackView.snp.makeConstraints { make in
            make.leading.equalTo(20)
            make.top.equalToSuperview().offset(10)
        }
        stackView.addArrangedSubview(backBtn)
        stackView.addArrangedSubview(sendInfoLabel)
        
        self.view.addSubview(closeBtn)
        backBtn.snp.makeConstraints { make in
            make.width.height.equalTo(30)
        }
        closeBtn.snp.makeConstraints { make in
            make.trailing.equalTo(-20)
            make.centerY.equalTo(stackView)
            make.width.height.equalTo(45)
        }
        self.view.addSubview(lineView)
        lineView.snp.makeConstraints { make in
            make.leading.equalTo(20)
            make.trailing.equalTo(-20)
            make.height.equalTo(1)
            make.top.equalTo(stackView.snp.bottom).offset(10)
        }
    }
    
    func initScanView(){
        scanView =  MIScanView(frame: .zero)
        self.view.addSubview(scanView ?? UIView())
        scanView?.isHidden = false
        
        scanView?.backgroundColor = .clear
        scanView?.snp.makeConstraints { make in
            make.top.equalTo(lineView.snp.bottom)
            make.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview()
        }
    }
    
    func initDeviceViews() {
 
        self.view.addSubview(nearbyUsersView)
        nearbyUsersView.isHidden = true
        nearbyUsersView.snp.makeConstraints {
            $0.top.equalTo(lineView.snp.bottom)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(-100)
        }
    }
    func initBottomView(){
        
        self.view.addSubview(desLabel)
        desLabel.snp.makeConstraints { make in
            make.leading.equalTo(20)
            make.trailing.equalTo(-20)
            make.bottom.equalTo(-10)
            make.height.equalTo(80)
        }
        
        self.view.addSubview(importingLabel)
        importingLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(desLabel.snp.top).offset(-2)
        }
        
    }
    
    /**显示扫描动画**/
    func showScanView(isShow:Bool = false){
        if isShow {
            self.nearbyUsersView.isHidden = true
            self.scanView?.isHidden = false
            self.scanView?.startAction()
        }else{
            self.nearbyUsersView.isHidden = false
            self.nearbyUsersView.updateUserInfos(self.deviceInfos)
            self.scanView?.isHidden = true
            self.scanView?.stopAction()
        }
    }
    
    func updatopInfoView(_ info: [AnyHashable: Any]?) {
        
  
        self.backBtn.isHidden =  (selectFilePlace == 3 ||  selectFilePlace == -1)
        let size = Int64((info?["totalSize"] as? String) ?? "0")

        var totalSizeStr = ""
        if let size = size,
           size < 1000 {
            totalSizeStr = "\(size) B"
        } else {
            totalSizeStr = formatFileSize(byteSize:size ?? 0 )
        }


        let itemCount = selectFilePlace == 8 ? (info?["contactsCount"] as? String ?? "") : (info?["itemCount"] as? String ?? "")
        let titleStr = selectFilePlace == 8  ? "个联系人" : (selectFilePlace == 3 ? "个文件" : "张图片")
        if(selectFilePlace == 0){
            let phontCount = Int(info?["photoCount"] as? String ?? "0") ?? 0
            let videoCount = Int(info?["videoCount"] as? String ?? "0") ?? 0



            if phontCount != 0 && videoCount != 0{
                sendInfoLabel.text = "\(phontCount)张图片,\(videoCount)个视频(共\(totalSizeStr))"

            }else if phontCount != 0 {
                sendInfoLabel.text = "\(phontCount)张图片(\(totalSizeStr))"
            }else if videoCount != 0 {
                sendInfoLabel.text = "\(videoCount)个视频(\(totalSizeStr))"
            }
        }else if self.selectFilePlace == 3{
            var imageCount = 0
            var mediaVideoCount = 0
            var otherTypeCount = 0
            for file in fileArr  {
                if file.isImageType {
                    imageCount += 1
                }
                if file.isVideoType {
                    mediaVideoCount += 1
                }
                if !file.isImageType && !file.isVideoType {
                    otherTypeCount += 1
                }
            }
           var newStr = ""
            if otherTypeCount > 0 {
                newStr = "\(otherTypeCount)" + "个文件".localized + ((imageCount > 0 || mediaVideoCount > 0) ? "," : "")
            }
            if imageCount > 0 {
                newStr = newStr + "\(imageCount)" + "张图片".localized + ((mediaVideoCount > 0) ? "," : "")
            }
            
            if mediaVideoCount > 0 {
                newStr = newStr + "\(mediaVideoCount)" + "个视频".localized
            }
            sendInfoLabel.text = "\(newStr)(\(totalSizeStr))"
        }else if selectFilePlace == -1{
            sendInfoLabel.text = "\(dict["navStr"] ?? "")(\(totalSizeStr))"
        }
        
        else{
            sendInfoLabel.text = "\(itemCount)\(titleStr)(\(totalSizeStr))"
        }
    }
}

extension MIHuaweiShareViewController_Modal{
    func deviceTapAction() {
        self.nearbyUsersView.selectDeviceTapped = {[weak self] userInfo in
            
            guard let weakSelf = self else { return  }
            // 如果设备已经在队列中，不重复添加
            if !(weakSelf.selectUsers.contains(where: { $0.uuid == userInfo.uuid })) {
                userInfo.deviceStatus = .waiting
                userInfo.progress = 0
                weakSelf.selectUsers.append(userInfo)
                weakSelf.updateView(userInfo: userInfo)
                //设备点击后。立即刷新 设备点击后的状态
                if weakSelf.selectUsers.count > 1 {
                    weakSelf.nearbyUsersView.updateDeviceStatus(userInfo)
                }
                
            } else {
                if userInfo.deviceStatus == .completed {
                    
                    userInfo.deviceStatus = .waiting
                    userInfo.progress = 0
                    weakSelf.selectUsers.append(userInfo)
                    weakSelf.updateView(userInfo: userInfo)
                    //设备点击后。立即刷新 设备点击后的状态
                    if weakSelf.selectUsers.count > 1 {
                        weakSelf.nearbyUsersView.updateDeviceStatus(userInfo)
                    }
                    return
                }
                if userInfo.deviceStatus == .waiting {
                    
                    weakSelf.selectUsers.removeAll { $0.uuid == userInfo.uuid}
              
                    userInfo.deviceStatus = .cancelled
                    userInfo.progress = 0
                    weakSelf.nearbyUsersView.updateDeviceStatus(userInfo)
                    
                    return
                }
                
                
                self?.cancelAlert = AlertManager.showAlert(title: "确定要取消发送吗？", cancelTitle: "取消发送".localized,cancelAction: {
                    //TODO：如果设备是在发送中。请求先取消   然后在代理中移除设备

                    if weakSelf.selectUsers.first(where: { $0.uuid == userInfo.uuid})?.deviceStatus != .completed {

                        ShareAPI.shared().cancelShare(userInfo.uuid)
                        //if weakSelf.selectUsers.first?.device.deviceStatus == .connecting {
                        //    // 没有传输
                        //    weakSelf.manger?.cancelShare(userInfo.device.uuid)
                        //} else {
                        //    // 传输中
                        //    weakSelf.manger?.cancelShare(userInfo.device.uuid)
                        //}

                        weakSelf.selectUsers.removeAll { $0.uuid == userInfo.uuid}
                        weakSelf.shareFilesSessionId = nil
                        userInfo.deviceStatus = .cancelled
                        weakSelf.importingLabel.isHidden = true
                        userInfo.progress = 0
                        weakSelf.nearbyUsersView.updateDeviceStatus(userInfo)
                        weakSelf.updateView(userInfo: userInfo)
                    }else{
                        self?.view.pickerMakeToast("取消失败".localized, duration: 2.0, point: self?.view.center ?? .zero, title: nil, image: nil) { didTap in

                        }
                    }
                    weakSelf.cancelAlertDismiss()
                } ,confirmTitle: "继续发送".localized) {
                    weakSelf.cancelAlertDismiss()
                }
            }
        }
    }
    
    func updateView(userInfo:MIDevice){


        ShareAPI.shared().log(1,"我要发送...之前的发送id\(self.shareFilesSessionId ?? "不存在")")

        //self.selectUsers.count > 0 已经选好了设备
        //self.shareFilesSessionId == nil 不存在 正在发送的事件


        //发送事件存在  设备不存在 不可能发生事件
        //发送事件不存在 设备不存在 不做任何处理

        //发送事件存在。 设备存在 不做任何处理
        //发送事件不存在  设备存在

        //存在设备。不存在发送事件
        if self.shareFilesSessionId == nil &&  self.selectUsers.count > 0 {

            //以下 解决是否需要直接发送
            self.sendSelectFile()
          
        }else{
            if self.selectUsers.count == 0 {
                if #available(iOS 16.2, *) {
                    ShareAPI.shared().log(1,"MIChoseDevicePostController endActivity updateView")
                    LiveActivityManager.shared.endActivity(dismissTimeInterval: 2)
                }
            }
        }
    }

    func endSendAction() {
        isSendTask = false
        for selectUser in self.selectUsers {
            if selectUser.deviceStatus == .needreceive || selectUser.deviceStatus == .connecting || selectUser.deviceStatus == .connected || selectUser.deviceStatus == .sending {
                ShareAPI.shared().cancelShare(selectUser.uuid)
                // TODO 取消灵动岛
                if #available(iOS 16.2, *) {
                    ShareAPI.shared().log(1,"MIChoseDevicePostController endActivity endSendAction")
                    LiveActivityManager.shared.endActivity(dismissTimeInterval: 2)
                }
            }
        }

        for deviceInfo in self.deviceInfos {
            if deviceInfo.deviceStatus != .normal {
                deviceInfo.deviceStatus = .normal
                deviceInfo.progress = 0
                self.nearbyUsersView.updateDeviceStatus(deviceInfo)
            }
        }
        self.selectUsers.removeAll()
        self.shareFilesSessionId = nil
        self.importingLabel.isHidden = true
        ShareExtensionInfoManager.shared.clearShareInfo()
    }

    
//
//    func updateViewNormal(){
//        //单个刷新 避免 一次刷新。界面闪动
//        for selectUser in self.selectUsers {
//            selectUser.deviceStatus = .normal
//            selectUser.progress = 0
//            self.nearbyUsersView.updateDeviceStatus(selectUser)
//        }
//        self.selectUsers.removeAll()
//
//        //self.nearbyUsersView.updateUserInfos(self.deviceInfos)
//    }
    func cancelAlertDismiss() {
        self.cancelAlert?.dismiss(animated: true)
        self.cancelAlert = nil;
    }
}

extension MIHuaweiShareViewController_Modal{
    // MARK: -
    @objc func cancelAction(_ noti :Notification? = nil){
        
        if let userDeviceInfo = self.selectUsers.first,userDeviceInfo.deviceStatus != .completed {
            
            userDeviceInfo.deviceStatus = .cancelled
            userDeviceInfo.progress = 0
            self.nearbyUsersView.updateDeviceStatus(userDeviceInfo)
            self.selectUsers.removeAll { $0.uuid == userDeviceInfo.uuid}
            
            print(self.selectUsers.count)
            
            ShareAPI.shared().cancelShare(userDeviceInfo.uuid)
            
            self.shareFilesSessionId = nil
            self.importingLabel.isHidden = true
            isSendTask = false
            
            if self.selectUsers.count > 0 {
                self.shareFilesSessionId = ShareAPI.shared().shareFiles(self.selectUsers.first?.uuid ?? "", metadata: self.dict as [AnyHashable : Any])
                self.importingLabel.isHidden = false
                if #available(iOS 16.2
                              , *) {
                    ShareAPI.shared().log(1,"MIChoseDevicePostController updateActivity cancelAction 待接收")
                    LiveActivityManager.shared.updateActivity(delay: 0, alert: false, progressValue: 0,status: StatusLive.waiting, stateInfo: "待接收".localized,statusInfo: "")
                }
            }else{
                if #available(iOS 16.2, *) {
                    ShareAPI.shared().log(1,"MIChoseDevicePostController endActivity cancelAction")
                    LiveActivityManager.shared.endActivity(dismissTimeInterval: 2)
                }
            }
        }
    }
}

extension MIHuaweiShareViewController_Modal{
    //给代理发送文件
    func sendSelectFile(){
        
        ShareAPI.shared().log(1, "sendSelectFile:开始分享队列第一个设备")
        if let sendUser = self.selectUsers.first {
            ShareAPI.shared().log(1, "sendSelectFile:开始分享队列第一个设备：Udid:\(sendUser.uuid)")
            let  shareFilesSessionId = ShareAPI.shared().shareFiles(sendUser.uuid, metadata: self.dict as [AnyHashable : Any])
              
            if shareFilesSessionId != "" {
                
                self.importingLabel.isHidden = false
                ShareAPI.shared().log(1, "sendSelectFile:开始分享队列第一个设备 设备不存在：Udid:\(sendUser.uuid)")
                self.shareFilesSessionId = shareFilesSessionId
                  sendUser.deviceStatus = .needreceive
                  sendUser.progress = 0
                  self.nearbyUsersView.updateDeviceStatus(sendUser)
                  if #available(iOS 16.2, *) {
                      //TODO:能否重复注册
                      LiveActivityManager.shared.startLiveActivityWithToken()
                      ShareAPI.shared().log(1,"sendSelectFile 待接收")
                      LiveActivityManager.shared.updateActivity(delay: 0, alert: false, progressValue: 0,status: StatusLive.waiting, stateInfo: "待接收".localized,statusInfo: "")
                  }
              }else{
                  
                  sendUser.deviceStatus = .error
                  sendUser.progress = 0
                  self.nearbyUsersView.updateDeviceStatus(sendUser)
                  self.selectUsers.removeAll {$0.uuid == sendUser.uuid}
                  //发送完成清空发送sessionId
                  self.shareFilesSessionId = nil
                  self.importingLabel.isHidden = true
                  if self.selectUsers.count > 0 {
                      sendSelectFile()
                  }
                  
                  
              }
            
        }
        
     
    }
    
 
    //TODO:  需要 根据底层 文件发送结果进行优化。保存单个文件 单个文件是否成功
    func saveSendContent(selectUser:MIDevice) {
        //保存发送记录
        ShareAPI.shared().log(1, "MIHuaweiShareViewController:saveSendContent:\(selectUser.uuid)")
        
        let record = MITransferRecord()
        record.deviceId = selectUser.uuid
        record.hwId = selectUser.hwId
        record.deviceType = selectUser.deviceType
        record.deviceName = selectUser.name
        record.transferType = .send
        record.transferTime = Date()
        
        var files: [MITransferFile] = []
        
        if let shareInfoList = ShareExtensionInfoManager.shared.shareInfoModel?.fileInfos {
            for shareInfo in shareInfoList {
                let model = MITransferFile()
                model.fileSize =  Int64(shareInfo.fileSize)
                model.fileName = shareInfo.fileName
                model.fileUrl = shareInfo.filePath
                model.fileType = .photoAndVideo
                files.append(model)
            }
        }else{
            let fileType = Int(dict["sendType"] as? String ?? "0")
            
            if fileType == 0 {
                for asset in picker?.photoAssets ?? [] {
                    let model = MITransferFile()
                    model.fileSize = Int64(asset.fileSize)
                    model.fileName = asset.fileName
                    model.fileUrl = asset.filePath
                    model.fileType = .photoAndVideo
                    files.append(model)
                }
                for fileModel in fileArr {
                    let model = MITransferFile()
                    model.fileSize = fileModel.sizeInBytes
                    model.fileName = fileModel.name
                    model.fileUrl = fileModel.url.path
                    model.fileType = .file
                    files.append(model)
                }
            }
           
            else if fileType == 3 {
                for fileModel in fileArr {
                    let model = MITransferFile()
                    model.fileSize = fileModel.sizeInBytes
                    model.fileName = fileModel.name
                    model.fileUrl = fileModel.url.path
                    model.fileType = .file
                    files.append(model)
                }
                
            } else{
                //通讯录数据组装
                let model = MITransferFile()
                model.fileSize = Int64(contacts?["fileSize"] ?? "")
                model.fileName = contacts?["fileName"] ?? ""
                model.fileUrl = contacts?["fileUrl"] ?? ""
                model.fileType = .contacts
                files.append(model)
            }
        }

        record.sendContent = files
        do{
            _ = try MIWCDBManager.shared.insertRecord(record)
            
        } catch {
            
        }
    }
}

extension MIHuaweiShareViewController{
    
    // 选择设备后。--- 选取文件
    //0  : 照片视频。3: 文件 8:通讯录 //数量。
    func sendContentToDevice(fileType:Int, picker: PickerResult?, fileArr:[FileModel]? , contacts: [String:String]? ) {
        
        var totalSize : Int64 = 0
        var phontCount: Int = 0
        var videoCount: Int = 0
        
        var itemCount = 0
        var contactsCount = 0
        var fileCount = 0
        var previewSummary : [String:Int] = [:]
        
        if fileType == 0 {
            guard let result = picker else { return }
            
            itemCount = result.photoAssets.count
            fileCount = itemCount
            
            let photoSize: Int = result.photoSize
            let videoSize: Int = result.videoSize
            phontCount = result.phontCount
            videoCount = result.videoCount
            totalSize = Int64(photoSize + videoSize)
            for asset in result.photoAssets {
                //获取文件后缀
                if let fileExtension =  asset.fileName.components(separatedBy: ".").last{
                    if let filetypeNum = previewSummary[".\(fileExtension)"]  {
                        
                        previewSummary[".\(fileExtension)"] = filetypeNum + 1
                    }else{
                        previewSummary[".\(fileExtension)"] = 1
                    }
                }
            }
            
        } else if fileType == 3 {
            itemCount = fileArr?.count ?? 0
            fileCount = itemCount
            totalSize = fileArr?.map { $0.sizeInBytes }.reduce(0, +) ?? 0
            
            for file in fileArr ?? [] {
                //获取文件后缀
                if let fileExtension =  file.name.components(separatedBy: ".").last{
                    if let filetypeNum = previewSummary[".\(fileExtension)"]  {
                        previewSummary[".\(fileExtension)"] = filetypeNum + 1
                    }else{
                        previewSummary[".\(fileExtension)"] = 1
                    }
                }
            }
        } else if fileType == 8 {
            contactsCount = Int(contacts?["itemCount"] as? String ?? "0") ?? 0
            itemCount = 1
            fileCount = 1
            totalSize = Int64(contacts?["fileSize"] as? String ?? "0") ?? 0
            previewSummary[".vcf"] = 1
        }
        
      let previewSummaryStr = dictionaryToJSON(previewSummary).replacingOccurrences(of: "\n", with: "")
        self.manger?.log(1,"previewSummaryStr：\(previewSummaryStr)")
      

        dict = ["sendType":"\(fileType)",//0媒体类型 3文件类型
                    "senderName":deviceName ?? "",//设备名称
                    "itemCount":"\(itemCount)",//对应的数量
                    "totalSize":"\(totalSize)",
                    "fileCount":(fileType == 0 && itemCount <= 500) ? "0" : "\(fileCount)",//文件总数
                    "folderCount":"0",//文件夹个数
                    "previewSummary":previewSummaryStr,
                    "photoCount":"\(phontCount)",
                    "videoCount":"\(videoCount)",
                    "contactsCount":"\(contactsCount)"
        ] as [String : Any]
        
        
        if fileType == 3 {
            var imageCount = 0
            var mediaVideoCount = 0
            var otherTypeCount = 0
            for file in fileArr ?? [] {
                if file.isImageType {
                    imageCount += 1
                }
                if file.isVideoType {
                    mediaVideoCount += 1
                }
                if !file.isImageType && !file.isVideoType {
                    otherTypeCount += 1
                }
            }
            if otherTypeCount == 0 && (imageCount + mediaVideoCount) > 0 {
                dict["sendType"] = "0"
                dict["photoCount"] = "\(imageCount)"
                dict["videoCount"] = "\(mediaVideoCount)"
            }
        }
        showModalVC(fileType: fileType,picker: picker,fileArr: fileArr,contacts: contacts)
    }
    
    func showModalVC(fileType:Int, picker: PickerResult?, fileArr:[FileModel]? , contacts: [String:String]?, animated: Bool = true) {
       
       
        modalVC = MIHuaweiShareViewController_Modal()
        modalVC?.selectFilePlace = fileType
        setNewDelegate()
        
        modalVC?.isModalInPresentation = true
        if fileType == 0 || fileType == 8 {
            modalVC?.modalPresentationStyle = .overCurrentContext
        }
        modalVC?.dict = self.dict
        
        print("dict========\(dict)")
        
       
    
        
        
        
        
        var topVC = MIGetTopViewController()
        print("========1=\(topVC)")
        if (!(topVC?.isKind(of: XXPhotoPicker.PhotoPickerViewController.self) ?? false) && !(topVC?.isKind(of: MIDocumentPickerViewController.self) ?? false) && !(topVC?.isKind(of: MIContactViewController.self) ?? false) && !(topVC?.isKind(of: XXPhotoPicker.PhotoPreviewViewController.self) ?? false)) || fileType == 3{
            topVC = self
            print("=========2\(topVC)")
        }
        print("=========3\(topVC)")
        topVC?.present(modalVC ?? MIHuaweiShareViewController_Modal(), animated: true) {
            let devices = self.deviceInfos.map{
                let dev = MIDevice(name: $0.name, uuid: $0.uuid, hwId: $0.hwId,devicetype: $0.deviceType, deviceStatus:$0.deviceStatus,isShowIcon: $0.isShowIcon)
                return dev
            }
            if fileType == 0{
                self.modalVC?.picker = picker
            }else if fileType == 3{
                self.modalVC?.fileArr = fileArr ?? []
            }else if fileType == 8{
                self.modalVC?.contacts = contacts
                
            }
                
                
            self.modalVC?.deviceInfos = devices
            
            self.modalVC?.updatopInfoView(self.dict)
        
            self.modalVC?.showScanView(isShow: devices.count == 0)
            if let selectDevice =  self.selectDevice {
                if let dev = devices.first(where: {$0.uuid == selectDevice.uuid}) {
                    self.modalVC?.selectUsers.append(dev)
                    self.modalVC?.sendSelectFile()
                }
            }
            
//            if let _ =  self.selectDevice {
//                self.modalVC?.sendSelectFile()
//            }
        }
        
        modalVC?.closeClick = {[weak self] in
            
            guard let weakSelf = self else { return  }
            
            if fileType == 0 || fileType == 8 {
                weakSelf.modalVC?.presentingViewController?.presentingViewController?.dismiss(animated: true){
                    weakSelf.contentView.isHidden = false
                    weakSelf.modalVC = nil
                    weakSelf.selectDevice = nil
                }
               
            }else{
                weakSelf.modalVC?.dismiss(animated: true) {
                    weakSelf.contentView.isHidden = false
                    weakSelf.modalVC = nil
                    weakSelf.selectDevice = nil
                }
            }
            
        }
        modalVC?.backClick = {[weak self] in
            guard let weakSelf = self else { return  }
            weakSelf.modalVC?.dismiss(animated: true){
                weakSelf.contentView.isHidden = false
                weakSelf.modalVC = nil
                weakSelf.selectDevice = nil
            }
        }
        
      
    }
}


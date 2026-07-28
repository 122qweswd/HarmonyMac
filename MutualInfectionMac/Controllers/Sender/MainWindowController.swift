//
//  MainWindowController.swift
//  MutualInfection
//
//  Created by 1234 on 2025/9/22.
//

import Cocoa
import AppKit
import CoreLocation

var moreMeumView:MoreMeumView?
var receivePageManger: MIRecvPageManager?
var topRightButton: NSButton?

class MainWindowController: NSViewController, CLLocationManagerDelegate ,NSWindowDelegate{
    
    ///设备信息数组
    var deviceInfos : [MIDevice] = []
    var selectUsers = [MIDevice]()
    var fileArr:[URL] = []
    var dict : [AnyHashable : Any] = [:]
    var selectUsersData = [AnyHashable:[URL]]()
    var sendUsersData = [AnyHashable:[FileModel]]()
    //分享sessionId
    var shareFilesSessionId: String?
    var manger : ShareAPI?
    var fileType:Int = -1
    var scanView : MIMACScanView?
    let nearbyUsersView = MIMACNearbyUsersView(frame: .zero, userInfos: [])
    var bottomLabel : NSTextField?
    var bottomView : NSView?
    
    var hostName:String!//当前设备用户名
    var userAvatar: NSImage? //当前用户头像
    //用户名
    var ownNameLabel = NSTextField(labelWithString: "")
    var ownPhotoView = CustomImageView(nsImage:Gloable.userAvatar,size: NSSize(width: 40, height: 40))
    var openPanel : NSOpenPanel?
    var currentSlectUser : MIDevice?
    var centralManager: CBCentralManager?
    var locationManager: CLLocationManager?
      
    var shareFileCome = false
    var preView:NSView? // 选择弹窗时，挡住vc让其不可点击
    var systemIsAwake = true
    var appWindowOpen = true
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: kOriMainWindowWidth, height: kOriMainWindowHeight))
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        NetworkMonitorConnectMac.shared.startMonitoring()
        if receivePageManger == nil {
            receivePageManger = MIRecvPageManager(type: .receivePop, isShowCloseBtn: false)
        }
        dataLoading()
        //设置背景图片
        initBkg()
        setScanView()
//        setToData()
        
        setCustomImage()
        setTipLabel()
        setTopButton()
//        setBottomLabel()
        setUpBottomView()
        setNearbyUsersView()
        setMoreMeum()
        
        //创建代理
        setNewDelegate()

        manger?.changeBtName(NSString(string: hostName ?? "Mac") as String)
        manger?.setSpeedMode(UserDefaults.standard.bool(forKey: speedMode))
        //申请蓝牙权限，不做任何操作
        firstScan()
        //申请本地网络权限，不做任何操作
        MILocalNetworkPermissionManager.shared.requestPermission()
        
        manger?.log(1, "首页单利初始化 开启设备扫描 deviceName:\(hostName ?? "Mac")")
        // 监听通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNameUpdate(_:)),
            name: Notification.Name("NameDidChange"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAvatarUpdate(_:)),
            name: Notification.Name("AvatarDidChange"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(shareFilesReceived(_:)),
            name: Notification.Name("FilesReceived"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showTransmitRecord(_:)),
            name: Notification.Name("MainWindowControllerShowTransmitRecord"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowIsReopen(_:)),
            name: Notification.Name("windowIsReopen"),
            object: nil
        )
        let workspace = NSWorkspace.shared
        let notificationCenter = workspace.notificationCenter
        
        // 1. 监听系统即将睡眠
        notificationCenter.addObserver(
            self,
            selector: #selector(systemWillSleep(_:)),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        
        // 2. 监听系统已经唤醒
        notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake(_:)),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        addPreView()
    }
    deinit{
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        self.view.window?.delegate = self
    }
    
    
  
//  func windowShouldClose(_ sender: NSWindow) -> Bool {
//      return false
//  }
    
    @objc private func systemWillSleep(_ notification: Notification) {
        print("系统即将睡眠")
        // 在此处执行睡眠前的操作：
        // - 暂停网络请求或下载
        // - 保存当前应用状态
        // - 断开外部设备连接
        // - 停止定时器或CPU密集型任务
        // **注意：此方法必须迅速返回，否则会阻碍系统睡眠。**
        if systemIsAwake {
            systemIsAwake = false
            manger?.log(1, "systemWillSleep")
            if appWindowOpen {
                manger?.enterBackground()
            }
        }
    }
    
    @objc private func systemDidWake(_ notification: Notification) {
        print("系统已被唤醒")
        // 在此处执行唤醒后的操作：
        // - 恢复网络连接
        // - 刷新应用数据（如重新请求最新的网络信息）
        // - 重新连接外部设备
        // - 更新用户界面
        if !systemIsAwake{
            systemIsAwake = true
            manger?.log(1, "systemDidWake")
            if appWindowOpen {
                manger?.enterForeground()
            }
        }
    }
    
    @objc func windowIsReopen(_ notification: Notification){
        if !appWindowOpen {
            appWindowOpen = true
            manger?.log(1, "windowIsReopen")
            // 只有当系统也醒着时才进入前台
            if systemIsAwake {
                manger?.enterForeground()
            }
        }
        
    }
    func windowWillClose(_ notification: Notification) {
        if appWindowOpen {
            appWindowOpen = false
            manger?.log(1, "windowWillClose")
            // 无论系统状态如何，窗口关闭都进入后台
            manger?.enterBackground()
        }
    }
    func addPreView(){
        preView = NSView()
        guard let preView = preView else { return }
        let tap = NSClickGestureRecognizer(target: self, action: #selector(nothing))
        preView.addGestureRecognizer(tap)
        preView.wantsLayer = true
        preView.layer?.backgroundColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.1).cgColor
        self.view.addSubview(preView, positioned: .above, relativeTo: nil)
        
        preView.isHidden = true
        
        globalDragEnabled = true
        preView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    @objc func nothing(){
        print("别随便乱点")
    }
      //SDK 代理
      func setNewDelegate(){
          manger = ShareAPI.shared()
          manger?.setDeviceDelegate(self)
          manger?.setConnectDelegate(self)
          manger?.setTransDelegate(self)
          manger?.setDFXDelegate(self)
          manger?.start()
      }
    @objc func handleNameUpdate(_ notification: Notification) {
        if let newName = notification.userInfo?["newName"] as? String {
            ownNameLabel.stringValue = newName
            self.manger?.changeBtName(newName)
        }
    }
    
    @objc func shareFilesReceived(_ notification: Notification) {
        onlyClosePanel()
        
        ShareAPI.shared().log(1, "222 path: \(SharedFilesManager.shared.receivedFiles[0].path)");
        let receivedFiles = SharedFilesManager.shared.receivedFiles
        guard !receivedFiles.isEmpty else {
            ShareAPI.shared().log(1, "No received files available")
            return
        }
        
        let firstFile = receivedFiles[0]
        let filePath = firstFile.path
        let url = URL(fileURLWithPath: filePath)
        // 检查文件是否存在
        if FileManager.default.fileExists(atPath: filePath) {
            let url = URL(fileURLWithPath: filePath)
            ShareAPI.shared().log(1, "File URL created: \(url.path)")
        } else {
            ShareAPI.shared().log(1, "File does not exist at path: \(filePath)")
        }
        
        if #available(macOS 13.0, *) {
            ShareAPI.shared().log(1, "333 url: \(url.path())")
        } else {
            // Fallback on earlier versions
        }
        self.shareFileCome = true
        self.fileArr = receivedFiles.map{ return URL(fileURLWithPath: $0.path) }
    }
    @objc func handleAvatarUpdate(_ notification: Notification) {
        if let newImage = notification.userInfo?["newAvatar"] as? NSImage {
            ownPhotoView.image = newImage
        }
    }
    
    @objc func showTransmitRecord(_ notification: Notification) {
        let page=PagesCall(upWindow:self.view.window)
        page.transmitRecordWindowShow()
    }

    func dataLoading() {
        if UserDefaults.standard.string(forKey: deviceNameKey) == nil || UserDefaults.standard.string(forKey: deviceNameKey) == "" {
            Gloable.userName = Host.current().localizedName ?? "Mac"
        } else {
            Gloable.userName = UserDefaults.standard.string(forKey: deviceNameKey)!
        }
        
        if let avatarData = UserDefaults.standard.data(forKey: userAvatarKey),let image = NSImage(data: avatarData) {
            Gloable.userAvatar = image
        } else {
            Gloable.userAvatar = NSImage.deviceMacOri
        }
        
        let savedName = UserDefaults.standard.string(forKey: deviceNameKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        Gloable.userName = (savedName?.isEmpty == false) ? savedName! : (Host.current().localizedName ?? "Mac")
        self.hostName = Gloable.userName
        self.userAvatar = Gloable.userAvatar
    }
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
}


extension MainWindowController:CBCentralManagerDelegate{
        
    func firstScan(){
        // 初始化蓝牙管理器（此时若未授权，不会立即弹窗）
        self.centralManager = CBCentralManager(delegate: self, queue: .main)
        // 2. 初始化位置管理器（修正错误：CLLocationManager 没有 (delegate:queue:) 构造方法）
        self.locationManager = CLLocationManager()
        self.locationManager?.delegate = self  // 单独设置代理
        self.locationManager?.desiredAccuracy = kCLLocationAccuracyThreeKilometers  // 可选：设置精度
        
        // 3. 立即检查并请求位置权限
        checkLocationPermission()
    }
    // 检查位置权限状态
    private func checkLocationPermission() {
        guard let locationManager = locationManager else { return }
        
        // macOS 中获取位置权限状态（无需区分 iOS 14+，直接使用 authorizationStatus）
        let status = CLLocationManager.authorizationStatus()
        
        switch status {
        case .notDetermined:
            // 首次请求权限：macOS 中只能请求 "使用时" 权限（没有 Always 选项）
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            // 已授权（macOS 中只有 WhenInUse 一种授权类型）
            print("位置权限已授权")
            // 此处可触发蓝牙扫描（确保蓝牙也已就绪）
//        case .denied, .restricted:
            // 权限被拒或受限制，提示用户去设置
//            showLocationPermissionAlert()
        @unknown default:
            break
        }
    }
    // 位置权限变更时回调（必须实现）
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkLocationPermission()  // 重新检查权限
    }
    // 位置权限被拒时的提示弹窗
    private func showLocationPermissionAlert() {
        // 根据平台（iOS/macOS）实现弹窗，以下是 iOS 示例
        showSheetAlert(messageText: "位置权限未打开".localized, message: "没有获得位置权限，请在设置中打开位置权限".localized,window:self.view.window,confirmTitle: "去设置".localized, completion:{
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
                NSWorkspace.shared.open(url)
            }
        })
    }
        // 蓝牙状态更新时触发
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            // 蓝牙已打开，开始搜索设备（此操作会触发权限弹窗，若未授权）
            central.scanForPeripherals(withServices: nil, options: nil)
        case .unauthorized:
            // 已拒绝权限，可引导用户去设置开启（见前文蓝牙权限引导）
            print("蓝牙权限未授予")
//            showSheetAlert(messageText: "蓝牙权限未打开".localized, message: "没有获得蓝牙权限，请在设置中打开蓝牙权限".localized,window:self.view.window,confirmTitle: "去设置".localized, completion:{
//                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth") {
//                    NSWorkspace.shared.open(url)
//                }
//            })
        default:
            break
        }
    }
      
}

extension MainWindowController:DeviceDelegate{
    //Mark: 发现新的设备
    func didDeviceFound(_ udid: String, device: [AnyHashable : Any]) {
        manger?.log(1, "发现新的设备:didDeviceFound:udid:\(udid)")
        DispatchQueue.main.async {
            self.showScanView(isShow: false)
            let name =  (device["name"] as? String) ?? "";
            let udid = (device["udid"] as? String) ?? "";
            let hwId: String = (device["hwid"] as? String) ?? "";
            let isShowIcon = device["icon"] as? Bool ?? false
            let deviceType =  (device["deviceType"] as? Int) ?? 1;
            let logDeviceOldName = ShareAPI.shared().anonymizeString(name)
            self.manger?.log(1, "首页收到设备\(logDeviceOldName):\(udid)")

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
            
            manger?.log(1, "设备信息更新:didDeviceUpdate:udid:\(udid)")
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
        DispatchQueue.main.async {
            
            if  let lostDevice =  self.selectUsers.first(where: {$0.uuid == udid }),let current = self.currentSlectUser,lostDevice.uuid == current.uuid,let panel = self.openPanel {
                self.closePanel()
            }
            //设备丢失：包含异常。如果是发送的设备 停止发送   其他设备正常移除
            if let lostDevice =  self.selectUsers.first(where: {$0.uuid == udid }),(lostDevice.deviceStatus == .sending || lostDevice.deviceStatus == .connecting || lostDevice.deviceStatus == .connected || lostDevice.deviceStatus == .needreceive ){
                //TODO:处理
//                let _ = AlertManager.showAlert(title: "对方掉线,发送失败".localized,cancelTitle: nil, confirmTitle: "知道了".localized) {
                lostDevice.deviceStatus = .disconnected
                self.deviceInfos.removeAll {$0.uuid == udid}
                self.nearbyUsersView.updateUserInfos(self.deviceInfos)
                self.selectUsers.removeAll(where: {$0.uuid == udid})
                self.selectUsersData.removeValue(forKey: udid)
                self.shareFilesSessionId = nil
                //设备移除后。是否存在等待发送的设备。如果存在继续发送
                if self.selectUsers.count > 0 {
                    //继续发送
                    self.sendSelectFile()
                    return
                } else {
                    self.clearSelectUserData()
                }
            } else {
                let count = self.deviceInfos.count
                self.deviceInfos.removeAll {$0.uuid == udid}
                self.selectUsers.removeAll(where: {$0.uuid == udid})
                self.selectUsersData.removeValue(forKey: udid)
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

extension MainWindowController:ConnectDelegate {
   
    //Mark: 对方 取消发送/接收
    func didCancel(_ udid: String) {
        manger?.log(1, " 对方取消发送:didCancel:udid:\(udid)")
        
        if let userDeviceInfo = self.selectUsers.first(where: {$0.uuid == udid}){
            
            //防止完成时 显示取消 并调用下一个发送
            if userDeviceInfo.deviceStatus != .completed  {
                let panel = MICustomPanel(
                    title: "\(userDeviceInfo.name)" + "取消，分享失败".localized,
                    confirmButtonTitle: "知道了".localized,
                    cancelButtonTitle: ""
                )
                panel.showModal(in: self.view.window ?? NSWindow(),
                    confirmHandler: {

                },cancelHandler: {
                    
                })
                //                    guard let ss = self else { return }
                let ss = self
                userDeviceInfo.fristSendEnd = true
                userDeviceInfo.deviceStatus = .cancelled
                userDeviceInfo.progress = 0
                ss.nearbyUsersView.updateDeviceStatus(userDeviceInfo)
                ss.selectUsers.removeAll { $0.uuid == udid}
                ss.selectUsersData.removeValue(forKey: udid)
                ss.shareFilesSessionId = nil
                
                //设备移除后。是否存在等待发送的设备。如果存在继续发送
                if ss.selectUsers.count > 0 {
                    //继续发送
                    ss.sendSelectFile()
                    return
                }else{
                    ss.clearSelectUserData()
                }
                //不存在需要发送的设备 停止保活 停止灵动岛
                isSendTask = false
                
                //TODO:处理
//                let _ = AlertManager.showAlert(title: "\(userDeviceInfo.name)取消，分享失败".localized,cancelTitle: nil, confirmTitle: "知道了".localized) {
//                    userDeviceInfo.deviceStatus = .cancelled
//                    userDeviceInfo.progress = 0
//                    self.nearbyUsersView.updateDeviceStatus(userDeviceInfo)
//                    self.selectUsers.removeAll { $0.uuid == udid}
//                    self.shareFilesSessionId = nil
//                    
//                    //设备移除后。是否存在等待发送的设备。如果存在继续发送
//                    if self.selectUsers.count > 0 {
//                       //继续发送
//                        self.sendSelectFile()
//                        return
//                    }
//                    //不存在需要发送的设备 停止保活 停止灵动岛
//                    isSendTask = false
//             
//                }
            }
        } else if isRecvTask {
            receivePageManger?.recvErrorPopController?.setMessage(message: "对方取消发送，接收失败".localized)
        }
    }

    //Mark: 自己弹出加入热点。取消
    func didSelfCancel(_ udid: String) {
        
        manger?.log(1, " 设备连接状态:didSelfCancel:udid:\(udid)")
        
        if let deviceInfo = self.selectUsers.first(where: {$0.uuid == udid}){
            deviceInfo.deviceStatus = .cancelled
            deviceInfo.progress = 0
            self.nearbyUsersView.updateDeviceStatus(deviceInfo)
            isSendTask = false
            
            self.selectUsers.removeAll(where: {$0.uuid == udid})
            self.selectUsersData.removeValue(forKey: udid)
            self.shareFilesSessionId = nil
            if self.selectUsers.count > 0 {
                self.sendSelectFile()
               
            }else{
                clearSelectUserData()
            }
        } else if isRecvTask {
            receivePageManger?.stopReceptPopController?.cancelRecv()
        }
    }
    //Mark: 设备连接状态返回。连接中 和已经连接  已连接 时可进行数据发送处理
    func didConnect(_ udid: String, status: String) {
        receivePageManger?.stopReceptPopController?.didConnect(udid, status: status)
        manger?.log(1, " 设备连接状态:didConnect:udid:\(udid) status:\(status)")
        if let userDeviceInfo = self.selectUsers.first(where: {$0.uuid == udid}){
            if status == "connecting" || status == "joinwifi" {
                userDeviceInfo.deviceStatus = .connecting
                userDeviceInfo.progress = 0
              
            } else if status == "connected" {
                userDeviceInfo.deviceStatus = .connected
                userDeviceInfo.progress = 0
            }else if status == "joinwififailed" {
                
                let panel = MICustomPanel(
                    title: "请断开已连接的WIFI后重试".localized,
                    confirmButtonTitle: "取消",
                    cancelButtonTitle: "去设置"
                )
                
                panel.showModal(in: self.view.window ?? NSWindow(),
                    confirmHandler: {
                    self.endSendAction()
                },cancelHandler: {
                    self.endSendAction()
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.network") {
                        
                        NSWorkspace.shared.open(url)
                    }
                })
            }
            self.nearbyUsersView.updateDeviceStatus(userDeviceInfo)
            if (status == "connected") {
                var files : [[AnyHashable:Any]] = []
                
                let fileType = Int(dict["sendType"] as? String ?? "0")
                
                //Mark:  if内容是iOS的，永远不会走
                if let shareInfoList = ShareExtensionInfoManager.shared.shareInfoModel?.fileInfos {
                    for shareInfo in shareInfoList {
                        files.append(["fileSize": "\(shareInfo.fileSize)",
                                      "fileName": shareInfo.fileName,
                                      "fileUrl": shareInfo.filePath])
                    }
                    isSendTask = true
                    manger?.sendFiles(udid, files: files)
                } else {
                    if let fileurls = selectUsersData[udid]{
//                        if shareFileCome == false {
                            //不是系统分享过来的数据
                            var filesArr:[FileModel] = []
                            let serialQueue = DispatchQueue(label: "com.MutualInfection.serial")
                            let dispatchMacGroup = DispatchGroup()
                            // 处理每个文件信息
                            for (index, info) in fileurls.enumerated() {
                                dispatchMacGroup.enter()
                                serialQueue.sync {
                                    manger?.log(1, "处理每个文件信息 ====\(info)")
                                    self.parseMacFileAttributes(url: info) { fileMdl in
                                        filesArr.append(fileMdl)
                                        dispatchMacGroup.leave()
                                    }
                                }
                            }
                            dispatchMacGroup.notify(queue: .main) {
                                for fileModel in filesArr {
                                    let data = ["fileSize":"\(fileModel.sizeInBytes)",
                                               "fileName" :fileModel.name,
                                               "fileUrl":fileModel.url.path,
                                               "fileType":fileModel.type,
                                               "date_added":getPHAssetDateStr(fileModel.creationDate),
                                               "date_taken":getPHAssetDateStr(fileModel.modificationDate),
                                               "detail_time":""]
                                    files.append(data)
                                    ShareAPI.shared().log(1, "发送的数据:data=didConnect fileModelData：\(data)")
                                    ShareAPI.shared().log(1, "开始发送:fileModel=========\(fileModel)")
                                }
                                isSendTask = true
                                self.sendUsersData[udid] = filesArr
                                self.manger?.sendFiles(udid, files: files)
                            }
                    }
                    else{
                        isSendTask = true
                        self.manger?.sendFiles(udid, files: files)
                    }
                }
                //TODO: 测试异常场景代码 记得删除
//                DispatchQueue.global().async {
//                    var percent = 0.0
//                    while percent<=100 {
//                        percent+=5
//                        Thread.sleep(forTimeInterval: 0.1)
//                        self.didUpdateProgress(udid, percent: percent, stat: [:])
//                        
//                        if percent == 100{
//                            self.didSendEnd(udid, file: "", isFinished: true)
//                            break
//                        }
//                    }
//                }
            }
        }
        
        func getPHAssetDateStr(_ date: Date?) -> String {
            var dateStr = "-1"
            if let date = date {
                let dateInt = Int(date.timeIntervalSince1970 * 1000.0)
                dateStr = "\(dateInt)"
            }
            return dateStr
        }
    }
   
    //Mark: 设备 连接丢失  接收界面需要单独处理  首页 根据传回的 udid  要做判断 是否显示状态
    func didDisconnect(_ udid: String, reason: String, errorCode: Int32) {

        var deviceStatus : DeviceStatus? = nil
        var title = ""
        
        manger?.log(1, " 设备连接状态:didDisconnect:udid:\(udid) reason：\(reason),errorCode:\(errorCode)")
        
        if reason == "peer_disconnected" || reason == "self_disconnected" {
            deviceStatus = .disconnected
            title = ""
        } 
        else if reason == "peer_busy" {
            deviceStatus = .peerBusy
            title = "对方忙".localized
            isSendTask = false
       } 
        else if reason == "trans_error" {
           deviceStatus = .error
           title = "分享失败".localized
           isSendTask = false
           showRecvErrorAlert(title: "接收失败".localized)
           
       }
        else if reason == "timeout"{
           deviceStatus = .timeout
           isSendTask = false
           title = "连接已超时，请重新点击对方设备后再连接".localized
           showRecvErrorAlert(title: "连接已超时，请对端重新点击设备发起连接".localized)
       }
        else if reason == "nospace" {
           deviceStatus = .nospace
           isSendTask = false
           title = "内存不足，分享失败".localized
           showRecvErrorAlert(title: "内存不足，接收失败".localized)
       }
        else if reason == "hotspotOn"{
           isSendTask = false
           return
       }
        else if reason == "ble_ltk"{
            isSendTask = false
            guard let device = self.selectUsers.first(where: {$0.uuid == udid}) else{return}
            device.deviceStatus = .error
            device.progress = 0
            self.nearbyUsersView.updateDeviceStatus(device)
            self.selectUsersData.removeValue(forKey: udid)
            self.selectUsers.removeAll {$0.uuid == udid}
            self.shareFilesSessionId = nil
            let deviceName = device.name
                        
            MIMACDownloadFolderManager().Alert(message: "请尝试在\"设置-蓝牙\"页面中忽略\(deviceName),功能可恢复".localized, oneBtnTit: "取消", twoBtnTit: "去设置") { index in
                if index == 1 {
                    if self.selectUsers.count > 0 {
                        self.sendSelectFile()
                    }
                }else if index == 2 {
                    let url = URL(string: "x-apple.systempreferences:")!
                    NSWorkspace.shared.open(url)
                }
            }
            return
        }
        else if reason == "network_error"{
            receivePageManger?.receptOrNotPopController?.cancelButtonClicked(_:NSButton())
            receivePageManger?.stopReceptPopController?.cancelReceiveShare()
            
            let alert = NSAlert()
            alert.messageText = "连接失败".localized
            alert.informativeText = "建议一端设备开启热点，另一端设备手动连接热点后再试。".localized
            alert.alertStyle = .warning
            alert.addButton(withTitle: "我知道了".localized)
            alert.runModal()
            
            
            isSendTask = false
            guard let device = self.selectUsers.first(where: {$0.uuid == udid}) else{return}
            device.deviceStatus = .error
            device.progress = 0
            self.nearbyUsersView.updateDeviceStatus(device)
            self.selectUsersData.removeValue(forKey: udid)
            self.selectUsers.removeAll {$0.uuid == udid}
            self.shareFilesSessionId = nil
//            return
        }
        
        manger?.cancelShare(udid)
        
        if let selectDevice = self.selectUsers.first(where: {$0.uuid == udid}),let deviceStatus = deviceStatus {
            
            selectDevice.fristSendEnd = true
            selectDevice.deviceStatus = deviceStatus
            selectDevice.progress = 0
            self.nearbyUsersView.updateDeviceStatus(selectDevice)
            self.selectUsers.removeAll {$0.uuid == selectDevice.uuid}
            self.selectUsersData.removeValue(forKey: udid)
            //发送完成清空发送sessionId
            self.shareFilesSessionId = nil
            
            if self.selectUsers.count > 0 {
                self.sendSelectFile()
            }else{
                self.clearSelectUserData()
            }
        }

        if isRecvTask {
            return
        }
 
//        //弹窗后。后台无法操作
//        let _ = AlertManager.showAlert(title: title,cancelTitle: nil, confirmTitle: "知道了".localized) {
//            if let selectDevice = self.selectUsers.first(where: {$0.uuid == udid}),let deviceStatus = deviceStatus {
//                selectDevice.deviceStatus = deviceStatus
//                selectDevice.progress = 0
//                self.nearbyUsersView.updateDeviceStatus(selectDevice)
//                self.selectUsers.removeAll {$0.uuid == selectDevice.uuid}
//                //发送完成清空发送sessionId
//                self.shareFilesSessionId = nil
//                
//                if self.selectUsers.count > 0 {
//                    self.sendSelectFile()
//                }
//              
//                
//            }
//        }
    }
    
    func didMetaRecv(_ udid: String, hwid: String, metadata: [AnyHashable : Any], isCoap: Bool) {
        manger?.log(1, "[UI] [MainWindowController] didMetaRecv udid: \(udid) isCoap: \(isCoap)")
        let senderType = (metadata["sendType"] as? String) ?? ""
        let previewSummary = (metadata["previewSummary"] as? String) ?? ""
        //落盘初始化
        SaveFileHandler.shared.saveFileInit(senderType, previewSummary)
    
        let popupsCall = PagesCall(upWindow:self.view.window!)
        popupsCall.receptOrNotPopShow(udid, metadata: metadata)
        receivePageManger?.stopReceptPopController?.udid = udid
        receivePageManger?.stopReceptPopController?.setConnectMessage(message: isCoap ? "连接中" : "正在连接对方热点")
    }
    
    //Mark:  代理作用不清楚
    func didAccept(_ udid: String) {
        manger?.log(1, " 设备连接状态:didAccept:udid:\(udid)")
        if let userDeviceInfo = self.selectUsers.first(where: {$0.uuid == udid}){
            
            userDeviceInfo.deviceStatus = .connecting
            userDeviceInfo.progress = 0
            self.nearbyUsersView.updateDeviceStatus(userDeviceInfo)
        }
    
    }
        //Mark: 对方拒绝接收
    func didReject(_ udid: String) {
        print("========11")
        self.manger?.log(1, "didReject:udid:\(udid)")
        isSendTask = false

        if let selectDevice = selectUsers.first(where: { $0.uuid == udid}),selectDevice.uuid == udid {
            selectDevice.deviceStatus = .didReject
            selectDevice.progress = 0
            self.nearbyUsersView.updateDeviceStatus(selectDevice)
            self.selectUsers.removeAll { $0.uuid == selectDevice.uuid}
            self.selectUsersData.removeValue(forKey: udid)
            //清空这一次请求sessionId
            self.shareFilesSessionId = nil
            
            if self.selectUsers.count > 0 {
                self.sendSelectFile()
            }else{
                clearSelectUserData()
            }
        }
    }
}

extension MainWindowController:TransDelegate {
    
    //A侧取消接收,返回取消是否成功
    func didIsCancel(_ isCancel: Bool) {
        receivePageManger?.stopReceptPopController?.didIsCancel(isCancel)
    }
    
    //Mark:
    func didRecvAllFiles(_ udid: String, files: [String], totalBytes: NSNumber) {
        self.manger?.log(1, "didRecvAllFiles:udid:\(udid)")
        receivePageManger?.stopReceptPopController?.didRecvAllFiles(udid, files: files, totalBytes: totalBytes)
    }
    
    //Mark:
    func didRecvStart(_ udid: String, file: String) -> String {
        self.manger?.log(1, "didRecvStart:udid:\(udid)")
        let path = receivePageManger?.stopReceptPopController?.didRecvStart(udid, file: file)
        return path ?? ""
    }
    
    //Mark:
    func didRecvData(_ udid: String, data: Data, file: String) {
        self.manger?.log(1, "didRecvData:udid:\(udid)")
    }
    
    //Mark:
    func didRecvEnd(_ udid: String, file: String, isFinished: Bool, fileSize: CLongLong) {
        self.manger?.log(1, "didRecvEnd:udid:\(udid)")
        receivePageManger?.stopReceptPopController?.didRecvEnd(udid, file: file, isFinished: isFinished, fileSize: fileSize)
    }
    
    func didRecvThumb(_ thumbnail: String) {
        self.manger?.log(1, "didRecvThumb")
        receivePageManger?.stopReceptPopController?.didRecvThumb(thumbnail)
    }
    
    func didRecvTime(_ timeInfo: String) {
        self.manger?.log(1, "didRecvTime:\(timeInfo)")
        receivePageManger?.stopReceptPopController?.didRecvTime(timeInfo)
    }
    
    //Mark:
    func didSendStart(_ udid: String, file: String) {
        self.manger?.log(1, "didSendStart:udid:\(udid)")
        print("========8")
        if let selectDevice = self.selectUsers.first(where: {$0.uuid == udid}){
            selectDevice.deviceStatus = .sending
            self.nearbyUsersView.updateDeviceStatus(selectDevice)
        }
    }
    //Mark:
    func didSendData(_ udid: String, data: Data, file: String) {
        self.manger?.log(1, "didSendData:udid:\(udid)")
        print("========3")
    }
    
    //Mark: 发送中  进度 按照100.0 返回的数据  需要自行转化
//    func didSendProgress(_ udid: String, percent: Double) {
    func didUpdateProgress(_ udid: String, percent: Double, stat: [AnyHashable : Any]) {
        if isRecvTask {
            receivePageManger?.stopReceptPopController?.didUpdateProgress(udid, percent: percent, stat: stat)
        } else {
            //TODO 设备id 回传后  要增加过滤条件 // (where: {$0.uuid == udid})
            if let selectDevice = selectUsers.first(where: { $0.uuid == udid}){
                //TODO 进度需要根据底层修改后。转化为 0 - 1的小数
                let percent = percent/100.0
                self.manger?.log(1, "发送中的进度: didUpdateProgress:udid:\(udid)--\(percent)")
                print("测试：进度\(percent)")
                
                selectDevice.deviceStatus = .sending
                selectDevice.progress = percent
                self.nearbyUsersView.updateDeviceStatus(selectDevice)
                return
            }
        }
    }
    
    //Mark: 发送结束后。执行的操作
    func didSendEnd(_ udid: String, file: String, isFinished: Bool) {
        isSendTask = false
        self.manger?.log(1, "发送完成:didSendEnd:udid:\(udid)--\(file)")
            if let selectDevice = selectUsers.first(where: { $0.uuid == udid}){
                if (isFinished) {
                    print("测试：结束")
                    selectDevice.fristSendEnd = true
                    selectDevice.deviceStatus = .completed
                    selectDevice.progress = 1
                    self.nearbyUsersView.updateDeviceStatus(selectDevice)
                    self.saveSendContent(selectUser: selectDevice)
                    
                    self.selectUsers.removeAll {$0.uuid == selectDevice.uuid}
                    self.selectUsersData.removeValue(forKey: udid)
                    //发送完成清空发送sessionId
                    self.shareFilesSessionId = nil
              
                    if self.selectUsers.count > 0 {
                        self.sendSelectFile()
                    }else{
                        clearSelectUserData()
                    }
                }
                else {
                    //self.nearbyUsersView.updateDeviceStatus(selectDevice, status: .sending, getShareProgress("end") ?? 0)
                }
            }
    }
    
    func didLivePhotoReady(_ imagePath: String, videoPath: String) {
        self.manger?.log(1, "didLivePhotoReady:\(imagePath)--videoPath:\(videoPath)")
    }
}
//
extension MainWindowController{
    //给代理发送文件
    func sendSelectFile(){
        
        if let sendUser = self.selectUsers.first {
            self.manger?.log(1, "sendSelectFile:udid:\(sendUser.uuid)--")
            sendUser.deviceStatus = .needreceive
            sendUser.progress = 0
            self.nearbyUsersView.updateDeviceStatus(sendUser)
            self.manger?.log(1, "需要发送的设备的 === \(sendUser.uuid)")
            makeMacDict(urls: selectUsersData[sendUser.uuid] ?? []) { oriDict in
                if  let dict = oriDict {
                    self.manger?.log(1, "发送给设备的设备id === \(sendUser.uuid)")
                    self.manger?.log(1, "发送给设备的数据 === \(String(describing: oriDict))")
                    self.shareFilesSessionId = self.manger?.shareFiles(sendUser.uuid, metadata: dict as [AnyHashable : Any])
                    self.manger?.log(1, "发送事件id === \(self.shareFilesSessionId ?? "")")

                }
            }
//            let oriDict = makeDict(urls: selectUsersData[sendUser.uuid] ?? [])
//            if  let dict = oriDict {
//                self.shareFilesSessionId = self.manger?.shareFiles(sendUser.uuid, metadata: dict as [AnyHashable : Any])
//            }
            
            
            //TODO: 测试异常场景代码 记得删除
//            DispatchQueue.main.asyncAfter(deadline: .now() + 2){
//                self.manger?.sendSDKEvent(0)
////                self.didConnect(sendUser.uuid, status: "joinwififailed")
//                self.didConnect(sendUser.uuid, status: "connected")
////                self.didCancel(sendUser.uuid)
//            }

//            if  let dict = oriDict {
//                self.shareFilesSessionId = self.manger?.shareFiles(sendUser.uuid, metadata: dict as [AnyHashable : Any])
//            }
                
        }else{
            clearSelectUserData()
        }
    }
    func clearSelectUserData(){
        shareFileCome = false
        selectUsersData.removeAll()
        selectUsers.removeAll()
        fileArr.removeAll()
        sendUsersData.removeAll()
        
    }
    
    func endSendAction() {
        isSendTask = false
        for selectUser in self.selectUsers {
            if selectUser.deviceStatus == .needreceive || selectUser.deviceStatus == .connecting || selectUser.deviceStatus == .connected || selectUser.deviceStatus == .sending {
                manger?.cancelShare(selectUser.uuid)
            }
        }

        for deviceInfo in self.deviceInfos {
            if deviceInfo.deviceStatus != .normal {
                deviceInfo.deviceStatus = .normal
                deviceInfo.progress = 0
                self.nearbyUsersView.updateDeviceStatus(deviceInfo)
            }
        }
        clearSelectUserData()
        self.shareFilesSessionId = nil
        ShareExtensionInfoManager.shared.clearShareInfo()
    }
 
    //TODO:  需要 根据底层 文件发送结果进行优化。保存单个文件 单个文件是否成功
    func saveSendContent(selectUser:MIDevice) {
        //保存发送记录
        ShareAPI.shared().log(1, "MainWindowController:saveSendContent:\(selectUser.uuid)")
        var thumbImageItems: [MIThumbImageOperation] = []
        
        let record = MITransferRecord()
        record.deviceId = selectUser.uuid
        record.hwId = selectUser.hwId
        record.deviceName = selectUser.name
        record.transferType = .send
        record.deviceType = selectUser.deviceType
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
                
                let item = MIThumbImageOperation(file: model, filePath: model.fileUrl, fileName: model.fileName)
                thumbImageItems.append(item)
            }
        }else{
//            let fileType = Int(dict["sendType"] as? String ?? "0")
//            
//            if fileType == 0 {
//                for asset in picker?.photoAssets ?? [] {
//                    let model = MITransferFile()
//                    model.fileSize = Int64(asset.fileSize)
//                    model.fileName = asset.fileName
//                    model.fileUrl = asset.filePath
//                    model.fileType = .photoAndVideo
//                    files.append(model)
//                }
//            }
//           
//            else if fileType == 3 {
            
            if let currentFilearr = sendUsersData[selectUser.uuid]{
                for fileModel in currentFilearr {
                    let model = MITransferFile()
                    model.fileSize = fileModel.sizeInBytes
                    model.fileName = fileModel.name
                    model.fileUrl = fileModel.url.path
                    model.fileType = .file
                    // 先判断是否为 Live Photo（苹果特有 UTI）
                    let isLivePhoto = fileModel.type == "com.apple.live-photo"
                    
                    if isLivePhoto {
                        model.fileType = .photoAndVideo
                    } else {
                        // 判断是否为普通照片（UTI 符合 public.image，如 .jpg、.png 等）
                        let isNormalPhoto = UTTypeConformsTo(fileModel.type as CFString, kUTTypeImage)
                        // 判断是否为普通视频（UTI 符合 public.movie，如 .mp4、.mov 等）
                        let isNormalVideo = UTTypeConformsTo(fileModel.type as CFString, kUTTypeMovie)
                        
                        if isNormalPhoto {
                            model.fileType = .photoAndVideo
                        } else if isNormalVideo {
                            model.fileType = .photoAndVideo
                        }
                        // 其他文件（非媒体类型）不统计到 photoCount/videoCount
                    }
                    files.append(model)

                    let item = MIThumbImageOperation(file: model, filePath: model.fileUrl, fileName: model.fileName)
                    thumbImageItems.append(item)
                }
            }
//
//            } else{
//                //通讯录数据组装
//                let model = MITransferFile()
//                model.fileSize = Int64(contacts?["fileSize"] ?? "")
//                model.fileName = contacts?["fileName"] ?? ""
//                model.fileUrl = contacts?["fileUrl"] ?? ""
//                model.fileType = .contacts
//                files.append(model)
//            }
        }

        record.sendContent = files
        do{
            _ = try MIWCDBManager.shared.insertRecord(record)
            
        } catch {
            
        }
        
        if thumbImageItems.count > 0 {
            let batchProcessor = MIBatchProcessor()
            batchProcessor.processBatchWithOperationQueue(items: thumbImageItems) {
                
            }
        }
    }
}

extension MainWindowController {
    func showRecvErrorAlert(title: String) {

        if isRecvTask {
            receivePageManger?.recvErrorPopController?.setMessage(message: title)
        }
    }
}


extension MainWindowController:DFXDelegate{
    func dfxReport(_ log: String) {
        ShareAPI.shared().log(1,"dfxReport data [\(log)]")
        let dfxDBO=BigDataTracDBOMac()
        Task {
            do {
                if NetworkMonitorConnectMac.shared.isReachable {
                    //有网络
                    let bigDataTrac = BigDataTracMac()
                    try await bigDataTrac.sendPostRequest(content: log)
                }else{
                    //无网络
                    dfxDBO.insertDfxData(data: log)
                }
            }catch {
                dfxDBO.insertDfxData(data: log)
            }
        }
    }
}

//
//  MainWindowController+UI.swift
//  MutualInfectionMac
//
//  Created by apple on 2025/10/16.
//

import Foundation
import AppKit
import Cocoa
import CoreServices
import Photos

extension MainWindowController{
    
    //设置背景图片
    func initBkg(){
        // 设置全局背景图
        
        let backgroundView = NSView()
        
        backgroundView.wantsLayer = true
        backgroundView.layer?.contents = NSImage.macBG
        //        backgroundView.imageScaling = .scaleNone
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.layer?.contentsGravity = .resizeAspectFill
        self.view.addSubview(backgroundView, positioned: .below, relativeTo: nil)
        
        
        backgroundView.snp.makeConstraints {
            $0.edges.equalToSuperview()
            //            $0.width.equalTo(screenWidth)
        }
    }
    func setNearbyUsersView() {
        
        self.view.addSubview(nearbyUsersView)
        nearbyUsersView.updateUserInfos([])
        guard let bottomView = bottomView else { return }
        nearbyUsersView.snp.makeConstraints() {
            $0.top.equalTo(self.ownPhotoView.snp.bottom).offset(15)
            $0.leading.equalTo(kOriMainWindowMargin)
            $0.trailing.equalTo(-kOriMainWindowMargin)
            $0.bottom.equalTo(bottomView.snp.top).offset(-20)
        }
        //要发送的拖拽
        self.nearbyUsersView.dragFileToDevice = {[weak self] userInfo,urls in
            ShareAPI().log(1, "要发送的拖拽视频=====\(urls)")
            
            guard let weakSelf = self else { return  }
            
            guard weakSelf.checkAndHandleBluetoothPermission() else {
                weakSelf.manger?.log(1, "没有蓝牙权限:udid:\(userInfo.uuid)")
                return
            }
            
            weakSelf.manger?.log(1, "dragFileToDevice:udid:\(userInfo.uuid)")
            
            if userInfo.deviceStatus != .needreceive && userInfo.deviceStatus != .sending{
                userInfo.deviceStatus = .waiting
                userInfo.progress = 0
                weakSelf.dragFile(user: userInfo, urls: urls)
            }
            if weakSelf.selectUsers.count > 0{
                weakSelf.nearbyUsersView.updateDeviceStatus(userInfo)
            }
            
        }
        self.nearbyUsersView.selectDeviceTapped = {[weak self] userInfo in
            self?.manger?.log(1, "点击的设备 uuid:=====\(userInfo.uuid)")

            guard let weakSelf = self else { return  }
            
            guard weakSelf.checkAndHandleBluetoothPermission() else {
                
                weakSelf.manger?.log(1, "没有蓝牙权限，操作取消:udid:\(userInfo.uuid)")
                return
            }
            weakSelf.manger?.log(1, "selectDeviceTapped:udid:\(userInfo.uuid)")
            // 如果设备已经在队列中，不重复添加
            if !(weakSelf.selectUsers.contains(where: { $0.uuid == userInfo.uuid })) {
                userInfo.deviceStatus = .waiting
                userInfo.progress = 0
                weakSelf.selectUsers.append(userInfo)
                
                if weakSelf.fileArr.isEmpty{
                    weakSelf.updateView(userInfo: userInfo)
                }else{
                    if weakSelf.shareFileCome && weakSelf.shareFilesSessionId == nil {
                        weakSelf.selectUsersData[userInfo.uuid] = weakSelf.fileArr
                        weakSelf.sendSelectFile()
                    }else{
                        weakSelf.updateView(userInfo: userInfo)
                    }
                }
                //设备点击后。立即刷新 设备点击后的状态
                if weakSelf.selectUsers.count > 0 {
                    weakSelf.nearbyUsersView.updateDeviceStatus(userInfo)
                }
            } 
            else {
                if userInfo.deviceStatus == .completed {
                    userInfo.deviceStatus = .waiting
                    userInfo.progress = 0
                    weakSelf.selectUsers.append(userInfo)
                    weakSelf.updateView(userInfo: userInfo)
                    //设备点击后。立即刷新 设备点击后的状态
                    if weakSelf.selectUsers.count > 0 {
                        weakSelf.nearbyUsersView.updateDeviceStatus(userInfo)
                    }
                    return
                }
                
                MIMACDownloadFolderManager().Alert(message: "确认要取消发送吗".localized, oneBtnTit: "继续发送".localized, twoBtnTit: "取消发送".localized) { index in
                    if index == 1 {
                        weakSelf.manger?.log(1, "dragFileToDevice 继续发送:udid:\(userInfo.uuid)")
                    }else if index == 2 {
                        print("用户取消了操作")
                        weakSelf.manger?.log(1, "dragFileToDevice 取消发送:udid:\(userInfo.uuid)")
                        guard let device = weakSelf.selectUsers.first(where: { $0.uuid == userInfo.uuid}) else { return }
                        if device.deviceStatus != .completed {
                            weakSelf.manger?.cancelShare(userInfo.uuid)
                            
                            weakSelf.selectUsers.removeAll { $0.uuid == userInfo.uuid}
                            weakSelf.shareFilesSessionId = nil
                            if weakSelf.selectUsers.isEmpty{
                                weakSelf.clearSelectUserData()
                            }else{
                                if device.deviceStatus == .needreceive || device.deviceStatus == .sending{
                                    weakSelf.sendSelectFile()
                                }
                            }
                            userInfo.deviceStatus = .cancelled
                            userInfo.progress = 0
                            weakSelf.nearbyUsersView.updateDeviceStatus(userInfo)
//                            weakSelf.updateView(userInfo: userInfo)
                        }
                    }
                }
                
                // MARK: - 演示方法
                //                let _ = AlertManager.showAlert(title: "确定要取消发送吗？", cancelTitle: "取消发送".localized,cancelAction: {
                //TODO：如果设备是在发送中。请求先取消   然后在代理中移除设备
                
                //                    if weakSelf.selectUsers.first(where: { $0.uuid == userInfo.uuid})?.deviceStatus != .completed {
                
                //weakSelf.manger?.cancelShare(userInfo.uuid)
                //if weakSelf.selectUsers.first?.device.deviceStatus == .connecting {
                //    // 没有传输
                //    weakSelf.manger?.cancelShare(userInfo.device.uuid)
                //} else {
                //    // 传输中
                //    weakSelf.manger?.cancelShare(userInfo.device.uuid)
                //}
                
                //                        weakSelf.selectUsers.removeAll { $0.uuid == userInfo.uuid}
                //                        weakSelf.shareFilesSessionId = nil
                //                        userInfo.deviceStatus = .cancelled
                //                        userInfo.progress = 0
                //                        weakSelf.nearbyUsersView.updateDeviceStatus(userInfo)
                //                        weakSelf.updateView(userInfo: userInfo)
                //                    }else{
                //                        self?.view.makeToast("取消失败".localized, duration: 2.0, point: self?.view.center ?? .zero, title: nil, image: nil) { didTap in
                //                           
                //                        }
                //                    }
                //                } ,confirmTitle: "继续发送".localized) {
                //                }
            }
        }
    }
    
    func updateView(userInfo:MIDevice){
        
        
        self.manger?.log(1,"我要发送...之前的发送id\(self.shareFilesSessionId ?? "不存在")")
        
        //self.selectUsers.count > 0 已经选好了设备
        //self.shareFilesSessionId == nil 不存在 正在发送的事件
        
        
        //发送事件存在  设备不存在 不可能发生事件
        //发送事件不存在 设备不存在 不做任何处理
        
        //发送事件存在。 设备存在 不做任何处理
        //发送事件不存在  设备存在
        
        //存在设备。不存在发送事件
        if self.shareFilesSessionId == nil &&  self.selectUsers.count > 0 {
            //            //以下 解决是否需要直接发送
            if ShareExtensionInfoManager.shared.shareInfoModel != nil || self.fileType != -1{
                self.sendSelectFile()
            }else{
                selectFile(user: userInfo)
            }
        }else{
            if ((self.selectUsersData[userInfo.uuid]?.isEmpty) != nil) {
                self.sendSelectFile()
            }else{
                selectFile(user: userInfo)
            }
        }
    }
}


extension MainWindowController {
    func dragFile(user:MIDevice,urls:[URL]){
        var filearr = selectUsersData[user.uuid] ?? []
//        if !(self.selectUsers.contains(where: { $0.uuid == user.uuid })) {
//            self.selectUsers.append(user)
//        }
        filearr.append(contentsOf: urls)
        selectUsersData[user.uuid] = filearr
        if !(self.selectUsers.contains(where: { $0.uuid == user.uuid })) {
            self.selectUsers.append(user)
            if self.shareFilesSessionId == nil{
                sendSelectFile()
            }
        }
    }
    
    func selectFile( user:MIDevice) {
        openPanel = NSOpenPanel()
        openPanel?.allowsMultipleSelection = true // 允许选择多个文件
        openPanel?.canChooseDirectories = true // 不能选择目录
        openPanel?.canChooseFiles = true // 可以选择文件
        openPanel?.title = "选择要发送的文件".localized
        openPanel?.prompt = "发送".localized  // 修改主按钮文字
        openPanel?.allowedFileTypes = nil // 允许所有类型
        currentSlectUser = user
        preView?.isHidden = false
        globalDragEnabled = false
        self.manger?.log(1, "打开文件选择面板，用户: \(user.uuid)")
        openPanel?.begin{[weak self] response in
            guard let self = self else { return }
            if response == .OK,let urls = self.openPanel?.urls {
                
                self.manger?.log(1, "用户选择了文件，数量: \(urls.count)")
                
                for url in urls {
                    // 输出文件路径
                    self.manger?.log(1, "输出文件路径: \(url.path)")
                    if iCloudFileUtility.isPhotoLibraryPlaceholder(at: url) {
                        let alert = NSAlert()
                        alert.informativeText = "非本地文件，请先存到本地后再重试".localized
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "我知道了".localized)
                        alert.runModal()
                        self.updateViewNormal(user: user)
                        self.currentSlectUser?.fristSendEnd = false
                        self.currentSlectUser = nil
                        self.openPanel = nil
                        self.preView?.isHidden = true
                        globalDragEnabled = true
                        return
                    }

                }
                self.selectUsersData[user.uuid] = urls
//                self.fileArr = urls
                if self.selectUsersData.count == 1  {
                    self.sendSelectFile()
                }
            }
            else{
                self.updateViewNormal(user: user)
            }
            self.currentSlectUser?.fristSendEnd = false
            self.currentSlectUser = nil
            self.openPanel = nil
            self.preView?.isHidden = true
            globalDragEnabled = true
        }
    }
    func onlyClosePanel(){
        
        guard let panel = openPanel else { return }
        // 关闭模态弹窗（会触发 runModal() 返回 .cancel 或自定义响应）
        //        if let window = NSApp.mainWindow {
        //            window.endSheet(panel)
        //        }
        self.currentSlectUser?.fristSendEnd = false
        //会走弹窗取消逻辑，清除设备信息
        panel.cancel(nil)
        self.preView?.isHidden = true
        globalDragEnabled = true
//        if let use = currentSlectUser{
//            use.deviceStatus = .normal
//            use.progress = 0
//            selectUsers.removeAll {$0.uuid == use.uuid}
//            nearbyUsersView.updateDeviceStatus(use)
//        }
        currentSlectUser = nil
        openPanel = nil
    }
    func closePanel() {
        
        onlyClosePanel()
        
        // 如果还有模态窗口，延迟执行
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showDeviceLostAlert()
        }
    }
    func showDeviceLostAlert() {
        let alert = NSAlert()
        alert.messageText = "设备已断开".localized
        alert.informativeText = "链接的设备已丢失，文件选择已取消。".localized
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定".localized)
        //        if let window = NSApp.mainWindow {//其他页面close影响这里
        //                alert.beginSheetModal(for: window) { _ in
        //                    // 可选：处理用户点击确定后的逻辑
        //                }
        //            } else {
        alert.runModal() // 备用方案
        //            }
    }
    func makeDict(urls:[URL]) -> [String : Any]? {
        // 首先检查是否有包文件，如果有则弹窗并返回nil
        if containsPackage(in: urls) {
            self.clearSelectStatus()
            showPackageNotSupportedAlert()
            return nil
        }
        var totalSize : Int64 = 0
        //var photopicCount : String = ""
        var photoCount: Int = 0
        var videoCount: Int = 0
        var vCardCount: Int = 0
        
        var itemCount = 0
        let contactsCount = 0
        var fileCount = 0
        let folderCount = countFolders(in: urls)
        var previewSummary : [String:Int] = [:]
        //        let funcfileArr = urls.map{parseFileAttributes(url:$0)}
        
        let (topLevelFiles, allFiles, totalFileCount) = parseFileAttributesSeparately(from: urls)
        itemCount = topLevelFiles.count
        fileCount = totalFileCount
        totalSize = allFiles.map { $0.sizeInBytes }.reduce(0, +)
        
        for file in topLevelFiles {
            if let fileType =  file.name.components(separatedBy: ".").last{
                if let filetypeNum = previewSummary[".\(fileType)"]  {
                    previewSummary[".\(fileType)"] = filetypeNum + 1
                }else{
                    previewSummary[".\(fileType)"] = 1
                }
            }
            let uti = file.type   // 通过 UTI 判断类型（最可靠）
            // 先判断是否为 Live Photo（苹果特有 UTI）
            let isLivePhoto = uti == "com.apple.live-photo"
            
            if isLivePhoto {
                //                    livePhotoCount += 1  // 累加 Live Photo 明细
                photoCount += 1      // Live Photo 计入总照片数
            }
            else if UTTypeConformsTo(uti as CFString, kUTTypeVCard) {
                vCardCount += 1
                print("这是一个 vCard 文件")
            } else {
                // 判断是否为普通照片（UTI 符合 public.image，如 .jpg、.png 等）
                let isNormalPhoto = UTTypeConformsTo(uti as CFString, kUTTypeImage)
                // 判断是否为普通视频（UTI 符合 public.movie，如 .mp4、.mov 等）
                let isNormalVideo = UTTypeConformsTo(uti as CFString, kUTTypeMovie)
                
                if isNormalPhoto {
                    photoCount += 1  // 普通照片计入总照片数
                } else if isNormalVideo {
                    videoCount += 1  // 普通视频计入视频数
                }
                // 其他文件（非媒体类型）不统计到 photoCount/videoCount
            }
            
        }
        
        
        let previewSummaryStr = dictionaryToJSON(previewSummary).replacingOccurrences(of: "\n", with: "")
        
        
        self.manger?.log(1, "makeDict previewSummaryStr: \(previewSummaryStr)")
        // -1:invalid，0:photo_asset,2:album,3:file_manager_file,4:folder,5:atomic_service,6:atomic_card,7:hap,8:sand_box_file,9:text,10:link,11:legacy_photo_asset,12:legacy_sand_box_file
        var sendType = 0
        if folderCount>0 {
            sendType = 4
        }else if photoCount + videoCount == itemCount {
            sendType = 0
        }else if vCardCount == itemCount {
            sendType = 8
            itemCount = 1
        }else {
            sendType = 3
        }
        var dict = ["sendType":"\(sendType)",//0媒体类型 3文件类型
                    "senderName":Gloable.userName,//设备名称
                    "itemCount":"\(itemCount)",//对应的数量
                    "totalSize":"\(totalSize)",
                    "fileCount":(sendType == 0 && itemCount <= 500) ? "0" : "\(fileCount)",//文件总数
                    "folderCount":"\(folderCount)",//文件夹个数
                    "previewSummary":previewSummaryStr,
                    "photoCount":"\(photoCount)",
                    "videoCount":"\(videoCount)",
                    "contactsCount":"\(contactsCount)"
        ] as [String : Any]
//        if UserDefaults.standard.bool(forKey: speedMode){
//            dict["isHighSpeed"] = "1"
//        }
        self.manger?.log(1, "makeDict dict: \(dict)")
        return dict
    }
    
    func makeMacDict(urls:[URL], complete: @escaping ([String : Any]?) -> Void) {
        // 首先检查是否有包文件，如果有则弹窗并返回nil
        if containsPackage(in: urls) {
            self.clearSelectStatus()
            showPackageNotSupportedAlert()
            return
        }
        
        parseMacFileAttributesSeparately(from: urls) { [weak self] topLevelFiles, allFiles, totalFileCount  in
            let dic = self?.changeDataDic(urls: urls, topLevelFiles: topLevelFiles, allFiles: allFiles, totalFileCount: totalFileCount)
            complete(dic)
        }
    }
    
    private func checkICloudFile(_ url: URL){
        let path = url.path
        let isCloud = path.contains("com~apple~Cloud")
        if isCloud && !isFileDownloaded(url){
            do {
                
                    manger?.log(1, "iCloud准备下载\(path)")
                // 尝试直接读取文件数据（系统会自动触发下载）
                _ = try Data(contentsOf: url)
                manger?.log(1, "iCloud下载完成\(path)")
                
            } catch {
                manger?.log(1, "iCloud下载失败: \(error.localizedDescription)")
            }
        }
    }
    private func isFileDownloaded(_ url: URL) -> Bool {
        do {
            // 方法1：尝试获取文件大小，如果为0或很小，可能是占位符
            let resourceValues = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            
            if let status = resourceValues.ubiquitousItemDownloadingStatus {
                // .current: 已下载且是最新版本
                // .downloaded: 已下载
                // .notDownloaded: 仅存在于云端
                return status == .current || status == .downloaded
            }
            return true
        } catch {
            // 方法2：文件不存在或无法访问，肯定没下载
            
                manger?.log(1, "iCloud未下载: \(error.localizedDescription)")
            return false
        }
    }
    func changeDataDic(urls:[URL], topLevelFiles: [FileModel], allFiles: [FileModel], totalFileCount: Int) -> [String : Any]? {
        var totalSize : Int64 = 0
        //var photopicCount : String = ""
        var photoCount: Int = 0
        var videoCount: Int = 0
        var vCardCount: Int = 0
        
        var itemCount = 0
        let contactsCount = 0
        var fileCount = 0
        let folderCount = countFolders(in: urls)
        var previewSummary : [String:Int] = [:]
        
        itemCount = topLevelFiles.count
        fileCount = totalFileCount
        totalSize = allFiles.map { $0.sizeInBytes }.reduce(0, +)
        print("要发送的文件的总大小 === \(totalSize)")
        for file in topLevelFiles {
            if let fileType =  file.name.components(separatedBy: ".").last{
                if let filetypeNum = previewSummary[".\(fileType)"]  {
                    previewSummary[".\(fileType)"] = filetypeNum + 1
                }else{
                    previewSummary[".\(fileType)"] = 1
                }
            }
            let uti = file.type   // 通过 UTI 判断类型（最可靠）
            // 先判断是否为 Live Photo（苹果特有 UTI）
            let isLivePhoto = uti == "com.apple.live-photo"
            
            if isLivePhoto {
                //                    livePhotoCount += 1  // 累加 Live Photo 明细
                photoCount += 1      // Live Photo 计入总照片数
            }
            else if UTTypeConformsTo(uti as CFString, kUTTypeVCard) {
                vCardCount += 1
                print("这是一个 vCard 文件")
            } else {
                // 判断是否为普通照片（UTI 符合 public.image，如 .jpg、.png 等）
                let isNormalPhoto = UTTypeConformsTo(uti as CFString, kUTTypeImage)
                // 判断是否为普通视频（UTI 符合 public.movie，如 .mp4、.mov 等）
                let isNormalVideo = UTTypeConformsTo(uti as CFString, kUTTypeMovie)
                
                if isNormalPhoto {
                    photoCount += 1  // 普通照片计入总照片数
                } else if isNormalVideo {
                    videoCount += 1  // 普通视频计入视频数
                }
                // 其他文件（非媒体类型）不统计到 photoCount/videoCount
            }
            
        }
        
        
        let previewSummaryStr = dictionaryToJSON(previewSummary).replacingOccurrences(of: "\n", with: "")
        
        
        self.manger?.log(1, "makeDict previewSummaryStr: \(previewSummaryStr)")
        // -1:invalid，0:photo_asset,2:album,3:file_manager_file,4:folder,5:atomic_service,6:atomic_card,7:hap,8:sand_box_file,9:text,10:link,11:legacy_photo_asset,12:legacy_sand_box_file
        var sendType = 0
        if folderCount>0 {
            sendType = 4
        }else if photoCount + videoCount == itemCount {
            sendType = 0
        }else if vCardCount == itemCount {
            sendType = 8
            itemCount = 1
        }else {
            sendType = 3
        }
        var dict = ["sendType":"\(sendType)",//0媒体类型 3文件类型
                    "senderName":Gloable.userName,//设备名称
                    "itemCount":"\(itemCount)",//对应的数量
                    "totalSize":"\(totalSize)",
                    "fileCount":(sendType == 0 && itemCount <= 500) ? "0" : "\(fileCount)",//文件总数
                    "folderCount":"\(folderCount)",//文件夹个数
                    "previewSummary":previewSummaryStr,
                    "photoCount":"\(photoCount)",
                    "videoCount":"\(videoCount)",
                    "contactsCount":"\(contactsCount)"
        ] as [String : Any]
//        if UserDefaults.standard.bool(forKey: speedMode){
//            dict["isHighSpeed"] = "1"
//        }
        self.manger?.log(1, "makeDict dict: \(dict)")
        return dict
    }
    func parseFileAttributesSeparately(from urls: [URL]) -> (topLevelFiles: [FileModel], allFiles: [FileModel], totalCount: Int) {
        var topLevelFiles: [FileModel] = []
        var allFiles: [FileModel] = []
        var totalCount = 0
        
        for url in urls {
            // 检查是否是文件夹
            var isDirectory: ObjCBool = false
            let hasAccess = url.startAccessingSecurityScopedResource()
            
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                // 如果是文件夹，递归获取其中的内容
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
                
                do {
                    let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
                    let (_, subFiles, subCount) = parseFileAttributesSeparately(from: contents)
                    allFiles.append(contentsOf: subFiles)
                    totalCount += subCount
                } catch {
                    print("Error reading directory: \(error)")
                }
            } else {
                // 如果是文件，解析文件属性
                let attributes = parseFileAttributes(url: url)
                topLevelFiles.append(attributes)
                allFiles.append(attributes)
                totalCount += 1
                
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
        }
        
        return (topLevelFiles, allFiles, totalCount)
    }
    func parseMacFileAttributesSeparately(from urls: [URL],complete :@escaping ([FileModel], [FileModel], Int) -> Void) {
        var topLevelFiles: [FileModel] = []
        var allFiles: [FileModel] = []
        var totalCount = 0
        let dispatchMacGroup = DispatchGroup()
        
        for url in urls {
            // 检查是否是文件夹
            var isDirectory: ObjCBool = false
            let hasAccess = url.startAccessingSecurityScopedResource()
            
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                // 如果是文件夹，递归获取其中的内容
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
                
                do {
                    let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
                    //                    let (_, subFiles, subCount) = parseFileAttributesSeparately(from: contents)
                    dispatchMacGroup.enter()
                    parseMacFileAttributesSeparately(from: contents) { _, subFiles, subCount in
                        allFiles.append(contentsOf: subFiles)
                        totalCount += subCount
                        dispatchMacGroup.leave()
                    }
                } catch {
                    print("Error reading directory: \(error)")
                }
            } 
            else {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
                // 如果是文件，解析文件属性
                //                let attributes = parseFileAttributes(url: url)
                dispatchMacGroup.enter()
                parseMacFileAttributes(url: url) { attributes in
                    totalCount += 1
                    
                    topLevelFiles.append(attributes)
                    allFiles.append(attributes)
                    dispatchMacGroup.leave()
                }
            }
        }
        
        dispatchMacGroup.notify(queue: .main) {
            complete(topLevelFiles, allFiles, totalCount)
        }
    }
    
    func dictionaryToJSON(_ dictionary: [String: Any]) -> String {
        if let jsonData = try? JSONSerialization.data(withJSONObject: dictionary, options: .prettyPrinted) {
            return String(data: jsonData, encoding: .utf8) ?? ""
        }
        return ""
    }
    
    func parseFileAttributes( url: URL) -> FileModel {
        
        var fileModel = FileModel()
        
        // 文件名
        let fileName = url.lastPathComponent
        print("文件名: \(fileName)")
        fileModel.name = fileName
        
        // 文件大小
        if let size = getItemSize(for: url) {
            let sizeMB = Double(size) / (1024 * 1024)
            print("大小: \(size) 字节 (\(String(format: "%.2f", sizeMB)) MB)")
            fileModel.size = formatFileSize(byteSize: Int64(size))
            fileModel.sizeInBytes = Int64(size)
        }
        
        // 创建日期
        if let createDate = getFileDates(for: url).creationDate {
            print("创建日期: \((createDate))")
            fileModel.creationDate = createDate
        }
        
        // 修改日期
        if let modifyDate = getFileDates(for: url).modificationDate {
            print("修改日期: \((modifyDate))")
            fileModel.modificationDate = modifyDate
        }
        
        // 文件类型（UTI）
        //        if let fileType = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier {
        //            print("文件类型(UTI): \(fileType)")
        //            fileModel.type = fileType
        //        }
        fileModel.type = getFileType(for: url)
        
        fileModel.url = url
//        print("安全路径: \(url.path)")
        
        return fileModel
    }
    func parseMacFileAttributes( url: URL,complete: @escaping (FileModel) -> Void) {
        
        var fileModel = FileModel()
        
        // 文件名
        let fileName = url.lastPathComponent
        ShareAPI.shared().log(1, "文件名: \(fileName)")
        fileModel.name = fileName
        

        // 文件大小
        if let size = getItemSize(for: url) {
            let sizeMB = Double(size) / (1024 * 1024)
            ShareAPI.shared().log(1, "文件原始大小: \(size) 字节 (\(String(format: "%.2f", sizeMB)) MB)")
            fileModel.size = formatFileSize(byteSize: Int64(size))
            fileModel.sizeInBytes = Int64(size)
        }
        
        // 创建日期
        if let createDate = getFileDates(for: url).creationDate {
            ShareAPI.shared().log(1, "创建日期: \((createDate))")
            fileModel.creationDate = createDate
        }
        
        // 修改日期
        if let modifyDate = getFileDates(for: url).modificationDate {
            ShareAPI.shared().log(1, "修改日期: \((modifyDate))")
            fileModel.modificationDate = modifyDate
        }
        
        fileModel.type = getFileType(for: url)
        let url = URL(fileURLWithPath: url.path)
        
        // 文件路径（沙盒内的安全路径）
        fileModel.url = url
        if LivePhotoAddressFetcher().isFromSystemPhotoLibrary(url) == false {
            if url.isImageFile {
                let hdrUrl = LivePhotoAddressFetcher().getHDRimgUrl(url: url)
                fileModel.url = hdrUrl
            }
            complete(self.changeModelData(fileModel))
            return
        }
        // MARK: - 通过路径获取uuid,通过uuid获取图库中对应图片的asset数据
        if let uuid = LivePhotoAddressFetcher().extractUUIDFromPath(url.path),let asset = LivePhotoAddressFetcher().fetchPhotoAsset(uuid) {
            fileModel.name = PHAssetResource.assetResources(for: asset).first!.originalFilename
            // MARK: - 通过assset数据判断是否是实况图
            if LivePhotoAddressFetcher().checkAssetIsPhotoLive(asset) {
                ShareAPI.shared().log(1, "通过asset查找实况图===\(uuid)")
                HongmengDynamicImageConverter.shared.convertLivePhoto(asset) { result in
                    switch result {
                    case .success(let success):
                        guard let imageURL = success.first, let videoURL = success.last else {
                            fileModel.url = url
                            complete(self.changeModelData(fileModel))
                            return
                        }
                        let livePhotoTmpStr = SharedFilesManager.getLiveURL(asset: asset)
                        /// 将 Live 拆分好的视频和图片传入C++合成 H 端的动图并保存到指定路径下
                        let isSucc = ShareAPI.shared().createPlayableLivePhoto(withImagePath: imageURL.path, videoPath: videoURL.path, livePhotoPath: livePhotoTmpStr)
                        if isSucc {
                            fileModel.url = URL(string: livePhotoTmpStr) ?? url
                            let size = self.getItemSize(for: fileModel.url)
                            let sizeMB = Double(size ?? 0) / (1024 * 1024)
                            ShareAPI.shared().log(1, "转换后实况图：大小: \(size ?? 0) 字节 (\(String(format: "%.2f", sizeMB)) MB)")
                            fileModel.size = formatFileSize(byteSize: Int64(size ?? 0))
                            fileModel.sizeInBytes = Int64(size ?? 0)
                            ShareAPI.shared().log(1, "实况图转换成功")
                            complete(self.changeModelData(fileModel))
                        } else {
                            fileModel.url = url
                            ShareAPI.shared().log(1, "实况图转换失败")
                            complete(self.changeModelData(fileModel))
                        }
                    case .failure(let failure):
                        /// 拆分失败
                        ShareAPI.shared().log(1, "发生错误 - 实况图拆分失败==\(failure)")
                        fileModel.url = url
                        complete(self.changeModelData(fileModel))
                    }
                }
            }
            else {
                MainWindowController().getShareableFileURL(for: asset) { targetURL, originalFilename in
                    LivePhotoAddressFetcher.isHDRAssetAsync(asset) { isHdr in
                        if isHdr {
                            let hdrUrl = LivePhotoAddressFetcher().urlToHDRimgUrl(url: targetURL!)
                            fileModel.url = hdrUrl
                            complete(self.changeModelData(fileModel))
                            return
                        }else{
                            fileModel.url = targetURL!
                            complete(fileModel)
                            return 
                        }
                    }
                }
            }   
        }
        else{
            if url.isImageFile {
                let hdrUrl = LivePhotoAddressFetcher().getHDRimgUrl(url: url)
                fileModel.url = hdrUrl
                complete(changeModelData(fileModel)) 
                return
            }else{
                fileModel.url = url
                complete(changeModelData(fileModel))
                return 
            }
        }
//        print("安全路径: \(url.path)")
    }
    /// 获取文件名、大小、日期、类型
    func changeModelData(_ oldFileModel: FileModel) -> FileModel {
        var fileModel = oldFileModel
        let url = fileModel.url
        
        // 文件名
        let fileName = url.lastPathComponent
        ShareAPI.shared().log(1, "文件名: \(fileName)")
        fileModel.name = fileName
        
        // 文件大小
        if let size = getItemSize(for: url) {
            let sizeMB = Double(size) / (1024 * 1024)
            ShareAPI.shared().log(1, "转换之后大小: \(size) 字节 (\(String(format: "%.2f", sizeMB)) MB)")
            fileModel.size = formatFileSize(byteSize: Int64(size))
            fileModel.sizeInBytes = Int64(size)
        }
        
//        // 创建日期
//        if let createDate = getFileDates(for: url).creationDate {
//            print("创建日期: \((createDate))")
//            fileModel.creationDate = createDate
//        }
//        
//        // 修改日期
//        if let modifyDate = getFileDates(for: url).modificationDate {
//            print("修改日期: \((modifyDate))")
//            fileModel.modificationDate = modifyDate
//        }
        
        fileModel.type = getFileType(for: url)
        
        return fileModel
    }
    
    func updateViewNormal(user:MIDevice){
        //单个刷新 避免 一次刷新。界面闪动
//        for selectUser in self.selectUsers {
//            selectUser.deviceStatus = .normal
//            selectUser.progress = 0
//            self.nearbyUsersView.updateDeviceStatus(selectUser)
//        }
        //        self.selectUsers.removeAll()
//        self.clearSelectUserData()
        
        user.deviceStatus = .normal
        user.progress = 0
        self.nearbyUsersView.updateDeviceStatus(user)
        selectUsersData.removeValue(forKey: user.uuid)
        selectUsers.removeAll { $0.uuid == user.uuid }
        sendUsersData.removeValue(forKey: user.uuid)
        
        //self.nearbyUsersView.updateUserInfos(self.deviceInfos)
    }
    /// 统计URL数组中文件夹（目录）的数量
    /// - Parameter fileURLs: 待检查的文件/文件夹URL数组
    /// - Returns: 文件夹的数量
    func countFolders(in fileURLs: [URL]) -> Int {
        var folderCount = 0
        
        for url in fileURLs {
            // 1. 处理沙盒权限（沙盒外的文件需要临时访问权限）
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource() // 用完释放权限
                }
            }
            
            // 2. 检查是否为文件夹（目录）
            do {
                // 获取 "是否为目录" 的属性（isDirectoryKey）
                let resourceValues = try url.resourceValues(forKeys: Set([.isDirectoryKey]))
                if let isDirectory = resourceValues.isDirectory, isDirectory {
                    folderCount += 1 // 是文件夹则计数+1
                }
            } catch {
                print("无法判断文件类型（\(url.path)）：\(error.localizedDescription)")
                // 忽略错误（如文件不存在、无权限等，不纳入统计）
            }
        }
        
        return folderCount
    }
    func getItemSize(for url: URL) -> Int? {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return nil
        }
        
        if isDirectory.boolValue {
            // 处理文件夹
            return getFolderSize(for: url)
        } else {
            // 处理文件
            return SharedFilesManager.shared.getFileSize(for: url)
        }
    }
    
    // 辅助函数：获取文件夹大小（同步）
    private func getFolderSize(for folderURL: URL) -> Int? {
        var totalSize: Int = 0
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(at: folderURL,
                                                      includingPropertiesForKeys: [.fileSizeKey],
                                                      options: [.skipsHiddenFiles]) else {
            return nil
        }
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                if let fileSize = resourceValues.fileSize {
                    totalSize += fileSize
                }
            } catch {
                print("获取文件大小失败: \(error) for \(fileURL)")
            }
        }
        
        return totalSize
    }
    func getFileDates(for fileURL: URL) -> (creationDate: Date?, modificationDate: Date?) {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let creationDate = attributes[.creationDate] as? Date
            let modificationDate = attributes[.modificationDate] as? Date
            
            return (creationDate, modificationDate)
            
        } catch {
            ShareAPI.shared().log(1, "FileManager 获取日期失败: \(error.localizedDescription)")
        }
        let hasAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                fileURL.stopAccessingSecurityScopedResource() // 用完释放权限
            }
        }
        do {
            // 同时读取创建日期和修改日期的属性
            let resourceKeys: [URLResourceKey] = [.creationDateKey, .contentModificationDateKey]
            let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            
            return (
                creationDate: resourceValues.creationDate,
                modificationDate: resourceValues.contentModificationDate
            )
        } catch {
            ShareAPI.shared().log(1, "获取文件日期失败：\(error.localizedDescription)")
            return (nil, nil)
        }
    }
    
    // 通过文件结构检测包
    func isPackageByStructure(_ url: URL) -> Bool {
        let fileManager = FileManager.default
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }
        
        // 检查常见的包目录结构
        let commonPackageContents = [
            "Contents/Info.plist",           // macOS App
            "Contents/MacOS",                // macOS App 可执行文件目录
            "Info.plist",                    // iOS App 等
            "Contents/Resources",            // 资源目录
            "Contents/Frameworks",           // 框架目录
            "Contents/PlugIns",              // 插件目录
            "project.pbxproj",               // Xcode 项目
            "contents.xcworkspacedata"       // Xcode 工作空间
        ]
        
        for content in commonPackageContents {
            let testPath = url.appendingPathComponent(content).path
            if fileManager.fileExists(atPath: testPath) {
                return true
            }
        }
        
        // 检查是否有特定的包标识文件
        let packageMarkers = [
            "PkgInfo",                      // 包信息文件
            "version.plist",                // 版本信息
            "CodeResources"                 // 代码签名资源
        ]
        
        for marker in packageMarkers {
            let markerPath = url.appendingPathComponent(marker).path
            if fileManager.fileExists(atPath: markerPath) {
                return true
            }
        }
        
        return false
    }
    func isPackageFile(_ url: URL) -> Bool {
        self.manger?.log(1, "[UI] [MainWindowController+UI] isPackageFile url: \(url)")
        let fileManager = FileManager.default
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        checkICloudFile(url)
        do {
            // 1. 首先通过资源值检测（最可靠）
            let resourceValues = try url.resourceValues(forKeys: [.isPackageKey, .typeIdentifierKey])
            
            // 如果系统明确标记为包，直接返回 true
            if resourceValues.isPackage == true {
                self.manger?.log(1, "[UI] [MainWindowController+UI] isPackageFile isPackage is true")
                return true
            }
            
            // 2. 通过统一类型标识符检测
            if let typeIdentifier = resourceValues.typeIdentifier {
                self.manger?.log(1, "[UI] [MainWindowController+UI] isPackageFile typeIdentifier: \(typeIdentifier)")
                // 检查是否是包类型
                if UTTypeConformsTo(typeIdentifier as CFString, kUTTypeBundle) ||
                    UTTypeConformsTo(typeIdentifier as CFString, kUTTypeApplicationBundle) ||
                    UTTypeConformsTo(typeIdentifier as CFString, kUTTypeFramework) {
                    self.manger?.log(1, "[UI] [MainWindowController+UI] isPackageFile 是包类型")
                    return true
                }
                
                // 检查其他已知的包类型
                let packageTypeIdentifiers = [
                    "com.apple.application-bundle",
                    "com.apple.framework",
                    "com.apple.plugin",
                    "com.apple.preference-pane",
                    "com.apple.quicklook-generator",
                    "com.apple.xcode.project",
                    "com.apple.workspace",
                    "com.apple.interface-builder.document"
                ]
                
                if packageTypeIdentifiers.contains(typeIdentifier) {
                    return true
                }
            }
            
            // 3. 通过文件结构检测（即使重命名也能检测）
            //            if isPackageByStructure(url) {
            //                return true
            //            }
            
            // 4. 通过扩展名检测（作为后备方案）
            //            let pathExtension = url.pathExtension.lowercased()
            //            let packageExtensions: Set<String> = [
            //                "app", "framework", "bundle", "plugin",
            //                "component", "xcodeproj", "xcworkspace",
            //                "workflow", "prefPane", "qlgenerator",
            //                "appex", "dmg", "pkg"
            //            ]
            
            //            return packageExtensions.contains(pathExtension)
            return false
            
        } catch {
            print("无法获取包属性: \(error)")
            return false
        }
    }
    func containsPackage(in urls: [URL]) -> Bool {
        
        self.manger?.log(1, "开始包检测，文件数量: \(urls.count)")
        for url in urls {
            self.manger?.log(1, "开始检测到文件: \(url.lastPathComponent), 路径: \(url.path)")
            if isPackageFile(url) {
                self.manger?.log(1, "检测到包文件: \(url.lastPathComponent), 路径: \(url.path)")
                return true
            }
            
            // 如果是文件夹，递归检查其中的内容
            var isDirectory: ObjCBool = false
            let hasAccess = url.startAccessingSecurityScopedResource()
            
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                // 先检查这个文件夹本身是否是包
                if isPackageFile(url) {
                    if hasAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                    
                    self.manger?.log(1, "文件夹本身是包: \(url.lastPathComponent)")
                    return true
                }
                
                // 如果不是包，再递归检查内容
                do {
                    let contents = try FileManager.default.contentsOfDirectory(
                        at: url,
                        includingPropertiesForKeys: [.isDirectoryKey],
                        options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
                    )
                    
                    if hasAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                    self.manger?.log(1, "递归检查文件夹内容: \(url.lastPathComponent), 子文件数: \(contents.count)")
                    
                    // 递归检查子内容
                    if containsPackage(in: contents) {
                        return true
                    }
                    
                } catch {
                    self.manger?.log(1, "读取目录内容失败: \(error), 路径: \(url.path)")
                    if hasAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            } else {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
        }
        self.manger?.log(1, "包检测完成，未发现包文件")
        return false
    }
    func showPackageNotSupportedAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "不支持发送应用程序包".localized
            alert.informativeText = "检测到应用程序(.app)、项目文件或其他包文件，这些文件类型暂不支持发送。\n\n请选择普通文件或文件夹。".localized
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定".localized)
            
            //            if let window = NSApp.mainWindow {
            //                alert.beginSheetModal(for: window) { _ in
            //                    // 清理选择状态
            //                    
            //                }
            //            } else {
            alert.runModal()
            //            }
        }
    }
    func clearSelectStatus() {
        if let user = selectUsers.first{
            user.deviceStatus = .normal
            self.nearbyUsersView.updateUserInfos(self.deviceInfos)
        }
        
        self.clearSelectUserData()
    }
    
    func getFileType(for url: URL) -> String {
        var fileType: String?
        
        // 首先尝试安全范围访问（即使可能失败）
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // 方法1: 尝试使用 resourceValues 获取 UTI
        //        if hasAccess {
        do {
            let resourceValues = try url.resourceValues(forKeys: [.typeIdentifierKey])
            fileType = resourceValues.typeIdentifier
            if let type = fileType {
//                self.manger?.log(1, "✅ 通过 resourceValues 获取文件类型: \(type)")
                return type
            }
        } catch {
            ShareAPI.shared().log(1, "❌ resourceValues 获取失败: \(error.localizedDescription)")
        }
        //        }
        
        // 方法2: 尝试使用 UniformTypeIdentifiers (iOS 14+/macOS 11+)
        if #available(iOS 14.0, macOS 11.0, *) {
            do {
                let resourceValues = try url.resourceValues(forKeys: [.contentTypeKey])
                if let contentType = resourceValues.contentType {
                    fileType = contentType.identifier
                    self.manger?.log(1, "✅ 通过 UniformTypeIdentifiers 获取文件类型: \(contentType.identifier)")
                    return contentType.identifier
                }
            } catch {
                ShareAPI.shared().log(1, "❌ UniformTypeIdentifiers 获取失败: \(error.localizedDescription)")
            }
        }
        // 方法3: 使用 NSWorkspace.type(ofFile:) (macOS 专用)
        let workspaceType = try? NSWorkspace.shared.type(ofFile: url.path)
        if let workspaceType = workspaceType, !workspaceType.isEmpty && workspaceType != "dyn.ah62d4rv4ge81e62" { // 排除未知类型
            self.manger?.log(1, "✅ 通过 NSWorkspace 获取文件类型: \(workspaceType)")
            return workspaceType
        } else {
            self.manger?.log(1, "❌ NSWorkspace 返回未知类型: \(String(describing: workspaceType))")
        }
        // 方法3: 通过文件扩展名推断（最可靠的备用方案）
        let fileExtension = url.pathExtension.lowercased()
        let inferredType = inferFileType(from: fileExtension)
        self.manger?.log(1, "✅ 通过扩展名推断文件类型: \(inferredType)")
        return inferredType
    }
    // 扩展名到 UTI 的映射函数
    private func inferFileType(from fileExtension: String) -> String {
        let typeMapping: [String: String] = [
            // 图片格式
            "png": "public.png",
            "jpg": "public.jpeg",
            "jpeg": "public.jpeg",
            "gif": "public.gif",
            "bmp": "public.bmp",
            "tiff": "public.tiff",
            "tif": "public.tiff",
            "heic": "public.heic",
            "heif": "public.heif",
            "webp": "public.webp",
            "ico": "com.microsoft.ico",
            "icns": "com.apple.icns",
            "svg": "public.svg-image",
            
            // 文档格式
            "pdf": "com.adobe.pdf",
            "txt": "public.plain-text",
            "rtf": "public.rtf",
            "html": "public.html",
            "htm": "public.html",
            "md": "net.daringfireball.markdown",
            "json": "public.json",
            "xml": "public.xml",
            
            // Office 文档
            "doc": "com.microsoft.word.doc",
            "docx": "org.openxmlformats.wordprocessingml.document",
            "xls": "com.microsoft.excel.xls",
            "xlsx": "org.openxmlformats.spreadsheetml.sheet",
            "ppt": "com.microsoft.powerpoint.ppt",
            "pptx": "org.openxmlformats.presentationml.presentation",
            "pages": "com.apple.pages",
            "numbers": "com.apple.numbers",
            "key": "com.apple.keynote",
            
            // 压缩文件
            "zip": "public.zip",
            "rar": "public.rar-archive",
            "7z": "public.7z-archive",
            "tar": "public.tar-archive",
            "gz": "org.gnu.gnu-zip-archive",
            
            // 音频
            "mp3": "public.mp3",
            "wav": "com.microsoft.waveform-audio",
            "aac": "public.aac-audio",
            "m4a": "public.mpeg-4-audio",
            "flac": "public.flac",
            "ogg": "public.ogg-audio",
            
            // 视频
            "mp4": "public.mpeg-4",
            "mov": "com.apple.quicktime-movie",
            "avi": "public.avi",
            "mkv": "public.mkv",
            "flv": "com.adobe.flash.video",
            "m4v": "com.apple.m4v-video",
            "wmv": "com.microsoft.windows-media-wmv",
            
            // 代码文件
            "swift": "public.swift-source",
            "java": "com.sun.java-source",
            "c": "public.c-source",
            "cpp": "public.c-plus-plus-source",
            "h": "public.c-header",
            "py": "public.python-script",
            "js": "com.netscape.javascript-source",
            "php": "public.php-script",
            
            // 其他
            "dmg": "com.apple.disk-image",
            "pkg": "com.apple.installer-package",
            "app": "com.apple.application-bundle"
        ]
        
        return typeMapping[fileExtension] ?? "public.data"
    }
}

extension MainWindowController{
    // MARK: - 导出根据asset获取到的图库静态图片和视频
    func getShareableFileURL(for asset: PHAsset, completion: @escaping (URL?, String?) -> Void) {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first else {
            completion(nil, nil)
            return
        }
        
        let originalFilename = resource.originalFilename
        // 在临时目录创建一个使用原始文件名的文件
        let temporaryDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        if !FileManager.default.fileExists(atPath: temporaryDirectoryURL.path) {
            do {
                try FileManager.default.createDirectory(at: URL(fileURLWithPath: temporaryDirectoryURL.path), withIntermediateDirectories: true, attributes: nil)
            } catch {
                
            }
        }
        let targetURL = temporaryDirectoryURL.appendingPathComponent(originalFilename)
        
        // 移除临时目录下可能存在的同名文件
        try? FileManager.default.removeItem(at: targetURL)
        
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = false // 允许从iCloud下载
        
        PHAssetResourceManager.default().writeData(for: resource, toFile: targetURL, options: options) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("导出文件失败: \(error.localizedDescription)")
                    completion(nil, nil)
                } else {
                    print("文件已导出至: \(targetURL)")
                    completion(targetURL, originalFilename)
                }
            }
        }
    }
}




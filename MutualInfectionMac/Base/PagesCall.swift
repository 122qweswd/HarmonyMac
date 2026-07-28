//
//  PopupsCall.swift
//  MutualInfection
//
//  Created by 1234 on 2025/9/25.
//

import Cocoa

class PagesCall: NSObject {
    var upWindow:NSWindow!//父窗口
    var userName:String!//用户名
    var fileCount:String!//文件数
    var fileSize:String!//文件大小
    var progress:String!//进度
    var lable:String!//更新弹窗内容
    var buttonLable:String!//更新弹窗按钮文字
    
    init(upWindow: NSWindow? = nil,userName: String = "",fileCount: String = "",fileSize: String = "",progress: String = "",lable: String = "",buttonLable: String = "") {
        self.upWindow=upWindow
        self.userName=userName
        self.fileCount=fileCount
        self.fileSize=fileSize
        self.progress=progress
        self.lable=lable
        self.buttonLable=buttonLable
    }
    
    //设备名称
    func deviceNameWindowShow() {
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 0, height: 0),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        let deviceNameVC = DeviceNameController()
        
        deviceNameVC.chageNameClick = { newName in
            Gloable.userName = newName
            UserDefaults.standard.set(newName, forKey: deviceNameKey)
        }
        
        deviceNameVC.chageAvatarClick = { newAvatar in
            guard let tiffData = newAvatar.tiffRepresentation,
                  let bitmapImage = NSBitmapImageRep(data: tiffData) else { return }

            // JPEG压缩存储（推荐有损压缩）
            let imageData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.5])
            
            UserDefaults.standard.set(imageData, forKey: userAvatarKey)
        }
        
        newWindow.contentViewController = deviceNameVC
        newWindow.makeKeyAndOrderFront(nil)
        
        upWindow.beginSheet(newWindow) { response in
            // 处理窗口关闭后的回调
        }
        Gloable.showTabNSWindow = newWindow
    }
    //互传记录
    func transmitRecordWindowShow() {
        if let window = Gloable.transmitRecordWindow {
            window.close()
        }
        
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 0, height: 0),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        /// 需要使用导航管理单例
        MACNavigationManager.shared.window = newWindow
        MACNavigationManager.shared.setRootViewController(TransmitRecordController())
//        newWindow.contentViewController = TransmitRecordController()
//        newWindow.makeKeyAndOrderFront(nil)
        upWindow.beginSheet(newWindow) { response in
            // 处理窗口关闭后的回调
        }
        Gloable.showTabNSWindow = newWindow
        Gloable.transmitRecordWindow = newWindow
    }
    //帮助页面
    func helpWindowShow(){
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 0, height: 0),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        newWindow.contentViewController = HelpController(upWindow: self.upWindow)
        newWindow.makeKeyAndOrderFront(nil)
        upWindow.beginSheet(newWindow) { response in
            // 处理窗口关闭后的回调
        }
        Gloable.showTabNSWindow = newWindow
    }
    //反馈页面
    func feedbackWindowShow() {
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 0, height: 0),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        newWindow.contentViewController = FeedbackController()
        newWindow.makeKeyAndOrderFront(nil)
        upWindow.beginSheet(newWindow) { response in
            // 处理窗口关闭后的回调
        }
        Gloable.showTabNSWindow = newWindow
    }
    //系统权限管理页面
    func permissionWindowShow() {
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 0, height: 0),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        newWindow.contentViewController = PermissionController()
        newWindow.makeKeyAndOrderFront(nil)
        upWindow.beginSheet(newWindow) { response in
            // 处理窗口关闭后的回调
        }
        Gloable.showTabNSWindow = newWindow
    }
    //关于页面
    func aboutWindowShow(){
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 0, height: 0),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        newWindow.contentViewController = AboutController()
        newWindow.makeKeyAndOrderFront(nil)
        upWindow.beginSheet(newWindow) { response in
            // 处理窗口关闭后的回调
        }
        Gloable.showTabNSWindow = newWindow
    }
    // 接收完成
    func completeReceptPopShow() {
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 0, height: 0),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        newWindow.contentViewController = CompleteReceptPopController(userName: self.userName,fileCount: self.fileCount,fileSize: self.fileSize)
        newWindow.makeKeyAndOrderFront(nil)
        upWindow.beginSheet(newWindow) { response in
            // 处理窗口关闭后的回调
        }
        Gloable.showTabNSWindow = newWindow
    }
    // 接收弹框
    func receptOrNotPopShow(_ udid: String, metadata: [AnyHashable : Any]) {
        isRecvTask = true
        Gloable.isNotSendingStatus = false
        NotificationCenter.default.post(name: NSNotification.Name("GetIsSendingStatus"), object: nil)
        receivePageManger?.switchToViewController(ofType: .receivePop, udid: udid, metadata: metadata)
        receivePageManger?.showModal()
    }
    // 接收中
    func stopReceptPopShow(upWindow: NSWindow, udid: String, metadata: [AnyHashable : Any]) {
        ShareAPI.shared().acceptRequest(udid)
        receivePageManger?.switchToViewController(ofType: .receivingPop, metadata: metadata)
    }
    // 取消接收弹框
    func cancelReceptPopShow() {
        receivePageManger?.switchCancelPage(isShow: true)
    }
    //加入热点弹框
    func joinPopShow() {
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 0, height: 0),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        newWindow.contentViewController = JoinPopController(userName: self.userName,fileCount: self.fileCount,fileSize: self.fileSize)
        newWindow.makeKeyAndOrderFront(nil)
        upWindow.beginSheet(newWindow) { response in
            // 处理窗口关闭后的回调
        }
        Gloable.showTabNSWindow = newWindow
    }
    // 版本更新
    func updatePopShow() {
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 0, height: 0),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        newWindow.contentViewController = UpdatePopController(lable: self.lable,buttonLable: self.buttonLable)
        newWindow.makeKeyAndOrderFront(nil)
        upWindow.beginSheet(newWindow) { response in
            // 处理窗口关闭后的回调
        }
        Gloable.showTabNSWindow = newWindow
    }
    //意见反馈提示
    func feedBackTipControllerShow(tipLabel: String = "",imageName: String = "") ->NSWindow{
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 0, height: 0),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        newWindow.contentViewController = FeedBackTipController(tipLabel:tipLabel,imageName:imageName)
        newWindow.makeKeyAndOrderFront(nil)
        upWindow.beginSheet(newWindow) { response in
            // 处理窗口关闭后的回调
        }
        Gloable.showTabNSWindow = newWindow
        return newWindow
    }
}

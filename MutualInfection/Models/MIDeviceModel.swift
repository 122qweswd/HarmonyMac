//
//  MIDeviceModel.swift
//  MutualInfection
//
//  Created by apple on 2025/10/15.
//

import Foundation

// MARK: - Device Model
class MIDevice {
    var name: String
    let uuid: String
    var hwId:String
    var deviceStatus: DeviceStatus
    var isShowIcon: Bool
    let deviceType : Int
    var progress: CGFloat
    var fristSendEnd = false
    init(name: String, uuid: String, hwId:String,devicetype:Int, deviceStatus: DeviceStatus = .normal,isShowIcon:Bool = false,_ progress:CGFloat = 0) {
        self.name = name
        self.uuid = uuid
        self.deviceStatus = deviceStatus
        self.isShowIcon = isShowIcon
        self.progress = progress
        self.hwId =  hwId
        self.deviceType = devicetype
    }
}

// MARK: - Device Status Enum
enum DeviceStatus {
    case normal      // 在线，未选择 - 正常设备状态
    case connecting  // 连接中状态 - 正在建立连接
    case waiting     // 等待中状态 - 等待用户确认或网络连接
    case sending     // 发送中状态 - 保持动画不变
    case completed   // 发送完成 - 保持白色对钩不变
    case cancelled   // 取消发送 - 用户取消或发送失败
    case needreceive  //待接收
    case connected //连接完成
    case disconnected //连接断开
    case didReject //对方拒绝
    case peerBusy //对方忙
    case selfBusy //已方忙
    case error
    case timeout
    case nospace
}

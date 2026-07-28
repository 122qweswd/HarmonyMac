//
//  Gloable.swift
//  MutualInfection
//
//  Created by 1234 on 2025/9/25.
//

import AppKit

let deviceNameKey = "deviceName_key"
let userAvatarKey = "userAvatar_key"
let speedMode = "speedMode_key"
let openDevice = "openDevice_key"
let isNotSendingStatus = "isNotSendingStatus_key"

struct Gloable{
    static var isMoreMeumShow = false
    static var userName = ""
    static var userAvatar: NSImage? = NSImage(named: "")
    static var speedMode = false
    static var openDevice = true
    static var isNotSendingStatus: Bool = true
    static var dfxAutoFlag: Bool = true
    static var showTabNSWindow: NSWindow?
    
    /// 互传记录页面
    static var transmitRecordWindow: NSWindow? = nil
}

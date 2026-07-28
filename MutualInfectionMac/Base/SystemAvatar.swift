//
//  SystemAvatar.swift
//  MutualInfection
//
//  Created by 1234 on 2025/9/30.
//

import Cocoa
import AppKit
import Collaboration

class SystemAvatar: NSObject {
    func get() -> NSImage? {
        // 方法1：通过Collaboration框架获取高清头像
        if let identity = CBIdentity(name: NSUserName(), authority: .default()),
           let image = identity.image {
            return image
        }
        
        // 方法2：从系统头像目录获取
        let avatarPaths = [
            "/Library/User Pictures/Fun/Beach Ball.png",
            "/Library/User Pictures/Nature/Sunflower.tiff",
            "/Library/User Pictures/Animals/Eagle.png"
        ]
        
        for path in avatarPaths {
            if let image = NSImage(contentsOfFile: path) {
                return image
            }
        }
        
        // 方法3：获取系统默认头像
        return NSImage(named: NSImage.userName)
    }
}

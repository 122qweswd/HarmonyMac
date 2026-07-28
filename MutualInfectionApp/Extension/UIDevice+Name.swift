//
//  UIDevice+Name.swift
//  MutualInfectionApp
//
//  Created by Niko on 2025/9/26.
//

import Foundation
import UIKit

extension UIDevice {
    static var isPad: Bool {
        current.userInterfaceIdiom == .pad
    }
    
    static var isPhone: Bool {
        current.userInterfaceIdiom == .phone
    }
    
    var deviceName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let identifier = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? UIDevice.current.name
            }
        }
        return UIDevice.deviceMap[identifier] ?? identifier
    }
    
    private static let deviceMap: [String: String] = [

        "iPhone7,2": "iPhone 6",
        "iPhone7,1": "iPhone 6 Plus",
        "iPhone8,1": "iPhone 6s",
        "iPhone8,2": "iPhone 6s Plus",
        "iPhone8,4": "iPhone SE",
        "iPhone9,1": "iPhone 7",
        "iPhone9,3": "iPhone 7",
        "iPhone9,2": "iPhone 7 Plus",
        "iPhone9,4": "iPhone 7 Plus",
        "iPhone10,1": "iPhone 8",
        "iPhone10,4": "iPhone 8",
        "iPhone10,2": "iPhone 8 Plus",
        "iPhone10,5": "iPhone 8 Plus",
        "iPhone10,3": "iPhone X",
        "iPhone10,6": "iPhone X",
        "iPhone11,2": "iPhone XS",
        "iPhone11,4": "iPhone XS Max",
        "iPhone11,6": "iPhone XS Max",
        "iPhone11,8": "iPhone XR",
        "iPhone12,1": "iPhone 11",
        "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone12,8": "iPhone SE",
        "iPhone13,1": "iPhone 12 mini",
        "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone14,4": "iPhone 13 mini",
        "iPhone14,5": "iPhone 13",
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,6": "iPhone SE",
        // iPhone 14 系列（2022年）
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",

        // iPhone 15 系列（2023年）
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",

        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone16,3": "iPhone 15",
        "iPhone16,4": "iPhone 15 Plus",
        
        "iPhone17,5": "iPhone 16e",
        "iPhone17,1": "iPhone 16 Pro",
        "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus",  // 推断
        "iPhone18,3": "iPhone 17",       // 推断
        "iPhone18,1": "iPhone 17 Pro",   // 推断
        "iPhone18,2": "iPhone 17 Pro Max", // 推断
        "iPhone18,4": "iPhone Air",       // 新款 “Air” 型号

        // ==== 标准iPad系列型号映射表 ====
        "iPad1,1": "iPad 1",
        "iPad2,1": "iPad 2",
        "iPad2,2": "iPad 2",
        "iPad2,3": "iPad 2",
        "iPad2,4": "iPad 2",
        "iPad3,1": "iPad 3",
        "iPad3,2": "iPad 3",
        "iPad3,3": "iPad 3",
        "iPad3,4": "iPad 4",
        "iPad3,5": "iPad 4",
        "iPad3,6": "iPad 4",
        "iPad6,11": "iPad 5",
        "iPad6,12": "iPad 5",
        "iPad7,5": "iPad 6",
        "iPad7,6": "iPad 6",
        "iPad7,11": "iPad 7",
        "iPad7,12": "iPad 7",
        "iPad11,6": "iPad 8",
        "iPad11,7": "iPad 8",
        "iPad12,1": "iPad 9",
        "iPad12,2": "iPad 9",
        "iPad13,18": "iPad 10",
        "iPad13,19": "iPad 10",
        "iPad14,7": "iPad 11",
        "iPad14,8": "iPad 11",
        
        // ==== iPad mini系列 ====
       "iPad2,5": "iPad mini 1",
       "iPad2,6": "iPad mini 1",
       "iPad2,7": "iPad mini 1",
       "iPad4,4": "iPad mini 2",
       "iPad4,5": "iPad mini 2",
       "iPad4,6": "iPad mini 2",
       "iPad4,7": "iPad mini 3",
       "iPad4,8": "iPad mini 3",
       "iPad4,9": "iPad mini 3",
       "iPad5,1": "iPad mini 4",
       "iPad5,2": "iPad mini 4",
       "iPad11,1": "iPad mini 5",
       "iPad11,2": "iPad mini 5",
       "iPad14,1": "iPad mini 6",
       "iPad14,2": "iPad mini 6",
       "iPad15,1": "iPad mini 7",
       "iPad15,2": "iPad mini 7",
       "iPad15,5": "iPad Air 13-inch (M3)",
       "iPad15,7": "iPad",
        
        // ==== iPad Air系列 ====
        "iPad4,1": "iPad Air",
        "iPad4,2": "iPad Air",
        "iPad4,3": "iPad Air",
        "iPad5,3": "iPad Air 2",
        "iPad5,4": "iPad Air 2",
        "iPad11,3": "iPad Air 3",
        "iPad11,4": "iPad Air 3",
        "iPad13,1": "iPad Air 4",
        "iPad13,2": "iPad Air 4",
        "iPad13,16": "iPad Air 5",
        "iPad13,17": "iPad Air 5",
        "iPad14,6": "iPad Air 6",
        
        // ==== iPad Pro系列 ====
        // 9.7英寸/10.5英寸
        "iPad6,3": "iPad Pro 9.7-inch",
        "iPad6,4": "iPad Pro 9.7-inch",
        "iPad7,3": "iPad Pro 10.5-inch",
        "iPad7,4": "iPad Pro 10.5-inch",
        
        // 12.9英寸 (第1-2代)
        "iPad6,7": "iPad Pro 12.9-inch",
        "iPad6,8": "iPad Pro 12.9-inch",
        "iPad7,1": "iPad Pro 12.9-inch",
        "iPad7,2": "iPad Pro 12.9-inch",
        
        // 11英寸/12.9英寸 (第3代 - 全面屏)
        "iPad8,1": "iPad Pro 11-inch",
        "iPad8,2": "iPad Pro 11-inch",
        "iPad8,3": "iPad Pro 11-inch",
        "iPad8,4": "iPad Pro 11-inch",
        "iPad8,5": "iPad Pro 12.9-inch",
        "iPad8,6": "iPad Pro 12.9-inch",
        "iPad8,7": "iPad Pro 12.9-inch",
        "iPad8,8": "iPad Pro 12.9-inch",
        
        // 11英寸/12.9英寸 (第4代)
        "iPad8,9": "iPad Pro 11-inch",
        "iPad8,10": "iPad Pro 11-inch",
        "iPad8,11": "iPad Pro 12.9-inch",
        "iPad8,12": "iPad Pro 12.9-inch",
        
        // 11英寸/12.9英寸 (第5代 - M1)
        "iPad13,4": "iPad Pro 11-inch",
        "iPad13,5": "iPad Pro 11-inch",
        "iPad13,6": "iPad Pro 11-inch",
        "iPad13,7": "iPad Pro 11-inch",
        "iPad13,8": "iPad Pro 12.9-inch",
        "iPad13,9": "iPad Pro 12.9-inch",
        "iPad13,10": "iPad Pro 12.9-inch",
        "iPad13,11": "iPad Pro 12.9-inch",
        
        // 11英寸/12.9英寸 (第6代 - M2)
        "iPad14,3": "iPad Pro 11-inch",
        "iPad14,4": "iPad Pro 11-inch",
        "iPad14,5": "iPad Pro 12.9-inch",
        
        
        // 11英寸/13英寸 (第7代 - M4)
        "iPad16,1": "iPad Pro 11-inch",
        "iPad16,3": "iPad Pro 11-inch",
        "iPad16,4": "iPad Pro 11-inch",
        "iPad16,5": "iPad Pro 13-inch",
        "iPad16,6": "iPad Pro 13-inch",
        
        // ==== 特殊和教育版型号 ====
        "iPad5,5": "iPad",
        "iPad6,9": "iPad",
        "iPad6,10": "iPad",
        "iPad7,9": "iPad",
        "iPad7,10": "iPad",
        "iPad14,9": "iPad SE",
        "iPad14,10": "iPad SE",
        
        // ==== 中国特定型号 ====
        "iPad4,10": "iPad Air",
        "iPad4,11": "iPad Air",
        "iPad5,6": "iPad Air 2",
        "iPad5,7": "iPad Air 2",
        "iPad13,12": "iPad Air 4",
        "iPad13,13": "iPad Air 4",
        "iPad15,3": "iPad Pro 13-inch"
    ]
}

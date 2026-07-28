//
//  NSFont+Extension.swift
//  MutualInfectionMac
//
//  Created by delegate on 2025/9/26.
//


import AppKit

extension NSFont: ExtensionCompatible {
    
    public enum Name: String {
        case pingFangSCRegular = "PingFangSC-Regular"
        case pingFangSCMedium = "PingFangSC-Medium"
        case pingFangSCSemibold = "PingFangSC-Semibold"
        case pingFangSCLight = "PingFangSC-Light"
        case pingFangSCThin = "PingFangSC-Thin"
        public func font(size: CGFloat) -> NSFont {
            NSFont.mi.font(name: self, size: size)
        }
    }
}

public extension MI where Base == NSFont {
    static func font(name: NSFont.Name? = .pingFangSCRegular, size: CGFloat, weight: NSFont.Weight? = nil) -> NSFont {
        if let weight = weight {
            return NSFont.systemFont(ofSize: size, weight: weight)
        }
        else {
            if let font = NSFont(name: name?.rawValue ?? NSFont.Name.pingFangSCRegular.rawValue, size: size) {
                return font
            }
            return NSFont.systemFont(ofSize: size)
        }
    }
    static func pingFangSCRegular(size: CGFloat) -> NSFont {
        return font(name: .pingFangSCRegular, size: size)
    }
    static func pingFangSCMedium(size: CGFloat) -> NSFont {
        return font(name: .pingFangSCMedium, size: size)
    }
    static func pingFangSCSemibold(size: CGFloat) -> NSFont {
        return font(name: .pingFangSCSemibold, size: size)
    }
    static func pingFangSCLight(size: CGFloat) -> NSFont {
        return font(name: .pingFangSCLight, size: size)
    }
    static func pingFangSCThin(size: CGFloat) -> NSFont {
        return font(name: .pingFangSCThin, size: size)
    }
}

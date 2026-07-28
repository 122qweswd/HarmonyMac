//
//  ClassNameProtocol.swift
//  MutualInfectionApp
//
//  Created by Niko on 2025/9/11.
//

import Foundation

// MARK: - 类名获取扩展
public protocol ClassNameProtocol {
    static var className: String { get }
    var className: String { get }
}

extension ClassNameProtocol {
    // 获取类名（静态属性）
    public static var className: String {
        return String(describing: self)
    }
    
    // 获取类名（实例属性）
    public var className: String {
        return type(of: self).className
    }
}

// 让所有 NSObject 子类自动遵循此协议
extension NSObject: ClassNameProtocol {}

// 让所有 Swift 类型也能使用（可选）
extension ClassNameProtocol where Self: Any {
    // 另一种获取类名的方式
    public static var classFullName: String {
        return NSStringFromClass(Self.self as! AnyClass)
    }
    
    public var classFullName: String {
        return NSStringFromClass(type(of: self) as! AnyClass)
    }
}

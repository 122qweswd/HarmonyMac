//
//  ExtensionCompatible.swift
//  MutualInfectionMac
//
//  Created by delegate on 2025/9/26.
//

import Foundation

public struct MI<Base> {
    // 可扩展的基础对象
    public let base: Base
    init(_ base: Base) {
        self.base = base
    }
}

// 通过协议扩展【类、结构体、对象】的前缀属性
public protocol ExtensionCompatible {
    associatedtype ComplatibleType
    // 实现此协议的活着class的对象 可以直接调用 .mi，比如 str.mi.func()
    var mi: MI<ComplatibleType> { get set }
    // 实现此协议的类或者class 可以直接调用 .mi，比如String.mi.classFunc()
    static var mi: MI<ComplatibleType>.Type { get set }
}

public extension ExtensionCompatible {
    var mi: MI<Self> {
        // 原本使用计算属性就够了，但是为了让我们可以以后使用mutating声明的可变对象，所以实现set()
        set {}
        
        get {
            MI<Self>(self)
        }
    }
    
    static var mi: MI<Self>.Type {
        set {}
        get {
            MI<Self>.self
        }
    }
}

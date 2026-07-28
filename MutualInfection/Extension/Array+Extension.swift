//
//  Array+Extension.swift
//  MutualInfection
//
//  Created by Niko on 2025/9/30.
//

import Foundation

// MARK: - Array Extension for Object-based Removal
extension Array where Element: Equatable {
    
    /// 安全下标访问
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
    
    /// 删除数组中指定的元素（第一个匹配项）
    /// - Parameter element: 要删除的元素
    /// - Returns: 是否成功删除
    @discardableResult
    mutating func remove(_ element: Element) -> Bool {
        guard let index = firstIndex(of: element) else {
            return false
        }
        
        remove(at: index)
        return true
    }
    
    /// 删除数组中所有匹配的元素
    /// - Parameter element: 要删除的元素
    /// - Returns: 删除的元素数量
    @discardableResult
    mutating func removeAll(_ element: Element) -> Int {
        let originalCount = count
        removeAll { $0 == element }
        return originalCount - count
    }
    
    /// 安全删除元素（不会导致崩溃）
    /// - Parameter element: 要删除的元素
    /// - Returns: 是否成功删除
    @discardableResult
    mutating func safeRemove(_ element: Element) -> Bool {
        guard let index = firstIndex(of: element) else {
            return false
        }
        guard indices.contains(index) else {
            return false
        }
        remove(at: index)
        return true
    }
    
    /// 删除元素并返回被删除的元素
    /// - Parameter element: 要删除的元素
    /// - Returns: 被删除的元素（如果存在）
    @discardableResult
    mutating func removeAndReturn(_ element: Element) -> Element? {
        guard let index = firstIndex(of: element) else {
            return nil
        }
        return remove(at: index)
    }
}

// MARK: - Array Extension for Identifiable Objects
extension Array where Element: Identifiable {
    
    /// 通过 ID 删除元素（适用于 Identifiable 对象）
    /// - Parameter id: 要删除的元素的 ID
    /// - Returns: 是否成功删除
    @discardableResult
    mutating func remove(byID id: Element.ID) -> Bool {
        guard let index = firstIndex(where: { $0.id == id }) else {
            return false
        }
        remove(at: index)
        return true
    }
    
    /// 通过 ID 删除所有匹配的元素
    /// - Parameter id: 要删除的元素的 ID
    /// - Returns: 删除的元素数量
    @discardableResult
    mutating func removeAll(byID id: Element.ID) -> Int {
        let originalCount = count
        removeAll { $0.id == id }
        return originalCount - count
    }
}

// MARK: - Array Extension with Custom KeyPath Support
extension Array {
    
    /// 通过 KeyPath 删除元素
    /// - Parameters:
    ///   - keyPath: 用于比较的键路径
    ///   - value: 要匹配的值
    /// - Returns: 是否成功删除
    @discardableResult
    mutating func remove<T: Equatable>(by keyPath: KeyPath<Element, T>, value: T) -> Bool {
        guard let index = firstIndex(where: { $0[keyPath: keyPath] == value }) else {
            return false
        }
        remove(at: index)
        return true
    }
    
    /// 通过 KeyPath 删除所有匹配的元素
    /// - Parameters:
    ///   - keyPath: 用于比较的键路径
    ///   - value: 要匹配的值
    /// - Returns: 删除的元素数量
    @discardableResult
    mutating func removeAll<T: Equatable>(by keyPath: KeyPath<Element, T>, value: T) -> Int {
        let originalCount = count
        removeAll { $0[keyPath: keyPath] == value }
        return originalCount - count
    }
}


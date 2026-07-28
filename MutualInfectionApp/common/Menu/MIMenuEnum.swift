//
//  MIMenuEnum.swift
//  MutualInfection
//
//  Created by Niko on 2025/9/28.
//

import Foundation
import WCDBSwift

// MARK: - 排序配置枚举
enum ConfigSortType: String {
    case none       = ""
    /// 升序
    case ascending  = "升序"
    /// 降序
    case descending = "降序"
    
    var rawValue: String {
        switch self {
            case .none:
                return ""
            case .ascending:
                return LocalizedStrings.ascendingOrder
            case .descending:
                return LocalizedStrings.descendingOrder
        }
    }
    
    /// 切换排序方向
    func toggle() -> ConfigSortType {
        return self == .ascending ? .descending : .ascending
    }
    
    /// 转换为 WCDB 的 Order
    var wcdbOrder: Order {
        return self == .ascending ? .ascending : .descending
    }
}

// MARK: - 排序状态枚举
enum ConfigSortState {
    /// 无状态（默认）
    case none
    /// 编辑模式
    case edit
    /// 按时间排序
    case sortByTime(ConfigSortType)
    /// 按类型排序
    case sortByType(ConfigSortType)
    
    /// 当前排序类型描述
    var description: String {
        switch self {
        case .none:
            return "默认"
        case .edit:
            return "编辑"
        case .sortByTime(let sortType):
            return "时间 \(sortType.rawValue)"
        case .sortByType(let sortType):
            return "类型 \(sortType.rawValue)"
        }
    }
    
    /// 是否按时间排序
    var isSortByTime: Bool {
        switch self {
        case .sortByTime:
            return true
        default:
            return false
        }
    }
    
    /// 是否按类型排序
    var isSortByType: Bool {
        switch self {
        case .sortByType:
            return true
        default:
            return false
        }
    }
 
    /// 获取当前排序方式（如果不是排序状态则返回nil）
    var currentSortType: ConfigSortType? {
        switch self {
        case .sortByTime(let sortType), .sortByType(let sortType):
            return sortType
        default:
            return nil
        }
    }
    
    /// 设置为默认
    func setupDefault() -> ConfigSortState {
        switch self {
            case .sortByTime:
                return .sortByTime(.none)
            case .sortByType:
                return .sortByType(.none)
            default:
                return self
        }
    }
    
    /// 切换排序方向（仅对排序状态有效）
    func toggleSortDirection() -> ConfigSortState {
        switch self {
        case .sortByTime(let sortType):
            return .sortByTime(sortType.toggle())
        case .sortByType(let sortType):
            return .sortByType(sortType.toggle())
        default:
            return self
        }
    }
}

// MARK: - 扩展 Equatable 协议
extension ConfigSortState: Equatable {
    static func == (lhs: ConfigSortState, rhs: ConfigSortState) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case (.edit, .edit):
            return true
        case (.sortByTime(let lhsType), .sortByTime(let rhsType)):
            return lhsType == rhsType
        case (.sortByType(let lhsType), .sortByType(let rhsType)):
            return lhsType == rhsType
        default:
            return false
        }
    }
}

//
//  MIJSONUtils.swift
//  MutualInfection
//
//  Created by Niko on 2025/9/25.
//

import Foundation

// MARK: - JSON转换工具类
final class MIJSONUtils {
    
    /// 通用的JSON编码器配置
    private static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys] // 美化输出和键排序
        encoder.dateEncodingStrategy = .iso8601 // ISO8601日期格式
        return encoder
    }()
    
    /// 将任意Codable对象转换为JSON字符串
    /// - Parameter object: 遵循Codable协议的对象
    /// - Returns: JSON字符串，失败返回nil
    static func toJSONString<T: Codable>(_ object: T) -> String? {
        do {
            let jsonData = try jsonEncoder.encode(object)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            print("❌ JSON编码失败: \(error)")
            return nil
        }
    }
    
    /// 将任意Codable对象转换为JSON Data
    /// - Parameter object: 遵循Codable协议的对象
    /// - Returns: JSON Data，失败返回nil
    static func toJSONData<T: Codable>(_ object: T) -> Data? {
        do {
            return try jsonEncoder.encode(object)
        } catch {
            print("❌ JSON编码失败: \(error)")
            return nil
        }
    }
    
    /// 将JSON字符串转换为指定类型的对象
    /// - Parameters:
    ///   - jsonString: JSON字符串
    ///   - type: 目标类型
    /// - Returns: 解码后的对象，失败返回nil
    static func fromJSONString<T: Codable>(_ jsonString: String, to type: T.Type) -> T? {
        guard let jsonData = jsonString.data(using: .utf8) else {
            print("❌ JSON字符串转换为Data失败")
            return nil
        }
        
        return fromJSONData(jsonData, to: type)
    }
    
    /// 将JSON Data转换为指定类型的对象
    /// - Parameters:
    ///   - jsonData: JSON Data
    ///   - type: 目标类型
    /// - Returns: 解码后的对象，失败返回nil
    static func fromJSONData<T: Codable>(_ jsonData: Data, to type: T.Type) -> T? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            return try decoder.decode(type, from: jsonData)
        } catch {
            print("❌ JSON解码失败: \(error)")
            return nil
        }
    }
    
    /// 将对象数组转换为JSON字符串
    /// - Parameter objects: 对象数组
    /// - Returns: JSON字符串，失败返回nil
    static func arrayToJSONString<T: Codable>(_ objects: [T]) -> String? {
        return toJSONString(objects)
    }
    
    /// 将字典转换为JSON字符串
    /// - Parameter dictionary: 字典
    /// - Returns: JSON字符串，失败返回nil
    static func dictionaryToJSONString(_ dictionary: [String: Any]) -> String? {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dictionary, options: [.prettyPrinted, .sortedKeys])
            return String(data: jsonData, encoding: .utf8)
        } catch {
            print("❌ 字典转JSON失败: \(error)")
            return nil
        }
    }
}

extension MITransferRecord {
    
    /// 将传输记录转换为JSON字符串
    func toJSONString() -> String? {
        return MIJSONUtils.toJSONString(self)
    }
    
    /// 将传输记录转换为JSON Data
    func toJSONData() -> Data? {
        return MIJSONUtils.toJSONData(self)
    }
    
    /// 从JSON字符串创建传输记录
    static func fromJSONString(_ jsonString: String) -> MITransferRecord? {
        return MIJSONUtils.fromJSONString(jsonString, to: MITransferRecord.self)
    }
    
    /// 从JSON Data创建传输记录
    static func fromJSONData(_ jsonData: Data) -> MITransferRecord? {
        return MIJSONUtils.fromJSONData(jsonData, to: MITransferRecord.self)
    }
}

extension MITransferFile {
    
    /// 将传输文件转换为JSON字符串
    func toJSONString() -> String? {
        return MIJSONUtils.toJSONString(self)
    }
    
    /// 将传输文件转换为JSON Data
    func toJSONData() -> Data? {
        return MIJSONUtils.toJSONData(self)
    }
    
    /// 从JSON字符串创建传输文件
    static func fromJSONString(_ jsonString: String) -> MITransferFile? {
        return MIJSONUtils.fromJSONString(jsonString, to: MITransferFile.self)
    }
    
    /// 从JSON Data创建传输文件
    static func fromJSONData(_ jsonData: Data) -> MITransferFile? {
        return MIJSONUtils.fromJSONData(jsonData, to: MITransferFile.self)
    }
}

// MARK: - 日期扩展：ISO8601格式化
extension Date {
    /// 转换为ISO8601格式字符串
    func iso8601String() -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
    
    /// 从ISO8601字符串创建日期
    static func fromISO8601String(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: string)
    }
}

// MARK: - 数组扩展：批量JSON转换
extension Array where Element: MITransferRecord {
    /// 将传输记录数组转换为JSON字符串
    func toJSONString() -> String? {
        return MIJSONUtils.arrayToJSONString(self)
    }
}

extension Array where Element: MITransferFile {
    /// 将传输文件数组转换为JSON字符串
    func toJSONString() -> String? {
        return MIJSONUtils.arrayToJSONString(self)
    }
}

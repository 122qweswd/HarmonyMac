//
//  Date+Extension.swift
//  MutualInfection
//
//  Created by Niko on 2025/9/30.
//

import Foundation

extension Date {
    enum SCDateFormatType: String {
        case yyyy = "yyyy"
        case yyyyMM = "yyyy-MM"
        case yyyyMMdd = "yyyy-MM-dd"
        case yyyyMMddHH = "yyyy-MM-dd HH"
        case yyyyMMddHHmm = "yyyy-MM-dd HH:mm"
        case yyyyMMddHHmmss = "yyyy-MM-dd HH:mm:ss"
    }
    
    /// date 转 string
    static func toString(_ date:Date ,format: SCDateFormatType) -> String? {
        return date.toString(format: format)
    }
    
    /// date 转 string
    static func toString(_ date:Date ,format: String) -> String? {
        return date.toString(format: format)
    }
    
    /// date 转 string
    func toString(format: SCDateFormatType) -> String? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format.rawValue
        return dateFormatter.string(from: self)
    }
    
    /// date 转 string
    func toString(format: String) -> String? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        return dateFormatter.string(from: self)
    }
    
    /// string 转 Date
    static func dateFromString(_ dateString: String?, format: SCDateFormatType) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format.rawValue
        return dateFormatter.date(from: dateString ?? "")
    }
    
    /// string 转 Date
    static func dateFromString(_ dateString: String?, format: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        return dateFormatter.date(from: dateString ?? "")
    }
    func getPHAssetDateStr() -> String {
        var dateStr = "-1"
        let dateInt = Int(self.timeIntervalSince1970 * 1000.0)
        dateStr = "\(dateInt)"
        return dateStr
    }
}



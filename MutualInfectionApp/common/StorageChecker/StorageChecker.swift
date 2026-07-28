//
//  StorageChecker.swift
//  MutualInfection
//
//  Created by mac on 2025/10/15.
//


import Foundation

class StorageChecker {
    static func getFreeDiskSpace() -> Int64? {
        let fileURL = URL(fileURLWithPath: NSHomeDirectory())
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            return values.volumeAvailableCapacityForImportantUsage
        } catch {
            ShareAPI.shared().log(3, "获取存储空间失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    static func formattedFreeSpace(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    static func getFreeSpace() -> Int64 {
        guard let bytes = getFreeDiskSpace() else { return 0 }
        return bytes
    }
}

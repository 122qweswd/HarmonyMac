//
//  MemoryChecker.swift
//  MutualInfection
//
//  Created by mac on 2025/10/15.
//

import Foundation
import MachO

class MemoryChecker {
    // 获取当前进程占用内存（字节）
    static func usedMemory() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return kerr == KERN_SUCCESS ? UInt64(info.resident_size) : 0
    }
    
    // 获取设备物理内存总量（字节）
    static func totalMemory() -> UInt64 {
        return ProcessInfo.processInfo.physicalMemory
    }
    
    // 获取可用内存
    static func availableMemory() -> UInt64 {
        return UInt64(os_proc_available_memory())
    }
    
    // 内存使用率百分比
    static func memoryUsagePercentage() -> Double {
        let used = Double(usedMemory())
        let total = Double(totalMemory())
        return (used / total) * 100.0
    }
}

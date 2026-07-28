//
//  TaskQueueManager.swift
//  MutualInfection
//
//  Created by Niko on 2025/10/28.
//

import Foundation

// MARK: - 任务队列管理器
public final class TaskQueueManager {
    
    public static let shared = TaskQueueManager()
    
    private var activeGroups: [TaskGroup] = []
    private let queue = DispatchQueue(label: "com.taskqueue.manager", attributes: .concurrent)
    
    private init() {}
    
    public func register(_ group: TaskGroup) {
        queue.async(flags: .barrier) { [weak self] in
            self?.activeGroups.append(group)
        }
    }
    
    public func unregister(_ group: TaskGroup) {
        queue.async(flags: .barrier) { [weak self] in
            self?.activeGroups.removeAll { $0 === group }
        }
    }
    
    public static func createBatchGroup() -> BatchTaskGroup {
        let group = BatchTaskGroup()
        shared.register(group)
        return group
    }
    
    public static func createChainGroup() -> ChainTaskGroup {
        let group = ChainTaskGroup()
        shared.register(group)
        return group
    }
}


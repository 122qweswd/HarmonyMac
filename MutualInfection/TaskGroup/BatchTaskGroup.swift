//
//  BatchTaskGroup.swift
//  MutualInfection
//
//  Created by Niko on 2025/10/28.
//

import Foundation

// MARK: - 任务组协议
public protocol TaskGroup: AnyObject {
    var type: TaskGroupType { get }
    var tasks: [TaskOperation] { get }
    var onAllTasksFinished: ((Bool) -> Void)? { get set }
    
    func add(_ task: TaskOperation)
    func start()
}

// MARK: - 批量任务组（并行）
public final class BatchTaskGroup: TaskGroup {
    
    public let type: TaskGroupType = .batch
    public private(set) var tasks: [TaskOperation] = []
    public var onAllTasksFinished: ((Bool) -> Void)?
    
    private var dispatchGroup: DispatchGroup?
    private var isRunning = false
    
    public func add(_ task: TaskOperation) {
        guard !isRunning else { return }
        tasks.append(task)
    }
    
    public func start() {
        guard !tasks.isEmpty, !isRunning else { return }
        
        isRunning = true
        let group = DispatchGroup()
        self.dispatchGroup = group
        
        // 设置任务完成回调
        for task in tasks {
            group.enter()
            
            let originalCallback = task.onTaskFinished
            task.onTaskFinished = { finishedTask, result in
                print("Batch task completed: \(finishedTask.identifier)")
                
                originalCallback?(finishedTask, result)
                group.leave()
            }
        }
        
        // 设置组完成回调
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            print("All batch tasks completed")
            
            onAllTasksFinished?(true)
            cleanup()
        }
        
        // 开始所有任务
        tasks.forEach { $0.start() }
    }
    
    private func cleanup() {
        isRunning = false
        dispatchGroup = nil
    }
}


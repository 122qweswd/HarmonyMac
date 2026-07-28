//
//  ChainTaskGroup.swift
//  MutualInfection
//
//  Created by Niko on 2025/10/28.
//

import Foundation

// MARK: - 链式任务组（串行）
public final class ChainTaskGroup: TaskGroup {
    
    public let type: TaskGroupType = .chain
    public private(set) var tasks: [TaskOperation] = []
    public var onAllTasksFinished: ((Bool) -> Void)?
    
    private var currentIndex = 0
    private var isRunning = false
    
    public func add(_ task: TaskOperation) {
        guard !isRunning else { return }
        tasks.append(task)
    }
    
    public func insert(_ task: TaskOperation, after existingTask: TaskOperation) {
        guard let index = tasks.firstIndex(where: { $0.identifier == existingTask.identifier }) else { return }
        
        if index == tasks.count - 1 {
            tasks.append(task)
        } else {
            tasks.insert(task, at: index + 1)
        }
        
        setupTaskExecution(for: task)
    }
    
    public func start() {
        guard !tasks.isEmpty, !isRunning else { return }
        
        isRunning = true
        currentIndex = 0
        
        // 设置所有任务的执行逻辑
        tasks.forEach { setupTaskExecution(for: $0) }
        
        // 开始第一个任务
        tasks.first?.start()
    }
    
    private func setupTaskExecution(for task: TaskOperation) {
        let originalCallback = task.onTaskFinished
        
        task.onTaskFinished = { [weak self] finishedTask, shouldContinue in
            guard let self = self else { return }
            
            print("Chain task completed: \(finishedTask.identifier), continue: \(shouldContinue)")
            originalCallback?(finishedTask, shouldContinue)
            
            if !shouldContinue {
                self.finishChain(success: false)
                return
            }
            
            self.currentIndex += 1
            if self.currentIndex < self.tasks.count {
                self.tasks[self.currentIndex].start()
            } else {
                self.finishChain(success: true)
            }
        }
    }
    
    private func finishChain(success: Bool) {
        print("Chain tasks \(success ? "completed successfully" : "was interrupted")")
        onAllTasksFinished?(success)
        cleanup()
    }
    
    private func cleanup() {
        isRunning = false
        currentIndex = 0
    }
}


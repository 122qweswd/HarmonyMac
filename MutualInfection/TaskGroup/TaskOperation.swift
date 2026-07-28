//
//  TaskOperation.swift
//  MutualInfection
//
//  Created by Niko on 2025/10/28.
//

import Foundation

// MARK: - 任务组类型
public enum TaskGroupType {
    case batch  // 并行执行
    case chain  // 串行执行
}

// MARK: - 任务操作对象
public class TaskOperation {
    
    public let identifier: String
    public let customData: Any?
    public var onTaskFinished: ((TaskOperation, Bool) -> Void)?
    
    private let operationBlock: (TaskOperation) -> Void
    private let isSync: Bool
    
    public init(identifier: String,
                customData: Any? = nil,
                isSync: Bool = false,
                operation: @escaping (TaskOperation) -> Void) {
        self.identifier = identifier
        self.customData = customData
        self.isSync = isSync
        self.operationBlock = operation
    }
    
    public static func async(identifier: String,
                            customData: Any? = nil,
                            operation: @escaping (TaskOperation) -> Void) -> TaskOperation {
        return TaskOperation(identifier: identifier,
                           customData: customData,
                           isSync: false,
                           operation: operation)
    }
    
    public static func sync(identifier: String,
                           customData: Any? = nil,
                           operation: @escaping (TaskOperation) -> Void) -> TaskOperation {
        return TaskOperation(identifier: identifier,
                           customData: customData,
                           isSync: true,
                           operation: operation)
    }
    
    public func start() {
        if operationBlock != nil {
            operationBlock(self)
        }
        
        if isSync {
            finish()
        }
    }
    
    public func finish(_ shouldContinue: Bool = true) {
        onTaskFinished?(self, shouldContinue)
        onTaskFinished = nil
    }
}

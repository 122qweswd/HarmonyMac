//
//  MIAsynchronousOperation.swift
//  MutualInfection
//
//  Created by apple on 2025/12/2.
//

class MIAsynchronousOperation: Operation, @unchecked Sendable {
    // MARK: - 手动管理操作状态
    private let stateLock = NSLock()
    private var _isExecuting = false
    private var _isFinished = false
    
    override var isAsynchronous: Bool { return true }
    
    override var isExecuting: Bool {
        get { stateLock.withLock { _isExecuting } }
        set {
            willChangeValue(forKey: "isExecuting")
            stateLock.withLock { _isExecuting = newValue }
            didChangeValue(forKey: "isExecuting")
        }
    }
    
    override var isFinished: Bool {
        get { stateLock.withLock { _isFinished } }
        set {
            willChangeValue(forKey: "isFinished")
            stateLock.withLock { _isFinished = newValue }
            didChangeValue(forKey: "isFinished")
        }
    }
    
    // MARK: - 必须调用的完成方法
    func completeOperation() {
        if isExecuting { isExecuting = false }
        isFinished = true
    }
    
    override func start() {
        guard !isCancelled else {
            // 如果已被取消，直接标记完成
            finish()
            return
        }
        isExecuting = true
        main()
    }
    
    override func main() {
        // 子类必须重写此方法，并不要调用 super.main()
        // 在异步任务完成后，必须调用 `finish()`
        fatalError("Subclasses must implement `main` without calling super.")
    }
    
    func finish() {
        completeOperation()
    }
}

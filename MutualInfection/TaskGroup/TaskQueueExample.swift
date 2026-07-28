//
//  TaskQueueExample.swift
//  MutualInfection
//
//  Created by Niko on 2025/10/28.
//

import Foundation
// MARK: - 使用示例
extension TaskOperation {
    
    /// 便捷方法：创建网络请求任务
    public static func networkRequest(identifier: String,
                                    url: URL,
                                    completion: @escaping (Result<Data, Error>) -> Void) -> TaskOperation {
        return TaskOperation.async(identifier: identifier) { task in
            URLSession.shared.dataTask(with: url) { data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(.failure(error))
                    } else if let data = data {
                        completion(.success(data))
                    }
                    task.finish()
                }
            }.resume()
        }
    }
    
    /// 便捷方法：创建延时任务
    public static func delay(identifier: String,
                           duration: TimeInterval) -> TaskOperation {
        return TaskOperation.async(identifier: identifier) { task in
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                task.finish()
            }
        }
    }
}

// MARK: - 使用示例
class TaskQueueExample {
    
    func demonstrateBatchTasks() {
        let batchGroup = TaskQueueManager.createBatchGroup()
        
        // 创建多个并行任务
        let task1 = TaskOperation.async(identifier: "DownloadImage1") { task in
            print("Starting download 1")
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                print("Download 1 completed")
                task.finish()
            }
        }
        
        let task2 = TaskOperation.async(identifier: "DownloadImage2") { task in
            print("Starting download 2")
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                print("Download 2 completed")
                task.finish()
            }
        }
        
        let task3 = TaskOperation.sync(identifier: "ProcessData") { task in
            print("Processing data synchronously")
            // 同步任务会自动调用 finish()
        }
        
        batchGroup.add(task1)
        batchGroup.add(task2)
        batchGroup.add(task3)
        
        batchGroup.onAllTasksFinished = { success in
            print("All batch tasks completed: \(success)")
        }
        
        batchGroup.start()
    }
    
    func demonstrateChainTasks() {
        let chainGroup = TaskQueueManager.createChainGroup()
        
        let task1 = TaskOperation.async(identifier: "Step1") { task in
            print("Step 1: Authentication")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                print("Authentication successful")
                task.finish(true) // 继续下一步
            }
        }
        
        let task2 = TaskOperation.async(identifier: "Step2") { task in
            print("Step 2: Fetch user data")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                print("User data fetched")
                task.finish(true) // 继续下一步
            }
        }
        
        let task3 = TaskOperation.async(identifier: "Step3") { task in
            print("Step 3: Update UI")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("UI updated")
                task.finish(true) // 完成
            }
        }
        
        chainGroup.add(task1)
        chainGroup.add(task2)
        chainGroup.add(task3)
        
        chainGroup.onAllTasksFinished = { success in
            print("Chain completed: \(success)")
        }
        
        chainGroup.start()
    }
    
    func demonstrateFailureChain() {
        let chainGroup = TaskQueueManager.createChainGroup()
        
        let task1 = TaskOperation.async(identifier: "Step1") { task in
            print("Step 1: Check network")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                print("Network check failed")
                task.finish(false) // 终止链
            }
        }
        
        let task2 = TaskOperation.async(identifier: "Step2") { task in
            print("This should not execute")
            task.finish(true)
        }
        
        chainGroup.add(task1)
        chainGroup.add(task2)
        
        chainGroup.onAllTasksFinished = { success in
            print("Chain completed with success: \(success)") // 这里会输出 false
        }
        
        chainGroup.start()
    }
}

/**
// 运行示例
let example = TaskQueueExample()
example.demonstrateBatchTasks()
example.demonstrateChainTasks()
example.demonstrateFailureChain()
*/

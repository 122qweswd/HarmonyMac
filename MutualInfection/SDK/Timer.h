//
//  Timer.h
//  MutualInfection
//
//  Created by apple on 2025/9/26.
//
#ifndef TIMER_H
#define TIMER_H
#include <atomic>
#include <thread>
#include <functional>
#include <queue>
#include <mutex>
#include <condition_variable>
#include <chrono>
#include <memory>
#include <vector>

class TimerTask {
public:
    using TimePoint = std::chrono::steady_clock::time_point;
    
    int id;
    int intervalMs;
    int repeatCount;
    int executedCount;
    std::function<void()> task;
    TimePoint nextExecutionTime;
    bool isActive;
    
    TimerTask(int taskId, int interval, int repeat, std::function<void()> func)
        : id(taskId), intervalMs(interval), repeatCount(repeat), executedCount(0),
          task(std::move(func)), isActive(true) {
        updateNextExecutionTime();
    }
    
    void updateNextExecutionTime() {
        nextExecutionTime = std::chrono::steady_clock::now() +
                           std::chrono::milliseconds(intervalMs);
    }
    
    // 用于优先队列的比较函数
    bool operator>(const TimerTask& other) const {
        return nextExecutionTime > other.nextExecutionTime;
    }
};

class TimerQueue {
private:
    std::atomic<bool> running_{false};
    std::thread workerThread_;
    
    // 任务队列（最小堆，按执行时间排序）
    std::priority_queue<TimerTask, std::vector<TimerTask>,
                       std::greater<TimerTask>> taskQueue_;
    
    std::mutex queueMutex_;
    std::condition_variable condition_;
    
    int nextTaskId_{0};
    
public:
    TimerQueue() = default;
    
    ~TimerQueue() {
        stop();
    }
    
    // 禁止拷贝
    TimerQueue(const TimerQueue&) = delete;
    TimerQueue& operator=(const TimerQueue&) = delete;
    
    void start() {
        if (running_.exchange(true)) {
            return; // 已经在运行
        }
        
        workerThread_ = std::thread([this]() {
            this->workerLoop();
        });
        
    }
    
    void stop() {
        if (!running_.exchange(false)) {
            return; // 已经停止
        }
        
        condition_.notify_all();
        
        if (workerThread_.joinable()) {
            workerThread_.join();
        }
        
        // 清空队列
        std::lock_guard<std::mutex> lock(queueMutex_);
        while (!taskQueue_.empty()) {
            taskQueue_.pop();
        }
        
    }
    
    // 添加定时任务
    template<typename Callable, typename... Args>
    int addTask(int intervalMs, int repeatCount, Callable&& task, Args&&... args) {
        if (!running_.load()) {
            return -1;
        }
        
        // 绑定任务和参数
        auto boundTask = [task = std::forward<Callable>(task), args...]() mutable {
            task(args...);
        };
        
        int taskId = ++nextTaskId_;
        TimerTask newTask(taskId, intervalMs, repeatCount, std::move(boundTask));
        
        {
            std::lock_guard<std::mutex> lock(queueMutex_);
            taskQueue_.push(std::move(newTask));
        }
        
        condition_.notify_one();
        
        return taskId;
    }
    
    // 取消任务
    bool cancelTask(int taskId) {
        std::lock_guard<std::mutex> lock(queueMutex_);
        
        // 由于 priority_queue 不支持直接删除，我们需要重建队列
        std::vector<TimerTask> tempTasks;
        bool found = false;
        
        // 将任务转移到临时容器
        while (!taskQueue_.empty()) {
            TimerTask task = taskQueue_.top();
            taskQueue_.pop();
            
            if (task.id == taskId) {
                found = true;
            } else {
                tempTasks.push_back(std::move(task));
            }
        }
        
        // 将剩余任务放回队列
        for (auto& task : tempTasks) {
            taskQueue_.push(std::move(task));
        }
        
        return found;
    }
    
    // 获取队列中的任务数量
    size_t getTaskCount() {
        std::lock_guard<std::mutex> lock(queueMutex_);
        return taskQueue_.size();
    }
    
    // 检查队列是否运行
    bool isRunning() const {
        return running_.load();
    }

private:
    void workerLoop() {
        
        while (running_.load()) {
            std::unique_lock<std::mutex> lock(queueMutex_);
            
            if (taskQueue_.empty()) {
                // 队列为空，等待新任务
                condition_.wait(lock, [this]() {
                    return !taskQueue_.empty() || !running_.load();
                });
                
                if (!running_.load()) {
                    break;
                }
            }
            
            // 获取下一个任务的执行时间
            auto nextTaskTime = taskQueue_.top().nextExecutionTime;
            
            // 等待直到任务执行时间或新任务到达
            if (condition_.wait_until(lock, nextTaskTime, [this, nextTaskTime]() {
                return !running_.load() ||
                       (!taskQueue_.empty() && taskQueue_.top().nextExecutionTime != nextTaskTime);
            })) {
                // 被新任务或停止信号唤醒
                continue;
            }
            
            if (!running_.load()) {
                break;
            }
            
            if (taskQueue_.empty()) {
                continue;
            }
            // 执行任务
            TimerTask task = taskQueue_.top();
            taskQueue_.pop();
            
            lock.unlock(); // 释放锁，允许添加新任务
            
            try {
                if (task.isActive) {
                    task.task(); // 执行任务
                    task.executedCount++;
                    
                    // 检查是否需要重新调度
                    if (task.repeatCount == 0 || task.executedCount < task.repeatCount) {
                        task.updateNextExecutionTime();
                        
                        std::lock_guard<std::mutex> relock(queueMutex_);
                        taskQueue_.push(std::move(task));
                    } else {
                    }
                }
            } catch (const std::exception& e) {
            }
            
            lock.lock(); // 重新获取锁用于下一次循环
        }
        
    }
};

#endif // TIMER_H

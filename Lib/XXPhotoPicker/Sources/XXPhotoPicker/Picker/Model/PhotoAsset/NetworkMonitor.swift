//
//  File.swift
//  XXPhotoPicker
//
//  Created by Niko on 2025/10/25.
//

import Foundation
import Network

open class NetworkMonitor {
    public static let shared = NetworkMonitor()
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    open var isConnected: Bool = false
    var connectionType: ConnectionType = .unknown
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }
    
    private init() {
        monitor = NWPathMonitor()
    }
    
    open func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isConnected = path.status == .satisfied
            self?.updateConnectionType(path)
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .networkStatusDidChange,
                    object: nil,
                    userInfo: ["isConnected": self?.isConnected ?? false]
                )
            }
        }
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
    
    private func updateConnectionType(_ path: NWPath) {
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else {
            connectionType = .unknown
        }
    }
    
    /// 检查当前网络是否可用
    func checkNetworkAvailability() -> Bool {
        return isConnected
    }
}

// 扩展通知名称
extension Notification.Name {
    static let networkStatusDidChange = Notification.Name("NetworkStatusDidChange")
}

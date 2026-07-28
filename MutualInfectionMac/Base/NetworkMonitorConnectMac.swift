//
//  NetworkMonitorConnectMac.swift
//  MutualInfection
//
//  Created by 1234 on 2025/11/18.
//
import Foundation
import Network

class NetworkMonitorConnectMac {
    static let shared = NetworkMonitorConnectMac()
    private let monitor: NWPathMonitor
    private var status: NWPath.Status = .requiresConnection
    var isReachable: Bool { status == .satisfied }

    private init() {
        monitor = NWPathMonitor()
        startMonitoring()
    }

    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.status = path.status
            let dfxDBO=BigDataTracDBOMac()
            if Gloable.dfxAutoFlag == true
            {
                dfxDBO.dfxDataAutoPost()
            }
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
    }

    func stopMonitoring() {
        monitor.cancel()
        
    }
}

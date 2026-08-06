//
//  NodeRuntimeManager.swift
//  MutualInfectionMac
//
//  Created by Codex on 2026/7/30.
//

import Foundation
#if canImport(Darwin)
import Darwin
#endif

final class NodeRuntimeManager {
    private enum State: String { case idle, starting, running, stopping, stopped, failed }
    private let readyMarker = "a2a-gateway: HTTP listening"
    private let fileManager = FileManager.default
    private let stateQueue = DispatchQueue(label: "com.mutualinfectionmac.node-runtime")
    private var state: State = .idle
    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var runtimeLogHandle: FileHandle?
    private var stderrLogHandle: FileHandle?
    private var stdoutBuffer = Data()
    private var stderrBuffer = Data()
    private var didObserveReady = false

    deinit { stop() }

    func startIfNeeded() {
        stateQueue.async {
            guard self.state == .idle || self.state == .stopped || self.state == .failed else {
                self.log("跳过启动，当前状态=\(self.state.rawValue)")
                return
            }
            self.state = .starting
            self.didObserveReady = false
            do {
                let layout = try self.resolveLayout()
                try self.prepareWritableDirectories(with: layout)
                try self.prepareRuntimeConfig(with: layout)
                try self.openLogHandles(with: layout)
                try self.launchProcess(with: layout)
            } catch {
                self.state = .failed
                self.log("NodeRuntime 启动失败: \(error.localizedDescription)")
                self.closeLogHandles()
            }
        }
    }

    func stop() {
        stateQueue.sync {
            guard let process else {
                self.state = .stopped
                self.closeLogHandles()
                return
            }
            self.state = .stopping
            let processID = process.processIdentifier
            self.log("准备停止 NodeRuntime，pid=\(processID)")
            stdoutPipe?.fileHandleForReading.readabilityHandler = nil
            stderrPipe?.fileHandleForReading.readabilityHandler = nil
            if process.isRunning {
                terminateProcessGroup(processID, process: process)
                waitForProcessExit(process, timeout: 3)
            }
            self.process = nil
            self.stdoutPipe = nil
            self.stderrPipe = nil
            self.state = .stopped
            self.closeLogHandles()
        }
    }

    private func terminateProcessGroup(_ processID: pid_t, process: Process) {
        #if canImport(Darwin)
        if kill(-processID, SIGTERM) != 0 { process.terminate() }
        #else
        process.terminate()
        #endif
    }

    private func waitForProcessExit(_ process: Process, timeout: TimeInterval) {
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
        if process.isRunning {
            #if canImport(Darwin)
            _ = kill(-process.processIdentifier, SIGKILL)
            #else
            process.terminate()
            #endif
        }
    }

    private func launchProcess(with layout: Layout) throws {
        let process = Process()
        process.executableURL = layout.nodeBinaryURL
        process.arguments = [layout.openclawEntryURL.path, "gateway", "run", "--force", "--port", "\(layout.gatewayPort)"]
        process.currentDirectoryURL = layout.openclawRootURL
        var environment = ProcessInfo.processInfo.environment
        environment["OPENCLAW_HOME"] = layout.applicationSupportRootURL.path
        environment["OPENCLAW_STATE_DIR"] = layout.stateDirectoryURL.path
        environment["OPENCLAW_CONFIG_PATH"] = layout.runtimeConfigURL.path
        environment["MUTUAL_NODE_RUNTIME_APP_SUPPORT_DIR"] = layout.applicationSupportRootURL.path
        environment["MUTUAL_NODE_RUNTIME_LOG_DIR"] = layout.logsRootURL.path
        environment["MUTUAL_NODE_RUNTIME_CONFIG_PATH"] = layout.runtimeConfigURL.path
        process.environment = environment
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in self?.consumeOutput(from: handle, isError: false) }
        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in self?.consumeOutput(from: handle, isError: true) }
        process.terminationHandler = { [weak self] process in
            self?.stateQueue.async {
                guard let self else { return }
                self.log("NodeRuntime 进程退出，status=\(process.terminationStatus)")
                self.stdoutPipe?.fileHandleForReading.readabilityHandler = nil
                self.stderrPipe?.fileHandleForReading.readabilityHandler = nil
                self.process = nil
                self.stdoutPipe = nil
                self.stderrPipe = nil
                self.state = .stopped
                self.closeLogHandles()
            }
        }
        try process.run()
        #if canImport(Darwin)
        _ = setpgid(process.processIdentifier, process.processIdentifier)
        #endif
        self.process = process
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe
        self.state = .running
        self.log("NodeRuntime 已启动，pid=\(process.processIdentifier)，gateway 端口=\(layout.gatewayPort)")
    }

    private func consumeOutput(from handle: FileHandle, isError: Bool) {
        let data = handle.availableData
        guard !data.isEmpty else { return }
        stateQueue.async {
            if isError { self.stderrBuffer.append(data); self.flushBuffer(isError: true) }
            else { self.stdoutBuffer.append(data); self.flushBuffer(isError: false) }
        }
    }

    private func flushBuffer(isError: Bool) {
        let newline = Data([0x0A])
        var buffer = isError ? stderrBuffer : stdoutBuffer
        while let range = buffer.range(of: newline) {
            let lineData = buffer.subdata(in: 0..<range.lowerBound)
            buffer.removeSubrange(0..<range.upperBound)
            handleLine(String(data: lineData, encoding: .utf8) ?? "<non-utf8>", isError: isError)
        }
        if isError { stderrBuffer = buffer } else { stdoutBuffer = buffer }
    }

    private func handleLine(_ line: String, isError: Bool) {
        if !isError && line.contains(readyMarker) && !didObserveReady {
            didObserveReady = true
            log("openclaw ready 信号已收到（a2a-gateway HTTP listening）")
        }
        log("\(isError ? "[NodeRuntime][stderr]" : "[NodeRuntime][stdout]") \(line)")
        appendLogLine(line, isError: isError)
    }

    private func appendLogLine(_ line: String, isError: Bool) {
        guard let data = "\(line)\n".data(using: .utf8) else { return }
        let handle = isError ? stderrLogHandle : runtimeLogHandle
        handle?.seekToEndOfFile()
        handle?.write(data)
    }

    private func prepareWritableDirectories(with layout: Layout) throws {
        try fileManager.createDirectory(at: layout.applicationSupportRootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: layout.logsRootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: layout.runtimeConfigDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: layout.stateDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: layout.cacheDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: layout.tmpDirectoryURL, withIntermediateDirectories: true)
    }

    private static let configTemplateVersion = 10

    private func prepareRuntimeConfig(with layout: Layout) throws {
        let configURL = layout.runtimeConfigURL
        let versionURL = layout.runtimeConfigVersionURL
        let rawVersion = try? String(contentsOf: versionURL, encoding: .utf8)
        let appliedVersion = rawVersion.flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        guard !fileManager.fileExists(atPath: configURL.path) || appliedVersion != Self.configTemplateVersion else { return }
        if fileManager.fileExists(atPath: layout.openclawTemplateURL.path) {
            if fileManager.fileExists(atPath: configURL.path) { try? fileManager.removeItem(at: configURL) }
            try fileManager.copyItem(at: layout.openclawTemplateURL, to: configURL)
        } else {
            let fallback = "{\"gateway\":{\"mode\":\"local\"},\"plugins\":{\"entries\":{\"a2a-gateway\":{\"enabled\":true,\"config\":{\"server\":{\"host\":\"127.0.0.1\",\"port\":18810},\"security\":{\"inboundAuth\":\"none\"}}}}}}"
            try fallback.write(to: configURL, atomically: true, encoding: .utf8)
        }
        try "\(Self.configTemplateVersion)".write(to: versionURL, atomically: true, encoding: .utf8)
        log("已按模板重新生成 openclaw 配置（版本 \(Self.configTemplateVersion)）")
    }

    private func openLogHandles(with layout: Layout) throws {
        if !fileManager.fileExists(atPath: layout.runtimeLogURL.path) { fileManager.createFile(atPath: layout.runtimeLogURL.path, contents: nil) }
        if !fileManager.fileExists(atPath: layout.stderrLogURL.path) { fileManager.createFile(atPath: layout.stderrLogURL.path, contents: nil) }
        runtimeLogHandle = try FileHandle(forWritingTo: layout.runtimeLogURL)
        stderrLogHandle = try FileHandle(forWritingTo: layout.stderrLogURL)
    }

    private func closeLogHandles() {
        try? runtimeLogHandle?.close()
        try? stderrLogHandle?.close()
        runtimeLogHandle = nil
        stderrLogHandle = nil
        stdoutBuffer.removeAll(keepingCapacity: false)
        stderrBuffer.removeAll(keepingCapacity: false)
    }

    private func resolveLayout() throws -> Layout {
        guard let resourceURL = Bundle.main.resourceURL else { throw NodeRuntimeError.missingBundleResourceRoot }
        let root = resourceURL.appendingPathComponent("NodeRuntime", isDirectory: true)
        let node = root.appendingPathComponent("node/bin/node")
        let openclaw = root.appendingPathComponent("openclaw", isDirectory: true)
        let template = root.appendingPathComponent("config/openclaw.template.json")
        guard let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { throw NodeRuntimeError.missingApplicationSupportDirectory }
        guard let library = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first else { throw NodeRuntimeError.missingLibraryDirectory }
        let appSupport = support.appendingPathComponent("MutualInfectionMac/NodeRuntime", isDirectory: true)
        let logs = library.appendingPathComponent("Logs/MutualInfectionMac/NodeRuntime", isDirectory: true)
        let configDir = appSupport.appendingPathComponent("config", isDirectory: true)
        return Layout(nodeBinaryURL: node, openclawRootURL: openclaw, openclawEntryURL: openclaw.appendingPathComponent("openclaw.mjs"), openclawTemplateURL: template, applicationSupportRootURL: appSupport, logsRootURL: logs, runtimeConfigDirectoryURL: configDir, runtimeConfigURL: configDir.appendingPathComponent("openclaw.json"), runtimeConfigVersionURL: configDir.appendingPathComponent(".template_version"), stateDirectoryURL: appSupport.appendingPathComponent("state"), cacheDirectoryURL: appSupport.appendingPathComponent("cache"), tmpDirectoryURL: appSupport.appendingPathComponent("tmp"), runtimeLogURL: logs.appendingPathComponent("runtime.log"), stderrLogURL: logs.appendingPathComponent("stderr.log"))
    }

    private func log(_ message: String) { ShareAPI.shared().log(1, "[NodeRuntimeManager] \(message)") }
}

private extension NodeRuntimeManager {
    struct Layout {
        let nodeBinaryURL: URL
        let openclawRootURL: URL
        let openclawEntryURL: URL
        let openclawTemplateURL: URL
        let applicationSupportRootURL: URL
        let logsRootURL: URL
        let runtimeConfigDirectoryURL: URL
        let runtimeConfigURL: URL
        let runtimeConfigVersionURL: URL
        let stateDirectoryURL: URL
        let cacheDirectoryURL: URL
        let tmpDirectoryURL: URL
        let runtimeLogURL: URL
        let stderrLogURL: URL
        let gatewayPort: Int = 18800
    }

    enum NodeRuntimeError: LocalizedError {
        case missingBundleResourceRoot, missingApplicationSupportDirectory, missingLibraryDirectory
        var errorDescription: String? {
            switch self {
            case .missingBundleResourceRoot: return "无法解析 Bundle 资源目录"
            case .missingApplicationSupportDirectory: return "无法解析 Application Support 目录"
            case .missingLibraryDirectory: return "无法解析 Library 目录"
            }
        }
    }
}

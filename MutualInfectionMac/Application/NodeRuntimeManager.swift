//
//  NodeRuntimeManager.swift
//  MutualInfectionMac
//
//  Created by Codex on 2026/7/30.
//

import Foundation

final class NodeRuntimeManager {
    private enum State: String {
        case idle
        case starting
        case running
        case stopping
        case stopped
        case failed
    }

    private let readyMarker = "NODE_RUNTIME_READY"
    private let stoppedMarker = "NODE_RUNTIME_STOPPED"

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

    deinit {
        stop()
    }

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
            self.log("准备停止 NodeRuntime，pid=\(process.processIdentifier)")

            stdoutPipe?.fileHandleForReading.readabilityHandler = nil
            stderrPipe?.fileHandleForReading.readabilityHandler = nil

            if process.isRunning {
                process.terminate()
            }

            self.process = nil
            self.stdoutPipe = nil
            self.stderrPipe = nil
            self.state = .stopped
            self.closeLogHandles()
        }
    }

    private func launchProcess(with layout: Layout) throws {
        let process = Process()
        process.executableURL = layout.nodeBinaryURL
        process.arguments = [
            layout.hostEntryURL.path,
            "--config",
            layout.runtimeConfigURL.path
        ]
        process.currentDirectoryURL = layout.hostDirectoryURL

        var environment = ProcessInfo.processInfo.environment
        environment["MUTUAL_NODE_RUNTIME_APP_SUPPORT_DIR"] = layout.applicationSupportRootURL.path
        environment["MUTUAL_NODE_RUNTIME_LOG_DIR"] = layout.logsRootURL.path
        environment["MUTUAL_NODE_RUNTIME_CONFIG_PATH"] = layout.runtimeConfigURL.path
        process.environment = environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            self?.consumeOutput(from: handle, isError: false)
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            self?.consumeOutput(from: handle, isError: true)
        }

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

        self.process = process
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe
        self.state = .running
        self.log("NodeRuntime 已启动，pid=\(process.processIdentifier)")
    }

    private func consumeOutput(from handle: FileHandle, isError: Bool) {
        let data = handle.availableData
        guard !data.isEmpty else { return }

        stateQueue.async {
            if isError {
                self.stderrBuffer.append(data)
                self.flushBuffer(isError: true)
            } else {
                self.stdoutBuffer.append(data)
                self.flushBuffer(isError: false)
            }
        }
    }

    private func flushBuffer(isError: Bool) {
        let newline = Data([0x0A])
        var buffer = isError ? stderrBuffer : stdoutBuffer

        while let range = buffer.range(of: newline) {
            let lineData = buffer.subdata(in: 0..<range.lowerBound)
            buffer.removeSubrange(0..<range.upperBound)
            let line = String(data: lineData, encoding: .utf8) ?? "<non-utf8>"
            handleLine(line, isError: isError)
        }

        if isError {
            stderrBuffer = buffer
        } else {
            stdoutBuffer = buffer
        }
    }

    private func handleLine(_ line: String, isError: Bool) {
        if !isError, line.contains(readyMarker), !didObserveReady {
            didObserveReady = true
            log("NodeRuntime ready 信号已收到")
        }

        if !isError, line.contains(stoppedMarker) {
            log("NodeRuntime 停止标记已收到")
        }

        let prefix = isError ? "[NodeRuntime][stderr]" : "[NodeRuntime][stdout]"
        log("\(prefix) \(line)")
        appendLogLine(line, isError: isError)
    }

    private func appendLogLine(_ line: String, isError: Bool) {
        guard let data = "\(line)\n".data(using: .utf8) else { return }
        let handle = isError ? stderrLogHandle : runtimeLogHandle
        do {
            try handle?.seekToEnd()
            try handle?.write(contentsOf: data)
        } catch {
            log("写入 NodeRuntime 日志失败: \(error.localizedDescription)")
        }
    }

    private func prepareWritableDirectories(with layout: Layout) throws {
        try fileManager.createDirectory(at: layout.applicationSupportRootURL, withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: layout.logsRootURL, withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: layout.runtimeConfigDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: layout.stateDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: layout.cacheDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: layout.tmpDirectoryURL, withIntermediateDirectories: true, attributes: nil)
    }

    private func prepareRuntimeConfig(with layout: Layout) throws {
        if !fileManager.fileExists(atPath: layout.runtimeConfigURL.path) {
            if fileManager.fileExists(atPath: layout.runtimeConfigTemplateURL.path) {
                try fileManager.copyItem(at: layout.runtimeConfigTemplateURL, to: layout.runtimeConfigURL)
            } else {
                let fallback = """
                {
                  "version": 1,
                  "hostEntry": "index.js",
                  "logLevel": "info",
                  "heartbeatIntervalMs": 30000
                }
                """
                try fallback.write(to: layout.runtimeConfigURL, atomically: true, encoding: .utf8)
            }
        }
    }

    private func openLogHandles(with layout: Layout) throws {
        if !fileManager.fileExists(atPath: layout.runtimeLogURL.path) {
            _ = fileManager.createFile(atPath: layout.runtimeLogURL.path, contents: nil)
        }
        if !fileManager.fileExists(atPath: layout.stderrLogURL.path) {
            _ = fileManager.createFile(atPath: layout.stderrLogURL.path, contents: nil)
        }

        runtimeLogHandle = try FileHandle(forWritingTo: layout.runtimeLogURL)
        stderrLogHandle = try FileHandle(forWritingTo: layout.stderrLogURL)
    }

    private func closeLogHandles() {
        do {
            try runtimeLogHandle?.close()
            try stderrLogHandle?.close()
        } catch {
            log("关闭 NodeRuntime 日志句柄失败: \(error.localizedDescription)")
        }

        runtimeLogHandle = nil
        stderrLogHandle = nil
        stdoutBuffer.removeAll(keepingCapacity: false)
        stderrBuffer.removeAll(keepingCapacity: false)
    }

    private func resolveLayout() throws -> Layout {
        guard let resourceURL = Bundle.main.resourceURL else {
            throw NodeRuntimeError.missingBundleResourceRoot
        }

        let runtimeRootURL = resourceURL.appendingPathComponent("NodeRuntime", isDirectory: true)
        let nodeBinaryURL = runtimeRootURL
            .appendingPathComponent("node", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("node", isDirectory: false)
        let hostDirectoryURL = runtimeRootURL.appendingPathComponent("host", isDirectory: true)
        let hostEntryURL = hostDirectoryURL
            .appendingPathComponent("dist", isDirectory: true)
            .appendingPathComponent("index.js", isDirectory: false)
        let runtimeConfigTemplateURL = runtimeRootURL
            .appendingPathComponent("config", isDirectory: true)
            .appendingPathComponent("runtime-config.template.json", isDirectory: false)

        guard let applicationSupportBaseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw NodeRuntimeError.missingApplicationSupportDirectory
        }
        guard let libraryBaseURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            throw NodeRuntimeError.missingLibraryDirectory
        }

        let applicationSupportRootURL = applicationSupportBaseURL
            .appendingPathComponent("MutualInfectionMac", isDirectory: true)
            .appendingPathComponent("NodeRuntime", isDirectory: true)
        let logsRootURL = libraryBaseURL
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("MutualInfectionMac", isDirectory: true)
            .appendingPathComponent("NodeRuntime", isDirectory: true)

        let runtimeConfigDirectoryURL = applicationSupportRootURL.appendingPathComponent("config", isDirectory: true)
        let runtimeConfigURL = runtimeConfigDirectoryURL.appendingPathComponent("runtime-config.json", isDirectory: false)
        let stateDirectoryURL = applicationSupportRootURL.appendingPathComponent("state", isDirectory: true)
        let cacheDirectoryURL = applicationSupportRootURL.appendingPathComponent("cache", isDirectory: true)
        let tmpDirectoryURL = applicationSupportRootURL.appendingPathComponent("tmp", isDirectory: true)
        let runtimeLogURL = logsRootURL.appendingPathComponent("runtime.log", isDirectory: false)
        let stderrLogURL = logsRootURL.appendingPathComponent("stderr.log", isDirectory: false)

        return Layout(
            nodeBinaryURL: nodeBinaryURL,
            hostDirectoryURL: hostDirectoryURL,
            hostEntryURL: hostEntryURL,
            runtimeConfigTemplateURL: runtimeConfigTemplateURL,
            applicationSupportRootURL: applicationSupportRootURL,
            logsRootURL: logsRootURL,
            runtimeConfigDirectoryURL: runtimeConfigDirectoryURL,
            runtimeConfigURL: runtimeConfigURL,
            stateDirectoryURL: stateDirectoryURL,
            cacheDirectoryURL: cacheDirectoryURL,
            tmpDirectoryURL: tmpDirectoryURL,
            runtimeLogURL: runtimeLogURL,
            stderrLogURL: stderrLogURL
        )
    }

    private func log(_ message: String) {
        ShareAPI.shared().log(1, "[NodeRuntimeManager] \(message)")
    }
}

private extension NodeRuntimeManager {
    struct Layout {
        let nodeBinaryURL: URL
        let hostDirectoryURL: URL
        let hostEntryURL: URL
        let runtimeConfigTemplateURL: URL
        let applicationSupportRootURL: URL
        let logsRootURL: URL
        let runtimeConfigDirectoryURL: URL
        let runtimeConfigURL: URL
        let stateDirectoryURL: URL
        let cacheDirectoryURL: URL
        let tmpDirectoryURL: URL
        let runtimeLogURL: URL
        let stderrLogURL: URL
    }

    enum NodeRuntimeError: LocalizedError {
        case missingBundleResourceRoot
        case missingApplicationSupportDirectory
        case missingLibraryDirectory

        var errorDescription: String? {
            switch self {
            case .missingBundleResourceRoot:
                return "无法解析 Bundle 资源目录"
            case .missingApplicationSupportDirectory:
                return "无法解析 Application Support 目录"
            case .missingLibraryDirectory:
                return "无法解析 Library 目录"
            }
        }
    }
}

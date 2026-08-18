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
    /// 本机在 A2A 网络里的身份名；须与 openclaw.template.json 的
    /// tunnel.deviceId / registry.serviceId / agentCard.name 保持一致。
    static let localDeviceName = "TargetMac"
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
                self.prepareWorkspaceContext(with: layout)
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
        // 授权目录注入 a2a-gateway：让 a2a_send_local_file 的 allowedPrefixes 含这些目录（与 entitlement 同步）
        environment["A2A_LOCAL_FILE_ROOTS"] = Self.authorizedWorkDirs.joined(separator: ":")
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

    /// 写入 workspace 的 AGENTS.md，告知 Agent 授权工作目录（语义层）。
    /// 授权目录清单须与 .entitlements 的 temporary-exception.files.absolute-path.read-write 保持一致（路径含 trailing slash 表示目录递归）。
    private func prepareWorkspaceContext(with layout: Layout) {
        // OpenClaw workspace = $OPENCLAW_HOME/.openclaw/workspace（OPENCLAW_HOME 即 applicationSupportRootURL）
        let workspaceURL = layout.applicationSupportRootURL
            .appendingPathComponent(".openclaw", isDirectory: true)
            .appendingPathComponent("workspace", isDirectory: true)
        try? fileManager.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        // 覆盖写入 AGENTS.md：授权目录清单由项目控制（与 .entitlements 同步）
        let dirs = Self.authorizedWorkDirs
        let list = dirs.map { "- \($0)" }.joined(separator: "\n")
        let inboxDir = layout.stateDirectoryURL.appendingPathComponent("a2a-files").path
        let content = """
# 授权工作目录

你可以使用文件工具在以下目录内读取、写入、创建文件：

\(list)

这些目录之外（如 /tmp、~/Documents）由 macOS 沙盒保护，访问会被拒绝。
首次访问 ~/Desktop 时，还需要用户允许 macOS 的“桌面文件夹”权限。
用户未给绝对路径时，默认在上述目录内操作。

# 接收对端文件后的搬运

对端（手机等）通过 a2a-gateway 发来的入站文件，会先由网关自动落到临时收件目录：

- \(inboxDir)/

此目录在 App 沙盒容器内，用户在 Finder 里看不到。系统随后会给你一段以「【A2A 文件接收成功】」开头的文本，其中含「保存路径」字段（临时收件目录中的绝对路径）。你必须按以下策略处理：

1. 若用户没有指定目的地：如实汇报「保存路径」的绝对路径，不要改写。
2. 若用户指定的目的地位于上面「授权工作目录」清单内（例如“存到桌面”→ /Users/jiahaoli/Desktop/）：
   - 用文件工具把文件从「保存路径」移动或复制到该目录（保留原文件名，重名时追加 (1)、(2) 等后缀）；
   - 然后向用户汇报**移动后**的最终绝对路径，不要再提临时收件目录。
3. 若用户指定的目的地不在授权目录内：拒绝搬运，向用户说明仅授权目录内可以落盘，并给出临时收件目录中的绝对路径。

搬运时使用绝对路径，禁止编造路径或使用相对路径。
"""
        try? content.data(using: .utf8)?.write(to: workspaceURL.appendingPathComponent("AGENTS.md"))
        // 删除 BOOTSTRAP.md：避免首次 onboarding ritual 干扰嵌入式 a2a agent
        try? fileManager.removeItem(at: workspaceURL.appendingPathComponent("BOOTSTRAP.md"))
        prepareWorkspaceIdentityFiles(at: workspaceURL, with: layout)
    }

    /// 写入 workspace 的 MEMORY.md / TOOLS.md：让 agent 知道本机/对端身份与 A2A 用法。
    /// 身份信息由项目控制（与 openclaw.template.json 的 agentCard / registry 保持一致）。
    private func prepareWorkspaceIdentityFiles(at workspaceURL: URL, with layout: Layout) {
        let deviceName = Self.localDeviceName
        let filesDir = layout.stateDirectoryURL.appendingPathComponent("a2a-files").path
        let memory = """
        # 本机与对端

        - 本机名：\(deviceName)（A2A Agent Card 名称）
        - 对端 peer：`HW-Phone1`（通过注册中心发现，经公网隧道通信）
        - 本机 A2A：端口 18810；手机 A2A：端口 18800。
        - 共享令牌：两端必须完全一致，见 openclaw.json 的 `plugins.entries.a2a-gateway.config.security.token`。
        - 收发文件暂存目录：\(filesDir)
        """
        let tools = """
        # A2A Gateway 用法

        本机 a2a-gateway 连接 `124.71.140.180:8000` 的公网中继和注册中心。
        `peer` 使用注册中心发现的服务名 `HW-Phone1`。本机控制 gateway 监听 18800，A2A 服务监听 18810。

        ## 发消息给对端
        ```
        openclaw gateway call a2a.send --token "$GATEWAY_TOKEN" --timeout 300000 \\
          --params '{"peer":"HW-Phone1","message":{"text":"你好"}}'
        ```

        ## 发本地文件给对端
        ```
        openclaw gateway call a2a.send_local_file --token "$GATEWAY_TOKEN" --timeout 300000 \\
          --params '{"peer":"HW-Phone1","path":"<本地绝对路径>"}'
        ```
        `path` 必须是绝对路径，且在授权目录内（见 AGENTS.md）。

        ## 说明
        - `$GATEWAY_TOKEN` = openclaw.json 的 `gateway.auth.token`（本机自用令牌）。
        - 长耗时任务可增大 `--timeout`；返回 `Request accepted` 表示异步任务，需轮询 `tasks/get`。
        - 对端 not found：对端未向注册中心注册、发现尚未刷新，或 peer 名不是 `HW-Phone1`。
        - unauthorized：`--token` 缺失或与 gateway.auth.token 不一致。
        """
        try? memory.data(using: .utf8)?.write(to: workspaceURL.appendingPathComponent("MEMORY.md"))
        try? tools.data(using: .utf8)?.write(to: workspaceURL.appendingPathComponent("TOOLS.md"))
    }

    /// 授权工作目录清单（macOS）：须与 .entitlements 的 temporary-exception.files.absolute-path.read-write
    /// 保持一致（含 trailing slash）。三处共用：写 workspace AGENTS.md（语义层）、注入 A2A_LOCAL_FILE_ROOTS
    /// （a2a_send_local_file 的 allowedPrefixes）。改目录时同步 .entitlements。
    private static let authorizedWorkDirs = [
        "/Users/jiahaoli/project/harmonymac/",
        "/Users/jiahaoli/Agent_Workspace/",
        "/Users/jiahaoli/Desktop/",
    ]

    private static let configTemplateVersion = 24

    private func prepareRuntimeConfig(with layout: Layout) throws {
        let configURL = layout.runtimeConfigURL
        let versionURL = layout.runtimeConfigVersionURL
        let appliedMarker = try? String(contentsOf: versionURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let expectedMarker = try configTemplateMarker(at: layout.openclawTemplateURL)
        guard !fileManager.fileExists(atPath: configURL.path) || appliedMarker != expectedMarker else { return }
        if fileManager.fileExists(atPath: layout.openclawTemplateURL.path) {
            if fileManager.fileExists(atPath: configURL.path) { try? fileManager.removeItem(at: configURL) }
            try fileManager.copyItem(at: layout.openclawTemplateURL, to: configURL)
            try materializeConfigPlaceholders(at: configURL, with: layout)
        } else {
            let fallback = "{\"gateway\":{\"mode\":\"local\"},\"plugins\":{\"entries\":{\"a2a-gateway\":{\"enabled\":true,\"config\":{\"server\":{\"host\":\"127.0.0.1\",\"port\":18810},\"security\":{\"inboundAuth\":\"none\"}}}}}}"
            try fallback.write(to: configURL, atomically: true, encoding: .utf8)
        }
        try expectedMarker.write(to: versionURL, atomically: true, encoding: .utf8)
        log("已按模板重新生成 openclaw 配置（标记 \(expectedMarker)）")
    }

    /// 版本号处理结构变更，内容指纹处理模板参数变更（例如换网后的手机 IP）。
    private func configTemplateMarker(at templateURL: URL) throws -> String {
        guard fileManager.fileExists(atPath: templateURL.path) else {
            return "\(Self.configTemplateVersion):fallback"
        }
        let data = try Data(contentsOf: templateURL)
        var fingerprint: UInt64 = 14_695_981_039_346_656_037
        for byte in data {
            fingerprint ^= UInt64(byte)
            fingerprint &*= 1_099_511_628_211
        }
        return "\(Self.configTemplateVersion):\(String(fingerprint, radix: 16))"
    }

    /// 把模板里的路径占位符替换成运行时绝对路径。
    /// 解析运行时目录与当前局域网 IPv4，保证 Agent Card 发布手机可达的 URL。
    /// 落在 macOS 可写目录下，不依赖 openclaw 是否对这些字段展开 ${ENV}。
    /// token 等明文值由模板直接提供，不在此处理。
    private func materializeConfigPlaceholders(at configURL: URL, with layout: Layout) throws {
        let raw = try String(contentsOf: configURL, encoding: .utf8)
        let rendered = raw
            .replacingOccurrences(of: "${OPENCLAW_STATE_DIR}", with: layout.stateDirectoryURL.path)
            .replacingOccurrences(of: "${OPENCLAW_HOME}", with: layout.applicationSupportRootURL.path)
            .replacingOccurrences(of: "${FUZZY_SEARCH_TOOL_PATH}", with: layout.fuzzySearchToolURL.path)
            .replacingOccurrences(of: "${A2A_LAN_IP}", with: preferredLANIPv4Address() ?? "127.0.0.1")
        try rendered.write(to: configURL, atomically: true, encoding: .utf8)
        // 预创建 a2a 运行时目录，避免插件首次写入失败
        try? fileManager.createDirectory(at: layout.stateDirectoryURL.appendingPathComponent("a2a-tasks", isDirectory: true), withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: layout.stateDirectoryURL.appendingPathComponent("a2a-files", isDirectory: true), withIntermediateDirectories: true)
    }

    /// 优先选择物理网络接口，避开 loopback、VPN 与 Apple 点对点虚拟接口。
    private func preferredLANIPv4Address() -> String? {
        var firstAddress: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&firstAddress) == 0, let firstAddress else { return nil }
        defer { freeifaddrs(firstAddress) }

        var candidates: [(priority: Int, address: String)] = []
        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddress
        while let current = cursor {
            let interface = current.pointee
            defer { cursor = interface.ifa_next }
            guard let socketAddress = interface.ifa_addr,
                  socketAddress.pointee.sa_family == UInt8(AF_INET) else { continue }

            let flags = Int32(interface.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0 else { continue }

            let name = String(cString: interface.ifa_name)
            guard !name.hasPrefix("utun"),
                  !name.hasPrefix("awdl"),
                  !name.hasPrefix("llw"),
                  !name.hasPrefix("bridge") else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(
                socketAddress,
                socklen_t(socketAddress.pointee.sa_len),
                &host,
                socklen_t(host.count),
                nil,
                0,
                NI_NUMERICHOST
            ) == 0 else { continue }

            let priority = name == "en0" ? 0 : (name == "en1" ? 1 : 10)
            candidates.append((priority, String(cString: host)))
        }

        return candidates.sorted { $0.priority < $1.priority }.first?.address
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
        return Layout(nodeBinaryURL: node, openclawRootURL: openclaw, openclawEntryURL: openclaw.appendingPathComponent("openclaw.mjs"), openclawTemplateURL: template, fuzzySearchToolURL: root.appendingPathComponent("tools/myers-bit-parallel-fuzzy-search"), applicationSupportRootURL: appSupport, logsRootURL: logs, runtimeConfigDirectoryURL: configDir, runtimeConfigURL: configDir.appendingPathComponent("openclaw.json"), runtimeConfigVersionURL: configDir.appendingPathComponent(".template_version"), stateDirectoryURL: appSupport.appendingPathComponent("state"), cacheDirectoryURL: appSupport.appendingPathComponent("cache"), tmpDirectoryURL: appSupport.appendingPathComponent("tmp"), runtimeLogURL: logs.appendingPathComponent("runtime.log"), stderrLogURL: logs.appendingPathComponent("stderr.log"))
    }

    private func log(_ message: String) { ShareAPI.shared().log(1, "[NodeRuntimeManager] \(message)") }
}

private extension NodeRuntimeManager {
    struct Layout {
        let nodeBinaryURL: URL
        let openclawRootURL: URL
        let openclawEntryURL: URL
        let openclawTemplateURL: URL
        let fuzzySearchToolURL: URL
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

# 阶段 3 — Swift 侧改造：拉起 openclaw

> 状态：✅ 代码改造完成（`getDiagnostics` 无语法错误）；⚠️ 编译/运行验证需 Xcode 环境（本机仅 CLT）
> 日期：2026-08-04

## 目标

把 `NodeRuntimeManager` 从"拉起心跳桩"改造为"拉起 openclaw agent runtime"，并注入 a2a-gateway 运行配置、重定向运行时目录到 App 私有目录、用 openclaw 原生日志识别 ready。

## 修改的文件清单

| 路径 | 变更 | 说明 |
|------|------|------|
| `MutualInfectionMac/Application/NodeRuntimeManager.swift` | **重写** | 见下"before/after" |
| `MutualInfectionMac/AppDelegate.swift` | **未改** | `startIfNeeded()`/`stop()` 签名不变，启动/停止挂钩点（`applicationDidFinishLaunching`/`terminate`）原样保留 |

## 关键改动 before / after

| 项 | before（心跳桩） | after（openclaw） |
|----|------|------|
| `Layout` 字段 | `hostDirectoryURL`、`hostEntryURL`、`runtimeConfigTemplateURL` | 删除；新增 `openclawRootURL`、`openclawEntryURL`、`openclawTemplateURL`、`gatewayPort`（=18800） |
| `readyMarker` | `"NODE_RUNTIME_READY"`（心跳桩主动输出） | `"a2a-gateway: HTTP listening"`（识别 openclaw 启动日志） |
| `launchProcess` arguments | `[hostEntry, "--config", configPath]` | `[openclawEntry, "gateway", "run", "--force", "--port", "18800"]` |
| `launchProcess` 工作目录 | `hostDirectoryURL`（`NodeRuntime/host/`） | `openclawRootURL`（`NodeRuntime/openclaw/`） |
| `launchProcess` 环境变量 | 仅 `MUTUAL_NODE_RUNTIME_*` | 新增 `OPENCLAW_HOME`、`OPENCLAW_STATE_DIR`、`OPENCLAW_CONFIG_PATH`（重定向到 App Application Support）；保留 `MUTUAL_NODE_RUNTIME_*` |
| `prepareRuntimeConfig` | 拷 `runtime-config.template.json` → `runtime-config.json` | 拷 `openclaw.template.json` → `openclaw.json`（含 `gateway.mode=local` + a2a-gateway 配置） |
| `resolveLayout` 路径 | `NodeRuntime/host/dist/index.js` 等 | `NodeRuntime/openclaw/openclaw.mjs`、`NodeRuntime/config/openclaw.template.json`；运行配置文件名 `openclaw.json` |
| `handleLine` | 识别 `NODE_RUNTIME_READY` + `NODE_RUNTIME_STOPPED` | 识别 `a2a-gateway: HTTP listening`（去掉 stoppedMarker，openclaw 退出由 `terminationHandler` 处理） |

## 执行的操作

无命令行操作；纯 Swift 代码改造。改造基于阶段 0–2 验证的事实：

1. **启动命令**：`node openclaw.mjs gateway run --force --port <port>`（阶段 0/2 验证可起常驻进程）
2. **配置注入**：`OPENCLAW_CONFIG_PATH` 指向 `openclaw.json`，内含 `gateway.mode=local`（免 `--allow-unconfigured`，阶段 1 验证）+ `plugins.entries.a2a-gateway`（阶段 0 验证）
3. **目录重定向**：`OPENCLAW_HOME`/`OPENCLAW_STATE_DIR` 把运行时写入限制在 App Application Support（阶段 0 验证有效，避免写 `~/.openclaw`）
4. **ready 信号**：openclaw 日志 `a2a-gateway: HTTP listening on 127.0.0.1:<port>`（阶段 0/2 观察到）

## 验证结果

| 验证项 | 结果 | 说明 |
|--------|------|------|
| Swift 语法诊断 | ✅ | `getDiagnostics` 返回空（无错误） |
| 启动/停止签名兼容 | ✅ | `startIfNeeded()`/`stop()` 未变，AppDelegate 无需改 |
| 逻辑正确性 | ✅（静态） | 路径/参数/环境变量与阶段 0–2 实测一致 |
| 编译 + 运行 | ⚠️ 待验 | 需 Xcode（本机仅 CLT，无 `xcodebuild`）→ 阶段 4 |

## 遇到的问题与决策

### ① ready 检测用日志字符串而非 HTTP 轮询
- 计划原拟 HTTP 轮询 `/.well-known/agent-card.json`，但阶段 0 发现该端点在定制版 404（路由未代理到 a2a app）。
- 改为识别 stdout 日志 `a2a-gateway: HTTP listening`，是 openclaw 原生输出、阶段 0/2 已验证稳定出现。
- 如后续需要更强的 ready 保证，可加 HTTP 轮询 `/health`（已验证 200）作为二次确认——但当前日志识别已够用。

### ② 端口：`--port` 与 a2a-gateway `server.port`
- `--port 18800` 控制 gateway 主端口；a2a-gateway HTTP 端口由 config `server.port` 决定。
- 本阶段两者都设为 18800（`gatewayPort` + 模板 `server.port`），阶段 0 实测两者共存于 18800 正常。
- 如需分离，改 config 模板的 `server.port` 与 `gatewayPort` 即可（但 ready 日志会显示 a2a 实际端口）。

### ③ 编译验证受环境限制
- 本机 `xcode-select` 指向 CommandLineTools，无完整 Xcode，无法 `xcodebuild` 编译验证。
- 决策：阶段 3 用 `getDiagnostics` + 人工审查保证语法/逻辑；实际编译运行验证留阶段 4（用户 Xcode 环境）。

## 下一步

进入阶段 4：在 Xcode 环境构建 `MutualInfectionMac`、启动 App，端到端验证 openclaw 起来、`/health` 可访问、退出时进程清理。本机无 Xcode，阶段 4 以"用户验证清单"形式给出。

# 阶段 3 — Swift 侧改造：托管 OpenClaw 与注入运行上下文

> 状态：✅ 已完成，并从“启动 OpenClaw”继续演进到 A2A 双端运行上下文
> 原执行日期：2026-08-04
> 最后同步：2026-08-20

## 目标

将 `NodeRuntimeManager` 从最小 Node 心跳桩托管器改造为完整的 OpenClaw 宿主：

- 用私有 Node 拉起 OpenClaw gateway；
- 管理进程组、日志与生命周期；
- 将状态和配置重定向到 App 可写目录；
- 生成合法、可升级的运行配置；
- 注入 Agent workspace、设备身份、授权目录和 A2A 文件能力。

## 修改文件

| 路径 | 当前作用 |
|---|---|
| `MutualInfectionMac/Application/NodeRuntimeManager.swift` | 核心宿主与上下文注入器，当前约 440 行 |
| `MutualInfectionMac/AppDelegate.swift` | App 启动/退出时调用 `startIfNeeded()` / `stop()`；接口保持兼容 |
| `MutualInfectionMac/MutualInfectionMac.entitlements` | Release 沙盒、网络与授权工作目录 |
| `MutualInfectionMac/MutualInfectionMacDebug.entitlements` | Debug 对应权限 |
| `openclaw-source/extensions/a2a-gateway/index.ts` | 读取 `A2A_LOCAL_FILE_ROOTS`，扩展 Mac 本地文件发送白名单（当前未提交） |

## 核心启动链

```text
AppDelegate.applicationDidFinishLaunching
  → NodeRuntimeManager.startIfNeeded()
      → resolveLayout()
      → prepareWritableDirectories()
      → prepareWorkspaceContext()
      → prepareRuntimeConfig()
      → openLogHandles()
      → launchProcess()
          node openclaw.mjs gateway run --force --port 18800
```

### Process 参数

```swift
process.executableURL = layout.nodeBinaryURL
process.arguments = [
    layout.openclawEntryURL.path,
    "gateway", "run", "--force", "--port", "18800"
]
process.currentDirectoryURL = layout.openclawRootURL
```

### 注入环境变量

| 变量 | 作用 |
|---|---|
| `OPENCLAW_HOME` | App Application Support 下的 NodeRuntime 根 |
| `OPENCLAW_STATE_DIR` | `NodeRuntime/state` |
| `OPENCLAW_CONFIG_PATH` | 生成的 `config/openclaw.json` |
| `MUTUAL_NODE_RUNTIME_*` | 保留宿主目录、日志、配置路径 |
| `A2A_LOCAL_FILE_ROOTS` | 以冒号连接授权目录，供 a2a `send_local_file` 路径校验 |

## 配置生成机制

### 从数字版本演进为版本 + 内容指纹

早期实现仅比较整数 `.template_version`。当前：

```swift
private static let configTemplateVersion = 24
```

`configTemplateMarker()` 对模板内容计算 FNV 风格指纹，标记格式：

```text
24:<hex-fingerprint>
```

这解决了只 bump 版本才能更新的问题：模板内容、模型、IP 占位符配置变化都会导致指纹变化并触发 App 自行重生成。

### 占位符实例化

`materializeConfigPlaceholders()` 替换：

- `${OPENCLAW_STATE_DIR}`
- `${OPENCLAW_HOME}`
- `${A2A_LAN_IP}`

其中 LAN IPv4 通过 `getifaddrs` 查找，优先 `en0` / `en1`，排除 loopback、`utun`、`awdl`、`llw`、`bridge` 等接口，使手机能够访问 Agent Card URL。

配置生成后还会创建：

- `state/a2a-tasks/`
- `/Users/jiahaoli/Desktop/A2A-Files/`

## Workspace 注入

`prepareWorkspaceContext()` 在：

```text
$OPENCLAW_HOME/.openclaw/workspace/
```

生成或覆盖：

### `AGENTS.md`

告知 Agent：

- 可操作目录：
  - `/Users/jiahaoli/project/harmonymac/`
  - `/Users/jiahaoli/Agent_Workspace/`
  - `/Users/jiahaoli/Desktop/`
- Desktop 首次访问可能需要 macOS“桌面文件夹”权限；
- 手机入站文件落 `/Users/jiahaoli/Desktop/A2A-Files/`；
- 用户指定目的地时如何搬运、重名和汇报最终绝对路径。

### `MEMORY.md`

写入：

- 本机 `TargetMac`
- 对端 `HW-Phone1`
- Mac A2A 18810 / 手机 A2A 18800
- 双端共享 A2A bearer token 的配置位置
- 收发文件目录

### `TOOLS.md`

写入：

- `openclaw gateway call a2a.send`
- `openclaw gateway call a2a.send_local_file`
- peer、gateway token、timeout 与常见错误说明

同时删除 `BOOTSTRAP.md`，避免首次 onboarding ritual 干扰嵌入式 Agent。

## 权限设计

当前文件能力不是单一开关，而是多层约束：

```text
entitlements              → macOS 真正允许访问
NodeRuntimeManager 清单    → 唯一授权目录源
AGENTS.md                  → Agent 知道允许访问哪里
A2A_LOCAL_FILE_ROOTS       → a2a 插件允许发送哪些本地路径
```

Release entitlements 当前授权：

- 项目目录
- `Agent_Workspace`
- Desktop
- 网络 client/server
- downloads read-write
- user-selected read-only

> 改目录必须同步 Debug/Release entitlements 与 `authorizedWorkDirs`。Desktop 仍受 TCC 控制，第一次访问可能需要用户允许。

## 生命周期与日志

- stdout/stderr 经 `Pipe` 分行处理；
- stdout 出现 `a2a-gateway: HTTP listening` 即记录 ready；
- 日志写入 `runtime.log` / `stderr.log`；
- `setpgid(pid,pid)` 建独立进程组；
- stop 时发送组 SIGTERM，最多等待 3 秒，再 SIGKILL；
- `terminationHandler` 回收 pipe、process 与日志句柄。

## 当前身份与配置基线

| 项目 | 当前值 |
|---|---|
| 本机身份 | `TargetMac` |
| 对端 peer | `HW-Phone1` |
| 主 gateway | 18800，token auth |
| Mac A2A HTTP | 18810，bearer auth |
| 入站文件目录 | `~/Desktop/A2A-Files` |
| 模板标记 | `24:<模板指纹>` |
| 主模型 | `volcengine/qwen3.5-plus` |

## 验证结论

最初阶段只完成静态逻辑验证；此后已经在 Xcode App 中继续完成：

- 私有 Node/OpenClaw 启动；
- 主 gateway / A2A 端口；
- 配置自愈；
- 模型与文件工具；
- entitlement 授权目录；
- TargetMac 与 HarmonyOS 手机的 A2A 联调。

因此“编译/运行待 Xcode”已是历史状态，不再是当前限制。

## 当前风险

1. 所有授权路径和收件路径硬编码 `/Users/`，不可直接移植到其他账户。
2. Desktop 收件目录依赖 TCC；错误提示和授权引导仍需产品化。
3. 模板中含明文 API key/token，但文件被 gitignore；应改用 Keychain、xcconfig 或构建时 Secret 注入。
4. `A2A_LOCAL_FILE_ROOTS` 使用冒号分隔，适用于当前 macOS 绝对路径；若将来路径本身含特殊格式或跨平台复用，需改为 JSON 等稳健编码。
5. `prepareWorkspaceContext()` 写文件失败使用 `try?` 静默忽略，生产环境应记录具体错误。

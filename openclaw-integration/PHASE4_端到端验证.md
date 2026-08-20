# 阶段 4 — 端到端验证

> 状态：✅ App 集成与跨端 A2A 已完成阶段性验证
> 原执行日期：2026-08-04
> 最后同步：2026-08-20
> 当前范围：Mac App 内 OpenClaw 运行、模型/文件能力、Mac ↔ HarmonyOS 双向消息与文件。

## 目标

验证完整链路：

```text
Xcode Build
  → .app 内私有 Node + OpenClaw + 配置模板
  → App 启动自动生成 workspace/config
  → OpenClaw 主 gateway / a2a-gateway ready
  → TargetMac 注册、发现 HW-Phone1
  → 双向消息
  → 双向本地文件
  → App 退出清理进程组
```

## 第一阶段：历史本机逻辑预检

最初因执行环境只有 Command Line Tools，使用模拟 App bundle 精确复现 `NodeRuntimeManager` 的启动参数与环境变量：

```bash
export OPENCLAW_HOME="$APPSUPPORT"
export OPENCLAW_STATE_DIR="$APPSUPPORT/state"
export OPENCLAW_CONFIG_PATH="$APPSUPPORT/config/openclaw.json"
cd "$APPROOT/openclaw"
"$NODE" openclaw.mjs gateway run --force --port 18800
```

当时验证：

| 项目 | 结果 |
|---|---|
| ready marker | ✅ 约 4 秒内出现 |
| 主 gateway `/health` | ✅ |
| 运行状态写入 App Application Support | ✅ |
| 基础启动未污染默认 `~/.openclaw` | ✅ |

这证明 Swift 参数、环境与路径设计成立。

## 第二阶段：Xcode App 实际运行验证

后续已在完整 Xcode 环境完成真实 `.app` 构建与运行，并验证：

- Build Phase 将 NodeRuntime 打进 `鸿蒙星河互联.app`；
- 私有 Node 版本为 v22.16.0；
- OpenClaw 主 gateway 18800 正常；
- a2a-gateway 在 18810 独立监听；
- `/.well-known/agent-card.json` 可返回 Agent Card；
- Node 26 `IncomingMessage.signal` TypeError 不再出现；
- `.template_version` 配置自愈有效；
- OpenClaw 可以调用模型和文件工具；
- App 正常退出时清理 Node/OpenClaw 进程组。

## 第三阶段：T8 文件权限与 Agent 上下文

为让 Agent 真正操作用户工作目录，完成了以下闭环：

1. Release/Debug entitlements 加入项目目录、`Agent_Workspace` 与 Desktop 绝对路径读写例外；
2. `NodeRuntimeManager.authorizedWorkDirs` 维护同一清单；
3. 每次启动生成 `AGENTS.md`，让 Agent 知道授权范围；
4. 生成 `MEMORY.md` / `TOOLS.md`，写入本机/对端身份及 A2A 用法；
5. `A2A_LOCAL_FILE_ROOTS` 将授权根传给 a2a 插件，使 `send_local_file` 不再只接受 HarmonyOS 默认目录。

当前 Mac 文件能力：

| 路径 | 用途 |
|---|---|
| `~/project/harmonymac/` | 项目读取/编辑 |
| `~/Agent_Workspace/` | Agent 工作与 Mac→手机发送文件 |
| `~/Desktop/` | 用户可见文件与入站收件目录 |
| `~/Desktop/A2A-Files/` | 手机→Mac 文件最终落盘目录 |

## 第四阶段：Mac ↔ HarmonyOS 双端联调

当前测试身份：

| 端 | 身份 | A2A HTTP |
|---|---|---:|
| Mac | `TargetMac` | 18810 |
| HarmonyOS 手机 | `HW-Phone1` | 18800 |

发现与跨网配置：

- registry：`http://124.71.140.180:8000`
- tunnel relay：`ws://124.71.140.180:8000`
- 双端共享 A2A bearer token
- Mac 本机 gateway 另使用 gateway token

### 双向消息

`verify.sh` 当前覆盖：

1. Mac 直接向手机 `/a2a/jsonrpc` 发送 `message/send`；
2. 测试端直接向 Mac 18810 发送 `message/send`；
3. 请求携带 bearer token；
4. 结果接受 `completed` / `taskId` / 测试标记作为成功证据。

### Mac → 手机文件

- 在 `~/Agent_Workspace/mac-to-phone.txt` 创建测试文件；
- 使用 App bundle 内私有 Node/OpenClaw CLI；
- 调本机 gateway method：

```bash
openclaw gateway call a2a.send_local_file \
  --url=ws://127.0.0.1:18800 \
  --token=<GATEWAY_TOKEN> \
  --params='{"peer":"HW-Phone1","path":"/Users/jiahaoli/Agent_Workspace/mac-to-phone.txt"}'
```

- `A2A_LOCAL_FILE_ROOTS` 使插件允许发送 Mac entitlement 授权目录中的文件；
- 手机目标目录由手机端配置决定，当前测试检查 `Docs/OPENCLAW`。

### 手机 → Mac 文件

- 通过 HDC 在手机执行其 OpenClaw CLI；
- 对端 peer 为 `TargetMac`；
- 手机 fixture 为 `/data/local/.openclaw/workspace/a2a-fixtures/phone-to-pc-test.txt`；
- Mac a2a executor 将 inline bytes 解码并写入：

```text
/Users/jiahaoli/Desktop/A2A-Files/
```

- Agent 收到以 `【A2A 文件接收成功】` 开头的内部文本，并被要求向用户原样报告真实保存路径。

## 一键验证脚本

```bash
openclaw-integration/verify.sh
```

脚本当前步骤：

1. 自动寻找最新 DerivedData `.app`，确认私有 Node/OpenClaw；
2. 检查双方 Agent Card；
3. Mac → 手机文本；
4. 手机 → Mac 文本；
5. Mac → 手机文件；
6. 手机 → Mac 文件（HDC）；
7. 检查双方收件目录。

## 验证前置条件

- Mac App 已在 Xcode 中运行；
- Mac/手机 IP 与脚本匹配；
- 手机在线且 HDC 能看到 target；
- 双端 A2A token 一致；
- 本机 gateway token 正确；
- registry/tunnel 服务可达；
- Desktop TCC 已允许；
- `NodeRuntimeHost/config/openclaw.template.json` 已安全配置；
- `openclaw-bundle-output/` 与 `.app` 已包含最新 a2a 源码修改。

## 当前无法声明的内容

本次文档同步时，`hdc list targets` 返回 `[Empty]`，所以**没有重新执行手机在线回归**。这不否定此前已完成的联调记录，但表示当前工作区最新的 `A2A_LOCAL_FILE_ROOTS`、桌面收件目录与重写后的 `verify.sh` 仍应在手机在线时再跑一次最终全绿回归。

## 已知限制

1. `verify.sh` 写死当前实验环境的 IP、peer、token、HDC 路径，尚不是通用 CI 脚本。
2. 手机离线、IP 变化、registry 未刷新或 token 不一致都会导致真机项失败。
3. Desktop 文件访问受 TCC 控制；只配置 entitlement 不保证用户已允许。
4. `fileStorage.tempDir`、授权目录和测试路径硬编码个人 Home。
5. 测试脚本当前把“请求接受”作为部分异步场景的成功条件；若要证明业务最终完成，应增加 task polling 和内容校验。
6. `.app` 若复用旧的 `openclaw-bundle-output/`，可能没有最新插件代码；强制回归前应删除并重建中间产物。

## 最终判定标准

| 级别 | 判据 |
|---|---|
| App 集成通过 | Build、Node22、主 gateway、Mac A2A、配置自愈、退出清理通过 |
| Agent 功能通过 | 模型调用与授权目录文件工具通过 |
| 双端消息通过 | TargetMac ↔ HW-Phone1 双向 `message/send` 返回完成/接受 |
| 双端文件通过 | 两端 `send_local_file` 成功，且目标目录真实出现内容一致的文件 |
| 当前最终状态 | 前三层已有历史实测；最新工作区需在手机重新上线后执行一次 `verify.sh` 全绿回归 |

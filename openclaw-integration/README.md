# OpenClaw 集成交接说明

> **阅读对象**：接手 `harmonyMac` OpenClaw 集成的开发者、构建/测试人员。
> **适用范围**：`MutualInfectionMac` macOS App 内嵌 OpenClaw Agent Runtime，以及 Mac `TargetMac` ↔ HarmonyOS `HW-Phone1` 的 A2A 联调。
> **文档状态**：2026-08-20 同步；以当前工作区代码为准，历史排障过程见同目录 PHASE 文档。

## 1. 先看这里：项目当前状态

这条集成线已经完成“源码基线 → 私有 Node → OpenClaw 产物 → Xcode App → Swift 托管 → A2A 双端消息/文件”的主链路。


## 2. 交接必读顺序

1. **本文**：环境、构建、运行、验证、风险与接手清单；
2. [`00_集成总览.md`](./00_集成总览.md)：架构、调用链、目录和端口；
3. [`PHASE0_基线本地跑通.md`](./PHASE0_基线本地跑通.md) ～ [`PHASE4_端到端验证.md`](./PHASE4_端到端验证.md)：阶段目标、历史证据和当前补充；
4. [`测试方案.md`](./测试方案.md)：本地、App Runtime、Agent、真机 A2A 测试；
5. [`工作总结.md`](./工作总结.md)：完整工作范围、决策背景和已知后续任务；
6. `record/`：Node Runtime 基础托管的早期记录；
7. `openclaw-source/extensions/a2a-gateway/`：A2A 插件源码与方法/工具实现。


## 3. 组件地图

| 组件 | 路径 | 交接说明 |
|---|---|---|
| macOS 宿主 | `MutualInfectionMac/` | AppDelegate 调用 `NodeRuntimeManager.startIfNeeded()` / `stop()` |
| Swift 运行时管理 | `MutualInfectionMac/Application/NodeRuntimeManager.swift` | 拉起私有 Node，注入 OpenClaw 环境、workspace、权限白名单，处理日志和退出 |
| OpenClaw 源码 | `openclaw-source/` | TypeScript/Node runtime；源码入库，dist/node_modules 等构建物按 `.gitignore` 排除 |
| A2A 插件 | `openclaw-source/extensions/a2a-gateway/` | Agent Card、JSON-RPC、registry/tunnel、双向文本/文件、任务执行 |
| OpenClaw 打包 | `scripts/prepare_openclaw_bundle.sh` | 源码 → `openclaw-bundle-output/`；缺 dist 时会 install/build |
| App Runtime 打包 | `scripts/prepare_node_runtime_bundle.sh` | 私有 Node + OpenClaw + template → `.app/Contents/Resources/NodeRuntime/` |
| Xcode 工程 | `MutualInfection.xcodeproj/project.pbxproj` | 两个 Build Phase，先 OpenClaw bundle 后 NodeRuntime bundle |
| 私有 Node | `record/node-official/v22.16.0/` | Node 22.16.0，当前支持 arm64/x86_64 包 |
| 敏感模板 | `NodeRuntimeHost/config/openclaw.template.json` | 本机文件被 `.gitignore` 排除，需从安全配置源恢复 |
| 可选 fuzzy-search | `openclaw-source/extensions/fuzzy-search/`、`qol/` | 若启用，需同步模板、Swift 的 `${FUZZY_SEARCH_TOOL_PATH}`、构建脚本和产物工具 |

## 4. 环境要求

### 4.1 开发与构建环境

- macOS；
- Xcode 15 或以上；
- 当前 scheme/target：`MutualInfectionMac`；
- `pnpm`（建议使用仓库 `package.json` / `packageManager` 指定版本）；
- `rsync`、`tar`、`python3`、`curl`；
- Apple Silicon 是主要验证平台；Node bundle 脚本另有 x86_64 分支，Intel 是否正式支持仍需单独验收；
- App Sandbox entitlement 中的绝对路径需要改成接手者自己的 Home 路径，不能直接复制当前 `/Users/jiahaoli/` 配置。

### 4.2 真机 A2A 联调环境

- HarmonyOS 手机已安装对应 OpenClaw/gateway；
- HDC 可执行并能发现手机；
- 手机和 Mac 的 IP、端口、peer 名、A2A token 与脚本/模板一致；
- registry/tunnel 服务 `124.71.140.180:8000` 可达；
- Mac 首次访问 Desktop 时获得 macOS TCC 授权。

## 5. 敏感配置与新机器初始化

`NodeRuntimeHost/config/openclaw.template.json` 包含模型 API key、gateway token 和 A2A bearer token，故被根 `.gitignore` 排除。接手者必须从受控安全渠道恢复它，不能从普通提交或日志中复制密钥。

模板至少要保持以下语义一致：

| 配置 | 当前约定 |
|---|---|
| 主 gateway | `mode=local`，主端口 18800，独立 gateway token |
| Mac A2A | `host=0.0.0.0`，HTTP 18810，bearer token |
| Mac 身份 | `TargetMac`（agentCard / tunnel.deviceId / registry.serviceId 一致） |
| 手机 peer | `HW-Phone1` |
| relay/registry | `124.71.140.180:8000` |
| 入站文件 | `fileStorage.tempDir` 指向 `<用户 Home>/Desktop/A2A-Files` |
| task/audit | 使用 `${OPENCLAW_STATE_DIR}`，不要落默认用户 Home |
| 模型 | 当前主模型 `volcengine/qwen3.5-plus`；可选 Ark 模型；按安全渠道提供 key |

接手者还必须同步替换以下个人路径：

- `MutualInfectionMac/MutualInfectionMac.entitlements`；
- `MutualInfectionMac/MutualInfectionMacDebug.entitlements`；
- `NodeRuntimeManager.authorizedWorkDirs`；
- `NodeRuntimeManager` 中 Desktop/A2A-Files 路径；
- `verify.sh` 中 Mac/手机 IP、HDC、peer、工作目录；
- 敏感模板中的 `fileStorage.tempDir` 和其他绝对路径；
- `NodeRuntimeManager` 中 `${FUZZY_SEARCH_TOOL_PATH}` 的运行时占位符（若启用 fuzzy-search 插件）；
- `openclaw.template.json` 中 fuzzy-search 插件的 `enabled`、`toolPath` 和 `rootPath`（若启用该能力）。

## 6. 构建流程

### 6.1 首次或源码更新后准备

```bash
cd /Users/jiahaoli/project/harmonymac

# 如果源码或 a2a 插件更新，先清理旧中间产物，避免 Xcode 命中旧 bundle
rm -rf openclaw-bundle-output

# 可以手动执行；Xcode Phase 1 也会自动执行
scripts/prepare_openclaw_bundle.sh
```

脚本会：

1. 检查 `openclaw-source/dist/`；缺失时执行源码 install + build；
2. 将 OpenClaw 运行文件复制到临时 staging；
3. 以生产依赖、hoisted 结构安装依赖；
4. 打包 `docs/reference/templates/`；
5. 输出 `openclaw-bundle-output/`；
6. 已存在 `openclaw.mjs` 和 `node_modules` 时使用缓存。

### 6.2 Xcode Build

```bash
open /Users/jiahaoli/project/harmonymac/MutualInfection.xcodeproj
```

选择 `MutualInfectionMac`，执行 ⌘B。Build Phase 顺序应为：

```text
Prepare Openclaw Bundle
  → Prepare Node Runtime Bundle
  → Resources / Copy Files
```

最终产物：

```text
<DerivedData>/Build/Products/<configuration>/鸿蒙星河互联.app/Contents/Resources/NodeRuntime/
├── node/bin/node
├── openclaw/openclaw.mjs
├── openclaw/dist/
├── openclaw/node_modules/
└── config/openclaw.template.json
```

### 6.3 常见构建失败

| 现象 | 原因 | 处理 |
|---|---|---|
| 配置模板缺失 | 敏感模板未恢复 | 从安全配置源放回 `NodeRuntimeHost/config/openclaw.template.json` |
| OpenClaw 产物缺失 | Phase 1 未执行或失败 | 单独运行 `scripts/prepare_openclaw_bundle.sh` 查看完整日志 |
| pnpm 不存在 | 首次需要构建源码 dist | 安装匹配版本 pnpm 或提供预构建中间产物 |
| Node archive 缺失 | `record/node-official/v22.16.0/` 不完整 | 检查 arm64/x64 tar.gz 与目录名 |
| 构建后仍是旧代码 | 中间产物缓存 | 删除 `openclaw-bundle-output/` 后 Clean Build |
| fuzzy-search 不可用 | Swift 工具未编译或模板占位符未替换 | 检查 `qol/`、构建脚本的 `tools/` 输出、`${FUZZY_SEARCH_TOOL_PATH}` |

## 7. 启动与运行时检查

⌘R 启动 App 后，先检查进程和日志：

```bash
ps -ef | grep -E '鸿蒙星河|openclaw' | grep -v grep

# 以下路径以 Release sandbox 为例
CONT="$HOME/Library/Containers/com.HarmonyOSInterconnection.app/Data"
BASE="$CONT/Library/Application Support/MutualInfectionMac/NodeRuntime"
LOG="$CONT/Library/Logs/MutualInfectionMac/NodeRuntime"
```

期望：

- 私有 Node 版本 v22.16.0；
- stdout 出现 `a2a-gateway: HTTP listening`；
- 主 gateway 18800；
- Mac A2A 18810；
- `stderr.log` 中 `Cannot set property signal` 计数为 0；
- 配置、task、audit 状态使用 App 目录；
- App 退出后 Node/OpenClaw 进程组消失。

## 8. 端口、身份和通信

| 端口/身份 | 用途 |
|---|---|
| Mac `18800` | OpenClaw 主 gateway / CLI 控制面 |
| Mac `18810` | A2A HTTP、Agent Card、JSON-RPC |
| Mac `18811` | A2A gRPC，通常为 `server.port + 1` |
| Mac `18802` | browser control |
| 手机 `18800` | 当前 HarmonyOS A2A HTTP |
| `TargetMac` | Mac Agent Card、tunnel、registry 身份 |
| `HW-Phone1` | 手机 peer 名 |

本机 CLI 的 gateway token 与跨设备 A2A bearer token 是两套凭据，不能混用。

## 9. 本地验证（不依赖手机）

```bash
cd /Users/jiahaoli/project/harmonymac
sh -n scripts/prepare_openclaw_bundle.sh
sh -n scripts/prepare_node_runtime_bundle.sh
bash -n openclaw-integration/verify.sh

# App 运行后
curl -fsS http://127.0.0.1:18800/health
curl -fsS -H 'Authorization: Bearer <A2A_TOKEN>' \
  http://127.0.0.1:18810/.well-known/agent-card.json

CFG="$BASE/config"
cat "$CFG/.template_version"       # 24:<模板指纹>
python3 -m json.tool "$CFG/openclaw.json" >/dev/null
ls "$BASE/.openclaw/workspace"/{AGENTS,MEMORY,TOOLS}.md
```

目标：构建、私有 Node、主 gateway、Agent Card、配置自愈、workspace 注入、日志和退出清理均通过。

## 10. 真机 A2A 验证

手机在线并能被 HDC 发现后：

```bash
cd /Users/jiahaoli/project/harmonymac
openclaw-integration/verify.sh
```

脚本覆盖：

1. 自动找最新 App 内 Node/OpenClaw；
2. 检查手机和 Mac Agent Card；
3. Mac → 手机文本；
4. 手机 → Mac 文本；
5. Mac → 手机文件；
6. 手机 → Mac 文件；
7. 检查两端收件目录并汇总通过/失败。

脚本当前绑定实验环境的 IP、token、HDC 路径和目录；接手后优先改造成环境变量参数。部分异步任务只判断 `accepted/taskId`，最终验收还应轮询任务并校验文件内容或 SHA256。

## 11. 文件权限闭环

文件访问需要同时满足四层：

1. macOS entitlements：系统实际访问权限；
2. `authorizedWorkDirs`：Swift 目录清单；
3. workspace `AGENTS.md`：Agent 语义上的授权范围；
4. `A2A_LOCAL_FILE_ROOTS`：a2a 插件的本地发送路径白名单。

当前默认授权：项目目录、`Agent_Workspace`、Desktop。Desktop 仍可能受 TCC 影响。入站 inline 文件落 `~/Desktop/A2A-Files`，Agent 应向用户报告真实绝对路径，不能编造。

## 12. 文档与当前已知问题

### 文档索引

- [总览](./00_集成总览.md)
- [PHASE0](./PHASE0_基线本地跑通.md) / [PHASE1](./PHASE1_离线打包产物.md) / [PHASE2](./PHASE2_Xcode构建接入.md) / [PHASE3](./PHASE3_Swift侧改造.md) / [PHASE4](./PHASE4_端到端验证.md)
- [测试方案](./测试方案.md)
- [工作总结](./工作总结.md)

### 主要已知问题

- `openclaw.template.json` 含敏感 key/token，未进入 Git；新机器依赖安全恢复流程；
- `jiahaoli` 个人绝对路径仍分散在 entitlements、Swift、template、verify.sh，尚未完全参数化；
- `Prepare Openclaw Bundle`、`A2A_LOCAL_FILE_ROOTS` 和相关文档属于当前工作区修改，需接手者确认后提交；
- 中间产物缓存没有源内容 hash，源码更新后需手动删除输出目录；
- 首次无 dist 时构建需要 pnpm/网络或缓存；
- 真机脚本依赖手机在线、HDC、固定 IP 和 relay/registry；
- 桌面 TCC、A2A 鉴权、异步任务最终状态和文件哈希仍需产品级回归；
- 当前 `NodeRuntimeManager` fallback JSON 的 A2A 鉴权仍为 `none`，仅在敏感模板缺失时触发，生产构建不能依赖 fallback；
- fuzzy-search 为可选能力，若启用，需要把 `qol` Swift CLI、OpenClaw 插件、模板和 App bundle 构建链作为一个整体验收。

## 13. 接手清单

### 接手者第一次操作

- [ ] 阅读本文和 `00_集成总览.md`；
- [ ] 查看 `git status`，确认并保留前任未提交修改；
- [ ] 从安全渠道恢复敏感 `openclaw.template.json`；
- [ ] 将所有 `/Users/jiahaoli/` 替换为接手者实际 Home，并同步 entitlements、Swift、template、verify.sh；
- [ ] 确认 Xcode 15+、scheme/target 和私有 Node 包；
- [ ] 清理并生成最新 `openclaw-bundle-output/`；
- [ ] Xcode Clean Build；
- [ ] 启动 App，完成本地 Runtime 验证；
- [ ] 手机上线后运行 `verify.sh`，补充双向消息/文件最终证据；
- [ ] 若启用 fuzzy-search，验证 Swift CLI 已存在且 Agent tool 能按授权目录检索；
- [ ] 检查 token、日志、文件结果中没有泄露真实密钥；
- [ ] 决定是否提交当前工作区的 Build Phase、Swift、插件、脚本和文档修改。

## 14. 交接完成标准

交接不是“README 写完”即完成，而应满足：

- [ ] 新开发者能不依赖前任口头说明恢复敏感模板；
- [ ] Xcode 能生成 NodeRuntime bundle；
- [ ] App 能使用 Node 22.16 启动 OpenClaw；
- [ ] 18800/18810 健康与 Agent Card 正常；
- [ ] workspace 与四层文件权限一致；
- [ ] 手机上的 HDC target 可见；
- [ ] 双向文本和文件最终状态可通过内容/哈希证明；
- [ ] 所有当前未提交修改已明确决策（提交、拆分或回退）。

> **最终原则**：代码是最终事实，本文是接手路径；如果文档与代码冲突，以当前源码、Xcode 工程、entitlements、运行模板和日志为准，并在完成验证后更新本文档。


如果修改了路径、模型、端口、身份或鉴权，必须同时更新代码、模板、entitlements、验证脚本和本目录文档，并留下新的同步日期。

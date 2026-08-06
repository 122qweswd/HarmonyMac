# 阶段 4 — 端到端验证

> 状态：✅ 本机逻辑预检通过（精确复现 `NodeRuntimeManager` 启动链路）；⚠️ 真实 `.app` 构建/运行验证需用户在 Xcode 环境完成（本机仅 Command Line Tools）
> 日期：2026-08-04

## 目标

验证完整链路：App 启动 → `NodeRuntimeManager` 拉起私有 node + openclaw gateway → ready → a2a 服务可用 → App 退出时进程清理。

## 本机逻辑预检（已完成 ✅）

本机无 Xcode，无法 `xcodebuild`。改为**精确复现 `NodeRuntimeManager.launchProcess` 的启动逻辑**（同一 `arguments` / `environment` / config 实例化流程），在阶段 2 模拟 `.app` 上验证：

```bash
# 等效于 NodeRuntimeManager.startIfNeeded 的内部流程
APPSUPPORT=/tmp/.../MutualInfectionMac/NodeRuntime
mkdir -p "$APPSUPPORT"/{config,state,cache,tmp}
cp "$APPROOT/config/openclaw.template.json" "$APPSUPPORT/config/openclaw.json"  # prepareRuntimeConfig
export OPENCLAW_HOME="$APPSUPPORT" OPENCLAW_STATE_DIR="$APPSUPPORT/state" OPENCLAW_CONFIG_PATH="$APPSUPPORT/config/openclaw.json"
cd "$APPROOT/openclaw"
"$NODE" openclaw.mjs gateway run --force --port 18800   # launchProcess arguments
```

| 检查项 | 结果 |
|--------|------|
| ready 标记 `a2a-gateway: HTTP listening` 命中 | ✅ 4s 内 |
| `/health` 200 | ✅ 4s 内 |
| 运行时数据全在 App Application Support（`config/state/cache/tmp`） | ✅ |
| 用户 home（`~/.openclaw`）未被污染 | ✅ 干净 |

**结论**：阶段 3 的 Swift 改造逻辑（arguments / environment / config 路径）经验证有效——`NodeRuntimeManager` 启动后约 4s 会观察到 ready，且不污染用户目录。

## 用户 Xcode 验证清单（待执行）

在装有完整 Xcode 的机器上：

```bash
# 0. 一次性生成 openclaw 产物（已加缓存，二次跳过）
cd /Users/jiahaoli/project/harmonymac
scripts/prepare_openclaw_bundle.sh
# → 产物在 openclaw-bundle-output/

# 1. 用 Xcode 打开并构建
open MutualInfection.xcodeproj
# 选 MutualInfectionMac scheme，Build（build phase 会调用 prepare_node_runtime_bundle.sh，
# 把 openclaw 产物拷进 .app/Contents/Resources/NodeRuntime/）
```

构建成功后运行 App，逐项验证：

| # | 检查 | 期望 | 命令/位置 |
|---|------|------|-----------|
| 1 | App 启动后 openclaw 起来 | 日志 `[NodeRuntimeManager] openclaw ready 信号已收到（a2a-gateway HTTP listening）` | Console / `~/Library/Logs/MutualInfectionMac/NodeRuntime/runtime.log` |
| 2 | gateway 监听 | `curl -s http://127.0.0.1:18800/health` → 200 | 终端 |
| 3 | a2a 服务 | `curl -s http://127.0.0.1:18800/a2a/jsonrpc` → 200 | 终端 |
| 4 | 运行配置生成 | `~/Library/Application Support/MutualInfectionMac/NodeRuntime/config/openclaw.json` 存在 | Finder |
| 5 | 不依赖系统 Node | `which node`（系统） vs App 内私有 node 各自版本 | App 应不依赖系统 node |
| 6 | App 退出清理 | node/openclaw 进程随 App 退出消失 | 活动监视器搜 `node` |
| 7 | home 不被污染 | `~/.openclaw` 不出现 a2a 数据 | 终端 |

## 已知限制

1. **agent-card 端点 404**（阶段 0 发现）：`/.well-known/agent-card.json` 在定制版未路由到 a2a app。A2A 外部 peer 发现本节点暂不可用；a2a jsonrpc 通信正常。后续排查 gateway 框架路由代理。
2. **a2a `storage.tasksDir` 默认 `~/.openclaw/a2a-tasks`**：逻辑预检中 home 未被污染（可能因 `OPENCLAW_HOME` 重定向），但若跑实际 a2a 任务，建议在 config 显式设 `storage.tasksDir` 指向 App 目录（阶段 0 记录的路径泄漏项）。
3. **体积 1.3G**：全量产物，App 包体大。阶段 5 裁剪。
4. **pbxproj input/output paths 未更新**：仍引用旧 host 路径，不影响构建功能（见 PHASE2 问题①）。

## 整体集成总结（阶段 0–4）

| 阶段 | 产出 | 状态 |
|------|------|------|
| 0 | openclaw-custom 本地跑通（pnpm install + gateway 验证） | ✅ |
| 1 | 离线打包产物（arm64/prod/hoisted）+ `prepare_openclaw_bundle.sh` | ✅ |
| 2 | Xcode build phase 接入（`prepare_node_runtime_bundle.sh` 重写 + config 模板） | ✅ 模拟验证 |
| 3 | `NodeRuntimeManager` 改造拉起 openclaw | ✅ 逻辑验证 |
| 4 | 端到端验证 | ✅ 逻辑预检；真实构建待用户 Xcode |

**新增/修改的文件（入库）**：
- `scripts/prepare_openclaw_bundle.sh`（新）
- `scripts/prepare_node_runtime_bundle.sh`（重写）
- `NodeRuntimeHost/config/openclaw.template.json`（新）
- `MutualInfectionMac/Application/NodeRuntimeManager.swift`（重写）
- `.gitignore`（加 `openclaw-bundle-output/`）
- `openclaw-integration/`（新目录：README + PHASE0–4 文档）

**核心成果**：openclaw agent runtime 可作为**离线自包含**组件嵌入 `MutualInfectionMac.app`——私有 node（arm64）+ openclaw 代码 + 扁平依赖全部打包，App 启动即拉起 a2a-gateway，不依赖用户本地 Node/网络，运行时数据隔离在 App 私有目录。

## 下一步（阶段 5，后续）

体积裁剪：剔除 a2a-gateway 不需要的模块（discord/telegram/whatsapp 等 ~40 渠道插件、`playwright-core`、`node-llama-cpp`、`pdfjs-dist`、`@aws-sdk`、`@lancedb`、`koffi` 多平台 prebuilt 等，详见 PHASE1 体积表），目标把 1.3G 压到 ~300–400M。

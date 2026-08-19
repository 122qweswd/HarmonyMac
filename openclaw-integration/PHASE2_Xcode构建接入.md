# 阶段 2 — 接入 Xcode Build Phase，拷进 .app

> 状态：✅ 脚本/配置改动完成 + 模拟 build phase 验证通过；⚠️ 实际 `xcodebuild` 构建待用户在 Xcode 环境验证（本机仅 Command Line Tools，无 Xcode.app）
> 日期：2026-08-04

## 目标

让 Xcode 构建 `MutualInfectionMac` 时，自动把 openclaw 运行时产物组装进 `.app/Contents/Resources/NodeRuntime/`，并退役心跳桩 host。

## 执行的操作（可复制）

```bash
# 1.（一次性）生成 openclaw 产物到仓库内固定路径（gitignore）
cd /Users/jiahaoli/project/harmonymac
scripts/prepare_openclaw_bundle.sh
# → 产物在 openclaw-bundle-output/（已加缓存，二次运行跳过 install）

# 2. 模拟 Xcode build phase（手动设环境变量验证脚本逻辑）
export PROJECT_DIR=/Users/jiahaoli/project/harmonymac
export TARGET_BUILD_DIR=/tmp/oc-appsim
export UNLOCALIZED_RESOURCES_FOLDER_PATH=Contents/Resources
export DERIVED_FILE_DIR=/tmp/oc-derived
export CURRENT_ARCH=arm64
export OPENCLAW_BUNDLE_DIR=/tmp/openclaw-bundle   # 或 openclaw-bundle-output
sh scripts/prepare_node_runtime_bundle.sh
# → 组装 /tmp/oc-appsim/Contents/Resources/NodeRuntime/{node,openclaw,config}

# 3. 验证 .app 内 openclaw 自包含可跑（见下）
```

## 修改的文件清单

| 路径 | 变更 | 说明 |
|------|------|------|
| `scripts/prepare_node_runtime_bundle.sh` | **重写** | 移除心跳桩 host 拷贝（`host/dist/index.js`、`host/package.json`）；新增从 `OPENCLAW_BUNDLE_DIR` 拷 openclaw 产物到 `NodeRuntime/openclaw/`；config 模板改拷 `openclaw.template.json`；保留私有 node 二进制提取逻辑 |
| `scripts/prepare_openclaw_bundle.sh` | 加缓存 | 产物已存在则跳过 `pnpm install`（避免 Xcode 每次构建重跑），删除产物目录可强制重建 |
| `NodeRuntimeHost/config/openclaw.template.json` | **新增** | a2a-gateway 配置模板（`gateway.mode=local` + `plugins.entries.a2a-gateway`）；阶段 3 由 Swift 读取并实例化为 `openclaw.json` |
| `.gitignore` | 加 `openclaw-bundle-output/` | 产物 1.2G+，不入库 |
| `MutualInfection.xcodeproj/project.pbxproj` | **未改** | build phase `Prepare Node Runtime Bundle`（ID `C0D3A002...`）的 `shellScript` 仍调 `prepare_node_runtime_bundle.sh`，无需改动；`inputPaths`/`outputPaths` 仍引用旧 host 路径（见下"问题①"） |

## 验证结果

| 验证项 | 结果 | 证据 |
|--------|------|------|
| 模拟 build phase 脚本执行 | ✅ | exit 0，组装出完整 NodeRuntime |
| `.app` 内私有 node 可执行 | ✅ | `NodeRuntime/node/bin/node -v` → v22.16.0 |
| `.app` 内 openclaw 产物完整 | ✅ | `openclaw/openclaw.mjs` + 663 个顶层 node_modules 包 + dist + extensions |
| `.app` 内 config 模板 | ✅ | `NodeRuntime/config/openclaw.template.json` |
| `.app` 内 openclaw 自包含运行 | ✅ | 私有 node + .app 内 openclaw `gateway run` → `/health` 200（10s 内） |
| NodeRuntime 体积 | 1.3G | node + openclaw 1.2G + config |

**模拟层验证通过**：build phase 脚本能正确组装 .app，且组装后 openclaw 自包含可跑。

## 发现（影响阶段 3）

### 端口：`--port` 与 a2a-gateway `server.port` 是两个独立配置
- 实测 `gateway run --force --port 18804` 时：
  - gateway **主 WebSocket** 监听 `18804`（`--port` 控制）
  - **a2a-gateway HTTP** 仍监听 `18800`（由 config `plugins.entries.a2a-gateway.config.server.port` 控制，**不受 `--port` 影响**）
  - gRPC 监听 `server.port + 1`（18801）
- **对阶段 3 的含义**：Swift 拉起时 `--port` 只决定 gateway 主端口；a2a-gateway 的监听端口由注入的 config 决定。ready 检测若查 a2a 端点，要用 config 里的端口；查 `/health` 则用 `--port`。

## 遇到的问题与决策

### ① pbxproj 的 input/output paths 未更新（已知，不影响功能）
- build phase 的 `inputPaths` 仍声明 `NodeRuntimeHost/dist/index.js`、`package.json`、`runtime-config.template.json`；`outputPaths` 仍声明 `NodeRuntime/host/dist/index.js`。
- 这些文件仍存在于仓库（心跳桩未删），inputPaths 校验通过；outputPaths 仅用于 Xcode 增量判断，不强制生成。**不影响构建功能**。
- 决策：不改 pbxproj（避免工程文件风险 + 本机无法 xcodebuild 验证改动）。保留 `NodeRuntimeHost/dist/index.js` 不删，维持 inputPaths 有效。后续可优化。

### ② 本机无 Xcode.app，无法 xcodebuild 验证
- `xcode-select -p` → `/Library/Developer/CommandLineTools`，无完整 Xcode，`xcodebuild` 不可用。
- 决策：阶段 2 用**模拟 build phase**（手动设环境变量）验证脚本逻辑，已通过。实际 Xcode 构建验证留待**阶段 4**（或用户在 Xcode 手动构建）。

### ③ 产物含 pnpm 元数据（阶段 5 清理）
- `NodeRuntime/openclaw/` 内含 `.npmrc`、`pnpm-lock.yaml`、`pnpm-workspace.yaml`、`ui/`、`packages/`——运行时不需要，是 `prepare_openclaw_bundle.sh` 全量拷贝带入的。功能无影响，体积可优化，阶段 5 处理。

## 下一步

进入阶段 3：改造 `NodeRuntimeManager.swift`——Layout 增 openclaw 路径、`prepareRuntimeConfig` 生成 `openclaw.json`、`launchProcess` 改拉起 `openclaw.mjs gateway run` + 注入 `OPENCLAW_*` 环境变量、ready 检测改 HTTP `/health` 轮询。

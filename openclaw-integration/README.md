# openclaw Agent Runtime 集成进 MutualualInfectionMac

把定制版 openclaw（`openclaw-source/`，含内置 A2A Gateway）作为**离线、自包含**的 Agent Runtime 集成进 macOS App `MutualInfectionMac`，使互传 App 充当 A2A（Agent-to-Agent）节点。**不依赖用户本地 Node/npm/网络**——Node 二进制 + openclaw 代码 + 全部依赖都打包进 `.app`。

> 本目录与 `record/` 平级、相互独立：`record/` 记录的是 Node 运行时**基础托管**（心跳桩那条线，清单第 1–7 步）；本目录记录的是 openclaw **业务集成**这条独立工作线。

## 关键决策

- **路线**：复用 harmonymac 现有 NodeRuntime 框架（`Process` + 私有 node），把心跳桩换成 openclaw 真实入口。**不移植 openclaw 官方 mac app**（`apps/macos/`）——调查发现它依赖系统 node、是独立 SwiftUI App、用 launchd，约束与本项目（私有 node + 嵌入现有 AppKit App）相反。
- **复用官方验证过的技巧**：`pnpm install --node-linker=hoisted`（扁平化依赖，见 `openclaw-source/scripts/package-mac-app.sh:118`）；`OPENCLAW_HOME`/`OPENCLAW_STATE_DIR`/`OPENCLAW_CONFIG_PATH` 重定向运行时目录；`/.well-known/agent-card.json` 作为 ready/健康端点。
- **范围**：先全量跑通再裁剪；**仅 arm64**（Apple Silicon）。
- 完整方案见 plan：`~/.claude/plans/replicated-purring-blossom.md`。

## 阶段进度

| 阶段 | 文档 | 状态 |
|------|------|------|
| 0 — openclaw-source 本地基线跑通 | [PHASE0_基线本地跑通.md](./PHASE0_基线本地跑通.md) | ✅ 完成 |
| 1 — 构造离线打包产物（arm64/生产依赖/hoisted） | [PHASE1_离线打包产物.md](./PHASE1_离线打包产物.md) | ✅ 完成 |
| 2 — 接入 Xcode Build Phase，拷进 .app | [PHASE2_Xcode构建接入.md](./PHASE2_Xcode构建接入.md) | ✅ 脚本+模拟验证 |
| 3 — Swift 侧改造：拉起 openclaw | [PHASE3_Swift侧改造.md](./PHASE3_Swift侧改造.md) | ✅ 代码完成 |
| 4 — 端到端验证 | [PHASE4_端到端验证.md](./PHASE4_端到端验证.md) | ✅ 逻辑验证（Xcode 构建待用户） |
| 5 — 裁剪（后续） | _不在本次范围_ | ⬜ |

## 文档约定

每个阶段产出 `PHASE<N>_<中文标题>.md`，固定含：目标 / 执行的操作（可复制命令）/ 修改的文件清单及说明 / 验证结果（如实记成功或失败）/ 问题与决策 / 体积数据。文档是阶段的完成凭证。

## 产物布局（目标）

```
MutualInfectionMac.app/Contents/Resources/NodeRuntime/
├── node/bin/node                 # 私有 Node arm64（复用 record/node-official/v22.16.0）
├── openclaw/{openclaw.mjs, dist/, package.json, node_modules/}   # hoisted 扁平，仅 arm64 生产依赖
└── config/openclaw.template.json # a2a-gateway 配置模板

~/Library/Application Support/MutualInfectionMac/NodeRuntime/    # 运行数据（OPENCLAW_STATE_DIR 指向）
~/Library/Logs/MutualInfectionMac/NodeRuntime/                   # 日志
```

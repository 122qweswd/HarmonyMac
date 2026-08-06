# FIX：私有 Node 从 v26.5.0 切换到 v22.16.0 LTS

> 触发：端到端验证（PHASE4）发现 Node 26 兼容性报错。本文档记录本次修复的全部操作与依据，供追溯与协作同步。
> 日期：2026-08-04

## 背景 / 目标

PHASE4 验证 openclaw runtime 在 `MutualInfectionMac.app`（`鸿蒙星河互联.app`）内运行时，`stderr.log` 反复出现：

```
TypeError: Cannot set property signal of #<IncomingMessage> which has only a getter
    at dist/auth-profiles-CUUGuGNp.js:27829
    at Layer.handleRequest (.../node_modules/router/lib/layer.js:152:17)
    ...（express 中间件链）
```

该错误导致 18802（browser control）每个请求返回 HTTP 500，并可能影响 a2a-gateway 请求链。

**根因**：私有 Node 用的是 **v26.5.0 Current**。Node 26 把 `http.IncomingMessage.signal` 改为**只读 getter**，而 openclaw 的 auth-profiles 中间件（及部分 express 中间件）尝试对其赋值，触发 TypeError。openclaw `engines>=22.16.0`，官方 mac app 实际跑在 22.x LTS。

**目标**：将私有 Node 回退到 **v22.16.0 LTS**，消除上述 TypeError。

## 操作过程

1. `grep -rn "26\.5\.0"` 摸清仓库内所有引用（排除 openclaw-custom/node_modules/.git），确认**代码层只有 `scripts/prepare_node_runtime_bundle.sh`**，其余均为文档。
2. 后台下载 Node v22.16.0 三件套到 `record/node-official/v22.16.0/`：
   - `node-v22.16.0-darwin-arm64.tar.gz`
   - `node-v22.16.0-darwin-x64.tar.gz`
   - `SHASUMS256.txt`
   - 来源 `https://nodejs.org/dist/v22.16.0/`
3. SHA256 校验：本地值与官方 `SHASUMS256.txt` 完全一致（见验证结果）。
4. 改 `scripts/prepare_node_runtime_bundle.sh`：引入 `NODE_VERSION` 变量，切版本只改一处。
5. 同步描述当前配置的活文档（`openclaw-integration/README、PHASE1、PHASE2`）：`sed 's/26\.5\.0/22.16.0/g'`。
6. 历史步骤记录（`record/NODE_RUNTIME_STEP4-6.md`）保留原 v26.5.0 表述，**不回改**（历史决策事实）。
7. 在 `NODE_RUNTIME_INTEGRATION_CHECKLIST.md` 决策记录区追加本次版本回退说明。

## 修改清单

| 文件 | 改动 |
|------|------|
| `scripts/prepare_node_runtime_bundle.sh` | 引入 `NODE_VERSION="22.16.0"`；`OFFICIAL_NODE_DIR`、arm64/x86_64 的 `NODE_ARCHIVE_NAME`、`NODE_EXTRACTED_DIR` 全部改用 `node-v${NODE_VERSION}-...`；加版本选择注释（为何选 22 LTS） |
| `record/node-official/v22.16.0/` | 新增 `node-v22.16.0-darwin-arm64.tar.gz` + `node-v22.16.0-darwin-x64.tar.gz` + `SHASUMS256.txt` |
| `openclaw-integration/README.md` | `26.5.0` → `22.16.0` |
| `openclaw-integration/PHASE1_离线打包产物.md` | `26.5.0` → `22.16.0` |
| `openclaw-integration/PHASE2_Xcode构建接入.md` | `26.5.0` → `22.16.0` |
| `NODE_RUNTIME_INTEGRATION_CHECKLIST.md` | 决策记录区追加版本回退说明 |

**未改**（保留为历史记录，记录当时决策事实）：`record/NODE_RUNTIME_STEP4_私有Node二进制准备方案.md`、`STEP5`、`STEP6`。

## 决策与依据

- 选 **22.16.0 LTS**：正好是 openclaw `engines>=22.16.0` 的最低线；LTS 稳定；openclaw 官方 mac app 用 22.x；Node 26 太新，引入只读 `signal` 破坏现有中间件。
- 不回改历史 STEP 记录：追溯文档应保留各步骤当时的真实决策，版本演进用 CHECKLIST 决策记录 + 本文档承载，避免历史被改写。
- 把版本提取为 `NODE_VERSION` 变量：以后换版本只改一行，避免散落硬编码再漏改（之前 v26.5.0 在脚本里硬编码 5 处）。

## 验证结果

- **SHA256（本地 == 官方）**：
  - arm64 `1d7f34ec4c03e12d8b33481e5c4560432d7dc31a0ef3ff5a4d9a8ada7cf6ecc9`
  - x64　 `838d400f7e66c804e5d11e2ecb61d6e9e878611146baff69d6a2def3cc23f4ac`
- `/bin/sh -n scripts/prepare_node_runtime_bundle.sh` 语法 OK。
- `grep` 确认 `scripts/` 与 `openclaw-integration/` 无 `26.5.0` 残留。
- Node 包体积：arm64 46M / x64 47M（v26 是 57M/58M，22 更精简）。

## 待验证（下一步，需重新构建 App）

1. 重新执行 `scripts/prepare_openclaw_bundle.sh` → Xcode 构建 `MutualInfectionMac` → 启动 App。
2. 确认 `node --version`（从日志或进程）为 `v22.16.0`。
3. 确认 `stderr.log` **不再出现** `Cannot set property signal` TypeError。
4. 确认 18802（browser control）`/` 不再返回 HTTP 500。

> 注：a2a-gateway `/.well-known/agent-card.json` 返回 404 是**独立的端口冲突问题**（a2a-gateway 与主 gateway 共用 18800，agent-card 路由被主 gateway 接管），不在本次修复范围。建议另行把 a2a-gateway `server.port` 改成独立端口（如 18810）。

## 风险 / 已知限制

- `record/node-official/` 现同时存有 v26.5.0（~115M）和 v22.16.0（~93M）。确认 22.16 稳定后可删除 v26.5.0 节省仓库体积（需同步 `.gitignore` 与构建机缓存策略）。
- `openclaw-custom/dist` 是编译后产物，运行用 22.16 应无碍；若后续出现 22.16 不支持的语法（22.16 支持到 ES2024），需重新评估。
- 旧 v26.5.0 的 `SHASUMS256.txt`、tar 包未删除，仍占用仓库空间。

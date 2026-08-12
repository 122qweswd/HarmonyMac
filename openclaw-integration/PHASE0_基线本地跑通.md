# 阶段 0 — openclaw-source 本地基线跑通

> 状态：✅ 完成（跑通标准达成，含 1 个已记录的已知问题）
> 日期：2026-08-04
> 执行人：Claude（与用户协作）

## 目标

在动打包之前，证明 `openclaw-source/` 能在本机跑起来、a2a-gateway 能作为常驻进程监听端口并响应。定义"跑通标准"。

## 执行的操作（可复制）

```bash
# 1. 准备 pnpm（package.json 指定 packageManager: pnpm@10.23.0）
corepack enable
corepack prepare pnpm@10.23.0 --activate
pnpm -v   # → 10.23.0

# 2. 补全依赖（见下方"问题与决策"为何要重建）
cd openclaw-source
CI=true pnpm install --ignore-scripts --prefer-offline
# → Done in 2m 1.1s

# 3. 验证基础可执行
node openclaw.mjs --version        # → OpenClaw 2026.3.13

# 4. 用临时目录 + 环境变量重定向，避免污染 ~/.openclaw
mkdir -p /tmp/oc-test/.openclaw
export OPENCLAW_HOME=/tmp/oc-test
export OPENCLAW_STATE_DIR=/tmp/oc-test/.openclaw
export OPENCLAW_CONFIG_PATH=/tmp/oc-test/.openclaw/openclaw.json

# 5. 确认 a2a-gateway 是 stock 内置且 loaded
node openclaw.mjs plugins list | grep -i a2a
# → A2A Gateway | a2a-gateway | loaded | stock:a2a-gateway/index.ts | 1.3.0

# 6. 启动 gateway（--allow-unconfigured 见"问题与决策"）
node openclaw.mjs gateway run --force --port 18800 --allow-unconfigured &

# 7. 探测端点
curl -s http://127.0.0.1:18800/health                 # → 200
curl -s http://127.0.0.1:18800/a2a/jsonrpc            # → 200
curl -s http://127.0.0.1:18800/.well-known/agent-card.json   # → 404（已知问题）
```

## 修改的文件清单

本阶段**没有修改任何源码**。变更均为环境/依赖层面：

| 路径 | 变更 | 说明 |
|------|------|------|
| `openclaw-source/node_modules/` | 重建 | 见下"问题与决策①"。1.9G → 1.1G |
| `~/Library/pnpm/store/v10/` | 新增 1.1G | pnpm 全局 store（重建时填充，后续阶段复用） |
| `/tmp/oc-test/` | 新增（临时） | 阶段 0 验证用的运行时目录，**不进仓库** |

> 注：`/tmp/oc-test/.openclaw/openclaw.json` 是测试配置，openclaw 启动时还会自动往里写入 `gateway.auth.token`、`agents.defaults`、`commands`、`meta` 等字段（自动配置行为）。

## 验证结果

| 验证项 | 结果 | 证据 |
|--------|------|------|
| `openclaw --version` | ✅ | `OpenClaw 2026.3.13`，exit 0 |
| a2a-gateway 插件加载 | ✅ | `plugins list` 显示 `loaded`，Source=`stock:a2a-gateway/index.ts` |
| `OPENCLAW_*` 环境变量重定向 | ✅ | 运行数据写到 `/tmp/oc-test/.openclaw`，未污染 home |
| gateway 进程启动并监听 | ✅ | 日志 `a2a-gateway: HTTP listening on 127.0.0.1:18800` + `gRPC listening on 18801` |
| `/health` | ✅ 200 | 可作 ready 信号 |
| `/a2a/jsonrpc`、`/a2a/metrics` | ✅ 200 | a2a 服务可用 |
| `/`（Control UI） | ✅ 200 | HTML（OpenClaw Control 页面） |
| `/.well-known/agent-card.json` | ❌ 404 | **已知问题，见下** |

**跑通标准达成**：openclaw 可执行 + a2a-gateway 监听并响应（`/health`、`/a2a/jsonrpc` 200）。

## 遇到的问题与决策

### ① 现有 node_modules 不可用，pnpm 触发重建
- **现象**：首次 `node openclaw.mjs` 报 `Cannot find package 'chalk'`；`pnpm install` 报 `ERR_PNPM_ABORTED_REMOVE_MODULES_DIR_NO_TTY`。
- **根因**：`openclaw-source/` 是从别处拷贝进本仓库的，`node_modules`（1.9G）随之拷来，但 pnpm 全局 store 路径变了（本机 `~/Library/pnpm/store/v10` 为空）→ 顶层符号链接（如 `node_modules/chalk`）断链 → ESM `import "chalk"` 解析失败。pnpm 检测到 `.modules.yaml` 与当前 store 不一致，要求重建。
- **决策**：设 `CI=true` 让 pnpm 非交互重建（`pnpm install --ignore-scripts` 跳过原生编译，先验证纯 JS 主链路）。重建耗时 2m1s，store 填充 1.1G，此后可复用。
- **对后续阶段的影响**：阶段 1 打包时，store 已有缓存，重新 `pnpm install --prod --node-linker=hoisted` 会快很多。

### ② gateway 启动被门控拦截
- **现象**：`gateway run` 日志 `Gateway start blocked: set gateway.mode=local (current: unset) or pass --allow-unconfigured`。
- **决策**：阶段 0 用 `--allow-unconfigured` 绕过；阶段 3 Swift 注入配置时，应在 `openclaw.json` 写 `"gateway": {"mode": "local"}`（更规范，不依赖命令行 flag）。

### ③ agent-card 端点 404（已知问题，待阶段 3 处理）
- **现象**：`/.well-known/agent-card.json` 返回 404，而 `/a2a/jsonrpc`、`/a2a/metrics`、`/health` 都 200。
- **分析**：
  - `@a2a-js/sdk` 的 `AGENT_CARD_PATH = ".well-known/agent-card.json"`，`a2a-gateway/index.ts:570-575` 确实在该路径注册了 `agentCardHandler`。
  - `agentCardHandler` 出错时返回 **500**（非 404）；404 响应头含 `X-Content-Type-Options: nosniff`（gateway 主 server 的 header，非 express）。
  - 结论：请求**未到达** a2a-gateway 的 express app——gateway 主 server 把 `/a2a/*` 代理到 a2a app，但未把 `/.well-known/*` 代理过去。这是定制版 gateway 框架与 a2a-gateway 插件的路由集成细节。
- **影响**：A2A 协议的标准"发现"端点暂时不可达，外部 peer 无法通过 agent-card 发现本节点。但不影响 gateway 自身运行和 a2a jsonrpc 通信。
- **决策**：不在阶段 0 深挖（需读 openclaw gateway 框架的 HTTP 代理逻辑，超出范围）。如实记录，留待后续阶段排查。**阶段 3 的 ready 检测改用 `/health`（已验证 200），不依赖 agent-card。**

### ④ 路径泄漏（阶段 3 必须处理）
- **现象**：日志显示 `a2a-gateway: durable task store at /Users/jiahaoli/.openclaw/a2a-tasks` 和 `log file: /tmp/openclaw/openclaw-2026-08-04.log`——这些**没被** `OPENCLAW_HOME` 重定向。
- **根因**：a2a-gateway 的 `storage.tasksDir`、`observability.auditLogPath` 有独立默认值（见 `openclaw.plugin.json`，默认 `~/.openclaw/...`），不受 `OPENCLAW_HOME` 控制。
- **决策**：阶段 3 注入配置时，在 `plugins.entries.a2a-gateway.config` 里显式设 `storage.tasksDir`、`storage.auditLogPath` 指向 App 的 Application Support 目录，避免写用户 home。

### ⑤ 裁剪线索（供阶段 5）
`plugins list` 显示大量插件 `disabled`（discord/telegram/whatsapp/matrix/feishu/line/slack/imessage/.../playwright 渠道、llm-task、memory-lancedb 等），仅 `a2a-gateway`、`device-pair`、`memory-core` 是 `loaded`。阶段 5 裁剪时可优先剔除这些 disabled 插件及其依赖。

## 体积数据

| 阶段 | node_modules | 说明 |
|------|--------------|------|
| 拷贝来的原始 | 1.9G | 含 Windows/Linux 跨平台二进制 + devDependencies |
| pnpm 重建后（全量，含 dev） | 1.1G | `--ignore-scripts` 未编译原生；结构规整 |
| 阶段 1 目标（仅 arm64 生产依赖） | 待测 | 预计进一步显著下降 |

## 下一步

进入阶段 1：用 `pnpm install --prod --node-linker=hoisted` + `supported-architectures=darwin/arm64` 构造扁平、仅 arm64 生产依赖的离线产物，并用私有 node 验证其自包含可跑。

# 阶段 0 — openclaw-source 本地基线跑通

> 状态：✅ 历史阶段已完成
> 原执行日期：2026-08-04
> 最后同步：2026-08-20

## 目标

在改动打包链之前，证明 `openclaw-source/` 能在本机启动，a2a-gateway 能作为常驻服务监听端口并响应请求，为后续离线打包与 App 托管建立基线。

## 当时执行的操作

```bash
# package.json 当时指定 pnpm@10.23.0
corepack enable
corepack prepare pnpm@10.23.0 --activate

cd openclaw-source
CI=true pnpm install --ignore-scripts --prefer-offline

node openclaw.mjs --version

mkdir -p /tmp/oc-test/.openclaw
export OPENCLAW_HOME=/tmp/oc-test
export OPENCLAW_STATE_DIR=/tmp/oc-test/.openclaw
export OPENCLAW_CONFIG_PATH=/tmp/oc-test/.openclaw/openclaw.json

node openclaw.mjs plugins list | grep -i a2a
node openclaw.mjs gateway run --force --port 18800 --allow-unconfigured
```

当时的探测：

```bash
curl -s http://127.0.0.1:18800/health
curl -s http://127.0.0.1:18800/a2a/jsonrpc
curl -s http://127.0.0.1:18800/.well-known/agent-card.json
```

## 当时的验证结论

| 验证项 | 结果 | 说明 |
|---|---|---|
| OpenClaw CLI 可执行 | ✅ | 当时版本输出 `OpenClaw 2026.3.13` |
| a2a-gateway 插件加载 | ✅ | `plugins list` 显示 stock plugin loaded |
| `OPENCLAW_*` 重定向 | ✅ | 基础运行数据写入 `/tmp/oc-test` |
| gateway / A2A JSON-RPC | ✅ | `/health`、`/a2a/jsonrpc` 可响应 |
| agent-card | ❌ 404 | 当时主 gateway 与 a2a 插件共用 18800，实际命中主 gateway 404 |
| 依赖可用性 | ✅（重建后） | 拷贝来的 pnpm `node_modules` 因 store 路径变化出现断链，重装后恢复 |

## 当时发现的问题与后续处理

### 1. 拷贝来的 `node_modules` 不可复用

- 现象：`Cannot find package 'chalk'`，且 pnpm 检测到 store 不一致。
- 根因：pnpm 顶层依赖是指向全局 store 的符号链接；项目拷贝后原 store 不存在。
- 决策：用 `CI=true pnpm install --ignore-scripts` 重建。
- 后续影响：促成 PHASE1 使用 hoisted 扁平依赖构造可分发产物。

### 2. 未配置 gateway mode 时启动被阻止

- 当时使用 `--allow-unconfigured` 临时绕过。
- 后续在模板中固化 `gateway.mode=local`，正式启动不再依赖该 flag。

### 3. agent-card 404

- 当时发现 `/.well-known/agent-card.json` 未命中 a2a express app。
- 后续确认是 Mac 主 gateway 和 a2a-gateway 都占用 18800。
- 最终由 A2A 端口分离改动解决：Mac 主 gateway 18800，Mac A2A HTTP 18810；详细历史已汇总到 `00_集成总览.md` 与 `工作总结.md`。

### 4. a2a 存储路径泄漏到用户 Home

- 当时日志显示 durable tasks/audit 使用默认路径。
- 当前模板已显式配置：
  - `storage.tasksDir=${OPENCLAW_STATE_DIR}/a2a-tasks`
  - `observability.auditLogPath=${OPENCLAW_STATE_DIR}/a2a-audit.jsonl`
- 当前入站文件另配置为用户可见的 `~/Desktop/A2A-Files`。

## 2026-08-20 当前状态补充

阶段 0 的最小本地验证已演进为真实跨端 A2A 系统：

- Mac 身份：`TargetMac`；A2A HTTP 18810；主 gateway 18800。
- HarmonyOS 手机身份：`HW-Phone1`；A2A HTTP 18800。
- A2A 入站鉴权：bearer token，不再是 `none`。
- Agent Card URL 使用运行时探测到的 LAN IPv4，而非固定 localhost。
- 双端通过 registry/tunnel 发现和通信；`verify.sh` 覆盖双向消息与双向文件。
- 本阶段当时的 404、路径泄漏和无鉴权均已解决或替换。

## 历史体积数据

| 项目 | 当时数据 | 说明 |
|---|---:|---|
| 拷贝来的原始 `node_modules` | 1.9G | 含断链与跨平台内容 |
| pnpm 重建后 | 1.1G | 阶段 0 基线值 |

> 当前依赖树和构建脚本已更新，体积优化应重新统计最新 `openclaw-bundle-output/`，不应把上述历史数值当成当前精确值。

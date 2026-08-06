# FIX：a2a-gateway 端口分离（解决 agent-card 404）

> 触发：PHASE4 验证发现 `curl http://127.0.0.1:18800/.well-known/agent-card.json` 返回 404。本文档记录修复全过程。
> 日期：2026-08-04

## 背景 / 目标

PHASE4 实测：openclaw 启动日志里 a2a-gateway 与主 gateway **都声称 listening on 18800**：
```
[gateway] listening on ws://127.0.0.1:18800 (PID ...)        ← 主 gateway（控制台/canvas）
[gateway] a2a-gateway: HTTP listening on 127.0.0.1:18800      ← a2a-gateway 也配了 18800
```
但实际 `18800/.well-known/agent-card.json` 命中的是**主 gateway 的 404**——a2a-gateway 没能真正绑到 18800（被主 gateway 先占），其 agent-card 路由没生效。

**根因**：模板 `openclaw.template.json` 里 `a2a-gateway.config.server.port` = 18800，与 openclaw 主 gateway 端口（`gateway run --port 18800`）冲突。

**目标**：a2a-gateway 改用独立端口 **18810**，主 gateway 保持 18800，agent-card 在 18810 可访问。

## 一个关键障碍（决定了实现方式）

改完模板后，发现沙盒容器里已生成的旧 `openclaw.json`（port 18800）**外部进程无法删除/修改**：
```
rm: .../openclaw.json: Operation not permitted
sed: ...: Operation not permitted
```
权限是 `-rw-------`（用户可写）、无 immutable flag、无 ACL，但仍被拒。原因：**macOS App Sandbox 容器保护**——`~/Library/Containers/<bundle-id>/Data/` 内文件，外部进程只读，只有 App 自己能写。而 `NodeRuntimeManager.prepareRuntimeConfig` 原逻辑是"仅首次生成、已存在则保留"，所以光改模板，旧 18800 配置永不更新。

**因此必须让 App 自己在模板变更时重新生成配置** → 引入 `configVersion` 版本机制。

## 操作过程

1. 模板 `NodeRuntimeHost/config/openclaw.template.json`：
   - `a2a-gateway.config.server.port`：`18800` → `18810`
   - 顶层新增 `"configVersion": 1`
2. `NodeRuntimeManager.prepareRuntimeConfig` 改造：
   - 读取模板与容器配置的顶层 `configVersion`；
   - 容器配置缺失、或其版本 ≠ 模板版本时，**由 App 自己**（有容器写权限）删旧配置、从模板重新生成；
   - 兜底配置（模板缺失时）的 a2a 端口也改成 18810（原来用 `layout.gatewayPort`=18800，会冲突）。
3. 新增私有方法 `configVersion(at:)` 解析 JSON 顶层版本号。
4. 尝试清理容器旧配置失败（外部不可写），改由 App 启动时自愈（版本机制）。

## 修改清单

| 文件 | 改动 |
|------|------|
| `NodeRuntimeHost/config/openclaw.template.json` | a2a `server.port` 18800→18810；顶层加 `"configVersion": 1` |
| `MutualInfectionMac/Application/NodeRuntimeManager.swift` | `prepareRuntimeConfig` 加 configVersion 版本检查，版本不符时由 App 重新生成配置；兜底配置 a2a 端口改 18810；新增 `configVersion(at:)` |

## 决策与依据

- 选 **18810**：与主 gateway 18800 错开 10，留出 18801/18802/18803（a2a gRPC、browser control 等已占用）的间隔，避免再撞。
- 用 **configVersion 机制**而非"每次覆盖"：用户后续可能在容器配置里加 a2a `peers`/`tunnel`/`token` 等运行时数据，每次覆盖会丢失；版本机制只在开发者主动 bump `configVersion` 时重生成，可演进。
- 不改 NodeRuntimeManager 的 `gatewayPort`（主 gateway 仍 18800）：冲突只在 a2a 侧，最小改动。

## 验证步骤（重新构建后）

1. Xcode 重新 Build & Run `MutualInfectionMac`。
2. 看 runtime.log，应出现：
   - `已按模板重新生成 openclaw 配置（configVersion=1）`（说明版本机制触发，旧配置被覆盖）
   - `[gateway] a2a-gateway: HTTP listening on 127.0.0.1:18810`（端口已分离）
3. curl 验证 a2a-gateway 身份端点：
   ```bash
   curl -s http://127.0.0.1:18810/.well-known/agent-card.json
   # 期望：返回 JSON，含 "protocolVersion":"0.3.0" 和 agentCard.name
   ```
4. 确认容器内配置已更新：
   ```bash
   F=~/Library/Containers/com.HarmonyOSInterconnection.app/Data/Library/Application\ Support/MutualInfectionMac/NodeRuntime/config/openclaw.json
   grep -E "configVersion|port" "$F"
   # 期望：configVersion: 1, a2a port 18810
   ```

## 风险 / 已知限制

- **版本覆盖会丢运行时配置**：bump `configVersion` 触发重生成时，用户在容器 `openclaw.json` 里手动加的 `peers`/`tunnel` 会被清掉。当前阶段没有这类配置，可接受。后续若需保留用户运行时数据，应把"默认模板"与"用户覆盖项"分离（例如 openclaw 的 `plugins.entries` 配置覆盖机制或独立 user-config 文件）。
- 主 gateway 18800 与 a2a-gateway 18810 都监听，外部若要做 A2A 互通，应对接 **18810**（a2a 协议端口），不是 18800（那是 openclaw 控制台）。
- 依赖 PHASE Node22 修复一起验证：建议先换 Node 22.16（消除 TypeError），再验证 a2a 端口分离，两者可同一次构建一并验证。

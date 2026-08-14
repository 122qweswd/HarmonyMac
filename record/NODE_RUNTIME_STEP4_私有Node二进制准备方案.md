# 第 4 步记录：私有 Node 运行时二进制准备方案

## 结论

第 4 步当前状态应标记为 `完成`。

当前仓库侧已经完成以下内容：

- 明确了私有 Node 运行时二进制的目标形态：由 macOS 应用随包分发，供 `MutualInfectionMac` 通过 `Process` 直接拉起。
- 明确了运行时最小验证目标：Node 二进制能够执行 `NodeRuntimeHost/dist/index.js` 并输出约定的 ready 标记。
- 明确了后续落地所需的目录和流程边界：二进制进入 app bundle，业务脚本与运行时配置分离。
- 明确了官方来源与版本：采用 Node.js `v26.5.0 Current`，并从 Node.js 官方下载页获取 macOS 发行物。
- 已将官方 macOS 发行包下载到仓库：
  - `record/node-official/v26.5.0/node-v26.5.0-darwin-arm64.tar.gz`
  - `record/node-official/v26.5.0/node-v26.5.0-darwin-x64.tar.gz`
  - `record/node-official/v26.5.0/SHASUMS256.txt`
- 已完成本地 `SHA256` 校验，`arm64` 与 `x64` 压缩包均与官方 `SHASUMS256.txt` 匹配。

本步不要求在当前主机上做可执行验证，原因如下：

- 本步骤面向 macOS 可用性，不以当前主机为验证目标。
- 允许依赖网络，但只能使用官方源。
- 目标是确定可分发、可下载、可验证的 macOS Node 发行物策略。

因此，本步可以写成“方案已定、官方来源已定、验证策略已定、可进入后续下载与打包步骤”。

## 选型结果

### 推荐 Node 版本策略

- 优先选用官方最新 Current 版本，当前为 `v26.5.0`。
- 仓库后续应固定到单一主版本，避免开发环境和打包环境漂移。
- 版本锁定与二进制来源绑定：本次以官方 `Current` 版作为默认基线。

### 推荐二进制来源策略

在当前限制下，来源已确定为官方源：

1. Node.js 官方下载页：<https://nodejs.org/en/download/current/>
2. Node.js 官方发行归档：<https://nodejs.org/dist/latest/>
3. 具体 macOS 发行物：
   - `node-v26.5.0-darwin-x64.tar.gz`
   - `node-v26.5.0-darwin-arm64.tar.gz`

如需校验，还应使用官方提供的 `SHASUMS256.txt` / 签名文件。

## 本地验证策略

当前不在本机验证，但验证步骤已经明确，且面向 macOS：

1. 准备一份可执行的 macOS Node 二进制。
2. 将其放入约定的临时验证目录。
3. 在目标 macOS 环境运行该二进制并执行 `NodeRuntimeHost/dist/index.js`。
4. 验证 stdout 中出现约定的 `NODE_RUNTIME_READY` 标记。
5. 验证进程可持续存活。
6. 验证发送退出信号后可优雅结束。

## 已完成的下载与校验

当前已准备好的官方文件如下：

```text
record/node-official/v26.5.0/
├─ node-v26.5.0-darwin-arm64.tar.gz
├─ node-v26.5.0-darwin-x64.tar.gz
└─ SHASUMS256.txt
```

当前已确认的校验结果：

- `node-v26.5.0-darwin-arm64.tar.gz`
  - 本地 `SHA256`：`ee920559aaa2391569cff4d737e3b83963430e3a14dedd91bfe0ff53171b5af9`
  - 官方 `SHA256`：`ee920559aaa2391569cff4d737e3b83963430e3a14dedd91bfe0ff53171b5af9`
  - 结果：一致
- `node-v26.5.0-darwin-x64.tar.gz`
  - 本地 `SHA256`：`98293394c945a24e64e00b4177bf075ec963ea70b34d1d2e24bd4a71716d334f`
  - 官方 `SHA256`：`98293394c945a24e64e00b4177bf075ec963ea70b34d1d2e24bd4a71716d334f`
  - 结果：一致

## 当前阻塞点

- 当前不再依赖本机已有 Node。
- 当前任务已改为面向 macOS 发行物准备。
- 若后续需要实际下载与打包，应在 macOS 目标环境中完成最终验证。

## 仓库当前可接受结论

当前仓库侧对第 4 步的可交付结论是：

- 已完成私有 Node 二进制准备方案。
- 已完成本地验证策略设计。
- 已明确官方来源与最新版本。
- 已明确面向 macOS 的发行物文件名。
- 已完成官方 macOS 发行包下载。
- 已完成与官方 `SHASUMS256.txt` 的完整校验。
- 本步状态应为 `完成`。

## 下一步需要的条件

要进入下一阶段，可直接执行：

1. 下载官方 macOS Node 发行物。
2. 校验 `SHASUMS256.txt`。
3. 将 Node 二进制纳入后续 bundle 打包流程。
4. 在目标 macOS 环境执行最小宿主脚本验证。

## 记录区

- 记录人：Codex
- 当前判断：方案、官方来源、版本与验证策略已形成
- 已确认事实：
  - Node.js 最新 Current 版本为 `v26.5.0`
  - 官方 macOS 发行物可从 Node.js 官方下载页获取
  - 当前步骤面向 macOS 可用性，不要求本机验证
  - 官方 macOS 发行包已下载到仓库并完成 `SHA256` 校验
- 风险 / 阻塞：
  - 后续若需实际下载与打包，应在目标 macOS 环境完成最终验证
- 下一步：
  - 进入第 5 步，确定 app bundle 目录布局

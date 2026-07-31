# Node 运行时第 2 步记录

## 目标

创建一个仅用于验证 Node 运行时托管能力的最小宿主项目，为后续 Xcode 接入、Swift 进程管理和运行时复制策略提供稳定基础。

## 本次落地结果

已在仓库根目录新增：

```text
NodeRuntimeHost/
├─ package.json
├─ tsconfig.json
├─ README.md
└─ src/
   └─ index.ts
```

## 目录选择说明

当前将最小宿主项目放在仓库根目录下的 `NodeRuntimeHost/`，原因如下：

1. 当前阶段它仍是独立验证项目，不应过早与某个 Xcode target 深耦合。
2. 后续 Xcode Build Phase 可以从固定根目录复制其构建产物。
3. 后续若需要替换实现或迁移路径，影响范围更可控。

## 当前入口行为

`src/index.ts` 当前行为如下：

1. 解析 `--config` 参数
2. 启动后输出进程信息
3. 输出固定 ready 标记 `NODE_RUNTIME_READY`
4. 按固定间隔输出 heartbeat
5. 收到 `SIGINT` / `SIGTERM` 后输出停止标记并退出
6. 对 `uncaughtException` 和 `unhandledRejection` 输出错误并以非零状态退出

## 当前脚本设计意图

该入口暂不承载业务逻辑，只用于证明以下链路：

- Node 项目结构可独立维护
- TypeScript 可编译为运行时产物
- Swift 后续可依据 ready 标记判断启动成功
- Swift 后续可观察进程生命周期和异常退出

## 当前限制

当前项目仍未完成以下内容：

1. 尚未执行依赖安装与实际构建验证
2. 尚未定义 `dist/` 是否入库
3. 尚未确定是否直接分发 `node_modules`
4. 尚未接入 Xcode Build Phase
5. 尚未接入 Swift `Process` 启动逻辑

这些内容属于后续步骤范围，不影响第 2 步完成。

## 建议下一步

建议进入第 3 步，明确以下问题：

- 构建产物是否只复制 `dist/`
- 是否需要在打包阶段携带完整 `node_modules`
- Node 项目如何在 Xcode 构建前自动编译

# NodeRuntimeHost

这是 `nshare_1926` 用于验证 macOS 内置 Node 运行时托管能力的最小宿主项目。

当前目标：

- 提供一个可独立构建的 Node 项目骨架
- 提供一个最小入口脚本
- 输出固定 ready 标记供 Swift 侧识别
- 保持进程存活，便于后续接入 `Process` 管理
- 收到退出信号后能够优雅结束

当前目录说明：

- `package.json`：项目定义与基础脚本
- `tsconfig.json`：TypeScript 构建配置
- `src/index.ts`：最小宿主入口

当前入口行为：

1. 启动后输出进程信息
2. 输出 `NODE_RUNTIME_READY`
3. 每隔一段时间输出 heartbeat
4. 收到 `SIGINT` 或 `SIGTERM` 后输出停止标记并退出

当前示例启动参数：

```bash
node dist/index.js --config /path/to/runtime-config.json
```

后续步骤：

- 第 3 步：确定构建产物与依赖复制策略
- 第 4 步：准备私有 Node 二进制
- 第 7 步：由 Swift 侧实现运行时管理器并拉起此入口

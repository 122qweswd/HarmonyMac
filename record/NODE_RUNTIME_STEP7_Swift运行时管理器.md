# 第 7 步记录：实现 Swift 运行时管理器

## 结论

第 7 步当前状态标记为 `完成`。

本步骤已经完成以下内容：

- 新增了 `NodeRuntimeManager.swift`
- 将其接入 `AppDelegate` 启动与退出生命周期
- 完成了 bundle 内路径解析
- 完成了 bundle 外运行目录准备
- 完成了 Node 进程启动、stdout/stderr 捕获、ready 信号识别与优雅停止

本步骤仍未完成真实 macOS/Xcode 运行验证，但从代码结构上已经把第 7 步所需职责落到了工程内。

## 本次改动

### 1. 新增运行时管理器

新增：

```text
MutualInfectionMac/Application/NodeRuntimeManager.swift
```

主要职责：

- 解析 bundle 内 Node 路径
- 解析 bundle 外可写目录
- 首次启动时创建运行目录
- 复制或生成运行配置文件
- 使用 `Process` 拉起 `NodeRuntimeHost/dist/index.js`
- 捕获 stdout / stderr
- 识别 `NODE_RUNTIME_READY`
- 在应用退出时终止进程

### 2. 接入 AppDelegate 生命周期

已修改：

```text
MutualInfectionMac/AppDelegate.swift
```

接入方式：

- `applicationDidFinishLaunching` 中调用 `nodeRuntimeManager.startIfNeeded()`
- `applicationWillTerminate` 中调用 `nodeRuntimeManager.stop()`
- `applicationShouldTerminate` 中再次调用 `nodeRuntimeManager.stop()`，保证退出链路幂等

## 当前路径实现

### bundle 内

管理器当前按第 5 步约定解析：

- `NodeRuntime/node/bin/node`
- `NodeRuntime/host/dist/index.js`
- `NodeRuntime/config/runtime-config.template.json`

### bundle 外

管理器当前会准备：

- `~/Library/Application Support/MutualInfectionMac/NodeRuntime/`
- `~/Library/Application Support/MutualInfectionMac/NodeRuntime/config/runtime-config.json`
- `~/Library/Application Support/MutualInfectionMac/NodeRuntime/state/`
- `~/Library/Application Support/MutualInfectionMac/NodeRuntime/cache/`
- `~/Library/Application Support/MutualInfectionMac/NodeRuntime/tmp/`
- `~/Library/Logs/MutualInfectionMac/NodeRuntime/runtime.log`
- `~/Library/Logs/MutualInfectionMac/NodeRuntime/stderr.log`

## 当前进程行为

启动时：

- 若当前状态不是 `idle/stopped/failed`，则跳过重复启动
- 准备配置目录与日志目录
- 若运行配置不存在，则从模板复制；若模板缺失，则生成一个回退 JSON
- 启动 bundle 内 Node，参数为：

```text
<node> <host/dist/index.js> --config <runtime-config.json>
```

运行时：

- 读取 stdout / stderr
- 逐行写入 `ShareAPI` 日志
- 同步写入 `runtime.log` 与 `stderr.log`
- 识别 `NODE_RUNTIME_READY` 和 `NODE_RUNTIME_STOPPED`

停止时：

- 取消 `readabilityHandler`
- 终止进程
- 关闭日志文件句柄

## 当前风险

- 当前尚未在 macOS 真机或 Xcode 真实运行环境中验证 `Process` 拉起是否成功。
- 当前 `NodeRuntimeHost/dist/index.js` 仍是落库产物，后续若 `src/index.ts` 变化，需要同步维护。
- 当前没有实现启动超时、自动重试、崩溃重启等高级策略。
- 当前没有把运行状态回传给 UI，只做日志级管理。

## 下一步建议

建议继续进入第 8 步，补启动握手协议的显式超时策略和失败处理路径。

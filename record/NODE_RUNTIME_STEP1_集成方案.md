# Node 运行时集成方案

## 目标

为 `MutualInfectionMac` 集成一套应用私有的 Node 运行时，使 macOS App 在不依赖用户系统 Node 环境的前提下，可以稳定地：

- 定位内置 Node 可执行文件
- 启动自带的 Node 宿主脚本
- 读取启动完成信号
- 捕获日志与退出状态
- 为后续业务层接入预留稳定边界

当前方案只解决运行时接入，不处理 `openclaw`、商店审核、自动更新和生产加固问题。

## 方案结论

第 1 步采用以下基线方案：

1. Node 作为应用私有运行时随 `MutualInfectionMac.app` 一起分发。
2. Swift 不直接依赖系统 Node，不执行 `npx`，也不依赖用户本地 npm 环境。
3. Swift 通过 `Process` 拉起 app bundle 内置的 Node 二进制。
4. Node 只运行项目内自维护的最小宿主脚本，不直接把复杂业务逻辑塞进启动入口。
5. 第一版只运行构建后的 JavaScript 产物，不在应用内直接跑 TypeScript 源码。
6. Swift 与 Node 的边界先定义为“进程管理 + stdout/stderr + ready 信号”，后续再扩展本地 IPC。

## 推荐架构

整体结构：

`MutualInfectionMac (Swift)`
-> `Process`
-> `bundle 内置 node`
-> `bundle 内置 node host 脚本`

说明：

- `MutualInfectionMac` 负责生命周期管理。
- Node 负责提供一个稳定的后台运行时入口。
- 业务层功能后续挂到 Node 宿主项目中，而不是直接耦合 Swift。

## 目录布局建议

建议将 bundle 内的运行时文件组织为：

```text
MutualInfectionMac.app
└─ Contents
   └─ Resources
      └─ runtime
         ├─ node
         │  └─ bin
         │     └─ node
         └─ app
            ├─ dist
            │  └─ index.mjs
            ├─ node_modules
            └─ package.json
```

说明：

- `runtime/node/bin/node`：内置 Node 可执行文件
- `runtime/app/dist/index.mjs`：最小 Node 宿主入口
- `runtime/app/node_modules`：运行时依赖
- `runtime/app/package.json`：保留依赖信息和版本边界

## 运行数据目录建议

bundle 内目录只用于存放只读运行时文件。运行数据应写入用户目录，例如：

```text
~/Library/Application Support/MutualInfection/node-runtime/
~/Library/Logs/MutualInfection/node-runtime/
```

建议划分：

- `Application Support`：配置、状态、缓存
- `Logs`：stdout/stderr 持久化日志和诊断日志

不要将运行期数据写回 `.app` 包内。

## 启动方式建议

Swift 第一版通过 `Process` 启动：

- 可执行文件：bundle 内 `node`
- 启动参数：`dist/index.mjs` 与必要配置路径

建议启动形态：

```text
node /path/to/dist/index.mjs --config /path/to/runtime-config.json
```

第一版不引入额外 wrapper shell，不通过 `bash -lc` 间接启动。

## 第一版宿主脚本要求

最小 Node 宿主入口只需要满足这些行为：

1. 启动后输出固定 ready 标记，例如 `NODE_RUNTIME_READY`
2. 保持进程存活，便于 Swift 管理与观察
3. 捕获 `SIGTERM` / `SIGINT` 并优雅退出
4. 能读取一份由 Swift 生成的配置文件
5. 将关键启动信息打印到 stdout/stderr

这样能先打通运行时接入链路，再逐步挂业务能力。

## 为什么第一版只跑 JavaScript

第一版选择运行编译后的 JavaScript，而不是运行 TypeScript 源码，原因如下：

1. 启动路径更短，依赖更少。
2. 避免在应用内引入 `ts-node`、`tsx` 等开发态运行器。
3. 出问题时更容易排查 bundle 内真正执行的文件。
4. 更适合后续做构建阶段复制和权限控制。

因此推荐开发时使用 TypeScript，交付时只复制构建后的 `dist/`。

## 为什么不依赖系统 Node

不依赖系统 Node 的原因：

1. 用户机器可能未安装 Node。
2. 即使已安装，版本也不可控。
3. 路径解析与环境变量差异会放大排障成本。
4. 后续升级与问题定位会失去可重复性。

因此，Node 必须作为应用私有组件管理。

## 与后续步骤的边界

本方案落定后，后续步骤可按以下边界推进：

- 第 2 步：创建最小 Node 宿主项目
- 第 3 步：确定 Node 构建与依赖复制策略
- 第 4 步：准备和验证 Node 二进制
- 第 5 步：将这里的目录建议落实到具体路径
- 第 6 步：接入 Xcode Build Phase
- 第 7 步：实现 `NodeRuntimeManager`

## 当前风险

当前已知但暂不处理的风险：

1. Node 二进制体积较大，后续可能需要瘦身。
2. `node_modules` 直接随包分发会增加包体积。
3. 尚未设计本地 IPC，只完成进程级托管边界。
4. 尚未验证签名、权限和分发场景。

这些风险不影响第 1 步作为基线方案成立。

## 下一步建议

建议直接进入第 2 步，创建一个最小 Node 宿主项目，先验证：

- 内置 Node 能否拉起
- ready 信号能否被 Swift 识别
- 退出信号能否正确处理
- 日志能否被捕获

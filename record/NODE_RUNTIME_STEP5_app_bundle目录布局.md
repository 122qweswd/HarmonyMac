# 第 5 步记录：确定 app bundle 目录布局

## 结论

第 5 步当前状态应标记为 `完成`。

本步骤已经明确以下内容：

- `.app` 内私有 Node 运行时的最终目录布局
- 官方 Node macOS 包解压后，哪些文件进入 bundle
- `NodeRuntimeHost` 的运行时产物在 bundle 内的映射方式
- bundle 外运行数据目录方案
- Swift 侧路径解析约定

本步骤只定义目录与路径约定，不修改 Swift 代码、不修改 Xcode Build Phase，也不推进第 6 步及以后工作。

## 一、bundle 内目录布局

推荐在 `MutualInfectionMac.app` 内使用以下固定布局：

```text
MutualInfectionMac.app
└─ Contents
   ├─ MacOS
   ├─ Resources
   │  └─ NodeRuntime
   │     ├─ node
   │     │  ├─ bin
   │     │  │  └─ node
   │     │  └─ LICENSE
   │     ├─ host
   │     │  ├─ dist
   │     │  │  └─ index.js
   │     │  └─ package.json
   │     └─ config
   │        └─ runtime-config.template.json
   └─ Info.plist
```

命名约定说明：

- `Resources/NodeRuntime/` 作为整个 Node 私有运行时的根目录。
- `node/` 只放随应用分发的 Node 二进制和必要的授权文件。
- `host/` 放 `NodeRuntimeHost` 的运行时产物。
- `config/` 放只读配置模板，不放运行期会变更的数据。

## 二、官方 Node 包解压后的取用范围

当前仓库已准备好的官方包位于：

```text
record/node-official/v26.5.0/
├─ node-v26.5.0-darwin-arm64.tar.gz
├─ node-v26.5.0-darwin-x64.tar.gz
└─ SHASUMS256.txt
```

官方压缩包解压后，第一版推荐只将以下文件放入 bundle：

### 必选文件

- `bin/node`

映射目标：

- `Contents/Resources/NodeRuntime/node/bin/node`

### 建议保留文件

- `LICENSE`

映射目标：

- `Contents/Resources/NodeRuntime/node/LICENSE`

### 第一版不进入 bundle 的内容

- `bin/npm`
- `bin/npx`
- `bin/corepack`
- `include/`
- `share/`
- 其余仅用于开发、构建或命令行生态的附属文件

原因：

- 当前目标只是让宿主 app 拉起私有 Node 并执行 `NodeRuntimeHost/dist/index.js`。
- 当前方案不依赖运行期 `npm install`、`npx`、`corepack` 或 C/C++ 原生扩展构建。
- 为控制体积和复杂度，第一版按最小运行时分发。

补充约定：

- `darwin-arm64` 包用于 Apple Silicon 构建产物。
- `darwin-x64` 包用于 Intel macOS 构建产物。
- 第一步不要求在一个 `.app` 中同时塞入两套 Node；优先采用“按目标架构分别打包”的方式。

## 三、NodeRuntimeHost 运行时产物映射

当前 `NodeRuntimeHost` 在仓库中的来源目录为：

```text
NodeRuntimeHost/
├─ package.json
├─ tsconfig.json
└─ src/
```

根据第 3 步结论，运行期只带构建产物和少量元数据。第一版映射如下：

### 必选文件

- `NodeRuntimeHost/dist/index.js`

映射目标：

- `Contents/Resources/NodeRuntime/host/dist/index.js`

### 建议保留文件

- `NodeRuntimeHost/package.json`

映射目标：

- `Contents/Resources/NodeRuntime/host/package.json`

保留 `package.json` 的原因：

- 便于运行时识别宿主项目版本与元数据
- 便于后续排障时确认 bundle 内置宿主版本
- 为未来引入少量静态元数据保留稳定落点

### 当前不进入 bundle 的文件

- `NodeRuntimeHost/src/`
- `NodeRuntimeHost/tsconfig.json`
- 构建阶段依赖文件
- 后续如有的开发脚本、测试脚本

## 四、配置模板映射

第一版建议在 bundle 内保留一个只读模板文件位置：

- `Contents/Resources/NodeRuntime/config/runtime-config.template.json`

用途：

- 提供默认配置结构
- 作为 Swift 首次生成运行配置时的参考模板
- 便于后续 agent 在不修改代码的前提下补充字段约定

注意：

- 模板文件是只读资源，不作为运行期真实配置文件。
- 真实配置文件应写到 bundle 外。

## 五、bundle 外运行数据目录方案

运行期可变数据统一放在用户目录下，不写回 `.app` 内。

推荐目录如下：

### 应用支持目录

```text
~/Library/Application Support/MutualInfectionMac/NodeRuntime/
```

建议承载内容：

- `config/runtime-config.json`
- `state/`
- `cache/`
- `tmp/`

### 日志目录

```text
~/Library/Logs/MutualInfectionMac/NodeRuntime/
```

建议承载内容：

- `runtime.log`
- `stderr.log`
- 未来扩展的诊断日志

目录职责约定：

- `Application Support` 放配置、状态、缓存等业务运行数据
- `Logs` 放日志文件
- 临时性中间文件优先落在 `Application Support/MutualInfectionMac/NodeRuntime/tmp/`

## 六、Swift 侧路径解析约定

Swift 侧应按“bundle 内只读资源”和“bundle 外可写数据”分开解析路径。

### 1. bundle 内路径解析

Node 根目录：

- `Bundle.main.resourceURL`
- 追加 `NodeRuntime/node`

Node 可执行文件：

- `Bundle.main.resourceURL`
- 追加 `NodeRuntime/node/bin/node`

宿主入口文件：

- `Bundle.main.resourceURL`
- 追加 `NodeRuntime/host/dist/index.js`

配置模板：

- `Bundle.main.resourceURL`
- 追加 `NodeRuntime/config/runtime-config.template.json`

### 2. bundle 外路径解析

应用支持目录：

- 使用 `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)`
- 在其下追加 `MutualInfectionMac/NodeRuntime`

日志目录：

- 优先使用 `FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)`
- 在其下追加 `Logs/MutualInfectionMac/NodeRuntime`

真实配置文件路径：

- `~/Library/Application Support/MutualInfectionMac/NodeRuntime/config/runtime-config.json`

### 3. 路径使用原则

- Swift 不应假设当前工作目录。
- Swift 不应通过相对路径查找 Node 运行时文件。
- 所有运行期写操作都必须落在 bundle 外目录。
- 启动 Node 时，传入绝对路径而不是相对路径。

## 七、当前接受的目录布局结论

本仓库当前对第 5 步的接受结论是：

- `.app` 内 Node 私有运行时根目录固定为 `Contents/Resources/NodeRuntime/`
- 官方 Node 包当前只取 `bin/node` 为必选运行时文件，`LICENSE` 为建议保留文件
- `NodeRuntimeHost` 当前只映射 `dist/index.js` 与 `package.json`
- 配置模板位于 bundle 内，真实配置与运行数据位于 bundle 外
- Swift 通过 `Bundle.main.resourceURL` 与 `FileManager` 标准目录 API 解析路径

## 记录区

- 记录人：Codex
- 决策说明：
  - 已确定 `.app` 内 Node 运行时统一挂在 `Contents/Resources/NodeRuntime/`。
  - 已确定第一版只分发最小运行时：Node 二进制、授权文件、宿主 `dist` 产物和少量元数据。
  - 已确定运行期可变数据全部放在 bundle 外用户目录。
  - 已确定 Swift 侧路径解析必须基于 `Bundle.main.resourceURL` 和 `FileManager` 标准目录。
- 风险 / 阻塞：
  - 当前仍未进入实际 Build Phase 复制与 macOS 真机验证。
  - 后续若引入 npm 运行期依赖，需要重新评估是否继续只复制 `bin/node`。
- 下一步：
  - 进入第 6 步，设计并接入 Xcode 构建阶段复制流程。

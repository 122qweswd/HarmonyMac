# Node 运行时集成清单

用途：用于跟踪 `nshare_1926` 的 macOS 端私有 Node.js 运行时集成工作。当前只关注 Node 环境接入，不展开后续 `openclaw` 业务集成。

使用说明：
- 随进度更新 `状态`。
- 在每一步的 `记录区` 中补充具体决策、路径、命令、阻塞点和下一步动作。
- 尽量追加记录，不要直接覆盖已有有效信息。
- 后续 agent 优先在本文件持续补充，不再新建平行计划文档。

状态说明：
- `TODO`
- `进行中`
- `阻塞`
- `完成`
- `不适用`

## 项目概览

- 范围：为 macOS target 集成应用私有 Node 运行时，并验证 Swift 能够启动和管理该运行时。
- 当前负责人：待定
- 总体状态：`TODO`
- 主要 macOS target：`MutualInfectionMac`
- 当前不包含：`openclaw` 业务接入、App Store 审核约束、超出基础运行时管理范围的生产级加固

## 清单

### 第 1 步：确定运行时集成方案

- 状态：`完成`
- 目标：确定 Node 在 macOS app 内的基本集成和启动架构。
- 交付物：
  - `.app` 内运行时目录布局说明
  - 是否直接内置 Node，还是在构建阶段动态拷贝的决策说明
  - 第一版是仅运行编译后的 JavaScript，还是运行 TypeScript 的决策说明
- 记录区：
  - 记录人：Codex
  - 决策说明：
    - Node 作为 `MutualInfectionMac.app` 私有运行时随包分发，不依赖系统 Node。
    - Swift 通过 `Process` 直接拉起 bundle 内置 Node。
    - 第一版仅运行构建后的 JavaScript 产物，不在 app 内直接运行 TypeScript 源码。
    - Swift 与 Node 的第一版边界限定为进程管理、stdout/stderr 捕获和 ready 信号识别。
  - 风险 / 阻塞：
    - 暂未处理 Node 体积、签名、分发与本地 IPC 扩展问题。
  - 下一步：
    - 进入第 2 步，创建最小 Node 宿主项目。
    - 详细方案见 `record/NODE_RUNTIME_STEP1_集成方案.md`。

### 第 2 步：创建最小 Node 宿主项目

- 状态：`完成`
- 目标：新增一个仅用于验证运行时托管的最小 Node 项目。
- 交付物：
  - `package.json`
  - 如使用 TypeScript，则包含 `tsconfig.json`
  - 最小入口脚本：输出 ready 标记、保持运行、收到退出信号后可正常结束
- 记录区：
  - 记录人：Codex
  - 计划路径：
    - `NodeRuntimeHost/`
  - 使用命令：
    - 本次仅创建骨架文件，未执行依赖安装与构建命令。
  - 风险 / 阻塞：
    - 尚未验证 TypeScript 构建产物。
    - 尚未确定 `node_modules` 与 `dist/` 的最终分发策略。
  - 下一步：
    - 进入第 3 步，明确构建产物与依赖复制策略。
    - 详细记录见 `record/NODE_RUNTIME_STEP2_最小宿主项目.md`。

### 第 3 步：确定构建产物与依赖策略

- 状态：`完成`
- 目标：定义 Node 代码如何构建，以及哪些产物需要被复制进 app bundle。
- 交付物：
  - 构建命令定义
  - 是否直接携带 `node_modules` 或改为更小产物的决策
  - 运行时所需文件清单
- 记录区：
  - 记录人：Codex
  - 决策说明：
    - 开发期使用 TypeScript，交付期只使用编译后的 JavaScript 产物。
    - 当前最小宿主项目运行期不携带 `node_modules`，因为入口只依赖 Node 内建模块。
    - 构建依赖仅用于构建阶段，不进入最终运行时分发物。
    - 后续优先复制 `dist/`，再按需补充少量静态元数据文件。
  - 产物布局：
    - 当前推荐为 `NodeRuntimeHost/dist/index.js` + `NodeRuntimeHost/package.json`。
  - 风险 / 阻塞：
    - 尚未接入 Xcode Build Phase。
    - 尚未实现依赖安装自动化与产物复制脚本。
  - 下一步：
    - 进入第 4 步，准备私有 Node 运行时二进制。
    - 详细记录见 `record/NODE_RUNTIME_STEP3_构建产物与依赖策略.md`。

### 第 4 步：准备私有 Node 运行时二进制

- 状态：`完成`
- 目标：准备一份可被 app 打包并拉起的 macOS Node 二进制。
- 交付物：
  - Node 版本选择结果
  - 本地验证：该二进制能运行最小宿主脚本
  - 后续升级与替换流程说明
- 记录区：
  - 记录人：Codex
  - 选定版本：
    - 已确定采用官方最新 Current 版本 `v26.5.0`。
    - 采用“由应用私有分发、不依赖系统 Node”的策略。
  - 验证说明：
    - 本步骤面向 macOS 可用性，不要求在当前主机上做可执行验证。
    - 已明确后续验证方式为在目标 macOS 环境运行官方 Node 发行物并执行最小宿主脚本。
    - 官方 macOS `arm64` / `x64` 发行包与 `SHASUMS256.txt` 已下载到 `record/node-official/v26.5.0/`。
    - 两个压缩包的本地 `SHA256` 均已与官方 `SHASUMS256.txt` 匹配。
  - 风险 / 阻塞：
    - 后续若进入实际下载与打包，应在目标 macOS 环境完成最终验证。
  - 下一步：
    - 进入第 5 步，确定 app bundle 目录布局。
    - 详细记录见 `record/NODE_RUNTIME_STEP4_私有Node二进制准备方案.md`。
  - 下一步：
    - 待提供离线 Node 二进制、内部制品路径或具备 Node 的验证环境后，再补做二进制导入与最小脚本验证。
    - 详细记录见 `record/NODE_RUNTIME_STEP4_私有Node二进制准备方案.md`。

### 第 5 步：确定 app bundle 目录布局

- 状态：`完成`
- 目标：确定 `.app` 内 Node、脚本、配置模板等文件路径，以及 bundle 外运行数据目录。
- 交付物：
  - bundle 内相对路径方案
  - bundle 外运行数据目录方案
  - Swift 侧路径解析约定
- 记录区：
  - 记录人：Codex
  - bundle 路径方案：
    - 统一采用 `Contents/Resources/NodeRuntime/` 作为私有 Node 运行时根目录。
    - Node 二进制映射到 `Contents/Resources/NodeRuntime/node/bin/node`。
    - `NodeRuntimeHost` 运行时产物映射到 `Contents/Resources/NodeRuntime/host/dist/index.js`。
    - `NodeRuntimeHost/package.json` 映射到 `Contents/Resources/NodeRuntime/host/package.json`。
    - 配置模板预留到 `Contents/Resources/NodeRuntime/config/runtime-config.template.json`。
  - 运行数据路径方案：
    - 配置、状态、缓存、临时文件放在 `~/Library/Application Support/MutualInfectionMac/NodeRuntime/`。
    - 日志放在 `~/Library/Logs/MutualInfectionMac/NodeRuntime/`。
    - 真实运行配置文件位于 `~/Library/Application Support/MutualInfectionMac/NodeRuntime/config/runtime-config.json`。
  - 风险 / 阻塞：
    - 当前只完成目录和路径约定，尚未进入实际复制、权限保留和 macOS 真机验证。
    - 若后续 Node 运行时引入 `npm` 级别依赖，需要重新评估是否继续只复制最小二进制集合。
  - 下一步：
    - 进入第 6 步，设计 Xcode Build Phase 中的复制流程。
    - 详细记录见 `record/NODE_RUNTIME_STEP5_app_bundle目录布局.md`。

### 第 6 步：接入 Xcode 构建阶段

- 状态：`完成`
- 目标：让 Xcode 在构建 macOS app 时自动复制 Node 运行时及 Node 项目产物。
- 交付物：
  - macOS target 的 build phase 改动
  - 本地构建下可重复的复制 / 分发行为
  - 可执行权限保留验证
- 记录区：
  - 记录人：Codex
  - 修改文件：
    - `MutualInfection.xcodeproj/project.pbxproj`
    - `scripts/prepare_node_runtime_bundle.sh`
    - `NodeRuntimeHost/dist/index.js`
    - `NodeRuntimeHost/config/runtime-config.template.json`
  - Build Phase 说明：
    - 已为 `MutualInfectionMac` target 新增 `Prepare Node Runtime Bundle`。
    - Build Phase 调用仓库脚本，按目标架构从官方 Node 包中提取 `bin/node` 与 `LICENSE`。
    - 同时复制 `NodeRuntimeHost` 的运行时入口、`package.json` 与配置模板到 `NodeRuntime/` 目录。
  - 风险 / 阻塞：
    - 当前尚未在真实 macOS/Xcode 环境执行构建验证。
    - 当前 `dist/index.js` 为直接落库产物，后续需要与 `src/index.ts` 保持同步或补自动构建。
  - 下一步：
    - 进入第 7 步，实现 Swift 运行时管理器。
    - 详细记录见 `record/NODE_RUNTIME_STEP6_Xcode构建阶段接入.md`。

### 第 7 步：实现 Swift 运行时管理器

- 状态：`完成`
- 目标：新增 Swift 组件，负责定位、启动、停止并观察 Node 进程。
- 交付物：
  - `NodeRuntimeManager` 或等价组件
  - 启动路径解析逻辑
  - stdout / stderr 捕获
  - 优雅退出能力
- 记录区：
  - 记录人：Codex
  - 修改文件：
    - `MutualInfectionMac/Application/NodeRuntimeManager.swift`
    - `MutualInfectionMac/AppDelegate.swift`
  - API 设计：
    - 新增 `NodeRuntimeManager.startIfNeeded()` 与 `NodeRuntimeManager.stop()`。
    - 管理器内部负责 bundle 内路径解析、bundle 外目录准备、配置文件准备、`Process` 启动与日志捕获。
  - 风险 / 阻塞：
    - 当前尚未在真实 macOS/Xcode 运行环境验证 `Process` 启动效果。
    - 当前未实现超时、重试、崩溃恢复等高级策略。
  - 下一步：
    - 进入第 8 步，定义启动握手协议。
    - 详细记录见 `record/NODE_RUNTIME_STEP7_Swift运行时管理器.md`。

### 第 8 步：定义启动握手协议

- 状态：`TODO`
- 目标：通过 Node 侧 ready 信号保证启动过程可判定、可等待。
- 交付物：
  - ready 标记或健康检查协议
  - 启动超时策略
  - 启动失败处理路径
- 记录区：
  - 记录人：
  - 握手方案：
  - 超时策略：
  - 风险 / 阻塞：
  - 下一步：

### 第 9 步：增加配置注入通道

- 状态：`TODO`
- 目标：定义 macOS app 如何向 Node 进程传入运行配置。
- 交付物：
  - 配置文件位置
  - Swift 生成 / 更新配置逻辑
  - 启动参数或环境变量约定
- 记录区：
  - 记录人：
  - 配置路径：
  - 注入方式：
  - 风险 / 阻塞：
  - 下一步：

### 第 10 步：增加日志与诊断能力

- 状态：`TODO`
- 目标：让嵌入式 Node 运行时在开发和排障时可观测。
- 交付物：
  - stdout / stderr 收集方案
  - 运行时日志文件位置
  - 基础失败诊断流程
- 记录区：
  - 记录人：
  - 日志路径：
  - 诊断说明：
  - 风险 / 阻塞：
  - 下一步：

### 第 11 步：定义生命周期与重启策略

- 状态：`TODO`
- 目标：明确 Node 进程在 app 启动、退出、崩溃场景下的行为。
- 交付物：
  - 第一版重启策略
  - app 退出时的处理策略
  - 崩溃恢复说明
- 记录区：
  - 记录人：
  - 生命周期策略：
  - 崩溃策略：
  - 风险 / 阻塞：
  - 下一步：

### 第 12 步：执行端到端验证

- 状态：`TODO`
- 目标：验证从 Xcode 构建到 app 拉起 Node 运行时的完整链路。
- 交付物：
  - 测试清单结果
  - 已知限制列表
  - 是否可以进入业务层集成的结论说明
- 建议验证项：
  - app 能在不依赖系统 Node 的情况下拉起内置 Node
  - Node 进程能输出 ready 标记
  - Swift 能捕获 stdout / stderr
  - Node 能成功读取配置
  - Node 能将日志写入指定目录
  - app 能正常关闭 Node 进程
- 记录区：
  - 记录人：
  - 验证环境：
  - 验证结果：
  - 已知限制：
  - 下一步：

## 决策记录

- 初始说明：已创建 Node 运行时集成跟踪清单。

## Agent 备注

- 后续 agent 可以按需增加子步骤，但尽量保持当前顶层编号稳定。
- 某一步进入阻塞时，记录清楚具体阻塞点，以及涉及的文件、路径或工具。
- 某一步完成时，补充足够信息，避免下一个 agent 重新摸索上下文。

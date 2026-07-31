# 第 6 步记录：接入 Xcode 构建阶段

## 结论

第 6 步当前状态标记为 `完成`。

本步骤已经完成以下内容：

- 为 `MutualInfectionMac` 设计并接入了一个专用 Build Phase。
- 新增仓库脚本 `scripts/prepare_node_runtime_bundle.sh`，由 Xcode 在构建时调用。
- 已将官方 Node 包、`NodeRuntimeHost` 运行时产物和配置模板纳入脚本输入。
- 已将脚本输出路径固定到 `Contents/Resources/NodeRuntime/` 对应的构建产物目录。

本步骤的目标是把复制逻辑正式纳入工程，而不是在当前主机上完成 macOS 真机构建验证。

## 本次改动

### 1. 新增打包脚本

新增：

```text
scripts/prepare_node_runtime_bundle.sh
```

职责：

- 根据当前目标架构选择官方 Node 压缩包
- 解压到 `DERIVED_FILE_DIR` 下的临时目录
- 从官方包中提取 `bin/node` 与 `LICENSE`
- 将 `NodeRuntimeHost` 的运行时文件复制到目标资源目录
- 将配置模板复制到目标资源目录

### 2. 新增最小运行时产物

新增：

```text
NodeRuntimeHost/dist/index.js
NodeRuntimeHost/config/runtime-config.template.json
```

说明：

- `dist/index.js` 作为当前最小宿主入口的运行时文件
- `runtime-config.template.json` 作为 bundle 内的只读配置模板

### 3. 工程文件接入

已修改：

```text
MutualInfection.xcodeproj/project.pbxproj
```

对 `MutualInfectionMac` target 新增一个 `PBXShellScriptBuildPhase`：

- 名称：`Prepare Node Runtime Bundle`
- 执行脚本：`"$PROJECT_DIR/scripts/prepare_node_runtime_bundle.sh"`

该 Build Phase 的输入包含：

- `record/node-official/v26.5.0/node-v26.5.0-darwin-arm64.tar.gz`
- `record/node-official/v26.5.0/node-v26.5.0-darwin-x64.tar.gz`
- `record/node-official/v26.5.0/SHASUMS256.txt`
- `NodeRuntimeHost/dist/index.js`
- `NodeRuntimeHost/package.json`
- `NodeRuntimeHost/config/runtime-config.template.json`
- `scripts/prepare_node_runtime_bundle.sh`

该 Build Phase 的输出包含：

- `$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/NodeRuntime/node/bin/node`
- `$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/NodeRuntime/host/dist/index.js`
- `$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/NodeRuntime/host/package.json`
- `$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/NodeRuntime/config/runtime-config.template.json`

## 当前 Build Phase 行为

### 架构选择规则

脚本基于 `CURRENT_ARCH` 或 `NATIVE_ARCH_ACTUAL` 判断当前 macOS 目标架构：

- `arm64` -> 选 `node-v26.5.0-darwin-arm64.tar.gz`
- `x86_64` -> 选 `node-v26.5.0-darwin-x64.tar.gz`

若架构不是以上两种，则直接报错退出。

### 目标输出目录

脚本将运行时内容输出到：

```text
$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/NodeRuntime/
```

生成后的结构与第 5 步约定保持一致。

## 当前未做的事情

本步骤刻意没有处理：

- 自动执行 TypeScript 编译
- 自动安装 `NodeRuntimeHost` 依赖
- macOS 真机构建验证
- 运行期 Swift 代码接入

这些内容分别属于后续验证或实现步骤。

## 当前风险

- 当前 `NodeRuntimeHost/dist/index.js` 是根据现有最小宿主脚本直接落的运行时文件，后续如修改 `src/index.ts`，需要同步维护或补自动构建。
- 当前未在 macOS/Xcode 环境实际执行 Build Phase，因此仍存在权限、`tar` 行为、架构变量差异等真实构建风险。
- 当前脚本默认按单架构产物处理，不覆盖同一 `.app` 中双架构 Node 同时分发的场景。

## 下一步建议

建议进入第 7 步，开始实现 Swift 运行时管理器；同时在后续可用的 macOS 构建环境中补一轮真实构建验证。

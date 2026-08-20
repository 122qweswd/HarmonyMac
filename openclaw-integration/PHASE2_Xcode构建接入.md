# 阶段 2 — 接入 Xcode Build Phase，组装进 .app

> 状态：✅ 已完成并继续增强
> 原执行日期：2026-08-04
> 最后同步：2026-08-20
> 当前结论：Xcode 已形成两个连续 Build Phase，先准备 OpenClaw 中间产物，再组装 NodeRuntime。

## 目标

让 Xcode 构建 `MutualInfectionMac` 时自动完成：

1. 从 `openclaw-source/` 生成或复用 `openclaw-bundle-output/`；
2. 解包私有 Node v22.16.0；
3. 将 Node、OpenClaw 与本机配置模板拷入 `.app/Contents/Resources/NodeRuntime/`；
4. 彻底停止使用历史心跳桩 host 作为运行入口。

## 当前构建链

```text
Sources
  → Prepare Openclaw Bundle（C0D3A003…，当前工作区新增）
      /bin/sh "${PROJECT_DIR}/scripts/prepare_openclaw_bundle.sh"
      输出：openclaw-bundle-output/openclaw.mjs、package.json、dist、node_modules…
  → Prepare Node Runtime Bundle（C0D3A002…）
      /bin/sh "${PROJECT_DIR}/scripts/prepare_node_runtime_bundle.sh"
      输出：.app/Contents/Resources/NodeRuntime/{node,openclaw,config}
  → Resources / Copy Files
```

`Prepare Openclaw Bundle` 的输入至少包括：

- `scripts/prepare_openclaw_bundle.sh`
- `openclaw-source/package.json`
- `openclaw-source/pnpm-lock.yaml`

输出声明：

- `openclaw-bundle-output/openclaw.mjs`
- `openclaw-bundle-output/package.json`

第二个 Phase 使用：

- `record/node-official/v22.16.0/`
- `openclaw-bundle-output/`
- `NodeRuntimeHost/config/openclaw.template.json`

## 修改文件

| 路径 | 当前作用 |
|---|---|
| `scripts/prepare_openclaw_bundle.sh` | 生成 prod/hoisted 中间产物；缺 `dist` 时先 install + build；打包 workspace 模板；产物存在时缓存跳过 |
| `scripts/prepare_node_runtime_bundle.sh` | 根据当前架构解包 Node 22.16；复制 OpenClaw 中间产物和配置模板 |
| `MutualInfection.xcodeproj/project.pbxproj` | 定义两个按顺序执行的 Build Phase；`Prepare Openclaw Bundle` 为当前未提交修改 |
| `NodeRuntimeHost/config/openclaw.template.json` | 本机敏感配置；包含模型 API key、gateway/A2A token、tunnel/registry、fileStorage 等；被 `.gitignore` 排除 |
| `.gitignore` | 排除 `openclaw-bundle-output/`、OpenClaw 构建物及本机敏感模板 |

## 当前产物布局

```text
鸿蒙星河互联.app/Contents/Resources/NodeRuntime/
├── node/
│   ├── bin/node
│   └── LICENSE
├── openclaw/
│   ├── openclaw.mjs
│   ├── package.json
│   ├── dist/
│   ├── node_modules/
│   ├── extensions/
│   ├── packages/
│   ├── ui/
│   └── docs/reference/templates/
└── config/
    └── openclaw.template.json
```

## 架构处理

`prepare_node_runtime_bundle.sh` 当前支持：

| `CURRENT_ARCH` | Node 包 |
|---|---|
| `arm64` | `node-v22.16.0-darwin-arm64.tar.gz` |
| `x86_64` | `node-v22.16.0-darwin-x64.tar.gz` |

> 最初文档以 Apple Silicon 为范围；当前脚本已有 x64 分支，但项目是否正式支持 Intel 仍需由 Xcode 构建设置和实际验证确认。

## 验证情况

历史阶段已完成手工模拟 Build Phase，验证 NodeRuntime 目录可组装、私有 Node 可执行、OpenClaw 可启动。此后用户已在完整 Xcode 环境运行 App，并继续完成 Node22、端口分离、模型调用、文件访问与手机双端联调，因此“本机只有 CLT、真实 Xcode 待验证”已不再是当前状态。

当前静态检查可使用：

```bash
sh -n scripts/prepare_openclaw_bundle.sh
sh -n scripts/prepare_node_runtime_bundle.sh

test -f NodeRuntimeHost/config/openclaw.template.json
test -f record/node-official/v22.16.0/node-v22.16.0-darwin-arm64.tar.gz
```

Xcode Report Navigator 中应看到：

```text
Prepare Openclaw Bundle
Prepare Node Runtime Bundle
Prepared NodeRuntime bundle at ... for arch arm64
```

## 风险与注意事项

1. **配置模板不会随 git clone 获取**：它被故意忽略以保护密钥；缺失时 NodeRuntime Phase 会失败。应建立脱敏样例和 Secret 注入流程。
2. **首次构建可能联网且耗时**：若 `dist/` 和中间产物都不存在，Phase 1 会执行 pnpm install/build。
3. **缓存可能过粗**：当前输出存在即跳过，OpenClaw 源更新后可能需要手动删除 `openclaw-bundle-output/`。
4. **Build Phase 新增尚未提交**：`project.pbxproj` 的 `C0D3A003…` 当前在工作区修改中。
5. **产物体积仍未裁剪**：需以最新源重新测量，历史 1.2–1.3G 仅供参考。

## 当前下一步

- 将新增 Build Phase、a2a 白名单与文档一起提交；
- 将模板敏感值改为构建时 Secret 注入；
- 为构建缓存增加源内容 hash；
- 在需要时验证 x86_64，或明确收敛为 arm64-only。

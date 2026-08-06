# 阶段 1 — 构造离线打包产物（arm64 / 生产依赖 / hoisted）

> 状态：✅ 完成（离线自包含产物已验证可跑；体积优化留待阶段 5）
> 日期：2026-08-04
> 执行人：Claude（与用户协作）

## 目标

从 `openclaw-custom` 产出一个**干净、扁平、可随包分发**的 openclaw 运行时子集：仅 macOS arm64、仅生产依赖、`node_modules` 扁平化（hoisted）。并用**私有 node** 验证该产物能离线自包含跑起 a2a-gateway，不依赖项目其余文件。

## 执行的操作（可复制）

```bash
# 产物构造脚本（本阶段新增并固化）：scripts/prepare_openclaw_bundle.sh
# 手动等价流程（已验证）：

STAGING=/tmp/openclaw-bundle
rm -rf "$STAGING" && mkdir -p "$STAGING"
cd openclaw-custom
# 1. 拷运行所需文件（排除 node_modules/src/test/docs）
cp package.json pnpm-workspace.yaml pnpm-lock.yaml openclaw.mjs "$STAGING/"
rsync -a --exclude='node_modules' dist/   "$STAGING/dist/"
rsync -a --exclude='node_modules' extensions/ "$STAGING/extensions/"
rsync -a --exclude='node_modules' ui/     "$STAGING/ui/"
rsync -a --exclude='node_modules' packages/ "$STAGING/packages/"

# 2. 写打包专用 .npmrc（扁平 + 仅 darwin/arm64）
cat > "$STAGING/.npmrc" <<'EOF'
node-linker=hoisted
supported-architectures.os[]=darwin
supported-architectures.cpu[]=arm64
EOF

# 3. 装生产依赖（扁平 + 仅 arm64 + 跳过原生编译）
cd "$STAGING"
CI=true pnpm install --prod --ignore-scripts --node-linker=hoisted --no-frozen-lockfile
# → Done in 4.6s（阶段 0 已填充 store 缓存，全 reused）

# 4. 验证：私有 arm64 node 离线自包含可跑
NODE=/tmp/node-arm64/node-v22.16.0-darwin-arm64/bin/node   # 从 record/node-official 解出
export OPENCLAW_HOME=/tmp/oc-bundle-test
export OPENCLAW_STATE_DIR=/tmp/oc-bundle-test/.openclaw
export OPENCLAW_CONFIG_PATH=/tmp/oc-bundle-test/.openclaw/openclaw.json   # 含 gateway.mode=local
"$NODE" openclaw.mjs --version                    # → OpenClaw 2026.3.13
"$NODE" openclaw.mjs gateway run --force --port 18801 &
curl -s http://127.0.0.1:18801/health             # → 200
```

## 修改的文件清单

| 路径 | 变更 | 说明 |
|------|------|------|
| `scripts/prepare_openclaw_bundle.sh` | **新增**（已 chmod +x） | 固化上述流程；阶段 2 由 `prepare_node_runtime_bundle.sh` 调用，把产物拷进 `.app` |
| `/tmp/openclaw-bundle/` | 临时产物（1.2G） | 阶段 1 验证用；**不进仓库**，阶段 2 用脚本重新生成到正式位置 |
| `/tmp/node-arm64/` | 私有 node（解压自 `record/node-official/v22.16.0`） | 验证用 |

## 验证结果

| 验证项 | 结果 | 证据 |
|--------|------|------|
| `pnpm install --prod --node-linker=hoisted` | ✅ | 4.6s，1342 包，`devDependencies: skipped` |
| hoisted 扁平结构 | ✅ | 顶层 663 包，chalk/express 直接可达；`.pnpm` 仅 388K 空壳（无重复） |
| 私有 node v22.16.0 + staging `--version` | ✅ | `OpenClaw 2026.3.13` |
| 离线自包含 gateway 启动 | ✅ | 日志 `a2a-gateway: HTTP listening on 18801` + `gRPC listening on 18802` |
| `/health` 200 | ✅ | 私有 node + staging 产物，不依赖 `openclaw-custom` 原目录 |
| `gateway.mode=local` 配置注入 | ✅ | config 写 `gateway.mode=local` 即无需 `--allow-unconfigured`（阶段 3 采纳） |

**阶段 1 判定目标达成**：私有 node + 产物离线自包含跑通 a2a-gateway。

## 体积数据（全量基线，阶段 5 裁剪依据）

产物总 **1.2G**（node_modules 1.1G + dist 68M + extensions/ui）。

**node_modules top 15**：

| 包 | 体积 | a2a-gateway 是否需要 | 阶段 5 处置 |
|----|------|----------------------|-------------|
| @lancedb | 96M | ❌（memory-lancedb 插件用） | 剔除 |
| koffi | 84M | ❌（FFI；含多平台 prebuilt） | 剔除 |
| @aws-sdk | 76M | ❌（bedrock provider） | 剔除 |
| @tloncorp | 60M | ❌（tlon 渠道） | 剔除 |
| @smithy | 41M | ❌（@aws-sdk 依赖） | 随 aws-sdk 剔除 |
| pdfjs-dist | 40M | ❌（PDF 解析） | 剔除 |
| @opentelemetry | 37M | ⚠️ 可选（遥测） | 评估 |
| date-fns | 36M | ⚠️（含全部 locale） | 精简 |
| node-llama-cpp | 33M | ❌（本地 LLM） | 剔除 |
| @mariozechner | 26M | ⚠️（pi-agent，openclaw 内部 agent 框架） | 谨慎评估 |
| @napi-rs | 25M | ❌（canvas 图像） | 剔除 |
| typescript | 23M | ✅ **peerDep，运行时编译 .ts 插件需要** | 保留（可换更轻 TS 运行时） |
| @rolldown | 17M | ⚠️（动态打包？） | 评估 |
| @line | 17M | ❌（line 渠道） | 剔除 |

粗估：剔除上述 ❌ 项后，node_modules 可从 1.1G 压到 **~300–400M** 量级（阶段 5 实测）。

## 遇到的问题与决策

### ① `.pnpm` 仍存在但仅 388K
- hoisted 模式下 `.pnpm` 没有完全消失，但只剩 388K 空壳（无实际包内容），1116M 全是扁平内容。**不影响运行，不是体积问题**。无需处理。

### ② 平台二进制不纯（koffi/node-llama-cpp 自带多平台）
- `supported-architectures` 只能过滤"独立平台可选包"（如 `@img/sharp-darwin-arm64`），过滤不了 `koffi` 这种**单包内含 linux/win32/darwin 全平台 prebuilt** 的（koffi/build 下有 linux_ia32、win32_x64 等）。
- **影响**：纯体积浪费（功能不影响，darwin-arm64 二进制在）。
- **决策**：阶段 1 不处理。阶段 5 手动删除非 darwin-arm64 的 prebuilt 目录，或换用更小的 FFI 方案。

### ③ typescript/@rolldown 出现在 prod 产物
- `pnpm why typescript` 显示是 **peer dependency**。openclaw 运行时用 tsx/jiti 编译 `extensions/*.ts` 插件（plugins list 显示 `stock:a2a-gateway/index.ts`），所以 typescript **运行时真需要**，保留合理。
- 阶段 5 可评估用更轻的 TS 运行时替代以减小体积，但不影响阶段 1。

### ④ `--prod` 未显著减小体积
- devDependencies 只占小头（oxlint/vitest/jscpd 等已 skip），体积大头是生产依赖本身（所有渠道插件 + aws-sdk + llama + pdfjs 等）。这是"先全量跑通"的预期代价，阶段 5 按上表裁剪。

## 下一步

进入阶段 2：把 `prepare_openclaw_bundle.sh` 的产物接入 Xcode Build Phase，拷进 `MutualInfectionMac.app/Contents/Resources/NodeRuntime/openclaw/`，并改造 config 模板为 `openclaw.template.json`。

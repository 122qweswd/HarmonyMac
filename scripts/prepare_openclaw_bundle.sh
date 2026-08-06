#!/bin/sh
# 构造 openclaw 离线自包含运行时产物（仅 macOS arm64 + 生产依赖 + hoisted 扁平 node_modules）。
#
# 产物结构（OUTPUT_DIR）：
#   openclaw.mjs / package.json / dist/ / node_modules/ / extensions/ / ui/ / packages/
# 该产物可用私有 node 直接拉起 `node openclaw.mjs gateway run ...`，不依赖项目其余文件。
#
# 用法：
#   prepare_openclaw_bundle.sh [OPENCLAW_SRC] [OUTPUT_DIR]
#   环境变量：PNPM（默认 pnpm）
#
# 阶段 1 产物。阶段 2 由 prepare_node_runtime_bundle.sh 把该产物拷进 .app 的 NodeRuntime/openclaw/。

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OPENCLAW_SRC="${1:-$REPO_ROOT/openclaw-custom}"
OUTPUT_DIR="${2:-$REPO_ROOT/openclaw-bundle-output}"
PNPM="${PNPM:-pnpm}"

if [ ! -f "$OPENCLAW_SRC/openclaw.mjs" ]; then
  echo "error: openclaw.mjs not found in $OPENCLAW_SRC" >&2
  exit 1
fi

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

echo "==> 源: $OPENCLAW_SRC"
echo "==> 产物输出: $OUTPUT_DIR"

# 缓存：产物已存在则跳过昂贵的 pnpm install（Xcode 每次构建不重跑）。
# 删除 OUTPUT_DIR 可强制重建。
if [ -f "$OUTPUT_DIR/openclaw.mjs" ] && [ -d "$OUTPUT_DIR/node_modules" ]; then
  echo "==> 产物已存在，跳过 install（删除 $OUTPUT_DIR 可强制重建）"
  du -sh "$OUTPUT_DIR"
  exit 0
fi

# 1. 拷运行所需文件到 staging（排除 node_modules / src / test / docs）
echo "==> 拷贝源码与构建产物到 staging"
(
  cd "$OPENCLAW_SRC"
  cp package.json pnpm-workspace.yaml pnpm-lock.yaml openclaw.mjs "$STAGING/"
)
rsync -a --exclude='node_modules' "$OPENCLAW_SRC/dist/" "$STAGING/dist/"
rsync -a --exclude='node_modules' "$OPENCLAW_SRC/extensions/" "$STAGING/extensions/"
[ -d "$OPENCLAW_SRC/ui" ] && rsync -a --exclude='node_modules' "$OPENCLAW_SRC/ui/" "$STAGING/ui/"
[ -d "$OPENCLAW_SRC/packages" ] && rsync -a --exclude='node_modules' "$OPENCLAW_SRC/packages/" "$STAGING/packages/"

# 2. 写打包专用 .npmrc：扁平 + 仅 darwin/arm64
cat > "$STAGING/.npmrc" <<'EOF'
# 打包专用：扁平 node_modules（避免符号链接在 .app bundle 出问题）
node-linker=hoisted
# 仅保留 macOS arm64 平台可选包（注意：koffi/node-llama-cpp 等单包内自带多平台
# prebuilt，supported-architectures 过滤不了它们，需阶段 5 手动清理）
supported-architectures.os[]=darwin
supported-architectures.cpu[]=arm64
EOF

# 3. 装生产依赖（扁平 + 仅 arm64 + 跳过原生编译）
echo "==> pnpm install --prod --node-linker=hoisted（仅 darwin/arm64 生产依赖）"
(
  cd "$STAGING"
  CI=true "$PNPM" install --prod --ignore-scripts --node-linker=hoisted --no-frozen-lockfile
)

# 4. 组装产物到 OUTPUT_DIR（只保留运行所需）
echo "==> 组装产物"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
cp "$STAGING/openclaw.mjs" "$STAGING/package.json" "$OUTPUT_DIR/"
cp -R "$STAGING/dist" "$OUTPUT_DIR/dist"
cp -R "$STAGING/node_modules" "$OUTPUT_DIR/node_modules"
cp -R "$STAGING/extensions" "$OUTPUT_DIR/extensions"
[ -d "$STAGING/ui" ] && cp -R "$STAGING/ui" "$OUTPUT_DIR/ui"
[ -d "$STAGING/packages" ] && cp -R "$STAGING/packages" "$OUTPUT_DIR/packages"

# 5. 体积报告
echo "==> 完成"
echo "产物体积："
du -sh "$OUTPUT_DIR"
echo "产物路径：$OUTPUT_DIR"

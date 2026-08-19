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
OPENCLAW_SRC="${1:-$REPO_ROOT/openclaw-source}"
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

# 0. 确保 dist/ 存在：openclaw-source 是纯源码（dist/node_modules 被其 .gitignore 忽略），
#    首次或清理后需在源目录原地跑完整 install + build 生成 dist/（耗时、需联网）。
#    用 --ignore-scripts：与下方 staging install 一致，且避免 openclaw-source 的 prepare 脚本
#    改动外层仓库的 core.hooksPath。dist/node_modules 落在 openclaw-source/ 下作为缓存。
if [ ! -d "$OPENCLAW_SRC/dist" ]; then
  if ! command -v "$PNPM" >/dev/null 2>&1; then
    echo "error: 找不到 $PNPM，无法构建 dist。请先 'npm i -g pnpm'，或在装好 pnpm 的终端手动跑一次本脚本。" >&2
    exit 1
  fi
  echo "==> dist/ 缺失，在 $OPENCLAW_SRC 执行 $PNPM install + build（首次较慢，需联网）"
  ( cd "$OPENCLAW_SRC" && CI=true "$PNPM" install --ignore-scripts && "$PNPM" run build )
  if [ ! -d "$OPENCLAW_SRC/dist" ]; then
    echo "error: build 完成后仍未生成 $OPENCLAW_SRC/dist，请检查 openclaw-source 构建。" >&2
    exit 1
  fi
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
# agent workspace bootstrap 模板（dispatch 时需要 docs/reference/templates/AGENTS.md 等，否则 workspace 创建失败）
[ -d "$OPENCLAW_SRC/docs/reference/templates" ] && { mkdir -p "$STAGING/docs/reference"; rsync -a "$OPENCLAW_SRC/docs/reference/templates/" "$STAGING/docs/reference/templates/"; }
# 源只提供 *.dev.md（dev gateway 专用）；生产 bootstrap（ensureBootstrapFiles）需非 dev 版，
# 从 .dev.md 去 frontmatter 生成缺失的 IDENTITY.md / USER.md
for _f in IDENTITY USER; do
  if [ ! -f "$STAGING/docs/reference/templates/$_f.md" ] && [ -f "$STAGING/docs/reference/templates/$_f.dev.md" ]; then
    awk 'BEGIN{s=0} /^---[[:space:]]*$/{s++; next} s>=2{print}' "$STAGING/docs/reference/templates/$_f.dev.md" > "$STAGING/docs/reference/templates/$_f.md"
  fi
done

# 2. 写打包专用 .npmrc：扁平 + 仅 darwin/arm64
cat > "$STAGING/.npmrc" <<'EOF'
# 打包专用：扁平 node_modules（避免符号链接在 .app bundle 出问题）
node-linker=hoisted
# 仅保留 macOS arm64 平台可选包（注意：koffi/node-llama-cpp 等单包内自带多平台
# prebuilt，supported-architectures 过滤不了它们，需阶段 5 手动清理）
supportedArchitectures:
  cpu:
    - x64
    - arm64
  os:
    - darwin
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
[ -d "$STAGING/docs/reference/templates" ] && { mkdir -p "$OUTPUT_DIR/docs/reference"; cp -R "$STAGING/docs/reference/templates" "$OUTPUT_DIR/docs/reference/"; }

# 5. 体积报告
echo "==> 完成"
echo "产物体积："
du -sh "$OUTPUT_DIR"
echo "产物路径：$OUTPUT_DIR"

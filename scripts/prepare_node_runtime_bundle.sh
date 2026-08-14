#!/bin/sh
set -eu

# 为 MutualInfectionMac.app 组装 NodeRuntime bundle：
#   - 私有 Node 二进制（arm64，来自 record/node-official）
#   - openclaw 运行时产物（来自 openclaw-bundle-output，由 prepare_openclaw_bundle.sh 预生成）
#   - openclaw 配置模板（openclaw.template.json，阶段3 由 Swift 读取并实例化）
#
# 注意：心跳桩 NodeRuntimeHost/dist/index.js、package.json 已退役（阶段2），不再拷贝。

PROJECT_ROOT="${PROJECT_DIR}"
TARGET_RESOURCES_DIR="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
RUNTIME_ROOT="${TARGET_RESOURCES_DIR}/NodeRuntime"

# 私有 Node 版本。切版本只改这一处即可（对应 record/node-official/v<版本>/ 目录）。
# 选用 22.16 LTS：openclaw engines>=22.16.0；Node 26 会触发 IncomingMessage.signal 只读报错。
NODE_VERSION="22.16.0"
OFFICIAL_NODE_DIR="${PROJECT_ROOT}/record/node-official/v${NODE_VERSION}"
STAGING_ROOT="${DERIVED_FILE_DIR}/NodeRuntimeStaging"
OPENCLAW_BUNDLE_DIR="${OPENCLAW_BUNDLE_DIR:-${PROJECT_ROOT}/openclaw-bundle-output}"
OPENCLAW_CONFIG_TEMPLATE_PATH="${PROJECT_ROOT}/NodeRuntimeHost/config/openclaw.template.json"

CURRENT_ARCH_NAME="${CURRENT_ARCH:-}"
case "${CURRENT_ARCH_NAME}" in
  ""|undefined_arch)
    CURRENT_ARCH_NAME="${NATIVE_ARCH_ACTUAL:-}"
    ;;
esac

case "${CURRENT_ARCH_NAME}" in
  ""|undefined_arch)
    CURRENT_ARCH_NAME="${ARCHS:-}"
    ;;
esac

case "${CURRENT_ARCH_NAME}" in
  ""|undefined_arch)
    CURRENT_ARCH_NAME="$(uname -m)"
    ;;
esac

case "${CURRENT_ARCH_NAME}" in
  arm64)
    NODE_ARCHIVE_NAME="node-v${NODE_VERSION}-darwin-arm64.tar.gz"
    NODE_EXTRACTED_DIR="node-v${NODE_VERSION}-darwin-arm64"
    ;;
  x86_64)
    NODE_ARCHIVE_NAME="node-v${NODE_VERSION}-darwin-x64.tar.gz"
    NODE_EXTRACTED_DIR="node-v${NODE_VERSION}-darwin-x64"
    ;;
  *)
    echo "error: unsupported macOS arch '${CURRENT_ARCH_NAME}'. Expected 'arm64' or 'x86_64'." >&2
    exit 1
    ;;
esac

NODE_ARCHIVE_PATH="${OFFICIAL_NODE_DIR}/${NODE_ARCHIVE_NAME}"
NODE_LICENSE_PATH="${STAGING_ROOT}/${NODE_EXTRACTED_DIR}/LICENSE"
NODE_BINARY_PATH="${STAGING_ROOT}/${NODE_EXTRACTED_DIR}/bin/node"

if [ ! -f "${NODE_ARCHIVE_PATH}" ]; then
  echo "error: missing official Node archive: ${NODE_ARCHIVE_PATH}" >&2
  exit 1
fi

if [ ! -d "${OPENCLAW_BUNDLE_DIR}" ]; then
  echo "error: openclaw 产物不存在: ${OPENCLAW_BUNDLE_DIR}" >&2
  echo "hint: 先在仓库根执行 scripts/prepare_openclaw_bundle.sh 生成产物" >&2
  exit 1
fi

if [ ! -f "${OPENCLAW_CONFIG_TEMPLATE_PATH}" ]; then
  echo "error: openclaw 配置模板缺失: ${OPENCLAW_CONFIG_TEMPLATE_PATH}" >&2
  exit 1
fi

rm -rf "${STAGING_ROOT}" "${RUNTIME_ROOT}"
mkdir -p "${STAGING_ROOT}" \
  "${RUNTIME_ROOT}/node/bin" \
  "${RUNTIME_ROOT}/config"

tar -xzf "${NODE_ARCHIVE_PATH}" -C "${STAGING_ROOT}"

if [ ! -f "${NODE_BINARY_PATH}" ]; then
  echo "error: extracted Node binary not found: ${NODE_BINARY_PATH}" >&2
  exit 1
fi

cp "${NODE_BINARY_PATH}" "${RUNTIME_ROOT}/node/bin/node"
chmod +x "${RUNTIME_ROOT}/node/bin/node"

if [ -f "${NODE_LICENSE_PATH}" ]; then
  cp "${NODE_LICENSE_PATH}" "${RUNTIME_ROOT}/node/LICENSE"
fi

# openclaw 运行时产物（dist + 扁平 node_modules + extensions 等）
rm -rf "${RUNTIME_ROOT}/openclaw"
cp -R "${OPENCLAW_BUNDLE_DIR}" "${RUNTIME_ROOT}/openclaw"
echo "已拷贝 openclaw 产物: $(du -sh "${OPENCLAW_BUNDLE_DIR}" 2>/dev/null | cut -f1)"

# openclaw 配置模板（阶段3 Swift 实例化为 openclaw.json）
cp "${OPENCLAW_CONFIG_TEMPLATE_PATH}" "${RUNTIME_ROOT}/config/openclaw.template.json"

echo "Prepared NodeRuntime bundle at ${RUNTIME_ROOT} for arch ${CURRENT_ARCH_NAME}"

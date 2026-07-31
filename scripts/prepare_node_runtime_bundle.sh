#!/bin/sh
set -eu

PROJECT_ROOT="${PROJECT_DIR}"
TARGET_RESOURCES_DIR="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
RUNTIME_ROOT="${TARGET_RESOURCES_DIR}/NodeRuntime"
OFFICIAL_NODE_DIR="${PROJECT_ROOT}/record/node-official/v26.5.0"
HOST_ROOT="${PROJECT_ROOT}/NodeRuntimeHost"
STAGING_ROOT="${DERIVED_FILE_DIR}/NodeRuntimeStaging"

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
    NODE_ARCHIVE_NAME="node-v26.5.0-darwin-arm64.tar.gz"
    NODE_EXTRACTED_DIR="node-v26.5.0-darwin-arm64"
    ;;
  x86_64)
    NODE_ARCHIVE_NAME="node-v26.5.0-darwin-x64.tar.gz"
    NODE_EXTRACTED_DIR="node-v26.5.0-darwin-x64"
    ;;
  *)
    echo "error: unsupported macOS arch '${CURRENT_ARCH_NAME}'. Expected 'arm64' or 'x86_64'." >&2
    exit 1
    ;;
esac

NODE_ARCHIVE_PATH="${OFFICIAL_NODE_DIR}/${NODE_ARCHIVE_NAME}"
NODE_LICENSE_PATH="${STAGING_ROOT}/${NODE_EXTRACTED_DIR}/LICENSE"
NODE_BINARY_PATH="${STAGING_ROOT}/${NODE_EXTRACTED_DIR}/bin/node"
HOST_ENTRY_PATH="${HOST_ROOT}/dist/index.js"
HOST_PACKAGE_PATH="${HOST_ROOT}/package.json"
HOST_CONFIG_TEMPLATE_PATH="${HOST_ROOT}/config/runtime-config.template.json"

if [ ! -f "${NODE_ARCHIVE_PATH}" ]; then
  echo "error: missing official Node archive: ${NODE_ARCHIVE_PATH}" >&2
  exit 1
fi

if [ ! -f "${HOST_ENTRY_PATH}" ]; then
  echo "error: missing NodeRuntimeHost entry: ${HOST_ENTRY_PATH}" >&2
  echo "hint: ensure NodeRuntimeHost/dist/index.js is present before building MutualInfectionMac." >&2
  exit 1
fi

if [ ! -f "${HOST_PACKAGE_PATH}" ]; then
  echo "error: missing NodeRuntimeHost package metadata: ${HOST_PACKAGE_PATH}" >&2
  exit 1
fi

if [ ! -f "${HOST_CONFIG_TEMPLATE_PATH}" ]; then
  echo "error: missing runtime config template: ${HOST_CONFIG_TEMPLATE_PATH}" >&2
  exit 1
fi

rm -rf "${STAGING_ROOT}" "${RUNTIME_ROOT}"
mkdir -p "${STAGING_ROOT}" \
  "${RUNTIME_ROOT}/node/bin" \
  "${RUNTIME_ROOT}/host/dist" \
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

cp "${HOST_ENTRY_PATH}" "${RUNTIME_ROOT}/host/dist/index.js"
cp "${HOST_PACKAGE_PATH}" "${RUNTIME_ROOT}/host/package.json"
cp "${HOST_CONFIG_TEMPLATE_PATH}" "${RUNTIME_ROOT}/config/runtime-config.template.json"

echo "Prepared NodeRuntime bundle at ${RUNTIME_ROOT} for arch ${CURRENT_ARCH_NAME}"

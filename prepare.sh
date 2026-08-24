#!/usr/bin/env bash

set -e

# ============================================================
# llama-cpp-fnnas dependency prepare script
#
# LLAMA_CPP_VER 由 GitHub Actions build.yml 提供
# 不再在这里写死 llama.cpp 版本
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# ============================================================
# Check llama.cpp version
# ============================================================

if [ -z "${LLAMA_CPP_VER:-}" ]; then
    echo "============================================================"
    echo "ERROR: LLAMA_CPP_VER is not set."
    echo ""
    echo "Please provide LLAMA_CPP_VER from GitHub Actions."
    echo ""
    echo "Example:"
    echo "  LLAMA_CPP_VER=b10612 ./prepare.sh"
    echo "============================================================"
    exit 1
fi

echo "============================================================"
echo "Preparing llama.cpp dependencies"
echo "llama.cpp version: ${LLAMA_CPP_VER}"
echo "============================================================"

# ============================================================
# fnpack version
# ============================================================

FNPACK_VER="${FNPACK_VER:-1.2.3}"

echo ""
echo "fnpack version: ${FNPACK_VER}"

# ============================================================
# Directories
# ============================================================

mkdir -p app/bin/x64
mkdir -p app/bin/arm64
mkdir -p app/webui

# ============================================================
# llama.cpp release URL
# ============================================================

RELEASE_URL="https://github.com/ggml-org/llama.cpp/releases/download/${LLAMA_CPP_VER}"

echo ""
echo "llama.cpp release URL:"
echo "${RELEASE_URL}"

# ============================================================
# Temporary directory
# ============================================================

TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "${TMP_DIR}"
}

trap cleanup EXIT

# ============================================================
# Download helper
# ============================================================

download_file() {
    local url="$1"
    local output="$2"

    echo ""
    echo "------------------------------------------------------------"
    echo "Downloading:"
    echo "${url}"
    echo "------------------------------------------------------------"

    curl \
        --fail \
        --location \
        --retry 3 \
        --retry-delay 3 \
        --connect-timeout 30 \
        --max-time 1800 \
        -o "${output}" \
        "${url}"
}

# ============================================================
# Download fnpack
#
# 保持原项目 fnpack 下载逻辑。
# 如果你的原 prepare.sh 使用的 fnpack URL 不同，
# 只需要保留原来的 URL 即可。
# ============================================================

FNPACK_URL="https://github.com/MasterRoc/fnpack/releases/download/v${FNPACK_VER}/fnpack"

echo ""
echo "Downloading fnpack..."
echo "${FNPACK_URL}"

download_file \
    "${FNPACK_URL}" \
    "${TMP_DIR}/fnpack"

chmod +x "${TMP_DIR}/fnpack"

cp "${TMP_DIR}/fnpack" ./fnpack

# ============================================================
# x86_64 Vulkan
# ============================================================

X64_ARCHIVE="llama-${LLAMA_CPP_VER}-bin-ubuntu-vulkan-x64.tar.gz"

download_file \
    "${RELEASE_URL}/${X64_ARCHIVE}" \
    "${TMP_DIR}/${X64_ARCHIVE}"

echo ""
echo "Extracting x86_64 Vulkan..."

rm -rf "${TMP_DIR}/x64"
mkdir -p "${TMP_DIR}/x64"

tar -xzf \
    "${TMP_DIR}/${X64_ARCHIVE}" \
    -C "${TMP_DIR}/x64"

# ============================================================
# ARM64 Vulkan
# ============================================================

ARM64_ARCHIVE="llama-${LLAMA_CPP_VER}-bin-ubuntu-vulkan-arm64.tar.gz"

download_file \
    "${RELEASE_URL}/${ARM64_ARCHIVE}" \
    "${TMP_DIR}/${ARM64_ARCHIVE}"

echo ""
echo "Extracting ARM64 Vulkan..."

rm -rf "${TMP_DIR}/arm64"
mkdir -p "${TMP_DIR}/arm64"

tar -xzf \
    "${TMP_DIR}/${ARM64_ARCHIVE}" \
    -C "${TMP_DIR}/arm64"

# ============================================================
# Copy x86_64 binaries
# ============================================================

echo ""
echo "Installing x86_64 binaries..."

find "${TMP_DIR}/x64" -type f -name "llama-server" -exec cp {} ./app/bin/x64/ \;

find "${TMP_DIR}/x64" -type f -name "libggml-vulkan.so*" -exec cp {} ./app/bin/x64/ \;

# ============================================================
# Copy ARM64 binaries
# ============================================================

echo ""
echo "Installing ARM64 binaries..."

find "${TMP_DIR}/arm64" -type f -name "llama-server" -exec cp {} ./app/bin/arm64/ \;

find "${TMP_DIR}/arm64" -type f -name "libggml-vulkan.so*" -exec cp {} ./app/bin/arm64/ \;

# ============================================================
# WebUI
# ============================================================

UI_ARCHIVE="llama-${LLAMA_CPP_VER}-ui.tar.gz"

download_file \
    "${RELEASE_URL}/${UI_ARCHIVE}" \
    "${TMP_DIR}/${UI_ARCHIVE}"

echo ""
echo "Extracting WebUI..."

rm -rf "${TMP_DIR}/webui"
mkdir -p "${TMP_DIR}/webui"

tar -xzf \
    "${TMP_DIR}/${UI_ARCHIVE}" \
    -C "${TMP_DIR}/webui"

# ============================================================
# Install WebUI
# ============================================================

echo ""
echo "Installing WebUI..."

find "${TMP_DIR}/webui" -mindepth 1 -maxdepth 1 -exec cp -a {} ./app/webui/ \;

# ============================================================
# Verify
# ============================================================

echo ""
echo "============================================================"
echo "Verifying llama.cpp installation"
echo "============================================================"

echo ""
echo "x86_64:"
ls -lah ./app/bin/x64/

echo ""
echo "ARM64:"
ls -lah ./app/bin/arm64/

echo ""
echo "WebUI:"
ls -lah ./app/webui/ | head -30

echo ""

if [ ! -f "./app/bin/x64/llama-server" ]; then
    echo "ERROR: x86_64 llama-server not found!"
    exit 1
fi

if [ ! -f "./app/bin/arm64/llama-server" ]; then
    echo "ERROR: ARM64 llama-server not found!"
    exit 1
fi

if ! find ./app/bin/x64 -type f -name "libggml-vulkan.so*" | grep -q .; then
    echo "ERROR: x86_64 Vulkan library not found!"
    exit 1
fi

if ! find ./app/bin/arm64 -type f -name "libggml-vulkan.so*" | grep -q .; then
    echo "ERROR: ARM64 Vulkan library not found!"
    exit 1
fi

if [ ! -f "./app/webui/index.html" ]; then
    echo "ERROR: WebUI index.html not found!"
    exit 1
fi

if [ ! -x "./fnpack" ]; then
    echo "ERROR: fnpack not found or not executable!"
    exit 1
fi

echo ""
echo "============================================================"
echo "Preparation completed successfully!"
echo ""
echo "llama.cpp version: ${LLAMA_CPP_VER}"
echo "fnpack version:    ${FNPACK_VER}"
echo ""
echo "x86_64 llama-server: OK"
echo "x86_64 Vulkan:       OK"
echo "ARM64 llama-server:  OK"
echo "ARM64 Vulkan:        OK"
echo "WebUI:               OK"
echo "fnpack:              OK"
echo "============================================================"

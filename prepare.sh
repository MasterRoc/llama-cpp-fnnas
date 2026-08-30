bash
#!/bin/bash

# ============================================================
# llama.cpp for fnOS - Prepare Script
#
# 自动下载：
#   1. fnpack
#   2. llama.cpp x86_64 Vulkan
#   3. llama.cpp ARM64 Vulkan
#   4. llama.cpp WebUI
#
# LLAMA_CPP_VER 由 GitHub Actions 提供：
#   b10694
#   b10695
#   b10696
# ============================================================

set -euo pipefail


# ============================================================
# 基础目录
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

APP_DIR="${SCRIPT_DIR}/app"

BIN_DIR="${APP_DIR}/bin"

WEBUI_DIR="${APP_DIR}/webui"

TMP_DIR="${SCRIPT_DIR}/.prepare-tmp"


# ============================================================
# 版本
# ============================================================

if [ -z "${LLAMA_CPP_VER:-}" ]; then

    echo "ERROR: LLAMA_CPP_VER is not set."

    echo "Example:"
    echo "  LLAMA_CPP_VER=b10694 ./prepare.sh"

    exit 1

fi


FNPACK_VER="${FNPACK_VER:-1.2.3}"


# ============================================================
# 检查 llama.cpp 版本
# ============================================================

if ! echo "${LLAMA_CPP_VER}" | grep -Eq '^b[0-9]+$'; then

    echo ""
    echo "ERROR: Invalid llama.cpp version:"
    echo "${LLAMA_CPP_VER}"
    echo ""
    echo "Expected format: bXXXXX"
    echo ""

    exit 1

fi


# ============================================================
# URL
# ============================================================

RELEASE_URL="https://github.com/ggml-org/llama.cpp/releases/download/${LLAMA_CPP_VER}"


# ============================================================
# 创建临时目录
# ============================================================

rm -rf "${TMP_DIR}"

mkdir -p "${TMP_DIR}"


# ============================================================
# 清理
# ============================================================

cleanup() {

    rm -rf "${TMP_DIR}"

}

trap cleanup EXIT


# ============================================================
# 下载函数
# ============================================================

download_file() {

    local url="$1"

    local output="$2"

    echo ""
    echo "Downloading:"
    echo "${url}"
    echo ""

    curl \
        -fL \
        --retry 5 \
        --retry-delay 2 \
        --retry-connrefused \
        --connect-timeout 30 \
        --max-time 1800 \
        -o "${output}" \
        "${url}"

}


# ============================================================
# 开始
# ============================================================

echo ""
echo "============================================================"
echo " llama.cpp for fnOS"
echo " Prepare dependencies"
echo "============================================================"
echo ""

echo "llama.cpp version : ${LLAMA_CPP_VER}"
echo "fnpack version    : ${FNPACK_VER}"

echo ""

echo "Release URL:"
echo "${RELEASE_URL}"

echo ""


# ============================================================
# 1. fnpack
# ============================================================

echo "============================================================"
echo "[1/3] fnpack"
echo "============================================================"
echo ""


FNPACK_PATH="${SCRIPT_DIR}/fnpack"


if [ -f "${FNPACK_PATH}" ]; then

    echo "fnpack already exists."
    echo ""

else

    echo "Downloading fnpack..."
    echo ""

    case "$(uname -s)" in

        Linux)

            ARCH="$(uname -m)"

            case "${ARCH}" in

                x86_64)

                    FNPACK_BIN="fnpack-${FNPACK_VER}-linux-amd64"

                    ;;

                aarch64)

                    FNPACK_BIN="fnpack-${FNPACK_VER}-linux-arm64"

                    ;;

                *)

                    echo "ERROR: Unsupported Linux architecture: ${ARCH}"

                    exit 1

                    ;;

            esac


            download_file \
                "https://static2.fnnas.com/fnpack/${FNPACK_BIN}" \
                "${FNPACK_PATH}"


            chmod +x "${FNPACK_PATH}"

            ;;


        MINGW*|MSYS*|CYGWIN*)

            download_file \
                "https://static2.fnnas.com/fnpack/fnpack-${FNPACK_VER}-windows-amd64" \
                "${SCRIPT_DIR}/fnpack.exe"

            ;;


        *)

            echo "ERROR: Unsupported operating system:"
            uname -s

            exit 1

            ;;

    esac

fi


if [ -x "${FNPACK_PATH}" ]; then

    echo ""
    echo "fnpack version:"
    "${FNPACK_PATH}" --version || true

fi


# ============================================================
# 2. llama.cpp Vulkan
# ============================================================

echo ""
echo "============================================================"
echo "[2/3] llama.cpp Vulkan binaries"
echo "============================================================"
echo ""


# ------------------------------------------------------------
# 删除旧版本
# ------------------------------------------------------------

echo "Removing old llama.cpp binaries..."

rm -rf "${BIN_DIR}/x64"

rm -rf "${BIN_DIR}/arm64"


mkdir -p "${BIN_DIR}/x64"

mkdir -p "${BIN_DIR}/arm64"


# ============================================================
# x86_64
# ============================================================

X64_ASSET="llama-${LLAMA_CPP_VER}-bin-ubuntu-vulkan-x64.tar.gz"

X64_URL="${RELEASE_URL}/${X64_ASSET}"

X64_TMP="${TMP_DIR}/${X64_ASSET}"


echo ""
echo "------------------------------------------------------------"
echo "x86_64 Vulkan"
echo "------------------------------------------------------------"
echo ""

echo "Version:"
echo "${LLAMA_CPP_VER}"

echo ""

echo "Asset:"
echo "${X64_ASSET}"

echo ""


download_file \
    "${X64_URL}" \
    "${X64_TMP}"


echo ""

echo "Extracting x86_64..."

tar \
    -xzf "${X64_TMP}" \
    --strip-components=1 \
    -C "${BIN_DIR}/x64"


echo ""

echo "x86_64 files:"

find "${BIN_DIR}/x64" \
    -type f \
    -print \
    | sort


# ------------------------------------------------------------
# x86_64 检查
# ------------------------------------------------------------

if [ ! -f "${BIN_DIR}/x64/llama-server" ]; then

    echo ""
    echo "ERROR: x86_64 llama-server not found."

    exit 1

fi


if [ ! -f "${BIN_DIR}/x64/libggml-vulkan.so" ]; then

    echo ""
    echo "ERROR: x86_64 libggml-vulkan.so not found."

    exit 1

fi


chmod +x "${BIN_DIR}/x64/llama-server"


echo ""
echo "x86_64 Vulkan: OK"


# ============================================================
# ARM64
# ============================================================

ARM64_ASSET="llama-${LLAMA_CPP_VER}-bin-ubuntu-vulkan-arm64.tar.gz"

ARM64_URL="${RELEASE_URL}/${ARM64_ASSET}"

ARM64_TMP="${TMP_DIR}/${ARM64_ASSET}"


echo ""
echo "------------------------------------------------------------"
echo "ARM64 Vulkan"
echo "------------------------------------------------------------"
echo ""

echo "Version:"
echo "${LLAMA_CPP_VER}"

echo ""

echo "Asset:"
echo "${ARM64_ASSET}"

echo ""


download_file \
    "${ARM64_URL}" \
    "${ARM64_TMP}"


echo ""

echo "Extracting ARM64..."

tar \
    -xzf "${ARM64_TMP}" \
    --strip-components=1 \
    -C "${BIN_DIR}/arm64"


echo ""

echo "ARM64 files:"

find "${BIN_DIR}/arm64" \
    -type f \
    -print \
    | sort


# ------------------------------------------------------------
# ARM64 检查
# ------------------------------------------------------------

if [ ! -f "${BIN_DIR}/arm64/llama-server" ]; then

    echo ""
    echo "ERROR: ARM64 llama-server not found."

    exit 1

fi


if [ ! -f "${BIN_DIR}/arm64/libggml-vulkan.so" ]; then

    echo ""
    echo "ERROR: ARM64 libggml-vulkan.so not found."

    exit 1

fi


chmod +x "${BIN_DIR}/arm64/llama-server"


echo ""
echo "ARM64 Vulkan: OK"


# ============================================================
# 3. WebUI
# ============================================================

echo ""
echo "============================================================"
echo "[3/3] llama.cpp WebUI"
echo "============================================================"
echo ""


WEBUI_ASSET="llama-${LLAMA_CPP_VER}-ui.tar.gz"

WEBUI_URL="${RELEASE_URL}/${WEBUI_ASSET}"

WEBUI_TMP="${TMP_DIR}/${WEBUI_ASSET}"


# ------------------------------------------------------------
# 删除旧 WebUI
# ------------------------------------------------------------

echo "Removing old WebUI..."

rm -rf "${WEBUI_DIR}"

mkdir -p "${WEBUI_DIR}"


echo ""
echo "Downloading WebUI..."

echo ""

echo "Version:"
echo "${LLAMA_CPP_VER}"

echo ""

echo "Asset:"
echo "${WEBUI_ASSET}"

echo ""


download_file \
    "${WEBUI_URL}" \
    "${WEBUI_TMP}"


echo ""

echo "Extracting WebUI..."

tar \
    -xzf "${WEBUI_TMP}" \
    --strip-components=1 \
    -C "${WEBUI_DIR}"


# ------------------------------------------------------------
# WebUI 检查
# ------------------------------------------------------------

echo ""
echo "WebUI files:"

find "${WEBUI_DIR}" \
    -type f \
    -print \
    | sort \
    | head -200


if [ ! -f "${WEBUI_DIR}/index.html" ]; then

    echo ""
    echo "ERROR: WebUI index.html not found."

    exit 1

fi


echo ""
echo "WebUI: OK"


# ============================================================
# 中文语言检测
# ============================================================

echo ""
echo "============================================================"
echo "Checking WebUI language support"
echo "============================================================"
echo ""


if grep -RqiE \
    'zh-CN|zh_CN|Chinese|中文' \
    "${WEBUI_DIR}" \
    2>/dev/null; then

    echo "Chinese language resources detected."

else

    echo "Chinese language resources not detected."

    echo "WebUI will keep its original language."

fi


# ============================================================
# 保存版本
# ============================================================

VERSION_FILE="${APP_DIR}/VERSION"


cat > "${VERSION_FILE}" <<EOF
LLAMA_CPP_VER=${LLAMA_CPP_VER}
FNPACK_VER=${FNPACK_VER}
EOF


# ============================================================
# 最终检查
# ============================================================

echo ""
echo "============================================================"
echo "Final verification"
echo "============================================================"
echo ""


echo "llama.cpp:"
echo "  ${LLAMA_CPP_VER}"


echo ""
echo "x86_64 Vulkan:"

ls -lh \
    "${BIN_DIR}/x64/llama-server" \
    "${BIN_DIR}/x64/libggml-vulkan.so"


echo ""
echo "ARM64 Vulkan:"

ls -lh \
    "${BIN_DIR}/arm64/llama-server" \
    "${BIN_DIR}/arm64/libggml-vulkan.so"


echo ""
echo "WebUI:"

ls -lh \
    "${WEBUI_DIR}/index.html"


echo ""
echo "WebUI file count:"

find "${WEBUI_DIR}" \
    -type f \
    | wc -l


echo ""
echo "============================================================"
echo " Prepare completed successfully!"
echo "============================================================"
echo ""

echo "llama.cpp version : ${LLAMA_CPP_VER}"
echo "fnpack version    : ${FNPACK_VER}"

echo ""

echo "x86_64 Vulkan     : OK"
echo "ARM64 Vulkan      : OK"
echo "WebUI             : OK"

echo ""

echo "Output:"
echo "${APP_DIR}"

echo ""

echo "Next step:"
echo "./build.sh"

echo ""


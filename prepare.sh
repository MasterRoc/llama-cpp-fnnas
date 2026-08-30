```bash
#!/bin/bash

# ============================================================
# llama.cpp for fnOS - Prepare Script
#
# 功能：
#
# 1. 下载 fnpack
# 2. 下载指定版本 llama.cpp x86_64 Vulkan
# 3. 下载指定版本 llama.cpp ARM64 Vulkan
# 4. 下载指定版本 llama.cpp WebUI
# 5. 每次构建都确保使用当前 LLAMA_CPP_VER
#
# LLAMA_CPP_VER 由 GitHub Actions 提供：
#
#   b10694
#   b10695
#   b10696
#
# 不在这里写死 llama.cpp 版本。
# ============================================================

set -euo pipefail


# ============================================================
# 基础目录
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

APP_DIR="${SCRIPT_DIR}/app"

BIN_DIR="${APP_DIR}/bin"

WEBUI_DIR="${APP_DIR}/webui"


# ============================================================
# 版本
# ============================================================

if [ -z "${LLAMA_CPP_VER:-}" ]; then
    echo ""
    echo "ERROR: LLAMA_CPP_VER is not set."
    echo ""
    echo "Please set LLAMA_CPP_VER before running prepare.sh."
    echo ""
    echo "Example:"
    echo ""
    echo "  LLAMA_CPP_VER=b10694 ./prepare.sh"
    echo ""
    exit 1
fi


FNPACK_VER="${FNPACK_VER:-1.2.3}"


# ============================================================
# 检查 llama.cpp 版本格式
#
# 只允许：
#
#   b10694
#   b10695
#
# 不允许：
#
#   v0.3.0
#   0.3.0
#   master
# ============================================================

if ! echo "${LLAMA_CPP_VER}" | grep -Eq '^b[0-9]+$'; then

    echo ""
    echo "ERROR: Invalid llama.cpp version:"
    echo "       ${LLAMA_CPP_VER}"
    echo ""
    echo "Expected format:"
    echo "       bXXXXX"
    echo ""
    exit 1

fi


# ============================================================
# GitHub Release 地址
# ============================================================

RELEASE_URL="https://github.com/ggml-org/llama.cpp/releases/download/${LLAMA_CPP_VER}"


# ============================================================
# 临时目录
# ============================================================

TMP_DIR="${SCRIPT_DIR}/.prepare-tmp"

mkdir -p "${TMP_DIR}"


# ============================================================
# 清理函数
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
echo "============================================================"
echo ""


# ============================================================
# 1. fnpack
# ============================================================

echo ""
echo "============================================================"
echo "[1/3] fnpack"
echo "============================================================"


FNPACK_PATH="${SCRIPT_DIR}/fnpack"


if [ -f "${FNPACK_PATH}" ]; then

    echo "fnpack already exists."

else

    echo "Downloading fnpack..."

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

                    echo ""
                    echo "ERROR: Unsupported Linux architecture:"
                    echo "${ARCH}"
                    echo ""
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

            echo ""
            echo "ERROR: Unsupported operating system:"
            uname -s
            echo ""
            exit 1

            ;;

    esac

fi


echo ""
echo "fnpack:"
echo "${FNPACK_PATH}"


if [ -x "${FNPACK_PATH}" ]; then

    "${FNPACK_PATH}" --version || true

fi


# ============================================================
# 2. llama.cpp Vulkan binaries
# ============================================================

echo ""
echo "============================================================"
echo "[2/3] llama.cpp Vulkan binaries"
echo "============================================================"


# ------------------------------------------------------------
# 每次构建都删除旧版本
#
# 防止：
#
# b10694
#   ↓
# b10695
#
# 结果仍然使用 b10694。
# ------------------------------------------------------------

echo ""
echo "Removing old llama.cpp binaries..."

rm -rf "${BIN_DIR}/x64"
rm -rf "${BIN_DIR}/arm64"


mkdir -p "${BIN_DIR}/x64"
mkdir -p "${BIN_DIR}/arm64"


# ------------------------------------------------------------
# x86_64
# ------------------------------------------------------------

X64_ASSET="llama-${LLAMA_CPP_VER}-bin-ubuntu-vulkan-x64.tar.gz"

X64_URL="${RELEASE_URL}/${X64_ASSET}"

X64_TMP="${TMP_DIR}/${X64_ASSET}"


echo ""
echo "------------------------------------------------------------"
echo "Downloading x86_64 Vulkan"
echo "------------------------------------------------------------"
echo ""
echo "Version : ${LLAMA_CPP_VER}"
echo "Asset   : ${X64_ASSET}"
echo ""


download_file \
    "${X64_URL}" \
    "${X64_TMP}"


echo ""
echo "Extracting x86_64 Vulkan..."


tar \
    -xzf "${X64_TMP}" \
    --strip-components=1 \
    -C "${BIN_DIR}/x64"


echo ""
echo "x86_64 files:"
find "${BIN_DIR}/x64" \
    -maxdepth 2 \
    -type f \
    -print \
    | sort


# ------------------------------------------------------------
# 检查 x86_64
# ------------------------------------------------------------

if [ ! -f "${BIN_DIR}/x64/llama-server" ]; then

    echo ""
    echo "ERROR: x86_64 llama-server not found!"
    echo ""
    exit 1

fi


if [ ! -f "${BIN_DIR}/x64/libggml-vulkan.so" ]; then

    echo ""
    echo "ERROR: x86_64 libggml-vulkan.so not found!"
    echo ""
    exit 1

fi


chmod +x "${BIN_DIR}/x64/llama-server"


echo ""
echo "x86_64 Vulkan: OK"


# ------------------------------------------------------------
# ARM64
# ------------------------------------------------------------

ARM64_ASSET="llama-${LLAMA_CPP_VER}-bin-ubuntu-vulkan-arm64.tar.gz"

ARM64_URL="${RELEASE_URL}/${ARM64_ASSET}"

ARM64_TMP="${TMP_DIR}/${ARM64_ASSET}"


echo ""
echo "------------------------------------------------------------"
echo "Downloading ARM64 Vulkan"
echo "------------------------------------------------------------"
echo ""
echo "Version : ${LLAMA_CPP_VER}"
echo "Asset   : ${ARM64_ASSET}"
echo ""


download_file \
    "${ARM64_URL}" \
    "${ARM64_TMP}"


echo ""
echo "Extracting ARM64 Vulkan..."


tar \
    -xzf "${ARM64_TMP}" \
    --strip-components=1 \
    -C "${BIN_DIR}/arm64"


echo ""
echo "ARM64 files:"
find "${BIN_DIR}/arm64" \
    -maxdepth 2 \
    -type f \
    -print \
    | sort


# ------------------------------------------------------------
# 检查 ARM64
# ------------------------------------------------------------

if [ ! -f "${BIN_DIR}/arm64/llama-server" ]; then

    echo ""
    echo "ERROR: ARM64 llama-server not found!"
    echo ""
    exit 1

fi


if [ ! -f "${BIN_DIR}/arm64/libggml-vulkan.so" ]; then

    echo ""
    echo "ERROR: ARM64 libggml-vulkan.so not found!"
    echo ""
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


WEBUI_ASSET="llama-${LLAMA_CPP_VER}-ui.tar.gz"

WEBUI_URL="${RELEASE_URL}/${WEBUI_ASSET}"

WEBUI_TMP="${TMP_DIR}/${WEBUI_ASSET}"


# ------------------------------------------------------------
# 每次构建都重新下载 WebUI
#
# 防止旧 WebUI：
#
# b10694 WebUI
#      ↓
# b10695
#
# 仍然使用旧版。
# ------------------------------------------------------------

echo ""
echo "Removing old WebUI..."

rm -rf "${WEBUI_DIR}"

mkdir -p "${WEBUI_DIR}"


echo ""
echo "Downloading WebUI..."
echo ""
echo "Version : ${LLAMA_CPP_VER}"
echo "Asset   : ${WEBUI_ASSET}"
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


echo ""
echo "WebUI files:"
find "${WEBUI_DIR}" \
    -maxdepth 3 \
    -type f \
    -print \
    | sort \
    | head -200


# ------------------------------------------------------------
# 检查 WebUI
# ------------------------------------------------------------

if [ ! -f "${WEBUI_DIR}/index.html" ]; then

    echo ""
    echo "ERROR: WebUI index.html not found!"
    echo ""
    exit 1

fi


echo ""
echo "WebUI: OK"


# ============================================================
# WebUI 中文支持检测
#
# 注意：
#
# 不直接修改压缩 JS。
#
# 先检测当前 WebUI 是否已经包含：
#
#   zh
#   zh-CN
#   Chinese
#   中文
#
# 如果存在，则保留官方语言机制。
#
# 如果不存在，输出提示，后续可以针对当前 WebUI
# 的实际结构进行自动汉化。
# ============================================================

echo ""
echo "============================================================"
echo "Checking WebUI language support"
echo "============================================================"


LANGUAGE_MATCH="false"


if grep -RqiE \
    'zh-CN|zh_CN|Chinese|中文' \
    "${WEBUI_DIR}" \
    2>/dev/null; then

    LANGUAGE_MATCH="true"

fi


if [ "${LANGUAGE_MATCH}" = "true" ]; then

    echo ""
    echo "WebUI appears to contain Chinese language resources."

else

    echo ""
    echo "WebUI does not appear to contain Chinese language resources."

fi


# ============================================================
# 保存版本信息
# ============================================================

VERSION_FILE="${APP_DIR}/VERSION"


cat > "${VERSION_FILE}" <<EOF
LLAMA_CPP_VER=${LLAMA_CPP_VER}
FNPACK_VER=${FNPACK_VER}
EOF


echo ""
echo "Version information:"
cat "${VERSION_FILE}"


# ============================================================
# 最终检查
# ============================================================

echo ""
echo "============================================================"
echo "Final verification"
echo "============================================================"


echo ""
echo "llama.cpp:"
echo "  Version: ${LLAMA_CPP_VER}"


echo ""
echo "x86_64:"
ls -lh \
    "${BIN_DIR}/x64/llama-server" \
    "${BIN_DIR}/x64/libggml-vulkan.so"


echo ""
echo "ARM64:"
ls -lh \
    "${BIN_DIR}/arm64/llama-server" \
    "${BIN_DIR}/arm64/libggml-vulkan.so"


echo ""
echo "WebUI:"
ls -lh "${WEBUI_DIR}/index.html"


echo ""
echo "WebUI file count:"
find "${WEBUI_DIR}" \
    -type f \
    | wc -l


# ============================================================
# 完成
# ============================================================

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
echo "Now run:"
echo ""
echo "  ./build.sh"
echo ""
```

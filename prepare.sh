bash
#!/usr/bin/env bash

# ============================================================
# llama.cpp for fnOS
#
# prepare.sh
#
# 功能：
#
# 1. 下载 fnpack
# 2. 下载 llama.cpp x64 Vulkan
# 3. 下载 llama.cpp ARM64 Vulkan
# 4. 下载 llama.cpp WebUI
# 5. 创建 app/VERSION
# 6. 自动更新 app/manifest
#
# llama.cpp 版本格式：
#
#     b10696
#     b10695
#     b10694
#
# GitHub Actions 会通过：
#
#     LLAMA_CPP_VER
#
# 传入版本。
#
# ============================================================

set -euo pipefail


# ============================================================
# 基础目录
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

APP_DIR="${SCRIPT_DIR}/app"

BIN_DIR="${APP_DIR}/bin"

WEBUI_DIR="${APP_DIR}/webui"

MANIFEST="${APP_DIR}/manifest"

VERSION_FILE="${APP_DIR}/VERSION"


# ============================================================
# 配置
# ============================================================

FNPACK_VER="${FNPACK_VER:-1.2.3}"

LLAMA_CPP_VER="${LLAMA_CPP_VER:-}"


# ============================================================
# 检查 llama.cpp 版本
# ============================================================

if [ -z "${LLAMA_CPP_VER}" ]; then

    echo ""
    echo "============================================================"
    echo "ERROR: LLAMA_CPP_VER is not set."
    echo "============================================================"
    echo ""

    echo "GitHub Actions should provide:"
    echo ""

    echo "LLAMA_CPP_VER=b10696"

    echo ""

    exit 1

fi


# ============================================================
# 验证版本格式
#
# 只允许：
#
# bXXXXX
#
# 例如：
#
# b10696
# b10549
# ============================================================

if ! printf '%s\n' "${LLAMA_CPP_VER}" | grep -Eq '^b[0-9]+$'; then

    echo ""
    echo "============================================================"
    echo "ERROR: Invalid llama.cpp version:"
    echo "${LLAMA_CPP_VER}"
    echo "============================================================"
    echo ""

    echo "Expected format:"
    echo "bXXXXX"

    echo ""

    exit 1

fi


# ============================================================
# 开始
# ============================================================

echo ""
echo "============================================================"
echo " llama.cpp for fnOS"
echo " Dependency Preparation"
echo "============================================================"
echo ""

echo "llama.cpp version : ${LLAMA_CPP_VER}"
echo "fnpack version    : ${FNPACK_VER}"
echo ""

echo "Project directory:"
echo "${SCRIPT_DIR}"
echo ""


# ============================================================
# 创建目录
# ============================================================

mkdir -p "${APP_DIR}"

mkdir -p "${BIN_DIR}"

mkdir -p "${WEBUI_DIR}"


# ============================================================
# 1. fnpack
# ============================================================

echo "============================================================"
echo "[1/5] fnpack"
echo "============================================================"
echo ""


FNPACK_PATH="${SCRIPT_DIR}/fnpack"


if [ -x "${FNPACK_PATH}" ]; then

    echo "fnpack already exists."

    ls -lh "${FNPACK_PATH}"

else

    echo "Downloading fnpack ${FNPACK_VER}..."

    ARCH="$(uname -m)"

    case "${ARCH}" in

        x86_64)

            FNPACK_BIN="fnpack-${FNPACK_VER}-linux-amd64"

            ;;

        aarch64|arm64)

            FNPACK_BIN="fnpack-${FNPACK_VER}-linux-arm64"

            ;;

        *)

            echo ""
            echo "ERROR: Unsupported build architecture:"
            echo "${ARCH}"
            echo ""

            exit 1

            ;;

    esac


    FNPACK_URL="https://static2.fnnas.com/fnpack/${FNPACK_BIN}"


    echo ""
    echo "URL:"
    echo "${FNPACK_URL}"
    echo ""


    curl \
        -fL \
        --retry 5 \
        --retry-delay 2 \
        --retry-connrefused \
        --connect-timeout 30 \
        -o "${FNPACK_PATH}" \
        "${FNPACK_URL}"


    chmod +x "${FNPACK_PATH}"


    if [ ! -x "${FNPACK_PATH}" ]; then

        echo ""
        echo "ERROR: fnpack download failed."
        echo ""

        exit 1

    fi


    echo ""
    echo "fnpack downloaded successfully."

    ls -lh "${FNPACK_PATH}"

fi


echo ""


# ============================================================
# 2. llama.cpp Release URL
# ============================================================

RELEASE_URL="https://github.com/ggml-org/llama.cpp/releases/download/${LLAMA_CPP_VER}"


echo "============================================================"
echo "[2/5] llama.cpp Vulkan binaries"
echo "============================================================"
echo ""

echo "Release:"
echo "${LLAMA_CPP_VER}"

echo ""

echo "Release URL:"
echo "${RELEASE_URL}"

echo ""


# ============================================================
# 下载 llama.cpp 二进制
# ============================================================

download_llama_binary() {

    local ARCH_NAME="$1"

    local ASSET_NAME="$2"

    local DEST_DIR="${BIN_DIR}/${ARCH_NAME}"

    local TEMP_FILE="/tmp/llama-${LLAMA_CPP_VER}-${ARCH_NAME}.tar.gz"


    echo ""
    echo "------------------------------------------------------------"
    echo "Architecture: ${ARCH_NAME}"
    echo "------------------------------------------------------------"
    echo ""

    mkdir -p "${DEST_DIR}"


    # --------------------------------------------------------
    # 如果已经存在，则跳过
    # --------------------------------------------------------

    if [ -f "${DEST_DIR}/llama-server" ] && \
       [ -f "${DEST_DIR}/libggml-vulkan.so" ]; then

        echo "llama.cpp ${ARCH_NAME} already exists."

        echo ""

        ls -lh \
            "${DEST_DIR}/llama-server" \
            "${DEST_DIR}/libggml-vulkan.so"

        return 0

    fi


    # --------------------------------------------------------
    # 下载
    # --------------------------------------------------------

    local DOWNLOAD_URL="${RELEASE_URL}/${ASSET_NAME}"


    echo "Downloading:"
    echo "${DOWNLOAD_URL}"

    echo ""


    rm -f "${TEMP_FILE}"


    curl \
        -fL \
        --retry 5 \
        --retry-delay 2 \
        --retry-connrefused \
        --connect-timeout 30 \
        -o "${TEMP_FILE}" \
        "${DOWNLOAD_URL}"


    if [ ! -s "${TEMP_FILE}" ]; then

        echo ""
        echo "ERROR: Downloaded archive is empty:"
        echo "${TEMP_FILE}"
        echo ""

        exit 1

    fi


    echo ""
    echo "Archive:"
    ls -lh "${TEMP_FILE}"

    echo ""


    # --------------------------------------------------------
    # 解压
    # --------------------------------------------------------

    echo "Extracting..."

    tar \
        xzf "${TEMP_FILE}" \
        --strip-components=1 \
        -C "${DEST_DIR}"


    rm -f "${TEMP_FILE}"


    # --------------------------------------------------------
    # 验证
    # --------------------------------------------------------

    if [ ! -f "${DEST_DIR}/llama-server" ]; then

        echo ""
        echo "ERROR: llama-server not found after extraction:"
        echo "${DEST_DIR}"
        echo ""

        exit 1

    fi


    if [ ! -f "${DEST_DIR}/libggml-vulkan.so" ]; then

        echo ""
        echo "ERROR: libggml-vulkan.so not found after extraction:"
        echo "${DEST_DIR}"
        echo ""

        exit 1

    fi


    echo ""
    echo "llama.cpp ${ARCH_NAME} downloaded successfully."

    echo ""

    echo "Files:"

    find "${DEST_DIR}" \
        -maxdepth 1 \
        -type f \
        -printf '%f\n' |
        sort

}


# ============================================================
# x86_64
# ============================================================

download_llama_binary \
    "x64" \
    "llama-${LLAMA_CPP_VER}-bin-ubuntu-vulkan-x64.tar.gz"


# ============================================================
# ARM64
# ============================================================

download_llama_binary \
    "arm64" \
    "llama-${LLAMA_CPP_VER}-bin-ubuntu-vulkan-arm64.tar.gz"


echo ""


# ============================================================
# 3. WebUI
# ============================================================

echo "============================================================"
echo "[3/5] WebUI"
echo "============================================================"
echo ""


WEBUI_ARCHIVE="/tmp/llama-${LLAMA_CPP_VER}-ui.tar.gz"

WEBUI_URL="${RELEASE_URL}/llama-${LLAMA_CPP_VER}-ui.tar.gz"


echo "WebUI URL:"
echo "${WEBUI_URL}"

echo ""


# ------------------------------------------------------------
# 不使用旧 WebUI
#
# 每次 prepare 都确保当前版本对应当前 WebUI。
# ------------------------------------------------------------

if [ -f "${WEBUI_DIR}/index.html" ]; then

    echo "Existing WebUI detected."

    echo "Removing old WebUI..."

    find "${WEBUI_DIR}" \
        -mindepth 1 \
        -maxdepth 1 \
        -exec rm -rf {} +

fi


mkdir -p "${WEBUI_DIR}"


rm -f "${WEBUI_ARCHIVE}"


echo "Downloading WebUI..."


curl \
    -fL \
    --retry 5 \
    --retry-delay 2 \
    --retry-connrefused \
    --connect-timeout 30 \
    -o "${WEBUI_ARCHIVE}" \
    "${WEBUI_URL}"


if [ ! -s "${WEBUI_ARCHIVE}" ]; then

    echo ""
    echo "ERROR: WebUI archive is empty."
    echo ""

    exit 1

fi


echo ""
echo "Extracting WebUI..."


tar \
    xzf "${WEBUI_ARCHIVE}" \
    --strip-components=1 \
    -C "${WEBUI_DIR}"


rm -f "${WEBUI_ARCHIVE}"


if [ ! -f "${WEBUI_DIR}/index.html" ]; then

    echo ""
    echo "ERROR: WebUI index.html not found."
    echo ""

    exit 1

fi


echo ""
echo "WebUI downloaded successfully."

echo ""

echo "WebUI files:"
find "${WEBUI_DIR}" \
    -type f |
    head -100


echo ""


# ============================================================
# 4. VERSION
# ============================================================

echo "============================================================"
echo "[4/5] Version"
echo "============================================================"
echo ""


mkdir -p "${APP_DIR}"


echo "${LLAMA_CPP_VER}" > "${VERSION_FILE}"


echo "Created:"
echo "${VERSION_FILE}"

echo ""

echo "Version:"
cat "${VERSION_FILE}"

echo ""


# ============================================================
# 5. Manifest
# ============================================================

echo "============================================================"
echo "[5/5] Version and manifest"
echo "============================================================"
echo ""


if [ ! -f "${MANIFEST}" ]; then

    echo ""
    echo "ERROR: manifest not found:"
    echo "${MANIFEST}"
    echo ""

    exit 1

fi


echo "Manifest:"
echo "${MANIFEST}"

echo ""


# ============================================================
# manifest 版本替换
#
# manifest 中必须存在：
#
# version=__VERSION__
#
# prepare.sh 会自动变成：
#
# version=b10696
#
# 注意：
#
# 这里使用 sed。
#
# 不使用 Python 解析 manifest。
#
# 因此 manifest 中可以安全使用中文。
# ============================================================


if grep -q '^version=__VERSION__$' "${MANIFEST}"; then

    sed -i \
        "s/^version=__VERSION__$/version=${LLAMA_CPP_VER}/" \
        "${MANIFEST}"

else

    if grep -q '^version=' "${MANIFEST}"; then

        sed -i \
            "s/^version=.*/version=${LLAMA_CPP_VER}/" \
            "${MANIFEST}"

    else

        echo "version=${LLAMA_CPP_VER}" \
            >> "${MANIFEST}"

    fi

fi


echo "Updated manifest:"
echo ""

cat "${MANIFEST}"

echo ""


# ============================================================
# 最终检查
# ============================================================

echo "============================================================"
echo " Final verification"
echo "============================================================"
echo ""


# ------------------------------------------------------------
# fnpack
# ------------------------------------------------------------

if [ ! -x "${FNPACK_PATH}" ]; then

    echo "ERROR: fnpack is missing."

    exit 1

fi


# ------------------------------------------------------------
# VERSION
# ------------------------------------------------------------

if [ ! -f "${VERSION_FILE}" ]; then

    echo "ERROR: VERSION file is missing."

    exit 1

fi


# ------------------------------------------------------------
# manifest
# ------------------------------------------------------------

if [ ! -f "${MANIFEST}" ]; then

    echo "ERROR: manifest is missing."

    exit 1

fi


# ------------------------------------------------------------
# manifest version
# ------------------------------------------------------------

MANIFEST_VERSION="$(
    sed -n 's/^version=//p' "${MANIFEST}" |
    head -n 1
)"


if [ "${MANIFEST_VERSION}" != "${LLAMA_CPP_VER}" ]; then

    echo ""
    echo "ERROR: Manifest version mismatch."

    echo "Expected:"
    echo "${LLAMA_CPP_VER}"

    echo ""

    echo "Actual:"
    echo "${MANIFEST_VERSION}"

    echo ""

    exit 1

fi


# ------------------------------------------------------------
# x64
# ------------------------------------------------------------

if [ ! -f "${BIN_DIR}/x64/llama-server" ]; then

    echo "ERROR: x64 llama-server missing."

    exit 1

fi


if [ ! -f "${BIN_DIR}/x64/libggml-vulkan.so" ]; then

    echo "ERROR: x64 Vulkan library missing."

    exit 1

fi


# ------------------------------------------------------------
# ARM64
# ------------------------------------------------------------

if [ ! -f "${BIN_DIR}/arm64/llama-server" ]; then

    echo "ERROR: arm64 llama-server missing."

    exit 1

fi


if [ ! -f "${BIN_DIR}/arm64/libggml-vulkan.so" ]; then

    echo "ERROR: arm64 Vulkan library missing."

    exit 1

fi


# ------------------------------------------------------------
# WebUI
# ------------------------------------------------------------

if [ ! -f "${WEBUI_DIR}/index.html" ]; then

    echo "ERROR: WebUI index.html missing."

    exit 1

fi


# ============================================================
# 完成
# ============================================================

echo ""
echo "============================================================"
echo " Preparation completed successfully!"
echo "============================================================"
echo ""

echo "llama.cpp:"
echo "  ${LLAMA_CPP_VER}"

echo ""

echo "fnpack:"
echo "  ${FNPACK_VER}"

echo ""

echo "x64 Vulkan:"
echo "  ${BIN_DIR}/x64"

echo ""

echo "ARM64 Vulkan:"
echo "  ${BIN_DIR}/arm64"

echo ""

echo "WebUI:"
echo "  ${WEBUI_DIR}"

echo ""

echo "VERSION:"
echo "  ${VERSION_FILE}"

echo ""

echo "Manifest:"
echo "  ${MANIFEST}"

echo ""

echo "Manifest version:"
echo "  ${MANIFEST_VERSION}"

echo ""

echo "Next step:"
echo "  ./build.sh"

echo ""

#!/bin/bash

# ============================================================
# llama.cpp for fnOS - Prepare Script
#
# 功能：
#
# 1. 下载 fnpack
# 2. 下载 llama.cpp x64 Vulkan
# 3. 下载 llama.cpp ARM64 Vulkan
# 4. 下载 llama.cpp WebUI
# 5. 自动写入 app/VERSION
# 6. 自动修改根目录 manifest 的 version
# 7. 自动进行 WebUI 中文化
# 8. 检查所有依赖
#
# llama.cpp Release 版本：
#
#   b10694
#   b10695
#   b10696
#
# 不使用：
#
#   v0.3.0
#
# ============================================================

set -euo pipefail


# ============================================================
# 基础目录
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

APP_DIR="${SCRIPT_DIR}/app"

BIN_DIR="${APP_DIR}/bin"

X64_DIR="${BIN_DIR}/x64"

ARM64_DIR="${BIN_DIR}/arm64"

WEBUI_DIR="${APP_DIR}/webui"

TMP_DIR="${SCRIPT_DIR}/.prepare-tmp"

FNPACK_PATH="${SCRIPT_DIR}/fnpack"

MANIFEST_FILE="${SCRIPT_DIR}/manifest"

VERSION_FILE="${APP_DIR}/VERSION"


# ============================================================
# llama.cpp 版本
# ============================================================

if [ -z "${LLAMA_CPP_VER:-}" ]; then

    echo ""
    echo "============================================================"
    echo "ERROR: LLAMA_CPP_VER is not set."
    echo "============================================================"
    echo ""

    exit 1

fi


# ============================================================
# 检查版本格式
#
# 必须是：
#
# b10694
#
# b10695
#
# ============================================================

if ! printf '%s\n' "${LLAMA_CPP_VER}" | grep -Eq '^b[0-9]+$'; then

    echo ""
    echo "============================================================"
    echo "ERROR: Invalid llama.cpp version"
    echo "============================================================"
    echo ""

    echo "Received:"
    echo "${LLAMA_CPP_VER}"

    echo ""

    echo "Expected:"
    echo "bXXXXX"

    echo ""

    exit 1

fi


# ============================================================
# fnpack
# ============================================================

FNPACK_VER="${FNPACK_VER:-1.2.3}"


# ============================================================
# Release URL
# ============================================================

RELEASE_URL="https://github.com/ggml-org/llama.cpp/releases/download/${LLAMA_CPP_VER}"


# ============================================================
# 临时目录
# ============================================================

rm -rf "${TMP_DIR}"

mkdir -p "${TMP_DIR}"


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


    if [ ! -f "${output}" ]; then

        echo ""
        echo "ERROR: Download failed:"
        echo "${output}"
        echo ""

        exit 1

    fi


    if [ ! -s "${output}" ]; then

        echo ""
        echo "ERROR: Downloaded file is empty:"
        echo "${output}"
        echo ""

        exit 1

    fi

}


# ============================================================
# 文件检查
# ============================================================

check_file() {

    local file="$1"


    if [ ! -f "${file}" ]; then

        echo ""
        echo "ERROR: Required file not found:"
        echo "${file}"
        echo ""

        exit 1

    fi


    if [ ! -s "${file}" ]; then

        echo ""
        echo "ERROR: Required file is empty:"
        echo "${file}"
        echo ""

        exit 1

    fi

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

echo "Manifest:"
echo "${MANIFEST_FILE}"

echo ""

echo "Release URL:"
echo "${RELEASE_URL}"

echo ""


# ============================================================
# 检查 manifest
# ============================================================

echo "============================================================"
echo "Checking manifest"
echo "============================================================"
echo ""


if [ ! -f "${MANIFEST_FILE}" ]; then

    echo "ERROR: manifest not found:"
    echo "${MANIFEST_FILE}"

    echo ""

    echo "Project files:"
    find "${SCRIPT_DIR}" \
        -maxdepth 2 \
        -type f \
        -print \
        | sort

    exit 1

fi


echo "Manifest found:"
echo "${MANIFEST_FILE}"


# ============================================================
# 清理旧的二进制
# ============================================================

echo ""
echo "============================================================"
echo "Cleaning old dependencies"
echo "============================================================"
echo ""


rm -rf "${X64_DIR}"

rm -rf "${ARM64_DIR}"

rm -rf "${WEBUI_DIR}"


mkdir -p "${X64_DIR}"

mkdir -p "${ARM64_DIR}"

mkdir -p "${WEBUI_DIR}"


# ============================================================
# 1. fnpack
# ============================================================

echo ""
echo "============================================================"
echo "[1/5] fnpack"
echo "============================================================"
echo ""


if [ -f "${FNPACK_PATH}" ]; then

    echo "fnpack already exists, skip download."

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
                    echo "ERROR: Unsupported architecture:"
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

        *)

            echo ""
            echo "ERROR: Unsupported operating system:"
            uname -s
            echo ""

            exit 1

            ;;

    esac

fi


check_file "${FNPACK_PATH}"

chmod +x "${FNPACK_PATH}"


echo ""
echo "fnpack:"
ls -lh "${FNPACK_PATH}"


echo ""
echo "fnpack help:"

"${FNPACK_PATH}" --help || true


# ============================================================
# 2. llama.cpp x64 Vulkan
# ============================================================

echo ""
echo "============================================================"
echo "[2/5] llama.cpp x86_64 Vulkan"
echo "============================================================"
echo ""


X64_ASSET="llama-${LLAMA_CPP_VER}-bin-ubuntu-vulkan-x64.tar.gz"

X64_URL="${RELEASE_URL}/${X64_ASSET}"

X64_TMP="${TMP_DIR}/${X64_ASSET}"


echo "Asset:"
echo "${X64_ASSET}"

echo ""


download_file \
    "${X64_URL}" \
    "${X64_TMP}"


echo ""
echo "Checking archive..."


tar \
    -tzf "${X64_TMP}" \
    >/dev/null


echo ""
echo "Extracting..."


tar \
    -xzf "${X64_TMP}" \
    --strip-components=1 \
    -C "${X64_DIR}"


check_file "${X64_DIR}/llama-server"

check_file "${X64_DIR}/libggml-vulkan.so"


chmod +x "${X64_DIR}/llama-server"


echo ""
echo "x86_64 Vulkan: OK"

echo ""

echo "Files:"
find "${X64_DIR}" \
    -type f \
    | wc -l


# ============================================================
# 3. llama.cpp ARM64 Vulkan
# ============================================================

echo ""
echo "============================================================"
echo "[3/5] llama.cpp ARM64 Vulkan"
echo "============================================================"
echo ""


ARM64_ASSET="llama-${LLAMA_CPP_VER}-bin-ubuntu-vulkan-arm64.tar.gz"

ARM64_URL="${RELEASE_URL}/${ARM64_ASSET}"

ARM64_TMP="${TMP_DIR}/${ARM64_ASSET}"


echo "Asset:"
echo "${ARM64_ASSET}"

echo ""


download_file \
    "${ARM64_URL}" \
    "${ARM64_TMP}"


echo ""
echo "Checking archive..."


tar \
    -tzf "${ARM64_TMP}" \
    >/dev/null


echo ""
echo "Extracting..."


tar \
    -xzf "${ARM64_TMP}" \
    --strip-components=1 \
    -C "${ARM64_DIR}"


check_file "${ARM64_DIR}/llama-server"

check_file "${ARM64_DIR}/libggml-vulkan.so"


chmod +x "${ARM64_DIR}/llama-server"


echo ""
echo "ARM64 Vulkan: OK"

echo ""

echo "Files:"
find "${ARM64_DIR}" \
    -type f \
    | wc -l


# ============================================================
# 4. WebUI
# ============================================================

echo ""
echo "============================================================"
echo "[4/5] llama.cpp WebUI"
echo "============================================================"
echo ""


WEBUI_ASSET="llama-${LLAMA_CPP_VER}-ui.tar.gz"

WEBUI_URL="${RELEASE_URL}/${WEBUI_ASSET}"

WEBUI_TMP="${TMP_DIR}/${WEBUI_ASSET}"


echo "Asset:"
echo "${WEBUI_ASSET}"

echo ""


download_file \
    "${WEBUI_URL}" \
    "${WEBUI_TMP}"


echo ""
echo "Checking WebUI archive..."


tar \
    -tzf "${WEBUI_TMP}" \
    >/dev/null


echo ""
echo "Extracting WebUI..."


tar \
    -xzf "${WEBUI_TMP}" \
    --strip-components=1 \
    -C "${WEBUI_DIR}"


check_file "${WEBUI_DIR}/index.html"


echo ""
echo "WebUI: OK"

echo ""

echo "WebUI files:"
find "${WEBUI_DIR}" \
    -type f \
    | wc -l


# ============================================================
# WebUI Bundle
# ============================================================

echo ""
echo "============================================================"
echo "Detecting WebUI JavaScript"
echo "============================================================"
echo ""


BUNDLE_FILE=""


while IFS= read -r file; do

    BUNDLE_FILE="${file}"

    break

done < <(
    find "${WEBUI_DIR}" \
        -type f \
        -name 'bundle.*.js' \
        -print \
        | sort
)


if [ -z "${BUNDLE_FILE}" ]; then

    while IFS= read -r file; do

        BUNDLE_FILE="${file}"

        break

    done < <(
        find "${WEBUI_DIR}" \
            -type f \
            -name '*.js' \
            -print \
            | sort
    )

fi


if [ -n "${BUNDLE_FILE}" ]; then

    echo "Bundle:"
    echo "${BUNDLE_FILE}"

else

    echo "WARNING: WebUI JavaScript bundle not found."

fi


# ============================================================
# WebUI 中文化
# ============================================================

echo ""
echo "============================================================"
echo "Applying Chinese WebUI translations"
echo "============================================================"
echo ""


if [ -n "${BUNDLE_FILE}" ]; then

    python3 - "${BUNDLE_FILE}" <<'PY'

import sys
from pathlib import Path


file = Path(sys.argv[1])


text = file.read_text(
    encoding="utf-8"
)


translations = {

    "New Chat": "新建对话",
    "New Conversation": "新建对话",

    "Conversation": "对话",
    "Conversations": "对话",

    "Chat": "聊天",
    "Chats": "聊天",

    "Send": "发送",
    "Stop": "停止",

    "Cancel": "取消",
    "Close": "关闭",
    "Open": "打开",

    "Clear": "清空",
    "Delete": "删除",
    "Edit": "编辑",

    "Save": "保存",
    "Saved": "已保存",

    "Confirm": "确认",

    "Back": "返回",
    "Next": "下一步",
    "Previous": "上一步",

    "Model": "模型",
    "Models": "模型",

    "Model Name": "模型名称",
    "Model Settings": "模型设置",

    "Load Model": "加载模型",
    "Unload Model": "卸载模型",
    "Select Model": "选择模型",

    "Prompt": "提示词",
    "System Prompt": "系统提示词",
    "User Prompt": "用户提示词",

    "System": "系统",
    "User": "用户",
    "Assistant": "助手",

    "Temperature": "温度",
    "Context Size": "上下文长度",
    "Context Length": "上下文长度",

    "Max Tokens": "最大 Token 数",
    "Max New Tokens": "最大生成 Token 数",

    "Seed": "随机种子",

    "Repeat Penalty": "重复惩罚",

    "Settings": "设置",
    "General": "常规",
    "Advanced": "高级",

    "Appearance": "外观",
    "Theme": "主题",
    "Language": "语言",

    "Dark": "深色",
    "Light": "浅色",

    "Server": "服务器",
    "Server Settings": "服务器设置",

    "Connection": "连接",
    "Connect": "连接",
    "Disconnect": "断开连接",

    "Host": "主机",
    "Port": "端口",

    "File": "文件",
    "Files": "文件",

    "Upload": "上传",
    "Download": "下载",

    "Remove": "移除",
    "Browse": "浏览",

    "Tool": "工具",
    "Tools": "工具",

    "Reasoning": "思考",
    "Thinking": "思考",

    "Search": "搜索",
    "Refresh": "刷新",
    "Reload": "重新加载",

    "Welcome": "欢迎",
    "Help": "帮助",
    "About": "关于",

    "Loading": "加载中",

    "Error": "错误",
    "Warning": "警告",
    "Success": "成功",

}


count = 0


for old, new in translations.items():

    for quote in ('"', "'"):

        old_text = quote + old + quote

        new_text = quote + new + quote

        occurrences = text.count(old_text)

        if occurrences:

            text = text.replace(
                old_text,
                new_text
            )

            count += occurrences


file.write_text(
    text,
    encoding="utf-8"
)


print(
    f"Chinese translations applied: {count}"
)

PY

else

    echo "No WebUI bundle found, skipping translation."

fi


# ============================================================
# 5. Version / Manifest
# ============================================================

echo ""
echo "============================================================"
echo "[5/5] Version and manifest"
echo "============================================================"
echo ""


# ============================================================
# 修改根目录 manifest
#
# 原始：
#
# version=__VERSION__
#
# 修改：
#
# version=b10694
#
# ============================================================

echo "Updating manifest version..."

sed -i \
    -E "s/^version=.*/version=${LLAMA_CPP_VER}/" \
    "${MANIFEST_FILE}"


# ============================================================
# 检查 manifest 是否存在 version
# ============================================================

if ! grep -q "^version=${LLAMA_CPP_VER}$" "${MANIFEST_FILE}"; then

    echo ""
    echo "============================================================"
    echo "ERROR: Failed to update manifest version"
    echo "============================================================"
    echo ""

    echo "Current manifest:"
    cat "${MANIFEST_FILE}"

    echo ""

    exit 1

fi


echo ""
echo "Manifest version:"
grep "^version=" "${MANIFEST_FILE}"


# ============================================================
# 写入 app/VERSION
# ============================================================

echo ""
echo "Updating app/VERSION..."


printf '%s\n' "${LLAMA_CPP_VER}" > "${VERSION_FILE}"


check_file "${VERSION_FILE}"


echo ""
echo "app/VERSION:"
cat "${VERSION_FILE}"


# ============================================================
# 最终检查
# ============================================================

echo ""
echo "============================================================"
echo "Final verification"
echo "============================================================"
echo ""


echo "===== Manifest ====="

grep "^appname=" "${MANIFEST_FILE}" || true

grep "^version=" "${MANIFEST_FILE}" || true

grep "^display_name=" "${MANIFEST_FILE}" || true

grep "^maintainer=" "${MANIFEST_FILE}" || true

grep "^distributor=" "${MANIFEST_FILE}" || true


echo ""
echo "===== app/VERSION ====="

cat "${VERSION_FILE}"


echo ""
echo "===== x86_64 ====="

check_file "${X64_DIR}/llama-server"

check_file "${X64_DIR}/libggml-vulkan.so"


echo "llama-server:"
ls -lh "${X64_DIR}/llama-server"

echo ""

echo "libggml-vulkan.so:"
ls -lh "${X64_DIR}/libggml-vulkan.so"


echo ""
echo "===== ARM64 ====="

check_file "${ARM64_DIR}/llama-server"

check_file "${ARM64_DIR}/libggml-vulkan.so"


echo "llama-server:"
ls -lh "${ARM64_DIR}/llama-server"

echo ""

echo "libggml-vulkan.so:"
ls -lh "${ARM64_DIR}/libggml-vulkan.so"


echo ""
echo "===== WebUI ====="

check_file "${WEBUI_DIR}/index.html"

ls -lh "${WEBUI_DIR}/index.html"


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

echo "Manifest          : OK"

echo "app/VERSION       : OK"

echo ""

echo "Manifest version:"
grep "^version=" "${MANIFEST_FILE}"

echo ""

echo "Next step:"
echo "./build.sh"

echo ""

bash
#!/bin/bash

# ============================================================
# llama.cpp for fnOS - Prepare Script
#
# 自动下载并准备 FPK 所需依赖
#
# 依赖：
#   1. fnpack
#   2. llama.cpp x86_64 Vulkan
#   3. llama.cpp ARM64 Vulkan
#   4. llama.cpp WebUI
#
# llama.cpp 版本：
#
#   b10694
#   b10695
#   b10696
#
# 版本由 GitHub Actions 的 LLAMA_CPP_VER 提供。
#
# ============================================================

set -euo pipefail


# ============================================================
# 基础路径
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

APP_DIR="${SCRIPT_DIR}/app"

BIN_DIR="${APP_DIR}/bin"

X64_DIR="${BIN_DIR}/x64"

ARM64_DIR="${BIN_DIR}/arm64"

WEBUI_DIR="${APP_DIR}/webui"

TMP_DIR="${SCRIPT_DIR}/.prepare-tmp"

FNPACK_PATH="${SCRIPT_DIR}/fnpack"


# ============================================================
# 版本
# ============================================================

if [ -z "${LLAMA_CPP_VER:-}" ]; then

    echo ""
    echo "ERROR: LLAMA_CPP_VER is not set."
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
# 只接受：
#
#   b10694
#   b10695
#
# 不接受：
#
#   v0.3.0
#   0.3.0
#   master
#
# ============================================================

if ! printf '%s\n' "${LLAMA_CPP_VER}" | grep -Eq '^b[0-9]+$'; then

    echo ""
    echo "ERROR: Invalid llama.cpp version:"
    echo ""
    echo "  ${LLAMA_CPP_VER}"
    echo ""
    echo "Expected format:"
    echo ""
    echo "  bXXXXX"
    echo ""

    exit 1

fi


# ============================================================
# GitHub Release URL
# ============================================================

RELEASE_URL="https://github.com/ggml-org/llama.cpp/releases/download/${LLAMA_CPP_VER}"


# ============================================================
# 临时目录
# ============================================================

rm -rf "${TMP_DIR}"

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
    echo "------------------------------------------------------------"
    echo "Downloading"
    echo "------------------------------------------------------------"
    echo ""
    echo "${url}"
    echo ""
    echo "Output:"
    echo "${output}"
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
# 检查文件
# ============================================================

check_file() {

    local file="$1"

    if [ ! -f "${file}" ]; then

        echo ""
        echo "ERROR: File not found:"
        echo "${file}"
        echo ""

        exit 1

    fi


    if [ ! -s "${file}" ]; then

        echo ""
        echo "ERROR: File is empty:"
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

echo "Release URL:"
echo "${RELEASE_URL}"

echo ""


# ============================================================
# 清理旧版本
# ============================================================

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
echo "[1/4] fnpack"
echo "============================================================"
echo ""


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


check_file "${FNPACK_PATH}"


chmod +x "${FNPACK_PATH}"


echo ""
echo "fnpack:"
ls -lh "${FNPACK_PATH}"


# ------------------------------------------------------------
# 注意：
#
# fnpack 1.2.3 不支持：
#
#   fnpack --version
#
# 所以这里不再调用 --version。
#
# 使用 help 检查程序是否可以正常运行。
# ------------------------------------------------------------

echo ""
echo "fnpack help:"

"${FNPACK_PATH}" --help || true


# ============================================================
# 2. x86_64 Vulkan
# ============================================================

echo ""
echo "============================================================"
echo "[2/4] llama.cpp x86_64 Vulkan"
echo "============================================================"
echo ""


X64_ASSET="llama-${LLAMA_CPP_VER}-bin-ubuntu-vulkan-x64.tar.gz"

X64_URL="${RELEASE_URL}/${X64_ASSET}"

X64_TMP="${TMP_DIR}/${X64_ASSET}"


echo "Version:"
echo "${LLAMA_CPP_VER}"

echo ""

echo "Asset:"
echo "${X64_ASSET}"

echo ""


download_file \
    "${X64_URL}" \
    "${X64_TMP}"


check_file "${X64_TMP}"


echo ""
echo "Checking archive..."

tar \
    -tzf "${X64_TMP}" \
    >/dev/null


echo ""
echo "Extracting x86_64 Vulkan..."


tar \
    -xzf "${X64_TMP}" \
    --strip-components=1 \
    -C "${X64_DIR}"


echo ""
echo "x86_64 files:"

find "${X64_DIR}" \
    -type f \
    -print \
    | sort


# ------------------------------------------------------------
# x86_64 必需文件
# ------------------------------------------------------------

if [ ! -f "${X64_DIR}/llama-server" ]; then

    echo ""
    echo "ERROR: x86_64 llama-server not found."
    echo ""

    exit 1

fi


if [ ! -f "${X64_DIR}/libggml-vulkan.so" ]; then

    echo ""
    echo "ERROR: x86_64 libggml-vulkan.so not found."
    echo ""

    exit 1

fi


chmod +x "${X64_DIR}/llama-server"


echo ""
echo "x86_64 Vulkan: OK"


# ============================================================
# 3. ARM64 Vulkan
# ============================================================

echo ""
echo "============================================================"
echo "[3/4] llama.cpp ARM64 Vulkan"
echo "============================================================"
echo ""


ARM64_ASSET="llama-${LLAMA_CPP_VER}-bin-ubuntu-vulkan-arm64.tar.gz"

ARM64_URL="${RELEASE_URL}/${ARM64_ASSET}"

ARM64_TMP="${TMP_DIR}/${ARM64_ASSET}"


echo "Version:"
echo "${LLAMA_CPP_VER}"

echo ""

echo "Asset:"
echo "${ARM64_ASSET}"

echo ""


download_file \
    "${ARM64_URL}" \
    "${ARM64_TMP}"


check_file "${ARM64_TMP}"


echo ""
echo "Checking archive..."

tar \
    -tzf "${ARM64_TMP}" \
    >/dev/null


echo ""
echo "Extracting ARM64 Vulkan..."


tar \
    -xzf "${ARM64_TMP}" \
    --strip-components=1 \
    -C "${ARM64_DIR}"


echo ""
echo "ARM64 files:"

find "${ARM64_DIR}" \
    -type f \
    -print \
    | sort


# ------------------------------------------------------------
# ARM64 必需文件
# ------------------------------------------------------------

if [ ! -f "${ARM64_DIR}/llama-server" ]; then

    echo ""
    echo "ERROR: ARM64 llama-server not found."
    echo ""

    exit 1

fi


if [ ! -f "${ARM64_DIR}/libggml-vulkan.so" ]; then

    echo ""
    echo "ERROR: ARM64 libggml-vulkan.so not found."
    echo ""

    exit 1

fi


chmod +x "${ARM64_DIR}/llama-server"


echo ""
echo "ARM64 Vulkan: OK"


# ============================================================
# 4. WebUI
# ============================================================

echo ""
echo "============================================================"
echo "[4/4] llama.cpp WebUI"
echo "============================================================"
echo ""


WEBUI_ASSET="llama-${LLAMA_CPP_VER}-ui.tar.gz"

WEBUI_URL="${RELEASE_URL}/${WEBUI_ASSET}"

WEBUI_TMP="${TMP_DIR}/${WEBUI_ASSET}"


echo "Version:"
echo "${LLAMA_CPP_VER}"

echo ""

echo "Asset:"
echo "${WEBUI_ASSET}"

echo ""


download_file \
    "${WEBUI_URL}" \
    "${WEBUI_TMP}"


check_file "${WEBUI_TMP}"


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


# ------------------------------------------------------------
# WebUI index
# ------------------------------------------------------------

if [ ! -f "${WEBUI_DIR}/index.html" ]; then

    echo ""
    echo "ERROR: WebUI index.html not found."
    echo ""

    exit 1

fi


echo ""
echo "WebUI index:"
ls -lh "${WEBUI_DIR}/index.html"


# ============================================================
# 查找 WebUI JS Bundle
# ============================================================

echo ""
echo "============================================================"
echo "Detecting WebUI bundle"
echo "============================================================"
echo ""


BUNDLE_COUNT=0

BUNDLE_FILE=""


while IFS= read -r file; do

    BUNDLE_COUNT=$((BUNDLE_COUNT + 1))

    if [ -z "${BUNDLE_FILE}" ]; then

        BUNDLE_FILE="${file}"

    fi

done < <(
    find "${WEBUI_DIR}" \
        -type f \
        \( \
            -name 'bundle.*.js' \
            -o \
            -name '*.js' \
        \) \
        -print \
        | sort
)


echo "JavaScript files found:"
echo "${BUNDLE_COUNT}"


if [ -n "${BUNDLE_FILE}" ]; then

    echo ""
    echo "Primary bundle:"
    echo "${BUNDLE_FILE}"

    echo ""
    echo "Bundle size:"
    ls -lh "${BUNDLE_FILE}"

else

    echo ""
    echo "WARNING: No JavaScript bundle detected."

fi


# ============================================================
# WebUI 中文化
#
# 注意：
#
# 官方 llama-ui 当前是 SvelteKit WebUI。
#
# 为避免破坏新版压缩 JS：
#
# 这里只替换“明确的 UI 文本”。
#
# 不对普通英文单词做全局替换。
#
# ============================================================

echo ""
echo "============================================================"
echo "WebUI Chinese translation"
echo "============================================================"
echo ""


if [ -z "${BUNDLE_FILE}" ]; then

    echo "No bundle found."
    echo "Skip translation."

else

    echo "Translating UI strings..."
    echo ""


    # --------------------------------------------------------
    # 创建备份
    # --------------------------------------------------------

    cp \
        "${BUNDLE_FILE}" \
        "${BUNDLE_FILE}.before-cn"


    # --------------------------------------------------------
    # 中文翻译函数
    #
    # 只处理常见 UI 字符串。
    #
    # 使用 Python 而不是 sed：
    #
    # 1. 支持 UTF-8
    # 2. 避免 sed 在不同 Linux 环境下行为差异
    # 3. 可以安全处理大文件
    # --------------------------------------------------------

    python3 - "${BUNDLE_FILE}" <<'PY'
import sys
from pathlib import Path

file = Path(sys.argv[1])

text = file.read_text(encoding="utf-8")

# ============================================================
# 中文翻译表
#
# 这里只放明确的 UI 文本。
# ============================================================

translations = {

    # -----------------------------
    # 基础
    # -----------------------------

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

    "Save": "保存",
    "Saved": "已保存",
    "Delete": "删除",
    "Edit": "编辑",
    "Clear": "清空",
    "Reset": "重置",

    "Confirm": "确认",
    "Back": "返回",
    "Next": "下一步",
    "Previous": "上一步",

    # -----------------------------
    # Model
    # -----------------------------

    "Model": "模型",
    "Models": "模型",
    "Load Model": "加载模型",
    "Unload Model": "卸载模型",
    "Select Model": "选择模型",
    "Model Name": "模型名称",

    "Model Settings": "模型设置",

    # -----------------------------
    # Prompt
    # -----------------------------

    "Prompt": "提示词",
    "System Prompt": "系统提示词",
    "User Prompt": "用户提示词",

    "System": "系统",
    "User": "用户",
    "Assistant": "助手",

    # -----------------------------
    # Generation
    # -----------------------------

    "Temperature": "温度",
    "Top P": "Top P",
    "Top K": "Top K",
    "Min P": "Min P",

    "Context Size": "上下文长度",
    "Context Length": "上下文长度",

    "Max Tokens": "最大 Token 数",
    "Max New Tokens": "最大生成 Token 数",

    "Seed": "随机种子",

    "Repeat Penalty": "重复惩罚",

    # -----------------------------
    # Settings
    # -----------------------------

    "Settings": "设置",
    "General": "常规",
    "Advanced": "高级",
    "Appearance": "外观",
    "Theme": "主题",
    "Language": "语言",

    "Dark": "深色",
    "Light": "浅色",
    "System": "跟随系统",

    # -----------------------------
    # Server
    # -----------------------------

    "Server": "服务器",
    "Server Settings": "服务器设置",
    "Connection": "连接",
    "Connect": "连接",
    "Disconnect": "断开连接",

    "Host": "主机",
    "Port": "端口",

    # -----------------------------
    # File
    # -----------------------------

    "File": "文件",
    "Files": "文件",
    "Upload": "上传",
    "Download": "下载",
    "Remove": "移除",
    "Browse": "浏览",

    # -----------------------------
    # MCP
    # -----------------------------

    "MCP": "MCP",
    "Tools": "工具",
    "Tool": "工具",

    # -----------------------------
    # Reasoning
    # -----------------------------

    "Reasoning": "思考",
    "Thinking": "思考",
    "Reasoning Content": "思考内容",

    # -----------------------------
    # UI
    # -----------------------------

    "Menu": "菜单",
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


# ============================================================
# 替换策略
#
# 只替换 JSON/JS 中作为完整字符串出现的文本。
#
# 同时处理：
#
#   "Settings"
#   'Settings'
#
# 避免：
#
#   settings
#   SettingsManager
#   settings_url
#
# 被误修改。
# ============================================================

replacements = 0

for old, new in translations.items():

    patterns = [
        f'"{old}"',
        f"'{old}'",
    ]

    for pattern in patterns:

        replacement = (
            '"' + new + '"'
            if pattern.startswith('"')
            else "'" + new + "'"
        )

        count = text.count(pattern)

        if count:
            text = text.replace(pattern, replacement)
            replacements += count


file.write_text(text, encoding="utf-8")

print(f"Chinese translation replacements: {replacements}")

PY


    # --------------------------------------------------------
    # 检查 JS 是否仍然存在
    # --------------------------------------------------------

    if [ ! -s "${BUNDLE_FILE}" ]; then

        echo ""
        echo "ERROR: WebUI bundle became empty."

        echo "Restoring original bundle..."

        mv \
            "${BUNDLE_FILE}.before-cn" \
            "${BUNDLE_FILE}"

        exit 1

    fi


    # --------------------------------------------------------
    # 删除备份
    # --------------------------------------------------------

    rm -f "${BUNDLE_FILE}.before-cn"


    echo ""
    echo "WebUI translation completed."

fi


# ============================================================
# WebUI 文件统计
# ============================================================

echo ""
echo "============================================================"
echo "WebUI verification"
echo "============================================================"
echo ""


WEBUI_FILE_COUNT=$(
    find "${WEBUI_DIR}" \
        -type f \
        | wc -l
)


echo "WebUI file count:"
echo "${WEBUI_FILE_COUNT}"


echo ""

echo "WebUI structure:"

find "${WEBUI_DIR}" \
    -maxdepth 3 \
    -type f \
    -print \
    | sort \
    | head -200


# ============================================================
# 保存版本信息
# ============================================================

echo ""
echo "============================================================"
echo "Saving version information"
echo "============================================================"
echo ""


VERSION_FILE="${APP_DIR}/VERSION"


cat > "${VERSION_FILE}" <<EOF
LLAMA_CPP_VER=${LLAMA_CPP_VER}
FNPACK_VER=${FNPACK_VER}
EOF


echo "Created:"
echo "${VERSION_FILE}"


cat "${VERSION_FILE}"


# ============================================================
# 最终检查
# ============================================================

echo ""
echo "============================================================"
echo "Final verification"
echo "============================================================"
echo ""


# ------------------------------------------------------------
# fnpack
# ------------------------------------------------------------

echo "===== fnpack ====="

ls -lh "${FNPACK_PATH}"


# ------------------------------------------------------------
# x86_64
# ------------------------------------------------------------

echo ""
echo "===== x86_64 Vulkan ====="

ls -lh \
    "${X64_DIR}/llama-server" \
    "${X64_DIR}/libggml-vulkan.so"


# ------------------------------------------------------------
# ARM64
# ------------------------------------------------------------

echo ""
echo "===== ARM64 Vulkan ====="

ls -lh \
    "${ARM64_DIR}/llama-server" \
    "${ARM64_DIR}/libggml-vulkan.so"


# ------------------------------------------------------------
# WebUI
# ------------------------------------------------------------

echo ""
echo "===== WebUI ====="

ls -lh \
    "${WEBUI_DIR}/index.html"


# ------------------------------------------------------------
# 版本
# ------------------------------------------------------------

echo ""
echo "===== Version ====="

echo "llama.cpp:"
echo "${LLAMA_CPP_VER}"

echo ""

echo "fnpack:"
echo "${FNPACK_VER}"


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

echo "Chinese UI        : PATCHED"

echo ""

echo "Output:"
echo "${APP_DIR}"

echo ""

echo "Next step:"
echo "./build.sh"

echo ""


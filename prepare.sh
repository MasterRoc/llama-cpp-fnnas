bash
#!/bin/bash

# ============================================================
# llama.cpp for fnOS - Prepare Script
#
# 功能：
#
# 1. 下载 fnpack
# 2. 下载 llama.cpp x86_64 Vulkan
# 3. 下载 llama.cpp ARM64 Vulkan
# 4. 下载 llama.cpp WebUI
# 5. 自动设置 app/VERSION
# 6. 自动修改 app/manifest 版本号
# 7. 自动进行 WebUI 中文化
# 8. 完整检查依赖
#
# llama.cpp 版本格式：
#
#   b10694
#   b10695
#   b10696
#
# 不使用：
#
#   v0.3.0
#   0.3.0
#
# LLAMA_CPP_VER 由 GitHub Actions 提供。
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

MANIFEST_FILE="${APP_DIR}/manifest"

VERSION_FILE="${APP_DIR}/VERSION"


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
# llama.cpp 当前 Release 使用：
#
#   bXXXXX
#
# 例如：
#
#   b10694
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
    echo "Expected format:"
    echo "bXXXXX"
    echo ""
    echo "Examples:"
    echo "b10694"
    echo "b10695"
    echo "b10696"
    echo ""

    exit 1

fi


# ============================================================
# Release URL
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
    echo "URL:"
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
# 检查普通文件
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

echo "Release URL:"
echo "${RELEASE_URL}"

echo ""


# ============================================================
# 清理旧版本
#
# 防止上一次构建残留旧版本文件。
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
echo "[1/5] fnpack"
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
echo "fnpack file:"
ls -lh "${FNPACK_PATH}"


# ------------------------------------------------------------
# fnpack 1.2.3 不支持：
#
#   fnpack --version
#
# 因此这里只使用 help。
# ------------------------------------------------------------

echo ""
echo "fnpack help:"

"${FNPACK_PATH}" --help || true


# ============================================================
# 2. x86_64 Vulkan
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
echo "Checking x86_64 archive..."


tar \
    -tzf "${X64_TMP}" \
    >/dev/null


echo ""
echo "Extracting x86_64 Vulkan..."


tar \
    -xzf "${X64_TMP}" \
    --strip-components=1 \
    -C "${X64_DIR}"


# ------------------------------------------------------------
# x86_64 必需文件
# ------------------------------------------------------------

check_file "${X64_DIR}/llama-server"

check_file "${X64_DIR}/libggml-vulkan.so"


chmod +x "${X64_DIR}/llama-server"


echo ""
echo "x86_64 Vulkan: OK"

echo ""

echo "x86_64 file count:"
find "${X64_DIR}" -type f | wc -l


# ============================================================
# 3. ARM64 Vulkan
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
echo "Checking ARM64 archive..."


tar \
    -tzf "${ARM64_TMP}" \
    >/dev/null


echo ""
echo "Extracting ARM64 Vulkan..."


tar \
    -xzf "${ARM64_TMP}" \
    --strip-components=1 \
    -C "${ARM64_DIR}"


# ------------------------------------------------------------
# ARM64 必需文件
# ------------------------------------------------------------

check_file "${ARM64_DIR}/llama-server"

check_file "${ARM64_DIR}/libggml-vulkan.so"


chmod +x "${ARM64_DIR}/llama-server"


echo ""
echo "ARM64 Vulkan: OK"

echo ""

echo "ARM64 file count:"
find "${ARM64_DIR}" -type f | wc -l


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


# ------------------------------------------------------------
# WebUI 必需文件
# ------------------------------------------------------------

check_file "${WEBUI_DIR}/index.html"


WEBUI_FILE_COUNT=$(
    find "${WEBUI_DIR}" \
        -type f \
        | wc -l
)


echo ""
echo "WebUI file count:"
echo "${WEBUI_FILE_COUNT}"


# ============================================================
# 查找 WebUI Bundle
# ============================================================

echo ""
echo "============================================================"
echo "Detecting WebUI JavaScript bundle"
echo "============================================================"
echo ""


BUNDLE_FILE=""


# 优先寻找：
#
# bundle.xxxxx.js
#
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


# 如果没有 bundle.*.js
# 再寻找普通 JS。

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

    echo "WebUI bundle:"
    echo "${BUNDLE_FILE}"

    echo ""

    echo "Bundle size:"
    ls -lh "${BUNDLE_FILE}"

else

    echo ""
    echo "WARNING: No WebUI JavaScript bundle found."

fi


# ============================================================
# WebUI 中文化
# ============================================================

echo ""
echo "============================================================"
echo "WebUI Chinese translation"
echo "============================================================"
echo ""


if [ -z "${BUNDLE_FILE}" ]; then

    echo "No JavaScript bundle detected."

    echo "Skipping translation."

else

    echo "Applying safe UI translations..."


    # --------------------------------------------------------
    # 备份
    # --------------------------------------------------------

    cp \
        "${BUNDLE_FILE}" \
        "${BUNDLE_FILE}.before-cn"


    # --------------------------------------------------------
    # Python UTF-8 翻译
    # --------------------------------------------------------

    python3 - "${BUNDLE_FILE}" <<'PY'

import sys
from pathlib import Path


file = Path(sys.argv[1])


text = file.read_text(
    encoding="utf-8"
)


# ============================================================
# 翻译表
#
# 这里只替换完整字符串。
#
# 不进行普通英文单词全局替换。
# ============================================================

translations = {

    # --------------------------------------------------------
    # Chat
    # --------------------------------------------------------

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

    # --------------------------------------------------------
    # Model
    # --------------------------------------------------------

    "Model": "模型",
    "Models": "模型",
    "Model Name": "模型名称",

    "Model Settings": "模型设置",

    "Load Model": "加载模型",
    "Unload Model": "卸载模型",
    "Select Model": "选择模型",

    # --------------------------------------------------------
    # Prompt
    # --------------------------------------------------------

    "Prompt": "提示词",
    "System Prompt": "系统提示词",
    "User Prompt": "用户提示词",

    "System": "系统",
    "User": "用户",
    "Assistant": "助手",

    # --------------------------------------------------------
    # Generation
    # --------------------------------------------------------

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

    # --------------------------------------------------------
    # Settings
    # --------------------------------------------------------

    "Settings": "设置",
    "General": "常规",
    "Advanced": "高级",

    "Appearance": "外观",
    "Theme": "主题",
    "Language": "语言",

    "Dark": "深色",
    "Light": "浅色",

    # --------------------------------------------------------
    # Server
    # --------------------------------------------------------

    "Server": "服务器",
    "Server Settings": "服务器设置",

    "Connection": "连接",
    "Connect": "连接",
    "Disconnect": "断开连接",

    "Host": "主机",
    "Port": "端口",

    # --------------------------------------------------------
    # File
    # --------------------------------------------------------

    "File": "文件",
    "Files": "文件",

    "Upload": "上传",
    "Download": "下载",

    "Remove": "移除",
    "Browse": "浏览",

    # --------------------------------------------------------
    # Tools
    # --------------------------------------------------------

    "Tool": "工具",
    "Tools": "工具",

    "MCP": "MCP",

    # --------------------------------------------------------
    # Reasoning
    # --------------------------------------------------------

    "Reasoning": "思考",
    "Thinking": "思考",

    "Reasoning Content": "思考内容",

    # --------------------------------------------------------
    # UI
    # --------------------------------------------------------

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
# 替换
# ============================================================

count = 0


for old, new in translations.items():

    patterns = [

        f'"{old}"',

        f"'{old}'",

    ]


    for pattern in patterns:

        if pattern.startswith('"'):

            replacement = f'"{new}"'

        else:

            replacement = f"'{new}'"


        occurrences = text.count(pattern)


        if occurrences > 0:

            text = text.replace(
                pattern,
                replacement
            )

            count += occurrences


# ============================================================
# 写回
# ============================================================

file.write_text(
    text,
    encoding="utf-8"
)


print(
    f"Chinese translation replacements: {count}"
)

PY


    # --------------------------------------------------------
    # 检查文件
    # --------------------------------------------------------

    check_file "${BUNDLE_FILE}"


    # --------------------------------------------------------
    # 删除备份
    # --------------------------------------------------------

    rm -f "${BUNDLE_FILE}.before-cn"


    echo ""
    echo "WebUI Chinese translation: OK"

fi


# ============================================================
# 5. 设置版本信息
# ============================================================

echo ""
echo "============================================================"
echo "[5/5] Version and manifest"
echo "============================================================"
echo ""


# ============================================================
# 检查 manifest
# ============================================================

if [ ! -f "${MANIFEST_FILE}" ]; then

    echo ""
    echo "ERROR: manifest not found:"
    echo "${MANIFEST_FILE}"
    echo ""

    exit 1

fi


echo "Manifest:"
echo "${MANIFEST_FILE}"

echo ""


# ============================================================
# 修改 manifest
#
# version=__VERSION__
#
# 自动变成：
#
# version=b10694
# ============================================================

echo "Updating manifest version..."


python3 \
    "${MANIFEST_FILE}" \
    "${LLAMA_CPP_VER}" \
    <<'PY'

import sys
from pathlib import Path


manifest = Path(sys.argv[1])

version = sys.argv[2]


text = manifest.read_text(
    encoding="utf-8"
)


lines = text.splitlines()


found = False


for i, line in enumerate(lines):

    if line.startswith("version="):

        lines[i] = f"version={version}"

        found = True

        break


if not found:

    raise SystemExit(
        "ERROR: version= line not found in manifest"
    )


manifest.write_text(
    "\n".join(lines) + "\n",
    encoding="utf-8"
)


print(
    f"Manifest version updated: {version}"
)

PY


# ============================================================
# 验证 manifest
# ============================================================

MANIFEST_VERSION="$(
    grep '^version=' "${MANIFEST_FILE}" \
    | head -1 \
    | cut -d'=' -f2-
)"


if [ -z "${MANIFEST_VERSION}" ]; then

    echo ""
    echo "ERROR: Unable to read manifest version."
    echo ""

    exit 1

fi


if [ "${MANIFEST_VERSION}" != "${LLAMA_CPP_VER}" ]; then

    echo ""
    echo "============================================================"
    echo "ERROR: Manifest version mismatch"
    echo "============================================================"
    echo ""

    echo "Expected:"
    echo "${LLAMA_CPP_VER}"

    echo ""

    echo "Actual:"
    echo "${MANIFEST_VERSION}"

    echo ""

    exit 1

fi


echo ""
echo "Manifest version:"
echo "version=${MANIFEST_VERSION}"


# ============================================================
# 写入 app/VERSION
# ============================================================

cat > "${VERSION_FILE}" <<EOF
${LLAMA_CPP_VER}
EOF


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


# ------------------------------------------------------------
# fnpack
# ------------------------------------------------------------

echo "===== fnpack ====="

check_file "${FNPACK_PATH}"

ls -lh "${FNPACK_PATH}"


# ------------------------------------------------------------
# x86_64
# ------------------------------------------------------------

echo ""
echo "===== x86_64 Vulkan ====="

check_file "${X64_DIR}/llama-server"

check_file "${X64_DIR}/libggml-vulkan.so"

ls -lh \
    "${X64_DIR}/llama-server" \
    "${X64_DIR}/libggml-vulkan.so"


# ------------------------------------------------------------
# ARM64
# ------------------------------------------------------------

echo ""
echo "===== ARM64 Vulkan ====="

check_file "${ARM64_DIR}/llama-server"

check_file "${ARM64_DIR}/libggml-vulkan.so"

ls -lh \
    "${ARM64_DIR}/llama-server" \
    "${ARM64_DIR}/libggml-vulkan.so"


# ------------------------------------------------------------
# WebUI
# ------------------------------------------------------------

echo ""
echo "===== WebUI ====="

check_file "${WEBUI_DIR}/index.html"

ls -lh "${WEBUI_DIR}/index.html"


# ------------------------------------------------------------
# Manifest
# ------------------------------------------------------------

echo ""
echo "===== Manifest ====="

grep '^appname=' "${MANIFEST_FILE}" || true

grep '^version=' "${MANIFEST_FILE}" || true

grep '^display_name=' "${MANIFEST_FILE}" || true

grep '^maintainer=' "${MANIFEST_FILE}" || true

grep '^distributor=' "${MANIFEST_FILE}" || true


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

echo "Manifest version  : ${MANIFEST_VERSION}"

echo "Chinese UI        : OK"

echo ""

echo "Manifest:"
echo "${MANIFEST_FILE}"

echo ""

echo "Version:"
echo "${VERSION_FILE}"

echo ""

echo "Next step:"
echo "./build.sh"

echo ""


bash
#!/usr/bin/env bash

# ============================================================
# llama.cpp for fnOS - Prepare Script
#
# 功能：
#
# 1. 自动检测 ggml-org/llama.cpp 最新 bXXXXX Release
# 2. 不使用 v0.3.0 之类版本
# 3. 下载 fnpack
# 4. 下载 llama.cpp x64 Vulkan
# 5. 下载 llama.cpp arm64 Vulkan
# 6. 下载对应版本 WebUI
# 7. 自动生成 app/VERSION
# 8. 自动寻找 manifest 模板
# 9. 自动生成 app/manifest
# 10. 强制更新 manifest 的 version=
# 11. 最终验证所有版本
#
# manifest 自动寻找顺序：
#
#   ./manifest
#   ./config/manifest
#   ./package/manifest
#   ./app/manifest
#
# manifest 中可以写：
#
#   version=__VERSION__
#
# 或：
#
#   version=b10549
#
# 或：
#
#   version=任何旧版本
#
# 最终都会自动变成：
#
#   version=bXXXXX
#
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

APP_DIR="${SCRIPT_DIR}/app"
BIN_DIR="${APP_DIR}/bin"
WEBUI_DIR="${APP_DIR}/webui"

VERSION_FILE="${APP_DIR}/VERSION"
MANIFEST_FILE="${APP_DIR}/manifest"

FNPACK_VER="${FNPACK_VER:-1.2.3}"

GITHUB_REPO="ggml-org/llama.cpp"

RELEASE_API="https://api.github.com/repos/${GITHUB_REPO}/releases?per_page=100"

echo ""
echo "============================================================"
echo " llama.cpp for fnOS"
echo " Prepare dependencies"
echo "============================================================"
echo ""

# ============================================================
# 1. 检查工具
# ============================================================

echo "[1/5] Checking required tools..."

REQUIRED_COMMANDS=(
    curl
    tar
    gzip
    python3
    grep
    sed
    find
    sort
    head
    tr
    mktemp
)

for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
        echo ""
        echo "ERROR: required command not found: ${cmd}"
        exit 1
    fi
done

echo "Required tools OK"
echo ""

# ============================================================
# 2. 检测 llama.cpp 最新 bXXXXX
# ============================================================

detect_llama_version() {

    echo "Getting llama.cpp releases..." >&2

    local json_file
    json_file="$(mktemp)"

    curl \
        --fail \
        --silent \
        --show-error \
        --location \
        --retry 5 \
        --retry-delay 2 \
        --connect-timeout 30 \
        --max-time 180 \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -o "${json_file}" \
        "${RELEASE_API}"

    if [ ! -s "${json_file}" ]; then
        echo "ERROR: GitHub API returned empty response" >&2
        rm -f "${json_file}"
        return 1
    fi

    python3 - "${json_file}" <<'PY'
import json
import re
import sys

filename = sys.argv[1]

try:
    with open(filename, "r", encoding="utf-8") as f:
        releases = json.load(f)
except Exception as e:
    print(f"ERROR: failed to parse GitHub API response: {e}", file=sys.stderr)
    sys.exit(1)

if not isinstance(releases, list):
    print("ERROR: GitHub API response is not a release list", file=sys.stderr)
    sys.exit(1)

versions = []

for release in releases:
    if not isinstance(release, dict):
        continue

    tag = str(release.get("tag_name", "")).strip()

    # 只接受：
    #
    # b10549
    # b10696
    # b10697
    #
    # 不接受：
    #
    # v0.3.0
    # latest
    # master
    # 其他 tag
    #
    match = re.fullmatch(r"b([0-9]+)", tag)

    if not match:
        continue

    number = int(match.group(1))

    versions.append((number, tag))

if not versions:
    print(
        "ERROR: No bXXXXX llama.cpp release found",
        file=sys.stderr
    )
    sys.exit(1)

versions.sort(
    key=lambda x: x[0],
    reverse=True
)

print(versions[0][1])
PY

    rm -f "${json_file}"
}

# ============================================================
# 获取版本
# ============================================================

if [ -n "${LLAMA_CPP_VER:-}" ]; then

    echo "[2/5] LLAMA_CPP_VER provided:"
    echo "      ${LLAMA_CPP_VER}"

else

    echo "[2/5] Detecting latest llama.cpp bXXXXX release..."

    LLAMA_CPP_VER="$(detect_llama_version)"

fi

# ============================================================
# 检查版本格式
# ============================================================

if ! printf '%s\n' "${LLAMA_CPP_VER}" | grep -Eq '^b[0-9]+$'; then

    echo ""
    echo "ERROR: Invalid llama.cpp version:"
    echo "${LLAMA_CPP_VER}"
    echo ""
    echo "Expected format:"
    echo "bXXXXX"
    echo ""

    exit 1

fi

echo ""
echo "============================================================"
echo " Detected llama.cpp version: ${LLAMA_CPP_VER}"
echo " fnpack version: ${FNPACK_VER}"
echo "============================================================"
echo ""

# ============================================================
# 创建目录
# ============================================================

mkdir -p "${APP_DIR}"
mkdir -p "${BIN_DIR}"
mkdir -p "${WEBUI_DIR}"

# ============================================================
# 3. 下载 fnpack
# ============================================================

echo "[3/5] fnpack"
echo "------------------------------------------------------------"

download_fnpack() {

    local os
    os="$(uname -s)"

    case "${os}" in

        Linux)

            local arch
            arch="$(uname -m)"

            local fnpack_asset

            case "${arch}" in

                x86_64)
                    fnpack_asset="fnpack-${FNPACK_VER}-linux-amd64"
                    ;;

                aarch64)
                    fnpack_asset="fnpack-${FNPACK_VER}-linux-arm64"
                    ;;

                *)
                    echo "ERROR: Unsupported Linux architecture: ${arch}"
                    return 1
                    ;;

            esac

            echo "Downloading:"
            echo "${fnpack_asset}"

            curl \
                --fail \
                --location \
                --show-error \
                --retry 5 \
                --retry-delay 2 \
                --connect-timeout 30 \
                --max-time 300 \
                -o "${SCRIPT_DIR}/fnpack" \
                "https://static2.fnnas.com/fnpack/${fnpack_asset}"

            chmod +x "${SCRIPT_DIR}/fnpack"

            ;;

        MINGW*|MSYS*|CYGWIN*)

            echo "Downloading Windows fnpack..."

            curl \
                --fail \
                --location \
                --show-error \
                --retry 5 \
                --connect-timeout 30 \
                -o "${SCRIPT_DIR}/fnpack.exe" \
                "https://static2.fnnas.com/fnpack/fnpack-${FNPACK_VER}-windows-amd64"

            ;;

        *)

            echo "ERROR: Unsupported operating system:"
            uname -s

            return 1

            ;;

    esac
}

if [ -x "${SCRIPT_DIR}/fnpack" ]; then

    echo "fnpack already exists."
    echo "Skipping download."

elif [ -f "${SCRIPT_DIR}/fnpack.exe" ]; then

    echo "fnpack.exe already exists."
    echo "Skipping download."

else

    download_fnpack

fi

echo ""

# ============================================================
# llama.cpp Release URL
# ============================================================

RELEASE_URL="https://github.com/${GITHUB_REPO}/releases/download/${LLAMA_CPP_VER}"

echo "llama.cpp release URL:"
echo "${RELEASE_URL}"
echo ""

# ============================================================
# 下载 Vulkan 二进制
# ============================================================

download_llama_vulkan() {

    local arch="$1"
    local asset="$2"

    local destination="${BIN_DIR}/${arch}"
    local temp_file

    temp_file="$(mktemp --suffix=".tar.gz")"

    echo ""
    echo "------------------------------------------------------------"
    echo "Downloading llama.cpp ${arch}"
    echo "------------------------------------------------------------"

    echo "Version:"
    echo "${LLAMA_CPP_VER}"

    echo ""
    echo "Asset:"
    echo "${asset}"

    echo ""
    echo "URL:"
    echo "${RELEASE_URL}/${asset}"

    mkdir -p "${destination}"

    # 清理旧版本文件，避免旧文件残留
    find "${destination}" \
        -mindepth 1 \
        -maxdepth 1 \
        -exec rm -rf {} +

    curl \
        --fail \
        --location \
        --show-error \
        --retry 5 \
        --retry-delay 2 \
        --connect-timeout 30 \
        --max-time 1800 \
        -o "${temp_file}" \
        "${RELEASE_URL}/${asset}"

    if [ ! -s "${temp_file}" ]; then

        echo ""
        echo "ERROR: Downloaded archive is empty."

        rm -f "${temp_file}"

        return 1

    fi

    echo ""
    echo "Extracting..."

    tar \
        -xzf "${temp_file}" \
        --strip-components=1 \
        -C "${destination}"

    rm -f "${temp_file}"

    if [ ! -f "${destination}/llama-server" ]; then

        echo ""
        echo "ERROR: llama-server not found:"
        echo "${destination}/llama-server"

        return 1

    fi

    if [ ! -f "${destination}/libggml-vulkan.so" ]; then

        echo ""
        echo "ERROR: libggml-vulkan.so not found:"
        echo "${destination}/libggml-vulkan.so"

        return 1

    fi

    chmod +x "${destination}/llama-server" 2>/dev/null || true

    echo ""
    echo "llama.cpp ${arch} downloaded successfully."

    echo ""
    echo "File count:"
    find "${destination}" \
        -maxdepth 1 \
        -type f |
        wc -l

}

download_llama_vulkan \
    "x64" \
    "llama-${LLAMA_CPP_VER}-bin-ubuntu-vulkan-x64.tar.gz"

download_llama_vulkan \
    "arm64" \
    "llama-${LLAMA_CPP_VER}-bin-ubuntu-vulkan-arm64.tar.gz"

echo ""

# ============================================================
# 下载 WebUI
# ============================================================

echo "[4/5] WebUI"
echo "------------------------------------------------------------"

WEBUI_ASSET="llama-${LLAMA_CPP_VER}-ui.tar.gz"
WEBUI_URL="${RELEASE_URL}/${WEBUI_ASSET}"

WEBUI_TEMP="$(mktemp --suffix=".tar.gz")"

echo "WebUI:"
echo "${WEBUI_ASSET}"

echo ""
echo "URL:"
echo "${WEBUI_URL}"

# 删除旧 WebUI
find "${WEBUI_DIR}" \
    -mindepth 1 \
    -maxdepth 1 \
    -exec rm -rf {} +

curl \
    --fail \
    --location \
    --show-error \
    --retry 5 \
    --retry-delay 2 \
    --connect-timeout 30 \
    --max-time 1800 \
    -o "${WEBUI_TEMP}" \
    "${WEBUI_URL}"

if [ ! -s "${WEBUI_TEMP}" ]; then

    echo ""
    echo "ERROR: WebUI archive is empty."

    rm -f "${WEBUI_TEMP}"

    exit 1

fi

echo ""
echo "Extracting WebUI..."

tar \
    -xzf "${WEBUI_TEMP}" \
    --strip-components=1 \
    -C "${WEBUI_DIR}"

rm -f "${WEBUI_TEMP}"

if [ ! -f "${WEBUI_DIR}/index.html" ]; then

    echo ""
    echo "ERROR: WebUI index.html not found."

    exit 1

fi

echo ""
echo "WebUI downloaded successfully."

# ============================================================
# 5. VERSION + manifest
# ============================================================

echo ""
echo "[5/5] Version and manifest"
echo "------------------------------------------------------------"

# ============================================================
# 生成 app/VERSION
# ============================================================

echo ""
echo "Creating app/VERSION..."

printf '%s\n' "${LLAMA_CPP_VER}" > "${VERSION_FILE}"

if [ ! -f "${VERSION_FILE}" ]; then

    echo "ERROR: failed to create:"
    echo "${VERSION_FILE}"

    exit 1

fi

echo ""
echo "app/VERSION:"
cat "${VERSION_FILE}"

# ============================================================
# 自动寻找 manifest
#
# 重要：
#
# 这里不是要求 app/manifest 必须提前存在。
#
# 会自动搜索：
#
# 1. 项目根目录 manifest
# 2. config/manifest
# 3. package/manifest
# 4. app/manifest
#
# 找到后复制成：
#
# app/manifest
#
# ============================================================

echo ""
echo "Searching manifest template..."

MANIFEST_TEMPLATE=""

MANIFEST_CANDIDATES=(
    "${SCRIPT_DIR}/manifest"
    "${SCRIPT_DIR}/config/manifest"
    "${SCRIPT_DIR}/package/manifest"
    "${APP_DIR}/manifest"
)

for candidate in "${MANIFEST_CANDIDATES[@]}"; do

    if [ -f "${candidate}" ]; then

        MANIFEST_TEMPLATE="${candidate}"

        echo "Manifest template found:"
        echo "${MANIFEST_TEMPLATE}"

        break

    fi

done

# ============================================================
# 如果没有找到 manifest
# ============================================================

if [ -z "${MANIFEST_TEMPLATE}" ]; then

    echo ""
    echo "ERROR: manifest template not found."
    echo ""

    echo "Searched locations:"

    for candidate in "${MANIFEST_CANDIDATES[@]}"; do
        echo "  ${candidate}"
    done

    echo ""
    echo "Please create a manifest template."
    echo ""

    exit 1

fi

# ============================================================
# 生成 app/manifest
#
# 这里是关键修复。
#
# 不管原 manifest 是：
#
# version=__VERSION__
#
# version=b10549
#
# version=b10696
#
# version=xxx
#
# 最终统一强制修改为：
#
# version=${LLAMA_CPP_VER}
#
# ============================================================

echo ""
echo "Generating app/manifest..."

TEMP_MANIFEST="$(mktemp)"

# ------------------------------------------------------------
# 先复制模板
# ------------------------------------------------------------

cp \
    "${MANIFEST_TEMPLATE}" \
    "${TEMP_MANIFEST}"

# ------------------------------------------------------------
# 删除 CRLF
#
# 防止 Windows 编辑器产生：
#
# version=b10697\r
#
# ------------------------------------------------------------

sed -i 's/\r$//' "${TEMP_MANIFEST}"

# ------------------------------------------------------------
# 检查是否存在 version=
# ------------------------------------------------------------

if grep -q '^version=' "${TEMP_MANIFEST}"; then

    echo "Existing version field found."

    # 强制替换整个 version 行
    sed -i \
        "s/^version=.*/version=${LLAMA_CPP_VER}/" \
        "${TEMP_MANIFEST}"

else

    echo "No version field found."

    echo "Adding:"
    echo "version=${LLAMA_CPP_VER}"

    {
        printf 'version=%s\n' "${LLAMA_CPP_VER}"
        cat "${TEMP_MANIFEST}"
    } > "${TEMP_MANIFEST}.new"

    mv \
        "${TEMP_MANIFEST}.new" \
        "${TEMP_MANIFEST}"

fi

# ------------------------------------------------------------
# 最终写入 app/manifest
# ------------------------------------------------------------

cp \
    "${TEMP_MANIFEST}" \
    "${MANIFEST_FILE}"

rm -f "${TEMP_MANIFEST}"

# ============================================================
# 检查 app/manifest
# ============================================================

if [ ! -f "${MANIFEST_FILE}" ]; then

    echo ""
    echo "ERROR: failed to create:"
    echo "${MANIFEST_FILE}"

    exit 1

fi

# ============================================================
# 读取 manifest version
# ============================================================

MANIFEST_VERSION="$(
    sed \
        -n \
        's/^version=//p' \
        "${MANIFEST_FILE}" |
        head -n 1 |
        tr -d '\r' |
        tr -d '[:space:]'
)"

echo ""
echo "============================================================"
echo " Generated app/manifest"
echo "============================================================"

cat "${MANIFEST_FILE}"

echo ""
echo "============================================================"
echo " Manifest version check"
echo "============================================================"

echo "Expected:"
echo "${LLAMA_CPP_VER}"

echo ""
echo "Actual:"
echo "${MANIFEST_VERSION}"

if [ "${MANIFEST_VERSION}" != "${LLAMA_CPP_VER}" ]; then

    echo ""
    echo "ERROR: manifest version mismatch."

    echo ""
    echo "Expected:"
    echo "${LLAMA_CPP_VER}"

    echo ""
    echo "Actual:"
    echo "${MANIFEST_VERSION}"

    exit 1

fi

echo ""
echo "Manifest version OK."

# ============================================================
# 最终 VERSION 检查
# ============================================================

echo ""
echo "============================================================"
echo " VERSION check"
echo "============================================================"

APP_VERSION="$(
    tr -d '[:space:]' < "${VERSION_FILE}"
)"

echo "Expected:"
echo "${LLAMA_CPP_VER}"

echo ""
echo "Actual:"
echo "${APP_VERSION}"

if [ "${APP_VERSION}" != "${LLAMA_CPP_VER}" ]; then

    echo ""
    echo "ERROR: app/VERSION mismatch."

    exit 1

fi

echo ""
echo "app/VERSION OK."

# ============================================================
# x64 检查
# ============================================================

echo ""
echo "============================================================"
echo " x64 Vulkan check"
echo "============================================================"

if [ ! -f "${BIN_DIR}/x64/llama-server" ]; then

    echo "ERROR: x64 llama-server not found."

    exit 1

fi

if [ ! -f "${BIN_DIR}/x64/libggml-vulkan.so" ]; then

    echo "ERROR: x64 libggml-vulkan.so not found."

    exit 1

fi

echo "llama-server:"
ls -lh "${BIN_DIR}/x64/llama-server"

echo ""
echo "libggml-vulkan.so:"
ls -lh "${BIN_DIR}/x64/libggml-vulkan.so"

echo ""
echo "x64 Vulkan OK."

# ============================================================
# ARM64 检查
# ============================================================

echo ""
echo "============================================================"
echo " arm64 Vulkan check"
echo "============================================================"

if [ ! -f "${BIN_DIR}/arm64/llama-server" ]; then

    echo "ERROR: arm64 llama-server not found."

    exit 1

fi

if [ ! -f "${BIN_DIR}/arm64/libggml-vulkan.so" ]; then

    echo "ERROR: arm64 libggml-vulkan.so not found."

    exit 1

fi

echo "llama-server:"
ls -lh "${BIN_DIR}/arm64/llama-server"

echo ""
echo "libggml-vulkan.so:"
ls -lh "${BIN_DIR}/arm64/libggml-vulkan.so"

echo ""
echo "arm64 Vulkan OK."

# ============================================================
# WebUI 检查
# ============================================================

echo ""
echo "============================================================"
echo " WebUI check"
echo "============================================================"

if [ ! -f "${WEBUI_DIR}/index.html" ]; then

    echo "ERROR: WebUI index.html not found."

    exit 1

fi

WEBUI_FILE_COUNT="$(
    find "${WEBUI_DIR}" \
        -type f |
        wc -l
)"

echo "WebUI files:"
echo "${WEBUI_FILE_COUNT}"

if [ "${WEBUI_FILE_COUNT}" -le 0 ]; then

    echo "ERROR: WebUI is empty."

    exit 1

fi

echo ""
echo "WebUI OK."

# ============================================================
# fnpack 检查
# ============================================================

echo ""
echo "============================================================"
echo " fnpack check"
echo "============================================================"

if [ -f "${SCRIPT_DIR}/fnpack" ]; then

    chmod +x "${SCRIPT_DIR}/fnpack"

    ls -lh "${SCRIPT_DIR}/fnpack"

elif [ -f "${SCRIPT_DIR}/fnpack.exe" ]; then

    ls -lh "${SCRIPT_DIR}/fnpack.exe"

else

    echo "ERROR: fnpack not found."

    exit 1

fi

echo ""
echo "fnpack OK."

# ============================================================
# 最终目录结构
# ============================================================

echo ""
echo "============================================================"
echo " Application structure"
echo "============================================================"

find "${APP_DIR}" \
    -maxdepth 3 \
    -type f \
    -print |
sort

# ============================================================
# 最终结果
# ============================================================

echo ""
echo "============================================================"
echo " Prepare completed successfully"
echo "============================================================"

echo ""
echo "llama.cpp:"
echo "  ${LLAMA_CPP_VER}"

echo ""
echo "fnpack:"
echo "  ${FNPACK_VER}"

echo ""
echo "VERSION:"
echo "  ${VERSION_FILE}"

echo ""
echo "Manifest:"
echo "  ${MANIFEST_FILE}"

echo ""
echo "Manifest template:"
echo "  ${MANIFEST_TEMPLATE}"

echo ""
echo "x64 Vulkan:"
echo "  ${BIN_DIR}/x64"

echo ""
echo "arm64 Vulkan:"
echo "  ${BIN_DIR}/arm64"

echo ""
echo "WebUI:"
echo "  ${WEBUI_DIR}"

echo ""
echo "Ready for:"
echo "  ./build.sh"

echo ""


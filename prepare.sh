bash
#!/usr/bin/env bash

# ============================================================
# llama.cpp for fnOS - Prepare Script
#
# 功能：
#
# 1. 自动检测 ggml-org/llama.cpp 最新 bXXXXX 版本
# 2. 下载 fnpack
# 3. 下载 llama.cpp x64 Vulkan
# 4. 下载 llama.cpp arm64 Vulkan
# 5. 下载对应版本 WebUI
# 6. 自动生成 app/VERSION
# 7. 自动寻找 manifest 模板
# 8. 自动生成 app/manifest
# 9. 自动替换 manifest 中的 __VERSION__
# 10. 检查所有依赖
#
# 注意：
#
# GitHub Actions 中 build.yml 会设置：
#
#   LLAMA_CPP_VER=bXXXXX
#
# 如果没有设置，本脚本会自行从 GitHub API 检测。
#
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

APP_DIR="${SCRIPT_DIR}/app"
BIN_DIR="${APP_DIR}/bin"
WEBUI_DIR="${APP_DIR}/webui"

FNPACK_VER="${FNPACK_VER:-1.2.3}"

GITHUB_REPO="ggml-org/llama.cpp"

RELEASE_API="https://api.github.com/repos/${GITHUB_REPO}/releases?per_page=100"

echo "============================================================"
echo " llama.cpp for fnOS"
echo " Prepare dependencies"
echo "============================================================"
echo ""

# ============================================================
# 工具检查
# ============================================================

echo "[1/5] Checking required tools..."

for cmd in curl tar gzip python3 grep sed find sort; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
        echo "ERROR: required command not found: ${cmd}"
        exit 1
    fi
done

echo "Required tools OK"
echo ""

# ============================================================
# 自动检测 llama.cpp 版本
# ============================================================

detect_llama_version() {

    echo "Getting llama.cpp releases..." >&2

    local json_file
    json_file="$(mktemp)"

    cleanup_detect() {
        rm -f "${json_file}"
    }

    trap cleanup_detect RETURN

    curl \
        --fail \
        --silent \
        --show-error \
        --location \
        --retry 5 \
        --retry-delay 2 \
        --connect-timeout 30 \
        --max-time 120 \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -o "${json_file}" \
        "${RELEASE_API}"

    if [ ! -s "${json_file}" ]; then
        echo "ERROR: GitHub API returned empty response" >&2
        return 1
    fi

    python3 - "${json_file}" <<'PY'
import json
import re
import sys

filename = sys.argv[1]

with open(filename, "r", encoding="utf-8") as f:
    releases = json.load(f)

if not isinstance(releases, list):
    raise SystemExit("ERROR: GitHub API response is not a list")

versions = []

for release in releases:

    if not isinstance(release, dict):
        continue

    tag = str(release.get("tag_name", "")).strip()

    # 只接受：
    #
    # b10549
    # b10690
    # b10696
    #
    # 不接受：
    #
    # v0.3.0
    # latest
    # other-tag

    match = re.fullmatch(r"b([0-9]+)", tag)

    if not match:
        continue

    number = int(match.group(1))

    versions.append((number, tag))

if not versions:
    raise SystemExit(
        "ERROR: No llama.cpp bXXXXX release found"
    )

versions.sort(
    key=lambda item: item[0],
    reverse=True
)

print(versions[0][1])
PY
}

# ============================================================
# 获取版本
# ============================================================

if [ -n "${LLAMA_CPP_VER:-}" ]; then

    echo "[2/5] LLAMA_CPP_VER already provided:"
    echo "      ${LLAMA_CPP_VER}"

else

    echo "[2/5] Detecting latest llama.cpp version..."

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
echo " llama.cpp version: ${LLAMA_CPP_VER}"
echo " fnpack version:    ${FNPACK_VER}"
echo "============================================================"
echo ""

# ============================================================
# 创建目录
# ============================================================

mkdir -p "${APP_DIR}"
mkdir -p "${BIN_DIR}"
mkdir -p "${WEBUI_DIR}"

# ============================================================
# 下载 fnpack
# ============================================================

echo "[3/5] fnpack"
echo "------------------------------------------------------------"

download_fnpack() {

    local output=""

    case "$(uname -s)" in

        Linux)

            local arch
            arch="$(uname -m)"

            case "${arch}" in

                x86_64)
                    output="fnpack-${FNPACK_VER}-linux-amd64"
                    ;;

                aarch64)
                    output="fnpack-${FNPACK_VER}-linux-arm64"
                    ;;

                *)
                    echo "ERROR: Unsupported Linux architecture: ${arch}"
                    return 1
                    ;;

            esac

            echo "Downloading fnpack:"
            echo "${output}"

            curl \
                --fail \
                --location \
                --show-error \
                --retry 5 \
                --connect-timeout 30 \
                -o "${SCRIPT_DIR}/fnpack" \
                "https://static2.fnnas.com/fnpack/${output}"

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

else

    download_fnpack

fi

echo ""

# ============================================================
# llama.cpp Release URL
# ============================================================

RELEASE_URL="https://github.com/${GITHUB_REPO}/releases/download/${LLAMA_CPP_VER}"

echo "llama.cpp release:"
echo "${RELEASE_URL}"
echo ""

# ============================================================
# 下载 llama.cpp Vulkan
# ============================================================

download_llama_vulkan() {

    local arch="$1"
    local asset="$2"

    local destination="${BIN_DIR}/${arch}"
    local temp_file="/tmp/llama-${LLAMA_CPP_VER}-${arch}.tar.gz"

    echo ""
    echo "------------------------------------------------------------"
    echo "Downloading llama.cpp ${arch}"
    echo "------------------------------------------------------------"

    mkdir -p "${destination}"

    # 如果之前目录存在旧文件，避免旧版本文件残留
    find "${destination}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +

    echo "Version:"
    echo "${LLAMA_CPP_VER}"

    echo "Asset:"
    echo "${asset}"

    echo "URL:"
    echo "${RELEASE_URL}/${asset}"

    curl \
        --fail \
        --location \
        --show-error \
        --retry 5 \
        --connect-timeout 30 \
        --max-time 1800 \
        -o "${temp_file}" \
        "${RELEASE_URL}/${asset}"

    if [ ! -s "${temp_file}" ]; then
        echo "ERROR: Downloaded archive is empty."
        rm -f "${temp_file}"
        return 1
    fi

    echo "Extracting..."

    tar \
        -xzf "${temp_file}" \
        --strip-components=1 \
        -C "${destination}"

    rm -f "${temp_file}"

    if [ ! -f "${destination}/llama-server" ]; then
        echo "ERROR: llama-server not found:"
        echo "${destination}/llama-server"
        return 1
    fi

    if [ ! -f "${destination}/libggml-vulkan.so" ]; then
        echo "ERROR: libggml-vulkan.so not found:"
        echo "${destination}/libggml-vulkan.so"
        return 1
    fi

    echo ""
    echo "llama.cpp ${arch} downloaded successfully."

    echo ""
    echo "Files:"
    find "${destination}" \
        -maxdepth 1 \
        -type f \
        -printf '%f\n' |
    sort

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

echo "WebUI asset:"
echo "${WEBUI_ASSET}"

echo ""
echo "WebUI URL:"
echo "${WEBUI_URL}"

WEBUI_TEMP="/tmp/llama-${LLAMA_CPP_VER}-webui.tar.gz"

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
    --connect-timeout 30 \
    --max-time 1800 \
    -o "${WEBUI_TEMP}" \
    "${WEBUI_URL}"

if [ ! -s "${WEBUI_TEMP}" ]; then
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
    echo "ERROR: WebUI index.html not found."
    exit 1
fi

echo ""
echo "WebUI downloaded successfully."

# ============================================================
# 自动寻找 manifest
# ============================================================

echo ""
echo "[5/5] Version and manifest"
echo "------------------------------------------------------------"

VERSION_FILE="${APP_DIR}/VERSION"
MANIFEST_FILE="${APP_DIR}/manifest"

# ============================================================
# 生成 app/VERSION
# ============================================================

echo ""
echo "Creating app/VERSION..."

printf '%s\n' "${LLAMA_CPP_VER}" > "${VERSION_FILE}"

if [ ! -f "${VERSION_FILE}" ]; then
    echo "ERROR: failed to create app/VERSION"
    exit 1
fi

echo ""
echo "app/VERSION:"
cat "${VERSION_FILE}"

# ============================================================
# 自动寻找 manifest 模板
#
# 优先级：
#
# 1. 根目录 manifest
# 2. config/manifest
# 3. package/manifest
# 4. app/manifest
#
# 如果已经存在 app/manifest：
#   直接使用它作为模板
#
# ============================================================

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
    echo "Searched:"
    echo ""

    for candidate in "${MANIFEST_CANDIDATES[@]}"; do
        echo "  ${candidate}"
    done

    echo ""
    echo "Please put your manifest file in the project root:"
    echo ""
    echo "  manifest"
    echo ""

    exit 1

fi

echo ""
echo "Manifest template found:"
echo "${MANIFEST_TEMPLATE}"

# ============================================================
# 生成 app/manifest
#
# 不使用 Python。
#
# 这样中文内容完全不会出现：
#
# SyntaxError: invalid character
#
# ============================================================

TEMP_MANIFEST="/tmp/llama-manifest-${LLAMA_CPP_VER}"

sed \
    "s/__VERSION__/${LLAMA_CPP_VER}/g" \
    "${MANIFEST_TEMPLATE}" \
    > "${TEMP_MANIFEST}"

# ============================================================
# 如果模板没有 version=__VERSION__
#
# 则自动替换现有 version=
#
# 例如：
#
# version=b10549
#
# 自动变成：
#
# version=b10696
#
# ============================================================

if ! grep -q '^version=' "${TEMP_MANIFEST}"; then

    echo ""
    echo "WARNING: manifest has no version= field."

    echo "Adding:"
    echo "version=${LLAMA_CPP_VER}"

    {
        echo "version=${LLAMA_CPP_VER}"
        cat "${TEMP_MANIFEST}"
    } > "${TEMP_MANIFEST}.new"

    mv \
        "${TEMP_MANIFEST}.new" \
        "${TEMP_MANIFEST}"

else

    sed \
        -i \
        "s/^version=.*/version=${LLAMA_CPP_VER}/" \
        "${TEMP_MANIFEST}"

fi

# ============================================================
# 写入 app/manifest
# ============================================================

cp \
    "${TEMP_MANIFEST}" \
    "${MANIFEST_FILE}"

rm -f "${TEMP_MANIFEST}"

# ============================================================
# 检查 manifest
# ============================================================

if [ ! -f "${MANIFEST_FILE}" ]; then

    echo ""
    echo "ERROR: failed to create app/manifest"

    exit 1

fi

MANIFEST_VERSION="$(
    sed \
        -n \
        's/^version=//p' \
        "${MANIFEST_FILE}" |
    head -n 1 |
    tr -d '\r'
)"

echo ""
echo "app/manifest:"
echo "------------------------------------------------------------"
cat "${MANIFEST_FILE}"
echo "------------------------------------------------------------"

echo ""
echo "Manifest version:"
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
# 最终检查
# ============================================================

echo ""
echo "============================================================"
echo " Final verification"
echo "============================================================"

# ------------------------------------------------------------
# VERSION
# ------------------------------------------------------------

echo ""
echo "===== VERSION ====="

if [ ! -f "${VERSION_FILE}" ]; then
    echo "ERROR: app/VERSION not found"
    exit 1
fi

APP_VERSION="$(
    tr -d '[:space:]' < "${VERSION_FILE}"
)"

echo "Expected: ${LLAMA_CPP_VER}"
echo "Actual:   ${APP_VERSION}"

if [ "${APP_VERSION}" != "${LLAMA_CPP_VER}" ]; then
    echo "ERROR: app/VERSION mismatch"
    exit 1
fi

echo "OK"

# ------------------------------------------------------------
# manifest
# ------------------------------------------------------------

echo ""
echo "===== MANIFEST ====="

if [ ! -f "${MANIFEST_FILE}" ]; then
    echo "ERROR: app/manifest not found"
    exit 1
fi

echo "OK"

# ------------------------------------------------------------
# x64
# ------------------------------------------------------------

echo ""
echo "===== x64 Vulkan ====="

if [ ! -f "${BIN_DIR}/x64/llama-server" ]; then
    echo "ERROR: x64 llama-server not found"
    exit 1
fi

if [ ! -f "${BIN_DIR}/x64/libggml-vulkan.so" ]; then
    echo "ERROR: x64 libggml-vulkan.so not found"
    exit 1
fi

echo "llama-server:"
ls -lh "${BIN_DIR}/x64/llama-server"

echo "libggml-vulkan.so:"
ls -lh "${BIN_DIR}/x64/libggml-vulkan.so"

echo "OK"

# ------------------------------------------------------------
# arm64
# ------------------------------------------------------------

echo ""
echo "===== arm64 Vulkan ====="

if [ ! -f "${BIN_DIR}/arm64/llama-server" ]; then
    echo "ERROR: arm64 llama-server not found"
    exit 1
fi

if [ ! -f "${BIN_DIR}/arm64/libggml-vulkan.so" ]; then
    echo "ERROR: arm64 libggml-vulkan.so not found"
    exit 1
fi

echo "llama-server:"
ls -lh "${BIN_DIR}/arm64/llama-server"

echo "libggml-vulkan.so:"
ls -lh "${BIN_DIR}/arm64/libggml-vulkan.so"

echo "OK"

# ------------------------------------------------------------
# WebUI
# ------------------------------------------------------------

echo ""
echo "===== WebUI ====="

if [ ! -f "${WEBUI_DIR}/index.html" ]; then
    echo "ERROR: WebUI index.html not found"
    exit 1
fi

WEBUI_FILE_COUNT="$(
    find "${WEBUI_DIR}" \
        -type f |
    wc -l
)"

echo "WebUI files: ${WEBUI_FILE_COUNT}"
echo "OK"

# ------------------------------------------------------------
# fnpack
# ------------------------------------------------------------

echo ""
echo "===== fnpack ====="

if [ ! -x "${SCRIPT_DIR}/fnpack" ]; then
    echo "ERROR: fnpack not found"
    exit 1
fi

ls -lh "${SCRIPT_DIR}/fnpack"

echo "OK"

# ============================================================
# 最终目录
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
# 完成
# ============================================================

echo ""
echo "============================================================"
echo " Prepare completed successfully"
echo "============================================================"
echo ""
echo "llama.cpp version:"
echo "  ${LLAMA_CPP_VER}"
echo ""
echo "fnpack version:"
echo "  ${FNPACK_VER}"
echo ""
echo "VERSION:"
echo "  ${VERSION_FILE}"
echo ""
echo "Manifest:"
echo "  ${MANIFEST_FILE}"
echo ""
echo "x64:"
echo "  ${BIN_DIR}/x64"
echo ""
echo "arm64:"
echo "  ${BIN_DIR}/arm64"
echo ""
echo "WebUI:"
echo "  ${WEBUI_DIR}"
echo ""
echo "Ready for:"
echo "  ./build.sh"
echo ""

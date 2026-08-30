bash
#!/usr/bin/env bash

# ============================================================
# llama.cpp for fnOS - Build Script
#
# 功能：
#   1. 检查 app/VERSION
#   2. 检查 app/manifest
#   3. 检查 manifest 版本
#   4. 检查 x64 Vulkan
#   5. 检查 arm64 Vulkan
#   6. 检查 WebUI
#   7. 检查 fnpack
#   8. 自动生成应用图标
#   9. 使用 fnpack 打包 FPK
#  10. 自动整理到 dist/
#
# 注意：
#   prepare.sh 必须先执行。
#
#   prepare.sh 会生成：
#
#       app/VERSION
#       app/manifest
#       app/bin/x64/
#       app/bin/arm64/
#       app/webui/
#
# ============================================================

set -euo pipefail

# ============================================================
# 基础路径
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

APP_DIR="${SCRIPT_DIR}/app"
BIN_DIR="${APP_DIR}/bin"
WEBUI_DIR="${APP_DIR}/webui"

VERSION_FILE="${APP_DIR}/VERSION"
MANIFEST_FILE="${APP_DIR}/manifest"

OUTPUT_DIR="${SCRIPT_DIR}/dist"

echo "============================================================"
echo " llama.cpp for fnOS"
echo " FPK Build"
echo "============================================================"
echo ""

# ============================================================
# 读取版本
# ============================================================

echo "[1/8] Checking application version..."
echo ""

if [ ! -f "${VERSION_FILE}" ]; then
    echo "ERROR: app/VERSION not found:"
    echo "${VERSION_FILE}"
    echo ""
    echo "Please run ./prepare.sh first."
    exit 1
fi

LLAMA_CPP_VER="$(tr -d '[:space:]' < "${VERSION_FILE}")"

if [ -z "${LLAMA_CPP_VER}" ]; then
    echo "ERROR: app/VERSION is empty."
    exit 1
fi

if ! printf '%s\n' "${LLAMA_CPP_VER}" | grep -Eq '^b[0-9]+$'; then
    echo "ERROR: invalid llama.cpp version:"
    echo "${LLAMA_CPP_VER}"
    echo ""
    echo "Expected format: bXXXXX"
    exit 1
fi

echo "llama.cpp version: ${LLAMA_CPP_VER}"
echo ""

# ============================================================
# 检查 manifest
# ============================================================

echo "[2/8] Checking manifest..."
echo ""

if [ ! -f "${MANIFEST_FILE}" ]; then
    echo "ERROR: app/manifest not found:"
    echo "${MANIFEST_FILE}"
    echo ""
    echo "Please run ./prepare.sh first."
    exit 1
fi

echo "Manifest:"
echo "${MANIFEST_FILE}"
echo ""

# ============================================================
# 检查 manifest 版本
# ============================================================

MANIFEST_VERSION="$(
    sed -n 's/^version=//p' "${MANIFEST_FILE}" |
    head -n 1 |
    tr -d '\r'
)"

if [ -z "${MANIFEST_VERSION}" ]; then
    echo "ERROR: version= not found in app/manifest"
    echo ""
    cat "${MANIFEST_FILE}"
    exit 1
fi

echo "VERSION file:"
echo "  ${LLAMA_CPP_VER}"

echo "Manifest:"
echo "  ${MANIFEST_VERSION}"
echo ""

if [ "${MANIFEST_VERSION}" != "${LLAMA_CPP_VER}" ]; then
    echo "ERROR: version mismatch!"
    echo ""
    echo "app/VERSION:"
    echo "  ${LLAMA_CPP_VER}"
    echo ""
    echo "app/manifest:"
    echo "  ${MANIFEST_VERSION}"
    echo ""
    echo "Please run ./prepare.sh again."
    exit 1
fi

echo "Manifest version OK."
echo ""

# ============================================================
# 检查 fnpack
# ============================================================

echo "[3/8] Checking fnpack..."
echo ""

FNPACK=""

if [ -x "${SCRIPT_DIR}/fnpack" ]; then
    FNPACK="${SCRIPT_DIR}/fnpack"

elif [ -f "${SCRIPT_DIR}/fnpack.exe" ]; then
    FNPACK="${SCRIPT_DIR}/fnpack.exe"

elif command -v fnpack >/dev/null 2>&1; then
    FNPACK="$(command -v fnpack)"

fi

if [ -z "${FNPACK}" ]; then
    echo "ERROR: fnpack not found."
    echo ""
    echo "Expected one of:"
    echo "  ${SCRIPT_DIR}/fnpack"
    echo "  ${SCRIPT_DIR}/fnpack.exe"
    echo "  fnpack in PATH"
    echo ""
    exit 1
fi

echo "fnpack:"
echo "  ${FNPACK}"
echo ""

# 不使用 fnpack --version
#
# 你当前的 fnpack 不支持：
#
#   fnpack --version
#
# 因此这里只检查 help。
#
if ! "${FNPACK}" --help >/dev/null 2>&1; then
    echo "WARNING: fnpack --help failed."
    echo "Continuing anyway..."
fi

echo "fnpack check completed."
echo ""

# ============================================================
# 检查 x64 Vulkan
# ============================================================

echo "[4/8] Checking x64 Vulkan..."
echo ""

X64_DIR="${BIN_DIR}/x64"

if [ ! -d "${X64_DIR}" ]; then
    echo "ERROR: x64 directory not found:"
    echo "${X64_DIR}"
    echo ""
    exit 1
fi

if [ ! -f "${X64_DIR}/llama-server" ]; then
    echo "ERROR: x64 llama-server not found:"
    echo "${X64_DIR}/llama-server"
    exit 1
fi

if [ ! -f "${X64_DIR}/libggml-vulkan.so" ]; then
    echo "ERROR: x64 libggml-vulkan.so not found:"
    echo "${X64_DIR}/libggml-vulkan.so"
    exit 1
fi

chmod +x "${X64_DIR}/llama-server" || true

echo "x64 llama-server:"
ls -lh "${X64_DIR}/llama-server"

echo ""

echo "x64 Vulkan library:"
ls -lh "${X64_DIR}/libggml-vulkan.so"

echo ""
echo "x64 Vulkan check OK."
echo ""

# ============================================================
# 检查 arm64 Vulkan
# ============================================================

echo "[5/8] Checking arm64 Vulkan..."
echo ""

ARM64_DIR="${BIN_DIR}/arm64"

if [ ! -d "${ARM64_DIR}" ]; then
    echo "ERROR: arm64 directory not found:"
    echo "${ARM64_DIR}"
    echo ""
    exit 1
fi

if [ ! -f "${ARM64_DIR}/llama-server" ]; then
    echo "ERROR: arm64 llama-server not found:"
    echo "${ARM64_DIR}/llama-server"
    exit 1
fi

if [ ! -f "${ARM64_DIR}/libggml-vulkan.so" ]; then
    echo "ERROR: arm64 libggml-vulkan.so not found:"
    echo "${ARM64_DIR}/libggml-vulkan.so"
    exit 1
fi

chmod +x "${ARM64_DIR}/llama-server" || true

echo "arm64 llama-server:"
ls -lh "${ARM64_DIR}/llama-server"

echo ""

echo "arm64 Vulkan library:"
ls -lh "${ARM64_DIR}/libggml-vulkan.so"

echo ""
echo "arm64 Vulkan check OK."
echo ""

# ============================================================
# 检查 WebUI
# ============================================================

echo "[6/8] Checking WebUI..."
echo ""

if [ ! -d "${WEBUI_DIR}" ]; then
    echo "ERROR: WebUI directory not found:"
    echo "${WEBUI_DIR}"
    exit 1
fi

if [ ! -f "${WEBUI_DIR}/index.html" ]; then
    echo "ERROR: WebUI index.html not found:"
    echo "${WEBUI_DIR}/index.html"
    exit 1
fi

WEBUI_COUNT="$(
    find "${WEBUI_DIR}" -type f | wc -l
)"

echo "WebUI files: ${WEBUI_COUNT}"
echo ""

if [ "${WEBUI_COUNT}" -eq 0 ]; then
    echo "ERROR: WebUI is empty."
    exit 1
fi

echo "WebUI check OK."
echo ""

# ============================================================
# 检查 app 目录
# ============================================================

echo "Checking app structure..."
echo ""

if [ ! -d "${APP_DIR}" ]; then
    echo "ERROR: app directory not found."
    exit 1
fi

echo "Application files:"
find "${APP_DIR}" \
    -maxdepth 2 \
    -type f \
    -print |
sort

echo ""

# ============================================================
# 图标
# ============================================================

echo "[7/8] Checking application icons..."
echo ""

ICON_GENERATOR="${SCRIPT_DIR}/generate_icons.py"

if [ -f "${ICON_GENERATOR}" ]; then

    if [ -f "${SCRIPT_DIR}/ICON_SOURCE.PNG" ] ||
       [ -f "${SCRIPT_DIR}/ICON_SOURCE.png" ] ||
       [ -f "${SCRIPT_DIR}/ICON_SOURCE" ] ||
       [ ! -f "${SCRIPT_DIR}/ICON.PNG" ] ||
       [ ! -f "${SCRIPT_DIR}/ICON_256.PNG" ]; then

        echo "Generating application icons..."

        if ! command -v python3 >/dev/null 2>&1; then
            echo "ERROR: python3 not found."
            exit 1
        fi

        python3 "${ICON_GENERATOR}"

    else

        echo "Icons already exist."
        echo "Skipping icon generation."

    fi

else

    echo "generate_icons.py not found."
    echo "Skipping icon generation."

fi

echo ""

# ============================================================
# 清理旧 FPK
# ============================================================

echo "Cleaning previous build files..."
echo ""

rm -rf "${OUTPUT_DIR}"

mkdir -p "${OUTPUT_DIR}"

find "${SCRIPT_DIR}" \
    -maxdepth 1 \
    -type f \
    -name "*.fpk" \
    -delete

echo "Clean completed."
echo ""

# ============================================================
# fnpack 构建函数
# ============================================================

run_fnpack_build() {

    echo "Running fnpack build..."
    echo ""

    # --------------------------------------------------------
    # Linux fnpack
    # --------------------------------------------------------

    if [ "${FNPACK}" != *.exe ] && [ -x "${FNPACK}" ]; then

        echo "Using native fnpack:"
        echo "${FNPACK}"
        echo ""

        "${FNPACK}" build --directory "${SCRIPT_DIR}"

        return $?

    fi

    # --------------------------------------------------------
    # Windows fnpack.exe
    # --------------------------------------------------------

    if [ -f "${SCRIPT_DIR}/fnpack.exe" ]; then

        echo "Using Windows fnpack.exe"

        # WSL 环境
        if command -v wslpath >/dev/null 2>&1; then

            WIN_DIR="$(wslpath -w "${SCRIPT_DIR}")"

            echo "Windows project path:"
            echo "${WIN_DIR}"
            echo ""

            "${SCRIPT_DIR}/fnpack.exe" \
                build \
                --directory "${WIN_DIR}"

            return $?

        fi

        # Git Bash / MSYS
        "${SCRIPT_DIR}/fnpack.exe" \
            build \
            --directory "${SCRIPT_DIR}"

        return $?

    fi

    # --------------------------------------------------------
    # PATH 中的 fnpack
    # --------------------------------------------------------

    if command -v fnpack >/dev/null 2>&1; then

        echo "Using fnpack from PATH"

        fnpack build --directory "${SCRIPT_DIR}"

        return $?

    fi

    echo "ERROR: Unable to execute fnpack."
    exit 1
}

# ============================================================
# 执行打包
# ============================================================

echo "============================================================"
echo " Building FPK"
echo "============================================================"
echo ""

run_fnpack_build

echo ""

# ============================================================
# 查找 FPK
# ============================================================

echo "[8/8] Collecting FPK..."
echo ""

FPK_FILES=()

while IFS= read -r -d '' file; do
    FPK_FILES+=("${file}")
done < <(
    find "${SCRIPT_DIR}" \
        -maxdepth 1 \
        -type f \
        -name "*.fpk" \
        -print0
)

if [ "${#FPK_FILES[@]}" -eq 0 ]; then

    echo "ERROR: No .fpk file generated."
    echo ""
    echo "Please check the fnpack build output above."
    echo ""

    exit 1

fi

# ============================================================
# 移动 FPK 到 dist
# ============================================================

for file in "${FPK_FILES[@]}"; do

    filename="$(basename "${file}")"

    echo "Moving:"
    echo "  ${filename}"

    mv "${file}" "${OUTPUT_DIR}/${filename}"

done

echo ""

# ============================================================
# 最终检查
# ============================================================

echo "============================================================"
echo " Final verification"
echo "============================================================"
echo ""

FINAL_FPK_COUNT="$(
    find "${OUTPUT_DIR}" \
        -maxdepth 1 \
        -type f \
        -name "*.fpk" |
    wc -l
)"

if [ "${FINAL_FPK_COUNT}" -eq 0 ]; then
    echo "ERROR: No FPK found in dist/"
    exit 1
fi

echo "FPK count: ${FINAL_FPK_COUNT}"
echo ""

echo "Generated FPK:"
find "${OUTPUT_DIR}" \
    -maxdepth 1 \
    -type f \
    -name "*.fpk" \
    -exec ls -lh {} \;

echo ""

# ============================================================
# Build Summary
# ============================================================

echo "============================================================"
echo " Build completed successfully"
echo "============================================================"
echo ""

echo "llama.cpp version:"
echo "  ${LLAMA_CPP_VER}"

echo ""

echo "Manifest version:"
echo "  ${MANIFEST_VERSION}"

echo ""

echo "Architecture:"
echo "  x86_64"
echo "  arm64"

echo ""

echo "Vulkan:"
echo "  x64:   OK"
echo "  arm64: OK"

echo ""

echo "WebUI:"
echo "  ${WEBUI_COUNT} files"

echo ""

echo "FPK:"
echo "  ${OUTPUT_DIR}/"

echo ""

for file in "${OUTPUT_DIR}"/*.fpk; do
    [ -e "${file}" ] || continue
    echo "  $(basename "${file}")"
done

echo ""

echo "============================================================"
echo " Ready"
echo "============================================================"
echo ""


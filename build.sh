```bash
#!/usr/bin/env bash

# ============================================================
# llama.cpp for fnOS - Build Script
#
# 功能：
#
# 1. 自动读取 app/VERSION
# 2. 自动寻找 manifest 模板
# 3. 自动生成 app/manifest
# 4. 强制 manifest version 与 app/VERSION 一致
# 5. 自动替换 __VERSION__
# 6. 防止 VERSION 占位符进入 FPK
# 7. 检查 llama.cpp x64 / arm64 Vulkan
# 8. 检查 WebUI
# 9. 使用 fnpack build 打包
# 10. 自动整理 dist/*.fpk
#
# 示例：
#
# app/VERSION
#     b10696
#
# app/manifest
#     version=b10696
#
# 最终：
#
#     dist/*.fpk
#
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

APP_DIR="${SCRIPT_DIR}/app"
OUTPUT_DIR="${SCRIPT_DIR}/dist"

VERSION_FILE="${APP_DIR}/VERSION"
MANIFEST_FILE="${APP_DIR}/manifest"

echo ""
echo "============================================================"
echo " llama.cpp for fnOS - FPK Build"
echo "============================================================"
echo ""

# ============================================================
# 1. 检查 app
# ============================================================

echo "[1/8] Checking application directory..."

if [ ! -d "${APP_DIR}" ]; then
    echo ""
    echo "ERROR: app directory not found:"
    echo "${APP_DIR}"
    echo ""
    echo "Please run ./prepare.sh first."
    exit 1
fi

echo "OK: ${APP_DIR}"
echo ""

# ============================================================
# 2. 获取版本
# ============================================================

echo "============================================================"
echo " Version"
echo "============================================================"
echo ""

if [ ! -f "${VERSION_FILE}" ]; then
    echo "ERROR: app/VERSION not found:"
    echo "${VERSION_FILE}"
    echo ""
    echo "Please run:"
    echo "  ./prepare.sh"
    exit 1
fi

LLAMA_CPP_VER="$(tr -d '[:space:]' < "${VERSION_FILE}")"

if [ -z "${LLAMA_CPP_VER}" ]; then
    echo "ERROR: app/VERSION is empty."
    exit 1
fi

echo "llama.cpp version:"
echo "${LLAMA_CPP_VER}"

# 只允许 bXXXXX
if ! printf '%s\n' "${LLAMA_CPP_VER}" | grep -Eq '^b[0-9]+$'; then
    echo ""
    echo "ERROR: Invalid llama.cpp version:"
    echo "${LLAMA_CPP_VER}"
    echo ""
    echo "Expected format:"
    echo "  bXXXXX"
    exit 1
fi

echo ""
echo "Version format: OK"
echo ""

# ============================================================
# 3. 查找 manifest
# ============================================================

echo "============================================================"
echo " Manifest"
echo "============================================================"
echo ""

MANIFEST_TEMPLATE=""

# 优先使用项目根目录 manifest
if [ -f "${SCRIPT_DIR}/manifest" ]; then

    MANIFEST_TEMPLATE="${SCRIPT_DIR}/manifest"

# 其次使用 app/manifest
elif [ -f "${APP_DIR}/manifest" ]; then

    MANIFEST_TEMPLATE="${APP_DIR}/manifest"

# config/manifest
elif [ -f "${SCRIPT_DIR}/config/manifest" ]; then

    MANIFEST_TEMPLATE="${SCRIPT_DIR}/config/manifest"

# package/manifest
elif [ -f "${SCRIPT_DIR}/package/manifest" ]; then

    MANIFEST_TEMPLATE="${SCRIPT_DIR}/package/manifest"

fi

if [ -z "${MANIFEST_TEMPLATE}" ]; then

    echo "ERROR: manifest template not found."
    echo ""
    echo "Searched:"
    echo "  ${SCRIPT_DIR}/manifest"
    echo "  ${APP_DIR}/manifest"
    echo "  ${SCRIPT_DIR}/config/manifest"
    echo "  ${SCRIPT_DIR}/package/manifest"
    echo ""
    exit 1

fi

echo "Manifest template:"
echo "${MANIFEST_TEMPLATE}"
echo ""

# ============================================================
# 4. 生成 app/manifest
# ============================================================

echo "Creating app/manifest..."

# 如果模板不是 app/manifest，复制
if [ "${MANIFEST_TEMPLATE}" != "${MANIFEST_FILE}" ]; then
    cp "${MANIFEST_TEMPLATE}" "${MANIFEST_FILE}"
fi

# 处理 CRLF
sed -i 's/\r$//' "${MANIFEST_FILE}"

# ------------------------------------------------------------
# 替换 __VERSION__
# ------------------------------------------------------------

sed -i \
    "s/__VERSION__/${LLAMA_CPP_VER}/g" \
    "${MANIFEST_FILE}"

# ------------------------------------------------------------
# 替换 version=
# ------------------------------------------------------------

if grep -q '^version=' "${MANIFEST_FILE}"; then

    sed -i \
        "s/^version=.*/version=${LLAMA_CPP_VER}/" \
        "${MANIFEST_FILE}"

else

    echo "manifest has no version= field."
    echo "Adding version=${LLAMA_CPP_VER}"

    TEMP_MANIFEST="$(mktemp)"

    {
        echo "version=${LLAMA_CPP_VER}"
        cat "${MANIFEST_FILE}"
    } > "${TEMP_MANIFEST}"

    mv "${TEMP_MANIFEST}" "${MANIFEST_FILE}"

fi

echo ""
echo "app/manifest generated:"
echo "------------------------------------------------------------"
cat "${MANIFEST_FILE}"
echo "------------------------------------------------------------"
echo ""

# ============================================================
# 5. 检查 manifest 版本
# ============================================================

echo "============================================================"
echo " Manifest verification"
echo "============================================================"
echo ""

MANIFEST_VERSION="$(
    sed -n 's/^version=//p' "${MANIFEST_FILE}" |
    head -n 1 |
    tr -d '\r' |
    tr -d '[:space:]'
)"

echo "Expected:"
echo "  ${LLAMA_CPP_VER}"

echo ""
echo "Manifest:"
echo "  ${MANIFEST_VERSION}"

if [ -z "${MANIFEST_VERSION}" ]; then

    echo ""
    echo "ERROR: manifest version is empty."
    exit 1

fi

if [ "${MANIFEST_VERSION}" != "${LLAMA_CPP_VER}" ]; then

    echo ""
    echo "ERROR: manifest version mismatch."
    echo ""
    echo "Expected:"
    echo "  ${LLAMA_CPP_VER}"
    echo ""
    echo "Actual:"
    echo "  ${MANIFEST_VERSION}"
    exit 1

fi

# ------------------------------------------------------------
# 禁止占位符
# ------------------------------------------------------------

if grep -Eq '^version=(VERSION|__VERSION__)$' "${MANIFEST_FILE}"; then

    echo ""
    echo "ERROR: manifest still contains a placeholder:"
    grep '^version=' "${MANIFEST_FILE}" || true
    exit 1

fi

echo ""
echo "Manifest version: OK"
echo ""

# ============================================================
# 6. 检查应用文件
# ============================================================

echo "============================================================"
echo " Application verification"
echo "============================================================"
echo ""

# ------------------------------------------------------------
# VERSION
# ------------------------------------------------------------

echo "[1] app/VERSION"

if [ ! -f "${APP_DIR}/VERSION" ]; then
    echo "ERROR: app/VERSION not found."
    exit 1
fi

echo "  $(cat "${APP_DIR}/VERSION")"
echo "  OK"
echo ""

# ------------------------------------------------------------
# MANIFEST
# ------------------------------------------------------------

echo "[2] app/manifest"

if [ ! -f "${APP_DIR}/manifest" ]; then
    echo "ERROR: app/manifest not found."
    exit 1
fi

echo "  OK"
echo ""

# ------------------------------------------------------------
# x64
# ------------------------------------------------------------

echo "[3] x64 llama-server"

if [ ! -f "${APP_DIR}/bin/x64/llama-server" ]; then
    echo "ERROR: x64 llama-server not found."
    exit 1
fi

ls -lh "${APP_DIR}/bin/x64/llama-server"
echo "  OK"
echo ""

echo "[4] x64 Vulkan"

if [ ! -f "${APP_DIR}/bin/x64/libggml-vulkan.so" ]; then
    echo "ERROR: x64 libggml-vulkan.so not found."
    exit 1
fi

ls -lh "${APP_DIR}/bin/x64/libggml-vulkan.so"
echo "  OK"
echo ""

# ------------------------------------------------------------
# arm64
# ------------------------------------------------------------

echo "[5] arm64 llama-server"

if [ ! -f "${APP_DIR}/bin/arm64/llama-server" ]; then
    echo "ERROR: arm64 llama-server not found."
    exit 1
fi

ls -lh "${APP_DIR}/bin/arm64/llama-server"
echo "  OK"
echo ""

echo "[6] arm64 Vulkan"

if [ ! -f "${APP_DIR}/bin/arm64/libggml-vulkan.so" ]; then
    echo "ERROR: arm64 libggml-vulkan.so not found."
    exit 1
fi

ls -lh "${APP_DIR}/bin/arm64/libggml-vulkan.so"
echo "  OK"
echo ""

# ------------------------------------------------------------
# WebUI
# ------------------------------------------------------------

echo "[7] WebUI"

if [ ! -f "${APP_DIR}/webui/index.html" ]; then
    echo "ERROR: WebUI index.html not found."
    exit 1
fi

echo "  ${APP_DIR}/webui/index.html"
echo "  OK"
echo ""

# ============================================================
# 7. 查找 fnpack
# ============================================================

echo "============================================================"
echo " fnpack"
echo "============================================================"
echo ""

FNPACK_CMD=""

if [ -x "${SCRIPT_DIR}/fnpack" ]; then

    FNPACK_CMD="${SCRIPT_DIR}/fnpack"

elif [ -f "${SCRIPT_DIR}/fnpack.exe" ]; then

    FNPACK_CMD="${SCRIPT_DIR}/fnpack.exe"

elif command -v fnpack >/dev/null 2>&1; then

    FNPACK_CMD="$(command -v fnpack)"

fi

if [ -z "${FNPACK_CMD}" ]; then

    echo "ERROR: fnpack not found."
    echo ""
    echo "Please run ./prepare.sh first."
    exit 1

fi

echo "fnpack:"
echo "${FNPACK_CMD}"
echo ""

# 注意：
# 不执行 fnpack --version
# 因为当前 fnpack 不支持 --version

# ============================================================
# 8. 清理旧构建
# ============================================================

echo "============================================================"
echo " Cleaning old build"
echo "============================================================"
echo ""

rm -rf "${OUTPUT_DIR}"

mkdir -p "${OUTPUT_DIR}"

# 删除项目根目录旧 FPK
find "${SCRIPT_DIR}" \
    -maxdepth 1 \
    -type f \
    -name '*.fpk' \
    -delete

echo "Old build files cleaned."
echo ""

# ============================================================
# 生成图标
# ============================================================

echo "============================================================"
echo " Icons"
echo "============================================================"
echo ""

if [ -f "${SCRIPT_DIR}/generate_icons.py" ]; then

    if [ -f "${SCRIPT_DIR}/ICON_SOURCE.PNG" ] || \
       [ -f "${SCRIPT_DIR}/ICON_SOURCE.png" ] || \
       [ -f "${SCRIPT_DIR}/ICON_SOURCE" ] || \
       [ ! -f "${SCRIPT_DIR}/ICON.PNG" ] || \
       [ ! -f "${SCRIPT_DIR}/ICON_256.PNG" ]; then

        echo "Generating application icons..."

        python3 "${SCRIPT_DIR}/generate_icons.py"

        echo "Icons generated."

    else

        echo "Icons already exist."
        echo "Skipping."

    fi

else

    echo "generate_icons.py not found."
    echo "Skipping icon generation."

fi

echo ""

# ============================================================
# 打包前最终版本检查
# ============================================================

echo "============================================================"
echo " Pre-build version check"
echo "============================================================"
echo ""

FINAL_VERSION="$(
    tr -d '[:space:]' < "${APP_DIR}/VERSION"
)"

FINAL_MANIFEST_VERSION="$(
    sed -n 's/^version=//p' "${APP_DIR}/manifest" |
    head -n 1 |
    tr -d '\r' |
    tr -d '[:space:]'
)"

echo "app/VERSION:"
echo "  ${FINAL_VERSION}"

echo ""
echo "app/manifest:"
echo "  ${FINAL_MANIFEST_VERSION}"

# ------------------------------------------------------------
# VERSION 一致
# ------------------------------------------------------------

if [ "${FINAL_VERSION}" != "${LLAMA_CPP_VER}" ]; then

    echo ""
    echo "ERROR: app/VERSION changed unexpectedly."
    exit 1

fi

# ------------------------------------------------------------
# manifest 一致
# ------------------------------------------------------------

if [ "${FINAL_MANIFEST_VERSION}" != "${LLAMA_CPP_VER}" ]; then

    echo ""
    echo "ERROR: app/manifest version changed unexpectedly."
    exit 1

fi

# ------------------------------------------------------------
# 禁止 VERSION 占位符
# ------------------------------------------------------------

if grep -Eq '^version=(VERSION|__VERSION__)$' "${APP_DIR}/manifest"; then

    echo ""
    echo "ERROR: VERSION placeholder detected."
    echo ""
    grep '^version=' "${APP_DIR}/manifest" || true
    exit 1

fi

echo ""
echo "Pre-build version check: PASS"
echo ""

# ============================================================
# 开始 fnpack build
# ============================================================

echo "============================================================"
echo " Building FPK"
echo "============================================================"
echo ""

cd "${SCRIPT_DIR}"

# ------------------------------------------------------------
# Windows fnpack.exe
# ------------------------------------------------------------

if [[ "${FNPACK_CMD}" == *.exe ]]; then

    echo "Detected Windows fnpack.exe"

    if command -v wslpath >/dev/null 2>&1; then

        WIN_DIR="$(wslpath -w "${SCRIPT_DIR}")"

    else

        # WSL fallback
        if [[ "${SCRIPT_DIR}" =~ ^/mnt/([a-zA-Z])/(.*)$ ]]; then

            DRIVE="${BASH_REMATCH[1]}"
            REST="${BASH_REMATCH[2]}"

            WIN_DIR="${DRIVE^^}:/${REST}"

        else

            echo "ERROR: Unable to convert WSL path:"
            echo "${SCRIPT_DIR}"
            exit 1

        fi

    fi

    echo "Build directory:"
    echo "${WIN_DIR}"
    echo ""

    "${FNPACK_CMD}" \
        build \
        --directory "${WIN_DIR}"

# ------------------------------------------------------------
# Linux fnpack
# ------------------------------------------------------------

else

    echo "Using Linux fnpack"

    "${FNPACK_CMD}" \
        build \
        --directory "${SCRIPT_DIR}"

fi

# ============================================================
# 查找生成的 FPK
# ============================================================

echo ""
echo "============================================================"
echo " Collecting FPK"
echo "============================================================"
echo ""

FPK_FOUND=0

while IFS= read -r -d '' FPK_FILE; do

    FPK_FOUND=1

    FPK_NAME="$(basename "${FPK_FILE}")"

    echo "Generated:"
    echo "  ${FPK_NAME}"

    echo "Size:"
    ls -lh "${FPK_FILE}"

    echo ""

done < <(
    find "${SCRIPT_DIR}" \
        -maxdepth 1 \
        -type f \
        -name '*.fpk' \
        -print0
)

if [ "${FPK_FOUND}" -eq 0 ]; then

    echo "ERROR: No .fpk file generated."
    echo ""
    echo "Project root:"
    ls -lah "${SCRIPT_DIR}"
    exit 1

fi

# ============================================================
# 检查 FPK 文件名
# ============================================================

echo "============================================================"
echo " FPK verification"
echo "============================================================"
echo ""

while IFS= read -r -d '' FPK_FILE; do

    FPK_NAME="$(basename "${FPK_FILE}")"

    echo "Checking:"
    echo "  ${FPK_NAME}"

    # 禁止 VERSION
    if [[ "${FPK_NAME}" == *"VERSION"* ]]; then

        echo ""
        echo "ERROR: FPK filename contains VERSION:"
        echo "${FPK_NAME}"
        exit 1

    fi

    # 禁止 __VERSION__
    if [[ "${FPK_NAME}" == *__VERSION__* ]]; then

        echo ""
        echo "ERROR: FPK filename contains __VERSION__:"
        echo "${FPK_NAME}"
        exit 1

    fi

    echo "  OK"
    echo ""

done < <(
    find "${SCRIPT_DIR}" \
        -maxdepth 1 \
        -type f \
        -name '*.fpk' \
        -print0
)

# ============================================================
# 移动到 dist
# ============================================================

echo "Moving FPK files to dist..."

find "${SCRIPT_DIR}" \
    -maxdepth 1 \
    -type f \
    -name '*.fpk' \
    -exec mv {} "${OUTPUT_DIR}/" \;

echo "Done."
echo ""

# ============================================================
# 最终检查
# ============================================================

echo "============================================================"
echo " Final verification"
echo "============================================================"
echo ""

DIST_COUNT="$(
    find "${OUTPUT_DIR}" \
        -maxdepth 1 \
        -type f \
        -name '*.fpk' |
    wc -l |
    tr -d '[:space:]'
)"

echo "FPK count:"
echo "${DIST_COUNT}"

if [ "${DIST_COUNT}" -eq 0 ]; then

    echo ""
    echo "ERROR: No FPK found in dist."
    exit 1

fi

echo ""
echo "Generated FPK:"
echo ""

find "${OUTPUT_DIR}" \
    -maxdepth 1 \
    -type f \
    -name '*.fpk' \
    -printf '  %f\n' |
sort

echo ""

echo "File sizes:"
echo ""

ls -lh "${OUTPUT_DIR}"/*.fpk

# ============================================================
# 最终版本
# ============================================================

echo ""
echo "============================================================"
echo " Final version"
echo "============================================================"
echo ""

echo "llama.cpp:"
echo "  ${LLAMA_CPP_VER}"

echo ""
echo "app/VERSION:"
echo "  ${FINAL_VERSION}"

echo ""
echo "app/manifest:"
echo "  ${FINAL_MANIFEST_VERSION}"

# ============================================================
# 最终版本必须一致
# ============================================================

if [ "${FINAL_VERSION}" != "${FINAL_MANIFEST_VERSION}" ]; then

    echo ""
    echo "ERROR: FINAL VERSION MISMATCH"
    exit 1

fi

if [ "${FINAL_VERSION}" != "${LLAMA_CPP_VER}" ]; then

    echo ""
    echo "ERROR: FINAL LLAMA VERSION MISMATCH"
    exit 1

fi

# ============================================================
# 完成
# ============================================================

echo ""
echo "============================================================"
echo " BUILD SUCCESS"
echo "============================================================"
echo ""

echo "llama.cpp version:"
echo "  ${LLAMA_CPP_VER}"

echo ""

echo "FPK output:"
echo "  ${OUTPUT_DIR}"

echo ""

for file in "${OUTPUT_DIR}"/*.fpk; do
    echo "  $(basename "${file}")"
done

echo ""
echo "============================================================"
echo " Ready for fnOS installation"
echo "============================================================"
echo ""
```

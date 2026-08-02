#!/bin/bash
# ============================================================
# llama.cpp for fnOS - Build Script
# Uses fnpack to package the app as a .fpk installer
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/dist"

echo "========================================"
echo "  Llama.cpp for fnOS - 打包脚本"
echo "========================================"
echo ""

# ---- Locate fnpack ----
# Priority: ./fnpack.exe (Windows on WSL) > ./fnpack (native) > PATH

# Convert a WSL path (/mnt/c/...) to a Windows path (C:/...)
wsl_to_win() {
    local wsl_path="$1"
    # /mnt/X/... -> X:/...
    local drive="${wsl_path#/mnt/}"
    local first_char="${drive:0:1}"
    local rest="${drive:2}"
    echo "${first_char^^}:/${rest}"
}

run_fnpack() {
    if [ -f "${SCRIPT_DIR}/fnpack.exe" ]; then
        # fnpack.exe is a Windows binary — invoke directly from WSL2
        # (WSL2 can call .exe files natively; just need a Windows path for --directory)
        local win_dir
        win_dir="$(wsl_to_win "${SCRIPT_DIR}")"
        "${SCRIPT_DIR}/fnpack.exe" build --directory "${win_dir}"
    elif [ -f "${SCRIPT_DIR}/fnpack" ]; then
        "${SCRIPT_DIR}/fnpack" build --directory "${SCRIPT_DIR}"
    elif command -v fnpack &>/dev/null; then
        fnpack build --directory "${SCRIPT_DIR}"
    else
        echo "[错误] 找不到 fnpack 命令"
        echo ""
        echo "请先安装 fnpack 工具:"
        echo "  - 在 fnOS 上: fnpack 已预装"
        echo "  - 本地安装: 从 https://developer.fnnas.com/docs/cli/fnpack/ 下载"
        echo "  - 或将 fnpack.exe 放到本目录下"
        echo ""
        echo "或者直接复制项目到 fnOS 设备上运行:"
        echo "  cd /path/to/llama-cpp-fnnas"
        echo "  fnpack build"
        echo ""
        exit 1
    fi
}

# ---- Clean ----
echo "[1/3] 清理旧构建产物..."
rm -rf "${OUTPUT_DIR}"
rm -f "${SCRIPT_DIR}"/*.fpk

# ---- Generate icons ----
# If ICON_256_new.png exists, always regenerate (use custom icon).
# Otherwise only generate if icons are missing.
if [ -f "${SCRIPT_DIR}/ICON_256_new.png" ] || [ -f "${SCRIPT_DIR}/ICON_256_new" ] || \
   [ ! -f "${SCRIPT_DIR}/ICON.PNG" ] || [ ! -f "${SCRIPT_DIR}/ICON_256.PNG" ]; then
    echo "[*] 生成应用图标..."
    python3 "${SCRIPT_DIR}/generate_icons.py"
fi

# ---- Build fpk ----
echo "[2/3] 构建 FPK 安装包..."
cd "${SCRIPT_DIR}"
run_fnpack

# ---- Collect output ----
echo "[3/3] 整理构建产物..."
mkdir -p "${OUTPUT_DIR}"

if ls *.fpk 1>/dev/null 2>&1; then
    mv *.fpk "${OUTPUT_DIR}/"
    echo ""
    echo "========================================"
    echo "  打包完成！"
    echo "========================================"
    echo ""
    echo "安装包位置: ${OUTPUT_DIR}/"
    ls -lh "${OUTPUT_DIR}/"
    echo ""
    echo "安装方法:"
    echo "  1. 将 .fpk 文件传输到飞牛设备"
    echo "  2. 进入 fnOS 桌面 -> 应用中心"
    echo "  3. 点击「手动安装」"
    echo "  4. 选择上传的 .fpk 文件"
    echo ""
    echo "或通过 SSH 安装:"
    echo "  appcenter-cli install-fpk llama-cpp*.fpk"
    echo ""
else
    echo "[错误] 打包失败，未生成 .fpk 文件"
    echo "请检查上述输出中的错误信息"
    exit 1
fi

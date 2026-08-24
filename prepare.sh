#!/bin/bash

# ============================================================
# llama.cpp for fnOS - Prepare Script
# Downloads all external dependencies needed for packaging.
#
# Git repo 只包含源码，以下组件需要从外部下载：
# 1. fnpack — 飞牛官方打包工具
# 2. llama.cpp 二进制 — 预编译的 Vulkan 推理引擎
# 3. WebUI — llama.cpp 内置聊天界面
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ============================================================
# llama.cpp version
#
# 版本由 GitHub Actions build.yml 提供。
# 不再在 prepare.sh 中写死 b10276。
# ============================================================

if [ -z "${LLAMA_CPP_VER:-}" ]; then
    echo "ERROR: LLAMA_CPP_VER is not set."
    echo "Please specify llama.cpp version in GitHub Actions."
    exit 1
fi

FNPACK_VER="${FNPACK_VER:-1.2.3}"

echo "========================================"
echo " Llama.cpp - 依赖下载"
echo "========================================"
echo ""
echo "llama.cpp version: ${LLAMA_CPP_VER}"
echo "fnpack version: ${FNPACK_VER}"
echo ""

# ---- 1. fnpack ----

if [ -f "${SCRIPT_DIR}/fnpack.exe" ] || [ -f "${SCRIPT_DIR}/fnpack" ] || command -v fnpack &>/dev/null; then

echo "[1/3] fnpack: already present, skip"

else

echo "[1/3] Downloading fnpack..."

case "$(uname -s)" in

Linux)

ARCH=$(uname -m)

case "${ARCH}" in
x86_64) FNPACK_BIN="fnpack-${FNPACK_VER}-linux-amd64" ;;
aarch64) FNPACK_BIN="fnpack-${FNPACK_VER}-linux-arm64" ;;
*) echo "Unsupported arch: ${ARCH}"; exit 1 ;;
esac

curl -L --connect-timeout 30 \
-o "${SCRIPT_DIR}/fnpack" \
"https://static2.fnnas.com/fnpack/${FNPACK_BIN}"

chmod +x "${SCRIPT_DIR}/fnpack"

echo " -> fnpack (Linux)"

;;

MINGW*|MSYS*|CYGWIN*)

curl -L --connect-timeout 30 \
-o "${SCRIPT_DIR}/fnpack.exe" \
"https://static2.fnnas.com/fnpack/fnpack-${FNPACK_VER}-windows-amd64"

echo " -> fnpack.exe (Windows)"

;;

*)

echo "WARN: unknown OS, please download fnpack manually"
echo " https://developer.fnnas.com/docs/cli/fnpack/"

;;

esac

fi

# ---- 2. llama.cpp Vulkan binaries ----

RELEASE_URL="https://github.com/ggml-org/llama.cpp/releases/download/${LLAMA_CPP_VER}"

download_bin() {

local arch="$1"
local asset="$2"

local dest="${SCRIPT_DIR}/app/bin/${arch}"

if [ -f "${dest}/llama-server" ] && [ -f "${dest}/libggml-vulkan.so" ]; then

echo "[2/3] llama.cpp ${arch}: already present, skip"

return

fi

echo "[2/3] Downloading llama.cpp ${arch}..."

mkdir -p "${dest}"

local tmp="/tmp/llama-${arch}.tar.gz"

curl -L --connect-timeout 30 \
-o "${tmp}" \
"${RELEASE_URL}/${asset}"

tar xzf "${tmp}" \
--strip-components=1 \
-C "${dest}/" \
2>/dev/null || true

rm -f "${tmp}"

echo " -> $(ls "${dest}" | wc -l) files"

}

download_bin \
"x64" \
"llama-${LLAMA_CPP_VER}-bin-ubuntu-vulkan-x64.tar.gz"

download_bin \
"arm64" \
"llama-${LLAMA_CPP_VER}-bin-ubuntu-vulkan-arm64.tar.gz"

# ---- 3. WebUI ----

if [ -f "${SCRIPT_DIR}/app/webui/index.html" ]; then

echo "[3/3] WebUI: already present, skip"

else

echo "[3/3] Downloading WebUI..."

mkdir -p "${SCRIPT_DIR}/app/webui"

tmp="/tmp/llama-ui.tar.gz"

curl -L --connect-timeout 30 \
-o "${tmp}" \
"${RELEASE_URL}/llama-${LLAMA_CPP_VER}-ui.tar.gz"

tar xzf "${tmp}" \
--strip-components=1 \
-C "${SCRIPT_DIR}/app/webui/" \
2>/dev/null || true

rm -f "${tmp}"

echo " -> $(find "${SCRIPT_DIR}/app/webui" -type f | wc -l) files"

fi

echo ""
echo "========================================"
echo " 依赖下载完成！"
echo "========================================"
echo ""
echo "llama.cpp version: ${LLAMA_CPP_VER}"
echo ""
echo "现在可以运行 ./build.sh 进行打包:"
echo " ./build.sh"
echo ""

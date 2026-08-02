#!/bin/bash
# ============================================================
# llama.cpp Vulkan Build Script
# 在 WSL2 / Linux 上编译带 Vulkan 支持的 llama.cpp 二进制文件
#
# 用法:
#   chmod +x build_vulkan.sh
#   ./build_vulkan.sh
#
# 前置条件 (Ubuntu/Debian):
#   - 基本编译工具链和 Vulkan SDK
#   - 脚本会自动通过 apt 安装缺失的依赖
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="${SCRIPT_DIR}/app/bin/x64"
BUILD_DIR="/tmp/llama-cpp-vulkan-build"
REPO_URL="https://ghfast.top/https://github.com/ggml-org/llama.cpp.git"
# 如果镜像不可用，改回直连: REPO_URL="https://github.com/ggml-org/llama.cpp.git"
# 使用最新的稳定版本 tag，如需特定版本可在此修改
LLAMA_CPP_TAG="master"

echo "========================================"
echo "  llama.cpp Vulkan 编译脚本"
echo "========================================"
echo ""
echo "目标目录: ${TARGET_DIR}"
echo "编译目录: ${BUILD_DIR}"
echo ""

# ---- 检查是否在 Linux 环境 ----
if [ "$(uname -s)" != "Linux" ]; then
    echo "[错误] 此脚本需要在 Linux 环境下运行"
    echo ""
    echo "在 Windows 上，请使用 WSL2:"
    echo "  wsl --install -d Ubuntu"
    echo "  然后在 WSL 中: cd /mnt/c/Users/jeryz/Desktop/fnllama/llama-cpp-fnnas"
    echo "  ./build_vulkan.sh"
    echo ""
    exit 1
fi

# ---- 安装依赖 ----
echo "[1/5] 检查并安装编译依赖..."
PACKAGES="cmake g++ git build-essential libvulkan-dev glslc spirv-headers glslang-tools"
MISSING=""

for pkg in $PACKAGES; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        MISSING="$MISSING $pkg"
    fi
done

if [ -n "$MISSING" ]; then
    echo "需要安装:$MISSING"
    echo ""
    if [ "$(id -u)" -eq 0 ]; then
        apt update
        apt install -y $MISSING
    else
        echo "请使用 sudo 安装依赖:"
        echo "  sudo apt update && sudo apt install -y$MISSING"
        echo ""
        # 尝试使用 sudo
        if command -v sudo &>/dev/null; then
            sudo apt update
            sudo apt install -y $MISSING
        else
            echo "[错误] 无法安装依赖，请手动运行:"
            echo "  apt update && apt install -y$MISSING"
            exit 1
        fi
    fi
else
    echo "所有依赖已安装"
fi

echo ""
echo "依赖检查完成:"
echo "  cmake:   $(cmake --version 2>/dev/null | head -1 || echo 'NOT FOUND')"
echo "  g++:     $(g++ --version 2>/dev/null | head -1 || echo 'NOT FOUND')"
echo "  vulkan:  $(dpkg -s libvulkan-dev 2>/dev/null | grep Version | awk '{print $2}' || echo 'NOT FOUND')"

# ---- 克隆 / 更新源码 ----
echo ""
echo "[2/5] 准备 llama.cpp 源码..."

if [ -d "${BUILD_DIR}/.git" ]; then
    echo "更新已有仓库..."
    cd "${BUILD_DIR}"
    git fetch origin
    git checkout "${LLAMA_CPP_TAG}"
    git pull origin "${LLAMA_CPP_TAG}" 2>/dev/null || true
else
    echo "克隆 llama.cpp (branch: ${LLAMA_CPP_TAG})..."
    rm -rf "${BUILD_DIR}"
    git clone --depth 1 --branch "${LLAMA_CPP_TAG}" "${REPO_URL}" "${BUILD_DIR}"
fi

cd "${BUILD_DIR}"
LLAMA_COMMIT=$(git rev-parse --short HEAD)
echo "当前 commit: ${LLAMA_COMMIT}"

# ---- CMake 配置 ----
echo ""
echo "[3/5] CMake 配置 (Vulkan ON)..."

rm -rf build
mkdir -p build
cd build

cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_VULKAN=ON \
    -DGGML_NATIVE=OFF \
    -DGGML_CUDA=OFF \
    -DGGML_OPENMP=ON \
    -DGGML_BLAS=OFF \
    -DGGML_RPC=ON

echo ""
echo "CMake 配置完成"

# ---- 编译 ----
echo ""
echo "[4/5] 编译中 (使用所有 CPU 核心)..."

cmake --build . --config Release -j"$(nproc)" --target llama-server llama-cli llama ggml-rpc-server llama-bench llama-batched-bench llama-perplexity llama-quantize llama-tokenize llama-llava-cli llama-gemma3-cli llama-minicpmv-cli llama-qwen2vl-cli llama-mtmd-cli llama-imatrix llama-gguf-split llama-tts llama-completion llama-fit-params llama-debug-template-parser llama-results llama-template-analysis llama-mtmd-debug 2>&1 || {
    echo ""
    echo "[警告] 部分 target 编译失败，尝试逐个编译核心 target..."
    cmake --build . --config Release -j"$(nproc)" --target llama-server
    cmake --build . --config Release -j"$(nproc)" --target llama-cli
}

echo ""
echo "编译完成"

# ---- 复制二进制文件 ----
echo ""
echo "[5/5] 复制二进制文件到打包目录..."

mkdir -p "${TARGET_DIR}"

# 复制所有 .so 文件（包括 ggml-vulkan.so）
echo "复制共享库 (.so)..."
find bin -maxdepth 1 -name "*.so*" -type f | while read -r f; do
    cp -v "$f" "${TARGET_DIR}/" 2>/dev/null || true
done

# 如果 ggml-vulkan.so 不在 bin/ 下，尝试在 lib/ 或其他位置查找
if [ ! -f "bin/ggml-vulkan.so" ]; then
    VULKAN_SO=$(find . -name "ggml-vulkan.so" -type f 2>/dev/null | head -1)
    if [ -n "${VULKAN_SO}" ]; then
        cp -v "${VULKAN_SO}" "${TARGET_DIR}/"
    else
        echo "[警告] 找不到 ggml-vulkan.so，请确认 Vulkan 编译是否成功"
    fi
fi

# 复制可执行文件
echo "复制可执行文件..."
for bin in llama-server llama-cli llama ggml-rpc-server \
    llama-bench llama-batched-bench llama-perplexity llama-quantize \
    llama-tokenize llama-llava-cli llama-gemma3-cli llama-minicpmv-cli \
    llama-qwen2vl-cli llama-mtmd-cli llama-imatrix llama-gguf-split \
    llama-tts llama-completion llama-fit-params \
    llama-debug-template-parser llama-results llama-template-analysis \
    llama-mtmd-debug; do
    if [ -f "bin/${bin}" ]; then
        cp -v "bin/${bin}" "${TARGET_DIR}/"
    fi
done

# 复制 LICENSE
if [ -f "${BUILD_DIR}/LICENSE" ]; then
    cp -v "${BUILD_DIR}/LICENSE" "${TARGET_DIR}/LICENSE"
fi

# 清理旧的无用 .so 文件（如果旧版本有，新版本没有的）
echo ""
echo "复制完成！"

# ---- 输出摘要 ----
echo ""
echo "========================================"
echo "  编译完成！"
echo "========================================"
echo ""
echo "llama.cpp commit: ${LLAMA_COMMIT}"
echo "目标目录: ${TARGET_DIR}"
echo ""
echo "Vulkan 相关文件:"
ls -lh "${TARGET_DIR}/ggml-vulkan.so" 2>/dev/null || echo "  [警告] ggml-vulkan.so 未找到!"
echo ""
echo "关键二进制:"
ls -lh "${TARGET_DIR}/llama-server" "${TARGET_DIR}/libggml.so"* "${TARGET_DIR}/libllama.so"* 2>/dev/null || true
echo ""
echo "下一步:"
echo "  1. 将项目复制到飞牛设备"
echo "  2. 在飞牛上确保安装了 Vulkan 运行时:"
echo "     sudo apt install libvulkan1 mesa-vulkan-drivers"
echo "  3. 运行 ./build.sh 打包为 .fpk"
echo "  4. 安装时在「Extra arguments」中填入: -ngl 99"
echo "     (99 表示将所有层 offload 到 GPU)"
echo ""
echo "注意: 如果 NAS 没有显卡或 Vulkan 驱动，"
echo "       llama-server 仍可回退到纯 CPU 模式运行"
echo ""

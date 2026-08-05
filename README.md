# Llama.cpp for fnOS (飞牛)

高性能本地大语言模型推理服务，为飞牛 fnOS 量身打造的原生应用。

## 功能特性

- **本地推理** — 数据不出设备，完全离线运行
- **GPU 加速** — 支持 Vulkan 核显/独显加速推理 (Intel / AMD / NVIDIA)
- **Web 聊天界面** — 内置精美的聊天 UI，支持多轮对话
- **OpenAI 兼容 API** — 可作为 ChatGPT 替代后端
- **多模型支持** — 支持动态模型加载和切换
- **飞牛原生体验** — 桌面图标一键打开弹窗式界面
- **统一网关访问** — 走飞牛系统域名，内外网通用，无需额外开端口
- **纯原生应用** — 非 Docker，资源占用更低

## 目录结构

> **注意**：Git 仓库只包含源码和配置。`app/bin/`、`app/webui/` 和 `fnpack` 需要另外下载，见下方快速开始说明。

```
llama-cpp-fnnas/
├── manifest              # 应用元数据
├── ICON_SOURCE.PNG       # 自定义图标源 (256x256) — 支持替换
├── ICON.PNG              # 64x64 图标 (由 generate_icons.py 自动生成)
├── ICON_256.PNG          # 256x256 图标 (由 generate_icons.py 自动生成)
├── LICENSE               # 开源协议
├── prepare.sh            # 依赖下载脚本 (拉代码后先跑这个)
├── build.sh              # fnpack 打包脚本 (自动生成图标 + 打包)
├── build_vulkan.sh       # WSL/Linux Vulkan 编译脚本
├── generate_icons.py     # 图标生成脚本 (从 ICON_SOURCE.PNG 或程序化生成)
├── app/
│   ├── bin/              # [需下载] llama.cpp 二进制 (x64 + arm64)
│   ├── webui/            # [需下载] llama.cpp Web 聊天界面
│   └── ui/
│       ├── config         # 应用入口配置 (iframe 弹窗)
│       └── images/        # UI 图标资源 (自动生成)
├── cmd/
│   ├── main               # 主控脚本 (start/stop/status)
│   ├── install_init       # 安装初始化
│   ├── install_callback   # 安装回调
│   ├── uninstall_init     # 卸载初始化
│   ├── uninstall_callback # 卸载回调
│   ├── upgrade_init       # 升级初始化
│   ├── upgrade_callback   # 升级回调
│   ├── config_init        # 配置变更初始化
│   └── config_callback    # 配置变更回调
├── config/
│   ├── privilege          # 权限声明
│   └── resource           # 资源声明
└── wizard/
    ├── install            # 安装向导表单
    ├── config             # 配置向导表单
    └── uninstall          # 卸载向导表单
```

## 快速开始

### 前置准备：下载依赖（仅首次）

> 从 GitHub 拉下来的代码只包含源码和配置，缺少二进制和 WebUI。运行 `prepare.sh` 自动下载。

```bash
# 首次克隆后执行一次即可
chmod +x prepare.sh
./prepare.sh
```

该脚本会自动下载：
- **fnpack** — 飞牛官方打包工具
- **llama.cpp 二进制** — 预编译的 Vulkan 推理引擎 (x64 + arm64)
- **WebUI** — llama.cpp 内置聊天界面

### 方式一：在 fnOS 上直接打包

```bash
# SSH 登录飞牛设备，将项目目录复制到设备上
scp -r llama-cpp-fnnas fnos@<ip>:/tmp/

# 在飞牛设备上打包
cd /tmp/llama-cpp-fnnas
fnpack build

# 安装生成的 .fpk 文件
appcenter-cli install-fpk *.fpk
```

### 方式二：本地打包后上传

```bash
# 本地打包（需要安装 fnpack CLI 工具）
./build.sh

# 将 dist/ 目录下的 .fpk 文件上传到飞牛设备
# 然后通过 应用中心 -> 手动安装 进行安装
```

### 方式三：开发模式直接运行

```bash
# 在飞牛设备上，进入项目目录
cd /path/to/llama-cpp-fnnas

# 以开发模式安装
appcenter-cli install-local
```

## 访问方式：统一网关

本应用通过飞牛 **统一网关** 对外提供服务，而非独占端口：

- llama-server 监听一个本地 **Unix Socket**（`${TRIM_APPDEST}/app.sock`），不直接暴露 TCP 端口
- 飞牛把系统域名下的 `/app/llama-cpp/` 路径，在**校验 NAS 登录态后**转发到该 socket
- 因此无论内网还是公网，都通过飞牛系统域名访问（走系统已开放的 443 端口），**无需在防火墙为应用单独开端口**

```
浏览器 → https://<飞牛访问域名>/app/llama-cpp/  (443, 已开放)
   → 飞牛网关校验登录态
   → 转发到 ${TRIM_APPDEST}/app.sock (本地 Unix Socket)
   → llama-server (带 /app/llama-cpp 前缀)
```

> 桌面入口的 `app/ui/config` 中 `url` 字段必须以 `/` 结尾（即 `/app/llama-cpp/`），否则会 404。

## 配置说明

安装过程中可通过向导设置：

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| 模型目录 | .gguf 模型文件的存放路径 | 自动选择 |
| 额外参数 | llama-server 的附加启动参数 | 无 |

安装后可在应用设置中随时修改配置。

## GPU 加速 (Vulkan)

本应用内置了 Vulkan 后端支持，可利用 Intel 核显、AMD 独显或 NVIDIA 显卡加速大模型推理。

> ⚠️ **CPU 模式无需任何依赖**：如果 NAS 未安装 Vulkan，应用**自动以 CPU 模式运行**，无需任何额外操作。GPU 加速是可选优化，不是必需。

### NAS 端前置条件

GPU 加速需要在飞牛设备上安装 Vulkan 运行库和显卡驱动。**安装 Vulkan 驱动需要 root 权限，无法通过应用自动安装**，需要用户在 NAS 上手动执行以下命令。

```bash
# Debian / Ubuntu 系 (fnOS)

# Intel / AMD GPU (绝大多数 NAS 核显或 AMD 独显)
sudo apt update
sudo apt install -y libvulkan1 mesa-vulkan-drivers

# NVIDIA GPU
sudo apt update
sudo apt install -y libvulkan1 nvidia-driver
```

### 自动检测

应用安装时会自动检测系统 Vulkan 环境：

- **Vulkan 运行库 + 驱动均已安装** → GPU 加速可用，安装日志提示"GPU 加速可用"。
- **Vulkan 运行库缺失** → 安装日志提示安装命令，应用以 CPU 模式运行。
- **驱动缺失** → 安装日志提示安装 GPU 驱动，应用以 CPU 模式运行。
- **未检测到 GPU 设备** → 应用以 CPU 模式运行，无需任何操作。

### GPU 设备权限

GPU 设备（`/dev/dri/renderD128` 等）通常属 `render` 组，应用用户必须在该组才能访问。

本应用通过 `config/privilege` 的 `join-groups` 字段声明 `["video", "render"]`，飞牛 fnOS 在安装时由框架（root 权限）自动把应用用户加入这两个组。无需手动加组，也无需重启应用——框架建用户时即带组，首次启动 llama-server 便能访问 GPU。（卸载时框架不会自动移除这些组，应用用户残留属 fnOS 常态，无害，且重装时复用。）

若仍遇到权限问题，手动排查：

```bash
# 查看进程实际拥有的组（关键）
PID=$(cat /vol1/@appdata/llama-cpp/llama-server.pid)
cat /proc/$PID/status | grep Groups

# 查看应用用户与组
id $(stat -c '%U' /vol1/@appcenter/llama-cpp/)

# 查看设备属主
ls -l /dev/dri/renderD*
```

> 进程的 `Groups` 需包含 `render` 对应的 gid，才能读取 `/dev/dri/renderD*`。

### 启用 GPU 加速

1. 安装应用时，在向导的「Extra arguments」中填入 `-ngl 99`
2. 或者在安装后，进入应用设置 -> 修改「Extra arguments」为 `-ngl 99`
3. 重启应用生效

> **`-ngl` 参数说明**: 表示 offload 到 GPU 的模型层数。
> - `-ngl 99` = 将所有层 offload 到 GPU（推荐，如果显存够用）
> - `-ngl 0` = 纯 CPU 模式（默认）
> - 可根据模型大小和显存调整，如 `-ngl 20` 部分 offload

### 验证 GPU 是否生效

启动后查看日志：
```bash
cat /vol1/@appdata/llama-cpp/logs/server.log | grep -i vulkan
```

如果看到类似 `ggml_vulkan: ...` 的输出，说明 GPU 加速已启用。

## 使用说明

1. 安装完成后，飞牛桌面会出现 Llama.cpp 图标
2. 将 `.gguf` 格式的模型文件放入模型目录（默认为飞牛文件管理器中的共享文件夹 `llama-cpp/models`，也可在安装向导里自定义）
3. 在应用中心启动 Llama.cpp 服务
4. 点击桌面图标打开 AI 聊天窗口（弹窗模式）
5. 也可直接访问 `https://<飞牛访问域名>/app/llama-cpp/`（内网外网同一入口，需登录飞牛账号）

## 模型下载

推荐的 GGUF 模型下载源：

- [HuggingFace GGUF Models](https://huggingface.co/models?library=gguf)
- [Qwen 系列中文模型](https://huggingface.co/Qwen)
- [Llama 系列模型](https://huggingface.co/meta-llama)

## API 使用

llama.cpp server 提供兼容 OpenAI Chat Completions 的 API，通过统一网关前缀 `/app/llama-cpp` 访问：

```bash
curl https://<飞牛访问域名>/app/llama-cpp/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "your-model",
    "messages": [
      {"role": "user", "content": "你好！"}
    ]
  }'
```

> API 同样走统一网关（带 `/app/llama-cpp` 前缀），需先登录飞牛账号或带有效的会话 Cookie。

## 技术架构

- **推理引擎**: [llama.cpp](https://github.com/ggml-org/llama.cpp)
- **Web UI**: llama.cpp 内置 SvelteKit 界面
- **访问接入**: 飞牛统一网关（Unix Socket + `--api-prefix`，无需开端口）
- **打包工具**: fnpack (飞牛官方 CLI)
- **运行环境**: fnOS 原生环境（非 Docker）

> llama-server 通过 `--host /path/to/app.sock`（host 以 `.sock` 结尾即自动切 AF_UNIX）监听 Unix Socket，
> 并用 `--api-prefix /app/llama-cpp` 让所有路由与静态资源带前缀，与飞牛网关转发的路径对齐。

## 从源码编译 (Vulkan)

如果需要自行编译带 Vulkan 支持的 llama.cpp 二进制文件：

### Windows (WSL2)

```bash
# 1. 安装 WSL2 Ubuntu (一次性)
wsl --install -d Ubuntu

# 2. 进入 WSL，运行编译脚本
cd /path/to/llama-cpp-fnnas
chmod +x build_vulkan.sh
./build_vulkan.sh
```

### Linux / fnOS

```bash
# 直接在飞牛设备上编译
cd /path/to/llama-cpp-fnnas
chmod +x build_vulkan.sh
./build_vulkan.sh
```

编译完成后运行 `./build.sh` 打包为 .fpk 安装包。

## 更新说明

### v1.1.0 — 规范化整改（对照飞牛官方开发者文档）

按 [飞牛应用开放平台开发者文档](https://developer.fnnas.com/docs/core-concepts/privilege) 规范，重构了权限与资源声明：

- **GPU 组权限**：改用 `config/privilege` 的 `join-groups: ["video","render"]`，由飞牛框架在安装时以 root 自动加入应用用户。移除了 `install_callback`/`uninstall_callback` 里手写的 `usermod`/`gpasswd`（callback 以非 root 包用户运行，这些命令必然失败）。
- **模型目录**：改用 `config/resource` 的 `data-share` 声明共享文件夹 `llama-cpp/models`，用户可在飞牛文件管理器中直接拖入 `.gguf` 模型，无需 SSH。修正了原先 `config/resource` 错误的顶层结构。
- **manifest**：声明 `checkport=false`（统一网关应用无服务端口），补充 `changelog`。
- **优雅停止**：`cmd/main` 的 stop 改为 SIGTERM → 等待 10s → SIGKILL，避免强杀导致模型状态未保存。
- **向导**：安装向导补充说明 tips，`-ngl 99` 作为默认值，降低首次使用门槛。
- **错误可观测性**：启动失败时写入 `TRIM_TEMP_LOGFILE`，应用中心可见错误信息。

## License

MIT License — 详见 [LICENSE](LICENSE) 文件。

llama.cpp 本身使用 MIT 协议，版权归 ggml.ai 及贡献者所有。

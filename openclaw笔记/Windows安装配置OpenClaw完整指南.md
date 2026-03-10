# Windows 安装配置 OpenClaw 完整指南（从零开始）

> 本笔记基于 [OpenClaw 官方文档](https://docs.openclaw.ai/install)，记录在 Windows 上通过 WSL2 安装和配置 OpenClaw 的完整流程。
> OpenClaw 是一个开源、自托管的 AI 代理，可以执行实际任务（收发邮件、浏览网页、管理文件、运行命令等），通过 WhatsApp / Telegram / Discord / 飞书等通讯应用与你交互。

---

## 一、前置要求

| 项目 | 要求 |
|------|------|
| 操作系统 | Windows 10（版本 1903+）或 Windows 11 |
| 内存 | 建议 ≥ 8GB RAM（跑本地模型建议 ≥ 16GB） |
| 磁盘 | ≥ 10GB 可用空间 |
| BIOS | 虚拟化已启用（VT-x / AMD-V） |
| API Key | 至少一个 LLM 提供商的 Key（如 Anthropic / OpenAI / Google / DeepSeek），也可以用本地模型 |

> [!important] 官方文档地址：https://docs.openclaw.ai/install ，安装过程中遇到问题可以先去查阅。

---

## 二、安装 WSL2

OpenClaw 官方明确要求 Windows 用户通过 [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install) 运行。

### 2.1 确认虚拟化已开启

`Ctrl + Shift + Esc` → 任务管理器 → 性能 → CPU → 查看右下角 **"虚拟化：已启用"**

![[Pasted image 20260310201207.png]]

如果显示"已禁用"，需要进 BIOS 开启：
- 重启电脑，按 `Del` / `F2` / `F10`（取决于主板品牌）进入 BIOS
- 找到 `Intel VT-x` 或 `AMD-V`（也可能叫 `SVM Mode`）
- 设为 **Enabled** → 保存退出

### 2.2 安装 WSL2

以**管理员身份**打开 PowerShell（右键开始菜单 → "终端(管理员)"）：

```powershell
wsl --install

# 或者先看可用发行版
wsl --list --online
# 指定装 Ubuntu 24.04
wsl --install -d Ubuntu-24.04
```

`wsl --install` 会一次性完成以下操作：
- 启用 WSL 功能和"虚拟机平台"组件
- 下载并安装 Linux 内核
- 将 WSL 2 设置为默认版本
- 下载并安装 Ubuntu（默认发行版）

安装完成后**重启电脑**。

### 2.3 首次配置 Ubuntu

重启后 Ubuntu 会自动打开（或从开始菜单搜索 "Ubuntu" 打开）：

1. 等待初始化完成（可能需要几分钟）
2. 输入用户名（纯英文小写，如 `openclaw`）
3. 输入密码（**输入时不会显示任何字符，这是正常的 Linux 行为**），输入两次确认

> [!warning] 牢记此密码！后续 `sudo` 命令都需要输入。

### 2.4 验证 WSL2

在 **Windows PowerShell** 中运行：

```powershell
wsl --list --verbose
```

确认 VERSION 列为 **2**：

```
  NAME      STATE           VERSION
* Ubuntu    Running         2
```

如果 VERSION 显示 1，执行转换：

```powershell
wsl --set-version Ubuntu 2
wsl --set-default-version 2
```

> [!NOTE] 📸 **请在此截图**：`wsl --list --verbose` 的输出。

---

## 三、配置 WSL2 Ubuntu 环境

以下命令都在 **Ubuntu 终端**中执行。

### 3.1 更新系统软件包

```bash
sudo apt update && sudo apt upgrade -y
```

> 如果弹出紫色/蓝色界面问 `What do you want to do about modified configuration files?`，选择 **keep the local version currently installed**，直接按回车。

### 3.2 安装基础工具

```bash
sudo apt install -y build-essential curl wget unzip software-properties-common
```

### 3.3 启用 systemd（重要！）

OpenClaw 的后台 daemon 服务在 WSL2 上依赖 systemd（`--install-daemon` 会配置 systemd user unit）。

编辑 WSL 配置文件：

```bash
sudo nano /etc/wsl.conf
```

添加以下内容（如果文件已有内容，在末尾追加）：

```ini
[boot]
systemd=true
```

保存退出：`Ctrl+O` → 回车确认 → `Ctrl+X` 退出

在 **Windows PowerShell** 中重启 WSL：

```powershell
wsl --shutdown
```

重新打开 Ubuntu 终端，验证 systemd 是否启用：

```bash
systemctl list-unit-files --type=service | head -20
```

能看到一列 service 列表即表示成功。

> [!NOTE] 📸 **请在此截图**：systemctl 命令的输出，证明 systemd 已启用。

---

## 四、安装 Node.js（v22+）

OpenClaw 官方要求 **Node.js 22 或更高版本**。推荐用 nvm（Node Version Manager）安装管理。

> [!tip] 如果你使用方式 A（官方一键脚本）安装 OpenClaw，脚本会检测并自动安装 Node.js，可以跳过此步。但建议还是手动装好 nvm 来管理版本。

### 4.1 安装 nvm

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
```

安装完成后重新加载配置：

```bash
source ~/.bashrc
```

验证：

```bash
nvm --version
# 应显示 0.40.1
```

### 4.2 安装 Node.js 22

```bash
nvm install 22
nvm alias default 22
```

### 4.3 验证

```bash
node --version   # 应显示 v22.x.x
npm --version    # 应显示 10.x.x
```

> [!NOTE] 📸 **请在此截图**：`node --version` 和 `npm --version` 的输出。

---

## 五、安装 Git

```bash
sudo apt install -y git
git --version   # 应显示 git version 2.x.x
```

可选：配置 Git 身份信息

```bash
git config --global user.name "你的名字"
git config --global user.email "你的邮箱"
```

---

## 六、安装 Docker Desktop（可选）

> [!tip] Docker **不是** OpenClaw 的必须依赖。部分插件和高级功能会用到 Docker，建议安装但可以后续再装。

### 6.1 下载安装

1. 下载 [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/)
2. 运行 `Docker Desktop Installer.exe`
3. 安装选项界面需要关注的选项：

| 选项 | 选择 | 说明 |
|------|------|------|
| Use WSL 2 instead of Hyper-V | ✅ 勾选 | **必须勾选**，让 Docker 使用 WSL 2 引擎 |
| Add shortcut to desktop | ✅ 可选 | 方便从桌面启动 |

> [!NOTE] 📸 **请在此截图**：安装选项界面，确认 WSL 2 已勾选。

4. 点击 **OK** → 等待安装 → **Close and restart** 重启电脑

### 6.2 首次启动

重启后打开 Docker Desktop：
1. 弹出服务协议 → 勾选 "I accept the terms" → **Accept**
2. 提示 Docker Hub 登录 → 可以 **Skip** 跳过
3. Welcome Survey 问卷 → 可以 **Skip** 跳过

### 6.3 配置 WSL2 集成

点击 Docker Desktop 右上角 ⚙️ Settings：

1. **General** → 确认 `Use the WSL 2 based engine` 已勾选 ✅
2. **Resources → WSL Integration** → 开启 "Enable integration with my default WSL distro" ✅ → 找到 Ubuntu 发行版打开开关 → **Apply & Restart**

> [!NOTE] 📸 **请在此截图**：WSL Integration 页面，Ubuntu 开关已打开。

### 6.4 验证

在 Ubuntu 终端中：

```bash
docker --version
docker run hello-world
```

看到 `Hello from Docker!` 即表示 Docker 配置成功。

---

## 七、安装 OpenClaw

以下操作在 **Ubuntu 终端**中执行。有以下几种安装方式，推荐方式 A。

### 方式 A：官方一键安装脚本（推荐）

```bash
curl -fsSL https://openclaw.ai/install.sh | bash
```

此脚本会自动：
- 检测 Node.js 版本，缺失时自动安装
- 安装 OpenClaw
- 启动 onboarding 交互式配置向导
- 安装后台 daemon 服务

> 如果只想安装不立即配置，加 `--no-onboard` 参数：
> ```bash
> curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard
> ```

### 方式 B：npm 手动安装

```bash
npm install -g openclaw@latest
openclaw onboard --install-daemon
```

> [!warning] 注意：这是**两条命令**，不是一条。先安装再配置。

### 方式 C：pnpm 安装

```bash
pnpm add -g openclaw@latest
pnpm approve-builds -g    # 批准 openclaw、sharp、node-llama-cpp 等构建
openclaw onboard --install-daemon
```

### 方式 D：从源码构建（高级）

```bash
git clone https://github.com/openclaw/openclaw.git
cd openclaw
pnpm install
pnpm ui:build
pnpm build
pnpm link --global
openclaw onboard --install-daemon
```

### 验证安装

```bash
openclaw --version
```

> [!NOTE] 📸 **请在此截图**：`openclaw --version` 的输出。

### 常见安装问题

**问题 1：`openclaw` 命令找不到（command not found）**

```bash
# 诊断 PATH
node -v
npm -v
npm prefix -g
echo "$PATH"

# 修复：将 npm 全局 bin 目录加入 PATH
echo 'export PATH="$(npm prefix -g)/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

**问题 2：`sharp` 构建报错**

```bash
# 方案 1：忽略全局 libvips
SHARP_IGNORE_GLOBAL_LIBVIPS=1 npm install -g openclaw@latest

# 方案 2：安装 node-gyp
npm install -g node-gyp
```

**问题 3：npm 权限错误**

```bash
# 方案 1：使用 sudo
sudo npm install -g openclaw@latest

# 方案 2：修改 npm 全局目录
mkdir ~/.npm-global
npm config set prefix '~/.npm-global'
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
npm install -g openclaw@latest
```

---

## 八、配置 OpenClaw（Onboarding 向导）

如果使用方式 A 安装，onboarding 向导会自动启动。如果使用其他方式安装，或需要重新配置：

```bash
openclaw onboard --install-daemon
```

> `--install-daemon` 参数会将 OpenClaw 安装为 systemd 用户服务（WSL2/Linux），实现后台常驻运行。

向导会依次引导你配置以下内容：

### 8.1 选择 LLM 提供商

```
? Which LLM provider would you like to use?
  ❯ Anthropic (Claude)       ← 推荐，代码执行能力强
    OpenAI (GPT)
    Google (Gemini)           ← 免费额度较多，适合入门
    DeepSeek                  ← 性价比高
    Local (Ollama/LM Studio)  ← 本地模型，不需要 API Key
    Custom API
```

用方向键选择，按 Enter 确认。

> [!NOTE] 📸 **请在此截图**：LLM 提供商选择界面。

### 8.2 输入 API Key

各提供商 API Key 获取地址：

| 提供商 | 获取地址 | 说明 |
|--------|----------|------|
| Anthropic | [console.anthropic.com](https://console.anthropic.com/) | 注册 → API Keys → 创建 |
| OpenAI | [platform.openai.com/api-keys](https://platform.openai.com/api-keys) | 注册 → API Keys → 创建 |
| Google | [aistudio.google.com/apikey](https://aistudio.google.com/apikey) | 直接创建 |
| DeepSeek | [platform.deepseek.com](https://platform.deepseek.com/) | 注册 → 控制台 → 创建 |

> [!warning] API Key 是敏感信息，请妥善保管，不要泄露！

### 8.3 选择默认模型

向导会列出该提供商可用的模型，推荐选择标记 **`recommended`** 的模型（平衡性能和成本）。

> [!NOTE] 📸 **请在此截图**：模型选择界面。

### 8.4 配置消息通道

```
? Would you like to configure a messaging channel now?
  ❯ Yes
    No, I'll do it later
```

**建议选 No**，先确保基础安装正常。后续通过 `openclaw channels add` 随时添加（飞书、Telegram 等）。

### 8.5 其他配置项

向导可能还会询问：
- **工作区路径**（Workspace Location）：OpenClaw 存储工作文件的位置，保持默认即可
- **网关设置**（Gateway Settings）：绑定地址、端口、认证等，保持默认即可
- **时区**：选择 `Asia/Shanghai`
- **技能选择**（Skills）：选择 AI 助手启用的能力，默认全部即可

### 8.6 配置完成

向导完成后，OpenClaw 会自动启动后台 daemon 服务。

> [!NOTE] 📸 **请在此截图**：onboard 向导完成后的输出。

### 8.7 配置文件说明

onboarding 完成后会在 `~/.openclaw/` 目录下生成配置文件：

```
~/.openclaw/
├── openclaw.json    # 主配置文件（模型、时区等）
├── .env             # API Key 等敏感配置
├── workspace/       # 工作区文件
└── logs/            # 日志文件
```

查看配置：

```bash
cat ~/.openclaw/openclaw.json
```

编辑配置：

```bash
openclaw config edit
```

也可以通过命令行管理 API Key：

```bash
# 设置 API Key
openclaw config set ANTHROPIC_API_KEY sk-ant-xxxxxxxxx

# 或直接编辑 .env 文件
nano ~/.openclaw/.env
```

> [!tip] 可以同时配置多个提供商的 API Key，使用时切换不同模型。也可以在 onboard 命令中直接指定 Key：
> ```bash
> openclaw onboard --install-daemon --anthropic-api-key "sk-ant-..."
> ```

---

## 九、启动与验证

### 9.1 查看状态

```bash
openclaw status
```

应显示 Daemon 和 Gateway 状态为 `running`。

> [!NOTE] 📸 **请在此截图**：`openclaw status` 的输出。

### 9.2 健康检查（重要）

```bash
openclaw doctor
```

此命令会检查所有依赖、配置、连接是否正确，输出一份完整的健康报告。有问题的项目会标红提示。

> [!NOTE] 📸 **请在此截图**：`openclaw doctor` 的输出。

### 9.3 Web 控制面板

```bash
openclaw dashboard
```

或在浏览器中访问：`http://localhost:3007`（端口以实际输出为准）

> [!NOTE] 📸 **请在此截图**：OpenClaw Web Dashboard 界面。

### 9.4 命令行对话测试

```bash
openclaw chat
```

发送一条消息（如 "你好"），确认 AI 能正常回复，按 `Ctrl+C` 退出。

### 9.5 查看实时日志

```bash
openclaw logs --follow
```

实时显示运行日志，按 `Ctrl+C` 退出。startup 和 AI 交互的信息都会在这里显示。

### 9.6 启动 / 停止 / 重启

```bash
openclaw start              # 启动
openclaw stop               # 停止
openclaw restart             # 重启
openclaw gateway restart     # 仅重启网关（修改通道配置后需要）
```

---

## 十、常见问题排查

### 安装阶段

| 问题 | 解决方案 |
|------|----------|
| `wsl --install` 无反应 | 确认 PowerShell 以管理员运行 |
| WSL VERSION 显示 1 | `wsl --set-version Ubuntu 2` + `wsl --set-default-version 2` |
| Docker Desktop 启动报错 | 检查 BIOS 虚拟化；管理员运行 `bcdedit /set hypervisorlaunchtype auto` 后重启 |
| `nvm` 命令找不到 | `source ~/.bashrc` 或重开终端 |
| `openclaw` 命令找不到 | 见第七节"常见安装问题"的 PATH 修复方法 |
| `sharp` 构建报错 | 见第七节"常见安装问题" |
| npm 权限错误 | 见第七节"常见安装问题" |

### 配置阶段

| 问题 | 解决方案 |
|------|----------|
| API Key 无效 | 去提供商控制台重新复制 Key，注意不要有多余的空格 |
| 连接 LLM 超时（国内网络） | 配置代理，见下方 |
| `openclaw start` 失败 | 检查 systemd：`systemctl --version`；检查端口冲突 |
| daemon 状态异常 | 查看日志 `openclaw logs` 根据错误信息排查 |

### 完全重置 OpenClaw

如果配置搞乱了想重来：

```bash
openclaw reset --scope full --yes --non-interactive
openclaw onboard --install-daemon
```

### 国内网络代理配置

如果在国内访问 LLM API 有困难，需要配置代理：

```bash
# 编辑 ~/.bashrc，在末尾添加（端口号替换为你实际的代理端口）
nano ~/.bashrc

# 添加以下内容：
export http_proxy="http://127.0.0.1:7890"
export https_proxy="http://127.0.0.1:7890"
export all_proxy="socks5://127.0.0.1:7890"
```

```bash
source ~/.bashrc
```

> `7890` 是 Clash 等代理工具的常见端口号，请替换为你实际使用的端口。

---

## 十一、更新与卸载

### 更新 OpenClaw

```bash
# npm 安装的更新方式
npm install -g openclaw@latest

# 或者重新运行安装脚本
curl -fsSL https://openclaw.ai/install.sh | bash
```

详见官方文档：https://docs.openclaw.ai/install/updating

### 卸载 OpenClaw

详见官方文档：https://docs.openclaw.ai/install/uninstall

---

## 十二、下一步

安装配置完成后，你可以：

1. **接入通讯应用**：`openclaw channels add` 接入飞书、Telegram 等 → 详见 [[openclaw接入飞书]]
2. **安装插件**：`openclaw plugins install <插件名>`
3. **配置多模型**：不同任务可以使用不同的 AI 模型，在性能和成本之间取舍
4. **浏览器自动化**：安装 [OpenClaw Browser Relay](https://docs.openclaw.ai/tools/chrome-extension) Chrome 扩展

---

## 命令速查表

```bash
# ===== WSL 管理 =====
wsl --install                           # 安装 WSL2
wsl --install -d Ubuntu-24.04           # 指定发行版
wsl --list --verbose                    # 查看 WSL 版本
wsl --shutdown                          # 关闭 WSL（用于重启）
wsl --set-default-version 2             # 设 WSL2 为默认

# ===== Node.js =====
nvm install 22                          # 安装 Node.js 22
nvm alias default 22                    # 设为默认
node --version                          # 查看版本

# ===== OpenClaw 安装 =====
curl -fsSL https://openclaw.ai/install.sh | bash  # 一键安装
npm install -g openclaw@latest          # npm 安装
openclaw onboard --install-daemon       # 配置向导 + 安装 daemon
openclaw --version                      # 查看版本

# ===== OpenClaw 运行管理 =====
openclaw start                          # 启动
openclaw stop                           # 停止
openclaw restart                        # 重启
openclaw status                         # 查看状态
openclaw doctor                         # 健康检查
openclaw logs --follow                  # 实时日志

# ===== OpenClaw 使用 =====
openclaw chat                           # 命令行对话
openclaw dashboard                      # Web 控制面板

# ===== OpenClaw 配置 =====
openclaw config edit                    # 编辑配置文件
openclaw config set <KEY> <VALUE>       # 设置配置项
openclaw channels add                   # 添加消息通道
openclaw channels list                  # 列出已有通道
openclaw gateway restart                # 重启网关

# ===== OpenClaw 插件 =====
openclaw plugins list                   # 列出已安装插件
openclaw plugins install <名称>         # 安装插件

# ===== OpenClaw 维护 =====
openclaw reset --scope full --yes --non-interactive  # 完全重置
npm install -g openclaw@latest          # 更新
```

---

> 📝 最后更新：2026-03-10
> 📖 官方文档：https://docs.openclaw.ai

# Windows 安装配置 OpenClaw 完整指南（从零开始）

> 本笔记从零开始，详细记录在 Windows 系统上通过 WSL2 安装和配置 OpenClaw 的完整过程。
> 包括每一步的选择说明和需要截图的地方。

---

## 📋 目录

- [一、环境概览与前置要求](#一环境概览与前置要求)
- [二、安装 WSL2（Windows Subsystem for Linux）](#二安装-wsl2windows-subsystem-for-linux)
- [三、配置 WSL2 Ubuntu 环境](#三配置-wsl2-ubuntu-环境)
- [四、安装 Docker Desktop](#四安装-docker-desktop)
- [五、安装 Node.js（v22+）](#五安装-nodejsv22)
- [六、安装 Git](#六安装-git)
- [七、安装 OpenClaw](#七安装-openclaw)
- [八、配置 OpenClaw](#八配置-openclaw)
- [九、启动 OpenClaw](#九启动-openclaw)
- [十、验证安装](#十验证安装)
- [十一、常见问题排查](#十一常见问题排查)

---

## 一、环境概览与前置要求

### 什么是 OpenClaw？

OpenClaw 是一个**开源、自托管的自主 AI 代理**，可以在你自己的硬件上运行（Mac、Windows、Linux、树莓派或 VPS）。它不仅仅是聊天机器人，而是可以实际执行任务的 AI 助手：

- 📧 分类邮件、起草回复、安排会议
- 🌐 浏览网页、管理文件、运行 Shell 命令
- 💬 通过 WhatsApp、Telegram、Discord、Slack、飞书等通讯应用与你交互
- 🧠 跨会话保持记忆和上下文

### 系统要求

| 项目 | 要求 |
|------|------|
| 操作系统 | Windows 10（版本 1903 或更高）或 Windows 11 |
| 内存 | 建议至少 8GB RAM |
| 磁盘空间 | 至少 10GB 可用空间 |
| 网络 | 稳定的互联网连接 |
| 虚拟化 | BIOS 中需启用虚拟化（VT-x / AMD-V） |

### 需要准备的东西

- 一个 LLM 提供商的 API Key（至少一个），例如：
  - **Anthropic**（Claude）—— 推荐
  - **OpenAI**（GPT 系列）
  - **Google**（Gemini）
  - **DeepSeek**
  - 或者本地部署的开源模型（如 Llama）

> [!important] 📌 请提前注册好 LLM 提供商账号并获取 API Key。如果还没有，可以先安装好环境，到配置步骤时再获取。

---

## 二、安装 WSL2（Windows Subsystem for Linux）

WSL2 是在 Windows 上运行 Linux 的官方方案，OpenClaw 在 Windows 上依赖 WSL2 环境运行。

### 2.1 检查系统版本

1. 按 `Win + R` 打开运行对话框
2. 输入 `winver` 按回车
3. 确认版本号 ≥ 1903（Windows 10）或 Windows 11

> [!NOTE] 📸 **请在此截图**：`winver` 弹出的"关于 Windows"对话框，记录你的 Windows 版本号。

### 2.2 检查 BIOS 虚拟化是否开启

1. 按 `Ctrl + Shift + Esc` 打开任务管理器
2. 切换到 **"性能"** 选项卡
3. 点击 **"CPU"**
4. 在右下角查看 **"虚拟化"** 是否显示 **"已启用"**

> [!NOTE] 📸 **请在此截图**：任务管理器性能页面，显示虚拟化状态。

如果虚拟化未启用，需要进入 BIOS 设置开启：
- 重启电脑，按 `Del`、`F2` 或 `F10`（具体按键取决于主板品牌）进入 BIOS
- 找到 `Intel VT-x` 或 `AMD-V`（也可能叫 `SVM Mode`）选项
- 将其设置为 **Enabled**
- 保存并退出 BIOS

### 2.3 安装 WSL2

1. **以管理员身份打开 PowerShell**：
   - 右键点击 **开始菜单**（Windows 图标）
   - 选择 **"终端（管理员）"** 或 **"Windows PowerShell（管理员）"**

> [!NOTE] 📸 **请在此截图**：右键开始菜单，选择管理员终端的选项。

2. **执行安装命令**：

```powershell
wsl --install
```

这个命令会自动完成以下操作：
- ✅ 启用 WSL 功能
- ✅ 启用"虚拟机平台"组件
- ✅ 下载并安装最新的 Linux 内核
- ✅ 将 WSL 2 设置为默认版本
- ✅ 下载并安装 **Ubuntu**（默认发行版）

> [!NOTE] 📸 **请在此截图**：`wsl --install` 命令执行过程和输出结果。

3. **等待安装完成后重启电脑**

> [!warning] ⚠️ 安装过程中可能会提示"需要重启才能完成安装"，请保存所有工作后重启。

### 2.4 首次配置 Ubuntu

重启后，Windows 会自动打开 Ubuntu 终端窗口（或者你可以从开始菜单搜索 "Ubuntu" 打开）。

1. **等待 Ubuntu 完成初始化**（可能需要几分钟）
2. **创建 Linux 用户名**：
   - 输入一个用户名（建议纯英文小写，如 `openclaw`）
   - 按回车

3. **创建密码**：
   - 输入密码（**输入时不会显示任何字符，这是正常的**）
   - 按回车
   - 再次输入密码确认
   - 按回车

> [!NOTE] 📸 **请在此截图**：Ubuntu 首次启动，设置用户名和密码的界面（密码输入前截图即可）。

> [!warning] ⚠️ 请牢记这个用户名和密码！后续执行 `sudo` 命令时需要输入此密码。

### 2.5 验证 WSL2 安装

**在 PowerShell 中**运行：

```powershell
wsl --list --verbose
```

你应该看到类似输出：

```
  NAME      STATE           VERSION
* Ubuntu    Running         2
```

确认 `VERSION` 列显示的是 **2**。

> [!NOTE] 📸 **请在此截图**：`wsl --list --verbose` 的输出结果。

如果 VERSION 显示为 1，运行以下命令转换：

```powershell
wsl --set-version Ubuntu 2
```

### 2.6 设置 WSL2 为默认版本（可选，推荐）

```powershell
wsl --set-default-version 2
```

---

## 三、配置 WSL2 Ubuntu 环境

### 3.1 更新系统软件包

**在 Ubuntu 终端中**执行：

```bash
sudo apt update && sudo apt upgrade -y
```

> 这一步会更新所有已安装的软件包到最新版本，过程中可能需要输入刚才设置的密码。

> **选择说明**：如果更新过程中弹出紫色/蓝色界面要求选择配置文件（如 `What do you want to do about modified configuration files?`），选择 **`keep the local version currently installed`**（保留当前本地版本），直接按回车即可。

> [!NOTE] 📸 **请在此截图**：`sudo apt update && sudo apt upgrade -y` 执行完毕的输出。

### 3.2 安装基础开发工具

```bash
sudo apt install -y build-essential curl wget unzip software-properties-common
```

这些是后续安装其他工具时需要的基础依赖。

### 3.3 启用 systemd（重要！）

OpenClaw 的后台网关服务需要 `systemd` 支持。

1. **编辑 WSL 配置文件**：

```bash
sudo nano /etc/wsl.conf
```

2. **添加以下内容**（如果文件已存在内容，在末尾添加即可）：

```ini
[boot]
systemd=true
```

3. **保存退出**：
   - 按 `Ctrl + O`（字母 O）→ 按 `Enter` 确认保存
   - 按 `Ctrl + X` 退出编辑器

4. **重启 WSL**（在 Windows PowerShell 中执行）：

```powershell
wsl --shutdown
```

然后重新打开 Ubuntu 终端。

5. **验证 systemd 是否启用**：

```bash
systemctl list-unit-files --type=service | head -20
```

如果能看到一堆 service 列表，说明 systemd 已成功启用。

> [!NOTE] 📸 **请在此截图**：`systemctl` 命令的输出结果，证明 systemd 已启用。

---

## 四、安装 Docker Desktop

Docker 是 OpenClaw 运行的容器化环境基础（部分功能和插件依赖 Docker）。

### 4.1 下载 Docker Desktop

1. 打开浏览器，访问 [Docker Desktop 官网下载页](https://www.docker.com/products/docker-desktop/)
2. 点击 **"Download for Windows"** 下载安装包

> [!NOTE] 📸 **请在此截图**：Docker Desktop 下载页面。

### 4.2 安装 Docker Desktop

1. 双击下载的 `Docker Desktop Installer.exe`
2. 安装过程中会出现**配置选项**：

   | 选项 | 选择 | 说明 |
   |------|------|------|
   | Use WSL 2 instead of Hyper-V | ✅ 勾选 | **必须勾选**，使用 WSL 2 引擎 |
   | Add shortcut to desktop | ✅ 勾选 | 可选，方便在桌面打开 |

> [!NOTE] 📸 **请在此截图**：Docker Desktop 安装时的配置选项界面，确保 WSL 2 选项已勾选。

3. 点击 **"OK"** 开始安装
4. 安装完成后，点击 **"Close and restart"** 重启电脑

### 4.3 首次启动 Docker Desktop

1. 重启后，从开始菜单或桌面打开 **Docker Desktop**
2. 首次启动会弹出**服务协议**：
   - 勾选 **"I accept the terms"**
   - 点击 **"Accept"**

3. 可能会提示**登录或注册** Docker Hub 账号：
   - 可以选择 **"Skip"** 跳过（不是必须的）
   - 或者注册一个免费账号

4. 可能出现 **Welcome Survey（欢迎调查问卷）**：
   - 可以选择 **"Skip"** 跳过

> [!NOTE] 📸 **请在此截图**：Docker Desktop 首次启动后的主界面（左下角应显示绿色 "Engine running"）。

### 4.4 配置 Docker Desktop 的 WSL2 集成

1. 点击 Docker Desktop 右上角的 **⚙️ 齿轮图标**（Settings）
2. 进入 **"General"**：
   - 确认 **"Use the WSL 2 based engine"** 已勾选 ✅

3. 进入 **"Resources"** → **"WSL Integration"**：
   - 确认 **"Enable integration with my default WSL distro"** 已勾选 ✅
   - 在下方找到你的 **Ubuntu** 发行版，**打开开关** 🔘
   - 点击 **"Apply & Restart"**

> [!NOTE] 📸 **请在此截图**：Docker Desktop Settings → Resources → WSL Integration 页面，显示 Ubuntu 已开启集成。

### 4.5 验证 Docker 在 WSL2 中可用

在 **Ubuntu 终端** 中运行：

```bash
docker --version
```

应该输出类似：
```
Docker version 27.x.x, build xxxxxxx
```

再运行一下测试容器：

```bash
docker run hello-world
```

如果看到 `Hello from Docker!` 的输出，说明 Docker 已正确配置。

> [!NOTE] 📸 **请在此截图**：`docker run hello-world` 的完整输出。

---

## 五、安装 Node.js（v22+）

OpenClaw **严格要求 Node.js 版本 22.x 或更高**。推荐使用 **nvm**（Node Version Manager）来安装和管理 Node.js 版本。

### 5.1 安装 nvm

在 **Ubuntu 终端** 中执行：

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
```

安装完成后，**重新加载 shell 配置**：

```bash
source ~/.bashrc
```

验证安装：

```bash
nvm --version
```

应该显示版本号（如 `0.40.1`）。

### 5.2 安装 Node.js 22

```bash
nvm install 22
```

> **nvm 在安装过程中的选择说明**：nvm 会自动下载、编译（如需要）并安装指定版本的 Node.js。安装完成后会自动将其设为当前使用版本，无需额外选择。

将 Node.js 22 设为默认版本：

```bash
nvm alias default 22
```

### 5.3 验证 Node.js 和 npm

```bash
node --version
```

输出应类似：`v22.x.x`

```bash
npm --version
```

输出应类似：`10.x.x`

> [!NOTE] 📸 **请在此截图**：`node --version` 和 `npm --version` 的输出。

---

## 六、安装 Git

### 6.1 安装

在 **Ubuntu 终端** 中执行：

```bash
sudo apt install -y git
```

### 6.2 验证

```bash
git --version
```

输出应类似：`git version 2.x.x`

### 6.3 配置 Git（可选但推荐）

```bash
git config --global user.name "你的名字"
git config --global user.email "你的邮箱"
```

---

## 七、安装 OpenClaw

### 7.1 使用 npm 全局安装

在 **Ubuntu 终端** 中执行：

```bash
npm install -g openclaw
```

> 安装过程可能需要几分钟，取决于网络速度。

> [!NOTE] 📸 **请在此截图**：`npm install -g openclaw` 的安装过程和完成输出。

### 7.2 验证安装

```bash
openclaw --version
```

应该输出当前安装的 OpenClaw 版本号。

> [!NOTE] 📸 **请在此截图**：`openclaw --version` 的输出。

### 7.3 安装出错的备选方案

如果全局安装遇到权限问题，可以尝试：

```bash
# 方案 1：使用 sudo（不推荐但有效）
sudo npm install -g openclaw

# 方案 2：修改 npm 全局目录
mkdir ~/.npm-global
npm config set prefix '~/.npm-global'
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
npm install -g openclaw
```

---

## 八、配置 OpenClaw

### 8.1 运行交互式配置向导（Onboarding Wizard）

OpenClaw 提供了一个交互式向导来帮助你完成初始配置：

```bash
openclaw onboard
```

向导会依次引导你完成以下配置：

#### 步骤 1：选择 LLM 提供商

```
? Which LLM provider would you like to use?
  ❯ Anthropic (Claude)
    OpenAI (GPT)
    Google (Gemini)
    DeepSeek
    Local (Ollama/LM Studio)
    Custom API
```

**选择说明**：
- **Anthropic (Claude)** —— 推荐首选，Claude 在代码生成和任务执行方面表现优秀
- **OpenAI (GPT)** —— 如果你有 OpenAI API Key
- **Google (Gemini)** —— 免费额度相对较多，适合入门
- **DeepSeek** —— 性价比高
- **Local** —— 如果你想用本地模型（需要额外配置 Ollama 或 LM Studio）

用方向键选择，按 `Enter` 确认。

> [!NOTE] 📸 **请在此截图**：LLM 提供商选择界面。

#### 步骤 2：输入 API Key

```
? Enter your API key: ●●●●●●●●●●●●●●●●●●●●●●●●●
```

粘贴你从 LLM 提供商平台获取的 API Key。

**各提供商获取 API Key 的方式：**

| 提供商 | 获取地址 | 说明 |
|--------|----------|------|
| Anthropic | [console.anthropic.com](https://console.anthropic.com/) | 注册后在 API Keys 中创建 |
| OpenAI | [platform.openai.com](https://platform.openai.com/api-keys) | 注册后在 API Keys 中创建 |
| Google | [aistudio.google.com](https://aistudio.google.com/apikey) | 直接创建 API Key |
| DeepSeek | [platform.deepseek.com](https://platform.deepseek.com/) | 注册后在控制台创建 |

> [!warning] ⚠️ API Key 是敏感信息，请妥善保管，不要分享给他人！

#### 步骤 3：选择默认模型

```
? Select default model:
  ❯ claude-4-sonnet (recommended)
    claude-4-opus
    claude-3.5-sonnet
    claude-3.5-haiku
```

**选择说明**：
- 推荐选择 **标记 `recommended` 的模型**（平衡性能和成本）
- Opus 类模型更强大但更贵
- Haiku/Flash 类模型更便宜但能力稍弱

> [!NOTE] 📸 **请在此截图**：模型选择界面。

#### 步骤 4：配置消息通道（可选）

```
? Would you like to configure a messaging channel now?
  ❯ Yes
    No, I'll do it later
```

**选择说明**：
- 选择 **No** 先跳过，先确保基础安装正常
- 后续可以通过 `openclaw channels add` 随时添加通道（如飞书、Telegram 等）
- 如果选 Yes，会进入通道配置向导（详见下方 8.3 节）

#### 步骤 5：其他配置

根据你选择的通道和其他选项，向导可能会继续询问：
- **时区设置**：选择你所在的时区（如 `Asia/Shanghai`）
- **语言偏好**：选择中文或英文
- **数据存储路径**：默认路径 `~/.openclaw/`，建议保持默认

> [!NOTE] 📸 **请在此截图**：配置向导执行完成的最终输出。

### 8.2 手动编辑配置文件（可选）

配置文件位于 `~/.openclaw/openclaw.json`，可以手动查看和修改：

```bash
cat ~/.openclaw/openclaw.json
```

也可以用编辑器修改：

```bash
nano ~/.openclaw/openclaw.json
```

常见配置项示例：

```json5
{
  // 默认 LLM 提供商和模型
  "llm": {
    "provider": "anthropic",
    "model": "claude-4-sonnet"
  },
  // 时区
  "timezone": "Asia/Shanghai",
  // 日志级别
  "logLevel": "info"
}
```

### 8.3 配置 API Key 的其他方式

除了 `onboard` 向导，还可以通过以下方式设置 API Key：

**方式 1：命令行设置**

```bash
# 设置 Anthropic API Key
openclaw config set ANTHROPIC_API_KEY sk-ant-xxxxxxxxx

# 设置 OpenAI API Key
openclaw config set OPENAI_API_KEY sk-xxxxxxxxx

# 设置 Google Gemini API Key
openclaw config set GOOGLE_API_KEY AIzaxxxxxxxxx
```

**方式 2：环境变量 / .env 文件**

创建或编辑 `~/.openclaw/.env` 文件：

```bash
nano ~/.openclaw/.env
```

添加内容：

```env
ANTHROPIC_API_KEY=sk-ant-xxxxxxxxx
OPENAI_API_KEY=sk-xxxxxxxxx
GOOGLE_API_KEY=AIzaxxxxxxxxx
```

> [!tip] 💡 可以同时配置多个提供商的 API Key，在使用时可以切换不同模型。

---

## 九、启动 OpenClaw

### 9.1 首次启动

```bash
openclaw start
```

OpenClaw 会启动后台服务（daemon）和网关（gateway）。

> [!NOTE] 📸 **请在此截图**：`openclaw start` 的输出，应该显示服务已启动。

### 9.2 查看运行状态

```bash
openclaw status
```

你应该看到类似输出：

```
OpenClaw Status:
  Daemon:   ● running
  Gateway:  ● running
  Version:  20xx.x.x
  Uptime:   xxs
```

> [!NOTE] 📸 **请在此截图**：`openclaw status` 的输出。

### 9.3 查看实时日志

```bash
openclaw logs --follow
```

这会实时显示 OpenClaw 的运行日志，按 `Ctrl + C` 退出。

### 9.4 设置开机自启（可选）

如果需要 OpenClaw 在 WSL 启动时自动运行：

```bash
openclaw config set autostart true
```

### 9.5 停止和重启

```bash
# 停止
openclaw stop

# 重启
openclaw restart

# 重启网关（修改通道配置后需要）
openclaw gateway restart
```

---

## 十、验证安装

### 10.1 使用 Web 控制面板

OpenClaw 提供了一个 Web 管理界面：

```bash
openclaw dashboard
```

或者在浏览器中访问：`http://localhost:3007`（默认端口，具体以 OpenClaw 输出的为准）

> [!NOTE] 📸 **请在此截图**：OpenClaw Web Dashboard 界面。

### 10.2 命令行对话测试

直接在终端与 OpenClaw 对话：

```bash
openclaw chat
```

输入一条简单消息（如 "Hello" 或 "你好"），确认 AI 能正常回复。

> [!NOTE] 📸 **请在此截图**：`openclaw chat` 的对话界面和 AI 回复。

### 10.3 检查所有组件

```bash
openclaw doctor
```

此命令会检查所有依赖项和配置是否正确，输出一份健康报告。

> [!NOTE] 📸 **请在此截图**：`openclaw doctor` 的完整输出。

---

## 十一、常见问题排查

### 安装阶段

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| `wsl --install` 无反应 | PowerShell 未以管理员身份运行 | 右键开始菜单选"终端（管理员）" |
| WSL 安装后 VERSION 显示 1 | WSL2 未设为默认 | 运行 `wsl --set-version Ubuntu 2` |
| Ubuntu 启动卡在 "Installing" | 网络或磁盘问题 | 耐心等待，或重试 `wsl --install -d Ubuntu` |
| Docker Desktop 启动报错 | 虚拟化未启用 / Hyper-V 冲突 | 检查 BIOS 虚拟化设置；以管理员身份运行 `bcdedit /set hypervisorlaunchtype auto` 后重启 |
| `nvm` 命令无法找到 | shell 配置未加载 | 运行 `source ~/.bashrc` 或重新打开终端 |
| `npm install -g openclaw` 报权限错误 | npm 全局目录权限不足 | 参考 7.3 节的备选方案 |

### 配置阶段

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| `openclaw onboard` 报 "API key invalid" | API Key 输入错误或已失效 | 重新去提供商控制台检查/复制 API Key |
| 连接 LLM 超时 | 网络问题（可能需要代理） | 检查网络；如在国内，考虑配置代理 |
| `openclaw start` 失败 | 端口被占用或 systemd 未启用 | 检查 systemd：`systemctl --version`；端口冲突可改配置 |

### 运行阶段

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| `openclaw status` 显示 daemon 未运行 | 后台进程崩溃 | 查看日志 `openclaw logs`，根据错误信息排查 |
| Web Dashboard 打不开 | 端口或服务未启动 | 确认 `openclaw status` 正常，检查端口号 |
| AI 回复特别慢 | 网络延迟或模型选择 | 尝试切换到更轻量的模型（如 haiku/flash） |

### 网络代理配置（国内用户可能需要）

如果你在国内访问 API 有困难，可以配置代理：

```bash
# 在 ~/.bashrc 中添加
export http_proxy="http://127.0.0.1:7890"
export https_proxy="http://127.0.0.1:7890"
export all_proxy="socks5://127.0.0.1:7890"
```

然后：

```bash
source ~/.bashrc
```

> 其中 `7890` 是常见代理端口，请替换为你实际的代理端口号。

---

## 十二、安装完成后的下一步

安装配置完成后，你可以：

1. **接入通讯应用**：通过 `openclaw channels add` 接入飞书、Telegram、微信等 → 详见 [[openclaw接入飞书]]
2. **安装插件**：通过 `openclaw plugins install <插件名>` 扩展功能
3. **自定义指令**：配置 OpenClaw 的行为和回复风格
4. **配置多模型**：根据不同任务使用不同的 LLM 模型，优化成本

---

## 📝 完整命令速查表

```bash
# 安装相关
wsl --install                           # 安装 WSL2
wsl --list --verbose                    # 查看 WSL 版本
wsl --shutdown                          # 关闭 WSL（重启用）

# Node.js 相关
nvm install 22                          # 安装 Node.js 22
nvm alias default 22                    # 设为默认

# OpenClaw 核心命令
openclaw --version                      # 查看版本
openclaw onboard                        # 交互式配置向导
openclaw start                          # 启动服务
openclaw stop                           # 停止服务
openclaw restart                        # 重启服务
openclaw status                         # 查看状态
openclaw logs --follow                  # 实时日志
openclaw chat                           # 命令行聊天
openclaw dashboard                      # 打开 Web 面板
openclaw doctor                         # 健康检查

# 通道管理
openclaw channels add                   # 添加消息通道
openclaw channels list                  # 列出已有通道
openclaw gateway restart                # 重启网关

# 配置管理
openclaw config set <KEY> <VALUE>       # 设置配置项
openclaw config get <KEY>               # 查看配置项

# 插件管理
openclaw plugins list                   # 列出已安装插件
openclaw plugins install <插件名>       # 安装插件
```

---

> 📝 最后更新：2026-03-10

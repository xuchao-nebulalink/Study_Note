# Windows 安装配置 OpenClaw 完整指南（从零开始）

> 本笔记基于 [OpenClaw 官方文档](https://docs.openclaw.ai/install)，记录在 Windows 上通过 WSL2 安装和配置 OpenClaw 的完整流程。
> OpenClaw 是一个开源、自托管的 AI 代理，可执行实际任务（收发邮件、浏览网页、管理文件、运行命令等），通过 WhatsApp / Telegram / Discord / 飞书等通讯应用与你交互。

---

## 一、前置要求

| 项目 | 要求 | 说明 |
|------|------|------|
| 操作系统 | Windows 10（版本 1903+）或 Windows 11 | 需要支持 WSL2 |
| 内存 | ≥ 8GB RAM（本地模型建议 ≥ 16GB） | 跑云端 API 8GB 够用 |
| 磁盘 | ≥ 10GB 可用空间 | OpenClaw + 依赖 + 工作区 |
| BIOS | 虚拟化已启用（VT-x / AMD-V） | WSL2 必须 |
| API Key | 至少一个 LLM 提供商的 Key | 也可以跑本地模型不需要 Key |

> [!important] 官方文档：https://docs.openclaw.ai ，遇到问题优先查阅。

---

## 二、安装 WSL2（必须）

OpenClaw 官方要求 Windows 用户通过 [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install) 运行。

**作用**：WSL2 是 Windows 上运行 Linux 的官方方案，提供完整的 Linux 内核环境。OpenClaw 依赖 Linux 原生工具链运行。

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

`wsl --install` 会一次性完成：
- 启用 WSL 功能和"虚拟机平台"组件
- 下载安装 Linux 内核
- 将 WSL 2 设为默认版本
- 下载安装 Ubuntu（默认发行版）

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

如果 VERSION 显示 1：

```powershell
wsl --set-version Ubuntu 2
wsl --set-default-version 2
```

> [!NOTE] 📸 **请在此截图**：`wsl --list --verbose` 的输出。

---

## 三、配置 WSL2 Ubuntu 环境（必须）

以下命令都在 **Ubuntu 终端**中执行。

### 3.1 更新系统软件包

```bash
sudo apt update && sudo apt upgrade -y
```

**作用**：将系统所有软件包更新到最新版本，确保安全性和兼容性。

> 如果弹出紫色/蓝色界面问 `What do you want to do about modified configuration files?`，选择 **keep the local version currently installed**，直接按回车。

### 3.2 安装基础开发工具（必须）

```bash
sudo apt install -y build-essential curl wget unzip software-properties-common
```

**各工具作用**：

| 工具 | 作用 |
|------|------|
| `build-essential` | C/C++ 编译器和构建工具，部分 npm 包需要编译原生模块（如 `sharp`） |
| `curl` | 命令行下载工具，后续安装 nvm 和 OpenClaw 都需要 |
| `wget` | 另一个下载工具，备用 |
| `unzip` | 解压工具 |
| `software-properties-common` | 管理 apt 软件源的工具 |

### 3.3 启用 systemd（重要！）

**作用**：OpenClaw 的 `--install-daemon` 会将 OpenClaw 配置为 systemd 用户服务，实现后台常驻运行。WSL2 默认不启用 systemd，需要手动开启。

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

## 四、安装 Node.js v22+（必须）

**作用**：OpenClaw 是用 Node.js 开发的，运行时严格要求 **Node.js 22 或更高版本**。

> [!tip] 如果使用方式 A（官方一键脚本）安装 OpenClaw，脚本会检测并自动安装 Node.js。但建议还是手动装好 nvm 来管理版本，方便后续升级切换。

**nvm 的作用**：Node Version Manager，管理多个 Node.js 版本，可以随时切换，避免版本冲突。

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

## 五、安装 Git（可选但推荐）

**作用**：版本控制工具。如果你使用源码安装 OpenClaw 或需要管理 OpenClaw 的工作区文件，需要 Git。官方一键脚本和 npm 安装方式不强制要求。

```bash
sudo apt install -y git
git --version   # 应显示 git version 2.x.x
```

可选：配置身份信息

```bash
git config --global user.name "你的名字"
git config --global user.email "你的邮箱"
```

---

## 六、安装 Docker Desktop（可选）

**作用**：容器化运行环境。OpenClaw 本身**不要求** Docker，但以下场景会用到：
- 部分 OpenClaw 插件需要 Docker 运行隔离环境
- OpenClaw 的沙箱（sandbox）功能可以用 Docker 隔离代码执行
- 你也可以选择用 Docker 方式部署 OpenClaw 本身

> [!tip] 如果你不确定是否需要，可以先跳过，后续需要时再安装。

### 6.1 下载安装

1. 下载 [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/)
2. 运行 `Docker Desktop Installer.exe`
3. 安装选项：

| 选项 | 选择 | 说明 |
|------|------|------|
| Use WSL 2 instead of Hyper-V | ✅ 勾选 | **必须勾选**，让 Docker 使用 WSL 2 引擎 |
| Add shortcut to desktop | ✅ 可选 | 方便从桌面启动 |

> [!NOTE] 📸 **请在此截图**：安装选项界面，确认 WSL 2 已勾选。

4. 点击 **OK** → 等待安装 → **Close and restart** 重启电脑

### 6.2 首次启动

重启后打开 Docker Desktop：
1. 弹出服务协议 → 勾选 "I accept the terms" → **Accept**
2. Docker Hub 登录 → 可 **Skip** 跳过（不是必须的）
3. Welcome Survey → 可 **Skip** 跳过

### 6.3 配置 WSL2 集成

Docker Desktop → ⚙️ Settings：

1. **General** → 确认 `Use the WSL 2 based engine` 已勾选 ✅
2. **Resources → WSL Integration** → 开启 "Enable integration with my default WSL distro" ✅ → 找到 Ubuntu 打开开关 → **Apply & Restart**

> [!NOTE] 📸 **请在此截图**：WSL Integration 页面，Ubuntu 开关已打开。

### 6.4 验证

在 Ubuntu 终端中：

```bash
docker --version
docker run hello-world
```

看到 `Hello from Docker!` 即成功。

---

## 七、安装 OpenClaw

以下操作在 **Ubuntu 终端**中执行。

### 方式 A：官方一键安装脚本（推荐）

```bash
curl -fsSL https://openclaw.ai/install.sh | bash
```

此脚本会自动：
- 检测 Node.js 版本，缺失时自动安装
- 安装 OpenClaw
- 启动 onboarding 配置向导
- 安装后台 daemon 服务

> 如果只想安装不立即配置：
> ```bash
> curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard
> ```

### 方式 B：npm 手动安装

```bash
npm install -g openclaw@latest
openclaw onboard --install-daemon
```

> [!warning] 这是**两条分开的命令**，先安装再配置。

### 方式 C：pnpm 安装

```bash
pnpm add -g openclaw@latest
pnpm approve-builds -g    # 批准 openclaw、sharp、node-llama-cpp 等原生模块构建
openclaw onboard --install-daemon
```

### 方式 D：从源码构建（开发者 / 高级用户）

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

**`openclaw` 命令找不到（command not found）**

```bash
# 诊断
node -v
npm -v
npm prefix -g
echo "$PATH"

# 修复：将 npm 全局 bin 目录加入 PATH
echo 'export PATH="$(npm prefix -g)/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

**`sharp` 构建报错**

```bash
# 方案 1：忽略全局 libvips
SHARP_IGNORE_GLOBAL_LIBVIPS=1 npm install -g openclaw@latest

# 方案 2：安装 node-gyp
npm install -g node-gyp
```

**npm 权限错误**

```bash
# 方案 1：sudo
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

如果使用方式 A 安装，onboarding 向导会自动启动。其他方式安装或需要重新配置：

```bash
openclaw onboard --install-daemon
```

> `--install-daemon` 的作用：将 OpenClaw 注册为 **systemd 用户服务**（WSL2/Linux），实现后台常驻运行，关闭终端后仍会继续运行。

向导会依次引导配置以下内容：

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
| Anthropic | [console.anthropic.com](https://console.anthropic.com/) | 注册 → API Keys → Create Key |
| OpenAI | [platform.openai.com/api-keys](https://platform.openai.com/api-keys) | 注册 → API Keys → Create |
| Google | [aistudio.google.com/apikey](https://aistudio.google.com/apikey) | 直接创建，有免费额度 |
| DeepSeek | [platform.deepseek.com](https://platform.deepseek.com/) | 注册 → 控制台 → 创建 Key |

> [!warning] API Key 是敏感信息，请妥善保管，不要泄露！

> 也可以在 onboard 时直接传入 Key，跳过交互式输入：
> ```bash
> openclaw onboard --install-daemon --anthropic-api-key "sk-ant-..."
> ```

### 8.3 选择默认模型

向导会列出该提供商可用的模型，推荐选择标记 **`recommended`** 的模型（平衡性能和成本）。

> [!NOTE] 📸 **请在此截图**：模型选择界面。

### 8.4 其他配置项

向导可能还会询问的内容（一般保持默认即可）：

| 配置项 | 建议选择 | 说明 |
|--------|----------|------|
| 消息通道（Channel） | **No / 跳过** | 先确保基本功跑通，后续 `openclaw channels add` 添加 |
| 工作区路径（Workspace） | 保持默认 | 默认 `~/.openclaw/workspace` |
| 网关设置（Gateway） | 保持默认 | 默认端口 18789 |
| 时区 | `Asia/Shanghai` | - |
| 技能（Skills） | 默认全部 | - |

### 8.5 配置完成

向导完成后，OpenClaw 会自动启动后台 Gateway 服务。

> [!NOTE] 📸 **请在此截图**：onboard 向导完成后的输出。

---

## 九、openclaw.json 配置文件详解

### 9.1 文件位置与结构

onboarding 完成后会在 `~/.openclaw/` 目录下生成配置和数据文件：

```
~/.openclaw/
├── openclaw.json              # 主配置文件（JSON5 格式，支持注释）
├── .env                       # API Key 等敏感配置
├── workspace/                 # AI 的工作区文件
├── credentials/               # 各通道的认证凭证
│   ├── whatsapp/              # WhatsApp 凭证
│   ├── <channel>-allowFrom.json   # 通道白名单
│   └── ...
├── agents/                    # Agent 配置
│   └── <agentId>/agent/auth-profiles.json  # 模型认证配置
└── logs/                      # 日志文件
```

### 9.2 配置文件示例

`~/.openclaw/openclaw.json` 是 **JSON5 格式**（支持注释和尾逗号），完整结构示例：

```json5
{
  // ========== Agent 配置 ==========
  agents: {
    defaults: {
      // 工作区路径
      workspace: "~/.openclaw/workspace",

      // 模型配置（重点！见第十章详解）
      model: {
        primary: "anthropic/claude-sonnet-4-5",   // 默认使用的主模型
        fallbacks: ["openai/gpt-5.2"],            // 主模型不可用时的备用模型
      },

      // 模型目录（定义可用模型列表，同时也是 /model 命令的白名单）
      models: {
        "anthropic/claude-sonnet-4-5": { alias: "Sonnet" },
        "anthropic/claude-opus-4-6":   { alias: "Opus" },
        "openai/gpt-5.2":             { alias: "GPT" },
        "google/gemini-2.5-flash":    { alias: "Flash" },
        "deepseek/deepseek-v3.2":     { alias: "DeepSeek" },
      },

      // 心跳检查（定期向你发消息汇报状态）
      heartbeat: {
        every: "2h",        // 每 2 小时
        target: "last",     // 发到最后活跃的通道
      },

      // 沙箱（代码执行隔离）
      sandbox: {
        mode: "non-main",   // off | non-main | all
        scope: "agent",     // session | agent | shared
      },
    },
  },

  // ========== 通道配置 ==========
  channels: {
    // 示例：Telegram
    telegram: {
      enabled: true,
      botToken: "123456:ABC-xyz",
      dmPolicy: "pairing",      // pairing | allowlist | open | disabled
      allowFrom: ["tg:123"],    // allowlist 模式下的白名单
    },
    // 示例：飞书（feishu）
    feishu: {
      enabled: true,
      appId: "cli_xxxxx",
      appSecret: "xxxxx",
      connectionMode: "websocket",
      dmPolicy: "pairing",
      groupPolicy: "disabled",
    },
  },

  // ========== 会话配置 ==========
  session: {
    dmScope: "per-channel-peer",
    reset: {
      mode: "daily",
      atHour: 4,
      idleMinutes: 120,
    },
  },

  // ========== 定时任务 ==========
  cron: {
    enabled: true,
    maxConcurrentRuns: 2,
  },
}
```

### 9.3 编辑配置的四种方式

| 方式 | 命令 | 适用场景 |
|------|------|----------|
| 配置向导（完整） | `openclaw onboard` | 首次配置或完整重配 |
| 配置向导（精简） | `openclaw configure` | 快速修改常用配置 |
| 命令行单项修改 | `openclaw config set/get/unset` | 改单个配置项 |
| 直接编辑文件 | `openclaw config edit` 或 `nano ~/.openclaw/openclaw.json` | 批量修改 |
| Web 控制面板 | 浏览器访问 `http://127.0.0.1:18789` | 图形界面操作 |

命令行示例：

```bash
# 查看配置项
openclaw config get agents.defaults.model.primary

# 修改配置项
openclaw config set agents.defaults.heartbeat.every "2h"

# 删除配置项
openclaw config unset tools.web.search.apiKey

# 打开编辑器编辑完整配置
openclaw config edit
```

> [!tip] 修改 `openclaw.json` 后，大部分配置会**自动热重载**，不需要重启。少数配置（如通道变更）需要重启网关：`openclaw gateway restart`。

---

## 十、多 API Key / 多提供商 / 模型切换

### 10.1 配置多个提供商的 API Key

OpenClaw 支持同时配置多个 LLM 提供商的 API Key，通过 `.env` 文件或环境变量管理：

**方式 1：编辑 .env 文件（推荐）**

```bash
nano ~/.openclaw/.env
```

填入多个提供商的 Key：

```env
ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxxxxxxxxxx
OPENAI_API_KEY=sk-xxxxxxxxxxxxxxxxxx
GOOGLE_API_KEY=AIzaxxxxxxxxxxxxxxxxxxxxxxx
DEEPSEEK_API_KEY=sk-xxxxxxxxxxxxxxxxxx
```

**方式 2：命令行逐个设置**

```bash
openclaw config set ANTHROPIC_API_KEY sk-ant-xxxxxxxxxx
openclaw config set OPENAI_API_KEY sk-xxxxxxxxxx
openclaw config set GOOGLE_API_KEY AIzaxxxxxxxxxx
openclaw config set DEEPSEEK_API_KEY sk-xxxxxxxxxx
```

### 10.2 配置模型目录（告诉 OpenClaw 可以用哪些模型）

在 `openclaw.json` 中配置 `agents.defaults.models`，定义你可用的模型列表：

```json5
{
  agents: {
    defaults: {
      model: {
        // 默认主模型
        primary: "anthropic/claude-sonnet-4-5",
        // 备用模型（主模型不可用时自动切换）
        fallbacks: ["openai/gpt-5.2", "google/gemini-2.5-flash"],
      },
      // 模型目录 —— 这里列出的模型才能在 /model 命令中切换
      models: {
        "anthropic/claude-sonnet-4-5":  { alias: "Sonnet" },
        "anthropic/claude-opus-4-6":    { alias: "Opus" },
        "openai/gpt-5.2":              { alias: "GPT" },
        "google/gemini-2.5-flash":     { alias: "Flash" },
        "deepseek/deepseek-v3.2":      { alias: "DeepSeek" },
      },
    },
  },
}
```

> [!important] **模型引用格式**：统一用 `提供商/模型名` 格式，如 `anthropic/claude-sonnet-4-5`、`openai/gpt-5.2`、`google/gemini-2.5-flash`。

`alias` 是别名，在 `/model` 命令中可以用别名快速切换。

### 10.3 切换模型

#### 方法 1：聊天中用 `/model` 命令实时切换

在和 OpenClaw 聊天时（任何通道：飞书、Telegram、Web 面板等），直接发送：

```
/model
```

OpenClaw 会列出 `agents.defaults.models` 中配置的所有可用模型供你选择。

也可以直接指定模型：

```
/model Sonnet       # 用别名切换
/model anthropic/claude-opus-4-6   # 用完整模型名切换
```

#### 方法 2：修改配置文件的默认模型

```bash
# 改默认主模型
openclaw config set agents.defaults.model.primary "openai/gpt-5.2"

# 重新加载（大部分情况自动热重载）
```

#### 方法 3：Web 控制面板切换

浏览器访问 `http://127.0.0.1:18789`，在 Dashboard 中可以图形化切换模型。

### 10.4 模型 Failover（自动故障切换）

如果配置了 `fallbacks`，当主模型不可用（API Key 用完、服务宕机等）时，OpenClaw 会**自动切换到备用模型**：

```json5
model: {
  primary: "anthropic/claude-sonnet-4-5",
  fallbacks: ["openai/gpt-5.2", "google/gemini-2.5-flash"],
  // 依次尝试：Sonnet → GPT → Flash
}
```

详见官方文档：[Model Failover](https://docs.openclaw.ai/concepts/model-failover)

### 10.5 成本优化建议

| 场景 | 推荐模型 | 说明 |
|------|----------|------|
| 日常简单任务 | `google/gemini-2.5-flash` 或 `deepseek/deepseek-v3.2` | 便宜快速 |
| 代码生成和复杂推理 | `anthropic/claude-sonnet-4-5` | 平衡性能和成本 |
| 最高质量要求 | `anthropic/claude-opus-4-6` | 最强但最贵 |

> [!tip] 建议把便宜的模型配为 primary 日常使用，遇到复杂任务时用 `/model` 临时切换到更强的模型。在 API 提供商的控制台设置**消费上限**来控制成本。

---

## 十一、启动与验证

### 11.1 查看 Gateway 状态

```bash
openclaw gateway status
```

> [!NOTE] 📸 **请在此截图**：gateway status 输出。

### 11.2 健康检查（重要）

```bash
openclaw doctor
```

检查所有依赖、配置、连接是否正确。有问题的项目会标红。

如果有问题需要自动修复：

```bash
openclaw doctor --fix
```

> [!NOTE] 📸 **请在此截图**：`openclaw doctor` 的输出。

### 11.3 Web 控制面板（Dashboard）

```bash
openclaw dashboard
```

或浏览器访问：`http://127.0.0.1:18789`

> [!NOTE] 📸 **请在此截图**：OpenClaw Web Dashboard 界面。

### 11.4 命令行对话测试

```bash
openclaw chat
```

发送 "你好"，确认 AI 正常回复，按 `Ctrl+C` 退出。

### 11.5 查看实时日志

```bash
openclaw logs --follow
```

实时显示运行日志，按 `Ctrl+C` 退出。

### 11.6 启停管理

```bash
openclaw start              # 启动
openclaw stop               # 停止
openclaw restart             # 重启
openclaw gateway restart     # 仅重启网关（修改通道配置后需要）
```

---

## 十二、常见问题排查

### 安装阶段

| 问题 | 解决方案 |
|------|----------|
| `wsl --install` 无反应 | 确认 PowerShell 以管理员运行 |
| WSL VERSION 显示 1 | `wsl --set-version Ubuntu 2` + `wsl --set-default-version 2` |
| Docker Desktop 启动报错 | 检查 BIOS 虚拟化；管理员运行 `bcdedit /set hypervisorlaunchtype auto` 后重启 |
| `nvm` 命令找不到 | `source ~/.bashrc` 或重开终端 |
| `openclaw` 命令找不到 | 见第七节 PATH 修复方法 |
| `sharp` 构建报错 | 见第七节 sharp 修复方法 |
| npm 权限错误 | 见第七节权限修复方法 |

### 配置阶段

| 问题 | 解决方案 |
|------|----------|
| API Key 无效 | 去提供商控制台重新复制，注意不要有多余空格 |
| 连接 LLM 超时（国内） | 配置代理，见下方 |
| Gateway 启动失败 | 检查 systemd：`systemctl --version`；检查端口冲突 |
| 配置文件校验失败 | `openclaw doctor --fix` 自动修复 |
| daemon 状态异常 | `openclaw logs` 查看错误日志 |

### 完全重置 OpenClaw

如果配置搞乱了想从头来：

```bash
openclaw reset --scope full --yes --non-interactive
openclaw onboard --install-daemon
```

### 国内网络代理配置

如果在国内访问 LLM API 有困难：

```bash
nano ~/.bashrc
# 在末尾添加（端口号替换为你实际的代理端口）：
export http_proxy="http://127.0.0.1:7890"
export https_proxy="http://127.0.0.1:7890"
export all_proxy="socks5://127.0.0.1:7890"
```

```bash
source ~/.bashrc
```

> `7890` 是 Clash 等代理工具的常见端口号，替换为你实际使用的端口。

---

## 十三、更新与卸载

### 更新 OpenClaw

```bash
# npm 方式
npm install -g openclaw@latest

# 或重新运行安装脚本
curl -fsSL https://openclaw.ai/install.sh | bash
```

详见：https://docs.openclaw.ai/install/updating

### 卸载

详见：https://docs.openclaw.ai/install/uninstall

---

## 十四、下一步

1. **接入通讯应用**：`openclaw channels add` 接入飞书、Telegram 等 → 详见 [[openclaw接入飞书]]
2. **安装插件**：`openclaw plugins install <插件名>`
3. **浏览器自动化**：安装 [OpenClaw Browser Relay](https://docs.openclaw.ai/tools/chrome-extension) Chrome 扩展
4. **定时任务**：配置 cron jobs 自动执行周期性任务
5. **连接更多通道**：[通道文档](https://docs.openclaw.ai/channels)

---

## 命令速查表

```bash
# ===== WSL 管理 =====
wsl --install                           # 安装 WSL2
wsl --install -d Ubuntu-24.04           # 指定发行版
wsl --list --verbose                    # 查看 WSL 版本
wsl --shutdown                          # 关闭 WSL（用于重启）

# ===== Node.js =====
nvm install 22                          # 安装 Node.js 22
nvm alias default 22                    # 设为默认
node --version                          # 查看版本

# ===== OpenClaw 安装 =====
curl -fsSL https://openclaw.ai/install.sh | bash  # 一键安装（推荐）
npm install -g openclaw@latest          # npm 安装
openclaw onboard --install-daemon       # 配置向导 + 安装 daemon
openclaw --version                      # 查看版本

# ===== 启停管理 =====
openclaw start                          # 启动
openclaw stop                           # 停止
openclaw restart                        # 重启
openclaw gateway status                 # 查看 Gateway 状态
openclaw gateway restart                # 重启网关

# ===== 检查与调试 =====
openclaw doctor                         # 健康检查
openclaw doctor --fix                   # 自动修复
openclaw logs --follow                  # 实时日志

# ===== 使用 =====
openclaw chat                           # 命令行对话
openclaw dashboard                      # Web 控制面板
/model                                  # 聊天中切换模型
/model <别名或模型名>                    # 指定切换

# ===== 配置管理 =====
openclaw onboard                        # 完整配置向导
openclaw configure                      # 精简配置向导
openclaw config edit                    # 编辑配置文件
openclaw config set <KEY> <VALUE>       # 设置配置项
openclaw config get <KEY>               # 查看配置项

# ===== 通道与插件 =====
openclaw channels add                   # 添加消息通道
openclaw channels list                  # 列出已有通道
openclaw plugins install <名称>         # 安装插件
openclaw plugins list                   # 列出已安装插件

# ===== 重置 =====
openclaw reset --scope full --yes --non-interactive  # 完全重置
```

---

> 📝 最后更新：2026-03-10
> 📖 官方文档：https://docs.openclaw.ai

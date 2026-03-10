# Windows 安装配置 OpenClaw 完整指南（从零开始）

> 在 Windows 上通过 WSL2 安装和配置 OpenClaw 的完整流程。

---

## 一、前置要求

| 项目 | 要求 |
|------|------|
| 操作系统 | Windows 10（版本 1903+）或 Windows 11 |
| 内存 | 建议 ≥ 8GB RAM |
| 磁盘 | ≥ 10GB 可用空间 |
| BIOS | 虚拟化已启用（VT-x / AMD-V） |
| API Key | 至少一个 LLM 提供商的 Key（Anthropic / OpenAI / Google / DeepSeek 等） |

---

## 二、安装 WSL2

### 2.1 确认虚拟化已开启

`Ctrl + Shift + Esc` → 任务管理器 → 性能 → CPU → 查看右下角 **"虚拟化：已启用"**

![[Pasted image 20260310201207.png]]

如果未启用：重启 → 进 BIOS（`Del` / `F2` / `F10`）→ 找到 `Intel VT-x` 或 `AMD-V`（或 `SVM Mode`）→ 设为 **Enabled** → 保存退出

### 2.2 安装 WSL2

以**管理员身份**打开 PowerShell：

```powershell
wsl --install

# 或者先看可用发行版  
wsl --list --online  
# 指定装 Ubuntu 24.04  
wsl --install -d Ubuntu-24.04
```

> `wsl --install` 会自动启用 WSL、安装 Linux 内核、设 WSL2 为默认、下载 Ubuntu。

安装完成后**重启电脑**。

### 2.3 首次配置 Ubuntu

重启后 Ubuntu 会自动打开（或从开始菜单搜索 "Ubuntu" 打开）：

1. 等待初始化完成
2. 创建用户名（纯英文小写）
3. 创建密码（输入时不显示字符，这是正常的）

> [!warning] 牢记此密码，后续 `sudo` 命令需要。

### 2.4 验证 WSL2

```powershell
wsl --list --verbose
```

确认 VERSION 列为 **2**。如果是 1：

```powershell
wsl --set-version Ubuntu 2
wsl --set-default-version 2
```

> [!NOTE] 📸 **请在此截图**：`wsl --list --verbose` 输出。

---

## 三、配置 WSL2 环境

### 3.1 更新系统

在 Ubuntu 终端中：

```bash
sudo apt update && sudo apt upgrade -y
```

> 如果弹出紫色界面问 `modified configuration files`，选 **keep the local version**，直接回车。

### 3.2 安装基础工具

```bash
sudo apt install -y build-essential curl wget unzip software-properties-common
```

### 3.3 启用 systemd（重要）

OpenClaw 后台服务依赖 systemd。

```bash
sudo nano /etc/wsl.conf
```

添加内容：

```ini
[boot]
systemd=true
```

`Ctrl+O` 保存 → `Ctrl+X` 退出。

在 **Windows PowerShell** 中重启 WSL：

```powershell
wsl --shutdown
```

重新打开 Ubuntu 终端，验证：

```bash
systemctl list-unit-files --type=service | head -20
```

能看到 service 列表即成功。

> [!NOTE] 📸 **请在此截图**：systemctl 输出结果。

---

## 四、安装 Docker Desktop（可选）

> Docker 非必需，但部分 OpenClaw 插件和高级功能会用到。建议安装。

### 4.1 下载安装

1. 下载 [Docker Desktop](https://www.docker.com/products/docker-desktop/)
2. 运行安装程序，安装选项：

| 选项 | 选择 |
|------|------|
| Use WSL 2 instead of Hyper-V | ✅ **必须勾选** |
| Add shortcut to desktop | ✅ 可选 |

> [!NOTE] 📸 **请在此截图**：安装选项界面，确认 WSL 2 已勾选。

3. 安装完成 → **Close and restart** 重启

### 4.2 首次启动配置

1. 打开 Docker Desktop → 接受服务协议
2. Docker Hub 登录 → 可 **Skip** 跳过
3. Welcome Survey → 可 **Skip** 跳过

### 4.3 配置 WSL2 集成

Docker Desktop → ⚙️ Settings：

- **General** → 确认 `Use the WSL 2 based engine` ✅
- **Resources → WSL Integration** → 打开 Ubuntu 的开关 → **Apply & Restart**

> [!NOTE] 📸 **请在此截图**：WSL Integration 页面，Ubuntu 开关已打开。

### 4.4 验证

在 Ubuntu 终端中：

```bash
docker run hello-world
```

看到 `Hello from Docker!` 即成功。

---

## 五、安装 Node.js（v22+）

OpenClaw 严格要求 **Node.js ≥ 22**，推荐用 nvm 管理。

### 5.1 安装 nvm + Node.js

```bash
# 安装 nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
source ~/.bashrc

# 安装 Node.js 22 并设为默认
nvm install 22
nvm alias default 22
```

### 5.2 验证

```bash
node --version   # 应显示 v22.x.x
npm --version    # 应显示 10.x.x
```

> [!NOTE] 📸 **请在此截图**：node 和 npm 版本输出。

---

## 六、安装 Git

```bash
sudo apt install -y git
git --version    # 应显示 git version 2.x.x

# 可选：配置身份信息
git config --global user.name "你的名字"
git config --global user.email "你的邮箱"
```

---

## 七、安装 OpenClaw

OpenClaw 提供两种安装方式，任选其一。

### 方式 A：官方一键安装脚本（推荐）

```bash
curl -fsSL https://openclaw.ai/install.sh | bash
```

> 此脚本会自动检测 Node.js 版本、安装缺失依赖、安装 OpenClaw 并启动 onboarding 向导。

### 方式 B：npm 手动安装

```bash
npm install -g openclaw@latest
openclaw onboard --install-daemon
```

### 验证

```bash
openclaw --version
```

> [!NOTE] 📸 **请在此截图**：安装完成后 `openclaw --version` 的输出。

### 安装出错？

```bash
# 权限问题方案 1：
sudo npm install -g openclaw@latest

# 权限问题方案 2：修改 npm 全局目录
mkdir ~/.npm-global
npm config set prefix '~/.npm-global'
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
npm install -g openclaw@latest
```

---

## 八、配置 OpenClaw

### 8.1 交互式配置向导

如果用方式 B 安装，或需要重新配置：

```bash
openclaw onboard
```

向导会依次引导配置以下内容：

#### 选择 LLM 提供商

```
? Which LLM provider would you like to use?
  ❯ Anthropic (Claude)       ← 推荐，代码能力强
    OpenAI (GPT)
    Google (Gemini)           ← 免费额度多，适合入门
    DeepSeek                  ← 性价比高
    Local (Ollama/LM Studio)  ← 本地模型
    Custom API
```

#### 输入 API Key

| 提供商 | 获取地址 |
|--------|----------|
| Anthropic | [console.anthropic.com](https://console.anthropic.com/) |
| OpenAI | [platform.openai.com/api-keys](https://platform.openai.com/api-keys) |
| Google | [aistudio.google.com/apikey](https://aistudio.google.com/apikey) |
| DeepSeek | [platform.deepseek.com](https://platform.deepseek.com/) |

> [!warning] API Key 是敏感信息，不要泄露！

#### 选择默认模型

推荐选择标记 **`recommended`** 的模型（平衡性能与成本）。

#### 配置消息通道

建议先选 **No**，确保基础安装正常后再通过 `openclaw channels add` 添加。

#### 其他选项

- **时区**：`Asia/Shanghai`
- **数据路径**：保持默认 `~/.openclaw/`

> [!NOTE] 📸 **请在此截图**：onboard 向导完成后的输出。

### 8.2 配置文件与 API Key

配置文件位于 `~/.openclaw/openclaw.json`：

```bash
cat ~/.openclaw/openclaw.json
```

也可以通过命令行或 `.env` 文件管理 API Key：

```bash
# 命令行方式
openclaw config set ANTHROPIC_API_KEY sk-ant-xxxxxxxxx

# .env 文件方式
nano ~/.openclaw/.env
# 添加：ANTHROPIC_API_KEY=sk-ant-xxxxxxxxx
```

---

## 九、启动与验证

### 9.1 启动

```bash
openclaw start
```

### 9.2 查看状态

```bash
openclaw status
```

应显示 Daemon 和 Gateway 都为 `running`。

> [!NOTE] 📸 **请在此截图**：`openclaw status` 输出。

### 9.3 健康检查

```bash
openclaw doctor
```

检查所有依赖和配置是否正确。

> [!NOTE] 📸 **请在此截图**：`openclaw doctor` 输出。

### 9.4 测试对话

```bash
openclaw chat
```

发送 "你好"，确认 AI 正常回复。

### 9.5 Web 控制面板

```bash
openclaw dashboard
```

或浏览器访问 `http://localhost:3007`（端口以实际输出为准）。

### 9.6 日志与管理

```bash
openclaw logs --follow    # 实时日志，Ctrl+C 退出
openclaw stop             # 停止
openclaw restart          # 重启
openclaw gateway restart  # 仅重启网关
```

---

## 十、常见问题

| 问题 | 解决方案 |
|------|----------|
| `wsl --install` 无反应 | 确认 PowerShell 以管理员运行 |
| WSL VERSION 显示 1 | `wsl --set-version Ubuntu 2` |
| Docker Desktop 报错 | 检查 BIOS 虚拟化；管理员运行 `bcdedit /set hypervisorlaunchtype auto` 后重启 |
| `nvm` 找不到 | `source ~/.bashrc` 或重开终端 |
| npm 安装权限错误 | 见第七节备选方案 |
| API Key 无效 | 去提供商控制台重新复制 Key |
| 连接 LLM 超时（国内） | 配置代理，见下方 |
| `openclaw start` 失败 | 检查 systemd：`systemctl --version`；检查端口冲突 |

### 国内代理配置

```bash
# 在 ~/.bashrc 中添加（端口号改为你实际的代理端口）
export http_proxy="http://127.0.0.1:7890"
export https_proxy="http://127.0.0.1:7890"
export all_proxy="socks5://127.0.0.1:7890"
```

```bash
source ~/.bashrc
```

---

## 十一、下一步

- **接入通讯应用**：`openclaw channels add` 接入飞书等 → 详见 [[openclaw接入飞书]]
- **安装插件**：`openclaw plugins install <插件名>`
- **配置多模型**：不同任务用不同模型，优化成本

---

## 命令速查表

```bash
# WSL
wsl --install                           # 安装 WSL2
wsl --list --verbose                    # 查看版本
wsl --shutdown                          # 重启 WSL

# Node.js
nvm install 22                          # 安装 Node.js 22
nvm alias default 22                    # 设为默认

# OpenClaw
openclaw --version                      # 版本
openclaw onboard                        # 配置向导
openclaw start / stop / restart         # 启停
openclaw status                         # 状态
openclaw logs --follow                  # 实时日志
openclaw chat                           # 命令行聊天
openclaw dashboard                      # Web 面板
openclaw doctor                         # 健康检查
openclaw channels add / list            # 通道管理
openclaw gateway restart                # 重启网关
openclaw config set <KEY> <VALUE>       # 设置配置
openclaw plugins install <名称>         # 安装插件
```

---

> 📝 最后更新：2026-03-10

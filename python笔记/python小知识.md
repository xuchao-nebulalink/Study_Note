
# WSL 环境下安装与切换 Python 3.12.10 版本指南

> **⚠️ 核心警告：绝对不要卸载或覆盖系统自带的 Python 3.10.12！**
> Ubuntu 底层系统工具（如 `apt` 等）严重依赖默认的 Python 环境。我们将采用**共存安装**的方式，让新旧版本互不干扰。

---

## 🌟 方法一：使用 pyenv 安装与管理（最推荐，适合开发）
`pyenv` 是 Python 版本管理神器，不仅不会污染系统环境，而且在多版本之间切换极其方便。

### 1. 安装编译所需的系统依赖
```bash
sudo apt update
sudo apt install -y make build-essential libssl-dev zlib1g-dev \
libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev git

### 2. 一键安装 pyenv
```bash
curl https://pyenv.run | bash
```

### 3. 配置环境变量
如果你使用的是默认的 Bash，执行以下命令将配置写入 `~/.bashrc`：
```bash
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(pyenv init -)"' >> ~/.bashrc
source ~/.bashrc  # 让配置立即生效
```
*(注：如果你使用 `zsh`，请将上述命令中的 `~/.bashrc` 全部替换为 `~/.zshrc`)*

### 4. 安装指定的 Python 3.12.10
```bash
pyenv install 3.12.10
```

### 🔄 5. 如何切换 Python 版本（pyenv 核心用法）
使用 pyenv，你无需修改任何系统底层的命令，主要有三种切换策略：

- **全局切换 (Global)**：更改你这个用户的默认 Python 版本
  ```bash
  pyenv global 3.12.10
  ```
  *(验证：此时在任意处输入 `python --version` 都会显示 3.12.10)*

- **局部切换 (Local)**：仅针对某个具体的项目/文件夹切换版本（极度推荐）
  ```bash
  cd /your/project/path
  pyenv local 3.12.10
  ```
  *(说明：这会在当前目录生成一个隐藏的 `.python-version` 文件。以后只要终端进入这个目录，Python 版本就会自动切换成 3.12.10，离开目录又会恢复默认。)*

- **当前会话切换 (Shell)**：仅在当前终端窗口临时生效，关闭窗口即失效
  ```bash
  pyenv shell 3.12.10
  ```

---


# 🐧 Linux (WSL) vs 🪟 Windows：Python 虚拟环境对比指南

> **💡 核心要点：**
> 无论什么系统，推荐的虚拟环境文件夹名称统一为 `.venv`（注意前面有个点）。
> 核心模块都是内置的 `venv`，区别主要在于系统的终端路径和脚本调用方式。

---

## 🐧 一、Linux / macOS (包括 WSL) 下的操作

Linux 和 macOS 使用基于 Bash/Zsh 的终端，激活脚本存放在虚拟环境的 `bin/` 目录下。

### 1. 创建虚拟环境
```bash
# 默认写法
python -m venv .venv

# 如果你的系统需要区分 python2 和 python3，请用：
python3 -m venv .venv


### 2. 激活虚拟环境
```bash
source .venv/bin/activate
```
*(激活成功后，命令行开头会出现 `(.venv)` 提示符)*

### 3. 退出虚拟环境
```bash
deactivate
```

---
## 🪟 二、Windows 下的操作

Windows 下通常使用 PowerShell 或 CMD，激活脚本存放在虚拟环境的 `Scripts\` 目录下。

### 1. 创建虚拟环境
```powershell
python -m venv .venv
```
*(如果提示找不到 python，请确保在安装 Python 时勾选了 "Add Python to PATH")*

### 2. 激活虚拟环境

Windows 有两种常见的命令行工具，激活命令略有不同：

**👉 情况 A：如果你使用的是 PowerShell (Win10/11 默认终端)**
```powershell
.\.venv\Scripts\Activate.ps1
```

**👉 情况 B：如果你使用的是传统的 CMD (命令提示符)**
```cmd
.venv\Scripts\activate.bat
```
*(激活成功后，命令行开头同样会出现 `(.venv)` 提示符)*

### 3. 退出虚拟环境
```powershell
deactivate
```

---

## ⚠️ Windows 下常见报错及解决办法

### ❌ 报错："在此系统上禁止运行脚本 (Execution_Policies)"
在 Windows 的 **PowerShell** 中首次激活虚拟环境时，90% 的人会遇到大红字的报错，提示系统禁止运行脚本。这是 Windows 的安全策略导致的。

**✅ 解决办法：**
1. 仍然在 PowerShell 中，执行以下命令：
   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
2. 系统会问你是否更改策略，输入 `Y` 并按回车确认。
3. 重新执行激活命令 `.\.venv\Scripts\Activate.ps1`，即可成功。
   *(这个设置是永久生效的，以后在这台电脑上激活任何虚拟环境都不会再报错了。)*
```
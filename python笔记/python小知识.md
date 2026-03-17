
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




# 🐍 Python 虚拟环境与包管理极简笔记 (Linux & Windows)

**统一规范**：推荐将虚拟环境统一命名为 `.venv`（隐藏文件夹，各大编辑器默认识别）。

---

## 🐧 一、 Linux / macOS (WSL)

### 1. 创建与激活
```bash
# 1. 创建虚拟环境 (如指定版本可将 python 替换为 python3.12)
python -m venv .venv

# 2. 激活环境
source .venv/bin/activate
### 2. 验证环境是否生效
```bash
which python
which pip
```
> **✅ 正确输出**：两者的路径都必须包含当前目录的 `.venv`。
> **❌ 错误输出**：如果 `which pip` 指向了全局（如 `~/.pyenv/shims/pip` 或 `/usr/bin/pip`），说明环境有问题，请看下文的“防坑绝招”。

---

## 🪟 二、 Windows

### 1. 创建与激活
```powershell
# 1. 创建虚拟环境
python -m venv .venv

# 2. 激活环境 (PowerShell 终端)
.venv\Scripts\activate
```
> **⚠️ PowerShell 报错“禁止运行脚本”解决办法**：
> 以管理员身份打开 PowerShell，执行一次：`Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`，输入 `Y` 确认，之后即可永久正常激活。

### 2. 验证环境是否生效
```powershell
where python
where pip
```
> 同样，输出的路径首行必须是你项目下的 `.venv` 文件夹。

---

## 🛡️ 三、 安装依赖包（防坑必看！）

**🔥 核心痛点**：有时候 `which python` 是对的，但 `which pip` 却指向了系统全局（比如被 `pyenv` 拦截），导致直接 `pip install` 会把包错误地装到系统环境里。

**🌟 标准动作（终极防坑绝招）**：
在虚拟环境中，**永远不要直接用 `pip install`，而是加上 `python -m` 前缀！**

```bash
# 完美安装命令，绝对不会装歪！
python -m pip install requests          # 安装单个包
python -m pip install numpy pandas      # 安装多个包
python -m pip install -r requirements.txt # 根据列表批量安装
```
*原理解析：只要 `which python` 的路径是对的，`python -m pip` 就会强制使用虚拟环境肚子里的 pip，百分百装在 `.venv` 里。*

---

## 🚪 四、 退出虚拟环境

无论 Linux 还是 Windows，退出命令均相同：
```bash
deactivate
```
```
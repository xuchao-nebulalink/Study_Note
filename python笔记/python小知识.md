


这里为你整理了一份结构清晰的 Markdown 格式笔记，你可以直接点击右上角的“复制”按钮，粘贴到你的 Typora、Obsidian 或其他笔记软件中。

我已经把 **“如何切换 Python 版本”** 的技巧作为重点补充到了各个方法中。

***

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


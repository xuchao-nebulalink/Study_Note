
# Windows 11 Git 多平台 SSH 配置指南

本指南用于在同一台电脑上为 GitHub、GitLab、Gitee 配置独立的 SSH 密钥，并为不同项目设置不同的用户名。

### 步骤 1：为各平台生成 SSH 密钥

为每个平台创建独立的 SSH 密钥文件。打开 Git Bash 并执行以下命令：

```bash
# 为 GitHub 生成密钥 (将邮箱替换成你自己的)
ssh-keygen -t rsa -b 4096 -C "your_email@example.com" -f ~/.ssh/id_rsa_github

# 为 GitLab 生成密钥
ssh-keygen -t rsa -b 4096 -C "your_email@example.com" -f ~/.ssh/id_rsa_gitlab

# 为 Gitee 生成密钥
ssh-keygen -t rsa -b 4096 -C "your_email@example.com" -f ~/.ssh/id_rsa_gitee
```
> 在提示输入密码（passphrase）时，可以直接按回车键跳过。

### 步骤 2：在各平台添加公钥

将每个平台对应的 **公钥** (`.pub` 文件) 内容添加到网站的 SSH 配置中。

*   **GitHub 公钥**: 复制 `~/.ssh/id_rsa_github.pub` 的内容。
*   **GitLab 公钥**: 复制 `~/.ssh/id_rsa_gitlab.pub` 的内容。
*   **Gitee 公钥**: 复制 `~/.ssh/id_rsa_gitee.pub` 的内容。

分别登录各平台网站，在 `Settings -> SSH Keys` (或类似名称的菜单) 中添加新公钥。

### 步骤 3：创建并配置 `config` 文件

这是实现多账户管理的核心。在 `~/.ssh/` 目录下创建一个名为 `config` (无扩展名) 的文件，并填入以下内容：

```
# GitHub
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_rsa_github
  IdentitiesOnly yes

# GitLab
Host gitlab.com
  HostName gitlab.com
  User git
  IdentityFile ~/.ssh/id_rsa_gitlab
  IdentitiesOnly yes

# Gitee
Host gitee.com
  HostName gitee.com
  User git
  IdentityFile ~/.ssh/id_rsa_gitee
  IdentitiesOnly yes
```

### 步骤 4：启动 SSH 代理并添加密钥

在 Git Bash 中启动 `ssh-agent` 并将私钥添加进去。

```bash
# 启动代理 (如果遇到 'Could not open a connection' 错误，执行此命令)
eval $(ssh-agent -s)

# 添加所有私钥到代理
ssh-add ~/.ssh/id_rsa_github
ssh-add ~/.ssh/id_rsa_gitlab
ssh-add ~/.ssh/id_rsa_gitee
```
> **提示**: 为了让 `ssh-agent` 开机自启，可以在 Windows 服务 (`services.msc`) 中找到 `OpenSSH Authentication Agent`，将其启动类型设为“自动”。

### 步骤 5：测试连接

验证每个平台的 SSH 连接是否成功。

```bash
ssh -T git@github.com
ssh -T git@gitlab.com
ssh -T git@gitee.com
```
如果看到包含你对应用户名的欢迎信息，则表示配置成功。

### 步骤 6：配置 Git 用户信息（这个可以只配置一个即可）

为确保提交记录的作者信息正确，推荐在每个项目中单独设置用户名。

```bash
# 1. (可选) 设置全局邮箱，因为你的邮箱都一样
git config --global user.email "your_email@example.com"

# 2. 清除全局用户名设置 (避免混淆)
git config --global --unset user.name

# 3. 进入你的项目目录，为项目单独设置用户名
# 例如，在一个 GitHub 项目中：
cd /path/to/your/github_project
git config user.name "YourGitHubUsername"

# 在一个 GitLab 项目中：
cd /path/to/your/gitlab_project
git config user.name "YourGitLabUsername"
```

---
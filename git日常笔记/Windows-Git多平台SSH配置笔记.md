
# Windows 11 Git 多平台 SSH 配置指南

本指南用于在 Windows 11 的 Git Bash 中为 GitHub、GitLab、Gitee 配置独立的 SSH 密钥。三个平台共用提交者姓名 `xuchao-nebulalink` 和邮箱 `xcwindfall@163.com`，全局设置一次即可。

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

本文使用 Git Bash 自带的 SSH 与 `ssh-agent`。密钥没有口令、且 `config` 已指定 `IdentityFile` 时，可以直接连接；需要把密钥加入代理时，按下面操作。Linux 是否需要代理同样取决于密钥和会话配置，不能一概省略。

```bash
# 当前终端没有可用代理，或提示 'Could not open a connection' 时执行
eval "$(ssh-agent -s)"

# 添加所有私钥到代理
ssh-add ~/.ssh/id_rsa_github
ssh-add ~/.ssh/id_rsa_gitlab
ssh-add ~/.ssh/id_rsa_gitee
```
Windows 的 `OpenSSH Authentication Agent` 系统服务与 Git Bash 自带的代理可能属于两套实现。开启系统服务，不会自动让 Git Bash 使用该服务。本节统一使用 Git Bash 的代理；重新打开终端后，如需使用代理，应检查当前会话是否仍能连接。[GitHub 官方说明](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent?platform=windows)

### 步骤 5：测试连接

验证每个平台的 SSH 连接是否成功。

```bash
ssh -T git@github.com
ssh -T git@gitlab.com
ssh -T git@gitee.com
```
如果看到包含你对应用户名的欢迎信息，则表示配置成功。

### 步骤 6：配置三个平台共用的 Git 用户信息

三个平台共用同一套提交身份，保留全局姓名和邮箱，未来新仓库会自动继承。`user.name` 是提交记录显示的姓名，不必等于平台账号名。[GitHub 官方说明](https://docs.github.com/en/get-started/git-basics/setting-your-username-in-git)

```bash
git config --global user.name "xuchao-nebulalink"
git config --global user.email "xcwindfall@163.com"
```

检查配置：

```bash
git config --global user.name
git config --global user.email
```

如果未来某个项目确实需要不同的提交身份，再进入那个仓库设置局部姓名或邮箱；仓库级设置会覆盖全局设置。

---

注意：如果gitlab需要指定的话比如是192.168.4.21需要在config文件中修改。吧gitlab.com修改成192.168.4.21即可



gittee如何出现要输入密码的操作：
设置成ssh的：git remote set-url origin git@gitee.com:username/repository.git

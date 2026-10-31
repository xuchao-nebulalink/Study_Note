# Mac mini：Git 安装与 GitHub / GitLab / Gitee SSH 配置笔记

记录日期：2026-10-31。适用于 Apple 芯片 Mac、macOS、zsh 终端。

这份笔记从新机安装写起，使用本次实际选择的方案：三个平台共用提交邮箱，各用一把无密码 SSH 密钥。安装和配置不需要先创建仓库。已经完成的步骤不用重做。

| 项目 | 本次配置 |
| --- | --- |
| 提交者姓名 | `xuchao-nebulalink` |
| 三个平台共用的提交邮箱 | `xcwindfall@163.com` |
| Git 来源 | Homebrew，路径 `/opt/homebrew/bin/git` |
| 本次检查到的 Git 版本 | `2.56.0`，以后版本可能不同 |
| SSH 密钥算法 | Ed25519 |
| 密钥密码 | 未设置；生成时两次直接回车 |
| GitLab 站点 | `gitlab.com`；公司自建 GitLab 需换成公司域名 |

**1．安装 Apple 命令行工具**

打开「终端」，先检查：

```bash
xcode-select -p
```

如果显示 `/Library/Developer/CommandLineTools` 等有效路径，跳过安装。未安装时执行：

```bash
xcode-select --install
```

在弹窗中完成安装，再继续。命令行工具也包含 Apple 版 Git，本笔记后续统一使用 Homebrew 版。[Git 官方安装说明](https://git-scm.com/install/mac)

**2．安装 Homebrew 并配置命令路径**

先检查是否已有 Homebrew：

```bash
brew --version
```

能显示版本就跳过安装。提示找不到命令时，先检查是否已经安装在默认位置：

```bash
/opt/homebrew/bin/brew --version
```

如果这个命令能显示版本，直接配置下面的命令路径。如果这个文件也不存在，再执行官方安装命令，按终端提示完成安装：

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Apple 芯片 Mac 默认安装到 `/opt/homebrew`。新装完成后，按安装程序的 `Next steps` 提示配置路径；默认 zsh 环境通常执行下面两行。第一行只需添加一次，不要反复追加：[Homebrew 官方安装说明](https://brew.sh/)

```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

再次运行 `brew --version`，能显示版本即可。

**3．安装并检查 Git、SSH**

```bash
brew install git
```

安装后检查：

```bash
command -v git
git --version
ssh -V
```

Git 路径预期为 `/opt/homebrew/bin/git`，版本以实际输出为准。如果仍显示 Apple 自带的 Git，重新打开终端后再检查。macOS 自带 SSH，无需另外通过 Homebrew 安装 OpenSSH。[Git 安装说明](https://git-scm.com/install/mac)、[GitLab SSH 前提条件](https://docs.gitlab.com/user/ssh/#prerequisites)

**4．设置三个平台共用的 Git 身份**

```bash
git config --global user.name "xuchao-nebulalink"
git config --global user.email "xcwindfall@163.com"
```

检查保存结果：

```bash
git config --global user.name
git config --global user.email
```

预期输出分别为：

```text
xuchao-nebulalink
xcwindfall@163.com
```

这里的 `user.name` 是提交记录中显示的姓名，不必等于平台登录账号。三个平台邮箱相同，全局设置一次即可；以后新仓库自动使用，除非仓库单独设置了其他邮箱。确认这个邮箱已经添加到各个平台账号并完成验证。[GitHub 提交邮箱说明](https://docs.github.com/en/account-and-profile/how-tos/email-preferences/setting-your-commit-email-address)

**5．生成三把无密码 SSH 密钥**

先准备目录并查看已有文件：

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
ls -la ~/.ssh
```

本机已经生成的密钥继续使用即可。下面用于首次配置；已有同名密钥时跳过对应的生成命令，避免覆盖。

GitHub：

```bash
ssh-keygen -t ed25519 -C "xcwindfall@163.com" -f ~/.ssh/id_ed25519_github
```

GitLab：

```bash
ssh-keygen -t ed25519 -C "xcwindfall@163.com" -f ~/.ssh/id_ed25519_gitlab
```

Gitee：

```bash
ssh-keygen -t ed25519 -C "xcwindfall@163.com" -f ~/.ssh/id_ed25519_gitee
```

逐条执行，每条完成后再执行下一条。遇到以下两个提示，都直接按回车，这就是本次采用的无密码方案：

```text
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
```

`-f` 指定保存文件名，避免三把密钥相互覆盖；`-C` 后面的邮箱只是备注，不决定 Git 提交邮箱。[GitLab 密钥生成说明](https://docs.gitlab.com/user/ssh/#generate-an-ssh-key-pair)、[Gitee 密钥生成说明](https://help.gitee.com/repository/ssh-key/generate-and-add-ssh-public-key)

生成后应有以下文件：

| 平台 | 私钥，留在本机 | 公钥，添加到平台 |
| --- | --- | --- |
| GitHub | `~/.ssh/id_ed25519_github` | `~/.ssh/id_ed25519_github.pub` |
| GitLab | `~/.ssh/id_ed25519_gitlab` | `~/.ssh/id_ed25519_gitlab.pub` |
| Gitee | `~/.ssh/id_ed25519_gitee` | `~/.ssh/id_ed25519_gitee.pub` |

无密码私钥可直接用于认证，所以只把 `.pub` 公钥添加到平台，私钥不要外传。

**6．配置 SSH 自动选择对应密钥**

下面适用于首次配置，原本没有其他 SSH 配置。如果已经配置了服务器等内容，应把这些 `Host` 条目合并进现有文件。

整段复制执行，包括最后单独一行的 `EOF`：

```bash
cat > ~/.ssh/config <<'EOF'
Host github.com gitlab.com gitee.com
  User git
  AddKeysToAgent yes
  IdentitiesOnly yes

Host github.com
  IdentityFile ~/.ssh/id_ed25519_github

Host gitlab.com
  IdentityFile ~/.ssh/id_ed25519_gitlab

Host gitee.com
  IdentityFile ~/.ssh/id_ed25519_gitee
EOF

chmod 600 ~/.ssh/config
chmod 600 ~/.ssh/id_ed25519_github ~/.ssh/id_ed25519_gitlab ~/.ssh/id_ed25519_gitee
```

执行后没有输出是正常的。`User git` 是平台 SSH 连接使用的固定用户名，不要换成自己的账号或邮箱。`IdentityFile` 决定连接各平台时使用哪把密钥。

本次密钥没有密码，因此配置中省略 `UseKeychain yes`，后面也不用 `--apple-use-keychain`。[GitHub macOS 密钥配置说明](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent?platform=mac)

**7．加载密钥**

```bash
/usr/bin/ssh-add ~/.ssh/id_ed25519_github
/usr/bin/ssh-add ~/.ssh/id_ed25519_gitlab
/usr/bin/ssh-add ~/.ssh/id_ed25519_gitee
```

看到 `Identity added` 表示已加入当前 SSH agent。若提示无法连接 agent，先执行下面这条，再重试上述命令：

```bash
eval "$(/usr/bin/ssh-agent -s)"
```

已有 `IdentityFile` 和 `AddKeysToAgent yes` 配置，无密码密钥在以后连接时也能直接读取并自动加载；重启后不需要重新生成密钥。

**8．把三把公钥分别添加到平台账号**

每复制一把，就去对应平台粘贴保存，再复制下一把。`pbcopy` 没有输出是正常的，内容已经进入剪贴板。

GitHub：

```bash
pbcopy < ~/.ssh/id_ed25519_github.pub
```

打开 [GitHub SSH 设置](https://github.com/settings/keys)，点击 **New SSH key**。Title 填 `Mac mini`，Key type 选 **Authentication Key**，Key 中按 `Command + V` 粘贴，然后保存。[GitHub 添加公钥说明](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account)

GitLab：

```bash
pbcopy < ~/.ssh/id_ed25519_gitlab.pub
```

打开 [GitLab SSH 设置](https://gitlab.com/-/user_settings/ssh_keys)，点击 **Add new key**。Title 填 `Mac mini`，Key 中粘贴；Usage type 选择 **Authentication**，或保留 **Authentication & Signing**，然后保存。留意页面的到期日期设置。[GitLab 添加公钥说明](https://docs.gitlab.com/user/ssh/#add-an-ssh-key-to-your-gitlab-account)

Gitee：

```bash
pbcopy < ~/.ssh/id_ed25519_gitee.pub
```

打开 [Gitee 账号 SSH 公钥设置](https://gitee.com/profile/sshkeys)，标题填 `Mac mini`，粘贴公钥后保存，按网页提示完成验证。这里添加到个人账号的 SSH 公钥设置，无需先创建仓库。

**9．分别测试连接**

逐条执行并查看结果，不要用 `&&` 把三个测试连起来。

```bash
ssh -T git@github.com
```

```bash
ssh -T git@gitlab.com
```

```bash
ssh -T git@gitee.com
```

首次连接可能显示主机指纹并询问：

```text
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

核对平台官方公布的主机指纹，确认匹配后输入 `yes`。[GitHub 主机指纹](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints)、[GitLab 主机指纹](https://docs.gitlab.com/user/gitlab_com/#ssh-host-keys-fingerprints)

| 平台 | 成功标志 | 本次已提供的结果 |
| --- | --- | --- |
| GitHub | 返回账号名，包含 `successfully authenticated` | 截图已确认成功 |
| GitLab | 包含 `Welcome to GitLab` | 尚未提供测试结果，待确认 |
| Gitee | 返回账号名，包含 `successfully authenticated` | 截图已确认成功 |

`does not provide shell access` 是正常提示，表示平台提供 Git 服务，不提供交互式终端。GitHub 测试成功时也可能返回退出码 `1`，因此以认证提示判断。[GitHub 测试连接说明](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/testing-your-ssh-connection)

这一步验证的是账号 SSH 认证。实际仓库的克隆、推送，需要以后创建或获得仓库权限后再操作。

**10．以后创建仓库时怎么用**

在对应平台网页创建仓库，复制页面提供的 **SSH 克隆地址**，在自己想保存项目的文件夹中执行 `git clone`。下面是地址格式示例，账号、组织和仓库名以网页实际地址为准：

```bash
git clone git@github.com:你的账号/仓库名.git
```

```bash
git clone git@gitlab.com:你的账号或组名/仓库名.git
```

```bash
git clone git@gitee.com:你的账号/仓库名.git
```

三个平台的仓库都会继承全局提交邮箱 `xcwindfall@163.com`，不必逐个仓库重新设置。SSH 连接由域名自动匹配对应密钥。

进入仓库后，可以检查实际使用的提交身份和远程地址：

```bash
git config user.name
git config user.email
git remote -v
```

如果将来某个仓库需要不同邮箱，只在该仓库目录内执行：

```bash
git config --local user.email "那个仓库需要使用的邮箱"
```

仓库级设置会覆盖全局设置；同一份提交推到不同平台时，提交里的邮箱不会随推送目标改变。[Git 配置说明](https://git-scm.com/docs/git-config)

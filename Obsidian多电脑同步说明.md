# Obsidian 多电脑同步说明

## 仓库中同步哪些内容

- 学习笔记、图片和其他附件。
- `.obsidian/app.json`、`appearance.json`、核心插件设置、社区插件启用列表、书签和图谱设置。
- `.obsidian/plugins/` 中的插件安装文件，包括 Git、Open in terminal、MCP Tools；以后安装的新插件文件也会被 Git 纳入同步。
- Git 插件的 `data.json`：当前设置为每 10 分钟自动提交、每 10 分钟推送、每 5 分钟拉取，启动时拉取，推送前先拉取。自动提交与推送使用独立计时器，需要立即同步时请手动执行同步命令。

各电脑独立保存窗口布局、缓存、回收站，以及其他插件的 `data.json`。其他插件的配置可能包含 API Key、令牌或本机程序路径，只有检查过的通用配置才应加入 `.gitignore` 白名单。插件安装文件同步，不代表所有插件设置都会同步。

Git 插件当前版本把登录凭据、Git 程序路径等存入本机存储，不在共享的 `data.json` 中。请保持共享设置里的 `basePath` 和 `gitDir` 为空；如需自定义脚本，也要避免写入只能在某台电脑使用的绝对路径。

本次还停止跟踪了 Git 插件的认证临时文件 `git_credentials_input` 和 `.response`。此前的密码提示响应非空，旧提交中仍有历史副本；如果当时输入的是真实密码，请更换该密码。停止跟踪不会清除 Git 历史。

## 在另一台电脑首次使用

1. 安装 Obsidian 和 Git。先确认终端执行 `git --version` 能成功；若刚安装 Git，请重启 Obsidian，使它读取新的 PATH。
2. 在准备存放笔记的父目录打开终端，克隆仓库：

   ```powershell
   git clone https://github.com/xuchao-nebulalink/Study_Note.git "Obsidian学习笔记合集"
   cd "Obsidian学习笔记合集"
   ```

   请克隆仓库，不要下载 ZIP 或只复制笔记文件：Git 插件需要克隆时生成的 `.git` 目录。

3. 检查这台电脑的提交身份；若还没有配置，在仓库目录内设置：

   ```powershell
   git config user.name "你的 GitHub 用户名"
   git config user.email "你的 GitHub 邮箱"
   ```

4. 在终端执行 `git pull --ff-only` 和 `git push --dry-run origin main`，确认网络与写入权限正常。需要登录时，按 Git Credential Manager 的提示在这台电脑登录有仓库写入权限的 GitHub 账号；凭据无需从旧电脑复制。
5. 在 Obsidian 选择“打开本地仓库”，打开刚克隆的整个文件夹，信任自己仓库中的插件并允许社区插件运行。插件文件和启用列表会随仓库带过来，无需逐个重新安装。
6. 检查 Git 插件是否正常加载。若提示找不到 Git，在插件设置中为这台电脑指定正确的 Git 程序路径。
7. Open in terminal 等依赖系统程序的插件，在每台电脑按实际安装位置设置；这些本机设置不会覆盖其他电脑。

## 日常在不同电脑间切换

开始编辑前，先执行命令面板中的 `Git: Pull`，确认没有报错。离开这台电脑前执行 `Git: Commit-and-sync`，等待同步成功；该命令名称对应当前 Git 插件版本。

另一台电脑先拉取再编辑。尽量避免两台电脑同时修改同一篇笔记；若出现冲突，需要保留双方内容并完成合并后再同步，不要用强制推送覆盖另一台电脑的笔记。

## 本次同步故障及代理排查

本次检查发现，这台电脑的 Git 全局代理设置为 `http://127.0.0.1:7897`，但该端口没有代理服务监听，导致拉取和推送失败；绕过代理可以访问 GitHub。本次只在当前仓库的 `.git/config` 设置 `remote.origin.proxy` 为空，让这个仓库直连。

该设置是每个克隆独立的本机配置，不会随笔记同步，也不改变其他仓库的全局代理。其他电脑网络正常时无需修改代理。如果同样出现 `127.0.0.1` 代理连接失败，可先检查：

```powershell
git config --show-origin --get-regexp '^(http|https)\..*proxy$|^remote\..*\.proxy$'
```

在终端执行以下命令，可打开当前仓库的 Git 配置文件：

```powershell
git config --local --edit
```

如果这台电脑可以直连 GitHub，在现有 `[remote "origin"]` 段内加入 `proxy =`（等号后留空），即可让这个远程绕过代理；若必须使用代理，则填写这台电脑实际运行的代理地址和端口。保存后用 `git ls-remote --heads origin main` 验证连通性。

参考：[Git 的远程代理配置](https://git-scm.com/docs/git-config#Documentation/git-config.txt-remoteltnamegtproxy)、[Obsidian Git 的忽略规则说明](https://publish.obsidian.md/git-doc/Tips-and-Tricks)。

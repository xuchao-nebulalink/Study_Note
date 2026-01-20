这也是为你准备的**WSL 2 网络配置精简笔记**，适合直接复制保存。

---

### 📝 WSL 2 网络配置笔记

**核心机制**：WSL 2 默认使用 NAT 虚拟网络，**IP 是动态的**，每次重启都会变。**不要**在 Linux 内部设置静态 IP。

#### 1. 最佳方案：镜像网络模式 (推荐 Win11 用户)
让 WSL 像 WSL1 一样直接共享 Windows 的 IP，不再有独立 IP，解决所有连接烦恼。

*   **配置方法**：
    在 Windows 用户目录 (`C:\Users\你的用户名\`) 新建或编辑 `.wslconfig` 文件，写入：
    ```ini
    [wsl2]
    networkingMode=mirrored
    ```
*   **生效命令** (PowerShell)：
    ```powershell
    wsl --shutdown
    ```

#### 2. 本机访问 (Windows 访问 WSL)
无需查 IP，WSL 自动支持 localhost 转发。
*   **方法**：直接在 Windows 浏览器/工具输入 `localhost:端口` (如 `localhost:8080`)。

#### 3. 局域网访问 (外部设备访问 WSL)
因 WSL 是 NAT 网络，外部无法直接访问，需做 **端口映射**。

*   **管理员 PowerShell 命令模板**：
    ```powershell
    # 格式：connectaddress 填 WSL 的 IP
    netsh interface portproxy add v4tov4 listenport=8080 listenaddress=0.0.0.0 connectport=8080 connectaddress=172.x.x.x
    ```
*   **查看转发规则**：`netsh interface portproxy show all`
*   **删除转发规则**：`netsh interface portproxy delete v4tov4 listenport=8080 listenaddress=0.0.0.0`

---
**💡 总结建议：** 能用 **镜像模式** 就用镜像模式，最省心；否则本机开发用 **localhost**。
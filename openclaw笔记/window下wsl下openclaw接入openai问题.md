# 填坑日记：WSL2 + Clash Verge + OpenClaw 网络血泪史

**日期**：2026年3月10日

## 💣 踩坑背景
今天在 WSL 环境下配置 OpenClaw，准备接入 OpenAI 时卡在了 OAuth 授权环节。每次执行 `openclaw onboard`，终端都会无情地抛出报错：
`TypeError: fetch failed`

## 🕵️ 排查与挣扎过程
1. **起初以为是没有走代理**：在 WSL 里手动配置了 `HTTP_PROXY` / `HTTPS_PROXY` 环境变量。结果发现 Node.js 18+ 内置的原生 `fetch` 极其“头铁”，默认直接无视系统环境变量，依然尝试直连导致撞墙报错。
2. **尝试修改 `.wslconfig`**：加入了 Windows 11 的新特性 `networkingMode=mirrored` (镜像网络) 和 `autoProxy=true`。这确实解决了一个痛点：让浏览器授权后的 `localhost` 端口能够顺畅回调到 WSL。但是，`fetch failed` 的报错依然坚如磐石！
3. **尝试各种 Clash 兜底设置**：开启了“局域网连接 (Allow LAN)”，关闭了“IPv6”，甚至开启了终极武器 **TUN 模式 (虚拟网卡接管)**，Node.js 却依然报错，仿佛身处网络黑洞。

## 💡 破案时刻与终极解法
经过层层扒皮，最后发现居然是**系统底层路由打架**了！罪魁祸首竟然是用来优化网络的 `networkingMode=mirrored`。

```
node -e "fetch('https://auth.openai.com').then(r=>console.log('✅ Node.js 连通了！状态码:', r.status)).catch(e=>console.error('❌ 还是连不上，报错:', e.message))"
```
输出是：✅ Node.js 连通了就ok

**最终解决步骤：**
1. **斩断镜像网络**：打开 `C:\Users\<用户名>\.wslconfig`，果断把 `networkingMode=mirrored` 删掉（或改成注释 `#networkingMode=mirrored`），让 WSL 强制回退到传统的 NAT 模式。
2. **彻底重启 WSL**：在 PowerShell 执行 `wsl --shutdown`。
3. **启用 TUN 模式兜底**：确保 Clash Verge 开启了 TUN 模式（虚拟网卡模式），接管全局流量。
4. **手动闭环授权**：重新在 WSL 运行 `openclaw onboard`。当终端吐出 `https://auth.openai.com...` 的超长授权链接时，手动复制到 Windows 浏览器中打开。
5. **灵魂一步（复制回调）**：授权完成后，浏览器会尝试跳回本地导致报错。此时不要慌，直接把浏览器地址栏里那串带有 `code=xxx` 的完整 `http://localhost:1455/auth/callback...` 链接复制下来，贴回 WSL 终端里敲回车。
6. **✅ Success！**

## 🧠 技术总结：为什么会这样？
Windows 11 的 WSL2 镜像网络 (`mirrored`) 虽然让本地端口互通变得极度丝滑，但它的底层机制会让 WSL 直接绑定 Windows 的物理网卡。这就导致 WSL 里发出的流量（比如 Node.js 固执的直连请求）直接从物理网卡“溜走”，完美绕过了 Clash TUN 模式创建的虚拟网卡。

删掉镜像网络后，WSL 回退为内部局域网里的一台虚拟机 (NAT 模式)。此时它的流量必须先发给 Windows 宿主机，只要一进入 Windows 的通用路由表，立刻就被 TUN 虚拟网卡逮个正着，乖乖被塞进代理通道。

**血泪教训：** 在搞涉及到底层网络请求的开发时，WSL 的“镜像网络”和 VPN的“TUN 虚拟网卡”就是水火不容的冤家！老老实实用 NAT 模式 + TUN 强制接管才是最稳的解法。
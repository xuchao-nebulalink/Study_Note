# 海外 VPS 网络中转部署笔记：从买服务器到导入 Clash Verge / v2rayN

> 用途：个人合法网络加速、远程访问海外服务。不要共享、售卖节点，不要跑违规业务。
>
> 本笔记按：**买好 VPS → 登录服务器 → 安装 3x-ui → 创建 VLESS Reality 节点 → 导入 v2rayN → 导入 Clash Verge Rev** 整理。

---

## 0. 最终方案

推荐组合：

```text
海外 VPS
+ Ubuntu 系统
+ 3x-ui 面板
+ VLESS + Reality + TCP RAW + xtls-rprx-vision
+ Windows 客户端：v2rayN / Clash Verge Rev
```

第一次搞，优先用：

```text
v2rayN 先跑通
再转 Clash Verge Rev
```

原因：v2rayN 对 `vless://` 分享链接支持更直接。

---

## 1. 服务器购买建议

### 1.1 服务器选择

优先选这些地区：

```text
美国洛杉矶
日本东京
新加坡
香港
```

个人用，最低配置就够：

```text
1 核 CPU
1G 内存
20G 硬盘
1TB 流量
100M 带宽
```

### 1.2 价格参考

普通海外 VPS：

```text
30 ~ 50 元/月
```

优化线路 / 9929 / CN2 / 住宅 IP：

```text
50 ~ 150+ 元/月
```

刚开始不要年付，先月付测试。

### 1.3 购买后你要拿到这些信息

```text
服务器 IP
SSH 端口，一般是 22
root 用户名
root 密码
系统：Ubuntu / Debian
```

---

## 2. 登录服务器

Windows 可以用：

```text
Xshell
FinalShell
Windows Terminal / PowerShell
```

命令行登录：

```bash
ssh root@你的服务器IP
```

例如：

```bash
ssh root@1.2.3.4
```

第一次提示 yes/no，输入：

```bash
yes
```

然后输入 root 密码。

---

## 3. 更新系统

登录后先切 root：

```bash
sudo -i
```

更新系统：

```bash
apt update && apt upgrade -y
apt install -y curl wget ufw ca-certificates
```

设置时区：

```bash
timedatectl set-timezone Asia/Shanghai
```

如果升级时提示：

```text
What do you want to do about modified configuration file sshd_config?
```

选择：

```text
keep the local version currently installed
```

也就是保留当前 SSH 配置，避免远程 SSH 登录出问题。

---

## 4. 安装 3x-ui

执行官方脚本：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
```

安装过程中按下面填。

### 4.1 面板端口

它问：

```text
Would you like to customize the Panel Port settings? [y/n]
```

输入：

```text
y
```

然后端口填一个随机高位端口，例如：

```text
39127
```

### 4.2 用户名密码

不要用默认 admin。

示例：

```text
用户名：自己设置，比如 qhadmin
密码：设置复杂密码
```

### 4.3 面板路径

建议设置随机路径，例如：

```text
/my-3x-panel-8291/
```

也可以让它自动生成。

### 4.4 SSL 证书

它问 SSL 的时候：

```text
Choose SSL certificate setup method
```

如果你没有域名，可以选：

```text
2. Let's Encrypt for IP Address
```

如果问 IPv6：

```text
Do you have an IPv6 address to include?
```

没有就直接回车，留空。

如果问 ACME HTTP-01 监听端口：

```text
Port to use for ACME HTTP-01 listener default 80
```

直接回车，用默认 80。

如果 SSL 失败，也可以后面改成不启用 SSL，面板用 HTTP 访问。

---

## 5. 放行防火墙端口

假设：

```text
SSH 端口：22
面板端口：39127
节点端口：443
证书申请端口：80
```

执行：

```bash
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 39127/tcp
ufw enable
ufw status
```

如果提示：

```text
Command may disrupt existing ssh connections. Proceed with operation y/n?
```

输入：

```text
y
```

---

## 6. 打开 3x-ui 面板

安装完成后终端会显示：

```text
Access URL: https://你的服务器IP:面板端口/面板路径
Username: xxx
Password: xxx
```

浏览器打开：

```text
https://你的服务器IP:39127/你的面板路径
```

如果浏览器提示不安全：

```text
高级 → 继续访问
```

进去后第一件事：

```text
面板设置 → 修改用户名、密码、面板路径
```

如果你把截图或链接发给别人了，务必重新改密码。

---

## 7. 设置中文

进入面板后：

```text
右侧翻译图标 → 选择中文 / 简体中文
```

或者：

```text
Panel Settings / 面板设置 → Language → 简体中文
```

保存后刷新页面。

---

## 8. 创建 VLESS Reality 入站节点

左侧点击：

```text
入站列表 → 添加入站
```

### 8.1 基础配置

按下面填：

```text
启用：打开
备注：us-9929 或 xc机场
协议：vless
监听：留空
端口：443
总流量：0
流量重置：从不
到期时间：留空
```

---

### 8.2 客户配置

展开「客户」：

```text
启用：打开
电子邮件：pc
ID：自动生成，不用改
Subscription：不用改
评论：留空
Flow：xtls-rprx-vision
反向标签：留空
总流量：0
首次使用后开始：关闭
到期时间：留空
```

重点：

```text
Flow 必须选 xtls-rprx-vision
```

如果没有这个选项，就先保持无，但优先选它。

---

### 8.3 Authentication / Encryption

保持默认：

```text
Authentication：留空
Decryption：none
Encryption：none
```

---

### 8.4 传输配置

```text
传输：TCP (RAW)
Proxy Protocol：关闭
HTTP 伪装：关闭
Sockopt：关闭
TCP Masks：不用管
External Proxy：关闭
```

---

### 8.5 Reality 配置

安全选：

```text
Reality
```

然后按下面填：

```text
Show：关闭
Xver：0
uTLS：chrome
Target：www.microsoft.com:443
SNI：www.microsoft.com
Max Time Diff(ms)：0
Min Client Ver：留空
Max Client Ver：留空
Short IDs：23dd3d 或自己生成一个
SpiderX：/
```

建议 Short ID 简单用一个就行，例如：

```text
23dd3d
```

或者：

```text
6f3a8b9c
```

然后点：

```text
Get New Cert
```

让它自动生成：

```text
公钥 Public Key
私钥 Private Key
```

注意：

```text
公钥、私钥不能是空的
```

---

### 8.6 Sniffing 配置

展开 Sniffing：

```text
开启：打开
HTTP：勾选
TLS：勾选
QUIC：取消
FAKEDNS：取消
Metadata Only：关闭
Route Only：关闭
IPs Excluded：保持默认
Domains Excluded：保持默认
```

简单记：

```text
只开 HTTP 和 TLS
```

---

### 8.7 最终检查

创建前确认：

```text
协议：vless
端口：443
传输：TCP RAW
安全：Reality
Flow：xtls-rprx-vision
uTLS：chrome
Target：www.microsoft.com:443
SNI：www.microsoft.com
Short ID：有内容
SpiderX：/
公钥/私钥：有内容
Sniffing：只开 HTTP、TLS
```

然后点：

```text
创建
```

---

## 9. 复制分享链接

创建完成后，回到：

```text
入站列表
```

找到节点，点右侧：

```text
二维码 / 分享 / 复制链接
```

你会拿到一条类似这样的链接：

```text
vless://UUID@服务器IP:443?type=tcp&encryption=none&security=reality&pbk=公钥&fp=chrome&sni=www.microsoft.com&sid=ShortID&spx=%2F&flow=xtls-rprx-vision#节点名
```

注意：

```text
vless:// 链接就是你的节点密码，不要发给别人。
```

---

## 10. 导入 v2rayN

### 10.1 安装客户端

Windows 推荐：

```text
v2rayN
```

### 10.2 导入节点

复制 3x-ui 的 `vless://` 分享链接。

打开 v2rayN：

```text
服务器 → 从剪贴板导入分享链接
```

然后：

```text
右键节点 → 设为活动服务器
```

开启代理：

```text
系统代理 → 自动配置系统代理
```

路由模式建议先选：

```text
绕过大陆 / 绕过中国大陆
```

### 10.3 测试

浏览器打开：

```text
https://www.google.com
https://chat.openai.com
https://www.youtube.com
https://ipinfo.io
```

如果 IP 显示为你的服务器 IP，说明成功。

---

## 11. 导入 Clash Verge Rev

### 11.1 注意版本

必须用：

```text
Clash Verge Rev
Mihomo 内核
```

不要用老版 Clash，因为老版不一定支持：

```text
VLESS + Reality + xtls-rprx-vision
```

---

### 11.2 方式一：直接导入 vless 链接

复制 3x-ui 的 `vless://` 链接。

打开 Clash Verge Rev：

```text
配置 / Profiles
→ 新建 / New
→ 从剪贴板导入 / Import from Clipboard
```

如果能识别，直接启用即可。

如果导入失败，用方式二。

---

### 11.3 方式二：手写 Clash/Mihomo YAML

新建本地配置，粘贴下面模板。

把里面这些换成你自己的：

```text
你的服务器IP
你的UUID
你的PublicKey
你的ShortID
```

模板：

```yaml
mixed-port: 7890
allow-lan: false
mode: rule
log-level: info
ipv6: false

dns:
  enable: true
  listen: 127.0.0.1:1053
  enhanced-mode: fake-ip
  nameserver:
    - 223.5.5.5
    - 119.29.29.29
  fallback:
    - 8.8.8.8
    - 1.1.1.1

proxies:
  - name: "xc机场-pc"
    type: vless
    server: 你的服务器IP
    port: 443
    uuid: 你的UUID
    network: tcp
    udp: true
    tls: true
    flow: xtls-rprx-vision
    servername: www.microsoft.com
    client-fingerprint: chrome
    reality-opts:
      public-key: 你的PublicKey
      short-id: 你的ShortID
      spider-x: "/"

proxy-groups:
  - name: "节点选择"
    type: select
    proxies:
      - "xc机场-pc"
      - DIRECT

rules:
  - GEOIP,CN,DIRECT
  - MATCH,节点选择
```

保存后：

```text
配置 → 启用这个配置
代理 → 节点选择 → 选择 xc机场-pc
设置 → 系统代理 → 开启
```

模式建议：

```text
Rule / 规则
```

如果想全部走代理，可以临时改：

```text
Global / 全局
```

---

## 12. 用你自己的 vless 链接转换 Clash 配置

假设你的 vless 链接长这样：

```text
vless://UUID@服务器IP:443?type=tcp&encryption=none&security=reality&pbk=PublicKey&fp=chrome&sni=www.microsoft.com&sid=ShortID&spx=%2F&flow=xtls-rprx-vision#节点名
```

对应到 Clash YAML：

```text
UUID       → uuid
服务器IP   → server
443        → port
PublicKey  → reality-opts.public-key
ShortID    → reality-opts.short-id
sni        → servername
fp=chrome  → client-fingerprint: chrome
flow       → flow: xtls-rprx-vision
```

注意：

```text
Clash 只需要 Public Key
不要填 Private Key
Private Key 是服务器端用的
```

---

## 13. 常用排查命令

### 13.1 查看 3x-ui 状态

```bash
x-ui status
```

### 13.2 重启 3x-ui

```bash
x-ui restart
```

### 13.3 查看端口监听

```bash
ss -tulpn | grep 443
ss -tulpn | grep 39127
```

### 13.4 查看防火墙

```bash
ufw status
```

### 13.5 放行端口

```bash
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 39127/tcp
```

---

## 14. 常见问题

### 14.1 面板打不开

检查：

```bash
x-ui status
ufw status
ss -tulpn | grep 39127
```

确认浏览器访问的是：

```text
https://服务器IP:面板端口/面板路径
```

如果 SSL 有问题，可以试：

```text
http://服务器IP:面板端口/面板路径
```

---

### 14.2 v2rayN 导入了但连不上

检查这些：

```text
服务器 IP 是否正确
端口是否 443
UUID 是否正确
Public Key 是否正确
Short ID 是否正确
SNI 是否是 www.microsoft.com
Flow 是否是 xtls-rprx-vision
Reality 私钥/公钥是否生成了
服务器防火墙是否放行 443
```

服务器检查：

```bash
ufw status
ss -tulpn | grep 443
x-ui status
```

---

### 14.3 Clash Verge 导入失败

大概率是：

```text
客户端不是 Clash Verge Rev
Mihomo 内核太旧
YAML 格式缩进错了
Reality 参数填错了
```

解决：

```text
先用 v2rayN 跑通
再手写 Clash YAML
```

---

### 14.4 速度慢

先测试：

```text
晚上 8 点 ~ 11 点
YouTube 1080P / 4K
ChatGPT / Cursor / Claude / Gemini
```

速度慢通常不是配置问题，而是线路问题。

解决方向：

```text
换 VPS 地区
换 9929 / CN2 / CMI 优化线路
换服务商
不要年付，月付试
```

---

## 15. 安全注意事项

### 15.1 不要泄露这些

```text
3x-ui 面板地址
3x-ui 用户名密码
vless:// 分享链接
UUID
Reality Private Key
Reality Public Key
Short ID
```

严格来说，Public Key 和 Short ID 泄露风险没私钥大，但整条链接泄露就等于节点泄露。

### 15.2 如果泄露了怎么办

进 3x-ui：

```text
入站列表 → 编辑节点
```

重新生成：

```text
UUID
Reality 公钥/私钥
Short ID
```

然后重新复制分享链接，重新导入客户端。

### 15.3 面板安全

建议：

```text
不要用 admin 用户名
密码要复杂
面板路径要随机
面板端口不要用默认
防火墙只开放必要端口
不要把节点给别人用
```

---

## 16. 最短操作版

买好服务器后，最短流程：

```bash
ssh root@你的服务器IP
sudo -i
apt update && apt upgrade -y
apt install -y curl wget ufw ca-certificates
bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 面板端口/tcp
ufw enable
ufw status
```

浏览器打开：

```text
https://你的服务器IP:面板端口/面板路径
```

3x-ui 添加入站：

```text
VLESS
443
TCP RAW
Reality
Flow: xtls-rprx-vision
uTLS: chrome
Target: www.microsoft.com:443
SNI: www.microsoft.com
Sniffing: HTTP + TLS
```

复制 `vless://` 链接。

v2rayN：

```text
服务器 → 从剪贴板导入分享链接 → 设为活动服务器 → 开启系统代理
```

Clash Verge Rev：

```text
配置 → 新建本地 YAML → 填入 VLESS Reality 配置 → 启用 → 开启系统代理
```

---

## 17. 我的建议

第一次部署：

```text
先用 v2rayN 导入 vless:// 链接跑通
再折腾 Clash Verge Rev
```

原因：

```text
v2rayN 更省事
Clash Verge 对 YAML 和 Mihomo 内核版本要求更严格
```

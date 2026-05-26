# Ubuntu 云服务器使用 3x-ui 节点科学上网

## 目标

已有一台国外服务器，已经搭建好 **3x-ui**。

现在要让另一台 **Ubuntu 云服务器** 使用这个 3x-ui 节点，实现类似 Windows 系统代理的效果：

```text
Ubuntu 云服务器
↓
v2rayA 客户端
↓
国外 3x-ui 节点
↓
外网
```

最终效果：

```text
curl / git / apt / docker / 程序访问外网
尽量不用每个软件单独配置代理
```

---

## 一、Ubuntu 安装 v2rayA + Xray

登录 Ubuntu 云服务器后执行：

```bash
sudo apt update
sudo apt install -y wget curl iptables iproute2 nftables ipset

sudo sh -c "$(wget -qO- https://github.com/v2rayA/v2rayA-installer/raw/main/installer.sh)" @ --with-xray

sudo systemctl enable --now v2raya
sudo systemctl status v2raya --no-pager
```

看到：

```text
active (running)
```

说明 v2rayA 启动成功。

---

## 二、Windows 访问 Ubuntu 的 v2rayA 面板

不要直接开放 2017 端口，使用 SSH 隧道访问。

Windows PowerShell 执行：

```bash
ssh -F NUL -L 2017:127.0.0.1:2017 root@你的Ubuntu服务器IP
```

例如：

```bash
ssh -F NUL -L 2017:127.0.0.1:2017 root@124.220.6.109
```

然后浏览器打开：

```text
http://127.0.0.1:2017
```

第一次进入会让你创建 v2rayA 账号。

---

## 三、导入 3x-ui 节点

去国外 3x-ui 面板复制节点链接，例如：

```text
vless://xxxx
vmess://xxxx
trojan://xxxx
```

然后在 v2rayA 页面：

```text
导入
↓
粘贴节点链接
↓
确定
```

导入后：

```text
选中节点
↓
启动
```

---

## 四、先测试代理端口是否正常

Ubuntu 执行：

```bash
sudo ss -lntp | grep -E '2017|20170|20171|20172'
```

正常应该能看到类似：

```text
127.0.0.1:2017
127.0.0.1:20170
127.0.0.1:20171
127.0.0.1:20172
```

测试 HTTP 代理：

```bash
curl -m 10 -x http://127.0.0.1:20171 https://ipinfo.io
```

如果返回的是国外节点 IP，说明节点可用。

例如：

```text
70.39.179.224
Los Angeles
US
```

---

## 五、开启系统级透明代理

进入 v2rayA 设置页面，按下面设置。

### 推荐配置

| 设置项 | 选择 |
|---|---|
| 透明代理 / 系统代理 | 启用：大陆白名单模式 |
| 开启 IP 转发 | 不开 |
| 开启端口分享 | 不开 |
| 透明代理 / 系统代理实现方式 | redirect |
| 规则端口的分流模式 | 大陆白名单模式 |
| 防止 DNS 污染 | 仅防止 DNS 劫持（快速） |
| 特殊模式 | 关闭 |
| TCPFastOpen | 保持系统默认 |
| 嗅探 | Http + TLS + Quic |
| 多路复用 | 关闭 |
| 自动更新订阅 | 关闭 |
| 解析订阅链接 / 更新时优先使用 | 跟随透明代理 / 系统代理 |

设置完成后点击：

```text
保存并应用
```

然后执行：

```bash
sudo systemctl restart v2raya
```

---

## 六、测试系统代理是否生效

这次不要加 `-x`。

```bash
curl -m 10 https://ipinfo.io
```

如果显示国外节点 IP，说明透明代理成功。

再测试：

```bash
curl -m 10 -I https://www.google.com
```

能返回类似：

```text
HTTP/2 200
```

或者：

```text
HTTP/1.1 200
```

就说明成功。

---

## 七、测试常用工具

### 测试 GitHub

```bash
git ls-remote https://github.com/v2rayA/v2rayA.git
```

### 测试 apt

```bash
sudo apt update
```

### 测试 Docker

```bash
docker pull hello-world
```

如果这些都能正常访问，说明 Ubuntu 云服务器已经基本实现系统级科学上网。

---

## 八、关键注意事项

### 1. 3x-ui 服务端 IP 要直连

你的国外 3x-ui 服务器 IP 要加到 v2rayA 的直连规则里。

例如节点 IP 是：

```text
70.39.179.224
```

就加入直连：

```text
70.39.179.224
```

原因：

```text
防止 Ubuntu 访问 3x-ui 节点时，又被代理回自己，导致代理套娃。
```

---

### 2. 不要开放这些端口到公网

这些端口只给本机用，不要开放公网：

```text
2017   v2rayA 面板
20170  SOCKS5 代理
20171  HTTP 代理
20172  分流代理
```

访问面板继续用 SSH 隧道：

```bash
ssh -F NUL -L 2017:127.0.0.1:2017 root@你的Ubuntu服务器IP
```

---

## 九、常见问题

### 问题 1：SSH 报错 Bad owner or permissions

报错类似：

```text
Bad owner or permissions on C:\Users\xuchao\.ssh\config
```

临时绕过方式：

```bash
ssh -F NUL -L 2017:127.0.0.1:2017 root@你的Ubuntu服务器IP
```

`-F NUL` 的意思是这次不读取 Windows 的 SSH config 文件。

---

### 问题 2：20171 连接被拒绝

报错：

```text
curl: (7) Failed to connect to 127.0.0.1 port 20171
```

说明 HTTP 代理端口没起来。

处理：

```bash
sudo systemctl restart v2raya
```

然后在 v2rayA 页面：

```text
选中节点
↓
启动
```

再测：

```bash
curl -m 10 -x http://127.0.0.1:20171 https://ipinfo.io
```

---

### 问题 3：加 -x 能访问，不加 -x 不能访问

例如：

```bash
curl -m 10 -x http://127.0.0.1:20171 https://ipinfo.io
```

能访问。

但是：

```bash
curl -m 10 https://ipinfo.io
```

不能访问。

说明：

```text
节点没问题
代理端口没问题
透明代理没生效
```

处理：

```text
透明代理实现方式改成 redirect
不要用 tproxy
```

保存后：

```bash
sudo systemctl restart v2raya
```

---

### 问题 4：curl 提示 Resolving timed out

报错：

```text
curl: (28) Resolving timed out
```

说明 DNS 卡住了。

处理：

```text
防止 DNS 污染 改成：
仅防止 DNS 劫持（快速）
```

不要优先选：

```text
转发 DNS 请求
```

保存后：

```bash
sudo systemctl restart v2raya
```

---

### 问题 5：tproxy 不好用

云服务器自己用代理，不当网关，一般不用 tproxy。

推荐：

```text
透明代理实现方式：redirect
```

更简单，更稳。

---

## 十、最终推荐配置

最终配置就用这一套：

```text
透明代理 / 系统代理：启用：大陆白名单模式
实现方式：redirect
规则端口分流模式：大陆白名单模式
防止 DNS 污染：仅防止 DNS 劫持（快速）
特殊模式：关闭
TCPFastOpen：保持系统默认
嗅探：Http + TLS + Quic
多路复用：关闭
开启 IP 转发：不开
开启端口分享：不开
```

---

## 十一、最终验证命令

```bash
curl -m 10 https://ipinfo.io
curl -m 10 -I https://www.google.com
git ls-remote https://github.com/v2rayA/v2rayA.git
sudo apt update
docker pull hello-world
```

这些都正常，就算完成。

---

## 十二、重启后验证

建议最后重启一次服务器：

```bash
sudo reboot
```

重新 SSH 登录后执行：

```bash
systemctl status v2raya --no-pager
curl -m 10 https://ipinfo.io
curl -m 10 -I https://www.google.com
```

如果重启后也正常，说明彻底配置完成。
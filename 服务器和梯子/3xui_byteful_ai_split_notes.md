# 3x-ui + Byteful 静态住宅 IP 分流配置日记

## 目标

只使用一个 Clash Verge 节点、一个 VLESS Reality 入站：

- ChatGPT / Claude → Byteful 静态住宅 IP
- YouTube / Google / 普通网站 → VPS 原 IP 直出

最终链路：

```text
Clash Verge
   ↓
VLESS + Reality + Vision
   ↓
3x-ui / Xray
   ├─ ChatGPT / Claude → Byteful SOCKS5 → 175.29.113.102
   └─ 其他网站 → direct → VPS 原 IP
```

## 1. Byteful 购买

产品：

```text
Static Dedicated Residential Proxy
```

配置：

```text
地区：United States
数量：1 IP
周期：Monthly
```

本次 IP：

```text
175.29.113.102
```

代理端口：

```text
61234
```

认证用户名、密码：保存在 Byteful 后台，不写入日记。

## 2. 3x-ui 新增 Byteful 出站

进入：

```text
Xray 配置 → 出站 → 新建
```

填写：

```text
协议：socks
标签：byteful
地址：175.29.113.102
端口：61234
用户名：Byteful 用户名
密码：Byteful 密码

发送通过：留空
目标解析策略：默认
Sockopts：关闭
TCP Masks：不配置
Mux：关闭
```

说明：这里的 `socks` 即 SOCKS5 出站。

## 3. 新建 AI 分流规则

进入：

```text
Xray 配置 → 路由规则 → 新建
```

填写：

```text
评论：AI -> Byteful
启用：开启
网络：(any)

源 IP：留空
源端口：留空
VLESS 路由：留空
协议：留空
属性：不配置
IP：留空
用户：留空
端口：留空

入站标签：in-443-tcp (xc科学上网)
出站标签：byteful
均衡器标签：(none)
```

域名：

```text
domain:chatgpt.com,
domain:openai.com,
domain:oaistatic.com,
domain:oaiusercontent.com,
domain:oaistatsig.com,
domain:openaimerge.com,
domain:claude.ai,
domain:claude.com,
domain:anthropic.com
```

这样电脑端、手机端的 ChatGPT / Claude 都走 Byteful。

## 4. 开启入站嗅探

编辑：

```text
in-443-tcp (xc科学上网)
```

进入「嗅探」：

```text
启用：开启

HTTP：开启
TLS：开启
QUIC：开启
FAKEDNS：可关

仅元数据：关闭
仅路由：开启

排除 IP：留空
排除域名：留空
```

`仅路由` 开启后，嗅探到的域名只用于判断路由，不改写原始目标。

## 5. 保存并重启

完成修改后：

```text
保存 Xray 配置
重启 Xray / 面板
```

Clash Verge 配置、VLESS Reality 节点、UUID、flow 都不需要修改。

## 6. 路由测试

应该得到：

```text
chatgpt.com          → byteful
api.openai.com       → byteful
ios.chat.openai.com  → byteful
claude.ai            → byteful
api.anthropic.com    → byteful

youtube.com          → 默认 direct
google.com           → 默认 direct
```

`google.com` 显示“无路由规则匹配，走默认第一个出站”属于正常情况，只要第一个出站是 `direct`。

## 7. 最终效果

```text
ChatGPT / Claude
    ↓
Byteful SOCKS5
    ↓
175.29.113.102

YouTube / Google / 普通网站
    ↓
direct
    ↓
VPS 原 IP
```

优点：

- 只有一个客户端节点
- 不需要手动切换代理
- AI 服务固定使用住宅/ISP IP
- 视频、下载继续走 VPS，速度更好
- Byteful 流量不会浪费在视频等大流量业务上

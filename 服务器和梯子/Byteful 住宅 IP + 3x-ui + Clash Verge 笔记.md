# Byteful 住宅 IP + 3x-ui + Clash Verge 笔记

## 1. 整体链路

```
Clash Verge
→ VLESS + Reality
→ 海外 VPS / 3x-ui
→ Byteful SOCKS5
→ 住宅 IP
→ Internet
```

## 2. 3x-ui 入站

- 协议：VLESS
    
- 端口：33445
    
- 传输：RAW / TCP
    
- 安全：Reality
    
- SNI：`www.apple.com`
    
- 入站标签：`in-33445-tcp`
    
- Sniffing：开启
    
- HTTP / TLS / QUIC / FAKEDNS：开启
    

入站本身不用再改。

## 3. Byteful 出站

3x-ui → Xray 设置 → 出站：

```
协议：socks
标签：byteFul
地址：Byteful 提供的代理地址/IP
端口：Byteful 提供的端口
用户名：Byteful 用户名
密码：Byteful 密码
Mux：关闭
Sockopts：关闭
```

## 4. 路由

Byteful 专用节点直接按入站标签路由，不需要再写 OpenAI 域名。

```
入站标签：in-33445-tcp
出站标签：byteFul
```

建议：

```
TCP → byteFul
UDP → blocked
```

## 5. Clash Verge 节点

```
proxies:
  - name: "Byteful-Node"
    type: vless
    server: 70.39.179.44
    port: 33445
    uuid: 610523ca-6a84-4613-a789-aef06f466a31
    network: tcp
    tls: true
    udp: false
    servername: www.apple.com
    client-fingerprint: chrome
    reality-opts:
      public-key: waMx0MJXEo32sC3HHeHIXCV-r-BItgBwxAu2Xx0Rr0A
      short-id: "253e"
```

完整简单配置：

```
mixed-port: 7890
allow-lan: false
mode: rule
log-level: info
ipv6: false

proxies:
  - name: "Byteful-Node"
    type: vless
    server: 70.39.179.44
    port: 33445
    uuid: 610523ca-6a84-4613-a789-aef06f466a31
    network: tcp
    tls: true
    udp: false
    servername: www.apple.com
    client-fingerprint: chrome
    reality-opts:
      public-key: waMx0MJXEo32sC3HHeHIXCV-r-BItgBwxAu2Xx0Rr0A
      short-id: "253e"

proxy-groups:
  - name: "PROXY"
    type: select
    proxies:
      - "Byteful-Node"
      - DIRECT

rules:
  - MATCH,PROXY
```

## 6. 验证

连接 `Byteful-Node` 后访问：

```
ipinfo.io
```

结果应该显示 Byteful 住宅 IP。

如果显示 `70.39.179.44`，说明 3x-ui 的：

```
in-33445-tcp → byteFul
```

路由没生效。

## 7. 注意

之前截图暴露过 Byteful 密码和 Reality 私钥，测试完成后建议重新生成凭证/Reality 密钥。
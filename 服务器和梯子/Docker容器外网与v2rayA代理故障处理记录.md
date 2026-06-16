# Docker 容器外网与 v2rayA 代理故障处理记录

## 1. 基本信息

- 处理日期：2026-06-15
- 服务器：`124.220.6.109`
- 系统：Ubuntu 22.04 LTS
- 涉及服务：Docker、v2rayA、New API、Sub2API、PostgreSQL、Redis

本文不记录 SSH 密码、API Key、代理订阅等敏感信息。

## 2. 最终结论

服务器上的 v2rayA 确实是类似 Clash Verge 的“规则模式”，不是所有流量都无条件经过境外代理。

当前规则的大意是：

- `geosite:geolocation-!cn`、`geosite:google`：代理。
- `geosite:cn`、`geoip:cn`、`geoip:private`：直连。
- `geoip:hk`、`geoip:mo`：代理。
- 未命中前面规则的流量：最终兜底为代理。

这些规则同时应用于 v2rayA 的 HTTP、SOCKS 和透明代理入口。

因此必须区分下面两个概念：

1. **请求进入 v2rayA 代理入口**：应用把请求交给 v2rayA。
2. **请求最终经过远程代理节点**：v2rayA 再根据域名、IP 和路由规则决定直连还是代理。

“配置了 v2rayA 地址”不等于“所有目标最终都走境外节点”。

## 3. 原故障是否真实存在

故障真实存在，但不是 Docker 天生不能访问外网，也不是必须让所有容器使用全局代理。

当时的主要现象是：

- 宿主机可以访问外网。
- Docker bridge 容器解析域名正常，但连接公网 HTTP/HTTPS 经常超时。
- New API 添加渠道后无法调用上游 API。
- 宿主机访问 OpenAI 正常，只能证明宿主机的 v2rayA 路径正常，不能证明 Docker NAT 正常。

故障由两个问题叠加造成。

### 3.1 Docker 流量被透明代理规则接管

v2rayA 创建了 `inet v2raya` nftables 表，并在 `tp_pre` 链处理进入宿主机的 TCP 流量。

普通 Docker Compose 网络使用 `br-*` 网桥，容器流量也会进入该链。当 Docker 流量被透明代理接管后，它没有继续按照预期的 Docker FORWARD、MASQUERADE 和 NAT 路径访问公网。

### 3.2 IPv4 转发被关闭

排查时确认出现过：

```text
net.ipv4.ip_forward = 0
```

该值为 `0` 时，Docker bridge 数据包无法由宿主机转发到公网。抓包表现为：

- Docker 网桥可以看到容器发出的 TCP SYN。
- 宿主机公网网卡看不到对应数据包。
- Docker MASQUERADE 计数不增长。
- 恢复 `net.ipv4.ip_forward=1` 后，容器直连立即恢复。

## 4. 当前采用的网络设计

现在的设计是：

1. 普通 Docker bridge 容器默认使用 Docker NAT 直连。
2. 宿主机继续使用 v2rayA 规则模式，不删除代理。
3. 只有确实需要代理的渠道、账号或后台任务，才显式连接 v2rayA。
4. Docker 容器统一使用 `http://host.docker.internal:20173` 访问 v2rayA。
5. `20173` 只允许 Docker 网桥访问，不对公网开放。

流量路径如下：

```text
普通容器直连：
容器 -> Docker bridge -> Docker NAT/MASQUERADE -> eth0 -> 公网

应用显式使用代理：
容器 -> host.docker.internal:20173
     -> socat -> 127.0.0.1:20171
     -> v2rayA 规则判断
        -> 国内/私有目标直连
        -> OpenAI 等目标经过代理节点
```

## 5. 已实施的系统修改

### 5.1 Docker 直连守护服务

脚本：

```text
/usr/local/sbin/docker-direct-bypass
```

systemd 服务：

```text
/etc/systemd/system/docker-direct-bypass.service
```

服务每两秒检查：

- `net.ipv4.ip_forward` 是否为 `1`。
- v2rayA 的 `inet v2raya tp_pre` 链是否存在。
- Docker 网桥绕过规则是否存在。

写入的核心规则是：

```nft
iifname "br-*" counter return comment "Docker direct bypass: user bridges"
iifname "docker0" counter return comment "Docker direct bypass: default bridge"
```

它们让标准 Docker bridge 流量跳过 v2rayA 的透明代理接管，继续走 Docker NAT。

即使 v2rayA 重启并重建 nftables 表，守护服务也会自动补回规则。

### 5.2 持久化 IPv4 转发

文件：

```text
/etc/sysctl.d/99-docker-ip-forward.conf
```

内容：

```conf
net.ipv4.ip_forward = 1
```

sysctl 文件负责开机初始化，守护服务负责运行期间持续检查。

### 5.3 Docker 共用代理入口

systemd 服务：

```text
/etc/systemd/system/v2raya-docker-proxy.service
```

转发关系：

```text
0.0.0.0:20173 -> 127.0.0.1:20171
```

- `127.0.0.1:20171`：v2rayA/Xray 的本机 HTTP 代理入口。
- `20173`：提供给 Docker bridge 容器的入口。
- 容器通过 `host.docker.internal:20173` 访问。

### 5.4 防火墙限制

UFW 只允许 Docker 网桥访问 `20173/tcp`：

```text
20173/tcp on docker0
20173/tcp on br+
```

公网访问 `124.220.6.109:20173` 已验证失败，符合安全预期。腾讯云安全组不需要开放该端口。

## 6. 三种代理配置不要混淆

### 6.1 宿主机透明代理

宿主机流量由 v2rayA 透明代理和路由规则处理，效果类似 Clash Verge 规则模式。

这部分仍然保留。

### 6.2 容器级全局代理变量

例如：

```yaml
environment:
  HTTP_PROXY: http://host.docker.internal:20173
  HTTPS_PROXY: http://host.docker.internal:20173
  ALL_PROXY: http://host.docker.internal:20173
```

这会让该容器内支持这些变量的程序，把大部分 HTTP/HTTPS 请求先交给 v2rayA。最终是否经过远程节点，仍由 v2rayA 规则决定。

它的影响范围是整个容器，容易同时影响健康检查、Webhook、GitHub 更新和其他请求。因此 New API 和 Sub2API 当前都没有配置这组全局变量。

### 6.3 应用内部的渠道或账号级代理

这是当前优先使用的方式：

- New API：按渠道配置代理。
- Sub2API：按账号绑定代理。
- 未配置代理的渠道或账号：直接使用 Docker NAT。
- 已配置代理的渠道或账号：连接 `host.docker.internal:20173`，再由 v2rayA 规则分流。

## 7. New API 当前配置

New API 已移除容器级 `HTTP_PROXY`、`HTTPS_PROXY` 和 `ALL_PROXY`。

Compose 保留：

```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```

需要代理的渠道，在 New API 渠道设置中填写：

```text
http://host.docker.internal:20173
```

例如：

- OpenAI 渠道：配置上述代理地址。
- DeepSeek 等可以直连的渠道：代理字段留空。

这样不会强迫 New API 的所有渠道共用代理。

## 8. Sub2API 当前配置

此前笔记中“Sub2API 整个容器都需要全局代理”的说法不正确，现已修正。

### 8.1 上游请求按账号决定

Sub2API 数据库中存在：

- `proxies`：保存代理地址。
- `accounts.proxy_id`：决定账号是否绑定某个代理。

2026-06-15 复核结果：

```text
账号 1 | openai | DIRECT
账号 2 | openai | proxy_id=1

代理 1 | xray-local | http://host.docker.internal:20173 | active
```

因此：

- 账号 1 没有绑定代理，Sub2API 为它创建直连 Transport。
- 账号 2 绑定 `xray-local`，其上游请求使用 Docker 共用代理入口。

运行镜像对应的 Sub2API `0.1.133` 源码也确认：

- 只有 `account.ProxyID` 和 `account.Proxy` 都存在时，才生成账号代理 URL。
- 空代理 URL 会被解析为 `nil`。
- `ConfigureTransportProxy(..., nil)` 直接返回，表示直连。
- 上游 Transport 没有使用 `http.ProxyFromEnvironment`。

所以未绑定代理的账号不会因为其他账号配置了代理而被连带代理。

### 8.2 容器没有全局代理

Sub2API 容器当前只有：

```text
UPDATE_PROXY_URL=http://host.docker.internal:20173
```

没有：

```text
HTTP_PROXY
HTTPS_PROXY
ALL_PROXY
```

### 8.3 GitHub 更新使用独立代理

Sub2API 官方提供了专用变量：

```env
UPDATE_PROXY_URL=http://host.docker.internal:20173
```

它只用于 GitHub 在线更新和定价数据，不负责账号上游请求。

这解决了移除全局代理后访问 `raw.githubusercontent.com` 可能超时的问题，同时不改变账号级代理关系。

相关官方源码：

- [账号代理判断](https://github.com/Wei-Shaw/sub2api/blob/68901cbfff783af794d96028be8dad3e532c0fe7/backend/internal/service/account_test_service.go)
- [上游 Transport 构建](https://github.com/Wei-Shaw/sub2api/blob/68901cbfff783af794d96028be8dad3e532c0fe7/backend/internal/repository/http_upstream.go)
- [代理配置函数](https://github.com/Wei-Shaw/sub2api/blob/68901cbfff783af794d96028be8dad3e532c0fe7/backend/internal/pkg/proxyutil/dialer.go)
- [官方 Compose 的 `UPDATE_PROXY_URL`](https://github.com/Wei-Shaw/sub2api/blob/68901cbfff783af794d96028be8dad3e532c0fe7/deploy/docker-compose.yml)

## 9. 新 Docker 项目如何配置

### 9.1 默认直连项目

普通项目不需要增加任何代理变量：

```yaml
services:
  app:
    image: your-image
    restart: unless-stopped
```

标准 Docker Compose 创建的 `br-*` 网络会自动被绕过规则覆盖，通过 Docker NAT 正常访问公网。

### 9.2 整个容器都需要 v2rayA 规则分流

只有应用没有渠道级配置，并且确实希望整个容器的兼容请求都交给 v2rayA 时，才使用：

```yaml
services:
  app:
    image: your-image
    extra_hosts:
      - "host.docker.internal:host-gateway"
    environment:
      HTTP_PROXY: http://host.docker.internal:20173
      HTTPS_PROXY: http://host.docker.internal:20173
      ALL_PROXY: http://host.docker.internal:20173
      NO_PROXY: localhost,127.0.0.1,redis,postgres
```

注意：应用是否读取这些变量取决于它使用的语言和 HTTP 客户端。

### 9.3 应用支持按渠道、账号或任务配置

优先在应用内部填写：

```text
http://host.docker.internal:20173
```

这样控制范围最小，也最容易判断哪类请求使用代理。

## 10. 复核结果

2026-06-15 最终检查：

- `docker-direct-bypass`：`active`、`enabled`
- `v2raya-docker-proxy`：`active`、`enabled`
- `v2raya`：`active`、`enabled`
- `net.ipv4.ip_forward = 1`
- `br-*` 和 `docker0` 绕过规则存在
- New API 无容器级全局代理
- New API DeepSeek 直连测试：HTTP `200`
- OpenAI 经过显式代理测试：HTTP `401`
  - 未携带有效 OpenAI Key 时，`401` 表示 DNS、TCP、TLS 和代理链路已经到达 OpenAI。
- Sub2API：`running healthy`
- Sub2API `/health`：HTTP `200`
- Sub2API 无全局 `HTTP_PROXY/HTTPS_PROXY/ALL_PROXY`
- Sub2API 账号 1：直连
- Sub2API 账号 2：绑定 `xray-local`
- Sub2API GitHub 更新：使用独立 `UPDATE_PROXY_URL`
- 公网访问 `20173`：失败，符合安全预期

## 11. 日常检查命令

```bash
# IPv4 转发
sudo sysctl net.ipv4.ip_forward

# Docker 绕过规则
sudo nft list chain inet v2raya tp_pre

# 三个关键服务
sudo systemctl status docker-direct-bypass
sudo systemctl status v2raya-docker-proxy
sudo systemctl status v2raya

# Docker 代理入口
sudo ss -lntp | grep 20173

# 应用状态
sudo docker ps
curl -I http://127.0.0.1:3000/api/status
curl -I http://127.0.0.1:7788/health

# Sub2API 是否意外出现全局代理变量
sudo docker inspect sub2api \
  --format '{{range .Config.Env}}{{println .}}{{end}}' |
  grep -i proxy
```

容器直连测试：

```bash
sudo docker exec new-api sh -lc \
  'wget -Y off -S --spider -T 15 https://api.deepseek.com/models'
```

容器显式代理测试：

```bash
sudo docker exec new-api sh -lc \
  'https_proxy=http://host.docker.internal:20173 \
   wget -Y on -S --spider -T 15 https://api.openai.com/v1/models'
```

## 12. 备份与回退

本次相关备份包括：

```text
/opt/new-api/docker-compose.yml.bak-20260615-112048
/opt/new-api/docker-compose.yml.bak-direct-20260615-115308
/opt/new-api/docker-compose.yml.bak-review-20260615-121548
/opt/sub2api/docker-compose.yml.bak-20260615-112423
/opt/sub2api/docker-compose.yml.bak-review-20260615-121548
/opt/sub2api/docker-compose.yml.bak-account-proxy-20260615-163443
/opt/sub2api/proxies.bak-20260615-163443.sql
/opt/sub2api/.env.bak-update-proxy-20260615-164007
```

不要随意关闭 `docker-direct-bypass`。否则在 v2rayA 重建规则或再次关闭 `ip_forward` 后，Docker bridge 容器可能重新出现外网超时。

## 13. 适用范围

当前自动规则覆盖：

- Docker 默认 `bridge` 网络，即 `docker0`
- Docker Compose 自动创建的 `br-*` 网络
- 后续新建的标准 Compose bridge 网络

以下网络模式需要单独评估：

- `network_mode: host`
- macvlan/ipvlan
- Docker Swarm overlay
- 手动指定了非 `br-*` Linux 网桥名称的网络

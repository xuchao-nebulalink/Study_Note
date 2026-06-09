# Docker 容器走宿主机代理笔记

## 适用场景

宿主机已经有科学上网，比如：

```text
xray / v2rayA / Clash / sing-box
```

宿主机自己访问 OpenAI 正常，但 Docker 容器里访问不通、超时、卡住。

典型现象：

```bash
# 宿主机正常
curl -x http://127.0.0.1:20171 -I https://api.openai.com/v1/models

# 容器里卡住或超时
docker exec -it xxx sh
curl -I https://api.openai.com/v1/models
```

---

## 核心概念

### 1. 容器里的 127.0.0.1 不是宿主机

容器里：

```text
127.0.0.1
```

指的是容器自己，不是宿主机。

所以容器里不能直接用：

```text
http://127.0.0.1:20171
```

访问宿主机的代理。

---

### 2. 宿主机代理只监听 127.0.0.1，容器访问不到

检查宿主机代理监听：

```bash
sudo ss -lntp | grep -E '20170|20171|7890|7891'
```

如果看到：

```text
127.0.0.1:20171
```

说明代理只给宿主机本机用，Docker 容器访问不到。

如果看到：

```text
0.0.0.0:20171
```

说明 Docker 容器可以通过宿主机网关 IP 访问。

---

## 推荐方案

有两种方案。

### 方案 A：把代理监听改成 0.0.0.0

如果你的代理工具支持，直接把 HTTP 代理监听地址从：

```text
127.0.0.1:20171
```

改成：

```text
0.0.0.0:20171
```

然后容器里用宿主机网关访问：

```text
http://容器网关IP:20171
```

注意：不要把代理端口暴露给公网。防火墙只允许 Docker 网段访问。

---

### 方案 B：用 socat 转发，推荐稳妥

如果代理只能监听 `127.0.0.1`，就用 `socat` 转发一个 Docker 容器能访问的端口。

链路：

```text
Docker 容器
→ 172.18.0.1:20172
→ socat 转发
→ 127.0.0.1:20171
→ xray / v2rayA / Clash
→ 外网
```

---

## 完整操作流程

### 1. 确认宿主机代理可用

宿主机执行：

```bash
curl -x http://127.0.0.1:20171 -I https://api.openai.com/v1/models --connect-timeout 8 --max-time 15
```

正常结果：

```text
HTTP/2 401
```

`401` 是正常的，说明已经访问到 OpenAI，只是没带 OpenAI API Key。

---

### 2. 查看容器网关 IP

比如容器名是 `sub2api`：

```bash
sudo docker inspect sub2api --format '{{range .NetworkSettings.Networks}}IP={{.IPAddress}} 网关={{.Gateway}}{{println}}{{end}}'
```

示例输出：

```text
IP=172.18.0.4 网关=172.18.0.1
```

这里的网关就是：

```text
172.18.0.1
```

后面转发和代理都用这个 IP。

---

### 3. 安装 socat

```bash
sudo apt update
sudo apt install -y socat
```

---

### 4. 启动 socat 转发

假设：

```text
容器网关：172.18.0.1
宿主机代理：127.0.0.1:20171
转发端口：20172
```

执行：

```bash
sudo nohup socat TCP-LISTEN:20172,fork,reuseaddr,bind=172.18.0.1 TCP:127.0.0.1:20171 > /tmp/socat-20172.log 2>&1 &
```

检查：

```bash
sudo ss -lntp | grep 20172
```

应该看到：

```text
172.18.0.1:20172
```

---

### 5. 如果 UFW 防火墙开着，放行 Docker 网段

查看防火墙：

```bash
sudo ufw status
```

如果是 active，推荐只允许 Docker 网段访问：

```bash
sudo ufw allow from 172.18.0.0/16 to any port 20172 proto tcp
sudo ufw reload
```

临时粗暴测试可以用：

```bash
sudo ufw allow 20172/tcp
sudo ufw reload
```

但长期不建议直接对公网放开代理端口。

---

### 6. 容器内测试代理

进入容器：

```bash
sudo docker exec -it sub2api sh
```

测试：

```bash
curl -x http://172.18.0.1:20172 -I https://api.openai.com/v1/models --connect-timeout 8 --max-time 15
```

正常结果：

```text
HTTP/1.1 200 Connection established
HTTP/2 401
```

这说明容器已经可以通过代理访问 OpenAI。

---

## 让整个容器默认走代理

如果项目本身没有代理配置，只能通过环境变量走代理，就在 `docker-compose.yml` 里加。

示例：

```yaml
services:
  your-service:
    image: your-image
    container_name: your-service
    environment:
      - HTTP_PROXY=http://172.18.0.1:20172
      - HTTPS_PROXY=http://172.18.0.1:20172
      - ALL_PROXY=http://172.18.0.1:20172
      - http_proxy=http://172.18.0.1:20172
      - https_proxy=http://172.18.0.1:20172
      - all_proxy=http://172.18.0.1:20172
      - NO_PROXY=localhost,127.0.0.1,redis,postgres
      - no_proxy=localhost,127.0.0.1,redis,postgres
```

重启：

```bash
sudo docker compose down
sudo docker compose up -d --force-recreate
```

验证：

```bash
sudo docker exec -it your-service sh
env | grep -i proxy
curl -v -I https://api.openai.com/v1/models --connect-timeout 8 --max-time 15
```

正常应该看到：

```text
Uses proxy env variable HTTPS_PROXY
Trying 172.18.0.1:20172
HTTP/2 401
```

---

## socat 开机自启

`nohup socat ... &` 是临时的，服务器重启后会失效。

创建 systemd 服务：

```bash
sudo nano /etc/systemd/system/socat-docker-proxy.service
```

填入：

```ini
[Unit]
Description=Socat proxy forward for Docker containers
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/socat TCP-LISTEN:20172,fork,reuseaddr,bind=172.18.0.1 TCP:127.0.0.1:20171
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

启用：

```bash
sudo systemctl daemon-reload
sudo systemctl enable socat-docker-proxy
sudo systemctl restart socat-docker-proxy
sudo systemctl status socat-docker-proxy
```

---

## 常见问题

### 1. 容器里提示 host.docker.internal 解析失败

Linux Docker 默认不一定有 `host.docker.internal`。

可以在 `docker-compose.yml` 里加：

```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```

但更直接的方式是用容器网关 IP，比如：

```text
172.18.0.1
```

---

### 2. 容器访问代理超时

检查三件事：

```bash
# 1. 代理是否只监听 127.0.0.1
sudo ss -lntp | grep 20171

# 2. socat 是否监听到容器网关 IP
sudo ss -lntp | grep 20172

# 3. UFW 是否拦截
sudo ufw status
```

---

### 3. HTTP/2 401 是不是失败？

不是。

访问：

```bash
curl -I https://api.openai.com/v1/models
```

不带 API Key 返回：

```text
HTTP/2 401
```

这是正常的，说明网络已经通了。

---

### 4. chatgpt.com/backend-api/codex/responses 返回 405 是不是失败？

不一定。

这个接口只允许 POST，请求 HEAD/GET 返回：

```text
HTTP/2 405
allow: POST
```

说明网络通了。

---

## 最佳实践

长期建议：

```text
项目自己支持代理配置 → 用项目内代理配置
项目不支持代理配置 → 用 Docker 环境变量代理
宿主机代理只监听 127.0.0.1 → 用 socat 转发
不要把代理端口暴露到公网
NO_PROXY 里加 redis、postgres、mysql 等内部服务名
```

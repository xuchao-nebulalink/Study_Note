# Sub2API 走代理笔记

## 适用场景

Sub2API 部署在 Docker 里，OpenAI OAuth / ChatGPT 账号测试失败，例如：

```text
Request failed:
Post "https://chatgpt.com/backend-api/codex/responses":
dial tcp xxx.xxx.xxx.xxx:443: connect: connection timed out
```

这种一般是 Sub2API 访问 ChatGPT / OpenAI 不通，或者账号测试没有走代理。

---

## 推荐做法

Sub2API 自带：

```text
IP 管理 / 代理管理
```

所以最推荐：

```text
不要给整个容器配置全局代理
直接在 Sub2API 后台添加代理
哪个账号需要代理，就给哪个账号绑定代理
```

这样最干净，不容易影响 Redis、Postgres、内部服务通信。

---

## 核心链路

如果宿主机代理是：

```text
127.0.0.1:20171
```

Docker 容器不能直接访问这个地址。

推荐用 socat 转发成容器能访问的地址：

```text
Sub2API 容器
→ 172.18.0.1:20172
→ socat
→ 127.0.0.1:20171
→ xray / v2rayA / Clash
→ OpenAI / ChatGPT
```

最终 Sub2API 后台代理填写：

```text
协议：HTTP
主机：172.18.0.1
端口：20172
```

---

## 第一步：确认容器能访问代理

### 1. 查看 Sub2API 容器网关

宿主机执行：

```bash
sudo docker inspect sub2api --format '{{range .NetworkSettings.Networks}}IP={{.IPAddress}} 网关={{.Gateway}}{{println}}{{end}}'
```

示例：

```text
IP=172.18.0.4 网关=172.18.0.1
```

记住这个网关：

```text
172.18.0.1
```

---

### 2. 如果宿主机代理只监听 127.0.0.1，就用 socat 转发

检查宿主机代理：

```bash
sudo ss -lntp | grep -E '20170|20171|7890|7891'
```

如果看到：

```text
127.0.0.1:20171
```

就转发：

```bash
sudo apt update
sudo apt install -y socat
sudo nohup socat TCP-LISTEN:20172,fork,reuseaddr,bind=172.18.0.1 TCP:127.0.0.1:20171 > /tmp/socat-20172.log 2>&1 &
```

如果 UFW 开着：

```bash
sudo ufw status
sudo ufw allow from 172.18.0.0/16 to any port 20172 proto tcp
sudo ufw reload
```

---

### 3. 在 Sub2API 容器里测试

```bash
sudo docker exec -it sub2api sh
```

测试 OpenAI API：

```bash
curl -x http://172.18.0.1:20172 -I https://api.openai.com/v1/models --connect-timeout 8 --max-time 15
```

正常结果：

```text
HTTP/1.1 200 Connection established
HTTP/2 401
```

`401` 是正常的，说明网络通了，只是没带 OpenAI API Key。

测试 ChatGPT Codex 接口：

```bash
curl -x http://172.18.0.1:20172 -I https://chatgpt.com/backend-api/codex/responses --connect-timeout 8 --max-time 20
```

正常可能返回：

```text
HTTP/2 405
allow: POST
```

`405` 也正常，因为这个接口只允许 POST。重点是不要 timeout。

---

## 第二步：Sub2API 后台添加代理

进入后台：

```text
IP 管理
→ 添加代理
```

这样填：

```text
名称：xray-local
协议：HTTP
主机：172.18.0.1
端口：20172
用户名：不填
密码：不填
```

创建后，点：

```text
测试连接
```

如果能成功，继续绑定账号。

---

## 第三步：给 OpenAI OAuth 账号绑定代理

进入：

```text
账号管理
→ 找到 OpenAI OAuth 账号
→ 编辑
```

找到类似字段：

```text
代理
IP 代理
Proxy
出口 IP
```

选择刚创建的代理：

```text
xray-local
```

保存后再点：

```text
测试账号连接
```

---

## 判断是否走代理

### 没走代理的典型日志

```text
Post "https://chatgpt.com/backend-api/codex/responses":
dial tcp 118.xxx.xxx.xxx:443: connect: connection timed out
```

这种一般说明 Sub2API 在直连，没有走后台绑定的代理。

---

### 容器网络已通的典型现象

容器里执行：

```bash
curl -v -I https://api.openai.com/v1/models --connect-timeout 8 --max-time 15
```

如果配置了容器全局代理，会看到：

```text
Uses proxy env variable HTTPS_PROXY
Trying 172.18.0.1:20172
HTTP/2 401
```

但 Sub2API 更推荐后台 IP 管理代理，不推荐全局代理。

---

## 是否需要 Docker 全局代理？

一般不需要。

Sub2API 已经有 IP 管理，所以推荐：

```text
Sub2API 后台 IP 管理代理 > Docker 容器全局代理
```

原因：

```text
1. 不影响 Redis / Postgres 内部通信
2. 可以给不同账号绑定不同出口
3. 出问题更容易定位
4. 不会让所有请求都走代理
```

---

## 建议删除 docker-compose.yml 里的全局代理

如果已经在后台 IP 管理里配置代理，可以考虑删除这些：

```yaml
HTTP_PROXY
HTTPS_PROXY
ALL_PROXY
http_proxy
https_proxy
all_proxy
NO_PROXY
no_proxy
```

然后重启：

```bash
cd /opt/sub2api
sudo docker compose down
sudo docker compose up -d --force-recreate
```

注意：删除全局代理后，后台 IP 管理里配置的代理仍然可用，前提是容器可以访问：

```text
172.18.0.1:20172
```

---

## socat 开机自启

如果用了 socat，建议做 systemd，不然重启服务器后代理转发会失效。

```bash
sudo nano /etc/systemd/system/socat-sub2api-proxy.service
```

填入：

```ini
[Unit]
Description=Socat proxy forward for Sub2API
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
sudo systemctl enable socat-sub2api-proxy
sudo systemctl restart socat-sub2api-proxy
sudo systemctl status socat-sub2api-proxy
```

---

## 最终推荐配置

### Sub2API 后台 IP 管理

```text
名称：xray-local
协议：HTTP
主机：172.18.0.1
端口：20172
认证：无
```

### OpenAI OAuth 账号

```text
绑定代理：xray-local
分组：default / gpt / 自己的分组
状态：active
测试模型：GPT-5.5 / gpt-5.5
```

### 防火墙

推荐只允许 Docker 网段访问：

```bash
sudo ufw allow from 172.18.0.0/16 to any port 20172 proto tcp
sudo ufw reload
```

不要把代理端口直接暴露给公网。

---

## 常见问题

### 1. 后台代理主机能不能填 127.0.0.1？

一般不行。

因为 Sub2API 在容器里，`127.0.0.1` 指的是容器自己，不是宿主机。

应该填：

```text
172.18.0.1
```

或者你的实际 Docker 网关 IP。

---

### 2. 后台测试账号还是失败怎么办？

看日志：

```bash
sudo docker logs -f sub2api
```

如果还是：

```text
dial tcp xxx.xxx.xxx.xxx:443 timeout
```

说明账号没有绑定代理，或者绑定的代理不可用。

---

### 3. 账号状态 active，但 Plus Fail 是不是一定不能用？

不一定。

优先看：

```text
测试账号连接是否成功
实际调用是否成功
```

Plus 检测失败可能是权益检测接口失败，不一定代表 OAuth token 完全不可用。

---

### 4. 用 OpenAI API Key 还需要这个代理吗？

如果服务器访问 `api.openai.com` 不通，就需要。

如果只用官方 OpenAI API Key，长期更稳定；如果用 ChatGPT OAuth 账号，则更依赖 `chatgpt.com` 这条线，代理更关键。

---

## 一句话总结

Sub2API 最好这样搞：

```text
宿主机代理 127.0.0.1:20171
→ socat 转发到 172.18.0.1:20172
→ Sub2API 后台 IP 管理添加 172.18.0.1:20172
→ OpenAI OAuth 账号绑定这个代理
```

不要优先给整个容器配全局代理，除非这个项目本身没有代理配置。

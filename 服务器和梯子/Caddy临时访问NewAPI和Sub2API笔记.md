# Caddy 临时访问 NewAPI / Sub2API 笔记

## 场景

域名还在备案，暂时不要用未备案域名访问国内服务器。

临时方案：

```text
http://服务器IP:18080  -> NewAPI
http://服务器IP:18081  -> Sub2API
```

备案成功后再改成：

```text
https://newapi.xcwindfall.top
https://sub2api.xcwindfall.top
```

---

## 推荐结构

项目容器只绑定本机端口：

```text
NewAPI   127.0.0.1:3000
Sub2API  127.0.0.1:3001
```

公网只开放 Caddy 入口：

```text
18080 -> NewAPI
18081 -> Sub2API
```

这样更安全，也方便后面切域名。

---

## 1. Docker 端口写法

### NewAPI

进入目录：

```bash
cd /opt/new-api
sudo nano docker-compose.yml
```

端口建议写成：

```yaml
ports:
  - "127.0.0.1:3000:3000"
```

重启：

```bash
sudo docker compose down
sudo docker compose up -d
```

测试：

```bash
curl http://127.0.0.1:3000
```

---

### Sub2API

进入目录：

```bash
cd /opt/sub2api
sudo nano docker-compose.yml
```

端口建议写成：

```yaml
ports:
  - "127.0.0.1:3001:3000"
```

重启：

```bash
sudo docker compose down
sudo docker compose up -d
```

测试：

```bash
curl http://127.0.0.1:3001
```

---

## 2. Caddy 配置

打开配置：

```bash
sudo nano /etc/caddy/Caddyfile
```

临时写法：

```caddy
:18080 {
    reverse_proxy 127.0.0.1:3000
}

:18081 {
    reverse_proxy 127.0.0.1:3001
}
```

保存后执行：

```bash
sudo caddy fmt --overwrite /etc/caddy/Caddyfile
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

---

## 3. 放行端口

服务器防火墙：

```bash
sudo ufw allow 18080/tcp
sudo ufw allow 18081/tcp
sudo ufw status
```

云服务器安全组也要放行：

```text
TCP 18080
TCP 18081
```

然后访问：

```text
http://服务器IP:18080
http://服务器IP:18081
```

---

## 4. 常见错误：address already in use

如果报错：

```text
listen tcp :3000: bind: address already in use
```

意思是：3000 端口已经被 NewAPI / Docker 占用了，Caddy 不能再监听 3000。

错误写法：

```caddy
:3000 {
    reverse_proxy 127.0.0.1:3000
}
```

正确写法：

```caddy
:18080 {
    reverse_proxy 127.0.0.1:3000
}
```

核心原则：

```text
Caddy 对外监听端口 ≠ 后端项目端口
```

---

## 5. 备案成功后改成域名

Caddyfile 改成：

```caddy
newapi.xcwindfall.top {
    reverse_proxy 127.0.0.1:3000
}

sub2api.xcwindfall.top {
    reverse_proxy 127.0.0.1:3001
}
```

然后执行：

```bash
sudo caddy fmt --overwrite /etc/caddy/Caddyfile
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

DNS 解析：

```text
newapi.xcwindfall.top   A记录 -> 服务器IP
sub2api.xcwindfall.top  A记录 -> 服务器IP
```

---

## 结论

备案前：

```text
NewAPI:   http://服务器IP:18080
Sub2API:  http://服务器IP:18081
```

备案后：

```text
NewAPI:   https://newapi.xcwindfall.top
Sub2API:  https://sub2api.xcwindfall.top
```

不要让 Caddy 监听已经被 Docker 占用的端口，比如 `:3000`。

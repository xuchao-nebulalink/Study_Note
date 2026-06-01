# 常见故障排查：端口、DNS、Caddy、Docker

> 访问不了时不要乱改，按顺序查。先确认项目本机能不能访问，再查 Caddy，再查 DNS。

## 1. 总排查顺序

```text
1. docker ps 看容器是否运行
2. docker compose logs 看项目是否报错
3. curl 127.0.0.1:端口 看本机端口是否通
4. sudo ss -lntp 看端口是否监听
5. sudo caddy validate 看 Caddyfile 是否正确
6. sudo journalctl -u caddy -f 看 Caddy 日志
7. nslookup 子域名 看 DNS 是否对
8. curl -I https://子域名 看 HTTPS 是否通
```

## 2. Docker 容器没起来

进入项目目录：

```bash
cd /opt/apps/项目名
```

看状态：

```bash
docker compose ps
```

看日志：

```bash
docker compose logs --tail=200
```

持续看日志：

```bash
docker compose logs -f
```

常见原因：

```text
1. .env 缺少密码
2. 端口被占用
3. 数据目录权限问题
4. config.yaml 格式错误
5. 镜像拉取失败
6. 数据库没启动成功
7. Redis 密码不一致
```

## 3. 端口冲突

查看所有监听端口：

```bash
sudo ss -lntp
```

查指定端口：

```bash
sudo ss -lntp | grep :3000
sudo ss -lntp | grep :8080
sudo ss -lntp | grep :8317
```

如果被占用，改项目 compose 的左边端口。

例如：

```yaml
ports:
  - "127.0.0.1:18080:8080"
```

意思：

```text
宿主机 18080 → 容器内 8080
```

Caddy 也要跟着改：

```caddyfile
sub2api.xcwindfall.top {
    reverse_proxy 127.0.0.1:18080
}
```

## 4. 本机端口不通

比如 New API：

```bash
curl -I http://127.0.0.1:3000
```

如果失败，说明不是 Caddy 问题，是项目自己没起来。

查：

```bash
cd /opt/apps/newapi
docker compose ps
docker compose logs -f newapi
```

## 5. 本机端口通，但域名不通

说明大概率是 Caddy 或 DNS 问题。

查 DNS：

```bash
nslookup newapi.xcwindfall.top
```

查 Caddy 配置：

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
```

查 Caddy 状态：

```bash
sudo systemctl status caddy
```

看 Caddy 日志：

```bash
sudo journalctl -u caddy -f
```

重载 Caddy：

```bash
sudo systemctl reload caddy
```

## 6. Caddy 502

502 代表：

```text
浏览器 → Caddy 通了
Caddy → 后端项目 不通
```

查后端：

```bash
curl -I http://127.0.0.1:项目端口
```

如果不通，去看 Docker。

如果通，再看 Caddyfile 里端口写错没。

## 7. Caddy 证书申请失败

常见原因：

```text
1. DNS 没解析到这台服务器
2. 80/443 没开放
3. 服务器安全组没放行 80/443
4. Cloudflare SSL 模式错误
5. Caddyfile 域名写错
```

检查 80/443：

```bash
sudo ss -lntp | grep -E ':80|:443'
```

防火墙：

```bash
sudo ufw status
```

放行：

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

## 8. DNS 没生效

本地查：

```bash
nslookup sub2api.xcwindfall.top
```

服务器查：

```bash
nslookup sub2api.xcwindfall.top 8.8.8.8
nslookup sub2api.xcwindfall.top 1.1.1.1
```

如果查不到服务器 IP，就去域名服务商那里改 DNS A 记录。

## 9. Cloudflare 小黄云问题

排查阶段建议：

```text
先关小黄云 → DNS only
等 Caddy 自动 HTTPS 成功后 → 再开小黄云
```

SSL/TLS 模式：

```text
Full 或 Full(strict)
不要用 Flexible
```

## 10. Docker 拉镜像失败

```bash
docker pull 镜像名:tag
```

如果卡住或失败：

```text
1. 服务器网络不能访问 Docker Hub
2. DNS 问题
3. 镜像名写错
4. 镜像 tag 不存在
```

查 DNS：

```bash
cat /etc/resolv.conf
```

临时测试：

```bash
curl -I https://registry-1.docker.io
```

## 11. PostgreSQL 起不来

看日志：

```bash
docker compose logs -f postgres
```

如果服务名不是 postgres，比如 New API：

```bash
docker compose logs -f newapi-postgres
```

常见原因：

```text
1. 旧数据目录是 PostgreSQL 15，新镜像换成 16/18 导致不兼容
2. POSTGRES_PASSWORD 没写
3. postgres_data 权限异常
4. 磁盘满了
```

查磁盘：

```bash
df -h
```

## 12. Redis 起不来

看日志：

```bash
docker compose logs -f redis
```

New API：

```bash
docker compose logs -f newapi-redis
```

测试：

```bash
docker compose exec redis redis-cli ping
```

有密码：

```bash
docker compose exec redis redis-cli -a '你的密码' ping
```

返回：

```text
PONG
```

## 13. 修改 Caddyfile 后没生效

正确流程：

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

如果你只是保存了文件，但没 reload，不会生效。

## 14. 项目启动后外网还是访问旧页面

可能是：

```text
1. Caddy 还指向旧端口
2. 浏览器缓存
3. Cloudflare 缓存
4. Docker 旧容器还在跑
```

查端口：

```bash
sudo ss -lntp | grep 端口
```

查容器：

```bash
docker ps
```

重启项目：

```bash
cd /opt/apps/项目名
docker compose up -d --force-recreate
```

## 15. 一键排查命令

把下面命令里的域名和端口改成你的。

```bash
echo "==== DNS ===="
nslookup newapi.xcwindfall.top || true

echo "==== Caddy ===="
sudo systemctl status caddy --no-pager || true
sudo caddy validate --config /etc/caddy/Caddyfile || true

echo "==== Ports ===="
sudo ss -lntp | grep -E ':80|:443|:3000|:8080|:8317' || true

echo "==== Local Curl ===="
curl -I http://127.0.0.1:3000 || true
curl -I http://127.0.0.1:8080 || true
curl -I http://127.0.0.1:8317 || true

echo "==== Docker ===="
docker ps
```

# Sub2API 完整部署笔记

> 推荐部署方式：**官方 deploy 脚本生成 docker-compose.local.yml + 本地目录挂载 + 宿主机 Caddy 统一反代**。
>
> Sub2API 官方部署说明里推荐 `docker-deploy.sh`，它会生成 `.env`、`docker-compose.local.yml`，并创建 `data/`、`postgres_data/`、`redis_data/` 等目录。

## 1. 部署目标

```text
访问地址：https://sub2api.xcwindfall.top
项目目录：/opt/projects/sub2api
本机端口：127.0.0.1:13000
```

Sub2API 自带后端、前端、PostgreSQL、Redis。  
这个项目和 New API 不一样，Sub2API 建议按官方 compose 带数据库部署。

## 2. 创建目录

```bash
sudo mkdir -p /opt/projects/sub2api
sudo chown -R $USER:$USER /opt/projects/sub2api
cd /opt/projects/sub2api
```

## 3. 下载并执行官方部署脚本

```bash
curl -sSL https://raw.githubusercontent.com/Wei-Shaw/sub2api/main/deploy/docker-deploy.sh -o docker-deploy.sh
chmod +x docker-deploy.sh
./docker-deploy.sh
```

脚本通常会做这些事：

```text
下载 docker-compose.local.yml
生成 .env
生成 JWT_SECRET / TOTP_ENCRYPTION_KEY / POSTGRES_PASSWORD 等密钥
创建 data/、postgres_data/、redis_data/ 目录
```

## 4. 检查生成的文件

```bash
ls -la
```

正常应该能看到类似：

```text
.env
docker-compose.local.yml
data/
postgres_data/
redis_data/
```

## 5. 修改端口

打开 compose：

```bash
nano docker-compose.local.yml
```

找到 `ports`，把 Web 服务端口改成绑定本机。  
具体容器内部端口以生成文件为准，常见写法类似：

```yaml
ports:
  - "127.0.0.1:13000:3000"
```

或者如果它内部是 8080，就写：

```yaml
ports:
  - "127.0.0.1:13000:8080"
```

判断内部端口的方法：看原始 compose 里冒号右边的端口。  
比如原来是：

```yaml
ports:
  - "3000:3000"
```

就改成：

```yaml
ports:
  - "127.0.0.1:13000:3000"
```

## 6. 启动 Sub2API

```bash
cd /opt/projects/sub2api
docker compose -f docker-compose.local.yml up -d
```

查看容器：

```bash
docker ps
```

查看日志：

```bash
docker compose -f docker-compose.local.yml logs -f
```

本机测试：

```bash
curl -I http://127.0.0.1:13000
```

## 7. 配置 Caddy

编辑：

```bash
sudo nano /etc/caddy/Caddyfile
```

追加：

```caddyfile
sub2api.xcwindfall.top {
    reverse_proxy 127.0.0.1:13000
}
```

检查并重载：

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

访问：

```text
https://sub2api.xcwindfall.top
```

## 8. DNS 解析

域名后台添加：

| 主机记录 | 类型 | 值 |
|---|---|---|
| `sub2api` | A | 你的服务器公网 IP |

如果已经做了 `*` 泛解析，可以不用单独加。

## 9. 更新 Sub2API

```bash
cd /opt/projects/sub2api
docker compose -f docker-compose.local.yml pull
docker compose -f docker-compose.local.yml up -d
```

## 10. 停止 Sub2API

```bash
cd /opt/projects/sub2api
docker compose -f docker-compose.local.yml down
```

## 11. 备份 Sub2API

Sub2API 有数据库，备份一定要带上整个项目目录：

```bash
cd /opt/projects
sudo tar -czvf sub2api-backup-$(date +%F).tar.gz sub2api
```

如果只备份 compose，不备份 `postgres_data/`，数据会丢。

## 12. 常见问题

### 访问打不开

```bash
# 容器是否正常
docker ps

# 本机端口是否通
curl -I http://127.0.0.1:13000

# 看 Sub2API 日志
cd /opt/projects/sub2api
docker compose -f docker-compose.local.yml logs -f

# 看 Caddy 日志
journalctl -u caddy -f
```

### 端口冲突

查：

```bash
sudo ss -tulpn | grep :13000
```

如果被占用，就换成 13001：

```yaml
ports:
  - "127.0.0.1:13001:原容器端口"
```

Caddy 同步改：

```caddyfile
sub2api.xcwindfall.top {
    reverse_proxy 127.0.0.1:13001
}
```

## 13. 风险提醒

Sub2API 这类项目涉及账号、订阅、API 转发。  
只建议用于你自己的账号、自己的服务、自己的学习测试。  
不要拿别人的账号、不要绕过服务条款、不要做违规转售。

## 14. 参考

- Sub2API GitHub：https://github.com/Wei-Shaw/sub2api
- Sub2API deploy 文档：https://github.com/Wei-Shaw/sub2api/blob/main/deploy/README.md

# 4. Sub2API 完整部署

目标：Sub2API 使用 Docker Compose 部署，带 PostgreSQL 和 Redis，外网通过 Caddy 访问。

访问地址示例：

```text
https://sub2api.xcwindfall.top
```

推荐用官方 `docker-deploy.sh`，因为它会生成：

```text
docker-compose.local.yml
.env
data/
postgres_data/
redis_data/
```

这种本地目录版最适合备份和迁移。

## 1. 创建目录

```bash
sudo mkdir -p /opt/projects/sub2api
sudo chown -R $USER:$USER /opt/projects/sub2api
cd /opt/projects/sub2api
```

## 2. 执行官方 Docker 部署脚本

```bash
curl -sSL https://raw.githubusercontent.com/Wei-Shaw/sub2api/main/deploy/docker-deploy.sh | bash
```

脚本会做这些事：

```text
下载 docker-compose.local.yml
生成 .env
生成 JWT_SECRET / TOTP_ENCRYPTION_KEY / POSTGRES_PASSWORD
创建 data、postgres_data、redis_data
```

## 3. 修改 `.env`

```bash
nano .env
```

重点检查这些：

```env
TZ=Asia/Shanghai
SERVER_PORT=8080

POSTGRES_PASSWORD=脚本生成或你自己改的强密码
JWT_SECRET=脚本生成或你自己改的随机字符串
TOTP_ENCRYPTION_KEY=脚本生成或你自己改的随机字符串

ADMIN_EMAIL=admin@sub2api.local
ADMIN_PASSWORD=建议你自己设置一个强密码
```

如果没有 `ADMIN_PASSWORD`，首次密码可能会自动生成，需要去日志里找。

## 4. 修改宿主机端口

打开：

```bash
nano docker-compose.local.yml
```

找到 `ports`，建议改成：

```yaml
ports:
  - "127.0.0.1:8081:8080"
```

意思是：

```text
容器里面还是 8080
服务器本地用 8081
Caddy 反代到 127.0.0.1:8081
```

这样可以避免跟其他项目抢 8080。

## 5. 启动

```bash
cd /opt/projects/sub2api
docker compose -f docker-compose.yml up -d
sudo docker compose ps
```

看日志：

```bash
docker compose -f docker-compose.yml logs -f sub2api
```

如果你没设置管理员密码，查自动生成密码：

```bash
docker compose -f docker-compose.yml logs sub2api | grep "admin password"
```

本机测试：

```bash
curl -I http://127.0.0.1:8081
```

## 6. 配置 Caddy

```bash
sudo nano /etc/caddy/Caddyfile
```

加入：

```caddyfile
sub2api.xcwindfall.top {
    encode gzip
    reverse_proxy 127.0.0.1:8081
}
```

重载：

```bash
sudo caddy validate --config /etc/caddy/Caddyfile   //作用以管理员权限验证 Caddy 配置文件的语法和逻辑是否正确，但不会实际应用或重启服务
sudo systemctl reload caddy
```

访问：

```text
https://sub2api.xcwindfall.top
```

## 7. Sub2API 更新

更新前备份：

```bash
cd /opt/projects/sub2api

BACKUP_DIR=backups/$(date +%F_%H%M)
mkdir -p $BACKUP_DIR
tar czf $BACKUP_DIR/sub2api_all.tar.gz .env docker-compose.local.yml data postgres_data redis_data
```

更新：

```bash
docker compose -f docker-compose.local.yml pull
docker compose -f docker-compose.local.yml up -d
docker compose -f docker-compose.local.yml logs -f sub2api
```

## 8. Sub2API 迁移到新服务器

源服务器：

```bash
cd /opt/projects
docker compose -f sub2api/docker-compose.local.yml down
tar czf sub2api.tar.gz sub2api
```

上传到新服务器：

```bash
scp sub2api.tar.gz root@新服务器IP:/opt/projects/
```

新服务器：

```bash
cd /opt/projects
tar xzf sub2api.tar.gz
cd sub2api
docker compose -f docker-compose.local.yml up -d
```

## 9. 常见问题

### 访问不了

检查：

```bash
docker compose -f docker-compose.local.yml ps
docker compose -f docker-compose.local.yml logs -f sub2api
sudo ss -lntp | grep 8081
curl -I http://127.0.0.1:8081
```

### 端口被占用

改 `docker-compose.local.yml` 左侧端口：

```yaml
ports:
  - "127.0.0.1:8082:8080"
```

然后 Caddy 改：

```caddyfile
reverse_proxy 127.0.0.1:8082
```

重启：

```bash
docker compose -f docker-compose.local.yml up -d
sudo systemctl reload caddy
```

### 数据库迁移失败

先别乱删目录，看日志：

```bash
docker compose -f docker-compose.local.yml logs -f sub2api
docker compose -f docker-compose.local.yml logs -f postgres
```

如果升级前没备份，别执行 `down -v`，否则数据可能没了。

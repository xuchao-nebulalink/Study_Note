# Sub2API 完整部署：PostgreSQL + Redis 生产版

> Sub2API 官方推荐用 `deploy/docker-deploy.sh` 生成本地目录版 `docker-compose.local.yml`。这个版本会把 `data/`、`postgres_data/`、`redis_data/` 都放在项目目录里，方便备份和迁移。

## 1. 目标效果

```text
访问地址：https://sub2api.xcwindfall.top
本机端口：127.0.0.1:8080
项目目录：/opt/apps/sub2api
应用容器：sub2api
数据库：sub2api-postgres
缓存：sub2api-redis
```

## 2. 创建目录

```bash
mkdir -p /opt/apps/sub2api
cd /opt/apps/sub2api
```

## 3. 推荐方式：使用官方 docker-deploy.sh

```bash
cd /opt/apps/sub2api
curl -sSL https://raw.githubusercontent.com/Wei-Shaw/sub2api/main/deploy/docker-deploy.sh -o docker-deploy.sh
chmod +x docker-deploy.sh
./docker-deploy.sh
```

这个脚本会做这些事：

```text
1. 下载 docker-compose.local.yml
2. 下载 .env.example
3. 自动生成 .env
4. 自动生成 JWT_SECRET
5. 自动生成 TOTP_ENCRYPTION_KEY
6. 自动生成 POSTGRES_PASSWORD
7. 创建 data/ postgres_data/ redis_data/
```

## 4. 检查 `.env`

```bash
nano .env
```

重点看这些：

```env
BIND_HOST=127.0.0.1
SERVER_PORT=8080
SERVER_MODE=release
RUN_MODE=standard
TZ=Asia/Shanghai

POSTGRES_USER=sub2api
POSTGRES_PASSWORD=这里必须是强密码
POSTGRES_DB=sub2api

REDIS_PASSWORD=可以设置一个强密码
REDIS_DB=0

ADMIN_EMAIL=admin@sub2api.local
ADMIN_PASSWORD=建议你自己设置一个强密码

JWT_SECRET=固定随机字符串
TOTP_ENCRYPTION_KEY=固定随机字符串
```

建议你手动把：

```env
BIND_HOST=127.0.0.1
```

这样 Sub2API 的 8080 只给本机访问，公网只能通过 Caddy 访问。

如果你想临时直接用 `服务器IP:8080` 调试，可以写：

```env
BIND_HOST=0.0.0.0
```

调试完再改回：

```env
BIND_HOST=127.0.0.1
```

## 5. 如果不用脚本，手动写 compose

一般不需要你手写，因为官方脚本会生成。这里给你一个可读版，方便你知道关键配置。

```yaml
services:
  sub2api:
    image: weishaw/sub2api:latest
    container_name: sub2api
    restart: unless-stopped
    ports:
      - "${BIND_HOST:-127.0.0.1}:${SERVER_PORT:-8080}:8080"
    volumes:
      - ./data:/app/data
      # 如果你要自定义 config.yaml，再打开这一行
      # - ./config.yaml:/app/data/config.yaml
    environment:
      AUTO_SETUP: "true"
      SERVER_HOST: 0.0.0.0
      SERVER_PORT: 8080
      SERVER_MODE: ${SERVER_MODE:-release}
      RUN_MODE: ${RUN_MODE:-standard}

      DATABASE_HOST: postgres
      DATABASE_PORT: 5432
      DATABASE_USER: ${POSTGRES_USER:-sub2api}
      DATABASE_PASSWORD: ${POSTGRES_PASSWORD}
      DATABASE_DBNAME: ${POSTGRES_DB:-sub2api}
      DATABASE_SSLMODE: disable
      DATABASE_MAX_OPEN_CONNS: ${DATABASE_MAX_OPEN_CONNS:-50}
      DATABASE_MAX_IDLE_CONNS: ${DATABASE_MAX_IDLE_CONNS:-10}

      REDIS_HOST: redis
      REDIS_PORT: 6379
      REDIS_PASSWORD: ${REDIS_PASSWORD:-}
      REDIS_DB: ${REDIS_DB:-0}
      REDIS_POOL_SIZE: ${REDIS_POOL_SIZE:-1024}

      ADMIN_EMAIL: ${ADMIN_EMAIL:-admin@sub2api.local}
      ADMIN_PASSWORD: ${ADMIN_PASSWORD:-}
      JWT_SECRET: ${JWT_SECRET:-}
      TOTP_ENCRYPTION_KEY: ${TOTP_ENCRYPTION_KEY:-}
      TZ: ${TZ:-Asia/Shanghai}

      UPDATE_PROXY_URL: ${UPDATE_PROXY_URL:-}
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - sub2api-network
    healthcheck:
      test: ["CMD", "wget", "-q", "-T", "5", "-O", "/dev/null", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  postgres:
    image: postgres:18-alpine
    container_name: sub2api-postgres
    restart: unless-stopped
    volumes:
      - ./postgres_data:/var/lib/postgresql/data
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-sub2api}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB:-sub2api}
      TZ: ${TZ:-Asia/Shanghai}
    networks:
      - sub2api-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-sub2api} -d ${POSTGRES_DB:-sub2api}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s

  redis:
    image: redis:8-alpine
    container_name: sub2api-redis
    restart: unless-stopped
    volumes:
      - ./redis_data:/data
    command: >
      sh -c 'redis-server --save 60 1 --appendonly yes --appendfsync everysec ${REDIS_PASSWORD:+--requirepass "$REDIS_PASSWORD"}'
    environment:
      TZ: ${TZ:-Asia/Shanghai}
      REDISCLI_AUTH: ${REDIS_PASSWORD:-}
    networks:
      - sub2api-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 5s

networks:
  sub2api-network:
    driver: bridge
```

## 6. 启动

官方脚本生成的是 `docker-compose.local.yml`，所以启动命令是：

```bash
cd /opt/apps/sub2api
docker compose -f docker-compose.local.yml up -d
```

查看状态：

```bash
docker compose -f docker-compose.local.yml ps
```

查看日志：

```bash
docker compose -f docker-compose.local.yml logs -f sub2api
```

如果你没设置 `ADMIN_PASSWORD`，首次密码一般在日志里：

```bash
docker compose -f docker-compose.local.yml logs sub2api | grep -i "admin password"
```

本机测试：

```bash
curl -I http://127.0.0.1:8080
curl http://127.0.0.1:8080/health
```

## 7. 配置 Caddy

```bash
sudo nano /etc/caddy/Caddyfile
```

添加：

```caddyfile
sub2api.xcwindfall.top {
    reverse_proxy 127.0.0.1:8080 {
        flush_interval -1
        transport http {
            read_timeout 600s
            write_timeout 600s
            dial_timeout 30s
        }
    }
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

## 8. `config.yaml` 怎么处理

Sub2API 默认会在 `/app/data/config.yaml` 生成配置。

映射到宿主机就是：

```text
/opt/apps/sub2api/data/config.yaml
```

你可以这样看：

```bash
cd /opt/apps/sub2api
ls -lah data
nano data/config.yaml
```

如果你想自己维护 `config.yaml`，可以：

```bash
cp data/config.yaml ./config.yaml
nano config.yaml
```

然后在 `docker-compose.local.yml` 里打开这行：

```yaml
volumes:
  - ./data:/app/data
  - ./config.yaml:/app/data/config.yaml
```

改完重启：

```bash
docker compose -f docker-compose.local.yml restart sub2api
```

## 9. 更新 Sub2API

更新前备份。

```bash
cd /opt/apps/sub2api
mkdir -p backups
BACKUP_TIME=$(date +%Y%m%d_%H%M%S)
docker compose -f docker-compose.local.yml exec -T postgres pg_dump -U sub2api sub2api > backups/sub2api_pg_${BACKUP_TIME}.sql
```

再打包整个目录：

```bash
cd /opt/apps
tar czf sub2api_full_$(date +%Y%m%d_%H%M%S).tar.gz sub2api
```

拉新镜像并重启：

```bash
cd /opt/apps/sub2api
docker compose -f docker-compose.local.yml pull
docker compose -f docker-compose.local.yml up -d
```

看日志：

```bash
docker compose -f docker-compose.local.yml logs -f sub2api
```

## 10. 迁移到新服务器

在旧服务器：

```bash
cd /opt/apps
docker compose -f /opt/apps/sub2api/docker-compose.local.yml down
tar czf sub2api-complete.tar.gz sub2api
```

传到新服务器：

```bash
scp sub2api-complete.tar.gz root@新服务器IP:/opt/apps/
```

在新服务器：

```bash
cd /opt/apps
tar xzf sub2api-complete.tar.gz
cd sub2api
docker compose -f docker-compose.local.yml up -d
```

再把 DNS 改到新服务器 IP，或者 Caddy 配好。

## 11. 回滚

如果更新后坏了：

```bash
cd /opt/apps/sub2api
docker compose -f docker-compose.local.yml down
```

如果你打包了整个目录，恢复最简单：

```bash
cd /opt/apps
mv sub2api sub2api_bad_$(date +%Y%m%d_%H%M%S)
tar xzf sub2api_full_时间.tar.gz
cd sub2api
docker compose -f docker-compose.local.yml up -d
```

## 12. 常见问题

### 12.1 登录密码不知道

```bash
cd /opt/apps/sub2api
docker compose -f docker-compose.local.yml logs sub2api | grep -i "admin"
```

或者你直接在 `.env` 固定：

```env
ADMIN_EMAIL=你的邮箱
ADMIN_PASSWORD=你的强密码
```

然后重启：

```bash
docker compose -f docker-compose.local.yml restart sub2api
```

注意：如果账号已经创建，改 `.env` 不一定会覆盖旧密码，具体看当前版本逻辑。

### 12.2 Redis healthcheck 失败

如果你设置了 `REDIS_PASSWORD`，但是 healthcheck 没带认证，可能需要改成：

```yaml
healthcheck:
  test: ["CMD-SHELL", "redis-cli -a \"$REDISCLI_AUTH\" ping | grep PONG"]
```

然后：

```bash
docker compose -f docker-compose.local.yml up -d
```

### 12.3 端口 8080 被占用

```bash
sudo ss -lntp | grep :8080
```

改 `.env`：

```env
SERVER_PORT=18080
```

Caddy 也改：

```caddyfile
sub2api.xcwindfall.top {
    reverse_proxy 127.0.0.1:18080
}
```

重启：

```bash
docker compose -f docker-compose.local.yml up -d
sudo systemctl reload caddy
```

## 13. 官方参考

- Sub2API GitHub：`https://github.com/Wei-Shaw/sub2api`
- Sub2API Docker 部署说明：`https://github.com/Wei-Shaw/sub2api/blob/main/deploy/README.md`
- Sub2API Docker Compose local：`https://github.com/Wei-Shaw/sub2api/blob/main/deploy/docker-compose.local.yml`
- Sub2API `.env.example`：`https://github.com/Wei-Shaw/sub2api/blob/main/deploy/.env.example`

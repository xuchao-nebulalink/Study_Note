# New API 完整部署：PostgreSQL + Redis 生产版

> 这一版不是最简单的 SQLite 部署，而是适合长期跑的 PostgreSQL + Redis 版本。New API 官方 Docker Compose 示例里包含 `calciumion/new-api:latest`、PostgreSQL、Redis、`SQL_DSN`、`REDIS_CONN_STRING` 等配置。

## 1. 目标效果

```text
访问地址：https://newapi.xcwindfall.top
本机端口：127.0.0.1:3000
应用容器：newapi
数据库：newapi-postgres
缓存：newapi-redis
数据目录：/opt/apps/newapi
```

## 2. 创建目录

```bash
mkdir -p /opt/apps/newapi
cd /opt/apps/newapi
mkdir -p data logs postgres_data redis_data backups
```

## 3. 创建 `.env`

```bash
nano .env
```

写入下面内容。

注意：密码自己改，不要照抄 `change_this`。

```env
# ========= 基础 =========
TZ=Asia/Shanghai
NEWAPI_PORT=3000

# ========= PostgreSQL =========
POSTGRES_USER=newapi
POSTGRES_PASSWORD=change_this_pg_password
POSTGRES_DB=newapi

# ========= Redis =========
REDIS_PASSWORD=change_this_redis_password

# ========= New API =========
# 生成命令：openssl rand -hex 32
SESSION_SECRET=change_this_session_secret
CRYPTO_SECRET=change_this_crypto_secret

# 流式响应超时，AI 网关建议给大一点
STREAMING_TIMEOUT=600

# 日志和批量更新
ERROR_LOG_ENABLED=true
BATCH_UPDATE_ENABLED=true
BATCH_UPDATE_INTERVAL=5
SYNC_FREQUENCY=60

# 节点名，单机也建议写，方便日志区分
NODE_NAME=newapi-main
```

生成随机密钥：

```bash
openssl rand -hex 32
openssl rand -hex 32
```

把生成的两个值分别填到：

```text
SESSION_SECRET=
CRYPTO_SECRET=
```

## 4. 创建 `docker-compose.yml`

```bash
nano docker-compose.yml
```

写入：

```yaml
services:
  newapi:
    image: calciumion/new-api:latest
    container_name: newapi
    restart: unless-stopped
    command: --log-dir /app/logs
    ports:
      - "127.0.0.1:${NEWAPI_PORT:-3000}:3000"
    volumes:
      - ./data:/data
      - ./logs:/app/logs
    environment:
      TZ: ${TZ:-Asia/Shanghai}
      SQL_DSN: postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@newapi-postgres:5432/${POSTGRES_DB}
      REDIS_CONN_STRING: redis://:${REDIS_PASSWORD}@newapi-redis:6379
      SESSION_SECRET: ${SESSION_SECRET}
      CRYPTO_SECRET: ${CRYPTO_SECRET}
      STREAMING_TIMEOUT: ${STREAMING_TIMEOUT:-600}
      ERROR_LOG_ENABLED: ${ERROR_LOG_ENABLED:-true}
      BATCH_UPDATE_ENABLED: ${BATCH_UPDATE_ENABLED:-true}
      BATCH_UPDATE_INTERVAL: ${BATCH_UPDATE_INTERVAL:-5}
      SYNC_FREQUENCY: ${SYNC_FREQUENCY:-60}
      NODE_NAME: ${NODE_NAME:-newapi-main}
    depends_on:
      newapi-postgres:
        condition: service_healthy
      newapi-redis:
        condition: service_healthy
    networks:
      - newapi-network
    healthcheck:
      test: ["CMD-SHELL", "wget -q -O - http://localhost:3000/api/status | grep -o '\"success\":\\s*true' || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  newapi-postgres:
    image: postgres:15-alpine
    container_name: newapi-postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
      TZ: ${TZ:-Asia/Shanghai}
    volumes:
      - ./postgres_data:/var/lib/postgresql/data
    networks:
      - newapi-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s

  newapi-redis:
    image: redis:7-alpine
    container_name: newapi-redis
    restart: unless-stopped
    command: >
      sh -c 'redis-server --appendonly yes --requirepass "$REDIS_PASSWORD"'
    environment:
      REDIS_PASSWORD: ${REDIS_PASSWORD}
      TZ: ${TZ:-Asia/Shanghai}
    volumes:
      - ./redis_data:/data
    networks:
      - newapi-network
    healthcheck:
      test: ["CMD-SHELL", "redis-cli -a \"$REDIS_PASSWORD\" ping | grep PONG"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 5s

networks:
  newapi-network:
    driver: bridge
```

## 5. 启动 New API

```bash
cd /opt/apps/newapi
docker compose up -d
```

查看容器：

```bash
docker ps
```

查看日志：

```bash
docker compose logs -f newapi
```

本机测试：

```bash
curl -I http://127.0.0.1:3000
```

## 6. 配置 Caddy 反代

编辑：

```bash
sudo nano /etc/caddy/Caddyfile
```

添加：

```caddyfile
newapi.xcwindfall.top {
    reverse_proxy 127.0.0.1:3000 {
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
https://newapi.xcwindfall.top
```

## 7. 首次登录

打开：

```text
https://newapi.xcwindfall.top
```

New API 默认初始账号通常需要看项目当前版本说明或容器日志。如果页面提示初始化，按页面操作。

看日志：

```bash
cd /opt/apps/newapi
docker compose logs newapi | tail -n 100
```

## 8. New API 环境变量说明

| 变量 | 用途 | 建议 |
|---|---|---|
| `SQL_DSN` | 数据库连接字符串 | 生产用 PostgreSQL/MySQL，不建议长期 SQLite |
| `REDIS_CONN_STRING` | Redis 连接字符串 | 建议开启，配合缓存和批量更新 |
| `SESSION_SECRET` | 会话密钥 | 固定不变，别每次换 |
| `CRYPTO_SECRET` | 加密密钥 | 固定不变，Redis/敏感数据相关 |
| `STREAMING_TIMEOUT` | 流式响应超时 | AI 网关建议 300~600 秒 |
| `ERROR_LOG_ENABLED` | 错误日志 | 建议 true |
| `BATCH_UPDATE_ENABLED` | 批量更新 | 建议 true，减轻数据库压力 |
| `SYNC_FREQUENCY` | 缓存同步频率 | 默认 60 秒即可 |
| `NODE_NAME` | 节点名称 | 建议写，方便日志审计 |

## 9. PostgreSQL 连接测试

```bash
cd /opt/apps/newapi
docker compose exec newapi-postgres psql -U newapi -d newapi -c '\dt'
```

## 10. Redis 连接测试

```bash
cd /opt/apps/newapi
docker compose exec newapi-redis redis-cli -a "$REDIS_PASSWORD" ping
```

如果上面这个环境变量没带进去，可以直接写密码：

```bash
docker compose exec newapi-redis redis-cli -a '你的Redis密码' ping
```

返回：

```text
PONG
```

## 11. 更新 New API

更新前先备份。

### 11.1 备份数据库

```bash
cd /opt/apps/newapi
mkdir -p backups
BACKUP_TIME=$(date +%Y%m%d_%H%M%S)
docker compose exec -T newapi-postgres pg_dump -U newapi newapi > backups/newapi_pg_${BACKUP_TIME}.sql
```

### 11.2 备份整个目录

```bash
cd /opt/apps
tar czf newapi_full_$(date +%Y%m%d_%H%M%S).tar.gz newapi
```

### 11.3 拉取新镜像并重启

```bash
cd /opt/apps/newapi
docker compose pull newapi
docker compose up -d
```

### 11.4 查看日志

```bash
docker compose logs -f newapi
```

## 12. 回滚 New API

如果更新后有问题：

```bash
cd /opt/apps/newapi
docker compose down
```

如果你之前固定了镜像版本，比如：

```yaml
image: calciumion/new-api:v0.x.x
```

就改回旧版本，然后：

```bash
docker compose up -d
```

如果数据库结构也被升级了，简单回退镜像不一定够，需要恢复数据库备份：

```bash
cd /opt/apps/newapi
docker compose down
docker compose up -d newapi-postgres
cat backups/newapi_pg_时间.sql | docker compose exec -T newapi-postgres psql -U newapi -d newapi
docker compose up -d
```

## 13. 从 SQLite 迁移到 PostgreSQL 的建议

如果你之前是 SQLite 部署，文件一般在：

```text
/opt/apps/newapi/data/one-api.db
```

迁移到 PostgreSQL 不建议直接硬转，除非你确认表结构兼容。稳妥做法：

```text
1. 先备份 SQLite 文件
2. 新建 PostgreSQL + Redis 版 New API
3. 页面里重新配置渠道、用户、令牌
4. 如果数据很重要，再研究数据库迁移脚本
```

备份 SQLite：

```bash
cd /opt/apps/newapi
cp data/one-api.db backups/one-api_$(date +%Y%m%d_%H%M%S).db
```

## 14. 常见问题

### 14.1 访问 `https://newapi.xcwindfall.top` 不通

先查本机端口：

```bash
curl -I http://127.0.0.1:3000
```

如果本机都不通，就是 New API 没起来：

```bash
cd /opt/apps/newapi
docker compose ps
docker compose logs -f newapi
```

如果本机通，域名不通，就是 DNS/Caddy 问题：

```bash
nslookup newapi.xcwindfall.top
sudo caddy validate --config /etc/caddy/Caddyfile
sudo journalctl -u caddy -f
```

### 14.2 Postgres 起不来

```bash
cd /opt/apps/newapi
docker compose logs -f newapi-postgres
```

常见原因：

```text
1. postgres_data 目录权限问题
2. POSTGRES_PASSWORD 空了
3. 旧数据目录和新版本 PostgreSQL 不兼容
```

### 14.3 Redis 密码不对

确保 `.env` 里的：

```env
REDIS_PASSWORD=xxx
```

和 compose 里的：

```yaml
REDIS_CONN_STRING: redis://:${REDIS_PASSWORD}@newapi-redis:6379
```

一致。

### 14.4 端口冲突

```bash
sudo ss -lntp | grep :3000
```

如果 3000 被占用，改 `.env`：

```env
NEWAPI_PORT=13000
```

Caddy 也改：

```caddyfile
newapi.xcwindfall.top {
    reverse_proxy 127.0.0.1:13000
}
```

然后：

```bash
docker compose up -d
sudo systemctl reload caddy
```

## 15. 官方参考

- New API GitHub：`https://github.com/QuantumNous/new-api`
- New API Docker Compose 示例：`https://github.com/QuantumNous/new-api/blob/main/docker-compose.yml`
- New API 环境变量文档：`https://github.com/QuantumNous/new-api-docs-v1/blob/main/content/docs/zh/installation/config-maintenance/environment-variables.mdx`

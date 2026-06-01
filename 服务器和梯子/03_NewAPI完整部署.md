# 3. New API 完整部署

目标：New API 使用 Docker Compose 部署，数据库用 PostgreSQL，缓存用 Redis，外网通过 Caddy 访问。

官方镜像：

```text
calciumion/new-api:latest
```

访问地址示例：

```text
https://newapi.xcwindfall.top
```

## 1. 创建目录

```bash
sudo mkdir -p /opt/projects/newapi
sudo chown -R $USER:$USER /opt/projects/newapi
cd /opt/projects/newapi

mkdir -p data logs postgres/data redis/data backups
```

## 2. 创建 `.env`

```bash
nano .env
```

写入：

```env
TZ=Asia/Shanghai

POSTGRES_USER=newapi
POSTGRES_PASSWORD=改成你的强密码
POSTGRES_DB=newapi

REDIS_PASSWORD=改成你的强密码

SESSION_SECRET=改成随机字符串
CRYPTO_SECRET=改成随机字符串

NEWAPI_PORT=3000
```

生成随机字符串：

```bash
openssl rand -hex 32
```

注意：

```text
POSTGRES_PASSWORD、REDIS_PASSWORD、SESSION_SECRET、CRYPTO_SECRET 都要改
不要用 123456
```

## 3. 创建 `docker-compose.yml`

```bash
nano docker-compose.yml
```

写入：

```yaml
services:
  new-api:
    image: calciumion/new-api:latest
    container_name: newapi
    restart: always
    command: --log-dir /app/logs
    env_file:
      - .env
    ports:
      - "127.0.0.1:${NEWAPI_PORT}:3000"
    volumes:
      - ./data:/data
      - ./logs:/app/logs
    environment:
      SQL_DSN: "postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}"
      REDIS_CONN_STRING: "redis://:${REDIS_PASSWORD}@redis:6379"
      TZ: "${TZ}"
      SESSION_SECRET: "${SESSION_SECRET}"
      CRYPTO_SECRET: "${CRYPTO_SECRET}"
      ERROR_LOG_ENABLED: "true"
      BATCH_UPDATE_ENABLED: "true"
      NODE_NAME: "newapi-node-1"
    depends_on:
      - postgres
      - redis
    networks:
      - newapi-net

  postgres:
    image: postgres:15
    container_name: newapi-postgres
    restart: always
    env_file:
      - .env
    environment:
      POSTGRES_USER: "${POSTGRES_USER}"
      POSTGRES_PASSWORD: "${POSTGRES_PASSWORD}"
      POSTGRES_DB: "${POSTGRES_DB}"
      TZ: "${TZ}"
    volumes:
      - ./postgres/data:/var/lib/postgresql/data
    networks:
      - newapi-net

  redis:
    image: redis:7
    container_name: newapi-redis
    restart: always
    command: ["redis-server", "--appendonly", "yes", "--requirepass", "${REDIS_PASSWORD}"]
    volumes:
      - ./redis/data:/data
    networks:
      - newapi-net

networks:
  newapi-net:
    driver: bridge
```

## 4. 启动

```bash
cd /opt/projects/newapi
docker compose up -d
docker compose ps
```

看日志：

```bash
docker compose logs -f new-api
```

本机测试：

```bash
curl -I http://127.0.0.1:3000
```

## 5. 配置 Caddy

```bash
sudo nano /etc/caddy/Caddyfile
```

加入：

```caddyfile
newapi.xcwindfall.top {
    encode gzip
    reverse_proxy 127.0.0.1:3000
}
```

重载：

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

访问：

```text
https://newapi.xcwindfall.top
```

首次进入后，按页面提示初始化管理员；如果出现默认管理员账号，第一件事就是改密码。

## 6. New API 更新

更新前先备份：

```bash
cd /opt/projects/newapi

mkdir -p backups/$(date +%F_%H%M)
docker exec newapi-postgres pg_dump -U newapi newapi > backups/$(date +%F_%H%M)/newapi.sql
tar czf backups/$(date +%F_%H%M)/newapi_files.tar.gz data logs
```

更新：

```bash
docker compose pull
docker compose up -d
docker compose logs -f new-api
```

清理旧镜像：

```bash
docker image prune -f
```

## 7. New API 备份

手动备份：

```bash
cd /opt/projects/newapi

BACKUP_DIR=backups/$(date +%F_%H%M)
mkdir -p $BACKUP_DIR

docker exec newapi-postgres pg_dump -U newapi newapi > $BACKUP_DIR/newapi.sql
tar czf $BACKUP_DIR/newapi_data.tar.gz data logs .env docker-compose.yml
```

查看备份：

```bash
ls -lh backups
```

## 8. New API 恢复

先停服务：

```bash
cd /opt/projects/newapi
docker compose down
```

恢复数据库：

```bash
docker compose up -d postgres redis
sleep 10

cat backups/你的备份目录/newapi.sql | docker exec -i newapi-postgres psql -U newapi -d newapi
```

恢复文件：

```bash
tar xzf backups/你的备份目录/newapi_data.tar.gz
docker compose up -d
```

## 9. 常见问题

### 端口冲突

```bash
sudo ss -lntp | grep 3000
```

如果 3000 被占用，改 `.env`：

```env
NEWAPI_PORT=3001
```

然后 Caddy 也改：

```caddyfile
reverse_proxy 127.0.0.1:3001
```

重启：

```bash
docker compose up -d
sudo systemctl reload caddy
```

### 数据库连不上

看数据库日志：

```bash
docker compose logs -f postgres
```

进入数据库测试：

```bash
docker exec -it newapi-postgres psql -U newapi -d newapi
```

### Redis 连不上

```bash
docker compose logs -f redis
docker exec -it newapi-redis redis-cli -a 你的Redis密码 ping
```

返回：

```text
PONG
```

说明 Redis 正常。

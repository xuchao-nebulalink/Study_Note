# New API 完整部署笔记

> 推荐部署方式：**Docker Compose + SQLite 简化版 + 宿主机 Caddy 统一反代**。
>
> New API 官方说明里，最新 Docker 镜像是 `calciumion/new-api:latest`，本地数据库可以用 SQLite，并且需要挂载 `/data` 目录。

## 1. 部署目标

```text
访问地址：https://newapi.xcwindfall.top
项目目录：/opt/projects/new-api
本机端口：127.0.0.1:3000
容器端口：3000
```

## 2. 创建目录

```bash
sudo mkdir -p /opt/projects/new-api
sudo chown -R $USER:$USER /opt/projects/new-api
cd /opt/projects/new-api
mkdir -p data logs
```

## 3. 创建 docker-compose.yml

```bash
nano docker-compose.yml
```

写入：

```yaml
services:
  new-api:
    image: calciumion/new-api:latest
    container_name: new-api
    restart: always
    ports:
      - "127.0.0.1:3000:3000"
    environment:
      - TZ=Asia/Shanghai
      - ERROR_LOG_ENABLED=true
    volumes:
      - ./data:/data
      - ./logs:/app/logs
```

说明：

```text
./data:/data      保存 SQLite 数据和关键数据
./logs:/app/logs  保存日志
127.0.0.1:3000   只允许本机访问，不直接暴露公网
```

## 4. 启动 New API

```bash
cd /opt/projects/new-api
docker compose up -d
```

查看容器：

```bash
docker ps | grep new-api
```

查看日志：

```bash
docker compose logs -f
```

本机测试：

```bash
curl -I http://127.0.0.1:3000
```

## 5. 配置 Caddy 反代

编辑：

```bash
sudo nano /etc/caddy/Caddyfile
```

追加：

```caddyfile
newapi.xcwindfall.top {
    reverse_proxy 127.0.0.1:3000
}
```

检查：

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
```

重载：

```bash
sudo systemctl reload caddy
```

访问：

```text
https://newapi.xcwindfall.top
```

## 6. DNS 解析

域名后台添加：

| 主机记录 | 类型 | 值 |
|---|---|---|
| `newapi` | A | 你的服务器公网 IP |

如果已经做了 `*` 泛解析，这一步可以不用单独加。

## 7. 更新 New API

```bash
cd /opt/projects/new-api
docker compose pull
docker compose up -d
```

## 8. 停止 New API

```bash
cd /opt/projects/new-api
docker compose down
```

## 9. 备份 New API

```bash
cd /opt/projects
sudo tar -czvf new-api-backup-$(date +%F).tar.gz new-api
```

## 10. 如果以后要上 MySQL/PostgreSQL

现在个人用、小规模用 SQLite 就够简单。  
后续用户多、数据多、要更稳定，可以再改成 MySQL 或 PostgreSQL。

官方支持的方向：

```text
SQLite：最简单，适合个人或小规模
MySQL：适合长期生产
PostgreSQL：也适合长期生产
Redis：可选，用于缓存/队列等增强能力
```

你现在这个服务器多个项目的方案里，New API 不单独配 Caddy，统一走宿主机 Caddy。

## 11. 常见问题

### 访问打不开

按顺序查：

```bash
# 1. 容器是否起来
docker ps | grep new-api

# 2. 本机端口是否通
curl -I http://127.0.0.1:3000

# 3. Caddy 配置是否正确
sudo caddy validate --config /etc/caddy/Caddyfile

# 4. Caddy 日志
journalctl -u caddy -f

# 5. DNS 是否解析正确
nslookup newapi.xcwindfall.top
```

### 3000 端口被占用

查：

```bash
sudo ss -tulpn | grep :3000
```

如果冲突，把 compose 改成：

```yaml
ports:
  - "127.0.0.1:3001:3000"
```

Caddy 也改：

```caddyfile
newapi.xcwindfall.top {
    reverse_proxy 127.0.0.1:3001
}
```

## 12. 参考

- New API GitHub：https://github.com/QuantumNous/new-api
- New API Docker Compose 文档：https://www.newapi.ai/en/docs/installation/config-maintenance/docker-compose-yml

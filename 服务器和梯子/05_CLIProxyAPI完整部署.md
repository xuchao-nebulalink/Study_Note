# 5. CLIProxyAPI 完整部署

目标：CLIProxyAPI 使用 Docker Compose 部署，外网通过 Caddy 访问主端口 `8317`。

访问地址示例：

```text
https://cliproxy.xcwindfall.top
```

CLIProxyAPI 主要端口：

| 端口 | 作用 |
|---:|---|
| `8317` | 主 API / 管理入口 |
| `8085` | Gemini OAuth 回调 |
| `1455` | Claude OAuth 回调 |
| `54545` | Codex OAuth 回调 |
| `51121` | Qwen OAuth 回调 |
| `11451` | iFlow OAuth 回调 |

## 1. 创建目录

```bash
sudo mkdir -p /opt/projects/cliproxyapi
sudo chown -R $USER:$USER /opt/projects/cliproxyapi
cd /opt/projects/cliproxyapi

mkdir -p auths logs backups
```

## 2. 创建 `config.yaml`

不要让 Docker 自动把 `config.yaml` 创建成目录，先手动创建文件：

```bash
nano config.yaml
```

写入最小配置：

```yaml
host: ""
port: 8317

auth-dir: "/root/.cli-proxy-api"

api-keys:
  - "改成你的访问密钥"

debug: false
logging-to-file: true

pprof:
  enable: false
  addr: "127.0.0.1:8316"

commercial-mode: false
```

生成访问密钥：

```bash
openssl rand -hex 32
```

把生成的值替换到：

```yaml
api-keys:
  - "这里"
```

## 3. 创建 `docker-compose.yml`

```bash
nano docker-compose.yml
```

写入：

```yaml
services:
  cli-proxy-api:
    image: eceasy/cli-proxy-api:latest
    container_name: cli-proxy-api
    restart: unless-stopped
    pull_policy: always
    environment:
      DEPLOY: ""
      TZ: Asia/Shanghai
    ports:
      - "127.0.0.1:8317:8317"
      - "127.0.0.1:8085:8085"
      - "127.0.0.1:1455:1455"
      - "127.0.0.1:54545:54545"
      - "127.0.0.1:51121:51121"
      - "127.0.0.1:11451:11451"
    volumes:
      - ./config.yaml:/CLIProxyAPI/config.yaml
      - ./auths:/root/.cli-proxy-api
      - ./logs:/CLIProxyAPI/logs
```

说明：

```text
8317 是主服务端口
其他几个是 OAuth 回调端口
全部绑定 127.0.0.1，避免裸奔到公网
```

## 4. 启动

```bash
cd /opt/projects/cliproxyapi
docker compose up -d
docker compose ps
```

看日志：

```bash
docker compose logs -f cli-proxy-api
```

本机测试：

```bash
curl -I http://127.0.0.1:8317
```

## 5. 配置 Caddy

```bash
sudo nano /etc/caddy/Caddyfile
```

加入：

```caddyfile
cliproxy.xcwindfall.top {
    encode gzip
    reverse_proxy 127.0.0.1:8317
}
```

重载：

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

访问：

```text
https://cliproxy.xcwindfall.top
```

## 6. API 调用测试

把 `sk-xxx` 换成你 `config.yaml` 里的 `api-keys`：

```bash
curl https://cliproxy.xcwindfall.top/v1/chat/completions \
  -H "Authorization: Bearer sk-xxx" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemini-2.5-pro",
    "messages": [{"role": "user", "content": "hello"}]
  }'
```

如果模型还没登录 OAuth，先做登录。

## 7. OAuth 登录

进入容器：

```bash
docker exec -it cli-proxy-api ./CLIProxyAPI -login
```

如果命令不对，先看容器内文件：

```bash
docker exec -it cli-proxy-api sh
ls -lah
```

登录后的授权数据会保存在：

```text
/opt/projects/cliproxyapi/auths
```

所以更新容器不会丢登录。

## 8. 更新

更新前备份：

```bash
cd /opt/projects/cliproxyapi

BACKUP_DIR=backups/$(date +%F_%H%M)
mkdir -p $BACKUP_DIR
tar czf $BACKUP_DIR/cliproxyapi_all.tar.gz config.yaml auths logs docker-compose.yml
```

更新：

```bash
docker compose pull
docker compose up -d
docker compose logs -f cli-proxy-api
```

## 9. 二创 / 自己改源码部署

如果你 fork 了项目，需要本地 build：

```bash
cd /opt/projects/cliproxyapi
git clone https://github.com/router-for-me/CLIProxyAPI.git src
cd src
```

修改代码后，`docker-compose.yml` 改成：

```yaml
services:
  cli-proxy-api:
    build:
      context: ./src
      dockerfile: Dockerfile
    image: local/cli-proxy-api:dev
    container_name: cli-proxy-api
    restart: unless-stopped
    ports:
      - "127.0.0.1:8317:8317"
      - "127.0.0.1:8085:8085"
      - "127.0.0.1:1455:1455"
      - "127.0.0.1:54545:54545"
      - "127.0.0.1:51121:51121"
      - "127.0.0.1:11451:11451"
    volumes:
      - ./config.yaml:/CLIProxyAPI/config.yaml
      - ./auths:/root/.cli-proxy-api
      - ./logs:/CLIProxyAPI/logs
```

重新构建：

```bash
cd /opt/projects/cliproxyapi
docker compose up -d --build
```

## 10. 常见问题

### config.yaml 变成目录了

这是因为你没提前创建文件，Docker 自动建了目录。

修复：

```bash
cd /opt/projects/cliproxyapi
docker compose down
rm -rf config.yaml
nano config.yaml
docker compose up -d
```

### 8317 被占用

```bash
sudo ss -lntp | grep 8317
```

换端口，比如宿主机用 8318：

```yaml
ports:
  - "127.0.0.1:8318:8317"
```

Caddy 改：

```caddyfile
reverse_proxy 127.0.0.1:8318
```

### OAuth 回调失败

检查：

```bash
docker compose logs -f cli-proxy-api
sudo ss -lntp | grep -E '8085|1455|54545|51121|11451'
```

如果某个 OAuth 必须浏览器访问回调端口，而你绑定了 `127.0.0.1`，就临时把对应端口暴露出来，登录完再改回去。不要长期公网暴露。

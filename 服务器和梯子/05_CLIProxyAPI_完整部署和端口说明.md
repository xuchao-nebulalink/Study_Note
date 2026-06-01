# CLIProxyAPI 完整部署和端口说明

> CLIProxyAPI 用来把 Gemini CLI、Claude Code、Codex、Grok 等 OAuth/CLI 订阅包装成兼容 API。官方 compose 默认镜像为 `eceasy/cli-proxy-api:latest`，默认暴露多个端口。

## 1. 目标效果

```text
访问地址：https://cliproxy.xcwindfall.top
主 API 端口：127.0.0.1:8317
项目目录：/opt/apps/cliproxyapi
配置文件：/opt/apps/cliproxyapi/config.yaml
认证目录：/opt/apps/cliproxyapi/auths
日志目录：/opt/apps/cliproxyapi/logs
```

## 2. 创建目录

```bash
mkdir -p /opt/apps/cliproxyapi
cd /opt/apps/cliproxyapi
mkdir -p auths logs backups
```

## 3. 创建 `.env`

```bash
nano .env
```

写入：

```env
# 镜像
CLI_PROXY_IMAGE=eceasy/cli-proxy-api:latest

# 配置、认证、日志路径
CLI_PROXY_CONFIG_PATH=./config.yaml
CLI_PROXY_AUTH_PATH=./auths
CLI_PROXY_LOG_PATH=./logs

# 如果官方后续支持 DEPLOY 参数，这里保留
DEPLOY=
```

## 4. 创建 `config.yaml`

```bash
nano config.yaml
```

先写一个占位配置：

```yaml
# CLIProxyAPI 配置文件
# 不同版本配置字段可能会变，首次启动后请结合官方文档和容器日志调整。

server:
  host: 0.0.0.0
  port: 8317

log:
  level: info
```

如果启动日志提示配置格式不对，就按当前版本官方文档或生成的示例配置改。

## 5. 创建 `docker-compose.yml`

官方 compose 默认会暴露：

```text
8317
8085
1455
54545
51121
11451
```

你服务器上更安全的写法是全部绑定 `127.0.0.1`。

```bash
nano docker-compose.yml
```

写入：

```yaml
services:
  cli-proxy-api:
    image: ${CLI_PROXY_IMAGE:-eceasy/cli-proxy-api:latest}
    container_name: cli-proxy-api
    restart: unless-stopped
    pull_policy: always
    env_file:
      - .env
    environment:
      DEPLOY: ${DEPLOY:-}
    ports:
      - "127.0.0.1:8317:8317"
      - "127.0.0.1:8085:8085"
      - "127.0.0.1:1455:1455"
      - "127.0.0.1:54545:54545"
      - "127.0.0.1:51121:51121"
      - "127.0.0.1:11451:11451"
    volumes:
      - ${CLI_PROXY_CONFIG_PATH:-./config.yaml}:/CLIProxyAPI/config.yaml
      - ${CLI_PROXY_AUTH_PATH:-./auths}:/root/.cli-proxy-api
      - ${CLI_PROXY_LOG_PATH:-./logs}:/CLIProxyAPI/logs
```

## 6. 启动

```bash
cd /opt/apps/cliproxyapi
docker compose up -d
```

查看状态：

```bash
docker compose ps
```

查看日志：

```bash
docker compose logs -f cli-proxy-api
```

本机测试：

```bash
curl -I http://127.0.0.1:8317
```

## 7. 配置 Caddy

```bash
sudo nano /etc/caddy/Caddyfile
```

添加：

```caddyfile
cliproxy.xcwindfall.top {
    reverse_proxy 127.0.0.1:8317 {
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
https://cliproxy.xcwindfall.top
```

## 8. 这些端口大概怎么理解

CLIProxyAPI 官方 compose 暴露多个端口，不同版本可能对应不同认证回调、管理、代理、兼容协议服务。

你实际使用时先重点关注：

```text
8317：主 API 服务，Caddy 通常反代这个
8085/1455/54545/51121/11451：保留给项目内部不同功能或登录/管理用途
```

不要直接把这些端口暴露公网。绑定 `127.0.0.1` 更安全。

如果后续你发现某个 OAuth 回调必须公网访问，再单独给它配子域名，例如：

```caddyfile
cliproxy-auth.xcwindfall.top {
    reverse_proxy 127.0.0.1:8085
}
```

不要一上来把所有端口都放公网。

## 9. 登录/认证数据在哪里

映射关系：

```text
宿主机：/opt/apps/cliproxyapi/auths
容器内：/root/.cli-proxy-api
```

所以账号登录、OAuth token 之类的数据，大概率在：

```bash
ls -lah /opt/apps/cliproxyapi/auths
```

这个目录非常重要，备份时一定带上。

## 10. 日志在哪里

```bash
ls -lah /opt/apps/cliproxyapi/logs
```

看 Docker 日志：

```bash
cd /opt/apps/cliproxyapi
docker compose logs -f cli-proxy-api
```

## 11. 更新 CLIProxyAPI

更新前备份：

```bash
cd /opt/apps
mkdir -p /opt/apps/cliproxyapi/backups
tar czf cliproxyapi_full_$(date +%Y%m%d_%H%M%S).tar.gz cliproxyapi
```

拉镜像并重启：

```bash
cd /opt/apps/cliproxyapi
docker compose pull
docker compose up -d
```

看日志：

```bash
docker compose logs -f cli-proxy-api
```

## 12. 如果你要用固定版本

不想每次 latest 变化导致不稳定，可以把 `.env` 改成固定 tag：

```env
CLI_PROXY_IMAGE=eceasy/cli-proxy-api:某个版本号
```

然后：

```bash
docker compose pull
docker compose up -d
```

## 13. 如果你要二创/本地构建 CLIProxyAPI

比如你 fork 了项目，要自己改代码构建。

目录：

```bash
cd /opt/apps
 git clone https://github.com/你的用户名/CLIProxyAPI.git cliproxyapi-src
cd cliproxyapi-src
```

compose 改成 build：

```yaml
services:
  cli-proxy-api:
    build:
      context: .
      dockerfile: Dockerfile
    image: local/cli-proxy-api:dev
    container_name: cli-proxy-api
    restart: unless-stopped
    ports:
      - "127.0.0.1:8317:8317"
    volumes:
      - ./config.yaml:/CLIProxyAPI/config.yaml
      - ./auths:/root/.cli-proxy-api
      - ./logs:/CLIProxyAPI/logs
```

构建并启动：

```bash
docker compose up -d --build
```

查看日志：

```bash
docker compose logs -f
```

## 14. 常见问题

### 14.1 容器启动后立刻退出

```bash
cd /opt/apps/cliproxyapi
docker compose logs --tail=200 cli-proxy-api
```

重点看：

```text
config.yaml 格式是否错误
挂载路径是否存在
镜像是否拉取失败
端口是否冲突
```

### 14.2 8317 被占用

```bash
sudo ss -lntp | grep :8317
```

如果被占用，把 compose 改成：

```yaml
ports:
  - "127.0.0.1:18317:8317"
```

Caddy 改成：

```caddyfile
cliproxy.xcwindfall.top {
    reverse_proxy 127.0.0.1:18317
}
```

重启：

```bash
docker compose up -d
sudo systemctl reload caddy
```

### 14.3 镜像拉不下来

```bash
docker pull eceasy/cli-proxy-api:latest
```

如果失败，可能是网络问题。你的服务器需要能访问 Docker Hub。

### 14.4 Caddy 502

502 通常是 Caddy 能访问域名，但后端没起来。

查：

```bash
curl -I http://127.0.0.1:8317
cd /opt/apps/cliproxyapi
docker compose ps
docker compose logs -f
```

## 15. 官方参考

- CLIProxyAPI GitHub：`https://github.com/router-for-me/CLIProxyAPI`
- CLIProxyAPI docker-compose：`https://github.com/router-for-me/CLIProxyAPI/blob/main/docker-compose.yml`
- CLIProxyAPI Guides：`https://help.router-for.me/`

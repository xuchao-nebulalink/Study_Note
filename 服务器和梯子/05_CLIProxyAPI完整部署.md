# CLIProxyAPI 完整部署笔记

> 推荐部署方式：**官方 GitHub 仓库 + Docker Compose + 宿主机 Caddy 统一反代**。
>
> CLIProxyAPI 官方 Docker Compose 默认服务名是 `cli-proxy-api`，镜像默认是 `eceasy/cli-proxy-api:latest`，并挂载 `config.yaml`、`auths/`、`logs/`。

## 1. 部署目标

```text
访问地址：https://cliproxyapi.xcwindfall.top
项目目录：/opt/projects/cliproxyapi
主接口端口：127.0.0.1:8317
```

CLIProxyAPI 可能会暴露多个端口，官方 compose 里常见有：

```text
8317
8085
1455
54545
51121
11451
```

你如果只是先部署主服务，重点先反代 `8317`。

## 2. 安装 git

```bash
sudo apt update
sudo apt install -y git
```

## 3. 拉取项目

```bash
sudo mkdir -p /opt/projects
sudo chown -R $USER:$USER /opt/projects
cd /opt/projects
git clone https://github.com/router-for-me/CLIProxyAPI.git cliproxyapi
cd /opt/projects/cliproxyapi
```

## 4. 创建配置文件

```bash
cp config.example.yaml config.yaml
```

后续需要改配置就编辑：

```bash
nano config.yaml
```

## 5. 修改 docker-compose.yml 端口

打开：

```bash
nano docker-compose.yml
```

把官方默认端口暴露改成只绑定本机。

推荐写法：

```yaml
services:
  cli-proxy-api:
    image: ${CLI_PROXY_IMAGE:-eceasy/cli-proxy-api:latest}
    pull_policy: always
    container_name: cli-proxy-api
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
    restart: unless-stopped
```

重点是：

```yaml
127.0.0.1:8317:8317
```

不要直接写：

```yaml
8317:8317
```

否则公网能直接扫到你的服务。

## 6. 启动 CLIProxyAPI

```bash
cd /opt/projects/cliproxyapi
docker compose up -d
```

查看容器：

```bash
docker ps | grep cli-proxy-api
```

查看日志：

```bash
docker compose logs -f
```

本机测试：

```bash
curl -I http://127.0.0.1:8317
```

## 7. 登录账号

官方文档里给的登录命令如下。

### Gemini 登录

```bash
docker compose exec cli-proxy-api /CLIProxyAPI/CLIProxyAPI -no-browser --login
```

### OpenAI / Codex 登录

```bash
docker compose exec cli-proxy-api /CLIProxyAPI/CLIProxyAPI -no-browser --codex-login
```

### Claude 登录

```bash
docker compose exec cli-proxy-api /CLIProxyAPI/CLIProxyAPI -no-browser --claude-login
```

### Antigravity 登录

```bash
docker compose exec cli-proxy-api /CLIProxyAPI/CLIProxyAPI -no-browser --antigravity-login
```

它一般会输出一个登录链接。  
复制链接到浏览器打开，登录完成后回到服务器看提示。

## 8. 配置 Caddy

编辑：

```bash
sudo nano /etc/caddy/Caddyfile
```

追加：

```caddyfile
cliproxyapi.xcwindfall.top {
    reverse_proxy 127.0.0.1:8317
}
```

检查并重载：

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

访问：

```text
https://cliproxyapi.xcwindfall.top
```

## 9. DNS 解析

域名后台添加：

| 主机记录 | 类型 | 值 |
|---|---|---|
| `cliproxyapi` | A | 你的服务器公网 IP |

如果已经做了 `*` 泛解析，可以不用单独加。

## 10. 更新 CLIProxyAPI

```bash
cd /opt/projects/cliproxyapi
git pull
docker compose pull
docker compose up -d
```

## 11. 停止 CLIProxyAPI

```bash
cd /opt/projects/cliproxyapi
docker compose down
```

## 12. 备份 CLIProxyAPI

重点备份：

```text
config.yaml
auths/
logs/ 可选
```

整目录备份：

```bash
cd /opt/projects
sudo tar -czvf cliproxyapi-backup-$(date +%F).tar.gz cliproxyapi
```

## 13. 常见问题

### 8317 端口被占用

查：

```bash
sudo ss -tulpn | grep :8317
```

如果冲突，改成 18317：

```yaml
ports:
  - "127.0.0.1:18317:8317"
```

Caddy 改：

```caddyfile
cliproxyapi.xcwindfall.top {
    reverse_proxy 127.0.0.1:18317
}
```

### 登录失败

查日志：

```bash
cd /opt/projects/cliproxyapi
docker compose logs -f
```

确认 `auths/` 目录存在且可写：

```bash
ls -la auths
```

没有就创建：

```bash
mkdir -p auths logs
```

## 14. 风险提醒

CLIProxyAPI 涉及把 CLI 登录态转成 API 服务。  
只建议用于你自己的账号和测试环境。  
不要共享你的登录态，不要公开暴露管理入口，不要做违规转售。

## 15. 参考

- CLIProxyAPI GitHub：https://github.com/router-for-me/CLIProxyAPI
- CLIProxyAPI Docker Compose 文档：https://help.router-for.me/docker/docker-compose

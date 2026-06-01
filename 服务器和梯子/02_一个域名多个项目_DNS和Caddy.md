# 一个域名多个项目：DNS 和 Caddy 配置

> 你只有一个主域名，比如 `xcwindfall.top`，完全够用。多个项目用多个子域名即可。

## 1. 推荐域名规划

| 项目 | 子域名 | 反代到本机 |
|---|---|---|
| New API | `newapi.xcwindfall.top` | `127.0.0.1:3000` |
| Sub2API | `sub2api.xcwindfall.top` | `127.0.0.1:8080` |
| CLIProxyAPI | `cliproxy.xcwindfall.top` | `127.0.0.1:8317` |
| 其他项目 1 | `app1.xcwindfall.top` | `127.0.0.1:18081` |
| 其他项目 2 | `app2.xcwindfall.top` | `127.0.0.1:18082` |

## 2. DNS 怎么写

去你的域名 DNS 管理页面，添加 A 记录：

```text
类型：A
主机记录：newapi
记录值：你的服务器公网 IP
TTL：默认
```

再加：

```text
类型：A
主机记录：sub2api
记录值：你的服务器公网 IP
```

再加：

```text
类型：A
主机记录：cliproxy
记录值：你的服务器公网 IP
```

如果你想省事，也可以加泛解析：

```text
类型：A
主机记录：*
记录值：你的服务器公网 IP
```

泛解析的意思：以后 `abc.xcwindfall.top`、`test.xcwindfall.top` 都会解析到这台服务器。

## 3. 检查 DNS 是否生效

在你本地电脑或者服务器上执行：

```bash
ping newapi.xcwindfall.top
ping sub2api.xcwindfall.top
ping cliproxy.xcwindfall.top
```

或者：

```bash
nslookup newapi.xcwindfall.top
```

看到服务器公网 IP 就行。

## 4. Caddyfile 统一模板

编辑：

```bash
sudo nano /etc/caddy/Caddyfile
```

写入：

```caddyfile
newapi.xcwindfall.top {
    reverse_proxy 127.0.0.1:3000
}

sub2api.xcwindfall.top {
    reverse_proxy 127.0.0.1:8080
}

cliproxy.xcwindfall.top {
    reverse_proxy 127.0.0.1:8317
}

app1.xcwindfall.top {
    reverse_proxy 127.0.0.1:18081
}
```

保存后检查：

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
```

没报错再重载：

```bash
sudo systemctl reload caddy
```

## 5. 如果项目需要流式输出，Caddy 推荐写法

AI 网关类项目经常有流式响应，建议给 New API、Sub2API、CLIProxyAPI 加上更稳的超时配置。

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

## 6. WebSocket 项目怎么写

Caddy 的 `reverse_proxy` 默认支持 WebSocket，一般不用额外写。

例如：

```caddyfile
wsdemo.xcwindfall.top {
    reverse_proxy 127.0.0.1:18090
}
```

## 7. 一个子域名下挂多个路径，不推荐但可以

例如只有一个域名，想这样：

```text
xcwindfall.top/newapi
xcwindfall.top/sub2api
xcwindfall.top/cliproxy
```

不太推荐，因为很多项目后台、静态资源、API 路径默认都认为自己在根路径 `/`，容易出现静态资源加载失败。

更推荐：

```text
newapi.xcwindfall.top
sub2api.xcwindfall.top
cliproxy.xcwindfall.top
```

如果非要路径转发，大概这样：

```caddyfile
xcwindfall.top {
    handle_path /newapi/* {
        reverse_proxy 127.0.0.1:3000
    }

    handle_path /sub2api/* {
        reverse_proxy 127.0.0.1:8080
    }
}
```

但项目本身可能还需要配置 base path，所以不建议你这么搞。

## 8. Caddy 常用命令

检查配置：

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
```

重载配置：

```bash
sudo systemctl reload caddy
```

重启 Caddy：

```bash
sudo systemctl restart caddy
```

看 Caddy 日志：

```bash
sudo journalctl -u caddy -f
```

看 Caddy 状态：

```bash
sudo systemctl status caddy
```

## 9. 访问不了时先这么查

### 9.1 域名是否解析到服务器

```bash
nslookup newapi.xcwindfall.top
```

### 9.2 Caddy 是否运行

```bash
sudo systemctl status caddy
```

### 9.3 项目本机端口是否能访问

```bash
curl -I http://127.0.0.1:3000
curl -I http://127.0.0.1:8080
curl -I http://127.0.0.1:8317
```

### 9.4 HTTPS 是否能访问

```bash
curl -I https://newapi.xcwindfall.top
```

### 9.5 看 80/443 是否监听

```bash
sudo ss -lntp | grep -E ':80|:443'
```

## 10. Cloudflare 注意点

如果你 DNS 用 Cloudflare：

```text
小黄云开启：走 Cloudflare 代理
小黄云关闭：DNS only，直接到服务器
```

首次部署排查建议先关闭小黄云，等 HTTPS 正常后再开。

SSL/TLS 模式建议：

```text
Full 或 Full(strict)
不要用 Flexible
```

Flexible 容易导致 HTTPS/HTTP 循环跳转问题。

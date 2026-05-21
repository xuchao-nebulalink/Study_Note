# Codex Reconnecting 5 次问题排查笔记

## 问题现象

Codex 新开对话或执行 `/new` 后，经常先出现：

```text
Reconnecting... 1/5
Reconnecting... 2/5
Reconnecting... 3/5
Reconnecting... 4/5
Reconnecting... 5/5
```

然后才开始正常回答。

## 核心原因

大概率是 **WebSocket 连接不稳定**。

Codex 默认可能优先走 WebSocket。  
如果代理、网络、节点对 WebSocket 支持不好，就会反复重连。  
重连失败后，才会回退到 HTTPS，所以会感觉每次都卡一会儿。

## 解决思路

直接让 Codex 不走 WebSocket，改成 HTTPS 方式。

编辑配置文件：

```bash
~/.codex/config.toml
```

Windows 通常在：

```text
C:\Users\你的用户名\.codex\config.toml
```

## 推荐配置

在 `config.toml` 里添加：

```toml
model_provider = "openai_https"

[model_providers.openai_https]
name = "OpenAI"
wire_api = "responses"
requires_openai_auth = true
supports_websockets = false
```

## 注意事项

1. 引号必须是英文半角引号 `" "`，不要用中文引号。
2. `model_provider` 的名字要和 `[model_providers.openai_https]` 保持一致。
3. 改完配置后，要完整重启 Codex。
4. 改 provider 后，历史记录可能看起来不一样，一般不是丢了，而是跟 provider 分组有关。

## 回滚方法

把这段删掉或注释掉：

```toml
[model_providers.openai_https]
name = "OpenAI"
wire_api = "responses"
requires_openai_auth = true
supports_websockets = false
```

然后把：

```toml
model_provider = "openai_https"
```

改回原来的 provider，例如：

```toml
model_provider = "openai"
```

最后重启 Codex。

## 我的建议

如果你的环境是：

- Windows / WSL
- Clash / 代理
- Codex 经常先 Reconnecting 5 次
- 之后又能正常回答

那可以优先试这个方案。

## 一句话总结

**Codex 每次 Reconnecting 5 次，大概率是 WebSocket 链路不稳定。可以通过配置 `supports_websockets = false`，让它直接走 HTTPS。**

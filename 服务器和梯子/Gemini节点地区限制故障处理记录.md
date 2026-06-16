# Gemini 节点地区限制故障处理记录

## 基本信息

- 处理日期：2026-06-15
- VPS：美国服务器
- VPS IP：`70.39.179.224`
- 系统：Ubuntu 22.04.5 LTS
- 面板：3x-ui 2.9.4
- Xray：26.4.25
- 客户端：Clash Verge

## 故障现象

使用自己的 VPS 节点打开 Gemini 时，页面提示：

> Gemini 目前不支持你所在的地区。

Google 账号和 Gemini Pro 会员本身没有问题。切换到其他机场节点后可以正常使用。

## 故障原因

问题出在 VPS 的原始出口 IP `70.39.179.224`。

检查结果如下：

- 客户端实际出口确实是 `70.39.179.224`。
- Gemini、Google 登录和 Google 主站流量均经过该 VPS。
- 没有 IPv6 出口，因此不是 IPv6 绕过代理。
- 3x-ui、Xray、DNS和防火墙工作正常。
- Xray 没有配置错误的 Google 分流。
- Cloudflare 将该 IP 识别为美国洛杉矶。
- 不同 IP 数据库却分别将该 IP 定位到加州、密歇根和马萨诸塞州。
- 登录状态下的 Gemini 将该 IP 判定为不支持地区。

因此，可以判断为 Google 对该 IP 或所在网段的地区识别、机房识别或风控结果异常。

这不是 Gemini 账号问题，也不是简单更换 Xray 协议、端口或重装 3x-ui 能解决的问题。

## 处理方案

没有更换 VPS IP，而是在服务器上增加 Cloudflare WARP 出口。

只让 Google 和 Gemini 相关流量经过 WARP，其他网站仍使用 VPS 原始出口。

当前流量路径：

```text
普通网站
客户端 -> 3x-ui/Xray -> 70.39.179.224 -> 目标网站

Google/Gemini
客户端 -> 3x-ui/Xray -> 本机 WARP SOCKS -> WARP 美国出口 -> Google
```

## 实际修改内容

### 1. 安装 Cloudflare WARP

安装的是 Cloudflare 官方软件包：

```text
cloudflare-warp 2026.4.1390.0
```

服务名称：

```text
warp-svc
```

该服务已设置为开机启动。

### 2. 使用本地代理模式

WARP 没有接管服务器默认路由，而是使用本机 SOCKS 代理模式：

```text
127.0.0.1:40000
```

这个端口只监听本机，外部无法直接访问。

配置完成时，WARP 测试出口为：

```text
104.28.195.187
```

WARP 出口 IP 以后可能自动变化，这是正常情况。

### 3. 增加 Xray 出站

新增 Xray 出站标签：

```text
warp-google
```

该出站连接到：

```text
127.0.0.1:40000
```

### 4. 增加 Google 域名分流

以下域名后缀通过 `warp-google` 出站：

```text
google.com
googleapis.com
gstatic.com
googleusercontent.com
ggpht.com
```

其中包含：

```text
gemini.google.com
accounts.google.com
```

其他网站不经过 WARP。

### 5. 持久化到 3x-ui

配置写入 3x-ui 数据库中的：

```text
xrayTemplateConfig
```

不能只修改 `/usr/local/x-ui/bin/config.json`，因为 3x-ui 重启时会重新生成该文件。

模板只保留 3x-ui 的 `api` 基础入站。实际节点入站由 3x-ui 从数据库自动添加，避免出现重复入站。

## 完整操作步骤

以下命令是在本次服务器环境中实际使用的做法。执行前应确认路径和版本与本文一致。

### 第一步：登录服务器

```bash
ssh root@70.39.179.224
```

不要把 SSH 密码写进脚本或命令历史。

### 第二步：备份 3x-ui

```bash
stamp=$(date +%Y%m%d-%H%M%S)
export stamp

mkdir -p /root/xui-backups
chmod 700 /root/xui-backups

python3 - <<'PY'
import os
import sqlite3

source_path = "/etc/x-ui/x-ui.db"
backup_path = (
    f"/root/xui-backups/x-ui.db.{os.environ['stamp']}"
)

source = sqlite3.connect(
    f"file:{source_path}?mode=ro",
    uri=True
)
backup = sqlite3.connect(backup_path)

try:
    source.backup(backup)
finally:
    backup.close()
    source.close()

print(backup_path)
PY

cp -a /usr/local/x-ui/bin/config.json \
  "/root/xui-backups/config.json.$stamp"

chmod 600 \
  "/root/xui-backups/x-ui.db.$stamp" \
  "/root/xui-backups/config.json.$stamp"
```

确认备份存在：

```bash
ls -lh /root/xui-backups/
```

### 第三步：安装 Cloudflare WARP

先安装添加软件源需要的基础工具：

```bash
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  ca-certificates curl gnupg lsb-release
```

导入 Cloudflare 软件源密钥：

```bash
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg \
  | gpg --yes --dearmor \
  --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
```

添加 Ubuntu 22.04 软件源：

```bash
echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] \
https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" \
> /etc/apt/sources.list.d/cloudflare-client.list
```

安装：

```bash
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y cloudflare-warp
```

确认服务正常：

```bash
systemctl enable --now warp-svc
systemctl is-active warp-svc
warp-cli --version
```

### 第四步：将 WARP 设置为本机 SOCKS 代理

注册设备：

```bash
warp-cli --accept-tos registration new
```

如果提示设备已经注册，检查现有注册即可：

```bash
warp-cli --accept-tos registration show
```

设置为代理模式，监听本机 `40000` 端口：

```bash
warp-cli --accept-tos mode proxy
warp-cli --accept-tos proxy port 40000
warp-cli --accept-tos connect
```

检查状态：

```bash
warp-cli --accept-tos status
ss -lntp | grep ':40000 '
```

正确状态应包含：

```text
Connected
Network: healthy
127.0.0.1:40000
```

比较原始出口和 WARP 出口：

```bash
echo "原始出口："
curl -4 https://api.ipify.org
echo

echo "WARP 出口："
curl -4 --socks5-hostname 127.0.0.1:40000 \
  https://api.ipify.org
echo
```

两个 IP 应该不同。本次测试时分别是：

```text
原始出口：70.39.179.224
WARP 出口：104.28.195.187
```

### 第五步：写入 3x-ui 持久化模板

3x-ui 会在启动时根据数据库重新生成：

```text
/usr/local/x-ui/bin/config.json
```

因此不能只编辑这个文件。需要修改数据库中的 `xrayTemplateConfig`。

执行下面的脚本：

```bash
python3 - <<'PY'
import json

config_path = "/usr/local/x-ui/bin/config.json"
output_path = "/tmp/xray-template-warp.json"

with open(config_path, encoding="utf-8") as file:
    config = json.load(file)

# 模板中只保留 3x-ui 自带的 API 入站。
# 节点入站会由 3x-ui 从数据库自动追加。
config["inbounds"] = [
    inbound
    for inbound in config.get("inbounds", [])
    if inbound.get("tag") == "api"
]

# 避免重复添加 WARP 出站。
outbounds = config.setdefault("outbounds", [])
outbounds[:] = [
    outbound
    for outbound in outbounds
    if outbound.get("tag") != "warp-google"
]

outbounds.append({
    "tag": "warp-google",
    "protocol": "socks",
    "settings": {
        "servers": [{
            "address": "127.0.0.1",
            "port": 40000
        }]
    }
})

routing = config.setdefault("routing", {})
rules = routing.setdefault("rules", [])

# 避免重复添加规则。
rules[:] = [
    rule
    for rule in rules
    if rule.get("outboundTag") != "warp-google"
]

google_rule = {
    "type": "field",
    "domain": [
        "domain:google.com",
        "domain:googleapis.com",
        "domain:gstatic.com",
        "domain:googleusercontent.com",
        "domain:ggpht.com"
    ],
    "network": "tcp",
    "outboundTag": "warp-google"
}

# 放在 API 规则之后、拦截规则之前。
insert_at = 1 if (
    rules
    and rules[0].get("inboundTag") == ["api"]
) else 0

rules.insert(insert_at, google_rule)

raw_config = json.dumps(
    config,
    ensure_ascii=False,
    indent=2
)

# 写入前确认 JSON 可以解析。
json.loads(raw_config)

with open(output_path, "w", encoding="utf-8") as file:
    file.write(raw_config)
    file.write("\n")

print(output_path)
PY
```

先用 Xray 检查模板，检查失败时不要写入数据库：

```bash
/usr/local/x-ui/bin/xray-linux-amd64 run -test \
  -config /tmp/xray-template-warp.json
```

必须看到：

```text
Configuration OK.
```

确认通过后，再写入数据库：

```bash
python3 - <<'PY'
import json
import sqlite3

db_path = "/etc/x-ui/x-ui.db"
template_path = "/tmp/xray-template-warp.json"

with open(template_path, encoding="utf-8") as file:
    raw_config = file.read()

# 数据库写入前再次检查文件完整性。
json.loads(raw_config)

connection = sqlite3.connect(db_path)

try:
    connection.execute("BEGIN IMMEDIATE")

    rows = connection.execute(
        """
        SELECT id
        FROM settings
        WHERE key = 'xrayTemplateConfig'
        ORDER BY id
        """
    ).fetchall()

    if rows:
        connection.execute(
            "UPDATE settings SET value = ? WHERE id = ?",
            (raw_config, rows[0][0])
        )

        # key 没有唯一索引，清理可能存在的重复记录。
        for duplicate in rows[1:]:
            connection.execute(
                "DELETE FROM settings WHERE id = ?",
                (duplicate[0],)
            )
    else:
        connection.execute(
            """
            INSERT INTO settings(key, value)
            VALUES('xrayTemplateConfig', ?)
            """,
            (raw_config,)
        )

    connection.commit()
finally:
    connection.close()

print("xrayTemplateConfig 已写入")
PY

rm -f /tmp/xray-template-warp.json
```

### 第六步：重启 3x-ui

```bash
systemctl restart x-ui
```

等待两秒后检查：

```bash
sleep 2
systemctl is-active x-ui
pgrep -a -f 'bin/xray-linux-amd64 -c bin/config.json'
```

检查节点端口：

```bash
ss -lntp | grep -E '(:443 |:39725 |:46496 |:40000 )'
```

本次服务器应看到：

```text
443       Xray 主节点
39725     其他 Xray 入站
46496     其他 Xray 入站
40000     WARP 本机 SOCKS
```

### 第七步：检查最终生成的配置

检查 Xray 配置语法：

```bash
/usr/local/x-ui/bin/xray-linux-amd64 run -test \
  -config /usr/local/x-ui/bin/config.json
```

正确结果：

```text
Configuration OK.
```

检查 WARP 出站和规则是否存在：

```bash
python3 - <<'PY'
import json

path = "/usr/local/x-ui/bin/config.json"

with open(path, encoding="utf-8") as file:
    config = json.load(file)

print("入站：")
for inbound in config.get("inbounds", []):
    print(inbound.get("tag"), inbound.get("port"))

print("\nWARP 出站：")
for outbound in config.get("outbounds", []):
    if outbound.get("tag") == "warp-google":
        print(json.dumps(outbound, indent=2))

print("\nGoogle 分流规则：")
for rule in config.get("routing", {}).get("rules", []):
    if rule.get("outboundTag") == "warp-google":
        print(json.dumps(rule, indent=2))
PY
```

### 第八步：检查主节点的域名嗅探

按域名分流要求主节点启用 TLS/HTTP 嗅探。

检查：

```bash
python3 - <<'PY'
import json

config = json.load(
    open("/usr/local/x-ui/bin/config.json", encoding="utf-8")
)

for inbound in config.get("inbounds", []):
    if inbound.get("tag") == "inbound-443":
        print(json.dumps(
            inbound.get("sniffing"),
            ensure_ascii=False,
            indent=2
        ))
PY
```

本次主节点的正确配置是：

```json
{
  "enabled": true,
  "destOverride": [
    "http",
    "tls"
  ],
  "metadataOnly": false,
  "routeOnly": false
}
```

如果这里是 `enabled: false`，需要在 3x-ui 对应入站中开启嗅探，否则 Google 域名规则可能无法命中。

### 第九步：最终检查

```bash
systemctl is-active x-ui
systemctl is-active warp-svc
warp-cli --accept-tos status

curl -4 https://api.ipify.org
curl -4 --socks5-hostname 127.0.0.1:40000 \
  https://api.ipify.org

ss -lntp | grep -E '(:443 |:40000 )'
```

客户端切回自己的 VPS 节点，然后使用无痕窗口访问：

```text
https://gemini.google.com/app
```

如果仍显示旧页面，清除 `gemini.google.com` 的网站数据后重新登录。

## 本次操作中遇到的问题

### 直接修改 config.json 无法持久化

直接修改：

```text
/usr/local/x-ui/bin/config.json
```

重启 3x-ui 后，文件会被数据库配置重新生成，手工修改会消失。

正确做法是修改数据库中的：

```text
xrayTemplateConfig
```

### 模板不能包含业务入站

第一次写入模板时保留了以下业务入站：

```text
inbound-443
inbound-39725
inbound-46496
```

3x-ui 启动时又从数据库追加了一遍，导致 Xray 报错：

```text
existing tag found: inbound-443
```

因此模板中的 `inbounds` 只能保留：

```text
api
```

修正后，3x-ui 会自动追加实际节点入站，Xray 即可正常启动。

## 验证结果

处理后验证结果：

- `x-ui` 服务正常运行。
- `warp-svc` 服务正常运行。
- Xray 进程正常运行。
- 端口 `443`、`39725`、`46496` 正常监听。
- 面板端口 `39127` 正常监听。
- WARP 本地端口 `40000` 正常监听。
- 普通流量出口仍是 `70.39.179.224`。
- 命中 WARP 规则的流量出口变为 `104.28.195.187`。
- Gemini 请求可以通过 WARP 出站完成。
- 服务器外部访问 `443` 端口正常。
- 重启 3x-ui 后配置仍然有效。
- 实际登录 Gemini 已恢复正常。

注意：Gemini 的地区限制页面本身也可能返回 HTTP 200，因此不能只根据状态码判断是否修复，必须以实际登录后的页面为准。

## 备份位置

修改前的数据库和配置备份位于：

```text
/root/xui-backups/
```

里面包含多份带时间戳的：

```text
x-ui.db.*
config.json.*
```

## 常用检查命令

检查服务：

```bash
systemctl status x-ui --no-pager
systemctl status warp-svc --no-pager
warp-cli --accept-tos status
```

检查端口：

```bash
ss -lntp | grep -E '(:443 |:39725 |:46496 |:40000 )'
```

检查原始出口：

```bash
curl -4 https://api.ipify.org
```

检查 WARP 出口：

```bash
curl -4 --socks5-hostname 127.0.0.1:40000 https://api.ipify.org
```

检查 Xray 配置：

```bash
/usr/local/x-ui/bin/xray-linux-amd64 run -test \
  -config /usr/local/x-ui/bin/config.json
```

## 回滚方法

需要取消本次分流配置时，优先恢复修改前的 3x-ui 数据库备份。

先查看备份：

```bash
ls -lht /root/xui-backups/x-ui.db.*
```

选择正确的修改前备份，把下面变量改成真实文件名：

```bash
backup="/root/xui-backups/x-ui.db.20260615-101813"

test -f "$backup" || {
  echo "备份文件不存在"
  exit 1
}

systemctl stop x-ui

cp -a "$backup" /etc/x-ui/x-ui.db
chown root:root /etc/x-ui/x-ui.db
chmod 600 /etc/x-ui/x-ui.db

systemctl start x-ui
```

确认旧配置恢复：

```bash
systemctl is-active x-ui
pgrep -a -f 'bin/xray-linux-amd64 -c bin/config.json'
ss -lntp | grep ':443 '
```

确认节点恢复后，再停止并禁用 WARP：

```bash
warp-cli --accept-tos disconnect
systemctl disable --now warp-svc
```

确认 WARP 已停用：

```bash
systemctl is-active warp-svc
ss -lntp | grep ':40000 ' || true
```

不要在未确认备份文件时间的情况下直接覆盖数据库。

## 后续注意事项

1. 最彻底的处理方式仍是向 VPS 商家申请更换 IP，最好更换不同网段或不同 ASN 的 IP。
2. WARP 免费出口以后也可能被 Google 风控。如果再次出现地区限制，应先检查 WARP 当前出口。
3. 不要在 3x-ui 启动后直接修改生成的 `config.json`，修改会在下次重启时丢失。
4. 本次安装 WARP 时同时安装了部分图形和网络依赖，但服务器剩余磁盘空间充足。
5. 服务器提示存在待生效的 Linux 内核更新。本次没有重启 VPS，避免影响节点。
6. root 密码曾发送到聊天中，应尽快修改，并改用 SSH 密钥登录。
7. 如果 `warp-svc` 停止，普通网站仍使用原始出口，但命中 `warp-google` 规则的 Google 和 Gemini 流量会连接失败。此时先检查 `warp-cli --accept-tos status` 和本机 `40000` 端口。

修改 root 密码：

```bash
passwd
```

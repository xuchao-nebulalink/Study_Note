# OpenClaw 接入飞书 完整配置笔记

> 本笔记涵盖飞书开放平台侧配置 + OpenClaw 侧配置的完整流程。

---

## ⚡ 正确的配置顺序（重要）

> [!warning] 飞书事件订阅必须在 OpenClaw 配置完成后再配置，否则长连接会保存失败或不生效。

```
1. 飞书：创建应用 → 加机器人 → 拿凭证 → 开权限
2. OpenClaw：装插件(旧版) → channels add → 重启网关
3. 飞书：配置事件订阅(长连接) → 发布应用
4. 验证：私聊 → pairing approve → 跑通收发消息
```

---

## 一、前置条件

- OpenClaw 实例已部署并正常运行（云服务器 / 本地 / Docker 均可）
- 拥有飞书管理员账号（需要有创建企业自建应用的权限）

---

## 二、飞书开放平台配置（第一阶段）

### 2.1 创建企业自建应用

1. 打开 [飞书开放平台](https://open.feishu.cn)，登录飞书账号
2. 点击 **「创建企业自建应用」**
3. 填写信息：
   - **应用名称**：自定义，如 `OpenClaw 助手`
   - **应用描述**：简单描述用途即可
   - **应用图标**：上传一个图标（可选）
4. 点击 **「创建」**
![[Pasted image 20260310174057.png]]
### 2.2 添加机器人能力

1. 进入刚创建的应用管理页面
2. 左侧导航栏 → **「添加应用能力」**
3. 找到 **「机器人」**，点击 **「添加」**
![[Pasted image 20260310174141.png]]
### 2.3 获取应用凭证

1. 左侧导航栏 → **「凭证与基础信息」**
2. 复制并保存以下两个值（后面 OpenClaw 配置要用）：
   - **App ID**
   - **App Secret**

> [!warning] ⚠️ App Secret 是敏感信息，不要泄露！

![[Pasted image 20260310174212.png]]
### 2.4 配置权限

1. 左侧导航栏 → **「权限管理」**
2. 推荐方式：点击 **「批量开通」**，粘贴权限 JSON 配置
3. 需要开通的核心权限（全部为 `im` 即时通讯类权限）：

| 权限名称 | 说明 |
|---------|------|
| `im:message` | 消息的读取与发送 |
| `im:message:send_as_bot` | 以机器人身份发送消息 |
| `im:chat` | 群组信息读取 |
| `im:chat:member` | 群成员管理 |
| `im:resource` | 消息中的资源文件 |

4. 点击 **「确认并申请开通」**
![[Pasted image 20260310174235.png]]

> [!important] ⏸️ 权限配好后先不要配事件订阅，先去第三章配 OpenClaw，配完再回来。

---

## 三、OpenClaw 侧配置

### 3.1 安装飞书插件（按版本判断）

- **v2026.2.12 及更高版本**：已原生支持飞书，**无需安装插件**，跳过此步
- **旧版本**：需手动安装插件

```bash
openclaw plugins install @openclaw/feishu
```

### 3.2 添加飞书通道

运行以下命令进入交互式配置：

```bash
openclaw channels add
```

交互式提示中依次选择/输入：

| 配置项            | 选择/输入               | 说明                      |
| -------------- | ------------------- | ----------------------- |
| 通道类型           | `Feishu/Lark (飞书)`  | 选择飞书                    |
| App ID         | 粘贴飞书凭证页的 App ID     | 第 2.3 步获取的              |
| App Secret     | 粘贴飞书凭证页的 App Secret | 第 2.3 步获取的              |
| connectionMode | `websocket`         | ✅ 推荐 WebSocket，与飞书长连接对应 |
| dmPolicy       | `pairing`           | 私聊策略：配对模式（默认值）          |
| groupPolicy    | `disabled`          | 群聊策略：**第一次建议选 disabled** |
| requireMention | `true`              | 群聊中需要 @机器人 才触发回复        |

> [!tip] **第一次接入建议 groupPolicy 选 `disabled`**，先把私聊 + pairing + 收发消息跑通，不要一开始就加太多变量。其他选项保持默认即可。

### 3.3 重启网关

配置完成后，**必须重启**才能生效：

```bash
openclaw gateway restart
```

---

## 四、飞书开放平台配置（第二阶段）

> [!important] 必须在 OpenClaw channels add 配置完成 **且网关已启动** 后，再来配置事件订阅。

### 4.1 配置事件订阅

1. 回到飞书开放平台 → 你的应用管理页面
2. 左侧导航栏 → **「事件与回调」** → **「事件配置」**
3. **请求方式选择**：选择 **「使用长连接接收事件」**（WebSocket 模式）
   - ✅ 推荐长连接模式，更稳定，无需公网域名
   - ❌ 不推荐传统 Webhook URL 模式
4. 点击 **「添加事件」**，搜索并添加：
   - `im.message.receive_v1`（接收消息事件 —— **必须添加**）
![[Pasted image 20260310174310.png]]

### 4.2 发布应用

1. 左侧导航栏 → **「版本管理与发布」**
2. 点击 **「创建版本」**
3. 填写版本号和更新说明
4. 点击 **「提交发布」**
5. 等待发布完成（通常几秒到几分钟）

---

## 五、验证 & Pairing 配对流程

### 5.1 查看日志确认连接

```bash
openclaw logs --follow
```

看到以下关键字说明连接成功：

```
feishu ws connected
feishu provider ready
```

### 5.2 Pairing 配对（私聊首次使用必走）

默认私聊策略是 `pairing`，流程如下：

1. 在飞书中找到你的机器人，**私聊发一条消息**
2. 机器人会回复一个 **配对码**（Pairing Code），类似 `ABC12345`
3. 在 OpenClaw 终端中执行审批命令：

```bash
openclaw pairing approve feishu <配对码>
```

例如：

```bash
openclaw pairing approve feishu ABC12345
```

4. 审批通过后，这个人才能正式和机器人聊天

**查看所有待审批的配对请求：**

```bash
openclaw pairing list feishu
```

> [!warning] **常见误区**：同一个配对码 approve 两次会报 `No pending pairing request found for code`，这不是失败！是因为第一次已经成功消费掉了这个码。

### 5.3 飞书端测试

1. **私聊测试**：完成 pairing 后，发消息给机器人，确认正常回复
2. **群聊测试**（如果 groupPolicy 不是 disabled）：把机器人拉入群聊 → @机器人 发消息 → 看是否回复

> ✅ 如果机器人正常回复，接入成功！

---

## 六、Group Policy 群聊策略详解

### 三个选项对比

| 策略 | 行为 | 适用场景 |
|------|------|---------|
| `disabled` | 不响应任何群消息 | 第一次接入，先跑通私聊 |
| `allowlist` | 只响应指定群（需配置白名单） | 私聊跑通后，逐步开放 |
| `open` | 所有群都可用（通常需要 @机器人） | 最终全面开放 |

### 推荐开放顺序

```
第一次接入 → disabled（专注跑通私聊 + pairing）
    ↓
私聊跑通后 → allowlist（指定群聊测试）
    ↓
确认稳定后 → open（全面开放）
```

### 如何获取群的 chat_id

切换到 `allowlist` 需要知道群的 `chat_id`，获取方法：

1. 先把机器人拉进目标群
2. 在群里 @机器人 发一条消息
3. 查看 OpenClaw 日志：

```bash
openclaw logs --follow
```

4. 在日志中找 `chat_id` 字段，格式类似：`oc_xxx`

### 如何修改 groupPolicy

修改通道配置，将 `groupPolicy` 改为新的策略：

```bash
openclaw channels update feishu --groupPolicy allowlist
```

修改后重启网关生效：

```bash
openclaw gateway restart
```

---

## 七、常见问题

| 问题 | 解决方案 |
|------|---------|
| 机器人发不出消息 | 检查权限是否全部开通，尤其是 `im:message:send_as_bot` |
| 飞书收不到消息 | 确认事件订阅已添加 `im.message.receive_v1`，且选的是长连接模式 |
| 长连接配置保存失败或不生效 | 必须先完成 OpenClaw channels add + 启动网关，再去飞书配事件 |
| OpenClaw 日志无连接信息 | 检查 App ID / App Secret 是否正确，确认已重启网关 |
| 私聊没反应 | 检查是否完成了 pairing approve |
| approve 报 `No pending pairing request` | 不是失败，是这个码已经被第一次 approve 消费掉了 |
| 群聊不回复 | 检查 groupPolicy 是否为 disabled；如果是 allowlist 检查是否添加了群 chat_id |
| 应用未发布 | 飞书应用必须发布后才能正常使用 |

---

> 📝 最后更新：2026-03-10

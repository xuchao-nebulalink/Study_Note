# OpenClaw 飞书官方插件迁移踩坑日记

## 日期
2026-03-12

## 主题
从 OpenClaw 内置飞书插件切换到飞书官方插件后，`/feishu start` 虽然能启动，但飞书文档/表格工具一直加载异常的问题排查记录。

---

## 一、问题现象
这次迁移的目标，是把 **OpenClaw 内置飞书插件** 切换成 **飞书官方插件**，以便在飞书里完成：

- 创建飞书文档
- 创建多维表格 / 表格
- 编辑文档内容
- 用本人账号权限操作飞书数据

前期排查时，遇到过两类问题：

### 1. 旧插件冲突
在飞书里执行：

```text
/feishu start
```

提示类似：

- 检测到旧版插件未禁用
- 需要先关闭旧版 `feishu` 插件

这个问题后来已经处理掉了。

### 2. 官方插件能启动，但工具还是不正常
后面再次执行：

```text
/feishu start
```

返回大致为：

- 飞书 OpenClaw 插件已启动
- 但带有警告：`工具 Profile 当前为 coding，飞书工具可能无法加载`

这说明：

- 飞书官方插件本身已经启动成功
- 旧插件冲突基本已经解决
- 但飞书相关工具没有完整加载出来

也就是说，问题已经不在插件安装，而在 **工具配置**。

---

## 二、根因定位
最终检查 `~/.openclaw/openclaw.json` 后，定位到真正的问题是：

```json
"tools": {
  "profile": "coding",
  "web": {
    "search": {
      "provider": "perplexity"
    }
  }
}
```

这里的：

```json
"profile": "coding"
```

就是根因。

### 原因解释
`tools.profile = coding` 的含义，是让 OpenClaw 使用偏“代码开发”的工具集。

这种模式通常更偏向：

- 终端/命令类工具
- 文件操作类工具
- 编码开发相关工具

但当前需求不是纯 coding，而是要让 **飞书官方插件加载文档、表格、多维表格、消息等飞书工具**。

因此当 profile 被限制成 `coding` 时，就会出现：

- 插件能启动
- 但插件的部分工具加载不全
- 飞书里提示 `工具 Profile 当前为 coding`
- 机器人可能能聊天，但创建文档/表格能力异常

---

## 三、最终解决办法
### 解决方式
**直接删除 `tools.profile` 即可。**

把原来的：

```json
"tools": {
  "profile": "coding",
  "web": {
    "search": {
      "provider": "perplexity"
    }
  }
}
```

改成：

```json
"tools": {
  "web": {
    "search": {
      "provider": "perplexity"
    }
  }
}
```

### 结论
这次的核心坑不是：

- 飞书 appId / appSecret 错了
- 官方插件没装好
- gateway 没启动
- 旧插件没删干净

而是：

> **官方插件已经启动成功，但因为 `tools.profile` 被设成了 `coding`，导致飞书工具集没有完整加载。**

---

## 四、标准检查步骤
下面整理一份以后再遇到类似问题时可直接复用的检查流程。

### 第 1 步：确认官方插件是否启动
在飞书里执行：

```text
/feishu start
```

#### 预期结果
- 能看到插件版本号
- 不再提示旧插件未禁用

#### 如果提示旧插件未禁用
说明还在插件冲突阶段，需要先处理旧插件。

---

### 第 2 步：确认旧内置 Feishu 插件是否关闭
检查配置文件：

```json
"plugins": {
  "entries": {
    "feishu": {
      "enabled": false
    },
    "feishu-openclaw-plugin": {
      "enabled": true
    }
  }
}
```

#### 预期结果
- `feishu.enabled = false`
- `feishu-openclaw-plugin.enabled = true`

如果不是这样，说明还没有完成从内置插件切换到官方插件。

---

### 第 3 步：检查是否仍有旧插件残留目录
在 WSL 中检查：

```bash
ls -la ~/.openclaw/extensions
```

如果有旧的 `feishu` 目录残留，可以删除：

```bash
rm -rf ~/.openclaw/extensions/feishu
```

然后重启：

```bash
openclaw gateway restart
```

---

### 第 4 步：检查 `tools.profile`
打开配置文件：

```bash
nano ~/.openclaw/openclaw.json
```

重点检查是否有：

```json
"tools": {
  "profile": "coding"
}
```

#### 如果存在
这是本次问题的关键坑点。

处理方式：

- 直接删除 `"profile": "coding"`
- 保留其他工具配置

---

### 第 5 步：重启网关
修改完配置后执行：

```bash
openclaw gateway restart
```

再检查状态：

```bash
openclaw gateway status
```

#### 预期结果
- gateway 正常 running
- RPC probe ok

---

### 第 6 步：回飞书再次验证
再次执行：

```text
/feishu start
```

#### 预期结果
- 插件正常启动
- 不再提示：`工具 Profile 当前为 coding`

这一步如果通过，说明 profile 问题已经解决。

---

### 第 7 步：验证飞书能力是否真的恢复
先让机器人学习插件能力：

```text
学习一下我安装的新飞书插件，列出你现在有哪些飞书能力
```

再进行真实测试：

```text
帮我创建一篇飞书文档，标题叫《OpenClaw插件测试文档》
```

以及：

```text
帮我创建一个多维表格，名称叫《OpenClaw插件测试表》，包含字段：任务名、状态、优先级
```

#### 预期结果
- 能创建文档
- 能创建多维表格
- 工具不再报缺失或无法加载

---

## 五、完整排查顺序（建议固定这么排）
以后如果再遇到飞书插件异常，建议按下面顺序查：

1. 先看 `/feishu start` 是否能启动
2. 再看是不是旧插件冲突
3. 再看官方插件是否已启用
4. 再看 `~/.openclaw/extensions` 是否有旧残留
5. 再看 `tools.profile` 是否被设成 `coding`
6. 修改后重启 `openclaw gateway`
7. 再测文档/表格创建

这样排查效率最高，不容易绕弯路。

---

## 六、本次经验总结
这次最容易误判的地方，是会下意识以为：

- 飞书权限没配好
- appSecret 有问题
- 官方插件版本不对
- 飞书 OAuth 没成功

但实际并不是这些。

真正的坑是：

> **插件已经启动成功，但 OpenClaw 的工具 Profile 被设置成了 `coding`，导致飞书工具集不能完整加载。**

### 以后记住一句话
如果飞书官方插件已经启动，但飞书里提示：

> `工具 Profile 当前为 coding，飞书工具可能无法加载`

那优先检查：

```json
"tools": {
  "profile": "coding"
}
```

**直接删掉这一行，往往就是正确解法。**

---

## 七、附：本次关键操作命令
### 查看配置文件
```bash
cat ~/.openclaw/openclaw.json
```

### 编辑配置文件
```bash
nano ~/.openclaw/openclaw.json
```

### 删除旧 Feishu 插件残留
```bash
rm -rf ~/.openclaw/extensions/feishu
```

### 重启网关
```bash
openclaw gateway restart
```

### 查看网关状态
```bash
openclaw gateway status
```

### 飞书侧验证
```text
/feishu start
```

---

## 八、最终结论
本次问题最终确认：

- **不是** 飞书官方插件安装失败
- **不是** 旧插件没有完全迁移
- **不是** gateway 启动异常
- **而是** `tools.profile = coding` 造成飞书工具加载异常

最终修复方式：

> **删除 `tools.profile` 中的 `coding` 配置，然后重启 gateway。**

修复后，飞书官方插件即可正常加载对应工具，后续再测试文档和表格创建功能即可。


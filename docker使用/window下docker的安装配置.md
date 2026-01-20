
---

# Windows 本地开发环境搭建 (Docker版)

**核心逻辑**：
*   **代码运行**：直接在 Windows (D盘) 运行
*   **数据库运行**：在 WSL2 (Docker) 中运行。
*   **连接方式**：通过 `localhost` 端口映射连接。

---

## 1. 基础环境安装

### 第一步：安装 WSL 2
1.  **开启**：右键开始菜单 -> **终端(管理员)**，执行：
    ```powershell
    wsl --install
    ```
    *(若提示已安装，执行 `wsl --update`)*
2.  **重启**：重启电脑，等待 Ubuntu 终端弹出，按提示设置用户名/密码。

### 第二步：安装 Docker Desktop
1.  **下载**：官网下载 [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/) 并安装。
2.  **配置** (关键)：
    *   打开 Docker Desktop 设置 (⚙️图标)。
    *   **General**: 勾选 `Use the WSL 2 based engine`。
    *   **Resources > WSL Integration**: 开启 `Ubuntu` 开关。
    *   点击 `Apply & restart`。

---

## 2. 数据库配置 (Docker Compose)

在 D 盘建立一个目录专门管理环境，例如 `D:\DevEnv`，在里面创建 `docker-compose.yml`。

**文件内容**：
```yaml
version: '3.8'

services:
  # --- Redis ---
  redis:
    image: redis:latest
    container_name: my-redis
    restart: always
    command: redis-server --requirepass "redis123" --appendonly yes
    ports:
      - "6379:6379"  # 开放端口给 Windows
    volumes:
      - ./redis_data:/data

  # --- Postgres ---
  postgres:
    image: postgres:15
    container_name: my-pg
    restart: always
    environment:
      POSTGRES_USER: root
      POSTGRES_PASSWORD: pg123
      POSTGRES_DB: mydb
    ports:
      - "5432:5432"  # 开放端口给 Windows
    volumes:
      - ./pg_data:/var/lib/postgresql/data
```

解释

---

## 3. 启动与管理命令

在 `D:\DevEnv` 目录下打开 PowerShell 或 CMD：

*   **启动所有服务** (后台)：
    ```bash
    docker-compose up -d
    # -d 表示 Detached（后台运行），不占用当前终端窗口
    ```
*   **停止服务**：
    ```bash
    docker-compose down
    ```
*   **查看状态** (检查是否 Up)：
    ```bash
    docker-compose ps
    # 状态必须是 "Up"，如果是 "Exit" 说明启动报错了
    ```
3.  **查看错误日志** (如果启动失败)：
    ```bash
    docker-compose logs postgres
    # 查看 postgres 的报错信息
    ```
---

## 4. DBeaver 连接检查

打开 DBeaver，新建 **PostgreSQL** 连接：

*   **主机 (Host)**: `localhost`  *(不要填 IP，直接 localhost)*
*   **端口 (Port)**: `5432`
*   **数据库**: `mydb`
*   **用户名**: `root`
*   **密码**: `pg123`
*   **操作**: 点击 `测试连接 (Test Connection)`。
    *   *成功显示 "Connected" 表示环境通了。*

**Redis 检查方法**：
使用 Windows 上的 Redis 客户端 (如 RDM) 连接 `localhost:6379`，密码 `redis123`。

## 5. 常见问题排错

1.  **DBeaver 连不上**：
    *   检查 Docker Desktop 也就是否运行中 (右下角鲸鱼图标)。
    *   执行 `docker-compose ps` 确认状态是 `Up` 而不是 `Exit`。
    *   检查端口 5432 是否被 Windows 本地安装的 PostgreSQL 占用了 (如果有，改 yaml 里的端口为 `5433:5432`)。
2.  **数据在哪里**：
    *   数据在你 `D:\DevEnv` 下的 `pg_data` 和 `redis_data` 文件夹里，只要不删这俩，重启电脑数据也不丢。
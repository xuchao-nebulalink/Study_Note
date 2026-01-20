
##  配置文件详解 (逐行翻译)

这是核心部分，理解了这里，你就是 Docker 入门了。

```yaml
version: '3.8'  # Docker Compose 的语法版本，3.8 是主流稳定版

services:       # 定义要启动哪些服务（容器）

  # ========== Redis 服务配置 ==========
  redis:
    image: redis:latest
    # 【image】: 镜像名。类似“安装包”。latest 表示下载最新版，也可写 redis:6.2
    
    container_name: my-redis
    # 【container_name】: 给容器起个固定的名字，方便后续查看日志或停止它
    
    restart: always
    # 【restart】: 重启策略。always 代表电脑重启或 Docker 重启后，这个服务会自动启动，不用手动敲命令
    
    command: redis-server --requirepass "redis123" --appendonly yes
    # 【command】: 覆盖容器启动时的默认命令。
    # --requirepass: 设置 Redis 密码为 redis123
    # --appendonly yes: 开启 AOF 持久化，保证数据不丢
    
    ports:
      - "6379:6379"
    # 【ports】: 端口映射，格式为 "宿主机端口:容器内部端口"
    # 左边的 6379: 你在 Windows 代码里写的端口，也是 DBeaver 连接的端口。
    # 右边的 6379: Redis 软件在容器里默认监听的端口。
    
    volumes:
      - ./redis_data:/data
    # 【volumes】: 挂载卷（数据持久化），格式为 "宿主机路径:容器内部路径"
    # ./redis_data: 代表在当前 yaml 文件同级目录下自动创建 redis_data 文件夹。
    # /data: Redis 官方规定存放数据的内部路径。
    # 作用：即使删了容器，你的 redis key 依然保存在 D:\DevEnv\redis_data 里。

  # ========== Postgres 服务配置 ==========
  postgres:
    image: postgres:15
    # 指定使用 Postgres 15 版本
    
    container_name: my-pg
    
    restart: always
    
    environment:
      POSTGRES_USER: root
      POSTGRES_PASSWORD: pg123
      POSTGRES_DB: mydb
    # 【environment】: 环境变量。这是配置 Postgres 的标准方式。
    # 设置默认超级用户为 root，密码 pg123，启动时自动创建名为 mydb 的库。
    
    ports:
      - "5432:5432"
    # 左边 5432 是 Windows 访问用的，右边 5432 是容器里的。
    
    volumes:
      - ./pg_data:/var/lib/postgresql/data
    # 将 Windows 的 ./pg_data 目录映射到容器内的 /var/lib/postgresql/data。
    # 数据库的所有表结构、数据都存在这里。
```


如何后续增加数据库

## 情况一：增加一个新的数据库软件 (比如 MySQL)
**场景**：你现在有 Postgres，但项目新功能需要用到 MySQL 或 MongoDB。

### 1. 修改配置文件
打开你的 `D:\DevEnv\docker-compose.yml`，在 `services:` 下面追加 MySQL 的配置块。**注意缩进要和 redis、postgres 保持对齐**。

```yaml
services:
  # ... 原有的 redis 和 postgres 保持不动 ...

  # ========== 新增 MySQL 配置 ==========
  mysql:
    image: mysql:8.0
    container_name: my-mysql
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: root  # 设置 root 密码
      MYSQL_DATABASE: init_db    # 初始创建的库名
    ports:
      - "3306:3306"  # Windows 端口 : 容器端口
    volumes:
      - ./mysql_data:/var/lib/mysql # 数据挂载到当前目录
```

### 2. 生效命令 (关键)
修改完文件后，保存。在 PowerShell 终端（`D:\DevEnv` 目录下）再次运行：
```bash
docker-compose up -d
```
*   **原理解析**：Docker 非常智能，它会检测配置。它发现 Redis/Postgres 没变，就不会重启它们；它发现多了一个 MySQL，就会只下载并启动 MySQL。

---

## 情况二：在现有 Postgres 中增加一个新的库
**场景**：你不需要新的软件，只是想在现有的 Postgres 里多建一个叫 `order_service` 的库给新模块用。

**不需要改 docker-compose.yml**，直接用 DBeaver 操作：

1.  打开 DBeaver，连接上你的 Postgres。
2.  在左侧导航栏，右键点击 **Databases** -> **新建 Database**。
3.  输入名字 (例如 `order_service`)，点击确定。
4.  **搞定**。代码里连接串把 `/mydb` 改成 `/order_service` 即可。

---

## 情况三：想运行两个 Postgres (多版本共存)
**场景**：老项目用 Postgres 12，新项目用 Postgres 15，想同时跑。

**关键点在于：端口不能冲突**。Windows 的 5432 端口已经被占用了，第二个必须换一个（比如 5433）。

在 `docker-compose.yml` 追加：

```yaml
  # ========== 旧版 PG 服务 ==========
  postgres_old:
    image: postgres:12
    container_name: my-pg-12
    environment:
      POSTGRES_PASSWORD: pg123
    ports:
      - "5433:5432" 
      # ⚠️注意左边：我把它改成了 5433。
      # 意思是：Windows 访问 localhost:5433 就会转发到这个容器。
      # 右边 5432 别动，因为容器内部 PG 还是听 5432 的。
    volumes:
      - ./pg12_data:/var/lib/postgresql/data
```

**代码连接配置**：
*   新项目连：`localhost:5432`
*   老项目连：`localhost:5433`
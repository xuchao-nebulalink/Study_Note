# Linux Docker 安装与常用操作笔记

> 这份笔记按 **Ubuntu / Debian 为主线**，同时补充 **CentOS Stream / Fedora** 的安装方法。
> 
> 目标：**装得上、跑得通、会验证、会日常操作、会排错、会清理。**

---

## 1. Docker 是什么

Docker 是一个**容器化运行环境**。
你可以把应用、依赖、运行环境一起打成镜像，然后在任何装了 Docker 的机器上按相同方式运行。

你平时最常接触的几个概念：

- **Image（镜像）**：应用模板，只读
- **Container（容器）**：镜像运行后的实例
- **Volume（数据卷）**：持久化数据
- **Network（网络）**：容器之间通信
- **Docker Engine**：Docker 后台服务
- **Docker Compose**：多容器编排工具，通常写在 `compose.yaml`

---

## 2. 安装前先确认

先看系统信息：

```bash
uname -a
cat /etc/os-release
arch
```

看是否已经装过旧版 Docker：

```bash
docker --version
docker compose version
which docker
```

看服务状态：

```bash
systemctl status docker
```

如果提示找不到，说明大概率没装。

---

## 3. Ubuntu / Debian 安装 Docker（推荐方式）

> 推荐直接用 Docker 官方仓库安装，不建议长期用系统自带的旧包。

### 3.1 卸载旧包

#### Ubuntu

```bash
sudo apt remove $(dpkg --get-selections docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc | cut -f1)
```

#### Debian

```bash
sudo apt remove $(dpkg --get-selections docker.io docker-compose docker-doc podman-docker containerd runc | cut -f1)
```

如果提示某些包不存在，正常。

### 3.2 配置官方仓库并安装

#### Ubuntu

```bash
# 1) 安装基础依赖
sudo apt update
sudo apt install -y ca-certificates curl

# 2) 准备 keyrings 目录
sudo install -m 0755 -d /etc/apt/keyrings

# 3) 导入 Docker 官方 GPG key
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# 4) 添加 Docker 仓库
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF2
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF2

# 5) 更新索引
sudo apt update

# 6) 安装 Docker Engine + Compose 插件 + Buildx
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

#### Debian

```bash
# 1) 安装基础依赖
sudo apt update
sudo apt install -y ca-certificates curl

# 2) 准备 keyrings 目录
sudo install -m 0755 -d /etc/apt/keyrings

# 3) 导入 Docker 官方 GPG key
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# 4) 添加 Docker 仓库
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF2
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF2

# 5) 更新索引
sudo apt update

# 6) 安装 Docker Engine + Compose 插件 + Buildx
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

> Debian 衍生版（例如 Kali）如果 `$VERSION_CODENAME` 不对，需要手动改成对应 Debian 版本代号，例如 `bookworm`。

### 3.3 验证服务是否启动

```bash
sudo systemctl status docker
```

如果没启动：

```bash
sudo systemctl start docker
sudo systemctl enable docker
```

### 3.4 验证安装是否成功

```bash
sudo docker run hello-world
```

如果成功，会看到类似：

```text
Hello from Docker!
This message shows that your installation appears to be working correctly.
```

再补几条检查：

```bash
sudo docker version
sudo docker info
sudo docker images
sudo docker ps
sudo docker compose version
sudo docker buildx version
```

---

## 4. CentOS Stream 安装 Docker

### 4.1 卸载旧包

```bash
sudo dnf remove -y docker \
  docker-client \
  docker-client-latest \
  docker-common \
  docker-latest \
  docker-latest-logrotate \
  docker-logrotate \
  docker-engine
```

### 4.2 配置仓库并安装

```bash
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### 4.3 启动并设置开机自启

```bash
sudo systemctl enable --now docker
```

### 4.4 验证

```bash
sudo docker run hello-world
sudo docker version
sudo docker info
```

---

## 5. Fedora 安装 Docker

### 5.1 卸载旧包

```bash
sudo dnf remove -y docker \
  docker-client \
  docker-client-latest \
  docker-common \
  docker-latest \
  docker-latest-logrotate \
  docker-logrotate \
  docker-selinux \
  docker-engine-selinux \
  docker-engine
```

### 5.2 配置仓库并安装

```bash
sudo dnf config-manager addrepo --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### 5.3 启动并设置开机自启

```bash
sudo systemctl enable --now docker
```

### 5.4 验证

```bash
sudo docker run hello-world
sudo docker version
sudo docker info
```

---

## 6. 让普通用户不加 sudo 直接用 Docker

默认很多操作需要 `sudo`。
如果你想直接执行：

```bash
docker ps
```

而不是：

```bash
sudo docker ps
```

就把当前用户加到 `docker` 用户组。

```bash
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker
```

然后验证：

```bash
docker run hello-world
```

### 6.1 如果出现 `.docker/config.json permission denied`

执行：

```bash
sudo chown "$USER":"$USER" /home/"$USER"/.docker -R
sudo chmod g+rwx "$HOME/.docker" -R
```

### 6.2 安全说明

`docker` 组基本等同于给了很高权限，别随便把普通账号都加进去。

---

## 7. 安装完成后的标准验证清单

下面这些命令都过了，基本就 OK：

```bash
# 1) 服务状态
systemctl status docker

# 2) 版本信息
docker --version
docker compose version
docker buildx version

# 3) 引擎信息
docker version
docker info

# 4) 拉起测试容器
docker run hello-world

# 5) 跑一个长期驻留容器测试
mkdir -p ~/docker-nginx-test
cd ~/docker-nginx-test
docker run -d --name mynginx -p 8080:80 nginx
curl http://127.0.0.1:8080

# 6) 查看运行中的容器
docker ps

# 7) 看日志
docker logs mynginx

# 8) 停掉并删除测试容器
docker stop mynginx
docker rm mynginx
```

如果第 5 步返回了 nginx 欢迎页 HTML，说明：

- Docker 引擎正常
- 拉镜像正常
- 启动容器正常
- 端口映射正常
- 容器网络基本正常

---

## 8. Docker 常用操作总表

下面这些是你平时最常用的命令。

### 8.1 查看帮助

```bash
docker --help
docker run --help
docker compose --help
```

### 8.2 版本与环境信息

```bash
docker --version
docker version
docker info
docker context ls
```

---

## 9. 镜像（image）操作

### 9.1 搜索镜像

```bash
docker search nginx
```

### 9.2 拉取镜像

```bash
docker pull nginx
docker pull redis:7
docker pull mysql:8.0
```

### 9.3 查看本地镜像

```bash
docker images
docker image ls
```

### 9.4 删除镜像

```bash
docker rmi nginx
docker image rm nginx:latest
```

### 9.5 强制删除镜像

```bash
docker rmi -f nginx
```

### 9.6 给镜像打标签

```bash
docker tag nginx my-nginx:v1
```

### 9.7 导出/导入镜像

```bash
# 保存为 tar
docker save -o nginx.tar nginx:latest

# 从 tar 导入
docker load -i nginx.tar
```

### 9.8 查看镜像历史

```bash
docker history nginx
```

### 9.9 查看镜像详细信息

```bash
docker inspect nginx
```

---

## 10. 容器（container）操作

### 10.1 创建并运行容器

```bash
# 前台运行
docker run --name test-nginx -p 8080:80 nginx

# 后台运行
docker run -d --name test-nginx -p 8080:80 nginx
```

### 10.2 常见参数

```bash
-d              后台运行
-it             进入交互终端
--name          指定容器名
-p 8080:80      端口映射：宿主机:容器
-v /a:/b        挂载目录或数据卷
-e K=V          注入环境变量
--restart       重启策略
--rm            容器退出后自动删除
```

### 10.3 查看容器

```bash
docker ps        # 只看运行中的
docker ps -a     # 看全部容器
```

### 10.4 停止 / 启动 / 重启

```bash
docker stop test-nginx
docker start test-nginx
docker restart test-nginx
```

### 10.5 删除容器

```bash
docker rm test-nginx
```

如果容器还在运行：

```bash
docker rm -f test-nginx
```

### 10.6 查看日志

```bash
docker logs test-nginx
docker logs -f test-nginx
docker logs --tail 100 test-nginx
```

### 10.7 进入容器内部

```bash
docker exec -it test-nginx /bin/bash
```

有些极简镜像没有 bash，用 sh：

```bash
docker exec -it test-nginx /bin/sh
```

### 10.8 查看容器详细信息

```bash
docker inspect test-nginx
```

### 10.9 查看容器资源占用

```bash
docker stats
docker stats test-nginx
```

### 10.10 查看容器进程

```bash
docker top test-nginx
```

### 10.11 容器和宿主机之间复制文件

```bash
# 宿主机 -> 容器
docker cp ./a.txt test-nginx:/tmp/a.txt

# 容器 -> 宿主机
docker cp test-nginx:/etc/nginx/nginx.conf ./nginx.conf
```

### 10.12 查看端口映射

```bash
docker port test-nginx
```

### 10.13 修改容器重启策略

```bash
docker update --restart unless-stopped test-nginx
```

### 10.14 重命名容器

```bash
docker rename test-nginx nginx-prod
```

---

## 11. 端口映射、目录挂载、环境变量

### 11.1 端口映射

```bash
docker run -d --name web -p 8080:80 nginx
```

含义：

- 宿主机 `8080`
- 映射到容器内 `80`

访问：

```bash
curl http://127.0.0.1:8080
```

### 11.2 目录挂载

```bash
mkdir -p ~/html
echo 'hello docker' > ~/html/index.html

docker run -d --name web2 -p 8081:80 -v ~/html:/usr/share/nginx/html nginx
```

### 11.3 环境变量

```bash
docker run -d --name myredis -e TZ=Asia/Shanghai redis:7
```

### 11.4 自动重启

```bash
docker run -d --name web3 --restart unless-stopped -p 8082:80 nginx
```

常见值：

- `no`
- `on-failure`
- `always`
- `unless-stopped`

---

## 12. 数据卷（volume）操作

### 12.1 创建数据卷

```bash
docker volume create mydata
```

### 12.2 查看数据卷

```bash
docker volume ls
```

### 12.3 查看数据卷详情

```bash
docker volume inspect mydata
```

### 12.4 使用数据卷

```bash
docker run -d --name nginx-vol -p 8083:80 -v mydata:/usr/share/nginx/html nginx
```

### 12.5 删除数据卷

```bash
docker volume rm mydata
```

### 12.6 清理未使用数据卷

```bash
docker volume prune
```

---

## 13. 网络（network）操作

### 13.1 查看网络

```bash
docker network ls
```

### 13.2 创建自定义网络

```bash
docker network create mynet
```

### 13.3 让容器加入同一网络

```bash
docker run -d --name app1 --network mynet nginx
docker run -d --name app2 --network mynet nginx
```

### 13.4 查看网络详情

```bash
docker network inspect mynet
```

### 13.5 连接 / 断开容器网络

```bash
docker network connect mynet test-nginx
docker network disconnect mynet test-nginx
```

### 13.6 删除网络

```bash
docker network rm mynet
```

### 13.7 清理未使用网络

```bash
docker network prune
```

---

## 14. 从 Dockerfile 构建镜像

### 14.1 最简单例子

创建目录：

```bash
mkdir -p ~/docker-demo
cd ~/docker-demo
```

创建 `Dockerfile`：

```dockerfile
FROM nginx:latest
COPY ./html /usr/share/nginx/html
```

准备页面文件：

```bash
mkdir -p html
echo '<h1>Hello Docker Build</h1>' > html/index.html
```

构建镜像：

```bash
docker build -t mysite:v1 .
```

运行：

```bash
docker run -d --name mysite -p 8088:80 mysite:v1
curl http://127.0.0.1:8088
```

### 14.2 常用构建命令

```bash
docker build -t myapp:latest .
docker build -f Dockerfile.prod -t myapp:prod .
docker build --no-cache -t myapp:clean .
```

### 14.3 Buildx

```bash
docker buildx version
docker buildx ls
```

---

## 15. Docker Compose 常用操作

> 现在通常用的是 `docker compose`，不是老的 `docker-compose`。

### 15.1 示例 `compose.yaml`

```yaml
services:
  nginx:
    image: nginx:latest
    container_name: compose-nginx
    ports:
      - "8089:80"
    restart: unless-stopped
```

### 15.2 常用命令

```bash
# 启动
docker compose up -d

# 前台启动
docker compose up

# 停止并删除
docker compose down

# 查看状态
docker compose ps

# 查看日志
docker compose logs
docker compose logs -f

# 重启
docker compose restart

# 拉取最新镜像
docker compose pull

# 重新构建并启动
docker compose up -d --build

# 进入容器
docker compose exec nginx /bin/sh
```

### 15.3 启动步骤建议

常规项目一般这样：

```bash
cd 项目目录
ls
cat compose.yaml
docker compose pull
docker compose up -d
docker compose ps
docker compose logs -f
```

---

## 16. 仓库登录、推送、拉取

### 16.1 登录仓库

```bash
docker login
```

登录私有仓库：

```bash
docker login registry.example.com
```

### 16.2 打 tag

```bash
docker tag mysite:v1 yourname/mysite:v1
```

### 16.3 推送镜像

```bash
docker push yourname/mysite:v1
```

### 16.4 拉取镜像

```bash
docker pull yourname/mysite:v1
```

### 16.5 退出登录

```bash
docker logout
docker logout registry.example.com
```

---

## 17. 清理命令

Docker 用久了，磁盘会很脏。
下面这些命令你要会。

### 17.1 删除已停止容器

```bash
docker container prune
```

### 17.2 删除未使用镜像

```bash
docker image prune
```

删除所有未被容器使用的镜像：

```bash
docker image prune -a
```

### 17.3 删除未使用网络

```bash
docker network prune
```

### 17.4 删除未使用数据卷

```bash
docker volume prune
```

### 17.5 一键清理大部分无用资源

```bash
docker system prune
```

更狠一点：

```bash
docker system prune -a --volumes
```

> 这个会删很多东西，执行前自己确认。

### 17.6 查看磁盘占用

```bash
docker system df
docker system df -v
```

---

## 18. 服务管理

### 18.1 查看状态

```bash
systemctl status docker
```

### 18.2 启动 / 停止 / 重启

```bash
sudo systemctl start docker
sudo systemctl stop docker
sudo systemctl restart docker
```

### 18.3 开机自启 / 取消开机自启

```bash
sudo systemctl enable docker
sudo systemctl disable docker
```

### 18.4 查看实时日志

```bash
journalctl -u docker -f
```

---

## 19. 常见问题排查

### 19.1 `docker: command not found`

先看有没有装：

```bash
which docker
docker --version
```

没有就重新安装。

### 19.2 `Cannot connect to the Docker daemon`

常见原因：

- docker 服务没启动
- 当前用户没权限
- `/var/run/docker.sock` 权限问题

检查：

```bash
systemctl status docker
ls -l /var/run/docker.sock
```

处理：

```bash
sudo systemctl start docker
sudo usermod -aG docker $USER
newgrp docker
```

### 19.3 `permission denied while trying to connect to the Docker daemon socket`

通常就是没进 `docker` 组。

```bash
sudo usermod -aG docker $USER
newgrp docker
```

### 19.4 `port is already allocated`

端口被占用。

查端口：

```bash
ss -lntp | grep 8080
lsof -i:8080
```

换端口或者停掉占用进程。

### 19.5 拉镜像慢 / 失败

检查：

```bash
docker pull nginx
curl -I https://registry-1.docker.io
```

如果网络差：

- 先确认宿主机能否正常访问外网
- 公司网络可能有限制
- 代理或镜像源配置可能有问题

### 19.6 容器一启动就退出

先看日志：

```bash
docker logs 容器名
```

再看容器配置：

```bash
docker inspect 容器名
```

### 19.7 容器里没有 bash

很多轻量镜像没有 `bash`，改用：

```bash
docker exec -it 容器名 /bin/sh
```

### 19.8 磁盘爆满

```bash
docker system df
docker system prune -a --volumes
```

执行前先确认是否有重要数据卷。

---

## 20. 常见目录

```text
/var/lib/docker/                Docker 数据目录
/etc/docker/                    Docker 配置目录
/etc/docker/daemon.json         Docker daemon 配置文件
/var/run/docker.sock            Docker Unix Socket
```

---

## 21. `daemon.json` 常见配置

文件：

```bash
sudo mkdir -p /etc/docker
sudo vim /etc/docker/daemon.json
```

示例：

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "data-root": "/data/docker"
}
```

改完重启：

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

说明：

- `log-driver`：日志驱动
- `max-size` / `max-file`：控制日志滚动
- `data-root`：Docker 数据根目录

如果你要把 Docker 数据迁到大磁盘，通常就会改 `data-root`。

---

## 22. 卸载 Docker

### Ubuntu / Debian

```bash
sudo apt purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
```

### CentOS / Fedora

```bash
sudo dnf remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
```

> 删除 `/var/lib/docker` 会把镜像、容器、卷等数据一起删掉。

---

## 23. 新手最小闭环：从安装到跑通

你最少按这套顺序走：

```bash
# 1. 看系统
cat /etc/os-release

# 2. 按发行版安装 Docker

# 3. 看服务
sudo systemctl status docker

# 4. 跑 hello-world
sudo docker run hello-world

# 5. 免 sudo（可选）
sudo usermod -aG docker $USER
newgrp docker

# 6. 再验证
docker run hello-world

# 7. 拉一个 nginx
docker pull nginx

# 8. 跑 nginx
docker run -d --name mynginx -p 8080:80 nginx

# 9. 看是否能访问
curl http://127.0.0.1:8080

# 10. 看日志
docker logs mynginx

# 11. 停掉并删除
docker stop mynginx
docker rm mynginx
```

你把这 11 步走通，就算 Docker 基本入门了。

---

## 24. 我建议你记住的 30 条高频命令

```bash
docker --version
docker version
docker info
docker images
docker ps
docker ps -a
docker pull nginx
docker run -d --name web -p 8080:80 nginx
docker stop web
docker start web
docker restart web
docker rm web
docker rmi nginx
docker logs -f web
docker exec -it web /bin/sh
docker inspect web
docker stats
docker cp web:/etc/nginx/nginx.conf ./
docker volume ls
docker volume create mydata
docker volume inspect mydata
docker network ls
docker network create mynet
docker network inspect mynet
docker build -t myapp:v1 .
docker compose version
docker compose up -d
docker compose ps
docker compose logs -f
docker system prune -a --volumes
```

---

## 25. 最后结论

安装 Docker，最稳的方式就是：

1. **用官方仓库安装**
2. **先跑 `hello-world` 验证**
3. **再跑一个 nginx 做端口映射验证**
4. **再配置普通用户免 sudo**
5. **最后掌握镜像、容器、卷、网络、compose、清理、排错**

这样就够你日常开发、部署、测试用了。

---

## 26. 官方参考

- Docker Engine 安装总览：<https://docs.docker.com/engine/install/>
- Ubuntu 安装：<https://docs.docker.com/engine/install/ubuntu/>
- Debian 安装：<https://docs.docker.com/engine/install/debian/>
- CentOS 安装：<https://docs.docker.com/engine/install/centos/>
- Fedora 安装：<https://docs.docker.com/engine/install/fedora/>
- Linux 安装后步骤：<https://docs.docker.com/engine/install/linux-postinstall/>

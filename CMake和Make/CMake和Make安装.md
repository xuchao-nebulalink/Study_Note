
# 📝 MSYS2 安装 CMake & Make 简易笔记
### 第一步：下载并安装 MSYS2

1. 访问官网：[msys2.org](https://www.google.com/url?sa=E&q=https%3A%2F%2Fwww.msys2.org%2F)。
2. 下载安装程序（通常是 msys2-x86_64-xxxx.exe）。
3. 运行安装程序，建议安装在默认路径 C:\msys64（**路径中千万不要有中文或空格**）。
4. 安装完成后，勾选 "Run MSYS2 now"。
### 1. 启动环境
打开 **MSYS2 UCRT64** (黄色图标)。
> **注意：** 始终优先使用 UCRT64 环境，它是最现代的 Windows 开发标准。

### 2. 更新系统 (首次安装必做)
在终端输入以下命令：
```bash
pacman -Syu
```

### 3. 一键安装工具链
直接复制并运行以下命令，安装编译器、Make 和 CMake：
```bash
pacman -S mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-make mingw-w64-ucrt-x86_64-cmake mingw-w64-ucrt-x86_64-gdb
```

### 4. 配置 Windows 环境变量
为了能在全局（如 VS Code, CMD, PowerShell）使用，必须手动添加路径：
1.  右键 **此电脑** -> **属性** -> **高级系统设置** -> **环境变量**。
2.  在 **系统变量** 中找到 **Path**，点击编辑。
3.  新建并添加路径：`C:\msys64\ucrt64\bin`
4.  一路点击“确定”保存。

### 5. 修正 Make 命令名称
MSYS2 默认的 make 文件名是 `mingw32-make.exe`，为了使用方便：
1.  打开文件夹：`C:\msys64\ucrt64\bin`
2.  找到 `mingw32-make.exe`，原地**复制一份**。
3.  将副本重命名为 `make.exe`。

### 6. 验证安装
打开一个新的 **CMD** 或 **PowerShell**，输入以下命令检查：
*   `gcc -v`
*   `cmake --version`
*   `make -v`

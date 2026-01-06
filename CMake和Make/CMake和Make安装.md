这份笔记整理好了，主打**简单、核心、实操**，直接复制到你的笔记软件（Notion/Obsidian）里即可。

---

# 🛠️ C++ 构建工具与 Windows 环境配置笔记

## 1. 三者关系（一句话看懂）
> **比喻**：盖房子
> *   **源代码** = 砖头
> *   **GCC/Clang** = 砌砖工人（编译器）

*   **CMake (总指挥)**：
    *   它不直接编译，而是**生成**施工图纸。
    *   **作用**：跨平台。你写一份 `CMakeLists.txt`，它根据你的环境生成 `Makefile` 或 `build.ninja`。
*   **Make (老工头)**：
    *   拿着 CMake 给的图纸（Makefile）指挥工人干活。
    *   **缺点**：逻辑古老，并发能力弱，慢。
*   **Ninja (新工头)**：
    *   Google 开发的，拿着 CMake 给的图纸（build.ninja）指挥工人干活。
    *   **优点**：**极速**，专注于并行编译。

**🚀 最佳组合**：`CMake` + `Ninja` + `GCC`

---

## 2. Windows 安装流程 (MSYS2 方案)

### Step 1: 下载与环境
1.  下载安装 [MSYS2](https://www.msys2.org/)。
2.  安装路径保持默认 `C:\msys64`（**严禁中文和空格**）。
3.  打开 **`MSYS2 UCRT64`** 终端（注意是 **UCRT64**，兼容性最好）。

### Step 2: 一键安装命令
直接运行下面这条命令，一次性装好编译器、CMake、Ninja、Git 等全家桶：

```bash
pacman -S --needed base-devel mingw-w64-ucrt-x86_64-toolchain mingw-w64-ucrt-x86_64-make mingw-w64-ucrt-x86_64-cmake mingw-w64-ucrt-x86_64-ninja git
```
*(遇到询问直接回车，输入 Y 确认)*

### Step 3: 配置系统环境变量 (PATH)
为了在 VSCode 或 PowerShell 里能用，必须配置 Windows 环境变量：
1.  搜索“编辑系统环境变量” -> 环境变量 -> 系统变量 -> **Path** -> 编辑。
2.  新建添加路径：**`C:\msys64\ucrt64\bin`**

### Step 4: 避坑操作 (Make 改名)
MSYS2 默认的 Make 叫 `mingw32-make.exe`，为了方便使用：
1.  去 `C:\msys64\ucrt64\bin`。
2.  找到 `mingw32-make.exe`，复制一份。
3.  将副本重命名为 **`make.exe`**。

---

## 3. 日常开发常用命令

### 检查安装是否成功（在 PowerShell 中）
```bash
gcc --version
cmake --version
ninja --version
make --version
```

### 标准编译流程（使用 Ninja）
```bash
# 1. 创建并进入构建目录
mkdir build
cd build

# 2. 生成构建文件 (指定 Ninja 为生成器)
cmake -G "Ninja" ..

# 3. 开始编译
ninja
```

---

## ⚠️ 常见问题急救
如果遇到 **“之前能跑，现在报错”** 或者 **“DLL 错误”**：
1.  **环境冲突**：确保 Path 里 MSYS2 的路径在最前面，别和旧的 MinGW 混用。
2.  **清理缓存**：直接删除 `build` 文件夹，重新运行 cmake 和 ninja。**换了环境必须重新编译！**
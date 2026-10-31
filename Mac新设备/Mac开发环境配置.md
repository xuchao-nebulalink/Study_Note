# Mac 开发环境配置

适用：Apple Silicon（M 系列芯片）＋ zsh，macOS 版本需满足 [Homebrew 当前支持要求](https://docs.brew.sh/Installation#macos-requirements)。已安装的工具验证通过后跳过安装。Git、Python、Go 见单独笔记。

## 1. 苹果命令行工具（先装）

提供 Clang 编译器、macOS SDK、Make 等基础工具。普通命令行开发先安装 Command Line Tools 即可。

```bash
xcode-select --install
```

等待弹窗中的安装完成，再验证；提示已安装时直接验证：

```bash
xcode-select -p
clang++ --version
make --version
```

开发工具路径通常为 `/Library/Developer/CommandLineTools`；完整 Xcode 也可能提供另一条有效路径。

## 2. Homebrew（软件包管理器）

安装：

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

按安装器的 Next steps 配置 PATH。Apple Silicon 默认路径为 `/opt/homebrew`，zsh 通常执行：

```bash
echo >> ~/.zprofile
echo 'eval "$(/opt/homebrew/bin/brew shellenv zsh)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv zsh)"
```

第一行补换行，避免与已有文件末行连在一起；第二行保存配置，第三行让当前终端生效。已配置时不要重复追加。安装时输入登录密码不显示字符，输完回车即可。

验证：

```bash
brew --version
command -v brew
brew --prefix
```

后两条应分别为 `/opt/homebrew/bin/brew`、`/opt/homebrew`。

## 3. C/C++（使用 Apple Clang）

第 1 步已提供编译器和 SDK。先使用 `clang` 编译 C、`clang++` 编译 C++；项目明确要求时再安装 GCC 等其他工具链。

在练习项目目录中新建 `main.cpp`，写入以下内容（这是文件内容，不是终端命令）：

```cpp
#include <iostream>

int main() {
    std::cout << "C++ OK" << std::endl;
    return 0;
}
```

在该目录编译、运行：

```bash
clang++ -std=c++20 -Wall -Wextra -g main.cpp -o hello
./hello
```

输出 `C++ OK` 即通过。`-std=c++20` 指定语言标准，`-g` 生成调试信息，`-o hello` 指定程序名称。

## 4. Make（执行构建规则）

优先使用第 1 步提供的 `make`。对于已有 `Makefile` 的项目，在项目目录执行 `make`。

项目需要新版 GNU Make 时再安装：

```bash
brew install make
gmake --version
```

**Homebrew 版本的命令是 `gmake`，不会自动替换现有的 `make`。** 先保留默认命名，按项目要求选择。

## 5. CMake（生成构建系统）

安装、验证：

```bash
brew install cmake
cmake --version
```

在第 3 步的 `main.cpp` 同级目录创建 `CMakeLists.txt`，写入：

```cmake
cmake_minimum_required(VERSION 3.20)
project(cpp_demo LANGUAGES CXX)

add_executable(hello main.cpp)
target_compile_features(hello PRIVATE cxx_std_20)
```

在项目目录配置、构建、运行：

```bash
cmake -S . -B build
cmake --build build
./build/hello
```

`-S .` 指定源代码目录，`-B build` 指定构建目录。修改代码后通常只需重新执行 `cmake --build build`。

关系：**CMake 生成构建规则 → Make 等工具执行规则 → Clang 编译代码**。CMake 本身不是编译器。

## 6. 编辑器（可选）

已有编辑器可以继续使用。VS Code 安装与打开项目：

```bash
brew install --cask visual-studio-code
code .
```

`code .` 在项目目录执行；补全、调试等功能后续按需配置。

## 7. 日常维护

| 命令 | 用途 |
| --- | --- |
| `brew list` | 查看已安装的软件 |
| `brew info cmake` | 查看软件版本、路径和安装提示 |
| `brew update` | 更新 Homebrew 及软件信息 |
| `brew outdated` | 查看有更新的软件 |
| `brew upgrade cmake` | 升级指定软件，名称按需替换 |

普通 `brew install` 不加 `sudo`。安装器确有需要时会自行提示。工具报错时先看具体输出，避免重复安装或反复追加 PATH。

官方资料：[苹果命令行工具](https://developer.apple.com/documentation/xcode/installing-the-command-line-tools) · [Homebrew 安装](https://docs.brew.sh/Installation) · [Make/gmake](https://formulae.brew.sh/formula/make) · [CMake 入门](https://cmake.org/cmake/help/latest/guide/tutorial/Before%20You%20Begin.html)

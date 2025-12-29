# Windsurf 里让 C/C++ 跳转可用（装旧版 cpptools）

- 结论：Windsurf 里新版 VSCode C/C++ 扩展（cpptools）可能不可用，装 **旧版 vsix** 通常能用。

**做法（超简版）**
1. 在 **VSCode** 里找到 **C/C++（ms-vscode.cpptools）**，下载一个**旧版本**的 `.vsix`
2. 到 **Windsurf**：Extensions → `...` → **Install from VSIX...** → 选择刚下载的 `.vsix`
3. 重启 Windsurf，然后用 `F12 / Ctrl+点` 测试跳转

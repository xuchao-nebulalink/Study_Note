# PowerShell / CMD 跑 npm 不一致（简记）

**原因**：PowerShell 命中的是 `D:\nodejs\npm.ps1`（脚本），会被 ExecutionPolicy 拦；CMD 跑的是 `npm.cmd`，不受影响。

确认：
```powershell
Get-Command npm
```
解决（任选其一）：
```powershell

# 1) 直接跑 cmd 版本（最快）

npm.cmd --version

# 2) 仅当前窗口临时放开（关窗口失效）

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
npm --version

# 3) 当前用户长期放开（常用）

Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
# 提示时输入 Y 回车
npm --version
```
如果 3) 仍无效（可能被组策略锁定）：
```powershell

Get-ExecutionPolicy -List

```
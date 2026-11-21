# Antigravity Proxy Launcher

**一个可配置、免安装的 Windows 启动器，让 Antigravity 使用你自己的代理，并在更新或重装后继续从桌面启动。**

[English](README.en.md) · [下载最新版](https://github.com/Jack464/antigravity-proxy-launcher/releases/latest) · [直接下载 EXE](https://github.com/Jack464/antigravity-proxy-launcher/releases/latest/download/AntigravityProxyLauncher.exe) · [反馈问题](https://github.com/Jack464/antigravity-proxy-launcher/issues/new/choose)

本项目独立开发，与 Google / Antigravity 官方无隶属关系。它只负责启动已安装的 Antigravity；不提供代理节点、不包含 Antigravity，也不读取或保存 Google 登录凭据。

## 下载与使用

适用于 **Windows 10 / 11**，需要 **.NET Framework 4.8**。不需要安装 .NET SDK、Node.js、Python 或 PowerShell 插件。程序按 AnyCPU 构建；当前支持范围为常规 x86 / x64 Windows 桌面环境，ARM64 未单独验证。

1. 从 [Releases](https://github.com/Jack464/antigravity-proxy-launcher/releases/latest) 下载 `AntigravityProxyLauncher.exe`，或下载便携 ZIP 后解压。
2. 将程序放到一个长期保留的目录，例如 `Documents\AntigravityProxyLauncher`。**放在 Antigravity 安装目录之外**，防止应用更新时清理掉启动器；创建快捷方式后也不要随意移动程序。
3. 首次双击会打开设置。保持自动查找 Antigravity，填入自己的代理地址，例如 `http://127.0.0.1:7890` 或 `socks5://127.0.0.1:10808`。
4. 选择保存并启动。也可以在设置中创建桌面快捷方式，以后双击该快捷方式直接启动。

发布包提供以下文件：

| 文件 | 用途 |
| --- | --- |
| `AntigravityProxyLauncher.exe` | 可直接运行的便携程序 |
| `AntigravityProxyLauncher-v1.0.0-windows.zip` | 程序、说明及许可证的便携包 |
| `SHA256SUMS.txt` | 下载文件的 SHA-256 校验值 |

当前发布程序未做付费代码签名。请从本仓库的 Release 下载；如果 Windows 显示发布者未知，可先核对下载来源和校验值，不要关闭系统防护。

```powershell
Get-FileHash .\AntigravityProxyLauncher.exe -Algorithm SHA256
```

## 解决什么问题

- 浏览器完成 Google 授权后，桌面应用交换登录令牌仍需要自己的网络连接。启动器将代理变量传给新启动的 Antigravity 进程。
- 启动器独立于应用目录，并在启动时重新查找程序，不依赖具体 Antigravity 版本号。
- 更新或重装留下同名后台辅助进程时，仍可启动主界面；不会因为发现一个 `Antigravity.exe` 进程就拒绝启动。
- 应用已有主窗口时，尝试恢复并显示该窗口。
- 代理端口不可达、程序路径无效或主窗口未出现时，显示具体错误并保留日志。

## 设置

| 设置 | 行为 |
| --- | --- |
| 使用代理 | 开启时向新应用进程注入代理变量；关闭时以直接连接方式启动 |
| 自动检测代理 | 优先检查填写的代理地址，再检查代理环境变量、Windows 系统代理和常见本地端口 |
| 代理地址 | 支持 `http://`、`socks5://`、`socks5h://`；不支持带用户名或密码的 URL |
| Antigravity 路径 | 留空时从标准安装目录及 Windows 注册信息查找；便携或自定义安装可手动选择 `Antigravity.exe` |
| 代理客户端路径 | 可选。代理不可用时启动这个已有客户端，等待代理端口就绪；不下载或安装客户端 |

自动检测只尝试本机回环地址，常见端口为 `7890`、`7897`、`10808`、`10809`。使用远程代理时请关闭自动检测并手动填写地址；如果电脑同时运行多个代理，也建议填写明确地址。

**端口检查只确认 TCP 连接可建立，不证明代理节点能够访问 Google。** 节点、代理分流和网络访问权限仍由你的代理客户端决定。

设置保存在 Windows 当前用户的本地应用数据目录：

```text
%LOCALAPPDATA%\AntigravityProxyLauncher\config.ini
```

日志也保存在该目录，实际路径可在设置或诊断信息中查看。程序不会修改 Windows 的永久环境变量或系统代理设置。

新应用进程会收到 `HTTP_PROXY`、`HTTPS_PROXY`、`ALL_PROXY`；本地回环地址放入 `NO_PROXY`，供 OAuth 回调和本地进程通信使用。

## 已经运行的应用

Windows 无法通过启动第二个进程，给已经运行的进程补加环境变量。若 Antigravity 原先由安装器、普通图标或其他工具打开，点击本启动器可能只显示原窗口。**需要让代理配置生效时，先保存工作并完全退出 Antigravity，再使用本启动器打开。**

启动器不会自动强制结束应用或辅助进程。

## 命令行

```text
AntigravityProxyLauncher.exe             启动；首次运行显示设置
AntigravityProxyLauncher.exe --settings  打开设置
AntigravityProxyLauncher.exe --diagnose  输出诊断，不启动应用
AntigravityProxyLauncher.exe --version   输出版本
AntigravityProxyLauncher.exe --help      输出帮助
```

这是 Windows GUI 程序。需要在终端捕获诊断输出时，可使用等待并重定向的方式：

```powershell
Start-Process .\AntigravityProxyLauncher.exe -ArgumentList '--diagnose' -Wait `
  -RedirectStandardOutput .\diagnostics.txt
Get-Content .\diagnostics.txt
```

诊断会检查路径、配置和本地代理端口，不进行 Google 登录，也不会上传结果。手动配置的远程代理只显示地址，诊断不会主动连接该远程端点；实际启动时才检查其可达性。

## 更新兼容性

一般的覆盖更新或原位置重装不需要重新配置启动器。独立保存的启动器、配置和桌面快捷方式可以保留。

如果 Antigravity 未来改名、改变安装架构，或不再支持这些代理环境变量，需要更新本项目。若手动设置的程序路径失效，可在设置中清空该路径恢复自动查找，或重新选择安装位置。

本启动器不自动更新自己。下载新版本替换原 EXE，配置会继续保留。

## 从源码构建

在 Windows 上使用系统自带的 .NET Framework C# 编译器，不需要恢复 NuGet 包：

```powershell
git clone https://github.com/Jack464/antigravity-proxy-launcher.git
cd antigravity-proxy-launcher
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build.ps1 -Version 1.0.0 -Test -Package
```

构建和打包结果位于 `dist/`。测试只使用临时目录和本地测试端口，不依赖真实 Antigravity 安装或 Google 账号。

GitHub Actions 会验证推送和 Pull Request。推送 `v*` 标签时，工作流在测试通过后构建并发布 EXE、便携 ZIP 和校验值；第三方 Actions 固定到具体提交，Release 写权限仅提供给发布任务。

参见 [贡献指南](CONTRIBUTING.md) 和 [更新记录](CHANGELOG.md)。

## 许可证与品牌

源代码和本项目原创图标采用 [MIT License](LICENSE)。Antigravity 及 Google 的名称属于其各自权利人，本仓库不分发 Google 原版图标、应用程序或账号数据。

# Antigravity Proxy Launcher

**一个可配置的 Windows / macOS 启动器，让 Antigravity 使用你自己的代理，并将启动入口与应用更新分开保存。**

[English](README.en.md) · [下载最新版](https://github.com/Jack464/antigravity-proxy-launcher/releases/latest) · [直接下载 EXE](https://github.com/Jack464/antigravity-proxy-launcher/releases/latest/download/AntigravityProxyLauncher.exe) · [反馈问题](https://github.com/Jack464/antigravity-proxy-launcher/issues/new/choose)

本项目独立开发，与 Google / Antigravity 官方无隶属关系。它只负责启动已安装的 Antigravity；不提供代理节点、不包含 Antigravity，也不读取或保存 Google 登录凭据。

## 下载与使用

| 平台 | 下载 | 运行要求 |
| --- | --- | --- |
| Windows | [单文件 EXE](https://github.com/Jack464/antigravity-proxy-launcher/releases/latest/download/AntigravityProxyLauncher.exe) 或 Release 中的 `*-windows.zip` | Windows 10 / 11，.NET Framework 4.8；常规 x86 / x64 桌面环境 |
| macOS 预览版 | [Universal ZIP](https://github.com/Jack464/antigravity-proxy-launcher/releases/download/v1.1.0/AntigravityProxyLauncher-v1.1.0-macos-universal.zip) | macOS 12 或更新版本；Apple Silicon 与 Intel |

macOS 版为 Swift / AppKit 原生应用，用户不需要安装 .NET、Swift SDK、Node.js 或 Python。Windows ARM64 尚未单独验证。

### Windows

1. 从 [Releases](https://github.com/Jack464/antigravity-proxy-launcher/releases/latest) 下载 `AntigravityProxyLauncher.exe`，或下载便携 ZIP 后解压。
2. 将程序放到一个长期保留的目录，例如 `Documents\AntigravityProxyLauncher`。**放在 Antigravity 安装目录之外**，防止应用更新时清理掉启动器；创建快捷方式后也不要随意移动程序。
3. 首次双击会打开设置。保持自动查找 Antigravity，填入自己的代理地址，例如 `http://127.0.0.1:7890` 或 `socks5://127.0.0.1:10808`。
4. 选择保存并启动。也可以在设置中创建桌面快捷方式，以后双击该快捷方式直接启动。

### macOS 预览版

1. 下载 `AntigravityProxyLauncher-v1.1.0-macos-universal.zip` 并解压。
2. 将 `Antigravity Proxy Launcher.app` 放入“应用程序”或其他长期保留的位置。请放在 `Antigravity.app` 包之外；可将启动器拖入 Dock 方便以后使用。
3. 首次打开后填写代理地址。应用位置可留空，启动器会查找 `/Applications/Antigravity.app`、`~/Applications/Antigravity.app` 以及系统登记的安装位置；自定义安装可手动选择 `.app`。
4. 选择保存并启动。以后需要更改设置时，按住 **Option** 再打开启动器；设置窗口打开时也可使用菜单中的“设置”。

**macOS 版当前为预览版：以 CI 构建和自动测试为验证依据，尚未在实际 Mac 上验证 Finder 首次打开、Gatekeeper 行为或 Google OAuth 登录。** 发布包仅采用 ad-hoc 签名，没有 Apple Developer ID 签名或公证，因此下载后可能被 Gatekeeper 拦截。请先确认下载来源与校验值，并参阅 [Apple 官方的安全打开应用说明](https://support.apple.com/102445)；本项目不要求关闭系统安全防护。

发布包提供以下文件：

| 文件 | 用途 |
| --- | --- |
| `AntigravityProxyLauncher.exe` | 可直接运行的 Windows 便携程序 |
| `AntigravityProxyLauncher-v1.1.0-windows.zip` | Windows 程序、说明及许可证 |
| `AntigravityProxyLauncher-v1.1.0-macos-universal.zip` | macOS Universal `.app`、说明及许可证（预览版） |
| `SHA256SUMS.txt` | 下载文件的 SHA-256 校验值 |

Windows 发布程序尚未代码签名。请从本仓库的 Release 下载；如果 Windows 显示发布者未知，可先核对下载来源和校验值，不要关闭系统防护。

```powershell
Get-FileHash .\AntigravityProxyLauncher.exe -Algorithm SHA256
```

## 解决什么问题

- 浏览器完成 Google 授权后，桌面应用交换登录令牌仍需要自己的网络连接。启动器将代理变量传给新启动的 Antigravity 进程。
- 启动器独立于应用目录，并在启动时重新查找程序，不依赖具体 Antigravity 版本号。
- Windows 更新或重装留下同名后台辅助进程时，仍可启动主界面；不会因为发现一个 `Antigravity.exe` 进程就拒绝启动。
- 应用已经运行时，尝试恢复窗口或激活现有应用。
- 代理端口不可达、程序路径无效或主窗口未出现时，显示具体错误并保留日志。

## 设置

| 设置 | 行为 |
| --- | --- |
| 使用代理 | 开启时向新应用进程注入代理变量；关闭时以直接连接方式启动 |
| 自动检测代理 | 优先检查填写的代理地址，再检查代理环境变量、当前平台的系统代理和常见本地端口 |
| 代理地址 | 支持 `http://`、`socks5://`、`socks5h://`；不支持带用户名或密码的 URL |
| Antigravity 路径 | 留空时自动查找；Windows 手动选择 `Antigravity.exe`，macOS 手动选择 `Antigravity.app` |
| 代理客户端路径 | 可选。代理不可用时启动这个已有客户端，等待代理端口就绪；Windows 选择 `.exe`，macOS 选择 `.app`；不下载或安装客户端 |

自动检测只尝试本机回环地址，常见端口为 `7890`、`7897`、`10808`、`10809`。使用远程代理时请关闭自动检测并手动填写地址；如果电脑同时运行多个代理，也建议填写明确地址。

**端口检查只确认 TCP 连接可建立，不证明代理节点能够访问 Google。** 节点、代理分流和网络访问权限仍由你的代理客户端决定。

Windows 设置保存在当前用户的本地应用数据目录：

```text
%LOCALAPPDATA%\AntigravityProxyLauncher\config.ini
```

macOS 设置保存在：

```text
~/Library/Application Support/AntigravityProxyLauncher/config.json
```

两平台的 `launcher.log` 均保存在各自配置目录，实际路径可在设置或诊断信息中查看。程序不会修改永久环境变量或系统代理设置，也不会通过 `launchctl` 设置全局代理。

新应用进程会收到 `HTTP_PROXY`、`HTTPS_PROXY`、`ALL_PROXY`；本地回环地址放入 `NO_PROXY`，供 OAuth 回调和本地进程通信使用。

## 已经运行的应用

启动第二个进程无法给已经运行的进程补加环境变量。若 Antigravity 原先由安装器、普通图标或其他工具打开，点击本启动器可能只显示或激活原应用。**需要让代理配置生效时，先保存工作并完全退出 Antigravity，再使用本启动器打开。** macOS 请使用 `Command-Q` 完全退出，关闭窗口本身不一定会结束应用。

启动器不会自动强制结束应用或辅助进程。

## 命令行

```text
AntigravityProxyLauncher.exe             启动；首次运行显示设置
AntigravityProxyLauncher.exe --settings  打开设置
AntigravityProxyLauncher.exe --diagnose  输出诊断，不启动应用
AntigravityProxyLauncher.exe --version   输出版本
AntigravityProxyLauncher.exe --help      输出帮助
```

Windows 版是 GUI 程序。需要在终端捕获诊断输出时，可使用等待并重定向的方式：

```powershell
Start-Process .\AntigravityProxyLauncher.exe -ArgumentList '--diagnose' -Wait `
  -RedirectStandardOutput .\diagnostics.txt
Get-Content .\diagnostics.txt
```

macOS 可直接调用应用包内的程序，参数相同，例如：

```bash
"/Applications/Antigravity Proxy Launcher.app/Contents/MacOS/AntigravityProxyLauncher" --diagnose
"/Applications/Antigravity Proxy Launcher.app/Contents/MacOS/AntigravityProxyLauncher" --settings
```

诊断会检查路径、配置和本地代理端口，不进行 Google 登录，也不会上传结果。手动配置的远程代理只显示地址，诊断不会主动连接该远程端点；实际启动时才检查其可达性。

## 更新兼容性

一般的覆盖更新或原位置重装不需要重新配置启动器。独立保存的启动器、配置和桌面快捷方式可以保留。

如果 Antigravity 未来改名、改变安装架构，或不再支持这些代理环境变量，需要更新本项目。若手动设置的程序路径失效，可在设置中清空该路径恢复自动查找，或重新选择安装位置。

本启动器不自动更新自己。下载新版本替换原 EXE 或 `.app`，配置会继续保留。

## 从源码构建

在 Windows 上使用系统自带的 .NET Framework C# 编译器，不需要恢复 NuGet 包：

```powershell
git clone https://github.com/Jack464/antigravity-proxy-launcher.git
cd antigravity-proxy-launcher
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build.ps1 -Version 1.1.0 -Test -Package
```

在装有 Xcode Command Line Tools 的 Mac 上：

```bash
swift test --package-path macos
bash scripts/build-macos.sh 1.1.0
```

macOS 源码使用 Swift Package，构建脚本打包 Universal `.app`。构建和打包结果位于 `dist/`。自动测试使用临时目录和本地测试端口，不依赖真实 Antigravity 安装或 Google 账号。

GitHub Actions 会分别验证 Windows 和 macOS 的推送与 Pull Request。推送 `v*` 标签时，工作流在测试通过后发布 Windows EXE、两个平台的 ZIP 和统一校验值；第三方 Actions 固定到具体提交，Release 写权限仅提供给发布任务。CI 编译和单元测试不等同于实际 Mac 的首次下载、Gatekeeper 或登录验证。

参见 [贡献指南](CONTRIBUTING.md) 和 [更新记录](CHANGELOG.md)。

## 许可证与品牌

源代码和本项目原创图标采用 [MIT License](LICENSE)。Antigravity 及 Google 的名称属于其各自权利人，本仓库不分发 Google 原版图标、应用程序或账号数据。

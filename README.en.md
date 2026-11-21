# Antigravity Proxy Launcher

**A configurable Windows / macOS launcher that starts Antigravity with your own proxy settings and keeps the launcher separate from application updates.**

[简体中文](README.md) · [Latest release](https://github.com/Jack464/antigravity-proxy-launcher/releases/latest) · [Download EXE](https://github.com/Jack464/antigravity-proxy-launcher/releases/latest/download/AntigravityProxyLauncher.exe) · [Report an issue](https://github.com/Jack464/antigravity-proxy-launcher/issues/new/choose)

This is an independent project, not an official Google or Antigravity product. It launches an existing installation. It does not provide proxy servers, bundle Antigravity, or read or store Google sign-in credentials.

## Quick start

| Platform | Download | Requirements |
| --- | --- | --- |
| Windows | [Standalone EXE](https://github.com/Jack464/antigravity-proxy-launcher/releases/latest/download/AntigravityProxyLauncher.exe) or the `*-windows.zip` Release asset | Windows 10 / 11 and .NET Framework 4.8; conventional x86 / x64 desktops |
| macOS preview | [Universal ZIP](https://github.com/Jack464/antigravity-proxy-launcher/releases/download/v1.1.0/AntigravityProxyLauncher-v1.1.0-macos-universal.zip) | macOS 12 or later; Apple Silicon and Intel |

The Mac application is native Swift / AppKit. Users do not need .NET, a Swift SDK, Node.js, or Python. Windows ARM64 has not been separately tested.

### Windows

1. Download `AntigravityProxyLauncher.exe` from [Releases](https://github.com/Jack464/antigravity-proxy-launcher/releases/latest), or extract the portable ZIP.
2. Keep it in a permanent folder **outside Antigravity's installation directory**, such as `Documents\AntigravityProxyLauncher`. Keep the EXE at this location after creating a shortcut.
3. Run it once to configure your proxy, for example `http://127.0.0.1:7890` or `socks5://127.0.0.1:10808`.
4. Save and launch. You can also create a desktop shortcut in Settings; later launches use the saved configuration.

### macOS preview

1. Download and extract `AntigravityProxyLauncher-v1.1.0-macos-universal.zip`.
2. Move `Antigravity Proxy Launcher.app` to Applications or another permanent location. Keep it outside the `Antigravity.app` bundle; optionally add the launcher to the Dock.
3. Open it once to configure the proxy. Leave the application path blank to discover `/Applications/Antigravity.app`, `~/Applications/Antigravity.app`, or the system-registered installation. Select the `.app` manually for a custom installation.
4. Save and launch. Use the launcher's Settings menu when you need to change the configuration.

**The macOS version is a preview: validation is based on CI builds and automated tests, without physical-Mac verification of first launch from Finder, Gatekeeper, or Google OAuth sign-in.** The bundle has an ad-hoc signature, not an Apple Developer ID signature or notarization, so Gatekeeper may prevent opening a downloaded copy. Confirm the source and checksum, and consult [Apple's guidance on safely opening Mac apps](https://support.apple.com/102445). This project does not require disabling system protection.

Release assets:

| File | Purpose |
| --- | --- |
| `AntigravityProxyLauncher.exe` | Ready-to-run Windows portable application |
| `AntigravityProxyLauncher-v1.1.0-windows.zip` | Windows application, documentation, and license |
| `AntigravityProxyLauncher-v1.1.0-macos-universal.zip` | macOS Universal `.app`, documentation, and license (preview) |
| `SHA256SUMS.txt` | SHA-256 checksums for downloadable files |

The Windows executable is unsigned. Download from this repository's Releases and compare its checksum if Windows reports an unknown publisher; do not disable system protection.

```powershell
Get-FileHash .\AntigravityProxyLauncher.exe -Algorithm SHA256
```

## Features

- Pass proxy environment variables to newly launched Antigravity processes.
- Discover the current installation through platform-specific standard locations and registration records, or use an explicit path.
- Keep the launcher outside directories managed by Antigravity's updater.
- On Windows, open the main interface even when a same-name background helper remains after an update or reinstall.
- Restore an existing main window or activate a running application instead of unnecessarily starting another instance.
- Check the proxy endpoint, optionally start a configured proxy client, and provide errors and local logs.
- Create a Windows desktop shortcut with the project's own icon; the Mac `.app` can be added to the Dock.

## Configuration

| Setting | Behavior |
| --- | --- |
| Use proxy | Inject proxy settings into a new application process; disable for direct connections |
| Auto-detect proxy | Try the configured address first, then proxy environment variables, platform system proxy settings, and common local ports |
| Proxy URL | Supports `http://`, `socks5://`, and `socks5h://`; URLs containing usernames or passwords are not supported |
| Antigravity application | Leave blank for discovery; select `Antigravity.exe` on Windows or `Antigravity.app` on macOS for a custom installation |
| Proxy client application | Optional existing client to start when the proxy endpoint is unavailable; choose an `.exe` on Windows or `.app` on macOS; the launcher does not download or install clients |

Auto-detection only probes local loopback addresses. Common ports are `7890`, `7897`, `10808`, and `10809`. Disable auto-detection and set an explicit address for a remote proxy or when several proxy clients are running.

**A successful TCP check only establishes that the endpoint accepts a connection. It does not prove that the proxy can reach Google.** Routing and upstream connectivity remain the responsibility of your proxy client.

Configuration is stored at the current user's Windows local application data location:

```text
%LOCALAPPDATA%\AntigravityProxyLauncher\config.ini
```

On macOS, configuration is stored at:

```text
~/Library/Application Support/AntigravityProxyLauncher/config.json
```

Each platform stores `launcher.log` in its configuration directory. Settings and diagnostics show the resolved paths. The launcher does not change permanent environment variables or system proxy settings, and does not use `launchctl` to set global proxy variables.

New processes receive `HTTP_PROXY`, `HTTPS_PROXY`, and `ALL_PROXY`. Loopback addresses are included in `NO_PROXY` for OAuth callbacks and local communication.

## Existing instances

Starting a new process cannot add environment variables to a process that is already running. If Antigravity was opened by an installer, its original shortcut, or another tool, this launcher may simply bring that existing window forward. **To apply proxy settings, save your work, exit Antigravity completely, then launch it here.**

On macOS, use `Command-Q` to quit the application. Closing its window alone does not necessarily end the process.

The launcher never forcibly terminates Antigravity or its helpers.

## Command line

```text
AntigravityProxyLauncher.exe             Launch; show Settings on first run
AntigravityProxyLauncher.exe --settings  Open Settings
AntigravityProxyLauncher.exe --diagnose  Print diagnostics without launching apps
AntigravityProxyLauncher.exe --version   Print the version
AntigravityProxyLauncher.exe --help      Print help
```

The Windows build is a GUI application. To capture command output, wait for it and redirect stdout:

```powershell
Start-Process .\AntigravityProxyLauncher.exe -ArgumentList '--diagnose' -Wait `
  -RedirectStandardOutput .\diagnostics.txt
Get-Content .\diagnostics.txt
```

On macOS, invoke the executable inside the application bundle with the same options, for example:

```bash
"/Applications/Antigravity Proxy Launcher.app/Contents/MacOS/AntigravityProxyLauncher" --diagnose
"/Applications/Antigravity Proxy Launcher.app/Contents/MacOS/AntigravityProxyLauncher" --settings
```

Diagnostics inspect paths, configuration, and local proxy endpoints. They do not sign in to Google or upload results. A manually configured remote proxy is displayed without connecting to it; the real launch checks its reachability.

## Updates and compatibility

Normal in-place application updates and reinstalls generally keep working without reconfiguring this launcher. Its executable, settings, and shortcut remain separate from Antigravity's files.

Future changes to the application name, installation architecture, or proxy environment support may require launcher changes. If an explicitly configured application path becomes invalid, clear it to restore discovery or select the new location.

This launcher does not update itself. Replace its EXE or `.app` with a new release to upgrade; settings remain in the user profile.

## Build from source

The Windows build uses the .NET Framework C# compiler already installed on the system, with no NuGet dependencies:

```powershell
git clone https://github.com/Jack464/antigravity-proxy-launcher.git
cd antigravity-proxy-launcher
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build.ps1 -Version 1.1.0 -Test -Package
```

On a Mac with Xcode Command Line Tools:

```bash
swift test --package-path macos
bash scripts/build-macos.sh 1.1.0
```

The macOS source is a Swift Package; the build script packages a Universal `.app`. Build artifacts are written to `dist/`. Automated tests use temporary directories and local test ports; no actual Antigravity installation or Google account is required.

GitHub Actions builds and tests Windows and macOS pushes and pull requests. A `v*` tag publishes the Windows EXE, both platform ZIPs, and combined checksums after the builds pass. Actions are pinned to commit IDs; only the release job receives repository write permission. Compilation and unit tests in CI do not replace physical-Mac verification of downloaded-app launch, Gatekeeper, or sign-in.

See [CONTRIBUTING.md](CONTRIBUTING.md) and [CHANGELOG.md](CHANGELOG.md).

## License and branding

Source code and the project's original icon are licensed under the [MIT License](LICENSE). Google and Antigravity names belong to their respective owners. This repository does not redistribute Google's original icon, application binaries, or account data.

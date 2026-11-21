# Changelog

## 1.1.0

- Add a native Swift / AppKit macOS preview for macOS 12 and later, packaged as a Universal application for Apple Silicon and Intel.
- Add Mac settings, local diagnostics, per-launch proxy environment, standard application discovery, and optional proxy-client `.app` startup.
- Store Mac configuration and logs under the current user's Application Support directory.
- Activate an already running Mac application without forcibly ending it; document that proxy changes require a complete quit and relaunch.
- Add macOS automated tests and release packaging alongside the Windows build, with combined SHA-256 checksums.
- Document the Mac preview's validation limits: no physical-Mac Finder, Gatekeeper, or Google OAuth verification; no Developer ID signing or notarization.
- Retain the Windows portable launcher and its existing configuration format.

## 1.0.0

First public release of Antigravity Proxy Launcher.

- Portable Windows executable with a first-run settings interface.
- Configurable HTTP and SOCKS proxy addresses, automatic endpoint discovery, and optional proxy-client startup.
- Antigravity discovery through standard installation paths and Windows registry records.
- Per-process proxy environment variables with loopback exclusions for local callbacks.
- Main-window restoration and safe startup in the presence of background helper processes.
- Desktop shortcut creation, local diagnostics, and persistent user configuration.
- Original project icon, MIT license, Chinese and English documentation.
- Windows build and tests with GitHub Release packaging and SHA-256 checksums.

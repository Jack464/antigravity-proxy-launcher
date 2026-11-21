# Contributing

欢迎通过 Issue 或 Pull Request 参与改进。Please keep reports and changes focused on a reproducible launcher problem.

## Build and test

For Windows, use .NET Framework 4.8. Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build.ps1 -Version 1.1.0 -Test -Package
```

For macOS, use a Mac with Xcode Command Line Tools:

```bash
swift test --package-path macos
bash scripts/build-macos.sh 1.1.0
```

The macOS app uses Swift / AppKit without third-party package dependencies. The build produces a Universal application for Apple Silicon and Intel. Automated tests and CI must not be described as physical-Mac validation of first launch from Finder, Gatekeeper, or OAuth sign-in. Keep this preview status explicit until those workflows have actually been verified.

Do not commit compiled binaries, your `config.ini` or `config.json`, local logs, proxy subscriptions, Google tokens, or personal file paths. Release binaries are published as GitHub Release assets.

Tests must not depend on a real Google account, a particular proxy node, or the contributor's Antigravity installation. Use temporary files and local listeners for configuration, process environment, and endpoint checks.

On an unlocked Windows desktop, also run the helper-process regression test:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-gui.ps1
```

This compiles a separate test application named `Antigravity.exe` in `build/gui-fixture`, starts a headless helper, and verifies that the launcher can open a new window and reuse it on a second launch. It only closes the fixture processes it created; the installed Antigravity application is not used.

## Scope

The launcher should remain small, portable, and independent of Antigravity's installation. Changes must preserve these behaviors:

- Proxy configuration affects newly launched applications rather than permanent system settings or global `launchctl` variables.
- No automatic process termination, credential extraction, or TLS validation bypass.
- Background helpers with no main window must not prevent opening the application.
- Existing windows or applications can be restored or activated without starting unnecessary duplicates; existing processes cannot receive new environment variables.
- No usernames, drive letters, or installation paths specific to one developer.
- No bundled third-party application binaries or proprietary brand assets.

Describe the problem, resulting behavior, and validation in a PR. If a change affects settings or command-line options, update both READMEs.

## Releases

1. Update the version metadata and `CHANGELOG.md`.
2. Run the full build, tests, and package command.
3. Push an annotated version tag such as `v1.1.1` after reviewing the source.
4. The tag workflow builds the same source for Windows and macOS, then publishes the Windows EXE, both platform ZIPs, and combined checksums.

The Mac preview is ad-hoc signed, without Apple Developer ID signing or notarization. Do not document `xattr` or `spctl` commands that disable or remove platform protection. Refer users to [Apple's safe app-opening guidance](https://support.apple.com/102445) when explaining distribution limitations.

The workflow uses GitHub's built-in token. Contributors do not need to add a personal access token or sign in to Google for the build.

## Reporting private data

Logs and diagnostics can contain local paths and proxy addresses. Review and redact them before posting publicly. Never attach access tokens, proxy credentials, or account databases.

# Contributing

欢迎通过 Issue 或 Pull Request 参与改进。Please keep reports and changes focused on a reproducible launcher problem.

## Build and test

Use Windows with .NET Framework 4.8. Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build.ps1 -Version 1.0.0 -Test -Package
```

Do not commit compiled binaries, your `config.ini`, local logs, proxy subscriptions, Google tokens, or personal file paths. Release binaries are published as GitHub Release assets.

Tests must not depend on a real Google account, a particular proxy node, or the contributor's Antigravity installation. Use temporary files and local listeners for configuration, process environment, and endpoint checks.

On an unlocked Windows desktop, also run the helper-process regression test:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-gui.ps1
```

This compiles a separate test application named `Antigravity.exe` in `build/gui-fixture`, starts a headless helper, and verifies that the launcher can open a new window and reuse it on a second launch. It only closes the fixture processes it created; the installed Antigravity application is not used.

## Scope

The launcher should remain small, portable, and independent of Antigravity's installation. Changes must preserve these behaviors:

- Proxy configuration affects child processes rather than permanent system settings.
- No automatic process termination, credential extraction, or TLS validation bypass.
- Background helpers with no main window must not prevent opening the application.
- Existing windows can be restored without starting unnecessary duplicates.
- No usernames, drive letters, or installation paths specific to one developer.
- No bundled third-party application binaries or proprietary brand assets.

Describe the problem, resulting behavior, and validation in a PR. If a change affects settings or command-line options, update both READMEs.

## Releases

1. Update the version metadata and `CHANGELOG.md`.
2. Run the full build, tests, and package command.
3. Push an annotated version tag such as `v1.0.1` after reviewing the source.
4. The tag workflow builds the same source and publishes the EXE, ZIP, and checksums.

The workflow uses GitHub's built-in token. Contributors do not need to add a personal access token or sign in to Google for the build.

## Reporting private data

Logs and diagnostics can contain local paths and proxy addresses. Review and redact them before posting publicly. Never attach access tokens, proxy credentials, or account databases.

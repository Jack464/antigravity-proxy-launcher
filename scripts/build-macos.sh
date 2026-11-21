#!/bin/bash
set -euo pipefail

version="${1:-1.1.0}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf 'Expected a version such as 1.1.0.\n' >&2
  exit 2
fi
if [[ "$(uname -s)" != Darwin ]]; then
  printf 'Build this app on macOS with Xcode Command Line Tools.\n' >&2
  exit 1
fi
project_root="$(cd "$(dirname "$0")/.." && pwd)"
build_root="$project_root/build/macos"
dist_root="$project_root/dist"
app="$build_root/Antigravity Proxy Launcher.app"
mkdir -p "$build_root" "$dist_root" "$app/Contents/MacOS" "$app/Contents/Resources"
export MACOSX_DEPLOYMENT_TARGET=12.0

for architecture in arm64 x86_64; do
  swift build --package-path "$project_root/macos" --scratch-path "$build_root/$architecture" --configuration release --arch "$architecture"
done
arm_bin="$(swift build --package-path "$project_root/macos" --scratch-path "$build_root/arm64" --configuration release --arch arm64 --show-bin-path)"
intel_bin="$(swift build --package-path "$project_root/macos" --scratch-path "$build_root/x86_64" --configuration release --arch x86_64 --show-bin-path)"
xcrun lipo -create "$arm_bin/AntigravityProxyLauncher" "$intel_bin/AntigravityProxyLauncher" -output "$app/Contents/MacOS/AntigravityProxyLauncher"
xcrun lipo -verify_arch arm64 x86_64 "$app/Contents/MacOS/AntigravityProxyLauncher"
chmod 755 "$app/Contents/MacOS/AntigravityProxyLauncher"

cat > "$app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Antigravity Proxy Launcher</string>
<key>CFBundleDisplayName</key><string>Antigravity Proxy Launcher</string>
<key>CFBundleExecutable</key><string>AntigravityProxyLauncher</string>
<key>CFBundleIdentifier</key><string>io.github.jack464.antigravity-proxy-launcher</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$version</string>
<key>CFBundleVersion</key><string>$version</string>
<key>CFBundleIconFile</key><string>LauncherIcon</string>
<key>LSMinimumSystemVersion</key><string>12.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHumanReadableCopyright</key><string>Copyright 2026 Jack464. MIT License.</string>
</dict></plist>
EOF
plutil -lint "$app/Contents/Info.plist"

swift "$project_root/scripts/macos-icon.swift" "$build_root/LauncherIcon.iconset"
iconutil -c icns "$build_root/LauncherIcon.iconset" -o "$app/Contents/Resources/LauncherIcon.icns"
cp "$project_root/LICENSE" "$project_root/README.md" "$project_root/README.en.md" "$app/Contents/Resources/"
# Ad-hoc signing verifies bundle integrity on Apple Silicon. It is not Developer ID signing or notarization.
codesign --force --sign - "$app"
codesign --verify --deep --strict --verbose=2 "$app"
"$app/Contents/MacOS/AntigravityProxyLauncher" --version
"$app/Contents/MacOS/AntigravityProxyLauncher" --help

zip_name="AntigravityProxyLauncher-v$version-macos-universal.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$dist_root/$zip_name"
(cd "$dist_root" && shasum -a 256 "$zip_name") > "$dist_root/SHA256SUMS-macos.txt"
printf 'Built %s\n' "$dist_root/$zip_name"

#!/bin/bash
# 把 ClaudeBar 打包成 .app bundle（menu-bar only，ad-hoc 簽章）。
# 用法：bash scripts/build-app.sh
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="ClaudeBar"
BUNDLE_ID="com.claudebar.app"
VERSION="0.2.2"
OUT="dist/${APP_NAME}.app"

echo "==> swift build -c release"
swift build -c release
BIN=".build/release/${APP_NAME}"

echo "==> 組裝 ${OUT}"
rm -rf "$OUT"
mkdir -p "${OUT}/Contents/MacOS" "${OUT}/Contents/Resources"
cp "$BIN" "${OUT}/Contents/MacOS/${APP_NAME}"
cp assets/claude-logo.png "${OUT}/Contents/Resources/claude-logo.png"

cat > "${OUT}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

echo "==> ad-hoc 簽章"
codesign --force --deep --sign - "$OUT"

echo "==> 壓成 zip（給 GitHub Release 當自我更新檔）"
ZIP="dist/${APP_NAME}-${VERSION}.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$OUT" "$ZIP"

echo "==> 完成：${OUT}"
echo "Release 檔：${ZIP}（上傳到 GitHub Release，tag 用 v${VERSION}）"
echo "拖進 /Applications，或： open ${OUT}"
